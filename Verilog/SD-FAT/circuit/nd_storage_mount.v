/****************************************************************************
** nd_storage open/preload FSM (mount)                                     **
**                                                                         **
** Design: docs/nd-storage-design.md section 2.3; binding contract        **
** docs/nd-storage-interface-spec.md sections 6 and 7. Invoked by the     **
** block engine (nd_storage_engine.v) once per granted open request:      **
**                                                                         **
**   M_IDLE : wait for mnt_start; latch the client; clear that client's  **
**            open_ok/open_err (only a new open_req rebuilds a slot).    **
**            A client outside PRELOAD_MASK (the SMD cache-window        **
**            clients 3..6 in v1) fails IMMEDIATELY - no card traffic,   **
**            no reader release (Phase 4 replaces this with the          **
**            tag-based cache fill).                                     **
**   M_INIT : phase_write<=0 (reader owns the SD pins), hold the reader  **
**            in reset a few more cycles, then release it for a FULL     **
**            init+mount+scan run - the per-open re-init that doubles    **
**            as the proven rewind/card-swap recovery.                   **
**   M_CARD : wait for card init (card_stat >= 8); watchdog -> NOCARD.   **
**   M_SCAN : wait for file_found; latch size/first-sector/first-cluster **
**            and geometry at the SAME edge (the ST_C_FIND lesson: the   **
**            reader is parked later and its registers reset with it).   **
**            size > slot -> park + fail, decided combinationally at     **
**            the latch edge - the reader needs hundreds of cycles to    **
**            reach the first outen byte, so no payload ever moves.      **
**            scan_done without file_found (missing file / bad FS) or    **
**            watchdog -> park + fail.                                   **
**   M_LOAD : consume the outen/outbyte stream -> 4-byte big-endian      **
**            packer (byte 4m lands in mem_wdata[31:24]) -> 8x32 sync    **
**            FIFO -> mem-port writes at {SLOT_BASE_BLK[c],9'b0} +       **
**            byte_cnt[21:2]; the tail word is zero-padded. The FIFO     **
**            only absorbs jitter (1 byte per ~16-64 clk_stor from the   **
**            reader vs ~10-40 clk_stor per mem write); overflow sets    **
**            the sticky load_fifo_ovf flag the testbench asserts on.    **
**   M_PARK : reader back into reset, phase_write<=1 (sd_writer owns    **
**            the card again).                                           **
**   M_CHK  : SDFAT_STORAGE_CHECK contiguity gate (nd_storage_fatchk.v): **
**            pulse chk_start once, wait for chk_done; chk_ok -> M_OK,   **
**            not ok (fragmented file / FAT read error) -> M_FAIL. The   **
**            failed open can simply be retried with a new open_req.     **
**            Without the feature flag the state passes straight through **
**            to M_OK (the card recipe alone guarantees contiguity).     **
**   M_OK   : open_ok[c]<=1, size_bytes/n_blocks (=ceil(size/2048)) /    **
**            first_sector published, mnt_done with mnt_err=0.           **
**   M_FAIL : open_err[c]<=1, mnt_done with mnt_err=1.                   **
**                                                                         **
** open_ok stays up across later write errors (spec section 7); only a   **
** new open_req for that client clears and rebuilds it (done here at     **
** the M_IDLE handshake).                                                 **
**                                                                         **
** Everything runs in clk_stor. The mem port is muxed onto the shared    **
** device port by the top (nd_storage.v) while mnt_busy is high; the     **
** engine is parked in E_OPEN for that whole time by construction.       **
**                                                                         **
** Last reviewed: 11-JUL-2026                                              **
** Ronny Hansen                                                            **
*****************************************************************************/
`include "sd_fat_features.vh"

module nd_storage_mount #(
    parameter         N_CLIENTS      = 7,             // 1..7
    parameter [31:0]  WD_MAX         = 32'd270_000_000,
    parameter [6:0]   PRELOAD_MASK   = 7'b0000111,    // v1: clients 0..2 only
    parameter [31:0]  SLOT0_BASE_BLK = 32'd0,
    parameter [31:0]  SLOT0_SIZE_BLK = 32'd32,
    parameter [31:0]  SLOT1_BASE_BLK = 32'd32,
    parameter [31:0]  SLOT1_SIZE_BLK = 32'd640,
    parameter [31:0]  SLOT2_BASE_BLK = 32'd672,
    parameter [31:0]  SLOT2_SIZE_BLK = 32'd640,
    parameter [31:0]  SLOT3_BASE_BLK = 32'd1312,
    parameter [31:0]  SLOT3_SIZE_BLK = 32'd160,
    parameter [31:0]  SLOT4_BASE_BLK = 32'd1472,
    parameter [31:0]  SLOT4_SIZE_BLK = 32'd160,
    parameter [31:0]  SLOT5_BASE_BLK = 32'd1632,
    parameter [31:0]  SLOT5_SIZE_BLK = 32'd160,
    parameter [31:0]  SLOT6_BASE_BLK = 32'd1792,
    parameter [31:0]  SLOT6_SIZE_BLK = 32'd160
) (
    input  wire clk_stor,
    input  wire rst_stor_n,

    // ---- engine handoff (nd_storage_engine E_OPEN) ----
    input  wire        mnt_start,   // 1-cycle pulse per granted open
    input  wire [2:0]  mnt_client,  // stable while the engine waits
    output reg         mnt_done,    // 1-cycle pulse
    output reg         mnt_err,     // valid with mnt_done
    output wire        mnt_busy,    // owns the reader + mem port while high

    // ---- reader control / observation (sd_file_reader at the top) ----
    output reg         rd_run,       // 1 = release the reader's reset
    output reg         phase_write,  // 1 = sd_writer owns the SD pins
    output reg  [2:0]  cur_client,   // target_name/target_len mux select
    input  wire [3:0]  card_stat,
    input  wire        file_found,
    input  wire        scan_done,
    input  wire [31:0] found_size,
    input  wire [31:0] found_first_sector,
    input  wire [31:0] found_cluster,    // captured for the fatchk checker
    input  wire [7:0]  fs_cluster_size,  // captured for the fatchk checker
    input  wire [31:0] fs_fat0_sector,   // captured for the fatchk checker
    input  wire        fs_is_fat32,      // captured for the fatchk checker
    input  wire        outen,
    input  wire [7:0]  outbyte,

    // ---- mem port (muxed onto the device port while mnt_busy) ----
    output reg         mem_start,   // 1-cycle pulse, only when mem_busy=0
    output wire        mem_we,      // the mount only ever writes
    output reg  [19:0] mem_addr,
    output reg  [31:0] mem_wdata,
    input  wire        mem_busy,
    input  wire        mem_done,

    // ---- fatchk handoff (nd_storage_fatchk.v, SDFAT_STORAGE_CHECK) ----
    output reg         chk_start,          // 1-cycle pulse in M_CHK
    input  wire        chk_done,           // 1-cycle pulse from the checker
    input  wire        chk_ok,             // level, valid at chk_done
    output reg  [31:0] chk_first_cluster,  // latched with file_found
    output reg  [7:0]  chk_cluster_size,
    output reg  [31:0] chk_fat0_sector,
    output reg         chk_is_fat32,       // latched with file_found
    output wire [31:0] chk_size,           // = the latched found_file_size

    // ---- per-client open results (clk_stor; quasi-static levels) ----
    output reg  [N_CLIENTS-1:0]    open_ok,
    output reg  [N_CLIENTS-1:0]    open_err,
    output wire [N_CLIENTS*32-1:0] size_bytes,
    output wire [N_CLIENTS*16-1:0] n_blocks,     // ceil(size/2048)
    output wire [N_CLIENTS*32-1:0] first_sector,

    // ---- sd_status feed for the top (spec section 7) ----
    output reg        st_upd,  // 1-cycle pulse with mnt_done (card was touched)
    output reg  [1:0] st_val,  // 1 = NOCARD, 2 = ERROR, 3 = OK

    // ---- testbench hook: preload FIFO never overflows (sticky) ----
    output reg load_fifo_ovf
);

  // ------------------------------------------------------------- slot map
  function [31:0] slot_base;
    input [2:0] c;
    begin
      case (c)
        3'd0:    slot_base = SLOT0_BASE_BLK;
        3'd1:    slot_base = SLOT1_BASE_BLK;
        3'd2:    slot_base = SLOT2_BASE_BLK;
        3'd3:    slot_base = SLOT3_BASE_BLK;
        3'd4:    slot_base = SLOT4_BASE_BLK;
        3'd5:    slot_base = SLOT5_BASE_BLK;
        default: slot_base = SLOT6_BASE_BLK;
      endcase
    end
  endfunction

  function [31:0] slot_size;
    input [2:0] c;
    begin
      case (c)
        3'd0:    slot_size = SLOT0_SIZE_BLK;
        3'd1:    slot_size = SLOT1_SIZE_BLK;
        3'd2:    slot_size = SLOT2_SIZE_BLK;
        3'd3:    slot_size = SLOT3_SIZE_BLK;
        3'd4:    slot_size = SLOT4_SIZE_BLK;
        3'd5:    slot_size = SLOT5_SIZE_BLK;
        default: slot_size = SLOT6_SIZE_BLK;
      endcase
    end
  endfunction

  // slot capacity in bytes (max slot 640 blocks = 1.25 MB, fits 32 bits)
  wire [31:0] s_slot_bytes = slot_size(cur_client) << 11;

  // ------------------------------------------------------------- FSM
  localparam [3:0] M_IDLE = 4'd0;
  localparam [3:0] M_INIT = 4'd1;
  localparam [3:0] M_CARD = 4'd2;
  localparam [3:0] M_SCAN = 4'd3;
  localparam [3:0] M_LOAD = 4'd4;
  localparam [3:0] M_PARK = 4'd5;
  localparam [3:0] M_CHK  = 4'd6;
  localparam [3:0] M_OK   = 4'd7;
  localparam [3:0] M_FAIL = 4'd8;

  reg [3:0]  s_state;
  reg [3:0]  s_rstcnt;      // extra reader-reset cycles in M_INIT
  reg        s_mask_fail;   // fail without ever touching the card (SMD v1)
  reg        s_nocard;      // fail reason: card never initialized
  reg        s_chk_run;     // M_CHK: chk_start issued, waiting for chk_done
  reg [31:0] s_size;        // latched found_file_size
  reg [31:0] s_first;       // latched found_file_first_sector

  assign chk_size = s_size;  // stable from the file_found latch to mnt_done

  assign mnt_busy = (s_state != M_IDLE);
  assign mem_we   = 1'b1;   // preload only writes

  wire s_card_ready = (card_stat >= 4'd8);

  // ------------------------------------------------------------- results
  reg [31:0] r_size  [0:N_CLIENTS-1];
  reg [15:0] r_nblk  [0:N_CLIENTS-1];
  reg [31:0] r_first [0:N_CLIENTS-1];

  genvar gc;
  generate
    for (gc = 0; gc < N_CLIENTS; gc = gc + 1) begin : g_res
      assign size_bytes[32*gc +: 32]   = r_size[gc];
      assign n_blocks[16*gc +: 16]     = r_nblk[gc];
      assign first_sector[32*gc +: 32] = r_first[gc];
    end
  endgenerate

  // ------------------------------------------------------------- watchdog
  // reset on any state change and on load progress (outen / mem_done)
  reg [3:0]  s_state_q;
  reg [31:0] s_wd;
  always @(posedge clk_stor) begin
    if (!rst_stor_n) begin
      s_state_q <= M_IDLE;
      s_wd      <= 32'd0;
    end else begin
      s_state_q <= s_state;
      if (s_state != s_state_q || s_state == M_IDLE || outen || mem_done)
        s_wd <= 32'd0;
      else s_wd <= s_wd + 32'd1;
    end
  end
  wire s_wd_hit = (s_wd >= WD_MAX);

  // ------------------------------------------------------------- packer+FIFO
  // outen/outbyte -> big-endian 32-bit words (byte 4m first = [31:24]),
  // buffered in a small same-clock FIFO, drained by the mem-port writer.
  reg [23:0] s_pack;        // last up-to-3 bytes received
  reg [21:0] s_bcnt;        // file byte counter (byte_cnt of the design doc)
  reg        s_flushed;     // tail word (if any) pushed after scan_done
  reg [31:0] s_fifo [0:7];
  reg [3:0]  s_wptr;
  reg [3:0]  s_rptr;
  reg [18:0] s_wordcnt;     // mem words written (= byte_cnt[21:2] in order)
  reg        s_outst;       // one mem op outstanding

  wire [3:0] s_ff_fill  = s_wptr - s_rptr;
  wire       s_ff_empty = (s_wptr == s_rptr);
  wire       s_ff_full  = (s_ff_fill == 4'd8);

  // zero-padded tail word for the flush push
  reg [31:0] s_tail_w;
  always @(*) begin
    case (s_bcnt[1:0])
      2'd1:    s_tail_w = {s_pack[7:0], 24'd0};
      2'd2:    s_tail_w = {s_pack[15:0], 16'd0};
      2'd3:    s_tail_w = {s_pack[23:0], 8'd0};
      default: s_tail_w = 32'd0;  // no partial word: nothing to push
    endcase
  end

  wire [31:0] s_base_blk  = slot_base(cur_client);
  wire [19:0] s_base_word = {s_base_blk[10:0], 9'd0};

  wire s_load_done = scan_done && s_flushed && s_ff_empty && !s_outst;

  // ------------------------------------------------------------- main
  always @(posedge clk_stor) begin : main
    integer i;
    if (!rst_stor_n) begin
      s_state           <= M_IDLE;
      s_rstcnt          <= 4'd0;
      s_mask_fail       <= 1'b0;
      s_nocard          <= 1'b0;
      s_size            <= 32'd0;
      s_first           <= 32'd0;
      cur_client        <= 3'd0;
      rd_run            <= 1'b0;
      phase_write       <= 1'b1;   // out of reset the writer owns the pins
      mnt_done          <= 1'b0;
      mnt_err           <= 1'b0;
      mem_start         <= 1'b0;
      mem_addr          <= 20'd0;
      mem_wdata         <= 32'd0;
      chk_start         <= 1'b0;
      chk_first_cluster <= 32'd0;
      chk_cluster_size  <= 8'd0;
      chk_fat0_sector   <= 32'd0;
      chk_is_fat32      <= 1'b0;
      s_chk_run         <= 1'b0;
      open_ok           <= {N_CLIENTS{1'b0}};
      open_err          <= {N_CLIENTS{1'b0}};
      st_upd            <= 1'b0;
      st_val            <= 2'd0;
      load_fifo_ovf     <= 1'b0;
      s_pack            <= 24'd0;
      s_bcnt            <= 22'd0;
      s_flushed         <= 1'b0;
      s_wptr            <= 4'd0;
      s_rptr            <= 4'd0;
      s_wordcnt         <= 19'd0;
      s_outst           <= 1'b0;
      for (i = 0; i < N_CLIENTS; i = i + 1) begin
        r_size[i]  <= 32'd0;
        r_nblk[i]  <= 16'd0;
        r_first[i] <= 32'd0;
      end
    end else begin
      mnt_done  <= 1'b0;
      mem_start <= 1'b0;
      chk_start <= 1'b0;
      st_upd    <= 1'b0;

      // ---- preload datapath (active in M_LOAD only) --------------------
      if (s_state == M_LOAD) begin
        if (outen) begin
          s_pack <= {s_pack[15:0], outbyte};
          s_bcnt <= s_bcnt + 22'd1;
          if (s_bcnt[1:0] == 2'd3) begin
            if (s_ff_full) load_fifo_ovf <= 1'b1;  // sticky; tb asserts 0
            s_fifo[s_wptr[2:0]] <= {s_pack, outbyte};
            s_wptr <= s_wptr + 4'd1;
          end
        end else if (scan_done && !s_flushed) begin
          // stream over: zero-pad and push the partial tail word (if any)
          s_flushed <= 1'b1;
          if (s_bcnt[1:0] != 2'd0) begin
            if (s_ff_full) load_fifo_ovf <= 1'b1;
            s_fifo[s_wptr[2:0]] <= s_tail_w;
            s_wptr <= s_wptr + 4'd1;
          end
        end

        // drain: one outstanding mem write at a time
        if (!s_outst && !s_ff_empty && !mem_busy) begin
          mem_start <= 1'b1;
          mem_addr  <= s_base_word + {1'd0, s_wordcnt};
          mem_wdata <= s_fifo[s_rptr[2:0]];
          s_rptr    <= s_rptr + 4'd1;
          s_wordcnt <= s_wordcnt + 19'd1;
          s_outst   <= 1'b1;
        end
        if (mem_done) s_outst <= 1'b0;
      end

      // ---- FSM ----------------------------------------------------------
      case (s_state)
        M_IDLE: begin
          rd_run      <= 1'b0;
          phase_write <= 1'b1;
          if (mnt_start) begin
            cur_client            <= mnt_client;
            open_ok[mnt_client]   <= 1'b0;  // only a new open rebuilds a slot
            open_err[mnt_client]  <= 1'b0;
            s_nocard              <= 1'b0;
            s_rstcnt              <= 4'd15;
            if (mnt_client >= N_CLIENTS[2:0] || !PRELOAD_MASK[mnt_client]) begin
              // v1: SMD cache-window clients answer open_err immediately -
              // no reader release, no card traffic (Phase 4 lands here)
              s_mask_fail <= 1'b1;
              s_state     <= M_FAIL;
            end else begin
              s_mask_fail <= 1'b0;
              s_state     <= M_INIT;
            end
          end
        end

        M_INIT: begin
          phase_write <= 1'b0;         // reader owns the SD pins
          if (s_rstcnt != 4'd0) begin
            s_rstcnt <= s_rstcnt - 4'd1;  // a clean reset window first
          end else begin
            rd_run  <= 1'b1;           // full init+mount+scan run begins
            s_state <= M_CARD;
          end
        end

        M_CARD: begin
          if (s_card_ready) begin
            s_state <= M_SCAN;
          end else if (s_wd_hit || scan_done) begin
            // no card / init failure (an unmountable card can also fall
            // straight to scan_done)
            s_nocard    <= !scan_done;
            rd_run      <= 1'b0;
            phase_write <= 1'b1;
            s_state     <= M_FAIL;
          end
        end

        M_SCAN: begin
          if (file_found) begin
            // same-edge capture: these registers vanish when the reader is
            // parked, so everything the load and the step-5 checker need is
            // latched NOW
            s_size            <= found_size;
            s_first           <= found_first_sector;
            chk_first_cluster <= found_cluster;
            chk_cluster_size  <= fs_cluster_size;
            chk_fat0_sector   <= fs_fat0_sector;
            chk_is_fat32      <= fs_is_fat32;
            if (found_size > s_slot_bytes) begin
              // too big for the slot: park before the first outen byte
              // (the reader needs hundreds of cycles to reach READ_A_FILE)
              rd_run      <= 1'b0;
              phase_write <= 1'b1;
              s_state     <= M_FAIL;
            end else begin
              s_pack    <= 24'd0;
              s_bcnt    <= 22'd0;
              s_flushed <= 1'b0;
              s_wptr    <= 4'd0;
              s_rptr    <= 4'd0;
              s_wordcnt <= 19'd0;
              s_outst   <= 1'b0;
              s_state   <= M_LOAD;
            end
          end else if (scan_done || s_wd_hit) begin
            // file not found / unmountable filesystem / stuck
            rd_run      <= 1'b0;
            phase_write <= 1'b1;
            s_state     <= M_FAIL;
          end
        end

        M_LOAD: begin
          if (s_load_done) begin
            s_state <= M_PARK;
          end else if (s_wd_hit) begin
            rd_run      <= 1'b0;
            phase_write <= 1'b1;
            s_state     <= M_FAIL;
          end
        end

        M_PARK: begin
          rd_run      <= 1'b0;   // reader parked until the next open
          phase_write <= 1'b1;   // sd_writer owns the card again
          s_chk_run   <= 1'b0;
          s_state     <= M_CHK;
        end

        M_CHK: begin
`ifdef SDFAT_STORAGE_CHECK
          // contiguity gate (nd_storage_fatchk.v): one start pulse, then
          // wait for the verdict. The checker owns the sd_writer command
          // mux (rd_mode=1) while chk_busy; phase_write is already 1, so
          // the writer owns the SD pins. A fragmented file (or a FAT read
          // error) fails the open; retry with a new open_req.
          if (!s_chk_run) begin
            chk_start <= 1'b1;
            s_chk_run <= 1'b1;
          end else if (chk_done) begin
            s_chk_run <= 1'b0;
            s_state   <= chk_ok ? M_OK : M_FAIL;
          end else if (s_wd_hit) begin
            // backstop only: the checker carries its own watchdog and the
            // sd_writer always terminates via its internal timeouts
            s_chk_run <= 1'b0;
            s_state   <= M_FAIL;
          end
`else
          // feature stripped: pass straight through - the card recipe
          // alone guarantees contiguous files (design section 3)
          s_state <= M_OK;
`endif
        end

        M_OK: begin
          open_ok[cur_client] <= 1'b1;
          r_size[cur_client]  <= s_size;
          r_nblk[cur_client]  <= s_size[26:11] + {15'd0, |s_size[10:0]};
          r_first[cur_client] <= s_first;
          mnt_err             <= 1'b0;
          mnt_done            <= 1'b1;
          st_upd              <= 1'b1;
          st_val              <= 2'd3;  // SD_OK
          s_state             <= M_IDLE;
        end

        M_FAIL: begin
          open_err[cur_client] <= 1'b1;
          mnt_err              <= 1'b1;
          mnt_done             <= 1'b1;
          if (!s_mask_fail) begin
            // mask failures never touched the card: no status update
            st_upd <= 1'b1;
            st_val <= s_nocard ? 2'd1 : 2'd2;  // SD_NOCARD / SD_ERROR
          end
          s_mask_fail <= 1'b0;
          s_state     <= M_IDLE;
        end

        default: s_state <= M_IDLE;
      endcase
    end
  end

endmodule

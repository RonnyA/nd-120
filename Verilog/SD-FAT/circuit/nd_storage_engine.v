/****************************************************************************
** nd_storage block engine: arbiter, client front-ends, CDC word bridge   **
**                                                                         **
** Core of the multi-client storage facade (docs/nd-storage-design.md     **
** section 2.2; binding contract docs/nd-storage-interface-spec.md).      **
** Serves N_CLIENTS client ports (clk_cpu domain) with 2048-byte block    **
** operations against the abstract mem port (clk_stor domain, SDRAM      **
** device region behind the board glue, nds_mem_model.v in sim):          **
**                                                                         **
**   - Round-robin arbiter: per-client pending latches, one request per  **
**     client (no queue), scan starts at ptr+1 and the pointer advances  **
**     past the winner at op completion - starvation impossible.         **
**   - Per-client front-ends (generate, clk_cpu): latch {wr, block} on   **
**     req, flip the request toggle, master the CLIENT's buffer through  **
**     buf_addr/buf_wdata/buf_we (read) and buf_rdata (write: address    **
**     presented in cycle A, one wait cycle for a registered BRAM read,  **
**     data sampled in cycle C - also correct for combinational reads).  **
**   - CDC word bridge: one 16-bit word at a time, toggle handshake in   **
**     each direction via nds_sync.v; data crosses as stable payload.    **
**   - READ path: 512 mem-port reads, each 32-bit word pushed as two     **
**     big-endian client words (word 2m = mem[31:16]).                   **
**   - WRITE path: 1024 words pulled from the client into the 512x32     **
**     staging BRAM, then 4 CMD24 sectors through the sd_writer command  **
**     port (sdw_*), then 512 mem-port writes. Ordering rule: card       **
**     first, SDRAM second, done last - a failed CMD24 leaves the SDRAM  **
**     copy untouched. The staging BRAM is a documented deviation from   **
**     the "nd_storage never stores payload" rationale: one shared 2 KB  **
**     block avoids pulling the client buffer twice over the CDC and     **
**     makes the card-first ordering natural.                            **
**   - Range check: block >= n_blocks[c] answers done+err with ZERO      **
**     mem/SD traffic.                                                   **
**   - Open requests are handed to the mount FSM (mnt_* port,            **
**     nd_storage_mount.v); geometry (n_blocks, first_sector) and the    **
**     open_ok/open_err/size levels are inputs from the mount logic.     **
**                                                                         **
** Step-4 change (the one flagged in docs/nd-storage-design.md for the   **
** step-4 implementer): N_CLIENTS grows to 7 (owner file set TAPE.BPUN,  **
** FLOPPY1/2.IMG, SMD0-3.IMG), so every 2-bit client index (grant,       **
** round-robin pointer, mnt_client, the synced grant id) widened to 3    **
** bits and the slot-base table gained SLOT4..6. No behavior change for  **
** N_CLIENTS <= 4 (the step-2/3 testbenches still pass unmodified).      **
**                                                                         **
** Every wait state carries the WD_MAX watchdog; a timeout ends the op   **
** with done+err and raises the sticky eng_wd_err level (the top folds   **
** it into sd_status = SD_ERROR).                                        **
**                                                                         **
** The W_SEC card phase drives the sdw_* command port (shaped like       **
** sd_writer's start/busy/done/err interface); the sd_writer byte fetch  **
** is served from the staging BRAM through a 2-stage registered read     **
** (word + lane latch, then byte mux) - well inside sd_writer's 8-bit-   **
** tick fetch spacing. Exercised against the real sd_writer + card       **
** model in nd_storage_write_tb.v (sim step 3).                           **
**                                                                         **
** Last reviewed: 11-JUL-2026                                              **
** Ronny Hansen                                                            **
*****************************************************************************/

module nd_storage_engine #(
    parameter         N_CLIENTS      = 4,             // 1..8
    parameter [31:0]  WD_MAX         = 32'd270_000_000,
    parameter [31:0]  SLOT0_BASE_BLK = 32'd0,
    parameter [31:0]  SLOT1_BASE_BLK = 32'd32,
    parameter [31:0]  SLOT2_BASE_BLK = 32'd672,
    parameter [31:0]  SLOT3_BASE_BLK = 32'd1312,
    parameter [31:0]  SLOT4_BASE_BLK = 32'd1472,
    parameter [31:0]  SLOT5_BASE_BLK = 32'd1632,
    parameter [31:0]  SLOT6_BASE_BLK = 32'd1792,
    parameter [31:0]  SLOT7_BASE_BLK = 32'd1920
) (
    input  wire clk_stor,
    input  wire rst_stor_n,
    input  wire clk_cpu,
    input  wire rst_cpu_n,

    // ---- mem port (clk_stor; SDRAM device region / nds_mem_model) ----
    output reg         mem_start,   // 1-cycle pulse, only when mem_busy=0
    output reg         mem_we,
    output reg  [19:0] mem_addr,    // {blk_abs[10:0], word[8:0]}
    output reg  [31:0] mem_wdata,
    input  wire [31:0] mem_rdata,   // valid at mem_done, then held
    input  wire        mem_busy,
    input  wire        mem_done,    // 1-cycle pulse

    // ---- mount handoff (clk_stor; nd_storage_mount in step 4) ----
    output reg         mnt_start,   // 1-cycle pulse per granted open
    output wire [2:0]  mnt_client,  // which client is being opened
    input  wire        mnt_done,    // 1-cycle pulse: mount finished
    input  wire        mnt_err,     // valid with mnt_done

    // ---- per-client geometry / open status from mount (clk_stor) ----
    // quasi-static: stable whenever open_ok_stor[c] is high
    input  wire [N_CLIENTS-1:0]    open_ok_stor,
    input  wire [N_CLIENTS-1:0]    open_err_stor,
    input  wire [N_CLIENTS*32-1:0] size_bytes_stor,
    input  wire [N_CLIENTS*16-1:0] n_blocks,      // ceil(size/2048) per client
    input  wire [N_CLIENTS*32-1:0] first_sector,  // file first SD sector

    // ---- sd_writer command port (clk_stor; wired by the top, step 3) ----
    output reg         sdw_start,
    output reg  [31:0] sdw_sector,
    input  wire        sdw_busy,
    input  wire        sdw_done,
    input  wire        sdw_err,
    input  wire [8:0]  sdw_rd_addr,  // sd_writer byte fetch (2-clk registered)
    output reg  [7:0]  sdw_rd_data,

    // ---- status ----
    output reg eng_wd_err,  // sticky until the next grant: watchdog fired

    // ---- client ports (clk_cpu, flattened per spec section 4) ----
    input  wire [N_CLIENTS-1:0]    open_req,
    output wire [N_CLIENTS-1:0]    open_ok,
    output wire [N_CLIENTS-1:0]    open_err,
    output wire [N_CLIENTS*32-1:0] size_bytes,
    input  wire [N_CLIENTS-1:0]    req,
    input  wire [N_CLIENTS-1:0]    wr,
    input  wire [N_CLIENTS*16-1:0] block,
    output wire [N_CLIENTS-1:0]    busy,
    output wire [N_CLIENTS-1:0]    done,
    output wire [N_CLIENTS-1:0]    err,
    output wire [N_CLIENTS*10-1:0] buf_addr,
    output wire [N_CLIENTS*16-1:0] buf_wdata,
    output wire [N_CLIENTS-1:0]    buf_we,
    input  wire [N_CLIENTS*16-1:0] buf_rdata
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
        3'd6:    slot_base = SLOT6_BASE_BLK;
        default: slot_base = SLOT7_BASE_BLK;
      endcase
    end
  endfunction

  // ------------------------------------------------------------- engine FSM
  localparam [3:0] E_IDLE     = 4'd0;
  localparam [3:0] E_GRANT    = 4'd1;
  localparam [3:0] E_OPEN     = 4'd2;
  localparam [3:0] R_MEM      = 4'd3;
  localparam [3:0] R_WAIT     = 4'd4;
  localparam [3:0] R_PUSH_HI  = 4'd5;
  localparam [3:0] R_PUSH_LO  = 4'd6;
  localparam [3:0] W_PULL     = 4'd7;
  localparam [3:0] W_SEC_GO   = 4'd8;
  localparam [3:0] W_SEC_WAIT = 4'd9;
  localparam [3:0] W_MEM      = 4'd10;
  localparam [3:0] W_MEM_WAIT = 4'd11;
  localparam [3:0] E_DONE     = 4'd12;

  reg [3:0]           s_state;
  reg [2:0]           s_grant;                     // granted client
  reg [2:0]           s_ptr;                       // round-robin pointer
  reg [N_CLIENTS-1:0] s_pend_open;
  reg [N_CLIENTS-1:0] s_pend_blk;
  reg                 s_op_wr    [0:N_CLIENTS-1];  // latched with the request
  reg [15:0]          s_op_block [0:N_CLIENTS-1];
  reg [10:0]          s_blk_abs;                   // slot base + block
  reg [8:0]           s_wcnt;                      // SDRAM word m, 0..511
  reg [9:0]           s_pull_cnt;                  // client word k, 0..1023
  reg [1:0]           s_sec;                       // sector within block
  reg                 s_phase;                     // per-state sub-phase
  reg                 s_err_c;                     // op error, done_tgl payload
  reg [31:0]          s_rdata_lat;                 // mem word being pushed
  reg [15:0]          s_stage_hi;                  // even pull word (high half)

  assign mnt_client = s_grant;

  // ------------------------------------------------------------- word bridge
  // stor -> cpu: toggles + stable data (design section 4.4)
  reg [15:0]          s_bridge_rd_data;  // stable one clk_stor before the flip
  reg                 s_rd_have_tgl;
  reg                 s_wr_want_tgl;
  reg [N_CLIENTS-1:0] s_done_tgl;

  // cpu -> stor answers, per client (only the granted client flips)
  wire [N_CLIENTS-1:0]    fe_open_tgl;
  wire [N_CLIENTS-1:0]    fe_req_tgl;
  wire [N_CLIENTS-1:0]    fe_ack_tgl;
  wire [N_CLIENTS-1:0]    fe_have_tgl;
  wire [N_CLIENTS-1:0]    fe_wr_lat;
  wire [N_CLIENTS*16-1:0] fe_block_lat;
  wire [N_CLIENTS*16-1:0] fe_wrdata;

  // synchronized pulses / levels
  wire [N_CLIENTS-1:0] s_open_pulse;      // clk_stor
  wire [N_CLIENTS-1:0] s_req_pulse;       // clk_stor
  wire [N_CLIENTS-1:0] s_ack_pulse_v;     // clk_stor, per client
  wire [N_CLIENTS-1:0] s_wr_have_pulse_v; // clk_stor, per client
  wire [N_CLIENTS-1:0] c_done_pulse;      // clk_cpu
  wire                 c_rd_have_pulse;   // clk_cpu
  wire                 c_wr_want_pulse;   // clk_cpu
  wire [2:0]           c_grant_sync;      // clk_cpu
  wire                 c_err_sync;        // clk_cpu
  wire [N_CLIENTS-1:0] c_open_ok_sync;    // clk_cpu
  wire [N_CLIENTS-1:0] c_open_err_sync;   // clk_cpu

  // pulse mux by the (stable-during-op) grant: each toggle has its own
  // synchronizer, so a grant change can never manufacture an edge
  wire        s_ack_pulse     = s_ack_pulse_v[s_grant];
  wire        s_wr_have_pulse = s_wr_have_pulse_v[s_grant];
  wire [15:0] s_wr_data_sel   = fe_wrdata[16*s_grant +: 16];

  nds_sync_pulse u_sync_rhave (
      .clk_dst(clk_cpu), .rst_dst_n(rst_cpu_n),
      .tgl_src(s_rd_have_tgl), .pulse_dst(c_rd_have_pulse)
  );
  nds_sync_pulse u_sync_want (
      .clk_dst(clk_cpu), .rst_dst_n(rst_cpu_n),
      .tgl_src(s_wr_want_tgl), .pulse_dst(c_wr_want_pulse)
  );
  nds_sync_level #(.WIDTH(3)) u_sync_grant (
      .clk_dst(clk_cpu), .rst_dst_n(rst_cpu_n),
      .d_src(s_grant), .q_dst(c_grant_sync)
  );
  nds_sync_level #(.WIDTH(1)) u_sync_err (
      .clk_dst(clk_cpu), .rst_dst_n(rst_cpu_n),
      .d_src(s_err_c), .q_dst(c_err_sync)
  );
  nds_sync_level #(.WIDTH(N_CLIENTS)) u_sync_ok (
      .clk_dst(clk_cpu), .rst_dst_n(rst_cpu_n),
      .d_src(open_ok_stor), .q_dst(c_open_ok_sync)
  );
  nds_sync_level #(.WIDTH(N_CLIENTS)) u_sync_oerr (
      .clk_dst(clk_cpu), .rst_dst_n(rst_cpu_n),
      .d_src(open_err_stor), .q_dst(c_open_err_sync)
  );

  assign open_ok  = c_open_ok_sync;
  assign open_err = c_open_err_sync;

  // ------------------------------------------------------------- arbiter scan
  // first pending client at ptr+1, ptr+2, ... ptr (mod N_CLIENTS)
  reg       s_scan_v;
  reg [2:0] s_scan_id;
  reg [3:0] s_scan_t;
  integer k;
  always @(*) begin
    s_scan_v  = 1'b0;
    s_scan_id = 3'd0;
    s_scan_t  = 4'd0;
    for (k = 1; k <= N_CLIENTS; k = k + 1) begin
      s_scan_t = {1'b0, s_ptr} + k[3:0];
      if (s_scan_t >= N_CLIENTS[3:0]) s_scan_t = s_scan_t - N_CLIENTS[3:0];
      if (!s_scan_v && (s_pend_open[s_scan_t[2:0]] || s_pend_blk[s_scan_t[2:0]])) begin
        s_scan_v  = 1'b1;
        s_scan_id = s_scan_t[2:0];
      end
    end
  end

  wire [31:0] s_slot_base_g = slot_base(s_grant);

  // ------------------------------------------------------------- watchdog
  reg [3:0]  s_state_q;
  reg [31:0] s_wd;
  always @(posedge clk_stor) begin
    if (!rst_stor_n) begin
      s_state_q <= E_IDLE;
      s_wd      <= 32'd0;
    end else begin
      s_state_q <= s_state;
      if (s_state != s_state_q || s_state == E_IDLE) s_wd <= 32'd0;
      else s_wd <= s_wd + 32'd1;
    end
  end
  wire s_wd_hit = (s_wd >= WD_MAX);

  // ------------------------------------------------------------- staging BRAM
  // 512 x 32, write side fed by W_PULL, read side shared between the
  // sd_writer byte fetch (W_SEC phase) and the W_MEM writeback
  reg [31:0] s_staging [0:511];
  reg [31:0] s_stg_rdata;
  reg [1:0]  s_sdw_lane;

  wire       s_stg_we    = (s_state == W_PULL) && s_phase && s_wr_have_pulse
                           && s_pull_cnt[0];
  wire [8:0] s_stg_waddr = s_pull_cnt[9:1];
  wire [31:0] s_stg_wdata = {s_stage_hi, s_wr_data_sel};
  wire [8:0] s_stg_raddr = (s_state == W_MEM || s_state == W_MEM_WAIT)
                           ? s_wcnt
                           : {s_sec, sdw_rd_addr[8:2]};

  always @(posedge clk_stor) begin
    if (s_stg_we) s_staging[s_stg_waddr] <= s_stg_wdata;
    // stage 1: word + byte lane
    s_stg_rdata <= s_staging[s_stg_raddr];
    s_sdw_lane  <= sdw_rd_addr[1:0];
    // stage 2: byte mux (byte 4m of SDRAM word m is dq[31:24])
    case (s_sdw_lane)
      2'd0: sdw_rd_data <= s_stg_rdata[31:24];
      2'd1: sdw_rd_data <= s_stg_rdata[23:16];
      2'd2: sdw_rd_data <= s_stg_rdata[15:8];
      2'd3: sdw_rd_data <= s_stg_rdata[7:0];
    endcase
  end

  // ------------------------------------------------------------- engine
  integer i;
  always @(posedge clk_stor) begin
    if (!rst_stor_n) begin
      s_state          <= E_IDLE;
      s_grant          <= 3'd0;
      // client 0 scanned first. The truncation is SAFE here and only here:
      // at N_CLIENTS==8, N_CLIENTS[2:0] is 3'b000 and 0-1 wraps to 7, which
      // still makes client 0 the next one scanned. Do not copy this pattern -
      // the same truncation in nd_storage_mount's range guard would break
      // mounting outright, which is why that one compares at full width.
      s_ptr            <= N_CLIENTS[2:0] - 3'd1;
      s_pend_open      <= {N_CLIENTS{1'b0}};
      s_pend_blk       <= {N_CLIENTS{1'b0}};
      s_blk_abs        <= 11'd0;
      s_wcnt           <= 9'd0;
      s_pull_cnt       <= 10'd0;
      s_sec            <= 2'd0;
      s_phase          <= 1'b0;
      s_err_c          <= 1'b0;
      s_rdata_lat      <= 32'd0;
      s_stage_hi       <= 16'd0;
      s_bridge_rd_data <= 16'd0;
      s_rd_have_tgl    <= 1'b0;
      s_wr_want_tgl    <= 1'b0;
      s_done_tgl       <= {N_CLIENTS{1'b0}};
      mem_start        <= 1'b0;
      mem_we           <= 1'b0;
      mem_addr         <= 20'd0;
      mem_wdata        <= 32'd0;
      mnt_start        <= 1'b0;
      sdw_start        <= 1'b0;
      sdw_sector       <= 32'd0;
      eng_wd_err       <= 1'b0;
      for (i = 0; i < N_CLIENTS; i = i + 1) begin
        s_op_wr[i]    <= 1'b0;
        s_op_block[i] <= 16'd0;
      end
    end else begin
      mem_start <= 1'b0;
      mnt_start <= 1'b0;
      sdw_start <= 1'b0;

      // pending latches: set on the synced request toggles, cleared at op
      // end (a client is busy until done, so set and clear never collide)
      for (i = 0; i < N_CLIENTS; i = i + 1) begin
        if (s_open_pulse[i]) s_pend_open[i] <= 1'b1;
        if (s_req_pulse[i]) begin
          s_pend_blk[i] <= 1'b1;
          s_op_wr[i]    <= fe_wr_lat[i];
          s_op_block[i] <= fe_block_lat[16*i +: 16];
        end
      end

      case (s_state)
        E_IDLE: begin
          s_phase <= 1'b0;
          if (s_scan_v) begin
            s_grant <= s_scan_id;
            s_state <= E_GRANT;
          end
        end

        E_GRANT: begin
          s_blk_abs  <= s_slot_base_g[10:0] + s_op_block[s_grant][10:0];
          s_wcnt     <= 9'd0;
          s_pull_cnt <= 10'd0;
          s_sec      <= 2'd0;
          s_phase    <= 1'b0;
          eng_wd_err <= 1'b0;
          if (s_pend_open[s_grant]) begin
            s_err_c <= 1'b0;
            s_state <= E_OPEN;
          end else if (s_op_block[s_grant] >= n_blocks[16*s_grant +: 16]) begin
            // out of range: done+err with ZERO mem/SD traffic
            s_err_c <= 1'b1;
            s_state <= E_DONE;
          end else begin
            s_err_c <= 1'b0;
            s_state <= s_op_wr[s_grant] ? W_PULL : R_MEM;
          end
        end

        // ---- open: hand to the mount FSM --------------------------------
        E_OPEN: begin
          if (!s_phase) begin
            mnt_start <= 1'b1;
            s_phase   <= 1'b1;
          end else if (mnt_done) begin
            s_err_c <= mnt_err;
            s_phase <= 1'b0;
            s_state <= E_DONE;
          end else if (s_wd_hit) begin
            s_err_c    <= 1'b1;
            eng_wd_err <= 1'b1;
            s_phase    <= 1'b0;
            s_state    <= E_DONE;
          end
        end

        // ---- block read: SDRAM word -> two client words ------------------
        R_MEM: begin
          if (!mem_busy) begin
            mem_start <= 1'b1;
            mem_we    <= 1'b0;
            mem_addr  <= {s_blk_abs, s_wcnt};
            s_state   <= R_WAIT;
          end else if (s_wd_hit) begin
            s_err_c    <= 1'b1;
            eng_wd_err <= 1'b1;
            s_state    <= E_DONE;
          end
        end

        R_WAIT: begin
          if (mem_done) begin
            s_rdata_lat      <= mem_rdata;
            s_bridge_rd_data <= mem_rdata[31:16];  // client word 2m first
            s_phase          <= 1'b0;
            s_state          <= R_PUSH_HI;
          end else if (s_wd_hit) begin
            s_err_c    <= 1'b1;
            eng_wd_err <= 1'b1;
            s_state    <= E_DONE;
          end
        end

        R_PUSH_HI: begin
          if (!s_phase) begin
            // data was set one clk_stor earlier - flip now
            s_rd_have_tgl <= ~s_rd_have_tgl;
            s_phase       <= 1'b1;
          end else if (s_ack_pulse) begin
            s_bridge_rd_data <= s_rdata_lat[15:0];  // client word 2m+1
            s_phase          <= 1'b0;
            s_state          <= R_PUSH_LO;
          end else if (s_wd_hit) begin
            s_err_c    <= 1'b1;
            eng_wd_err <= 1'b1;
            s_phase    <= 1'b0;
            s_state    <= E_DONE;
          end
        end

        R_PUSH_LO: begin
          if (!s_phase) begin
            s_rd_have_tgl <= ~s_rd_have_tgl;
            s_phase       <= 1'b1;
          end else if (s_ack_pulse) begin
            s_phase <= 1'b0;
            if (s_wcnt == 9'd511) s_state <= E_DONE;
            else begin
              s_wcnt  <= s_wcnt + 9'd1;
              s_state <= R_MEM;
            end
          end else if (s_wd_hit) begin
            s_err_c    <= 1'b1;
            eng_wd_err <= 1'b1;
            s_phase    <= 1'b0;
            s_state    <= E_DONE;
          end
        end

        // ---- block write phase 1: pull 1024 words into staging ----------
        W_PULL: begin
          if (!s_phase) begin
            s_wr_want_tgl <= ~s_wr_want_tgl;
            s_phase       <= 1'b1;
          end else if (s_wr_have_pulse) begin
            s_phase <= 1'b0;
            if (!s_pull_cnt[0]) s_stage_hi <= s_wr_data_sel;  // even word: high half
            // odd word: staging write via s_stg_we (this cycle)
            if (s_pull_cnt == 10'd1023) s_state <= W_SEC_GO;
            else s_pull_cnt <= s_pull_cnt + 10'd1;
          end else if (s_wd_hit) begin
            s_err_c    <= 1'b1;
            eng_wd_err <= 1'b1;
            s_phase    <= 1'b0;
            s_state    <= E_DONE;
          end
        end

        // ---- block write phase 2: 4 CMD24 sectors (card FIRST) ----------
        W_SEC_GO: begin
          if (!sdw_busy) begin
            sdw_start  <= 1'b1;
            sdw_sector <= first_sector[32*s_grant +: 32]
                          + {14'd0, s_op_block[s_grant], 2'b00}
                          + {30'd0, s_sec};
            s_state    <= W_SEC_WAIT;
          end else if (s_wd_hit) begin
            s_err_c    <= 1'b1;
            eng_wd_err <= 1'b1;
            s_state    <= E_DONE;
          end
        end

        W_SEC_WAIT: begin
          if (sdw_err) begin
            s_err_c <= 1'b1;   // card failed: SDRAM copy stays untouched
            s_state <= E_DONE;
          end else if (sdw_done) begin
            if (s_sec == 2'd3) begin
              s_wcnt  <= 9'd0;
              s_phase <= 1'b0;
              s_state <= W_MEM;
            end else begin
              s_sec   <= s_sec + 2'd1;
              s_state <= W_SEC_GO;
            end
          end else if (s_wd_hit) begin
            s_err_c    <= 1'b1;
            eng_wd_err <= 1'b1;
            s_state    <= E_DONE;
          end
        end

        // ---- block write phase 3: staging -> SDRAM (then done) ----------
        W_MEM: begin
          if (!s_phase) begin
            s_phase <= 1'b1;   // one cycle for the registered staging read
          end else if (!mem_busy) begin
            mem_start <= 1'b1;
            mem_we    <= 1'b1;
            mem_addr  <= {s_blk_abs, s_wcnt};
            mem_wdata <= s_stg_rdata;
            s_phase   <= 1'b0;
            s_state   <= W_MEM_WAIT;
          end else if (s_wd_hit) begin
            s_err_c    <= 1'b1;
            eng_wd_err <= 1'b1;
            s_phase    <= 1'b0;
            s_state    <= E_DONE;
          end
        end

        W_MEM_WAIT: begin
          if (mem_done) begin
            if (s_wcnt == 9'd511) s_state <= E_DONE;
            else begin
              s_wcnt  <= s_wcnt + 9'd1;
              s_state <= W_MEM;
            end
          end else if (s_wd_hit) begin
            s_err_c    <= 1'b1;
            eng_wd_err <= 1'b1;
            s_state    <= E_DONE;
          end
        end

        // ---- completion --------------------------------------------------
        E_DONE: begin
          if (!s_phase) begin
            s_phase <= 1'b1;   // err level settles >= 2 clk_stor before flip
          end else begin
            s_done_tgl[s_grant]  <= ~s_done_tgl[s_grant];
            s_pend_open[s_grant] <= 1'b0;
            s_pend_blk[s_grant]  <= 1'b0;
            s_ptr                <= s_grant;  // advance past the winner
            s_phase              <= 1'b0;
            s_state              <= E_IDLE;
          end
        end

        default: s_state <= E_IDLE;
      endcase
    end
  end

  // ------------------------------------------------------------- front-ends
  genvar gc;
  generate
    for (gc = 0; gc < N_CLIENTS; gc = gc + 1) begin : g_fe

      // request toggles into clk_stor
      nds_sync_pulse u_sync_open (
          .clk_dst(clk_stor), .rst_dst_n(rst_stor_n),
          .tgl_src(fe_open_tgl[gc]), .pulse_dst(s_open_pulse[gc])
      );
      nds_sync_pulse u_sync_req (
          .clk_dst(clk_stor), .rst_dst_n(rst_stor_n),
          .tgl_src(fe_req_tgl[gc]), .pulse_dst(s_req_pulse[gc])
      );
      // bridge answers into clk_stor (one synchronizer per toggle: a
      // grant change can never manufacture an edge)
      nds_sync_pulse u_sync_ack (
          .clk_dst(clk_stor), .rst_dst_n(rst_stor_n),
          .tgl_src(fe_ack_tgl[gc]), .pulse_dst(s_ack_pulse_v[gc])
      );
      nds_sync_pulse u_sync_whave (
          .clk_dst(clk_stor), .rst_dst_n(rst_stor_n),
          .tgl_src(fe_have_tgl[gc]), .pulse_dst(s_wr_have_pulse_v[gc])
      );
      // completion into clk_cpu
      nds_sync_pulse u_sync_done (
          .clk_dst(clk_cpu), .rst_dst_n(rst_cpu_n),
          .tgl_src(s_done_tgl[gc]), .pulse_dst(c_done_pulse[gc])
      );

      reg        r_busy;
      reg        r_open_tgl;
      reg        r_req_tgl;
      reg        r_ack_tgl;
      reg        r_have_tgl;
      reg        r_wr;
      reg [15:0] r_block;
      reg [9:0]  r_cnt;
      reg [15:0] r_wrdata;
      reg [1:0]  r_wrphase;
      reg        r_err;
      reg        r_done;
      reg [9:0]  r_buf_addr;
      reg [15:0] r_buf_wdata;
      reg        r_buf_we;
      reg        r_ok_q;
      reg [31:0] r_size;

      always @(posedge clk_cpu) begin
        if (!rst_cpu_n) begin
          r_busy      <= 1'b0;
          r_open_tgl  <= 1'b0;
          r_req_tgl   <= 1'b0;
          r_ack_tgl   <= 1'b0;
          r_have_tgl  <= 1'b0;
          r_wr        <= 1'b0;
          r_block     <= 16'd0;
          r_cnt       <= 10'd0;
          r_wrdata    <= 16'd0;
          r_wrphase   <= 2'd0;
          r_err       <= 1'b0;
          r_done      <= 1'b0;
          r_buf_addr  <= 10'd0;
          r_buf_wdata <= 16'd0;
          r_buf_we    <= 1'b0;
          r_ok_q      <= 1'b0;
          r_size      <= 32'd0;
        end else begin
          r_done   <= 1'b0;
          r_buf_we <= 1'b0;

          // size_bytes is stable long before open_ok rises (mount rule)
          r_ok_q <= c_open_ok_sync[gc];
          if (c_open_ok_sync[gc] && !r_ok_q)
            r_size <= size_bytes_stor[32*gc +: 32];

          // requests: req while busy (or without open_ok) is silently lost
          if (open_req[gc] && !r_busy) begin
            r_busy     <= 1'b1;
            r_open_tgl <= ~r_open_tgl;
          end else if (req[gc] && !r_busy && c_open_ok_sync[gc]) begin
            r_busy    <= 1'b1;
            r_wr      <= wr[gc];
            r_block   <= block[16*gc +: 16];
            r_req_tgl <= ~r_req_tgl;
          end

          // read stream: block data into the client's buffer
          if (r_busy && !r_wr && c_rd_have_pulse && (c_grant_sync == gc[2:0])) begin
            r_buf_addr  <= r_cnt;
            r_buf_wdata <= s_bridge_rd_data;  // stable while the flip crosses
            r_buf_we    <= 1'b1;
            r_cnt       <= r_cnt + 10'd1;
            r_ack_tgl   <= ~r_ack_tgl;
          end

          // write stream: present the address (cycle A), give a registered
          // BRAM one cycle to fetch (cycle B: addr committed at the end of
          // A is clocked by the BRAM at the end of B), sample and answer on
          // cycle C - correct for registered BRAMs and for the floppy's
          // combinational dbuf_rdata alike (the address is held, so a
          // combinational read is simply valid early)
          if (r_busy && r_wr && c_wr_want_pulse && (c_grant_sync == gc[2:0])) begin
            r_buf_addr <= r_cnt;               // cycle A
            r_wrphase  <= 2'd1;
          end else if (r_wrphase == 2'd1) begin
            r_wrphase  <= 2'd2;                // cycle B: BRAM read commits
          end else if (r_wrphase == 2'd2) begin
            r_wrdata   <= buf_rdata[16*gc +: 16];  // cycle C
            r_have_tgl <= ~r_have_tgl;
            r_cnt      <= r_cnt + 10'd1;
            r_wrphase  <= 2'd0;
          end

          // completion: err rides the done_tgl flip as a settled level
          if (c_done_pulse[gc]) begin
            r_err     <= c_err_sync;
            r_done    <= 1'b1;
            r_busy    <= 1'b0;
            r_cnt     <= 10'd0;
            r_wrphase <= 2'd0;
          end
        end
      end

      assign fe_open_tgl[gc]           = r_open_tgl;
      assign fe_req_tgl[gc]            = r_req_tgl;
      assign fe_ack_tgl[gc]            = r_ack_tgl;
      assign fe_have_tgl[gc]           = r_have_tgl;
      assign fe_wr_lat[gc]             = r_wr;
      assign fe_block_lat[16*gc +: 16] = r_block;
      assign fe_wrdata[16*gc +: 16]    = r_wrdata;

      assign busy[gc]                = r_busy;
      assign done[gc]                = r_done;
      assign err[gc]                 = r_err;
      assign buf_addr[10*gc +: 10]   = r_buf_addr;
      assign buf_wdata[16*gc +: 16]  = r_buf_wdata;
      assign buf_we[gc]              = r_buf_we;
      assign size_bytes[32*gc +: 32] = r_size;
    end
  endgenerate

endmodule

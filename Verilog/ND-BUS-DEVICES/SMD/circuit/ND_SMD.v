/**************************************************************************
** ND SMD DISC CONTROLLER, 15 MHz (ND632 / PCB 3043+3044), DMA           **
**                                                                       **
** Register core made 1:1 faithful to the AUTHORITATIVE C# oracle        **
**   RetroCore/Emulated.HW/ND/CPU/NDBUS/NDBusDiscControllerSMD.cs        **
** and its proven, host-gated C port                                     **
**   ND-BUS-DEVICES/portable/src/nd_smd.c  (nd_smd_*).                    **
** Where a behaviour is a documented DIVERGENCE in the C port, this RTL   **
** follows the same choice; those are marked "DIVERGENCE:" below.        **
**                                                                       **
** This is the 15 MHz card: it HAS the address/word-count FLIP-FLOPS, so  **
** the 24-bit Core Address and Word Count registers are each loaded by    **
** TWO writes (HI 8 bits, then LO 16) and read back LO then HI. Control-  **
** word bits 5-6 (address 16-17) belong to the OLD 10 MHz card and are    **
** IGNORED here, exactly as the oracle ignores them.                      **
**                                                                       **
** UNLIKE the floppy card there is NO command block in ND memory. The     **
** guest loads the transfer parameters into controller registers by IOX   **
** writes, then a GO (control word +5, bit 2 = active). ExecuteGO         **
** converts C/H/S -> LBA, bounds-checks the address, and moves the data.  **
**                                                                       **
** Register map (offset from base, ALL multiplexed by CWR = control       **
** word bit 15, mirrored in status bit 15):                              **
**   +0 R  Core Address (CWR=0) / Word Counter (CWR=1)  [LO then HI]      **
**   +1 W  Load Core Address (CWR=0, HI then LO) / count-mem (CWR=1)      **
**   +2 R  Seek Condition (CWR=0) / ECC Count (CWR=1)                     **
**   +3 W  Load Block Address I (CWR=0) / II (CWR=1)                      **
**   +4 R  Status (CWR=0, READING IT RESETS THE FLIP-FLOPS) / ECC Pattern **
**   +5 W  Load Control Word (GO / opcode)                               **
**   +6 R  Read Block Address I (CWR=0) / II (CWR=1)                      **
**   +7 W  Load Word Counter (CWR=0, HI then LO) / Load ECC Control (CWR=1)**
**                                                                       **
** Control word (+5): b0 int-enable (on NOT active), b1 error-int enable, **
**   b2 ACTIVE (GO), b3 test mode, b4 device clear, b5-6 addr16/17 (old   **
**   card, ignored), b7-9 unit select, b10 marginal recovery, b11-14      **
**   device operation (M0..M9), b15 register multiplex (CWR).            **
**                                                                       **
** Status (+4, CWR=0), oracle ReadStatusRegister():                      **
**   b0 int-enabled     b1 error-int-enabled   b2 active                 **
**   b3 ready-for-xfer  b4 inclusive-OR error  b5 illegal load           **
**   b6 timeout         b7 hardware error 2    b8 address mismatch        **
**   b10 comparer error b13 disk unit NOT ready (FORCED 1 when no unit    **
**   selected)          b14 on cylinder        b15 register multiplex.    **
**   Inclusive-OR (b4) = OR(illegal, timeout, hwErr2, addrMismatch,       **
**   comparerErr, seekErr) - the UNION taken by the C port so neither     **
**   reference's "error present" expectation is lost.                    **
**                                                                       **
** Seek condition (+2, CWR=0): b0-7 seek-complete (one per unit), b8-10   **
**   unit selected, b11 seek error (only M7 clears it), b12 = 1 (15 MHz   **
**   card id, SINTRAN uses it to tell the 15 MHz card from the NORD-10).  **
**                                                                       **
** Interrupt (level 11) is a LATCHED line driven at the oracle's exact    **
** SetInterruptBit() events: raised on completion iff int-enable is set   **
** (ReadEnd), raised on error iff error-int-enable is set (HandleError),  **
** re-evaluated on a non-GO control word, dropped when int-enable is      **
** cleared, and cleared on IDENT (which also clears int-enable).          **
**                                                                       **
** HARDWARE-CONSTRAINED DIVERGENCE (the only structural gap vs the        **
** oracle): the oracle's ExecuteGO pre-checks that the unit is ATTACHED   **
** and (for writes) not WRITE-PROTECTED using media metadata. This RTL    **
** controller has no such backend metadata port, so those two faults are  **
** surfaced the hardware way instead - the disk/DMA backend raises        **
** disk_err_in / dma_err during the transfer, which this core turns into  **
** the same HandleError (disk-unit-not-ready + error interrupt). The      **
** address-mismatch bound (b8) IS pre-checked, against the geometry given **
** by the GEO_* parameters (default = the 75 MB disk the C# oracle fixes  **
** every unit to). A backend that owns a different geometry should pass   **
** matching GEO_* parameters.                                            **
**                                                                       **
** BOOT MODE ('1540&'): the device-agnostic microcode mass-storage        **
** loader (writes +3 bit 2, polls +2 ready, reads +0) is answered from    **
** reset until the FIRST Load Control Word - preserved BYTE-FOR-BYTE from **
** the silicon-validated implementation; it is not part of the oracle.    **
**                                                                       **
** Thumbwheels (all level 11): tw0 01540/017, tw1 01550/020,             **
**   tw2 00540/023, tw3 00550/006 (octal). This instance = tw0 defaults.  **
**                                                                       **
** Last reviewed: 23-JUL-2026                                            **
** Ronny Hansen                                                          **
***************************************************************************/

module ND_SMD #(
    parameter [15:0] BASE_ADDR   = 16'o001540,
    parameter [15:0] IDENT_CODE  = 16'o000017,
    parameter [3:0]  INT_LEVEL   = 4'd11,
    parameter [15:0] DELAY_TICKS = 16'd10,  // nd100x IODELAY_HDD_SMD
    // Geometry for the ExecuteGO address-mismatch bound. Default = the
    // 75 MB SMD disk (5 heads, 18 sectors/track, 823 cylinders), which is
    // the geometry the C# oracle fixes every unit to. 1024-byte sectors.
    parameter [15:0] GEO_HEADS   = 16'd5,
    parameter [15:0] GEO_SPT     = 16'd18,
    parameter [15:0] GEO_MAX_CYL = 16'd823
) (
    input wire sysclk,
    input wire sys_rst_n,

    // Device bus (from ND_BUS_SLAVE) - IOX slave side
    input  wire [15:0] iox_addr,
    input  wire        iox_wr,
    input  wire [15:0] iox_wdata,
    input  wire        iox_rd,
    output reg  [15:0] iox_rdata,
    output wire [3:0]  int_pending,
    input  wire        ident_strobe,
    input  wire [3:0]  ident_level,
    input  wire        ident_grant_in,
    output wire        ident_grant_out,
    output wire        ident_hit,
    output wire [15:0] ident_code,

    // DMA master client port (to ND_DMA_MASTER)
    output reg         dma_req,
    output reg         dma_wr,
    output reg  [23:0] dma_addr,
    output reg  [15:0] dma_wdata,
    input  wire [15:0] dma_rdata,
    input  wire        dma_ack,
    input  wire        dma_err,
    input  wire        dma_busy,

    // Disk backend: chunk transfers through the internal buffer.
    output reg         disk_start,
    output reg         disk_req,
    output reg         disk_wr,
    output wire [15:0] disk_blkaddr1,  // block address I (head/sector)
    output wire [15:0] disk_blkaddr2,  // block address II (cylinder)
    output wire [2:0]  disk_unit,
    output wire [10:0] disk_wordcount, // words in the current chunk
    input  wire        disk_done,
    input  wire        disk_err_in,
    input  wire [9:0]  dbuf_addr,
    input  wire [15:0] dbuf_wdata,
    input  wire        dbuf_we,
    output reg  [15:0] dbuf_rdata
);

  localparam [10:0] BUF_WORDS = 11'd1024;

  // ---- controller registers (oracle ControllerRegs) ----
  reg [15:0] s_core_addr;     // core address bits 0-15   (LO)
  reg [7:0]  s_core_addr_hi;  // core address bits 16-23  (HI)
  reg [15:0] s_word_cnt;      // word counter bits 0-15   (LO)
  reg [7:0]  s_word_cnt_hi;   // word counter bits 16-23  (HI)
  reg [15:0] s_blkaddr1;      // block address I  (head b8-15, sector b0-7)
  reg [15:0] s_blkaddr2;      // block address II (cylinder)
  reg [15:0] s_ecc_count;     // ECC count register (bit0 of ECC control resets it)

  // ---- unit selection + per-unit state ----
  reg [2:0]  s_sel_unit;      // raw unit from control word bits 7-9
  reg        s_disk_selected; // a unit 0..3 is selected
  reg [7:0]  s_on_cyl;        // per-unit on-cylinder     (status b14)
  reg [7:0]  s_not_ready;     // per-unit disk-not-ready  (status b13)
  reg [7:0]  s_seek_complete; // seek-condition b0-7 (one per unit)

  // ---- status flags ----
  reg        s_cwr;           // register multiplex bit (control b15)
  reg        s_int_en;        // control b0
  reg        s_errint_en;     // control b1
  reg        s_active;        // status b2
  reg        s_rft;           // status b3 - ready for transfer
  reg        s_test_mode;     // control b3
  reg        s_marginal;      // control b10
  reg        s_illegal;       // status b5
  reg        s_time_out;      // status b6 (never set in this port, kept for parity)
  reg        s_hw_err2;       // status b7
  reg        s_addr_mismatch; // status b8
  reg        s_comparer_err;  // status b10
  reg        s_seek_err;      // seek-condition b11

  // ---- flip-flops (15 MHz card: two-word HI/LO loads, cleared by a
  //      status read or a device clear) ----
  reg        s_maw_ff;        // core-address WRITE flip-flop
  reg        s_mar_ff;        // core-address READ  flip-flop
  reg        s_wcw_ff;        // word-counter WRITE flip-flop
  reg        s_wcr_ff;        // word-counter READ  flip-flop
  reg        s_wc_eccw_ff;    // ECC-control  WRITE flip-flop

  reg        s_irq;           // latched level-11 interrupt line

  // ---- boot mode (not in the oracle; preserved verbatim) ----
  reg        s_boot_mode;
  reg        s_boot_fetch;
  reg        s_boot_loaded;
  reg [10:0] s_bootptr;

  assign disk_blkaddr1 = s_blkaddr1;
  assign disk_blkaddr2 = s_blkaddr2;
  assign disk_unit     = s_sel_unit;

  // ---- internal buffer ----
  reg [15:0] s_buffer[0:1023];
  always @(*) dbuf_rdata = s_buffer[dbuf_addr];

  // ---- decode ----
  wire s_addressed = (iox_addr[15:3] == BASE_ADDR[15:3]);
  wire [2:0] s_reg = iox_addr[2:0];
  wire s_wr_here = iox_wr && s_addressed;
  wire s_rd_here = iox_rd && s_addressed;

  // ---- status / seek / ECC assembly (oracle ReadStatusRegister etc.) ----
  wire s_incl_or = s_illegal | s_time_out | s_hw_err2 |
                   s_addr_mismatch | s_comparer_err | s_seek_err;

  // disk-unit-not-ready is FORCED 1 when no unit is selected.
  wire s_oncyl_bit    = s_disk_selected ? s_on_cyl[s_sel_unit]    : 1'b0;
  wire s_notready_bit = s_disk_selected ? s_not_ready[s_sel_unit] : 1'b1;

  wire [15:0] s_status =
      { s_cwr,            // b15 register multiplex
        s_oncyl_bit,      // b14 on cylinder
        s_notready_bit,   // b13 disk unit not ready
        1'b0,             // b12
        1'b0,             // b11
        s_comparer_err,   // b10 comparer error
        1'b0,             // b9
        s_addr_mismatch,  // b8  address mismatch
        s_hw_err2,        // b7  hardware error 2
        s_time_out,       // b6  timeout
        s_illegal,        // b5  illegal load
        s_incl_or,        // b4  inclusive-OR error
        s_rft,            // b3  ready for transfer
        s_active,         // b2  active
        s_errint_en,      // b1  error-interrupt enabled
        s_int_en };       // b0  interrupt enabled

  wire [15:0] s_seek_cond =
      { 3'b000,           // b15-13 address field / ECC parity / ECC correctable
        1'b1,             // b12    isSMD15Mhz (always 1)
        s_seek_err,       // b11    seek error
        s_sel_unit,       // b10-8  unit selected
        s_seek_complete };// b7-0   seek complete per unit

  // ECC pattern (read +4, CWR=1): bits 11-13 = 1, bit 15 = CWR read-back.
  wire [15:0] s_ecc_pattern = { s_cwr, 1'b0, 3'b111, 11'd0 };

  // ---- interrupt / ident (latched line) ----
  assign int_pending = {(INT_LEVEL == 4'd13) && s_irq,
                        (INT_LEVEL == 4'd12) && s_irq,
                        (INT_LEVEL == 4'd11) && s_irq,
                        (INT_LEVEL == 4'd10) && s_irq};
  wire s_ident_answer = ident_strobe && ident_grant_in &&
                        (ident_level == INT_LEVEL) && s_irq;
  assign ident_hit       = s_ident_answer;
  assign ident_code      = s_ident_answer ? IDENT_CODE : 16'd0;
  assign ident_grant_out = ident_grant_in && !s_ident_answer;

  // ---- IOX read mux (CWR-multiplexed; boot mode overrides) ----
  always @(*) begin
    iox_rdata = 16'd0;
    if (s_rd_here) begin
      if (s_boot_mode) begin
        case (s_reg)
          3'd0: iox_rdata = s_buffer[s_bootptr[9:0]];
          3'd2: iox_rdata = {11'd0, s_incl_or, s_rft, 3'd0};
          default: iox_rdata = 16'd0;
        endcase
      end else if (!s_disk_selected) begin
        // oracle Read(): returns 0 while no unit is selected
        iox_rdata = 16'd0;
      end else begin
        case (s_reg)
          3'd0: iox_rdata = s_cwr
                          ? (s_wcr_ff ? {8'd0, s_word_cnt_hi}   : s_word_cnt)
                          : (s_mar_ff ? {8'd0, s_core_addr_hi}  : s_core_addr);
          3'd2: iox_rdata = s_cwr ? s_ecc_count : s_seek_cond;
          3'd4: iox_rdata = s_cwr ? s_ecc_pattern : s_status;
          3'd6: iox_rdata = s_cwr ? s_blkaddr2 : s_blkaddr1;
          default: iox_rdata = 16'd0;
        endcase
      end
    end
  end

  // ---- transfer engine ----
  localparam E_IDLE    = 3'd0;
  localparam E_DISK_RD = 3'd1;  // backend: image chunk -> buffer
  localparam E_MEM_WR  = 3'd2;  // DMA: buffer -> ND memory
  localparam E_MEM_RD  = 3'd3;  // DMA: ND memory -> buffer
  localparam E_DISK_WR = 3'd4;  // backend: buffer -> image chunk
  localparam E_DELAY   = 3'd5;  // completion delay -> ReadEnd

  reg [2:0]  s_eng;
  reg [10:0] s_chunk_q;
  reg [10:0] s_sec_idx;
  reg [15:0] s_delay_cnt;
  reg        s_dma_wait;
  reg [23:0] s_mem_addr;      // running ND word address
  reg [23:0] s_words_left;    // words still to move
  reg [2:0]  s_unit;          // selected drive for this command

  assign disk_wordcount = s_chunk_q;

  // CHS -> LBA (oracle smd_chs_to_lba: uses S as-is; all-zero C/H/S -> 0).
  function [31:0] chs2lba;
    input [15:0] cyl;
    input [7:0]  head;
    input [7:0]  sector;
    begin
      if (cyl == 16'd0 && head == 8'd0 && sector == 8'd0)
        chs2lba = 32'd0;
      else
        chs2lba = (({16'd0, cyl} * {16'd0, GEO_HEADS}) + {24'd0, head})
                  * {16'd0, GEO_SPT} + {24'd0, sector};
    end
  endfunction

  // GO-time address decode (registers are stable outside a control write).
  wire [7:0]  w_head    = s_blkaddr1[15:8];
  wire [7:0]  w_sector  = s_blkaddr1[7:0];
  wire [15:0] w_cyl     = s_blkaddr2;
  wire [31:0] w_lba     = chs2lba(w_cyl, w_head, w_sector);
  wire [31:0] w_max_lba = chs2lba(GEO_MAX_CYL[15:0], GEO_HEADS[7:0], GEO_SPT[7:0]);
  wire [23:0] w_words   = {s_word_cnt_hi, s_word_cnt};

  task dma_issue(input wr, input [23:0] a, input [15:0] d);
    begin
      dma_req    <= 1'b1;
      dma_wr     <= wr;
      dma_addr   <= a;
      dma_wdata  <= d;
      s_dma_wait <= 1'b1;
    end
  endtask

  // ClearFlipFlops (oracle).
  task clr_ff;
    begin
      s_maw_ff     <= 1'b0;
      s_mar_ff     <= 1'b0;
      s_wcw_ff     <= 1'b0;
      s_wcr_ff     <= 1'b0;
      s_wc_eccw_ff <= 1'b0;
    end
  endtask

  // HandleError for a fault raised DURING a transfer (s_unit / s_errint_en are
  // stable here). The specific error status bit is set by the caller first.
  task err_active;
    begin
      s_rft    <= 1'b0;
      s_active <= 1'b0;
      clr_ff;
      s_on_cyl[s_unit]    <= 1'b0;
      s_not_ready[s_unit] <= 1'b1;
      s_eng      <= E_IDLE;
      s_dma_wait <= 1'b0;
      if (s_errint_en) s_irq <= 1'b1;
    end
  endtask

  always @(posedge sysclk or negedge sys_rst_n) begin
    if (!sys_rst_n) begin
      s_core_addr    <= 16'd0;
      s_core_addr_hi <= 8'd0;
      s_word_cnt     <= 16'd0;
      s_word_cnt_hi  <= 8'd0;
      s_blkaddr1     <= 16'd0;
      s_blkaddr2     <= 16'd0;
      s_ecc_count    <= 16'd0;
      s_sel_unit     <= 3'd0;
      s_disk_selected<= 1'b0;
      s_on_cyl       <= 8'd0;
      s_not_ready    <= 8'd0;
      s_seek_complete<= 8'd0;
      s_cwr          <= 1'b0;
      s_int_en       <= 1'b0;
      s_errint_en    <= 1'b0;
      s_active       <= 1'b0;
      s_rft          <= 1'b1;   // reset value serves the boot handshake
      s_test_mode    <= 1'b0;
      s_marginal     <= 1'b0;
      s_illegal      <= 1'b0;
      s_time_out     <= 1'b0;
      s_hw_err2      <= 1'b0;
      s_addr_mismatch<= 1'b0;
      s_comparer_err <= 1'b0;
      s_seek_err     <= 1'b0;
      s_maw_ff       <= 1'b0;
      s_mar_ff       <= 1'b0;
      s_wcw_ff       <= 1'b0;
      s_wcr_ff       <= 1'b0;
      s_wc_eccw_ff   <= 1'b0;
      s_irq          <= 1'b0;
      s_boot_mode    <= 1'b1;
      s_boot_fetch   <= 1'b0;
      s_boot_loaded  <= 1'b0;
      s_bootptr      <= 11'd0;
      s_eng          <= E_IDLE;
      s_chunk_q      <= 11'd0;
      s_sec_idx      <= 11'd0;
      s_delay_cnt    <= 16'd0;
      s_dma_wait     <= 1'b0;
      s_mem_addr     <= 24'd0;
      s_words_left   <= 24'd0;
      s_unit         <= 3'd0;
      dma_req        <= 1'b0;
      dma_wr         <= 1'b0;
      dma_addr       <= 24'd0;
      dma_wdata      <= 16'd0;
      disk_start     <= 1'b0;
      disk_req       <= 1'b0;
      disk_wr        <= 1'b0;
    end else begin
      dma_req    <= 1'b0;
      disk_start <= 1'b0;
      disk_req   <= 1'b0;

      if (dbuf_we) s_buffer[dbuf_addr] <= dbuf_wdata;

      // ---- read-strobe side effects ----
      if (s_rd_here) begin
        if (s_boot_mode) begin
          // boot stream readout: +0 read consumes the word, clears ready
          if (s_reg == 3'd0) begin
            s_bootptr <= s_bootptr + 11'd1;
            s_rft     <= 1'b0;
          end
        end else if (s_disk_selected) begin
          case (s_reg)
            3'd0: if (s_cwr) s_wcr_ff <= ~s_wcr_ff;  // read WC: LO then HI
                  else       s_mar_ff <= ~s_mar_ff;  // read CA: LO then HI
            3'd4: if (!s_cwr) clr_ff;                // status read resets FFs
            default: ;
          endcase
        end
      end

      // ---- IOX register writes ----
      if (s_wr_here) begin
        case (s_reg)
          // +1  Load Core Address (CWR=0) / count-mem (CWR=1, maint. only)
          3'd1: if (!s_boot_mode) begin
            if (s_cwr) begin
              if (s_test_mode && s_marginal) begin
                s_core_addr <= s_core_addr + 16'd1;
                s_word_cnt  <= s_word_cnt  - 16'd1;
              end
            end else if (s_active) begin
              s_illegal <= 1'b1;
              err_active;                    // illegal load while active
            end else if (s_maw_ff) begin
              s_core_addr <= iox_wdata;      // second write: LO 16
              s_maw_ff    <= 1'b0;
            end else begin
              s_core_addr_hi <= iox_wdata[7:0]; // first write: HI 8
              s_maw_ff       <= 1'b1;
            end
          end

          // +3  boot activate / Load Block Address I (CWR=0) / II (CWR=1)
          3'd3: begin
            if (s_boot_mode) begin
              // BOOT byte-server (preserved verbatim)
              if (iox_wdata[2] && s_eng == E_IDLE) begin
                if (!s_boot_loaded && !s_boot_fetch) begin
                  s_active     <= 1'b1;
                  s_hw_err2    <= 1'b0;
                  s_illegal    <= 1'b0;
                  s_boot_fetch <= 1'b1;
                  s_blkaddr1   <= 16'd0;
                  s_blkaddr2   <= 16'd0;
                  s_chunk_q    <= BUF_WORDS;
                  disk_start   <= 1'b1;
                  disk_req     <= 1'b1;
                  disk_wr      <= 1'b0;
                  s_eng        <= E_DISK_RD;
                end else if (s_bootptr == 11'd1024) begin
                  s_bootptr    <= 11'd0;
                  s_active     <= 1'b1;
                  s_rft        <= 1'b0;
                  s_boot_fetch <= 1'b1;
                  s_chunk_q    <= BUF_WORDS;
                  disk_req     <= 1'b1;
                  disk_wr      <= 1'b0;
                  s_eng        <= E_DISK_RD;
                end else begin
                  s_rft <= 1'b1;  // next word already buffered
                end
              end
            end else if (s_active) begin
              s_illegal <= 1'b1;
              err_active;                    // illegal load while active
            end else if (s_cwr) begin
              s_blkaddr2 <= iox_wdata;       // cylinder
            end else begin
              s_blkaddr1 <= iox_wdata;       // head b8-15, sector b0-7
            end
          end

          // +5  Load Control Word (GO / opcode). Leaves boot mode.
          // Oracle: a control word is IGNORED while the controller is active.
          3'd5: if (!s_active) begin
            s_boot_mode <= 1'b0;
            s_int_en    <= iox_wdata[0];
            s_errint_en <= iox_wdata[1];
            s_test_mode <= iox_wdata[3];
            s_marginal  <= iox_wdata[10];
            s_sel_unit  <= iox_wdata[9:7];
            s_disk_selected <= ~iox_wdata[9];  // unit 0..3 -> selected
            s_cwr       <= iox_wdata[15];
            s_active    <= iox_wdata[2];        // oracle: active = bit 2 (clear/GO override below)
            s_rft       <= 1'b1;               // oracle: ready = true (top)
            if (!iox_wdata[0]) s_irq <= 1'b0;  // int-enable clear drops line

            // selecting a unit puts it on-cylinder
            if (~iox_wdata[9]) s_on_cyl[iox_wdata[9:7]] <= 1'b1;

            if (iox_wdata[4]) begin
              // ---- Device clear ----
              s_active <= 1'b0;
              if (~iox_wdata[9]) s_not_ready[iox_wdata[9:7]] <= 1'b0;
              s_seek_complete[iox_wdata[9:7]] <= 1'b1;
              s_core_addr    <= 16'd0;
              s_core_addr_hi <= 8'd0;
              s_blkaddr1     <= 16'd0;
              s_blkaddr2     <= 16'd0;
              s_word_cnt     <= 16'd0;
              s_word_cnt_hi  <= 8'd0;
              s_rft          <= 1'b0;
              clr_ff;
              s_illegal      <= 1'b0;
              s_time_out     <= 1'b0;
              s_hw_err2      <= 1'b0;
              s_addr_mismatch<= 1'b0;
              s_comparer_err <= 1'b0;
              s_seek_err     <= 1'b0;
              s_eng          <= E_IDLE;
              s_dma_wait     <= 1'b0;
              // else-branch interrupt eval with rft now false: ie && test
              s_irq          <= iox_wdata[0] && iox_wdata[3];
            end else if (iox_wdata[2]) begin
              // ---- GO ----
              if (iox_wdata[9]) begin
                // no unit selected -> DRIVE_NOT_SELECTED
                s_hw_err2 <= 1'b1;
                s_rft     <= 1'b0;
                s_active  <= 1'b0;
                clr_ff;
                s_eng      <= E_IDLE;
                s_dma_wait <= 1'b0;
                if (iox_wdata[1]) s_irq <= 1'b1;
              end else begin
                s_active            <= 1'b1;
                s_unit              <= iox_wdata[9:7];
                s_not_ready[iox_wdata[9:7]] <= 1'b0;
                s_seek_complete[iox_wdata[9:7]] <= 1'b0; // clear for the xfer
                s_mem_addr   <= {s_core_addr_hi, s_core_addr};
                s_words_left <= w_words;

                if (!iox_wdata[3] &&
                    ((w_lba > w_max_lba) ||
                     (w_sector >= GEO_SPT[7:0]) ||
                     ({8'd0, w_head} >= GEO_MAX_CYL))) begin
                  // ---- address mismatch ----
                  s_addr_mismatch <= 1'b1;
                  s_rft    <= 1'b0;
                  s_active <= 1'b0;
                  clr_ff;
                  s_on_cyl[iox_wdata[9:7]]    <= 1'b0;
                  s_not_ready[iox_wdata[9:7]] <= 1'b1;
                  s_eng      <= E_IDLE;
                  s_dma_wait <= 1'b0;
                  if (iox_wdata[1]) s_irq <= 1'b1;
                end else begin
                  case (iox_wdata[14:11])
                    4'd0: begin  // M0 read transfer (disk -> memory)
                      if (w_words != 24'd0) begin
                        disk_start <= 1'b1;
                        disk_req   <= 1'b1;
                        disk_wr    <= 1'b0;
                        s_chunk_q  <= (w_words > {13'd0, BUF_WORDS}) ?
                                      BUF_WORDS : w_words[10:0];
                        s_sec_idx  <= 11'd0;
                        s_eng      <= E_DISK_RD;
                      end else begin
                        s_delay_cnt <= DELAY_TICKS;
                        s_eng       <= E_DELAY;
                      end
                    end
                    4'd1: begin  // M1 write transfer (memory -> disk)
                      if (w_words != 24'd0) begin
                        disk_start <= 1'b1;
                        s_chunk_q  <= (w_words > {13'd0, BUF_WORDS}) ?
                                      BUF_WORDS : w_words[10:0];
                        s_sec_idx  <= 11'd0;
                        s_eng      <= E_MEM_RD;
                      end else begin
                        s_delay_cnt <= DELAY_TICKS;
                        s_eng       <= E_DELAY;
                      end
                    end
                    4'd4: begin  // M4 initiate seek
                      s_seek_err  <= 1'b0;
                      s_delay_cnt <= DELAY_TICKS;
                      s_eng       <= E_DELAY;
                    end
                    4'd6: begin  // M6 seek-complete search
                      s_on_cyl[iox_wdata[9:7]] <= 1'b1;
                      s_seek_err  <= 1'b0;
                      s_seek_complete[iox_wdata[9:7]] <= 1'b1;
                      s_delay_cnt <= DELAY_TICKS;
                      s_eng       <= E_DELAY;
                    end
                    4'd7: begin  // M7 return to zero (only op that clears seekErr)
                      s_seek_err  <= 1'b0;
                      s_on_cyl[iox_wdata[9:7]] <= 1'b1;
                      s_seek_complete[iox_wdata[9:7]] <= 1'b1;
                      s_delay_cnt <= DELAY_TICKS;
                      s_eng       <= E_DELAY;
                    end
                    4'd9: begin  // M9 select release (DIVERGENCE: complete, no hang)
                      s_disk_selected <= 1'b0;
                      s_delay_cnt <= DELAY_TICKS;
                      s_eng       <= E_DELAY;
                    end
                    default: begin  // M2/M3/M5/M8 stub completion
                      s_delay_cnt <= DELAY_TICKS;
                      s_eng       <= E_DELAY;
                    end
                  endcase
                end
              end
            end else begin
              // ---- not a GO: re-evaluate the interrupt line ----
              // rft was just set true, so ie && (test?1:rft) == ie
              s_irq <= iox_wdata[0];
            end
          end

          // +7  Load Word Counter (CWR=0) / Load ECC Control (CWR=1)
          3'd7: if (!s_boot_mode) begin
            if (s_cwr) begin
              if (s_wc_eccw_ff) begin
                if (iox_wdata[0]) s_ecc_count <= 16'd0; // bit0: reset ECC
                if (iox_wdata[1]) s_hw_err2   <= 1'b1;  // bit1: force parity
                s_wc_eccw_ff  <= 1'b0;
              end else begin
                s_wc_eccw_ff  <= 1'b1;   // HI byte unused (as in the oracle)
              end
            end else if (s_wcw_ff) begin
              s_word_cnt <= iox_wdata;        // second write: LO 16
              s_wcw_ff   <= 1'b0;
            end else begin
              s_word_cnt_hi <= iox_wdata[7:0];// first write: HI 8
              s_wcw_ff      <= 1'b1;
            end
          end

          default: ;
        endcase
      end

      // ---- transfer engine ----
      case (s_eng)
        E_IDLE: ;

        E_DISK_RD: begin
          if (disk_done) begin
            if (disk_err_in && s_boot_fetch) begin
              // boot fetch error (boot path, no unit semantics)
              s_hw_err2    <= 1'b1;
              s_boot_fetch <= 1'b0;
              s_active     <= 1'b0;
              s_rft        <= 1'b1;
              s_eng        <= E_IDLE;
            end else if (disk_err_in) begin
              // media read fault -> disk unit not ready (oracle READ_ERROR)
              err_active;
            end else if (s_boot_fetch) begin
              s_boot_fetch  <= 1'b0;
              s_boot_loaded <= 1'b1;
              s_active      <= 1'b0;
              s_rft         <= 1'b1;
              s_eng         <= E_IDLE;
            end else begin
              s_sec_idx <= 11'd0;
              s_eng     <= E_MEM_WR;
            end
          end
        end

        E_MEM_WR: begin
          if (!s_dma_wait && !dma_busy) begin
            dma_issue(1'b1, s_mem_addr, s_buffer[s_sec_idx[9:0]]);
          end else if (s_dma_wait && dma_ack) begin
            s_dma_wait <= 1'b0;
            if (dma_err) begin
              err_active;              // bus/memory fault -> not ready
            end else begin
              s_mem_addr   <= s_mem_addr   + 24'd1;
              s_words_left <= s_words_left - 24'd1;
              if (s_sec_idx + 11'd1 >= s_chunk_q || s_words_left == 24'd1) begin
                if (s_words_left == 24'd1) begin
                  s_delay_cnt <= DELAY_TICKS;
                  s_eng       <= E_DELAY;
                end else begin
                  s_chunk_q <= ((s_words_left - 24'd1) > {13'd0, BUF_WORDS}) ?
                               BUF_WORDS : (s_words_left[10:0] - 11'd1);
                  disk_req  <= 1'b1;
                  disk_wr   <= 1'b0;
                  s_eng     <= E_DISK_RD;
                end
              end else begin
                s_sec_idx <= s_sec_idx + 11'd1;
              end
            end
          end
        end

        E_MEM_RD: begin
          if (!s_dma_wait && !dma_busy) begin
            dma_issue(1'b0, s_mem_addr, 16'd0);
          end else if (s_dma_wait && dma_ack) begin
            s_dma_wait <= 1'b0;
            if (dma_err) begin
              err_active;              // bus/memory fault -> not ready
            end else begin
              s_buffer[s_sec_idx[9:0]] <= dma_rdata;
              s_mem_addr   <= s_mem_addr   + 24'd1;
              s_words_left <= s_words_left - 24'd1;
              if (s_sec_idx + 11'd1 >= s_chunk_q || s_words_left == 24'd1) begin
                disk_req <= 1'b1;
                disk_wr  <= 1'b1;
                s_eng    <= E_DISK_WR;
              end else begin
                s_sec_idx <= s_sec_idx + 11'd1;
              end
            end
          end
        end

        E_DISK_WR: begin
          if (disk_done) begin
            if (disk_err_in) begin
              s_comparer_err <= 1'b1;  // media write fault (oracle WriteBlock false)
              err_active;
            end else if (s_words_left == 24'd0) begin
              s_delay_cnt <= DELAY_TICKS;
              s_eng       <= E_DELAY;
            end else begin
              s_chunk_q <= (s_words_left > {13'd0, BUF_WORDS}) ?
                           BUF_WORDS : s_words_left[10:0];
              s_sec_idx <= 11'd0;
              s_eng     <= E_MEM_RD;
            end
          end
        end

        // Completion delay, then ReadEnd (oracle SMDReadEnd). Boot completions
        // use the same delay slot but skip the register sync / interrupt.
        E_DELAY: begin
          if (s_delay_cnt != 16'd0) begin
            s_delay_cnt <= s_delay_cnt - 16'd1;
          end else if (s_boot_mode) begin
            s_active <= 1'b0;
            s_rft    <= 1'b1;
            s_eng    <= E_IDLE;
          end else begin
            s_active <= 1'b0;
            s_rft    <= 1'b1;
            clr_ff;
            s_core_addr    <= s_mem_addr[15:0];
            s_core_addr_hi <= s_mem_addr[23:16];
            s_word_cnt     <= 16'd0;
            s_word_cnt_hi  <= 8'd0;
            s_seek_complete<= (8'd1 << s_unit);
            s_eng          <= E_IDLE;
            s_irq          <= s_int_en;   // ReadEnd: interrupt iff int-enabled
          end
        end

        default: s_eng <= E_IDLE;
      endcase

      // IDENT answered: clear interrupt-enable and drop the line (oracle IDENT).
      if (s_ident_answer) begin
        s_int_en <= 1'b0;
        s_irq    <= 1'b0;
      end
    end
  end

endmodule

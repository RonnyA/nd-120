/**************************************************************************
** ND120 CPU, MM&M                                                       **
** MEM/RAM - SDRAM backend (Tang Nano 20K)                               **
** Drop-in replacement for the sheet-49 RAM (MEM_RAM_49) that maps the   **
** ND-120 DRAM protocol onto the board's 8 MB embedded SDRAM through     **
** the 18-bit-word controller (sdram18.v).                               **
**                                                                       **
** Protocol contract (measured, docs/nd120-dram-memory.md section 4;     **
** N = OSC cycle of the RAS rising edge, fast = 2x OSC, edge-aligned):   **
**   N   : row on AA_9_0, MWRITE50_n and BANKx valid                     **
**   N+1 : column on AA_9_0                                              **
**   N+2 : CAS rises, write data DD_17_0_IN valid                        **
**   N+4 : read data must be on DD_17_0_OUT (held while CAS high)        **
**   N+5 : RAS falls, CAS tail one more cycle                            **
**   Next access no earlier than N+11.                                   **
**                                                                       **
** Capacity: 2M x 18-bit words = BANK0 + BANK1 (1M words each) = 4 MB.   **
** BANK2 is not populated: never written, reads as 0, so the ND-120's    **
** boot-time memory sizing simply detects two banks.                     **
**                                                                       **
** ND_SDRAM_PACK16 (docs/nd120-parity-refactor-order.md, semantics       **
** pinned by docs/nd120-parity-analysis.md): only the 16 DATA bits are   **
** stored, two adjacent ND words per 32-bit SDRAM location, so           **
** BANK0+BANK1 (still the full 4 MB, boot sizing unchanged) fold into    **
** the LOWER half of the chip (location bit 20 = 0); the upper half is   **
** RESERVED for the nd_storage disk-image cache (nd-storage-design.md    **
** section 5.2). Parity is COMPUTED on the read path (DD[8]/DD[17]       **
** regenerated as odd parity, CORR_n always "correct") - licensed by the **
** parity analysis: no self-test or runtime path reads stored parity.    **
** The CPU/storage split is parameterized at ND-row granularity          **
** (CPU_PART_ROWS) so a future build can trade CPU memory for cache.     **
**                                                                       **
** Refresh is generated HERE (the board logic's refresh chain is         **
** inactive - see docs/nd120-dram-memory.md section 4): primarily in     **
** the guaranteed-idle slot right after each access, plus an idle        **
** watchdog when the CPU leaves memory alone.                            **
**                                                                       **
** Last reviewed: 8-JUL-2026                                             **
** Ronny Hansen                                                          **
***************************************************************************/

module MEM_RAM_49_SDRAM #(
    // Frequency of clk2x (= 2x OSC). MEM_43 instantiates this module without
    // parameters, so the default must track the board clock: when the build
    // provides BOARD_CLK_FREQ (tang20k_defines.v), derive 2x from it - the
    // refresh interval and the controller's init counts depend on it.
`ifdef BOARD_CLK_FREQ
    parameter CLK2X_FREQ = 2 * `BOARD_CLK_FREQ,
`else
    parameter CLK2X_FREQ = 54_000_000,
`endif
    // ND_SDRAM_PACK16 only: how many 1K-ND-word rows ({bank, row[9:0]} out of
    // 2048) belong to the CPU. Default 2048 = full 4 MB main memory (both ND
    // banks). Rows at/above this count report ABSENT (read 0, writes dropped),
    // so boot-time sizing shrinks accordingly - e.g. 1024 = 2 MB CPU, freeing
    // 6 MB of the chip for the storage cache. Keep it a multiple of 1024 so
    // whole ND banks appear/disappear (the sizing probe works per bank).
    parameter CPU_PART_ROWS = 2048
) (
    // Input signals (sheet-49 interface, same as MEM_RAM_49)
    input sysclk,     // OSC-domain clock (unused internally; kept for symmetry)
    input sys_rst_n,  // System reset

    input [9:0] AA_9_0,
    input       BANK0,
    input       BANK1,
    /* verilator lint_off UNUSEDSIGNAL */
    input       BANK2,  // not populated in the SDRAM backend (2M words = 2 banks)
    /* verilator lint_on UNUSEDSIGNAL */

    input CAS,
    input RAS,

    input MWRITE50_n,

    input  [17:0] DD_17_0_IN,
    output [17:0] DD_17_0_OUT,

    output CORR_n,

    // Fast clock domain (2x OSC from the same rPLL, edge-aligned)
    input clk2x,
    input clk2x_sdram,  // 180 degrees from clk2x, for the SDRAM chip

    // SDRAM device pins ("magic" names on Gowin EDA; pinned in the OSS cst)
    output        O_sdram_clk,
    output        O_sdram_cke,
    output        O_sdram_cs_n,
    output        O_sdram_cas_n,
    output        O_sdram_ras_n,
    output        O_sdram_wen_n,
    inout  [31:0] IO_sdram_dq,
    output [10:0] O_sdram_addr,
    output [ 1:0] O_sdram_ba,
    output [ 3:0] O_sdram_dqm,

    // Raw bridge state for the on-chip analyzer (see TRACE-CAPTURE-GUIDE.md)
    output [ 7:0] DBG_BRIDGE
);

  /*******************************************************************************
   ** Write-data capture - OR-accumulation across the access                    **
   **                                                                            **
   ** Hardware evidence (Tang, 8-JUL-2026, four builds): the write data on      **
   ** DD_17_0_IN appears only as a SUB-CYCLE PULSE somewhere inside the access  **
   ** window - the AM29833A transceivers in MEM_DATA_46 drive it                **
   ** combinationally, gated by PAL-generated OET_n/OER_n whose FF-mode phase   **
   ** is narrow; every fixed sample point tried (2N+5 / 2N+9 / OSC N+2 / N+3)   **
   ** read a dead or half-risen bus. The saving property: when NOT driving,     **
   ** the transceiver outputs hard ZEROS (T_OUT = mode ? data : 0). So          **
   ** OR-accumulate DD on every clk2x edge across the access: idle samples      **
   ** contribute nothing, and with the pulse ~an OSC cycle wide, at least one   **
   ** 74 ns-spaced sample lands inside it with all bits driven.                 **
   *******************************************************************************/
  reg [17:0] dd_acc;

  // Second sampler on the falling clk2x edge: 37 ns effective granularity,
  // in case the drive pulse is narrower than one clk2x period
  reg [17:0] dd_acc_n;
  reg        ras_dn;
  always @(negedge clk2x) begin
    if (!sys_rst_n) begin
      dd_acc_n <= 0;
      ras_dn   <= 0;
    end else begin
      ras_dn <= RAS;
      if (RAS && !ras_dn) dd_acc_n <= DD_17_0_IN;
      else if (RAS || CAS) dd_acc_n <= dd_acc_n | DD_17_0_IN;
    end
  end

  /*******************************************************************************
   ** SDRAM controller (18-bit word variant, runs entirely on clk2x)             **
   *******************************************************************************/
  reg         s_rd, s_wr, s_refresh;
`ifdef ND_SDRAM_PACK16
  reg  [21:0] s_addr;  // half-word address: [21]=0 pins the CPU to the low half
  reg  [15:0] s_din;
  wire [15:0] s_dout;
`else
  reg  [20:0] s_addr;
  reg  [17:0] s_din;
  wire [17:0] s_dout;
`endif
  wire        s_data_ready, s_busy;

  sdram18 #(
      .FREQ(CLK2X_FREQ)
  ) u_sdram (
      .clk(clk2x),
      .clk_sdram(clk2x_sdram),
      .resetn(sys_rst_n),
      .rd(s_rd),
      .wr(s_wr),
      .refresh(s_refresh),
      .addr(s_addr),
      .din(s_din),
      .dout(s_dout),
      .data_ready(s_data_ready),
      .busy(s_busy),

      .SDRAM_DQ(IO_sdram_dq),
      .SDRAM_A(O_sdram_addr),
      .SDRAM_BA(O_sdram_ba),
      .SDRAM_nCS(O_sdram_cs_n),
      .SDRAM_nWE(O_sdram_wen_n),
      .SDRAM_nRAS(O_sdram_ras_n),
      .SDRAM_nCAS(O_sdram_cas_n),
      .SDRAM_CLK(O_sdram_clk),
      .SDRAM_CKE(O_sdram_cke),
      .SDRAM_DQM(O_sdram_dqm)
  );

  /*******************************************************************************
   ** Refresh timer: one auto-refresh per 15 us (fast-clock cycles)              **
   *******************************************************************************/
  localparam REFRESH_INTERVAL = CLK2X_FREQ / 1_000_000 * 15;

  reg [10:0] ref_cnt;
  reg refresh_needed;
  always @(posedge clk2x) begin
    if (!sys_rst_n) begin
      ref_cnt        <= 0;
      refresh_needed <= 0;
    end else begin
      ref_cnt <= ref_cnt + 1;
      if (ref_cnt >= REFRESH_INTERVAL[10:0]) refresh_needed <= 1;
      if (s_refresh) begin
        ref_cnt        <= 0;
        refresh_needed <= 0;
      end
    end
  end

  /*******************************************************************************
   ** Protocol bridge state machine (clk2x domain)                               **
   **                                                                            **
   ** RAS/CAS/AA/BANKx/MWRITE50_n are OSC-domain registered-PAL outputs; clk2x   **
   ** is the same PLL at exactly 2x, so they change only on every other clk2x    **
   ** edge and are sampled here as synchronous signals (fast edge 2N+1 sees the  **
   ** value OSC edge N produced).                                                **
   *******************************************************************************/
  localparam B_IDLE    = 3'd0;
  localparam B_COLWAIT = 3'd1;  // fast edge 2N+2: AA is switching to the column
  localparam B_COL     = 3'd2;  // fast edge 2N+3: column valid -> issue read
  localparam B_WRDATA  = 3'd3;  // fast edge 2N+5: DD_IN valid -> issue write
  localparam B_RDWAIT  = 3'd4;  // wait for data_ready, capture and hold
  localparam B_POST    = 3'd5;  // op done: run a refresh if one is due
  localparam B_TAIL    = 3'd6;  // unpopulated bank: just wait out the access

  reg [2:0] bstate;
  reg       ras_d;
  reg [9:0] row_q;
  reg       wn_q;    // 1 = read (MWRITE50_n high)
  reg       bsel_q;  // access hits a populated bank (BANK0/BANK1)
  reg       bank_q;  // 0 = BANK0, 1 = BANK1
  reg [2:0] wcnt_q;  // write-data settle counter (capture late in the window)

  reg [17:0] dd_hold;
  reg        have_data;

  assign DBG_BRIDGE = {bstate[2:0],    // [7:5] FSM state (B_IDLE..B_TAIL)
                       s_wr,           // [4] write command issued
                       s_rd,           // [3] read command issued
                       s_data_ready,   // [2] controller returned read data
                       have_data,      // [1] read data held for DD_OUT
                       s_busy};        // [0] controller busy

  // Idle watchdog: if the CPU leaves memory alone, refresh anyway
  reg [6:0] idle_cnt;
  localparam IDLE_REFRESH_AFTER = 7'd64;  // fast cycles (~1.2 us at 54 MHz)

  always @(posedge clk2x) begin
    if (!sys_rst_n) begin
      bstate    <= B_IDLE;
      ras_d     <= 0;
      s_rd      <= 0;
      s_wr      <= 0;
      s_refresh <= 0;
      s_addr    <= 0;
      s_din     <= 0;
      row_q     <= 0;
      wn_q      <= 1;
      bsel_q    <= 0;
      bank_q    <= 0;
      wcnt_q    <= 0;
      dd_hold   <= 0;
      have_data <= 0;
      idle_cnt  <= 0;
    end else begin
      // command outputs are 1-cycle pulses
      s_rd      <= 0;
      s_wr      <= 0;
      s_refresh <= 0;

      ras_d <= RAS;

      // OR-accumulate the write data across the access (see comment above):
      // reset at RAS rise, collect every clk2x edge while the access runs
      if (RAS && !ras_d) dd_acc <= DD_17_0_IN;
      else if (RAS || CAS) dd_acc <= dd_acc | DD_17_0_IN;

      // have_data lifecycle: set when a read completes, cleared when the next
      // access starts; the CAS term in read_active closes the output window.

      case (bstate)
        B_IDLE: begin
          if (RAS && !ras_d) begin  // fast edge 2N+1: RAS rise seen, AA = row
            row_q     <= AA_9_0;
            wn_q      <= MWRITE50_n;
`ifdef ND_SDRAM_PACK16
            // partition check at row granularity: rows beyond the CPU's share
            // behave exactly like an unpopulated bank (B_TAIL path)
            bsel_q    <= (BANK0 | BANK1) && ({BANK1, AA_9_0} < CPU_PART_ROWS[11:0]);
`else
            bsel_q    <= BANK0 | BANK1;
`endif
            bank_q    <= BANK1;
            have_data <= 0;
            idle_cnt  <= 0;
            bstate    <= B_COLWAIT;
          end else begin
            // idle watchdog refresh (only when no access is starting)
            idle_cnt <= (idle_cnt == IDLE_REFRESH_AFTER) ? idle_cnt : idle_cnt + 1;
            if (refresh_needed && !s_busy && idle_cnt == IDLE_REFRESH_AFTER) s_refresh <= 1;
          end
        end

        B_COLWAIT: bstate <= B_COL;  // 2N+2: skip the AA row->column switch edge

        B_COL: begin  // 2N+3: AA carries the column
          if (!bsel_q) begin
            bstate <= B_TAIL;  // BANK2 / no bank: not populated, do nothing
          end else if (!s_busy) begin
`ifdef ND_SDRAM_PACK16
            // ND word address as a HALF-WORD index into the low half of the
            // chip: adjacent ND words share one 32-bit location ([0] = half)
            s_addr <= {1'b0, bank_q, row_q, AA_9_0};
`else
            s_addr <= {bank_q, row_q, AA_9_0};  // {bank, row[9:0], col[9:0]} = 21 bits
`endif
            if (wn_q) begin
              s_rd   <= 1;  // read: issue now -> data_ready by fast 2N+8 = OSC N+4
              bstate <= B_RDWAIT;
            end else begin
              wcnt_q <= 0;  // write: DD_IN settles DURING the both-low window
              bstate <= B_WRDATA;
            end
          end
          // if s_busy (watchdog refresh collided with this access) hold here;
          // the refresh frees the controller within 5 fast cycles
        end

        B_WRDATA: begin
          // Wait until the accumulated data has covered the whole possible
          // drive window (through OSC N+4 = fast 2N+8), then issue with it
          wcnt_q <= wcnt_q + 1'b1;
          if (wcnt_q >= 3'd5 && !s_busy) begin
`ifdef ND_SDRAM_PACK16
            // store the 16 DATA bits only; DD[8]/DD[17] (parity) are dropped
            // and recomputed on read (docs/nd120-parity-analysis.md section 6)
            s_din  <= {dd_acc[16:9] | dd_acc_n[16:9], dd_acc[7:0] | dd_acc_n[7:0]};
`else
            s_din  <= dd_acc | dd_acc_n;
`endif
            s_wr   <= 1;
            bstate <= B_POST;
          end else if (wcnt_q >= 3'd5) begin
            wcnt_q <= wcnt_q;  // controller busy (colliding refresh): hold
          end
        end

        B_RDWAIT:
        if (s_data_ready) begin
`ifdef ND_SDRAM_PACK16
          // regenerate ODD parity (AM29833A convention: PAR = ~^byte) so the
          // downstream checkers and CORR_n always see a correct word
          dd_hold   <= {~(^s_dout[15:8]), s_dout[15:8], ~(^s_dout[7:0]), s_dout[7:0]};
`else
          dd_hold   <= s_dout;
`endif
          have_data <= 1;
          bstate    <= B_POST;
        end

        B_POST:
        if (!s_busy && !s_rd && !s_wr) begin
          // guaranteed-idle slot: earliest next access is N+11 (22 fast cycles
          // after RAS rise), a refresh takes 5 - always safe here
          if (refresh_needed) s_refresh <= 1;
          bstate <= B_IDLE;
        end

        B_TAIL: begin
          // absent bank/row: the controller is idle for this whole access, so
          // it is a free refresh slot - without this, a run of absent-row
          // accesses (each resetting the idle watchdog, none reaching the
          // B_POST slot) starves refresh past its 15 us cadence
          if (refresh_needed && !s_busy) s_refresh <= 1;
          if (!RAS) bstate <= B_IDLE;
        end

        default: bstate <= B_IDLE;
      endcase
    end
  end

  /*******************************************************************************
   ** Sheet-49 outputs: same gating as the SIP1M9 chips (drive 0 / parity 1     **
   ** when not selected or not reading, so downstream OR-combining still works) **
   *******************************************************************************/
  wire read_active = CAS & wn_q & bsel_q & have_data;

  assign DD_17_0_OUT = read_active ? dd_hold : 18'b0;

  // Two virtual SIP1M9 parity outputs (low chip = DD[8:0], high chip = DD[17:9]),
  // remaining four (unpopulated banks) contribute constant 1 - same formula as
  // SIP1M9's PRD_n, same AND-combination as MEM_RAM_49's CORR_n.
  assign CORR_n = read_active ? ((^dd_hold[8:0]) & (^dd_hold[17:9])) : 1'b1;

endmodule

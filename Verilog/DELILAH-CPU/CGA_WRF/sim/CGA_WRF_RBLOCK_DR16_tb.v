/**************************************************************************
** ND120 CPU, MM&M                                                       **
** CGA_WRF_RBLOCK_DR16 testbench                                         **
** DUT: DELILAH-CPU/CGA_WRF/circuit/CGA_WRF_RBLOCK_DR16.v (PDF page 64)  **
**                                                                       **
** Golden behavior re-derived from the netlist and the commented-out     **
** SCAN_FF bank it replaces (independent model):                         **
**   16-bit register: on ALUCLK rise, WR=1 -> regFF <= RB_15_0,          **
**   WR=0 -> hold (the SCAN_FF bank recirculates D=Q when TE=0).         **
**   REG_15_0 mirrors the register. sys_rst_n is a no-op (port only).    **
**   In FF mode the capture is posedge sysclk gated by ALUCLK_EN && WR.  **
**                                                                       **
**  1. Exhaustive load sweep: all 65536 RB values clocked with WR=1,     **
**     checked bit-for-bit (catches any output bus swap/inversion).      **
**  2. Clocked hold: 16 LFSR-picked RB values clocked with WR=0 must     **
**     leave the register unchanged.                                     **
**  3. Hold with no clock event while RB and WR change.                  **
**  4. sys_rst_n no-op pin: asserting reset (with and without a clock    **
**     event, WR=0) must not touch the register.                         **
**  5. 4000-step fixed-seed LFSR soak with random WR (about half the     **
**     edges write), inputs held across each edge, compared to the       **
**     clocked golden model after every edge.                            **
**                                                                       **
** Sequential (ALUCLK domain): compile once plain (posedge ALUCLK) and   **
** once with -DFPGA_FF_MODE (sysclk + ALUCLK_EN capture) - Makefile      **
** target test-wrf-dr16 runs both.                                       **
**                                                                       **
** Self-checking: prints TB_RESULT: PASS / FAIL (never silent), with a   **
** hard expected-check-count assertion (69555 checks).                   **
**                                                                       **
** 01-AUG-2026                                                           **
** Ronny Hansen                                                          **
***************************************************************************/
`timescale 1ns / 1ps

module CGA_WRF_RBLOCK_DR16_tb;

  reg         sysclk = 0;
  reg         sys_rst_n = 1;
  reg         ALUCLK_EN = 0;
  reg         ALUCLK = 0;
  reg  [15:0] RB_15_0 = 0;
  reg         WR = 0;
  wire [15:0] REG_15_0;

  integer errors = 0;
  integer checks = 0;
  integer i, k;

  // Golden register state (independent model).
  reg [15:0] greg;

  reg [31:0] lfsr = 32'hD1607EE7;

  localparam integer EXPECTED_CHECKS = 69555;

  CGA_WRF_RBLOCK_DR16 dut (
      .sysclk   (sysclk),
      .sys_rst_n(sys_rst_n),
      .ALUCLK_EN(ALUCLK_EN),
      .ALUCLK   (ALUCLK),
      .RB_15_0  (RB_15_0),
      .WR       (WR),
      .REG_15_0 (REG_15_0)
  );

  always #5 sysclk = ~sysclk;

  // One ALUCLK event, valid in BOTH build modes (house pattern), then
  // update the golden model: WR-qualified load, else hold.
  task pulse_aluclk;
    begin
      @(negedge sysclk);
      ALUCLK_EN = 1;
      @(posedge sysclk);
      #1 ALUCLK = 1;
      @(negedge sysclk);
      ALUCLK    = 0;
      ALUCLK_EN = 0;
      if (WR) greg = RB_15_0;
    end
  endtask

  task check_reg(input [127:0] name);
    begin
      checks = checks + 1;
      if (REG_15_0 !== greg) begin
        errors = errors + 1;
        $display("FAIL %0s: REG=%06o expected %06o (RB=%06o WR=%b)",
                 name, REG_15_0, greg, RB_15_0, WR);
      end
    end
  endtask

  initial begin
`ifdef FPGA_FF_MODE
    $display("CGA_WRF_RBLOCK_DR16_tb: FPGA_FF_MODE (sysclk+ALUCLK_EN capture)");
`else
    $display("CGA_WRF_RBLOCK_DR16_tb: latch/CP mode (posedge ALUCLK capture)");
`endif
    #12;

    // ------------------------------------------------------------------
    // 1. Exhaustive load sweep: all 65536 RB values, WR=1. The first
    //    pulse also defines the powered-up-unknown register.
    //    (65536 checks)
    // ------------------------------------------------------------------
    WR = 1;
    for (i = 0; i < 65536; i = i + 1) begin
      RB_15_0 = i[15:0];
      pulse_aluclk;
      check_reg("load");
    end

    // ------------------------------------------------------------------
    // 2. Clocked hold: WR=0, RB noise must not load. (16 checks)
    // ------------------------------------------------------------------
    WR      = 1;
    RB_15_0 = 16'o125252;
    pulse_aluclk;
    WR = 0;
    for (k = 0; k < 16; k = k + 1) begin
      lfsr    = lfsr[0] ? (lfsr >> 1) ^ 32'hEDB88320 : lfsr >> 1;
      RB_15_0 = lfsr[15:0];
      pulse_aluclk;
      check_reg("hold-clocked");
    end

    // ------------------------------------------------------------------
    // 3. Hold with no clock event while RB and WR change. (1 check)
    // ------------------------------------------------------------------
    WR      = 1;
    RB_15_0 = 16'o054321;
    #40;
    check_reg("hold-no-clock");

    // ------------------------------------------------------------------
    // 4. sys_rst_n no-op pin: reset asserted without and with a clock
    //    event (WR=0) leaves the register untouched. (2 checks)
    // ------------------------------------------------------------------
    WR        = 0;
    sys_rst_n = 0;
    #40;
    check_reg("rst-no-clock");
    pulse_aluclk;
    check_reg("rst-clocked");
    sys_rst_n = 1;

    // ------------------------------------------------------------------
    // 5. 4000-step fixed-seed LFSR soak with random WR. (4000 checks)
    // ------------------------------------------------------------------
    for (k = 0; k < 4000; k = k + 1) begin
      lfsr    = lfsr[0] ? (lfsr >> 1) ^ 32'hEDB88320 : lfsr >> 1;
      RB_15_0 = lfsr[15:0];
      WR      = lfsr[16];
      pulse_aluclk;
      check_reg("soak");
    end

    // ------------------------------------------------------------------
    // Verdict. Expected: 65536 load + 16 clocked-hold + 1 no-clock +
    // 2 rst-no-op + 4000 soak = 69555 (the phase-2 preload pulse is
    // deliberately unchecked).
    // ------------------------------------------------------------------
    if (errors == 0 && checks == EXPECTED_CHECKS)
      $display("TB_RESULT: PASS (%0d checks)", checks);
    else
      $display("TB_RESULT: FAIL (%0d errors, %0d of %0d checks)",
               errors, checks, EXPECTED_CHECKS);
    $finish;
  end

endmodule

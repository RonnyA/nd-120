/**************************************************************************
** ND120 CGA (CPU Gate Array / DELILAH)                                  **
** CGA_ALU_ARG testbench                                                 **
** DUT: DELILAH-CPU/CGA_ALU/circuit/CGA_ALU_ARG.v (page 53)              **
**                                                                       **
** Golden behavior re-derived from the netlist (independent model):      **
**   16-bit ARG register: regArg <= CSBIT_15_0 on every ALUCLK rise,     **
**   no enable, no reset. ARG_15_0 mirrors the register. In FF mode the  **
**   capture is posedge sysclk gated by ALUCLK_EN instead.               **
**                                                                       **
**  1. Exhaustive load sweep: all 65536 CSBIT values, each clocked in    **
**     and checked bit-for-bit (also proves no bit swap/inversion in     **
**     the output wiring).                                               **
**  2. Hold with no clock event while CSBIT changes.                     **
**  3. 4000-step fixed-seed LFSR soak, inputs held across each edge,     **
**     compared to the clocked golden model after every edge.            **
**                                                                       **
** Sequential (ALUCLK domain): compile once plain (posedge ALUCLK) and   **
** once with -DFPGA_FF_MODE (sysclk + ALUCLK_EN capture) - Makefile      **
** target test-alu-arg runs both.                                       **
**                                                                       **
** Self-checking: prints TB_RESULT: PASS / FAIL (never silent), with a   **
** hard expected-check-count assertion (69537 checks).                   **
**                                                                       **
** 01-AUG-2026                                                           **
** Ronny Hansen                                                          **
***************************************************************************/
`timescale 1ns / 1ps

module CGA_ALU_ARG_tb;

  reg         sysclk = 0;
  reg         ALUCLK_EN = 0;
  reg         ALUCLK = 0;
  reg  [15:0] CSBIT_15_0 = 0;
  wire [15:0] ARG_15_0;

  integer errors = 0;
  integer checks = 0;
  integer i, k;

  // Golden register state (independent model).
  reg [15:0] garg;

  reg [31:0] lfsr = 32'hA1207A56;

  localparam integer EXPECTED_CHECKS = 69537;

  CGA_ALU_ARG dut (
      .sysclk    (sysclk),
      .ALUCLK_EN (ALUCLK_EN),
      .ALUCLK    (ALUCLK),
      .CSBIT_15_0(CSBIT_15_0),
      .ARG_15_0  (ARG_15_0)
  );

  always #5 sysclk = ~sysclk;

  // One ALUCLK event, valid in BOTH build modes (house pattern), then
  // update the golden model: unconditional load.
  task pulse_aluclk;
    begin
      @(negedge sysclk);
      ALUCLK_EN = 1;
      @(posedge sysclk);
      #1 ALUCLK = 1;
      @(negedge sysclk);
      ALUCLK    = 0;
      ALUCLK_EN = 0;
      garg = CSBIT_15_0;
    end
  endtask

  task check_arg(input [127:0] name);
    begin
      checks = checks + 1;
      if (ARG_15_0 !== garg) begin
        errors = errors + 1;
        $display("FAIL %0s: ARG=%06o expected %06o (CSBIT=%06o)",
                 name, ARG_15_0, garg, CSBIT_15_0);
      end
    end
  endtask

  initial begin
`ifdef FPGA_FF_MODE
    $display("CGA_ALU_ARG_tb: FPGA_FF_MODE (sysclk+ALUCLK_EN capture)");
`else
    $display("CGA_ALU_ARG_tb: latch/CP mode (posedge ALUCLK capture)");
`endif
    #12;

    // ------------------------------------------------------------------
    // 1. Exhaustive load sweep: all 65536 CSBIT values. The first pulse
    //    also defines the powered-up-unknown register. (65536 checks)
    // ------------------------------------------------------------------
    for (i = 0; i < 65536; i = i + 1) begin
      CSBIT_15_0 = i[15:0];
      pulse_aluclk;
      check_arg("load");
    end

    // ------------------------------------------------------------------
    // 2. Hold with no clock event while CSBIT changes. (1 check)
    // ------------------------------------------------------------------
    CSBIT_15_0 = 16'o123456;
    #40;
    check_arg("hold-no-clock");

    // ------------------------------------------------------------------
    // 3. 4000-step fixed-seed LFSR soak. (4000 checks)
    // ------------------------------------------------------------------
    for (k = 0; k < 4000; k = k + 1) begin
      lfsr       = lfsr[0] ? (lfsr >> 1) ^ 32'hEDB88320 : lfsr >> 1;
      CSBIT_15_0 = lfsr[15:0];
      pulse_aluclk;
      check_arg("soak");
    end

    // ------------------------------------------------------------------
    // Verdict. Expected: 65536 load + 1 hold + 4000 soak = 69537.
    // ------------------------------------------------------------------
    if (errors == 0 && checks == EXPECTED_CHECKS)
      $display("TB_RESULT: PASS (%0d checks)", checks);
    else
      $display("TB_RESULT: FAIL (%0d errors, %0d of %0d checks)",
               errors, checks, EXPECTED_CHECKS);
    $finish;
  end

endmodule

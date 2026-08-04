/**************************************************************************
** ND120 CGA (CPU Gate Array / DELILAH)                                  **
** CGA_IDBCTL_PGSREG testbench                                           **
**                                                                       **
** Verification of the paging-status register (PDF page 98):             **
** 14 SCAN_FF_EN bits clocked by MCLK, scan-enabled by VACC (=~VACCN).   **
**                                                                       **
** Independent model (from the netlist reading, D=Q recirculation on     **
** every bit, TI = capture source, TE = VACC):                           **
**   on MCLK rise with VACCN=0:                                          **
**     r15 <= FETCHN, r14 <= PVIOL, r[11:0] <= LA_21_10[11:0]            **
**   on MCLK rise with VACCN=1: hold (D=Q loop)                          **
**   outputs: PGS_15_14 = { ~r15, r14 }  (PGS15 output taken from QN!)   **
**            PGS_11_0  = r[11:0]                                        **
**                                                                       **
** Test plan:                                                            **
**   1. defining load of all-zeros, then all-ones                        **
**   2. walking-one across all 14 state bits (14 loads)                  **
**   3. hold with clock (VACCN=1, inputs changed, 2 pulses)              **
**   4. hold without clock (inputs changed, no MCLK)                     **
**   5. 256 fixed-seed LFSR steps with random VACCN/FETCHN/PVIOL/LA      **
**                                                                       **
** Registered module (SCAN_FF_EN switched by FPGA_FF_MODE): the          **
** Makefile target test-idbctl-pgsreg runs this twice - default          **
** latch/CP mode (posedge MCLK) and -DFPGA_FF_MODE (sysclk + MCLK_EN     **
** capture). USE_TRANSPARENT_LATCHES does not appear in this module's    **
** primitive set.                                                        **
**                                                                       **
** Self-checking: prints TB_RESULT: PASS / FAIL (never silent).          **
**                                                                       **
** 31-JUL-2026                                                           **
** Ronny Hansen                                                          **
***************************************************************************/
`timescale 1ns / 1ps

module CGA_IDBCTL_PGSREG_tb;

  reg         sysclk = 0;
  reg         MCLK_EN = 0;
  reg         MCLK = 0;
  reg         FETCHN = 0;
  reg  [11:0] LA_21_10 = 0;
  reg         PVIOL = 0;
  reg         VACCN = 0;

  wire [11:0] PGS_11_0;
  wire [ 1:0] PGS_15_14;

  integer errors = 0;
  integer checks = 0;
  integer i;

  // reference model state
  reg        m_r15;
  reg        m_r14;
  reg [11:0] m_r11_0;
  reg [31:0] lfsr;

  wire [13:0] got = {PGS_15_14, PGS_11_0};
  wire [13:0] exp = {~m_r15, m_r14, m_r11_0};

  CGA_IDBCTL_PGSREG dut (
      .sysclk(sysclk),
      .MCLK_EN(MCLK_EN),
      .FETCHN(FETCHN),
      .LA_21_10(LA_21_10),
      .MCLK(MCLK),
      .PVIOL(PVIOL),
      .VACCN(VACCN),
      .PGS_11_0(PGS_11_0),
      .PGS_15_14(PGS_15_14)
  );

  always #5 sysclk = ~sysclk;

  // One MCLK event, valid in BOTH build modes: the EN-mode register captures
  // at posedge sysclk while MCLK_EN=1; the CP-mode register captures at the
  // posedge of MCLK raised just after the same sysclk edge (inputs stable).
  task pulse_mclk;
    begin
      @(negedge sysclk);
      MCLK_EN = 1;
      @(posedge sysclk);
      #1 MCLK = 1;
      @(negedge sysclk);
      MCLK    = 0;
      MCLK_EN = 0;
    end
  endtask

  // apply inputs, clock once, update the model, compare the full output bus
  task step(input v_vaccn, input v_fetchn, input v_pviol, input [11:0] v_la,
            input [127:0] name);
    begin
      VACCN    = v_vaccn;
      FETCHN   = v_fetchn;
      PVIOL    = v_pviol;
      LA_21_10 = v_la;
      pulse_mclk;
      if (!v_vaccn) begin
        m_r15   = v_fetchn;
        m_r14   = v_pviol;
        m_r11_0 = v_la;
      end
      #2;
      checks = checks + 1;
      if (got !== exp) begin
        errors = errors + 1;
        $display("FAIL %0s: got %14b expected %14b (VACCN=%b FETCHN=%b PVIOL=%b LA=%03h)",
                 name, got, exp, v_vaccn, v_fetchn, v_pviol, v_la);
      end
    end
  endtask

  function [31:0] lfsr_next(input [31:0] x);
    lfsr_next = {x[30:0], x[31] ^ x[21] ^ x[1] ^ x[0]};
  endfunction

  initial begin
`ifdef FPGA_FF_MODE
    $display("CGA_IDBCTL_PGSREG_tb: FPGA_FF_MODE (sysclk+MCLK_EN capture)");
`else
    $display("CGA_IDBCTL_PGSREG_tb: latch/CP mode (posedge MCLK capture)");
`endif

    // 1. defining loads
    step(0, 0, 0, 12'h000, "load zeros");
    step(0, 1, 1, 12'hFFF, "load ones");

    // 2. walking-one across the 14 state bits
    for (i = 0; i < 12; i = i + 1)
      step(0, 0, 0, 12'h001 << i, "walk LA bit");
    step(0, 0, 1, 12'h000, "walk PVIOL");
    step(0, 1, 0, 12'h000, "walk FETCHN");

    // 3. hold with clock: VACCN=1 must ignore new inputs on the MCLK edge
    step(0, 1, 0, 12'hA5A, "pre-hold load");
    step(1, 0, 1, 12'h5A5, "hold w/ clock 1");
    step(1, 1, 1, 12'hFFF, "hold w/ clock 2");

    // 4. hold without clock: change inputs, no MCLK, outputs must not move
    VACCN = 0; FETCHN = 0; PVIOL = 0; LA_21_10 = 12'h123;
    #40;
    checks = checks + 1;
    if (got !== exp) begin
      errors = errors + 1;
      $display("FAIL hold w/o clock: got %14b expected %14b", got, exp);
    end

    // 5. fixed-seed LFSR random steps
    lfsr = 32'hC0DE1D8B;
    for (i = 0; i < 256; i = i + 1) begin
      lfsr = lfsr_next(lfsr);
      step(lfsr[14], lfsr[13], lfsr[12], lfsr[11:0], "lfsr step");
    end

    // Verdict. Expected: 2 + 14 + 3 + 1 + 256 = 276 checks.
    if (errors == 0 && checks == 276)
      $display("TB_RESULT: PASS (%0d checks)", checks);
    else
      $display("TB_RESULT: FAIL (%0d errors, %0d of 276 checks)", errors, checks);
    $finish;
  end

endmodule

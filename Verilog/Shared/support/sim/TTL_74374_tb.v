/****************************************************************************
** TTL_74374 - functional testbench                                       **
**                                                                        **
** COVERAGE: all 256 D values captured through the sysclk-detected CK     **
** edge path, plus named checks for OE_n masking, back-to-back CK rises,  **
** and a CK held high across several sysclks (must capture only once).    **
**                                                                        **
** RTL-VS-DATASHEET DISAGREEMENT (record and assert the RTL, not the      **
** datasheet): the real 74LS374 clocks directly on the rising edge of CK. **
** This RTL does NOT clock on CK directly - it registers CK on sysclk     **
** (CK_d), forms CK_pulse = CK & ~CK_d, and captures Q_reg on that pulse. **
** The practical effect: capture lands on the FIRST posedge sysclk that   **
** observes CK high after having observed it low - i.e. up to one sysclk **
** period after the real CK transition, not at the instant CK rises.     **
** This testbench drives CK between sysclk edges (as the real board's    **
** strobes do) and checks the capture lands exactly at that first        **
** qualifying posedge sysclk, not before, not later.                     **
**                                                                        **
** Q_reg is declared with an explicit initial value of 0, so (unlike     **
** TTL_74534) reading Q before any capture is well-defined 0, not X.      **
**                                                                        **
** Run: cd Verilog/Shared/support/sim && iverilog -g2012 -o tb.vvp \      **
**   TTL_74374_tb.v ../TTL_74374.v && vvp tb.vvp                          **
**                                                                        **
** Last reviewed: 20-AUG-2026                                            **
** Ronny Hansen                                                          **
*****************************************************************************/
`timescale 1ns / 1ps
`default_nettype none

module TTL_74374_tb;

  reg        sysclk = 0;
  always #5 sysclk = ~sysclk;

  reg  [7:0] D = 8'h00;
  reg        CK = 0;
  reg        OE_n = 0;
  wire [7:0] Q;

  integer errors = 0;
  integer checks = 0;

  TTL_74374 DUT (
      .sysclk(sysclk), .D(D), .CK(CK), .OE_n(OE_n), .Q(Q)
  );

  // Pulse CK for exactly one sysclk (rise at a negedge, fall at the
  // following negedge) and check the capture landed at the intervening
  // posedge sysclk - the documented one-sysclk-latency path.
  task pulse_and_check(input [7:0] dval);
    begin
      D = dval;
      @(negedge sysclk);
      CK = 1;
      @(posedge sysclk);
      #1;
      checks = checks + 1;
      if (Q !== dval) begin
        errors = errors + 1;
        if (errors < 10) $display("FAIL capture: D=%02h Q=%02h", dval, Q);
      end
      @(negedge sysclk);
      CK = 0;
      @(posedge sysclk);
    end
  endtask

  integer i;

  initial begin
    $dumpfile("TTL_74374_tb.vcd");
    $dumpvars(0, TTL_74374_tb);

    // ---- Q_reg initialises to 0 -------------------------------------------
    checks = checks + 1;
    if (Q !== 8'h00) begin
      errors = errors + 1;
      $display("FAIL INIT_ZERO: Q=%02h expected 00 before any capture", Q);
    end

    // ---- short documentation sequence -------------------------------------
    pulse_and_check(8'h5A);
    pulse_and_check(8'hA5);
    pulse_and_check(8'h00);
    pulse_and_check(8'hFF);
    $dumpoff;

    // ---- exhaustive: all 256 D values --------------------------------------
    $display("=====================================================");
    $display(" TTL_74374 exhaustive capture sweep (256 D values)");
    $display("=====================================================");
    for (i = 0; i < 256; i = i + 1) begin
      pulse_and_check(i[7:0]);
    end

    // ---- named check: OE_n masks a non-zero stored value -------------------
    pulse_and_check(8'hC3);
    OE_n = 1;
    #1;
    checks = checks + 1;
    if (Q !== 8'h00) begin
      errors = errors + 1;
      $display("FAIL OE_MASK: Q=%02h expected 00 with OE_n=1 and stored value C3", Q);
    end
    OE_n = 0;
    #1;
    checks = checks + 1;
    if (Q !== 8'hC3) begin
      errors = errors + 1;
      $display("FAIL OE_UNMASK: Q=%02h expected C3 after OE_n back to 0", Q);
    end

    // ---- named check: CK held high across several sysclks captures ONCE ---
    D = 8'h11;
    @(negedge sysclk);
    CK = 1;
    @(posedge sysclk); #1;
    checks = checks + 1;
    if (Q !== 8'h11) begin
      errors = errors + 1;
      $display("FAIL SINGLE_CAPTURE_setup: Q=%02h expected 11", Q);
    end
    D = 8'h22;              // D changes while CK still held high
    @(posedge sysclk); #1;
    checks = checks + 1;
    if (Q !== 8'h11) begin
      errors = errors + 1;
      $display("FAIL SINGLE_CAPTURE_held_high: Q=%02h changed to reflect new D=%02h while CK stayed high", Q, D);
    end
    D = 8'h33;
    @(posedge sysclk); #1;
    checks = checks + 1;
    if (Q !== 8'h11) begin
      errors = errors + 1;
      $display("FAIL SINGLE_CAPTURE_held_high_2: Q=%02h changed to reflect new D=%02h while CK stayed high", Q, D);
    end
    @(negedge sysclk);
    CK = 0;
    @(posedge sysclk);

    // ---- named check: back-to-back CK rises each capture ------------------
    pulse_and_check(8'h44);
    pulse_and_check(8'h88);
    pulse_and_check(8'hEE);

    $display("-----------------------------------------------------");
    $display(" checks run : %0d", checks);
    $display(" failures   : %0d", errors);
    if (errors == 0) $display("TB_RESULT: PASS");
    else             $display("TB_RESULT: FAIL");
    $display("=====================================================");
    $finish;
  end

  initial begin
    #200000;
    $display("FAIL [timeout]: watchdog fired");
    $display("TB_RESULT: FAIL (timeout)");
    $finish;
  end

endmodule

`default_nettype wire

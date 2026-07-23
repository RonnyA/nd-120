`timescale 1ns / 1ps

/**************************************************************************
** Exhaustive validation of CYC_CC_D against PAL_44601B.
**
** CYC_CC_D reproduces PAL_44601B's CC3..CC0 counter NEXT-state (the
** CCx_reg D inputs) combinationally. This checks it is EXACT: for every
** current cycle-control state (all 16 CC values), both current TERM
** values, and every combination of the 4 CC-relevant inputs
** (CGNTCACT_n, WAIT1, WAIT2, BRK_n), it verifies that each CCx_D equals
** the value PAL_44601B latches into CCx_reg on the next clock edge from
** that same state.  16 x 2 x 16 = 512 exhaustive checks.
**
** Method: force the PAL's CC/TERM registers to the test vector, read the
** mirror's prediction, release, clock once, read the PAL's updated CCx_reg.
** force/release is testbench-only; the PAL is not modified.
**
** Re-run (make test-ccd) if PAL_44601B.v ever changes.
***************************************************************************/

module CYC_CC_D_tb;

  reg CK;
  reg OE_n;
  reg DLY1_n, DLY0_n, CSDELAY0, WAIT1, WAIT2, CGNTCACT_n, HIT, BRK_n, SLOW_n, SHORT_n;

  wire CX_n, TERM_n, CC0_n, CC1_n, CC2_n, CC3_n;
  wire CC0_D, CC1_D, CC2_D, CC3_D;

  integer checks, errors;
  integer si, tv, iv;
  reg [3:0] s;
  reg [3:0] expected;   // {CC3_D,CC2_D,CC1_D,CC0_D}
  reg [3:0] actual;

  PAL_44601B uut (
    .CK(CK), .OE_n(OE_n),
    .DLY1_n(DLY1_n), .DLY0_n(DLY0_n), .CSDELAY0(CSDELAY0),
    .WAIT1(WAIT1), .WAIT2(WAIT2), .CGNTCACT_n(CGNTCACT_n),
    .HIT(HIT), .BRK_n(BRK_n), .SLOW_n(SLOW_n), .SHORT_n(SHORT_n),
    .CX_n(CX_n), .TERM_n(TERM_n),
    .CC0_n(CC0_n), .CC1_n(CC1_n), .CC2_n(CC2_n), .CC3_n(CC3_n)
  );

  CYC_CC_D dut (
    .CC0_n(CC0_n), .CC1_n(CC1_n), .CC2_n(CC2_n), .CC3_n(CC3_n), .TERM_n(TERM_n),
    .CGNTCACT_n(CGNTCACT_n), .WAIT1(WAIT1), .WAIT2(WAIT2), .BRK_n(BRK_n),
    .CC0_D(CC0_D), .CC1_D(CC1_D), .CC2_D(CC2_D), .CC3_D(CC3_D)
  );

  initial begin
    CK = 0;
    forever #10 CK = ~CK;
  end

  // Drive the 4 CC-relevant inputs; hold the TERM-only inputs benign.
  task set_inputs(input [3:0] c);
    begin
      CGNTCACT_n = c[0];
      WAIT1      = c[1];
      WAIT2      = c[2];
      BRK_n      = c[3];
      // not used by the CC equations - fixed benign
      SHORT_n = 1'b1; HIT = 1'b0; SLOW_n = 1'b1;
      DLY0_n = 1'b1; DLY1_n = 1'b1; CSDELAY0 = 1'b0;
    end
  endtask

  task check(input [3:0] state, input term_cur, input [3:0] combo);
    begin
      @(negedge CK);
      set_inputs(combo);
      force uut.CC0_reg  = state[0];
      force uut.CC1_reg  = state[1];
      force uut.CC2_reg  = state[2];
      force uut.CC3_reg  = state[3];
      force uut.TERM_reg = term_cur;
      #1;
      expected = {CC3_D, CC2_D, CC1_D, CC0_D};
      release uut.CC0_reg;
      release uut.CC1_reg;
      release uut.CC2_reg;
      release uut.CC3_reg;
      release uut.TERM_reg;
      @(posedge CK); #1;
      actual = {uut.CC3_reg, uut.CC2_reg, uut.CC1_reg, uut.CC0_reg};
      checks = checks + 1;
      if (actual !== expected) begin
        errors = errors + 1;
        $display("FAIL: state=%b TERM=%b (CGNTCACT_n=%b WAIT1=%b WAIT2=%b BRK_n=%b): mirror CC=%b PAL CC=%b",
                 state, term_cur, combo[0], combo[1], combo[2], combo[3], expected, actual);
      end
    end
  endtask

  initial begin
    checks = 0; errors = 0; OE_n = 1'b0;
    set_inputs(4'b0);

    $display("======================================================");
    $display("CYC_CC_D exhaustive validation vs PAL_44601B");
    $display("(all 16 CC states x 2 TERM x 16 CC-input combos)");
    $display("======================================================");

    for (si = 0; si < 16; si = si + 1) begin
      s = si[3:0];
      for (tv = 0; tv < 2; tv = tv + 1)
        for (iv = 0; iv < 16; iv = iv + 1)
          check(s, tv[0], iv[3:0]);
    end

    $display("------------------------------------------------------");
    $display("checks=%0d  errors=%0d", checks, errors);
    if (errors == 0)
      $display("RESULT: PASS - CYC_CC_D matches PAL_44601B CC next-state exactly");
    else
      $display("RESULT: FAIL - CYC_CC_D diverges from PAL_44601B in %0d case(s)", errors);
    $display("======================================================");

    if (errors != 0) $fatal(1, "CYC_CC_D mismatch");
    $finish;
  end

  initial begin
    #1000000;
    $display("FAIL [timeout]: watchdog fired");
    $fatal(1, "timeout");
  end

endmodule

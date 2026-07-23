`timescale 1ns / 1ps

/**************************************************************************
** Exhaustive validation of CYC_TERM_D against PAL_44601B.
**
** CYC_TERM_D reproduces PAL_44601B's TERM register NEXT-state (its D
** input) combinationally, so CYC_36 can build a phase-accurate clock
** enable. This testbench proves the mirror is EXACT: for every current
** cycle-control state (all 16 CC values), both current TERM values, and
** every combination of the 7 terminate-condition inputs, it checks that
**
**    CYC_TERM_D.TERM_D  ==  the value PAL_44601B latches into TERM_reg
**                           on the next clock edge from that same state.
**
** Method: force the PAL's CC/TERM registers to the test vector, read the
** mirror's prediction, release, clock once, and read the PAL's updated
** TERM_reg. force/release is a testbench-only construct - the PAL is not
** modified. 16 states x 2 TERM x 128 input combos = 4096 exhaustive checks.
**
** If PAL_44601B.v ever changes, re-run this (make test-cyctermd). Any
** mismatch means CYC_TERM_D.v must be updated to match the PAL.
***************************************************************************/

module CYC_TERM_D_tb;

  reg CK;
  reg OE_n;

  // PAL inputs
  reg DLY1_n, DLY0_n, CSDELAY0, WAIT1, WAIT2, CGNTCACT_n, HIT, BRK_n, SLOW_n, SHORT_n;

  // PAL outputs
  wire CX_n, TERM_n, CC0_n, CC1_n, CC2_n, CC3_n;

  // Mirror output
  wire TERM_D_mirror;

  integer checks;
  integer errors;
  integer si;       // state index 0..15
  integer tv;       // current TERM value 0..1
  integer iv;       // input combo 0..127
  reg [3:0] s;
  reg       expected;
  reg       actual;

  PAL_44601B uut (
    .CK(CK), .OE_n(OE_n),
    .DLY1_n(DLY1_n), .DLY0_n(DLY0_n), .CSDELAY0(CSDELAY0),
    .WAIT1(WAIT1), .WAIT2(WAIT2), .CGNTCACT_n(CGNTCACT_n),
    .HIT(HIT), .BRK_n(BRK_n), .SLOW_n(SLOW_n), .SHORT_n(SHORT_n),
    .CX_n(CX_n), .TERM_n(TERM_n),
    .CC0_n(CC0_n), .CC1_n(CC1_n), .CC2_n(CC2_n), .CC3_n(CC3_n)
  );

  // Mirror under test - fed the PAL's current (forced) outputs + the same inputs.
  CYC_TERM_D dut (
    .CC0_n(CC0_n), .CC1_n(CC1_n), .CC2_n(CC2_n), .CC3_n(CC3_n), .TERM_n(TERM_n),
    .SHORT_n(SHORT_n), .HIT(HIT), .BRK_n(BRK_n), .SLOW_n(SLOW_n),
    .DLY0_n(DLY0_n), .DLY1_n(DLY1_n), .CSDELAY0(CSDELAY0),
    .TERM_D(TERM_D_mirror)
  );

  initial begin
    CK = 0;
    forever #10 CK = ~CK;
  end

  // Drive the 7 TERM-relevant inputs from a combo index. WAIT*/CGNTCACT do not
  // affect the TERM equation, held benign.
  task set_inputs(input [6:0] c);
    begin
      SHORT_n  = c[0];
      HIT      = c[1];
      BRK_n    = c[2];
      SLOW_n   = c[3];
      DLY0_n   = c[4];
      DLY1_n   = c[5];
      CSDELAY0 = c[6];
      WAIT1 = 1'b0; WAIT2 = 1'b0; CGNTCACT_n = 1'b1;
    end
  endtask

  // Force the PAL to (state s, TERM tv), read mirror, release, clock, read PAL
  // next TERM_reg, compare.
  task check(input [3:0] state, input term_cur, input [6:0] combo);
    begin
      @(negedge CK);
      set_inputs(combo);
      force uut.CC0_reg  = state[0];
      force uut.CC1_reg  = state[1];
      force uut.CC2_reg  = state[2];
      force uut.CC3_reg  = state[3];
      force uut.TERM_reg = term_cur;
      #1;
      expected = TERM_D_mirror;         // mirror prediction from this (state,TERM,inputs)
      release uut.CC0_reg;
      release uut.CC1_reg;
      release uut.CC2_reg;
      release uut.CC3_reg;
      release uut.TERM_reg;
      @(posedge CK); #1;                // PAL latches TERM_reg <= f(state, inputs)
      actual = uut.TERM_reg;
      checks = checks + 1;
      if (actual !== expected) begin
        errors = errors + 1;
        $display("FAIL: state=%b TERM=%b combo=%b(SHORT_n=%b HIT=%b BRK_n=%b SLOW_n=%b DLY0_n=%b DLY1_n=%b CSDELAY0=%b): mirror=%b PAL=%b",
                 state, term_cur, combo, combo[0], combo[1], combo[2], combo[3], combo[4], combo[5], combo[6],
                 expected, actual);
      end
    end
  endtask

  initial begin
    checks = 0;
    errors = 0;
    OE_n   = 1'b0;
    set_inputs(7'b0);

    $display("======================================================");
    $display("CYC_TERM_D exhaustive validation vs PAL_44601B");
    $display("(all 16 CC states x 2 TERM x 128 input combos)");
    $display("======================================================");

    for (si = 0; si < 16; si = si + 1) begin
      s = si[3:0];
      for (tv = 0; tv < 2; tv = tv + 1) begin
        for (iv = 0; iv < 128; iv = iv + 1) begin
          check(s, tv[0], iv[6:0]);
        end
      end
    end

    $display("------------------------------------------------------");
    $display("checks=%0d  errors=%0d", checks, errors);
    if (errors == 0)
      $display("RESULT: PASS - CYC_TERM_D matches PAL_44601B TERM next-state exactly");
    else
      $display("RESULT: FAIL - CYC_TERM_D diverges from PAL_44601B in %0d case(s)", errors);
    $display("======================================================");

    if (errors != 0) $fatal(1, "CYC_TERM_D mismatch");
    $finish;
  end

  initial begin
    #2000000;
    $display("FAIL [timeout]: watchdog fired");
    $fatal(1, "timeout");
  end

endmodule

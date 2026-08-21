/****************************************************************************
** PAL_44404C_EN (14D, CYIN1 - cycle control input generator part 1) tb    **
**                                                                         **
** SPEC: DesignDocuments/PAL-Code/SRC/44404C.txt. The model is re-derived   **
** from that PALASM listing term by term; the Verilog is under test, and a  **
** disagreement is a FINDING rather than a licence to edit the RTL.         **
**                                                                         **
**   IF (VCC) DLY1 = CSDELAY1 * /LBA3 * LBA1 * LBA0 + RRF * SLCOND          **
**   NOWRIT := /CSALUM1 * /CSALUI8 * /CSALUI7                               **
**           + /CSALUM0 * /CSALUI8 * /CSALUI7                               **
**                                                                         **
** DLSHADOW IS NOT IN THIS LISTING. It belongs to revision 44404D, whose    **
** listing is not in DesignDocuments/PAL-Code/SRC, and PAL_44404C.v records **
** its implementation (a one-clock delay of LSHADOW) as an explicit GUESS.  **
** It is left unconnected on the board - CYC_36.v:485 - so it drives        **
** nothing. It is tested here AS IMPLEMENTED, under a name that says so     **
** (DLSHADOW_AS_IMPLEMENTED_NOT_IN_LISTING), so that a change is noticed;   **
** passing this check is NOT evidence that the guess is right.              **
**                                                                         **
** COVERAGE: EXHAUSTIVE. 12 input pins x 2 state bits = 16384 combinations, **
** all applied to BOTH build variants in one loop:                          **
**   USE_ENABLE=1 - posedge sysclk + EN (the FPGA clock-enable conversion)  **
**   USE_ENABLE=0 - the original PAL_44404C on posedge CLK                  **
** Both registers are FORCED before every vector, so the whole transition   **
** function is exercised.                                                   **
**                                                                         **
** OUTPUT ENABLE: /NOWRIT sits on pin 17 and DLSHADOW on the neighbouring   **
** registered pin, both /OE controlled; /DLY1 sits on pin 12 with "IF       **
** (VCC)" and is always enabled. The RTL matches. A disabled output drives  **
** 0, never z - and on the active-low /NOWRIT pin that reads as NOWRIT      **
** ASSERTED, which is checked explicitly.                                   **
**                                                                         **
** A flipped term is caught: writing LBA3 instead of /LBA3 in DLY1 inverts  **
** the output on every vector where CSDELAY1 * LBA1 * LBA0 holds - 2^9 of   **
** them in this sweep.                                                      **
**                                                                         **
** Run: cd Verilog/PAL/sim && make test-pal44404c                           **
**                                                                         **
** Last reviewed: 20-AUG-2026                                               **
** Ronny Hansen                                                             **
*****************************************************************************/
`timescale 1ns / 1ps
`default_nettype none

module PAL_44404C_EN_tb;

  reg sysclk, EN, CLK, OE_n;
  reg CSDELAY1, CSALUM1, CSALUM0, CSALUI8, CSALUI7, LBA3, LBA1, LBA0;
  reg RRF_n, LSHADOW, SLCOND_n;

  wire e_NOWRIT_n, e_DLSHADOW, e_DLY1_n;
  wire o_NOWRIT_n, o_DLSHADOW, o_DLY1_n;

  integer checks = 0, errors = 0, vec, st, dumped = 0;

  PAL_44404C_EN #(.USE_ENABLE(1)) DUT_EN (
      .sysclk(sysclk), .EN(EN), .CLK(1'b0), .OE_n(OE_n),
      .CSDELAY1(CSDELAY1), .CSALUM1(CSALUM1), .CSALUM0(CSALUM0),
      .CSALUI8(CSALUI8), .CSALUI7(CSALUI7),
      .LBA3(LBA3), .LBA1(LBA1), .LBA0(LBA0),
      .NOWRIT_n(e_NOWRIT_n), .DLSHADOW(e_DLSHADOW),
      .RRF_n(RRF_n), .LSHADOW(LSHADOW), .SLCOND_n(SLCOND_n), .DLY1_n(e_DLY1_n)
  );

  PAL_44404C_EN #(.USE_ENABLE(0)) DUT_OR (
      .sysclk(1'b0), .EN(1'b0), .CLK(CLK), .OE_n(OE_n),
      .CSDELAY1(CSDELAY1), .CSALUM1(CSALUM1), .CSALUM0(CSALUM0),
      .CSALUI8(CSALUI8), .CSALUI7(CSALUI7),
      .LBA3(LBA3), .LBA1(LBA1), .LBA0(LBA0),
      .NOWRIT_n(o_NOWRIT_n), .DLSHADOW(o_DLSHADOW),
      .RRF_n(RRF_n), .LSHADOW(LSHADOW), .SLCOND_n(SLCOND_n), .DLY1_n(o_DLY1_n)
  );

  // ---- golden model from the listing ------------------------------------
  wire g_RRF = ~RRF_n, g_SLCOND = ~SLCOND_n;

  reg  r_nowrit, r_dlshadow;

  wire g_nowrit_next = (~CSALUM1 & ~CSALUI8 & ~CSALUI7)
                     | (~CSALUM0 & ~CSALUI8 & ~CSALUI7);
  wire g_dlshadow_next = LSHADOW;   // 44404D guess, not in the 44404C listing

  wire g_DLY1_n = ~( (CSDELAY1 & ~LBA3 & LBA1 & LBA0) | (g_RRF & g_SLCOND) );

  task chk (input [127:0] name, input got, input exp);
    begin
      checks = checks + 1;
      if (got !== exp) begin
        errors = errors + 1;
        if (errors < 12)
          $display("FAIL %0s: got=%b exp=%b | nowrit=%b dlsh=%b OE_n=%b CSDELAY1=%b CSALUM1=%b CSALUM0=%b CSALUI8=%b CSALUI7=%b LBA3=%b LBA1=%b LBA0=%b RRF_n=%b LSHADOW=%b SLCOND_n=%b",
                   name, got, exp, r_nowrit, r_dlshadow, OE_n, CSDELAY1,
                   CSALUM1, CSALUM0, CSALUI8, CSALUI7, LBA3, LBA1, LBA0,
                   RRF_n, LSHADOW, SLCOND_n);
      end
    end
  endtask

  task set_state (input n, input d);
    begin
      r_nowrit = n; r_dlshadow = d;
      DUT_EN.gen_enable.NOWRIT       = n;
      DUT_EN.gen_enable.DLSHADOW_reg = d;
      DUT_OR.gen_orig.PAL.NOWRIT       = n;
      DUT_OR.gen_orig.PAL.DLSHADOW_reg = d;
      #1;
    end
  endtask

  task tick;
    begin
      sysclk = 1'b0; CLK = 1'b0; #1;
      sysclk = 1'b1; CLK = 1'b1; #1;
      sysclk = 1'b0; CLK = 1'b0; #1;
    end
  endtask

  initial begin
    $dumpfile("PAL_44404C_EN_tb.vcd");
    $dumpvars(0, PAL_44404C_EN_tb);
  end

  initial begin
    sysclk = 1'b0; CLK = 1'b0; EN = 1'b1;
    r_nowrit = 0; r_dlshadow = 0;
    $display("=====================================================");
    $display(" PAL_44404C_EN (CYIN1) exhaustive golden testbench");
    $display(" 12 input pins x 2 state bits = 16384 combinations");
    $display(" checked for USE_ENABLE=1 and USE_ENABLE=0");
    $display("=====================================================");

    for (st = 0; st < 4; st = st + 1) begin
      for (vec = 0; vec < 4096; vec = vec + 1) begin
        {CSDELAY1, CSALUM1, CSALUM0, CSALUI8, CSALUI7, LBA3, LBA1, LBA0,
         RRF_n, LSHADOW, SLCOND_n, OE_n} = vec[11:0];
        set_state(st[0], st[1]);

        // pin 12 (/DLY1) is always enabled
        chk("EN1_DLY1_n", e_DLY1_n, g_DLY1_n);
        chk("OR0_DLY1_n", o_DLY1_n, g_DLY1_n);

        if (OE_n === 1'b0) begin
          chk("EN1_NOWRIT_n", e_NOWRIT_n, ~r_nowrit);
          chk("OR0_NOWRIT_n", o_NOWRIT_n, ~r_nowrit);
          chk("DLSHADOW_AS_IMPLEMENTED_NOT_IN_LISTING_EN1", e_DLSHADOW, r_dlshadow);
          chk("DLSHADOW_AS_IMPLEMENTED_NOT_IN_LISTING_OR0", o_DLSHADOW, r_dlshadow);
        end else begin
          chk("OEOFF_EN1_NOWRIT_n", e_NOWRIT_n, 1'b0);
          chk("OEOFF_OR0_NOWRIT_n", o_NOWRIT_n, 1'b0);
          chk("OEOFF_EN1_DLSHADOW", e_DLSHADOW, 1'b0);
          chk("OEOFF_OR0_DLSHADOW", o_DLSHADOW, 1'b0);
        end

        tick;
        if (OE_n === 1'b0) begin
          chk("EN1_NOWRIT_n_next", e_NOWRIT_n, ~g_nowrit_next);
          chk("OR0_NOWRIT_n_next", o_NOWRIT_n, ~g_nowrit_next);
          chk("EN1_DLSHADOW_next", e_DLSHADOW, g_dlshadow_next);
          chk("OR0_DLSHADOW_next", o_DLSHADOW, g_dlshadow_next);
        end

        dumped = dumped + 1;
        if (dumped == 40) $dumpoff;
      end
    end

    // ---- named property checks -----------------------------------------
    OE_n = 1'b0;

    // 1. DLY1 first term needs /LBA3 - LBA3 high must kill it
    CSDELAY1 = 1'b1; LBA3 = 1'b0; LBA1 = 1'b1; LBA0 = 1'b1;
    RRF_n = 1'b1; SLCOND_n = 1'b1; #1;
    checks = checks + 1;
    if (e_DLY1_n !== 1'b0) begin
      errors = errors + 1;
      $display("FAIL DLY1_LBA_TERM: e_DLY1_n=%b, must assert on CSDELAY1 * /LBA3 * LBA1 * LBA0", e_DLY1_n);
    end
    LBA3 = 1'b1; #1;
    checks = checks + 1;
    if (e_DLY1_n !== 1'b1) begin
      errors = errors + 1;
      $display("FAIL DLY1_LBA3: e_DLY1_n=%b, LBA3 must kill the term", e_DLY1_n);
    end

    // 2. DLY1 second term needs BOTH RRF and SLCOND
    CSDELAY1 = 1'b0; RRF_n = 1'b0; SLCOND_n = 1'b0; #1;
    checks = checks + 1;
    if (e_DLY1_n !== 1'b0) begin
      errors = errors + 1;
      $display("FAIL DLY1_RRF_SLCOND: e_DLY1_n=%b, must assert", e_DLY1_n);
    end
    SLCOND_n = 1'b1; #1;
    checks = checks + 1;
    if (e_DLY1_n !== 1'b1) begin
      errors = errors + 1;
      $display("FAIL DLY1_RRF_ALONE: e_DLY1_n=%b, RRF alone must not assert DLY1", e_DLY1_n);
    end

    // 3. NOWRIT: CSALUI8 or CSALUI7 high kills BOTH product terms
    CSALUM1 = 1'b0; CSALUM0 = 1'b0; CSALUI8 = 1'b0; CSALUI7 = 1'b0;
    set_state(1'b0, 1'b0);
    tick;
    checks = checks + 1;
    if (e_NOWRIT_n !== 1'b0) begin
      errors = errors + 1;
      $display("FAIL NOWRIT_SET: e_NOWRIT_n=%b, must assert", e_NOWRIT_n);
    end
    CSALUI8 = 1'b1;
    set_state(1'b0, 1'b0);
    tick;
    checks = checks + 1;
    if (e_NOWRIT_n !== 1'b1) begin
      errors = errors + 1;
      $display("FAIL NOWRIT_CSALUI8: e_NOWRIT_n=%b, CSALUI8 must kill both terms", e_NOWRIT_n);
    end
    CSALUI8 = 1'b0; CSALUI7 = 1'b1;
    set_state(1'b0, 1'b0);
    tick;
    checks = checks + 1;
    if (e_NOWRIT_n !== 1'b1) begin
      errors = errors + 1;
      $display("FAIL NOWRIT_CSALUI7: e_NOWRIT_n=%b, CSALUI7 must kill both terms", e_NOWRIT_n);
    end
    //    and the two ALU-mode literals are an OR, not an AND: one low is enough
    CSALUI7 = 1'b0; CSALUM1 = 1'b1; CSALUM0 = 1'b0;
    set_state(1'b0, 1'b0);
    tick;
    checks = checks + 1;
    if (e_NOWRIT_n !== 1'b0) begin
      errors = errors + 1;
      $display("FAIL NOWRIT_OR: e_NOWRIT_n=%b, /CSALUM0 term alone must assert", e_NOWRIT_n);
    end

    // 4. the clock enable really gates the USE_ENABLE=1 registers
    CSALUM1 = 1'b0; CSALUM0 = 1'b0; CSALUI8 = 1'b0; CSALUI7 = 1'b0;
    set_state(1'b0, 1'b0);
    EN = 1'b0; sysclk = 1'b1; #1; sysclk = 1'b0; #1;
    checks = checks + 1;
    if (e_NOWRIT_n !== 1'b1) begin
      errors = errors + 1;
      $display("FAIL EN_GATE: e_NOWRIT_n=%b, EN low must block the capture", e_NOWRIT_n);
    end
    EN = 1'b1; tick;
    checks = checks + 1;
    if (e_NOWRIT_n !== 1'b0) begin
      errors = errors + 1;
      $display("FAIL EN_RELEASE: e_NOWRIT_n=%b, EN high must capture", e_NOWRIT_n);
    end

    // 5. nothing floats
    checks = checks + 1;
    if (^{e_NOWRIT_n, e_DLSHADOW, e_DLY1_n} === 1'bx) begin
      errors = errors + 1;
      $display("FAIL NO_Z: an output is x/z");
    end

    $display("-----------------------------------------------------");
    $display(" checks run : %0d", checks);
    $display(" failures   : %0d", errors);
    if (errors == 0) $display("TB_RESULT: PASS");
    else             $display("TB_RESULT: FAIL");
    $display("=====================================================");
    $finish;
  end

endmodule

`default_nettype wire

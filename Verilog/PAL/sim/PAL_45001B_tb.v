/****************************************************************************
** PAL_45001B (8D, BPAR - bus parity error status) golden testbench        **
**                                                                         **
** SPEC: DesignDocuments/PAL-Code/SRC/45001B.txt. The model is re-derived   **
** from that PALASM listing product term by product term; the Verilog is    **
** under test, and a disagreement is a FINDING to report rather than fix.   **
**                                                                         **
**   IF (/TEST) /SPES = /BDRY50 * /BDRY75 + BDRY50 * BDRY75                 **
**                    + /BDRY50 * BDRY75 + BLOCK25 + EPEA + EPES + MR       **
**   IF (/TEST) /SPEA = /DBAPR + BLOCK25 + EPEA + MR                        **
**   IF (/TEST) BLOCK = BDRY50 * /BDRY75 * /EPEA * /EPES * MOR25   * /MR    **
**                    + BDRY50 * /BDRY75 * /EPEA * /EPES * BPERR50 * /MR    **
**                    + BLOCK * /EPEA * /MR                                 **
**   IF (/TEST) PARERR = BDRY50 * /BDRY75 * BPERR50 * /MR + LERR            **
**   IF (/TEST) RERR = BPERR50 * /MR + RERR * /LPERR * /MR + MOR25 * /MR    **
**                                                                         **
** SPES fires only on the ONE BDRY50/BDRY75 combination the sum leaves out, **
** BDRY50 * /BDRY75 - the 50/75 ns window where the parity result is valid. **
** Writing any of those three /SPES terms wrong widens or closes that       **
** window silently, which is why all four combinations are swept.           **
**                                                                         **
** DBAPR PIN POLARITY: the listing's pin list has DBAPR ACTIVE HIGH (the    **
** 1987 note "NEED TO USE DELAYED BAPR INSTEAD OF /BAPR ... POLARITY        **
** CHANGE"). The port name DBAPR_n is a misnomer - it carries the           **
** active-high delayed BAPR from 44304E - so /DBAPR in the equation is the  **
** port INVERTED, which is what the model uses.                             **
**                                                                         **
** BLOCK and RERR are self-referencing 16L8 terms - feedback latches:       **
**   BLOCK: HOLD = /EPEA * /MR        RERR: HOLD = /LPERR * /MR             **
**                                                                         **
** COVERAGE: EXHAUSTIVE. 12 input pins x 2 state bits = 16384 combinations, **
** all applied, with DUT.BLOCK_reg and DUT.RERR_reg FORCED before each      **
** vector so the whole transition function is exercised.                    **
**                                                                         **
** BUILD MODE: default (edge-triggered) build - state is forced and CK is   **
** pulsed. Do not compile with USE_TRANSPARENT_LATCHES. Both RTL branches   **
** carry the same next-state expressions.                                   **
**                                                                         **
** TEST MODE / TRI-STATE: no /OE pin; TEST is the listing's output-disable  **
** term. The RTL drives each pin to its INACTIVE level, never z - and that  **
** level differs per pin because the polarities differ: SPEA and SPES are   **
** active-high pins and go to 0, PARERR_n / BLOCK_n / RERR_n are active-low **
** and go to 1. Both are checked on every TEST=1 vector.                    **
**                                                                         **
** Run: cd Verilog/PAL/sim && make test-pal45001b                           **
**                                                                         **
** Last reviewed: 20-AUG-2026                                               **
** Ronny Hansen                                                             **
*****************************************************************************/
`timescale 1ns / 1ps
`default_nettype none

module PAL_45001B_tb;

  reg CK, sys_rst_n;
  reg BDRY50_n, BDRY75_n, BLOCK25_n, BPERR50_n, DBAPR_n, MOR25_n;
  reg LPERR_n, MR_n, EPES_n, EPEA_n, TEST, LERR_n;

  wire SPEA, SPES, BLOCK_n, PARERR_n, RERR_n;

  integer checks = 0, errors = 0, vec, st, dumped = 0;

  PAL_45001B DUT (
      .CK(CK), .sys_rst_n(sys_rst_n),
      .BDRY50_n(BDRY50_n), .BDRY75_n(BDRY75_n), .BLOCK25_n(BLOCK25_n),
      .BPERR50_n(BPERR50_n), .DBAPR_n(DBAPR_n), .MOR25_n(MOR25_n),
      .LPERR_n(LPERR_n), .MR_n(MR_n), .EPES_n(EPES_n), .EPEA_n(EPEA_n),
      .SPEA(SPEA), .SPES(SPES),
      .BLOCK_n(BLOCK_n), .PARERR_n(PARERR_n), .RERR_n(RERR_n),
      .TEST(TEST), .LERR_n(LERR_n)
  );

  // ---- golden model from the listing ------------------------------------
  wire g_BDRY50 = ~BDRY50_n, g_BDRY75 = ~BDRY75_n, g_BLOCK25 = ~BLOCK25_n;
  wire g_BPERR50 = ~BPERR50_n, g_MOR25 = ~MOR25_n, g_MR = ~MR_n;
  wire g_EPES = ~EPES_n, g_EPEA = ~EPEA_n, g_LERR = ~LERR_n;
  wire g_DBAPR = ~DBAPR_n;                   // port is a misnomer, see header

  reg  r_block, r_rerr;

  wire g_SPES = ~( (BDRY50_n & BDRY75_n)
                 | (g_BDRY50 & g_BDRY75)
                 | (BDRY50_n & g_BDRY75)
                 | g_BLOCK25 | g_EPEA | g_EPES | g_MR );

  wire g_SPEA = ~( g_DBAPR | g_BLOCK25 | g_EPEA | g_MR );

  wire g_PARERR_n = ~( (g_BDRY50 & BDRY75_n & g_BPERR50 & MR_n) | g_LERR );

  wire g_block_set  = (g_BDRY50 & BDRY75_n & EPEA_n & EPES_n & g_MOR25   & MR_n)
                    | (g_BDRY50 & BDRY75_n & EPEA_n & EPES_n & g_BPERR50 & MR_n);
  wire g_block_hold = EPEA_n & MR_n;
  wire g_block_next = g_block_set | (r_block & g_block_hold);

  wire g_rerr_set   = (g_BPERR50 & MR_n) | (g_MOR25 & MR_n);
  wire g_rerr_hold  = LPERR_n & MR_n;
  wire g_rerr_next  = g_rerr_set | (r_rerr & g_rerr_hold);

  task chk (input [127:0] name, input got, input exp);
    begin
      checks = checks + 1;
      if (got !== exp) begin
        errors = errors + 1;
        if (errors < 12)
          $display("FAIL %0s: got=%b exp=%b | block=%b rerr=%b TEST=%b BDRY50_n=%b BDRY75_n=%b BLOCK25_n=%b BPERR50_n=%b DBAPR_n=%b MOR25_n=%b LPERR_n=%b MR_n=%b EPES_n=%b EPEA_n=%b LERR_n=%b",
                   name, got, exp, r_block, r_rerr, TEST, BDRY50_n, BDRY75_n,
                   BLOCK25_n, BPERR50_n, DBAPR_n, MOR25_n, LPERR_n, MR_n,
                   EPES_n, EPEA_n, LERR_n);
      end
    end
  endtask

  task set_state (input b, input r);
    begin
      r_block = b; r_rerr = r;
      DUT.BLOCK_reg = b; DUT.RERR_reg = r;
      #1;
    end
  endtask

  task tick; begin CK = 1'b0; #1; CK = 1'b1; #1; CK = 1'b0; #1; end endtask

  initial begin
    $dumpfile("PAL_45001B_tb.vcd");
    $dumpvars(0, PAL_45001B_tb);
  end

  initial begin
    CK = 1'b0; sys_rst_n = 1'b1; r_block = 0; r_rerr = 0;
    $display("=====================================================");
    $display(" PAL_45001B (BPAR) exhaustive golden testbench");
    $display(" 12 input pins x 2 state bits = 16384 combinations");
    $display("=====================================================");

    for (st = 0; st < 4; st = st + 1) begin
      for (vec = 0; vec < 4096; vec = vec + 1) begin
        {BDRY50_n, BDRY75_n, BLOCK25_n, BPERR50_n, DBAPR_n, MOR25_n,
         LPERR_n, MR_n, EPES_n, EPEA_n, TEST, LERR_n} = vec[11:0];
        set_state(st[0], st[1]);

        if (TEST === 1'b0) begin
          chk("SPES",     SPES,     g_SPES);
          chk("SPEA",     SPEA,     g_SPEA);
          chk("PARERR_n", PARERR_n, g_PARERR_n);
          chk("BLOCK_n",  BLOCK_n,  ~r_block);
          chk("RERR_n",   RERR_n,   ~r_rerr);
        end else begin
          // disabled -> inactive level, per pin polarity, never z
          chk("TEST_SPES",     SPES,     1'b0);
          chk("TEST_SPEA",     SPEA,     1'b0);
          chk("TEST_PARERR_n", PARERR_n, 1'b1);
        end

        tick;
        if (TEST === 1'b0) begin
          chk("BLOCK_n_next", BLOCK_n, ~g_block_next);
          chk("RERR_n_next",  RERR_n,  ~g_rerr_next);
        end else begin
          // TEST clears both feedback latches at the edge
          chk("TEST_BLOCK_n_next", BLOCK_n, 1'b1);
          chk("TEST_RERR_n_next",  RERR_n,  1'b1);
        end

        dumped = dumped + 1;
        if (dumped == 40) $dumpoff;
      end
    end

    // ---- named property checks -----------------------------------------
    TEST = 1'b0;

    // 1. async reset clears both latches
    set_state(1'b1, 1'b1);
    sys_rst_n = 1'b0; #1;
    checks = checks + 1;
    if (BLOCK_n !== 1'b1 || RERR_n !== 1'b1) begin
      errors = errors + 1;
      $display("FAIL RESET: BLOCK_n=%b RERR_n=%b, reset must clear both", BLOCK_n, RERR_n);
    end
    sys_rst_n = 1'b1; #1;

    // 2. THE BDRY WINDOW: /SPES leaves out exactly one of the four BDRY
    //    combinations, so SPES may be active for BDRY50 * /BDRY75 and for
    //    nothing else.
    BLOCK25_n = 1'b1; EPEA_n = 1'b1; EPES_n = 1'b1; MR_n = 1'b1;
    for (vec = 0; vec < 4; vec = vec + 1) begin
      {BDRY50_n, BDRY75_n} = ~vec[1:0];
      #1;
      checks = checks + 1;
      if ((SPES === 1'b1) !== (vec == 2'b10)) begin
        errors = errors + 1;
        $display("FAIL SPES_WINDOW: BDRY50=%b BDRY75=%b SPES=%b",
                 ~BDRY50_n, ~BDRY75_n, SPES);
      end
    end

    // 3. THE 45001B AUDIT FINDS. BLOCK25 must STOP the strobes (the literal
    //    is BLOCK25, not /BLOCK25), and /SPEA needs the ACTIVE-HIGH DBAPR.
    {BDRY50_n, BDRY75_n} = 2'b01;                 // the SPES window
    BLOCK25_n = 1'b0;                             // BLOCK25 ACTIVE
    #1;
    checks = checks + 1;
    if (SPES !== 1'b0) begin
      errors = errors + 1;
      $display("FAIL SPES_BLOCK25: SPES=%b, an active BLOCK25 must stop the strobe", SPES);
    end
    BLOCK25_n = 1'b1;
    DBAPR_n = 1'b1;                               // port carries DBAPR high
    #1;
    checks = checks + 1;
    if (SPEA !== 1'b1) begin
      errors = errors + 1;
      $display("FAIL SPEA_DBAPR_HIGH: SPEA=%b, DBAPR high must let SPEA fire", SPEA);
    end
    DBAPR_n = 1'b0;
    #1;
    checks = checks + 1;
    if (SPEA !== 1'b0) begin
      errors = errors + 1;
      $display("FAIL SPEA_DBAPR_LOW: SPEA=%b, /DBAPR must stop SPEA", SPEA);
    end
    DBAPR_n = 1'b1;

    // 4. BLOCK freezes on a REMOTE error and is released only by a PEA read
    BDRY50_n = 1'b0; BDRY75_n = 1'b1; EPEA_n = 1'b1; EPES_n = 1'b1;
    MOR25_n = 1'b1; BPERR50_n = 1'b0; MR_n = 1'b1;
    set_state(1'b0, 1'b0);
    tick;
    checks = checks + 1;
    if (BLOCK_n !== 1'b0) begin
      errors = errors + 1;
      $display("FAIL BLOCK_SET: BLOCK_n=%b, a bus parity error must block", BLOCK_n);
    end
    BPERR50_n = 1'b1;
    set_state(1'b1, 1'b0);
    tick;
    checks = checks + 1;
    if (BLOCK_n !== 1'b0) begin
      errors = errors + 1;
      $display("FAIL BLOCK_HOLD: BLOCK_n=%b, BLOCK must hold", BLOCK_n);
    end
    EPEA_n = 1'b0;                                 // PEA read
    set_state(1'b1, 1'b0);
    tick;
    checks = checks + 1;
    if (BLOCK_n !== 1'b1) begin
      errors = errors + 1;
      $display("FAIL BLOCK_RELEASE: BLOCK_n=%b, a PEA read must release BLOCK", BLOCK_n);
    end
    EPEA_n = 1'b1;

    // 5. RERR: set on a bus error or on MOR, released by a LOCAL error
    BPERR50_n = 1'b0; MOR25_n = 1'b1; LPERR_n = 1'b1;
    set_state(1'b0, 1'b0);
    tick;
    checks = checks + 1;
    if (RERR_n !== 1'b0) begin
      errors = errors + 1;
      $display("FAIL RERR_BPERR: RERR_n=%b, a bus parity error must set RERR", RERR_n);
    end
    BPERR50_n = 1'b1; MOR25_n = 1'b0;
    set_state(1'b0, 1'b0);
    tick;
    checks = checks + 1;
    if (RERR_n !== 1'b0) begin
      errors = errors + 1;
      $display("FAIL RERR_MOR: RERR_n=%b, MOR must set RERR too", RERR_n);
    end
    MOR25_n = 1'b1; LPERR_n = 1'b0;                // local error takes over
    set_state(1'b1, 1'b1);
    tick;
    checks = checks + 1;
    if (RERR_n !== 1'b1) begin
      errors = errors + 1;
      $display("FAIL RERR_LOCAL: RERR_n=%b, a local error must clear RERR", RERR_n);
    end
    LPERR_n = 1'b1;

    // 6. PARERR takes a LOCAL error straight through, with no BDRY window
    BDRY50_n = 1'b1; BDRY75_n = 1'b1; BPERR50_n = 1'b1; MR_n = 1'b1;
    LERR_n = 1'b0; #1;
    checks = checks + 1;
    if (PARERR_n !== 1'b0) begin
      errors = errors + 1;
      $display("FAIL PARERR_LERR: PARERR_n=%b, LERR must reach PARERR", PARERR_n);
    end
    LERR_n = 1'b1; #1;
    checks = checks + 1;
    if (PARERR_n !== 1'b1) begin
      errors = errors + 1;
      $display("FAIL PARERR_IDLE: PARERR_n=%b, must be inactive", PARERR_n);
    end

    // 7. nothing floats
    checks = checks + 1;
    if (^{SPEA, SPES, BLOCK_n, PARERR_n, RERR_n} === 1'bx) begin
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

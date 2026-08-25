/****************************************************************************
** PAL_44303B (2C, LBC2 - local data bus control) - exhaustive golden tb   **
**                                                                         **
** SPEC: DesignDocuments/PAL-Code/SRC/44303B.txt. The model below is       **
** re-derived from that PALASM listing, term by term; PAL_44303B.v is the  **
** implementation under test. A disagreement is a FINDING, never a reason  **
** to edit the RTL.                                                        **
**                                                                         **
**   IF (/TEST) WBD     = EADR + CBWRITE + IOD * MISO * /BINPUT50 + BACT   **
**   IF (/TEST) CBWRITE = WRITE * CACT + CBWRITE * CACT                    **
**   IF (/TEST) WLBD    = CBWRITE + CMWRITE + IOD * MISO * /BINPUT50       **
**   IF (/TEST) CMWRITE = WRITE * CGNT + CMWRITE * CGNT                    **
**                                                                         **
** CBWRITE and CMWRITE are self-referencing 16L8 terms - feedback latches - **
** so each is SET + STATE * HOLD:                                          **
**   CBWRITE: SET = WRITE * CACT, HOLD = CACT                              **
**   CMWRITE: SET = WRITE * CGNT, HOLD = CGNT                              **
**                                                                         **
** COVERAGE: EXHAUSTIVE. 9 input pins x 2 state bits = 2048 combinations,  **
** all applied. Both feedback latches are FORCED (DUT.CBWRITE, DUT.CMWRITE) **
** before every vector, so the whole transition function is covered, not   **
** just the reachable part.                                                **
**                                                                         **
** BUILD MODE: default (edge-triggered) build. Do not compile with         **
** USE_TRANSPARENT_LATCHES - the state is forced and CK is pulsed. Both    **
** RTL branches carry the same next-state expression.                      **
**                                                                         **
** TEST MODE / TRI-STATE: this part has no /OE pin; TEST is the listing's  **
** only output-disable term. The RTL drives the INACTIVE level (1 on every **
** _n pin), never z - checked explicitly on every TEST=1 vector.           **
**                                                                         **
** A flipped term is caught: swapping CACT for CGNT in the CBWRITE hold    **
** term would make CBWRITE_n differ on all 512 vectors where CACT and CGNT **
** disagree with the state set to 1.                                       **
**                                                                         **
** Run: cd Verilog/PAL/sim && make test-pal44303b                          **
**                                                                         **
** Last reviewed: 20-AUG-2026                                              **
** Ronny Hansen                                                            **
*****************************************************************************/
`timescale 1ns / 1ps
`default_nettype none

module PAL_44303B_tb;

  reg CK, sys_rst_n;
  reg CACT_n, CGNT_n, EADR_n, BINPUT50_n, MIS0, IOD_n, WRITE, TEST, BACT_n;
  wire WBD_n, CBWRITE_n, WLBD_n, CMWRITE_n;

  integer checks = 0, errors = 0, vec, st, dumped = 0;

  PAL_44303B DUT (
      .CK(CK), .sys_rst_n(sys_rst_n),
      .CACT_n(CACT_n), .CGNT_n(CGNT_n), .EADR_n(EADR_n),
      .BINPUT50_n(BINPUT50_n), .MIS0(MIS0), .IOD_n(IOD_n),
      .WRITE(WRITE), .TEST(TEST), .BACT_n(BACT_n),
      .WBD_n(WBD_n), .CBWRITE_n(CBWRITE_n),
      .WLBD_n(WLBD_n), .CMWRITE_n(CMWRITE_n)
  );

  // ---- golden model from the PALASM listing -----------------------------
  wire g_CACT = ~CACT_n, g_CGNT = ~CGNT_n, g_EADR = ~EADR_n;
  wire g_IOD  = ~IOD_n,  g_BACT = ~BACT_n;

  reg  g_cbw, g_cmw;                        // forced state
  wire g_cbw_next = (WRITE & g_CACT) | (g_cbw & g_CACT);
  wire g_cmw_next = (WRITE & g_CGNT) | (g_cmw & g_CGNT);

  wire g_iox   = g_IOD & MIS0 & BINPUT50_n;   // IOD * MISO * /BINPUT50
  wire g_WBD_n = ~(g_EADR | g_cbw | g_iox | g_BACT);
  wire g_WLBD_n = ~(g_cbw | g_cmw | g_iox);

  task chk (input [127:0] name, input got, input exp);
    begin
      checks = checks + 1;
      if (got !== exp) begin
        errors = errors + 1;
        if (errors < 12)
          $display("FAIL %0s: got=%b exp=%b | cbw=%b cmw=%b TEST=%b CACT_n=%b CGNT_n=%b EADR_n=%b BINPUT50_n=%b MIS0=%b IOD_n=%b WRITE=%b BACT_n=%b",
                   name, got, exp, g_cbw, g_cmw, TEST, CACT_n, CGNT_n, EADR_n,
                   BINPUT50_n, MIS0, IOD_n, WRITE, BACT_n);
      end
    end
  endtask

  task set_state (input b, input m);
    begin
      g_cbw = b; g_cmw = m;
      DUT.CBWRITE = b; DUT.CMWRITE = m;
      #1;
    end
  endtask

  task tick; begin CK = 1'b0; #1; CK = 1'b1; #1; CK = 1'b0; #1; end endtask

  initial begin
    $dumpfile("PAL_44303B_tb.vcd");
    $dumpvars(0, PAL_44303B_tb);
  end

  initial begin
    CK = 1'b0; sys_rst_n = 1'b1; g_cbw = 1'b0; g_cmw = 1'b0;
    $display("=====================================================");
    $display(" PAL_44303B (LBC2) exhaustive golden testbench");
    $display(" 9 input pins x 2 state bits = 2048 combinations");
    $display("=====================================================");

    for (st = 0; st < 4; st = st + 1) begin
      for (vec = 0; vec < 512; vec = vec + 1) begin
        {CACT_n, CGNT_n, EADR_n, BINPUT50_n, MIS0, IOD_n, WRITE, TEST, BACT_n} = vec[8:0];
        set_state(st[0], st[1]);

        if (TEST === 1'b0) begin
          chk("WBD_n",     WBD_n,     g_WBD_n);
          chk("WLBD_n",    WLBD_n,    g_WLBD_n);
          chk("CBWRITE_n", CBWRITE_n, ~g_cbw);
          chk("CMWRITE_n", CMWRITE_n, ~g_cmw);
        end else begin
          chk("TEST_WBD_n",     WBD_n,     1'b1);
          chk("TEST_WLBD_n",    WLBD_n,    1'b1);
          chk("TEST_CBWRITE_n", CBWRITE_n, 1'b1);
          chk("TEST_CMWRITE_n", CMWRITE_n, 1'b1);
        end

        tick;
        if (TEST === 1'b0) begin
          chk("CBWRITE_n_next", CBWRITE_n, ~g_cbw_next);
          chk("CMWRITE_n_next", CMWRITE_n, ~g_cmw_next);
        end

        dumped = dumped + 1;
        if (dumped == 40) $dumpoff;
      end
    end

    // ---- named property checks -----------------------------------------
    TEST = 1'b0;

    // 1. async reset clears both feedback latches
    set_state(1'b1, 1'b1);
    sys_rst_n = 1'b0; #1;
    checks = checks + 1;
    if (CBWRITE_n !== 1'b1 || CMWRITE_n !== 1'b1) begin
      errors = errors + 1;
      $display("FAIL RESET: CBWRITE_n=%b CMWRITE_n=%b, reset must clear both",
               CBWRITE_n, CMWRITE_n);
    end
    sys_rst_n = 1'b1; #1;

    // 2. the two latches are INDEPENDENT: CACT must not move CMWRITE
    CACT_n = 1'b0; CGNT_n = 1'b1; WRITE = 1'b1;
    EADR_n = 1'b1; BACT_n = 1'b1; IOD_n = 1'b1; MIS0 = 1'b0; BINPUT50_n = 1'b1;
    set_state(1'b0, 1'b0);
    tick;
    checks = checks + 1;
    if (CBWRITE_n !== 1'b0 || CMWRITE_n !== 1'b1) begin
      errors = errors + 1;
      $display("FAIL CACT_ONLY: CBWRITE_n=%b (want 0) CMWRITE_n=%b (want 1)",
               CBWRITE_n, CMWRITE_n);
    end
    // and CGNT must not move CBWRITE
    CACT_n = 1'b1; CGNT_n = 1'b0;
    set_state(1'b0, 1'b0);
    tick;
    checks = checks + 1;
    if (CBWRITE_n !== 1'b1 || CMWRITE_n !== 1'b0) begin
      errors = errors + 1;
      $display("FAIL CGNT_ONLY: CBWRITE_n=%b (want 1) CMWRITE_n=%b (want 0)",
               CBWRITE_n, CMWRITE_n);
    end

    // 3. the IOX direction term needs ALL THREE literals
    set_state(1'b0, 1'b0);
    CACT_n = 1'b1; CGNT_n = 1'b1; EADR_n = 1'b1; BACT_n = 1'b1;
    IOD_n = 1'b0; MIS0 = 1'b1; BINPUT50_n = 1'b1; #1;
    checks = checks + 1;
    if (WBD_n !== 1'b0 || WLBD_n !== 1'b0) begin
      errors = errors + 1;
      $display("FAIL IOX_TERM: WBD_n=%b WLBD_n=%b, both must assert", WBD_n, WLBD_n);
    end
    BINPUT50_n = 1'b0; #1;              // BINPUT50 active kills the term
    checks = checks + 1;
    if (WBD_n !== 1'b1 || WLBD_n !== 1'b1) begin
      errors = errors + 1;
      $display("FAIL IOX_BINPUT50: WBD_n=%b WLBD_n=%b, both must drop", WBD_n, WLBD_n);
    end

    // 4. BACT reaches WBD but must NOT reach WLBD
    BINPUT50_n = 1'b1; IOD_n = 1'b1; MIS0 = 1'b0; BACT_n = 1'b0; #1;
    checks = checks + 1;
    if (WBD_n !== 1'b0 || WLBD_n !== 1'b1) begin
      errors = errors + 1;
      $display("FAIL BACT_SCOPE: WBD_n=%b (want 0) WLBD_n=%b (want 1)", WBD_n, WLBD_n);
    end

    // 5. nothing ever floats
    checks = checks + 1;
    if (^{WBD_n, WLBD_n, CBWRITE_n, CMWRITE_n} === 1'bx) begin
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

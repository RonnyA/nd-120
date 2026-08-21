/****************************************************************************
** PAL_44310D (3F, LBDIF - local bus / DRAM interface) exhaustive golden tb **
**                                                                         **
** SPEC: DesignDocuments/PAL-Code/SRC/44310D.txt. The model below is        **
** re-derived from that PALASM listing product term by product term.        **
** PAL_44310D.v is the implementation under test; a disagreement is a       **
** FINDING and is reported, never patched away in the RTL.                  **
**                                                                         **
**   BCGNT50R = /MWRITE50 * BGNT * BGNT50 + /MWRITE50 * CGNT * CGNT50       **
**   BDRY     = /MWRITE50 * BDAP50 * BGNT * /LOEN * /HIEN * /RAS            **
**            + MWRITE50 * BDAP50 * BGNT50 * BGNT                           **
**            + BIOXL * ECCR                                                **
**            + /MR * BDRY * BDAP50            (hold, memory)               **
**            + /MR * BDRY * BIOXE             (hold, IOX)                  **
**            + REF100                                                      **
**            + /MWRITE50 * BDAP50 * /BGNT50 * BGNT75                       **
**   BIOXL    = BIOXE * /BGNT * /CGNT                                       **
**   /RDATA   = MWRITE50 + LOEN + HIEN + /BGNT * /CGNT + RAS                **
**                                                                         **
** BDRY is a self-referencing 16L8 term - a feedback latch - so             **
**   BDRY' = SET + BDRY * HOLD, HOLD = /MR * (BDAP50 + BIOXE)               **
** The two hold product terms COMBINE with an OR inside the sum, which is   **
** exactly what the 30-JUL audit fixed in this file; the model here is      **
** built from the listing so it re-checks that fix independently.           **
**                                                                         **
** COVERAGE: EXHAUSTIVE. 14 input pins x 1 state bit = 32768 combinations,  **
** all applied, with DUT.BDRY forced before each vector so every            **
** (state, input) pair of the transition function is exercised.             **
**                                                                         **
** BUILD MODE: default (edge-triggered) build - state is forced and CK is   **
** pulsed. Do not compile with USE_TRANSPARENT_LATCHES. Both RTL branches   **
** carry the same next-state expression.                                    **
**                                                                         **
** TRI-STATE: no /OE and no TEST pin on this part; every output is always   **
** driven. Checked for x/z at the end.                                      **
**                                                                         **
** A flipped term is caught: if the memory hold term lost BDAP50 the DUT    **
** would keep BDRY asserted on the 2^12 vectors with /MR set, BDAP50 low    **
** and BIOXE low, where the model drops it.                                 **
**                                                                         **
** Run: cd Verilog/PAL/sim && make test-pal44310d                           **
**                                                                         **
** Last reviewed: 20-AUG-2026                                               **
** Ronny Hansen                                                             **
*****************************************************************************/
`timescale 1ns / 1ps
`default_nettype none

module PAL_44310D_tb;

  reg CK, sys_rst_n;
  reg HIEN_n, BGNT_n, CGNT_n, LOEN_n, CGNT50_n, ECCR, BGNT50_n, BGNT75_n;
  reg BDAP50_n, MR_n, RAS, REF100_n, BIOXE_n, MWRITE50_n;

  wire BDRY_n, BIOXL_n, BCGNT50R_n, RDATA;

  integer checks = 0, errors = 0, vec, st, dumped = 0;

  PAL_44310D DUT (
      .CK(CK), .sys_rst_n(sys_rst_n),
      .HIEN_n(HIEN_n), .BGNT_n(BGNT_n), .CGNT_n(CGNT_n), .LOEN_n(LOEN_n),
      .CGNT50_n(CGNT50_n), .ECCR(ECCR), .BGNT50_n(BGNT50_n),
      .BGNT75_n(BGNT75_n), .BDAP50_n(BDAP50_n), .MR_n(MR_n),
      .BDRY_n(BDRY_n), .BIOXL_n(BIOXL_n),
      .RAS(RAS), .REF100_n(REF100_n), .BIOXE_n(BIOXE_n), .MWRITE50_n(MWRITE50_n),
      .BCGNT50R_n(BCGNT50R_n), .RDATA(RDATA)
  );

  // ---- golden model from the PALASM listing -----------------------------
  wire g_HIEN = ~HIEN_n, g_BGNT = ~BGNT_n, g_CGNT = ~CGNT_n, g_LOEN = ~LOEN_n;
  wire g_BGNT50 = ~BGNT50_n, g_BGNT75 = ~BGNT75_n, g_BDAP50 = ~BDAP50_n;
  wire g_CGNT50 = ~CGNT50_n, g_MWRITE50 = ~MWRITE50_n, g_BIOXE = ~BIOXE_n;
  wire g_REF100 = ~REF100_n;

  wire g_BIOXL = g_BIOXE & BGNT_n & CGNT_n;          // BIOXE * /BGNT * /CGNT

  wire g_BCGNT50R_n = ~( (MWRITE50_n & g_BGNT & g_BGNT50)
                       | (MWRITE50_n & g_CGNT & g_CGNT50) );

  wire g_RDATA = ~( g_MWRITE50 | g_LOEN | g_HIEN | (BGNT_n & CGNT_n) | RAS );

  reg  g_bdry;
  wire g_set  = (MWRITE50_n & g_BDAP50 & g_BGNT & LOEN_n & HIEN_n & ~RAS)
              | (g_MWRITE50 & g_BDAP50 & g_BGNT50 & g_BGNT)
              | (g_BIOXL & ECCR)
              | (g_REF100)
              | (MWRITE50_n & g_BDAP50 & BGNT50_n & g_BGNT75);
  wire g_hold = MR_n & (g_BDAP50 | g_BIOXE);
  wire g_bdry_next = g_set | (g_bdry & g_hold);

  task chk (input [127:0] name, input got, input exp);
    begin
      checks = checks + 1;
      if (got !== exp) begin
        errors = errors + 1;
        if (errors < 12)
          $display("FAIL %0s: got=%b exp=%b | bdry=%b HIEN_n=%b BGNT_n=%b CGNT_n=%b LOEN_n=%b CGNT50_n=%b ECCR=%b BGNT50_n=%b BGNT75_n=%b BDAP50_n=%b MR_n=%b RAS=%b REF100_n=%b BIOXE_n=%b MWRITE50_n=%b",
                   name, got, exp, g_bdry, HIEN_n, BGNT_n, CGNT_n, LOEN_n,
                   CGNT50_n, ECCR, BGNT50_n, BGNT75_n, BDAP50_n, MR_n, RAS,
                   REF100_n, BIOXE_n, MWRITE50_n);
      end
    end
  endtask

  task set_state (input v);
    begin g_bdry = v; DUT.BDRY = v; #1; end
  endtask

  task tick; begin CK = 1'b0; #1; CK = 1'b1; #1; CK = 1'b0; #1; end endtask

  initial begin
    $dumpfile("PAL_44310D_tb.vcd");
    $dumpvars(0, PAL_44310D_tb);
  end

  initial begin
    CK = 1'b0; sys_rst_n = 1'b1; g_bdry = 1'b0;
    $display("=====================================================");
    $display(" PAL_44310D (LBDIF) exhaustive golden testbench");
    $display(" 14 input pins x 1 state bit = 32768 combinations");
    $display("=====================================================");

    for (st = 0; st < 2; st = st + 1) begin
      for (vec = 0; vec < 16384; vec = vec + 1) begin
        {HIEN_n, BGNT_n, CGNT_n, LOEN_n, CGNT50_n, ECCR, BGNT50_n,
         BGNT75_n, BDAP50_n, MR_n, RAS, REF100_n, BIOXE_n, MWRITE50_n} = vec[13:0];
        set_state(st[0]);

        chk("BCGNT50R_n", BCGNT50R_n, g_BCGNT50R_n);
        chk("BIOXL_n",    BIOXL_n,    ~g_BIOXL);
        chk("RDATA",      RDATA,      g_RDATA);
        chk("BDRY_n",     BDRY_n,     ~g_bdry);

        tick;
        chk("BDRY_n_next", BDRY_n, ~g_bdry_next);

        dumped = dumped + 1;
        if (dumped == 40) $dumpoff;
      end
    end

    // ---- named property checks -----------------------------------------

    // 1. async reset clears BDRY
    set_state(1'b1);
    sys_rst_n = 1'b0; #1;
    checks = checks + 1;
    if (BDRY_n !== 1'b1) begin
      errors = errors + 1;
      $display("FAIL RESET: BDRY_n=%b, reset must clear BDRY", BDRY_n);
    end
    sys_rst_n = 1'b1; #1;

    // 2. THE 30-JUL AUDIT PROPERTY: in a DMA cycle BIOXE is off, and the
    //    memory hold term (/MR * BDRY * BDAP50) must still hold BDRY on its
    //    own. An AND of the two hold terms - the old bug - drops it here.
    MWRITE50_n = 1'b1; BDAP50_n = 1'b0; BGNT_n = 1'b1; CGNT_n = 1'b1;
    LOEN_n = 1'b0; HIEN_n = 1'b0; RAS = 1'b1; ECCR = 1'b0;
    BGNT50_n = 1'b1; BGNT75_n = 1'b1; REF100_n = 1'b1;
    BIOXE_n = 1'b1;                       // BIOXE OFF - the DMA case
    MR_n = 1'b1;
    set_state(1'b1);
    tick;
    checks = checks + 1;
    if (BDRY_n !== 1'b0) begin
      errors = errors + 1;
      $display("FAIL DMA_HOLD: BDRY_n=%b, BDAP50 alone must hold BDRY", BDRY_n);
    end
    //    mirror case: BIOXE alone must hold it with BDAP50 off
    BDAP50_n = 1'b1; BIOXE_n = 1'b0;
    set_state(1'b1);
    tick;
    checks = checks + 1;
    if (BDRY_n !== 1'b0) begin
      errors = errors + 1;
      $display("FAIL IOX_HOLD: BDRY_n=%b, BIOXE alone must hold BDRY", BDRY_n);
    end
    //    with BOTH off, BDRY must fall
    BDAP50_n = 1'b1; BIOXE_n = 1'b1;
    set_state(1'b1);
    tick;
    checks = checks + 1;
    if (BDRY_n !== 1'b1) begin
      errors = errors + 1;
      $display("FAIL HOLD_RELEASE: BDRY_n=%b, no hold term left, BDRY must fall", BDRY_n);
    end
    //    and MR must beat both hold terms
    BDAP50_n = 1'b0; BIOXE_n = 1'b0; MR_n = 1'b0; REF100_n = 1'b1; ECCR = 1'b0;
    BGNT_n = 1'b1; CGNT_n = 1'b1; MWRITE50_n = 1'b1; RAS = 1'b1;
    set_state(1'b1);
    tick;
    checks = checks + 1;
    if (BDRY_n !== 1'b1) begin
      errors = errors + 1;
      $display("FAIL MR_CLEARS: BDRY_n=%b, MR must clear BDRY", BDRY_n);
    end

    // 3. BIOXL needs the bus idle: BIOXE with a grant active must not assert
    MR_n = 1'b1; BIOXE_n = 1'b0; BGNT_n = 1'b1; CGNT_n = 1'b1; #1;
    checks = checks + 1;
    if (BIOXL_n !== 1'b0) begin
      errors = errors + 1;
      $display("FAIL BIOXL_IDLE: BIOXL_n=%b, must assert with BIOXE and no grant", BIOXL_n);
    end
    BGNT_n = 1'b0; #1;
    checks = checks + 1;
    if (BIOXL_n !== 1'b1) begin
      errors = errors + 1;
      $display("FAIL BIOXL_BGNT: BIOXL_n=%b, BGNT must block BIOXL", BIOXL_n);
    end
    BGNT_n = 1'b1; CGNT_n = 1'b0; #1;
    checks = checks + 1;
    if (BIOXL_n !== 1'b1) begin
      errors = errors + 1;
      $display("FAIL BIOXL_CGNT: BIOXL_n=%b, CGNT must block BIOXL", BIOXL_n);
    end

    // 4. RAS is in RDATA to kill the LOEN->HIEN transition spike
    MWRITE50_n = 1'b1; LOEN_n = 1'b1; HIEN_n = 1'b1; BGNT_n = 1'b0; RAS = 1'b0; #1;
    checks = checks + 1;
    if (RDATA !== 1'b1) begin
      errors = errors + 1;
      $display("FAIL RDATA_ON: RDATA=%b, must be 1 with no blocking term", RDATA);
    end
    RAS = 1'b1; #1;
    checks = checks + 1;
    if (RDATA !== 1'b0) begin
      errors = errors + 1;
      $display("FAIL RDATA_RAS: RDATA=%b, RAS must suppress RDATA", RDATA);
    end

    // 5. nothing floats
    checks = checks + 1;
    if (^{BDRY_n, BIOXL_n, BCGNT50R_n, RDATA} === 1'bx) begin
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

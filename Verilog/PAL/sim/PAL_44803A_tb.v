/****************************************************************************
** PAL_44803A (5F, RAMA - the DRAM arbiter) exhaustive golden testbench    **
**                                                                         **
** SPEC: DesignDocuments/PAL-Code/SRC/44803A.txt. The model below is        **
** re-derived from that PALASM listing product term by product term. The    **
** Verilog is the implementation under test; a disagreement is a FINDING    **
** to report, never a reason to edit the RTL.                               **
**                                                                         **
** This is the part that decides who owns the DRAM. Its stated priority is  **
**   1. refresh   2. CPU after a refresh   3. bus   4. CPU                  **
** and the whole arbiter rests on the three-way interlock                   **
** /RGNT * /CGNT * /BGNT that appears in every grant-set term: nothing may  **
** be granted while anything is granted.                                    **
**                                                                         **
**   RGNT := RLRQ * /CSEM * /BSEM * /RGNT * /CGNT * /BGNT                   **
**         + RGNT * /LOEN * /LOEN25 + RGNT * LOEN * LOEN25                  **
**         + RGNT * LOEN * /LOEN25                                          **
**   CGNT := /MR * /CSEM * /BSEM * CLRQ * /BLRQ50 * /RLRQ * INTERLOCK       **
**         + /MR * /CSEM * /BSEM * LDR * /RLRQ * CLRQ * INTERLOCK           **
**         + /MR * CSEM * /BSEM * CLRQ * INTERLOCK                          **
**         + CGNT * (hold on LOEN / LOEN25) * /MR                           **
**   BGNT := /MR * /CSEM * /BSEM * /RLRQ * /CLRQ * BLRQ50 * INTERLOCK       **
**         + /MR * /CSEM * /BSEM * /LDR * /RLRQ * BLRQ50 * INTERLOCK        **
**         + /MR * /CSEM * BSEM * BLRQ50 * INTERLOCK                        **
**         + BGNT * (hold on LOEN / LOEN25) * /MR                           **
**   LDR    := RGNT + LDR * /CGNT * /BGNT                                   **
**   CSEM   := /MR * SSEMA * CGNT + /MR * CSEM * (hold on LOEN / LOEN25)    **
**   BSEM   := /MR * SEMRQ50 * BGNT + /MR * BSEM * (hold on LOEN / LOEN25)  **
**   LOEN25 := LOEN                                                         **
**   /BCGNT25 := /BGNT * /CGNT                                              **
** (the three hold terms per grant are spelled out in full in the model)    **
**                                                                         **
** COVERAGE: EXHAUSTIVE. 8 input pins x 8 state bits = 65536 combinations,  **
** every one applied. All eight registers are FORCED through hierarchical   **
** references before each vector, so the complete transition function of an **
** eight-bit state machine is exercised - including the states the arbiter  **
** should never reach, which is exactly where an arbiter bug hides.         **
**                                                                         **
** OUTPUT ENABLE: a PAL16R8 puts all eight outputs under /OE, and the RTL   **
** matches. A disabled output drives 0, never z, and on these ACTIVE-LOW    **
** grant pins that reads as EVERY GRANT ASSERTED - checked explicitly.      **
**                                                                         **
** The equations are swept with OE_n=0 only. The RTL takes its register     **
** feedback through the OE-gated output ports, where a real 16R8 feeds back **
** from the register; with /OE high the two therefore differ. That cannot   **
** happen on the 3202D, where /OE is PD1 and PD1..PD4 are always low        **
** (PAL_44803A.v:26).                                                       **
**                                                                         **
** OCR NOTE: the listing's pin line reads "/CSEM /CSEM" for pins 13 and 14. **
** Pin 13 must be /BSEM - BSEM has its own equation and no other pin is     **
** free. Treated as OCR garble in the .txt, not as a design fact.           **
**                                                                         **
** Run: cd Verilog/PAL/sim && make test-pal44803a                           **
**                                                                         **
** Last reviewed: 20-AUG-2026                                               **
** Ronny Hansen                                                             **
*****************************************************************************/
`timescale 1ns / 1ps
`default_nettype none

module PAL_44803A_tb;

  reg CK, OE_n;
  reg LOEN_n, RLRQ_n, MR_n, CLRQ_n, BLRQ50_n, SSEMA_n, SEMRQ50_n;

  wire RGNT_n, CGNT_n, BGNT_n, LOEN25_n, LDR_n, CSEM_n, BSEM_n, BCGNT25;

  integer checks = 0, errors = 0, vec, st, dumped = 0;

  PAL_44803A DUT (
      .CK(CK), .OE_n(OE_n), .HOLD(1'b0),
      .LOEN_n(LOEN_n), .RLRQ_n(RLRQ_n), .MR_n(MR_n), .CLRQ_n(CLRQ_n),
      .BLRQ50_n(BLRQ50_n), .SSEMA_n(SSEMA_n), .SEMRQ50_n(SEMRQ50_n),
      .RGNT_n(RGNT_n), .CGNT_n(CGNT_n), .BGNT_n(BGNT_n),
      .LOEN25_n(LOEN25_n), .LDR_n(LDR_n), .CSEM_n(CSEM_n),
      .BSEM_n(BSEM_n), .BCGNT25(BCGNT25)
  );

  // ---- golden model from the listing ------------------------------------
  wire g_LOEN = ~LOEN_n, g_RLRQ = ~RLRQ_n, g_CLRQ = ~CLRQ_n;
  wire g_BLRQ50 = ~BLRQ50_n, g_SSEMA = ~SSEMA_n, g_SEMRQ50 = ~SEMRQ50_n;

  reg r_rgnt, r_cgnt, r_bgnt, r_ldr, r_csem, r_bsem, r_loen25, r_bcgnt25_n;

  // the interlock that appears in every grant-set term
  wire g_lock = ~r_rgnt & ~r_cgnt & ~r_bgnt;

  // the three-term "hold to the end of the DRAM cycle" pattern
  wire g_hold = (~g_LOEN & ~r_loen25) | (g_LOEN & r_loen25) | (g_LOEN & ~r_loen25);
  // and the semaphore variant, which pairs LOEN25 the other way round
  wire g_shold = (r_loen25 & g_LOEN) | (r_loen25 & ~g_LOEN) | (~r_loen25 & ~g_LOEN);

  wire g_rgnt_next = (g_RLRQ & ~r_csem & ~r_bsem & g_lock) | (r_rgnt & g_hold);

  wire g_cgnt_next = (MR_n & ~r_csem & ~r_bsem & g_CLRQ & BLRQ50_n & RLRQ_n & g_lock)
                   | (MR_n & ~r_csem & ~r_bsem & r_ldr  & RLRQ_n  & g_CLRQ & g_lock)
                   | (MR_n &  r_csem & ~r_bsem & g_CLRQ & g_lock)
                   | (r_cgnt & g_hold & MR_n);

  wire g_bgnt_next = (MR_n & ~r_csem & ~r_bsem & RLRQ_n & CLRQ_n & g_BLRQ50 & g_lock)
                   | (MR_n & ~r_csem & ~r_bsem & ~r_ldr & RLRQ_n & g_BLRQ50 & g_lock)
                   | (MR_n & ~r_csem &  r_bsem & g_BLRQ50 & g_lock)
                   | (r_bgnt & g_hold & MR_n);

  wire g_ldr_next    = r_rgnt | (r_ldr & ~r_cgnt & ~r_bgnt);
  wire g_csem_next   = (MR_n & g_SSEMA   & r_cgnt) | (MR_n & r_csem & g_shold);
  wire g_bsem_next   = (MR_n & g_SEMRQ50 & r_bgnt) | (MR_n & r_bsem & g_shold);
  wire g_loen25_next = g_LOEN;
  wire g_bcgnt25_n_next = ~r_bgnt & ~r_cgnt;

  task chk (input [127:0] name, input got, input exp);
    begin
      checks = checks + 1;
      if (got !== exp) begin
        errors = errors + 1;
        if (errors < 12)
          $display("FAIL %0s: got=%b exp=%b | r=%b c=%b b=%b ldr=%b csem=%b bsem=%b loen25=%b bc25n=%b | OE_n=%b LOEN_n=%b RLRQ_n=%b MR_n=%b CLRQ_n=%b BLRQ50_n=%b SSEMA_n=%b SEMRQ50_n=%b",
                   name, got, exp, r_rgnt, r_cgnt, r_bgnt, r_ldr, r_csem,
                   r_bsem, r_loen25, r_bcgnt25_n, OE_n, LOEN_n, RLRQ_n, MR_n,
                   CLRQ_n, BLRQ50_n, SSEMA_n, SEMRQ50_n);
      end
    end
  endtask

  task set_state (input [7:0] s);
    begin
      {r_bcgnt25_n, r_loen25, r_bsem, r_csem, r_ldr, r_bgnt, r_cgnt, r_rgnt} = s;
      DUT.RGNT_reg      = s[0];
      DUT.CGNT_reg      = s[1];
      DUT.BGNT_reg      = s[2];
      DUT.LDR_reg       = s[3];
      DUT.CSEM_reg      = s[4];
      DUT.BSEM_reg      = s[5];
      DUT.LOEN25_reg    = s[6];
      DUT.BCGNT25_n_reg = s[7];
      #1;
    end
  endtask

  task tick; begin CK = 1'b0; #1; CK = 1'b1; #1; CK = 1'b0; #1; end endtask

  initial begin
    $dumpfile("PAL_44803A_tb.vcd");
    $dumpvars(0, PAL_44803A_tb);
  end

  initial begin
    CK = 1'b0;
    {r_bcgnt25_n, r_loen25, r_bsem, r_csem, r_ldr, r_bgnt, r_cgnt, r_rgnt} = 8'b0;
    $display("=====================================================");
    $display(" PAL_44803A (RAMA arbiter) exhaustive golden testbench");
    $display(" 8 input pins x 8 state bits = 65536 combinations");
    $display("=====================================================");

    for (st = 0; st < 256; st = st + 1) begin
      for (vec = 0; vec < 256; vec = vec + 1) begin
        {LOEN_n, RLRQ_n, MR_n, CLRQ_n, BLRQ50_n, SSEMA_n, SEMRQ50_n, OE_n} = vec[7:0];
        set_state(st[7:0]);

        if (OE_n === 1'b0) begin
          chk("RGNT_n",   RGNT_n,   ~r_rgnt);
          chk("CGNT_n",   CGNT_n,   ~r_cgnt);
          chk("BGNT_n",   BGNT_n,   ~r_bgnt);
          chk("LDR_n",    LDR_n,    ~r_ldr);
          chk("CSEM_n",   CSEM_n,   ~r_csem);
          chk("BSEM_n",   BSEM_n,   ~r_bsem);
          chk("LOEN25_n", LOEN25_n, ~r_loen25);
          chk("BCGNT25",  BCGNT25,  ~r_bcgnt25_n);
        end else begin
          chk("OEOFF_RGNT_n",   RGNT_n,   1'b0);
          chk("OEOFF_CGNT_n",   CGNT_n,   1'b0);
          chk("OEOFF_BGNT_n",   BGNT_n,   1'b0);
          chk("OEOFF_LDR_n",    LDR_n,    1'b0);
          chk("OEOFF_CSEM_n",   CSEM_n,   1'b0);
          chk("OEOFF_BSEM_n",   BSEM_n,   1'b0);
          chk("OEOFF_LOEN25_n", LOEN25_n, 1'b0);
          chk("OEOFF_BCGNT25",  BCGNT25,  1'b0);
        end

        tick;
        if (OE_n === 1'b0) begin
          chk("RGNT_n_next",   RGNT_n,   ~g_rgnt_next);
          chk("CGNT_n_next",   CGNT_n,   ~g_cgnt_next);
          chk("BGNT_n_next",   BGNT_n,   ~g_bgnt_next);
          chk("LDR_n_next",    LDR_n,    ~g_ldr_next);
          chk("CSEM_n_next",   CSEM_n,   ~g_csem_next);
          chk("BSEM_n_next",   BSEM_n,   ~g_bsem_next);
          chk("LOEN25_n_next", LOEN25_n, ~g_loen25_next);
          chk("BCGNT25_next",  BCGNT25,  ~g_bcgnt25_n_next);
        end

        dumped = dumped + 1;
        if (dumped == 40) $dumpoff;
      end
    end

    // ---- named property checks -----------------------------------------
    OE_n = 1'b0;
    LOEN_n = 1'b1; RLRQ_n = 1'b1; MR_n = 1'b1; CLRQ_n = 1'b1;
    BLRQ50_n = 1'b1; SSEMA_n = 1'b1; SEMRQ50_n = 1'b1;

    // 1. MUTUAL EXCLUSION - the property the whole part exists for. From
    //    every one of the 256 states, with every request asserted at once,
    //    no NEW grant may be handed out while any grant is already up.
    RLRQ_n = 1'b0; CLRQ_n = 1'b0; BLRQ50_n = 1'b0;
    for (st = 0; st < 256; st = st + 1) begin
      set_state(st[7:0]);
      if (r_rgnt | r_cgnt | r_bgnt) begin
        tick;
        checks = checks + 1;
        // the only grants that may be up afterwards are ones that were
        // already up and held - no new grant may appear
        if ((~RGNT_n & ~r_rgnt) | (~CGNT_n & ~r_cgnt) | (~BGNT_n & ~r_bgnt)) begin
          errors = errors + 1;
          $display("FAIL INTERLOCK: state=%02h granted a NEW owner (r=%b c=%b b=%b -> %b %b %b)",
                   st[7:0], r_rgnt, r_cgnt, r_bgnt, ~RGNT_n, ~CGNT_n, ~BGNT_n);
        end
      end
    end

    // 2. REFRESH HAS ABSOLUTE PRIORITY: from idle with all three requests up
    //    and no semaphore held, the refresh grant is the one that fires.
    RLRQ_n = 1'b0; CLRQ_n = 1'b0; BLRQ50_n = 1'b0;
    set_state(8'h00);
    tick;
    checks = checks + 1;
    if (RGNT_n !== 1'b0 || CGNT_n !== 1'b1 || BGNT_n !== 1'b1) begin
      errors = errors + 1;
      $display("FAIL REFRESH_PRIORITY: RGNT_n=%b CGNT_n=%b BGNT_n=%b", RGNT_n, CGNT_n, BGNT_n);
    end

    // 3. MASTER CLEAR kills CGNT and BGNT but NOT RGNT - the listing gives
    //    the refresh grant no /MR literal at all, so refresh survives reset.
    MR_n = 1'b0; RLRQ_n = 1'b1; CLRQ_n = 1'b1; BLRQ50_n = 1'b1;
    LOEN_n = 1'b1;                             // LOEN low -> holds via /LOEN * /LOEN25
    set_state(8'b0000_0111);                   // rgnt, cgnt, bgnt all set
    tick;
    checks = checks + 1;
    if (CGNT_n !== 1'b1 || BGNT_n !== 1'b1) begin
      errors = errors + 1;
      $display("FAIL MR_DROPS_GRANTS: CGNT_n=%b BGNT_n=%b, MR must drop both", CGNT_n, BGNT_n);
    end
    checks = checks + 1;
    if (RGNT_n !== 1'b0) begin
      errors = errors + 1;
      $display("FAIL MR_KEEPS_REFRESH: RGNT_n=%b, the listing gives RGNT no /MR term", RGNT_n);
    end
    MR_n = 1'b1;

    // 4. LDR (last-done-refresh) sets on RGNT and holds until the next grant
    set_state(8'b0000_0001);                   // rgnt set
    tick;
    checks = checks + 1;
    if (LDR_n !== 1'b0) begin
      errors = errors + 1;
      $display("FAIL LDR_SET: LDR_n=%b, RGNT must set LDR", LDR_n);
    end
    set_state(8'b0000_1000);                   // ldr set, no grants
    tick;
    checks = checks + 1;
    if (LDR_n !== 1'b0) begin
      errors = errors + 1;
      $display("FAIL LDR_HOLD: LDR_n=%b, LDR must hold with no grant", LDR_n);
    end
    set_state(8'b0000_1010);                   // ldr set, cgnt set
    tick;
    checks = checks + 1;
    if (LDR_n !== 1'b1) begin
      errors = errors + 1;
      $display("FAIL LDR_CLEAR: LDR_n=%b, CGNT must clear LDR", LDR_n);
    end

    // 5. BCGNT25 is the registered OR of the two non-refresh grants
    set_state(8'b0000_0000);
    tick;
    checks = checks + 1;
    if (BCGNT25 !== 1'b0) begin
      errors = errors + 1;
      $display("FAIL BCGNT25_IDLE: BCGNT25=%b, must be inactive with no grant", BCGNT25);
    end
    set_state(8'b0000_0010);                   // cgnt
    tick;
    checks = checks + 1;
    if (BCGNT25 !== 1'b1) begin
      errors = errors + 1;
      $display("FAIL BCGNT25_CGNT: BCGNT25=%b, CGNT must raise it", BCGNT25);
    end

    // 6. nothing floats
    checks = checks + 1;
    if (^{RGNT_n, CGNT_n, BGNT_n, LOEN25_n, LDR_n, CSEM_n, BSEM_n, BCGNT25} === 1'bx) begin
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

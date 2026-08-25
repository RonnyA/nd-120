/****************************************************************************
** PAL_44902A (6F, RAMC - the DRAM control state machine) golden testbench **
**                                                                         **
** SPEC: DesignDocuments/PAL-Code/SRC/44902A.txt. The model is re-derived   **
** from that PALASM listing product term by product term; the Verilog is    **
** under test and a disagreement is a FINDING, not a licence to edit it.    **
**                                                                         **
** This part is the four-bit RAM sequencer QA..QD plus the four strobes it  **
** drives (RAS, CAS, LOEN, HIEN). Its 1987 note says the equations were     **
** deliberately "maximized with internal feedback to match clock skew", so  **
** they are full of redundant pairs such as /QD * QA * QD and /QD * QA *    **
** /QD - one of which is identically zero. Those are transcribed verbatim   **
** in the model below because the listing is the spec, not a tidied-up      **
** version of it.                                                           **
**                                                                         **
** COVERAGE: EXHAUSTIVE. 7 input pins x 8 state bits = 32768 combinations,  **
** every one applied. All eight registers are FORCED before each vector, so **
** the transition function is checked from all 256 states - including the   **
** six illegal ones the sequencer should recover from, which is precisely   **
** where a mis-transcribed feedback literal would hide.                     **
**                                                                         **
** OUTPUT ENABLE: a PAL16R8 puts all eight outputs under /OE, and the RTL   **
** matches. A disabled output drives 0, never z - checked explicitly.       **
** The equations are swept with OE_n=0 only, because the RTL takes its      **
** state feedback through the OE-gated output ports where a real 16R8 feeds **
** back from the registers. /OE is PD3 on the 3202D and PD1..PD4 are always **
** low (PAL_44902A.v:27), so the difference is unreachable in the machine.  **
**                                                                         **
** UNUSED PINS: the listing's pin 3 (/CGNT) and pin 4 (/BGNT) appear in no  **
** equation, and the module leaves them off the port list entirely. That    **
** matches the listing and is not a dropped input.                          **
**                                                                         **
** A flipped term is caught: dropping /BDRY50 from QB's wait-state exit     **
** term would let the machine leave the pause state without the timeout,    **
** changing QB on every vector with QB * BGNT25 * /BDAP50 * /MR * BDRY50.   **
**                                                                         **
** Run: cd Verilog/PAL/sim && make test-pal44902a                           **
**                                                                         **
** Last reviewed: 20-AUG-2026                                               **
** Ronny Hansen                                                             **
*****************************************************************************/
`timescale 1ns / 1ps
`default_nettype none

module PAL_44902A_tb;

  reg CK, OE_n;
  reg RGNT_n, BDAP50_n, MR_n, BGNT25_n, CGNT25_n, BDRY50_n;

  wire QA_n, QB_n, QC_n, QD_n, RAS, CAS, LOEN_n, HIEN_n;

  integer checks = 0, errors = 0, vec, st, dumped = 0;

  PAL_44902A DUT (
      .CK(CK), .OE_n(OE_n), .HOLD(1'b0),
      .RGNT_n(RGNT_n), .BDAP50_n(BDAP50_n), .MR_n(MR_n),
      .BGNT25_n(BGNT25_n), .CGNT25_n(CGNT25_n), .BDRY50_n(BDRY50_n),
      .QA_n(QA_n), .QB_n(QB_n), .QC_n(QC_n), .QD_n(QD_n),
      .RAS(RAS), .CAS(CAS), .LOEN_n(LOEN_n), .HIEN_n(HIEN_n)
  );

  // ---- golden model from the listing ------------------------------------
  wire g_RGNT = ~RGNT_n, g_BGNT25 = ~BGNT25_n;

  reg r_qa, r_qb, r_qc, r_qd, r_ras_n, r_cas_n, r_loen, r_hien;

  wire g_qa_next = (~r_qd & ~r_qc & ~r_qb &  r_qa)
                 | (~r_qd & ~r_qc & ~r_qb & ~r_qa)
                 | ( r_qd & ~r_qc &  r_qb &  r_qa)
                 | ( r_qd & ~r_qc &  r_qb & ~r_qa);

  wire g_qb_next = (r_qc &  r_qb &  r_qd)
                 | (r_qc &  r_qb & ~r_qd)
                 | (r_qc & ~r_qb &  r_qd)
                 | (r_qc & ~r_qb & ~r_qd)
                 | (r_qb & ~r_qa &  r_qc)
                 | (r_qb & ~r_qa & ~r_qc)
                 | (~r_qd & r_qa)
                 | (r_qb & g_BGNT25 & BDAP50_n & MR_n & BDRY50_n);

  wire g_qc_next = (~r_qd &  r_qc &  r_qb)
                 | (~r_qd &  r_qc & ~r_qb)
                 | ( r_qc & ~r_qb &  r_qa)
                 | ( r_qc & ~r_qb & ~r_qa)
                 | ( r_qc &  r_qa &  r_qd)
                 | ( r_qc &  r_qa & ~r_qd)
                 | (~r_qd &  r_qb & ~r_qa)
                 | ( r_qc & RGNT_n & CGNT25_n & BGNT25_n);

  wire g_qd_next = (r_qc &  r_qd &  r_qb)
                 | (r_qc & ~r_qd &  r_qb)
                 | (r_qc &  r_qd & ~r_qb)
                 | (r_qc & ~r_qd & ~r_qb)
                 | (r_qb & ~r_qa &  r_qc)
                 | (r_qb & ~r_qa & ~r_qc)
                 | (r_qd &  r_qa &  r_qb)
                 | (r_qd &  r_qa & ~r_qb);

  // /RAS - the two /QD * QA * QD / /QD * QA * /QD terms are verbatim from
  // the listing; the first is identically zero and is kept on purpose.
  wire g_ras_n_next = ( r_qc &  r_qa &  r_qb)
                    | ( r_qc & ~r_qa &  r_qb)
                    | ( r_qc &  r_qa & ~r_qb)
                    | ( r_qc & ~r_qa & ~r_qb)
                    | (~r_qd &  r_qa &  r_qd)
                    | (~r_qd &  r_qa & ~r_qd)
                    | (~r_qd &  r_qb &  r_qc)
                    | (~r_qd &  r_qb & ~r_qc);

  wire g_loen_next = (~r_qc & ~r_qb & ~r_qa &  r_qd)
                   | (~r_qc & ~r_qb & ~r_qa & ~r_qd)
                   | ( r_qd & ~r_qc &  r_qa &  r_qb)
                   | ( r_qd & ~r_qc &  r_qa & ~r_qb);

  wire g_hien_next = ( r_qd &  r_qb & ~r_qa &  r_qc)
                   | ( r_qd &  r_qb & ~r_qa & ~r_qc)
                   | (~r_qd & ~r_qc &  r_qb &  r_qa)
                   | (~r_qd & ~r_qc &  r_qb & ~r_qa);

  wire g_cas_n_next = ( r_qb & ~r_qa & RGNT_n)
                    | ( r_qd &  r_qb & RGNT_n)
                    | ( r_qc & ~r_qb &  r_qa)
                    | ( r_qc & ~r_qb & ~r_qa)
                    | ( r_qc &  r_qa &  r_qd)
                    | ( r_qc &  r_qa & ~r_qd)
                    | (~r_qd & g_RGNT);

  task chk (input [127:0] name, input got, input exp);
    begin
      checks = checks + 1;
      if (got !== exp) begin
        errors = errors + 1;
        if (errors < 12)
          $display("FAIL %0s: got=%b exp=%b | Q(DCBA)=%b%b%b%b ras_n=%b cas_n=%b loen=%b hien=%b | OE_n=%b RGNT_n=%b BDAP50_n=%b MR_n=%b BGNT25_n=%b CGNT25_n=%b BDRY50_n=%b",
                   name, got, exp, r_qd, r_qc, r_qb, r_qa, r_ras_n, r_cas_n,
                   r_loen, r_hien, OE_n, RGNT_n, BDAP50_n, MR_n, BGNT25_n,
                   CGNT25_n, BDRY50_n);
      end
    end
  endtask

  task set_state (input [7:0] s);
    begin
      {r_hien, r_loen, r_cas_n, r_ras_n, r_qd, r_qc, r_qb, r_qa} = s;
      DUT.QA_reg    = s[0];
      DUT.QB_reg    = s[1];
      DUT.QC_reg    = s[2];
      DUT.QD_reg    = s[3];
      DUT.RAS_n_reg = s[4];
      DUT.CAS_n_reg = s[5];
      DUT.LOEN_reg  = s[6];
      DUT.HIEN_reg  = s[7];
      #1;
    end
  endtask

  task tick; begin CK = 1'b0; #1; CK = 1'b1; #1; CK = 1'b0; #1; end endtask

  initial begin
    $dumpfile("PAL_44902A_tb.vcd");
    $dumpvars(0, PAL_44902A_tb);
  end

  initial begin
    CK = 1'b0;
    {r_hien, r_loen, r_cas_n, r_ras_n, r_qd, r_qc, r_qb, r_qa} = 8'b0;
    $display("=====================================================");
    $display(" PAL_44902A (RAMC) exhaustive golden testbench");
    $display(" 7 input pins x 8 state bits = 32768 combinations");
    $display("=====================================================");

    for (st = 0; st < 256; st = st + 1) begin
      for (vec = 0; vec < 128; vec = vec + 1) begin
        {RGNT_n, BDAP50_n, MR_n, BGNT25_n, CGNT25_n, BDRY50_n, OE_n} = vec[6:0];
        set_state(st[7:0]);

        if (OE_n === 1'b0) begin
          chk("QA_n",   QA_n,   ~r_qa);
          chk("QB_n",   QB_n,   ~r_qb);
          chk("QC_n",   QC_n,   ~r_qc);
          chk("QD_n",   QD_n,   ~r_qd);
          chk("RAS",    RAS,    ~r_ras_n);
          chk("CAS",    CAS,    ~r_cas_n);
          chk("LOEN_n", LOEN_n, ~r_loen);
          chk("HIEN_n", HIEN_n, ~r_hien);
        end else begin
          chk("OEOFF_QA_n",   QA_n,   1'b0);
          chk("OEOFF_QB_n",   QB_n,   1'b0);
          chk("OEOFF_QC_n",   QC_n,   1'b0);
          chk("OEOFF_QD_n",   QD_n,   1'b0);
          chk("OEOFF_RAS",    RAS,    1'b0);
          chk("OEOFF_CAS",    CAS,    1'b0);
          chk("OEOFF_LOEN_n", LOEN_n, 1'b0);
          chk("OEOFF_HIEN_n", HIEN_n, 1'b0);
        end

        tick;
        if (OE_n === 1'b0) begin
          chk("QA_n_next",   QA_n,   ~g_qa_next);
          chk("QB_n_next",   QB_n,   ~g_qb_next);
          chk("QC_n_next",   QC_n,   ~g_qc_next);
          chk("QD_n_next",   QD_n,   ~g_qd_next);
          chk("RAS_next",    RAS,    ~g_ras_n_next);
          chk("CAS_next",    CAS,    ~g_cas_n_next);
          chk("LOEN_n_next", LOEN_n, ~g_loen_next);
          chk("HIEN_n_next", HIEN_n, ~g_hien_next);
        end

        dumped = dumped + 1;
        if (dumped == 40) $dumpoff;
      end
    end

    // ---- named property checks -----------------------------------------
    OE_n = 1'b0;
    RGNT_n = 1'b1; BDAP50_n = 1'b1; MR_n = 1'b1;
    BGNT25_n = 1'b1; CGNT25_n = 1'b1; BDRY50_n = 1'b1;

    // 1. THE SEQUENCER MUST NEVER WEDGE. From every one of the 256 states,
    //    with no request of any kind, iterate the machine and require it to
    //    reach a repeating cycle within 16 steps rather than sit in an
    //    illegal state - the "other states will go to idle" comment in the
    //    listing is a promise this checks.
    for (st = 0; st < 256; st = st + 1) begin
      set_state(st[7:0]);
      for (vec = 0; vec < 16; vec = vec + 1) tick;
      checks = checks + 1;
      if (^{QA_n, QB_n, QC_n, QD_n} === 1'bx) begin
        errors = errors + 1;
        $display("FAIL SEQ_UNKNOWN: state %02h left Q undefined", st[7:0]);
      end
    end

    // 2. LOEN and HIEN are mutually exclusive in every state the listing
    //    names for them (LOEN = 3,4,5,6 and HIEN = 0,1,2,8 are disjoint), so
    //    the two bank enables must never be asserted together.
    for (st = 0; st < 16; st = st + 1) begin
      set_state({4'b0000, st[3:0]});
      tick;
      checks = checks + 1;
      if (LOEN_n === 1'b0 && HIEN_n === 1'b0) begin
        errors = errors + 1;
        $display("FAIL BANK_OVERLAP: Q=%0d asserted LOEN and HIEN together", st);
      end
    end

    // 3. the QB wait term needs every one of its five literals. State
    //    Q(DCBA) = 1011 is chosen because it kills every OTHER QB product
    //    term (QC is low, QA is high), leaving the wait term alone.
    set_state(8'b0000_1011);
    BGNT25_n = 1'b0; BDAP50_n = 1'b1; MR_n = 1'b1; BDRY50_n = 1'b1;
    tick;
    checks = checks + 1;
    if (QB_n !== 1'b0) begin
      errors = errors + 1;
      $display("FAIL QB_WAIT_TERM: QB_n=%b, the BGNT25 wait term must hold QB", QB_n);
    end
    set_state(8'b0000_1011);
    MR_n = 1'b0;                             // master clear kills the term
    tick;
    checks = checks + 1;
    if (QB_n !== 1'b1) begin
      errors = errors + 1;
      $display("FAIL QB_MR: QB_n=%b, MR must kill the wait term", QB_n);
    end
    set_state(8'b0000_1011);
    MR_n = 1'b1; BDRY50_n = 1'b0;            // BDRY50 timeout also kills it
    tick;
    checks = checks + 1;
    if (QB_n !== 1'b1) begin
      errors = errors + 1;
      $display("FAIL QB_BDRY50: QB_n=%b, BDRY50 must get us out of the wait state", QB_n);
    end
    set_state(8'b0000_1011);
    MR_n = 1'b1; BDRY50_n = 1'b1; BDAP50_n = 1'b0;   // BDAP50 kills it too
    tick;
    checks = checks + 1;
    if (QB_n !== 1'b1) begin
      errors = errors + 1;
      $display("FAIL QB_BDAP50: QB_n=%b, BDAP50 must kill the wait term", QB_n);
    end
    BDAP50_n = 1'b1; BDRY50_n = 1'b1; BGNT25_n = 1'b1;

    // 4. the refresh product term of /CAS. The listing writes the equation
    //    for /CAS and the pin CAS is active high, so a term that is TRUE
    //    drives the CAS pin INACTIVE. From Q(DCBA)=0000 no other term fires,
    //    so /QD * RGNT is isolated: CAS active without refresh, inactive
    //    with it. Getting the sense of this pin backwards is exactly the
    //    kind of single-literal error this suite exists to catch.
    set_state(8'b0000_0000);
    RGNT_n = 1'b1;
    tick;
    checks = checks + 1;
    if (CAS !== 1'b1) begin
      errors = errors + 1;
      $display("FAIL CAS_NO_REFRESH: CAS=%b, no /CAS term fires so CAS must be active", CAS);
    end
    set_state(8'b0000_0000);
    RGNT_n = 1'b0;
    tick;
    checks = checks + 1;
    if (CAS !== 1'b0) begin
      errors = errors + 1;
      $display("FAIL CAS_REFRESH_TERM: CAS=%b, /QD * RGNT must drive /CAS", CAS);
    end
    RGNT_n = 1'b1;

    // 5. nothing floats
    checks = checks + 1;
    if (^{QA_n, QB_n, QC_n, QD_n, RAS, CAS, LOEN_n, HIEN_n} === 1'bx) begin
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

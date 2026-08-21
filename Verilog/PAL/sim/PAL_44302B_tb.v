/****************************************************************************
** PAL_44302B (11D, LBC1) - exhaustive golden testbench                    **
**                                                                         **
** SPEC: DesignDocuments/PAL-Code/SRC/44302B.txt - the original PALASM     **
** listing. The reference model in this file is re-derived from that       **
** listing product term by product term; the Verilog is the thing under    **
** test. Where the two disagree the listing wins and it is a FINDING, not  **
** a licence to edit the RTL.                                              **
**                                                                         **
**   IF (/TEST) EMD = Q2 * Q0 * CACT + EMD * CACT + CGNT * CGNT50                  **
**                  + EMD * RT * CC2 * /TERM + EMD * IORQ * CC2 * /TERM                **
**   IF (/TEST) CGNTCACT = CGNT + CACT                                     **
**   IF (/TEST) BGNTCACT = BGNT + CACT                                     **
**   IF (/TEST) DSTB = CGNT + CACT * /BDRY50 * /BDRY25 * /IORQ + CACT * IORQ * CC2   **
**                                                                         **
** EMD is a self-referencing 16L8 term, i.e. a transparent latch built     **
** from feedback: EMD' = SET + EMD * HOLD with                               **
**   SET  = Q2 * Q0 * CACT + CGNT * CGNT50                                       **
**   HOLD = CACT + RT * CC2 * /TERM + IORQ * CC2 * /TERM                           **
** BUILD MODE: this testbench targets the DEFAULT build (edge-triggered    **
** flip-flop, what the FPGA uses). It forces the state register and pulses **
** CK, which a transparent latch has no notion of, so do NOT compile it    **
** with USE_TRANSPARENT_LATCHES. The two branches of the RTL carry the     **
** SAME next-state expression, so a term checked here is checked for both. **
**                                                                         **
** COVERAGE: EXHAUSTIVE. 13 input pins x 1 state bit = 16384 combinations, **
** every one applied. The latch state is FORCED through the hierarchical   **
** reference DUT.EMD before each vector, so every (state, input) pair of   **
** the transition function is exercised - not only the reachable ones.     **
**                                                                         **
** TEST MODE: the listing's IF (/TEST) is an output-enable term. With      **
** TEST=1 every pin is disabled and pulled inactive; those vectors are     **
** checked for "all outputs inactive" rather than against the equations,   **
** because the real part's combinational feedback would then come from the **
** pulled-up pin while the RTL keeps its internal state alive. That        **
** difference is reported in the task notes, not asserted here.            **
**                                                                         **
** OUTPUT ENABLE / TRI-STATE: this part has no /OE pin. TEST is the only   **
** disable, and the RTL drives the INACTIVE LEVEL (1 on every _n pin), not **
** z. Checked explicitly below.                                            **
**                                                                         **
** A single flipped product term is caught: e.g. dropping /IORQ from the   **
** DSTB middle term makes DSTB assert for CACT * /BDRY50 * /BDRY25 * IORQ, a     **
** combination this sweep visits 2^8 times; the first one fails.           **
**                                                                         **
** Run: cd Verilog/PAL/sim && make test-pal44302b                          **
**                                                                         **
** Last reviewed: 20-AUG-2026                                              **
** Ronny Hansen                                                            **
*****************************************************************************/
`timescale 1ns / 1ps
`default_nettype none

module PAL_44302B_tb;

  reg CK, sys_rst_n;
  reg Q0_n, Q2_n, CC2_n, BDRY25_n, BDRY50_n, CGNT_n, CGNT50_n, CACT_n, TERM_n, BGNT_n;
  reg TEST, IORQ_n, RT_n;

  wire BGNTCACT_n, CGNTCACT_n, EMD_n, DSTB_n;

  integer checks = 0;
  integer errors = 0;
  integer vec;
  integer st;
  integer dumped = 0;

  PAL_44302B DUT (
      .CK(CK), .sys_rst_n(sys_rst_n),
      .Q0_n(Q0_n), .Q2_n(Q2_n), .CC2_n(CC2_n),
      .BDRY25_n(BDRY25_n), .BDRY50_n(BDRY50_n),
      .CGNT_n(CGNT_n), .CGNT50_n(CGNT50_n), .CACT_n(CACT_n),
      .TERM_n(TERM_n), .BGNT_n(BGNT_n),
      .BGNTCACT_n(BGNTCACT_n), .CGNTCACT_n(CGNTCACT_n),
      .EMD_n(EMD_n), .DSTB_n(DSTB_n),
      .TEST(TEST), .IORQ_n(IORQ_n), .RT_n(RT_n)
  );

  // ---- golden model, straight from the PALASM listing -------------------
  // active-high senses of the active-low pins
  wire g_Q0 = ~Q0_n, g_Q2 = ~Q2_n, g_CC2 = ~CC2_n;
  wire g_CGNT = ~CGNT_n, g_CGNT50 = ~CGNT50_n, g_CACT = ~CACT_n;
  wire g_IORQ = ~IORQ_n, g_RT = ~RT_n, g_BGNT = ~BGNT_n;

  wire g_set  = (g_Q2 & g_Q0 & g_CACT) | (g_CGNT & g_CGNT50);
  wire g_hold = (g_CACT) | (g_RT & g_CC2 & TERM_n) | (g_IORQ & g_CC2 & TERM_n);

  reg  g_emd;                       // the state we forced into the DUT
  wire g_emd_next = g_set | (g_emd & g_hold);

  wire g_CGNTCACT_n = ~(g_CGNT | g_CACT);
  wire g_BGNTCACT_n = ~(g_BGNT | g_CACT);
  wire g_DSTB_n = ~( g_CGNT
                   | (g_CACT & BDRY50_n & BDRY25_n & IORQ_n)
                   | (g_CACT & g_IORQ & g_CC2) );
  wire g_EMD_n = ~g_emd;

  task chk (input [127:0] name, input got, input exp);
    begin
      checks = checks + 1;
      if (got !== exp) begin
        errors = errors + 1;
        if (errors < 12)
          $display("FAIL %0s: got=%b exp=%b | st=%b TEST=%b Q0_n=%b Q2_n=%b CC2_n=%b BDRY25_n=%b BDRY50_n=%b CGNT_n=%b CGNT50_n=%b CACT_n=%b TERM_n=%b BGNT_n=%b IORQ_n=%b RT_n=%b",
                   name, got, exp, g_emd, TEST, Q0_n, Q2_n, CC2_n, BDRY25_n, BDRY50_n,
                   CGNT_n, CGNT50_n, CACT_n, TERM_n, BGNT_n, IORQ_n, RT_n);
      end
    end
  endtask

  // Force the latch/flop into a chosen state, then settle.
  task set_state (input v);
    begin
      g_emd = v;
      DUT.EMD = v;
      #1;
    end
  endtask

  task tick;
    begin
      CK = 1'b0; #1; CK = 1'b1; #1; CK = 1'b0; #1;
    end
  endtask

  initial begin
    $dumpfile("PAL_44302B_tb.vcd");
    $dumpvars(0, PAL_44302B_tb);
  end

  initial begin
    CK = 1'b0; sys_rst_n = 1'b1; g_emd = 1'b0;
    $display("=====================================================");
    $display(" PAL_44302B (LBC1) exhaustive golden testbench");
    $display(" 13 input pins x 1 state bit = 16384 combinations");
    $display("=====================================================");

    for (st = 0; st < 2; st = st + 1) begin
      for (vec = 0; vec < 8192; vec = vec + 1) begin
        {Q0_n, Q2_n, CC2_n, BDRY25_n, BDRY50_n, CGNT_n, CGNT50_n,
         CACT_n, TERM_n, BGNT_n, TEST, IORQ_n, RT_n} = vec[12:0];
        set_state(st[0]);

        if (TEST === 1'b0) begin
          chk("CGNTCACT_n", CGNTCACT_n, g_CGNTCACT_n);
          chk("BGNTCACT_n", BGNTCACT_n, g_BGNTCACT_n);
          chk("DSTB_n",     DSTB_n,     g_DSTB_n);
          chk("EMD_n",      EMD_n,      g_EMD_n);
        end else begin
          // TEST disables every output; the RTL must present the INACTIVE
          // level (1 on an _n pin) and never z.
          chk("TEST_CGNTCACT_n", CGNTCACT_n, 1'b1);
          chk("TEST_BGNTCACT_n", BGNTCACT_n, 1'b1);
          chk("TEST_DSTB_n",     DSTB_n,     1'b1);
          chk("TEST_EMD_n",      EMD_n,      1'b1);
        end

        // next-state of the EMD feedback term
        tick;
        if (TEST === 1'b0) chk("EMD_n_next", EMD_n, ~g_emd_next);

        dumped = dumped + 1;
        if (dumped == 40) $dumpoff;   // keep the committed VCD short
      end
    end

    // ---- named property checks --------------------------------------

    // 1. async reset clears the EMD flop (flip-flop build only)
    TEST = 1'b0;
    set_state(1'b1);
    sys_rst_n = 1'b0; #1;
`ifndef USE_TRANSPARENT_LATCHES
    checks = checks + 1;
    if (EMD_n !== 1'b1) begin
      errors = errors + 1;
      $display("FAIL RESET: EMD_n=%b, async reset must clear EMD", EMD_n);
    end
`endif
    sys_rst_n = 1'b1; #1;

    // 2. no output ever floats - z is never legal inside the FPGA
    checks = checks + 1;
    if (^{BGNTCACT_n, CGNTCACT_n, EMD_n, DSTB_n} === 1'bx) begin
      errors = errors + 1;
      $display("FAIL NO_Z: an output is x/z (%b %b %b %b)",
               BGNTCACT_n, CGNTCACT_n, EMD_n, DSTB_n);
    end

    // 3. THE 30-JUL AUDIT TERM: DSTB must assert on a plain CPU-from-bus
    //    read, i.e. CACT * /BDRY50 * /BDRY25 * /IORQ with no CGNT and no IOX.
    TEST = 1'b0; CGNT_n = 1'b1; CGNT50_n = 1'b1; CACT_n = 1'b0;
    BDRY50_n = 1'b1; BDRY25_n = 1'b1; IORQ_n = 1'b1; CC2_n = 1'b1; #1;
    checks = checks + 1;
    if (DSTB_n !== 1'b0) begin
      errors = errors + 1;
      $display("FAIL DSTB_READ_TERM: DSTB_n=%b, must be asserted (0)", DSTB_n);
    end
    //    and it must NOT assert once IORQ appears without CC2
    IORQ_n = 1'b0; #1;
    checks = checks + 1;
    if (DSTB_n !== 1'b1) begin
      errors = errors + 1;
      $display("FAIL DSTB_IORQ_BLOCK: DSTB_n=%b, /IORQ term must drop out", DSTB_n);
    end

    // 4. EMD hold term: once set, CACT alone must hold it
    TEST = 1'b0; Q0_n = 1'b0; Q2_n = 1'b0; CACT_n = 1'b0;
    CGNT_n = 1'b1; CGNT50_n = 1'b1; #1;
    set_state(1'b0);
    tick;
    checks = checks + 1;
    if (EMD_n !== 1'b0) begin
      errors = errors + 1;
      $display("FAIL EMD_SET: EMD_n=%b, Q2*Q0*CACT must set EMD", EMD_n);
    end
    Q0_n = 1'b1; #1;             // drop the set term, keep CACT
    tick;
    checks = checks + 1;
    if (EMD_n !== 1'b0) begin
      errors = errors + 1;
      $display("FAIL EMD_HOLD: EMD_n=%b, CACT must hold EMD", EMD_n);
    end
    CACT_n = 1'b1; RT_n = 1'b1; IORQ_n = 1'b1; #1;   // drop every hold term
    tick;
    checks = checks + 1;
    if (EMD_n !== 1'b1) begin
      errors = errors + 1;
      $display("FAIL EMD_CLEAR: EMD_n=%b, EMD must fall with no hold term", EMD_n);
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

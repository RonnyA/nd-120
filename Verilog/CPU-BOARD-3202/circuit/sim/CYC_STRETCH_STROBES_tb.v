/**************************************************************************
** CYCFSM strobe contract under a STRETCHED memory grant (iverilog)       **
**                                                                        **
** DUTs: PAL_44601B (CYCFSM cycle state counter, sheet 36) and            **
** PAL_44307C (CYCLK strobe decode, sheet 13D). Both are used untouched.  **
**                                                                        **
** THE CONTRACT THIS BENCH PINS (verified against the PAL equations and   **
** closed on silicon 27-AUG-2026):                                        **
**                                                                        **
**   State walk of a slow memory cycle (CC3..CC0, SLOW active, WAIT1=     **
**   WAIT2=1, BRK/HIT/SHORT inactive):                                    **
**     a(0000) b(0001) c(0011) d(0010) e(0110) f(0111) g(0101) h(0100)    **
**   TERM is registered at the end of g and is high during h; the next    **
**   clock returns the FSM to a.                                          **
**                                                                        **
**   - State d exits ONLY when the grant arrives (CGNTCACT active; the    **
**     WAIT1_n bypass product term is dead because the board holds        **
**     WAIT1=1 during memory cycles - CYC_36.v drives                     **
**     s_wait1 = MR_n & (MREQ|IORQ)). A DELAYED grant stretches d.        **
**   - State e exits ONLY when the grant is released (CGNTCACT_n; the     **
**     WAIT2_n bypass is dead the same way). A HELD grant stretches e.    **
**   - CYD is a LEVEL decode, ACTIVE HIGH (PAL history: "300687 JLB: CYD  **
**     POSITIVE POLARITY"; the board consumes it active-high -            **
**     CPU_MMU_24.v WMAP_n = ~(LSHADOW & WRITE & CYD)). High through      **
**     states d..f, so its high time is 3 + arrival_delay + hold_extra    **
**     sysclks: the pulse ELONGATES with the grant stretch.               **
**   - UCLK is ACTIVE HIGH in state c only (the PAL also holds state c    **
**     while a grant from a previous buffered write is still active -     **
**     the "e PREV WRITE" hold term in PAL_44601B CC0 - which would       **
**     elongate UCLK too; this drive never grants during c, so UCLK       **
**     stays 1 sysclk here).                                              **
**   - WRFSTB is ACTIVE HIGH in state b only (1 sysclk, never stretched). **
**   - EORF_n is ACTIVE LOW in state d only, so it elongates with a       **
**     DELAYED grant and is untouched by a HELD one.                      **
**                                                                        **
**   THE HEADLINE INVARIANT: every strobe rises EXACTLY ONCE per machine  **
**   cycle at every stretch. Strobes elongate; they never REPEAT. That    **
**   single-edge property is the corruption-relevant one: the PT-RAM      **
**   write repetition during a freeze happens downstream, in the          **
**   TMM2018D model consuming a held WMAP_n, not in these PALs.           **
**                                                                        **
** WHY THE OLD BENCH REPORTED 41 FAILURES (27-AUG-2026 analysis - they    **
** were the bench's own artifacts, kept here as the record):              **
**   1. It counted INVERTED CYD and UCLK ("~cyd", "~uclk"), so the wait   **
**      states' LOW time was booked as strobe assertion.                  **
**   2. Its count window was "grant + 12 clocks", so the window itself    **
**      grew with the stretch and every count grew with it.               **
**   3. It tied WAIT1=WAIT2=0, which turns ON the WAIT1_n/WAIT2_n bypass  **
**      product terms - the FSM never actually waited for the grant, the  **
**      exact behavior under test. The board drives both to 1 during      **
**      memory cycles (CYC_36.v).                                         **
**   4. It sampled a free-running FSM (SLOW inactive, so no TERM ever     **
**      fired) at whatever phase each run happened to start - no anchor.  **
**                                                                        **
** SILICON CLOSURE (27-AUG-2026, Verilog/TODO.md): the elongated-CYD      **
** consequence (PT RAMs rewriting every sysclk of a DDR2 freeze) is       **
** MEASURED HARMLESS - the overlap probe (DBG_PTW_LVL & MEM_HOLD,         **
** sticky+counter) stayed 0/0 across a full SINTRAN boot, and the         **
** wrong-PPN trap signature (TVEC 3 at PIL>=8) never fired in two armed   **
** full boots. The 25-AUG wrong-PPN ERRFATAL is attributed to the         **
** stale-word cache bug fixed the same evening.                           **
**                                                                        **
** Method: every measurement is anchored to ONE machine cycle delimited   **
** by TERM. The FSM parks in state d until the bench grants, so cycle     **
** boundaries are deterministic. Sweeps: grant arrival delayed 0..40      **
** sysclks; grant release held 0..40 extra sysclks; 3 combined points.    **
** Per point this bench asserts:                                          **
**   (a) exactly ONE rising edge of CYD, UCLK, WRFSTB, EORF per cycle;    **
**   (b) exact high-time law: CYD = 3+delay+hold, EORF = 1+delay,         **
**       UCLK = 1, WRFSTB = 1 (elongation REAL and pinned, not hidden);   **
**   (c) TERM fires within the watchdog - the cycle always completes.     **
**                                                                        **
** Original bench history note (25-AUG-2026): written during the Nexys    **
** wrong-PPN-fetch hunt to ask whether the MEM_RAM_49_DDR2 cache-miss     **
** freeze (which holds CGNTCACT) elongates or repeats the write strobes.  **
** Answer, now pinned: elongates yes (documented above), repeats never.   **
**                                                                        **
** Verdict: prints "TB_RESULT: PASS" / "TB_RESULT: FAIL ...".             **
**                                                                        **
** Run: make test-cycstretch   (CPU-BOARD-3202/circuit/sim)               **
**                                                                        **
** Last reviewed: 27-AUG-2026                                             **
** Ronny Hansen                                                           **
***************************************************************************/
`timescale 1ns / 1ps

module CYC_STRETCH_STROBES_tb;

  reg clk = 0;
  always #30 clk = ~clk;

  // ---- CYCFSM (PAL_44601B), board-real memory-cycle drive ----
  // SLOW active = slow memory cycle (the kind that traverses d/e).
  // WAIT1 = WAIT2 = 1 = what CYC_36 drives during a memory cycle; this
  // KEEPS the wait states real (0 would bypass them - old-bench bug 3).
  reg dly1_n = 1, dly0_n = 1, csdelay0 = 0, wait1 = 1, wait2 = 1;
  reg cgntcact_n = 1, hit = 0, brk_n = 1;
  reg slow_n = 0, short_n = 1;
  wire cx_n, term_n, cc0_n, cc1_n, cc2_n, cc3_n;

  PAL_44601B u_cyc (
      .CK(clk), .OE_n(1'b0),
      .DLY1_n(dly1_n), .DLY0_n(dly0_n), .CSDELAY0(csdelay0),
      .WAIT1(wait1), .WAIT2(wait2), .CGNTCACT_n(cgntcact_n),
      .HIT(hit), .BRK_n(brk_n),
      .SLOW_n(slow_n), .SHORT_n(short_n),
      .CX_n(cx_n), .TERM_n(term_n),
      .CC0_n(cc0_n), .CC1_n(cc1_n), .CC2_n(cc2_n), .CC3_n(cc3_n)
  );

  // ---- strobe decoder (PAL_44307C) ----
  // FORM/RWCS/TRAP inactive: MAP_n and MACLK_n stay quiet; the four
  // strobes under contract are CYD, UCLK, WRFSTB, EORF.
  reg form_n = 1, rwcs_n = 1, trap_n = 1, vex = 0;
  wire mclk_n, maclk_n, wrfstb, cyd, eorf_n, uclk, etrap_n, map_n;

  PAL_44307C u_str (
      .TERM_n(term_n),
      .CC0_n(cc0_n), .CC1_n(cc1_n), .CC2_n(cc2_n), .CC3_n(cc3_n),
      .FORM_n(form_n), .BRK_n(brk_n), .RWCS_n(rwcs_n),
      .TRAP_n(trap_n), .VEX(vex),
      .MCLK_n(mclk_n), .MACLK_n(maclk_n),
      .WRFSTB(wrfstb), .CYD(cyd), .EORF_n(eorf_n), .UCLK(uclk),
      .ETRAP_n(etrap_n), .MAP_n(map_n)
  );

  // ---- TRUE-polarity strobe views (old-bench bug 1 was inverting these) --
  wire s_cyd  = cyd;      // ACTIVE HIGH ("CYD POSITIVE POLARITY", 300687 JLB)
  wire s_uclk = uclk;     // ACTIVE HIGH (high in state c)
  wire s_wrf  = wrfstb;   // ACTIVE HIGH (high in state b)
  wire s_eorf = ~eorf_n;  // pin is active LOW (low in state d)

  wire [3:0] state = {~cc3_n, ~cc2_n, ~cc1_n, ~cc0_n};
  localparam [3:0] ST_D = 4'b0010, ST_E = 4'b0110;

  // per-cycle counters: rising edges and high (asserted) sysclks
  integer e_cyd, l_cyd, e_uclk, l_uclk, e_wrf, l_wrf, e_eorf, l_eorf;
  reg p_cyd, p_uclk, p_wrf, p_eorf;
  integer errors = 0;
  reg cycle_done;

  localparam WATCHDOG_CLKS = 4000;

  // Run ONE machine cycle, anchored to TERM (old-bench bugs 2 and 4 were
  // a stretch-dependent window and no anchor). Must be entered right
  // after the previous cycle's TERM clock was consumed (or from the
  // zeroed power-up state, which is state a with TERM low).
  //
  //   d_delay = sysclks the grant ARRIVAL is delayed once state d is seen
  //   e_hold  = extra sysclks the grant is HELD once state e is seen
  //
  // Everything is sampled at negedge: the PAL registers clock on posedge,
  // so state and its combinational decodes are settled at every negedge.
  integer dwait, ewait, guard;
  reg granted, released;
  task run_one_cycle(input integer d_delay, input integer e_hold);
    begin
      e_cyd = 0; l_cyd = 0; e_uclk = 0; l_uclk = 0;
      e_wrf = 0; l_wrf = 0; e_eorf = 0; l_eorf = 0;
      p_cyd = 0; p_uclk = 0; p_wrf = 0; p_eorf = 0;
      dwait = 0; ewait = 0; guard = 0;
      granted = 0; released = 0;
      cycle_done = 0;
      while (!cycle_done) begin
        @(negedge clk);
        // count with TRUE polarities inside the TERM-delimited window
        if (s_cyd)               l_cyd  = l_cyd + 1;
        if (s_cyd  && !p_cyd)    e_cyd  = e_cyd + 1;
        if (s_uclk)              l_uclk = l_uclk + 1;
        if (s_uclk && !p_uclk)   e_uclk = e_uclk + 1;
        if (s_wrf)               l_wrf  = l_wrf + 1;
        if (s_wrf  && !p_wrf)    e_wrf  = e_wrf + 1;
        if (s_eorf)              l_eorf = l_eorf + 1;
        if (s_eorf && !p_eorf)   e_eorf = e_eorf + 1;
        p_cyd = s_cyd; p_uclk = s_uclk; p_wrf = s_wrf; p_eorf = s_eorf;

        // grant choreography, anchored to the observed state
        if (state == ST_D && term_n && !granted) begin
          if (dwait == d_delay) begin
            cgntcact_n = 0;   // grant arrives (active low)
            granted    = 1;
          end else dwait = dwait + 1;
        end
        if (state == ST_E && term_n && granted && !released) begin
          if (ewait == e_hold) begin
            cgntcact_n = 1;   // grant released
            released   = 1;
          end else ewait = ewait + 1;
        end

        if (!term_n) cycle_done = 1;   // TERM clock counted, cycle over

        guard = guard + 1;
        if (guard > WATCHDOG_CLKS) begin
          errors = errors + 1;
          $display("FAIL: livelock - no TERM within %0d clks at delay=%0d hold=%0d (state=%b granted=%b released=%b)",
                   WATCHDOG_CLKS, d_delay, e_hold, state, granted, released);
          cgntcact_n = 1;
          cycle_done = 1;
        end
      end
    end
  endtask

  task check_point(input integer d_delay, input integer e_hold);
    begin
      // (a) headline invariant: exactly ONE rising edge per strobe per cycle
      if (e_cyd != 1 || e_uclk != 1 || e_wrf != 1 || e_eorf != 1) begin
        errors = errors + 1;
        $display("FAIL: edge count != 1 at delay=%0d hold=%0d: CYD %0d UCLK %0d WRFSTB %0d EORF %0d",
                 d_delay, e_hold, e_cyd, e_uclk, e_wrf, e_eorf);
      end
      // (b) exact high-time law: elongation is real and pinned
      if (l_cyd != 3 + d_delay + e_hold) begin
        errors = errors + 1;
        $display("FAIL: CYD high-time %0d != %0d (3+delay+hold) at delay=%0d hold=%0d",
                 l_cyd, 3 + d_delay + e_hold, d_delay, e_hold);
      end
      if (l_eorf != 1 + d_delay) begin
        errors = errors + 1;
        $display("FAIL: EORF low-time %0d != %0d (1+delay) at delay=%0d hold=%0d",
                 l_eorf, 1 + d_delay, d_delay, e_hold);
      end
      if (l_uclk != 1 || l_wrf != 1) begin
        errors = errors + 1;
        $display("FAIL: UCLK/WRFSTB stretched at delay=%0d hold=%0d: UCLK %0d WRFSTB %0d (both must be 1)",
                 d_delay, e_hold, l_uclk, l_wrf);
      end
    end
  endtask

  integer k, prev_l_cyd;

  initial begin
`ifdef DUMP
    $dumpfile("CYC_STRETCH_STROBES_tb.vcd");
    $dumpvars(0, CYC_STRETCH_STROBES_tb);
`endif
    // PAL registers have no initializer - zero them (same practice as
    // MEM_RAMC_50_tb / MEM_CHAIN_DDR2_tb). Zero state = a, TERM low.
    u_cyc.TERM_reg = 0; u_cyc.CC0_reg = 0; u_cyc.CC1_reg = 0;
    u_cyc.CC2_reg = 0;  u_cyc.CC3_reg = 0;

    // warm-up cycle: from power-up to the first TERM (not checked)
    run_one_cycle(0, 0);

    // baseline cycle: prompt grant, prompt release
    run_one_cycle(0, 0);
    check_point(0, 0);
    $display("baseline (delay=0 hold=0): CYD e%0d/l%0d UCLK e%0d/l%0d WRFSTB e%0d/l%0d EORF e%0d/l%0d",
             e_cyd, l_cyd, e_uclk, l_uclk, e_wrf, l_wrf, e_eorf, l_eorf);

    // sweep 1: grant ARRIVAL delayed 0..40 sysclks (state d stretch)
    for (k = 0; k <= 40; k = k + 1) begin
      run_one_cycle(k, 0);
      check_point(k, 0);
    end
    $display("arrival sweep 0..40 done: at delay=40 CYD e%0d/l%0d EORF e%0d/l%0d UCLK l%0d WRFSTB l%0d",
             e_cyd, l_cyd, e_eorf, l_eorf, l_uclk, l_wrf);

    // sweep 2: grant RELEASE held 0..40 extra sysclks (state e stretch),
    // with the monotonic-growth check made explicit
    prev_l_cyd = -1;
    for (k = 0; k <= 40; k = k + 1) begin
      run_one_cycle(0, k);
      check_point(0, k);
      if (l_cyd <= prev_l_cyd) begin
        errors = errors + 1;
        $display("FAIL: CYD high-time not monotonic at hold=%0d: %0d after %0d",
                 k, l_cyd, prev_l_cyd);
      end
      prev_l_cyd = l_cyd;
    end
    $display("hold sweep 0..40 done: at hold=40 CYD e%0d/l%0d EORF e%0d/l%0d UCLK l%0d WRFSTB l%0d",
             e_cyd, l_cyd, e_eorf, l_eorf, l_uclk, l_wrf);

    // combined points: both stretches at once
    run_one_cycle(7, 7);    check_point(7, 7);
    run_one_cycle(13, 29);  check_point(13, 29);
    run_one_cycle(40, 40);  check_point(40, 40);
    $display("combined (40,40): CYD e%0d/l%0d EORF e%0d/l%0d UCLK l%0d WRFSTB l%0d",
             e_cyd, l_cyd, e_eorf, l_eorf, l_uclk, l_wrf);

    if (errors == 0)
      $display("TB_RESULT: PASS (85 TERM-anchored cycles: one rising edge per strobe per cycle at every stretch; CYD=3+delay+hold, EORF=1+delay, UCLK=WRFSTB=1)");
    else
      $display("TB_RESULT: FAIL (%0d contract violations)", errors);
    $finish;
  end

  initial begin
    #60_000_000;
    $display("TB_RESULT: FAIL (watchdog)");
    $finish;
  end

endmodule

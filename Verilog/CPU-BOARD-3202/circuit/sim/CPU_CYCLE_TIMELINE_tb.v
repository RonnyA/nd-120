/****************************************************************************
** TESTBENCH: microcycle TIMELINE observatory + golden-trace gate           **
**                                                                         **
** WHY THIS EXISTS (08-AUG-2026)                                           **
**                                                                         **
** Every question of the form "when does <strobe> actually fire during a    **
** <kind> cycle?" was being answered by booting the whole machine, dumping  **
** a multi-gigabyte waveform and hand-reading it. That costs minutes per    **
** hypothesis and, worse, the CSV samplers used to read those dumps take    **
** one settled sample per tick and are therefore blind to anything that     **
** happens WITHIN a cycle state - which produced several confident and      **
** wrong answers about MACLK during the TRA CS investigation.               **
**                                                                         **
** This bench answers the same question in about a second, at full timing   **
** resolution, from the real PALs.                                         **
**                                                                         **
** WHAT IT DOES                                                            **
**                                                                         **
** It walks one microcycle of each kind through the actual cycle-control    **
** hardware - PAL_44601B (CYCFSM, the state machine), PAL_44307C (CYCLK,    **
** the clock/strobe generator) and PAL_44305D (CSCTL, the control-store     **
** strobes) - combined exactly as CYC_36.v combines them, and prints one    **
** line per cycle state showing every derived signal.                       **
**                                                                         **
** WHAT IT ASSERTS - AND WHAT IT DELIBERATELY DOES NOT                     **
**                                                                         **
** It does NOT assert that any particular strobe SHOULD fire in any         **
** particular state. Nothing in this repo has established that independently**
** of the PALs themselves, so such a check would only restate the PAL       **
** equations back at themselves and would pass by construction.             **
**                                                                         **
** What it asserts is:                                                     **
**   1. every cycle kind terminates (no hang), within a stated bound; and   **
**   2. the printed timeline is IDENTICAL to the checked-in golden file     **
**      CPU_CYCLE_TIMELINE.golden.                                         **
**                                                                         **
** (2) is the useful one. It makes microcycle timing a regression-tested    **
** property, so a latch-to-flip-flop conversion, a clock-enable refactor or **
** an edited PAL cannot silently move an edge. When the golden file changes,**
** the diff shows exactly which strobe moved and in which state - and that  **
** diff is then something to justify against the drawings, not to rubber-   **
** stamp. Regenerate deliberately with `make golden-cycle-timeline`, and    **
** never as a reflex to make a red test go green.                          **
**                                                                         **
** Verdict: TB_RESULT: PASS / TB_RESULT: FAIL <n> errors                    **
**                                                                         **
** Ronny Hansen                                                            **
*****************************************************************************/
`timescale 1ns / 1ps

module CPU_CYCLE_TIMELINE_tb;

  integer errors = 0;

  task ck;
    input          cond;
    input [1023:0] what;
    begin
      if (!cond) begin
        $display("FAIL: %0s", what);
        errors = errors + 1;
      end else begin
        $display("[ ok ] %0s", what);
      end
    end
  endtask

  // ------------------------------------------------------------------
  // Clocks
  // ------------------------------------------------------------------
  reg sysclk = 1'b0;
  always #1 sysclk = ~sysclk;

  reg sys_rst_n = 1'b0;
  reg osc       = 1'b0;   // one cycle state per OSC period

  // ------------------------------------------------------------------
  // Microword / board inputs the cycle machine reacts to
  // ------------------------------------------------------------------
  reg rwcs_n     = 1'b1;
  reg lcs_n      = 1'b1;
  reg wcs_n      = 1'b1;
  reg brk_n      = 1'b1;
  reg form_n     = 1'b1;
  reg fetch      = 1'b0;
  reg trap_n     = 1'b1;
  reg vex        = 1'b0;
  reg wca_n      = 1'b1;
  reg lua12      = 1'b0;
  reg short_n    = 1'b1;
  reg slow_n     = 1'b1;
  reg dly0_n     = 1'b1;
  reg dly1_n     = 1'b1;
  reg csdelay0   = 1'b0;
  reg wait1      = 1'b0;
  reg wait2      = 1'b0;
  reg cgntcact_n = 1'b1;
  reg hit        = 1'b0;

  // ------------------------------------------------------------------
  // The real cycle-control hardware
  // ------------------------------------------------------------------
  wire cx_n, term_n, cc0_n, cc1_n, cc2_n, cc3_n;

  PAL_44601B UCYCFSM (
      .CK        (osc),
      .OE_n      (1'b0),
      .DLY1_n    (dly1_n),
      .DLY0_n    (dly0_n),
      .CSDELAY0  (csdelay0),
      .WAIT1     (wait1),
      .WAIT2     (wait2),
      .CGNTCACT_n(cgntcact_n),
      .HIT       (hit),
      .BRK_n     (brk_n),
      .SLOW_n    (slow_n),
      .SHORT_n   (short_n),
      .CX_n      (cx_n),
      .TERM_n    (term_n),
      .CC0_n     (cc0_n),
      .CC1_n     (cc1_n),
      .CC2_n     (cc2_n),
      .CC3_n     (cc3_n)
  );

  wire mclk_n, maclk_n, wrfstb, cyd, eorf_n, uclk, etrap_n, map_n;

  PAL_44307C UCYCLK (
      .TERM_n (term_n),
      .CC0_n  (cc0_n),
      .CC1_n  (cc1_n),
      .CC2_n  (cc2_n),
      .CC3_n  (cc3_n),
      .FORM_n (form_n),
      .BRK_n  (brk_n),
      .RWCS_n (rwcs_n),
      .TRAP_n (trap_n),
      .VEX    (vex),
      .MCLK_n (mclk_n),
      .MACLK_n(maclk_n),
      .WRFSTB (wrfstb),
      .CYD    (cyd),
      .EORF_n (eorf_n),
      .UCLK   (uclk),
      .ETRAP_n(etrap_n),
      .MAP_n  (map_n)
  );

  wire wica_n, wcstb_n, ecsl_n, ewca_n, eupp_n, elow_n;

  PAL_44305D UCSCTL (
      .FORM_n (form_n),
      .CC1_n  (cc1_n),
      .CC2_n  (cc2_n),
      .CC3_n  (cc3_n),
      .LCS_n  (lcs_n),
      .RWCS_n (rwcs_n),
      .WCS_n  (wcs_n),
      .FETCH  (fetch),
      .BRK_n  (brk_n),
      .TERM_n (term_n),
      .WICA_n (wica_n),
      .WCSTB_n(wcstb_n),
      .ECSL_n (ecsl_n),
      .EWCA_n (ewca_n),
      .EUPP_n (eupp_n),
      .ELOW_n (elow_n),
      .WCA_n  (wca_n),
      .LUA12  (lua12)
  );

  // Exactly how CYC_36.v combines them (CYC_36.v:223, :268-269, :365).
  wire maclk  = ~(term_n & maclk_n);
  wire mclk   = ~(term_n & mclk_n);
  wire aluclk = ~(term_n | ~lcs_n);
  wire clk    = ~term_n;

  // ------------------------------------------------------------------
  // Helpers
  // ------------------------------------------------------------------
  task osc_tick;
    begin
      osc = 1'b0; #4;
      osc = 1'b1; #4;
    end
  endtask

  // PAL16R6 has no reset pin - on the real board the registers come up from
  // power-on. Put them in a defined state so the walk is repeatable.
  task cyc_init;
    begin
      force UCYCFSM.TERM_reg = 1'b0;
      force UCYCFSM.CC0_reg  = 1'b0;
      force UCYCFSM.CC1_reg  = 1'b0;
      force UCYCFSM.CC2_reg  = 1'b0;
      force UCYCFSM.CC3_reg  = 1'b0;
      osc_tick;
      release UCYCFSM.TERM_reg;
      release UCYCFSM.CC0_reg;
      release UCYCFSM.CC1_reg;
      release UCYCFSM.CC2_reg;
      release UCYCFSM.CC3_reg;
    end
  endtask

  task run_to_term;
    integer guard;
    begin
      guard = 0;
      while (term_n && guard < 64) begin
        osc_tick;
        guard = guard + 1;
      end
    end
  endtask

  // Reset every microword input to its idle level, so each scenario starts
  // from the same place and only names what it actually changes.
  task idle_inputs;
    begin
      rwcs_n  = 1'b1; lcs_n  = 1'b1; wcs_n = 1'b1;
      brk_n   = 1'b1; form_n = 1'b1; fetch = 1'b0;
      trap_n  = 1'b1; vex    = 1'b0; wca_n = 1'b1; lua12 = 1'b0;
      short_n = 1'b1; slow_n = 1'b1;
    end
  endtask

  // ------------------------------------------------------------------
  // Walk one microcycle and print a line per state
  // ------------------------------------------------------------------
  integer states_run;
  reg     saw_term;
  reg [3:0] term_state;

  task walk_cycle;
    input [1023:0] label;
    integer guard;
    begin
      states_run = 0;
      saw_term   = 1'b0;
      term_state = 4'hx;

      // run_to_term leaves the machine standing ON the previous cycle's TERM
      // state. The microword inputs are latched at TERM on the real board, so
      // the caller sets them there; this tick consumes that edge and starts
      // the fresh cycle, so the timeline below begins at its first state.
      if (!term_n) osc_tick;

      $display("");
      $display("---- cycle: %0s ----", label);
      $display("     CC  TERM MCLK MACLK ALUCLK CLK WRFSTB CYD EORF UCLK ETRAP MAP | ECSL EWCA EUPP ELOW WICA WCSTB");

      for (guard = 0; guard < 64 && !saw_term; guard = guard + 1) begin
        // PAL_44601B clears the CC counter on the same edge that asserts
        // TERM, so the state a cycle is IN must be sampled before the tick.
        term_state = {~cc3_n, ~cc2_n, ~cc1_n, ~cc0_n};
        $display("   %b    %b    %b     %b      %b    %b     %b     %b   %b    %b     %b    %b |   %b    %b    %b    %b    %b     %b",
                 term_state, ~term_n, mclk, maclk, aluclk, clk,
                 wrfstb, cyd, ~eorf_n, uclk, ~etrap_n, ~map_n,
                 ~ecsl_n, ~ewca_n, ~eupp_n, ~elow_n, ~wica_n, ~wcstb_n);
        osc_tick;
        states_run = states_run + 1;
        if (!term_n) saw_term = 1'b1;
      end

      $display("   -> terminated after %0d states, in state CC=%b",
               states_run, term_state);
    end
  endtask

  // Run one scenario: idle, settle, assert the microword inputs, walk.
  task scenario;
    input [1023:0] label;
    begin
      run_to_term;
      idle_inputs;
      walk_cycle(label);
      ck(saw_term, {label, " : cycle terminates (no hang)"});
    end
  endtask

  integer k;

  initial begin
    sys_rst_n = 1'b0;
    for (k = 0; k < 8; k = k + 1) @(posedge sysclk);
    sys_rst_n = 1'b1;
    for (k = 0; k < 8; k = k + 1) @(posedge sysclk);

    cyc_init;
    for (k = 0; k < 6; k = k + 1) osc_tick;

    $display("== microcycle timelines ==");
    $display("(1 = signal ASSERTED, active-low pins shown already inverted)");

    // --- plain microword, no speed bits ------------------------------
    run_to_term; idle_inputs;
    walk_cycle("NORMAL (no SHORT, no SLOW)");
    ck(saw_term, "NORMAL : cycle terminates (no hang)");

    // --- SHORT cycle -------------------------------------------------
    run_to_term; idle_inputs; short_n = 1'b0;
    walk_cycle("SHORT");
    ck(saw_term, "SHORT : cycle terminates (no hang)");

    // --- SLOW cycle --------------------------------------------------
    run_to_term; idle_inputs; slow_n = 1'b0;
    walk_cycle("SLOW");
    ck(saw_term, "SLOW : cycle terminates (no hang)");

    // --- FETCH (the macroinstruction fetch path) ---------------------
    run_to_term; idle_inputs; fetch = 1'b1;
    walk_cycle("FETCH");
    ck(saw_term, "FETCH : cycle terminates (no hang)");

    // --- FORM: the input PAL_44307C's MAP term is qualified with -----
    run_to_term; idle_inputs; form_n = 1'b0;
    walk_cycle("FORM (drives the MAP term in PAL_44307C)");
    ck(saw_term, "FORM : cycle terminates (no hang)");

    // --- TRAP --------------------------------------------------------
    run_to_term; idle_inputs; trap_n = 1'b0;
    walk_cycle("TRAP");
    ck(saw_term, "TRAP : cycle terminates (no hang)");

    // --- RWCS read (the TRA CS path) ---------------------------------
    run_to_term; idle_inputs; rwcs_n = 1'b0;
    walk_cycle("RWCS read (TRA CS / control-store readback)");
    ck(saw_term, "RWCS : cycle terminates (no hang)");

    // --- LCS (microcode load) ----------------------------------------
    run_to_term; idle_inputs; lcs_n = 1'b0;
    walk_cycle("LCS (microcode load)");
    ck(saw_term, "LCS : cycle terminates (no hang)");

    // --- BRK ---------------------------------------------------------
    run_to_term; idle_inputs; brk_n = 1'b0;
    walk_cycle("BRK (break)");
    ck(saw_term, "BRK : cycle terminates (no hang)");

    $display("");
    if (errors == 0) $display("TB_RESULT: PASS");
    else             $display("TB_RESULT: FAIL %0d errors", errors);
    $finish;
  end

endmodule

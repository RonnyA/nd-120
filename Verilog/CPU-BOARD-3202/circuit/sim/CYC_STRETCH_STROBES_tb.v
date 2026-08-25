/**************************************************************************
** CYCFSM strobe behavior under a STRETCHED memory grant (iverilog)      **
**                                                                       **
** Question under test (25-AUG-2026, Nexys wrong-PPN-fetch hunt): the    **
** MEM_RAM_49_DDR2 cache-miss freeze holds the memory grant, so          **
** CGNTCACT_n stays ACTIVE longer and PAL_44601B waits in its d/e wait   **
** states. PAL_44307C's strobes (CYD "WRITE PULSE USED IN WMAP AND WCA", **
** UCLK "USED TO UPDATE USED BITS", WRFSTB, MACLK) are LEVEL DECODES of  **
** the CC states. HYPOTHESIS: a stretched wait ELONGATES one of those    **
** write pulses (or fires it twice), which can corrupt page-table /      **
** WCA / used-bit writes whose address or data move meanwhile.           **
**                                                                       **
** Method: run the REAL PAL_44601B + PAL_44307C through the same cycle   **
** kind twice - once with the normal CGNTCACT timing, once with the      **
** grant-active phase stretched by N extra cycles - and record every     **
** strobe's assertion cycles. PASS = for every strobe, the stretched     **
** run has the SAME number of assertion EDGES and the SAME total         **
** assertion LENGTH as the reference (i.e. the wait states do not decode **
** into any write strobe). FAIL = any strobe pulses longer or again.     **
**                                                                       **
** Both verdicts are informative: FAIL confirms the corruption           **
** mechanism; PASS refutes it and moves the hunt elsewhere.              **
**                                                                       **
** Verdict: prints "TB_RESULT: PASS" / "TB_RESULT: FAIL ...".            **
**                                                                       **
** Run: make test-cycstretch   (CPU-BOARD-3202/circuit/sim)              **
**                                                                       **
** Last reviewed: 25-AUG-2026                                            **
** Ronny Hansen                                                          **
***************************************************************************/
`timescale 1ns / 1ps

module CYC_STRETCH_STROBES_tb;

  reg clk = 0;
  always #30 clk = ~clk;

  // ---- CYCFSM (PAL_44601B) ----
  reg dly1_n = 1, dly0_n = 1, csdelay0 = 0, wait1 = 0, wait2 = 0;
  reg cgntcact_n = 1, hit = 0, brk_n = 1;
  reg slow_n = 1, short_n = 1;
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

  // ---- per-run strobe accounting -------------------------------------
  // For each strobe: count assertion EDGES and total asserted CYCLES.
  // CYD and EORF_n and MACLK_n are active low at the pin; normalize.
  wire s_cyd    = ~cyd;      // CYD pin is the ACTIVE-LOW write pulse
  wire s_uclk   = ~uclk;     // same
  wire s_wrf    = wrfstb;
  wire s_maclk  = ~maclk_n;

  integer e_cyd, l_cyd, e_uclk, l_uclk, e_wrf, l_wrf, e_maclk, l_maclk;
  reg p_cyd, p_uclk, p_wrf, p_maclk;
  reg counting = 0;

  always @(posedge clk) begin
    if (counting) begin
      p_cyd <= s_cyd;  p_uclk <= s_uclk;  p_wrf <= s_wrf;  p_maclk <= s_maclk;
      if (s_cyd)              l_cyd   = l_cyd + 1;
      if (s_cyd  && !p_cyd)   e_cyd   = e_cyd + 1;
      if (s_uclk)             l_uclk  = l_uclk + 1;
      if (s_uclk && !p_uclk)  e_uclk  = e_uclk + 1;
      if (s_wrf)              l_wrf   = l_wrf + 1;
      if (s_wrf  && !p_wrf)   e_wrf   = e_wrf + 1;
      if (s_maclk)            l_maclk = l_maclk + 1;
      if (s_maclk && !p_maclk) e_maclk = e_maclk + 1;
    end
  end

  task clear_counts;
    begin
      e_cyd=0; l_cyd=0; e_uclk=0; l_uclk=0; e_wrf=0; l_wrf=0;
      e_maclk=0; l_maclk=0;
      p_cyd=0; p_uclk=0; p_wrf=0; p_maclk=0;
    end
  endtask

  // Drive one FULL memory-reference cycle through the FSM. The grant
  // (CGNTCACT active low) is asserted when the FSM reaches the d-state
  // request point and released after `glen` cycles - the stretched run
  // simply holds it longer, exactly what a frozen PAL_44803A does.
  integer gi;
  task run_cycle(input integer glen);
    begin
      // idle: let the FSM settle in a known state
      cgntcact_n = 1;
      repeat (6) @(negedge clk);
      clear_counts;
      counting = 1;
      // start of cycle: the FSM free-runs; when it reaches the d-state it
      // waits for CGNTCACT. Assert the grant after 2 cycles, hold glen.
      repeat (2) @(negedge clk);
      cgntcact_n = 0;
      for (gi = 0; gi < glen; gi = gi + 1) @(negedge clk);
      cgntcact_n = 1;
      // let the cycle complete
      repeat (12) @(negedge clk);
      counting = 0;
    end
  endtask

  integer r_e_cyd, r_l_cyd, r_e_uclk, r_l_uclk, r_e_wrf, r_l_wrf, r_e_maclk, r_l_maclk;
  integer errors = 0;
  integer stretch;

  task compare(input integer stretch_cycles);
    begin
      if (e_cyd != r_e_cyd || e_uclk != r_e_uclk || e_wrf != r_e_wrf || e_maclk != r_e_maclk) begin
        errors = errors + 1;
        $display("FAIL: strobe EDGE count changed at stretch=%0d: CYD %0d->%0d UCLK %0d->%0d WRF %0d->%0d MACLK %0d->%0d",
                 stretch_cycles, r_e_cyd, e_cyd, r_e_uclk, e_uclk, r_e_wrf, e_wrf, r_e_maclk, e_maclk);
      end
      if (l_cyd != r_l_cyd || l_uclk != r_l_uclk || l_wrf != r_l_wrf || l_maclk != r_l_maclk) begin
        errors = errors + 1;
        $display("FAIL: strobe LENGTH changed at stretch=%0d: CYD %0d->%0d UCLK %0d->%0d WRF %0d->%0d MACLK %0d->%0d",
                 stretch_cycles, r_l_cyd, l_cyd, r_l_uclk, l_uclk, r_l_wrf, l_wrf, r_l_maclk, l_maclk);
      end
    end
  endtask

  initial begin
`ifdef DUMP
    $dumpfile("CYC_STRETCH_STROBES_tb.vcd");
    $dumpvars(0, CYC_STRETCH_STROBES_tb);
`endif
    // PAL registers have no initializer - zero them (same practice as
    // MEM_RAMC_50_tb / MEM_CHAIN_DDR2_tb)
    u_cyc.TERM_reg = 0; u_cyc.CC0_reg = 0; u_cyc.CC1_reg = 0;
    u_cyc.CC2_reg = 0;  u_cyc.CC3_reg = 0;
    repeat (8) @(negedge clk);

    // reference: normal grant length (7 cycles ~ one DRAM sequence)
    run_cycle(7);
    r_e_cyd=e_cyd; r_l_cyd=l_cyd; r_e_uclk=e_uclk; r_l_uclk=l_uclk;
    r_e_wrf=e_wrf; r_l_wrf=l_wrf; r_e_maclk=e_maclk; r_l_maclk=l_maclk;
    $display("reference (grant=7): CYD e%0d/l%0d UCLK e%0d/l%0d WRF e%0d/l%0d MACLK e%0d/l%0d",
             r_e_cyd, r_l_cyd, r_e_uclk, r_l_uclk, r_e_wrf, r_l_wrf, r_e_maclk, r_l_maclk);
    if (r_l_cyd == 0 && r_l_uclk == 0 && r_l_wrf == 0 && r_l_maclk == 0) begin
      $display("TB_RESULT: FAIL (no strobes in the reference cycle - drive scheme wrong)");
      $finish;
    end

    // stretched runs: grant held 8..40 extra cycles (a DDR2 miss is
    // ~5-15 cycles at 16.667 MHz; 40 covers refresh-collision worst case)
    for (stretch = 8; stretch <= 47; stretch = stretch + 1) begin
      run_cycle(stretch);
      compare(stretch - 7);
    end

    if (errors == 0)
      $display("TB_RESULT: PASS (strobes identical across all stretches - elongation hypothesis REFUTED at this level)");
    else
      $display("TB_RESULT: FAIL (%0d strobe divergences - stretch DOES alter write strobes)", errors);
    $finish;
  end

  initial begin
    #60_000_000;
    $display("TB_RESULT: FAIL (watchdog)");
    $finish;
  end

endmodule

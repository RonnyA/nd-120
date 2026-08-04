/**************************************************************************
** ND120 CPU - unit test                                                 **
** BIF_DPATH_LDBCTL_12: local data bus control sheet (sheet 12) - the    **
** three LBC PALs wired together: PAL_44303B (ULBC2, WBD/WLBD direction  **
** + CBWRITE/CMWRITE latches), PAL_44302B (ULBC1, EMD latch + DSTB +     **
** the xGNTCACT merges, incl. the audited 30-JUL DSTB middle term), and  **
** PAL_44304E (ULBC3, BACT/EBADR latches + EBD/CLKBD/DBAPR), including   **
** the sheet-level comb feedback BACT_n (44304E B0) -> 44303B I9 (WBD    **
** DMA-output term).                                                     **
**                                                                       **
** INDEPENDENT golden model re-derived from the PALASM comments and the  **
** set/hold/clear structure, not transliterated: five state bits         **
** (CBWRITE, CMWRITE, EMD, BACT, EBADR_n) with set-priority next-state   **
** rules, plus pure-comb output equations computed from state+inputs.    **
**                                                                       **
** TWO BUILD MODES (the Makefile compiles and runs both):                **
**   plain                     - PAL state as posedge-OSC FFs with async **
**                               sys_rst_n (FPGA branch)                 **
**   -DUSE_TRANSPARENT_LATCHES - PAL state as transparent latches        **
**                               (original hardware); sys_rst_n unused,  **
**                               state reacts to inputs with NO clock    **
** The tb golden model switches semantics on the same define: latch      **
** mode applies the next-state rules immediately after every input       **
** change, FF mode only at posedge OSC (async reset immediate). The      **
** SAME stimulus runs in both modes (identical check counts); the        **
** expectations diverge exactly where latch/FF behavior diverges.        **
**                                                                       **
** PINNED (netlist facts, checked as-is):                                **
**   - Top port BGNTCACT carries the ACTIVE-LOW value ~(BGNT|CACT)       **
**     (44302B Y0_n wired straight out despite the un-suffixed name).    **
**   - PAL_44304E ignores its TEST pin (code removed as never used), so  **
**     PD3 kills DSTB/EMD/xGNTCACT (44302B) but NOT EBD/CLKBD/DBAPR/     **
**     EBADR; PD1 kills only the 44303B outputs (WBD/WLBD/CBWRITE).      **
**   - EBADR clear needs IBAPR AND GNT; set (GNT_n&BGNT_n) has priority. **
**                                                                       **
**  1. Init wiggle (latch-mode X flush) + defined idle state.            **
**  2. Reset pulse: FF mode must clear all five state bits (latch mode:  **
**     no-op, same events).                                              **
**  3. Directed FSM walks, one clock per step, checked after every       **
**     settle and every edge: CBWRITE set/hold/clear, CMWRITE            **
**     set/hold/clear, EMD both set terms and all three hold terms,      **
**     BACT set/BDAP50-hold/clear, EBADR grant walk, the IOX             **
**     IOD&MIS0&BINPUT50_n direction term, all three DSTB product        **
**     terms, PD1/PD3 kills with live state behind them.                 **
**  4. Clock-frozen comb sweeps: 256 combos over {IBAPR,BGNT50,BDAP50,   **
**     MWRITE,EBUS,CGNT,GNT,BGNT} (CLKBD/DBAPR/EBD/EBADR side) and 256   **
**     combos over {CACT,CGNT,BDRY50,BDRY25,IORQ,CC2,Q0,Q2} (DSTB/       **
**     xGNTCACT side) - in latch mode these also exercise the immediate  **
**     state reaction, in FF mode the hold.                              **
**  5. 4000-step fixed-seed xorshift32 soak: random inputs each step     **
**     (occasional reset assert), checked after the settle AND after     **
**     the following clock edge (8000 events).                           **
**                                                                       **
** Every check event compares all 11 outputs; the total check count is   **
** asserted exactly (a silent partial run FAILS).                        **
**                                                                       **
** Self-checking: prints TB_RESULT: PASS / FAIL (never silent).          **
**                                                                       **
** Run: make test-ldbctl   (CPU-BOARD-3202/circuit/sim)                  **
**                                                                       **
** 01-AUG-2026                                                           **
** Ronny Hansen                                                          **
***************************************************************************/
`timescale 1ns / 1ps

module BIF_DPATH_LDBCTL_12_tb;

  // ---------------------------------------------------------------- clock
  reg osc = 0;
  reg rst_n = 1;

  // ---------------------------------------------------------------- inputs
  reg bdap50_n = 1, bdry25_n = 1, bdry50_n = 1, bgnt50_n = 1, bgnt_n = 1;
  reg binput50_n = 1, cact_n = 1, cc2_n = 1, cgnt50_n = 1, cgnt_n = 1;
  reg eadr_n = 1, ebus_n = 1, gnt_n = 1, ibapr_n = 1, iod_n = 1;
  reg iorq_n = 1, mis0 = 0, mwrite_n = 1, pd1 = 0, pd3 = 0;
  reg q0_n = 1, q2_n = 1, rt_n = 1, term_n = 1, write = 0;

  // ---------------------------------------------------------------- outputs
  wire bgntcact, cbwrite_n, cgntcact_n, clkbd, dbapr, dstb_n;
  wire ebadr, ebd_n, emd_n, wbd_n, wlbd_n;

  BIF_DPATH_LDBCTL_12 dut (
      .OSC       (osc),
      .sys_rst_n (rst_n),
      .BDAP50_n  (bdap50_n),
      .BDRY25_n  (bdry25_n),
      .BDRY50_n  (bdry50_n),
      .BGNT50_n  (bgnt50_n),
      .BGNT_n    (bgnt_n),
      .BINPUT50_n(binput50_n),
      .CACT_n    (cact_n),
      .CC2_n     (cc2_n),
      .CGNT50_n  (cgnt50_n),
      .CGNT_n    (cgnt_n),
      .EADR_n    (eadr_n),
      .EBUS_n    (ebus_n),
      .GNT_n     (gnt_n),
      .IBAPR_n   (ibapr_n),
      .IOD_n     (iod_n),
      .IORQ_n    (iorq_n),
      .MIS0      (mis0),
      .MWRITE_n  (mwrite_n),
      .PD1       (pd1),
      .PD3       (pd3),
      .Q0_n      (q0_n),
      .Q2_n      (q2_n),
      .RT_n      (rt_n),
      .TERM_n    (term_n),
      .WRITE     (write),

      .BGNTCACT  (bgntcact),
      .CBWRITE_n (cbwrite_n),
      .CGNTCACT_n(cgntcact_n),
      .CLKBD     (clkbd),
      .DBAPR     (dbapr),
      .DSTB_n    (dstb_n),
      .EBADR     (ebadr),
      .EBD_n     (ebd_n),
      .EMD_n     (emd_n),
      .WBD_n     (wbd_n),
      .WLBD_n    (wlbd_n)
  );

  // ------------------------------------------------------ independent model
  reg g_cbw = 0, g_cmw = 0, g_emd = 0, g_bact = 0, g_ebadr_n = 1;

  // One next-state evaluation (set priority, then clear, else hold).
  // Each bit depends only on inputs and itself, so a single blocking pass
  // is the fixed point in latch mode.
  task golden_next;
    reg n_cbw, n_cmw, n_emd, n_bact, n_ebadr_n;
    begin
      // 44303B: CBWRITE / CMWRITE
      n_cbw = (write & ~cact_n) ? 1'b1 : (cact_n ? 1'b0 : g_cbw);
      n_cmw = (write & ~cgnt_n) ? 1'b1 : (cgnt_n ? 1'b0 : g_cmw);
      // 44302B: EMD - set on CPU-to-bus (Q2&Q0&CACT) or CPU-to-mem
      // (CGNT&CGNT50); clear when no hold term (CACT, RT&CC2&TERM_n,
      // IORQ&CC2&TERM_n) is up.
      if ((~q2_n & ~q0_n & ~cact_n) | (~cgnt_n & ~cgnt50_n)) n_emd = 1'b1;
      else if ((~cact_n | (~rt_n & ~cc2_n & term_n) | (~iorq_n & ~cc2_n & term_n)) == 1'b0)
        n_emd = 1'b0;
      else n_emd = g_emd;
      // 44304E: BACT - set on BGNT50 while not a memory write; hold on
      // BDAP50; clear when BDAP50 drops.
      n_bact = (~bgnt50_n & mwrite_n) ? 1'b1 : (bdap50_n ? 1'b0 : g_bact);
      // 44304E: EBADR_n - off when nobody granted; on (0) at IBAPR&GNT.
      n_ebadr_n = (gnt_n & bgnt_n) ? 1'b1 : ((~ibapr_n & ~gnt_n) ? 1'b0 : g_ebadr_n);
      g_cbw = n_cbw;
      g_cmw = n_cmw;
      g_emd = n_emd;
      g_bact = n_bact;
      g_ebadr_n = n_ebadr_n;
    end
  endtask

  task golden_clear;  // FF-mode async reset state
    begin
      g_cbw = 0;
      g_cmw = 0;
      g_emd = 0;
      g_bact = 0;
      g_ebadr_n = 1;
    end
  endtask

  // Called after every tb input change: latch mode reacts immediately,
  // FF mode only honors an async reset assert.
  task golden_settle;
    begin
`ifdef USE_TRANSPARENT_LATCHES
      golden_next;
`else
      if (!rst_n) golden_clear;
`endif
    end
  endtask

  // ------------------------------------------------- expected comb outputs
  wire e_iox = ~iod_n & mis0 & binput50_n;  // output part of IOX
  wire e_wbd_n = pd1 ? 1'b1 : ~((~eadr_n) | g_cbw | e_iox | g_bact);
  wire e_cbwrite_n = pd1 ? 1'b1 : ~g_cbw;
  wire e_wlbd_n = pd1 ? 1'b1 : ~(g_cbw | g_cmw | e_iox);
  wire e_cgntcact_n = pd3 ? 1'b1 : ~(~cgnt_n | ~cact_n);
  wire e_bgntcact = pd3 ? 1'b1 : ~(~bgnt_n | ~cact_n);  // active-low value
  wire e_dstb_n = pd3 ? 1'b1 : ~((~cgnt_n)
                               | (~cact_n & bdry50_n & bdry25_n & iorq_n)
                               | (~cact_n & ~iorq_n & ~cc2_n));
  wire e_emd_n = pd3 ? 1'b1 : ~g_emd;
  wire e_dbapr = ~ibapr_n;
  wire e_ebadr = ~g_ebadr_n;
  wire e_ebd_n = ~((~ebus_n & cgnt_n & gnt_n) | (~ebus_n & ~bgnt_n)
                 | (~ebus_n & g_bact));
  wire e_clkbd = ~((ibapr_n & bgnt50_n) | (ibapr_n & bdap50_n)
                 | (ibapr_n & mwrite_n));

  // ---------------------------------------------------------------- checking
  integer checks = 0;
  integer errors = 0;

  task chk1(input [127:0] name, input got, input exp);
    begin
      checks = checks + 1;
      if (got !== exp) begin
        errors = errors + 1;
        if (errors <= 20)
          $display("MISMATCH t=%0t %0s got=%b exp=%b", $time, name, got, exp);
      end
    end
  endtask

  task check_all;
    begin
      chk1("BGNTCACT", bgntcact, e_bgntcact);
      chk1("CBWRITE_n", cbwrite_n, e_cbwrite_n);
      chk1("CGNTCACT_n", cgntcact_n, e_cgntcact_n);
      chk1("CLKBD", clkbd, e_clkbd);
      chk1("DBAPR", dbapr, e_dbapr);
      chk1("DSTB_n", dstb_n, e_dstb_n);
      chk1("EBADR", ebadr, e_ebadr);
      chk1("EBD_n", ebd_n, e_ebd_n);
      chk1("EMD_n", emd_n, e_emd_n);
      chk1("WBD_n", wbd_n, e_wbd_n);
      chk1("WLBD_n", wlbd_n, e_wlbd_n);
    end
  endtask

  task settle_check;  // input change absorbed, no clock
    begin
      golden_settle;
      #2 check_all;
    end
  endtask

  task clk_check;  // one posedge OSC, then check
    begin
      #2 osc = 1;
`ifndef USE_TRANSPARENT_LATCHES
      if (rst_n) golden_next;
      else golden_clear;
`endif
      #2 osc = 0;
      #1 check_all;
    end
  endtask

  // ---------------------------------------------------------------- soak rng
  reg [31:0] rnd = 32'h5EED0012;
  task next_rnd;
    begin
      rnd = rnd ^ (rnd << 13);
      rnd = rnd ^ (rnd >> 17);
      rnd = rnd ^ (rnd << 5);
    end
  endtask

  task idle_inputs;
    begin
      bdap50_n = 1; bdry25_n = 1; bdry50_n = 1; bgnt50_n = 1; bgnt_n = 1;
      binput50_n = 1; cact_n = 1; cc2_n = 1; cgnt50_n = 1; cgnt_n = 1;
      eadr_n = 1; ebus_n = 1; gnt_n = 1; ibapr_n = 1; iod_n = 1;
      iorq_n = 1; mis0 = 0; mwrite_n = 1; pd1 = 0; pd3 = 0;
      q0_n = 1; q2_n = 1; rt_n = 1; term_n = 1; write = 0;
    end
  endtask

  // 8577 check events (init 3 + reset 6 + FSM walks 52 + sweeps 516 +
  // soak 8000 - see the phases below), 11 output compares each.
  localparam EXP_CHECKS = 8577 * 11;

  integer i;
  initial begin
    // ---- 1. init wiggle: guarantee a change event on every input so the
    // latch-mode always@(*) blocks leave X, then settle at idle.
    #1;
    bdap50_n = 0; bdry25_n = 0; bdry50_n = 0; bgnt50_n = 0; bgnt_n = 0;
    binput50_n = 0; cact_n = 0; cc2_n = 0; cgnt50_n = 0; cgnt_n = 0;
    eadr_n = 0; ebus_n = 0; gnt_n = 0; ibapr_n = 0; iod_n = 0;
    iorq_n = 0; mis0 = 1; mwrite_n = 0; pd1 = 1; pd3 = 1;
    q0_n = 0; q2_n = 0; rt_n = 0; term_n = 0; write = 1;
    golden_settle;
    #2;
    idle_inputs;
    golden_settle;
    #2;
    // FF-mode power-on: the PAL FFs are X until the first async reset;
    // pulse it before the first check (latch mode: no-op, same events).
    rst_n = 0;
    settle_check;
    rst_n = 1;
    settle_check;
    settle_check;

    // ---- 2. reset pulse (FF clears state; latch mode no-op)
    write  = 1;
    cact_n = 0;  // arm CBWRITE
    settle_check;
    clk_check;
    rst_n = 0;
    settle_check;
    rst_n = 1;
    settle_check;
    idle_inputs;
    settle_check;
    clk_check;

    // ---- 3a. CBWRITE life cycle: set, hold on WRITE drop, clear on CACT drop
    write  = 1;
    cact_n = 0;
    settle_check;
    clk_check;
    write = 0;
    settle_check;
    clk_check;  // hold (CACT still on)
    cact_n = 1;
    settle_check;
    clk_check;  // clear

    // ---- 3b. CMWRITE life cycle (WLBD term without WBD)
    write  = 1;
    cgnt_n = 0;
    settle_check;
    clk_check;
    write = 0;
    settle_check;
    clk_check;  // hold on CGNT
    cgnt_n = 1;
    settle_check;
    clk_check;  // clear

    // ---- 3c. EMD: CPU-to-bus set (Q2&Q0&CACT), CACT hold, RT/IORQ holds
    q0_n   = 0;
    q2_n   = 0;
    cact_n = 0;
    settle_check;
    clk_check;  // set
    q0_n = 1;
    q2_n = 1;
    settle_check;
    clk_check;  // hold via CACT
    rt_n  = 0;
    cc2_n = 0;
    settle_check;
    cact_n = 1;
    settle_check;
    clk_check;  // hold via RT&CC2&TERM_n
    rt_n   = 1;
    iorq_n = 0;
    settle_check;
    clk_check;  // hold via IORQ&CC2&TERM_n (DSTB IOX term also live)
    term_n = 0;
    settle_check;
    clk_check;  // TERM kills the hold -> clear
    idle_inputs;
    settle_check;
    clk_check;
    // EMD second set term: CGNT&CGNT50
    cgnt_n   = 0;
    cgnt50_n = 0;
    settle_check;
    clk_check;  // set (DSTB also low via CGNT)
    cgnt_n   = 1;
    cgnt50_n = 1;
    settle_check;
    clk_check;  // no hold term -> clear
    idle_inputs;
    settle_check;

    // ---- 3d. BACT: set on BGNT50&MWRITE_n, hold on BDAP50, clear
    bgnt50_n = 0;
    bdap50_n = 0;
    settle_check;
    clk_check;  // set
    bgnt50_n = 1;
    settle_check;
    clk_check;  // hold via BDAP50
    ebus_n = 0;
    settle_check;  // EBD via BACT while EBUS
    bdap50_n = 1;
    settle_check;
    clk_check;  // clear
    idle_inputs;
    settle_check;

    // ---- 3e. EBADR grant walk: IBAPR&GNT sets, GNT_n&BGNT_n clears
    gnt_n   = 0;
    ibapr_n = 0;
    settle_check;
    clk_check;  // EBADR on (also DBAPR/CLKBD comb via IBAPR)
    ibapr_n = 1;
    settle_check;
    clk_check;  // hold (GNT still on)
    bgnt_n = 0;
    gnt_n  = 1;
    settle_check;
    clk_check;  // still held (BGNT keeps the set term away? set needs both off)
    bgnt_n = 1;
    settle_check;
    clk_check;  // GNT_n&BGNT_n -> off
    idle_inputs;
    settle_check;

    // ---- 3f. IOX direction term + PD kills with live state
    iod_n      = 0;
    mis0       = 1;
    binput50_n = 1;
    settle_check;  // WBD/WLBD via IOX term, no clock needed
    pd1 = 1;
    settle_check;  // kills WBD/WLBD/CBWRITE only
    pd1   = 0;
    pd3   = 1;
    cact_n = 0;
    settle_check;  // kills DSTB/EMD/xGNTCACT only
    pd3 = 0;
    idle_inputs;
    settle_check;
    clk_check;

    // ---- 4. clock-frozen comb sweeps
    for (i = 0; i < 256; i = i + 1) begin
      ibapr_n  = i[0];
      bgnt50_n = i[1];
      bdap50_n = i[2];
      mwrite_n = i[3];
      ebus_n   = i[4];
      cgnt_n   = i[5];
      gnt_n    = i[6];
      bgnt_n   = i[7];
      settle_check;
    end
    idle_inputs;
    settle_check;
    clk_check;
    for (i = 0; i < 256; i = i + 1) begin
      cact_n   = i[0];
      cgnt_n   = i[1];
      bdry50_n = i[2];
      bdry25_n = i[3];
      iorq_n   = i[4];
      cc2_n    = i[5];
      q0_n     = i[6];
      q2_n     = i[7];
      settle_check;
    end
    idle_inputs;
    settle_check;
    clk_check;

    // ---- 5. randomized soak: settle-check then edge-check per step
    for (i = 0; i < 4000; i = i + 1) begin
      next_rnd;
      bdap50_n   = rnd[0];
      bdry25_n   = rnd[1];
      bdry50_n   = rnd[2];
      bgnt50_n   = rnd[3];
      bgnt_n     = rnd[4];
      binput50_n = rnd[5];
      cact_n     = rnd[6];
      cc2_n      = rnd[7];
      cgnt50_n   = rnd[8];
      cgnt_n     = rnd[9];
      eadr_n     = rnd[10];
      ebus_n     = rnd[11];
      gnt_n      = rnd[12];
      ibapr_n    = rnd[13];
      iod_n      = rnd[14];
      iorq_n     = rnd[15];
      mis0       = rnd[16];
      mwrite_n   = rnd[17];
      q0_n       = rnd[18];
      q2_n       = rnd[19];
      rt_n       = rnd[20];
      term_n     = rnd[21];
      write      = rnd[22];
      pd1        = (rnd[25:23] == 3'b000);
      pd3        = (rnd[28:26] == 3'b000);
      rst_n      = (rnd[31:29] != 3'b000);
      settle_check;
      clk_check;
    end

    // ---------------------------------------------------------- verdict
    if (checks != EXP_CHECKS) begin
      $display("CHECK-COUNT MISMATCH: ran %0d, expected %0d", checks, EXP_CHECKS);
      errors = errors + 1;
    end
    if (errors == 0) $display("TB_RESULT: PASS (%0d checks)", checks);
    else $display("TB_RESULT: FAIL (%0d errors in %0d checks)", errors, checks);
    $finish;
  end

endmodule

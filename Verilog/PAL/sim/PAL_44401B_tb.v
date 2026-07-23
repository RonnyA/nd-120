`timescale 1ns / 1ps

/**************************************************************************
** Testbench for PAL_44401B  (PAL16R4D, BTIM - bus cycle timing)
** ND-120 CPU board 3202D sheet 6, instance PAL_44401_UBTIM.
**
** WHY THIS TEST EXISTS (20-JUL-2026):
**   This PAL generates EIOD (which enables BIOXE, the IOX bus strobe),
**   APR (address present) and EADR (address enable). The reported bug was
**   the CPU issuing an IOX cycle (BIOXE_n=0) while an external DMA master
**   held the bus. BIOXE cannot fire unless EIOD asserts, and EIOD is GATED
**   BY CACT (CPU-active). So this testbench pins the second half of the
**   "bus not interruptible" guarantee:
**
**     EIOD (-> BIOXE) can ONLY assert while CACT=1.
**
**   Together with PAL_44801A (which now correctly keeps CACT=0 while a DMA
**   grant GNT is held), this proves the CPU cannot run an IOX cycle on top
**   of a granted DMA: no CACT -> no EIOD -> no BIOXE.
**
** EIOD_n (PAL_44401B.v:139) is combinational:
**   EIOD_n = ~(IORQ & Q2_n & Q1_n & Q0_n & CACT & CACT25 & BDRY50_n & CC2)
** so it is exercised by driving the inputs directly; the Q state (the
** cycle FSM) is forced to the settled "s" state (Q2_n Q1_n Q0_n = 111,
** i.e. Q=000) where an IOX strobe is allowed.
**
** TEETH: a "bad" EIOD that OMITS the CACT gate MUST assert while CACT=0
**   (during a DMA) - it must diverge from the real (gated) EIOD, proving
**   the gate is doing real work.
**
** Read convention: OE_n held 0 so outputs enabled; X = ~X_n.
**
** Run: make -C PAL/sim test-pal44401b   (or test-all)
***************************************************************************/

module PAL_44401B_tb;

  reg CK;
  reg sys_rst_n;
  reg OE_n;

  // Inputs (active-low as named)
  reg CC2_n;      // I0 - cycle counter bit 2
  reg CACT_n;     // I1 - CPU active
  reg CACT25_n;   // I2 - CPU active, 25 ns delayed
  reg BDRY50_n;   // I3 - bus data ready, 50 ns delayed
  reg CGNT_n;     // I4 - CPU grant (local RAM)
  reg CGNT50_n;   // I5
  reg TERM_n;     // I6 - cycle terminate
  reg IORQ_n;     // I7 - IO request

  wire Q0_n, Q1_n, Q2_n;
  wire APR_n, DAP_n, EIOD_n, EADR_n;

  // Decoded active-high
  wire EIOD = ~EIOD_n;   // -> enables BIOXE
  wire APR  = ~APR_n;
  wire CACT = ~CACT_n;

  integer errors;
  integer checks;
  integer teeth_diverged;

  PAL_44401B uut (
      .CK       (CK),
      .sys_rst_n(sys_rst_n),
      .OE_n     (OE_n),
      .CC2_n    (CC2_n),
      .CACT_n   (CACT_n),
      .CACT25_n (CACT25_n),
      .BDRY50_n (BDRY50_n),
      .CGNT_n   (CGNT_n),
      .CGNT50_n (CGNT50_n),
      .TERM_n   (TERM_n),
      .IORQ_n   (IORQ_n),
      .Q0_n     (Q0_n),
      .Q1_n     (Q1_n),
      .Q2_n     (Q2_n),
      .APR_n    (APR_n),
      .DAP_n    (DAP_n),
      .EIOD_n   (EIOD_n),
      .EADR_n   (EADR_n)
  );

  initial begin
    CK = 0;
    forever #10 CK = ~CK;
  end

  // TEETH: EIOD without the CACT gate. Must assert (during a valid IOX
  // window) even when CACT=0, where the real EIOD stays inactive.
  wire bad_eiod = (~IORQ_n) & Q2_n & Q1_n & Q0_n /* NO CACT */ &
                  (~CACT25_n) & BDRY50_n & (~CC2_n);

  // Force the cycle FSM into the settled "s" state (Q=000 -> Q*_n = 111),
  // the only state where an IOX strobe is permitted.
  task force_state_s;
    begin
      force uut.Q0 = 1'b0;
      force uut.Q1 = 1'b0;
      force uut.Q2 = 1'b0;
    end
  endtask

  // All IOX-window conditions satisfied EXCEPT CACT is the variable of
  // interest: IORQ active, state s, CACT25 active, BDRY50_n high, CC2 active.
  task iox_window_inputs;
    begin
      IORQ_n   = 1'b0;   // IORQ = 1
      CACT25_n = 1'b0;   // CACT25 = 1
      BDRY50_n = 1'b1;   // no data-ready yet
      CC2_n    = 1'b0;   // CC2 = 1
      TERM_n   = 1'b1;
      CGNT_n   = 1'b1;
      CGNT50_n = 1'b1;
    end
  endtask

  task chk(input cond, input [255:0] nm);
    begin
      checks = checks + 1;
      if (cond) $display("PASS [%0s]", nm);
      else begin errors = errors + 1; $display("FAIL [%0s] (EIOD=%b APR=%b CACT=%b)", nm, EIOD, APR, CACT); end
    end
  endtask

  initial begin
    errors = 0; checks = 0; teeth_diverged = 0;
    sys_rst_n = 1'b1;
    OE_n      = 1'b0;
    CACT_n    = 1'b1;
    iox_window_inputs;

    $display("======================================================");
    $display("PAL_44401B BTIM self-check (EIOD/BIOXE gated by CACT)");
    $display("======================================================");

    force_state_s;
    #1;

    // -----------------------------------------------------------------
    // 1. THE SCENARIO: during a DMA cycle the CPU is NOT active (CACT=0).
    //    Even with a perfect IOX window, EIOD (-> BIOXE) must stay OFF.
    // -----------------------------------------------------------------
    $display("\n-- 1: CACT=0 (DMA holds the bus) -> EIOD must stay OFF --");
    CACT_n = 1'b1;   // CACT = 0
    #1;
    chk(EIOD === 1'b0, "eiod-off-when-cpu-inactive");
    chk(APR  === 1'b0, "apr-off-when-cpu-inactive");
    // teeth: the ungated EIOD WOULD have fired here
    if (bad_eiod === 1'b1 && EIOD === 1'b0) teeth_diverged = teeth_diverged + 1;

    // -----------------------------------------------------------------
    // 2. CPU active (CACT=1) with the same window -> EIOD asserts.
    // -----------------------------------------------------------------
    $display("\n-- 2: CACT=1 (CPU owns the bus) -> EIOD asserts --");
    CACT_n = 1'b0;   // CACT = 1
    #1;
    chk(EIOD === 1'b1, "eiod-on-when-cpu-active");

    // -----------------------------------------------------------------
    // 3. Each remaining EIOD qualifier must be necessary (drop one at a
    //    time with CACT=1, EIOD must fall).
    // -----------------------------------------------------------------
    $display("\n-- 3: every EIOD qualifier is necessary --");
    IORQ_n = 1'b1; #1; chk(EIOD === 1'b0, "no-eiod-without-IORQ");   IORQ_n = 1'b0;
    CC2_n  = 1'b1; #1; chk(EIOD === 1'b0, "no-eiod-without-CC2");    CC2_n  = 1'b0;
    BDRY50_n = 1'b0; #1; chk(EIOD === 1'b0, "no-eiod-when-BDRY50"); BDRY50_n = 1'b1;
    CACT25_n = 1'b1; #1; chk(EIOD === 1'b0, "no-eiod-without-CACT25"); CACT25_n = 1'b0;
    #1; chk(EIOD === 1'b1, "eiod-restored");

    // -----------------------------------------------------------------
    // 4. Not in state s: EIOD must not fire even with CACT=1 (IOX strobe
    //    only in the settled state). Force Q0=1 (state t).
    // -----------------------------------------------------------------
    $display("\n-- 4: outside state s -> no EIOD --");
    force uut.Q0 = 1'b1; #1;
    chk(EIOD === 1'b0, "no-eiod-outside-state-s");
    force uut.Q0 = 1'b0; #1;

    // -----------------------------------------------------------------
    // 5. Sweep CACT a few times to accumulate teeth divergences in the
    //    IOX window (ungated EIOD fires, gated one does not, when CACT=0).
    // -----------------------------------------------------------------
    $display("\n-- 5: CACT sweep (teeth) --");
    begin : sweep
      integer i;
      for (i = 0; i < 8; i = i + 1) begin
        CACT_n = i[0];   // alternate CACT
        #1;
        if (bad_eiod === 1'b1 && EIOD === 1'b0) teeth_diverged = teeth_diverged + 1;
        // invariant: EIOD can never be 1 while CACT is 0
        if (EIOD === 1'b1 && CACT === 1'b0) begin
          errors = errors + 1;
          $display("FAIL [excl]: EIOD asserted while CACT=0 (BIOXE on top of DMA!)");
        end
        checks = checks + 1;
      end
    end

    release uut.Q0; release uut.Q1; release uut.Q2;

    $display("\n======================================================");
    $display("checks=%0d errors=%0d teeth(ungated-eiod diverged)=%0d",
             checks, errors, teeth_diverged);
    if (teeth_diverged == 0)
      $display("RESULT: FAIL (teeth: ungated EIOD never diverged - CACT gate not exercised)");
    else if (errors == 0)
      $display("RESULT: PASS - EIOD/BIOXE cannot fire without CACT (no IOX over a DMA)");
    else
      $display("RESULT: FAIL - %0d error(s)", errors);
    $display("======================================================");

    if (errors != 0 || teeth_diverged == 0)
      $fatal(1, "PAL_44401B testbench failed");
    $finish;
  end

  initial begin
    #100000;
    $display("RESULT: FAIL [timeout]: watchdog fired");
    $fatal(1, "timeout");
  end

endmodule

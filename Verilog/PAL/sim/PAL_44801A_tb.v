`timescale 1ns / 1ps

/**************************************************************************
** Testbench for PAL_44801A  (PAL16R8, BARB - the ND-100 bus arbiter)
** ND-120 CPU board 3202D sheet 6, instance PAL_44801_UBARB.
**
** WHY THIS TEST EXISTS (20-JUL-2026):
**   An EXTERNAL DMA bus master (our NDDeviceCore C card driving the raw
**   ND120_TOP bus pins - the same path that becomes FPGA pins on real
**   hardware) requests the bus with BREQ, is granted, and runs a memory
**   cycle. It was observed that the CPU could start an IOX cycle
**   (BIOXE_n=0) WHILE that granted DMA cycle was still active (BMEM_n=0).
**   On real ND-100 hardware the bus is "not interruptible" once allocated
**   (ND-06.016.01 II.4.1.2). This testbench pins the ARBITER'S half of that
**   guarantee: CACT (CPU active) and GNT (DMA grant) are MUTUALLY EXCLUSIVE
**   and each HOLDS until the cycle's BDRY. If the arbiter honours this, then
**   any observed CPU/DMA overlap is a WIRING problem (the external master's
**   BREQ not reaching BRQ50, or BDRY25 released early) - NOT the arbiter.
**
** The expected behaviour below is derived from the ND-100 bus allocation
** rules and the documented PAL priority (REFRESH > CPU-after-refresh > BUS
** > CPU), NOT by copying the PAL's own product terms.
**
** THE STRUCTURAL INVARIANT (checked every clock - the real bug catcher):
**   at most ONE of {CACT, GNT, REF} may be asserted at a time. Two of them
**   high = the bus is granted to two masters at once = the exact failure we
**   are chasing.
**
** TEETH: an inline "bad" arbiter whose CACT set-term OMITS the GNT_n guard
**   (the lazy transcription that would let the CPU run over a DMA) MUST
**   diverge - i.e. it MUST assert CACT while GNT is held at least once.
**   If it never diverges, the stimulus never exercised the interlock and
**   the test has no teeth -> reported as FAIL.
**
** Read convention: OE_n held 0 so outputs enabled; X = ~X_n.
**
** Run: make -C PAL/sim test-pal44801a   (or test-all)
***************************************************************************/

module PAL_44801A_tb;

  // Clock / output enable
  reg CK;
  reg OE_n;

  // PAL inputs (all active-low as they arrive at the PAL)
  reg CRQ_n;      // I0 - CPU request
  reg IORQ_n;     // I1 - IO request
  reg MR_n;       // I2 - master reset
  reg BRQ50_n;    // I3 - bus request (DMA), 50ns delayed
  reg REFRQ50_n;  // I4 - refresh request, 50ns delayed
  reg BDRY25_n;   // I5 - bus data ready, 25ns delayed (cycle terminator)
  reg SEMRQ50_n;  // I6 - semaphore request
  reg MOFF_n;     // I7 - memory off (unused)

  // PAL outputs (active-low)
  wire SEM_n, ACT_n, DOREF_n, MEM_n, REF_n, IOD_n, GNT_n, CACT_n;

  // Decoded active-high views
  wire CACT = ~CACT_n;
  wire GNT  = ~GNT_n;
  wire REF  = ~REF_n;
  wire MEM  = ~MEM_n;   // -> BMEM on the bus

  integer errors;
  integer checks;
  reg     checking;            // enable the every-tick invariant
  integer teeth_diverged;      // times the guard-less "bad" CACT diverged

  // ---- Unit under test -------------------------------------------------
  PAL_44801A uut (
      .CK        (CK),
      .OE_n      (OE_n),
      .CRQ_n     (CRQ_n),
      .IORQ_n    (IORQ_n),
      .MR_n      (MR_n),
      .BRQ50_n   (BRQ50_n),
      .REFRQ50_n (REFRQ50_n),
      .BDRY25_n  (BDRY25_n),
      .SEMRQ50_n (SEMRQ50_n),
      .MOFF_n    (MOFF_n),
      .SEM_n     (SEM_n),
      .ACT_n     (ACT_n),
      .DOREF_n   (DOREF_n),
      .MEM_n     (MEM_n),
      .REF_n     (REF_n),
      .IOD_n     (IOD_n),
      .GNT_n     (GNT_n),
      .CACT_n    (CACT_n)
  );

  // ---- Clock: 20 ns period --------------------------------------------
  initial begin
    CK = 0;
    forever #10 CK = ~CK;
  end

  // ---- TEETH: a guard-less shadow of the CACT set-term ------------------
  // The real CACT term requires GNT_n (no DMA grant). This "bad" variant
  // drops that guard - the classic lazy transcription. It is clocked the
  // same way and compared against the real CACT: if the design is correct,
  // the bad version will assert CACT while a DMA holds GNT and the real one
  // will not, so they MUST diverge during the interlock scenario.
  reg bad_cact;
  always @(posedge CK) begin
    bad_cact <=
        ( ~CRQ_n & REFRQ50_n & BRQ50_n & REF_n /* NO GNT_n guard */ & SEM_n & BDRY25_n & MR_n)
      | ( ~CRQ_n & REFRQ50_n & DOREF_n & REF_n /* NO GNT_n guard */ & SEM_n & BDRY25_n & MR_n)
      | ( bad_cact & BDRY25_n & MR_n);
  end

  // ---- Sample + run the mutual-exclusion invariant every tick ----------
  task tick;
    begin
      @(posedge CK); #1;
      if (checking) begin
        checks = checks + 1;
        // THE invariant: no two bus owners at once.
        if ((CACT & GNT) | (CACT & REF) | (GNT & REF)) begin
          errors = errors + 1;
          $display("FAIL [excl]: two bus owners at t=%0t  CACT=%b GNT=%b REF=%b",
                   $time, CACT, GNT, REF);
        end
        // teeth: the guard-less CACT asserted where the real one did not,
        // while a DMA grant was held -> the interlock is doing real work.
        if (bad_cact & ~CACT & GNT) teeth_diverged = teeth_diverged + 1;
      end
    end
  endtask

  // Force all 8 registers to idle (0). The PAL has no reset pin; force/
  // release is a testbench-only construct and does not modify the DUT.
  task reset_idle;
    begin
      checking = 0;
      force uut.SEM_reg   = 1'b0;
      force uut.ACT_reg   = 1'b0;
      force uut.DOREF_reg = 1'b0;
      force uut.MEM_reg   = 1'b0;
      force uut.REF_reg   = 1'b0;
      force uut.IOD_reg   = 1'b0;
      force uut.GNT_reg   = 1'b0;
      force uut.CACT_reg  = 1'b0;
      bad_cact = 1'b0;
      @(posedge CK); #1;
      release uut.SEM_reg;
      release uut.ACT_reg;
      release uut.DOREF_reg;
      release uut.MEM_reg;
      release uut.REF_reg;
      release uut.IOD_reg;
      release uut.GNT_reg;
      release uut.CACT_reg;
      checking = 1;
    end
  endtask

  // Everything inactive: no request of any kind, no data-ready, no reset.
  task idle_inputs;
    begin
      CRQ_n     = 1'b1;
      IORQ_n    = 1'b1;
      MR_n      = 1'b1;   // NOT in reset
      BRQ50_n   = 1'b1;
      REFRQ50_n = 1'b1;
      BDRY25_n  = 1'b1;   // no data-ready -> grants HOLD
      SEMRQ50_n = 1'b1;
      MOFF_n    = 1'b1;
    end
  endtask

  task expect_state(input exp_cact, input exp_gnt, input exp_ref, input [255:0] nm);
    begin
      checks = checks + 1;
      if (CACT === exp_cact && GNT === exp_gnt && REF === exp_ref)
        $display("PASS [%0s]: CACT=%b GNT=%b REF=%b", nm, CACT, GNT, REF);
      else begin
        errors = errors + 1;
        $display("FAIL [%0s]: CACT=%b GNT=%b REF=%b (expected %b/%b/%b)",
                 nm, CACT, GNT, REF, exp_cact, exp_gnt, exp_ref);
      end
    end
  endtask

  initial begin
    errors         = 0;
    checks         = 0;
    checking       = 0;
    teeth_diverged = 0;
    OE_n           = 1'b0;    // outputs enabled the whole run
    idle_inputs;

    $display("======================================================");
    $display("PAL_44801A ND-100 bus arbiter self-check");
    $display("  (CPU/DMA mutual-exclusion interlock)");
    $display("======================================================");

    // -----------------------------------------------------------------
    // 1. CPU alone: CRQ -> CACT sets, GNT stays clear.
    // -----------------------------------------------------------------
    $display("\n-- 1: CPU request alone -> CACT --");
    reset_idle; idle_inputs;
    CRQ_n = 1'b0;                 // CPU requests
    tick;                         // one edge to register CACT
    expect_state(1'b1, 1'b0, 1'b0, "cpu-alone");
    // hold: CACT must stay while BDRY25_n=1
    tick;
    expect_state(1'b1, 1'b0, 1'b0, "cpu-hold");
    // end cycle: BDRY25 asserted -> CACT clears
    BDRY25_n = 1'b0; tick; CRQ_n = 1'b1; BDRY25_n = 1'b1; tick;
    expect_state(1'b0, 1'b0, 1'b0, "cpu-release");

    // -----------------------------------------------------------------
    // 2. DMA alone: BRQ50 -> GNT sets, CACT stays clear, MEM (BMEM) set.
    // -----------------------------------------------------------------
    $display("\n-- 2: DMA request alone -> GNT (+BMEM) --");
    reset_idle; idle_inputs;
    BRQ50_n = 1'b0;               // external DMA requests the bus
    tick;
    expect_state(1'b0, 1'b1, 1'b0, "dma-alone");
    if (MEM === 1'b1) $display("PASS [bmem]: MEM asserted during DMA cycle");
    else begin errors = errors + 1; $display("FAIL [bmem]: MEM not asserted during DMA cycle"); end

    // -----------------------------------------------------------------
    // 3. THE INTERLOCK (the reported failure scenario):
    //    DMA holds a granted cycle; the CPU now requests. CACT MUST NOT
    //    set while GNT is held (BDRY25_n=1). This is "not interruptible".
    // -----------------------------------------------------------------
    $display("\n-- 3: CPU requests while DMA holds the grant -> CPU BLOCKED --");
    // (continue from scenario 2: GNT=1, BDRY25_n=1)
    CRQ_n  = 1'b0;               // CPU now wants the bus, mid-DMA
    IORQ_n = 1'b0;               // ... specifically an IOX (drives IOD/BIOXE upstream)
    tick;
    expect_state(1'b0, 1'b1, 1'b0, "cpu-blocked-by-gnt");
    tick;
    expect_state(1'b0, 1'b1, 1'b0, "cpu-still-blocked");

    // -----------------------------------------------------------------
    // 4. Release: the DMA cycle completes (BDRY25). GNT drops; only THEN
    //    can the CPU win CACT.
    // -----------------------------------------------------------------
    $display("\n-- 4: DMA BDRY releases the bus -> CPU may proceed --");
    BDRY25_n = 1'b0; tick;       // data-ready terminates the DMA cycle
    expect_state(1'b0, 1'b0, 1'b0, "gnt-released");
    // The DMA cycle is done, so the external master releases BREQ (as a real
    // one does). With BRQ50 gone and the CPU still requesting, the CPU wins.
    // (Were BRQ50 held here with DOREF=0, the arbiter would CORRECTLY re-grant
    // the DMA by toggled priority - not a bug, so we model the release.)
    BRQ50_n  = 1'b1;             // DMA no longer requesting
    BDRY25_n = 1'b1; tick;       // now the pending CPU request is served
    expect_state(1'b1, 1'b0, 1'b0, "cpu-now-active");
    CRQ_n = 1'b1; IORQ_n = 1'b1;
    BDRY25_n = 1'b0; tick; BDRY25_n = 1'b1; tick;

    // -----------------------------------------------------------------
    // 5. Priority: refresh outranks a simultaneous CPU + DMA request.
    // -----------------------------------------------------------------
    $display("\n-- 5: REFRESH wins over simultaneous CPU + DMA --");
    reset_idle; idle_inputs;
    REFRQ50_n = 1'b0; CRQ_n = 1'b0; BRQ50_n = 1'b0;   // all three at once
    tick;
    expect_state(1'b0, 1'b0, 1'b1, "refresh-wins");

    // -----------------------------------------------------------------
    // 5b. TOGGLED PRIORITY (the DOREF tie-break, spec II.4.1.2 "priority to
    //     the one not having the previous cycle"). On a simultaneous CPU+DMA
    //     request: right AFTER a refresh the CPU wins (DOREF held = 1); the
    //     next simultaneous contest, with DOREF cleared, the DMA wins. This
    //     depends on DOREF HOLDING between the refresh and the next cycle -
    //     so it is the regression guard for the DOREF-hold fix. If DOREF did
    //     not hold, the CPU-after-refresh case would hand the bus to the DMA.
    //     Mutual exclusion holds throughout (checked every tick).
    // -----------------------------------------------------------------
    $display("\n-- 5b: toggled priority after refresh (DOREF tie-break) --");
    reset_idle; idle_inputs;
    // a refresh cycle: grant REF, then complete it (BDRY) so DOREF latches.
    REFRQ50_n = 1'b0; tick;                        // REF granted
    REFRQ50_n = 1'b1; BDRY25_n = 1'b0; tick;       // refresh completes -> DOREF set
    BDRY25_n  = 1'b1; tick;                         // settle; DOREF must now HOLD
    // simultaneous CPU + DMA, immediately after the refresh -> CPU wins.
    CRQ_n = 1'b0; BRQ50_n = 1'b0; tick;
    expect_state(1'b1, 1'b0, 1'b0, "after-refresh-CPU-wins");
    // complete the CPU cycle (this clears DOREF).
    CRQ_n = 1'b1; BRQ50_n = 1'b1; BDRY25_n = 1'b0; tick; BDRY25_n = 1'b1; tick;
    // now DOREF=0; the next simultaneous contest -> DMA wins (toggled).
    CRQ_n = 1'b0; BRQ50_n = 1'b0; tick;
    expect_state(1'b0, 1'b1, 1'b0, "not-after-refresh-DMA-wins");
    CRQ_n = 1'b1; BRQ50_n = 1'b1; BDRY25_n = 1'b0; tick; BDRY25_n = 1'b1; tick;

    // -----------------------------------------------------------------
    // 6. Randomised soak: pulse requests, drive BDRY to terminate cycles,
    //    and enforce the mutual-exclusion invariant every single tick.
    // -----------------------------------------------------------------
    $display("\n-- 6: randomised soak (invariant on every tick) --");
    reset_idle; idle_inputs;
    begin : soak
      integer i;
      for (i = 0; i < 400; i = i + 1) begin
        case ($random & 7)
          0: CRQ_n     = $random & 1;
          1: BRQ50_n   = $random & 1;
          2: REFRQ50_n = $random & 1;
          3: IORQ_n    = $random & 1;
          4: BDRY25_n  = 1'b0;                 // terminate whatever runs
          5: BDRY25_n  = 1'b1;
          6: begin CRQ_n = 1'b0; BRQ50_n = 1'b0; end   // contended
          7: begin CRQ_n = 1'b1; BRQ50_n = 1'b1; BDRY25_n = 1'b0; end
        endcase
        tick;
      end
    end
    idle_inputs; BDRY25_n = 1'b0; tick; tick;

    // -----------------------------------------------------------------
    // Summary
    // -----------------------------------------------------------------
    $display("\n======================================================");
    $display("checks=%0d errors=%0d teeth(guard-less diverged)=%0d",
             checks, errors, teeth_diverged);
    if (teeth_diverged == 0)
      $display("RESULT: FAIL (teeth: guard-less CACT never ran over a held GNT - interlock not exercised)");
    else if (errors == 0)
      $display("RESULT: PASS - arbiter interlock holds (CPU cannot run over a granted DMA)");
    else
      $display("RESULT: FAIL - %0d error(s) detected", errors);
    $display("======================================================");

    if (errors != 0 || teeth_diverged == 0)
      $fatal(1, "PAL_44801A testbench failed");
    $finish;
  end

  // Global watchdog
  initial begin
    #200000;
    $display("RESULT: FAIL [timeout]: watchdog fired");
    $fatal(1, "timeout");
  end

endmodule

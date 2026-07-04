`timescale 1ns / 1ps

/**************************************************************************
** CGA_MIC_MASEL race-condition testbench
**
** Tests the actual CGA_MIC_MASEL module under race conditions where the
** mux selector inputs (SC5/SC6) transition at the same sysclk edge as
** MCLK rises. This is the situation we observe in the FPGA: the original
** posedge-MCLK regIW FF captures the OLD regREP value instead of the
** NEW one because the data input changes at the same instant as the
** clock edge.
**
** Drives MASEL with sysclk-level stimulus that mimics CYC_36's actual
** behavior:
**   - sysclk runs at 100 MHz
**   - MCLK is a multi-sysclk-wide pulse from CYC_36's PAL state machine
**   - SC5/SC6 transition at sysclk edges
**
** Each scenario sets up an "expected JUMP target" and checks that IW_12_0
** captures it correctly when MCLK rises.
**
** Run with iverilog from this directory:
**   make MASEL_iw_capture_tb
**   ./MASEL_iw_capture_tb
***************************************************************************/

module MASEL_iw_capture_tb;

  // Sysclk: 100 MHz, 10 ns period
  reg sysclk = 0;
  always #5 sysclk = ~sysclk;

  // CGA_MIC_MASEL ports
  reg         sys_rst_n;
  reg         CSBIT20;
  reg [11:0]  CSBIT_11_0;
  reg [3:0]   JMP_3_0;
  reg         MCLK;
  reg         MCLKN;
  reg         MRN;
  reg [12:0]  NEXT_12_0;
  reg [12:0]  RET_12_0;
  reg         SC5;
  reg         SC6;

  wire [12:0] IW_12_0;
  wire [12:0] W_12_0;

  // Keep MCLKN inverted from MCLK
  always @(*) MCLKN = ~MCLK;

  CGA_MIC_MASEL uut (
    .sysclk(sysclk),
    .sys_rst_n(sys_rst_n),
    .CSBIT20(CSBIT20),
    .CSBIT_11_0(CSBIT_11_0),
    .JMP_3_0(JMP_3_0),
    .MCLK(MCLK),
    .MCLKN(MCLKN),
    .MRN(MRN),
    .NEXT_12_0(NEXT_12_0),
    .RET_12_0(RET_12_0),
    .SC5(SC5),
    .SC6(SC6),
    .IW_12_0(IW_12_0),
    .W_12_0(W_12_0)
  );

  // ------------------------------------------------------------------
  // Parallel capture variant V_NEG: negedge sysclk + edge-detect on
  // mclk rising. This captures HALF a sysclk later than the posedge
  // sysclk version inside MASEL. The half-sysclk gap gives more time
  // for the SC5/SC6 -> regREP combinational path to settle, which
  // *should* be more robust on FPGA hardware where setup time is real.
  //
  // Driven by the SAME regREP signal MASEL sees (via hierarchical
  // reference into the UUT).
  // ------------------------------------------------------------------
  reg [12:0] regIW_neg;
  reg        mclk_prev_neg;
  always @(negedge sysclk) begin
    if (!uut.s_mr_n) begin
      regIW_neg     <= 13'd0;
      mclk_prev_neg <= 1'b0;
    end else begin
      mclk_prev_neg <= MCLK;
      if (MCLK & ~mclk_prev_neg) regIW_neg <= uut.regREP;
    end
  end

  // Track pass/fail counts
  integer pass_count = 0;
  integer fail_count = 0;
  integer pass_neg   = 0;
  integer fail_neg   = 0;

  // ------------------------------------------------------------------
  // Stability monitoring — detect unwanted latch updates.
  //
  // Per design intent:
  //   - IW_12_0: stable EXCEPT at MCLK rising edge. Captures once at
  //     each rising MCLK and holds.
  //   - W_12_0:  latches every sysclk while MCLKN=1 (idle phase). Holds
  //     during the active phase (MCLK=1). So W_12_0 stability checks
  //     ONLY apply during the active phase.
  //
  // The check_iw monitor flags any IW_12_0 change between snapshots.
  // The check_w monitor flags any W_12_0 change while MCLK=1.
  // ------------------------------------------------------------------
  reg [12:0] iw_snapshot;
  reg [12:0] w_snapshot;
  reg        stab_iw_active;
  reg        stab_w_active;
  reg [8*64-1:0] stab_phase;
  integer    iw_glitch_count = 0;
  integer    w_glitch_count  = 0;

  always @(posedge sysclk) begin
    if (stab_iw_active && IW_12_0 !== iw_snapshot) begin
      $display("  GLITCH: IW_12_0 changed from %o to %o during %0s",
               iw_snapshot, IW_12_0, stab_phase);
      iw_glitch_count = iw_glitch_count + 1;
      iw_snapshot     = IW_12_0;
    end
    if (stab_w_active && MCLK && W_12_0 !== w_snapshot) begin
      $display("  GLITCH: W_12_0 changed from %o to %o during %0s (MCLK=1)",
               w_snapshot, W_12_0, stab_phase);
      w_glitch_count = w_glitch_count + 1;
      w_snapshot     = W_12_0;
    end
  end

  task begin_stab_iw(input [8*64-1:0] phase);
    begin
      iw_snapshot    = IW_12_0;
      stab_phase     = phase;
      stab_iw_active = 1;
    end
  endtask

  task begin_stab_w_active_only(input [8*64-1:0] phase);
    begin
      w_snapshot    = W_12_0;
      stab_phase    = phase;
      stab_w_active = 1;
    end
  endtask

  task end_stab;
    begin
      stab_iw_active = 0;
      stab_w_active  = 0;
    end
  endtask

  task check_iw(input [12:0] expected, input [8*64-1:0] label);
    begin
      // MASEL UUT (posedge sysclk + edge-detect)
      if (IW_12_0 === expected) begin
        $display("  PASS UUT: %0s -- IW_12_0 = 13'o%o (%0d)", label, IW_12_0, IW_12_0);
        pass_count = pass_count + 1;
      end else begin
        $display("  FAIL UUT: %0s -- expected 13'o%o (%0d), got 13'o%o (%0d)",
                 label, expected, expected, IW_12_0, IW_12_0);
        fail_count = fail_count + 1;
      end
      // Parallel V_NEG variant (negedge sysclk + edge-detect)
      if (regIW_neg === expected) begin
        $display("  PASS NEG: %0s -- regIW_neg = 13'o%o (%0d)", label, regIW_neg, regIW_neg);
        pass_neg = pass_neg + 1;
      end else begin
        $display("  FAIL NEG: %0s -- expected 13'o%o (%0d), got 13'o%o (%0d)",
                 label, expected, expected, regIW_neg, regIW_neg);
        fail_neg = fail_neg + 1;
      end
    end
  endtask

  // Helper: drive MCLK as a pulse, with SC5/SC6 transition timing controlled
  // by `race_at_edge` parameter (1 = transition at the same posedge as MCLK
  // rises, 0 = transition early before MCLK rise)

  initial begin
    $dumpfile("MASEL_iw_capture_tb.vcd");
    $dumpvars(0, MASEL_iw_capture_tb);

    // ---------------------------------------------------------------
    // Initial state
    // ---------------------------------------------------------------
    sys_rst_n  = 0;
    MRN        = 0;
    MCLK       = 0;
    SC5        = 0;
    SC6        = 0;
    CSBIT20    = 0;
    CSBIT_11_0 = 12'h000;
    JMP_3_0    = 4'h0;
    NEXT_12_0  = 13'o0001;  // sequential next
    RET_12_0   = 13'o7777;  // distinct return value

    // Hold reset
    @(posedge sysclk); @(posedge sysclk); @(posedge sysclk);
    sys_rst_n = 1;
    MRN       = 1;
    @(posedge sysclk);

    $display("");
    $display("================================================================");
    $display(" CGA_MIC_MASEL race-condition testbench");
    $display(" Tests regIW capture timing across SC5/SC6 transitions");
    $display("================================================================");

    // ---------------------------------------------------------------
    // Test 1: Clean SEL_JUMP — selectors stable BEFORE mclk rises
    // ---------------------------------------------------------------
    $display("");
    $display("Test 1: Clean SEL_JUMP — selectors stable before MCLK rising");

    // Set up JMP target = o2001 (MACL entry)
    // s_jmpaddr_12_0 = {CSBIT20, CSBIT_11_0[11:4], JMP_3_0[3:0]}
    // o2001 = 13'b0_010_000_000_001
    //   bit 12 = 0 → CSBIT20 = 0
    //   bits 11:4 = 8'b00100000 → CSBIT_11_0[11:4] = 8'b00100000
    //                              CSBIT_11_0[3:0]  = don't care
    //   bits 3:0  = 4'b0001 → JMP_3_0 = 4'b0001
    @(negedge sysclk);
    SC6 = 0; SC5 = 0;             // SEL_JUMP
    CSBIT20    = 1'b0;
    CSBIT_11_0 = 12'b0100_0000_0000;
    JMP_3_0    = 4'b0001;

    // Wait several sysclks for selectors to settle
    @(negedge sysclk); @(negedge sysclk);

    // Pulse MCLK high for several sysclks (matches real cycle)
    @(posedge sysclk); MCLK = 1;
    @(posedge sysclk);
    @(posedge sysclk);
    @(posedge sysclk); MCLK = 0;
    @(posedge sysclk);

    check_iw(13'o2001, "Test 1 IW after clean SEL_JUMP to o2001");

    // ---------------------------------------------------------------
    // Test 2: RACE — SC6 changes from NEXT (1) to JUMP (0) at the same
    // sysclk edge that MCLK rises. Same as the FPGA-observed bug.
    // ---------------------------------------------------------------
    $display("");
    $display("Test 2: RACE — SC6 transitions at same sysclk edge as MCLK rising");

    // First, set selectors to SEL_NEXT and let things settle
    @(negedge sysclk);
    SC6 = 1; SC5 = 0;             // SEL_NEXT (mux_selector=10)
    NEXT_12_0  = 13'o0001;        // would-be next address
    CSBIT20    = 1'b0;
    CSBIT_11_0 = 12'b0100_0000_0000;
    JMP_3_0    = 4'b0001;          // JMP target o2001 ready in CSBITS

    @(negedge sysclk); @(negedge sysclk);

    // Now create the race: MCLK rises and SC6 transitions to 0 (SEL_JUMP)
    // BOTH at the same posedge sysclk
    @(posedge sysclk);
    MCLK = 1;
    SC6  = 0;   // SEL_JUMP at same instant as MCLK rising

    @(posedge sysclk);
    @(posedge sysclk);
    @(posedge sysclk); MCLK = 0;
    @(posedge sysclk);

    check_iw(13'o2001, "Test 2 IW after race (correct = JUMP target o2001)");

    // ---------------------------------------------------------------
    // Test 3: RACE + revert — SC6 transitions to JUMP at MCLK rising,
    // then reverts to NEXT one sysclk later (more realistic for the
    // ND-120 where the JMP decision is brief)
    // ---------------------------------------------------------------
    $display("");
    $display("Test 3: RACE + revert (SC6 briefly = JUMP then back to NEXT)");

    @(negedge sysclk);
    SC6 = 1; SC5 = 0;             // start in SEL_NEXT
    NEXT_12_0 = 13'o0001;
    @(negedge sysclk); @(negedge sysclk);

    @(posedge sysclk);
    MCLK = 1;
    SC6  = 0;   // SEL_JUMP exactly at mclk rising

    @(posedge sysclk);
    SC6 = 1;    // revert to SEL_NEXT one sysclk later

    @(posedge sysclk);
    @(posedge sysclk); MCLK = 0;
    @(posedge sysclk);

    check_iw(13'o2001, "Test 3 IW after race+revert (still expect JUMP target)");

    // ---------------------------------------------------------------
    // Test 4: SEL_NEXT (no race) — confirm sequential address path works
    // ---------------------------------------------------------------
    $display("");
    $display("Test 4: SEL_NEXT clean — sequential address path");

    @(negedge sysclk);
    SC6 = 1; SC5 = 0;
    NEXT_12_0 = 13'o0123;
    @(negedge sysclk); @(negedge sysclk);

    @(posedge sysclk); MCLK = 1;
    @(posedge sysclk);
    @(posedge sysclk); MCLK = 0;
    @(posedge sysclk);

    check_iw(13'o0123, "Test 4 IW after clean SEL_NEXT to o0123");

    // ---------------------------------------------------------------
    // Test 5: SEL_RETURN — RET path
    // ---------------------------------------------------------------
    $display("");
    $display("Test 5: SEL_RETURN — return-stack address");

    @(negedge sysclk);
    SC6 = 0; SC5 = 1;
    RET_12_0 = 13'o4567;
    @(negedge sysclk); @(negedge sysclk);

    @(posedge sysclk); MCLK = 1;
    @(posedge sysclk);
    @(posedge sysclk); MCLK = 0;
    @(posedge sysclk);

    check_iw(13'o4567, "Test 5 IW after clean SEL_RETURN to o4567");

    // ---------------------------------------------------------------
    // Test 6: IW_12_0 STABILITY across many sysclks during a held
    // active phase. After capture, IW_12_0 must NOT change for any
    // sysclk while MCLK stays high.
    // ---------------------------------------------------------------
    $display("");
    $display("Test 6: IW_12_0 stability during held active phase (MCLK=1, many sysclks)");

    @(negedge sysclk);
    SC6 = 0; SC5 = 0;
    CSBIT20    = 1'b0;
    CSBIT_11_0 = 12'b0100_0000_0000;   // bits 11..4 of o2001
    JMP_3_0    = 4'b0001;              // bits 3..0 of o2001
    @(negedge sysclk); @(negedge sysclk);

    // Drive an MCLK rising edge to capture o2001
    @(posedge sysclk); MCLK = 1;

    // Snapshot AFTER one sysclk (let capture complete)
    @(posedge sysclk);
    begin_stab_iw("Test 6 hold MCLK=1");

    // Now poke regREP source signals while MCLK stays high — IW_12_0
    // should NOT respond
    @(posedge sysclk); SC6 = 1; SC5 = 0; NEXT_12_0 = 13'o7777;  // changes regREP via SEL_NEXT
    @(posedge sysclk); RET_12_0 = 13'o3333;
    @(posedge sysclk); SC6 = 0; SC5 = 1;                         // SEL_RETURN
    @(posedge sysclk); JMP_3_0 = 4'hF;                           // change JMP target
    @(posedge sysclk); SC6 = 1; SC5 = 1;                         // SEL_REPEAT
    @(posedge sysclk); CSBIT_11_0 = 12'hFFF;
    @(posedge sysclk);

    end_stab;
    @(posedge sysclk); MCLK = 0;
    check_iw(13'o2001, "Test 6 IW after stability check (still o2001)");

    // ---------------------------------------------------------------
    // Test 7: W_12_0 stability during HELD ACTIVE PHASE.
    // W_12_0 is a transparent latch during idle (mclk=0) but should
    // HOLD throughout the active phase. Any change while MCLK=1 is a
    // glitch.
    // ---------------------------------------------------------------
    $display("");
    $display("Test 7: W_12_0 stability during held active phase (MCLK=1)");

    @(negedge sysclk);
    SC6 = 0; SC5 = 0;
    CSBIT_11_0 = 12'b0100_0000_0000;
    JMP_3_0    = 4'b0001;
    @(negedge sysclk); @(negedge sysclk);

    @(posedge sysclk); MCLK = 1;
    @(posedge sysclk);   // let one sysclk pass for the capture to settle
    begin_stab_w_active_only("Test 7 hold W during MCLK=1");

    // Poke source signals while MCLK is held high — W_12_0 must hold
    @(posedge sysclk); NEXT_12_0  = 13'o5555;
    @(posedge sysclk); RET_12_0   = 13'o6666;
    @(posedge sysclk); SC6 = 1; SC5 = 0;
    @(posedge sysclk); JMP_3_0 = 4'hA;
    @(posedge sysclk); CSBIT_11_0 = 12'hAAA;
    @(posedge sysclk);

    end_stab;
    @(posedge sysclk); MCLK = 0;

    // ---------------------------------------------------------------
    // Test 8: IW_12_0 stability during HELD IDLE PHASE.
    // No MCLK rising edge has occurred since the last capture, so
    // IW_12_0 should remain at the previously captured value across
    // many sysclks regardless of regREP source changes.
    // ---------------------------------------------------------------
    $display("");
    $display("Test 8: IW_12_0 stability during held idle phase (MCLK=0)");

    // Set up known state via a single MCLK pulse
    @(negedge sysclk);
    SC6 = 0; SC5 = 0;
    CSBIT_11_0 = 12'b0100_0000_0000;
    JMP_3_0    = 4'b0001;
    @(negedge sysclk);
    @(posedge sysclk); MCLK = 1;
    @(posedge sysclk); @(posedge sysclk);
    @(posedge sysclk); MCLK = 0;
    @(posedge sysclk);

    begin_stab_iw("Test 8 hold MCLK=0");

    // Poke source signals while MCLK is held LOW — IW_12_0 still must hold
    @(posedge sysclk); SC6 = 1; SC5 = 0;
    @(posedge sysclk); NEXT_12_0 = 13'o1234;
    @(posedge sysclk); SC6 = 0; SC5 = 1;
    @(posedge sysclk); RET_12_0 = 13'o2345;
    @(posedge sysclk); CSBIT_11_0 = 12'h123;
    @(posedge sysclk); JMP_3_0 = 4'h7;
    @(posedge sysclk);

    end_stab;
    check_iw(13'o2001, "Test 8 IW after idle-phase stability check");

    // ---------------------------------------------------------------
    // Summary
    // ---------------------------------------------------------------
    $display("");
    $display("================================================================");
    $display(" UUT (in MASEL.v)");
    $display("    Capture-correctness: %0d PASS / %0d FAIL", pass_count, fail_count);
    $display("    IW_12_0 glitches:    %0d", iw_glitch_count);
    $display("    W_12_0 glitches:     %0d (during held MCLK=1 only)", w_glitch_count);
    $display(" V_NEG (parallel test variant)");
    $display("    Capture-correctness: %0d PASS / %0d FAIL", pass_neg, fail_neg);
    $display("================================================================");

    $finish;
  end

  // Safety timeout
  initial begin
    #5000;
    $display("TIMEOUT — testbench did not finish");
    $finish;
  end

endmodule

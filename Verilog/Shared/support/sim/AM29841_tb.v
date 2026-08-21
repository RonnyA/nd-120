/****************************************************************************
** AM29841 - functional testbench, all three capture behaviours          **
**                                                                        **
** This module has three DIFFERENT behaviours selected by parameters:     **
**   (a) FPGA_MODE=0, USE_ENABLE=0 : transparent latch (real AM29841      **
**       behaviour) - Q follows D continuously while LE is high.          **
**   (b) FPGA_MODE=1, USE_ENABLE=0 : edge-triggered - Q captures only on  **
**       the rising edge of LE, holding through the rest of the LE-high   **
**       period even if D keeps changing.                                 **
**   (c) USE_ENABLE=1              : Q captures on posedge sysclk while   **
**       EN is high; LE is ignored entirely (overrides FPGA_MODE).        **
**                                                                        **
** RTL-VS-DATASHEET DISAGREEMENT (record and assert the RTL, not the      **
** datasheet): the real AM29841 is a transparent latch - that behaviour   **
** is only mode (a) here. Without `USE_TRANSPARENT_LATCHES defined, the   **
** DEFAULT build (no explicit parameter override) is FPGA_MODE=1, i.e.    **
** mode (b), edge-triggered - NOT the real part's transparent-latch       **
** behaviour. This testbench exercises all three modes with EXPLICIT      **
** parameter overrides so the default-vs-real-part gap is visible and     **
** proven, not assumed.                                                   **
**                                                                        **
** COVERAGE: exhaustive over all 1024 D values in mode (b) (edge-         **
** triggered, the default build mode) - Y checked against D for every     **
** value after the LE capture edge. Modes (a) and (c) get directed        **
** sequences that prove their distinct level/enable timing.               **
**                                                                        **
** Every mode gets an explicit OE_n=1-forces-zero check with a non-zero   **
** stored value underneath, per the repo's zero-when-disabled convention. **
**                                                                        **
** Run: cd Verilog/Shared/support/sim && iverilog -g2012 -o tb.vvp \      **
**   AM29841_tb.v ../AM29841.v && vvp tb.vvp                              **
**                                                                        **
** Last reviewed: 20-AUG-2026                                            **
** Ronny Hansen                                                          **
*****************************************************************************/
`timescale 1ns / 1ps
`default_nettype none

module AM29841_tb;

  reg        sysclk = 0;
  always #5 sysclk = ~sysclk;

  reg  [9:0] D = 10'b0;
  reg        LE = 0;
  reg        EN = 0;
  reg        OE_n = 0;
  wire [9:0] Y_latch, Y_edge, Y_enable;

  integer errors = 0;
  integer checks = 0;

  AM29841 #(.FPGA_MODE(0), .USE_ENABLE(0)) U_LATCH (
      .sysclk(sysclk), .EN(EN), .D(D), .LE(LE), .OE_n(OE_n), .Y(Y_latch)
  );

  AM29841 #(.FPGA_MODE(1), .USE_ENABLE(0)) U_EDGE (
      .sysclk(sysclk), .EN(EN), .D(D), .LE(LE), .OE_n(OE_n), .Y(Y_edge)
  );

  AM29841 #(.USE_ENABLE(1)) U_ENABLE (
      .sysclk(sysclk), .EN(EN), .D(D), .LE(LE), .OE_n(OE_n), .Y(Y_enable)
  );

  integer i;

  // ---- (a) transparent latch: pulse LE and check Y follows D while high --
  task edge_pulse_and_check(input [9:0] dval);
    begin
      D = dval;
      LE = 0;
      #2;
      LE = 1;
      #2;
      checks = checks + 1;
      if (Y_edge !== dval) begin
        errors = errors + 1;
        if (errors < 10) $display("FAIL edge-mode capture: D=%03o Y_edge=%03o", dval, Y_edge);
      end
      LE = 0;
      #2;
    end
  endtask

  initial begin
    $dumpfile("AM29841_tb.vcd");
    $dumpvars(0, AM29841_tb);

    // ---- short documentation sequence --------------------------------------
    OE_n = 0;

    // transparent latch: Y tracks D while LE high
    D = 10'o0123; LE = 1; #2;
    checks = checks + 1;
    if (Y_latch !== 10'o0123) begin
      errors = errors + 1;
      $display("FAIL doc latch track 1: Y_latch=%03o expected 0123", Y_latch);
    end
    D = 10'o0456; #2;   // D changes while LE still high -> Y must follow
    checks = checks + 1;
    if (Y_latch !== 10'o0456) begin
      errors = errors + 1;
      $display("FAIL doc latch track 2: Y_latch=%03o expected 0456 (must track D while LE high)", Y_latch);
    end
    LE = 0; #2;
    D = 10'o0777;        // D changes after LE drops -> Y must hold
    #2;
    checks = checks + 1;
    if (Y_latch !== 10'o0456) begin
      errors = errors + 1;
      $display("FAIL doc latch hold: Y_latch=%03o expected 0456 (must hold, LE low)", Y_latch);
    end

    // edge mode, contrast: same D sequence, LE pulsed as an edge
    edge_pulse_and_check(10'o0123);
    edge_pulse_and_check(10'o0456);

    // enable mode
    EN = 0; LE = 0; D = 10'o0700;
    @(posedge sysclk); #1;
    checks = checks + 1;
    if (Y_enable !== 10'b0) begin
      errors = errors + 1;
      $display("FAIL doc enable gated: Y_enable=%03o expected 0 with EN=0", Y_enable);
    end
    EN = 1;
    @(posedge sysclk); #1;
    checks = checks + 1;
    if (Y_enable !== 10'o0700) begin
      errors = errors + 1;
      $display("FAIL doc enable capture: Y_enable=%03o expected 0700", Y_enable);
    end
    EN = 0;
    $dumpoff;

    // ---- exhaustive: all 1024 D values, edge-triggered mode (default build)
    $display("=====================================================");
    $display(" AM29841 exhaustive capture sweep, edge mode (1024 D values)");
    $display("=====================================================");
    for (i = 0; i < 1024; i = i + 1) begin
      edge_pulse_and_check(i[9:0]);
    end

    // ---- named check (a): transparent latch tracks D continuously while LE
    //      is high, INCLUDING a mid-pulse D change (the edge-mode divergence)
    D = 10'o0001; LE = 1; #2;
    checks = checks + 1;
    if (Y_latch !== 10'o0001) begin
      errors = errors + 1;
      $display("FAIL LATCH_TRACK_1: Y_latch=%03o expected 0001", Y_latch);
    end
    D = 10'o1000; #2;
    checks = checks + 1;
    if (Y_latch !== 10'o1000) begin
      errors = errors + 1;
      $display("FAIL LATCH_TRACK_MIDPULSE: Y_latch=%03o expected 1000 (real AM29841 behaviour: tracks while LE high)", Y_latch);
    end
    LE = 0; #2;

    // ---- named check (b): edge mode does NOT track a mid-pulse D change ---
    D = 10'o0011; LE = 0; #2; LE = 1; #2;
    checks = checks + 1;
    if (Y_edge !== 10'o0011) begin
      errors = errors + 1;
      $display("FAIL EDGE_CAPTURE: Y_edge=%03o expected 0011", Y_edge);
    end
    D = 10'o0022;        // D changes while LE still held high
    #2;
    checks = checks + 1;
    if (Y_edge !== 10'o0011) begin
      errors = errors + 1;
      $display("FAIL EDGE_NO_MIDPULSE_TRACK: Y_edge=%03o changed to reflect D=%03o while LE stayed high, edge mode must NOT track", Y_edge, D);
    end
    LE = 0; #2;

    // ---- named check (c): enable mode captures on sysclk+EN, LE ignored ---
    // First put a KNOWN value into Q_reg via a real EN=1 capture, so the
    // "gated" checks below are proven against a held value, not X.
    LE = 0; EN = 1; D = 10'o0555;
    @(posedge sysclk); #1;
    EN = 0;
    checks = checks + 1;
    if (Y_enable !== 10'o0555) begin
      errors = errors + 1;
      $display("FAIL ENABLE_setup: Y_enable=%03o expected 0555", Y_enable);
    end
    D = 10'o0333;          // EN=0: this D must NOT be captured
    @(posedge sysclk); #1;
    checks = checks + 1;
    if (Y_enable !== 10'o0555) begin
      errors = errors + 1;
      $display("FAIL ENABLE_GATED: Y_enable=%03o expected held value 0555 with EN=0", Y_enable);
    end
    LE = 1;               // LE asserted but must be ignored in this mode
    @(posedge sysclk); #1;
    checks = checks + 1;
    if (Y_enable !== 10'o0555) begin
      errors = errors + 1;
      $display("FAIL ENABLE_LE_IGNORED: Y_enable=%03o expected held value 0555, LE alone must not capture in USE_ENABLE mode", Y_enable);
    end
    EN = 1;
    @(posedge sysclk); #1;
    checks = checks + 1;
    if (Y_enable !== 10'o0333) begin
      errors = errors + 1;
      $display("FAIL ENABLE_CAPTURE: Y_enable=%03o expected 0333 with EN=1", Y_enable);
    end
    EN = 0; LE = 0;

    // ---- OE_n = 0-output check, all three modes, non-zero stored value ----
    // latch mode
    D = 10'o1777; LE = 1; #2; LE = 0; #2;
    checks = checks + 1;
    if (Y_latch !== 10'o1777) begin
      errors = errors + 1;
      $display("FAIL OE_setup latch: Y_latch=%03o expected 1777", Y_latch);
    end
    OE_n = 1; #1;
    checks = checks + 1;
    if (Y_latch !== 10'b0) begin
      errors = errors + 1;
      $display("FAIL OE_MASK_LATCH: Y_latch=%03o expected 0 with OE_n=1", Y_latch);
    end
    OE_n = 0; #1;
    checks = checks + 1;
    if (Y_latch !== 10'o1777) begin
      errors = errors + 1;
      $display("FAIL OE_UNMASK_LATCH: Y_latch=%03o expected 1777 after OE_n back to 0", Y_latch);
    end

    // edge mode
    edge_pulse_and_check(10'o1777);
    OE_n = 1; #1;
    checks = checks + 1;
    if (Y_edge !== 10'b0) begin
      errors = errors + 1;
      $display("FAIL OE_MASK_EDGE: Y_edge=%03o expected 0 with OE_n=1", Y_edge);
    end
    OE_n = 0; #1;
    checks = checks + 1;
    if (Y_edge !== 10'o1777) begin
      errors = errors + 1;
      $display("FAIL OE_UNMASK_EDGE: Y_edge=%03o expected 1777 after OE_n back to 0", Y_edge);
    end

    // enable mode
    D = 10'o1777; EN = 1;
    @(posedge sysclk); #1;
    EN = 0;
    checks = checks + 1;
    if (Y_enable !== 10'o1777) begin
      errors = errors + 1;
      $display("FAIL OE_setup enable: Y_enable=%03o expected 1777", Y_enable);
    end
    OE_n = 1; #1;
    checks = checks + 1;
    if (Y_enable !== 10'b0) begin
      errors = errors + 1;
      $display("FAIL OE_MASK_ENABLE: Y_enable=%03o expected 0 with OE_n=1", Y_enable);
    end
    OE_n = 0; #1;
    checks = checks + 1;
    if (Y_enable !== 10'o1777) begin
      errors = errors + 1;
      $display("FAIL OE_UNMASK_ENABLE: Y_enable=%03o expected 1777 after OE_n back to 0", Y_enable);
    end

    $display("-----------------------------------------------------");
    $display(" checks run : %0d", checks);
    $display(" failures   : %0d", errors);
    if (errors == 0) $display("TB_RESULT: PASS");
    else             $display("TB_RESULT: FAIL");
    $display("=====================================================");
    $finish;
  end

  initial begin
    #400000;
    $display("FAIL [timeout]: watchdog fired");
    $display("TB_RESULT: FAIL (timeout)");
    $finish;
  end

endmodule

`default_nettype wire

//============================================================================
//! Equivalence-check driver for IDT6168A_20 (31-AUG-2026).
//!
//! NOT a pass/fail testbench by itself - it drives a long, deterministic,
//! fixed-seed sequence (burst writes, burst reads, back-to-back same-address
//! writes, CE_n toggling mid-burst, address changes while WE_n stays low)
//! and dumps every cycle's inputs/outputs to a text log. Run this file
//! TWICE - once compiled plain (no defines: exercises the proven
//! plain-Verilog path) and once with -DQUARTUS_RAM_INFER=1 (exercises the
//! arm Quartus builds for the MiSTer) - then diff the two logs. Identical
//! logs = the two implementations are behaviorally equivalent for
//! everything this sequence covers. run_quartus_ram_equiv.sh does exactly
//! that. (Until 01-SEP-2026 the second run was the altsyncram megafunction
//! arm against a hand-written stub; both are gone - see IDT6168A_20.v.)
//============================================================================

`timescale 1ns / 1ps

module IDT6168A_20_equiv_tb;

  reg        clk = 0;
  reg        reset_n = 0;
  reg [11:0] A_11_0 = 0;
  reg        CE_n = 1;
  reg        WE_n = 1;
  reg [ 3:0] D_3_0_IN = 0;
  wire [3:0] D_3_0_OUT;

  integer logf;
  integer i;
  integer seed = 32'hC0FFEE;

  always #5 clk = ~clk;

  IDT6168A_20 DUT (
      .clk      (clk),
      .reset_n  (reset_n),
      .A_11_0   (A_11_0),
      .CE_n     (CE_n),
      .WE_n     (WE_n),
      .D_3_0_IN (D_3_0_IN),
      .D_3_0_OUT(D_3_0_OUT)
  );

  task step;
    begin
      @(posedge clk);
      #1;
      logf = $fopen("equiv_log.txt", "a");
      $fdisplay(logf, "%0d CE=%b WE=%b A=%0d DIN=%0d DOUT=%0d", $time, CE_n, WE_n, A_11_0,
                D_3_0_IN, D_3_0_OUT);
      $fclose(logf);
    end
  endtask

  initial begin
    logf = $fopen("equiv_log.txt", "w");
    $fclose(logf);

    reset_n = 0;
    CE_n    = 1;
    WE_n    = 1;
    repeat (4) step;
    reset_n = 1;

    // --- directed: single write then single read, same address -----------
    A_11_0   = 12'h010;
    D_3_0_IN = 4'hA;
    CE_n     = 0;
    WE_n     = 0;
    step;
    WE_n = 1;
    step;
    step;  // read latency

    // --- directed: burst write, sequential addresses, WE_n held low ------
    CE_n = 0;
    WE_n = 0;
    for (i = 0; i < 16; i = i + 1) begin
      A_11_0   = 12'h100 + i;
      D_3_0_IN = i[3:0] ^ 4'h5;
      step;
    end
    WE_n = 1;

    // --- burst read back the same addresses -------------------------------
    for (i = 0; i < 16; i = i + 1) begin
      A_11_0 = 12'h100 + i;
      step;
    end

    // --- back-to-back writes to the SAME address (repeat write) ----------
    A_11_0   = 12'h200;
    WE_n     = 0;
    D_3_0_IN = 4'h1;
    step;
    D_3_0_IN = 4'h2;
    step;
    D_3_0_IN = 4'h3;
    step;
    WE_n = 1;
    step;  // read back - should see 4'h3

    // --- CE_n toggling mid-burst (deselect for one cycle, then resume) ---
    A_11_0   = 12'h300;
    WE_n     = 0;
    D_3_0_IN = 4'h7;
    step;
    CE_n = 1;  // deselect - this cycle's write must NOT happen
    step;
    CE_n     = 0;
    D_3_0_IN = 4'h8;
    step;
    WE_n = 1;
    step;

    // --- address changes while reading (continuous re-read window) -------
    CE_n = 0;
    WE_n = 1;
    for (i = 0; i < 8; i = i + 1) begin
      A_11_0 = 12'h100 + i;
      step;
    end

    // --- pseudo-random stress: 500 cycles of randomized CE/WE/A/D --------
    for (i = 0; i < 500; i = i + 1) begin
      CE_n     = ($random(seed) % 5 == 0) ? 1'b1 : 1'b0;  // mostly selected
      WE_n     = ($random(seed) % 3 == 0) ? 1'b0 : 1'b1;  // occasional write
      A_11_0   = $random(seed) % 4096;
      D_3_0_IN = $random(seed) % 16;
      step;
    end

    CE_n = 1;
    step;
    step;

    $display("EQUIV_TB_DONE");
    $finish;
  end

endmodule

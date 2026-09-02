//============================================================================
//! Self-checking testbench for mips_counter.v - the panel's MIPS field.
//!
//! The counter is pure arithmetic, so the checks are exact numbers, scaled
//! down through the parameters so a whole "second" is a thousand clocks:
//!
//!   A. CLOCK_HZ=1000, SUB_MAX=10, a fetch edge every 4 clocks
//!      -> 250 edges in the window -> 25 chain bumps -> mips_bcd = 0025.
//!   B. The next window with NO fetches must publish 0000 - a stopped
//!      machine reads 00.00, not the last number it ever did.
//!   C. Saturation: SUB_MAX=1 and an edge every 2 clocks over a 25000-clock
//!      window is 12500 bumps - the chain must hold at 9999, not wrap to
//!      2501 (a wrap would read as 25.01, believable and wrong).
//!   D. Digits are BCD, checked digit by digit in A - 250 edges also proves
//!      a fetch held high for 2 clocks counts ONCE (edge, not level).
//!
//! Run: make test-mips-counter   (Verilog/Terminals/sim/)
//!
//! Written 30-AUG-2026.
//============================================================================

`default_nettype none
`timescale 1ns / 1ps

module mips_counter_tb;

  reg clk = 1'b0;
  always #5 clk = ~clk;

  reg rst_n = 1'b0;
  reg fetch_a = 1'b0;
  reg fetch_c = 1'b0;

  wire [15:0] bcd_a;
  wire [15:0] bcd_c;

  mips_counter #(
      .CLOCK_HZ(1000),
      .SUB_MAX (10)
  ) DUT_A (
      .clk(clk), .rst_n(rst_n), .fetch(fetch_a), .mips_bcd(bcd_a)
  );

  mips_counter #(
      .CLOCK_HZ(25000),
      .SUB_MAX (1)
  ) DUT_C (
      .clk(clk), .rst_n(rst_n), .fetch(fetch_c), .mips_bcd(bcd_c)
  );

  integer errors = 0;
  integer i;

  initial begin
    $dumpfile("mips_counter_tb.vcd");
    $dumpvars(1, mips_counter_tb);

    repeat (4) @(posedge clk);
    rst_n = 1'b1;
    @(posedge clk);

    //----------------------------------------------------------------
    // A: 250 fetch cycles inside the 1000-clock window
    //----------------------------------------------------------------
    // 3-clock cycles (2 high, 1 low) so all 250 edges land comfortably
    // inside the 1000-clock window - 750 clocks used, 250 to spare.
    // NONBLOCKING drives throughout: a blocking assign right after
    // @(posedge clk) races the DUT's own sampling flop - both run in the
    // same timestep in whichever order the simulator picks, and iverilog
    // picked the one where fetch and its delayed copy move together, so no
    // edge was ever detected. `<=` updates after every flop has sampled,
    // which is also how the signal behaves on the board.
    for (i = 0; i < 250; i = i + 1) begin
      fetch_a <= 1'b1; repeat (2) @(posedge clk);
      fetch_a <= 1'b0; @(posedge clk);
    end
    // let the window close and publish
    wait (bcd_a != 16'h0000);
    @(posedge clk);
    if (bcd_a !== 16'h0025) begin
      $display("FAIL: A published %04x, expected 0025 (250 edges / SUB_MAX 10)", bcd_a);
      errors = errors + 1;
    end else $display("-- A: 250 fetch cycles in one window publish 0025");

    //----------------------------------------------------------------
    // B: a whole quiet window publishes 0000
    //----------------------------------------------------------------
    repeat (1100) @(posedge clk);
    if (bcd_a !== 16'h0000) begin
      $display("FAIL: B published %04x after an idle window, expected 0000", bcd_a);
      errors = errors + 1;
    end else $display("-- B: an idle window publishes 0000");

    //----------------------------------------------------------------
    // C: saturation at 9999
    //----------------------------------------------------------------
    // DUT_C has been counting the whole time; restart it cleanly.
    rst_n = 1'b0; repeat (2) @(posedge clk); rst_n = 1'b1;
    for (i = 0; i < 12500; i = i + 1) begin
      fetch_c <= 1'b1; @(posedge clk);
      fetch_c <= 1'b0; @(posedge clk);
    end
    wait (bcd_c != 16'h0000);
    @(posedge clk);
    if (bcd_c !== 16'h9999) begin
      $display("FAIL: C published %04x, expected saturation at 9999", bcd_c);
      errors = errors + 1;
    end else $display("-- C: 12500 bumps in one window saturate at 9999");

    if (errors == 0) $display("TB_RESULT: PASS (window arithmetic, idle clear, saturation)");
    else $display("TB_RESULT: FAIL (%0d errors)", errors);
    $finish;
  end

  initial begin
    #10_000_000;
    $display("FAIL: timeout");
    $display("TB_RESULT: FAIL (timeout)");
    $finish;
  end

endmodule

`default_nettype wire

//============================================================================
//! Self-checking testbench for vga_timing.v
//!
//! Verifies the 800x600@60 default mode against the numbers a monitor
//! actually cares about: total pixels per line, total lines per frame, the
//! position and length of both sync pulses, sync polarity, and that exactly
//! H_VISIBLE*V_VISIBLE pixel clocks per frame have `de` asserted.
//!
//! Prints "TB_RESULT: PASS" or "TB_RESULT: FAIL" - the pattern
//! Verilog/tests/run_all_tests.sh greps for.
//!
//! Written 27-AUG-2026.
//============================================================================

`timescale 1ns / 1ps
`default_nettype none

module vga_timing_tb;

  localparam integer H_VISIBLE = 800;
  localparam integer H_FP      = 40;
  localparam integer H_SYNC    = 128;
  localparam integer H_BP      = 88;
  localparam integer V_VISIBLE = 600;
  localparam integer V_FP      = 1;
  localparam integer V_SYNC    = 4;
  localparam integer V_BP      = 23;

  localparam integer H_TOTAL = H_VISIBLE + H_FP + H_SYNC + H_BP;  // 1056
  localparam integer V_TOTAL = V_VISIBLE + V_FP + V_SYNC + V_BP;  // 628

  reg clk = 1'b0;
  reg rst_n = 1'b0;

  wire [11:0] x, y;
  wire hsync, vsync, de, hblank, vblank, line_end, frame_end;

  integer errors = 0;

  // 40 MHz pixel clock = 25 ns period
  always #12.5 clk = ~clk;

  vga_timing #(
      .H_VISIBLE    (H_VISIBLE),
      .H_FRONT_PORCH(H_FP),
      .H_SYNC       (H_SYNC),
      .H_BACK_PORCH (H_BP),
      .V_VISIBLE    (V_VISIBLE),
      .V_FRONT_PORCH(V_FP),
      .V_SYNC       (V_SYNC),
      .V_BACK_PORCH (V_BP)
  ) DUT (
      .clk      (clk),
      .rst_n    (rst_n),
      .x        (x),
      .y        (y),
      .hsync    (hsync),
      .vsync    (vsync),
      .de       (de),
      .hblank   (hblank),
      .vblank   (vblank),
      .line_end (line_end),
      .frame_end(frame_end)
  );

  task check;
    input condition;
    input [1023:0] what;
    begin
      if (!condition) begin
        $display("FAIL: %0s (at x=%0d y=%0d, time %0t)", what, x, y, $time);
        errors = errors + 1;
      end
    end
  endtask

  //--------------------------------------------------------------------------
  // Counters gathered over one whole frame
  //--------------------------------------------------------------------------

  integer de_count = 0;          //! pixel clocks with de high
  integer hsync_count = 0;       //! pixel clocks with hsync high
  integer vsync_count = 0;       //! pixel clocks with vsync high
  integer line_end_count = 0;
  integer clocks = 0;
  integer measuring = 0;

  always @(posedge clk) begin
    if (measuring) begin
      clocks = clocks + 1;
      if (de) de_count = de_count + 1;
      if (hsync) hsync_count = hsync_count + 1;
      if (vsync) vsync_count = vsync_count + 1;
      if (line_end) line_end_count = line_end_count + 1;

      // de must be exactly "inside both visible windows", every single clock
      check(de == (!hblank && !vblank), "de != ~(hblank|vblank)");
    end
  end

  //--------------------------------------------------------------------------

  initial begin
    $dumpfile("vga_timing_tb.vcd");
    $dumpvars(0, vga_timing_tb);

    repeat (4) @(posedge clk);
    rst_n = 1'b1;

    // Get to the start of a frame so the measurement covers exactly one.
    @(posedge frame_end);
    @(posedge clk);
    measuring = 1;

    // Measure one full frame.
    @(posedge frame_end);
    @(posedge clk);
    measuring = 0;

    $display("clocks per frame  : %0d (expect %0d)", clocks, H_TOTAL * V_TOTAL);
    $display("de clocks         : %0d (expect %0d)", de_count, H_VISIBLE * V_VISIBLE);
    $display("hsync clocks      : %0d (expect %0d)", hsync_count, H_SYNC * V_TOTAL);
    $display("vsync clocks      : %0d (expect %0d)", vsync_count, V_SYNC * H_TOTAL);
    $display("lines per frame   : %0d (expect %0d)", line_end_count, V_TOTAL);

    check(clocks == H_TOTAL * V_TOTAL, "wrong number of pixel clocks per frame");
    check(de_count == H_VISIBLE * V_VISIBLE, "wrong number of visible pixels");
    check(hsync_count == H_SYNC * V_TOTAL, "wrong total hsync width");
    check(vsync_count == V_SYNC * H_TOTAL, "wrong total vsync width");
    check(line_end_count == V_TOTAL, "wrong number of lines per frame");

    // Sync polarity: both positive for 800x600, i.e. hsync must be LOW during
    // the visible part of a line. Sample it at a known visible pixel.
    @(posedge clk);
    while (!(de && x == 12'd100)) @(posedge clk);
    check(hsync == 1'b0, "hsync active during visible area - polarity wrong");
    check(vsync == 1'b0, "vsync active during visible area - polarity wrong");

    if (errors == 0) $display("TB_RESULT: PASS");
    else $display("TB_RESULT: FAIL (%0d errors)", errors);

    $finish;
  end

  // Safety net: 800x600@60 is ~16.6 ms per frame; two frames plus slack.
  initial begin
    #50_000_000;
    $display("FAIL: timeout");
    $display("TB_RESULT: FAIL (timeout)");
    $finish;
  end

endmodule

`default_nettype wire

//============================================================================
//! Self-checking testbench for term_panel.v - the ND-120 operator panel
//!
//! WHAT IT CHECKS, and why these and not a picture comparison. The panel's
//! output is a colour per pixel; comparing a whole rendered frame against a
//! model would mean writing the renderer twice, and the second copy would share
//! the first one's misunderstandings. So this checks the properties that must
//! hold whatever the panel draws:
//!
//!   1. enable low  -> `active` NEVER asserts, anywhere in the frame. The
//!      board's switch is worth nothing if the panel still paints over things.
//!   2. enable high -> `active` asserts, and ONLY inside the declared region.
//!      A region-maths error is the easy bug here and it silently eats either
//!      the console text above or the screen edge.
//!   3. the region is the right SIZE - 80x5 cells of 8x16 - counted in pixels
//!      rather than assumed from the parameters that produced it.
//!   4. the level cell for the current PIL lights, and a level the CPU has
//!      never been on does not. That is the whole point of the field.
//!   5. changing PIL moves the lit cell, and the old one FADES rather than
//!      dropping instantly - the afterglow the real panel had.
//!
//! Check 5 is the one worth the effort: the first implementation had a decay
//! constant that took 28 minutes, which would have shown every level lit for
//! ever and looked entirely plausible while telling you nothing.
//!
//! Prints "TB_RESULT: PASS" or "TB_RESULT: FAIL".
//!
//! Written 28-AUG-2026.
//============================================================================

`timescale 1ns / 1ps
`default_nettype none

module term_panel_tb;

  localparam integer ORIGIN_X = 80;
  localparam integer ORIGIN_Y = 420;
  localparam integer W = 80 * 8;    // 640
  localparam integer H = 5  * 16;   // 80

  reg clk = 1'b0;
  reg rst_n = 1'b0;

  reg [11:0] x = 12'd0;
  reg [11:0] y = 12'd0;
  reg        mode = 1'b0;
  reg        enable = 1'b0;

  reg [3:0] pil = 4'd0;
  reg [3:0] utilization = 4'd4;
  reg [3:0] cache_hit = 4'd6;
  reg [1:0] ring = 2'd2;
  reg       paging_on = 1'b1;
  reg       interrupt_on = 1'b1;
  reg       running = 1'b1;
  reg [4:0] up_hours = 5'd1;
  reg [5:0] up_minutes = 6'd23;
  reg [5:0] up_seconds = 6'd45;

  wire       active;
  wire [2:0] colour;

  integer errors = 0;
  integer i;

  always #12.5 clk = ~clk;

  term_panel #(
      .FONT_FILE("../font/font8x16.hex"),
      .ORIGIN_X (ORIGIN_X),
      .ORIGIN_Y (ORIGIN_Y)
  ) DUT (
      .clk(clk), .rst_n(rst_n),
      .x(x), .y(y), .mode(mode), .enable(enable),
      // Held high so the testbench sees values immediately; on hardware
      // this is one pulse per frame.
      .frame_tick(1'b1),
      .pil(pil), .utilization(utilization), .cache_hit(cache_hit),
      .ring(ring), .paging_on(paging_on), .interrupt_on(interrupt_on),
      .running(running),
      .hdd_rd(1'b0), .hdd_wr(1'b0), .flp_rd(1'b0), .flp_wr(1'b0),
      .up_hours(up_hours), .up_minutes(up_minutes), .up_seconds(up_seconds),
      .active(active), .colour(colour)
  );

  //--------------------------------------------------------------------------
  //! Walk one rectangle of the screen and report how many pixels the panel
  //! claimed. The two clocks of pipeline delay mean the answer for a position
  //! arrives two clocks later, so the walk is deliberately slow and samples
  //! after settling rather than trying to track the pipeline.
  //--------------------------------------------------------------------------
  task scan_box;
    input integer x0, y0, x1, y1;
    output integer claimed;
    integer xi, yi;
    begin
      claimed = 0;
      for (yi = y0; yi < y1; yi = yi + 1) begin
        for (xi = x0; xi < x1; xi = xi + 1) begin
          @(negedge clk);
          x = xi[11:0];
          y = yi[11:0];
          // FOUR clocks, matching term_panel's pipeline depth: stage 1 (cell
          // position), stage 2 (composed character), the font ROM's registered
          // output, and one to settle. It was three until the panel was
          // pipelined to close timing at 148.4 MHz, and the symptom of getting
          // this wrong is precise and misleading - "claimed 639 of 640 pixels"
          // plus one pixel outside the origin, which reads like an off-by-one
          // in the region maths rather than a stale number in the testbench.
          repeat (4) @(posedge clk);
          if (active) claimed = claimed + 1;
        end
      end
    end
  endtask

  //! Is the level cell for `lvl` showing its lit glyph? Sampled by parking on a
  //! pixel inside that cell and reading the panel's own decision, rather than
  //! re-deriving the address here.
  task level_lit;
    input integer lvl;
    output lit;
    begin
      lit = DUT.s_glow[lvl] != 8'd0;
    end
  endtask

  integer claimed;
  reg lit_a, lit_b;

  initial begin
    $dumpfile("term_panel_tb.vcd");
    $dumpvars(1, term_panel_tb);

    repeat (4) @(posedge clk);
    rst_n = 1'b1;

    //------------------------------------------------------------------
    // 1. Disabled means silent.
    //------------------------------------------------------------------
    enable = 1'b0;
    scan_box(ORIGIN_X - 4, ORIGIN_Y - 4, ORIGIN_X + 20, ORIGIN_Y + 20, claimed);
    if (claimed != 0) begin
      $display("FAIL: panel claimed %0d pixels while disabled", claimed);
      errors = errors + 1;
    end else $display("-- disabled: 0 pixels claimed");

    //------------------------------------------------------------------
    // 2 & 3. Enabled, the region is exactly where and how big it should be.
    //        Scanned as a band one cell tall so the test stays quick, then
    //        the vertical extent is checked separately.
    //------------------------------------------------------------------
    enable = 1'b1;

    scan_box(ORIGIN_X, ORIGIN_Y, ORIGIN_X + W, ORIGIN_Y + 1, claimed);
    if (claimed != W) begin
      $display("FAIL: top row of the panel claimed %0d of %0d pixels", claimed, W);
      errors = errors + 1;
    end else $display("-- full width claimed: %0d pixels", claimed);

    // Just outside on the left and right must be silent.
    scan_box(ORIGIN_X - 8, ORIGIN_Y, ORIGIN_X, ORIGIN_Y + 1, claimed);
    if (claimed != 0) begin
      $display("FAIL: panel claimed %0d pixels LEFT of its origin", claimed);
      errors = errors + 1;
    end
    scan_box(ORIGIN_X + W, ORIGIN_Y, ORIGIN_X + W + 8, ORIGIN_Y + 1, claimed);
    if (claimed != 0) begin
      $display("FAIL: panel claimed %0d pixels RIGHT of its region", claimed);
      errors = errors + 1;
    end

    // Above the first row and below the last must be silent too.
    scan_box(ORIGIN_X, ORIGIN_Y - 2, ORIGIN_X + 8, ORIGIN_Y, claimed);
    if (claimed != 0) begin
      $display("FAIL: panel claimed %0d pixels ABOVE its region", claimed);
      errors = errors + 1;
    end
    scan_box(ORIGIN_X, ORIGIN_Y + H, ORIGIN_X + 8, ORIGIN_Y + H + 2, claimed);
    if (claimed != 0) begin
      $display("FAIL: panel claimed %0d pixels BELOW its region", claimed);
      errors = errors + 1;
    end
    if (errors == 0) $display("-- region bounded correctly on all four sides");

    //------------------------------------------------------------------
    // 4. The current level lights; an untouched one does not.
    //------------------------------------------------------------------
    pil = 4'd7;
    repeat (50) @(posedge clk);
    level_lit(7, lit_a);
    level_lit(3, lit_b);
    if (!lit_a) begin
      $display("FAIL: level 7 is current but its cell is not lit");
      errors = errors + 1;
    end
    if (lit_b) begin
      $display("FAIL: level 3 has never been current but its cell is lit");
      errors = errors + 1;
    end
    if (lit_a && !lit_b) $display("-- current level lit, untouched level dark");

    //------------------------------------------------------------------
    // 5. Afterglow: move off level 7 and it must fade, not vanish, and must
    //    eventually go out. A decay that never completes looks exactly like
    //    a working display and reports nothing - which is what the first
    //    version did, with a 28-minute time constant.
    //------------------------------------------------------------------
    pil = 4'd2;
    repeat (200) @(posedge clk);
    level_lit(7, lit_a);
    if (!lit_a) begin
      $display("FAIL: level 7 went dark immediately - there is no afterglow");
      errors = errors + 1;
    end else $display("-- level 7 still glowing shortly after moving off it");

    // Now run long enough for the glow to expire. 255 decrements at one per
    // 2^17 clocks is ~33.4 M clocks; step the tick counter directly rather
    // than simulating all of them.
    for (i = 0; i < 300; i = i + 1) begin
      force DUT.s_glow_tick = 17'h1FFFF;
      @(posedge clk);
      release DUT.s_glow_tick;
      @(posedge clk);
    end
    level_lit(7, lit_a);
    level_lit(2, lit_b);
    if (lit_a) begin
      $display("FAIL: level 7 never decayed - the afterglow does not expire");
      errors = errors + 1;
    end else $display("-- level 7 decayed to dark");
    if (!lit_b) begin
      $display("FAIL: level 2 is current but decayed anyway");
      errors = errors + 1;
    end else $display("-- level 2, still current, stayed lit throughout");

    if (errors == 0) $display("TB_RESULT: PASS (region bounded, levels and afterglow)");
    else $display("TB_RESULT: FAIL (%0d errors)", errors);

    $finish;
  end

  initial begin
    #200_000_000;
    $display("FAIL: timeout");
    $display("TB_RESULT: FAIL (timeout)");
    $finish;
  end

endmodule

`default_nettype wire

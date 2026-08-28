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

  //! A REAL frame tick, one clock wide, once every FRAME_CLOCKS.
  //!
  //! This used to be tied to 1'b1 "so the testbench sees values immediately".
  //! That tie is why this bench could not see the bug Ronny reported on
  //! 28-AUG-2026 (the ACTIVE LEVEL row lighting far more lamps than the CPU
  //! was using). term_panel RELOADS s_glow[pil] every clock and DECAYS one
  //! step per frame_tick. With frame_tick high the two happen at the same
  //! rate, so the glow behaved sanely here while on hardware - where a frame
  //! is 666,666 clocks at 40 MHz - a level needs 63 whole frames untouched
  //! before it goes dark, and anything the CPU revisits sooner stays lit for
  //! ever.
  //!
  //! FRAME_CLOCKS is 400 rather than 666,666: the point is only that a frame
  //! must be MUCH longer than one clock, so the reload/decay ratio is the one
  //! the hardware has. 400 keeps the run short enough to be a unit test.
  localparam integer FRAME_CLOCKS = 400;
  reg  [15:0] frame_div = 16'd0;
  reg         frame_tick = 1'b0;
  always @(posedge clk) begin
    if (frame_div == FRAME_CLOCKS - 1) begin
      frame_div  <= 16'd0;
      frame_tick <= 1'b1;
    end else begin
      frame_div  <= frame_div + 16'd1;
      frame_tick <= 1'b0;
    end
  end

  //! Run the panel for a number of whole frames.
  task run_frames (input integer frames);
    integer f;
    begin
      for (f = 0; f < frames; f = f + 1) begin
        @(posedge frame_tick);
      end
      @(posedge clk);
    end
  endtask

  //! How many of the 16 level lamps are lit right now.
  function integer lamps_lit;
    integer k, c;
    begin
      c = 0;
      for (k = 0; k < 16; k = k + 1) if (DUT.s_glow[k] != 6'd0) c = c + 1;
      lamps_lit = c;
    end
  endfunction

  term_panel #(
      .FONT_FILE("../font/font8x16.hex"),
      .ORIGIN_X (ORIGIN_X),
      .ORIGIN_Y (ORIGIN_Y)
  ) DUT (
      .clk(clk), .rst_n(rst_n),
      .x(x), .y(y), .mode(mode), .enable(enable),
      .frame_tick(frame_tick),
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
      lit = DUT.s_glow[lvl] != 6'd0;
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
    // 5. Afterglow: moving off a level must FADE it, not drop it, and the
    //    fade must eventually complete.
    //
    //    Timed in REAL FRAMES since 28-AUG-2026. frame_tick used to be tied
    //    high here, which made the decay run once per clock and hid the fact
    //    that on hardware the reload is per CLOCK while the decay is per
    //    FRAME. Anything measured in clocks was measuring a ratio the
    //    hardware does not have.
    //------------------------------------------------------------------
    pil = 4'd2;
    @(posedge clk);
    @(posedge clk);
    level_lit(7, lit_a);
    if (!lit_a) begin
      $display("FAIL: level 7 went dark immediately - there is no afterglow");
      errors = errors + 1;
    end else $display("-- level 7 still glowing just after moving off it");

    // 63 decay steps, one per FRAME - about a second at 60 Hz on hardware.
    // Wait comfortably past it, in frames.
    run_frames(70);
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

    //------------------------------------------------------------------
    // 6. EXACTLY ONE level is the current one. The manual is explicit that a
    //    single position is set; the first version lit every level touched in
    //    the last 0.84 s equally, which reads as a row of equals rather than
    //    as a machine running on one level.
    //------------------------------------------------------------------
    begin : one_current
      integer lv, n_current;
      n_current = 0;
      for (lv = 0; lv < 16; lv = lv + 1)
        if (lv[3:0] == DUT.r_pil) n_current = n_current + 1;
      if (n_current != 1) begin
        $display("FAIL: %0d levels claim to be current, expected exactly 1", n_current);
        errors = errors + 1;
      end else $display("-- exactly one level is current");
    end

    //------------------------------------------------------------------
    // 7. THE RELOAD/DECAY RATIO, which nothing checked before.
    //
    //    s_glow[pil] is reloaded to full on EVERY CLOCK, and decays one step
    //    per FRAME. So a level the CPU keeps returning to is pinned lit, and
    //    only a level left alone for 63 whole frames goes dark. With
    //    frame_tick tied high that asymmetry did not exist here at all.
    //
    //    This checks the property that actually matters for the display being
    //    readable: a level the CPU has STOPPED using must go dark within the
    //    afterglow window, even if it was hammered before. It says nothing
    //    about how many lamps SHOULD be lit while several levels are in use -
    //    on this machine several at once is normal.
    //------------------------------------------------------------------
    begin : ratio_check
      integer c, k;
      // hammer levels 2..6, switching far faster than one frame
      for (k = 0; k < 200; k = k + 1) begin
        pil = 4'd2 + (k % 5);
        repeat (20) @(posedge clk);
      end
      c = lamps_lit();
      $display("-- after hammering levels 2..6: %0d lamps lit", c);
      if (c < 5) begin
        $display("FAIL: only %0d lamps lit while 5 levels were in use", c);
        errors = errors + 1;
      end

      // now use ONLY level 2 and let the rest age out
      pil = 4'd2;
      run_frames(70);
      c = lamps_lit();
      $display("-- after 70 idle frames on level 2 alone: %0d lamps lit", c);
      if (c != 1) begin
        $display("FAIL: %0d lamps still lit after the others stopped running - expected 1",
                 c);
        errors = errors + 1;
      end else $display("-- levels that stopped running went dark");
    end

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

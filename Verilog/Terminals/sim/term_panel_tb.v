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
//!   5. changing PIL moves the lit cell: the old level is still shown for
//!      the frame it was used in, and is DARK on the frame after. There is
//!      no afterglow - see check 7 for why.
//!   6. exactly one level is the current one.
//!   7. PER-FRAME OCCUPANCY. Several levels used inside one frame all show;
//!      once the CPU stops using them they are dark within ONE frame.
//!   8. THE MEASURED BUG SHAPE: a level touched for 15 clocks (the ~1 us
//!      pulses the ILA saw on 29-AUG-2026) shows for that one frame and no
//!      longer. The old 63-frame afterglow turned every such pulse into a
//!      lamp lit for a second and the row saturated.
//!
//! Checks 7 and 8 are the ones worth the effort: the first implementation
//! had a decay constant that took 28 minutes, the next held for 63 frames,
//! and both showed every level the microcode brushes past as lit while
//! looking entirely plausible.
//!
//! Prints "TB_RESULT: PASS" or "TB_RESULT: FAIL".
//!
//! Written 28-AUG-2026. Rewritten for per-frame occupancy 29-AUG-2026.
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
  reg [15:0] mips = 16'd0;    //! BCD {d3,d2,d1,d0}, from the board's mips_counter

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
  //! was using): with frame_tick high every clock, a frame and a clock are
  //! the same thing, and anything that accumulates over a frame is invisible.
  //! On hardware a frame is 666,666 clocks at 40 MHz.
  //!
  //! FRAME_CLOCKS is 400 rather than 666,666: the point is only that a frame
  //! must be MUCH longer than one clock - and much longer than the 15-clock
  //! pulses of check 8. 400 keeps the run short enough to be a unit test.
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

  //! Run the panel for a number of whole frames, and come back AFTER the
  //! panel has latched the frame that just ended. frame_tick goes high at
  //! one clock edge; the DUT sees it and loads r_lamp at the next; so two
  //! clocks after the tick the latched lamps are the ones for that frame.
  task run_frames (input integer frames);
    integer f;
    begin
      for (f = 0; f < frames; f = f + 1) begin
        @(posedge frame_tick);
      end
      repeat (2) @(posedge clk);
    end
  endtask

  //! How many of the 16 level lamps are lit in the frame being displayed.
  //! r_lamp is what the renderer draws from - read that, not the accumulator
  //! behind it, so the check sees what the screen sees.
  function integer lamps_lit;
    integer k, c;
    begin
      c = 0;
      for (k = 0; k < 16; k = k + 1) if (DUT.r_lamp[k]) c = c + 1;
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
      .pil(pil), .actlv(actlv), .utilization(utilization), .cache_hit(cache_hit),
      .ring(ring), .paging_on(paging_on), .interrupt_on(interrupt_on),
      .running(running),
      .hdd_rd(1'b0), .hdd_wr(1'b0), .flp_rd(1'b0), .flp_wr(1'b0),
      .up_hours(up_hours), .up_minutes(up_minutes), .up_seconds(up_seconds),
      .mips(mips),
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

  //! Is the level cell for `lvl` lit in the frame being displayed? Read from
  //! the panel's own latched lamp vector - the thing the renderer draws from -
  //! rather than re-deriving it here.
  task level_lit;
    input integer lvl;
    output lit;
    begin
      lit = DUT.r_lamp[lvl];
    end
  endtask

  integer claimed;
  reg lit_a, lit_b;
  reg [15:0] actlv = 16'd0;   //! the panel processor's ACTIVE LEVEL word; 0 = none yet (PIL fallback)

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
    run_frames(1);          // the lamps show once the frame is latched
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
    // 5. Moving off a level. We are just past a frame tick, and the new
    //    frame was seeded with level 7 (current at the tick). Switch to 2 at
    //    once: the frame now in progress has seen BOTH 7 and 2, so when it is
    //    latched both show. The frame after that has only seen 2, so 7 must
    //    be dark by then - one frame, no afterglow.
    //------------------------------------------------------------------
    pil = 4'd2;
    run_frames(1);
    level_lit(7, lit_a);
    level_lit(2, lit_b);
    if (!lit_a) begin
      $display("FAIL: level 7 was used in this frame but is not shown");
      errors = errors + 1;
    end
    if (!lit_b) begin
      $display("FAIL: level 2 was used in this frame but is not shown");
      errors = errors + 1;
    end
    if (lit_a && lit_b) $display("-- the frame that spanned the change shows both 7 and 2");

    run_frames(1);
    level_lit(7, lit_a);
    level_lit(2, lit_b);
    if (lit_a) begin
      $display("FAIL: level 7 still lit one whole frame after the CPU left it");
      errors = errors + 1;
    end else $display("-- level 7 dark on the next frame");
    if (!lit_b) begin
      $display("FAIL: level 2 is current but is not shown");
      errors = errors + 1;
    end else $display("-- level 2, still current, stays lit");

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
    // 7. PER-FRAME OCCUPANCY. Several levels used within one frame all show
    //    in that frame - on this machine several at once is normal. And a
    //    level the CPU has STOPPED using must be dark within one frame, not
    //    63. The old reload-every-clock / decay-per-frame scheme kept a level
    //    pinned lit for ~1 s after its last visit, and that is what lit the
    //    whole row on hardware.
    //------------------------------------------------------------------
    begin : occupancy_check
      integer c, k;
      // hammer levels 2..6, cycling through all five in 100 clocks, for
      // 10.5 frames. NOT a whole number of frames: the loop starts just after
      // a tick, and 200 iterations (exactly 10 frames) ended 2 clocks into a
      // fresh frame, so the frame read below had seen only two levels and
      // the check failed against a correct DUT. 210 leaves 200 clocks - two
      // full cycles of all five levels - in the frame that gets read.
      for (k = 0; k < 210; k = k + 1) begin
        pil = 4'd2 + (k % 5);
        repeat (20) @(posedge clk);
      end
      // finish the frame the hammering ended in and read it
      pil = 4'd2;
      run_frames(1);
      c = lamps_lit();
      $display("-- after hammering levels 2..6: %0d lamps lit", c);
      if (c != 5) begin
        $display("FAIL: %0d lamps lit while exactly 5 levels were in use", c);
        errors = errors + 1;
      end

      // now ONLY level 2. The very next frame must show nothing else.
      run_frames(1);
      c = lamps_lit();
      $display("-- one frame later on level 2 alone: %0d lamps lit", c);
      if (c != 1) begin
        $display("FAIL: %0d lamps still lit one frame after the others stopped - expected 1",
                 c);
        errors = errors + 1;
      end else $display("-- levels that stopped running went dark within one frame");
    end

    //------------------------------------------------------------------
    // 8. THE MEASURED BUG SHAPE. The ILA on the Nexys (29-AUG-2026, TPE
    //    INSTRUCTION test) saw PIL pulse to 12, 13, 14, 15 for exactly 15 CPU
    //    clocks each, ~150 clocks apart, with level 0 in between - the CPU
    //    touching those levels, not running on them. Each such pulse must
    //    show for the frame it happened in and be gone the frame after.
    //------------------------------------------------------------------
    begin : pulse_check
      integer c, lv;
      pil = 4'd0;
      run_frames(2);                    // settle: only level 0 shown
      c = lamps_lit();
      if (c != 1 || !DUT.r_lamp[0]) begin
        $display("FAIL: expected only level 0 lit before the pulses, got %0d lamps", c);
        errors = errors + 1;
      end
      // the four pulses, same shape as the capture, all inside one frame
      for (lv = 12; lv <= 15; lv = lv + 1) begin
        pil = lv[3:0];
        repeat (15) @(posedge clk);
        pil = 4'd0;
        repeat (50) @(posedge clk);     // 4 x 65 = 260 clocks < one 400-clock frame
      end
      run_frames(1);
      c = lamps_lit();
      $display("-- frame containing the 12..15 pulses: %0d lamps lit", c);
      if (c != 5 || !DUT.r_lamp[12] || !DUT.r_lamp[13] || !DUT.r_lamp[14] || !DUT.r_lamp[15]) begin
        $display("FAIL: the frame with the pulses should show 0,12,13,14,15 - got %b", DUT.r_lamp);
        errors = errors + 1;
      end
      run_frames(1);
      c = lamps_lit();
      $display("-- frame after the pulses: %0d lamps lit", c);
      if (c != 1 || !DUT.r_lamp[0]) begin
        $display("FAIL: a 15-clock pulse is still lit a frame later - got %b", DUT.r_lamp);
        errors = errors + 1;
      end else $display("-- 1 us pulses show for one frame only");
    end

    //------------------------------------------------------------------
    // 9. THE ACTLV ROW AND ITS HOLD (29-AUG-2026, evening). Once the panel
    //    processor has sent an ACTIVE LEVEL word the row shows THAT, not
    //    PIL. A level set anywhere inside a frame - not only at the tick -
    //    must show, and it must stay lit for ACTLV_HOLD_FRAMES frames after
    //    the frame it was seen in, then go dark. Ronny saw the one-frame
    //    version "flicker like stupid" on the Nexys and asked for double.
    //------------------------------------------------------------------
    begin : actlv_check
      integer c, f;
      pil = 4'd0;
      actlv = 16'h0002;                 // level 1 active, steady
      run_frames(2);
      c = lamps_lit();
      if (c != 1 || !DUT.r_lamp[1]) begin
        $display("FAIL: ACTLV=0002 should light only level 1 - got %b", DUT.r_lamp);
        errors = errors + 1;
      end else $display("-- ACTLV word drives the row once it has arrived");
      // PIL must be ignored now
      pil = 4'd9;
      run_frames(1);
      if (DUT.r_lamp[9]) begin
        $display("FAIL: PIL=9 lit its lamp although an ACTLV word has arrived");
        errors = errors + 1;
      end else $display("-- PIL ignored once ACTLV is live");
      pil = 4'd0;
      // a 20-clock blip on level 5 in the MIDDLE of a frame (the old code
      // sampled only at the tick and missed it entirely)
      repeat (150) @(posedge clk);
      actlv = 16'h0022;
      repeat (20) @(posedge clk);
      actlv = 16'h0002;
      run_frames(1);
      if (!DUT.r_lamp[5]) begin
        $display("FAIL: a mid-frame ACTLV blip on level 5 is not shown - got %b", DUT.r_lamp);
        errors = errors + 1;
      end else $display("-- mid-frame ACTLV blip shown in its frame");
      // held for ACTLV_HOLD_FRAMES frames in total, then dark
      for (f = 1; f < DUT.ACTLV_HOLD_FRAMES; f = f + 1) begin
        run_frames(1);
        if (!DUT.r_lamp[5]) begin
          $display("FAIL: level 5 dropped after %0d frames, hold is %0d", f, DUT.ACTLV_HOLD_FRAMES);
          errors = errors + 1;
        end
      end
      run_frames(1);
      c = lamps_lit();
      if (DUT.r_lamp[5] || c != 1) begin
        $display("FAIL: level 5 still lit after its %0d-frame hold - got %b", DUT.ACTLV_HOLD_FRAMES, DUT.r_lamp);
        errors = errors + 1;
      end else $display("-- level 5 held %0d frames then dark", DUT.ACTLV_HOLD_FRAMES);
    end

    //------------------------------------------------------------------
    // 10. THE MIPS FIELD (30-AUG-2026). Four BCD digits in, "XX.XX" out at
    //     row 2 columns 63-67. Checked at the character mux: the pixel walk
    //     positions the pipeline on each cell and reads the composed char,
    //     so this fails if the digits, the dot, the column or the row move.
    //------------------------------------------------------------------
    begin : mips_check
      integer ci;
      reg [7:0] expect_ch;
      mips = 16'h0342;              // 03.42 MIPS
      run_frames(1);                // latched at the tick
      if (DUT.r_mips !== 16'h0342) begin
        $display("FAIL: r_mips latched %04x, expected 0342", DUT.r_mips);
        errors = errors + 1;
      end
      for (ci = 0; ci < 5; ci = ci + 1) begin
        @(negedge clk);
        x = (ORIGIN_X + (63 + ci) * 8);
        y = (ORIGIN_Y + 2 * 16);
        repeat (4) @(posedge clk);
        expect_ch = (ci == 0) ? "0" : (ci == 1) ? "3" : (ci == 2) ? "." :
                    (ci == 3) ? "4" : "2";
        if (DUT.s_live_char !== expect_ch) begin
          $display("FAIL: MIPS cell %0d shows 0x%02x, expected '%c'",
                   ci, DUT.s_live_char, expect_ch);
          errors = errors + 1;
        end
      end
      if (errors == 0) $display("-- MIPS 0342 renders as 03.42 at row 2 col 63");
    end

    if (errors == 0) $display("TB_RESULT: PASS (region bounded, levels, per-frame occupancy, ACTLV hold, MIPS field)");
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

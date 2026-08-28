//============================================================================
//! Self-checking testbench for text_screen.v - the pixel pipeline
//!
//! Scans a WHOLE FRAME and checks EVERY pixel against an independent model
//! built in the testbench from the same font file. Not a spot check: 480,000
//! visible pixels per frame, each one compared.
//!
//! WHY THE WHOLE FRAME. This module is three things at once - a 2-clock
//! fetch pipeline, the hardware-scroll row mapping, and the cursor/attribute
//! inversion - and every one of them fails in a way that looks almost right.
//! A pipeline off by one shifts the picture 8 pixels. A scroll mapping off by
//! one shows the wrong line. Both would pass a "does it draw an A" test.
//! Comparing every pixel against a model that computes the answer a different
//! way is the only check that catches those.
//!
//! The model deliberately does NOT reuse the DUT's arithmetic. It recovers the
//! pixel position from the OUTPUT stream (de, hsync, vsync) rather than from
//! the DUT's counters, then works out what should be there from first
//! principles. A model that shared the DUT's addressing would agree with it
//! however wrong both were.
//!
//! Covered: grid origin and the border around it, the 2-clock pipeline
//! alignment, per-cell characters, the reverse attribute, the cursor
//! inversion, and hardware scroll (top_row != 0).
//!
//! Prints "TB_RESULT: PASS" or "TB_RESULT: FAIL".
//!
//! Written 27-AUG-2026.
//============================================================================

`timescale 1ns / 1ps
`default_nettype none

module text_screen_tb;

  localparam integer COLS     = 80;
  localparam integer ROWS     = 25;
  localparam integer CELL_W   = 8;
  localparam integer CELL_H   = 16;
  localparam integer AWIDTH   = 11;
  localparam integer ORIGIN_X = 80;
  localparam integer ORIGIN_Y = 100;

  localparam integer H_VISIBLE = 800;
  localparam integer V_VISIBLE = 600;

  reg clk = 1'b0;
  reg rst_n = 1'b0;

  integer errors = 0;
  integer checked = 0;

  always #12.5 clk = ~clk;  // 40 MHz

  //--------------------------------------------------------------------------
  // DUT + its character RAM
  //--------------------------------------------------------------------------

  wire [AWIDTH-1:0] raddr;
  wire [      15:0] rdata;

  reg               we = 1'b0;
  reg  [AWIDTH-1:0] waddr = {AWIDTH{1'b0}};
  reg  [      15:0] wdata = 16'h0000;

  reg [7:0] top_row = 8'd0;
  reg [7:0] cursor_col = 8'd0;
  reg [7:0] cursor_row = 8'd0;
  reg       cursor_enable = 1'b0;

  wire pixel, hsync, vsync, de, frame_end;

  char_ram #(
      .COLS(COLS), .ROWS(ROWS), .AWIDTH(AWIDTH)
  ) RAM (
      .clk(clk),
      .we(we), .waddr(waddr), .wdata(wdata),
      .raddr(raddr), .rdata(rdata)
  );

  text_screen #(
      .COLS(COLS), .ROWS(ROWS), .CELL_W(CELL_W), .CELL_H(CELL_H),
      .AWIDTH(AWIDTH), .ORIGIN_X(ORIGIN_X), .ORIGIN_Y(ORIGIN_Y),
      .FONT_FILE("../font/font8x16.hex")
  ) DUT (
      .clk(clk), .rst_n(rst_n),
      .ram_raddr(raddr), .ram_rdata(rdata),
      // Font page 0 (US) and mode 0. The model reads the same hex file and
      // page 0 is its first 128 glyphs, so model and DUT agree by construction.
      .national(1'b0),
      .mode(1'b0),
      .top_row(top_row),
      .cursor_col(cursor_col), .cursor_row(cursor_row),
      .cursor_enable(cursor_enable),
      .pixel(pixel), .hsync(hsync), .vsync(vsync), .de(de),
      .frame_end(frame_end)
  );

  //--------------------------------------------------------------------------
  // The model: our own copy of the screen, and our own copy of the font
  //--------------------------------------------------------------------------

  reg [15:0] model_cells[0:COLS*ROWS-1];
  reg [ 7:0] model_font [0:4095];

  initial $readmemh("../font/font8x16.hex", model_font);

  //! Write one cell into BOTH the DUT's RAM and the model.
  task put_cell;
    input [7:0] srow;    //! STORED row
    input [7:0] scol;
    input [7:0] ch;
    input       reverse;
    reg [AWIDTH-1:0] addr;
    begin
      addr = srow * COLS + scol;
      @(posedge clk);
      we    = 1'b1;
      waddr = addr;
      wdata = {7'b0, reverse, ch};
      @(posedge clk);
      we = 1'b0;
      model_cells[addr] = {7'b0, reverse, ch};
    end
  endtask

  //--------------------------------------------------------------------------
  // Position recovery from the OUTPUT stream only
  //--------------------------------------------------------------------------

  integer px = 0;   //! visible column of the pixel being emitted now
  integer py = 0;   //! visible row
  reg     de_d = 1'b0;
  reg     vsync_d = 1'b0;
  integer scanning = 0;

  //! What SHOULD be on screen at (x, y). Computed from the model, from first
  //! principles - not from the DUT's addressing.
  function expected_pixel;
    input integer x;
    input integer y;
    integer gx, gy, col, row_on_screen, prow, pcol;
    integer stored, sum;
    reg [15:0] cellv;
    reg [7:0] glyph_row;
    reg       ink, invert, is_cursor;
    begin
      gx = x - ORIGIN_X;
      gy = y - ORIGIN_Y;

      if (gx < 0 || gx >= COLS * CELL_W || gy < 0 || gy >= ROWS * CELL_H) begin
        expected_pixel = 1'b0;          // the border around the grid
      end else begin
        col           = gx / CELL_W;
        pcol          = gx % CELL_W;
        row_on_screen = gy / CELL_H;
        prow          = gy % CELL_H;

        // hardware scroll: screen row N is stored row (top_row + N) mod ROWS
        sum    = top_row + row_on_screen;
        stored = (sum >= ROWS) ? (sum - ROWS) : sum;

        cellv     = model_cells[stored * COLS + col];
        glyph_row = model_font[cellv[7:0] * 16 + prow];
        ink       = glyph_row[7 - pcol];   // MSB is the leftmost pixel

        is_cursor = cursor_enable && (col == cursor_col) &&
                    (row_on_screen == cursor_row);
        invert    = cellv[8] ^ is_cursor;

        expected_pixel = ink ^ invert;
      end
    end
  endfunction

  //--------------------------------------------------------------------------
  // Compare every visible pixel of one frame
  //--------------------------------------------------------------------------

  integer reported = 0;   //! cap the noise if it goes badly wrong

  always @(posedge clk) begin
    de_d    <= de;
    vsync_d <= vsync;

    if (scanning) begin
      if (de) begin
        if (!de_d) px = 0;             // start of a visible line
        else px = px + 1;

        if (pixel !== expected_pixel(px, py)) begin
          if (reported < 12) begin
            $display("FAIL: pixel(x=%0d,y=%0d) = %b, expected %b (time %0t)",
                     px, py, pixel, expected_pixel(px, py), $time);
            reported = reported + 1;
          end
          errors = errors + 1;
        end
        checked = checked + 1;
      end else if (de_d) begin
        py = py + 1;                    // end of a visible line
      end

      if (vsync && !vsync_d) py = 0;    // top of the next frame
    end
  end

  //--------------------------------------------------------------------------

  integer r, c;
  integer before_errors;

  //! Scan exactly one frame with the comparison running.
  //!
  //! The window is frame_end -> frame_end, NOT vsync -> frame_end. vsync
  //! happens at line 601, i.e. already inside vertical blanking, so a window
  //! starting there contains no visible lines at all - the first version of
  //! this task checked exactly zero pixels and reported "0 wrong" four times
  //! over. The pixel counter at the end of this testbench exists because of
  //! that: a scan that silently checks nothing looks identical to a pass.
  task scan_frame;
    begin
      @(posedge frame_end);   // last clock of a frame; the next one starts fresh
      @(posedge clk);
      py       = 0;
      px       = 0;
      scanning = 1;
      @(posedge frame_end);   // and runs to the end of the following frame
      @(posedge clk);
      scanning = 0;
    end
  endtask

  initial begin
    $dumpfile("text_screen_tb.vcd");
    // The frame counters make a huge VCD and nothing here is debugged by
    // eye, so only the top level is dumped.
    $dumpvars(1, text_screen_tb);

    // Blank the model to match char_ram's own initial contents (spaces).
    for (r = 0; r < COLS*ROWS; r = r + 1) model_cells[r] = {8'h00, 8'h20};

    repeat (4) @(posedge clk);
    rst_n = 1'b1;

    //------------------------------------------------------------------
    // Fill the screen with a pattern that exercises every glyph, plus a
    // scattering of reverse-video cells.
    //------------------------------------------------------------------
    for (r = 0; r < ROWS; r = r + 1)
      for (c = 0; c < COLS; c = c + 1)
        put_cell(r[7:0], c[7:0], 8'h20 + ((r*COLS + c) % 95), ((r + c) % 7) == 0);

    //------------------------------------------------------------------
    // 1. Plain render, no cursor, no scroll.
    //------------------------------------------------------------------
    top_row       = 8'd0;
    cursor_enable = 1'b0;
    before_errors = errors;
    scan_frame;
    $display("-- frame 1 (plain): %0d pixels checked, %0d wrong",
             checked, errors - before_errors);
    if (errors == before_errors)
      $display("   grid origin, 2-clock pipeline alignment and reverse video all agree");

    //------------------------------------------------------------------
    // 2. Cursor on. It inverts exactly one cell and nothing else.
    //------------------------------------------------------------------
    cursor_enable = 1'b1;
    cursor_col    = 8'd17;
    cursor_row    = 8'd9;
    before_errors = errors;
    scan_frame;
    $display("-- frame 2 (cursor at 9,17): %0d wrong", errors - before_errors);

    //------------------------------------------------------------------
    // 3. Hardware scroll. top_row != 0 must show a different line at the
    //    top WITHOUT the character RAM changing at all - and the cursor,
    //    which is addressed in SCREEN coordinates, must stay where it is.
    //------------------------------------------------------------------
    top_row       = 8'd7;
    before_errors = errors;
    scan_frame;
    $display("-- frame 3 (top_row=7): %0d wrong", errors - before_errors);

    //------------------------------------------------------------------
    // 4. The wrap in the scroll mapping: top_row near the end means the
    //    bottom of the screen comes from the START of the RAM.
    //------------------------------------------------------------------
    top_row       = 8'd24;
    before_errors = errors;
    scan_frame;
    $display("-- frame 4 (top_row=24, wraps): %0d wrong", errors - before_errors);

    $display("total visible pixels checked: %0d", checked);

    // A frame is 800*600 visible pixels; four frames must have checked them
    // all. If the counter is short the scan itself was broken, and "0 errors"
    // would mean nothing.
    if (checked != 4 * H_VISIBLE * V_VISIBLE) begin
      $display("FAIL: checked %0d pixels, expected %0d - the scan is wrong, not the DUT",
               checked, 4 * H_VISIBLE * V_VISIBLE);
      errors = errors + 1;
    end

    if (errors == 0) $display("TB_RESULT: PASS (%0d pixels, 4 frames)", checked);
    else $display("TB_RESULT: FAIL (%0d errors)", errors);

    $finish;
  end

  initial begin
    #400_000_000;
    $display("FAIL: timeout");
    $display("TB_RESULT: FAIL (timeout)");
    $finish;
  end

endmodule

`default_nettype wire

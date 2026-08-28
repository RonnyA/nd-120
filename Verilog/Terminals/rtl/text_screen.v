//============================================================================
//! Text screen - turns the character RAM into pixels
//!
//! Part of the board-independent terminal core (Verilog/Terminals/).
//!
//! Owns the VGA timing generator, the character RAM read port and the font
//! ROM, and produces one monochrome pixel per pixel clock plus the sync and
//! blanking signals. Colour is applied by the board (12-bit on the Nexys, the
//! framework video mixer on MiSTer) - this module says "ink or paper", which
//! is all a terminal needs and keeps it portable.
//!
//! THE PIPELINE (the part that is easy to get wrong):
//!
//!   t+0  address the character RAM with the cell containing pixel X
//!   t+1  character code is out; address the font ROM with it + the pixel row
//!   t+2  the font's 8-pixel row is out; select bit X[2:0] and emit it
//!
//! So the pixel emitted at time t belongs to the pixel position the counters
//! held at t-2. Everything that must line up with it - de, hsync, vsync and
//! the low 3 bits of x - is delayed by the same two clocks. Delaying sync
//! along with the data (rather than compensating the address) keeps the whole
//! frame internally consistent; it shifts the image 2 pixels, which no monitor
//! and no human can see.
//!
//! Hardware scrolling: the visible top line is `top_row`, not row 0. Scrolling
//! is then one register increment instead of moving 1920 words, and the screen
//! is a ring. terminal_ctrl owns that register and clears the newly exposed
//! line.
//!
//! Written 27-AUG-2026.
//============================================================================

`default_nettype none

module text_screen #(
    parameter integer COLS        = 80,
    parameter integer ROWS        = 25,
    parameter integer CELL_W      = 8,
    parameter integer CELL_H      = 16,
    parameter integer AWIDTH      = 11,
    //! Where the character grid sits inside the visible area. 80x25 of 8x16 is
    //! 640x400; centred in 800x600 that is (800-640)/2 = 80, (600-400)/2 = 100.
    parameter integer ORIGIN_X    = 80,
    parameter integer ORIGIN_Y    = 100,
    parameter         FONT_FILE   = "../font/font8x16.hex",

    // VGA mode - defaults are 800x600@60 from a 40.000 MHz pixel clock
    parameter integer H_VISIBLE     = 800,
    parameter integer H_FRONT_PORCH = 40,
    parameter integer H_SYNC        = 128,
    parameter integer H_BACK_PORCH  = 88,
    parameter integer V_VISIBLE     = 600,
    parameter integer V_FRONT_PORCH = 1,
    parameter integer V_SYNC        = 4,
    parameter integer V_BACK_PORCH  = 23,

    // Mode 1: 1920x1080@60 (148.5 MHz), glyphs doubled to 16x32
    parameter integer H2_VISIBLE     = 1920,
    parameter integer H2_FRONT_PORCH = 88,
    parameter integer H2_SYNC        = 44,
    parameter integer H2_BACK_PORCH  = 148,
    parameter integer V2_VISIBLE     = 1080,
    parameter integer V2_FRONT_PORCH = 4,
    parameter integer V2_SYNC        = 5,
    parameter integer V2_BACK_PORCH  = 36
) (
    input wire clk,    //! pixel clock
    input wire rst_n,  //! async reset, active low

    // Character RAM read port
    output wire [AWIDTH-1:0] ram_raddr,
    input  wire [      15:0] ram_rdata,

    // Screen state, driven by terminal_ctrl
    //! Font page. 0 = US / ISO 646 IRV, 1 = Norwegian (NS 4551-1). It changes
    //! what six existing byte values LOOK like - it does not add characters.
    input wire       national,

    //! Video mode. 0 = the H_*/V_* parameters at 1x glyphs; 1 = the H2_*/V2_*
    //! parameters at 2x glyphs. MUST be switched together with the pixel clock.
    //!
    //! WHY THE GLYPHS SCALE WITH IT. The grid is a FIXED 80x25 cells, so at 1x
    //! it is always 640x400 pixels no matter how big the screen is. Raising the
    //! resolution alone therefore makes the text SMALLER - a 640x400 island in
    //! a 1920x1080 field. Doubling the glyphs turns that into 1280x800, which
    //! is a sensible size on a 1080p panel. It costs nothing: the same font ROM
    //! is read, each pixel and each row simply lasts twice as long.
    input wire       mode,

    input wire [7:0] top_row,       //! which stored row is displayed at the top
    input wire [7:0] cursor_col,
    input wire [7:0] cursor_row,    //! cursor position in SCREEN coordinates
    input wire       cursor_enable, //! draw the cursor at all

    // Video out
    output wire pixel,      //! 1 = ink, 0 = paper
    output wire hsync,
    output wire vsync,
    output wire de,         //! display enable, already aligned with `pixel`
    output wire frame_end,  //! one pulse per frame, un-delayed (for blink)

    //! The raw pixel counters, un-delayed. Anything else drawing on this screen
    //! (the operator panel) works from these and applies the SAME two clocks of
    //! delay, which is how the two stay aligned without either knowing about
    //! the other.
    output wire [11:0] x_raw,
    output wire [11:0] y_raw
);

  wire [11:0] s_x;
  wire [11:0] s_y;

  assign x_raw = s_x;
  assign y_raw = s_y;
  wire        s_hsync_raw;
  wire        s_vsync_raw;
  wire        s_de_raw;

  vga_timing #(
      .H_VISIBLE    (H_VISIBLE),
      .H_FRONT_PORCH(H_FRONT_PORCH),
      .H_SYNC       (H_SYNC),
      .H_BACK_PORCH (H_BACK_PORCH),
      .V_VISIBLE    (V_VISIBLE),
      .V_FRONT_PORCH(V_FRONT_PORCH),
      .V_SYNC       (V_SYNC),
      .V_BACK_PORCH (V_BACK_PORCH),
      .H2_VISIBLE    (H2_VISIBLE),
      .H2_FRONT_PORCH(H2_FRONT_PORCH),
      .H2_SYNC       (H2_SYNC),
      .H2_BACK_PORCH (H2_BACK_PORCH),
      .V2_VISIBLE    (V2_VISIBLE),
      .V2_FRONT_PORCH(V2_FRONT_PORCH),
      .V2_SYNC       (V2_SYNC),
      .V2_BACK_PORCH (V2_BACK_PORCH)
  ) TIMING (
      .clk      (clk),
      .rst_n    (rst_n),
      .mode     (mode),
      .x        (s_x),
      .y        (s_y),
      .hsync    (s_hsync_raw),
      .vsync    (s_vsync_raw),
      .de       (s_de_raw),
      .hblank   (),
      .vblank   (),
      .line_end (),
      .frame_end(frame_end)
  );

  //--------------------------------------------------------------------------
  // Stage 0 - which cell does pixel (s_x, s_y) belong to
  //--------------------------------------------------------------------------

  // Position inside the character grid. Signed compare against the origin, so
  // the border around the grid is simply "outside".
  //! Centre the grid for whichever mode is running. Computed, never written
  //! down - the same lesson as the 108-vs-100 bug that shipped in terminal_top:
  //! a hand-maintained origin goes stale the moment anything around it changes.
  localparam integer ORIGIN2_X = (H2_VISIBLE - COLS * CELL_W * 2) / 2;
  localparam integer ORIGIN2_Y = (V2_VISIBLE - ROWS * CELL_H * 2) / 2;

  wire [11:0] s_origin_x = mode ? ORIGIN2_X[11:0] : ORIGIN_X[11:0];
  wire [11:0] s_origin_y = mode ? ORIGIN2_Y[11:0] : ORIGIN_Y[11:0];

  wire signed [12:0] s_grid_x = $signed({1'b0, s_x}) - $signed({1'b0, s_origin_x});
  wire signed [12:0] s_grid_y = $signed({1'b0, s_y}) - $signed({1'b0, s_origin_y});

  wire s_in_grid = (s_grid_x >= 0) && (s_grid_x < (mode ? COLS*CELL_W*2 : COLS*CELL_W)) &&
                   (s_grid_y >= 0) && (s_grid_y < (mode ? ROWS*CELL_H*2 : ROWS*CELL_H));

  wire [11:0] s_gx = s_grid_x[11:0];
  wire [11:0] s_gy = s_grid_y[11:0];

  //! At 2x, every cell is 16x32 instead of 8x16, so the divide moves up one bit
  //! and the font is indexed with the position SHIFTED RIGHT - which is the
  //! whole of pixel doubling: each font pixel is read twice in a row, and each
  //! font row is read on two consecutive scan lines.
  wire [7:0] s_col        = mode ? s_gx[11:4] : s_gx[11:3];
  wire [7:0] s_screen_row = mode ? s_gy[11:5] : s_gy[11:4];
  wire [3:0] s_pixel_row  = mode ? s_gy[4:1]  : s_gy[3:0];
  wire [2:0] s_pixel_col  = mode ? s_gx[3:1]  : s_gx[2:0];

  // Hardware scroll: screen row N is stored row (top_row + N) mod ROWS.
  wire [8:0] s_sum_row    = {1'b0, top_row} + {1'b0, s_screen_row};
  wire [7:0] s_stored_row = (s_sum_row >= ROWS) ? (s_sum_row[7:0] - ROWS[7:0])
                                                : s_sum_row[7:0];

  // address = stored_row * COLS + col. COLS is 80 = 64 + 16, so the multiply is
  // two shifts and an add - no DSP, no multiplier inferred.
  assign ram_raddr = ({s_stored_row, 6'b0} + {s_stored_row, 4'b0} + s_col);

  //--------------------------------------------------------------------------
  // Stage 1 - character code out of the RAM, into the font ROM
  //--------------------------------------------------------------------------

  reg [3:0] s_pixel_row_d1;
  always @(posedge clk) s_pixel_row_d1 <= s_pixel_row;

  wire [7:0] s_font_pixels;

  //! WHICH FONT PAGE. The ROM holds two 128-glyph pages: page 0 is US / ISO
  //! 646 IRV, page 1 is the Norwegian variant, where six bytes draw AE OE AA
  //! ae oe aa and the currency sign instead of [ \ ] { | } and $. See the long
  //! note in font/make_font.py for why a national variant has to work this way
  //! on a 7-bit machine.
  //!
  //! Bit 7 of the stored character is REPLACED, not ORed: the ND-120 is 7-bit,
  //! so bit 7 carries no information, and replacing it means a stray high byte
  //! cannot land on the wrong page.
  font_rom #(
      .FONT_FILE(FONT_FILE)
  ) FONT (
      .clk      (clk),
      .char_code({national, ram_rdata[6:0]}),
      .row      (s_pixel_row_d1),
      .pixels   (s_font_pixels)
  );

  //--------------------------------------------------------------------------
  // Delay lines - everything that must meet the pixel two clocks downstream
  //--------------------------------------------------------------------------

  reg [1:0] s_de_dly, s_hsync_dly, s_vsync_dly, s_in_grid_dly;
  reg [2:0] s_pixel_col_d1, s_pixel_col_d2;
  //! Per-cell reverse-video attribute. It arrives WITH the character code, one
  //! stage later than everything else, so it needs one register to reach the
  //! output while the rest need two.
  reg s_reverse_d2;
  reg [1:0] s_cursor_dly;    //! this cell is the cursor cell

  // Is the cell being fetched at stage 0 the cursor cell? Compared in SCREEN
  // coordinates, so the cursor stays put when the screen scrolls under it.
  wire s_is_cursor_cell = cursor_enable && s_in_grid &&
                          (s_col == cursor_col) && (s_screen_row == cursor_row);

  always @(posedge clk) begin
    s_de_dly       <= {s_de_dly[0], s_de_raw};
    s_hsync_dly    <= {s_hsync_dly[0], s_hsync_raw};
    s_vsync_dly    <= {s_vsync_dly[0], s_vsync_raw};
    s_in_grid_dly  <= {s_in_grid_dly[0], s_in_grid};
    s_cursor_dly   <= {s_cursor_dly[0], s_is_cursor_cell};
    s_pixel_col_d1 <= s_pixel_col;
    s_pixel_col_d2 <= s_pixel_col_d1;
    s_reverse_d2   <= ram_rdata[8];
  end

  //--------------------------------------------------------------------------
  // Stage 2 - pick the pixel out of the font row
  //--------------------------------------------------------------------------

  // MSB is the leftmost pixel, so column 0 selects bit 7.
  wire s_glyph_pixel = s_font_pixels[3'd7 - s_pixel_col_d2];

  // Reverse video and the cursor are both "swap ink and paper". Doing the
  // cursor this way means it works on top of any character, needs no separate
  // shape, and costs one XOR.
  wire s_invert = s_reverse_d2 ^ s_cursor_dly[1];

  assign pixel = s_in_grid_dly[1] ? (s_glyph_pixel ^ s_invert) : 1'b0;
  assign de    = s_de_dly[1];
  assign hsync = s_hsync_dly[1];
  assign vsync = s_vsync_dly[1];

endmodule

`default_nettype wire

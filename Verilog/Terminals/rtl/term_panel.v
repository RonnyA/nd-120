//============================================================================
//! ND-120 operator panel, drawn below the console text.
//!
//! Part of the board-independent terminal core (Verilog/Terminals/).
//!
//! Recreates the machine's own folio panel in the empty screen area under the
//! 80x25 grid. Geometry and legends come from the photographed hardware
//! (Pictures/ronny/20230618_193546.jpg, active-levels.png), and the FIELDS come
//! from the original schematic: the ND-120's panel processor - an MC68705U3 at
//! board position 35C, sheet 40 of 50 dated 5-OCT-1987, transcribed in this
//! repo as IO_PANCAL_40.v - samples exactly these signals on its Port D:
//!
//!   PD0/PD1  PCR0/PCR1   -> PROTECT RING
//!   PD2      PONI        -> PAGING     ON/OFF
//!   PD3      IONI        -> INTERRUPT  ON/OFF
//!   PD4      LHIT        -> CACHE HIT RATE
//!   PD5      LEV0        -> UTILIZATION   (idle == running at level 0)
//!
//! So the panel is a VIEW of signals the machine already computes. Nothing here
//! is invented, and where a field has no honest source it is not drawn.
//!
//! TWO DELIBERATE DEPARTURES FROM THE REAL PANEL, both because the alternative
//! would be a display that looks right and is wrong:
//!
//!   CURRENT LEVEL, not ACTIVE LEVEL. The real display lights every level that
//!   is active at once, fed from the microprogram in PANC packets, with
//!   afterglow so a single instruction on a level stays visible. We have PIL -
//!   the one level running now. The picture would be identical and the claim
//!   would not, so the caption is changed. The afterglow is kept, because that
//!   part we can do honestly and it is what makes the display readable.
//!
//!   UP:hh:mm:ss, not DAY/TIME. The real clock is a battery-backed MM58274 that
//!   survives a power failure. There is no panel processor in our RTL and no
//!   calendar; this counts from reset and is labelled as uptime.
//!
//! It has its OWN font ROM rather than sharing the console's. That costs about
//! two block RAMs and buys the absence of an arbiter between two renderers on a
//! 2-clock pipeline - a trade worth making on a part with 100+ of them.
//!
//! Written 28-AUG-2026.
//============================================================================

`default_nettype none

module term_panel #(
    parameter FONT_FILE = "../font/font8x16.hex",

    //! Where the panel sits, in LOGICAL pixels (before the mode's 2x scaling).
    //! 80 columns of 8 pixels is 640 wide - the same width as the console grid,
    //! which is why it lines up underneath it with no arithmetic.
    parameter integer ORIGIN_X = 80,
    parameter integer ORIGIN_Y = 420
) (
    input wire clk,
    input wire rst_n,

    //! Raw pixel counters from the timing generator, and the mode. This module
    //! delays its own output by the SAME two clocks as the text pipeline, so
    //! the two stay aligned without either knowing about the other.
    input wire [11:0] x,
    input wire [11:0] y,
    input wire        mode,     //! 0 = 1x glyphs, 1 = 2x
    input wire        enable,   //! 0 = draw nothing at all

    // ---- what the machine is doing -------------------------------------
    input wire [3:0] pil,          //! current program level, 0..15
    input wire [3:0] utilization,  //! 0..8, eighths of a bargraph
    input wire [3:0] cache_hit,    //! 0..8, eighths of a bargraph
    input wire [1:0] ring,         //! PCR protect ring, 0..3
    input wire       paging_on,    //! PONI
    input wire       interrupt_on, //! IONI
    input wire       running,      //! CPU running (already de-inverted)
    input wire [4:0] up_hours,
    input wire [5:0] up_minutes,
    input wire [5:0] up_seconds,

    output wire       active,  //! this pixel belongs to the panel
    output wire [2:0] colour   //! palette index, see the localparams below
);

  // Palette indices. The BOARD maps these to its own colour depth - 12-bit on
  // the Nexys ladder, 24-bit on MiSTer - so nothing board-specific lives here.
  localparam [2:0] C_BLACK   = 3'd0;
  localparam [2:0] C_TEXT    = 3'd1;   //! console text ink
  localparam [2:0] C_FASCIA  = 3'd2;   //! the panel's near-black body
  localparam [2:0] C_SILK    = 3'd3;   //! silkscreen label white
  localparam [2:0] C_LCD     = 3'd4;   //! LCD ground, green-grey
  localparam [2:0] C_LCDINK  = 3'd5;   //! LCD segment, dark olive
  localparam [2:0] C_LIT     = 3'd6;   //! lit legend, red
  localparam [2:0] C_DARK    = 3'd7;   //! unlit legend

  // Block glyphs synthesised into the font's control-code slots by
  // font/make_font.py - see the note there.
  localparam [7:0] G_BAR0    = 8'h01;  //! +0..8 for eighths filled
  localparam [7:0] G_LEVEL_ON  = 8'h0A;
  localparam [7:0] G_LEVEL_OFF = 8'h0B;

  localparam integer PANEL_COLS = 80;
  localparam integer PANEL_ROWS = 5;

  //--------------------------------------------------------------------------
  // Which panel cell is this pixel in
  //--------------------------------------------------------------------------

  //! Logical position inside the panel. At 2x every logical pixel lasts two
  //! real ones, exactly as in text_screen - one shift, no other difference.
  wire [11:0] s_lx = mode ? {1'b0, x[11:1]} : x;
  wire [11:0] s_ly = mode ? {1'b0, y[11:1]} : y;

  wire signed [12:0] s_px = $signed({1'b0, s_lx}) - ORIGIN_X;
  wire signed [12:0] s_py = $signed({1'b0, s_ly}) - ORIGIN_Y;

  wire s_in_panel = enable &&
                    (s_px >= 0) && (s_px < PANEL_COLS * 8) &&
                    (s_py >= 0) && (s_py < PANEL_ROWS * 16);

  wire [11:0] s_ux = s_px[11:0];
  wire [11:0] s_uy = s_py[11:0];

  wire [6:0] s_col      = s_ux[9:3];
  wire [2:0] s_row      = s_uy[6:4];
  wire [2:0] s_pixel_col = s_ux[2:0];
  wire [3:0] s_pixel_row = s_uy[3:0];

  //--------------------------------------------------------------------------
  // The static layer
  //--------------------------------------------------------------------------

  wire [7:0] s_rom_char;

  term_panel_rom ROM (
      .addr({2'b0, s_row} * PANEL_COLS[8:0] + {2'b0, s_col}),
      .data(s_rom_char)
  );

  //--------------------------------------------------------------------------
  // The live layer - what goes in the cells the ROM left as 0x00
  //--------------------------------------------------------------------------

  // Column origins come from the generated ROM's own localparams in spirit;
  // repeated here because Verilog cannot read a child's parameters. make_panel.py
  // prints them into the ROM so the two can be checked against each other.
  localparam integer COL_UTIL_BAR     = 1;
  localparam integer UTIL_BAR_W       = 11;
  localparam integer COL_HIT_BAR      = 14;
  localparam integer HIT_BAR_W        = 10;
  localparam integer COL_RING_VALUE   = 35;
  localparam integer COL_INT_VALUE    = 43;
  localparam integer COL_PAGE_VALUE   = 53;
  localparam integer COL_UPTIME_VALUE = 4;
  localparam integer COL_LEVELS       = 24;
  localparam integer COL_LEGEND       = 62;

  //! Which of the 16 level cells this column is in, and whether it is lit.
  wire [4:0] s_level_index = (s_col - COL_LEVELS[6:0]) >> 1;
  wire       s_in_levels   = (s_col >= COL_LEVELS[6:0]) &&
                             (s_col <  COL_LEVELS[6:0] + 7'd32);

  //! Afterglow. The real field has it so a single instruction on a level stays
  //! visible; without it a level the CPU touches for a few microseconds would
  //! never be seen on a 60 Hz screen. One counter per level, reloaded while the
  //! level is current and counting down after.
  //! 8 bits decaying on a ~2 ms tick is about half a second of afterglow at
  //! 40 MHz. The first version used a 16-bit counter on a 26 ms tick, which is
  //! a 28-MINUTE decay - every level would have appeared permanently lit, and
  //! the display would have looked plausible while telling you nothing.
  //!
  //! The rate follows the pixel clock, so at 148 MHz the glow is ~3.7x shorter.
  //! Left as is rather than parameterised: both are in the range that reads as
  //! afterglow, and a wrong parameter is worse than a known approximation.
  reg [7:0]  s_glow[0:15];
  reg [16:0] s_glow_tick;
  integer gi;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      s_glow_tick <= 17'd0;
      for (gi = 0; gi < 16; gi = gi + 1) s_glow[gi] <= 8'd0;
    end else begin
      s_glow_tick <= s_glow_tick + 17'd1;
      // Reload continuously: whichever level is current is fully lit.
      s_glow[pil] <= 8'hFF;
      // Decay everything else slowly.
      if (s_glow_tick == 17'd0) begin
        for (gi = 0; gi < 16; gi = gi + 1)
          if (s_glow[gi] != 8'd0 && gi[3:0] != pil) s_glow[gi] <= s_glow[gi] - 8'd1;
      end
    end
  end

  wire s_level_lit = (s_glow[s_level_index[3:0]] != 8'd0);

  //! Uptime digits. Two cells per field plus the colons, laid out hh:mm:ss.
  wire [3:0] s_up_col = s_col - COL_UPTIME_VALUE[6:0];
  reg  [7:0] s_uptime_char;
  always @(*) begin
    case (s_up_col)
      4'd0: s_uptime_char = 8'h30 + {4'b0, up_hours   / 5'd10};
      4'd1: s_uptime_char = 8'h30 + {4'b0, up_hours   % 5'd10};
      4'd2: s_uptime_char = ":";
      4'd3: s_uptime_char = 8'h30 + {4'b0, up_minutes / 6'd10};
      4'd4: s_uptime_char = 8'h30 + {4'b0, up_minutes % 6'd10};
      4'd5: s_uptime_char = ":";
      4'd6: s_uptime_char = 8'h30 + {4'b0, up_seconds / 6'd10};
      4'd7: s_uptime_char = 8'h30 + {4'b0, up_seconds % 6'd10};
      default: s_uptime_char = 8'h20;
    endcase
  end

  //! ON / OFF, three cells wide so "ON " and "OFF" both fit.
  function [7:0] onoff_char;
    input integer offset;
    input on;
    begin
      if (on) onoff_char = (offset == 0) ? "O" : (offset == 1) ? "N" : " ";
      else    onoff_char = (offset == 0) ? "O" : (offset == 1) ? "F" : "F";
    end
  endfunction

  //! The bargraphs. A cell shows a full block if it is entirely below the
  //! level, an empty one if entirely above - the same eighths the real LCD
  //! bargraph grows in.
  function [7:0] bar_char;
    input [3:0] value;     // 0..8 eighths of the whole bar
    input [3:0] bar_cell;  // which cell of the bar - NOT `cell`, which is a
                           // Verilog-2001 config keyword and a parse error
    input [3:0] width;
    reg [7:0] filled;
    begin
      filled = (value * width) / 4'd8;
      bar_char = (bar_cell < filled[3:0]) ? (G_BAR0 + 8'd8) : G_BAR0;
    end
  endfunction

  reg [7:0] s_live_char;
  reg [2:0] s_live_colour;

  always @(*) begin
    s_live_char   = 8'h20;
    s_live_colour = C_LCDINK;

    if (s_in_levels) begin
      s_live_char   = s_level_lit ? G_LEVEL_ON : G_LEVEL_OFF;
      s_live_colour = C_LCDINK;
    end else if (s_col >= COL_UTIL_BAR[6:0] &&
                 s_col <  COL_UTIL_BAR[6:0] + UTIL_BAR_W[6:0] && s_row == 3'd1) begin
      s_live_char   = bar_char(utilization, s_col - COL_UTIL_BAR[6:0], UTIL_BAR_W[3:0]);
      s_live_colour = C_LCDINK;
    end else if (s_col >= COL_HIT_BAR[6:0] &&
                 s_col <  COL_HIT_BAR[6:0] + HIT_BAR_W[6:0] && s_row == 3'd1) begin
      s_live_char   = bar_char(cache_hit, s_col - COL_HIT_BAR[6:0], HIT_BAR_W[3:0]);
      s_live_colour = C_LCDINK;
    end else if (s_col == COL_RING_VALUE[6:0] && s_row == 3'd1) begin
      s_live_char   = 8'h30 + {6'b0, ring};
      s_live_colour = C_LCDINK;
    end else if (s_col >= COL_INT_VALUE[6:0] && s_col < COL_INT_VALUE[6:0] + 7'd3
                 && s_row == 3'd1) begin
      s_live_char   = onoff_char(s_col - COL_INT_VALUE[6:0], interrupt_on);
      s_live_colour = C_LCDINK;
    end else if (s_col >= COL_PAGE_VALUE[6:0] && s_col < COL_PAGE_VALUE[6:0] + 7'd3
                 && s_row == 3'd1) begin
      s_live_char   = onoff_char(s_col - COL_PAGE_VALUE[6:0], paging_on);
      s_live_colour = C_LCDINK;
    end else if (s_row == 3'd2 && s_col >= COL_UPTIME_VALUE[6:0]
                 && s_col < COL_UPTIME_VALUE[6:0] + 7'd8) begin
      s_live_char   = s_uptime_char;
      s_live_colour = C_LCDINK;
    end else if (s_col >= COL_LEGEND[6:0] && s_col < COL_LEGEND[6:0] + 7'd7) begin
      // The two lit legend words, driven by the RUN line. On the real fascia
      // only the currently usable words are lit; here RUNNING and OPCOM are
      // mutually exclusive, which is what the machine actually reports.
      if (s_row == 3'd1) begin
        s_live_char   = running ? {8'h20} : 8'h20;
        s_live_colour = running ? C_LIT : C_DARK;
      end else begin
        s_live_char   = 8'h20;
        s_live_colour = C_DARK;
      end
    end
  end

  //--------------------------------------------------------------------------
  // Compose: static text where the ROM has some, live text where it does not
  //--------------------------------------------------------------------------

  wire s_is_dynamic = (s_rom_char == 8'h00);
  wire [7:0] s_char = s_is_dynamic ? s_live_char : s_rom_char;

  //! The LCD window - rows 1 and 2 across the fields, which is the lit area of
  //! the real display. Everything else is fascia.
  wire s_in_lcd = (s_row == 3'd1) || (s_row == 3'd2);

  //! The octal ruler's alternating triplets are REVERSED OUT on the real
  //! fascia: dark digits on a light block, at {14,13,12} {8,7,6} {2,1,0}.
  wire [4:0] s_ruler_level = 5'd15 - ((s_col - COL_LEVELS[6:0]) >> 1);
  wire s_ruler_reversed = (s_row == 3'd3) && s_in_levels &&
                          ((s_ruler_level >= 5'd12 && s_ruler_level <= 5'd14) ||
                           (s_ruler_level >= 5'd6  && s_ruler_level <= 5'd8)  ||
                           (s_ruler_level <= 5'd2));

  //! Declared here, ABOVE the font ROM that reads it, not further down beside
  //! the other delay registers. Verilator accepts a forward reference; Vivado
  //! does not, and that exact mistake - a signal used above its declaration -
  //! is what stopped the first Nexys console build dead on 28-AUG-2026.
  reg [3:0] s_pixel_row_d1;

  wire [7:0] s_font_pixels;

  font_rom #(
      .FONT_FILE(FONT_FILE)
  ) PANELFONT (
      .clk      (clk),
      .char_code({1'b0, s_char[6:0]}),
      .row      (s_pixel_row_d1),
      .pixels   (s_font_pixels)
  );

  //--------------------------------------------------------------------------
  // Two clocks of delay, matching the text pipeline exactly
  //--------------------------------------------------------------------------

  reg [2:0] s_pixel_col_d1, s_pixel_col_d2;
  reg [1:0] s_in_panel_dly;
  reg [1:0] s_in_lcd_dly, s_reversed_dly, s_silk_dly;
  reg [2:0] s_colour_d1, s_colour_d2;

  //! Which colour this cell's ink is. Silkscreen labels are white on fascia;
  //! everything inside the LCD window is dark olive on green-grey.
  wire [2:0] s_ink = s_in_lcd ? (s_is_dynamic ? s_live_colour : C_LCDINK)
                              : ((s_row == 3'd1 || s_row == 3'd2) ? C_LCDINK : C_SILK);

  always @(posedge clk) begin
    s_pixel_row_d1 <= s_pixel_row;
    s_pixel_col_d1 <= s_pixel_col;
    s_pixel_col_d2 <= s_pixel_col_d1;
    s_in_panel_dly <= {s_in_panel_dly[0], s_in_panel};
    s_in_lcd_dly   <= {s_in_lcd_dly[0], s_in_lcd};
    s_reversed_dly <= {s_reversed_dly[0], s_ruler_reversed};
    s_silk_dly     <= {s_silk_dly[0], s_in_lcd ? 1'b0 : 1'b1};
    s_colour_d1    <= s_ink;
    s_colour_d2    <= s_colour_d1;
  end

  wire s_glyph_bit = s_font_pixels[3'd7 - s_pixel_col_d2];
  //! A reversed-out ruler cell swaps ink and ground.
  wire s_ink_here  = s_glyph_bit ^ s_reversed_dly[1];

  assign active = s_in_panel_dly[1];
  assign colour = !s_in_panel_dly[1] ? C_BLACK
                : s_in_lcd_dly[1]    ? (s_ink_here ? C_LCDINK : C_LCD)
                : s_ink_here         ? s_colour_d2
                                     : C_FASCIA;

endmodule

`default_nettype wire

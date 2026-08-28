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
    parameter integer ORIGIN_Y = 420,

    //! Mode-1 origin, also in LOGICAL pixels - i.e. physical/2, because at 2x
    //! every logical pixel lasts two real ones. The text grid sits differently
    //! in the two modes, so the panel has to as well; sharing one origin is
    //! what pushed the panel off the bottom of a 1080p screen.
    parameter integer ORIGIN_X2 = 160,
    parameter integer ORIGIN_Y2 = 440
) (
    input wire clk,
    input wire rst_n,

    //! Raw pixel counters from the timing generator, and the mode.
    //!
    //! This module's pipeline is THREE clocks deep, one more than the text
    //! path, because it had to be split to close timing at 148.4 MHz. That
    //! difference is deliberate and harmless: the panel occupies its own screen
    //! region, so nothing has to line up with the text grid pixel for pixel and
    //! the whole panel simply lands one pixel further right.
    input wire [11:0] x,
    input wire [11:0] y,
    input wire        mode,     //! 0 = 1x glyphs, 1 = 2x
    input wire        enable,   //! 0 = draw nothing at all

    //! One pulse per frame. EVERYTHING displayed is latched on it - see the
    //! frame-snapshot note below.
    input wire        frame_tick,

    // ---- what the machine is doing -------------------------------------
    input wire [3:0] pil,          //! current program level, 0..15
    input wire [3:0] utilization,  //! 0..8, eighths of a bargraph
    input wire [3:0] cache_hit,    //! 0..8, eighths of a bargraph
    input wire [1:0] ring,         //! PCR protect ring, 0..3
    input wire       paging_on,    //! PONI
    input wire       interrupt_on, //! IONI
    input wire       running,      //! CPU running (already de-inverted)

    //! Disc activity, one bit per direction per device. These are ACCESS
    //! STROBES - high for a request, not for the duration of a transfer - so
    //! they are held below rather than displayed directly; a single sector
    //! request is far too brief to see on a 60 Hz screen.
    input wire       hdd_rd,
    input wire       hdd_wr,
    input wire       flp_rd,
    input wire       flp_wr,
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
  //! A lamp is two cells wide, so each half has its own glyph - the outer pixel
  //! of each is blank, giving 14 lit pixels with a 2 px gap to the next level.
  //! One glyph used twice either runs the lamps together (full width) or splits
  //! each one down the middle (narrow).
  localparam [7:0] G_LEVEL_ON_L  = 8'h0A;
  localparam [7:0] G_LEVEL_ON_R  = 8'h0E;
  localparam [7:0] G_LEVEL_OFF_L = 8'h0B;
  localparam [7:0] G_LEVEL_OFF_R = 8'h0F;

  localparam integer PANEL_COLS = 80;
  localparam integer PANEL_ROWS = 5;

  //--------------------------------------------------------------------------
  // Which panel cell is this pixel in
  //--------------------------------------------------------------------------

  //! Logical position inside the panel. At 2x every logical pixel lasts two
  //! real ones, exactly as in text_screen - one shift, no other difference.
  wire [11:0] s_lx = mode ? {1'b0, x[11:1]} : x;
  wire [11:0] s_ly = mode ? {1'b0, y[11:1]} : y;

  wire [11:0] s_org_x = mode ? ORIGIN_X2[11:0] : ORIGIN_X[11:0];
  wire [11:0] s_org_y = mode ? ORIGIN_Y2[11:0] : ORIGIN_Y[11:0];

  wire signed [12:0] s_px = $signed({1'b0, s_lx}) - $signed({1'b0, s_org_x});
  wire signed [12:0] s_py = $signed({1'b0, s_ly}) - $signed({1'b0, s_org_y});

  wire s_in_panel = enable &&
                    (s_px >= 0) && (s_px < PANEL_COLS * 8) &&
                    (s_py >= 0) && (s_py < PANEL_ROWS * 16);

  wire [11:0] s_ux = s_px[11:0];
  wire [11:0] s_uy = s_py[11:0];

  wire [6:0] c_col       = s_ux[9:3];
  wire [2:0] c_row       = s_uy[6:4];
  wire [2:0] c_pixel_col = s_ux[2:0];
  wire [3:0] c_pixel_row = s_uy[3:0];

  //--------------------------------------------------------------------------
  // PIPELINE STAGE 1 - registered cell position
  //
  // Everything above is arithmetic on the raw pixel counters: subtract the
  // origin, compare the bounds, slice out row and column. Everything below is a
  // ROM lookup, a character mux and a font-ROM address. Doing all of it in one
  // clock is what failed timing at 148.4 MHz:
  //
  //   Source: TERMINAL/SCREEN/TIMING/s_vcount_reg[2]
  //   Dest:   PANEL/PANELFONT font ROM address
  //   Data Path Delay: 8.013 ns   Logic Levels: 12  (budget 6.737 ns)
  //   Slack: -1.889 ns
  //
  // Splitting it here costs one clock of latency and nothing else. The panel is
  // its own screen region - nothing has to line up with the text grid pixel for
  // pixel - so the whole panel simply lands one pixel further right, which no
  // monitor and no person can see.
  //--------------------------------------------------------------------------

  reg [6:0] r1_col;
  reg [2:0] r1_row;
  reg [2:0] r1_pixel_col;
  reg [3:0] r1_pixel_row;
  reg       r1_in_panel;

  always @(posedge clk) begin
    r1_col       <= c_col;
    r1_row       <= c_row;
    r1_pixel_col <= c_pixel_col;
    r1_pixel_row <= c_pixel_row;
    r1_in_panel  <= s_in_panel;
  end

  wire [6:0] s_col       = r1_col;
  wire [2:0] s_row       = r1_row;
  wire [2:0] s_pixel_col = r1_pixel_col;
  wire [3:0] s_pixel_row = r1_pixel_row;

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
  localparam integer COL_HDD_R        = 60;
  localparam integer COL_HDD_W        = 62;
  localparam integer COL_FLP_R        = 65;
  localparam integer COL_FLP_W        = 67;
  localparam integer COL_LEGEND       = 72;

  //! Which of the 16 level cells this column is in, and whether it is lit.
  //!
  //! COUNTED FROM THE RIGHT. make_panel.py prints the ruler high-to-low - level
  //! 15 leftmost, level 0 rightmost, exactly as on the real fascia:
  //!     col = COL_LEVELS + (15 - lvl) * LEVEL_CELL_W
  //! Counting left to right here mirrored the display against its own ruler, so
  //! an idle machine sitting on level 1 or 2 lit the cells under the digits 14
  //! and 13. From hardware: "level 14,14,13 is always on".
  wire [3:0] s_level_pair  = (s_col - COL_LEVELS[6:0]) >> 1;
  wire [3:0] s_level_index = 4'd15 - s_level_pair;

  //! ROW 2 ONLY. Without the row test this claimed columns 24-55 on every row,
  //! and because it is the first branch of the mux it overwrote the PROTECT
  //! RING digit, INTERRUPT and PAGING values that live on row 1. From hardware:
  //! those fields "seem a bit random".
  //!
  //! ONE column of each pair, not both. The cell is 2 columns wide so the octal
  //! ruler's two-digit labels fit underneath, but the lamp itself is a single
  //! square - two filled columns read as two lamps per level.
  wire       s_in_levels   = (s_row == 3'd2) &&
                             (s_col >= COL_LEVELS[6:0]) &&
                             (s_col <  COL_LEVELS[6:0] + 7'd32);
  wire       s_level_lamp  = s_in_levels && (s_col[0] == COL_LEVELS[0]);

  //--------------------------------------------------------------------------
  // THE FRAME SNAPSHOT
  //
  // Every value the panel draws is captured once per frame and held for all of
  // it. Not tidiness - the fix for what the display actually looked like.
  //
  // The inputs change on the CPU's schedule, not the beam's: PIL moves every
  // few microseconds, the glow counters decay continuously, the meters publish
  // whenever their window closes. Rendering straight from them lets a lamp be
  // lit while the beam draws its top half and dark by the bottom - a single
  // glyph not even rendering consistently down its own 16 rows. That is what
  // "shadows on the boxes" and "unstable rendering" were on hardware.
  //
  // The STATUS fields go slower still. PROTECT RING, INTERRUPT and PAGING
  // flipping the instant an instruction changes them is not what the real
  // machine did - its panel processor sends packets every 20 ms and the LCD has
  // response time on top, which Ronny puts at 200-300 ms. SLOW_FRAMES gives
  // ~267 ms. A field that changes 60 times a second is a strobe, not a display.
  //--------------------------------------------------------------------------

  localparam integer SLOW_FRAMES = 16;   //! ~267 ms at 60 Hz

  reg [4:0]  s_slow_cnt;
  reg [3:0]  r_disk;        //! {flp_wr, flp_rd, hdd_wr, hdd_rd}, held
  reg [15:0] r_lamp;
  reg [3:0]  r_util, r_hit, r_pil;
  reg [1:0]  r_ring;
  reg        r_paging, r_interrupt, r_running;
  reg [4:0]  r_up_h;
  reg [5:0]  r_up_m, r_up_s;

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

  //! All 16 lamps as one vector, so the frame latch captures them together.
  //! Disc lamps get the same treatment as the level afterglow, and for the
  //! same reason: a disc request is a strobe a few clocks long, which at 60 Hz
  //! would be invisible almost every time it happened. Held for ~0.25 s so a
  //! single sector access registers as a visible blink.
  reg [7:0] s_disk_hold[0:3];
  wire [3:0] s_disk_in = {flp_wr, flp_rd, hdd_wr, hdd_rd};
  integer di;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      for (di = 0; di < 4; di = di + 1) s_disk_hold[di] <= 8'd0;
    end else begin
      for (di = 0; di < 4; di = di + 1) begin
        if (s_disk_in[di[1:0]]) s_disk_hold[di] <= 8'hFF;
        else if (s_glow_tick == 17'd0 && s_disk_hold[di] != 8'd0)
          s_disk_hold[di] <= s_disk_hold[di] - 8'd1;
      end
    end
  end

  wire [3:0] s_disk_now;
  genvar dk;
  generate
    for (dk = 0; dk < 4; dk = dk + 1) begin : g_disk
      assign s_disk_now[dk] = (s_disk_hold[dk] != 8'd0);
    end
  endgenerate

  wire [15:0] s_lamp_now;
  genvar gl;
  generate
    for (gl = 0; gl < 16; gl = gl + 1) begin : g_lamp
      assign s_lamp_now[gl] = (s_glow[gl] != 8'd0);
    end
  endgenerate

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      s_slow_cnt <= 5'd0;
      r_disk <= 4'd0;
      r_lamp <= 16'd0; r_util <= 4'd0; r_hit <= 4'd0; r_pil <= 4'd0;
      r_ring <= 2'd0; r_paging <= 1'b0; r_interrupt <= 1'b0; r_running <= 1'b0;
      r_up_h <= 5'd0; r_up_m <= 6'd0; r_up_s <= 6'd0;
    end else if (frame_tick) begin
      // Per frame: the things that must keep up with the machine. The lamp
      // vector especially - the afterglow exists to make brief visits visible,
      // and sampling it slowly would discard the very events it is for.
      r_lamp <= s_lamp_now;
      r_disk <= s_disk_now;
      r_util <= utilization;
      r_hit  <= cache_hit;
      r_pil  <= pil;
      r_up_h <= up_hours;
      r_up_m <= up_minutes;
      r_up_s <= up_seconds;

      if (s_slow_cnt == SLOW_FRAMES[4:0] - 5'd1) begin
        s_slow_cnt  <= 5'd0;
        r_ring      <= ring;
        r_paging    <= paging_on;
        r_interrupt <= interrupt_on;
        r_running   <= running;
      end else begin
        s_slow_cnt <= s_slow_cnt + 5'd1;
      end
    end
  end

  wire s_level_lit = r_lamp[s_level_index];

  //! Uptime digits. Two cells per field plus the colons, laid out hh:mm:ss.
  wire [3:0] s_up_col = s_col - COL_UPTIME_VALUE[6:0];
  reg  [7:0] s_uptime_char;
  always @(*) begin
    case (s_up_col)
      4'd0: s_uptime_char = 8'h30 + {4'b0, r_up_h   / 5'd10};
      4'd1: s_uptime_char = 8'h30 + {4'b0, r_up_h   % 5'd10};
      4'd2: s_uptime_char = ":";
      4'd3: s_uptime_char = 8'h30 + {4'b0, r_up_m / 6'd10};
      4'd4: s_uptime_char = 8'h30 + {4'b0, r_up_m % 6'd10};
      4'd5: s_uptime_char = ":";
      4'd6: s_uptime_char = 8'h30 + {4'b0, r_up_s / 6'd10};
      4'd7: s_uptime_char = 8'h30 + {4'b0, r_up_s % 6'd10};
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
      // Only the first column of the pair carries the lamp; the second is the
      // gap between lamps, so each level reads as one square.
      // Both columns, each with its own half-glyph, so the pair forms one
      // 14 px lamp with a clear gap to the next level.
      s_live_char   = s_level_lamp
                    ? (s_level_lit ? G_LEVEL_ON_L : G_LEVEL_OFF_L)
                    : (s_level_lit ? G_LEVEL_ON_R : G_LEVEL_OFF_R);
      s_live_colour = C_LCDINK;
    end else if (s_col >= COL_UTIL_BAR[6:0] &&
                 s_col <  COL_UTIL_BAR[6:0] + UTIL_BAR_W[6:0] && s_row == 3'd1) begin
      s_live_char   = bar_char(r_util, s_col - COL_UTIL_BAR[6:0], UTIL_BAR_W[3:0]);
      s_live_colour = C_LCDINK;
    end else if (s_col >= COL_HIT_BAR[6:0] &&
                 s_col <  COL_HIT_BAR[6:0] + HIT_BAR_W[6:0] && s_row == 3'd1) begin
      s_live_char   = bar_char(r_hit, s_col - COL_HIT_BAR[6:0], HIT_BAR_W[3:0]);
      s_live_colour = C_LCDINK;
    end else if (s_col == COL_RING_VALUE[6:0] && s_row == 3'd1) begin
      s_live_char   = 8'h30 + {6'b0, r_ring};
      s_live_colour = C_LCDINK;
    end else if (s_col >= COL_INT_VALUE[6:0] && s_col < COL_INT_VALUE[6:0] + 7'd3
                 && s_row == 3'd1) begin
      s_live_char   = onoff_char(s_col - COL_INT_VALUE[6:0], r_interrupt);
      s_live_colour = C_LCDINK;
    end else if (s_col >= COL_PAGE_VALUE[6:0] && s_col < COL_PAGE_VALUE[6:0] + 7'd3
                 && s_row == 3'd1) begin
      s_live_char   = onoff_char(s_col - COL_PAGE_VALUE[6:0], r_paging);
      s_live_colour = C_LCDINK;
    end else if (s_row == 3'd2 && s_col >= COL_UPTIME_VALUE[6:0]
                 && s_col < COL_UPTIME_VALUE[6:0] + 7'd8) begin
      s_live_char   = s_uptime_char;
      s_live_colour = C_LCDINK;
    end else if (s_row == 3'd1 &&
                 (s_col == COL_HDD_R[6:0] || s_col == COL_HDD_W[6:0] ||
                  s_col == COL_FLP_R[6:0] || s_col == COL_FLP_W[6:0])) begin
      //! The letter appears ONLY while that disc is active. An idle lamp is
      //! blank, not a dimmed letter - a letter that is always there reads as a
      //! label rather than an indicator, and the LCD should be empty when
      //! nothing is happening. The cell is reversed at the same time (see
      //! s_disk_reversed), so an active lamp is a filled box with the letter
      //! knocked out of it.
      s_live_char = (s_col == COL_HDD_R[6:0] && r_disk[0]) ? "R"
                  : (s_col == COL_HDD_W[6:0] && r_disk[1]) ? "W"
                  : (s_col == COL_FLP_R[6:0] && r_disk[2]) ? "R"
                  : (s_col == COL_FLP_W[6:0] && r_disk[3]) ? "W"
                                                           : 8'h20;
      s_live_colour = C_LCDINK;
    end else if (s_col >= COL_LEGEND[6:0] && s_col < COL_LEGEND[6:0] + 7'd7) begin
      // The two lit legend words, driven by the RUN line. On the real fascia
      // only the currently usable words are lit; here RUNNING and OPCOM are
      // mutually exclusive, which is what the machine actually reports.
      if (s_row == 3'd1) begin
        s_live_char   = 8'h20;
        s_live_colour = r_running ? C_LIT : C_DARK;
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
  wire [7:0] c_char = s_is_dynamic ? s_live_char : s_rom_char;

  //--------------------------------------------------------------------------
  // PIPELINE STAGE 2 - registered character, straight into the font ROM
  //
  // The layout ROM is a 169-entry case and the live-value mux sits on top of
  // it. Registering the result here means the font ROM sees a flop output
  // rather than the far end of that logic, which is the other half of the
  // 8 ns path above.
  //--------------------------------------------------------------------------
  reg [7:0] r2_char;
  always @(posedge clk) r2_char <= c_char;

  wire [7:0] s_char = r2_char;

  //! The LCD window - rows 1 and 2 across the fields, which is the lit area of
  //! the real display. Everything else is fascia.
  wire s_in_lcd = (s_row == 3'd1) || (s_row == 3'd2);

  //! The octal ruler's alternating triplets are REVERSED OUT on the real
  //! fascia: dark digits on a light block, at {14,13,12} {8,7,6} {2,1,0}.
  wire [4:0] s_ruler_level = 5'd15 - ((s_col - COL_LEVELS[6:0]) >> 1);
  //! An active disc lamp REVERSES its cell, so the R or W is knocked out of a
  //! filled box. The letters themselves are static text in term_panel_rom, so
  //! nothing here has to draw them - only decide the box.
  wire s_disk_reversed = (s_row == 3'd1) &&
                         ((s_col == COL_HDD_R[6:0] && r_disk[0]) ||
                          (s_col == COL_HDD_W[6:0] && r_disk[1]) ||
                          (s_col == COL_FLP_R[6:0] && r_disk[2]) ||
                          (s_col == COL_FLP_W[6:0] && r_disk[3]));

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

  //! STILL TWO DEEP, even though the pipeline gained two stages - and getting
  //! this wrong is subtle enough to be worth spelling out.
  //!
  //! These delay lines are fed from the STAGE 1 registers, so they already
  //! start one clock in. The font path is: stage 1 -> layout ROM -> stage 2
  //! (r2_char) -> font ROM's registered output = 3 clocks. A signal entering
  //! here at stage 1 therefore needs exactly 2 more, not 3.
  //!
  //! Making them 3 deep put the region flags at 4 clocks against the font's 3.
  //! The panel testbench caught it immediately - "claimed 639 of 640 pixels"
  //! and one pixel outside the origin - which on a screen would have been a
  //! one-pixel smear nobody would ever have investigated.
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
    s_in_panel_dly <= {s_in_panel_dly[0], r1_in_panel};
    s_in_lcd_dly   <= {s_in_lcd_dly[0], s_in_lcd};
    s_reversed_dly <= {s_reversed_dly[0], s_ruler_reversed | s_disk_reversed};
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

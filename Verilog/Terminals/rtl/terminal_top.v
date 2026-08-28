//============================================================================
//! Terminal core - top level. Bytes in, video out.
//!
//! Part of the board-independent terminal core (Verilog/Terminals/).
//! Plan: Verilog/Terminals/docs/PLAN-vt100-terminal-core.md
//!
//! This is the whole Stage A terminal: give it console bytes on any clock and
//! it gives you a monochrome pixel stream with sync. It knows nothing about
//! any board - no VGA connector, no HDMI scaler, no keyboard. Each board wires
//! the two ends:
//!
//!   Nexys 4 DDR : deserialize cpu_txd into byte_in; pixel -> the 12-bit VGA
//!                 pins; keyboard from the onboard USB host as plain PS/2
//!   MiSTer      : ps2_key from hps_io; pixel -> CLK_VIDEO/CE_PIXEL/VGA_*
//!   MEGA65      : mega65 keyboard matrix; pixel -> the VDAC
//!
//! Keyboard input is NOT handled here - a keyboard produces bytes that go back
//! to the machine, which is the board's business, not the screen's.
//!
//! Written 27-AUG-2026.
//============================================================================

`default_nettype none

module terminal_top #(
    parameter integer COLS      = 80,
    parameter integer ROWS      = 25,
    parameter integer AWIDTH    = 11,
    parameter         FONT_FILE = "../font/font8x16.hex",

    //! Glyph box. Set by the font, not a free choice - font8x16.hex is 8 wide
    //! and 16 tall. Parameters here only so the origins below can be derived
    //! from them; change the font before changing these.
    parameter integer CELL_W = 8,
    parameter integer CELL_H = 16,

    //! 0 removes the operator panel from the design ENTIRELY - the renderer,
    //! its font ROM, the rate meters and the uptime counter all disappear.
    //!
    //! This is NOT the same as the board's panel switch. That switch blanks the
    //! panel at run time and the logic stays in the bitstream; this parameter is
    //! what you reach for when fabric or timing is actually tight. Both exist
    //! because they answer different questions.
    parameter integer WITH_PANEL = 1,

    // VGA mode - defaults are 800x600@60 from a 40.000 MHz pixel clock
    parameter integer H_VISIBLE     = 800,
    parameter integer H_FRONT_PORCH = 40,
    parameter integer H_SYNC        = 128,
    parameter integer H_BACK_PORCH  = 88,
    parameter integer V_VISIBLE     = 600,
    parameter integer V_FRONT_PORCH = 1,
    parameter integer V_SYNC        = 4,
    parameter integer V_BACK_PORCH  = 23,
    //! Top-left corner of the character grid inside the visible area.
    //!
    //! COMPUTED, not written down, and that is the point. These were constants
    //! until 28-AUG-2026, and ORIGIN_Y still said 108 - the value that centres
    //! a 24-ROW grid - long after the terminal became the TDV2200's real
    //! 80x25. It was not harmless: terminal_top passes its OWN defaults down,
    //! so 108 OVERRODE the corrected 100 in text_screen.v, and no board
    //! overrides it, so every build would have drawn the grid 8 pixels low.
    //!
    //! text_screen_tb did not catch it because it passes 100 explicitly - a
    //! test that supplies its own value cannot check a default. Deriving the
    //! number from the ones it depends on removes the whole failure mode:
    //! change ROWS, COLS or the video mode and the grid re-centres itself.
    parameter integer ORIGIN_X      = (H_VISIBLE - COLS * CELL_W) / 2,
    parameter integer ORIGIN_Y      = (V_VISIBLE - ROWS * CELL_H) / 2
) (
    // Byte in - the console stream, on ITS OWN clock
    input  wire       byte_clk,
    input  wire       byte_rst_n,
    input  wire       byte_valid,
    input  wire [7:0] byte_data,
    output wire       byte_ready,  //! low while the previous byte is in flight

    //! Font page: 0 = US / ISO 646 IRV, 1 = Norwegian (NS 4551-1). Must be
    //! driven from the SAME source as the keyboard's layout_no - the two
    //! disagreeing is worse than either being wrong, because what you type and
    //! what you see stop matching.
    input  wire national,

    //! Video mode: 0 = the H_*/V_* parameters at 1x glyphs, 1 = H2_*/V2_* at
    //! 2x. The board MUST switch the pixel clock with it - this core only
    //! counts, it cannot know what the clock really is.
    input  wire mode,

    // Video out - pixel clock domain
    input  wire pix_clk,
    input  wire pix_rst_n,
    output wire pixel,   //! 1 = ink, 0 = paper (the console text alone)

    //! Palette index for this pixel. The BOARD maps it to its own colour
    //! depth, so nothing board-specific lives in this core:
    //!   0 black  1 text ink  2 fascia  3 silkscreen
    //!   4 LCD ground  5 LCD segment  6 lit legend  7 unlit legend
    output wire [2:0] colour,
    output wire hsync,
    output wire vsync,
    output wire de,

    //! ---- operator panel -------------------------------------------------
    //! Drawn in the empty area below the text grid. `panel_enable` low draws
    //! nothing; it does NOT remove the logic, which is a build-time choice.
    //! RAW machine signals, exactly as they leave ND3202D's DBG_PANEL port in
    //! MC68705 Port-D order. The rate meters and the uptime counter live in
    //! here rather than in each board's top level, so three boards cannot end
    //! up with three slightly different definitions of "utilization".
    input  wire       panel_enable,
    input  wire [3:0] panel_pil,        //! current program level
    input  wire       panel_lev0,       //! LEV0 - running at level 0, i.e. idle
    input  wire       panel_hit,        //! HIT  - the ND-120's own cache
    input  wire [1:0] panel_ring,       //! PCR protect ring
    input  wire       panel_paging_on,  //! PONI
    input  wire       panel_interrupt_on, //! IONI
    input  wire       panel_running,    //! CPU running (already de-inverted)

    output wire bell,       //! one pix_clk per BEL received
    output wire [2:0] leds  //! TDV keyboard lamps (ENQ/ACK/NAK set, SYN clears)
);

  //--------------------------------------------------------------------------
  // Byte into the pixel domain
  //--------------------------------------------------------------------------

  wire       s_pix_byte_valid;
  wire [7:0] s_pix_byte_data;
  //! terminal_ctrl is not always able to take a byte - a clear-screen sweep
  //! walks 2000 cells and holds this low throughout. See the CDC note.
  wire       s_ctrl_ready;

  cdc_byte CDC (
      .src_clk  (byte_clk),
      .src_rst_n(byte_rst_n),
      .src_valid(byte_valid),
      .src_data (byte_data),
      .src_ready(byte_ready),

      .dst_clk  (pix_clk),
      .dst_rst_n(pix_rst_n),
      .dst_valid(s_pix_byte_valid),
      .dst_data (s_pix_byte_data),
      .dst_ready(s_ctrl_ready)
  );

  //--------------------------------------------------------------------------
  // Character RAM - written by the control logic, read by the screen
  //--------------------------------------------------------------------------

  wire              s_we;
  wire [AWIDTH-1:0] s_waddr;
  wire [      15:0] s_wdata;
  wire [AWIDTH-1:0] s_raddr;
  wire [      15:0] s_rdata;

  char_ram #(
      .COLS  (COLS),
      .ROWS  (ROWS),
      .AWIDTH(AWIDTH)
  ) CHARRAM (
      .clk  (pix_clk),
      .we   (s_we),
      .waddr(s_waddr),
      .wdata(s_wdata),
      .raddr(s_raddr),
      .rdata(s_rdata)
  );

  //--------------------------------------------------------------------------
  // Screen state
  //--------------------------------------------------------------------------

  wire [7:0] s_top_row;
  wire [7:0] s_cursor_col;
  wire [7:0] s_cursor_row;
  wire       s_cursor_enable;
  wire       s_frame_end;
  //! STX/ETX blank the display WITHOUT erasing it - so this gates the pixel
  //! on the way out, it does not touch the character RAM.
  wire       s_video_on;

  terminal_ctrl #(
      .COLS  (COLS),
      .ROWS  (ROWS),
      .AWIDTH(AWIDTH)
  ) CTRL (
      .clk  (pix_clk),
      .rst_n(pix_rst_n),

      .byte_valid(s_pix_byte_valid),
      .byte_data (s_pix_byte_data),
      // FED BACK, since 28-AUG-2026. This used to be left unconnected on the
      // argument that a 115200 console byte (every ~87 us) could never catch
      // the ~48 us clear-screen window. True of a UART, and false the moment
      // term_banner.v became a source: it hands over a byte every ~150 ns and
      // the power-on clear ate the entire startup message. The handshake is
      // now real, which also removes the caveat Stage B was going to have to
      // fix anyway.
      .ready     (s_ctrl_ready),

      .ram_we   (s_we),
      .ram_waddr(s_waddr),
      .ram_wdata(s_wdata),

      .top_row      (s_top_row),
      .cursor_col   (s_cursor_col),
      .cursor_row   (s_cursor_row),
      .cursor_enable(s_cursor_enable),

      .video_on (s_video_on),
      .charset  (),   // one font page today - see the SO/SI note in terminal_ctrl.v

      .frame_end(s_frame_end),
      .bell     (bell),
      .leds     (leds)
  );

  wire s_screen_pixel;
  assign pixel = s_screen_pixel & s_video_on;

  //! The panel works from the raw counters and applies its own two clocks of
  //! delay, matching the text pipeline. It never overlaps the text grid, so
  //! there is no arbitration - just a priority in the final mux.
  wire [11:0] s_x_raw, s_y_raw;
  wire        s_panel_active;
  wire [2:0]  s_panel_colour;

  generate
    if (WITH_PANEL != 0) begin : g_panel
    //! UTILIZATION is the inverse of LEV0: the real panel's caption is how much
    //! time the machine was NOT idle, and idle on an ND is "running at level 0".
    wire [3:0] s_utilization;
    rate_meter UTIL_METER (
        .clk(pix_clk), .rst_n(pix_rst_n), .sample(!panel_lev0), .eighths(s_utilization)
    );

    wire [3:0] s_cache_hit;
    rate_meter HIT_METER (
        .clk(pix_clk), .rst_n(pix_rst_n), .sample(panel_hit), .eighths(s_cache_hit)
    );

    //! Uptime, counted in FRAMES rather than clocks. The frame rate is 60 Hz in
    //! both video modes while the pixel clock is not - 40 MHz at 800x600 and
    //! 148.5 MHz at 1080p - so counting frames keeps the clock correct when the
    //! resolution switch is thrown. Counting clocks would have made the panel run
    //! 3.7x fast in one of the two modes, which is the kind of bug that gets
    //! blamed on the machine.
    reg [5:0]  s_up_frames;
    reg [5:0]  s_up_sec;
    reg [5:0]  s_up_min;
    reg [4:0]  s_up_hr;

    always @(posedge pix_clk or negedge pix_rst_n) begin
      if (!pix_rst_n) begin
        s_up_frames <= 6'd0;
        s_up_sec    <= 6'd0;
        s_up_min    <= 6'd0;
        s_up_hr     <= 5'd0;
      end else if (s_frame_end) begin
        if (s_up_frames == 6'd59) begin
          s_up_frames <= 6'd0;
          if (s_up_sec == 6'd59) begin
            s_up_sec <= 6'd0;
            if (s_up_min == 6'd59) begin
              s_up_min <= 6'd0;
              s_up_hr  <= (s_up_hr == 5'd23) ? 5'd0 : s_up_hr + 5'd1;
            end else s_up_min <= s_up_min + 6'd1;
          end else s_up_sec <= s_up_sec + 6'd1;
        end else s_up_frames <= s_up_frames + 6'd1;
      end
    end

    term_panel #(
        .FONT_FILE(FONT_FILE),
        .ORIGIN_X (ORIGIN_X),
        .ORIGIN_Y (ORIGIN_Y + ROWS * CELL_H + CELL_H)
    ) PANEL (
        .clk  (pix_clk),
        .rst_n(pix_rst_n),

        .x     (s_x_raw),
        .y     (s_y_raw),
        .mode  (mode),
        .enable(panel_enable),

        .pil         (panel_pil),
        .utilization (s_utilization),
        .cache_hit   (s_cache_hit),
        .ring        (panel_ring),
        .paging_on   (panel_paging_on),
        .interrupt_on(panel_interrupt_on),
        .running     (panel_running),
        .up_hours    (s_up_hr),
        .up_minutes  (s_up_min),
        .up_seconds  (s_up_sec),

        .active(s_panel_active),
        .colour(s_panel_colour)
    );
    end else begin : g_no_panel
      //! Nothing to draw, and nothing built. The colour mux below then
      //! collapses to the text path alone.
      assign s_panel_active = 1'b0;
      assign s_panel_colour = 3'd0;
    end
  endgenerate

  //! Panel first, then the text. They occupy different rows of the screen, so
  //! the priority never actually arbitrates - it just picks which of the two
  //! is speaking about this pixel.
  assign colour = s_panel_active ? s_panel_colour
                : (s_screen_pixel & s_video_on) ? 3'd1 : 3'd0;

  text_screen #(
      .COLS         (COLS),
      .ROWS         (ROWS),
      .CELL_W       (CELL_W),
      .CELL_H       (CELL_H),
      .AWIDTH       (AWIDTH),
      .ORIGIN_X     (ORIGIN_X),
      .ORIGIN_Y     (ORIGIN_Y),
      .FONT_FILE    (FONT_FILE),
      .H_VISIBLE    (H_VISIBLE),
      .H_FRONT_PORCH(H_FRONT_PORCH),
      .H_SYNC       (H_SYNC),
      .H_BACK_PORCH (H_BACK_PORCH),
      .V_VISIBLE    (V_VISIBLE),
      .V_FRONT_PORCH(V_FRONT_PORCH),
      .V_SYNC       (V_SYNC),
      .V_BACK_PORCH (V_BACK_PORCH)
  ) SCREEN (
      .clk  (pix_clk),
      .rst_n(pix_rst_n),

      .ram_raddr(s_raddr),
      .ram_rdata(s_rdata),

      .national     (national),
      .mode         (mode),

      .top_row      (s_top_row),
      .cursor_col   (s_cursor_col),
      .cursor_row   (s_cursor_row),
      .cursor_enable(s_cursor_enable),

      .pixel    (s_screen_pixel),
      .hsync    (hsync),
      .vsync    (vsync),
      .de       (de),
      .frame_end(s_frame_end),
      .x_raw    (s_x_raw),
      .y_raw    (s_y_raw)
  );

endmodule

`default_nettype wire

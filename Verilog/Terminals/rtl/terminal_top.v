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

    // Video out - pixel clock domain
    input  wire pix_clk,
    input  wire pix_rst_n,
    output wire pixel,   //! 1 = ink, 0 = paper
    output wire hsync,
    output wire vsync,
    output wire de,

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

      .top_row      (s_top_row),
      .cursor_col   (s_cursor_col),
      .cursor_row   (s_cursor_row),
      .cursor_enable(s_cursor_enable),

      .pixel    (s_screen_pixel),
      .hsync    (hsync),
      .vsync    (vsync),
      .de       (de),
      .frame_end(s_frame_end)
  );

endmodule

`default_nettype wire

//============================================================================
//! MiSTer glue for the board-independent terminal core.
//!
//! Full path: Verilog/fpga/mister/rtl/nd120_console_mister.v
//!
//! Everything MiSTer-specific about the console lives here, and nothing
//! MiSTer-specific lives in Verilog/Terminals/. The terminal core is shared
//! with the Nexys 4 DDR and (later) the MEGA65; the only things that differ
//! per board are the two ends - where keystrokes come from and where pixels
//! go - which is exactly what this file is.
//!
//! THE KEYBOARD END. hps_io gives us `ps2_key = {toggle, pressed, extended,
//! code[7:0]}` (sys/hps_io.sv:102-103, 306) - Linux has already done the USB
//! work AND the PS/2 framing, so there is no serial line to decode. That is
//! why this instantiates `ps2_decoder` and NOT `ps2_keyboard`: the framing
//! half of the Nexys keyboard has no job here, while the half with the actual
//! logic in it - modifiers, caps lock, control characters, the TDV cursor
//! keys - is shared. Bit 10 toggles per event rather than pulsing, so it needs
//! an edge detector to become a strobe.
//!
//! THE VIDEO END. MiSTer wants CLK_VIDEO + CE_PIXEL + VGA_DE/HS/VS/R/G/B and
//! scales whatever it is given. We hand it the terminal's own 800x600@60
//! timing at one pixel per clock, so CE_PIXEL is simply 1 - the same video
//! mode the Nexys build uses, which means one tested configuration rather than
//! one per board.
//!
//! BUILD 1 (28-AUG-2026) has no ND-120 in it at all. `cpu_*` is wired but
//! nothing drives it, so what you get is the banner plus local echo: type and
//! the characters appear. That is the whole point of build 1 - it proves the
//! clock, the video timing, the font, the character RAM and the keyboard on
//! real MiSTer hardware with NOTHING of the CPU able to be blamed. Build 2
//! drops ND3202D in behind the same seam.
//!
//! Written 28-AUG-2026.
//============================================================================

`default_nettype none

module nd120_console_mister #(
    //! A BARE FILENAME on purpose. Vivado resolves $readmemh next to the .v
    //! that contains it and Quartus is believed to resolve it relative to the
    //! project directory - so instead of betting on one, the build puts the
    //! font where both rules look: nd120.qsf adds a SEARCH_PATH and `make
    //! font` copies the hex into the project directory. Blank boxes on screen
    //! instead of glyphs means neither worked.
    parameter FONT_FILE = "font8x16.hex",

    //! Build 1 default: echo keystrokes straight to the screen so the console
    //! is testable with no machine behind it. Build 2 sets this to 0, because
    //! once the ND-120 is there IT echoes - a terminal that echoes locally as
    //! well shows every character twice, which is the classic first symptom.
    parameter LOCAL_ECHO = 1
) (
    input wire clk,    //! pixel clock, 40.000 MHz for 800x600@60
    input wire rst_n,  //! async reset, active low, in the pixel domain

    //! From hps_io. {toggle, pressed, extended, code[7:0]}
    input wire [10:0] ps2_key,

    //! The machine seam. Bytes from the ND-120's console UART come in here;
    //! keystrokes go back out. Unused in build 1.
    input  wire       cpu_byte_valid,
    input  wire [7:0] cpu_byte_data,
    output wire       cpu_byte_ready,

    output reg        kbd_valid,  //! one clock per keystroke to the machine
    output reg  [7:0] kbd_data,

    // Video, straight onto the framework's VGA_* ports
    output wire pixel,  //! 1 = ink
    output wire hsync,
    output wire vsync,
    output wire de,

    output wire bell
);

  //--------------------------------------------------------------------------
  // Keyboard: toggle -> strobe, then the shared decoder
  //--------------------------------------------------------------------------

  reg s_key_toggle_d;

  wire s_key_strobe = (ps2_key[10] != s_key_toggle_d);

  //! No reset on purpose. Resetting this to a CONSTANT would manufacture a
  //! phantom keystroke whenever the incoming toggle happened to sit at the
  //! other value when reset released - a stray character at power-on that
  //! looks exactly like a keyboard fault. Tracking the input unconditionally
  //! cannot produce a false edge; hps_io declares `ps2_key = 0` at power-up
  //! (sys/hps_io.sv:103) so both sides start agreeing anyway.
  always @(posedge clk) s_key_toggle_d <= ps2_key[10];

  wire       s_kbd_ascii_valid;
  wire [7:0] s_kbd_ascii_data;

  ps2_decoder DECODER (
      .clk  (clk),
      .rst_n(rst_n),

      .code_valid   (s_key_strobe),
      .code_data    (ps2_key[7:0]),
      //! hps_io reports `pressed`; the decoder wants `release`.
      .code_release (~ps2_key[9]),
      .code_extended(ps2_key[8]),

      .ascii_valid(s_kbd_ascii_valid),
      .ascii_data (s_kbd_ascii_data),

      .shift_active(),
      .ctrl_active (),
      .caps_active ()
  );

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      kbd_valid <= 1'b0;
      kbd_data  <= 8'h00;
    end else begin
      kbd_valid <= s_kbd_ascii_valid;
      kbd_data  <= s_kbd_ascii_data;
    end
  end

  //--------------------------------------------------------------------------
  // What the screen is told to display
  //
  // Three possible sources, in strict priority: the banner first (it owns the
  // screen until it has finished and then never speaks again), then the
  // machine, then the local echo. The banner going first matters - if it had
  // to share, a machine that starts talking immediately would interleave with
  // it and the self-test message would be unreadable exactly when something is
  // wrong.
  //--------------------------------------------------------------------------

  wire       s_banner_valid;
  wire [7:0] s_banner_data;
  wire       s_banner_done;
  wire       s_term_ready;

  term_banner BANNER (
      .clk  (clk),
      .rst_n(rst_n),
      .valid(s_banner_valid),
      .data (s_banner_data),
      .ready(s_term_ready),
      .done (s_banner_done)
  );

  wire s_echo_valid = (LOCAL_ECHO != 0) && s_kbd_ascii_valid;

  //! Gated on s_banner_done, and that is NOT the same as gating on
  //! !s_banner_valid. There is exactly one clock where the banner has reached
  //! its terminator so `valid` has already fallen but `done` has not yet risen.
  //! Selecting on !valid would let a machine byte through in that cycle while
  //! cpu_byte_ready (which follows `done`) was still low - so the terminal
  //! would print the byte and the machine, never seeing it accepted, would
  //! send it again. One duplicated character at the top of every boot, and a
  //! miserable thing to find on hardware.
  wire s_cpu_sel  = s_banner_done && cpu_byte_valid;
  wire s_echo_sel = s_banner_done && s_echo_valid && !cpu_byte_valid;

  wire       s_src_valid = s_banner_valid || s_cpu_sel || s_echo_sel;
  wire [7:0] s_src_data  = s_banner_valid ? s_banner_data :
                           (s_cpu_sel ? cpu_byte_data : s_kbd_ascii_data);

  //! The machine is only told the terminal is ready when the banner is out of
  //! the way, so a byte arriving during the banner is refused rather than
  //! silently dropped.
  assign cpu_byte_ready = s_term_ready && s_banner_done;

  //! NOTE on the echo path: a keystroke is a one-clock strobe with no queue
  //! behind it, so a character typed while the terminal is busy is lost rather
  //! than delayed. The busy window is a clear-screen, 1920 pixel clocks = 48 us
  //! at 40 MHz, and the banner is ~320 clocks = 8 us; a human cannot type into
  //! either. This is the same argument already recorded in terminal_top.v for
  //! the CDC, and it stops being good enough at the same moment - when Stage B
  //! adds escape sequences and the busy windows get longer. Written down
  //! rather than left as a surprise.

  //--------------------------------------------------------------------------
  // The shared terminal core
  //--------------------------------------------------------------------------

  terminal_top #(
      .FONT_FILE(FONT_FILE)
  ) TERMINAL (
      // One clock domain here: the whole console runs on the pixel clock, so
      // the CDC inside terminal_top is a no-op. Left in place rather than
      // bypassed - it is what lets this core drop onto a board where the
      // machine runs on its own clock, and it costs three flops.
      .byte_clk  (clk),
      .byte_rst_n(rst_n),
      .byte_valid(s_src_valid),
      .byte_data (s_src_data),
      .byte_ready(s_term_ready),

      .pix_clk  (clk),
      .pix_rst_n(rst_n),
      .pixel    (pixel),
      .hsync    (hsync),
      .vsync    (vsync),
      .de       (de),

      .bell(bell),
      .leds()
  );

endmodule

`default_nettype wire

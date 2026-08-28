//============================================================================
//! PS/2 scancode stream -> terminal bytes. Modifier state and lookup only.
//!
//! Part of the board-independent terminal core (Verilog/Terminals/).
//!
//! WHY THIS IS A SEPARATE MODULE (28-AUG-2026). Two of our boards produce
//! already-decoded scancodes and one produces a raw serial line:
//!
//!   Nexys 4 DDR : the onboard microcontroller presents USB HID as a plain
//!                 PS/2 clock/data pair, so `ps2_keyboard.v` has to do the
//!                 11-bit framing itself and then feeds this module.
//!   MiSTer      : hps_io hands over `ps2_key = {toggle, pressed, extended,
//!                 code[7:0]}` - Linux has already done the USB work and the
//!                 framing. There is no serial line to decode; the glue just
//!                 turns the toggle into a strobe and drives this module.
//!   MEGA65      : the keyboard is a matrix behind a CPLD, different again.
//!
//! Splitting the framing from the decoding means the part with the ACTUAL
//! logic in it - modifiers, caps lock, control characters, the TDV cursor
//! keys - exists once and is shared. A keyboard bug found on one board is
//! then fixed on all of them, which is not true if each board carries its own
//! copy.
//!
//! !! THE SCANCODE TABLE IS STILL UNVERIFIED against a physical keyboard -
//! !! see the warnings in ps2_ascii_table.v. This module's LOGIC is tested
//! !! (ps2_keyboard_tb.v drives it through the serial front end); the DATA it
//! !! looks things up in is not.
//!
//! Written 28-AUG-2026.
//============================================================================

`default_nettype none

module ps2_decoder (
    input wire clk,
    input wire rst_n,  //! async reset, active low

    //! One scancode, already framed and stripped of its E0/F0 prefixes.
    input wire       code_valid,     //! strobe, one clock
    input wire [7:0] code_data,      //! the scancode itself
    input wire       code_release,   //! this was a key RELEASE (F0 seen)
    input wire       code_extended,  //! this had the E0 prefix

    //! 0 = US ANSI, 1 = Norwegian. Changes both which key carries a character
    //! and which ISO 646 byte it sends - see ps2_ascii_table.v. The SCREEN must
    //! be switched with the same bit or a typed AE draws as '['.
    input wire       layout_no,

    output reg       ascii_valid,  //! one clock per character produced
    output reg [7:0] ascii_data,

    //! Modifier state, exposed because a board may want to light a lamp.
    output wire shift_active,
    output wire ctrl_active,
    output wire caps_active
);

  localparam [7:0] SC_LSHIFT = 8'h12;
  localparam [7:0] SC_RSHIFT = 8'h59;
  localparam [7:0] SC_CTRL   = 8'h14;
  localparam [7:0] SC_CAPS   = 8'h58;

  reg s_lshift, s_rshift, s_ctrl, s_caps;

  assign shift_active = s_lshift | s_rshift;
  assign ctrl_active  = s_ctrl;
  assign caps_active  = s_caps;

  wire s_shifted = s_lshift | s_rshift;

  wire [7:0] s_ascii_unshifted;
  wire [7:0] s_ascii_shifted;
  wire [7:0] s_ascii_extended;

  ps2_ascii_table TABLE (
      .code     (code_data),
      .layout_no(layout_no),
      .unshifted(s_ascii_unshifted),
      .shifted  (s_ascii_shifted),
      .extended (s_ascii_extended)
  );

  //! Caps lock affects letters only - not digits, not punctuation. Getting
  //! this wrong turns SHIFT+2 into a different character with caps on, which
  //! is the classic caps-lock bug.
  wire s_is_letter   = (s_ascii_unshifted >= "a") && (s_ascii_unshifted <= "z");
  wire s_use_shifted = s_shifted ^ (s_caps && s_is_letter);

  wire [7:0] s_ascii_plain = s_use_shifted ? s_ascii_shifted : s_ascii_unshifted;

  //! Control characters: CTRL + @A-Z[\]^_ gives 0x00-0x1F. Applied to the
  //! UNSHIFTED letter so ctrl-C and ctrl-shift-C are the same, as on a real
  //! terminal.
  wire [7:0] s_ascii_ctrl = {3'b000, s_ascii_unshifted[4:0]};

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      s_lshift    <= 1'b0;
      s_rshift    <= 1'b0;
      s_ctrl      <= 1'b0;
      s_caps      <= 1'b0;
      ascii_valid <= 1'b0;
      ascii_data  <= 8'h00;
    end else begin
      ascii_valid <= 1'b0;

      if (code_valid) begin
        case (code_data)
          SC_LSHIFT: s_lshift <= !code_release;
          SC_RSHIFT: s_rshift <= !code_release;
          SC_CTRL:   s_ctrl   <= !code_release;
          //! Caps lock toggles on PRESS only - toggling on the release too
          //! would cancel every press.
          SC_CAPS:   if (!code_release) s_caps <= !s_caps;

          default: begin
            // A character comes out on PRESS only.
            //
            // Extended (E0-prefixed) keys go through their own table: on a
            // TDV the arrows and HOME are bare C0 bytes, not escape
            // sequences, so they need no sequencer - just a different lookup.
            // An extended key with no TDV equivalent sends nothing,
            // deliberately (no VT100 fallback).
            if (!code_release) begin
              if (code_extended) begin
                if (s_ascii_extended != 8'h00) begin
                  ascii_valid <= 1'b1;
                  ascii_data  <= s_ascii_extended;
                end
              end else if (s_ascii_plain != 8'h00) begin
                ascii_valid <= 1'b1;
                ascii_data  <= s_ctrl ? s_ascii_ctrl : s_ascii_plain;
              end
            end
          end
        endcase
      end
    end
  end

endmodule

`default_nettype wire

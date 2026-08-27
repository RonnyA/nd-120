//============================================================================
//! PS/2 scancode set 2 -> ASCII, unshifted and shifted
//!
//! Part of the board-independent terminal core (Verilog/Terminals/).
//! Pure combinational lookup; 0x00 out means "this key has no character".
//!
//! !! UNVERIFIED DATA. These codes are transcribed from the published
//! !! scancode-set-2 tables. NOTHING here has been checked against a physical
//! !! keyboard, and the person who wrote it could not check it. Phase 3 of
//! !! fpga/nexys4ddr/PLAN-vga-console.md is exactly that check - type every
//! !! key on a real keyboard and read the screen. Until then every line below
//! !! is a claim, not a fact.
//!
//! Layout assumed: US ANSI. A Norwegian keyboard puts several of the
//! punctuation keys elsewhere, and the ones that matter for SINTRAN
//! (parentheses, colon, comma, full stop, slash) should be checked first when
//! Ronny types on his own keyboard.
//!
//! Extended (E0-prefixed) keys ARE here, in their own `extended` output and
//! their own case block below. That is only possible because a TDV sends BARE
//! C0 BYTES for the arrows and HOME, not escape sequences - so no sequencer is
//! needed, just a second lookup. See the block comment on that case for the
//! evidence from RetroTerm's key registry. The function keys, which DO need
//! sequences (F1 = ESC [ 5 0 _), are still Stage B/C work and are absent.
//!
//! Written 27-AUG-2026.
//============================================================================

`default_nettype none

module ps2_ascii_table (
    input  wire [7:0] code,
    output reg  [7:0] unshifted,
    output reg  [7:0] shifted,

    //! Byte for the same scancode when it arrived with the E0 (extended)
    //! prefix - the arrows, HOME and DELETE. 0x00 = this extended key sends
    //! nothing. See the TDV note below; these are NOT escape sequences.
    output reg  [7:0] extended
);

  //--------------------------------------------------------------------------
  // Extended (E0-prefixed) keys -> TDV control bytes
  //
  // On a TDV the cursor keys are BARE C0 BYTES, not escape sequences. There is
  // no ESC [ A. Send VT100 arrows and SINTRAN's full-screen tools do not see
  // cursor keys at all.
  //
  // This was worth checking rather than trusting: RetroTerm's
  // docs\TDV-KEYBOARD-COMPLETE-REFERENCE.md has a table showing
  // "TDV2200 Extended = ESC [ A" for the arrows. The CODE disagrees -
  // TDV2200KeyRegistry.cs registers UP/DOWN/LEFT/RIGHT/HOME with the flag
  // AlwaysSameCode and the SAME C0 byte in every column:
  //     Reg("C48","UP",   ...AlwaysSameCode, 38, "\x1C","\x1C",null,"\x1C",null)
  //     Reg("A48","DOWN", ...AlwaysSameCode, 40, "\x0B","\x0B",null,"\x0B",null)
  //     Reg("B47","LEFT", ...AlwaysSameCode, 37, "\x08","\x08",null,"\x08",null)
  //     Reg("B49","RIGHT",...AlwaysSameCode, 39, "\x18","\x18",null,"\x18",null)
  //     Reg("B48","HOME", ...AlwaysSameCode, 36, "\x1D","\x1D",null,"\x10",null)
  // The code is the source of truth; that doc table is a claim, and a wrong
  // one. HOME is the one key that differs between modes (0x1D native, 0x10 in
  // Simple ASCII) - we send the native code.
  //
  // !! The PS/2 SCANCODES below are from the published set-2 tables and are
  // !! UNVERIFIED against a physical keyboard, same as the main table.
  //--------------------------------------------------------------------------

  always @(*) begin
    case (code)
      8'h75:   extended = 8'h1C;  // Up    -> FS
      8'h72:   extended = 8'h0B;  // Down  -> VT
      8'h6B:   extended = 8'h08;  // Left  -> BS
      8'h74:   extended = 8'h18;  // Right -> CAN
      8'h6C:   extended = 8'h1D;  // Home  -> GS
      8'h71:   extended = 8'h7F;  // Delete-> DEL
      8'h5A:   extended = 8'h0D;  // keypad Enter -> CR (KPENTER is 0x0D always)
      default: extended = 8'h00;  // no TDV equivalent: send NOTHING.
                                  // Deliberate - RetroTerm has no VT100
                                  // fallback either. A fallback sends bytes a
                                  // real TDV never sent.
    endcase
  end

  always @(*) begin
    case (code)
      // --- letters ---------------------------------------------------------
      8'h1C: begin unshifted = "a"; shifted = "A"; end
      8'h32: begin unshifted = "b"; shifted = "B"; end
      8'h21: begin unshifted = "c"; shifted = "C"; end
      8'h23: begin unshifted = "d"; shifted = "D"; end
      8'h24: begin unshifted = "e"; shifted = "E"; end
      8'h2B: begin unshifted = "f"; shifted = "F"; end
      8'h34: begin unshifted = "g"; shifted = "G"; end
      8'h33: begin unshifted = "h"; shifted = "H"; end
      8'h43: begin unshifted = "i"; shifted = "I"; end
      8'h3B: begin unshifted = "j"; shifted = "J"; end
      8'h42: begin unshifted = "k"; shifted = "K"; end
      8'h4B: begin unshifted = "l"; shifted = "L"; end
      8'h3A: begin unshifted = "m"; shifted = "M"; end
      8'h31: begin unshifted = "n"; shifted = "N"; end
      8'h44: begin unshifted = "o"; shifted = "O"; end
      8'h4D: begin unshifted = "p"; shifted = "P"; end
      8'h15: begin unshifted = "q"; shifted = "Q"; end
      8'h2D: begin unshifted = "r"; shifted = "R"; end
      8'h1B: begin unshifted = "s"; shifted = "S"; end
      8'h2C: begin unshifted = "t"; shifted = "T"; end
      8'h3C: begin unshifted = "u"; shifted = "U"; end
      8'h2A: begin unshifted = "v"; shifted = "V"; end
      8'h1D: begin unshifted = "w"; shifted = "W"; end
      8'h22: begin unshifted = "x"; shifted = "X"; end
      8'h35: begin unshifted = "y"; shifted = "Y"; end
      8'h1A: begin unshifted = "z"; shifted = "Z"; end

      // --- digits and their shifted symbols (US layout) --------------------
      8'h45: begin unshifted = "0"; shifted = ")"; end
      8'h16: begin unshifted = "1"; shifted = "!"; end
      8'h1E: begin unshifted = "2"; shifted = "@"; end
      8'h26: begin unshifted = "3"; shifted = "#"; end
      8'h25: begin unshifted = "4"; shifted = "$"; end
      8'h2E: begin unshifted = "5"; shifted = "%"; end
      8'h36: begin unshifted = "6"; shifted = "^"; end
      8'h3D: begin unshifted = "7"; shifted = "&"; end
      8'h3E: begin unshifted = "8"; shifted = "*"; end
      8'h46: begin unshifted = "9"; shifted = "("; end

      // --- punctuation -----------------------------------------------------
      8'h0E: begin unshifted = "`";  shifted = "~"; end
      8'h4E: begin unshifted = "-";  shifted = "_"; end
      8'h55: begin unshifted = "=";  shifted = "+"; end
      8'h54: begin unshifted = "[";  shifted = "{"; end
      8'h5B: begin unshifted = "]";  shifted = "}"; end
      8'h5D: begin unshifted = "\\"; shifted = "|"; end
      8'h4C: begin unshifted = ";";  shifted = ":"; end
      8'h52: begin unshifted = "'";  shifted = 8'h22; end  // 0x22 = double quote
      8'h41: begin unshifted = ",";  shifted = "<"; end
      8'h49: begin unshifted = ".";  shifted = ">"; end
      8'h4A: begin unshifted = "/";  shifted = "?"; end

      // --- the control keys a console needs --------------------------------
      8'h29: begin unshifted = 8'h20; shifted = 8'h20; end  // space
      8'h5A: begin unshifted = 8'h0D; shifted = 8'h0D; end  // Enter -> CR
      8'h66: begin unshifted = 8'h08; shifted = 8'h08; end  // Backspace -> BS
      8'h0D: begin unshifted = 8'h09; shifted = 8'h09; end  // Tab -> HT
      8'h76: begin unshifted = 8'h1B; shifted = 8'h1B; end  // Esc

      // 0x00 = no character for this key. Modifiers land here too, which is
      // correct: the decoder handles them before it ever consults this table.
      default: begin unshifted = 8'h00; shifted = 8'h00; end
    endcase
  end

endmodule

`default_nettype wire

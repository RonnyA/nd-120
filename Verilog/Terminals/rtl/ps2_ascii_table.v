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
//! their own case block below. Since the 30-AUG-2026 VT100 decision the
//! arrows and HOME emit SEQUENCE MARKERS (0x80 | final byte) that
//! key_vt100.v expands into the real ESC [ x bytes on the way to the UART -
//! see the block comment on the case below.
//!
//! Written 27-AUG-2026.
//============================================================================

`default_nettype none

module ps2_ascii_table (
    input  wire [7:0] code,

    //! 0 = US ANSI, 1 = Norwegian (NS 4551-1). See the block comment below.
    input  wire       layout_no,
    output wire [7:0] unshifted,
    output wire [7:0] shifted,

    //! Byte for the same scancode when it arrived with the E0 (extended)
    //! prefix - the arrows, HOME and DELETE. 0x00 = this extended key sends
    //! nothing; 0x80|f = key_vt100.v expands it to ESC [ f (see below).
    output reg  [7:0] extended
);

  //--------------------------------------------------------------------------
  // Extended (E0-prefixed) keys -> VT100 (30-AUG-2026)
  //
  // A VT100 (SINTRAN terminal type 6) sends ESC [ A/B/C/D for the arrows -
  // three bytes per keypress. One lookup cannot produce three bytes, so the
  // table emits a MARKER: 0x80 OR'ed onto the sequence's final byte, and
  // key_vt100.v turns marker 0x80|f into ESC [ f on the wire. Bit 7 is safe
  // as a marker because the ND-120 is a 7-bit machine - no typed character
  // ever has it - and a marker that leaks unexpanded shows up as a printable
  // on the far side instead of vanishing.
  //
  // (Until 30-AUG-2026 these were the TDV bare C0 bytes - UP=0x1C, DOWN=0x0B,
  // LEFT=0x08, RIGHT=0x18, HOME=0x1D - correct for terminal type 53, whose
  // evidence trail is in docs/SPEC-tdv2200.md and the git history. The
  // terminal is a VT100 now.)
  //
  // !! The PS/2 SCANCODES below are from the published set-2 tables and are
  // !! UNVERIFIED against a physical keyboard, same as the main table.
  //--------------------------------------------------------------------------

  always @(*) begin
    case (code)
      8'h75:   extended = 8'h80 | "A";  // Up    -> ESC [ A
      8'h72:   extended = 8'h80 | "B";  // Down  -> ESC [ B
      8'h74:   extended = 8'h80 | "C";  // Right -> ESC [ C
      8'h6B:   extended = 8'h80 | "D";  // Left  -> ESC [ D
      8'h6C:   extended = 8'h80 | "H";  // Home  -> ESC [ H (CUP home)
      8'h71:   extended = 8'h7F;  // Delete-> DEL
      8'h5A:   extended = 8'h0D;  // keypad Enter -> CR
      default: extended = 8'h00;  // no VT100 equivalent (PgUp, End, ...):
                                  // send NOTHING rather than invent bytes.
    endcase
  end

  //--------------------------------------------------------------------------
  // Norwegian (NS 4551-1) - the layout_no overrides
  //
  // TWO THINGS DIFFER, and getting only one right produces nonsense:
  //
  //   1. WHICH KEY carries the character. Positions taken from RetroTerm's
  //      docs/KBD-ND-246.md (the ND 246 keyboard grid): D11, where US has [,
  //      is AA; C10 (US ;) is OE; C11 (US ') is AE; B8 (US ,) is , / ; ;
  //      B9 (US .) is . / : ; B10 (US /) is - / _ ; E11 (US -) is + / ?.
  //      Those are the same positions a modern PC Norwegian keyboard uses,
  //      which is the corroboration - two independent sources agreeing beats
  //      one source trusted.
  //
  //   2. WHICH BYTE it sends. NOT Latin-1. The ND-120 is a 7-BIT machine
  //      speaking ISO 646, where AE OE AA REPLACE [ \ ] and ae oe aa replace
  //      { | }. RetroTerm's FontTDV2200.cs says it outright: "The host sends
  //      7-bit ASCII position bytes (e.g. '[' = 0x5B for AE)". Send 0xC6 for
  //      AE and SINTRAN sees a byte with no meaning; send 0x5B and it is right.
  //
  // The SCREEN has to agree, which is why font_rom carries a second page (see
  // font/make_font.py). Keyboard and font are selected by the SAME bit -
  // letting them disagree would draw '[' for a typed AE.
  //
  // DEAD KEYS ARE NOT IMPLEMENTED. On a PC Norwegian layout the ¨/^ and ´/`
  // keys compose with the next keystroke, which needs state this table does
  // not have. They send their shifted character where that is plain ISO 646,
  // and nothing unshifted. Sending a plausible wrong byte would be worse than
  // sending none.
  //--------------------------------------------------------------------------

  reg [7:0] no_unshifted, no_shifted;
  reg       no_override;

  always @(*) begin
    no_override  = 1'b1;
    no_unshifted = 8'h00;
    no_shifted   = 8'h00;
    case (code)
      // number row - only the SHIFTED symbols move
      8'h1E: begin no_unshifted = "2"; no_shifted = 8'h22; end  // " where US has @
      8'h25: begin no_unshifted = "4"; no_shifted = 8'h24; end  // 0x24 is the currency sign in ISO 646 NO
      8'h36: begin no_unshifted = "6"; no_shifted = "&";   end
      8'h3D: begin no_unshifted = "7"; no_shifted = "/";   end
      8'h3E: begin no_unshifted = "8"; no_shifted = "(";   end
      8'h46: begin no_unshifted = "9"; no_shifted = ")";   end
      8'h45: begin no_unshifted = "0"; no_shifted = "=";   end

      // the three Norwegian letters, in their ISO 646 positions
      8'h54: begin no_unshifted = 8'h7D; no_shifted = 8'h5D; end  // D11  aa / AA
      8'h4C: begin no_unshifted = 8'h7C; no_shifted = 8'h5C; end  // C10  oe / OE
      8'h52: begin no_unshifted = 8'h7B; no_shifted = 8'h5B; end  // C11  ae / AE

      // the punctuation that moves
      8'h4E: begin no_unshifted = "+";   no_shifted = "?";   end  // E11
      8'h55: begin no_unshifted = 8'h5C; no_shifted = 8'h60; end  // \ and `
      8'h5D: begin no_unshifted = 8'h27; no_shifted = "*";   end  // C12  ' / *
      8'h41: begin no_unshifted = ",";   no_shifted = ";";   end  // B8
      8'h49: begin no_unshifted = ".";   no_shifted = ":";   end  // B9
      8'h4A: begin no_unshifted = "-";   no_shifted = 8'h5F; end  // B10  - / _
      8'h61: begin no_unshifted = "<";   no_shifted = ">";   end  // the extra ISO key US ANSI does not have

      // dead keys - shifted only, see the note above
      8'h5B: begin no_unshifted = 8'h00; no_shifted = 8'h5E; end  // D12  dead diaeresis / ^

      default: no_override = 1'b0;   // this key is the same in both layouts
    endcase
  end

  reg [7:0] us_unshifted, us_shifted;

  assign unshifted = (layout_no && no_override) ? no_unshifted : us_unshifted;
  assign shifted   = (layout_no && no_override) ? no_shifted   : us_shifted;

  always @(*) begin
    case (code)
      // --- letters ---------------------------------------------------------
      8'h1C: begin us_unshifted = "a"; us_shifted = "A"; end
      8'h32: begin us_unshifted = "b"; us_shifted = "B"; end
      8'h21: begin us_unshifted = "c"; us_shifted = "C"; end
      8'h23: begin us_unshifted = "d"; us_shifted = "D"; end
      8'h24: begin us_unshifted = "e"; us_shifted = "E"; end
      8'h2B: begin us_unshifted = "f"; us_shifted = "F"; end
      8'h34: begin us_unshifted = "g"; us_shifted = "G"; end
      8'h33: begin us_unshifted = "h"; us_shifted = "H"; end
      8'h43: begin us_unshifted = "i"; us_shifted = "I"; end
      8'h3B: begin us_unshifted = "j"; us_shifted = "J"; end
      8'h42: begin us_unshifted = "k"; us_shifted = "K"; end
      8'h4B: begin us_unshifted = "l"; us_shifted = "L"; end
      8'h3A: begin us_unshifted = "m"; us_shifted = "M"; end
      8'h31: begin us_unshifted = "n"; us_shifted = "N"; end
      8'h44: begin us_unshifted = "o"; us_shifted = "O"; end
      8'h4D: begin us_unshifted = "p"; us_shifted = "P"; end
      8'h15: begin us_unshifted = "q"; us_shifted = "Q"; end
      8'h2D: begin us_unshifted = "r"; us_shifted = "R"; end
      8'h1B: begin us_unshifted = "s"; us_shifted = "S"; end
      8'h2C: begin us_unshifted = "t"; us_shifted = "T"; end
      8'h3C: begin us_unshifted = "u"; us_shifted = "U"; end
      8'h2A: begin us_unshifted = "v"; us_shifted = "V"; end
      8'h1D: begin us_unshifted = "w"; us_shifted = "W"; end
      8'h22: begin us_unshifted = "x"; us_shifted = "X"; end
      8'h35: begin us_unshifted = "y"; us_shifted = "Y"; end
      8'h1A: begin us_unshifted = "z"; us_shifted = "Z"; end

      // --- digits and their shifted symbols (US layout) --------------------
      8'h45: begin us_unshifted = "0"; us_shifted = ")"; end
      8'h16: begin us_unshifted = "1"; us_shifted = "!"; end
      8'h1E: begin us_unshifted = "2"; us_shifted = "@"; end
      8'h26: begin us_unshifted = "3"; us_shifted = "#"; end
      8'h25: begin us_unshifted = "4"; us_shifted = "$"; end
      8'h2E: begin us_unshifted = "5"; us_shifted = "%"; end
      8'h36: begin us_unshifted = "6"; us_shifted = "^"; end
      8'h3D: begin us_unshifted = "7"; us_shifted = "&"; end
      8'h3E: begin us_unshifted = "8"; us_shifted = "*"; end
      8'h46: begin us_unshifted = "9"; us_shifted = "("; end

      // --- punctuation -----------------------------------------------------
      8'h0E: begin us_unshifted = "`";  us_shifted = "~"; end
      8'h4E: begin us_unshifted = "-";  us_shifted = "_"; end
      8'h55: begin us_unshifted = "=";  us_shifted = "+"; end
      8'h54: begin us_unshifted = "[";  us_shifted = "{"; end
      8'h5B: begin us_unshifted = "]";  us_shifted = "}"; end
      8'h5D: begin us_unshifted = "\\"; us_shifted = "|"; end
      8'h4C: begin us_unshifted = ";";  us_shifted = ":"; end
      8'h52: begin us_unshifted = "'";  us_shifted = 8'h22; end  // 0x22 = double quote
      8'h41: begin us_unshifted = ",";  us_shifted = "<"; end
      8'h49: begin us_unshifted = ".";  us_shifted = ">"; end
      8'h4A: begin us_unshifted = "/";  us_shifted = "?"; end

      // --- the control keys a console needs --------------------------------
      8'h29: begin us_unshifted = 8'h20; us_shifted = 8'h20; end  // space
      8'h5A: begin us_unshifted = 8'h0D; us_shifted = 8'h0D; end  // Enter -> CR
      8'h66: begin us_unshifted = 8'h08; us_shifted = 8'h08; end  // Backspace -> BS
      8'h0D: begin us_unshifted = 8'h09; us_shifted = 8'h09; end  // Tab -> HT
      8'h76: begin us_unshifted = 8'h1B; us_shifted = 8'h1B; end  // Esc

      // 0x00 = no character for this key. Modifiers land here too, which is
      // correct: the decoder handles them before it ever consults this table.
      default: begin us_unshifted = 8'h00; us_shifted = 8'h00; end
    endcase
  end

endmodule

`default_nettype wire

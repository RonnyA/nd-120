//============================================================================
//! PS/2 scancode set 2 -> ASCII / TDV2200 marker, unshifted and shifted
//!
//! Part of the board-independent terminal core (Verilog/Terminals/).
//! Pure combinational lookup; 0x00 out means "this key has no character".
//! Sibling of ps2_ascii_table.v (the VT100 table) - same letter/digit/
//! punctuation/Norwegian data (a keycap sends the same character on either
//! terminal), different EXTENDED and FUNCTION-KEY columns, because a TDV's
//! special keys are not VT100's.
//!
//! TERMINAL TYPE 93 (Tandberg TDV-2200/9S ND-NOTIS), not type 53 (TDV 2200/9,
//! no S) - these are different real hardware models. Ground truth, in order
//! of trust:
//!   1. RetroTerm src/RetroTerm.Core/Terminal/Emulators/TDV/TDV2200KeyRegistry.cs
//!      - the project's own corrected table (its sibling TDVKeyboardMapper.cs
//!        is legacy/VT220-shaped and explicitly disowned - do not use it).
//!   2. NDInsight Developer/Languages/Application/VTM-KEY-CODES.md section 3
//!      - measured on a live D100, terminal type 53.
//!   3. RetroTerm docs/manual-tests/FINDINGS-2026-08-20.md, "25 August 2026 -
//!      the TDV key registry checked end to end against a real ND host" - a
//!      live ND-100 check via VTM AT TYPE 93 SPECIFICALLY, 13/13 exact
//!      matches (HJELP=ESC[46_, ANGRE=ESC[30_, F3=ESC[55_, VTM codes agree).
//! All three agree exactly on the ESC[nn_ / ESC[(nn+1)_ family (shift = base
//! plus one - there is no separate modifier byte, unlike VT100's marker
//! scheme). Also confirmed on real hardware (same FINDINGS file, "M4.2d"):
//! Home really is bare GS 0x1D, not an escape sequence - SENDKEY HOME
//! transmitted GS and the cursor landed on the PED: line, "exactly the
//! documented behaviour."
//!
//! Written 31-AUG-2026.
//============================================================================

`default_nettype none

module ps2_ascii_table_tdv (
    input  wire [7:0] code,

    //! 0 = US ANSI, 1 = Norwegian (NS 4551-1). Same table as ps2_ascii_table.v.
    input  wire       layout_no,
    output wire [7:0] unshifted,
    output wire [7:0] shifted,

    //! Byte for the same scancode when it arrived with the E0 (extended)
    //! prefix. 0x00 = sends nothing.
    output reg  [7:0] extended
);

  //--------------------------------------------------------------------------
  // Extended (E0-prefixed) keys
  //
  // Arrows, Home, Delete, keypad Enter: BARE C0 BYTES on a TDV, never an
  // escape sequence (TDV2200KeyRegistry.cs: AlwaysSameCode, same byte in
  // every column). No marker/expander needed for these - they pass straight
  // through key_tdv2200.v unchanged, same as a letter.
  //
  // Insert/PageUp/PageDown/End sit on keys a real TDV keyboard does not have
  // in these positions; there is no PC-keyboard-to-TDV-grid standard to
  // follow, so these four are a deliberate, documented choice, picking the
  // PC key whose PHYSICAL LABEL matches the TDV function most naturally:
  //   PageUp   -> ROLLDN (registry: "D49 ROLLDN (Page Up, physically)")
  //   PageDown -> ROLLUP (registry: "D47 ROLLUP (Page Down, physically)")
  //   Insert   -> INNS/EXPS, the TDV's own Insert-mode toggle key (D99)
  //   End      -> SLUTT/EXIT (G54) - "slutt" is Norwegian for "end"
  // These four need the ESC[nn_ expander (key_tdv2200.v), so they carry a
  // MARKER (bit7 set) rather than a raw byte - see the marker scheme note
  // on the main table below.
  //--------------------------------------------------------------------------

  always @(*) begin
    case (code)
      8'h75:   extended = 8'h1C;  // Up     -> FS
      8'h72:   extended = 8'h0B;  // Down   -> VT
      8'h6B:   extended = 8'h08;  // Left   -> BS
      8'h74:   extended = 8'h18;  // Right  -> CAN
      8'h6C:   extended = 8'h1D;  // Home   -> GS
      8'h71:   extended = 8'h7F;  // Delete -> DEL
      8'h5A:   extended = 8'h0D;  // keypad Enter -> CR

      // ESC[nn_ family (unshifted n) - marker = 8'h80 | n, n fits 0..67 in 7 bits
      8'h7D:   extended = 8'h80 | 8'd32;  // PageUp   -> ROLLDN  ESC[32_
      8'h7A:   extended = 8'h80 | 8'd28;  // PageDown -> ROLLUP  ESC[28_
      8'h70:   extended = 8'h80 | 8'd82;  // Insert   -> INNS/EXPS ESC[82_
      8'h69:   extended = 8'h80 | 8'd48;  // End      -> SLUTT  ESC[48_

      default: extended = 8'h00;  // no TDV equivalent: send NOTHING
    endcase
  end

  //--------------------------------------------------------------------------
  // Norwegian (NS 4551-1) override - identical data to ps2_ascii_table.v.
  // See that file's header for the full rationale (position source, 7-bit
  // ISO 646 byte values, no dead-key composition).
  //--------------------------------------------------------------------------

  reg [7:0] no_unshifted, no_shifted;
  reg       no_override;

  always @(*) begin
    no_override  = 1'b1;
    no_unshifted = 8'h00;
    no_shifted   = 8'h00;
    case (code)
      8'h1E: begin no_unshifted = "2"; no_shifted = 8'h22; end
      8'h25: begin no_unshifted = "4"; no_shifted = 8'h24; end
      8'h36: begin no_unshifted = "6"; no_shifted = "&";   end
      8'h3D: begin no_unshifted = "7"; no_shifted = "/";   end
      8'h3E: begin no_unshifted = "8"; no_shifted = "(";   end
      8'h46: begin no_unshifted = "9"; no_shifted = ")";   end
      8'h45: begin no_unshifted = "0"; no_shifted = "=";   end

      8'h54: begin no_unshifted = 8'h7D; no_shifted = 8'h5D; end  // D11  aa / AA
      8'h4C: begin no_unshifted = 8'h7C; no_shifted = 8'h5C; end  // C10  oe / OE
      8'h52: begin no_unshifted = 8'h7B; no_shifted = 8'h5B; end  // C11  ae / AE

      8'h4E: begin no_unshifted = "+";   no_shifted = "?";   end
      8'h55: begin no_unshifted = 8'h5C; no_shifted = 8'h60; end
      8'h5D: begin no_unshifted = 8'h27; no_shifted = "*";   end
      8'h41: begin no_unshifted = ",";   no_shifted = ";";   end
      8'h49: begin no_unshifted = ".";   no_shifted = ":";   end
      8'h4A: begin no_unshifted = "-";   no_shifted = 8'h5F; end
      8'h61: begin no_unshifted = "<";   no_shifted = ">";   end

      8'h5B: begin no_unshifted = 8'h00; no_shifted = 8'h5E; end  // dead diaeresis / ^

      default: no_override = 1'b0;
    endcase
  end

  reg [7:0] us_unshifted, us_shifted;

  assign unshifted = (layout_no && no_override) ? no_unshifted : us_unshifted;
  assign shifted   = (layout_no && no_override) ? no_shifted   : us_shifted;

  //--------------------------------------------------------------------------
  // Main table: letters/digits/punctuation identical to ps2_ascii_table.v.
  // Function keys F1-F8 differ completely from VT100: TDV2200KeyRegistry.cs
  // has NO F1=ESC[11~ (that is the disowned VT220-shaped table) - the real
  // sequence is ESC[nn_, shift = nn+1, per key:
  //   F1=ESC[50_/51_  F2=ESC[52_/53_  F3=ESC[55_/56_  F4=ESC[58_/59_
  //   F5=ESC[60_/61_  F6=ESC[62_/63_  F7=ESC[64_/65_  F8=ESC[66_/67_
  // F9-F12 have no TDV2200/9S keyboard equivalent (an 8-function-key
  // keyboard) - mapped here to the TDV's other dedicated function keys that
  // a PC keyboard has no natural key for, so they are not wasted:
  //   F9 = HJELP (Help, G53)  ESC[46_/47_
  //   F10= FUNK  (Func-shift prefix, G51) ESC[42_/43_ - VTM then waits for
  //        the key FUNK modifies; a stray press swallows the next keystroke,
  //        which is the keyboard's design (FINDINGS-2026-08-20.md), not a bug.
  //   F11= SKRIV (Print, G52) ESC[44_/45_
  //   F12= ANGRE (Undo/Cancel, D48) ESC[30_/31_
  // The marker scheme: bit7=1 flags a TDV[nn_ sequence (safe - the ND-120
  // is 7-bit, no ASCII character has bit7 set); bits[6:0] carry n directly
  // (0..67 fits in 7 bits) - key_tdv2200.v expands marker -> ESC [ nn _.
  //--------------------------------------------------------------------------

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
      8'h52: begin us_unshifted = "'";  us_shifted = 8'h22; end
      8'h41: begin us_unshifted = ",";  us_shifted = "<"; end
      8'h49: begin us_unshifted = ".";  us_shifted = ">"; end
      8'h4A: begin us_unshifted = "/";  us_shifted = "?"; end

      // --- the control keys a console needs --------------------------------
      8'h29: begin us_unshifted = 8'h20; us_shifted = 8'h20; end  // space
      8'h5A: begin us_unshifted = 8'h0D; us_shifted = 8'h0D; end  // Enter -> CR
      8'h66: begin us_unshifted = 8'h08; us_shifted = 8'h08; end  // Backspace -> BS
      8'h0D: begin us_unshifted = 8'h09; us_shifted = 8'h09; end  // Tab -> HT
      8'h76: begin us_unshifted = 8'h1B; us_shifted = 8'h1B; end  // Esc

      // --- function keys: ESC[nn_ / ESC[(nn+1)_ marker pair -----------------
      8'h05: begin us_unshifted = 8'h80|8'd50; us_shifted = 8'h80|8'd51; end  // F1
      8'h06: begin us_unshifted = 8'h80|8'd52; us_shifted = 8'h80|8'd53; end  // F2
      8'h04: begin us_unshifted = 8'h80|8'd55; us_shifted = 8'h80|8'd56; end  // F3
      8'h0C: begin us_unshifted = 8'h80|8'd58; us_shifted = 8'h80|8'd59; end  // F4
      8'h03: begin us_unshifted = 8'h80|8'd60; us_shifted = 8'h80|8'd61; end  // F5
      8'h0B: begin us_unshifted = 8'h80|8'd62; us_shifted = 8'h80|8'd63; end  // F6
      8'h83: begin us_unshifted = 8'h80|8'd64; us_shifted = 8'h80|8'd65; end  // F7
      8'h0A: begin us_unshifted = 8'h80|8'd66; us_shifted = 8'h80|8'd67; end  // F8
      8'h01: begin us_unshifted = 8'h80|8'd46; us_shifted = 8'h80|8'd47; end  // F9  -> HJELP
      8'h09: begin us_unshifted = 8'h80|8'd42; us_shifted = 8'h80|8'd43; end  // F10 -> FUNK
      8'h78: begin us_unshifted = 8'h80|8'd44; us_shifted = 8'h80|8'd45; end  // F11 -> SKRIV
      8'h07: begin us_unshifted = 8'h80|8'd30; us_shifted = 8'h80|8'd31; end  // F12 -> ANGRE

      default: begin us_unshifted = 8'h00; us_shifted = 8'h00; end
    endcase
  end

endmodule

`default_nettype wire

#!/usr/bin/env python3
"""Generate rtl/term_banner_rom.v - the power-on message ROM.

WHY THIS IS GENERATED AND NOT HAND-WRITTEN. A message ROM in Verilog needs
two things that must agree: the characters, and how many there are. Writing
the length by hand is exactly the kind of constant that goes stale the moment
someone edits the text - and a length that is one too short silently truncates
the message, while one too long emits garbage. The generator cannot get it
wrong.

It also avoids $bits() on a packed string, which iverilog and Verilator handle
but Quartus 17's Verilog mode may not - this port has to build under three
different toolchains.

Run:  python3 font/make_banner.py
from Verilog/Terminals/. Re-run and commit the result after editing MESSAGE.
"""

import os
import sys

# CR then LF: our terminal treats 0x0D as "column 0" and 0x0A as "next line",
# exactly as the TDV does, so a line break needs BOTH. See docs/SPEC-tdv2200.md.
NL = "\r\n"

# Keep every line inside 80 columns. Nothing here should need the machine to be
# alive - this message is the proof that the VIDEO half works on its own.
MESSAGE = (
    "ND-120 TERMINAL CORE - SELF TEST" + NL +
    "80x25 TDV2200 console" + NL +
    NL +
    "If you can read this, the pixel path works:" + NL +
    "  clock, sync timing, font ROM, character RAM, scroll mapping." + NL +
    NL +
    "Now type. Characters should appear below, and the cursor should move." + NL +
    "If nothing appears, the KEYBOARD half is at fault, not the display." + NL +
    NL
)

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                   "..", "rtl", "term_banner_rom.v")

HEADER = """//============================================================================
//! Power-on message ROM for term_banner.v - GENERATED FILE, DO NOT EDIT.
//!
//! Regenerate with:  python3 font/make_banner.py   (from Verilog/Terminals/)
//! Edit the text in that script, not here.
//!
//! Part of the board-independent terminal core (Verilog/Terminals/).
//!
//! The message exists to split one failure into two. A blank screen and a
//! screen showing this text but not responding to the keyboard are completely
//! different faults, and telling them apart without this costs a build cycle -
//! which matters little on a board on the desk and a great deal when the board
//! belongs to someone in another country (see fpga/mega65/docs/00-plan.md).
//============================================================================

`default_nettype none

module term_banner_rom (
    input  wire [%(abits)d:0] addr,
    output reg  [7:0] data
);

  //! Characters in the message, for the record only. term_banner.v does NOT
  //! use this - it stops at the first 0x00, which the default branch below
  //! returns for every address past the end. That is deliberate: a length
  //! constant is a second number that can disagree with the text.
  localparam integer LEN = %(len)d;

  always @(*) begin
    case (addr)
"""

FOOTER = """      default: data = 8'h00;
    endcase
  end

endmodule

`default_nettype wire
"""


def printable(ch):
    """A comment showing the character, with the invisible ones named."""
    names = {0x0D: "CR", 0x0A: "LF", 0x20: "space"}
    code = ord(ch)
    if code in names:
        return names[code]
    if 0x21 <= code <= 0x7E:
        return ch
    return "0x%02X" % code


def main():
    msg = MESSAGE
    length = len(msg)

    for i, ch in enumerate(msg):
        if ord(ch) > 0x7F:
            sys.exit("MESSAGE character %d (%r) is not 7-bit ASCII - the font "
                     "ROM only has 128 usable glyphs" % (i, ch))
        # term_banner.v stops at the first 0x00 rather than counting, so the
        # message must not contain one. That is what makes the ROM
        # self-terminating and keeps a length constant out of the design
        # entirely - there is no second number that can disagree with the text.
        if ord(ch) == 0x00:
            sys.exit("MESSAGE contains a NUL at %d - that is the terminator" % i)

    abits = max(1, (length - 1).bit_length()) - 1
    # addr must be wide enough to reach LEN itself, since term_banner.v
    # compares against it before stopping.
    if (1 << (abits + 1)) <= length:
        abits += 1

    out = [HEADER % {"len": length, "abits": abits}]
    for i, ch in enumerate(msg):
        out.append("      %d'd%-4d: data = 8'h%02X;  // %s\n"
                   % (abits + 1, i, ord(ch), printable(ch)))
    out.append(FOOTER)

    path = os.path.normpath(OUT)
    with open(path, "w", newline="\n") as f:
        f.write("".join(out))

    print("wrote %s" % path)
    print("  %d characters, addr is %d bits" % (length, abits + 1))


if __name__ == "__main__":
    main()

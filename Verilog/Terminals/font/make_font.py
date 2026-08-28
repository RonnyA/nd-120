#!/usr/bin/env python3
"""Build an 8x16 character-generator ROM image from a Linux PSF console font.

    python3 make_font.py /usr/share/consolefonts/Lat15-VGA16.psf.gz font8x16.hex

Output is a $readmemh file: 4096 lines of two hex digits, one byte per line.
Byte (code * 16 + row) is the pixel row of the glyph for character `code`,
MSB = leftmost pixel. That is the layout `font_rom.v` expects.

Why a script and not a checked-in blob: the ROM must be regenerable, and the
font we ship has to be one whose licence we can point at. See README.md here.

PSF1 (magic 36 04) and PSF2 (magic 72 b5 4a 86) are both handled. The glyph
order in a PSF file is NOT the character code - a PSF carries a unicode table
saying which characters each glyph serves. We honour that table when it is
present, so the ROM comes out indexed by Latin-1/ASCII code as the terminal
expects. Without a table we fall back to glyph order, which is right for the
IBM-style fonts and stated in the output so nobody has to guess.
"""

import gzip
import struct
import sys

PSF1_MAGIC = b"\x36\x04"
PSF1_MODE512 = 0x01
PSF1_MODEHASTAB = 0x02
PSF2_MAGIC = b"\x72\xb5\x4a\x86"
PSF2_HAS_UNICODE = 0x01


def read_bytes(path):
    """Read the font file, transparently gunzipping a .gz."""
    opener = gzip.open if path.endswith(".gz") else open
    with opener(path, "rb") as handle:
        return handle.read()


def parse_psf(data):
    """Return (glyphs, height, width, unicode_table_or_None).

    glyphs is a list of bytes objects, one per glyph, height bytes each.
    """
    if data[:2] == PSF1_MAGIC:
        mode, charsize = data[2], data[3]
        count = 512 if (mode & PSF1_MODE512) else 256
        has_table = bool(mode & PSF1_MODEHASTAB)
        body = 4
        glyphs = [data[body + i * charsize: body + (i + 1) * charsize]
                  for i in range(count)]
        table = data[body + count * charsize:] if has_table else None
        return glyphs, charsize, 8, ("psf1", table)

    if data[:4] == PSF2_MAGIC:
        (_ver, headersize, flags, count, charsize,
         height, width) = struct.unpack("<7I", data[4:32])
        glyphs = [data[headersize + i * charsize: headersize + (i + 1) * charsize]
                  for i in range(count)]
        table = data[headersize + count * charsize:] if (flags & PSF2_HAS_UNICODE) else None
        return glyphs, height, width, ("psf2", table)

    raise SystemExit("not a PSF font (bad magic): %r" % data[:4])


def unicode_map(kind, table, glyph_count):
    """Map character code -> glyph index, from the font's unicode table.

    Returns {} when there is no table. Only codes 0..255 interest us; the
    terminal's character RAM holds a byte per cell.
    """
    if table is None:
        return {}
    mapping = {}
    if kind == "psf1":
        # sequence of 16-bit LE values per glyph, 0xFFFF terminates the glyph,
        # 0xFFFE starts a combining sequence (which we skip - single chars only)
        index, glyph = 0, 0
        skipping = False
        while index + 1 < len(table) and glyph < glyph_count:
            value = table[index] | (table[index + 1] << 8)
            index += 2
            if value == 0xFFFF:
                glyph += 1
                skipping = False
            elif value == 0xFFFE:
                skipping = True
            elif not skipping and value < 256:
                mapping.setdefault(value, glyph)
    else:
        # psf2: UTF-8 sequences, 0xFF terminates the glyph, 0xFE starts combining
        index, glyph = 0, 0
        current = bytearray()
        skipping = False
        while index < len(table) and glyph < glyph_count:
            byte = table[index]
            index += 1
            if byte == 0xFF:
                if current and not skipping:
                    try:
                        text = current.decode("utf-8")
                        if len(text) == 1 and ord(text) < 256:
                            mapping.setdefault(ord(text), glyph)
                    except UnicodeDecodeError:
                        pass
                current.clear()
                glyph += 1
                skipping = False
            elif byte == 0xFE:
                if current and not skipping:
                    try:
                        text = current.decode("utf-8")
                        if len(text) == 1 and ord(text) < 256:
                            mapping.setdefault(ord(text), glyph)
                    except UnicodeDecodeError:
                        pass
                current.clear()
                skipping = True
            else:
                current.append(byte)
    return mapping


# ---------------------------------------------------------------------------
# National variant - the SECOND font page
#
# The ND-120 is a 7-BIT machine and SINTRAN speaks ISO 646, not Latin-1. In the
# Norwegian variant (NS 4551-1) the letters AE, OE and AA do not live in some
# high range - they REPLACE the ASCII punctuation at 0x5B-0x5D and 0x7B-0x7D,
# and the currency sign replaces $ at 0x24. Confirmed from RetroTerm's
# FontTDV2200.cs, which says it outright: "The host sends 7-bit ASCII position
# bytes (e.g. '[' = 0x5B for AE)".
#
# So a national variant is not an extra character set bolted on the side - it
# CHANGES WHAT SIX EXISTING BYTES LOOK LIKE. A terminal cannot serve both from
# one page, which is why the ROM gets two: page 0 (0x00-0x7F) is US/IRV, page 1
# (0x80-0xFF) is the Norwegian variant. The board selects a page with one bit,
# so the switch on the Nexys changes the glyphs and the keyboard together.
#
# This costs nothing: the ROM was always 256 glyphs and a 7-bit machine can
# only ever address half of it.
# ---------------------------------------------------------------------------
# Synthesised block glyphs for the operator panel
#
# The panel needs bargraph and indicator cells, and the source console font has
# none that suit. They are drawn here and placed at 0x01-0x0F - control-code
# positions that a 7-bit ND machine never sends as printable characters, so
# nothing is displaced and the ASCII range is untouched.
#
# BAR_0..BAR_8 fill from the bottom, one eighth at a time, which is how the
# real panel's UTILIZATION and CACHE HIT RATE bargraphs grow. The two LEVEL
# glyphs are the ACTIVE LEVEL cells: a small filled block for a level that is
# on, a thin dash for one that is off, matching the photographed LCD where an
# unlit cell still shows faintly.
def block_glyphs():
    g = {}
    # 0x01..0x09 - bargraph, 0 to 8 eighths filled from the bottom
    for n in range(0, 9):
        rows = []
        for r in range(16):
            # r counts from the top; fill the bottom (n*2) rows
            rows.append(0x7E if r >= 16 - n * 2 else 0x00)
        g[0x01 + n] = bytes(rows)
    # 0x0A - ACTIVE LEVEL cell, lit
    g[0x0A] = bytes([0x00]*3 + [0x3C]*10 + [0x00]*3)
    # 0x0B - ACTIVE LEVEL cell, unlit (the faint ghost segment)
    g[0x0B] = bytes([0x00]*7 + [0x3C] + [0x00]*8)
    # 0x0C - solid block, for rules and the LCD surround
    g[0x0C] = bytes([0xFF]*16)
    # 0x0D - thin horizontal rule, vertically centred
    g[0x0D] = bytes([0x00]*7 + [0xFF] + [0x00]*8)
    return g


NATIONAL_VARIANTS = {
    # ISO 646 position -> the Unicode codepoint to draw there
    "no": {
        0x24: 0x00A4,  # currency sign replaces $
        0x5B: 0x00C6,  # AE
        0x5C: 0x00D8,  # OE
        0x5D: 0x00C5,  # AA
        0x7B: 0x00E6,  # ae
        0x7C: 0x00F8,  # oe
        0x7D: 0x00E5,  # aa
    },
}


def main():
    if len(sys.argv) != 3:
        raise SystemExit(__doc__)
    src, dst = sys.argv[1], sys.argv[2]

    glyphs, height, width, (kind, table) = parse_psf(read_bytes(src))
    if height != 16 or width != 8:
        raise SystemExit("need an 8x16 font; this one is %dx%d" % (width, height))

    mapping = unicode_map(kind, table, len(glyphs))
    blank = bytes(16)

    def glyph_for(codepoint):
        """The 16 bytes for a Unicode codepoint, or a blank box."""
        if mapping:
            idx = mapping.get(codepoint)
        else:
            idx = codepoint if codepoint < len(glyphs) else None
        return glyphs[idx] if idx is not None else None

    # Page 0: plain 7-bit ASCII / ISO 646 IRV, plus the panel block glyphs in
    # the control-code slots.
    blocks = block_glyphs()
    page0 = []
    for code in range(128):
        if code in blocks:
            page0.append(blocks[code])
            continue
        g = glyph_for(code)
        page0.append(g if g is not None else blank)

    # Page 1: the same, with the national substitutions applied.
    variant = NATIONAL_VARIANTS["no"]
    page1 = list(page0)
    substituted, absent = [], []
    for pos, codepoint in sorted(variant.items()):
        g = glyph_for(codepoint)
        if g is None:
            # Say so rather than silently leaving the ASCII glyph in place - a
            # silent fallback would draw '[' where the machine means AE, which
            # is exactly the bug this page exists to prevent.
            absent.append((pos, codepoint))
        else:
            page1[pos] = g
            substituted.append(pos)

    rom = page0 + page1

    with open(dst, "w", encoding="ascii", newline="\n") as out:
        out.write("// 8x16 character generator ROM, generated by make_font.py\n")
        out.write("// source: %s\n" % src)
        out.write("// index = character code * 16 + pixel row; MSB = leftmost pixel\n")
        out.write("// character->glyph mapping: %s\n"
                  % ("from the font's unicode table"
                     if mapping else "glyph order (font carried no table)"))
        for glyph in rom:
            for row in glyph:
                out.write("%02x\n" % row)

    # Space (0x20) is legitimately all-zero, so it is excluded from the check -
    # counting it as "missing" produced a false warning on a perfectly good font.
    missing = [code for code in range(0x21, 0x7F) if rom[code] == blank]
    print("wrote %s: 2 pages x 128 glyphs x 16 rows" % dst)
    print("panel block glyphs at 0x01-0x0D (bargraph, level cells, rules)")
    print("norwegian page: substituted %s"
          % " ".join("0x%02X" % p for p in substituted))
    if absent:
        print("WARNING: the source font has no glyph for %s - the Norwegian page"
              % " ".join("U+%04X (for 0x%02X)" % (c, p) for p, c in absent))
        print("         still shows the ASCII character there, which is WRONG")
    print("printable ASCII (0x21-0x7E) present: %d of 94" % (94 - len(missing)))
    if missing:
        print("WARNING: blank glyphs for %s - check the mapping"
              % " ".join("0x%02x" % code for code in missing))


if __name__ == "__main__":
    main()

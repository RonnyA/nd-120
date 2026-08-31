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
            elif not skipping and value < 0x3000:
                # Kept up to U+2FFF, not just Latin-1: the DEC Special
                # Graphics page wants box-drawing (U+25xx) and friends.
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
                        if len(text) == 1 and ord(text) < 0x3000:
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
                        if len(text) == 1 and ord(text) < 0x3000:
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
    # ACTIVE LEVEL lamps. A lamp spans TWO character cells, so it needs a left
    # half and a right half rather than one glyph used twice:
    #
    #   narrow glyph (0x3C) in both halves -> a gap down the MIDDLE of every
    #     lamp, which reads as two small boxes per level
    #   full width (0xFF) in both halves   -> 16 px with no gap at all, and the
    #     row of lamps runs together into one continuous bar
    #
    # Blanking only the OUTER pixel of each half gives 14 lit pixels per lamp
    # with a 2 px gap to its neighbour: one solid box per level, clearly
    # separated. 0x7F drops the leftmost pixel (MSB is leftmost), 0xFE the
    # rightmost.
    g[0x0A] = bytes([0x00]*3 + [0x7F]*10 + [0x00]*3)   # lit, left half
    g[0x0E] = bytes([0x00]*3 + [0xFE]*10 + [0x00]*3)   # lit, right half
    g[0x0B] = bytes([0x00]*7 + [0x7F] + [0x00]*8)      # unlit, left half
    g[0x0F] = bytes([0x00]*7 + [0xFE] + [0x00]*8)      # unlit, right half
    # 0x0C - solid block, for rules and the LCD surround
    g[0x0C] = bytes([0xFF]*16)
    # 0x0D - thin horizontal rule, vertically centred
    g[0x0D] = bytes([0x00]*7 + [0xFF] + [0x00]*8)
    return g


# ---------------------------------------------------------------------------
# DEC Special Graphics - the THIRD font page (VT100 line drawing)
#
# Designated with ESC ( 0 / ESC ) 0 and selected with SO/SI; it is how a VT100
# draws boxes, and SINTRAN's full-screen tools use it (PED's init sends
# ESC ) 0). Codes 0x00-0x5E render as ASCII; 0x5F is blank; 0x60-0x7E are the
# graphics. The line/corner/tee/cross/scan-line glyphs are SYNTHESIZED here -
# they are geometry, and synthesizing them means the page exists whatever PSF
# font is used. The symbol glyphs (degree, plus-minus, pi, ...) are taken from
# the source font's unicode table when it has them, from the hand bitmaps
# below when it does not, and only then blank (with a warning).
# ---------------------------------------------------------------------------

def dec_graphics_page(page0, glyph_for):
    """The 128 glyphs of the DEC Special Graphics set."""
    blank = bytes(16)

    # Line-drawing pieces. One-pixel strokes through the cell centre: the
    # vertical runs down column 4 (bit 0x08, MSB = leftmost = column 0), the
    # horizontal along pixel row 8. The four half-strokes union into every
    # corner, tee and the cross - build them once, OR them together.
    V_BIT, H_ROW = 0x08, 8

    def draw(up=False, down=False, left=False, right=False):
        rows = [0] * 16
        if up:
            for r in range(0, H_ROW + 1):
                rows[r] |= V_BIT
        if down:
            for r in range(H_ROW, 16):
                rows[r] |= V_BIT
        if left:
            rows[H_ROW] |= 0xF8  # columns 0-4
        if right:
            rows[H_ROW] |= 0x0F  # columns 4-7
        return bytes(rows)

    def hline(row):
        rows = [0] * 16
        rows[row] = 0xFF
        return bytes(rows)

    # Hand bitmaps for the symbols a Latin console font may not carry.
    HAND = {
        0x25C6: bytes([0, 0, 0, 0x18, 0x3C, 0x7E, 0xFF, 0xFF,
                       0x7E, 0x3C, 0x18, 0, 0, 0, 0, 0]),          # diamond
        0x2592: bytes([0xAA, 0x55] * 8),                            # checker
        0x00B0: bytes([0, 0, 0x38, 0x44, 0x44, 0x38, 0, 0,
                       0, 0, 0, 0, 0, 0, 0, 0]),                    # degree
        0x00B1: bytes([0, 0, 0, 0x10, 0x10, 0x7C, 0x10, 0x10,
                       0, 0x7C, 0, 0, 0, 0, 0, 0]),                 # plus-minus
        0x03C0: bytes([0, 0, 0, 0, 0, 0x7E, 0x24, 0x24,
                       0x24, 0x24, 0x24, 0x24, 0, 0, 0, 0]),        # pi
        0x2260: bytes([0, 0, 0, 0x02, 0x04, 0x7E, 0x18, 0x7E,
                       0x20, 0x40, 0, 0, 0, 0, 0, 0]),              # not equal
        0x2264: bytes([0, 0, 0x0C, 0x18, 0x30, 0x60, 0x30, 0x18,
                       0x0C, 0, 0x7E, 0, 0, 0, 0, 0]),              # <=
        0x2265: bytes([0, 0, 0x30, 0x18, 0x0C, 0x06, 0x0C, 0x18,
                       0x30, 0, 0x7E, 0, 0, 0, 0, 0]),              # >=
        0x00B7: bytes([0, 0, 0, 0, 0, 0, 0, 0x18,
                       0x18, 0, 0, 0, 0, 0, 0, 0]),                 # centre dot
        0x00A3: None,  # pound - font only; the hand version is not worth it
    }

    def symbol(codepoint):
        g = glyph_for(codepoint)
        if g is None:
            g = HAND.get(codepoint)
        return g  # may be None - the caller records the gap

    absent = []

    def sym(code, codepoint):
        g = symbol(codepoint)
        if g is None:
            absent.append((code, codepoint))
            return blank
        return g

    page = list(page0[:0x5F])          # 0x00-0x5E render as ASCII
    page.append(blank)                 # 0x5F is blank in this set
    page += [
        sym(0x60, 0x25C6),             # ` diamond
        sym(0x61, 0x2592),             # a checkerboard
        blank, blank, blank, blank,    # b-e HT/FF/CR/LF pictures - not drawn:
                                       #   status-display oddities nothing in
                                       #   the ND world ever writes
        sym(0x66, 0x00B0),             # f degree
        sym(0x67, 0x00B1),             # g plus/minus
        blank, blank,                  # h-i NL/VT pictures - same as b-e
        draw(up=True, left=True),      # j lower-right corner
        draw(down=True, left=True),    # k upper-right corner
        draw(down=True, right=True),   # l upper-left corner
        draw(up=True, right=True),     # m lower-left corner
        draw(up=True, down=True, left=True, right=True),  # n cross
        hline(1),                      # o scan line 1
        hline(4),                      # p scan line 3
        draw(left=True, right=True),   # q scan line 5 (the centre line)
        hline(11),                     # r scan line 7
        hline(14),                     # s scan line 9
        draw(up=True, down=True, right=True),  # t left tee
        draw(up=True, down=True, left=True),   # u right tee
        draw(up=True, left=True, right=True),  # v bottom tee
        draw(down=True, left=True, right=True),  # w top tee
        draw(up=True, down=True),      # x vertical bar
        sym(0x79, 0x2264),             # y less-or-equal
        sym(0x7A, 0x2265),             # z greater-or-equal
        sym(0x7B, 0x03C0),             # { pi
        sym(0x7C, 0x2260),             # | not equal
        sym(0x7D, 0x00A3),             # } pound sterling
        sym(0x7E, 0x00B7),             # ~ centre dot
        blank,                         # 0x7F
    ]
    assert len(page) == 128
    return page, absent


# ---------------------------------------------------------------------------
# TDV2200 Box - the FOURTH font page
#
# Designated with the bare two-byte "ESC 6" (NDSS6, Verilog/Terminals/docs/
# SPEC-tdv2200.md) - NOT VT100's three-byte "ESC ( 0". Needed because SINTRAN
# draws box screens (SCONF confirmed live, 31-AUG-2026: cell 0x60 rendered as
# a literal backtick instead of a top-left corner) using this set, not the
# VT100 DEC Special Graphics one page 2 already carries.
#
# Mapping at 0x60-0x7E per RetroTerm's TDVCharacterSets.cs (Box dictionary,
# cross-checked byte for byte against the SCONF screen capture: 0x60/'`' sat
# where a top-left corner belongs, 0x67/'g' where a light up+horizontal tee
# belongs, 0x6A/'j' where a vertical bar belongs - all three match exactly).
# Light box-drawing reuses the same one-pixel-stroke primitives as the DEC
# Special Graphics page; heavy is a 3-pixel stroke, double is two parallel
# 1-pixel strokes 3 pixels apart - both are geometry, synthesized the same
# way as page 2's corners rather than sourced from a font, for the same
# reason: the page exists whatever PSF font is used.
# ---------------------------------------------------------------------------

def tdv_box_page(page0):
    """The 128 glyphs of the TDV2200 Box character set."""
    blank = bytes(16)
    V_BIT, H_ROW = 0x08, 8  # centre column (MSB=leftmost, bit 0x08=col 4), centre row

    def light(up=False, down=False, left=False, right=False):
        rows = [0] * 16
        if up:
            for r in range(0, H_ROW + 1):
                rows[r] |= V_BIT
        if down:
            for r in range(H_ROW, 16):
                rows[r] |= V_BIT
        if left:
            rows[H_ROW] |= 0xF8
        if right:
            rows[H_ROW] |= 0x0F
        return bytes(rows)

    def light_hline():
        rows = [0] * 16
        rows[H_ROW] = 0xFF
        return bytes(rows)

    def light_vline():
        return light(up=True, down=True)

    # Heavy: a 3-pixel-wide stroke (columns 3-5 vertical, rows 7-9 horizontal)
    # instead of light's 1-pixel stroke - visibly bolder at 8x16.
    HV_BITS = 0x1C  # columns 3-5
    def heavy(up=False, down=False, left=False, right=False):
        rows = [0] * 16
        if up:
            for r in range(0, H_ROW + 2):
                rows[r] |= HV_BITS
        if down:
            for r in range(H_ROW - 1, 16):
                rows[r] |= HV_BITS
        if left:
            for r in range(H_ROW - 1, H_ROW + 2):
                rows[r] |= 0xFC
        if right:
            for r in range(H_ROW - 1, H_ROW + 2):
                rows[r] |= 0x1F
        return bytes(rows)

    def heavy_hline():
        rows = [0] * 16
        for r in range(H_ROW - 1, H_ROW + 2):
            rows[r] = 0xFF
        return bytes(rows)

    def heavy_vline():
        return heavy(up=True, down=True)

    # Double: two parallel light strokes either side of centre.
    def double(up=False, down=False, left=False, right=False):
        rows = [0] * 16
        vbits = 0x0A  # columns 3 and 5 (either side of centre column 4)
        if up:
            for r in range(0, H_ROW - 1):
                rows[r] |= vbits
            for r in range(0, H_ROW + 2):
                rows[r] |= vbits
        if down:
            for r in range(H_ROW + 2, 16):
                rows[r] |= vbits
            for r in range(H_ROW - 1, 16):
                rows[r] |= vbits
        if left:
            rows[H_ROW - 1] |= 0xF8
            rows[H_ROW + 1] |= 0xF8
        if right:
            rows[H_ROW - 1] |= 0x0F
            rows[H_ROW + 1] |= 0x0F
        return bytes(rows)

    page = list(page0[:0x60])           # 0x00-0x5F render as ASCII
    page += [
        light(down=True, right=True),   # 0x60 ` - down+right (top-left corner)
        light(down=True, left=True),    # 0x61 a - down+left (top-right corner)
        light(up=True, right=True),     # 0x62 b - up+right (bottom-left corner)
        light(up=True, left=True),      # 0x63 c - up+left (bottom-right corner)
        light(up=True, down=True, right=True),  # 0x64 d - vertical+right
        light(up=True, down=True, left=True),   # 0x65 e - vertical+left
        light(down=True, left=True, right=True),  # 0x66 f - down+horizontal
        light(up=True, left=True, right=True),    # 0x67 g - up+horizontal
        light(up=True, down=True, left=True, right=True),  # 0x68 h - cross
        light_hline(),                  # 0x69 i - horizontal
        light_vline(),                  # 0x6A j - vertical
        heavy(down=True, right=True),   # 0x6B k
        heavy(down=True, left=True),    # 0x6C l
        heavy(up=True, right=True),     # 0x6D m
        heavy(up=True, left=True),      # 0x6E n
        heavy(up=True, down=True, right=True),  # 0x6F o
        heavy(up=True, down=True, left=True),   # 0x70 p
        heavy(down=True, left=True, right=True),  # 0x71 q
        heavy(up=True, left=True, right=True),    # 0x72 r
        heavy(up=True, down=True, left=True, right=True),  # 0x73 s
        heavy_hline(),                  # 0x74 t
        heavy_vline(),                  # 0x75 u
        double(down=True, right=True),  # 0x76 v
        double(down=True, left=True),   # 0x77 w
        double(up=True, right=True),    # 0x78 x
        double(up=True, left=True),     # 0x79 y
        double(up=True, down=True, right=True),  # 0x7A z
        double(up=True, down=True, left=True),   # 0x7B {
        double(down=True, left=True, right=True),  # 0x7C |
        double(up=True, left=True, right=True),    # 0x7D }
        double(up=True, down=True, left=True, right=True),  # 0x7E ~
        blank,                          # 0x7F
    ]
    assert len(page) == 128
    return page


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

    # Page 2: DEC Special Graphics - the VT100 line-drawing set.
    page2, gfx_absent = dec_graphics_page(page0, glyph_for)

    # Page 3: TDV2200 Box - the TDV2200 line-drawing set (ESC 6 / NDSS6).
    page3 = tdv_box_page(page0)

    rom = page0 + page1 + page2 + page3

    with open(dst, "w", encoding="ascii", newline="\n") as out:
        out.write("// 8x16 character generator ROM, generated by make_font.py\n")
        out.write("// source: %s\n" % src)
        out.write("// page 0: US/ISO 646 IRV  page 1: Norwegian NS 4551-1\n")
        out.write("// page 2: DEC Special Graphics (VT100 line drawing)\n")
        out.write("// page 3: TDV2200 Box (ESC 6 / NDSS6 line drawing)\n")
        out.write("// index = page * 2048 + code * 16 + pixel row; MSB = leftmost pixel\n")
        out.write("// character->glyph mapping: %s\n"
                  % ("from the font's unicode table"
                     if mapping else "glyph order (font carried no table)"))
        for glyph in rom:
            for row in glyph:
                out.write("%02x\n" % row)

    # Space (0x20) is legitimately all-zero, so it is excluded from the check -
    # counting it as "missing" produced a false warning on a perfectly good font.
    missing = [code for code in range(0x21, 0x7F) if rom[code] == blank]
    print("wrote %s: 4 pages x 128 glyphs x 16 rows" % dst)
    if gfx_absent:
        print("WARNING: DEC graphics page is blank at %s - neither the font nor"
              % " ".join("0x%02X (U+%04X)" % (p, c) for p, c in gfx_absent))
        print("         the hand bitmaps had a glyph")
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

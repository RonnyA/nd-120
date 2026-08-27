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


def main():
    if len(sys.argv) != 3:
        raise SystemExit(__doc__)
    src, dst = sys.argv[1], sys.argv[2]

    glyphs, height, width, (kind, table) = parse_psf(read_bytes(src))
    if height != 16 or width != 8:
        raise SystemExit("need an 8x16 font; this one is %dx%d" % (width, height))

    mapping = unicode_map(kind, table, len(glyphs))
    blank = bytes(16)

    rom = []
    for code in range(256):
        if mapping:
            glyph_index = mapping.get(code)
        else:
            glyph_index = code if code < len(glyphs) else None
        rom.append(glyphs[glyph_index] if glyph_index is not None else blank)

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
    print("wrote %s: 256 glyphs x 16 rows" % dst)
    print("printable ASCII (0x21-0x7E) present: %d of 94" % (94 - len(missing)))
    if missing:
        print("WARNING: blank glyphs for %s - check the mapping"
              % " ".join("0x%02x" % code for code in missing))


if __name__ == "__main__":
    main()

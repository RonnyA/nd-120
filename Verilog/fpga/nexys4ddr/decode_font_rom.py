# Reconstruct the 8192-byte font ROM from the two x4 RAMB36 INIT strings and
# show what alphabet sits on each silicon page. Ground truth for the shift.
import sys
init = {}   # (cell, idx) -> 64-hex-char string (nibble per address, MSB-first)
for line in open("font_init_lines.txt"):
    cell, key, val = line.split()
    idx = int(key.split("_")[1], 16)   # 0..0x7F
    init[(cell, idx)] = val.rjust(64, "0")

def nibble(cell, A):
    # A: 0..8191. INIT index = A//64, position within = A%64.
    s = init[(cell, A // 64)]
    pos = A % 64                 # bits [pos*4 +: 4]
    return int(s[63 - pos], 16)  # MSB-first hex string

def rom_byte(A, hi="pixels_reg_1", lo="pixels_reg_0"):
    return (nibble(hi, A) << 4) | nibble(lo, A)

def glyph(page, code, hi, lo):
    base = page*2048 + code*16
    return [rom_byte(base + r, hi, lo) for r in range(16)]

def show(g):
    return " ".join("%02x" % b for b in g)

# Determine nibble order by matching page 0 'A' (0x41) - a US ASCII 'A' has a
# recognisable shape. Try both hi/lo orders; pick the one whose page-0 0x20..0x7e
# looks like text (many distinct non-zero glyphs, code 0x20 space = all zero).
for hi, lo in [("pixels_reg_1","pixels_reg_0"), ("pixels_reg_0","pixels_reg_1")]:
    sp = glyph(0, 0x20, hi, lo)   # space should be all zero
    A  = glyph(0, 0x41, hi, lo)   # 'A'
    print("ORDER hi=%s lo=%s : page0 0x20(space)=%s  0x41(A)=%s" %
          (hi[-1], lo[-1], show(sp), show(A)))

print()
# Use the order where space is all-zero.
def pick_order():
    for hi, lo in [("pixels_reg_1","pixels_reg_0"), ("pixels_reg_0","pixels_reg_1")]:
        if all(b == 0 for b in glyph(0, 0x20, hi, lo)):
            return hi, lo
    return "pixels_reg_1","pixels_reg_0"
hi, lo = pick_order()
print("USING hi=%s lo=%s\n" % (hi, lo))

# For each silicon page, print code 0x60 (the box horizontal / backtick / diamond)
# and 0x67, so the alphabet is identifiable.
names = {0x60:"0x60", 0x67:"0x67", 0x61:"0x61", 0x6a:"0x6a", 0x41:"0x41(A)"}
for page in range(4):
    print("=== silicon PAGE %d ===" % page)
    for code in (0x41, 0x60, 0x61, 0x67, 0x6a):
        print("  %-7s %s" % (names[code], show(glyph(page, code, hi, lo))))

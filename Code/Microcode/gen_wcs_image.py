#!/usr/bin/env python3
"""
Generate a pre-loaded Writable Control Store (WCS) image from the two ND-120
microcode PROM hex files, so the WCS can be $readmemh'd directly and the runtime
WCS-load phase (LCS_n sequence) can be skipped.

Full path: /mnt/e/Dev/Repos/Ronny/nd-120/Code/Microcode/gen_wcs_image.py

Data mapping (verified against RTL):
  - AM27256_45132L.hex = LO byte (bits 7:0),  AM27256_45133L.hex = HI byte (15:8)
  - PROM byte index      idx = LUA*4 + RF          (s_Address = {LUA_12_0, RF_1_0})
  - 16-bit PROM read     P(LUA,RF) = (hi[idx]<<8) | lo[idx]
  - 64-bit microword     word[LUA] = { P(RF=3), P(RF=2), P(RF=1), P(RF=0) }
                         RF=0 -> bits[15:0] ... RF=3 -> bits[63:48]  (no remap)
  - WCS geometry: 2 banks x 16 nibble chips (IDT6168A, 4096x4).
      bank C (16C..31C) = lower, LUA 0..4095 ; bank D (16D..31D) = upper, 4096..8191
      chip (16+j) holds bits [63-4j : 60-4j]  (16 -> [63:60], 31 -> [3:0])

Outputs (into ./wcs/):
  - wcs_image.hex        : 8192 lines x 16 hex digits (unified, for inspection /
                           a single-BRAM WCS rewrite)
  - wcs_<16..31><C|D>.hex : 32 files x 4096 lines x 1 hex nibble (per IDT6168A chip)
"""
import os

HERE = os.path.dirname(os.path.abspath(__file__))
OUT  = os.path.join(HERE, "wcs")

def read_bytes(name):
    with open(os.path.join(HERE, name)) as f:
        toks = f.read().split()
    vals = [int(t, 16) for t in toks]
    assert len(vals) == 32768, f"{name}: expected 32768 bytes, got {len(vals)}"
    return vals

def main():
    lo = read_bytes("AM27256_45132L.hex")   # bits 7:0
    hi = read_bytes("AM27256_45133L.hex")   # bits 15:8

    words = []
    for lua in range(8192):
        w = 0
        for rf in range(4):
            idx = lua * 4 + rf
            p16 = (hi[idx] << 8) | lo[idx]
            w |= p16 << (16 * rf)            # RF=0 -> LSB group
        words.append(w)

    os.makedirs(OUT, exist_ok=True)

    # Unified 64-bit image
    with open(os.path.join(OUT, "wcs_image.hex"), "w") as f:
        for w in words:
            f.write(f"{w:016x}\n")

    # 32 per-chip nibble files
    for bank, (name, lo_lua, hi_lua) in enumerate(
            [("C", 0, 4096), ("D", 4096, 8192)]):
        for j in range(16):                  # chip 16+j -> bits [63-4j : 60-4j]
            shift = 60 - 4 * j
            chip = 16 + j
            with open(os.path.join(OUT, f"wcs_{chip}{name}.hex"), "w") as f:
                for lua in range(lo_lua, hi_lua):
                    nib = (words[lua] >> shift) & 0xF
                    f.write(f"{nib:x}\n")

    # Sanity report
    nonzero = sum(1 for w in words if w != 0)
    print(f"WCS image: 8192 words, {nonzero} non-zero")
    print(f"  word[0x0000] = {words[0]:016x}   (master-clear entry)")
    print(f"  word[0x0001] = {words[1]:016x}")
    print(f"  word[0x0401] = {words[0x0401]:016x}   (o02001, first real exec)")
    print(f"  wrote wcs_image.hex + 32 per-chip files to {OUT}")

if __name__ == "__main__":
    main()

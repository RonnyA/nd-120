#!/usr/bin/env python3
"""Generate the floppy-boot test image + expected RAM-check line.

Boot sector layout (512 words, the autoload unit):
  word 0     = 0151000 octal (ND-100 WAIT) - the booted CPU parks
               immediately, leaving the loaded memory intact
  words 1..  = pattern (0x1234 + 3*i) & 0xFFFF
The rest of the image is zero-filled to one full diskette.

Usage: gen_fboot_img.py <image-out> <expected-line-out> [nwords]
"""
import sys

img_path, exp_path = sys.argv[1], sys.argv[2]
nwords = int(sys.argv[3]) if len(sys.argv) > 3 else 16

words = [0o151000] + [(0x1234 + 3 * i) & 0xFFFF for i in range(1, 512)]

with open(img_path, "wb") as f:
    for w in words:
        f.write(bytes([(w >> 8) & 0xFF, w & 0xFF]))
    f.write(b"\x00" * (1261568 - 2 * len(words)))

with open(exp_path, "w") as f:
    f.write("[binload] RAM check @000000:")
    for w in words[:nwords]:
        f.write(" %06o" % w)
    f.write("\n")
print("generated", img_path, "and", exp_path)

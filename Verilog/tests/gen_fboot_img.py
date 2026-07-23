#!/usr/bin/env python3
"""Generate the floppy-boot BPUN diskette + expected RAM-check line.

The '1560&' mass boot is the BPUN loader reading the boot stream from
the device data register - the diskette stores ONE STREAM BYTE PER
16-BIT WORD (low byte). This generator emits a minimal BPUN:
  leader "1!", load address E, word count, data words, checksum,
  execute address = E (autostart).
Program at E (octal 2000, clear of OPCOM's low-RAM scratch area):
SAA 77 / STA +11 / WAIT - executed proof is the value 000077 stored
near E, checked via the RAM dump.

Usage: gen_fboot_img.py <image-out> <expected-line-out>
"""
import sys

img_path, exp_path = sys.argv[1], sys.argv[2]

E = 0o2000
prog = [0o170477, 0o004011, 0o151000]  # SAA 77 / STA +11 / WAIT
count = len(prog)
checksum = sum(prog) & 0xFFFF

stream = bytearray()
# leader: octal digits accumulate into C, CR shifts C into B - so
# "2000\r2000!" gives B = C = 0o2000 (B = the start address)
stream += b"2000\r2000!"
def w16(v):
    stream.append((v >> 8) & 0xFF)
    stream.append(v & 0xFF)
w16(E)
w16(count)
for w in prog:
    w16(w)
w16(checksum)
w16(0)                                # action word: 0 = AUTOSTART (at B)

with open(img_path, "wb") as f:
    for b in stream:                  # one stream byte per 16-bit word
        f.write(bytes([0, b]))
    f.write(b"\x00" * (1261568 - 2 * len(stream)))

# expected RAM dump at E (16 words): prog, zeros, then 000077 at the
# STA target. STA is at E+1 with displacement 011 -> P-relative target
# E+1+011 = E+012 (index 10 within the dump window).
words = prog + [0] * 13
words[10] = 0o77
with open(exp_path, "w") as f:
    f.write("[binload] RAM check @002000:")
    for w in words[:16]:
        f.write(" %06o" % w)
    f.write("\n")
print("generated", img_path, "and", exp_path)

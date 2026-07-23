#!/usr/bin/env python3
# Pack an nd100-as/nd100-ld a.out16 into a deposit-loadable BPUN (load 01000,
# no autostart; start from MOPC with "1000!"). Usage: mk_bpun.py prog prog.BPUN
import struct, sys
data = open(sys.argv[1], "rb").read()
ntext = struct.unpack("<H", data[2:4])[0]
words = [struct.unpack("<H", data[16+2*i:18+2*i])[0] for i in range(ntext)]
E = 0o1000
out = bytearray(b"1000\r!") + struct.pack(">H", E) + struct.pack(">H", len(words))
s = 0
for w in words:
    out += struct.pack(">H", w)
    s = (s + w) & 0xFFFF
out += struct.pack(">H", s) + struct.pack(">H", 0)
open(sys.argv[2], "wb").write(bytes(out))
print("%s: %d words at %06o" % (sys.argv[2], len(words), E))

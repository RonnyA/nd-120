#!/usr/bin/env python3
"""Standalone LBYT/SBYT test program for the ND-120 (prints its own result).

WHY: FILSYS LIST-FILE-NAMES on the Nexys 4 DDR runs away exactly where the
oracle's trace shows it scanning file names with LBYT (P=057021: LBYT /
AAA -47 / JAZ). All data in memory is proven correct there, so the
suspect is the byte instruction itself on that board.

WHAT: T/X point at two known words at 003000: 052105 ("TE") 051515 ("SM").
The program does LBYT for X = 0,1,2,3 and prints each byte, then SBYT a
byte (0o101 'A') into X=1 and prints the resulting word. Output line:
    L bbbbbb bbbbbb bbbbbb bbbbbb W wwwwww
Golden values come from the oracle run (nd100x), not from assumptions
about T/X byte-addressing semantics.

Encodings verified against nd100x src/cpu/cpu_disasm.c: LBYT 142200,
SBYT 142600, LDT 050000, LDX 054000; the rest as in
tests/floppy-dma-test/gen_floppy_dma_test.py.
Usage: gen_lbyt_test.py <deposits-out.txt>
"""
import sys
ORG = 0o2000
DATA = 0o3000
code = []; labels = {}; fixups = []
def emit(w): code.append(w)
def label(n): labels[n] = ORG + len(code)
def memref(op, t, I=False):
    fixups.append((len(code), op | (0o1000 if I else 0), t)); emit(0)
def LDA(t, I=False): memref(0o044000, t, I)
def STA(t, I=False): memref(0o004000, t, I)
def LDT(t): memref(0o050000, t)
def LDX(t): memref(0o054000, t)
def AND(t): memref(0o070000, t)
def ORA(t): memref(0o074000, t)
def JPL(t): memref(0o134000, t)
def JAZ(t): memref(0o131000, t)
def SAA(n): emit(0o170400 | (n & 0xFF))
def IOX(d): emit(0o164000 | d)
def SHA_ZIN_SHR(n): emit(0o154400 | 0o2000 | ((64 - n) & 0o77))
def COPY(s, d): emit(0o146100 | (s << 3) | d)
SL, SA, DL, DA = 4, 5, 4, 5
def EXIT(): emit(0o146142)
def WAIT(): emit(0o151000)
def LBYT(): emit(0o142200)
def SBYT(): emit(0o142600)

label('START')
LDA('cCHL'); JPL('PUTC')
for x in range(4):
    LDT('cT'); LDX('cX%d' % x); LBYT(); JPL('POCT')
LDA('cCHW'); JPL('PUTC')
LDT('cT'); LDX('cX1'); LDA('cBYTE'); SBYT()
LDA('pD0', I=True); JPL('POCT')
LDA('cCR'); JPL('PUTC'); LDA('cLF'); JPL('PUTC')
WAIT()
for n, v in [('cT', DATA), ('cX0', 0), ('cX1', 1), ('cX2', 2), ('cX3', 3),
             ('cBYTE', 0o101), ('pD0', DATA), ('cCHL', 0o114), ('cCHW', 0o127),
             ('cCR', 0o15), ('cLF', 0o12)]:
    label(n); emit(v)
label('POCT')
STA('vPV'); COPY(SL, DA); STA('vRET')
for sh in (15, 12, 9, 6, 3):
    LDA('vPV'); SHA_ZIN_SHR(sh); AND('cSEVEN'); ORA('cC60'); JPL('PUTC')
LDA('vPV'); AND('cSEVEN'); ORA('cC60'); JPL('PUTC')
LDA('cSP'); JPL('PUTC')
LDA('vRET'); COPY(SA, DL); EXIT()
label('PUTC')
STA('vCH')
label('PUTW')
IOX(0o306); SHA_ZIN_SHR(3); AND('cONE'); JAZ('PUTW')
LDA('vCH'); IOX(0o305); EXIT()
for n, v in [('vPV', 0), ('vRET', 0), ('vCH', 0), ('cSEVEN', 7), ('cC60', 0o60),
             ('cSP', 0o40), ('cONE', 1)]:
    label(n); emit(v)
for idx, op, t in fixups:
    d = labels[t] - (ORG + idx); assert -128 <= d <= 127, t
    code[idx] = op | (d & 0xFF)
out = sys.argv[1] if len(sys.argv) > 1 else 'deposits.txt'
with open(out, 'w') as f:
    for i, w in enumerate(code): f.write(f"{ORG+i:06o} {w:06o}\n")
    f.write(f"{DATA:06o} 052105\n{DATA+1:06o} 051515\n")
print(f"{len(code)} words at {ORG:o}; data at {DATA:o}; start 2000!")

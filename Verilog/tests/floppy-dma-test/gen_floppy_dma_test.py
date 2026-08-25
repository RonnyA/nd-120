#!/usr/bin/env python3
"""Standalone floppy-DMA test program for the ND-120 (no OPCOM interaction
while running - the program prints its own results on the console).

WHAT IT DOES
------------
Replays exactly the FILSYS operation that fails on the Nexys 4 DDR:
a 12-word command block (READ, format 3, diskAddress 0, 2 sectors,
buffer 061100) pre-deposited at 003000, activated via IOX 1565/1567/1563
with control word 1403 - then polls status word 1 (IOX 1562) for the
ready-for-transfer bit, and prints in octal:

    S ssssss   status register (IOX 1562) at completion (or T ssssss on timeout)
    E eeeeee   command block word 6 = status 1 written back by DMA
    F ffffff   command block word 7 = status 2 written back by DMA
    B b0 b1 b2 b3  first four words of the data buffer at 061100

Expected values for a HEALTHY read of FLOPPY1.IMG sector 0 (format 3):
    B 000060 000057 000062 000015   (bytes 30 2F 32 0D, one byte per word
                                     pair: words 0030 002F 0032 000D)
    E has error code 0 in bits 9-14.
The Nexys failure signature would be E with error code oct 20-ish
(RANGE via the adapter) and B all zeros.

All instruction encodings verified against the nd100x disassembler
(src/cpu/cpu_disasm.c) - LDA 044000, STA 004000, JAZ 131000, JAF 131400,
JPL 134000, IOX 164000|dev, SAA 170400, SHA 154400 (ZIN 0x400, 6-bit
two's-complement count), AND 070000, SUB 064000, ORA 074000, WAIT 151000,
COPY = RADD CLD = 0146100|src<<3|dst (SL=4, SA=5, DP=2, DL=4, DA=5),
EXIT 146142. Terminal: IOX 306 read output status (bit 3 = ready),
IOX 305 write data.

Usage: gen_floppy_dma_test.py <deposits-out.txt>
Output: one "aaaaaa vvvvvv" octal pair per line (address, value), ready
for an OPCOM deposit loader. Start the program with "2000!".
"""
import sys

ORG = 0o2000
CB  = 0o3000
# Variant (argv[2] == 'boot'): replay the 1560& stage-1 bootstrap's FIRST
# operation exactly as the oracle issues it (nd100x DEBUG_FLOPPY_DMA trace):
# WORD-COUNT mode (CB w4 bit 15 set, 0o2000 = 1024 words), control word
# 0o400 (execute only, no interrupt), READ fmt3 diskAddress 0. Target moved
# to 0o20000 so the transfer cannot overwrite this program at 0o2000.
BOOT_VARIANT = len(sys.argv) > 2 and sys.argv[2] == 'boot'
BUF = 0o20000 if BOOT_VARIANT else 0o61100

code = []          # list of (label-or-None, callable/int)
labels = {}
fixups = []        # (index, kind, target-label)

def emit(word):        code.append(word)
def label(name):       labels[name] = ORG + len(code)

def memref(op, target, indirect=False):
    """P-relative memory reference; displacement resolved in pass 2."""
    fixups.append((len(code), op | (0o1000 if indirect else 0), target))
    emit(0)

def LDA(t, I=False):  memref(0o044000, t, I)
def STA(t, I=False):  memref(0o004000, t, I)
def AND(t):           memref(0o070000, t)
def ADD(t):           memref(0o060000, t)
def ORA(t):           memref(0o074000, t)
def SUB(t):           memref(0o064000, t)
def JMP(t):           memref(0o124000, t)
def JPL(t):           memref(0o134000, t)
def JAZ(t):           memref(0o131000, t)
def JAF(t):           memref(0o131400, t)
def SAA(n):           emit(0o170400 | (n & 0xFF))
def AAA(n):           emit(0o172400 | (n & 0xFF))
def IOX(dev):         emit(0o164000 | dev)
def SHA_ZIN_SHR(n):   emit(0o154400 | 0o2000 | ((64 - n) & 0o77))
def COPY(src, dst):   emit(0o146100 | (src << 3) | dst)
SL, SA = 4, 5
DP, DL, DA = 2, 4, 5
def EXIT():           emit(0o146142)
def WAIT():           emit(0o151000)

# ---------------- program ----------------
# P-relative displacements only reach +/-128 words, so constants live in
# THREE local pools, each next to the code that uses them (small constants
# are duplicated per pool on purpose).
label('START')
SAA(0)
IOX(0o1565)            # command block pointer HI = 0
LDA('cCBP')
IOX(0o1567)            # command block pointer LO = 003000
LDA('cCW')
IOX(0o1563)            # control word (1403 FILSYS-style / 400 boot-style)
LDA('cLOOPS')
STA('vCNT')
label('POLL')
IOX(0o1562)            # read status word 1
STA('vST')
SHA_ZIN_SHR(3)
AND('cONE')
JAF('RDY')             # bit 3 = ready for transfer
LDA('vCNT')
SUB('cONE')
STA('vCNT')
JAF('POLL')
LDA('cCHT')            # timeout marker 'T'
JMP('SHOW')
label('RDY')
LDA('cCHS')            # 'S'
JMP('SHOW')

for name, val in [
    ('cCBP',   CB),
    ('cCW',    0o400 if BOOT_VARIANT else 0o1403),
    ('cLOOPS', 0o77777),
    ('cONE',   1),
    ('cCHT',   0o124),    # 'T'
    ('cCHS',   0o123),    # 'S'
]:
    label(name)
    emit(val)

label('SHOW')          # A holds the status letter on entry
JPL('PUTC')
LDA('vST')
JPL('POCT')
LDA('cCHE')            # 'E' + CB word 6
JPL('PUTC')
LDA('pCB6', I=True)
JPL('POCT')
LDA('cCHF')            # 'F' + CB word 7
JPL('PUTC')
LDA('pCB7', I=True)
JPL('POCT')
LDA('cCHB')            # 'B' + buffer words 0..3
JPL('PUTC')
LDA('pBUF0', I=True)
JPL('POCT')
LDA('pBUF1', I=True)
JPL('POCT')
LDA('pBUF2', I=True)
JPL('POCT')
LDA('pBUF3', I=True)
JPL('POCT')
# checksum the WHOLE transfer (catches lost/misplaced DMA writes anywhere):
# sum of the first 1024 words at BUF, printed after 'C'
LDA('cBUFP')
STA('vPTR')
SAA(0)
STA('vSUM')
LDA('cNWORDS')
STA('vCNT2')
label('CSLOOP')
LDA('vPTR', I=True)
ADD('vSUM')
STA('vSUM')
LDA('vPTR')
AAA(1)
STA('vPTR')
LDA('vCNT2')
SUB('cONE2')
STA('vCNT2')
JAF('CSLOOP')
LDA('cCHC')
JPL('PUTC')
LDA('vSUM')
JPL('POCT')
LDA('cCR')
JPL('PUTC')
LDA('cLF')
JPL('PUTC')
WAIT()

for name, val in [
    ('vST',    0),
    ('vCNT',   0),
    ('cCHE',   0o105),    # 'E'
    ('cCHF',   0o106),    # 'F'
    ('cCHB',   0o102),    # 'B'
    ('cCHC',   0o103),    # 'C'
    ('cCR',    0o15),
    ('cLF',    0o12),
    ('pCB6',   CB + 6),
    ('pCB7',   CB + 7),
    ('pBUF0',  BUF),
    ('pBUF1',  BUF + 1),
    ('pBUF2',  BUF + 2),
    ('pBUF3',  BUF + 3),
    ('cBUFP',  BUF),
    ('cNWORDS', 1024),
    ('cONE2',  1),
    ('vPTR',   0),
    ('vSUM',   0),
    ('vCNT2',  0),
]:
    label(name)
    emit(val)

# print A as 6 octal digits + space (clobbers A; preserves caller's L)
label('POCT')
STA('vPV')
COPY(SL, DA)
STA('vRET')
for sh in (15, 12, 9, 6, 3):
    LDA('vPV')
    SHA_ZIN_SHR(sh)
    AND('cSEVEN')
    ORA('cC60')
    JPL('PUTC')
LDA('vPV')
AND('cSEVEN')
ORA('cC60')
JPL('PUTC')
LDA('cSP')
JPL('PUTC')
LDA('vRET')
COPY(SA, DL)
EXIT()

# print char in A (busy-waits on terminal output ready, IOX 306 bit 3)
label('PUTC')
STA('vCH')
label('PUTW')
IOX(0o306)
SHA_ZIN_SHR(3)
AND('cONE3')
JAZ('PUTW')
LDA('vCH')
IOX(0o305)
EXIT()

for name, val in [
    ('vPV',    0),
    ('vRET',   0),
    ('vCH',    0),
    ('cSEVEN', 7),
    ('cC60',   0o60),     # '0'
    ('cSP',    0o40),     # ' '
    ('cONE3',  1),
]:
    label(name)
    emit(val)

# ---------------- pass 2: resolve P-relative displacements ----------------
for idx, op, target in fixups:
    pc = ORG + idx
    disp = labels[target] - pc
    assert -128 <= disp <= 127, f"{target} out of P-relative range at {pc:o} (disp {disp})"
    code[idx] = op | (disp & 0xFF)

# ---------------- command block (deposited data, not code) ----------------
if BOOT_VARIANT:
    cb_words = [0o7400, 0, 0, BUF, 0o100000, 0o2000, 0, 0, 0, 0, 0, 0]
else:
    cb_words = [0o7400, 0, 0, BUF, 0, 2, 0, 0, 0, 0, 0, 0]

out = sys.argv[1] if len(sys.argv) > 1 else 'deposits.txt'
with open(out, 'w') as f:
    for i, w in enumerate(code):
        f.write(f"{ORG + i:06o} {w:06o}\n")
    for i, w in enumerate(cb_words):
        f.write(f"{CB + i:06o} {w:06o}\n")
print(f"{len(code)} program words at {ORG:o}, {len(cb_words)} CB words at {CB:o}")
print(f"deposit file: {out}")
print(f"start with: 2000!")

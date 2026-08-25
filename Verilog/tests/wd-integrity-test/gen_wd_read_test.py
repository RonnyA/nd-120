#!/usr/bin/env python3
# NOTE (25-AUG): the loop-mode / MA-hi variants are mid-refactor and the
# REPORT block exceeds the 8-bit P-relative reach to PUTC (needs a PUTC
# trampoline). The base config (argv: out FIRSTBLK NBLK) and the deposits
# already generated under tests/wd-integrity-test/ are valid; regenerate
# advanced variants only after adding the trampoline.
"""Standalone Winchester read-integrity test for the ND-120 (no OPCOM
interaction while running - the program prints its own results).

WHY IT EXISTS (24-AUG-2026)
---------------------------
The Nexys 4 DDR `&` boot dies non-deterministically: sometimes the SINTRAN
Winchester driver is handed ILLEGAL function code 0o13 (-> ERRFATAL DILLC,
proven by the ERRFA evidence probe), sometimes the machine hangs silently.
A garbage function code means the memory the resident was DMA-loaded into
holds wrong words. This program tests the disc path with NO SINTRAN at all:

  For each of NBLK blocks starting at FIRSTBLK:
    read the block TWICE (word count 0o2000, the mass-load microcode's own
    parameters) into two different buffers, compare word-by-word, and print

      K bbbbbb M mmmmmm C cccccc

    (block, mismatch count between the two reads, checksum of read 1).
    If M is ever nonzero the disc path is NON-DETERMINISTIC - the exact
    corruption class the boot shows. If M stays zero but C differs from the
    same block's checksum computed from the image file, the corruption is
    DETERMINISTIC (wrong data, same every time).
  Ends with "DN" and WAIT; "T ssssss" = status-poll timeout, aborted.

Winchester card: IOX 500-507 (ND-11.015.01): +1 W load MA (HI 8 first,
then LO 16), +3 W block address, +7 W word count, +5 W control
(0o4 = ACTIVE, device operation M0 read), +4 R status (bit3 = finished).

Instruction encodings identical to gen_floppy_dma_test.py (verified against
the nd100x disassembler there).

Usage: gen_wd_read_test.py <deposits-out.txt> [FIRSTBLK-octal] [NBLK-octal]
Output: one "aaaaaa vvvvvv" octal pair per line. Start with "2000!".
"""
import sys

ORG  = 0o2000
BUF1 = int(sys.argv[4], 8) if len(sys.argv) > 4 else 0o20000
BUF2 = int(sys.argv[5], 8) if len(sys.argv) > 5 else 0o24000
NW   = 0o2000            # words per read, same as the mass-load microcode
FIRSTBLK = int(sys.argv[2], 8) if len(sys.argv) > 2 else 0
NBLK     = int(sys.argv[3], 8) if len(sys.argv) > 3 else 0o30
GOWORD   = int(sys.argv[6], 8) if len(sys.argv) > 6 else 0o4
LOOPMODE = len(sys.argv) > 8 and sys.argv[8] == 'loop'
MAHI     = int(sys.argv[9], 8) if len(sys.argv) > 9 else 0
NW       = int(sys.argv[7], 8) if len(sys.argv) > 7 else NW

code = []
labels = {}
fixups = []

def emit(word):        code.append(word)
def label(name):       labels[name] = ORG + len(code)

def memref(op, target, indirect=False):
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

# ---------------- main ----------------
label('START')
LDA('cFB');  STA('vBLK')
LDA('cNB');  STA('vNB')

label('BLKLOOP')
LDA('cB1');  JPL('DOREAD')       # read 1 -> BUF1
IOX(0o500)                       # MA readback LOW 16 (first access)
STA('vMAL')
IOX(0o500)                       # MA readback HIGH 8 (second access)
STA('vMAH')

LDA('cB2');  JPL('DOREAD')       # read 2 -> BUF2

# compare + checksum
LDA('cB1');  STA('vP1')
LDA('cB2');  STA('vP2')
SAA(0);      STA('vMIS'); STA('vSUM')
LDA('cNW');  STA('vC')
label('CMPLOOP')
LDA('vP1', I=True); STA('vW1')
ADD('vSUM');        STA('vSUM')
LDA('vP2', I=True); SUB('vW1')
JAZ('CMPOK')
LDA('vMIS'); AAA(1); STA('vMIS')
label('CMPOK')
LDA('vP1'); AAA(1); STA('vP1')
LDA('vP2'); AAA(1); STA('vP2')
LDA('vC');  SUB('cONE'); STA('vC')
JAF('CMPLOOP')
JMP('REPORT')

for name, val in [
    ('cFB',  FIRSTBLK), ('cNB', NBLK), ('cB1', BUF1), ('cB2', BUF2),
    ('cNW',  NW), ('cONE', 1),
    ('vBLK', 0), ('vNB', 0), ('vP1', 0), ('vP2', 0),
    ('vMIS', 0), ('vSUM', 0), ('vC', 0), ('vW1', 0), ('vMAL', 0), ('vMAH', 0), ('vANOM', 0),
]:
    label(name)
    emit(val)

label('REPORT')
if LOOPMODE:
    # quiet sweeps: only impossible-status counts are reported
    LDA('vANOM')
    JAZ('RNEXT')
    LDA('cCHX'); JPL('PUTC')
    LDA('vANOM'); JPL('POCT')
    LDA('cCR'); JPL('PUTC')
    LDA('cLF'); JPL('PUTC')
    SAA(0); STA('vANOM')
    label('RNEXT')
else:
    LDA('cCHK'); JPL('PUTC')
    LDA('vBLK'); JPL('POCT')
    LDA('cCHM'); JPL('PUTC')
    LDA('vMIS'); JPL('POCT')
    LDA('cCHC'); JPL('PUTC')
    LDA('vSUM'); JPL('POCT')
    LDA('cCHA'); JPL('PUTC')
    LDA('vMAL'); JPL('POCT')
    LDA('cCHH'); JPL('PUTC')
    LDA('vMAH'); JPL('POCT')
    LDA('cCHA'); JPL('PUTC')
    LDA('vMAL2'); JPL('POCT')
    LDA('cCR');  JPL('PUTC')
    LDA('cLF');  JPL('PUTC')
LDA('vBLK'); AAA(1); STA('vBLK')
LDA('vNB');  SUB('cONE1'); STA('vNB')
JAF('BLKLOOP')
if LOOPMODE:
    # heartbeat 'S' each full sweep, then run forever
    LDA('cCHS2'); JPL('PUTC')
    JMP('START')
else:
    LDA('cCHD'); JPL('PUTC')
    LDA('cCHN'); JPL('PUTC')
    LDA('cCR');  JPL('PUTC')
    LDA('cLF');  JPL('PUTC')
    WAIT()


for name, val in [
    ('cCHK', 0o113),   # 'K'
    ('cCHM', 0o115),   # 'M'
    ('cCHC', 0o103),   # 'C'
    ('cCHD', 0o104),   # 'D'
    ('cCHX', 0o130),   # 'X'
    ('cCHS2', 0o123),  # 'S'
    ('cCHA', 0o101),   # 'A'
    ('cCHH', 0o110),   # 'H'
    ('cCHN', 0o116),   # 'N'
    ('cCR',  0o15), ('cLF', 0o12), ('cONE1', 1),
]:
    label(name)
    emit(val)

# ---- DOREAD: A = buffer address. Reads block vBLK (NW words) there. ----
# No nested JPL inside, so L is safe. Times out -> prints T + status, WAIT.
label('DOREAD')
STA('vMA')
LDA('cMAHI'); IOX(0o501)         # MA HI 8 (first access) = bank select (argv 9)
LDA('vMA');  IOX(0o501)          # MA LO 16 (second access)
LDA('vBLK2', I=False)            # placeholder replaced below
code.pop(); fixups.pop()         # (use the main vBLK via long constant)
LDA('pBLK', I=True)              # A = vBLK (indirect through pointer)
IOX(0o503)                       # block address
LDA('cNW2');  IOX(0o507)         # word count
SAA(GOWORD);  IOX(0o505)         # control: ACTIVE, M0 read (+bit0 int-en per argv)
LDA('cTO');   STA('vTC')
label('RPOLL')
IOX(0o306)                       # console output status - a SECOND device
STA('vCS')                       # on the OR-bus between every WD read
IOX(0o504)
STA('vST2')
AND('cIMPOS')                    # bit15/bit12 are never set in a real 3041
JAZ('STOK')                      # status word: count impossible reads
LDA('vANOM'); AAA(1); STA('vANOM')
label('STOK')
LDA('vST2')
SHA_ZIN_SHR(3)
AND('cONE2')
JAF('RDONE')                     # bit 3 = finished
LDA('vTC'); SUB('cONE2'); STA('vTC')
JAF('RPOLL')
LDA('cCHT');  JPL('PUTC')        # timeout: 'T' + status, halt
IOX(0o504);   JPL('POCT')
WAIT()
label('RDONE')
EXIT()

for name, val in [
    ('vMA', 0), ('vTC', 0), ('cNW2', NW), ('cONE2', 1), ('cMAHI', MAHI),
    ('vST2', 0), ('vCS', 0), ('cIMPOS', 0o110000),
    ('cTO', 0o77777), ('cCHT', 0o124),
]:
    label(name)
    emit(val)
label('pBLK')
emit(0)          # -> vBLK, patched in pass 2 below

# print A as 6 octal digits + space (saves/restores L)
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

# print char in A (busy-wait on IOX 306 bit 3)
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
    ('vPV', 0), ('vRET', 0), ('vCH', 0),
    ('cSEVEN', 7), ('cC60', 0o60), ('cSP', 0o40), ('cONE3', 1),
]:
    label(name)
    emit(val)

# ---------------- pass 2 ----------------
for idx, op, target in fixups:
    pc = ORG + idx
    disp = labels[target] - pc
    assert -128 <= disp <= 127, f"{target} out of P-relative range at {pc:o} (disp {disp})"
    code[idx] = op | (disp & 0xFF)

# pBLK -> absolute address of vBLK
code[labels['pBLK'] - ORG] = labels['vBLK']

out = sys.argv[1] if len(sys.argv) > 1 else 'deposits_wd.txt'
with open(out, 'w') as f:
    for i, w in enumerate(code):
        f.write(f"{ORG + i:06o} {w:06o}\n")
print(f"{len(code)} program words at {ORG:o}; blocks {FIRSTBLK:o}..{FIRSTBLK+NBLK-1:o}")
print(f"deposit file: {out}; start with 2000!")

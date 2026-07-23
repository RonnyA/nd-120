#!/usr/bin/env python3
"""Generate the DEMOCORE driver: a BPUN diskette that makes the ND-120 CPU
drive the NDDeviceCore portable nd_lineprinter core over the REAL bus RTL.

WHY A FLOPPY BPUN AND NOT SINTRAN: the CPU-boot / SINTRAN path is under
repair, so this gate must not depend on it. The '1560&' floppy mass boot is
an already-proven, self-contained loader (tests/gen_fboot_img.py +
`make test-floppy-boot`): the DMA floppy controller autoloads the BPUN and
AUTOSTARTS it on the bare machine, no OS involved. We reuse that mechanism
verbatim and only change the program that gets loaded.

THE PROGRAM (loaded at octal 2000, autostarted):

    SAA 4          ; control word: bit2 = activate
    IOX 0433       ; write control -> printer active + ready for transfer
  per character C:
    SAA C          ; A = the character
    IOX 0431       ; write data buffer -> the core queues a PUT on nd_char
  poll:
    IOX 0432       ; A = status word
    AND mask       ; isolate status bit 3 (ready for transfer)
    JAZ poll       ; not ready yet -> keep polling
  after the last character:
    SAA 77
    STA marker     ; executed-proof value, visible in the RAM dump
    WAIT
    JMP self       ; belt and braces if WAIT falls through

Register map / base address / ident come from NDDeviceCore's
include/nd_lineprinter.h + src/nd_lineprinter.c (thumbwheel 0 -> base 0430
octal, +0 read data, +1 write data, +2 read status, +3 write control,
ident 03, interrupt level 10) - NOT from memory.

Opcodes (ND-100, all one word):
    SAA n   170400+n        AND ea  070000+disp (mode 0 = P-relative)
    IOX d   164000+d        JAZ d   131000+disp
    STA ea  004000+disp     WAIT    151000
    JMP ea  124000+disp
Mode-0 effective address = (address of the instruction) + 1 + disp, which is
exactly what tests/gen_fboot_img.py's STA +11 relies on.

Usage: gen_democore_img.py <image-out> <text-to-print>
"""
import sys

img_path = sys.argv[1]
text = sys.argv[2] if len(sys.argv) > 2 else "ND120"

E = 0o2000                      # load + start address (same as the floppy gate)

SAA  = 0o170400
IOX  = 0o164000
AND  = 0o070000
JAZ  = 0o131000
STA  = 0o004000
WAIT = 0o151000
JMP  = 0o124000

LP_BASE      = 0o430            # nd_lineprinter thumbwheel 0
LP_WRITEDATA = LP_BASE + 1      # 0431
LP_READSTAT  = LP_BASE + 2      # 0432
LP_WRITECTRL = LP_BASE + 3      # 0433

READY_BIT = 1 << 3              # status b3 = ready for transfer


def disp8(value):
    """8-bit signed displacement field."""
    if not -128 <= value <= 127:
        raise ValueError("displacement %d out of 8-bit range" % value)
    return value & 0xFF


prog = []                       # list of ints OR ('fix', kind, target_name)
fixups = []                     # (index, opcode, target_label)
labels = {}


def emit(word):
    prog.append(word)


def emit_ref(opcode, label):
    """Emit a mode-0 instruction whose displacement points at `label`."""
    fixups.append((len(prog), opcode, label))
    prog.append(0)


# --- activate the printer -------------------------------------------------
emit(SAA | 0o4)                 # control: activate (bit 2)
emit(IOX | LP_WRITECTRL)

# --- print each character, polling ready-for-transfer between them --------
for ch in text:
    code = ord(ch)
    if not 0 <= code <= 127:
        raise ValueError("character %r is not 7-bit" % ch)
    emit(SAA | code)            # SAA takes an 8-bit signed immediate; 0..127 fits
    emit(IOX | LP_WRITEDATA)
    poll_at = len(prog)
    emit(IOX | LP_READSTAT)
    emit_ref(AND, "mask")
    fixups.append((len(prog), JAZ, ("@abs", poll_at)))
    prog.append(0)

# --- executed-proof marker + halt ----------------------------------------
emit(SAA | 0o77)
emit_ref(STA, "marker")
emit(WAIT)
selfloop = len(prog)
fixups.append((len(prog), JMP, ("@abs", selfloop)))
prog.append(0)

# --- data ----------------------------------------------------------------
labels["mask"] = len(prog)
emit(READY_BIT)
labels["marker"] = len(prog)
emit(0)

# --- resolve ---------------------------------------------------------------
for idx, opcode, target in fixups:
    if isinstance(target, tuple):
        tgt = target[1]
    else:
        tgt = labels[target]
    prog[idx] = opcode | disp8(tgt - (idx + 1))

count = len(prog)
checksum = sum(prog) & 0xFFFF

# --- BPUN stream (byte-for-byte the shape gen_fboot_img.py proved) --------
stream = bytearray()
stream += b"2000\r2000!"        # leader: sets B = C = 2000 (the start address)


def w16(v):
    stream.append((v >> 8) & 0xFF)
    stream.append(v & 0xFF)


w16(E)
w16(count)
for w in prog:
    w16(w)
w16(checksum)
w16(0)                          # action word: 0 = AUTOSTART at B

with open(img_path, "wb") as f:
    for b in stream:            # the diskette stores ONE stream byte per word
        f.write(bytes([0, b]))
    f.write(b"\x00" * (1261568 - 2 * len(stream)))

print("generated %s: %d words, prints %r via IOX %04o" %
      (img_path, count, text, LP_WRITEDATA))
for i, w in enumerate(prog):
    print("  %06o: %06o" % (E + i, w))

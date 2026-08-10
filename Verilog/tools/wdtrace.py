#!/usr/bin/env python3
"""Decode the TANG_WD_TRACE_DUMP stream and diff it against the C-model oracle.

The Tang build streams 64 lines of five hex digits when the WD IOX trace
triggers (ND120_TANG20K_TOP.v, `TANG_WD_TRACE_DUMP):

    digit 1     = {rw, register offset}   rw 1 = write, so 0-7 read, 8-F write
    digits 2-5  = the 16-bit value written or returned

The oracle is the same File System Investigator run under nd100x with
ND100X_WD_DEBUG=1 against the same WD0.IMG (see the memory note
fsi-winchester-oracle-nd100x). Its lines look like

    WD: IOX WRITE addr=505 reg=5 value=34005
    WD: IOX READ  addr=504 reg=4 -> 60005

Usage:
    wdtrace.py captured.txt                 # decode only
    wdtrace.py captured.txt oracle.txt      # decode and diff
"""
import re
import sys

REG_NAME = {
    0: "mem addr readback",
    1: "mem addr load",
    2: "-",
    3: "block address",
    4: "status",
    5: "control word",
    6: "block addr readback",
    7: "word count",
}


# Probe-mode tags (9, B, F) COLLIDE with ordinary register writes: in the
# default IOX trace a top nibble of 9 is WRITE +1 (memory address), B is
# WRITE +3 (block address) and F is WRITE +7 (WORD COUNT). Only one trace
# mode is compiled into a build, so the stream cannot say which it is - the
# reader must. Default to IOX, because that is the mode that matters and
# because decoding a word-count write as an "engine state" hid the cause of
# a SINTRAN boot failure for one whole capture (10-AUG-2026).
PROBE_TAGS = False


def decode_capture(path):
    """Every 5-hex-digit line in the file, oldest first.

    ND_WINCHESTER.v's trace_rec packs FIVE different record kinds, not two.
    Reading it as rw+register only was wrong and made two silicon dumps look
    like garbage before it was noticed (09-AUG-2026). From the RTL:

        {1'b1, reg[2:0], wdata}   register WRITE   top nibble 8..F
        {1'b0, reg[2:0], rdata}   register READ    top nibble 0..7
        {4'h8, IDENT_CODE}        IDENT answered   -- NOTE: collides with
                                  write-to-reg-0, disambiguated below
        {4'hA, 15'd0, irq}        interrupt edge
        {4'hC, iox_addr}          FOREIGN IOX - another device's address
                                  going past on the bus, not this card

    The 4'h8 IDENT record is indistinguishable from a write to register 0
    carrying the ident code as data; register 0 is the memory-address
    readback and is never written, so a top nibble of 8 is read as IDENT.
    Records are returned as (kind, a, b) with kind in
    {"W", "R", "IDENT", "IRQ", "FOREIGN"}.
    """
    out = []
    for raw in open(path):
        tok = raw.strip()
        if not re.fullmatch(r"[0-9a-fA-F]{5}", tok):
            continue
        v = int(tok, 16)
        top = (v >> 16) & 0xF
        val = v & 0xFFFF
        if top == 0xC:
            out.append(("FOREIGN", None, val))
        elif top == 0xA:
            out.append(("IRQ", None, val & 1))
        elif top == 0x8:
            out.append(("IDENT", None, val))
        elif top == 0xF and PROBE_TAGS:
            # Engine state change. Like tag 9 this MUST be tested before the
            # `top & 0x8` write branch, which would decode it as WRITE +7.
            out.append(("ESTATE", None, val))
        elif top == 0xB and PROBE_TAGS:
            out.append(("PIL", None, val & 0xF))
        elif top == 0x9 and PROBE_TAGS:
            # Unanswered IDENT cycle. Must be tested BEFORE the `top & 0x8`
            # write branch below, which would otherwise decode it as a
            # nonexistent WRITE +1.
            out.append(("NOIDENT", None, val))
        elif top & 0x8:
            out.append(("W", top & 7, val))
        else:
            out.append(("R", top & 7, val))
    return out


def decode_oracle(path):
    out = []
    for raw in open(path):
        m = re.search(r"IOX (WRITE|READ)\s+addr=(\d+)\s+reg=(\d+)\s+"
                      r"(?:value=|-> )([0-7]+)", raw)
        if m:
            kind = "W" if m.group(1) == "WRITE" else "R"
            out.append((kind, int(m.group(3)), int(m.group(4), 8)))
    return out


def fmt(rec):
    kind, reg, val = rec
    if kind == "FOREIGN":
        return "%-7s %-23s IOX %06o (another device)" % ("foreign", "", val)
    if kind == "IRQ":
        return "%-7s %-23s level-11 line -> %d" % ("irq", "", val)
    if kind == "IDENT":
        return "%-7s %-23s ident %06o" % ("IDENT", "", val)
    if kind == "ESTATE":
        names = {0:"E_IDLE",1:"E_GRANT",2:"E_OPEN",3:"R_MEM",4:"R_WAIT",
                 5:"R_PUSH_HI",6:"R_PUSH_LO",7:"W_PULL",8:"W_SEC_GO",
                 9:"W_SEC_WAIT",10:"W_MEM",11:"W_MEM_WAIT",12:"E_DONE",
                 13:"C_LOOK",14:"C_SEC_GO",15:"C_SEC_WAIT",16:"C_ALLOC",
                 17:"F_RES",18:"F_STEP",19:"F_FAT_GO",20:"F_FAT_WAIT"}
        st = val & 0x1F
        return "%-7s %-23s client=%d state=%s" % (
            "engine", "", (val >> 5) & 7, names.get(st, "?%d" % st))
    if kind == "PIL":
        return "%-7s %-23s CPU priority interrupt level -> %d" % ("PIL", "",
                                                                  val)
    if kind == "NOIDENT":
        return "%-7s %-23s IDENT cycle NOT answered: grant_in=%d irq=%d " \
               "level=%d" % ("no-id", "", (val >> 5) & 1, (val >> 4) & 1,
                             val & 0xF)
    arrow = "=" if kind == "W" else "->"
    return "%-7s +%d %-20s %s %06o" % (
        "WRITE" if kind == "W" else "READ", reg, REG_NAME.get(reg, "?"),
        arrow, val)


def main():
    global PROBE_TAGS
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    if "--probe" in sys.argv:
        PROBE_TAGS = True
        sys.argv.remove("--probe")
    cap = decode_capture(sys.argv[1])
    if not cap:
        sys.exit("no 5-hex-digit trace lines found in %s" % sys.argv[1])

    print("--- captured from silicon (%d accesses, oldest first) ---" % len(cap))
    for i, r in enumerate(cap):
        print("%3d  %s" % (i, fmt(r)))

    if len(sys.argv) < 3:
        return

    ora = decode_oracle(sys.argv[2])
    print("\n--- oracle (%d accesses) ---" % len(ora))

    # The ring holds only the LAST 64 accesses, so align on the oracle's tail
    # only if the capture is shorter; otherwise compare from the start.
    print("\n--- first divergence ---")
    n = min(len(cap), len(ora))
    for i in range(n):
        if cap[i] != ora[i]:
            print("index %d" % i)
            lo = max(0, i - 3)
            for j in range(lo, min(n, i + 4)):
                mark = ">>" if j == i else "  "
                print("%s %3d  silicon: %-46s oracle: %s"
                      % (mark, j, fmt(cap[j]), fmt(ora[j])))
            return
    print("no divergence in the first %d accesses" % n)


if __name__ == "__main__":
    main()

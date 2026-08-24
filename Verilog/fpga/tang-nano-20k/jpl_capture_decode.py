#!/usr/bin/env python3
"""Decode a TANG_JPL_CAPTURE dump: the microcode trail across the two JPL calls.

WHAT THIS SETTLES

    The Tang executes 064540..064547 straight through and takes neither of the
    two JPL I 111 calls at 064544/064545 that the oracle takes (to 004600 and
    052031, 170 instructions). Measured over three runs, program counter only.

    A story that FITS is that the decode lost instruction bit 11 - the only bit
    separating JPL (134000-137000) from the conditional jumps (130000-133000).
    135111 would become 131111, JAZ 111, and with A = 144017 that does not jump.
    But that is a GUESS, and it has a hole: SINTRAN executes JPL constantly for
    the 150 seconds before this point, so bit 11 cannot be generally lost.

    This decodes the MEASUREMENT that replaces the guess: which microroutine
    the decode actually dispatched to.

WIRE FORMAT

    5 hex digits per line, oldest first. Top nibble is the tag:

        tag 0   CSA_12_0, the microcode address (13 bits)
        tag 1   the fetch-qualified program counter

    Only changes are recorded, so consecutive identical values collapse.

MICROCODE ENTRY POINTS (Verilog/tests/instruction-verify/ND110-ND120-MIC-MAP.md)
"""

import argparse
import re
import sys

ENTRY_RE = re.compile(r"^([0-9A-Fa-f]{5})\s*$")

JUMP_GROUP = {
    0o007300: "JAP", 0o007304: "JAN", 0o007310: "JAZ", 0o007314: "JAF",
    0o007320: "JPC", 0o007324: "JNC", 0o007330: "JXZ", 0o007334: "JXN",
    0o007340: "JPL",
}
JPL_ENTRY = 0o007340

# PAL_44445B.v:65-67 - the CPU-side bank decode, from PPN21 and PPN20:
#   BANK0_n = PPN21 | PPN20        -> BANK0 when 00
#   BANK2_n = PPN21 | PPN20_n      -> BANK2 when 01
#   BANK1_n = PPN21_n | PPN20      -> BANK1 when 10
#   11 selects NO bank at all.
# MEM_RAM_49_SDRAM.v:18 and :415 - on the Tang, BANK1 is NOT POPULATED:
# "never written, reads as 0", and the access is dropped in B_TAIL.
BANK_OF = {
    0b00: "BANK0 (populated)",
    0b01: "BANK2 (populated)",
    0b10: "BANK1 (NOT POPULATED - reads as 0)",
    0b11: "NO BANK (reads as 0)",
}
JPL_PC = 0o064544


def parse_dump(text):
    """Return [(tag, value), ...] oldest first."""
    out = []
    for line in text.splitlines():
        m = ENTRY_RE.match(line.strip())
        if not m:
            continue
        w = int(m.group(1), 16)
        out.append(((w >> 16) & 0xF, w & 0xFFFF))
    return out


def report(entries, out=sys.stdout):
    if not entries:
        print("no entries found - is this the right log?", file=out)
        return 1

    print(f"{len(entries)} entries, oldest first\n", file=out)
    print(f"{'idx':>4}  {'what':<4}  {'value':>8}  note", file=out)
    print(f"{'':->4}  {'':-<4}  {'':->8}  {'':-<40}", file=out)

    seen_jump = []
    fid_words = []
    ppn_words = []
    cur_pc = None
    for i, (tag, val) in enumerate(entries):
        if tag == 1:
            cur_pc = val
            note = "program counter"
            if val == JPL_PC:
                note += "   <-- the first JPL I 111"
            print(f"{i:>4}  {'pc':<4}  {val:>8o}  {note}", file=out)
        elif tag == 3:
            # PPN[23:10]. PPN20 = bit 10, PPN21 = bit 11 - the bank-decode
            # inputs (PAL_44445B.v:65-67). BANK1 is NOT POPULATED on this
            # board (MEM_RAM_49_SDRAM.v:18).
            bank = BANK_OF.get((val >> 10) & 3, "?")
            note = "PPN[23:10]  ->  %s" % bank
            if bank == "BANK1 (NOT POPULATED - reads as 0)":
                note += "   <-- THIS PAGE CANNOT HOLD DATA"
            ppn_words.append((cur_pc, val, bank))
            print(f"{i:>4}  {'ppn':<4}  {val:>8o}  {note}", file=out)
        elif tag == 2:
            # 24-AUG: the word the CPU actually received on FIDBO. Run 13
            # measured only the dispatched microaddress and INFERRED the
            # instruction word from it; this is the measurement.
            note = "FIDBO word"
            if val == 0:
                note += "   <-- ZERO"
            elif val == 0o135111:
                note += "   <-- the real JPL I 111 opcode"
            fid_words.append((cur_pc, val))
            print(f"{i:>4}  {'fid':<4}  {val:>8o}  {note}", file=out)
        else:
            name = JUMP_GROUP.get(val)
            note = f"microcode: {name} entry" if name else ""
            if name:
                seen_jump.append((cur_pc, val, name))
            print(f"{i:>4}  {'csa':<4}  {val:>8o}  {note}", file=out)

    print("\n=== FIDBO, the word the CPU actually received ===", file=out)
    if not fid_words:
        print("  no FIDBO records - this dump is from the OLD build that only", file=out)
        print("  carried CSA and the program counter.", file=out)
    else:
        at_jpl = [v for pc, v in fid_words if pc in (JPL_PC, JPL_PC + 1)]
        for pc, v in fid_words[-40:]:
            print("  pc %06o  fidbo %06o%s"
                  % (pc if pc is not None else 0, v,
                     "   <-- ZERO" if v == 0 else ""), file=out)
        if at_jpl:
            if all(v == 0 for v in at_jpl):
                print("", file=out)
                print("  MEASURED: every word delivered at 064544/064545 is 000000.", file=out)
                print("  Memory really returns zero - the decode is innocent, and", file=out)
                print("  the question is the READ PATH: which physical page that", file=out)
                print("  access reaches and what is stored there.", file=out)
            elif any(v == 0o135111 for v in at_jpl):
                print("", file=out)
                print("  MEASURED: 135111 WAS delivered on FIDBO. Memory is fine and", file=out)
                print("  the instruction word reached the CPU - the fault is between", file=out)
                print("  FIDBO and the microcode dispatch (instruction register or", file=out)
                print("  decode), not in memory or the MMU.", file=out)

    print("\n=== PHYSICAL PAGE the access reaches ===", file=out)
    if not ppn_words:
        print("  no PPN records - this dump predates the PPN probe.", file=out)
    else:
        for pc, v, bank in ppn_words[-40:]:
            print("  pc %06o  ppn %06o  %s"
                  % (pc if pc is not None else 0, v, bank), file=out)
        at = [(v, b) for pc, v, b in ppn_words if pc in (JPL_PC, JPL_PC + 1)]
        dead = [b for _, b in at if "NOT POPULATED" in b or "NO BANK" in b]
        if dead:
            print("", file=out)
            print("  MEASURED: the fetch at 064544/064545 reaches a bank that", file=out)
            print("  HOLDS NOTHING. The page-table entry grants access and the", file=out)
            print("  physical page it names is not backed by memory, so every", file=out)
            print("  read returns 000000 and every disc write into it is lost.", file=out)
        elif at:
            print("", file=out)
            print("  The fetch reaches a POPULATED bank, so an absent bank is not", file=out)
            print("  the explanation - the zeros come from what is stored there.", file=out)

    print("\n=== verdict ===", file=out)
    if not seen_jump:
        print("  CSA never reached ANY entry point in the jump group", file=out)
        print("  (007300-007340). Either the window missed the instruction, or", file=out)
        print("  the decode dispatched somewhere else entirely. Check that a PC", file=out)
        print(f"  entry of {JPL_PC:06o} is present above before concluding anything.", file=out)
        return 0

    names = [n for _, _, n in seen_jump]
    if JPL_ENTRY in [v for _, v, _ in seen_jump]:
        print("  CSA DID reach the JPL entry 007340. The decode produced JPL, so", file=out)
        print("  the bit-11 story is WRONG and the fault is inside the JPL", file=out)
        print("  microroutine or in what it does with the pointer it fetches.", file=out)
    else:
        print(f"  CSA reached {', '.join(sorted(set(names)))} but NOT the JPL entry", file=out)
        print("  007340. The decode produced a conditional jump where the image", file=out)
        print("  holds JPL I 111 - which is what a lost instruction bit 11 would", file=out)
        print("  do, and it is now measured rather than guessed.", file=out)
    return 0


SELFTEST_DUMP = "noise\n" + "".join([
    "1%04X\n" % JPL_PC,
    "0%04X\n" % 0o007340,
    "0%04X\n" % 0o000123,
]) + "2341Fbad\n"


def selftest():
    ok = True

    def check(name, cond):
        nonlocal ok
        print(f"  {'ok  ' if cond else 'FAIL'}: {name}")
        if not cond:
            ok = False

    e = parse_dump(SELFTEST_DUMP)
    check("ignores noise and over-long lines", len(e) == 3)
    check("splits the tag off the top nibble", e[0][0] == 1 and e[1][0] == 0)
    check("decodes the program counter", e[0][1] == JPL_PC)
    check("decodes the JPL microcode entry", e[1][1] == JPL_ENTRY)
    check("keeps emission order", e[2][1] == 0o123)
    check("empty input yields nothing", parse_dump("") == [])

    import io as _io
    b = _io.StringIO(); report(e, out=b)
    check("verdict: JPL entry reached kills the bit-11 story",
          "bit-11 story is WRONG" in b.getvalue())
    b2 = _io.StringIO()
    report([(1, JPL_PC), (0, 0o007310)], out=b2)
    check("verdict: a conditional-jump entry supports the bit-11 story",
          "measured rather than guessed" in b2.getvalue())
    b3 = _io.StringIO()
    report([(1, JPL_PC), (0, 0o000123)], out=b3)
    check("verdict: no jump-group entry is reported as inconclusive",
          "never reached ANY entry point" in b3.getvalue())

    print("SELFTEST: PASS" if ok else "SELFTEST: FAIL")
    return 0 if ok else 1


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("dumpfile", nargs="?")
    ap.add_argument("--selftest", action="store_true")
    a = ap.parse_args()
    if a.selftest:
        return selftest()
    if not a.dumpfile:
        ap.error("a dump file is required (or use --selftest)")
    with open(a.dumpfile) as fh:
        return report(parse_dump(fh.read()))


if __name__ == "__main__":
    sys.exit(main())

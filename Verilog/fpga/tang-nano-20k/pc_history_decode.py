#!/usr/bin/env python3
"""Decode a TANG_PC_HISTORY dump into an annotated program-counter trail.

WHAT THIS IS FOR

    The Tang halts booting SINTRAN in ERRFATAL with IIC 3, a page fault on the
    ND-500 window page. The nd100x oracle, running the same image, NEVER
    touches that page - measured zero occurrences of PGS PNUMB 0o760 in a
    complete 25,000,000-instruction boot. So our first access to it IS the
    divergence; what was missing is how the machine got there.

    TANG_PC_HISTORY records {PIL[3:0], P[15:0]} into the Tang's 512-entry
    capture ring and freezes it on that access. This script turns the resulting
    hex dump back into a readable trail and marks the addresses the oracle
    never executes.

    Do NOT try to compare instruction STREAMS against the oracle - it cannot
    work. SINTRAN multiplexes level 1 among programs from the scheduler at
    PIL-2 address 032037, and which program runs depends on device timing, so
    two machines diverge at the first scheduling decision however correct both
    CPUs are.

LOOP SUPPRESSION - READ THIS BEFORE INTERPRETING A TRAIL (22-AUG-2026)

    The recorder skips a program counter that matches any of the last FOUR it
    wrote. Run 3 without that filter spent 465 of its 502 entries on the single
    three-instruction ERRFATAL print loop at 0o31444 / 0o31445 / 0o31446 and
    never reached back to the fault.

    So the trail is a list of DISTINCT-WITHIN-4 program counters, NOT an
    instruction stream. A loop of up to four instructions appears exactly once
    however many times it ran, and nothing in the dump says how long any part
    of it took. Do not count entries and call the number instructions.

ONLY LEVEL 1 IS RECORDED (22-AUG-2026, after run 5)

    The filter was narrowed twice, each time because the ring filled with the
    wrong code:

    Run 4 - all 502 entries were PIL 14, SINTRAN's error-message printer
    looping over 0o31354..0o31451 on the 9600-baud console. PIL 14 dropped.

    Run 5 - the trail then reached back through level 3 and level 2 and ended:
        494  PIL 2   032037   SINTRAN scheduler dispatch
        496  PIL 1   032040
        497  PIL 1   064404   the oracle NEVER executes this
        499  PIL 1   064406   "   <- that run's Perror
        501  PIL 12  004377   "
    but only FIVE of the 502 entries were level 1, so nothing said HOW P
    reached 064404. Everything except PIL 1 is now dropped.

    Expect a trail that is ENTIRELY PIL 1. Any other level means the wrong
    bitstream is loaded.

P IS NOW SAMPLED AT THE INSTRUCTION FETCH (22-AUG-2026, after run 6)

    Until run 6 the CGA exported RAW P, and the ring records every change of
    it. Microcode moves P inside a single instruction, so consecutive entries
    did NOT mean consecutive instructions. Run 6's trail recorded
    064540..064547 with nothing between, where the oracle takes two subroutine
    calls (JPL I 111 at 064544 -> 004600, again at 064545 -> 052031, 170
    instructions, all at PIL 1) - and the same trail carried 20+ entries at
    032040 sitting inside the 074721-074724 idle loop, which is code that
    cannot execute there. Those were artifacts of the unqualified port.

    CGA.v now registers P on XFETCHN, the P register's own fetch strobe, so
    the port only presents values that were live at an instruction fetch. From
    this build on, a consecutive run in the trail IS a consecutive run of
    instructions, and 032040-style artifacts should be gone. If they are still
    present, the qualification did not take effect - check the build.

WIRE FORMAT (from the dumper in src/ND120_TANG20K_TOP.v)

    One ring entry per line: 5 hex digits, most significant first, then CR LF.
    All 512 entries are emitted starting at cap_wptr, so the dump is already in
    chronological order - OLDEST FIRST, newest last.

        digit 0    = bits [19:16] = PIL
        digits 1-4 = bits [15:0]  = P (the program counter)

    At the dumper's 9600 baud a full dump is 512 * 7 = 3584 characters, about
    3.7 seconds. Raising DELAY_FRAMES is not needed for this probe.

USAGE

    pc_history_decode.py DUMPFILE [--hist ORACLE_PC_HISTOGRAM]
    pc_history_decode.py --selftest

    The oracle histogram and the disassembler live outside the repository, so
    they are given as arguments (or via the ND120_ORACLE_HIST and
    ND120_DISDRV environment variables) rather than hard-coded.

        ND120_ORACLE_HIST   "PC count" per line, PC in octal - built from the
                            oracle trace, tells us which addresses a healthy
                            system executes and how often
        ND120_DISDRV        the standalone disassembler driver built from the
                            nd100x source (nd100x_disdrv.c)
"""

import argparse
import os
import re
import sys
from collections import Counter

ENTRY_RE = re.compile(r"^([0-9A-Fa-f]{5})\s*$")

# SINTRAN's scheduler dispatch point, measured in the oracle trace: PIL-2
# address 032037 hands level 1 to whichever program is ready.
SCHEDULER_PC = 0o032037


def parse_dump(text):
    """Return [(pil, pc), ...] in the order the dumper emitted them.

    Lines that are not exactly five hex digits are ignored - the console
    output that precedes the dump is mixed into the same log.
    """
    out = []
    for line in text.splitlines():
        m = ENTRY_RE.match(line.strip())
        if not m:
            continue
        word = int(m.group(1), 16)
        out.append(((word >> 16) & 0xF, word & 0xFFFF))
    return out


def load_histogram(path):
    """PC (int) -> execution count, from 'OCTAL_PC count' lines."""
    hist = {}
    with open(path) as fh:
        for line in fh:
            parts = line.split()
            if len(parts) == 2:
                try:
                    hist[int(parts[0], 8)] = int(parts[1])
                except ValueError:
                    continue
    return hist


def split_tick(entries):
    """The last two ring entries are the 40-bit tick latched at the trigger.

    The probe writes tick[39:20] then tick[19:0] into the post-trigger window,
    so a complete dump ends with them. Returns (trail, tick or None).
    """
    if len(entries) < 3:
        return entries, None
    hi = (entries[-2][0] << 16) | entries[-2][1]
    lo = (entries[-1][0] << 16) | entries[-1][1]
    return entries[:-2], (hi << 20) | lo


def report(entries, hist, out=sys.stdout):
    if not entries:
        print("no 5-hex-digit entries found - is this the right log?", file=out)
        return 1

    entries, tick = split_tick(entries)
    print(f"{len(entries)} trail entries, oldest first", file=out)
    print("distinct-within-4 program counters, NOT an instruction count: a loop", file=out)
    print("of up to 4 instructions appears once (see LOOP SUPPRESSION above)", file=out)
    other = sorted({pil for pil, _ in entries} - {1})
    if other:
        print(f"WARNING: levels {other} present - this build records PIL 1 only.", file=out)
        print("         An old bitstream is probably still loaded on the board.", file=out)
    if tick is not None:
        # clk_cpu is half of clk2x (13.5 MHz), so ~6.75 MHz
        print(f"tick at trigger: {tick}  (~{tick/6.75e6:.1f} s at 6.75 MHz clk_cpu)", file=out)
        print("  compare this number across runs: if two runs agree, the boot is", file=out)
        print("  tick-deterministic and a two-pass capture at (tick - N) is viable.", file=out)
    print("", file=out)

    # An all-identical ring means the probe froze before recording anything
    # real, which is a defect in the instrument, not a finding about the CPU.
    if len(set(entries)) == 1:
        print("WARNING: every entry is identical - the ring never recorded a", file=out)
        print("         changing PC. Treat this as an instrument failure, not", file=out)
        print("         as evidence about the machine.\n", file=out)

    print(f"{'idx':>4}  {'PIL':>3}  {'P (octal)':>10}  oracle", file=out)
    print(f"{'':->4}  {'':->3}  {'':->10}  {'':->30}", file=out)

    never = []
    for i, (pil, pc) in enumerate(entries):
        if hist is None:
            note = "(no histogram given)"
        else:
            n = hist.get(pc)
            if n is None:
                note = "NEVER EXECUTED BY THE ORACLE"
                never.append((i, pil, pc))
            else:
                note = f"oracle runs it {n} times"
        mark = "  <-- scheduler dispatch" if pc == SCHEDULER_PC else ""
        print(f"{i:>4}  {pil:>3}  {pc:>10o}  {note}{mark}", file=out)

    print("", file=out)
    print(f"levels seen: "
          f"{', '.join(f'PIL {k}: {v}' for k, v in sorted(Counter(p for p, _ in entries).items()))}",
          file=out)

    if hist is not None:
        print(f"\naddresses the oracle NEVER executes: {len(never)} of {len(entries)}",
              file=out)
        if never:
            print("these are the interesting ones - the last is where we ended up:", file=out)
            for i, pil, pc in never[-12:]:
                print(f"    idx {i:>4}  PIL {pil}  {pc:06o}", file=out)

    print("\nNOTE: a PC trail carries no opcodes. To disassemble, read the words", file=out)
    print("      at these addresses out of the disc image and feed 'ADDR OPCODE'", file=out)
    print("      pairs to the nd100x disassembler driver.", file=out)
    return 0


# NOTE ON THIS DATA: an entry is FIVE characters - one PIL nibble plus four
# hex digits of P - not "PIL followed by a 6-digit octal address". Writing it
# the second way is a mistake that is easy to make and that this self-test
# caught before any board run. 0x6960 == 0o064540.
SELFTEST_DUMP = """\
some console noise before the dump
Sintran halt in ERRFATAL
1FFFF
10064
2341Fbad
16960
16961
E6962
16963
"""


def selftest():
    """Validate the decoder against known input - no board required."""
    ok = True

    def check(name, cond):
        nonlocal ok
        print(f"  {'ok  ' if cond else 'FAIL'}: {name}")
        if not cond:
            ok = False

    e = parse_dump(SELFTEST_DUMP)
    check("ignores console noise and malformed lines", len(e) == 6)
    check("decodes PIL from the top nibble", e[0] == (0x1, 0xFFFF))
    check("decodes P from the low 16 bits", e[1] == (0x1, 0x0064))
    check("keeps emission order (oldest first)", e[2][1] == 0o064540)
    check("handles PIL 14 (hex E)", e[4][0] == 14)
    check("rejects an over-long line", all(p != 0x341F for _, p in e))
    check("last entry is the newest", e[-1][1] == 0o064543)

    # An entry is 20 bits; nothing may exceed that
    check("all values fit 20 bits", all(0 <= pil < 16 and 0 <= pc < 65536 for pil, pc in e))

    # empty input must not crash
    check("empty input yields nothing", parse_dump("") == [])

    print("SELFTEST: PASS" if ok else "SELFTEST: FAIL")
    return 0 if ok else 1


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("dumpfile", nargs="?", help="captured serial log containing the dump")
    ap.add_argument("--hist", default=os.environ.get("ND120_ORACLE_HIST"),
                    help="oracle PC histogram ('OCTAL_PC count' per line)")
    ap.add_argument("--disasm", default=os.environ.get("ND120_DISDRV"),
                    help="path to the nd100x disassembler driver (optional)")
    ap.add_argument("--selftest", action="store_true", help="validate the decoder and exit")
    a = ap.parse_args()

    if a.selftest:
        return selftest()
    if not a.dumpfile:
        ap.error("a dump file is required (or use --selftest)")

    with open(a.dumpfile) as fh:
        entries = parse_dump(fh.read())

    hist = None
    if a.hist:
        if not os.path.exists(a.hist):
            print(f"histogram not found: {a.hist}", file=sys.stderr)
            return 2
        hist = load_histogram(a.hist)
    else:
        print("no --hist given: addresses will not be checked against the oracle\n",
              file=sys.stderr)

    return report(entries, hist)


if __name__ == "__main__":
    sys.exit(main())

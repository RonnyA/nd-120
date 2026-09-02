#!/usr/bin/env python3
"""
panel_clock_rate_test.py - measure the panel clock's TICK RATE on a board.

Full path (repo-relative):
  Verilog/fpga/tang-nano-20k/panel_clock_rate_test.py

tang_panel_clock_probe.py answers "what does the panel hold right now". This
answers a different question: "does it advance at one second per second". It
deposits that same 25-word program ONCE at the OPCOM '#' prompt, then runs it
twice a known distance apart and compares the panel's own counter delta with
the wall clock.

Depositing once is the point. A deposit costs about three minutes at the 0.30 s
per character the console needs, so re-depositing between samples would put
minutes of unmeasured time inside the measurement.

  python3 panel_clock_rate_test.py --macl --gap 600

GETTING TO THE '#' PROMPT
  from SINTRAN   : @OPCOM
  from the TPE monitor: type OPCOM. TPE echoes the word and reprints its own
                   "TPE>" prompt, which looks like a refusal - it is not. The
                   NEXT bare CR gives '#'. (ESC at TPE> only reprints TPE>.)
  from anywhere  : press S1 on the board (master clear).

RESOLUTION - read the result honestly. The panel reports whole seconds, so one
reading carries +/-1 s of quantisation. A 600 s run can prove drift under a
second; it cannot prove parts-per-million accuracy. Use a long --gap for that.

MEASURED 29-AUG-2026, Tang Nano 20K, fast20 (20.25 MHz) + panel clock:
623 s counted over 623.1 s of wall clock, and the counter survived the MACL
(it came back holding a 1994 date, not the 1979-01-01 power-up value).

30-AUG-2026  Ronny Hansen
"""
import argparse, os, re, sys, time

# the probe module lives next to this file - never an absolute path
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from tang_panel_clock_probe import assemble, BASE, RES, PFUNCS

import serial

CHAR_GAP = 0.30


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--port", default="/dev/ttyUSB1")
    ap.add_argument("--gap", type=float, default=600.0,
                    help="seconds between the two samples")
    ap.add_argument("--macl", action="store_true",
                    help="master clear first (the panel clock keeps its time)")
    ap.add_argument("--log", default="/tmp/panel_clock_rate_test.log")
    a = ap.parse_args()

    s = serial.Serial(a.port, 115200,
                      bytesize=serial.SEVENBITS, parity=serial.PARITY_EVEN,
                      stopbits=serial.STOPBITS_ONE, timeout=0.3)
    log = open(a.log, "w", buffering=1)

    def note(m):
        line = "%s %s" % (time.strftime("%H:%M:%S"), m)
        print(line, flush=True); log.write(line + "\n")

    def cmd(text, settle=0.6):
        for ch in text:
            s.write(ch.encode()); s.flush(); time.sleep(CHAR_GAP)
        s.write(b"\r"); s.flush()
        out, end = [], time.time() + settle
        while time.time() < end:
            d = s.read(256)
            if d:
                out.append("".join(chr(b & 0x7F) for b in d))
        t = "".join(out)
        log.write(t)
        return t

    def word(ad):
        t = cmd("%o/" % ad, settle=0.7).replace("\r", " ")
        m = re.search(r"(\d{6})", t)
        return int(m.group(1), 8) if m else None

    prog = assemble()
    time.sleep(0.5); s.reset_input_buffer()
    cmd("")

    if a.macl:
        note("MACL")
        cmd("MACL", settle=3.0)
        cmd("")

    note("depositing %d words" % len(prog))
    for ad in sorted(prog):
        cmd("%o/%o" % (ad, prog[ad]))
    note("verifying")
    bad = 0
    for ad in sorted(prog):
        got = word(ad)
        if got != prog[ad]:
            note("  MISMATCH %06o: wrote %06o read %s"
                 % (ad, prog[ad], "%06o" % got if got is not None else "?"))
            bad += 1
    if bad:
        note("deposit not clean (%d words) - not measuring" % bad)
        return 2
    note("deposit verified")

    def sample(tag):
        """Run the program and decode the four answer bytes.

        Each command is sampled twice because TRA PANS clears VAL. Only a word
        with READ=1, VAL=1 and STAT matching the requested PFUNC is accepted -
        taking whichever came back would be guessing.
        """
        t0 = time.time()
        cmd("%o!" % BASE, settle=2.0)
        vals = [word(RES + i) for i in range(2 * len(PFUNCS))]
        note("%s raw: %s" % (tag, " ".join(
            "%06o" % v if v is not None else "?" for v in vals)))
        byte = {}
        for i, v in enumerate(vals):
            if v is None:
                continue
            pf = PFUNCS[i // 2]
            if ((v >> 13) & 1) == 1 and ((v >> 12) & 1) == 1 and ((v >> 8) & 0xF) == pf:
                byte.setdefault(pf, v & 0xFF)
        if len(byte) != 4:
            note("%s: only PFUNC %s answered - cannot decode" % (tag, sorted(byte)))
            return None
        sec = byte[4] | (byte[5] << 8)          # seconds within the half-day
        hd = byte[6] | (byte[7] << 8)           # half-days since 1979-01-01
        note("%s  half-days=%d  seconds-in-half-day=%d  (%02d:%02d:%02d %s)"
             % (tag, hd, sec, sec // 3600, (sec // 60) % 60, sec % 60,
                "PM" if hd % 2 else "AM"))
        return t0, hd, sec

    first = sample("sample 1")
    if not first:
        return 3
    note("waiting %.0f s" % a.gap)
    time.sleep(a.gap)
    second = sample("sample 2")
    if not second:
        return 3

    wall = second[0] - first[0]
    counted = (second[1] - first[1]) * 43200 + (second[2] - first[2])
    note("=== RESULT ===")
    note("wall clock elapsed  : %.1f s" % wall)
    note("panel clock advanced: %d s" % counted)
    note("difference          : %+.1f s   (+/-1 s is the panel's own resolution)"
         % (counted - wall))
    return 0


if __name__ == "__main__":
    sys.exit(main())

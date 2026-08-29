#!/usr/bin/env python3
"""
tang_panel_clock_probe.py - read the panel clock on the Tang, with SINTRAN out
of the picture.

Full path: Verilog/fpga/tang-nano-20k/tang_panel_clock_probe.py

WHY (29-AUG-2026): on silicon, @UPDAT sets SINTRAN's software clock and the
time does NOT survive a master clear - the next boot still says "ND-100 PANEL
CLOCK INCORRECT". The reference manual says @UPDAT "updates the panel clock, if
installed", PRES is hardwired 1, and PANCAL_68705_CLOCK keeps its counters
across CLEAR_n by construction (unit test 8, 223 checks, PASS). So the question
is what the panel actually HOLDS, measured directly rather than through
SINTRAN.

Deposits a 25-word program through OPCOM, runs it, and reads back the four
answer bytes. The clock is (half-days since 1979-01-01, seconds in half-day):

    half-days 0      -> never written, still the power-up value (1979-01-01)
    half-days ~11563 -> a 1994 date was written and survived

The panel protocol (docs/panel-clock-68705.md): four TRR PANC with RD=1 and
PFUNC 4,5,6,7; each answer byte comes back in TRA PANS bits 7:0 with READ=1 and
STAT2:0 = PFUNC. A fresh snapshot is taken on PFUNC 4, so all four must be read
in order for a consistent value. TRA PANS clears VAL, so each command is
sampled TWICE and both samples are kept - the answer may not be there on the
first read, and guessing which one is real would defeat the point.

  python3 tang_panel_clock_probe.py [--port /dev/ttyUSB1] [--log FILE]

Expects the OPCOM '#' prompt (press S1 for master clear first). Ends the
program with WAIT so OPCOM regains control - never single-step (Z) a
privileged instruction, the stepper hangs and needs a power cycle.

29-AUG-2026  Ronny Hansen
"""
import argparse, re, sys, time
import serial

GAP = 0.30

# ---- instruction encodings (from sim/examples/panel_pans_probe.py, proven) --
TRA_PANS = 0o150000
TRR_PANC = 0o150100
WAIT     = 0o151000
LDA_P    = 0o044000   # + P-relative displacement
STA_P    = 0o004000   # + P-relative displacement

BASE  = 0o2000        # program
PANC  = 0o2100        # the four command words
RES   = 0o2110        # eight answer words (two samples per command)

# PANC word = RD(bit13) | PFUNC<<8 . RD=1 is a read request.
PFUNCS = [4, 5, 6, 7]


def assemble():
    """Build {addr: word}. Displacements are computed, never hand-written."""
    prog, addr = {}, BASE
    for i, _pf in enumerate(PFUNCS):
        panc_at = PANC + i
        res_at = RES + 2 * i
        def rel(target, at):
            d = target - at
            if not -128 <= d <= 127:
                raise SystemExit("displacement %d out of range at %o" % (d, at))
            return d & 0o377
        prog[addr] = LDA_P + rel(panc_at, addr); addr += 1
        prog[addr] = TRR_PANC;                   addr += 1
        prog[addr] = TRA_PANS;                   addr += 1
        prog[addr] = STA_P + rel(res_at, addr);  addr += 1
        prog[addr] = TRA_PANS;                   addr += 1
        prog[addr] = STA_P + rel(res_at + 1, addr); addr += 1
    prog[addr] = WAIT
    for i, pf in enumerate(PFUNCS):
        prog[PANC + i] = (1 << 13) | (pf << 8)
    for i in range(2 * len(PFUNCS)):
        prog[RES + i] = 0
    return prog


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--port", default="/dev/ttyUSB1")
    ap.add_argument("--log", default="/tmp/tang_panel_clock_probe.log")
    a = ap.parse_args()

    prog = assemble()
    s = serial.Serial(a.port, 115200,
                      bytesize=serial.SEVENBITS, parity=serial.PARITY_EVEN,
                      stopbits=serial.STOPBITS_ONE, timeout=0.3)
    log = open(a.log, "w", buffering=1)

    def note(m):
        line = "%s %s" % (time.strftime("%H:%M:%S"), m)
        print(line, flush=True); log.write(line + "\n")

    def cmd(text, settle=1.0):
        for ch in text:
            s.write(ch.encode()); s.flush(); time.sleep(GAP)
        s.write(b"\r"); s.flush()
        out, end = [], time.time() + settle
        while time.time() < end:
            d = s.read(256)
            if d:
                out.append("".join(chr(b & 0x7F) for b in d))
        t = "".join(out)
        log.write(t)
        return t

    note("=== panel clock probe ===")
    note("program (octal):")
    for ad in sorted(prog):
        note("   %06o/%06o" % (ad, prog[ad]))

    time.sleep(0.5); s.reset_input_buffer()
    cmd("")                                     # a bare CR should give '#'

    note("depositing")
    for ad in sorted(prog):
        cmd("%o/%o" % (ad, prog[ad]), settle=0.6)

    note("verifying the deposit")
    bad = 0
    for ad in sorted(prog):
        t = cmd("%o/" % ad, settle=0.6)
        m = re.search(r"(\d{6})", t.replace("\r", " "))
        got = int(m.group(1), 8) if m else None
        if got != prog[ad]:
            note("  MISMATCH %06o: wrote %06o read %s" % (ad, prog[ad], m.group(1) if m else "?"))
            bad += 1
    if bad:
        note("deposit not clean (%d words) - not running" % bad)
        return 2
    note("deposit verified")

    note("running from %o" % BASE)
    cmd("%o!" % BASE, settle=3.0)

    note("answers:")
    vals = []
    for i in range(2 * len(PFUNCS)):
        t = cmd("%o/" % (RES + i), settle=0.6)
        m = re.search(r"(\d{6})", t.replace("\r", " "))
        v = int(m.group(1), 8) if m else None
        vals.append(v)
        pf = PFUNCS[i // 2]
        note("  PFUNC %d sample %d: %s" % (pf, i % 2, "%06o" % v if v is not None else "?"))

    # PANS = |PRES FUL~ READ VAL|STAT3..0|RPAN(8)|
    note("decoded (PRES/FUL~/READ/VAL/STAT/byte):")
    for i, v in enumerate(vals):
        if v is None:
            continue
        note("  PFUNC %d s%d: PRES=%d FUL~=%d READ=%d VAL=%d STAT=%d byte=%03o"
             % (PFUNCS[i // 2], i % 2, (v >> 15) & 1, (v >> 14) & 1,
                (v >> 13) & 1, (v >> 12) & 1, (v >> 8) & 0xF, v & 0xFF))
    note("done - read the bytes above; this script draws no conclusion")
    return 0


if __name__ == "__main__":
    sys.exit(main())

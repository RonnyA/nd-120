#!/usr/bin/env python3
"""
Drive DISC-TEMA J02 "DU-DI-C" against the Verilog Winchester in VERILATOR.

Runs the same test that is run on the Tang: boot TPE Monitor B01 from the
floppy image, load DISC-TEMA, read one block off the Winchester at IOX 500,
and dump it.

BUILD THE ENGINE FIRST (both flags are MANDATORY - see the traps below):

    cd ../../../sim
    make probe-wd USE_LATCHES=0 EXTRA_WD_DEFINES=-DND120_DEV_DELAY_TICKS=216000

RUN (paths come from the environment; nothing here is machine-specific):

    ND120_FLOPPY_IMG=../../../runSim/FLOPPY1.IMG \
    ND120_WD_IMG=$ND_WD_IMAGE \
    ND120_WD_TRACE_FILE=wd_trace.log \
    python3 wd_disctema.py disctema_console.log

    ND120_FLOPPY_IMG  TPE Monitor boot diskette
    ND120_WD_IMG      the Winchester disc image (75 MB). NOT in this repo -
                      point it at your copy. The nd100x oracle capture used
                      WD0-L.img; a run against a different image will produce
                      a legitimately different dump.
    ND120_WD_TRACE_FILE  where the Winchester IOX/IDENT/disc trace is written.
                      It MUST be a file: the trace cannot go to stdout, which
                      carries the probe engine's line protocol.

Takes roughly 50 minutes. Expect the run to end with DISC-TEMA reporting
"Memory address Register not as expected" - that is the OPEN DEFECT, and
reproducing it here is the point of this script.

THREE TRAPS, each of which costs a full 50-minute run:

 1. USE_LATCHES=0 is MANDATORY. sim/Makefile has USE_LATCHES ?= 1 and only
    adds FPGA_FF_MODE when it is not 1, so the DEFAULT build is latch mode,
    which never floppy-boots. (The comment above the probe targets claiming
    "FF mode default" is wrong.) Symptom: prompt appears, 1560& echoes, then
    silence forever.
 2. ND120_DEV_DELAY_TICKS=216000 is MANDATORY. Without it DISC-TEMA dies with
    "Software Timeout" before programming the transfer, and the dump reads
    back all zeros. SMD_DELAY_TICKS in ND120_CORE.v converts an 8 ms drive
    latency into CYCLES using DEV_CLK_HZ: 27 MHz on the Tang = 216,000 cycles,
    but Verilator falls back to 100 MHz = 800,000. The CPU runs per cycle, so
    the sim hands the status-wait loop 3.7x more iterations. Harness artifact,
    not an RTL bug.
 3. The probe engine parses the LITERAL two characters \\r, not a CR byte
    (nd120_probe.cpp, the "send" command). Sending a real CR makes every
    command echo and never execute. 1560& hides this completely, because MOPC
    acts on the & itself and needs no CR.

Ronny Hansen
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
SIM = os.path.normpath(os.path.join(HERE, "..", "..", "..", "sim"))
sys.path.insert(0, SIM)

if not os.environ.get("ND120_WD_IMG"):
    sys.exit("ND120_WD_IMG is not set - point it at the Winchester disc image.")
if not os.environ.get("ND120_FLOPPY_IMG"):
    os.environ["ND120_FLOPPY_IMG"] = os.path.normpath(
        os.path.join(HERE, "..", "..", "..", "runSim", "FLOPPY1.IMG"))

from nd120_probe import Probe  # noqa: E402

OUT = sys.argv[1] if len(sys.argv) > 1 else "disctema_console.log"
CHUNK = 2_000_000


def flush(p, tag=""):
    txt = p.console_text()
    with open(OUT, "w") as f:
        f.write(txt)
    if tag:
        print("[%s] console %d bytes" % (tag, len(txt)), flush=True)
    return txt


def expect(p, pattern, maxticks, tag=""):
    """Advance the sim in chunks until `pattern` appears on the console.

    NOTE: the console ECHOES what is typed, so a pattern equal to a command
    matches the echo and reports a false success. Match on text only the
    machine can produce, or check that the console actually GREW.
    """
    done = 0
    while done < maxticks:
        p.run(CHUNK)
        done += CHUNK
        if pattern in p.console_text():
            flush(p, tag)
            print("  got %-14r after %9d ticks" % (pattern, done), flush=True)
            return True
        if done % 20_000_000 == 0:
            flush(p)
            print("  ...waiting for %r (%d ticks)" % (pattern, done), flush=True)
    flush(p, "TIMEOUT")
    print("  TIMEOUT waiting for %r after %d ticks" % (pattern, maxticks), flush=True)
    return False


def send_line(p, s):
    # The engine parses the two-character literal \r into a carriage return.
    # A real CR byte is eaten by the line protocol: the command echoes but
    # never executes.
    p.send(s + "\\r")
    # Characters are held ~300k ticks apart (ND120_SEND_GAP): MOPC has no
    # receive FIFO and drops back-to-back characters.
    p.run(400_000 * (len(s) + 2))


os.chdir(SIM)
p = Probe(engine=os.path.join(SIM, "obj_dir_probe_wd", "VND120_TOP"),
          wsl=False, echo_console=False, timeout=120)
p.start()
print("== engine up ==", flush=True)

p.run(6_000_000)
send_line(p, "1560&")
if not expect(p, "TPE Monitor", 60_000_000, "boot"):
    sys.exit(1)
if not expect(p, "TPE>", 10_000_000, "prompt"):
    sys.exit(1)

send_line(p, "disc")
if not expect(p, "DISC-TEMA", 200_000_000, "disctema"):
    sys.exit(1)

send_line(p, "DU-DI-C")
if not expect(p, "Disc name", 60_000_000, "duidic"):
    sys.exit(1)

send_line(p, "DIS-74-1")
expect(p, "Unit", 10_000_000, "unit")
send_line(p, "0")
expect(p, "Cylinder", 10_000_000, "cyl")
send_line(p, "0")
expect(p, "Surface", 10_000_000, "surf")
send_line(p, "0")
expect(p, "Sector", 10_000_000, "sect")
send_line(p, "0")
expect(p, "Amount", 10_000_000, "amount")
send_line(p, "1")

expect(p, "Word#", 120_000_000, "dump")
p.run(20_000_000)
flush(p, "final")

txt = p.console_text()
print("\n===== TAIL =====\n%s" % txt[-3000:], flush=True)
print("\nERROR banner present:", "***ERROR***" in txt, flush=True)
p.close()

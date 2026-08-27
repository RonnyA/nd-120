#!/usr/bin/env python3
"""
pflog_capture_decode.py - boot the Tang and decode the PAGE-FAULT STREAM ring
(TANG_PFLOG_CAPTURE build), or decode an existing log.

Full path:
  Verilog/fpga/tang-nano-20k/pflog_capture_decode.py

WHY THIS PROBE (23-AUG-2026, run 11)
  Run 10 closed the page-0o432 question: that page is cleared, faults twice,
  and the handler then writes GRANTING entries 062001 and 066001 - every
  no-permit access precedes the grant. Demand paging works there.

  What remains unknown is the fault that actually halts SINTRAN: the console
  reports Perror 064406, level 1, IIC 3 Page Fault, NPIT/APIT 000012 / 000007.
  This ring records EVERY page-fault vector transition, at ANY address, and is
  frozen by the ERRFATAL printer - so the LAST records are that fault, named
  by page and by what its page-table entry said.

RECORD FORMAT (one 20-bit hex value per line)
    [19:17] = 0
    [16:10] = PT[15:9]  = WPM RPM FPM WIP PGU ring1 ring0
    [ 9: 0] = LA[19:10] = the RAW page-table index
  software index = raw XOR 0o1400 (the top two table bits are complemented in
  hardware); software index = table<<6 | page.

USAGE
    python3 pflog_capture_decode.py [--port /dev/ttyUSB1] [--minutes 18]
    python3 pflog_capture_decode.py --decode-file <log>

23-AUG-2026  Ronny Hansen
"""

import argparse
import re
import sys
import time

BOOT_CMD = "20500&"
CHAR_GAP = 0.30  # this console drops characters without a gap

SW_XOR = 0o1400
PERROR_PAGE = 0o32     # Perror 064406 lies in page 0o32


def sw(raw10):
    return (raw10 & 0x3FF) ^ SW_XOR


def extract_samples(text):
    out = []
    for h in re.findall(r"(?m)^\s*([0-9a-fA-F]{4,5})\s*$", text):
        out.append(int(h, 16) & 0xFFFFF)
    return out


def decode(samples):
    """Return [(raw_index, pt_15_9)] in ring order."""
    return [((v & 0x3FF), (v >> 10) & 0x7F) for v in samples]


def line(raw, pt, mark=""):
    s = sw(raw)
    grants = "GRANTS" if (pt & 0x70) else "grants nothing"
    return ("   raw %06o -> sw %06o (table %2o page %2o)  "
            "WPM=%d RPM=%d FPM=%d WIP=%d PGU=%d  %-14s%s"
            % (raw, s, (s >> 6) & 0xF, s & 0x3F,
               (pt >> 6) & 1, (pt >> 5) & 1, (pt >> 4) & 1,
               (pt >> 3) & 1, (pt >> 2) & 1, grants, mark))


def report(faults):
    print("")
    print("=" * 74)
    print(" PAGE-FAULT STREAM - %d faults recorded before the ERRFATAL trigger"
          % len(faults))
    print("=" * 74)
    if not faults:
        print(" RING EMPTY. Either the trigger fired before any fault, or the")
        print(" probe path is dead - check the console log for the ERRFATAL.")
        print("=" * 74)
        return

    print("")
    print(" THE FATAL FAULT (last record):")
    raw, pt = faults[-1]
    print(line(raw, pt))
    s = sw(raw)
    if (s & 0x3F) == PERROR_PAGE:
        print("   ^ this IS the page Perror 064406 lies in (page %02o)" % PERROR_PAGE)
    else:
        print("   ^ NOT the page Perror 064406 lies in (that is page %02o)" % PERROR_PAGE)

    print("")
    print(" last 30 faults (oldest first):")
    for i, (raw, pt) in enumerate(faults[-30:]):
        mark = "  <== FATAL" if i == len(faults[-30:]) - 1 else ""
        print(line(raw, pt, mark))

    tally = {}
    for raw, pt in faults:
        tally[(raw, pt)] = tally.get((raw, pt), 0) + 1
    print("")
    print(" distinct (page, entry) pairs, most frequent first:")
    for (raw, pt), n in sorted(tally.items(), key=lambda kv: -kv[1])[:15]:
        print(line(raw, pt, "  x%d" % n))

    # A page that faults repeatedly with an entry that already grants access is
    # the interesting shape: the entry is there and the hardware faults anyway.
    granted = [(raw, pt, n) for (raw, pt), n in tally.items() if (pt & 0x70)]
    print("")
    print("=" * 74)
    if granted:
        print(" NOTE: %d distinct fault(s) happened on an entry that ALREADY"
              % len(granted))
        print(" GRANTS access. A fault on a granting entry cannot be demand")
        print(" paging - the permission compare or the entry read is wrong.")
        for raw, pt, n in granted:
            print(line(raw, pt, "  x%d" % n))
    else:
        print(" Every recorded fault hit an entry that grants nothing - the")
        print(" shape of ordinary demand paging. The fatal one is named above;")
        print(" the next question is why its page is never made resident.")
    print("=" * 74)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--port", default="/dev/ttyUSB1")
    ap.add_argument("--baud", type=int, default=115200)
    ap.add_argument("--minutes", type=float, default=18.0)
    ap.add_argument("--log", default="pflog_capture_run.log")
    ap.add_argument("--decode-file")
    args = ap.parse_args()

    if args.decode_file:
        text = open(args.decode_file, "r", errors="replace").read()
        report(decode(extract_samples(text)))
        return 0

    import serial  # here so --decode-file works without pyserial

    s = serial.Serial(args.port, args.baud, timeout=0.5)
    log = open(args.log, "w", buffering=1)

    def emit(line):
        stamp = time.strftime("%H:%M:%S")
        print("%s %s" % (stamp, line), flush=True)
        log.write("%s %s\n" % (stamp, line))

    emit("port %s @ %d, deadline %.0f min" % (args.port, args.baud, args.minutes))
    time.sleep(1.0)
    s.reset_input_buffer()
    emit("sending %r one character at a time (%.2fs gap)" % (BOOT_CMD, CHAR_GAP))
    for ch in BOOT_CMD:
        s.write(ch.encode())
        s.flush()
        time.sleep(CHAR_GAP)
    s.write(b"\r")
    s.flush()

    deadline = time.time() + args.minutes * 60
    buf = ""
    raw = []
    reopens = 0
    while time.time() < deadline:
        try:
            chunk = s.read(256)
        except Exception as exc:                      # noqa: BLE001
            reopens += 1
            emit("serial error (%s) - reopening, attempt %d"
                 % (exc.__class__.__name__, reopens))
            try:
                s.close()
            except Exception:
                pass
            time.sleep(2.0)
            try:
                s = serial.Serial(args.port, args.baud, timeout=0.5)
            except Exception as exc2:                 # noqa: BLE001
                emit("reopen failed: %s" % exc2)
                time.sleep(3.0)
            continue
        if not chunk:
            continue
        text = chunk.decode("latin-1", errors="replace")
        raw.append(text)
        log.write(text)
        buf += text
        while "\n" in buf:
            line, buf = buf.split("\n", 1)
            line = line.rstrip("\r")
            if line.strip():
                print(time.strftime("%H:%M:%S") + " | " + line, flush=True)

    s.close()
    emit("collection finished")
    report(decode(extract_samples("".join(raw))))
    return 0


if __name__ == "__main__":
    sys.exit(main())

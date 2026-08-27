#!/usr/bin/env python3
"""Boot the Tang to the ERRFATAL and collect the TANG_PC_HISTORY dump.

Boots 20500& on the Tang console, logs everything, and when the run ends hands
the log to pc_history_decode.py so the program-counter trail comes out
annotated against the oracle.

Build the bitstream first:

    powershell.exe -NoProfile -ExecutionPolicy Bypass -File gowin_build.ps1 \\
        -Variant slow -PcHistory
    make load-gowin

The serial machinery here follows pf_capture_run.py, which is proven on this
board: one character at a time with a 0.30 s gap (the console drops characters
without it), and reopen-on-error so a USB hiccup does not kill a 45-minute run.

WHAT TO EXPECT

    The console prints the SINTRAN banner, then eventually the ERRFATAL halt.
    Shortly after the ring freezes, the dumper takes the TX pin and streams 512
    lines of five hex digits. The console is dead from that point - expected,
    the machine has already halted.

    A trail that does NOT end near the ERRFATAL means the trigger fired early,
    most likely during initialisation before SINTRAN clears the ND-500 window
    PIT entry (while that entry is still mapped, an access there is legitimate
    and faults nothing). That is a wasted run, not a broken instrument - just
    run it again.
"""

import argparse
import os
import subprocess
import sys
import time

BOOT_CMD = "20500&"
CHAR_GAP = 0.30   # this console drops characters without a gap
HERE = os.path.dirname(os.path.abspath(__file__))
DECODER = os.path.join(HERE, "pc_history_decode.py")

# One ring entry is five hex digits; a full dump is 512 of them.
FULL_DUMP = 512


def count_entries(text):
    n = 0
    for line in text.splitlines():
        t = line.strip()
        if len(t) == 5:
            try:
                int(t, 16)
                n += 1
            except ValueError:
                pass
    return n


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--port", default="/dev/ttyUSB1")
    ap.add_argument("--baud", type=int, default=115200)
    ap.add_argument("--minutes", type=float, default=45.0)
    ap.add_argument("--log", default="pc_history_run.log")
    ap.add_argument("--hist", default=os.environ.get("ND120_ORACLE_HIST"),
                    help="oracle PC histogram, passed straight to the decoder")
    ap.add_argument("--decode-file", help="skip the board, decode an existing log")
    a = ap.parse_args()

    if a.decode_file:
        return decode(a.decode_file, a.hist)

    import serial  # imported late so --decode-file works without pyserial

    s = serial.Serial(a.port, a.baud, timeout=0.5)
    log = open(a.log, "w", buffering=1)

    def emit(line):
        stamp = time.strftime("%H:%M:%S")
        print("%s %s" % (stamp, line), flush=True)
        log.write("%s %s\n" % (stamp, line))

    emit("port %s @ %d, deadline %.0f min" % (a.port, a.baud, a.minutes))
    emit("waiting for the ND-500 window page access (raw PNUMB 0o1360) to freeze the ring")

    time.sleep(1.0)
    s.reset_input_buffer()
    emit("sending %r one character at a time (%.2fs gap)" % (BOOT_CMD, CHAR_GAP))
    for ch in BOOT_CMD:
        s.write(ch.encode())
        s.flush()
        time.sleep(CHAR_GAP)
    s.write(b"\r")
    s.flush()

    deadline = time.time() + a.minutes * 60
    buf = ""
    raw = []
    saw_errfatal = False
    reopens = 0
    entries_reported = 0

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
                s = serial.Serial(a.port, a.baud, timeout=0.5)
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
            if "ERRFATAL" in line:
                saw_errfatal = True
                emit(">>> ERRFATAL seen - the dumper should take the TX pin next")

        # progress while the dump streams, so a long run is not silent
        n = count_entries("".join(raw))
        if n >= entries_reported + 64:
            entries_reported = n - (n % 64)
            emit("dump progress: %d/%d entries" % (n, FULL_DUMP))
        if n >= FULL_DUMP:
            emit("full dump received (%d entries) - stopping early" % n)
            break

    s.close()
    all_text = "".join(raw)
    n = count_entries(all_text)
    emit("collection finished (errfatal_seen=%s, entries=%d)" % (saw_errfatal, n))

    if n == 0:
        emit("NO dump entries. Either the trigger never fired, or the build was")
        emit("not the -PcHistory one. Log kept at %s" % a.log)
        return 1
    if n < FULL_DUMP:
        emit("PARTIAL dump: %d of %d entries. Decoding anyway - the trail is" % (n, FULL_DUMP))
        emit("truncated at the OLD end, so the newest entries are still present.")

    log.close()
    return decode(a.log, a.hist)


def decode(path, hist):
    cmd = [sys.executable, DECODER, path]
    if hist:
        cmd += ["--hist", hist]
    print("\n--- decoding: %s ---\n" % " ".join(cmd), flush=True)
    return subprocess.call(cmd)


if __name__ == "__main__":
    sys.exit(main())

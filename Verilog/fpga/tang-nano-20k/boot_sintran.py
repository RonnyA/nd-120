#!/usr/bin/env python3
"""
boot_sintran.py - type the boot command on the Tang console and log the boot.

Full path:
  Verilog/fpga/tang-nano-20k/boot_sintran.py

Types '20500&' with the 0.30 s per-character pacing the console needs, then
logs everything and reports the landmarks live:

  * "ERRFATAL"            -> the old failure, with its L-reg / Perror / IIC
  * "SINTRAN"             -> the banner: the boot got through
  * any other printable output is echoed with a timestamp

  python3 boot_sintran.py [--minutes 45] [--log <file>]

24-AUG-2026  Ronny Hansen
"""

import argparse
import sys
import time

BOOT_CMD = "20500&"
CHAR_GAP = 0.30      # the console drops characters without a gap


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--port", default="/dev/ttyUSB1")
    ap.add_argument("--baud", type=int, default=115200)
    ap.add_argument("--minutes", type=float, default=45.0)
    ap.add_argument("--log", default="$ND120_ORACLE_DIR/boot_sintran.log")
    ap.add_argument("--no-send", action="store_true",
                    help="listen only - a boot is already running")
    a = ap.parse_args()

    import serial
    s = serial.Serial(a.port, a.baud, timeout=0.5)
    log = open(a.log, "w", buffering=1)

    def emit(msg):
        line = "%s %s" % (time.strftime("%H:%M:%S"), msg)
        print(line, flush=True)
        log.write(line + "\n")

    emit("port %s @ %d, %.0f min" % (a.port, a.baud, a.minutes))
    time.sleep(1.0)
    s.reset_input_buffer()
    if not a.no_send:
        emit("sending %r (%.2fs per character)" % (BOOT_CMD, CHAR_GAP))
        for ch in BOOT_CMD:
            s.write(ch.encode())
            s.flush()
            time.sleep(CHAR_GAP)
        s.write(b"\r")
        s.flush()

    t0 = time.time()
    deadline = t0 + a.minutes * 60
    buf = ""
    seen_fatal = False
    seen_banner = False
    while time.time() < deadline:
        try:
            chunk = s.read(256)
        except Exception as exc:                        # noqa: BLE001
            emit("serial error: %s" % exc)
            time.sleep(2.0)
            continue
        if not chunk:
            continue
        text = chunk.decode("latin-1", errors="replace")
        log.write(text)
        buf += text
        while "\n" in buf:
            line, buf = buf.split("\n", 1)
            line = line.rstrip("\r")
            if not line.strip():
                continue
            el = time.time() - t0
            print("%s [+%5.1fs] | %s" % (time.strftime("%H:%M:%S"), el, line),
                  flush=True)
            up = line.upper()
            if "ERRFATAL" in up and not seen_fatal:
                seen_fatal = True
                emit(">>> ERRFATAL at +%.1fs - the old failure is STILL THERE" % el)
            if "SINTRAN" in up and "ERRFATAL" not in up and not seen_banner:
                seen_banner = True
                emit(">>> SINTRAN banner at +%.1fs - THE BOOT GOT THROUGH" % el)

    s.close()
    emit("finished: ERRFATAL=%s banner=%s" % (seen_fatal, seen_banner))
    return 0


if __name__ == "__main__":
    sys.exit(main())

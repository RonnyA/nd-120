#!/usr/bin/env python3
"""listen_console.py - LISTEN ONLY on the Tang console, sending nothing.

Full path:
  Verilog/fpga/tang-nano-20k/listen_console.py

Why it exists (24-AUG-2026): every capture runner types the boot command when
it opens the port. When a boot is ALREADY in progress - because a previous
collector sent the command before it was stopped - retyping does nothing and
the ring dump streams to a port nobody is reading. This one only reads.

  python3 listen_console.py --minutes 12 --log <file>
"""
import argparse, sys, time

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--port", default="/dev/ttyUSB1")
    ap.add_argument("--baud", type=int, default=115200)
    ap.add_argument("--minutes", type=float, default=12.0)
    ap.add_argument("--log", required=True)
    a = ap.parse_args()
    import serial
    s = serial.Serial(a.port, a.baud, timeout=0.5)
    log = open(a.log, "w", buffering=1)
    log.write("%s listen-only on %s @ %d for %.1f min\n"
              % (time.strftime("%H:%M:%S"), a.port, a.baud, a.minutes))
    deadline = time.time() + a.minutes * 60
    while time.time() < deadline:
        try:
            chunk = s.read(256)
        except Exception as exc:                       # noqa: BLE001
            log.write("\nserial error: %s\n" % exc)
            time.sleep(2.0)
            continue
        if chunk:
            log.write(chunk.decode("latin-1", errors="replace"))
    s.close()
    log.write("\n%s listen finished\n" % time.strftime("%H:%M:%S"))
    return 0

if __name__ == "__main__":
    sys.exit(main())

#!/usr/bin/env python3
"""
measure_s3.py - time how long S3 takes to produce its first output.

Verilog/fpga/tang-nano-20k/measure_s3.py

Drives the console end to end: boot, log in as SYSTEM (blank password),
SET-T-T,,93, then S3 - and measures from the CR that submits "S3" to the
first byte of S3's output. Exits S3 with E twice.

The console is 7E2 at 9600 and drops characters typed at speed, so every
character is sent with a gap. Nothing here fabricates a result: if a step's
expected text never arrives, the script says which step timed out and exits
non-zero rather than reporting a number it did not measure.

  python3 measure_s3.py --label 27MHz --log <file>
"""
import argparse, re, sys, time

CHAR_GAP = 0.30
BOOT_CMD = "20500&"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--port", default="/dev/ttyUSB1")
    ap.add_argument("--label", default="run")
    ap.add_argument("--log", default="/tmp/measure_s3.log")
    ap.add_argument("--boot-timeout", type=float, default=420.0)
    ap.add_argument("--s3-timeout", type=float, default=600.0)
    a = ap.parse_args()

    import serial
    s = serial.Serial(a.port, 9600,
                      bytesize=serial.SEVENBITS,
                      parity=serial.PARITY_EVEN,
                      # ONE stop bit: what picocom -d 7 -p e uses, and what
                      # works on this console. TWO produced a completely silent
                      # read - not one byte, not even the echo (24-AUG-2026).
                      stopbits=serial.STOPBITS_ONE,
                      timeout=0.3)
    log = open(a.log, "w", buffering=1)
    buf = []

    def note(m):
        line = "%s %s" % (time.strftime("%H:%M:%S"), m)
        print(line, flush=True); log.write(line + "\n")

    def rx():
        d = s.read(512)
        if d:
            t = "".join(chr(b & 0x7F) for b in d)
            buf.append(t); log.write(t)
            return t
        return ""

    def wait_for(pattern, timeout, what):
        """Wait for a regex over everything received. Returns True/False."""
        rx_re = re.compile(pattern, re.I)
        end = time.time() + timeout
        while time.time() < end:
            rx()
            if rx_re.search("".join(buf)[-6000:]):
                return True
        note("TIMEOUT waiting for %s (%.0fs)" % (what, timeout))
        return False

    def send(text, cr=True):
        for ch in text:
            s.write(ch.encode("ascii", "replace")); s.flush(); time.sleep(CHAR_GAP)
        if cr:
            s.write(b"\r"); s.flush()

    note("=== %s ===" % a.label)
    time.sleep(1.0); s.reset_input_buffer()

    note("boot: %s" % BOOT_CMD)
    t_boot = time.time()
    send(BOOT_CMD)
    # The banner comes first, but the machine is not ready for a login until
    # the watchdog line appears - THAT is the trigger to press ESC, which
    # SINTRAN answers with the ENTER prompt.
    if not wait_for(r"SINTRAN\s+III\s+RUNNING", a.boot_timeout, "the SINTRAN banner"):
        return 2
    t_banner = time.time() - t_boot
    note("banner after %.1fs" % t_banner)
    if not wait_for(r"Watchdog\s+has\s+started", a.boot_timeout, "the watchdog line"):
        return 2
    note("watchdog after %.1fs - ready for login" % (time.time() - t_boot))
    time.sleep(1.0)

    note("login as SYSTEM")
    s.write(b"\x1b"); s.flush()
    if not wait_for(r"ENTER", 30.0, "the ENTER login prompt"):
        return 2
    send("SYSTEM"); time.sleep(2.0); rx()
    s.write(b"\r"); s.flush(); time.sleep(2.5); rx()   # blank password

    note("SET-T-T,,93")
    send("SET-T-T,,93"); time.sleep(2.5); rx()

    # ---- the measurement -----------------------------------------------
    note("S3 - timing from the submitting CR to the first output byte")
    for ch in "S3":
        s.write(ch.encode()); s.flush(); time.sleep(CHAR_GAP)
    mark = len("".join(buf))
    s.write(b"\r"); s.flush()
    t0 = time.time()

    first = None
    end = t0 + a.s3_timeout
    while time.time() < end:
        got = rx()
        if got:
            tail = "".join(buf)[mark:]
            # ignore the echo of the CR/LF itself
            if tail.strip(" \r\n"):
                first = time.time() - t0
                break
    if first is None:
        note("TIMEOUT: S3 produced no output in %.0fs" % a.s3_timeout)
        return 3

    note("RESULT %s: S3 first output after %.2f s" % (a.label, first))

    time.sleep(3.0); rx()
    note("exit S3 (E, E)")
    send("E"); time.sleep(2.0); rx()
    send("E"); time.sleep(2.0); rx()
    s.close()
    print("S3_SECONDS %s %.2f  (banner %.1fs)" % (a.label, first, t_banner))
    return 0


if __name__ == "__main__":
    sys.exit(main())

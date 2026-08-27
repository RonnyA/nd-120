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
    ap.add_argument("--s3-timeout", type=float, default=1200.0)
    a = ap.parse_args()

    import serial
    s = serial.Serial(a.port, 115200,
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
    # S3 is timed TWICE in one session, because the two runs measure different
    # things (Ronny, 24-AUG-2026): the FIRST start pays a demand-paging storm -
    # every SINTRAN MON call can fault in a page that is not resident yet, and
    # each page-in costs one disc operation = 8 ms of modelled drive latency
    # (ND120_CORE.v:373) plus a fixed-rate SD transfer. Both are WALL-CLOCK
    # constants, so a cold first start should barely improve with a faster CPU.
    # The SECOND start finds the pages resident and shows the CPU-bound cost.
    #
    # Getting this wrong once already produced a false comparison: a 27 MHz
    # "11.4 s" was a WARM start measured against a 6.75 MHz COLD start.
    def time_s3(tag):
        """Type S3, return (first_output_s, menu_s) or (None, None) on timeout."""
        note("draining before S3 (%s)" % tag)
        rx(); time.sleep(2.0); rx()
        note("S3 %s - timing to first real output and to the menu" % tag)
        for ch in "S3":
            s.write(ch.encode()); s.flush(); time.sleep(CHAR_GAP)
        m = len("".join(buf))
        s.write(b"\r"); s.flush()
        t = time.time()
        tf = None
        end2 = t + a.s3_timeout
        while time.time() < end2:
            rx()
            tail = "".join(buf)[m:]
            body = tail.replace("S3", "", 1).strip(" \r\n\x00")
            # the previous command's trailing OK can still be in flight; it is
            # not S3 output, so do not let it stop the clock
            if tf is None and body and body.strip() != "OK":
                tf = time.time() - t
                note("  %s: first real output after %.2f s" % (tag, tf))
            if re.search(r"SINTRAN\s+III\s+configuration", tail, re.I):
                tm = time.time() - t
                note("  %s: MENU after %.2f s" % (tag, tm))
                return tf, tm
        note("  %s: TIMEOUT - no menu in %.0f s" % (tag, a.s3_timeout))
        return tf, None

    cold_first, cold_menu = time_s3("COLD (first start, pages not resident)")
    if cold_menu is not None:
        time.sleep(2.0); rx()
        note("exit S3 (E, E) before the warm run")
        send("E"); time.sleep(2.0); rx()
        send("E"); time.sleep(3.0); rx()
        warm_first, warm_menu = time_s3("WARM (second start, pages resident)")
    else:
        warm_first = warm_menu = None

    note("RESULT %s: cold menu %s s, warm menu %s s"
         % (a.label,
            ("%.2f" % cold_menu) if cold_menu else "TIMEOUT",
            ("%.2f" % warm_menu) if warm_menu else "n/a"))

    time.sleep(3.0); rx()
    note("exit S3 (E, E)")
    send("E"); time.sleep(2.0); rx()
    send("E"); time.sleep(2.0); rx()
    s.close()
    print("S3_RESULT %s banner=%.1fs coldmenu=%s warmmenu=%s"
          % (a.label, t_banner,
             ("%.2f" % cold_menu) if cold_menu else "TIMEOUT",
             ("%.2f" % warm_menu) if warm_menu else "n/a"))
    return 0


if __name__ == "__main__":
    sys.exit(main())

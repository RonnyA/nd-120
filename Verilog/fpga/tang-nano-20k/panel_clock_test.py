#!/usr/bin/env python3
"""
panel_clock_test.py - exercise the MC68705/MM58274 panel clock on the Tang.

Full path:
  Verilog/fpga/tang-nano-20k/panel_clock_test.py

Assumes SINTRAN is ALREADY BOOTED (this does not send 20500&). It presses
ESC for the ENTER prompt, logs in as SYSTEM with a blank password, then runs
whatever commands are given with --cmd, echoing each answer with a timestamp.

Nothing here decides pass or fail - it prints what the machine said. Read the
transcript. That is deliberate: the clock commands' exact syntax is being
established, and a script that guessed would report a verdict it had not
measured.

  python3 panel_clock_test.py --cmd DATCL --cmd "UPDAT" --log <file>

Console is 7E1 at 115200 and drops characters typed at speed, so every
character is sent with a gap.

29-AUG-2026  Ronny Hansen
"""
import argparse, sys, time

CHAR_GAP = 0.30


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--port", default="/dev/ttyUSB1")
    ap.add_argument("--log", default="/tmp/panel_clock_test.log")
    ap.add_argument("--cmd", action="append", default=[],
                    help="command to type at the SINTRAN prompt (repeatable)")
    ap.add_argument("--settle", type=float, default=4.0,
                    help="seconds to collect output after each command")
    ap.add_argument("--login", action="store_true",
                    help="press ESC and log in as SYSTEM first")
    ap.add_argument("--macl", action="store_true",
                    help="issue MACL at the OPCOM prompt first (master clear,\n"
                         "RAM preserved) - the panel clock keeps its time")
    ap.add_argument("--boot", action="store_true",
                    help="send 20500& and wait for the watchdog line")
    a = ap.parse_args()

    import serial
    s = serial.Serial(a.port, 115200,
                      bytesize=serial.SEVENBITS,
                      parity=serial.PARITY_EVEN,
                      stopbits=serial.STOPBITS_ONE,
                      timeout=0.3)
    log = open(a.log, "w", buffering=1)

    def note(m):
        line = "%s %s" % (time.strftime("%H:%M:%S"), m)
        print(line, flush=True); log.write(line + "\n")

    def rx(seconds):
        """Collect for a fixed window, return the text."""
        out = []
        end = time.time() + seconds
        while time.time() < end:
            d = s.read(512)
            if d:
                out.append("".join(chr(b & 0x7F) for b in d))
        t = "".join(out)
        if t:
            log.write(t)
            for ln in t.splitlines():
                if ln.strip():
                    print("    | %s" % ln.rstrip(), flush=True)
        return t

    def send(text, cr=True):
        for ch in text:
            s.write(ch.encode("ascii", "replace")); s.flush(); time.sleep(CHAR_GAP)
        if cr:
            s.write(b"\r"); s.flush()

    time.sleep(1.0); s.reset_input_buffer()

    if a.macl:
        note("MACL (master clear) at the OPCOM prompt")
        send("MACL"); rx(4.0)

    if a.boot:
        note("boot: 20500&")
        t0 = time.time()
        send("20500&")
        # collect until the watchdog line, or give up after 8 minutes. The
        # boot banner is not enough - SINTRAN is not ready for a login until
        # the watchdog has started.
        seen = []
        end = time.time() + 480
        while time.time() < end:
            t = rx(2.0)
            seen.append(t)
            joined = "".join(seen)
            if "Watchdog has started" in joined:
                note("watchdog after %.1fs - ready for login" % (time.time() - t0))
                break
        else:
            note("TIMEOUT waiting for the watchdog line")
        joined = "".join(seen)
        # the message is printed with the high bit set on this console
        clean = "".join(chr(ord(c) & 0x7F) for c in joined).upper()
        if "PANEL CLOCK INCORRECT" in clean:
            note(">>> SINTRAN SAID: ND-100 PANEL CLOCK INCORRECT")
        else:
            note(">>> no 'PANEL CLOCK INCORRECT' line in this boot")

    if a.login:
        note("ESC for the login prompt")
        s.write(b"\x1b"); s.flush()
        rx(6.0)
        note("login as SYSTEM (blank password)")
        send("SYSTEM"); rx(3.0)
        s.write(b"\r"); s.flush(); rx(4.0)

    for c in a.cmd:
        note("command: %s" % c)
        send(c)
        rx(a.settle)

    note("done")
    return 0


if __name__ == "__main__":
    sys.exit(main())

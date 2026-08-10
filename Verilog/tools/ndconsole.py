#!/usr/bin/env python3
"""Drive the ND-120 OPCOM console over the Tang Nano 20K serial port.

WHY THIS FILE EXISTS
--------------------
This script had been rewritten from scratch, into a throwaway temp directory,
19 separate times - once or twice per debugging session - and every copy
rediscovered the same three rules the hard way. It is committed so the next
person (or the next session) starts from a working driver instead of a blank
file.

THE THREE RULES, none of which are guessable
--------------------------------------------
1. UPPERCASE ONLY. OPCOM does not accept lower case.
2. ~0.30 s BETWEEN CHARACTERS. At 0.12 s characters are dropped silently in
   the middle of a number and OPCOM answers '?'. That looks exactly like a
   machine fault and is not one - it is the terminal pacing.
3. 9600 8N1 on /dev/ttyUSB1 (ttyUSB0 is the JTAG side).

AND ONE RULE ABOUT CAPTURING
----------------------------
Output is written to the file AS IT ARRIVES, unbuffered. Two separate
Winchester trace captures were lost by piping a one-shot dump through `tail`,
which throws away the head, and a third by buffering the whole run in memory
and being killed before the single write() at the end. If this script is
killed, whatever arrived is already on disk.

USAGE
-----
    ndconsole.py --seconds 90 --out run.log '400$'
    ndconsole.py --seconds 30 --out idle.log            # listen only
    ndconsole.py --seconds 90 --out fsi.log 'DISC-74MB-1'

Send one command per invocation when the machine prompts between steps: the
inter-command pacing here is character-level only, it does not wait for a
prompt. Poll the output file and issue the next command when the prompt shows.

Requires pyserial. If the port will not open, the board is probably not
attached to WSL - run `make usb` in Verilog/fpga/tang-nano-20k.

Ronny Hansen
"""
import argparse
import sys
import time

try:
    import serial
except ImportError:
    sys.exit("ndconsole: pyserial is not installed (pip install pyserial)")

DEFAULT_PORT = "/dev/ttyUSB1"
DEFAULT_BAUD = 9600
DEFAULT_GAP = 0.30


def main():
    ap = argparse.ArgumentParser(description="Drive the ND-120 OPCOM console.")
    ap.add_argument("commands", nargs="*",
                    help="commands to send, each followed by CR (UPPERCASE)")
    ap.add_argument("--port", default=DEFAULT_PORT)
    ap.add_argument("--baud", type=int, default=DEFAULT_BAUD)
    ap.add_argument("--gap", type=float, default=DEFAULT_GAP,
                    help="seconds between characters (default 0.30; below "
                         "0.20 OPCOM drops characters)")
    ap.add_argument("--cmd-gap", type=float, default=0.0,
                    help="seconds to wait AFTER each command's CR before "
                         "sending the next one (default 0). Needed for any "
                         "program that prompts: the File System Investigator "
                         "asks Device name / Device unit in turn, and sending "
                         "the answers back to back loses them.")
    ap.add_argument("--seconds", type=float, default=60.0,
                    help="how long to keep listening after the last command")
    ap.add_argument("--out", default=None,
                    help="write everything received here, unbuffered")
    ap.add_argument("--echo", action="store_true",
                    help="also copy received bytes to stdout")
    args = ap.parse_args()

    if args.gap < 0.20:
        sys.stderr.write("ndconsole: WARNING gap %.2fs is below the 0.20s "
                         "floor - OPCOM will drop characters\n" % args.gap)

    for c in args.commands:
        if c != c.upper():
            sys.stderr.write("ndconsole: WARNING %r is not uppercase - "
                             "OPCOM will reject it\n" % c)

    try:
        s = serial.Serial(args.port, args.baud, timeout=0.3)
    except Exception as e:
        sys.exit("ndconsole: cannot open %s (%s)\n"
                 "  the board is probably not attached to WSL - run "
                 "`make usb` in Verilog/fpga/tang-nano-20k" % (args.port, e))

    sink = open(args.out, "wb", buffering=0) if args.out else None

    def drain():
        c = s.read(256)
        if c:
            if sink:
                sink.write(c)
            if args.echo or not sink:
                sys.stdout.write(c.decode("latin-1"))
                sys.stdout.flush()

    time.sleep(0.3)
    s.reset_input_buffer()

    for cmd in args.commands:
        for ch in cmd:
            s.write(ch.encode("latin-1"))
            s.flush()
            end = time.time() + args.gap
            while time.time() < end:      # keep draining while pacing, so
                drain()                   # nothing is missed between chars
        s.write(b"\r")
        s.flush()
        end = time.time() + args.cmd_gap
        while time.time() < end:          # keep draining while waiting, so the
            drain()                       # prompt we are pausing for is kept

    t0 = time.time()
    while time.time() - t0 < args.seconds:
        drain()

    s.close()
    if sink:
        sink.close()
        sys.stderr.write("ndconsole: wrote %s\n" % args.out)


if __name__ == "__main__":
    main()

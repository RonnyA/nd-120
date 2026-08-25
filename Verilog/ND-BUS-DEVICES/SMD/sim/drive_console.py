#!/usr/bin/env python3
"""Drive the runSim console with a sequence of commands and log everything.

Run it FROM the Verilog directory (it starts ./obj_dir/VND120_TOP inside
runSim). Build the simulator first, e.g.

  make -C runSim compile USE_LATCHES=0 VERILOG_TAPE=1 SD_STORAGE=0 \
       EXTRA_VDEFINES="-DND120_SMD_TRACE"

then, for the DISC-TEMA disc diagnostic against the SMD at 1540:

  ND120_FLOPPY_IMG=FLOPPY.IMG ND120_SMD_IMG=<smd image> \
  python3 ND-BUS-DEVICES/SMD/sim/drive_console.py /tmp/out.log 1500 \
      '1560&' 420 'dis' 90 'DISC-75MB-1' 120 'du-di-c' 60 '0' 700

Ronny Hansen

Usage: drive_console.py <logfile> <total-seconds> <cmd1> <wait1> [<cmd2> <wait2> ...]

Waits for the first OPCOM '#', then types each command (0.3 s per character,
CR at the end) and waits the given number of seconds before the next one.
Used to check whether typed characters come back doubled - the echo question -
without any hardware.
"""
import os
import subprocess
import sys
import threading
import time

logpath = sys.argv[1]
total = float(sys.argv[2])
pairs = sys.argv[3:]

proc = subprocess.Popen(
    ["./obj_dir/VND120_TOP"],
    cwd="runSim",
    stdin=subprocess.PIPE,
    stdout=subprocess.PIPE,
    stderr=subprocess.STDOUT,
    env=dict(os.environ),
)

log = open(logpath, "wb")
seen = threading.Event()


def pump():
    while True:
        c = proc.stdout.read(1)
        if not c:
            break
        log.write(c)
        log.flush()
        if c == b"#":
            seen.set()


threading.Thread(target=pump, daemon=True).start()

if not seen.wait(timeout=600):
    print("NO PROMPT", flush=True)
    proc.kill()
    sys.exit(2)

time.sleep(2.0)
for i in range(0, len(pairs), 2):
    cmd, wait = pairs[i], float(pairs[i + 1])
    print("typing %r" % cmd, flush=True)
    for ch in cmd + "\r":
        proc.stdin.write(ch.encode())
        proc.stdin.flush()
        time.sleep(0.3)
    time.sleep(wait)

time.sleep(total)
proc.kill()
print("done", flush=True)

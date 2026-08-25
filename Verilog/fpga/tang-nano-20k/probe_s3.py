#!/usr/bin/env python3
"""probe_s3.py - run S3 and log EVERYTHING for 90 s, judging nothing.

Learns what S3 actually prints, so a real timing marker can be defined.
Assumes the console is already logged in at the '@' prompt.
"""
import sys, time, serial

port = sys.argv[1] if len(sys.argv) > 1 else "/dev/ttyUSB1"
s = serial.Serial(port, 9600, bytesize=serial.SEVENBITS,
                  parity=serial.PARITY_EVEN, stopbits=serial.STOPBITS_ONE,
                  timeout=0.3)

def rx(sec):
    end = time.time() + sec
    out = []
    while time.time() < end:
        d = s.read(512)
        if d:
            out.append("".join(chr(b & 0x7F) for b in d))
    return "".join(out)

def send(t, gap=0.30):
    for ch in t:
        s.write(ch.encode()); s.flush(); time.sleep(gap)
    s.write(b"\r"); s.flush()

time.sleep(0.5); s.reset_input_buffer()
s.write(b"\r"); s.flush()
print("--- prompt check ---"); print(repr(rx(3)))

print("--- sending S3, logging 90 s, timestamped ---")
send("S3")
t0 = time.time()
end = t0 + 90
last = ""
while time.time() < end:
    d = s.read(256)
    if d:
        t = "".join(chr(b & 0x7F) for b in d)
        for line in t.replace("\r", "\n").split("\n"):
            if line.strip():
                print("[+%6.2fs] %s" % (time.time() - t0, line))
        last = t
s.close()

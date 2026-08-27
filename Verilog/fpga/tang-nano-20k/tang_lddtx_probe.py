#!/usr/bin/env python3
"""
tang_lddtx_probe.py - after SINTRAN's ERRFATAL halt, deposit a 5-word program
through OPCOM and run it, to measure what the physical-bank double load LDDTX
returns on the Tang for the segment-table entry the page-fault handler uses.

Full path: Verilog/fpga/tang-nano-20k/tang_lddtx_probe.py (repo-relative)

WHY (23-AUG-2026): on the oracle, the fault at VA 064540 is resolved by
SINCHECK -> LIMCHECK(FILSEGM), whose LDDTX reads bank T=2, X=134060 and gets
A=000413 (LOGADR) D=000065 (length) - page 0o432 is inside, so SINTRAN pages
it in. On the Tang the same fault dispatches, PGS is correct, and the page is
never paged in. If LDDTX here returns something else (zeros, bank-0 data),
LIMCHECK says "outside" for every segment and the handler declines - root
cause region found.

PROGRAM (assembled with nd100-as; LDDTX opcode 0143302 from nd100-dis):
  2000/171002  SAT 2         T := bank 2   (control run uses SAT 0 = 171000)
  2001/054003  LDX vec       X := word at 2004
  2002/143302  LDDTX         A,D := bank[T] words X, X+1
  2003/151000  WAIT
  2004/134060  vec
CONTROL first: T=0, X=2004 -> LDDTX must return A=134060 (the cell itself),
D = word at 2005 - proves the probe mechanics before the bank-2 question.

USAGE  python3 tang_lddtx_probe.py [--port /dev/ttyUSB1] [--boot] [--log FILE]
  --boot : send 20500& first and wait for ERRFATAL (max 6 min) before probing.
"""
import argparse, sys, time
import serial

GAP = 0.30

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--port", default="/dev/ttyUSB1")
    ap.add_argument("--boot", action="store_true")
    ap.add_argument("--log", default="tang_lddtx_probe.log")
    ap.add_argument("--macl", action="store_true", help="issue MACL (master clear) before probing - needed after an ERRFATAL halt, where ! does not run")
    a = ap.parse_args()
    s = serial.Serial(a.port, 115200, timeout=0.3)
    log = open(a.log, "w", buffering=1)

    def emit(t):
        line = "%s %s" % (time.strftime("%H:%M:%S"), t)
        print(line, flush=True); log.write(line + "\n")

    def send(text, settle=0.8):
        for ch in text:
            s.write(ch.encode()); s.flush(); time.sleep(GAP)
        time.sleep(settle)
        out = s.read(4096).decode("latin-1", errors="replace")
        log.write(out)
        return out

    def cmd(text):
        out = send(text + "\r")
        emit("> %-16s | %s" % (text, out.replace("\r", "").replace("\n", " ").strip()))
        return out

    if a.boot:
        emit("booting 20500& and waiting for ERRFATAL")
        send("20500&\r", settle=0.5)
        t0 = time.time(); buf = ""
        while time.time() - t0 < 360:
            chunk = s.read(512).decode("latin-1", errors="replace")
            if chunk:
                log.write(chunk); buf += chunk
                if "ERRFATAL" in buf:
                    time.sleep(3); s.read(4096); break
        else:
            emit("no ERRFATAL within 6 min - probing anyway"); 
        emit("halt seen after %.0f s" % (time.time() - t0))

    cmd("")                        # expect '#'
    if a.macl:
        cmd("MACL"); time.sleep(2); s.read(4096)
        emit("MACL issued (master clear, RAM preserved)")
    words = ["171000", "054003", "143302", "151000", "134060"]   # control: SAT 0
    def deposit(wlist):
        for i, w in enumerate(wlist):
            cmd("%o/%s" % (0o2000 + i, w))
        ok = True
        for i, w in enumerate(wlist):
            r = cmd("%o/" % (0o2000 + i))
            if w not in r: ok = False
        emit("deposit readback %s" % ("OK" if ok else "MISMATCH - do not trust the run"))

    def run_and_read(label):
        cmd("A/0"); cmd("D/0"); cmd("P/2000"); cmd("!"); time.sleep(1.5)
        s.read(4096)
        ra = cmd("A/"); rd = cmd("D/"); rt = cmd("T/"); rx = cmd("X/"); rp = cmd("P/")
        emit("RESULT %s: A=%s D=%s T=%s X=%s P=%s" % (label,
             ra.strip()[-7:], rd.strip()[-7:], rt.strip()[-7:], rx.strip()[-7:], rp.strip()[-7:]))

    emit("== CONTROL: T=0 X=2004 -> expect A=134060, D=word at 2005 ==")
    cmd("2005/"); deposit(words); run_and_read("control")
    emit("== TEST: T=2 X=134060 -> oracle expects A=000413 D=000065 ==")
    words[0] = "171002"           # SAT 2
    deposit(words); run_and_read("bank2 FILSEGM entry")
    emit("== TEST 2: T=2 X=134050 -> oracle expects A=000762 D=000001 ==")
    words[4] = "134050"
    deposit(words); run_and_read("bank2 SEGMA entry")
    s.close(); return 0

if __name__ == "__main__":
    sys.exit(main())

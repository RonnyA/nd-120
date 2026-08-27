#!/usr/bin/env python3
"""
ptwr_capture_decode.py - boot the Tang and decode the PAGE-TABLE WRITE history
ring (TANG_PTWR_CAPTURE build), or decode an existing log.

Full path:
  Verilog/fpga/tang-nano-20k/ptwr_capture_decode.py

WHAT THE RING HOLDS
  One 20-bit hex record per line, low 16 bits = DBG_PTW from CPU_MMU_24
  (the [19:16] nibble is the source tag 0xB). Each page-table write emits
  TWO consecutive words:
    word A: [15:14]=10  [13:3]=addr (raw 11-bit LA_20_10 index)  [2:0]=data[15:13]
    word B: [15:14]=11  [13:1]=data[12:0]                        [0]=0
  512 ring entries = the last ~256 writes before the ERRFATAL trigger.

THE DECODE
  software page-table index = raw[9:0] XOR 0o1400 (top two table bits are
  complemented in hardware; TRA PGS un-inverts them - match established
  21-AUG-2026). data[15:9] are the status bits WPM RPM FPM WIP PGU ring1 ring0.

THE QUESTION THE DUMP ANSWERS (23-AUG campaign, zero-read root cause)
  Does ANY write land at software 0o432 (raw 0o1032) - the page that faults
  correctly, is reported correctly in PGS, and still refaults forever?
    - writes at 0o432 present with sane data -> the write lands; the refault
      cause moves to the entry being cleared/overwritten afterwards
    - NO write at 0o432, but writes at OTHER indices right after its faults
      -> the handler wrote the WRONG ROW (indexing bug)
    - NO writes at all -> the write strobe never reaches the PT RAM
      (Issue-D family: check PAL_44306A terms and WMAP_n = LSHADOW&WRITE&CYD)

USAGE
    python3 ptwr_capture_decode.py [--port /dev/ttyUSB1] [--minutes 15]
    python3 ptwr_capture_decode.py --decode-file <log>

23-AUG-2026  Ronny Hansen
"""

import argparse
import re
import sys
import time

BOOT_CMD = "20500&"
CHAR_GAP = 0.30  # this console drops characters without a gap

SW_XOR = 0o1400
TARGET_RAW = 0o1032  # software 0o432 - the refaulting page


def sw(raw10):
    return (raw10 & 0x3FF) ^ SW_XOR


def extract_samples(text):
    out = []
    for h in re.findall(r"(?m)^\s*([0-9a-fA-F]{4,5})\s*$", text):
        out.append(int(h, 16) & 0xFFFF)
    return out


def decode(samples):
    """Pair A/B words into (raw_addr, data16) writes, in ring order."""
    writes = []
    attempts = []
    pend = None  # (addr, data_hi3)
    dropped = 0
    for v in samples:
        tag = (v >> 14) & 0x3
        if tag == 0b01:
            attempts.append(((v >> 3) & 0x7FF, v & 0x7))
            continue
        if tag == 0b10:
            if pend is not None:
                dropped += 1
            pend = ((v >> 3) & 0x7FF, v & 0x7)
        elif tag == 0b11:
            if pend is None:
                dropped += 1
                continue
            addr, hi3 = pend
            data = (hi3 << 13) | ((v >> 1) & 0x1FFF)
            writes.append((addr, data))
            pend = None
        # tag 00 = idle filler (should not be in the ring - stb gates it out)
    return writes, attempts, dropped


def report(writes, attempts, dropped):
    print("")
    print("=" * 66)
    print(" PAGE-TABLE WRITE HISTORY (%d writes, %d ATTEMPTS, %d unpaired)"
          % (len(writes), len(attempts), dropped))
    print("=" * 66)
    if attempts and not writes:
        print(" ATTEMPTS present, WRITE STROBES absent: the shadow write reaches")
        print(" the IDB->PT transfer (EPTI & WRITE) but the RAM strobe (EPT &")
        print(" WMAP = LSHADOW & WRITE & CYD) never fires. The break is in that")
        print(" conjunction or PAL_44306A's EPT/EPMAP terms - ON SILICON ONLY.")
        print(" last 10 attempts (addr raw -> software):")
        for addr, hi3 in attempts[-10:]:
            s = sw(addr)
            print("   raw %06o -> sw %06o (table %2o page %2o) data[15:13]=%o"
                  % (addr, s, (s >> 6) & 0xF, s & 0x3F, hi3))
        print("=" * 66)
        return
    if not writes:
        print(" NO page-table writes AND NO attempts in the ring at all.")
        print(" Either the machine never executed a shadow page-table write")
        print(" after arming, or the probe/ring path is dead - cross-check the")
        print(" Verilator [pt] WRI counts for the same boot phase.")
        print(" If the machine reached SINTRAN fault service before the trigger,")
        print(" the handler's entry writes never reach the PT RAM - the write")
        print(" strobe path (WMAP_n = LSHADOW & WRITE & CYD, PAL_44306A EPT/")
        print(" EPMAP terms) is the place to look. If the trigger fired before")
        print(" SINTRAN ran, this dump says nothing - check the console log.")
        print("=" * 66)
        return
    target_hits = 0
    by_addr = {}
    for addr, data in writes:
        by_addr[addr] = by_addr.get(addr, 0) + 1
        if (addr & 0x3FF) == TARGET_RAW:
            target_hits += 1
    print(" writes to the REFAULTING page raw %06o (software %06o): %d"
          % (TARGET_RAW, sw(TARGET_RAW), target_hits))
    print("")
    print(" last 40 writes (oldest first):")
    for addr, data in writes[-40:]:
        s = sw(addr)
        st = (data >> 9) & 0x7F
        mark = "  <== TARGET" if (addr & 0x3FF) == TARGET_RAW else ""
        print("   raw %06o -> sw %06o (table %2o page %2o)  data %06o  "
              "WPM=%d RPM=%d FPM=%d WIP=%d PGU=%d%s"
              % (addr, s, (s >> 6) & 0xF, s & 0x3F, data,
                 (st >> 6) & 1, (st >> 5) & 1, (st >> 4) & 1,
                 (st >> 3) & 1, (st >> 2) & 1, mark))
    print("")
    print(" per-index totals (top 15):")
    for addr, n in sorted(by_addr.items(), key=lambda kv: -kv[1])[:15]:
        s = sw(addr)
        print("   raw %06o -> sw %06o (table %2o page %2o) : %d writes"
              % (addr, s, (s >> 6) & 0xF, s & 0x3F, n))
    print("=" * 66)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--port", default="/dev/ttyUSB1")
    ap.add_argument("--baud", type=int, default=115200)
    ap.add_argument("--minutes", type=float, default=15.0)
    ap.add_argument("--log", default="ptwr_capture_run.log")
    ap.add_argument("--decode-file")
    args = ap.parse_args()

    if args.decode_file:
        text = open(args.decode_file, "r", errors="replace").read()
        writes, attempts, dropped = decode(extract_samples(text))
        report(writes, attempts, dropped)
        return 0

    import serial  # here so --decode-file works without pyserial

    s = serial.Serial(args.port, args.baud, timeout=0.5)
    log = open(args.log, "w", buffering=1)

    def emit(line):
        stamp = time.strftime("%H:%M:%S")
        print("%s %s" % (stamp, line), flush=True)
        log.write("%s %s\n" % (stamp, line))

    emit("port %s @ %d, deadline %.0f min" % (args.port, args.baud, args.minutes))
    time.sleep(1.0)
    s.reset_input_buffer()
    emit("sending %r one character at a time (%.2fs gap)" % (BOOT_CMD, CHAR_GAP))
    for ch in BOOT_CMD:
        s.write(ch.encode())
        s.flush()
        time.sleep(CHAR_GAP)
    s.write(b"\r")
    s.flush()

    deadline = time.time() + args.minutes * 60
    buf = ""
    raw = []
    reopens = 0
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
                s = serial.Serial(args.port, args.baud, timeout=0.5)
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

    s.close()
    emit("collection finished")
    writes, attempts, dropped = decode(extract_samples("".join(raw)))
    report(writes, attempts, dropped)
    return 0


if __name__ == "__main__":
    sys.exit(main())

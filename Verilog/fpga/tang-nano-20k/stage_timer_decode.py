#!/usr/bin/env python3
"""stage_timer_decode.py - decode the TANG_STAGE_TIMER dump.

Answers: of the ~1 second a disc operation costs on the Tang, how much is the
card actually busy, and how much is it idle and waiting?

Records are {tag,16} in the ring:
  1 t_all  2 t_wd  3 t_dma  4 t_sd  5 t_cache  (each 3 records, LSW first)
  6 n_ops  (2 records)
All tick counts are clk_cpu ticks.
"""
import argparse, re, sys

NAMES = {1: "total elapsed", 2: "Winchester ACTIVE", 3: "DMA busy",
         4: "SD card read", 5: "cache lookup", 6: "operations"}


def parse(text):
    vals = {}
    parts = {}
    for line in text.splitlines():
        m = re.match(r"^\s*([0-9A-Fa-f]{4,5})\s*$", line)
        if not m:
            continue
        w = int(m.group(1), 16)
        tag, v = (w >> 16) & 0xF, w & 0xFFFF
        if tag in NAMES:
            parts.setdefault(tag, []).append(v)
    for tag, ws in parts.items():
        acc = 0
        for i, v in enumerate(ws[:3]):
            acc |= v << (16 * i)
        vals[tag] = acc
    return vals


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("dumpfile")
    ap.add_argument("--mhz", type=float, default=27.0, help="clk_cpu in MHz")
    a = ap.parse_args()
    v = parse(open(a.dumpfile, errors="replace").read())
    if not v:
        print("no stage-timer records found - was the probe stripped?")
        return 1

    def sec(t):
        return t / (a.mhz * 1e6)

    tot = v.get(1, 0)
    ops = v.get(6, 0)
    print("")
    print("=" * 64)
    print(" DISC OPERATION STAGE TIMER   (clk_cpu %.2f MHz)" % a.mhz)
    print("=" * 64)
    print("  operations completed : %d" % ops)
    print("  total elapsed        : %10.2f s" % sec(tot))
    for tag in (2, 3, 4, 5):
        t = v.get(tag, 0)
        share = (100.0 * t / tot) if tot else 0
        print("  %-20s : %10.2f s  (%5.1f%% of elapsed)"
              % (NAMES[tag], sec(t), share))
    print("")
    if ops:
        wd = v.get(2, 0)
        print("  per operation: %.1f ms of Winchester-active time"
              % (1000.0 * sec(wd) / ops))
        for tag in (3, 4, 5):
            print("    of which %-14s %.1f ms"
                  % (NAMES[tag] + ":", 1000.0 * sec(v.get(tag, 0)) / ops))
        idle = wd - v.get(3, 0) - v.get(4, 0) - v.get(5, 0)
        print("    UNACCOUNTED         %.1f ms  <-- card active but no stage busy"
              % (1000.0 * sec(idle) / ops))
        print("")
        if idle > 0.5 * wd:
            print("  VERDICT: most of a disc operation is the controller sitting")
            print("  ACTIVE with nothing happening - not SD, not DMA, not cache.")
            print("  Look at what ends the operation: the completion path.")
        else:
            print("  VERDICT: the stages account for the time; the largest one above")
            print("  is the bottleneck and the place to optimise.")
    print("=" * 64)
    return 0


if __name__ == "__main__":
    sys.exit(main())

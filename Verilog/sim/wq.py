#!/usr/bin/env python3
"""
wq.py - waveform query. Edge-accurate signal timelines from an FST or VCD.

WHY THIS EXISTS
---------------
This directory accumulated twenty-odd single-use scripts (trace_before_lc1.py,
find_panvc.py, check_idb_at_ldlc.py, ...), each re-solving the same problem for
one signal on one day. Worse, the general CSV sampler in nd120_probe.py takes
ONE SETTLED SAMPLE PER TICK, so it cannot see anything that happens within a
cycle state - it produced several confident and wrong answers during the
TRA CS investigation before that was noticed.

This tool prints EVERY transition, at the resolution the waveform actually has.
If a signal glitches high for one delta and back, it shows up here. Nothing is
resampled and nothing is averaged.

It streams (via fst2vcd for .fst), so it does not load the file into memory and
it does not write a multi-gigabyte intermediate - which matters, because
artefacts in this repo are capped at 1 GB.

USAGE
-----
  # what signals exist (substring match, case-insensitive)
  python3 wq.py waveform.fst --list maclk

  # transition table for some signals over a time window
  python3 wq.py waveform.fst -s MACLK,TERM_n,LUA_12_0 -w 565800:566000

  # only the rows where a particular signal changed
  python3 wq.py waveform.fst -s MACLK,IDB_15_0 --edges MACLK

  # octal, which is how this machine is documented
  python3 wq.py waveform.fst -s LUA_12_0,CSA_12_0 --octal

Signal names match on suffix, so 'MACLK' finds 'TOP.dut.cpu.MACLK'. Use a
longer tail to disambiguate; --list shows the full names and how many matched.
"""

import argparse
import re
import sys

try:
    from fst import open_wave
except ImportError:                                    # standalone use
    import io
    import subprocess

    def open_wave(path, buffering=8 * 1024 * 1024):
        if path.endswith(".fst"):
            proc = subprocess.Popen(["fst2vcd", path],
                                    stdout=subprocess.PIPE,
                                    stderr=subprocess.DEVNULL)
            return io.TextIOWrapper(proc.stdout, buffering=buffering)
        return open(path, "r", buffering=buffering)


def parse_window(spec):
    if not spec:
        return None, None
    m = re.fullmatch(r"(\d*):(\d*)", spec)
    if not m:
        sys.exit("--window wants T0:T1, e.g. 565800:566000 (either side may be blank)")
    lo = int(m.group(1)) if m.group(1) else None
    hi = int(m.group(2)) if m.group(2) else None
    return lo, hi


def fmt(val, octal):
    """Format a VCD scalar or vector value."""
    if val is None:
        return "-"
    if not octal or not re.fullmatch(r"[01]+", val):
        return val
    return "o%o" % int(val, 2)


def main():
    ap = argparse.ArgumentParser(
        description="Edge-accurate signal timeline from an FST/VCD waveform.")
    ap.add_argument("wave", help="path to .fst or .vcd")
    ap.add_argument("-s", "--signals", default="",
                    help="comma-separated signal names (suffix match)")
    ap.add_argument("-w", "--window", default="",
                    help="time window T0:T1 (waveform time units)")
    ap.add_argument("--edges", default="",
                    help="only print rows where this signal changed")
    ap.add_argument("--octal", action="store_true",
                    help="show vector values in octal (ND-120 convention)")
    ap.add_argument("--list", dest="listpat", default=None,
                    help="list matching signal names and exit")
    ap.add_argument("--max-rows", type=int, default=2000,
                    help="stop after this many printed rows (default 2000)")
    args = ap.parse_args()

    t0, t1 = parse_window(args.window)
    wanted = [w.strip() for w in args.signals.split(",") if w.strip()]

    if not wanted and args.listpat is None:
        sys.exit("give -s/--signals, or --list to find names first")

    # ---------------- pass 1: the $var header ----------------
    # id -> full hierarchical name, and the reverse for what we asked for
    id_name = {}
    id_width = {}
    scope = []
    names_seen = []

    wave = open_wave(args.wave)
    for line in wave:
        s = line.strip()
        if s.startswith("$scope"):
            parts = s.split()
            if len(parts) >= 3:
                scope.append(parts[2])
        elif s.startswith("$upscope"):
            if scope:
                scope.pop()
        elif s.startswith("$var"):
            # $var wire 16 ! NAME [15:0] $end
            p = s.split()
            if len(p) >= 5:
                width, vid, base = p[2], p[3], p[4]
                full = ".".join(scope + [base])
                id_name.setdefault(vid, full)
                id_width[vid] = int(width)
                names_seen.append((full, vid))
        elif s.startswith("$enddefinitions"):
            break

    if args.listpat is not None:
        pat = args.listpat.lower()
        hits = [n for n, _ in names_seen if pat in n.lower()]
        for n in sorted(set(hits)):
            print(n)
        print(f"\n{len(set(hits))} match '{args.listpat}' "
              f"of {len(set(n for n, _ in names_seen))} signals", file=sys.stderr)
        return 0

    # resolve requested names by suffix
    # Matching is case-insensitive: signal names in this tree mix conventions
    # (ECSL_n in the RTL, ecsl_n in a testbench wire), and having to guess the
    # case defeats the point of a suffix match.
    watch = []          # (label, vid)
    for w in wanted:
        wl = w.lower()
        cands = [(n, v) for n, v in names_seen
                 if n.lower() == wl or n.lower().endswith("." + wl)
                 or n.split(".")[-1].lower() == wl]
        if not cands:
            sys.stdout.flush()
            print(f"no signal matches '{w}' - try --list {w}", file=sys.stderr)
            continue
        uniq = sorted(set(cands))
        if len(uniq) > 1:
            print(f"note: '{w}' matches {len(uniq)} signals, using {uniq[0][0]} "
                  f"(use a longer name tail to pick another)", file=sys.stderr)
        watch.append((w, uniq[0][1]))

    if not watch:
        sys.exit("nothing to watch")

    edge_vid = None
    if args.edges:
        for label, vid in watch:
            if label == args.edges:
                edge_vid = vid
        if edge_vid is None:
            sys.exit(f"--edges '{args.edges}' is not in --signals")

    watch_ids = {vid for _, vid in watch}
    cur = {vid: None for vid in watch_ids}

    # ---------------- pass 2: value changes ----------------
    print("time".rjust(12) + "  " + "  ".join(lbl.rjust(10) for lbl, _ in watch))
    print("-" * (12 + 2 + 12 * len(watch)))

    now = 0
    rows = 0
    dirty = False
    edge_hit = False
    printed_any = False

    def flush():
        nonlocal rows, dirty, edge_hit, printed_any
        if not dirty:
            return True
        if t0 is not None and now < t0:
            dirty = False
            edge_hit = False
            return True
        if t1 is not None and now > t1:
            return False
        if edge_vid is not None and not edge_hit:
            dirty = False
            return True
        print(str(now).rjust(12) + "  " +
              "  ".join(fmt(cur[v], args.octal).rjust(10) for _, v in watch))
        printed_any = True
        rows += 1
        dirty = False
        edge_hit = False
        return rows < args.max_rows

    for line in wave:
        s = line.strip()
        if not s:
            continue
        c = s[0]
        if c == "#":
            if not flush():
                break
            try:
                now = int(s[1:])
            except ValueError:
                continue
            if t1 is not None and now > t1:
                break
        elif c in "01xzXZ":
            vid = s[1:]
            if vid in watch_ids:
                if cur[vid] != c:
                    dirty = True
                    if vid == edge_vid:
                        edge_hit = True
                cur[vid] = c
        elif c in "bB":
            parts = s.split()
            if len(parts) == 2 and parts[1] in watch_ids:
                vid, val = parts[1], parts[0][1:]
                if cur[vid] != val:
                    dirty = True
                    if vid == edge_vid:
                        edge_hit = True
                cur[vid] = val
        elif c in "rR":
            parts = s.split()
            if len(parts) == 2 and parts[1] in watch_ids:
                vid, val = parts[1], parts[0][1:]
                if cur[vid] != val:
                    dirty = True
                    if vid == edge_vid:
                        edge_hit = True
                cur[vid] = val

    flush()

    sys.stdout.flush()
    if not printed_any:
        print("\n(no transitions in that window - widen -w, or check --list)",
              file=sys.stderr)
    elif rows >= args.max_rows:
        print(f"\nstopped at --max-rows {args.max_rows}; narrow -w to see more",
              file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main())

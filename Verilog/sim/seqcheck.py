#!/usr/bin/env python3
"""Clock-refactor acceptance gate: compare the microcode ADDRESS SEQUENCE
(de-duplicated CSA) of trace_latch.csv vs trace_ff.csv.

Cycle-exact `make compare` is the wrong gate for clock-domain changes (it is both
too strict - benign phase shifts trip it - and too weak - the R41P edge-detect bug
passed the o002001/o002047 milestone check yet took a wrong branch). The right test
is: does FF visit the SAME microcode addresses in the SAME ORDER as the golden latch
run? Timing/dwell may differ; the ordered sequence must not.

Usage:  python3 seqcheck.py   (run from sim/ after `make compare`)
Exit 0 = sequences identical (PASS), 1 = divergence (FAIL).
"""
import csv, sys

def load(fn):
    rows = list(csv.reader(open(fn)))
    hi = next(i for i, r in enumerate(rows[:5]) if any(c.lower() == 'cycle' for c in r))
    return rows[hi], rows[hi + 1:]

def seq(rows, j):
    out, last = [], None
    for r in rows:
        if len(r) <= j:
            continue
        v = r[j]
        if v != last:
            out.append(v); last = v
    return out

def main():
    h, la = load('trace_latch.csv')
    _, ff = load('trace_ff.csv')
    j = h.index('CSA')
    sl, sf = seq(la, j), seq(ff, j)
    # boot milestones on FF
    m = {1025: 'o002001', 1063: 'o002047'}
    hit = {}
    for r in ff:
        if len(r) <= j:
            continue
        try:
            v = int(r[j])
        except ValueError:
            continue
        if v in m and v not in hit:
            hit[v] = r[0]
    print(f"latch CSA transitions={len(sl)}  ff={len(sf)}")
    for k in (1025, 1063):
        print(f"  FF reaches {m[k]} @ {hit.get(k, 'NEVER')}")
    n = min(len(sl), len(sf))
    d = next((i for i in range(n) if sl[i] != sf[i]), None)
    if d is None and len(sl) == len(sf):
        print("PASS: address sequences IDENTICAL")
        return 0
    if d is None:
        print(f"NOTE: one sequence is a prefix of the other (latch={len(sl)} ff={len(sf)});"
              " likely a tail/dwell difference - inspect.")
        return 1
    lo = max(0, d - 4)
    fmt = lambda s: [f"o{int(x):o}" for x in s]
    print(f"FAIL: sequences diverge at transition #{d}")
    print("  latch:", fmt(sl[lo:d + 5]))
    print("  ff   :", fmt(sf[lo:d + 5]))
    return 1

if __name__ == '__main__':
    sys.exit(main())

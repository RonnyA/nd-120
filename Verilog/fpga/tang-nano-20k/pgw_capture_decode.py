#!/usr/bin/env python3
"""
pgw_capture_decode.py - decode the SDRAM-bridge PAGE-WRITE WATCH ring
(TANG_PGW_CAPTURE build).

Full path:
  Verilog/fpga/tang-nano-20k/pgw_capture_decode.py

WHY (24-AUG-2026, run 16)
  Run 15 measured the fetch at 064544 resolving to PPN 0o3770 = physical page
  2040 = {BANK2, row 1016} - REAL, POPULATED memory that still reads 000000.
  So the disc data was never stored there. This ring records every access to
  that page's neighbourhood (rows 1016..1023, both banks) AT THE SDRAM BRIDGE,
  the last point before the chip.

RECORD FORMAT (5 hex digits per line, top nibble 0xB)
    word A: [15:14]=10  [13]=bank  [12:3]=row  [2:0]=data[15:13]
    word B: [15:14]=11  [13:1]=data[12:0]      [0]=0
    read  : [15:14]=01  [13]=bank  [12:3]=row  [2:0]=0
  physical page = bank*1024 + row  (BANK0 = pages 0..1023, BANK2 = 1024..2047)

USAGE
    python3 pgw_capture_decode.py <log>
    python3 pgw_capture_decode.py --selftest
"""

import argparse
import re
import sys

TARGET_PAGE = 2040          # PPN 0o3770, measured in run 15
ENTRY_RE = re.compile(r"^\s*([0-9A-Fa-f]{4,5})\s*$")


def parse(text):
    out = []
    for line in text.splitlines():
        m = ENTRY_RE.match(line)
        if m:
            out.append(int(m.group(1), 16) & 0xFFFFF)
    return out


def decode(samples):
    """Return [(kind, page, data)] in ring order; kind is 'write' or 'read'."""
    events = []
    pend = None
    for v in samples:
        if ((v >> 16) & 0xF) != 0xB:
            continue
        w = v & 0xFFFF
        tag = (w >> 14) & 3
        page = (((w >> 13) & 1) * 1024) + ((w >> 3) & 0x3FF)
        if tag == 0b01:
            events.append(("read", page, None))
        elif tag == 0b10:
            pend = (page, w & 0x7)
        elif tag == 0b11 and pend is not None:
            page, hi3 = pend
            events.append(("write", page, (hi3 << 13) | ((w >> 1) & 0x1FFF)))
            pend = None
    return events


def report(events, out=sys.stdout):
    print("", file=out)
    print("=" * 68, file=out)
    print(" SDRAM-BRIDGE ACCESSES to physical pages 1016-1023 and 2040-2047",
          file=out)
    writes = [e for e in events if e[0] == "write"]
    reads = [e for e in events if e[0] == "read"]
    print(" %d records: %d writes, %d reads   (target page %d)"
          % (len(events), len(writes), len(reads), TARGET_PAGE), file=out)
    print("=" * 68, file=out)
    if not events:
        print(" RING EMPTY - no access to this neighbourhood reached the bridge", file=out)
        print(" before the trigger. Check the console log for the ERRFATAL.", file=out)
        print("=" * 68, file=out)
        return 0

    for kind, page, data in events[-40:]:
        mark = "  <== TARGET" if page == TARGET_PAGE else ""
        if kind == "write":
            print("   WRITE page %4d  data %06o%s" % (page, data, mark), file=out)
        else:
            print("   READ  page %4d%s" % (page, mark), file=out)

    tw = [d for k, p, d in events if k == "write" and p == TARGET_PAGE]
    tr = [1 for k, p, _ in events if k == "read" and p == TARGET_PAGE]
    nz = [d for d in tw if d != 0]
    print("", file=out)
    print("=" * 68, file=out)
    print(" target page %d: %d writes (%d with non-zero data), %d reads"
          % (TARGET_PAGE, len(tw), len(nz), len(tr)), file=out)
    if tw and nz:
        print(" Data WAS written into this page. It is not an unwritten page -", file=out)
        print(" something cleared it or the mapping changed afterwards.", file=out)
    elif tw and not nz:
        print(" Writes reached the page but every one carried ZERO. Whatever", file=out)
        print(" filled it wrote zeros - the disc data never got this far.", file=out)
    elif tr and not tw:
        print(" READS but NO WRITES. The Winchester transfer never targeted", file=out)
        print(" this page. Next: the physical address the DMA presents against", file=out)
        print(" the one the MMU resolves for the same logical page.", file=out)
    else:
        print(" No access to the target page in the window.", file=out)
    print("=" * 68, file=out)
    return 0


def selftest():
    ok = True

    def chk(name, cond):
        nonlocal ok
        print("  %s: %s" % ("ok  " if cond else "FAIL", name))
        if not cond:
            ok = False

    def wa(page, data):
        return 0xB0000 | (0b10 << 14) | ((page // 1024) << 13) | ((page % 1024) << 3) | ((data >> 13) & 7)

    def wb(data):
        return 0xB0000 | (0b11 << 14) | ((data & 0x1FFF) << 1)

    def rd(page):
        return 0xB0000 | (0b01 << 14) | ((page // 1024) << 13) | ((page % 1024) << 3)

    ev = decode([wa(2040, 0o135111), wb(0o135111), rd(2040)])
    chk("pairs a write and keeps its page", ev[0] == ("write", 2040, 0o135111))
    chk("decodes a read record", ev[1] == ("read", 2040, None))
    chk("ignores foreign tags", decode([0xC0001]) == [])
    import io
    b = io.StringIO(); report(decode([rd(2040), rd(2040)]), out=b)
    chk("reads without writes are called out", "NO WRITES" in b.getvalue())
    b2 = io.StringIO(); report(decode([wa(2040, 0), wb(0)]), out=b2)
    chk("zero-data writes are distinguished", "carried ZERO" in b2.getvalue())
    print("SELFTEST: PASS" if ok else "SELFTEST: FAIL")
    return 0 if ok else 1


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("dumpfile", nargs="?")
    ap.add_argument("--selftest", action="store_true")
    a = ap.parse_args()
    if a.selftest:
        return selftest()
    if not a.dumpfile:
        ap.error("a dump file is required (or use --selftest)")
    return report(decode(parse(open(a.dumpfile, errors="replace").read())))


if __name__ == "__main__":
    sys.exit(main())

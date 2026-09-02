#!/usr/bin/env python3
r"""
panel_pans_capture.py - CSV window around the TRA PANS microinstruction.

Same deposited program as panel_pans_probe.py (TRA PANS at octal 20). A rule
on CSA == o3660 (VECT2, the TRA PANS microinstruction: IDBS,MAPANS -> A)
triggers a CSV window of PRE ticks before and POST ticks after, with the
DGA decode, the panel-sheet enable, the IDB at the CPU boundary and the
ALU's FIDBI input - so the cycle where the ALU captures D can be compared
with the cycle(s) where EPANSN is low. Measurement, no assumptions.

Run:  python3 examples/panel_pans_capture.py   -> panel_pans_capture.csv
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from nd120_probe import Probe   # noqa: E402

BOOT_TICKS = int(os.environ.get("PANS_BOOT_TICKS", "2000000"))
PRE = int(os.environ.get("PANS_PRE", "48"))
POST = int(os.environ.get("PANS_POST", "96"))

PROG = {
    0o20: 0o150000, 0o21: 0o004077, 0o22: 0o044106, 0o23: 0o150100,
    0o24: 0o150000, 0o25: 0o004074, 0o26: 0o150000, 0o27: 0o004073,
    0o30: 0o124000, 0o130: 0o022000,
}

TOP = "ND120_TOP"
BRD = TOP + ".CORE.CPU_BOARD"
DGA = BRD + ".IO.DCD.DGA"
SIGS = [
    "CSA_12_0",
    BRD + ".IO.s_clk",
    BRD + ".IO.CLK_EN",
    DGA + ".IDBS.s_csidbs_4_0",
    DGA + ".IDBS.s_epans_n",
    DGA + ".IDBS.s_mapans",
    BRD + ".IO.PANCAL.s_epans",
    BRD + ".IO.PANCAL.s_idb_15_0_out",
    BRD + ".CPU.IDB_15_0_IN",
    BRD + ".CPU.PROC.CGA.DELILAH.ALU.s_fidbi_15_0",
    BRD + ".CPU.PROC.CGA.DELILAH.ALU.s_aluclk",
    BRD + ".CPU.PROC.CGA.DELILAH.ALU.ALUCLK_EN",
    BRD + ".CPU.PROC.CGA.DELILAH.ALU.s_csidbs4_0",
    BRD + ".CPU.PROC.CGA.DELILAH.ALU.s_a_15_0",
]
# Optional reference capture of another IDB source (e.g. the UART read the
# console polling does): PANS_TRIG='<vpi-sig> == o37' PANS_EXTRA='sig1,sig2'.
TRIG = os.environ.get("PANS_TRIG", "CSA_12_0 == o3660")
EXTRA = [x for x in os.environ.get("PANS_EXTRA", "").split(",") if x]
CSV = os.environ.get("PANS_CSV", "panel_pans_capture.csv")


def main():
    with Probe() as p:
        p.run(BOOT_TICKS)
        print("[boot] console tail: %r" % p.console_text()[-40:])
        for a in (0o120, 0o121, 0o122):
            p.deposit(a, 0o177777)
        for a, v in PROG.items():
            p.deposit(a, v)
        p.run(200)
        for s in SIGS + EXTRA:
            v = p.get(s)
            print("  %-60s %s" % (s, "UNRESOLVED" if v is None else oct(v)))
            p.watch(s)
        p.set(pre=PRE, post=POST)
        p.open(CSV)
        p.rule("vect2", TRIG, ["csv", "event"])
        p.send(r"20!\r")
        ev = p.expect_event(trig="vect2", timeout=600) if False else None
        p.run(3000000)
        print("[run] events: %d" % len(p.events()))
        for e in p.events()[:6]:
            print("  ", e.raw[:120])
        print("TRA PANS #1: %06o   #2: %06o   #3: %06o" %
              (p.examine(0o120), p.examine(0o121), p.examine(0o122)))


if __name__ == "__main__":
    main()

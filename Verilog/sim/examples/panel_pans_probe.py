#!/usr/bin/env python3
r"""
panel_pans_probe.py - what does the CPU really get from TRA PANS / TRR PANC?

Deposits a 9-word program at octal 20, starts it from the MOPC prompt (20!),
and reads back what TRA PANS delivered into A before and after a TRR PANC
read request (PFUNC 4). Built for the panel-clock work (ND120_PANEL_CLOCK,
docs/panel-clock-68705.md): TPE's start-up probe does exactly this sequence
(TRA PANS -> bit 15? -> TRA PANS -> bit 14? -> TRR PANC 022xxx -> TRA PANS ->
bit 12? -> TRA PANS -> byte), and on our machine it gave up after ONE TRA PANS
although the panel sheet was driving PRES=1. So: measure A, do not assume.

Program (octal):
    020  150000  TRA PANS
    021  004077  STA  0120          ; P-relative: 021+077
    022  044106  LDA  0130          ; 022+106 = 0130 -> the PANC word
    023  150100  TRR PANC
    024  150000  TRA PANS
    025  004074  STA  0121
    026  150000  TRA PANS
    027  004073  STA  0122
    030  124000  JMP  *             ; stay here
    0130 022000  PANC = read request (bit 13) + PFUNC 4

Run (engine built with: make probe PANEL_CLOCK=1):
    python3 examples/panel_pans_probe.py
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from nd120_probe import Probe   # noqa: E402

BOOT_TICKS = int(os.environ.get("PANS_BOOT_TICKS", "2000000"))
RUN_TICKS = int(os.environ.get("PANS_RUN_TICKS", "3000000"))

PROG = {
    0o20: 0o150000, 0o21: 0o004077, 0o22: 0o044106, 0o23: 0o150100,
    0o24: 0o150000, 0o25: 0o004074, 0o26: 0o150000, 0o27: 0o004073,
    0o30: 0o124000, 0o130: 0o022000,
}


def main():
    with Probe() as p:
        print("[boot] %d ticks to the MOPC prompt" % BOOT_TICKS)
        p.run(BOOT_TICKS)
        con = p.console_text()
        print("[boot] console tail: %r" % con[-80:])
        for a in (0o120, 0o121, 0o122):
            p.deposit(a, 0o177777)          # sentinel: 177777 = "never written"
        for a, v in PROG.items():
            p.deposit(a, v)
        print("[run] 20! at the MOPC prompt")
        p.send(r"20!\r")
        p.run(RUN_TICKS)
        r0 = p.examine(0o120)
        r1 = p.examine(0o121)
        r2 = p.examine(0o122)
        print("TRA PANS #1 (before TRR PANC)      : %06o" % r0)
        print("TRA PANS #2 (right after TRR PANC) : %06o" % r1)
        print("TRA PANS #3                        : %06o" % r2)
        print("[run] console tail: %r" % p.console_text()[-120:])


if __name__ == "__main__":
    main()

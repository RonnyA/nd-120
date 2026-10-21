# ND-632 15 MHz SMD controller, card 3044, logic diagram sheet 3, block
# "MEMORY ADDRESS & WORD COUNT" (ND-11.020.01, scan page 118), as a
# Logisim-Evolution 3.8.0 drawing.
#
# Every chip sits at the position code the drawing gives it (14C, 12A, 3D ...)
# and every connection is made on the drawing's DIP pin number through a
# tunnel named after the drawing's signal name.
#
#   python gen_3044.py sheet OUT.circ   -> the drawing, with switches for the
#                                          IOX strobes and the A register
#   python gen_3044.py bench OUT.circ   -> clocked bench that plays the ND-120
#                                          MASS load sequence and reads back
#   python gen_3044.py check LOG        -> checks the bench output

import sys

sys.path.insert(0, ".")
from lsgen import Circuit, project, LIB_MEM  # noqa: E402
import parts  # noqa: E402

STROBES = ["LMAR", "WCS", "LCW", "RMAR", "RWC"]
OTHERS = ["RSTAT0", "CF0", "RFT1", "PIODRY1", "DWC0", "ADREN1", "INGRANT0", "BUSDRV0"]

NOTES = [
    "ND-632 15 MHz SMD controller, card 3044, logic diagram sheet 3, block 'MEMORY ADDRESS & WORD COUNT'",
    "(ND-11.020.01, scan page 118). Chip position codes, DIP pin numbers and signal names are the drawing's.",
    "Gate types the manual does not state (it has no parts list), chosen by what the circuit must do - check them:",
    "  3E, 1G, 4C = AND; 4B = NAND; 1C, 14F = inverter. 3E and 1C/3A are drawn with the SAME symbol, yet 3E must",
    "  be an AND (a NAND would hold 4E preset) and 3A must invert (RREG1 must be the opposite of RREG0).",
    "  R40, R39 and RN9 pin 8 on DB16-18: the far end is not drawn; shown as pull-downs like the rest of RN9.",
    "  C13 (220 pF on the 4E preset) is not drawn. 14C /ACI and /WCI (pins 3, 1) use the same rail symbol as",
    "  /IE (pin 8), which must be ground for any instruction to run - so they are ground.",
    "Am2942: subcircuit built from the AMD data sheet (03574B) function table; D0-D7 inputs on the DIP pins,",
    "the three-state outputs Y0-Y7 beside the body are tied to the same nets (Logisim cannot make a two-way port).",
    "Not on this sheet, drawn as stand-ins: the NOT gates making X1 from the LS138 X0 strobes (sheet 1, 3A),",
    "and two 74244s putting the ND-100 A register on DB0-15 (the sheet 1 bus transceivers).",
    "SCOPE: the controller's own microcode ROM (which runs disc transfers) is not available, so the controller",
    "as a whole cannot be simulated. This block's register loads come straight from the CPU's IOX strobes and",
    "do not pass through that ROM; transfer-time signals from it (DWC0, ADREN1, INGRANT0, RFT1) are inputs here.",
    "OPEN: DWC0 must rest LOW between transfers for any IOX load to clock the 2942s - 2C/2D pins 1 and 2 are both",
    "DWC0, so DWC0 HIGH holds the LS54 output LOW. The 0 subscript would say active-low; DWC0 is made off this",
    "sheet and has not been traced.",
]


def sheet3(c):
    """All chips of the sheet 3 block, plus the stand-ins, into circuit c."""
    # --- the three Am2942 slices -------------------------------------------
    def am2942(label, dnets, cp, oe, wci, aci, wco, aco):
        nets = {1: wci, 3: aci, 8: "GND", 15: "GND",
                12: "I0_1", 13: "I1_1", 14: "I2_1", 10: cp, 9: oe, 2: wco, 20: aco}
        for k, p in enumerate(parts.D_PINS):
            nets[p] = dnets[k]
            nets[101 + k] = dnets[k]          # three-state output, same net
        c.chip("Am2942", nets, label, lib=None, npins=22)

    am2942("14C  bits 0-7",
           ["D14C_0", "D14C_1", "D14C_2", "DB3", "DB4", "DB5", "DB6", "DB7"],
           "CPL1", "OEL0", "GND", "GND", "WCO_14C", "ACO_14C")
    am2942("12C  bits 8-15",
           ["D12C_0", "D12C_1", "D12C_2", "DB11", "DB12", "DB13", "DB14", "DB15"],
           "CPL1", "OEL0", "WCO_14C", "ACO_14C", "WCO_12C", "ACO_12C")
    am2942("12A  bits 16-23",
           ["DB16", "DB17", "DB18", "DB19", "DB20", "DB21", "DB22", "DB23"],
           "CPH1", "OEH0", "WCO_12C", "ACO_12C", "WCZ0", "ACO_12A")

    # --- 11C LS245: DB0-2 / DB8-10 to the D0-D2 pins of 14C and 12C --------
    c.chip("74245", {1: "OEL0", 19: "LCW1",
                     2: "DB0", 3: "DB1", 4: "DB2", 7: "DB8", 8: "DB9", 9: "DB10",
                     18: "D14C_0", 17: "D14C_1", 16: "D14C_2",
                     13: "D12C_0", 12: "D12C_1", 11: "D12C_2"},
           "11C  LS245", "off during a control-word load (LCW1 on /E)")
    # --- 11B LS245: byte swapper DB16-23 <-> DB0-7 ---------------------------
    c.chip("74245", {1: "DIR11B", 19: "E11B",
                     2: "DB16", 3: "DB17", 6: "DB18", 7: "DB19",
                     9: "DB20", 8: "DB21", 5: "DB22", 4: "DB23",
                     18: "DB0", 17: "DB1", 14: "DB2", 13: "DB3",
                     11: "DB4", 12: "DB5", 15: "DB6", 16: "DB7"},
           "11B  LS245", "byte swapper: A = DB16-23, B = DB0-7")
    # --- 4E LS74: SELH --------------------------------------------------------
    c.chip("7474", {10: "PRE4E", 11: "CLK4E", 12: "SELH1", 13: "H9", 9: "SELH0", 8: "SELH1"},
           "4E  LS74", "D <- /Q: toggles on each CLK4E rising edge")
    # --- 3E: 4E preset and 11B enable (AND, see notes) ------------------------
    c.chip("7411", {5: "CF0", 4: "RSTAT0", 3: "RFT1", 6: "PRE4E",
                    13: "LMAR0", 1: "RREG0", 2: "WCS0", 12: "E11B"},
           "3E", "AND - chosen by function")
    # --- 3D LS27 NOR -------------------------------------------------------------
    c.chip("7427", {1: "RMAR1", 2: "LMAR1", 13: "N4B8", 12: "CLK4E",
                    3: "WCS1", 4: "LCW1", 5: "RWC1", 6: "I0_1",
                    9: "RMAR1", 10: "LCW1", 11: "RWC1", 8: "I2_1"}, "3D  LS27")
    # --- 4D LS02 NOR -------------------------------------------------------------
    c.chip("7402", {12: "LMAR1", 11: "LCW1", 13: "I1_1",
                    5: "RMAR1", 6: "RWC1", 4: "RREG0"}, "4D  LS02")
    # --- 4B 74S00 (NAND, see notes) -----------------------------------------------
    c.chip("7400", {10: "WCS0", 9: "RWC0", 8: "N4B8"}, "4B  74S00", "NAND - chosen by function")
    # --- 3A LS04 -------------------------------------------------------------------
    c.chip("7404", {11: "RREG0", 10: "RREG1"}, "3A  LS04")
    # --- 2B 74S02 NOR -------------------------------------------------------------
    c.chip("7402", {9: "RREG1", 8: "ADREN1", 10: "OEH0"}, "2B  74S02")
    # --- 3C 74S51 AND-OR-INVERT ----------------------------------------------------
    c.chip("7451", {9: "RREG1", 10: "SELH0", 13: "ADREN1", 1: "ADREN1", 8: "OEL0"}, "3C  74S51")
    # --- 4C (AND, see notes) --------------------------------------------------------
    c.chip("7408", {1: "SELH1", 2: "RREG1", 3: "DIR11B"}, "4C", "AND - same symbol as 3E")
    # --- 1C LS04: the 2942 clocks ----------------------------------------------------
    c.chip("7404", {9: "N2C6", 8: "CPH1", 11: "N2D6", 10: "CPL1"}, "1C  LS04",
           "inverter - same symbol as 3A")
    # --- 2C / 2D LS54 ----------------------------------------------------------------
    c.chip("74LS54", {1: "DWC0", 2: "DWC0", 3: "LMAR1", 4: "SELH0", 5: "PIODRY1",
                      9: "PIODRY1", 10: "SELH0", 11: "WCS1", 12: "LCW1", 13: "PIODRY1",
                      6: "N2C6"}, "2C  LS54", "high slice clock", lib=None, npins=14)
    c.chip("74LS54", {1: "DWC0", 2: "DWC0", 3: "LMAR1", 4: "PIODRY1", 5: "PIODRY1",
                      9: "PIODRY1", 10: "PIODRY1", 11: "WCS1", 12: "LCW1", 13: "PIODRY1",
                      6: "N2D6"}, "2D  LS54", "low slice clock", lib=None, npins=14)
    # --- 14F, 1G -------------------------------------------------------------------------
    c.chip("7404", {3: "WCZ0", 4: "WCZ1"}, "14F  74S04", "inverter - from the WCZ0/WCZ1 names")
    c.chip("7411", {9: "WCZ1", 10: "WCZ1", 11: "INGRANT0", 8: "DWCZ1"}, "1G", "AND - same symbol as 3E")
    # --- stand-ins for sheet 1 --------------------------------------------------------------
    for s in STROBES:
        c.gate("7404", [s + "0"], s + "1")
    c.chip("74244", {1: "BUSDRV0", 19: "BUSDRV0",
                     2: "A0", 18: "DB0", 4: "A1", 16: "DB1", 6: "A2", 14: "DB2", 8: "A3", 12: "DB3",
                     11: "A4", 9: "DB4", 13: "A5", 7: "DB5", 15: "A6", 5: "DB6", 17: "A7", 3: "DB7"},
           "STAND-IN", "A register bits 0-7 onto DB (sheet 1 transceivers)")
    c.chip("74244", {1: "BUSDRV0", 19: "BUSDRV0",
                     2: "A8", 18: "DB8", 4: "A9", 16: "DB9", 6: "A10", 14: "DB10", 8: "A11", 12: "DB11",
                     11: "A12", 9: "DB12", 13: "A13", 7: "DB13", 15: "A14", 5: "DB14", 17: "A15", 3: "DB15"},
           "STAND-IN", "A register bits 8-15 onto DB (sheet 1 transceivers)")


def rails_and_pulls(c, x, y):
    c.const(x, y, "VCC", 1)
    c.const(x + 120, y, "GND", 0)
    nets = [("D14C_0", "0"), ("D14C_1", "0"), ("D14C_2", "0"),
            ("D12C_0", "0"), ("D12C_1", "0"), ("D12C_2", "0"),
            ("DB16", "0"), ("DB17", "0"), ("DB18", "0"), ("H9", "1")]
    for k, (n, v) in enumerate(nets):
        c.pull(x + 300 + 100 * k, y, n, v)
    c.text(x + 750, y + 40, "RN9 13C on 14C/12C D0-D2; RN9 pin 8, R40, R39 on DB16-18; H9 (R15) pull-up on 4E /R", 10)


def build_sheet(out):
    c = Circuit("SMD3044_MA_WC")
    for k, s in enumerate(NOTES):
        c.text(2600, 40 + 18 * k, s, 11)
    rails_and_pulls(c, 60, 60)
    y = 160
    for k, s in enumerate(STROBES):
        c.in_pin(60 + 160 * k, y, s + "0")
    for k, s in enumerate(OTHERS):
        c.in_pin(60 + 160 * k, y + 60, s)
    c.in_pin(60, y + 140, "AREG", 16, label="A_REG")
    c.split(100, y + 300, "AREG", ["A%d" % k for k in range(16)], 16)
    c.tunnel(100, y + 300, "AREG", "west", 16)
    c.text(700, y + 120, "Strobes are the active-low LS138 outputs of sheet 1. One IOX write: set A_REG, "
           "BUSDRV0=0, PIODRY1=1, strobe low, strobe high.", 11)
    probes = ["SELH0", "SELH1", "I0_1", "I1_1", "I2_1", "CPH1", "CPL1", "OEL0", "OEH0",
              "DIR11B", "E11B", "CLK4E", "RREG1", "DWCZ1", "WCZ0"]
    for k, s in enumerate(probes):
        c.out_pin(700 + 90 * k, y + 220, s)
    for k in range(24):
        c.out_pin(700 + 50 * k, y + 300, "DB%d" % k)
    sheet3(c)
    c.place_chips(80, y + 520, 6, dx=420, dy=240)
    xml = project([c.xml(), parts.build_am2942(), parts.build_ls54()], "SMD3044_MA_WC")
    open(out, "w", encoding="utf-8").write(xml)


# ------------------------------------------------------------------ bench
# One ROM row per half IOX. Fields:
#   bits 0-15 A register, 16-20 strobe lows (LMAR WCS LCW RMAR RWC), 21 RSTAT0,
#   22 PIODRY1, 23 BUSDRV0, 24 CF0, 25 halt
OFF = {"LMAR0": 1, "WCS0": 1, "LCW0": 1, "RMAR0": 1, "RWC0": 1, "RSTAT0": 1,
       "PIODRY1": 0, "BUSDRV0": 1, "CF0": 1}


def row(a=0, **kw):
    r = dict(OFF); r.update(kw); r["A"] = a
    return r


def iox_write(strobe, a):
    """One IOX write: data and the decoded strobe first, then PIODRY1 (the
    data-ready strobe, in every 2C/2D clock term) up and down, then the strobe
    goes. The I lines come from the strobe alone, so they are settled before
    the clock rises - the Am2942 needs 46 ns set-up on I0-I3 (data sheet)."""
    s = strobe + "0"
    return [row(a, BUSDRV0=0, **{s: 0}), row(a, BUSDRV0=0, PIODRY1=1, **{s: 0}),
            row(a, BUSDRV0=0, **{s: 0}), row(a, BUSDRV0=0), row()]


def iox_read(strobe, tag):
    s = strobe + "0"
    return [row(), dict(row(**{s: 0}), tag=tag), row()]


def boot_rows():
    rows = [row(), row(CF0=0), row()]                     # device clear presets SELH
    rows += iox_write("LMAR", 0) + iox_write("LMAR", 0)   # IOX 1541 <- 0, twice
    rows += [row(a=0, BUSDRV0=0, PIODRY1=1), row()]       # IOX 1543 (block address): not in this block
    rows += iox_write("WCS", 0o2000)                      # IOX 1547 <- 002000, once
    rows += iox_write("LCW", 0o4)                         # IOX 1545 <- 4
    rows += [row(RSTAT0=0), row()]                        # status read resets SELH
    rows += iox_read("RWC", "wc_first") + iox_read("RWC", "wc_second")
    rows += [row(RSTAT0=0), row()]
    rows += iox_read("RMAR", "mar_first") + iox_read("RMAR", "mar_second")
    rows += [row(), row(halt=1)]
    return rows


def word(r):
    w = r["A"] & 0xFFFF
    for k, s in enumerate(["LMAR0", "WCS0", "LCW0", "RMAR0", "RWC0"]):
        w |= r[s] << (16 + k)
    w |= r["RSTAT0"] << 21 | r["PIODRY1"] << 22 | r["BUSDRV0"] << 23 | r["CF0"] << 24
    w |= r.get("halt", 0) << 25
    return w


BENCH_OUT = ["S%d" % k for k in range(6)] + ["DB%d" % k for k in range(24)] + ["SELH0", "CPH1", "CPL1"]


def build_bench(out):
    rows = boot_rows()
    c = Circuit("TB_3044_BOOT")
    rails_and_pulls(c, 60, 60)
    c.comp(0, 60, 140, "Clock")
    c.tunnel(60, 140, "CLK", "west")
    # DWC0 rests LOW here: with it HIGH the LS54 term 1.2 (DWC0.DWC0) is always
    # true and no IOX strobe can clock the 2942s (see the sheet notes).
    for s, v in [("RFT1", "VCC"), ("DWC0", "GND"), ("ADREN1", "GND"), ("INGRANT0", "VCC")]:
        c.gate("7404", ["GND" if v == "VCC" else "VCC"], s)   # tie through a gate: one driver per net
    c.split(200, 600, "ADDR", ["S%d" % k for k in range(8)], 8)
    c.tunnel(200, 600, "ADDR", "west", 8)
    contents = "addr/data: 8 26\n" + " ".join("%x" % word(r) for r in rows) + "\n"
    c.comp(LIB_MEM, 400, 500, "ROM", [("addrWidth", 8), ("dataWidth", 26),
                                      ("appearance", "classic"), ("contents", contents)])
    c.tunnel(400, 510, "ADDR", "east", 8)
    c.tunnel(640, 560, "WORD", "west", 26)
    names = ["A%d" % k for k in range(16)] + ["LMAR0", "WCS0", "LCW0", "RMAR0", "RWC0",
                                              "RSTAT0", "PIODRY1", "BUSDRV0", "CF0", "HALT"]
    c.split(800, 900, "WORD", names, 26)
    c.tunnel(800, 900, "WORD", "east", 26)
    c.chip("74161", {1: "VCC", 2: "CLK", 3: "GND", 4: "GND", 5: "GND", 6: "GND",
                     7: "VCC", 9: "VCC", 10: "VCC",
                     14: "S0", 13: "S1", 12: "S2", 11: "S3", 15: "RCO0"}, "step bits 0-3")
    c.chip("74161", {1: "VCC", 2: "CLK", 3: "GND", 4: "GND", 5: "GND", 6: "GND",
                     7: "VCC", 9: "VCC", 10: "RCO0",
                     14: "S4", 13: "S5", 12: "S6", 11: "S7"}, "step bits 4-7")
    sheet3(c)
    c.place_chips(80, 1200, 6, dx=420, dy=240)
    for k, n in enumerate(BENCH_OUT):
        c.out_pin(1200 + 50 * k, 300, n)
    c.out_pin(1200, 400, "HALT", label="halt")
    xml = project([c.xml(), parts.build_am2942(), parts.build_ls54()], "TB_3044_BOOT")
    open(out, "w", encoding="utf-8").write(xml)
    print("rows:", len(rows))


def check(log):
    rows = boot_rows()
    seen = {}
    for line in open(log):
        r = line.split()
        if len(r) < len(BENCH_OUT):
            continue
        v = dict(zip(BENCH_OUT, r))
        try:
            st = sum(int(v["S%d" % k]) << k for k in range(6))
        except ValueError:
            continue
        seen[st] = v
    def bus(v, lo, hi):
        b = [v["DB%d" % k] for k in range(lo, hi)]
        if any(x not in "01" for x in b):
            return "".join(reversed(b))
        return sum(int(x) << i for i, x in enumerate(b))
    results = {}
    for k, r in enumerate(rows):
        if "tag" in r and k in seen:
            results[r["tag"]] = (bus(seen[k], 0, 16), bus(seen[k], 16, 24))
    for t, (lo, hi) in results.items():
        print("%-11s DB0-15 = %s   DB16-23 = %s" % (t, ("%06o" % lo) if isinstance(lo, int) else lo,
                                                     ("%03o" % hi) if isinstance(hi, int) else hi))
    def low8(t):
        v = results.get(t, (None,))[0]
        if isinstance(v, int):
            return v & 0xFF
        return v[-8:] if isinstance(v, str) and all(ch in "01" for ch in v[-8:]) and int(v[-8:], 2) >= 0 and False else (int(v[-8:], 2) if isinstance(v, str) and all(ch in "01" for ch in v[-8:]) else None)
    ok = (results.get("wc_first", (None,))[0] == 0o2000 and low8("wc_second") == 0 and
          results.get("mar_first", (None,))[0] == 0 and low8("mar_second") == 0)
    print("expected: WC first read DB0-15 = 002000, second read DB0-7 = 000 (bits 16-23);")
    print("          MAR first read 000000, second read DB0-7 = 000")
    print("TB_RESULT: %s" % ("PASS" if ok else "FAIL"))


if __name__ == "__main__":
    {"sheet": build_sheet, "bench": build_bench, "check": check}[sys.argv[1]](sys.argv[2])

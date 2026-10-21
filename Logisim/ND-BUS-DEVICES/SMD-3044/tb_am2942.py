# Test bench for the Am2942 subcircuit.
#
# A clock drives a step counter (two 74161s) that addresses a ROM holding one
# stimulus word per step. The Am2942 clock is the inverted clock, so each step
# first changes the inputs (clock rising) and then executes (clock falling =
# CP rising). Logisim runs headless (-t table,halt) and prints the outputs on
# every change; this script compares the value seen after each CP edge with a
# reference model written straight from the data sheet tables (Figure 1,
# Figure 4, page 5 text) - a separate implementation from the TTL build.
#
# Usage: python tb_am2942.py build OUTDIR      -> writes tb_am2942.circ
#        python tb_am2942.py check LOGFILE     -> compares, prints PASS/FAIL

import random
import sys

sys.path.insert(0, ".")
from lsgen import Circuit, project, LIB_MEM  # noqa: E402
import parts  # noqa: E402

# ROM word layout
B_D, B_DRV, B_I, B_IE, B_OED, B_ACI, B_WCI, B_HALT = 0, 8, 9, 13, 14, 15, 16, 17
WIDTH = 18


# ------------------------------------------------------------ reference model
class Ref:
    def __init__(self):
        self.AR = self.WR = self.AC = self.WC = self.CR = 0

    def code(self, s):
        if s["IE"]:
            return "DIS_TC" if s["I"] & 8 else "DIS_DMA"
        return s["I"]

    def clock(self, s):
        c = self.code(s)
        mode = self.CR & 3
        d = s["D"] if s["D"] is not None else 0
        AR, WR, AC, WC, CR = self.AR, self.WR, self.AC, self.WC, self.CR
        ac_en = c in (7, 8, 0xA, 0xB, 0xE, 0xF, "DIS_DMA", "DIS_TC")
        wc_en = c in (7, 8, 9, 0xA, 0xB, 0xD, "DIS_DMA", "DIS_TC")
        if c in (0, 8):
            CR = d & 7
        if c in (4, 9, 0xC):
            AC = self.AR
        if c in (5, 0xD):
            AR = AC = d
        if c in (6, 0xE):
            WR = d
            WC = 0 if mode == 1 else d
        if c in (4, 0xC, 0xF):
            WC = 0 if mode == 1 else self.WR
        if ac_en and not s["ACI"]:
            AC = (self.AC + (-1 if self.CR & 4 else 1)) & 0xFF
        if wc_en and not s["WCI"] and mode != 2:
            WC = (self.WC + (-1 if mode == 0 else 1)) & 0xFF
        self.AR, self.WR, self.AC, self.WC, self.CR = AR, WR, AC, WC, CR

    def outputs(self, s):
        c = self.code(s)
        mode = self.CR & 3
        if c in (0, 6, 0xE):
            y = 0xFF
        elif c in (1, 8):
            y = self.CR | 0xF8
        elif c in (2, 5, 0xA, 0xD, 0xF, "DIS_TC"):
            y = self.WC
        else:
            y = self.AC
        if not s["OED"]:
            dbus = y
        elif s["DRV"]:
            dbus = s["D"]
        else:
            dbus = None                      # floating: not checked
        term_ac = self.AC == (0 if self.CR & 4 else 0xFF)
        aco = 0 if (not s["ACI"] and term_ac) else 1
        if mode == 2:
            wco = 1
        else:
            term_wc = self.WC == (0 if mode == 0 else 0xFF)
            wco = 0 if (not s["WCI"] and term_wc) else 1
        if mode == 0:
            done = self.WC == (1 if not s["WCI"] else 0)
        elif mode == 1:
            done = ((self.WC + (1 if not s["WCI"] else 0)) & 0xFF) == self.WR
        elif mode == 2:
            done = self.WC == self.AC
        else:
            done = False
        return dbus, aco, wco, int(done)


# ------------------------------------------------------------ stimulus
WRITES = (0, 5, 6, 8, 0xD, 0xE)
PREFIX = 3        # steps 1-3 load CR, AR/AC, WR/WC


def step(I, D=None, IE=0, OED=1, ACI=1, WCI=1):
    drv = D is not None
    if drv:
        OED = 1
    return {"I": I, "D": D, "DRV": int(drv), "IE": IE, "OED": OED, "ACI": ACI, "WCI": WCI}


def stimulus():
    # step 0 is never executed (the counter moves before the first CP edge):
    # a no-op that changes nothing even if it were.
    s = [step(1)]
    # The registers are undefined after power-up (AMD gives no reset state;
    # Logisim starts them undefined too). Load all five before checking.
    s += [step(0, D=0x00), step(5, D=0x00), step(6, D=0x00)]
    rd = lambda i, **k: step(i, OED=0, **k)
    # mode 0, count up
    s += [step(0, D=0x00), rd(1), step(5, D=0x12), rd(3), step(6, D=0x05), rd(2)]
    s += [rd(7, ACI=0, WCI=0) for _ in range(4)] + [rd(3), rd(2, WCI=0), rd(2)]
    s += [step(5, D=0xFF), rd(3, ACI=0), rd(7, ACI=0)]          # /ACO at FF
    s += [step(6, D=0x00), rd(2, WCI=0)]                        # /WCO in mode 0 at 0
    # mode 1
    s += [step(0, D=0x01), rd(1), step(6, D=0x03), rd(2)]       # WC cleared, WR = 3
    s += [rd(7, WCI=0) for _ in range(3)] + [rd(2), rd(2, WCI=0)]
    s += [step(4), rd(2)]                                       # REIN in mode 1: WC = 0
    # mode 2
    s += [step(0, D=0x02), step(6, D=0x20), step(5, D=0x1E), rd(3)]
    s += [rd(7, ACI=0, WCI=0) for _ in range(3)] + [rd(2), rd(3)]
    # mode 3
    s += [step(0, D=0x03), step(6, D=0xFE), rd(2, WCI=0)]
    s += [rd(7, WCI=0) for _ in range(3)]
    # decrement address counter (CR2)
    s += [step(0, D=0x04), step(5, D=0x01), rd(3, ACI=0), rd(7, ACI=0), rd(7, ACI=0), rd(3)]
    # reinitialize, instruction disable (both sets)
    s += [step(0, D=0x00), step(5, D=0x40), step(6, D=0x08)]
    s += [rd(7, ACI=0, WCI=0), rd(4), rd(3), rd(2)]
    s += [rd(3, IE=1, ACI=0, WCI=0), rd(0xB, IE=1, ACI=0, WCI=0), rd(3), rd(2)]
    # timer/counter set 8-F
    s += [step(8, D=0x01, ACI=0, WCI=0), rd(1), step(0xD, D=0x30, WCI=0), rd(3), rd(2)]
    s += [step(0xE, D=0x07, ACI=0), rd(3), rd(2), rd(9, WCI=0), rd(0xA), rd(0xB)]
    s += [rd(0xC), rd(3), rd(2), rd(0xF, ACI=0), rd(3), rd(2)]
    # random walk over everything
    rnd = random.Random(2942)
    while len(s) < 250:
        i = rnd.randrange(16)
        ie = int(rnd.random() < 0.1)
        aci, wci = rnd.randrange(2), rnd.randrange(2)
        if i in WRITES and not ie:
            s.append(step(i, D=rnd.randrange(256), ACI=aci, WCI=wci))
        else:
            s.append(step(i, IE=ie, OED=rnd.randrange(2), ACI=aci, WCI=wci))
    s.append(step(1, OED=0))   # halt step
    return s


def word(st, halt):
    w = (st["D"] or 0) << B_D
    w |= st["DRV"] << B_DRV | st["I"] << B_I | st["IE"] << B_IE | st["OED"] << B_OED
    w |= st["ACI"] << B_ACI | st["WCI"] << B_WCI | int(halt) << B_HALT
    return w


# ------------------------------------------------------------ circuit
OUTS = ["CPO"] + ["S%d" % k for k in range(8)] + ["D%d" % k for k in range(8)] + ["ACO", "WCO", "DONE"]


def build(out):
    seq = stimulus()
    assert len(seq) <= 256
    words = [word(st, k == len(seq) - 1) for k, st in enumerate(seq)]
    # step 0 is never executed with a clean edge: the counter starts at 0 and
    # the first falling clock executes step 0. Fine - CP rises at the first
    # falling edge after start.
    c = Circuit("TB_AM2942")
    c.const(40, 40, "VCC", 1)
    c.const(40, 80, "GND", 0)
    c.comp(0, 40, 140, "Clock")
    c.tunnel(40, 140, "CLK", "west")
    c.gate("7404", ["CLK"], "CP")
    # step counter
    c.chip("74161", {1: "VCC", 2: "CLK", 3: "GND", 4: "GND", 5: "GND", 6: "GND",
                     7: "VCC", 9: "VCC", 10: "VCC",
                     14: "S0", 13: "S1", 12: "S2", 11: "S3", 15: "RCO0"}, "step bits 0-3")
    c.chip("74161", {1: "VCC", 2: "CLK", 3: "GND", 4: "GND", 5: "GND", 6: "GND",
                     7: "VCC", 9: "VCC", 10: "RCO0",
                     14: "S4", 13: "S5", 12: "S6", 11: "S7"}, "step bits 4-7")
    # ROM: address bus from the step bits, data split into single nets
    c.split(200, 600, "ADDR", ["S%d" % k for k in range(8)], 8)
    c.tunnel(200, 600, "ADDR", "west", 8)
    contents = "addr/data: 8 %d\n" % WIDTH + " ".join("%x" % w for w in words) + "\n"
    c.comp(LIB_MEM, 400, 500, "ROM", [("addrWidth", 8), ("dataWidth", WIDTH),
                                      ("appearance", "classic"), ("contents", contents)])
    c.tunnel(400, 510, "ADDR", "east", 8)
    # classic ROM data out at (240, 60) for 8 bits; measured again below for 18
    c.tunnel(640, 560, "WORD", "west", WIDTH)
    names = (["DIN%d" % k for k in range(8)] + ["DRV", "I0", "I1", "I2", "I3", "IE", "OED",
                                               "ACI", "WCI", "halt_n"])
    c.split(800, 760, "WORD", names, WIDTH)
    c.tunnel(800, 760, "WORD", "east", WIDTH)
    c.gate("7404", ["DRV"], "nDRV")
    c.chip("74244", {1: "nDRV", 19: "nDRV",
                     2: "DIN0", 18: "D0", 4: "DIN1", 16: "D1", 6: "DIN2", 14: "D2", 8: "DIN3", 12: "D3",
                     11: "DIN4", 9: "D4", 13: "DIN5", 7: "D5", 15: "DIN6", 5: "D6", 17: "DIN7", 3: "D7"},
           "bench drives D0-D7 when DRV")
    # the chip under test
    nets = {1: "WCI", 2: "WCO", 3: "ACI", 8: "IE", 9: "OED", 10: "CP",
            12: "I0", 13: "I1", 14: "I2", 15: "I3", 20: "ACO", 21: "DONE"}
    for k, p in enumerate(parts.D_PINS):
        nets[p] = "D%d" % k
        nets[101 + k] = "D%d" % k        # three-state output on the same net
    c.chip("Am2942", nets, "Am2942 under test", lib=None, npins=22)
    c.pull(1500, 900, "DONE", "1")
    c.place_chips(300, 1100, 4, dx=320, dy=220)
    # outputs, one row, left to right in OUTS order
    c.tunnel(1600, 300, "CP", "west")
    for k, n in enumerate(OUTS):
        c.out_pin(1700 + 60 * k, 300, "CP" if n == "CPO" else n, label=n)
    c.out_pin(1700, 400, "halt_n", label="halt")
    xml = project([c.xml(), parts.build_am2942(), parts.build_ls54()], "TB_AM2942")
    open(out, "w", encoding="utf-8").write(xml)
    print("steps:", len(seq))


def check(logfile):
    seq = stimulus()
    rows = [l.split() for l in open(logfile) if l.strip()]
    n = len(OUTS)
    # tty table prints the outputs (plus halt) as one row per change
    seen = {}
    for r in rows:
        if len(r) < n:
            continue
        vals = dict(zip(OUTS, r[:n]))
        if vals["CPO"] != "1":
            continue
        try:
            st = sum(int(vals["S%d" % k]) << k for k in range(8))
        except ValueError:
            continue
        seen[st] = vals          # keep the last row for this step with CP high
    ref = Ref()
    fails = 0
    for k, st in enumerate(seq):
        if k == len(seq) - 1:
            continue           # halt step
        if k == 0:
            continue           # not executed
        ref.clock(st)
        if k <= PREFIX:
            continue           # registers still being loaded
        exp = ref.outputs(st)
        got = seen.get(k)
        if got is None:
            print("step %d: no row seen" % k); fails += 1; continue
        dbits = [got["D%d" % b] for b in range(8)]
        problems = []
        if exp[0] is not None:
            if any(x not in "01" for x in dbits):
                problems.append("D=%s" % "".join(reversed(dbits)))
            else:
                v = sum(int(dbits[b]) << b for b in range(8))
                if v != exp[0]:
                    problems.append("D=%02X want %02X" % (v, exp[0]))
        for name, e in zip(("ACO", "WCO", "DONE"), exp[1:]):
            if got[name] != str(e):
                problems.append("%s=%s want %d" % (name, got[name], e))
        if problems:
            fails += 1
            if fails <= 30:
                print("step %3d I=%X IE=%d D=%s OED=%d ACI=%d WCI=%d CR=%d AC=%02X WC=%02X WR=%02X AR=%02X: %s"
                      % (k, st["I"], st["IE"], "--" if st["D"] is None else "%02X" % st["D"],
                         st["OED"], st["ACI"], st["WCI"], ref.CR, ref.AC, ref.WC, ref.WR, ref.AR,
                         "; ".join(problems)))
    print("steps checked: %d, failed: %d" % (len(seq) - 2 - PREFIX, fails))
    print("TB_RESULT: %s" % ("PASS" if fails == 0 else "FAIL"))


if __name__ == "__main__":
    if sys.argv[1] == "build":
        build(sys.argv[2])
    else:
        check(sys.argv[2])

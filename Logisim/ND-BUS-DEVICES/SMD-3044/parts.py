# Subcircuits drawn as DIPs: 74LS54 and Am2942.
#
# Am2942 source: AMD Am2942 data sheet, form 03574B (scan and OCR kept
# outside this repository):
#   Figure 1 - control register / control modes / DONE
#   Figure 3 - instruction codes
#   Figure 4 - function table (what each instruction does to each register)
#   pin description and connection diagram (22-pin DIP).
# The data sheet gives the chip as registers plus a function table, not as
# gates, so the model below is those registers driven by that table, built
# from TTL parts. Where the data sheet is silent the choice is marked
# INFERRED in a comment.

from lsgen import Circuit, dip_appearance, dip_pin, LIB_WIRING


# --------------------------------------------------------------- 74LS54
# TI SN74LS54: Y(6) = NOT( 1.2 + 3.4.5 + 9.10.11 + 12.13 ).
# Logisim's own 7454 is the older 4-wide 2-input chip (Y on pin 8), so it
# cannot stand in for the LS54.
LS54_PORTS = [(1, "A1", False), (2, "B1", False), (3, "A2", False), (4, "B2", False),
              (5, "C2", False), (9, "A3", False), (10, "B3", False), (11, "C3", False),
              (12, "A4", False), (13, "B4", False), (6, "Y", True)]


def build_ls54():
    c = Circuit("74LS54")
    locs = {}
    y = 60
    for pin, name, is_out in LS54_PORTS:
        if is_out:
            locs[name] = (900, 60)
            c.out_pin(900, 60, "p%d" % pin, label=name)
        else:
            locs[name] = (40, y)
            c.in_pin(40, y, "p%d" % pin, label=name)
            y += 40
    c.gate("7400", ["p1", "p2"], "n1")            # NOT(1.2)
    c.gate("7410", ["p3", "p4", "p5"], "n2")      # NOT(3.4.5)
    c.gate("7410", ["p9", "p10", "p11"], "n3")    # NOT(9.10.11)
    c.gate("7400", ["p12", "p13"], "n4")          # NOT(12.13)
    c.gate("7420", ["n1", "n2", "n3", "n4"], "orx")  # = OR of the four ANDs
    c.gate("7404", ["orx"], "p6")                 # Y = NOT(OR)
    c.place_chips(200, 120, 3)
    c.text(400, 20, "74LS54: Y(6) = NOT(1.2 + 3.4.5 + 9.10.11 + 12.13), TI pinout", 12, True)
    app = dip_appearance(14, LS54_PORTS, "LS54", locs)
    return c.xml(app)


# --------------------------------------------------------------- Am2942
# 22-pin DIP, data sheet connection diagram: 1 /WCI, 2 /WCO, 3 /ACI, 4-7 D0-D3,
# 8 /IE, 9 /OE_D, 10 CP, 11 GND, 12-15 I0-I3, 16-19 D4-D7, 20 /ACO, 21 DONE,
# 22 VCC. D0-D7 are two-way on the real chip. Logisim cannot make one
# subcircuit port both input and output (an input and an output port on the
# same spot was tried: the input then never sees the outside value), so the
# DIP pins D0-D7 are the inputs and Y0-Y7, in a row to the right of the body,
# are the three-state outputs. Whoever uses the chip ties Dk and Yk to one
# net - which is what the real pin is.
D_PINS = [4, 5, 6, 7, 16, 17, 18, 19]
AM2942_PORTS = ([(1, "WCI", False), (3, "ACI", False), (8, "IE", False), (9, "OED", False),
                 (10, "CP", False), (12, "I0", False), (13, "I1", False), (14, "I2", False),
                 (15, "I3", False), (2, "WCO", True), (20, "ACO", True), (21, "DONE", True)]
                + [(p, "D%d" % k, False) for k, p in enumerate(D_PINS)]
                + [(101 + k, "Y%d_out" % k, True) for k in range(8)])


def bits(prefix, n=8):
    return ["%s%d" % (prefix, k) for k in range(n)]


def adder8(c, a, b_bits, cin, s, cout, label):
    """Two 74283s: s = a + b + cin; b_bits may be net names or 'VCC'/'GND'."""
    for half in range(2):
        lo = half * 4
        A = a[lo:lo + 4]; B = b_bits[lo:lo + 4]; S = s[lo:lo + 4]
        c.chip("74283", {5: A[0], 3: A[1], 14: A[2], 12: A[3],
                         6: B[0], 2: B[1], 15: B[2], 11: B[3],
                         4: S[0], 1: S[1], 13: S[2], 10: S[3],
                         7: cin if half == 0 else "%s_c4" % label,
                         9: "%s_c4" % label if half == 0 else cout},
               "%s %s" % (label, "bits 0-3" if half == 0 else "bits 4-7"))


def mux8(c, sel, a, b, y, label, strobe="GND"):
    """Two 74157s: y = sel ? b : a; strobe high forces y = 0."""
    for half in range(2):
        lo = half * 4
        A = a[lo:lo + 4]; B = b[lo:lo + 4]; Y = y[lo:lo + 4]
        c.chip("74157", {1: sel, 15: strobe,
                         2: A[0], 3: B[0], 4: Y[0],
                         5: A[1], 6: B[1], 7: Y[1],
                         11: A[2], 10: B[2], 9: Y[2],
                         14: A[3], 13: B[3], 12: Y[3]},
               "%s %s" % (label, "bits 0-3" if half == 0 else "bits 4-7"))


def reg8(c, d, q, clk, nen, label):
    """8-bit register: q <= d on clk rising edge when nen is low, else hold.

    Built as a 74157 (feeds Q back when not loading) in front of two 74175s.
    Logisim-Evolution 3.8.0's 74377 and 74273 never load (both share one
    model class; measured headless: outputs stay undefined over 8 clocks
    with the enable / clear held right), so they cannot be used."""
    tag = label.replace(" ", "_")
    qn = [x if x is not None else "%s_q%d" % (tag, k) for k, x in enumerate(q)]
    nxt = ["%s_n%d" % (tag, k) for k in range(8)]
    ld = c.gate("7404", [nen], "%s_ld" % tag)
    mux8(c, ld, qn, d, nxt, label + " hold / load")
    for half in range(2):
        lo = half * 4
        D = nxt[lo:lo + 4]; Q = qn[lo:lo + 4]
        c.chip("74175", {1: "VCC", 9: clk,
                         4: D[0], 2: Q[0], 5: D[1], 7: Q[1],
                         12: D[2], 10: Q[2], 13: D[3], 15: Q[3]},
               "%s %s" % (label, "bits 0-3" if half == 0 else "bits 4-7"))


def build_am2942():
    c = Circuit("Am2942")
    locs = {}
    yi, yo = 60, 60
    for pin, name, is_out in AM2942_PORTS:
        net = name
        if is_out:
            locs[name] = (3400, yo); c.out_pin(3400, yo, net, label=name); yo += 40
        else:
            locs[name] = (40, yi); c.in_pin(40, yi, net, label=name); yi += 40
    c.const(40, yi + 40, "VCC", 1)
    c.const(40, yi + 80, "GND", 0)
    D = bits("D")

    # ---- instruction decode (Figure 3) -----------------------------------
    # /IE high disables I0-I2 only; I3 still picks DMA (0) or T/C (1) set.
    c.chip("74138", {1: "I0", 2: "I1", 3: "I2", 4: "IE", 5: "I3", 6: "VCC",
                     15: "nC0", 14: "nC1", 13: "nC2", 12: "nC3", 11: "nC4", 10: "nC5", 9: "nC6", 7: "nC7"},
           "DMA codes 0-7", "active low, only while /IE low and I3 low")
    c.chip("74138", {1: "I0", 2: "I1", 3: "I2", 4: "IE", 5: "GND", 6: "I3",
                     15: "nC8", 14: "nC9", 13: "nCA", 12: "nCB", 11: "nCC", 10: "nCD", 9: "nCE", 7: "nCF"},
           "T/C codes 8-F", "active low, only while /IE low and I3 high")
    c.chip("74138", {1: "CR0", 2: "CR1", 3: "GND", 4: "GND", 5: "GND", 6: "VCC",
                     15: "nM0", 14: "nM1", 13: "nM2", 12: "nM3"},
           "control mode 0-3", "Figure 1: CR1 CR0")
    c.gate("7404", ["I3"], "nI3")
    c.gate("7400", ["IE", "nI3"], "nDIS_DMA")     # /IE high, I3 low: instruction disable
    c.gate("7400", ["IE", "I3"], "nDIS_TC")       # /IE high, I3 high: instruction disable, T/C
    c.gate("7404", ["nM0"], "M0")
    c.gate("7404", ["nM1"], "M1")

    # Each control below is an OR of instruction codes, read off Figure 4.
    c.gate("7400", ["nC0", "nC8"], "CR_LD")                     # D0-2 -> CR: WRCR, WCRT
    c.gate("7400", ["nC5", "nCD"], "AR_LD")                     # D -> AR (and D -> AC): LDAD, LDAT
    c.gate("7400", ["nC6", "nCE"], "WR_LD")                     # D -> WR: LDWC, LWCT
    c.gate("7410", ["nC4", "nC9", "nCC"], "AC_AR")              # AR -> AC: REIN, REAC, RAWC
    c.gate("7430", ["nC7", "nC8", "nCA", "nCB", "nCE", "nCF", "nDIS_DMA", "nDIS_TC"],
           "AC_CNTI")                                           # address counter ENABLE
    c.gate("7410", ["nC4", "nCC", "nCF"], "WC_REIN")            # WR -> WC (ZERO -> WC in mode 1): REIN, RAWC, REWC
    c.gate("7430", ["nC7", "nC8", "nC9", "nCA", "nCB", "nCD", "nDIS_DMA", "nDIS_TC"],
           "WC_CNTI")                                           # word counter ENABLE (HOLD in mode 2)
    c.gate("7410", ["nC0", "nC6", "nCE"], "Y_HIGH")             # data mux output FORCED HIGH
    c.gate("7400", ["nC1", "nC8"], "Y_CR")                      # output = control register
    c.gate("7430", ["nC2", "nC5", "nCA", "nCD", "nCF", "nDIS_TC", "VCC", "VCC"],
           "Y_WC")                                              # output = word counter; else address counter

    # Mode-dependent parts of Figure 4.
    c.gate("7408", ["WR_LD", "nM1"], "WC_LD_D")                 # D -> WC in modes 0, 2, 3
    c.gate("7432", ["WR_LD", "WC_REIN"], "WC_Z_ANY")
    c.gate("7408", ["WC_Z_ANY", "M1"], "WC_ZERO")               # ZERO -> WC in mode 1
    c.gate("7408", ["WC_REIN", "nM1"], "WC_FROM_WR")            # WR -> WC in modes 0, 2, 3
    c.gate("7404", ["ACI"], "nACI")
    c.gate("7404", ["WCI"], "nWCI")
    c.gate("7408", ["AC_CNTI", "nACI"], "AC_CNTE")              # counts when enabled and /ACI low
    c.gate("7411", ["WC_CNTI", "nM2", "nWCI"], "WC_CNTE")       # counts when enabled, /WCI low, not mode 2

    # Register clock enables (74377 /G, active low).
    c.gate("7427", ["AR_LD", "AC_AR", "AC_CNTE"], "nEN_AC")     # AR_LD also loads AC (D -> AC)
    c.gate("7432", ["WC_FROM_WR", "WC_CNTE"], "WC_EN_X")
    c.gate("7427", ["WC_LD_D", "WC_ZERO", "WC_EN_X"], "nEN_WC")
    c.gate("7404", ["AR_LD"], "nEN_AR")
    c.gate("7404", ["WR_LD"], "nEN_WR")
    c.gate("7404", ["CR_LD"], "nEN_CR")

    # ---- registers -------------------------------------------------------
    AR, WR, AC, WC = bits("AR"), bits("WR"), bits("AC"), bits("WC")
    reg8(c, D, AR, "CP", "nEN_AR", "address register")
    reg8(c, D, WR, "CP", "nEN_WR", "word count register")
    reg8(c, D[:3] + ["GND"] * 5, ["CR0", "CR1", "CR2"] + [None] * 5, "CP", "nEN_CR",
         "control register (D0-D2)")

    # ---- address counter: next = D | AR | AC +/- 1 -----------------------
    # Figure 1: CR2 low = increment, high = decrement. Adding 1 or adding
    # 11111111 (= minus 1).
    adder8(c, AC, ["VCC"] + ["CR2"] * 7, "GND", bits("ACN"), "AC_COUT", "AC +/- 1")
    mux8(c, "AC_AR", bits("ACN"), AR, bits("ACM"), "AC source: count / AR")
    mux8(c, "AR_LD", bits("ACM"), D, bits("ACX"), "AC source: D")
    reg8(c, bits("ACX"), AC, "CP", "nEN_AC", "address counter")
    # /ACO. INFERRED: the data sheet only says 'full lookahead carry'; taken as
    # LOW when /ACI is LOW and the counter is at its last value in its count
    # direction (FF counting up, 00 counting down). Carry out of the +/-1
    # adder is 1 at FF going up and 0 at 00 going down.
    c.gate("7486", ["AC_COUT", "CR2"], "AC_TERM")
    c.gate("7400", ["nACI", "AC_TERM"], "ACO")

    # ---- word counter: next = D | WR | 0 | WC +/- 1 ---------------------
    # Figure 1: decrement in mode 0, increment in modes 1 and 3, hold in mode 2.
    adder8(c, WC, ["VCC"] + ["M0"] * 7, "GND", bits("WCN"), "WC_COUT", "WC +/- 1")
    mux8(c, "WC_FROM_WR", bits("WCN"), WR, bits("WCM"), "WC source: count / WR")
    mux8(c, "WC_LD_D", bits("WCM"), D, bits("WCX"), "WC source: D, or zero", strobe="WC_ZERO")
    reg8(c, bits("WCX"), WC, "CP", "nEN_WC", "word counter")
    # /WCO: same INFERRED rule as /ACO; never active in mode 2 (no counting).
    c.gate("7486", ["WC_COUT", "M0"], "WC_TERM0")
    c.gate("7408", ["WC_TERM0", "nM2"], "WC_TERM")
    c.gate("7400", ["nWCI", "WC_TERM"], "WCO")

    # ---- data multiplexer and output buffers (Figure 2, Figure 4) --------
    # READ CONTROL REGISTER: Y0-Y2 = CR, Y3-Y7 HIGH (data sheet page 5).
    mux8(c, "Y_WC", AC, WC, bits("YA"), "Y: AC / WC")
    mux8(c, "Y_CR", bits("YA"), ["CR0", "CR1", "CR2"] + ["VCC"] * 5, bits("YB"), "Y: CR")
    for k in range(8):
        c.gate("7432", ["YB%d" % k, "Y_HIGH"], "Y%d" % k)          # FORCED HIGH
    # 74244: /OE_D low puts Y on D0-D7, high = high impedance.
    c.chip("74244", {1: "OED", 19: "OED",
                     2: "Y0", 18: "Y0_out", 4: "Y1", 16: "Y1_out", 6: "Y2", 14: "Y2_out",
                     8: "Y3", 12: "Y3_out", 11: "Y4", 9: "Y4_out", 13: "Y5", 7: "Y5_out",
                     15: "Y6", 5: "Y6_out", 17: "Y7", 3: "Y7_out"},
           "D0-D7 output buffers", "/OE_D low = drive")

    # ---- DONE (Figure 1) ---------------------------------------------------
    # mode 0: /WCI low: WC = 1      /WCI high: WC = 0
    # mode 1: /WCI low: WC + 1 = WR /WCI high: WC = WR
    # mode 2: WC = AC
    # mode 3: always LOW
    # Built as (WC + k) == B with k = -1 (mode 0, /WCI low), +1 (mode 1,
    # /WCI low), else 0; and B = 0 (mode 0), WR (mode 1), AC (mode 2).
    c.gate("7408", ["M0", "nWCI"], "KNEG")
    c.gate("7408", ["M1", "nWCI"], "KPOS")
    c.gate("7432", ["KNEG", "KPOS"], "KANY")
    adder8(c, WC, ["KANY"] + ["KNEG"] * 7, "GND", bits("WCK"), None, "DONE: WC + k")
    mux8(c, "M2_SEL", WR, AC, bits("CMPB"), "DONE: compare with WR / AC, or 0", strobe="M0")
    c.gate("7404", ["nM2"], "M2_SEL")
    c.chip("7485", {10: "WCK0", 12: "WCK1", 13: "WCK2", 15: "WCK3",
                    9: "CMPB0", 11: "CMPB1", 14: "CMPB2", 1: "CMPB3",
                    2: "GND", 3: "VCC", 4: "GND",
                    7: "LT_L", 6: "EQ_L", 5: "GT_L"}, "DONE compare bits 0-3")
    c.chip("7485", {10: "WCK4", 12: "WCK5", 13: "WCK6", 15: "WCK7",
                    9: "CMPB4", 11: "CMPB5", 14: "CMPB6", 1: "CMPB7",
                    2: "LT_L", 3: "EQ_L", 4: "GT_L", 6: "EQ"}, "DONE compare bits 4-7")
    c.gate("7408", ["EQ", "nM3"], "DONE_T")
    # DONE is open collector (data sheet): pulls LOW, never drives HIGH.
    c.chip("74125", {1: "DONE_T", 2: "GND", 3: "DONE"}, "DONE open collector",
           "drives LOW when not done, floats when done")

    c.place_chips(300, 120, 8, dx=300, dy=220)
    c.text(1400, 30, "Am2942 - registers and AMD's Figure 4 function table, built from TTL parts. "
           "Initial register contents after power-up are not defined by AMD; Logisim starts them at 0.",
           13, True)
    app = dip_appearance(22, AM2942_PORTS, "Am2942", locs)
    return c.xml(app)

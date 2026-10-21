# Exhaustive check of the 74LS54 subcircuit: Y = NOT(1.2 + 3.4.5 + 9.10.11 + 12.13).
import sys, itertools
sys.path.insert(0, ".")
from lsgen import Circuit, project
import parts
PINS = [1, 2, 3, 4, 5, 9, 10, 11, 12, 13]
if sys.argv[1] == "build":
    c = Circuit("TB_LS54")
    for k, p in enumerate(PINS):
        c.in_pin(40, 60 + 40 * k, "p%d" % p, label="p%02d" % p)
    nets = {p: "p%d" % p for p in PINS}
    nets[6] = "Y"
    c.chip("74LS54", nets, "dut", lib=None, npins=14)
    c.place_chips(400, 300, 1)
    c.out_pin(900, 60, "Y", label="Y")
    open(sys.argv[2], "w").write(project([c.xml(), parts.build_ls54()], "TB_LS54"))
else:
    rows = [l.split() for l in open(sys.argv[2]) if l.strip()]
    hdr = rows[0]; fails = 0; n = 0
    for r in rows[1:]:
        if len(r) != len(hdr): continue
        v = dict(zip(hdr, r)); b = lambda p: v["p%02d" % p] == "1"
        want = not ((b(1) and b(2)) or (b(3) and b(4) and b(5)) or (b(9) and b(10) and b(11)) or (b(12) and b(13)))
        n += 1
        if v["Y"] != ("1" if want else "0"):
            fails += 1
    print("combinations checked: %d, failed: %d" % (n, fails))
    print("TB_RESULT: %s" % ("PASS" if fails == 0 and n == 1024 else "FAIL"))

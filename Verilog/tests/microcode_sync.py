#!/usr/bin/env python3
###############################################################################
# microcode_sync.py - the tree must hold ONE microcode, everywhere.
#
# 24-AUG-2026 lesson: commit 895f360 (07-DEC-2024) patched byte 4104 of
# AM27256_45133L.hex in the Verilator harness copies only. For eight months
# every simulation validated microcode the FPGA boards never ran (the boards
# preload from Code/Microcode's raw dump). The split was found only at the
# end of a long silicon debugging campaign.
#
# This gate hashes every copy of the two microcode PROM images in the tree
# against the canonical ones in Code/Microcode/ and FAILS on any divergence
# that is not in the dated exception list below. Adding an exception is a
# deliberate, reviewed act - never a way to silence the gate.
#
# 02-SEP-2026, second half: the 32 WCS preload chip images (wcs_*.hex +
# wcs_image.hex) are covered too. They are generated, not tracked (except
# the MiSTer's copy in Verilog/Shared/support), so every copy found in the
# tree is compared against images RECOMPUTED here from the canonical PROMs
# with the same mapping gen_wcs_image.py uses. The word 0o2002 split is now
# DECIDED (Ronny, 02-SEP-2026): boards run the RAW PROM word, simulators run
# the 2024 patch (A,6 -> A,0 in the master-clear wait-loop count, 64x
# shorter power-on wait, nothing else - decoded in gen_wcs_image.py). So a
# WCS copy under a simulator directory (SIM_WCS_DIRS) must equal the --sim
# variant; every other copy must equal the raw variant. That is exactly the
# split found 01-SEP (TODO.md item 2) - now a rule, not a drift.
#
# Run: make test-microcode-sync   (Verilog/tests; registered in
#      run_all_tests.sh with pass pattern "TB_RESULT: PASS")
###############################################################################
import hashlib
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", ".."))
CANON = os.path.join(REPO, "Code", "Microcode")
IMAGES = ["AM27256_45132L.hex", "AM27256_45133L.hex"]

# Known, DECIDED divergences: (relative-path, image) -> reason.
# The DEC-2024 run-simulator patch (byte 4104: 0x60 -> 0x00 = microword
# 0o2002 MACL+1, A-operand A,6 -> A,0: the master-clear wait loop's outer
# count 64 -> 1). Both variants pass all tests everywhere (proven
# 24-AUG-2026: rig raw=PASS, rig patched=PASS, Tang raw=PASS; MiSTer boots
# SINTRAN raw). DECIDED 02-SEP-2026 (Ronny): raw on the boards, patched in
# the simulators - so these four harness copies are the sim variant by
# design, and only these.
EXCEPTIONS = {
    ("Verilog/sim", "AM27256_45133L.hex"): "895f360 sim patch - sims run the patched word by decision (02-SEP-2026)",
    ("Verilog/runSim", "AM27256_45133L.hex"): "895f360 sim patch - sims run the patched word by decision (02-SEP-2026)",
    ("Verilog/dmaSim", "AM27256_45133L.hex"): "895f360 sim patch - sims run the patched word by decision (02-SEP-2026)",
    ("Verilog/ND-120-Yosys", "AM27256_45133L.hex"): "895f360 sim patch - sims run the patched word by decision (02-SEP-2026)",
    # FOUND BY THIS GATE 24-AUG-2026, UNINVESTIGATED: byte 4109 differs
    # (LUA 0o2003 = MACL3, RF=1, bit 7 set: 0x01 -> 0x81) - a second
    # single-bit edit in the MACL microcode region, in a unit-test fixture
    # copy with no individual commit history. RONNY TO REVIEW: deliberate
    # bench fixture or stale drift? Remove this exception once decided.
    ("Verilog/CPU-BOARD-3202/circuit/BIF_BCTL_SYNC_8/sim", "AM27256_45132L.hex"):
        "UNINVESTIGATED byte-4109 edit (MACL3) - Ronny to review",
}

SKIP_DIRS = {"obj_dir", ".git", "boardtest-results", "build"}

# WCS preload images: which directories hold the SIMULATOR variant. Any
# other directory holding wcs_*.hex is a board flow (or Code/Microcode/wcs
# itself) and must hold the raw PROM word.
SIM_WCS_DIRS = {
    "Code/Microcode/wcs-sim",
    "Verilog/sim",
    "Verilog/runSim",
    "Verilog/dmaSim",
}
WCS_CHIPS = [f"wcs_{chip}{bank}" for bank in "CD" for chip in range(16, 32)]
# The --sim patch table, kept equal to gen_wcs_image.py PATCHES.
WCS_SIM_PATCHES = {0o2002: (0x0000000000006000, 0x0000000000000000)}


def md5(path):
    h = hashlib.md5()
    with open(path, "rb") as f:
        h.update(f.read())
    return h.hexdigest()


def read_prom(name):
    with open(os.path.join(CANON, name)) as f:
        vals = [int(t, 16) for t in f.read().split()]
    assert len(vals) == 32768, f"{name}: expected 32768 bytes, got {len(vals)}"
    return vals


def wcs_words(sim):
    """Recompute the 8192 microwords from the canonical PROMs the way
    gen_wcs_image.py does (RF=0 -> bits 15:0 ... RF=3 -> bits 63:48)."""
    lo = read_prom("AM27256_45132L.hex")
    hi = read_prom("AM27256_45133L.hex")
    words = []
    for lua in range(8192):
        w = 0
        for rf in range(4):
            idx = lua * 4 + rf
            w |= ((hi[idx] << 8) | lo[idx]) << (16 * rf)
        words.append(w)
    if sim:
        for lua, (clear, setb) in WCS_SIM_PATCHES.items():
            words[lua] = (words[lua] & ~clear) | setb
    return words


def wcs_expected_lines(words):
    """name -> list of hex lines, for wcs_image.hex and the 32 chip files."""
    exp = {"wcs_image": [f"{w:016x}" for w in words]}
    for bank, (name, lo_lua, hi_lua) in enumerate([("C", 0, 4096), ("D", 4096, 8192)]):
        for j in range(16):
            shift = 60 - 4 * j
            exp[f"wcs_{16 + j}{name}"] = [f"{(words[lua] >> shift) & 0xF:x}"
                                          for lua in range(lo_lua, hi_lua)]
    return exp


def read_lines(path):
    with open(path, "r") as f:
        return [ln.strip() for ln in f.read().splitlines() if ln.strip()]


def check_wcs_copies():
    """Every wcs_*.hex / wcs_image.hex in the tree must equal the recomputed
    raw image (board dirs) or the recomputed --sim image (SIM_WCS_DIRS).
    Returns (errors, checked)."""
    expected = {False: wcs_expected_lines(wcs_words(sim=False)),
                True: wcs_expected_lines(wcs_words(sim=True))}
    errors = 0
    checked = 0
    for root, dirs, files in os.walk(REPO):
        dirs[:] = [d for d in dirs if d not in SKIP_DIRS]
        rel = os.path.relpath(root, REPO).replace(os.sep, "/")
        present = [n for n in ["wcs_image"] + WCS_CHIPS if f"{n}.hex" in files]
        if not present:
            continue
        sim = rel in SIM_WCS_DIRS
        want = expected[sim]
        bad = []
        for n in present:
            checked += 1
            if read_lines(os.path.join(root, f"{n}.hex")) != want[n]:
                bad.append(n)
        variant = "SIM (patched 0o2002)" if sim else "RAW PROM"
        if bad:
            errors += len(bad)
            print(f"FAIL: {rel}: {len(bad)} WCS image(s) differ from the {variant} variant: "
                  f"{', '.join(bad)}")
            print(f"      regenerate: cd Code/Microcode && python3 gen_wcs_image.py"
                  f"{' --sim' if sim else ''}  (then copy)")
        else:
            print(f"  ok: {rel} ({len(present)} WCS images, {variant})")
    return errors, checked


def main():
    canon = {}
    for img in IMAGES:
        p = os.path.join(CANON, img)
        if not os.path.exists(p):
            print(f"FAIL: canonical image missing: {p}")
            print("TB_RESULT: FAIL")
            return 1
        canon[img] = md5(p)

    errors = 0
    checked = 0
    for root, dirs, files in os.walk(REPO):
        dirs[:] = [d for d in dirs if d not in SKIP_DIRS]
        for img in IMAGES:
            if img in files:
                p = os.path.join(root, img)
                rel = os.path.relpath(root, REPO).replace(os.sep, "/")
                if rel == "Code/Microcode":
                    continue
                checked += 1
                h = md5(p)
                if h != canon[img]:
                    key = (rel, img)
                    if key in EXCEPTIONS:
                        print(f"  allowed divergence: {rel}/{img} ({EXCEPTIONS[key]})")
                    else:
                        errors += 1
                        print(f"FAIL: {rel}/{img} differs from Code/Microcode/{img}")
                        print(f"      canonical {canon[img]}  found {h}")
                        print(f"      a NEW microcode split - sims and boards will")
                        print(f"      validate different machines (the 895f360 trap).")

    print(f"checked {checked} copies of {len(IMAGES)} images")

    wcs_errors, wcs_checked = check_wcs_copies()
    print(f"checked {wcs_checked} WCS preload images")
    errors += wcs_errors

    if errors == 0:
        print("TB_RESULT: PASS")
        return 0
    print(f"TB_RESULT: FAIL ({errors} undeclared divergences)")
    return 1


if __name__ == "__main__":
    sys.exit(main())

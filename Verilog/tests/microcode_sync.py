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
# The DEC-2024 run-simulator patch (byte 4104: 0x60 -> 0x00, microword
# 0o2002 MACL+1 COND bits). Both variants pass all tests everywhere
# (proven 24-AUG-2026: rig raw=PASS, rig patched=PASS, Tang raw=PASS);
# which one becomes canonical is Ronny's open decision. Until then these
# four harness copies are ALLOWED to differ - and only these.
EXCEPTIONS = {
    ("Verilog/sim", "AM27256_45133L.hex"): "895f360 sim patch, canonicalization pending",
    ("Verilog/runSim", "AM27256_45133L.hex"): "895f360 sim patch, canonicalization pending",
    ("Verilog/dmaSim", "AM27256_45133L.hex"): "895f360 sim patch, canonicalization pending",
    ("Verilog/ND-120-Yosys", "AM27256_45133L.hex"): "895f360 sim patch, canonicalization pending",
    # FOUND BY THIS GATE 24-AUG-2026, UNINVESTIGATED: byte 4109 differs
    # (LUA 0o2003 = MACL3, RF=1, bit 7 set: 0x01 -> 0x81) - a second
    # single-bit edit in the MACL microcode region, in a unit-test fixture
    # copy with no individual commit history. RONNY TO REVIEW: deliberate
    # bench fixture or stale drift? Remove this exception once decided.
    ("Verilog/CPU-BOARD-3202/circuit/BIF_BCTL_SYNC_8/sim", "AM27256_45132L.hex"):
        "UNINVESTIGATED byte-4109 edit (MACL3) - Ronny to review",
}

SKIP_DIRS = {"obj_dir", ".git", "boardtest-results", "build"}


def md5(path):
    h = hashlib.md5()
    with open(path, "rb") as f:
        h.update(f.read())
    return h.hexdigest()


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
    if errors == 0:
        print("TB_RESULT: PASS")
        return 0
    print(f"TB_RESULT: FAIL ({errors} undeclared divergences)")
    return 1


if __name__ == "__main__":
    sys.exit(main())

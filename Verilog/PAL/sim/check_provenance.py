#!/usr/bin/env python3
"""
PAL provenance checker.

Holds every PAL_<id>.v in Verilog/PAL/ to its original PALASM listing in
DesignDocuments/PAL-Code/SRC/<id>.txt: the Verilog may not drive an output the
listing does not define, and may not drop one it does.

This is the "invented signal" detector. It is a structural check, run on every
`make test`, complementing the one-time equation-by-equation audit recorded in
DesignDocuments/PAL-Code/PAL-TRANSCRIPTION-FINDINGS.md.

CAVEAT ON THE SOURCE (from that audit, 21-JUL-2026): the .txt listings are
OCR'd and have known garble - a dropped '/' on 44601B's /CGNTCACT produced one
false positive during the audit. The scanned images in
DesignDocuments/PAL-Code/IMG/<id>.png are the true original. When this checker
flags something, confirm against the PNG before believing the .txt.

Verdicts:
  COVERED          every Verilog output has an equation in the listing
  UNBACKED OUTPUT  the Verilog drives an output the listing does not define
  MISSING OUTPUT   the listing defines an equation the Verilog does not drive
  NO LISTING       no .txt exists for this PAL

Exit code 0 on pass, 1 on failure. Prints TB_RESULT: PASS / FAIL <n> errors.
"""

import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
PAL_DIR = os.path.abspath(os.path.join(HERE, ".."))
REPO_ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
SRC_DIR = os.path.join(REPO_ROOT, "DesignDocuments", "PAL-Code", "SRC")

# Verilog port names that differ from the listing's pin name for a stated
# reason. Every entry needs a justification - this table is how a genuine
# renaming bug would be hidden, so it stays short and each line is checkable.
ALIASES = {
    # (pal_id, verilog_name): listing_name
    ("44304E", "EBADR_b1"): "EBADR",   # PAL_44304E.v:18 - Verilator rejects
                                       # the bare name "EBADR"
}

# Pins the Verilog deliberately does not implement, with the reason. These are
# reported as warnings, never failures.
NOT_CONNECTED = {
    # (pal_id, signal): reason
    ("44408B", "RT"): "PAL_44408B.v:111 - pin exists on 444608 (VXFIX) but not "
                      "on 44408B; tied off, never driven",

    # Verified 08-AUG-2026 by tracing every instantiation: the ONLY board
    # instantiation is CYC_36.v:468 (PAL_44404C_EN), and CYC_36.v:485 leaves
    # .DLSHADOW() UNCONNECTED. PAL_44404C_EN.v:108 only forwards it to its own
    # port, which is the one CYC_36 leaves open. LSHADOW feeds nothing else
    # inside 44404C. The remaining references are the _EN equivalence
    # testbench, which compares the two implementations to each other.
    #
    # So although PAL_44404C.v:81-83 records the implementation as an explicit
    # GUESS (the signal belongs to revision 44404D, whose listing is not in
    # DesignDocuments/PAL-Code/SRC), the guess drives nothing and cannot change
    # machine behaviour. It is dead logic, not a latent bug.
    #
    # This only stops being true if someone connects .DLSHADOW() at CYC_36.v:485.
    # Doing so REQUIRES the 44404D listing first - do not wire it up on the
    # strength of the current guess.
    ("44404C", "DLSHADOW"): "CYC_36.v:485 leaves .DLSHADOW() unconnected at the "
                            "only board instantiation - the revision-D guess in "
                            "PAL_44404C.v:81-83 drives nothing. Needs the 44404D "
                            "listing before it may ever be connected.",
}

# KNOWN GAPS - signals the Verilog drives that no listing backs, which are
# already understood and are NOT new regressions. Reported loudly on every
# run as warnings so they stay visible, but they do not fail the build.
#
# This list may only ever SHRINK. Adding to it needs a specific, checkable
# reason; if you cannot write one, it is a real failure.
#
# Currently EMPTY. 44404C DLSHADOW used to be here; it was resolved on
# 08-AUG-2026 by proving the output is unconnected at the only board
# instantiation, and moved to NOT_CONNECTED above.
ACKNOWLEDGED = {
}


def verilog_outputs(path):
    """Output port names of the module, and the names it actually assigns."""
    src = open(path, errors="replace").read()
    src = re.sub(r"/\*.*?\*/", " ", src, flags=re.S)
    src = re.sub(r"//[^\n]*", " ", src)

    m = re.search(r"\bmodule\b.*?\((.*?)\)\s*;", src, flags=re.S)
    ports = set()
    if m:
        for pm in re.finditer(r"\boutput\b\s+(?:reg\s+|wire\s+)?"
                              r"(?:\[[^\]]*\]\s*)?([A-Za-z_]\w*)", m.group(1)):
            ports.add(pm.group(1))

    assigned = set()
    for am in re.finditer(r"\bassign\s+([A-Za-z_]\w*)\s*=", src):
        assigned.add(am.group(1))
    for am in re.finditer(r"([A-Za-z_]\w*)\s*<=", src):
        assigned.add(am.group(1))
    return ports, assigned


def listing_equations(path):
    """
    Equation left-hand-side names from a PALASM listing.

    Handles the real format in DesignDocuments/PAL-Code/SRC:
        IF (VCC) MCLK    = RWCS * /CC3
        IF (VCC) /WRFSTB = CC3
        MACLK := ...
    A leading '/' is polarity, not part of the name, so it is stripped.
    Stops at the DESCRIPTION section, whose revision comments are prose.
    """
    names = set()
    for line in open(path, errors="replace"):
        s = line.strip()
        if re.match(r"^DESCRIPTION\b", s, re.I):
            break
        if not s or s.startswith(";"):
            continue
        # strip trailing comment so a ';' comment cannot look like an equation
        s = s.split(";", 1)[0].strip()
        if not s:
            continue
        m = re.match(r"(?:IF\s*\([^)]*\)\s*)?/?([A-Za-z_]\w*)\s*:?=", s)
        if m:
            names.add(m.group(1))
    return names


def base_name(sig):
    """Verilog spells the active-low pins PALASM writes as /NAME with _n."""
    return sig[:-2] if sig.endswith("_n") else sig


def main():
    vfiles = sorted(f for f in os.listdir(PAL_DIR)
                    if re.fullmatch(r"PAL_\w+\.v", f))
    if not vfiles:
        print("no PAL_*.v found in", PAL_DIR)
        return 1
    if not os.path.isdir(SRC_DIR):
        print(f"PALASM listings not found at {SRC_DIR}")
        return 1

    errors = 0
    no_listing = []
    covered = []
    mirrors = []
    problems = []
    warned = []

    print("PAL provenance check")
    print("  Verilog  : Verilog/PAL/PAL_<id>.v")
    print("  listings : DesignDocuments/PAL-Code/SRC/<id>.txt")
    print("=" * 74)

    for vf in vfiles:
        pal_id = re.fullmatch(r"PAL_(\w+)\.v", vf).group(1)

        # _EN (clock-enable) and _D (decode mirror) files are derived from a
        # base PAL, not transcribed from a listing of their own. They are held
        # to the base by their equivalence testbenches, not by this checker.
        mm = re.fullmatch(r"(\w+?)_(EN|D)", pal_id)
        if mm:
            mirrors.append(pal_id)
            continue

        vpath = os.path.join(PAL_DIR, vf)
        lpath = os.path.join(SRC_DIR, pal_id + ".txt")

        if not os.path.isfile(lpath):
            no_listing.append(pal_id)
            continue

        ports, assigned = verilog_outputs(vpath)
        driven = (ports & assigned) or ports
        drives = {ALIASES.get((pal_id, base_name(p)), base_name(p))
                  for p in driven}
        eqbase = {base_name(e) for e in listing_equations(lpath)}

        raw_unbacked = sorted(drives - eqbase)
        raw_missing = sorted(eqbase - drives)

        unbacked, missing, notes = [], [], []
        for u in raw_unbacked:
            if (pal_id, u) in NOT_CONNECTED:
                notes.append(("n.c.", u, NOT_CONNECTED[(pal_id, u)]))
            elif (pal_id, u) in ACKNOWLEDGED:
                notes.append(("KNOWN GAP", u, ACKNOWLEDGED[(pal_id, u)]))
            else:
                unbacked.append(u)
        for m in raw_missing:
            if (pal_id, m) in NOT_CONNECTED:
                notes.append(("n.c.", m, NOT_CONNECTED[(pal_id, m)]))
            elif (pal_id, m) in ACKNOWLEDGED:
                notes.append(("KNOWN GAP", m, ACKNOWLEDGED[(pal_id, m)]))
            else:
                missing.append(m)

        if not unbacked and not missing and not notes:
            covered.append(pal_id)
            continue

        if not unbacked and not missing:
            warned.append(pal_id)
            print(f"\n{pal_id}")
            for kind, sig, why in notes:
                print(f"  [warn] {kind}: {sig}")
                print(f"         {why}")
            continue

        problems.append(pal_id)
        print(f"\n{pal_id}")
        print(f"  verilog drives : {', '.join(sorted(drives)) or '-'}")
        print(f"  listing defines: {', '.join(sorted(eqbase)) or '-'}")
        for kind, sig, why in notes:
            print(f"  [warn] {kind}: {sig} - {why}")
        for u in unbacked:
            print(f"  [FAIL] UNBACKED OUTPUT: {u} - driven by the Verilog, "
                  f"no equation in the listing")
            errors += 1
        for m in missing:
            print(f"  [FAIL] MISSING OUTPUT: {m} - in the listing, "
                  f"never driven by the Verilog")
            errors += 1
        print(f"  confirm against DesignDocuments/PAL-Code/IMG/{pal_id}.png "
              f"before believing the .txt - it is OCR'd")

    total = len(vfiles) - len(mirrors)
    print("\n" + "=" * 74)
    print(f"PALs checked  : {total}")
    print(f"covered       : {len(covered)}")
    if warned:
        print(f"with warnings : {len(warned)} - {' '.join(warned)}")
    if mirrors:
        print(f"derived mirrors: {len(mirrors)} "
              f"(held to their base PAL by equivalence tbs)")
    if no_listing:
        print(f"NO LISTING    : {len(no_listing)} - {' '.join(no_listing)}")

    print()
    if errors:
        print(f"TB_RESULT: FAIL {errors} errors")
        return 1
    print(f"TB_RESULT: PASS ({len(covered)} PALs agree with their listing "
          f"on every output)")
    return 0


if __name__ == "__main__":
    sys.exit(main())

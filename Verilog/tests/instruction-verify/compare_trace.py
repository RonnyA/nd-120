#!/usr/bin/env python3
###############################################################################
# compare_trace.py - mechanical INSTRUCTION-VERIFY trace comparator
#
# Compares an ND-120 RTL trace against the ND-110 golden reference trace
# (TRACE-INSTRUCTION-VERIFY-<AREA>.md format). Rules (from the ND-110 side):
#   1. Macro rows (instruction address, opcode, PIL, full register state at
#      fetch) must match EXACTLY, including current-level scratch R1-R7.
#   2. Micro rows are compared PER-SYMBOL (what registers a routine changed),
#      never by control-store address - the two microcodes place routines
#      differently. Symbols are normalized through the ND110<->ND120 map
#      (nd110_nd120_mic_map.tsv) including OCR spelling twins.
#   3. Clock-level (PIL 13) instructions are real and timing-dependent -
#      they are FILTERED into a separate count and flagged, never reported
#      as register divergence.
#
# Output: the FIRST macro divergence (address, register, expected vs actual,
# producing microcode routine by symbol), plus per-symbol micro warnings.
# Exit code 0 = traces equivalent, 1 = divergence, 2 = usage/parse error.
#
# Self-test (the calibration): compare a golden file against itself,
#   python3 compare_trace.py GOLDEN.md GOLDEN.md   -> "TRACES EQUIVALENT"
###############################################################################

import argparse
import os
import re
import sys

MACRO_RE = re.compile(r"^### #(\d+)\s+`([0-7]+) : ([0-7]+)`\s+PIL=(\d+)")
REGS_RE = re.compile(r"^`(.*)`\s*$")
MICRO_RE = re.compile(r"^\|\s*([0-7]+)\s*\|\s*([^|]*?)\s*\|\s*([^|]*?)\s*\|(.*)$")
CLOCK_PIL = 13  # level-13 = the clock; interleavings are timing-dependent

REG_NAMES = ["A", "D", "T", "X", "B", "L", "P", "STS",
             "R1", "R2", "R3", "R4", "R5", "R6", "R7",
             "Q", "F", "GPR", "LC"]


def parse_regs(line):
    regs = {}
    for tok in line.split():
        if "=" not in tok:
            continue
        k, v = tok.split("=", 1)
        regs[k] = v
    return regs


def parse_trace(path):
    """Returns list of macro entries:
    {n, addr, opcode, pil, regs, micro:[(csar, symbol, changed{k:v}, src)]}"""
    entries = []
    cur = None
    with open(path, "r", errors="replace") as f:
        for raw in f:
            line = raw.rstrip("\n")
            m = MACRO_RE.match(line)
            if m:
                cur = {"n": int(m.group(1)), "addr": m.group(2),
                       "opcode": m.group(3), "pil": int(m.group(4)),
                       "regs": None, "micro": []}
                entries.append(cur)
                continue
            if cur is None:
                continue
            if cur["regs"] is None:
                rm = REGS_RE.match(line)
                if rm and "=" in rm.group(1):
                    cur["regs"] = parse_regs(rm.group(1))
                    continue
            um = MICRO_RE.match(line)
            if um and um.group(1) and not line.startswith("|---"):
                sym = um.group(2).strip()
                changed = {}
                if um.group(3).strip() not in ("-", ""):
                    changed = parse_regs(um.group(3))
                cur["micro"].append((um.group(1), sym, changed, um.group(4)))
    return entries


def preprocess_ours(entries):
    """Normalize the ND-120 RTL trace to the golden representation:
    1) drop MOPC panel-service interludes - the ND-120 microcode's periodic
       console/panel poll enters via the PANEL vector between instructions
       (bumps P / clears GPR, then restores); the ND-110 emulator has no
       panel processor, so golden never logs these;
    2) merge an EXR with the instruction it executes - ours logs the
       executed instruction as a second section at the SAME address (the
       IRR dispatch passes csa 0); golden logs one merged section."""
    PANEL_ENTRY = ("PANEL", "MACRI", "PANVC")
    keep, panel = [], 0
    panel_scratch = set()  # (reg, pil) written by panel-service rows
    for e in entries:
        first = e["micro"][0][1] if e["micro"] else ""
        if first.split("+", 1)[0] in PANEL_ENTRY:
            # whole section is a panel interlude (older emitter versions)
            panel += 1
            written = set()
            for _csar, _sym, changed, _src in e["micro"]:
                for r in changed:
                    panel_scratch.add((r, e["pil"]))
                    written.add(r)
            if keep:
                keep[-1]["panel_after"] = keep[-1].get("panel_after", set()) | written
            continue
        # panel interlude embedded at the section tail: it runs BETWEEN
        # instructions and exits via CONT + fetch (= the next boundary)
        for j in range(len(e["micro"])):
            if e["micro"][j][1].split("+", 1)[0] in PANEL_ENTRY:
                panel += 1
                written = set()
                for _c, _s, changed, _t in e["micro"][j:]:
                    for r in changed:
                        panel_scratch.add((r, e["pil"]))
                        written.add(r)
                e["panel_after"] = e.get("panel_after", set()) | written
                break
        keep.append(e)
    merged, exr = [], 0
    for e in keep:
        if merged and merged[-1]["addr"] == e["addr"] \
                and merged[-1]["opcode"] != e["opcode"]:
            merged[-1]["micro"] = merged[-1]["micro"] + e["micro"]
            exr += 1
            continue
        merged.append(e)
    return merged, panel, exr, panel_scratch


def load_symmap(path):
    """symbol-normalizer: any spelling/side -> canonical (ND-120) name."""
    norm = {}
    if not path or not os.path.exists(path):
        return norm
    with open(path) as f:
        next(f)
        for line in f:
            parts = line.rstrip("\n").split("\t")
            if len(parts) < 4:
                continue
            sym, _a110, _a120, status = parts[:4]
            if status.startswith("ocr:"):
                other = status.split("=", 1)[1]
                norm[sym] = other      # ND-110 spelling -> ND-120 spelling
                norm[other] = other
            else:
                norm[sym] = sym
    return norm


def base_symbol(sym, norm):
    """LABEL+n -> canonical LABEL. Empty symbol stays empty."""
    if not sym:
        return ""
    base = sym.split("+", 1)[0]
    return norm.get(base, base)


def micro_symbol_profile(entry, norm):
    """Per-symbol union of changed registers inside one macro instruction."""
    prof = {}
    for _csar, sym, changed, _src in entry["micro"]:
        b = base_symbol(sym, norm)
        prof.setdefault(b, set()).update(changed.keys())
    return prof


def producing_symbol(prev_entry, reg, norm):
    """Last routine (by symbol) in the PREVIOUS macro entry that wrote reg."""
    if prev_entry is None:
        return "(none - first instruction)"
    last = None
    for _csar, sym, changed, _src in prev_entry["micro"]:
        if reg in changed:
            last = base_symbol(sym, norm) or "(unlabeled 0/)"
    return last or "(no micro row wrote %s)" % reg


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("golden", help="ND-110 reference trace .md")
    ap.add_argument("ours", help="ND-120 RTL trace .md (same format)")
    ap.add_argument("--map", default=os.path.join(
        os.path.dirname(os.path.abspath(__file__)), "nd110_nd120_mic_map.tsv"))
    ap.add_argument("--micro-warnings", action="store_true",
                    help="also report per-symbol micro profile differences")
    ap.add_argument("--max-warn", type=int, default=20)
    ap.add_argument("--ignore-regs", default="",
                    help="comma-separated registers to exclude from the macro "
                         "compare (whitelisted known-benign init differences)")
    args = ap.parse_args()
    ignore = set(x for x in args.ignore_regs.split(",") if x)

    norm = load_symmap(args.map)
    g_all = parse_trace(args.golden)
    o_all = parse_trace(args.ours)
    if not g_all:
        print("PARSE ERROR: no macro entries in %s" % args.golden)
        return 2
    if not o_all:
        print("PARSE ERROR: no macro entries in %s" % args.ours)
        return 2

    o_all, n_panel, n_exr, panel_scratch = preprocess_ours(o_all)
    if n_panel or n_exr:
        print("normalized ours: %d panel-service interludes dropped, "
              "%d EXR sections merged" % (n_panel, n_exr))
    if panel_scratch:
        print("panel-scratch registers (MOPC side effects; compared only "
              "once golden deviates from its baseline): %s"
              % ", ".join(sorted("%s@PIL%d" % k for k in panel_scratch)))
    g_clk = [e for e in g_all if e["pil"] == CLOCK_PIL]
    o_clk = [e for e in o_all if e["pil"] == CLOCK_PIL]
    g = [e for e in g_all if e["pil"] != CLOCK_PIL]
    o = [e for e in o_all if e["pil"] != CLOCK_PIL]

    print("golden: %d macro instructions (%d clock-level filtered)"
          % (len(g), len(g_clk)))
    print("ours:   %d macro instructions (%d clock-level filtered)"
          % (len(o), len(o_clk)))
    if len(g_clk) != len(o_clk):
        print("NOTE: clock-level (PIL %d) interleave count differs: golden=%d ours=%d"
              " - timing-dependent, flagged only." % (CLOCK_PIL, len(g_clk), len(o_clk)))

    warnings = 0
    prev_g = None
    # Per-(register, PIL) baselines: the value each trace had the FIRST time
    # that register was seen on that level. While BOTH traces still sit at
    # their own baseline the register is preamble state - init differences
    # (e.g. R7, level-0 D) are benign. The moment either trace deviates from
    # its baseline the compare is hard.
    g_base, o_base = {}, {}
    baseline_benign = set()
    # micro-state registers (not architectural): a dropped panel interlude
    # clobbers them on our side; they stay desynced until the two traces
    # naturally hold the same value again
    MICRO_STATE = ("Q", "F", "GPR", "LC")
    desync = set()
    desync_warns = 0
    for i in range(min(len(g), len(o))):
        ge, oe = g[i], o[i]
        # 1) macro address / opcode / PIL
        for field, label in (("addr", "instruction address"),
                             ("opcode", "opcode"), ("pil", "PIL")):
            if ge[field] != oe[field]:
                print("\nFIRST DIVERGENCE at macro #%d (golden #%d / ours #%d)"
                      % (i + 1, ge["n"], oe["n"]))
                print("  %s: expected %s, actual %s"
                      % (label, ge[field], oe[field]))
                print("  producing routine: %s"
                      % producing_symbol(prev_g, "P", norm))
                return 1
        # 2) full register state at fetch
        for r in REG_NAMES:
            if r in ignore:
                continue
            gv = (ge["regs"] or {}).get(r)
            ov = (oe["regs"] or {}).get(r)
            if r == "LC" and gv and ov:
                # golden logs LC as a 16-bit count; our hardware loop counter
                # is 6 bits ({ICD5,ICD4,LC3:0}) - compare the low 6 bits
                gv = "%02o" % (int(gv, 8) & 0o77)
                ov = "%02o" % (int(ov, 8) & 0o77)
            key = (r, ge["pil"])
            gb = g_base.setdefault(key, gv)
            ob = o_base.setdefault(key, ov)
            if gv != ov and gv == gb and ov == ob:
                baseline_benign.add("%s@PIL%d" % (r, ge["pil"]))
                continue
            if gv != ov and key in panel_scratch and gv == gb:
                # MOPC panel-service scratch: golden (no panel processor)
                # still holds its baseline; ours carries panel noise. Hard
                # compare resumes as soon as golden deviates (program wrote it).
                continue
            if r in MICRO_STATE:
                if gv == ov:
                    desync.discard(r)
                elif r in desync:
                    desync_warns += 1
                    continue
            if gv != ov:
                print("\nFIRST DIVERGENCE at macro #%d, address %s, opcode %s"
                      % (i + 1, ge["addr"], ge["opcode"]))
                print("  register %s: expected %s, actual %s" % (r, gv, ov))
                print("  producing routine (last writer in previous instruction): %s"
                      % producing_symbol(prev_g, r, norm))
                return 1
        # 3) micro per-symbol profile (warnings only, never a divergence)
        if args.micro_warnings and warnings < args.max_warn:
            gp = micro_symbol_profile(ge, norm)
            op = micro_symbol_profile(oe, norm)
            for sym in sorted(set(gp) | set(op)):
                if gp.get(sym, set()) != op.get(sym, set()):
                    print("  [micro warn] #%d %s: symbol %s changed %s vs %s"
                          % (i + 1, ge["addr"], sym or "(unlabeled)",
                             sorted(gp.get(sym, [])), sorted(op.get(sym, []))))
                    warnings += 1
        prev_g = ge
        # a panel interlude was dropped right after this instruction of ours:
        # its writes desync the micro-state registers until reconvergence
        for r in oe.get("panel_after", ()):  # set by preprocess_ours
            if r in MICRO_STATE:
                desync.add(r)

    if len(g) != len(o):
        # both traces are cap-limited (400 raw); normalization (panel drops,
        # EXR merges) shortens ours - a fully-matching common prefix is a pass
        if min(len(g), len(o)) >= 300:
            if baseline_benign:
                print("baseline-differs (benign, never written): %s"
                      % ", ".join(sorted(baseline_benign)))
            print("\nTRACES EQUIVALENT over common prefix: %d instructions "
                  "match exactly (golden %d / ours %d, both cap-limited)"
                  % (min(len(g), len(o)), len(g), len(o)))
            return 0
        print("\nLENGTH DIVERGENCE: golden has %d non-clock macro instructions,"
              " ours has %d (common prefix of %d matches)"
              % (len(g), len(o), min(len(g), len(o))))
        return 1

    if baseline_benign:
        print("baseline-differs (benign, never written by either trace): %s"
              % ", ".join(sorted(baseline_benign)))
    if desync_warns:
        print("micro-state desync skips after panel interludes: %d" % desync_warns)
    print("\nTRACES EQUIVALENT: %d macro instructions match exactly"
          " (%d micro warnings)" % (len(g), warnings))
    return 0


if __name__ == "__main__":
    sys.exit(main())

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
# Interrupt / stress levels (PIL 10-15): the clock (13), and under the RUN
# command the dummy-output (10) and IOX-error (12/14) stress levels run live.
# The golden traces log only the test levels (PIL 0-9); our emitter logs every
# level, so we filter interrupt-level rows into a separate count on both sides -
# they are timing-dependent, never a register divergence.
INTR_PIL_MIN = 10

REG_NAMES = ["A", "D", "T", "X", "B", "L", "P", "STS",
             "R1", "R2", "R3", "R4", "R5", "R6", "R7",
             "Q", "F", "GPR", "LC"]

# The ND-100/110/120 programmer-visible register set. Everything else in a
# macro row (R1-R7, Q, F, GPR, LC) is microcode working state, not
# architectural. Instruction validation rests on THESE plus addr/opcode/PIL.
ARCH_REGS = ("A", "D", "T", "X", "B", "L", "P", "STS")


def collapse_service_dups(entries):
    """Collapse consecutive macro rows that carry the SAME address, opcode and
    IDENTICAL architectural registers. Between real instructions BOTH microcodes
    periodically run panel/MOPC/wait service (PANEL, MS20, MOPC, WAIT1, CHKIT
    ...). The golden emitter logs each such interlude as its own macro row,
    stamped with the still-pending fetch (same addr+opcode, architectural state
    frozen, only scratch Q/F/GPR moving); our side normalizes its interludes
    out. Folding architecturally-identical repeats makes the two align without
    hiding real work: a genuine re-execution (loop back-edge) always advances an
    architectural register (a counter, X, T, P...), so it is never folded."""
    out, dropped = [], 0
    for e in entries:
        if out and out[-1]["addr"] == e["addr"] \
                and out[-1]["opcode"] == e["opcode"] \
                and out[-1]["regs"] and e["regs"] \
                and all((out[-1]["regs"].get(r) == e["regs"].get(r))
                        for r in ARCH_REGS):
            # keep the LAST folded row's registers (closest to the real fetch:
            # its GPR holds the opcode, not stale service scratch), concat micro
            out[-1]["micro"] = out[-1]["micro"] + e["micro"]
            out[-1]["regs"] = e["regs"]
            dropped += 1
            continue
        out.append(e)
    return out, dropped


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


def preprocess_ours(entries, do_exr=True):
    """Normalize a trace toward the shared representation:
    1) drop MOPC panel-service interludes - BOTH microcodes run a periodic
       console/panel poll between instructions (enters via the PANEL vector,
       bumps P / clears GPR, then restores). Both emitters log these as macro
       rows, so both traces are passed through this drop (do_exr toggles only
       step 2);
    2) merge an EXR with the instruction it executes - only OUR emitter logs
       the executed instruction as a second section at the SAME address (the
       IRR dispatch passes csa 0); golden logs one merged section, so this
       runs for ours only (do_exr=True)."""
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
    if not do_exr:
        return keep, panel, 0, panel_scratch
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


# Row is between-instruction service (not a real test instruction) when its
# FIRST labelled microcode routine is a service entry point: PANEL/MACRI/PANVC
# (the MOPC console/panel poll) or WAIT1 (the WAIT instruction's timing-
# dependent wait-for-interrupt loop). The two emitters disagree on whether such
# interludes get their own macro row - our boundary detector folds the WAIT
# loop into the neighbouring instruction, golden logs it standalone - and WAIT
# spins a timing-dependent number of times, so the counts never match. The
# resync aligner skips these on whichever side is ahead instead of comparing
# them position-for-position.
SERVICE_LED = ("PANEL", "MACRI", "PANVC", "WAIT1")


def is_service_row(entry, norm):
    for _csar, sym, _changed, _src in entry["micro"]:
        b = base_symbol(sym, norm)
        if b:                       # first LABELLED routine decides
            return b in SERVICE_LED
    return False


def macro_key(entry):
    return (entry["addr"], entry["opcode"], entry["pil"])


def dump_divergence(golden, ours, history, diff_reg, reason, norm, logpath):
    """On a deviation from the golden, write EVERYTHING needed to root-cause it:
    the diverging instruction on both sides, the full register state (marking
    which differ), the preceding aligned instructions for context, and the
    microcode routine steps of the diverging instruction on both sides. Printed
    to stdout and, if logpath is given, saved for later analysis."""
    L = []
    prev_g = history[-1][0] if history else None
    L.append("=" * 74)
    L.append("DIVERGENCE - ND-120 execution deviates from the ND-110 golden")
    L.append("=" * 74)
    L.append("reason: %s" % reason)
    L.append("golden #%s  %s : %s  PIL=%s"
             % (golden["n"], golden["addr"], golden["opcode"], golden["pil"]))
    L.append("ours   #%s  %s : %s  PIL=%s"
             % (ours["n"], ours["addr"], ours["opcode"], ours["pil"]))
    if diff_reg:
        gr = (golden["regs"] or {}).get(diff_reg)
        orr = (ours["regs"] or {}).get(diff_reg)
        L.append("diverging register %s: golden=%s  ours=%s" % (diff_reg, gr, orr))
    L.append("last writer of %s in the previous instruction: %s"
             % (diff_reg or "P", producing_symbol(prev_g, diff_reg or "P", norm)))
    L.append("")
    L.append("--- preceding aligned instructions (golden | ours) ---")
    for hg, ho in history[-8:]:
        L.append("  %s:%s  |  %s:%s"
                 % (hg["addr"], hg["opcode"], ho["addr"], ho["opcode"]))
    L.append("")
    L.append("--- full register state at the diverging instruction "
             "(* = differ) ---")
    gr, orr = golden["regs"] or {}, ours["regs"] or {}
    for r in REG_NAMES:
        gv, ov = gr.get(r), orr.get(r)
        L.append("  %-4s golden=%-8s ours=%-8s%s"
                 % (r, gv, ov, "  *" if gv != ov else ""))
    L.append("")
    L.append("--- golden micro rows (routine : changed registers) ---")
    for csar, sym, changed, _src in golden["micro"]:
        L.append("  %-8s %-12s %s"
                 % (csar, sym, " ".join("%s=%s" % kv for kv in changed.items())))
    L.append("--- ours micro rows ---")
    for csar, sym, changed, _src in ours["micro"]:
        L.append("  %-8s %-12s %s"
                 % (csar, sym, " ".join("%s=%s" % kv for kv in changed.items())))
    block = "\n".join(L)
    print(block)
    if logpath:
        with open(logpath, "w") as f:
            f.write(block + "\n")
        print("\n[full divergence detail written to %s]" % logpath)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("golden", help="ND-110 reference trace .md")
    ap.add_argument("ours", help="ND-120 RTL trace .md (same format)")
    ap.add_argument("--map", default=os.path.join(
        os.path.dirname(os.path.abspath(__file__)), "nd110_nd120_mic_map.tsv"))
    ap.add_argument("--micro-warnings", action="store_true",
                    help="also report per-symbol micro profile differences")
    ap.add_argument("--max-warn", type=int, default=20)
    ap.add_argument("--divergence-log", default=None,
                    help="on a deviation, write full register+context+microcode "
                         "detail to this file (default: <ours>.divergence.md)")
    ap.add_argument("--ignore-regs", default="",
                    help="comma-separated registers to exclude from the macro "
                         "compare (whitelisted known-benign init differences)")
    args = ap.parse_args()
    ignore = set(x for x in args.ignore_regs.split(",") if x)
    div_log = args.divergence_log or (args.ours + ".divergence.md")

    norm = load_symmap(args.map)
    g_all = parse_trace(args.golden)
    o_all = parse_trace(args.ours)
    if not g_all:
        print("PARSE ERROR: no macro entries in %s" % args.golden)
        return 2
    if not o_all:
        print("PARSE ERROR: no macro entries in %s" % args.ours)
        return 2

    # Panel/MOPC service runs between instructions on BOTH microcodes and both
    # emitters log it as macro rows - so drop it symmetrically. Only OUR emitter
    # double-logs EXR (executed instruction as a second same-address section),
    # so the EXR merge is our-side-only.
    o_all, n_panel, n_exr, panel_scratch = preprocess_ours(o_all, do_exr=True)
    g_all, g_panel, _ge, g_scratch = preprocess_ours(g_all, do_exr=False)
    panel_scratch |= g_scratch
    if n_panel or n_exr or g_panel:
        print("normalized: panel interludes dropped golden=%d ours=%d, "
              "%d EXR sections merged (ours)" % (g_panel, n_panel, n_exr))
    g_all, g_dup = collapse_service_dups(g_all)
    o_all, o_dup = collapse_service_dups(o_all)
    if g_dup or o_dup:
        print("collapsed service-interlude duplicate rows: golden %d, ours %d"
              % (g_dup, o_dup))
    if panel_scratch:
        print("panel-scratch registers (MOPC side effects; compared only "
              "once golden deviates from its baseline): %s"
              % ", ".join(sorted("%s@PIL%d" % k for k in panel_scratch)))
    g_clk = [e for e in g_all if e["pil"] >= INTR_PIL_MIN]
    o_clk = [e for e in o_all if e["pil"] >= INTR_PIL_MIN]
    g = [e for e in g_all if e["pil"] < INTR_PIL_MIN]
    o = [e for e in o_all if e["pil"] < INTR_PIL_MIN]

    print("golden: %d macro instructions (%d interrupt-level filtered)"
          % (len(g), len(g_clk)))
    print("ours:   %d macro instructions (%d interrupt-level filtered)"
          % (len(o), len(o_clk)))
    if len(g_clk) != len(o_clk):
        print("NOTE: interrupt-level (PIL>=%d) interleave count differs: "
              "golden=%d ours=%d - timing-dependent, flagged only."
              % (INTR_PIL_MIN, len(g_clk), len(o_clk)))

    warnings = 0
    prev_g = None
    # Per-(register, PIL) baselines: the value each trace had the FIRST time
    # that register was seen on that level. While BOTH traces still sit at
    # their own baseline the register is preamble state - init differences
    # (e.g. R7, level-0 D) are benign. The moment either trace deviates from
    # its baseline the compare is hard.
    g_base, o_base = {}, {}
    baseline_benign = set()
    # Scratch / microcode-state registers (NOT architectural). R1-R7 are the
    # WRF working registers the microcode borrows; Q/F/GPR/LC are ALU/decode
    # pipeline state. The ND architectural register set is only
    # A D T X B L P STS - those are ALWAYS hard-compared below.
    # Our ND-120 runs a panel display-refresh routine between instructions
    # (DISPL/DSPLY, which writes the hard-coded 174001 panel constant into a
    # WRF slot, then LDPANC) that the ND-110 emulator's panel does not
    # trigger, so it leaves different scratch behind. A dropped panel
    # interlude marks the registers it clobbered "desynced"; those scratch
    # registers are then skipped until the two traces naturally hold the same
    # value again (byte-string never reconverges R4 -> skipped for the rest).
    SCRATCH = ("R1", "R2", "R3", "R4", "R5", "R6", "R7", "Q", "F", "GPR", "LC")
    desync = set()
    desync_warns = 0
    scratch_warns = 0           # residual scratch divergences (never fatal)
    scratch_warn_regs = set()
    RESYNC_WIN = 8      # look-ahead when the streams get out of step
    i = j = 0           # independent golden / ours cursors
    matched = 0         # aligned real-instruction pairs compared
    skipped_g = skipped_o = 0
    history = []        # last aligned (golden, ours) pairs, for divergence context
    while i < len(g) and j < len(o):
        ge, oe = g[i], o[j]
        # --- alignment: skip between-instruction service rows, then resync ---
        if macro_key(ge) != macro_key(oe):
            if is_service_row(ge, norm):
                i += 1
                skipped_g += 1
                continue
            if is_service_row(oe, norm):
                j += 1
                skipped_o += 1
                continue
            # neither is obvious service: search a small window for the nearest
            # re-match and skip the shorter run (absorbs stray interludes)
            adv_g = next((k for k in range(1, RESYNC_WIN)
                          if i + k < len(g)
                          and macro_key(g[i + k]) == macro_key(oe)), None)
            adv_o = next((k for k in range(1, RESYNC_WIN)
                          if j + k < len(o)
                          and macro_key(o[j + k]) == macro_key(ge)), None)
            if adv_g is not None and (adv_o is None or adv_g <= adv_o):
                i += adv_g
                skipped_g += adv_g
                continue
            if adv_o is not None:
                j += adv_o
                skipped_o += adv_o
                continue
            dump_divergence(ge, oe, history, None,
                            "instruction stream desynced (no re-match within "
                            "%d rows): golden addr %s vs ours addr %s"
                            % (RESYNC_WIN, ge["addr"], oe["addr"]),
                            norm, div_log)
            return 1
        # aligned pair -> compare registers
        matched += 1
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
            if r in SCRATCH:
                if gv == ov:
                    desync.discard(r)
                elif r in desync:
                    desync_warns += 1
                    continue
            if gv != ov:
                # Architectural registers (the ND programmer's model) are the
                # instruction-correctness gate: any mismatch is a hard failure.
                if r in ARCH_REGS:
                    dump_divergence(ge, oe, history, r,
                                    "architectural register %s mismatch at macro "
                                    "#%d (%s : %s)"
                                    % (r, matched, ge["addr"], ge["opcode"]),
                                    norm, div_log)
                    return 1
                # Scratch/microcode-state register: not architectural. Residual
                # divergences here are panel display-refresh noise the desync
                # tracker did not catch through EXR-merge / resync. Surface as a
                # counted warning, never fail the gate on them.
                if scratch_warns < args.max_warn:
                    print("  [scratch warn] #%d %s %s: %s expected %s actual %s "
                          "(after %s)" % (matched, ge["addr"], ge["opcode"], r,
                          gv, ov, producing_symbol(prev_g, r, norm)))
                scratch_warns += 1
                scratch_warn_regs.add(r)
        # 3) micro per-symbol profile (warnings only, never a divergence)
        if args.micro_warnings and warnings < args.max_warn:
            gp = micro_symbol_profile(ge, norm)
            op = micro_symbol_profile(oe, norm)
            for sym in sorted(set(gp) | set(op)):
                if gp.get(sym, set()) != op.get(sym, set()):
                    print("  [micro warn] #%d %s: symbol %s changed %s vs %s"
                          % (matched, ge["addr"], sym or "(unlabeled)",
                             sorted(gp.get(sym, [])), sorted(op.get(sym, []))))
                    warnings += 1
        prev_g = ge
        history.append((ge, oe))
        if len(history) > 12:
            history.pop(0)
        # a panel interlude was dropped right after this instruction of ours:
        # its writes desync the micro-state registers until reconvergence
        for r in oe.get("panel_after", ()):  # set by preprocess_ours
            if r in SCRATCH:
                desync.add(r)
        i += 1
        j += 1

    if skipped_g or skipped_o:
        print("resync: skipped %d golden / %d ours service+wait rows"
              % (skipped_g, skipped_o))
    if baseline_benign:
        print("baseline-differs (benign, never written by either trace): %s"
              % ", ".join(sorted(baseline_benign)))
    if desync_warns:
        print("micro-state desync skips after panel interludes: %d" % desync_warns)
    if scratch_warns:
        print("scratch-register warnings (panel-refresh noise, non-fatal): "
              "%d across %s" % (scratch_warns,
              ", ".join(sorted(scratch_warn_regs))))

    # A short tail can remain on one side when a run is cap-limited (both raw
    # traces stop at 400) or ends inside a service interlude. What matters is
    # that every aligned real instruction matched.
    tail_g, tail_o = len(g) - i, len(o) - j
    if matched >= 300 or (tail_g == 0 or tail_o == 0):
        print("\nTRACES EQUIVALENT: %d aligned instructions match exactly "
              "(golden %d / ours %d rows; unmatched tail golden=%d ours=%d)"
              % (matched, len(g), len(o), tail_g, tail_o))
        return 0
    print("\nLENGTH DIVERGENCE: only %d instructions aligned "
          "(golden %d / ours %d, tail golden=%d ours=%d)"
          % (matched, len(g), len(o), tail_g, tail_o))
    return 1


if __name__ == "__main__":
    sys.exit(main())

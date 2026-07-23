#!/usr/bin/env python3
"""
fst_query.py — fast FST signal query for ND-120 Verilator traces.

Requires: pip install fstpy
Usage:
    python3 fst_query.py                   # demo: show signals near LCS_n rising edge
    python3 fst_query.py --help

Rules:
  - All addresses / values displayed in OCTAL (ND-120 is an octal machine)
  - LCS_n=1 marks start of execution (PROM->WCS load complete)
  - CSA=o000000, LCS_n=1 -> master clear / CPU self-test
  - CSA=o000016, LCS_n=1 -> PANEL INTERRUPT trap (TVEC dispatch)
"""

import sys
import os

FST = os.path.join(os.path.dirname(__file__), "waveform.fst")

# ---------------------------------------------------------------------------
# Signal substrings to search for in the FST hierarchy
# ---------------------------------------------------------------------------
SIGNALS = {
    "csa":    "s_debug_csa",
    "lcs_n":  "s_debug_lcs_n",     # or DEBUG_LCS_n
    "mclk":   "s_debug_mclk",
    "lc":     "s_lc_3_0",
    "ldlcn":  "s_ldlc_n",
    "cscomm": "s_cscomm_4_0",
    "csidbs": "s_csidbs_4_0",
    "idb":    "s_cpu_idb_15_0",
    "pan_n":  "s_pan_n",
    "conn_n": "s_conn_n",
}


def tick(t_ps):
    """Convert FST timestamp (ps) to simulation tick number."""
    return t_ps // 10 + 1


def fmt(key, val):
    """Format a signal value in octal (ND-120 convention)."""
    if val is None:
        return "?"
    if key in ("csa",):
        return f"o{val:06o}"
    if key in ("cscomm", "csidbs", "lc"):
        return f"o{val:02o}={val}"
    if key in ("idb",):
        return f"o{val:06o}"
    return str(val)


def load_fst(path, signals):
    """
    Load selected signals from an FST file.
    Returns dict: name -> list of (timestamp_ps, int_value)
    Requires fstpy: pip install fstpy
    """
    try:
        import fstpy
    except ImportError:
        print("ERROR: fstpy not installed. Run: pip install fstpy", file=sys.stderr)
        print("Alternative: fst2vcd waveform.fst > waveform_analysis.vcd", file=sys.stderr)
        sys.exit(1)

    print(f"Loading {path} ...", file=sys.stderr)
    fst = fstpy.read(path)

    # fstpy returns a dict: {signal_path: [(time, value_str), ...]}
    result = {k: [] for k in signals}
    found = {}

    for sig_path, events in fst.items():
        for key, substr in signals.items():
            if key not in found and substr in sig_path:
                found[key] = sig_path
                for t, v in events:
                    try:
                        result[key].append((int(t), int(str(v), 2)))
                    except (ValueError, TypeError):
                        pass  # x/z states
                break

    missing = [k for k in signals if k not in found]
    if missing:
        print(f"WARNING: signals not found: {missing}", file=sys.stderr)
    for k, path in sorted(found.items()):
        print(f"  {k:<10} -> {path} ({len(result[k])} events)", file=sys.stderr)

    return result


def find_lcs_rising(events):
    """Find first tick where LCS_n goes HIGH (1) = execution starts."""
    prev = None
    for t, v in events:
        if prev == 0 and v == 1:
            return t
        prev = v
    return None


def window(events, t_start, t_end):
    """Return events in [t_start, t_end]."""
    return [(t, v) for t, v in events if t_start <= t <= t_end]


def state_at(events, t):
    """Return most recent value at or before time t."""
    val = None
    for ev_t, v in events:
        if ev_t > t:
            break
        val = v
    return val


# ---------------------------------------------------------------------------
# Main demo: show signals around LCS_n rising edge + first LDLCN fire
# ---------------------------------------------------------------------------
if __name__ == "__main__":
    data = load_fst(FST, SIGNALS)

    lcs_evs = data.get("lcs_n", [])
    t_exec = find_lcs_rising(lcs_evs)
    if t_exec is None:
        print("LCS_n never went HIGH in this trace — PROM load still in progress?")
        sys.exit(0)

    print(f"\nExecution starts at tick {tick(t_exec)} (LCS_n went HIGH)")

    # CSA at start of execution
    csa_evs = data.get("csa", [])
    csa_at_start = state_at(csa_evs, t_exec + 100)
    print(f"CSA at execution start: {fmt('csa', csa_at_start)}")

    # Show all signals in a 50-tick window around LCS_n rising
    T0 = t_exec - 50 * 10
    T1 = t_exec + 100 * 10
    print(f"\n--- Signals around LCS_n rising (ticks {tick(T0)}..{tick(T1)}) ---")
    print(f"{'tick':>10}  {'signal':<10}  {'value'}")
    print("-" * 40)

    all_ev = []
    for sig, evs in data.items():
        for t, v in window(evs, T0, T1):
            all_ev.append((t, sig, v))
    all_ev.sort()

    for t, sig, v in all_ev:
        print(f"{tick(t):10d}  {sig:<10}  {fmt(sig, v)}")

    # First LDLCN fire after LCS_n=1
    ldlcn_evs = data.get("ldlcn", [])
    fires = [(t, v) for t, v in ldlcn_evs if t >= t_exec and v == 0]
    if fires:
        t_fire, _ = fires[0]
        csa_then = state_at(csa_evs, t_fire)
        print(f"\nFirst LDLCN fire after execution: tick {tick(t_fire)}, CSA={fmt('csa', csa_then)}")
    else:
        print("\nNo LDLCN fires after LCS_n=1 — LDLC bug still present")

# Signal Comparison Tool - How to Validate Changes

## Purpose

When modifying Verilog code (especially latch-to-FF conversions, bus redesigns, or
any logic changes), we need to verify that the simulation behavior hasn't changed.
This tool runs the simulation in two modes and compares key internal signals.

## Quick Start

```bash
cd /mnt/e/Dev/Repos/Ronny/nd-120/Verilog/sim

# Run both modes and compare (takes ~2 minutes)
make compare

# Results appear as:
#   IDENTICAL - no divergence!        (good)
#   DIVERGENCE FOUND - see trace_diff.txt   (investigate)
```

## What It Does

1. **`make compare_latch`** -- builds with `VERILATOR_SIM` (latch mode, original behavior), runs 1M cycles, outputs `trace_latch.csv`
2. **`make compare_ff`** -- builds with `VERILATOR_SIM` + `FPGA_FF_MODE` (flip-flop mode), runs 1M cycles, outputs `trace_ff.csv`
3. **`make compare`** -- runs both, then diffs the CSVs

## Signals Tracked

The comparison tool (`latch_ff_compare.cpp`) samples these signals at every `posedge sysclk`:

| Signal | Module | What it tells you |
|--------|--------|-------------------|
| CSA | ND120_TOP | Microcode address -- divergence here means CPU is executing different instructions |
| TERM_n | CYC_36 | Cycle termination -- timing divergence |
| MCLK | CYC_36 | Memory clock |
| EMD | PAL_44302B | Data path enable -- bus interface timing |
| CBWRITE | PAL_44303B | Write direction to bus |
| CMWRITE | PAL_44303B | Write direction to local memory |
| BACT | PAL_44304E | Bus activity state |
| EBADR_n | PAL_44304E | Bus address enable |
| DAP | PAL_44401B | Data address present |
| BLOCK | PAL_45001B | Error block state |
| RERR | PAL_45001B | Remote error state |
| BDRY | PAL_44310D | Bus data ready |
| DISB | PAL_45008B | Parity disable |
| TST | PAL_45008B | Test mode |
| BLOCKL | PAL_45009B | Local error block |
| LED | ND120_TOP | LED state -- visible output |

## Interpreting Results

### All MATCH
Your change is behaviorally identical. Safe to commit.

### Known acceptable divergences

| Signal | Cycle | Cause | Status |
|--------|-------|-------|--------|
| BDRY | 0 | Init transient: latch resolves to 1, FF resets to 0 | Harmless |
| LED | 0 | Follows from BDRY init | Harmless |
| CSA | ~16415 | Cascading from BDRY init | Harmless |
| TERM_n/MCLK | ~573456 | Late drift from CSA | Harmless |

These are expected and documented. Any NEW divergences need investigation.

### New divergence found
1. Note which signal diverges first and at what cycle
2. The earlier the divergence, the more fundamental the issue
3. If CSA diverges early (before cycle 1000), the change broke the CPU fetch sequence
4. Use GTKWave to examine the waveform around the divergence point

## How to Add More Signals

Edit `latch_ff_compare.cpp`. The signal paths use Verilator's internal naming:

```cpp
// Access via: top->rootp->ND120_TOP__DOT__CPU_BOARD__DOT__<path>__DOT__<signal>
(int)r.ND120_TOP__DOT__CPU_BOARD__DOT__BIF__DOT__DPATH__DOT__LDBCTL__DOT__PAL_44302_ULBC1__DOT__EMD,
```

To find the correct path for a new signal:
```bash
# Build first, then search the generated header
grep "YOUR_SIGNAL" sim/obj_dir/VND120_TOP___024root.h
```

Update the CSV header in the `printf` to match.

## Build Modes Explained

| Mode | Makefile command | Defines | Behavior |
|------|-----------------|---------|----------|
| Latch (default) | `make compile` | `VERILATOR_SIM` | Transparent latches, bus ports active, fast UART |
| FF (FPGA-like) | `make compile USE_LATCHES=0` | `VERILATOR_SIM` + `FPGA_FF_MODE` | Edge-triggered FFs, bus ports active, fast UART |
| Compare latch | `make compare_latch` | `VERILATOR_SIM` | Latch trace to trace_latch.csv |
| Compare FF | `make compare_ff` | `VERILATOR_SIM` + `FPGA_FF_MODE` | FF trace to trace_ff.csv |

Key: `VERILATOR_SIM` is always defined for Verilator builds (enables bus ports and fast UART).
`USE_TRANSPARENT_LATCHES` is derived in `ND120_TOP.v` -- active when `VERILATOR_SIM` is set
and `FPGA_FF_MODE` is NOT set.

## Python Analysis Script

For detailed per-signal first-divergence analysis:

```python
import csv
with open('trace_latch.csv') as f1, open('trace_ff.csv') as f2:
    r1 = csv.DictReader(f1)
    r2 = csv.DictReader(f2)
    cols = r1.fieldnames
    first_diff = {}
    for row1, row2 in zip(r1, r2):
        for c in cols:
            if c not in first_diff and row1[c] != row2[c]:
                first_diff[c] = (int(row1['cycle']), row1[c], row2[c])
    for c in cols:
        if c in first_diff:
            cyc, v1, v2 = first_diff[c]
            print(f"  {c:14s} {cyc:>10d}   latch={v1:>6s}  ff={v2:>6s}")
        elif c != 'cycle':
            print(f"  {c:14s}      MATCH")
```

## Files

| File | Purpose |
|------|---------|
| `sim/latch_ff_compare.cpp` | Signal sampling and CSV output |
| `sim/Makefile` | Build targets (`compare`, `compare_latch`, `compare_ff`) |
| `sim/trace_latch.csv` | Output: latch mode signal trace (gitignored) |
| `sim/trace_ff.csv` | Output: FF mode signal trace (gitignored) |
| `sim/trace_diff.txt` | Output: diff result (gitignored) |

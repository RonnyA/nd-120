# LDLCN / o000016 PANVC Dispatch Investigation

**Full path:** `Verilog/DELILAH-CPU/CGA_MIC/LDLCN_o000016_investigation.md`

**Last updated:** 2026-04-14

## Goal

Verify that the LDLC instruction at microcode address **o000016** (the PANVC
trap vector dispatch target) actually loads the LC (loop counter) register,
and that the value loaded is correct for the PANVC → MS20 microcode path.

## Background

- **o000016 is a TVEC dispatch target.** When TRAPN goes low, `CGA_MIC_IPOS`
  drives `MA_12_0 = {0...0, TVEC_3_0[3:0]}` combinationally, bypassing the
  MASEL (W_12_0) path entirely. So the jump into o000016 is a direct IPOS
  mux override, not a MASEL JMP/NEXT/RET operation.
- **LDLCN generation (CGA_DCD line 729):**
  `LDLCN = NAND(~COMM[4], COMM[3], COMM[2], COMM[1], COMM[0], LCS_n)`
  → LDLCN goes LOW when `COMM = o17` (5'b01111) AND `LCS_n = 1`.
- **LC counter (M169C in CGA_MIC.v lines 700-742):**
  - Clocked by `s_mclk` (CP)
  - Loads from `CD_15_0[5:0]` when `NL = LDLCN = 0` at posedge MCLK
  - LC_HI loads `CD[5:4]`; LC_LO loads `CD[3:0]`
- **RTC timing (memory: project_rtc_boot_fix.md):** RTC interrupt fires every
  8192 sysclk cycles in simulation. PANVC dispatch is driven by this.

## MASEL "Variant F" Fix (uncommitted, in working tree)

File: `DELILAH-CPU/CGA_MIC/circuit/CGA_MIC_MASEL.v`

The fix adds a `sysclk` pipeline register to break a data race:

```
Before: combinational mux → regREP (no sysclk stage) → posedge MCLK → regIW
After:  combinational mux → regREP_comb → posedge sysclk → regREP → posedge MCLK → regIW
```

The rationale: the old combinational `regREP` raced with `sc5/sc6` transitions
at the same sysclk edge as the MCLK rising edge, causing occasional setup
violations where regIW captured the wrong value. The Variant F stage makes
regREP stable for at least 1 sysclk before MCLK rises.

## Verified Facts (from fresh Verilator trace, 2026-04-14)

**Command run:**
```bash
cd Verilog/sim
make clean && make test_nd120 && make run   # via WSL
python3 trace_ldlc2.py
```

**Window around first PANVC dispatch (FST ticks 8957-8973):**

| Tick | CSA | CSCOMM | CSIDBS | MCLK | LDLCN | CD | LC |
|------|---------|--------|--------|------|-------|---------|-----|
| 8957 | o000000 | — | — | — | — | — | — |
| 8958 | — | — | — | **1↑** | — | — | — |
| 8959 | — | o03 | o04 | 0↓ | — | — | — |
| 8960 | o000017 | o00 | o00 | — | — | — | — |
| 8961 | **o000016** | — | — | — | — | — | — |
| 8964 | — | **o17 (LDLC)** | o27 | — | — | — | — |
| **8965** | **→o000050** | — | — | **1↑** | **0** | **o000001** | — |
| 8966 | — | o00 | o00 | 0↓ | — | — | — |
| 8968 | o000051 | — | — | 1↑ | 1 | o010160 | **o01** |

**Conclusions from this trace:**

1. **CSA does sit on o000016 long enough for MCLK to fire** — 4 FST ticks
   (8961 → 8965). The WCS output settles (CSCOMM=o17, CSIDBS=o27) before
   MCLK rises.
2. **LDLCN fires correctly** at the MCLK rising edge at tick 8965.
3. **LC loads value o01** at tick 8968 (one tick after the edge, due to
   FF propagation through M169C internal gates).
4. **The Variant F MASEL fix is working** — the pipeline register prevents
   the race that previously caused LDLCN to miss the MCLK edge.

## Simulation-wide LDLC activity (context)

Ran `trace_lc_all.py` which dumps every LDLCN pulse over the full run.
Observed 491 total LDLCN events. Two dominant repeating patterns:

- **o000050** — LC loads o01 (from PANVC at o000016, every ~8230 ticks)
- **o002502** — LC loads o17 (from a different LDLC instruction, same cadence)

Both fire on every RTC interrupt cycle (8192 sysclk ≈ 8230 FST ticks).
**o002502 is NOT part of this investigation** — it was noise from the
wide dump. Only o000016 / o000050 matters here.

## What Is NOT Yet Verified

1. **Is LC=o01 the semantically correct value for PANVC?** The trace confirms
   LC loads *some* value (1), but not whether the microcode at o000016
   intends to load 1. This requires cross-referencing the 1988 microcode
   listing at `Code/Microcode/ND-120 Mikroprogramlisting-L-ocr.md` for the
   LDLC instruction at address o000016.
2. **Does the PANVC → MS20 path downstream of o000016 actually reach MS20
   and complete correctly?** Not traced.
3. **Does the fix hold on FPGA?** Only verified in Verilator simulation.
   Per the 11b6ede checkpoint commit message, an earlier MASEL experiment
   worked in sim but broke on FPGA (CSA=00317 instead of 00000 at LCS_n
   rising). Variant F has not yet been flashed.

## Emulator Ground Truth (2026-07-13) — open items 1 and 2 CONFIRMED

Source: the ND110Compile emulator (`$ND_REPOS/ND110Compile/`), which boots
the SAME DELILAH-L binary through master clear + self-test to a working OPCOM and
passes INSTRUCTION-B end to end in ND-110 mode. Not guessed — asserted by a
committed unit test run against both microcode generations:

- Test: `PanelInterruptDispatch_TakesPanvcEntry1_MS20` in
  `$ND_REPOS/ND110Compile/TestND110/Boot/TestBootSequence.cs`
  (commit 4376d46). PASSES for ND-110/RASK and ND-120/DELILAH-L.

**Item 1 — LC=o01 IS the semantically correct value.** The compiled listing
(`$ND_REPOS/ND110Compile/ND110Compile/uCode/ND-120-DELILAH-L.LISTING.TXT`
lines 90-96 and 10254-10278) shows:

- o000016 = `% PANEL INTERRUPT` : `ALUD,NONE IDBS,PANEL COMM,LDLC T,JMP T,HOLD PANEL;`
- PANVC jump table at o003760, indexed by LC:
  `0:STOP  1:MS20  2:PRQ  3:SING2  4:LOAD  5:CONT  6:RSTRT  7:MACL`

So the 20ms panel/RTC interrupt must load LC=o01 to dispatch o003761 → MS20.
The emulator boot does exactly that: at the PANVC dispatch the LC low nibble is 1,
for both RASK and DELILAH-L. The observed `CD=o000001` at tick 8965 is correct.

**Item 2 — the PANVC → MS20 path completes.** Emulator-verified downstream path
(also visible in the golden CS trace
`$ND_REPOS/ND110Compile/traces/TRACE-OPCOM-0BANG-CSPATH.md`, RASK addresses):
`PANEL(o000050) → o000051 → o000052 (JMPAOPR dispatch) → o003761 (PANVC+1) →
MS20 → MOPC MRET1 → console poll`. The MS20 handler address is o002261 (RASK) /
o002333 (DELILAH-L). MS20 fires every 20ms period and OPCOM services the console
off it (proven by typed-command tests in the same suite).

Step A and Step B below are therefore answered; what remains for this
investigation is only Step C (FPGA validation of Variant F).

## Next Steps

### Step A — confirm expected LC value (task #3)

1. Read `Code/Microcode/ND-120 Mikroprogramlisting-L-ocr.md`
   and find the microcode word at address o000016.
2. Decode its LDLC source — what IDB selector does CSIDBS=o27 map to, and
   what value does that source put on CD[5:0]?
3. Compare against the observed `CD=o000001` at tick 8965.
4. If the value is wrong, the problem moved from "LDLCN timing" to
   "IDB mux / CSIDBS decode" — a different investigation.

### Step B — trace the full PANVC → MS20 path

1. From tick 8965 onward, follow CSA through o000050 → o000051 → o000052 →
   o000053 → o003761 and verify the microcode reaches MS20.
2. Watch for any early exit, unexpected branch, or LC underflow.

### Step C — FPGA validation (deferred)

1. Flash the Variant F MASEL fix.
2. Use the existing ILA probes (from the 11b6ede checkpoint) to capture
   CSA, LDLCN, LC, MCLK, regREP around a PANVC dispatch.
3. Compare against the Verilator-verified behavior above.
4. If CSA=00317 regression reappears, Variant F needs more work —
   likely a different clocking strategy (negedge sysclk, or deeper
   ALUCLK/MCLK FF chain refactor).

## Success Criteria

- **Task #2 (LDLCN timing):** LDLCN fires at every PANVC dispatch, LC loads
  a value from CD[5:0] at the MCLK edge following CSA=o000016.
  **STATUS: verified in Verilator as of 2026-04-14.** Pending FPGA confirmation.
- **Task #3 (LC value correctness):** LC value loaded at o000016 matches the
  intended value from the 1988 microcode listing, and the downstream PANVC →
  MS20 path executes to completion.
  **STATUS: not yet verified.**

## Key Files and Scripts

**Source files under investigation:**
- `Verilog/DELILAH-CPU/CGA_MIC/circuit/CGA_MIC.v` (LC counters, LDLCN routing)
- `Verilog/DELILAH-CPU/CGA_MIC/circuit/CGA_MIC_MASEL.v` (Variant F fix, uncommitted)
- `Verilog/DELILAH-CPU/CGA_MIC/circuit/CGA_MIC_IPOS.v` (TVEC override mux)
- `Verilog/DELILAH-CPU/CGA_DCD/circuit/CGA_DCD.v` (LDLCN decode from COMM)
- `Verilog/Shared/ndlib/M169C.v` (74LS169 counter behavior)

**Trace scripts:**
- `Verilog/sim/trace_ldlc2.py` — narrow window trace at first PANVC dispatch
- `Verilog/sim/trace_lc_all.py` — dumps all LDLCN pulses + LC changes across the run
- `Verilog/sim/trace_ldlcn.py` — total LDLCN event count over 2M ticks

**Build commands (WSL only — Git Bash verilator is broken):**
```bash
wsl bash -c "cd Verilog/sim && make clean && make test_nd120 && make run"
wsl bash -c "cd Verilog/sim && python3 trace_ldlc2.py"
```

**Microcode reference for Step A:**
- `Code/Microcode/ND-120 Mikroprogramlisting-L-ocr.md`

---

## Debug & Analysis Toolkit — `Verilog/sim/*.py`

All analysis scripts live in `Verilog/sim/` and
must be run from WSL (Git Bash `python3` works but `verilator` doesn't;
see `feedback_wsl_verilator.md`). All scripts default to reading
`waveform.fst` produced by `make run`.

**All addresses / values are displayed in OCTAL** — ND-120 is an octal
machine (see `feedback_use_octal.md`). Never print CSA, CD, LC, or any
address/value in hex or decimal alone.

### Infrastructure modules (imported by trace scripts)

| Script | Purpose |
|--------|---------|
| `fst.py` | Drop-in `open_wave(path)` reader. Pipes `.fst` through `fst2vcd` transparently; opens `.vcd` directly. **Every trace script should `from fst import open_wave`.** Requires `fst2vcd` (ships with gtkwave). |
| `nd120_vcd.py` | Legacy VCD signal-discovery helper (`find_ids`, `extract`). Used by older scripts; newer scripts inline their own `find_ids` over `open_wave`. |
| `fst_query.py` | General-purpose FST signal query with octal formatting and named markers (CSA, LCS_n, MCLK, LC, LDLCN, CSCOMM, CSIDBS, IDB, PAN_n, CONN_n). Good starting point for copy-paste when writing a new `trace_*.py`. |
| `vcd_extract.py` | Full-featured CLI extractor. Supports `-s SIG` exact, `-p PATTERN` substring, `--gtkw` (pull signals from a `.gtkw`), `--tstart/--tend`, `--json`, `--table`, `--list`. Use for ad-hoc "what's in this FST?" queries without writing a script. |
| `list_sigs.py` | Dump every signal name in the FST hierarchy. Use when you don't know the exact scoped path of a signal. |
| `find_sigs.py` | Grep signal names for substrings. Edit the `SUBS` list at the top and run. Faster than `list_sigs.py` when you know roughly what you want. |
| `find_wcs_signals.py` / `find_epans.py` / `find_panvc.py` | Same pattern as `find_sigs.py` but pre-wired for WCS / EPANS / PANVC-related signals. |

### Typical workflow for a new signal investigation

1. **Run the sim** to regenerate `waveform.fst` (WSL only):
   ```bash
   wsl bash -c "cd Verilog/sim && make clean && make test_nd120 && make run"
   ```
2. **Find the signal you need.** Try `vcd_extract.py waveform.fst --list` or
   `python3 find_sigs.py` (edit `SUBS` first). Signal scopes are under
   `TOP.ND120_TOP.CPU_BOARD.CPU.PROC.CGA.DELILAH.*` for CGA signals, and
   many debug signals are exposed as `TOP.ND120_TOP.s_debug_*`.
3. **Copy an existing `trace_*.py`** that's closest to your target
   (e.g. `trace_ldlc2.py` for narrow-window captures, `trace_lc_all.py`
   for whole-run dumps) and edit `WANT`, `T_START`, `T_END`.
4. **Run and iterate.** Trace scripts print octal-formatted tables —
   read them directly, don't open GTKWave for simple questions.

### Microcode decoding

| Script | Purpose |
|--------|---------|
| `decode_mcode.py` | Decode a 64-bit microcode word into CSIDBS (bits 41:37) and CSCOMM (bits 36:32). Edit the `decode_word(addr, hex)` calls at the bottom for specific addresses. Use when you have a hex word from the WCS ROM dump or listing and need to know what control signals it drives. Encodes the LDLCN rule: `CSCOMM=o17 (0b01111) AND LCS_n=1`. |

### FPGA (Vivado ILA) analysis

| Script | Purpose |
|--------|---------|
| `analyze_ila.py` | Parse a Vivado ILA CSV capture and extract CSA values at MCLK rising edges. Input: `F:/Xilinx/ND120/ND3202D/ND3202D.runs/impl_1/iladata.csv` (override via argv). Use after flashing a design and capturing via Vivado ILA to see the real-hardware boot sequence in the same octal CSA format the Verilator scripts use. |
| `compare_boot.py` | Cross-reference FPGA ILA CSV against Verilator VCD boot sequence and identify divergence points. Also loads the microcode listing at `E:/Dev/Repos/Ronny/ND110Compile/ND110Compile/uCode/ND-120-DELILAH-L.LISTING.TXT` for address→label mapping. **This is the bridge between sim-verified and FPGA-verified behavior** — run it after any change that needs FPGA confirmation. |

### Investigation-specific trace scripts (examples, not exhaustive)

There are ~40 `trace_*.py` scripts in `sim/`. They are all **one-off
captures** pinned to specific investigations (CSA ranges, named
microcode labels, signal sets). Treat them as historical examples to
copy, not as a stable API — names like `trace_mopc2.py` / `trace_mopc3.py`
just reflect successive iterations during a single debug session.

Useful families currently in the tree:

| Family | Scripts | Topic |
|--------|---------|-------|
| **LDLCN / LC** (this investigation) | `trace_ldlc.py`, `trace_ldlc2.py`, `trace_lc.py`, `trace_lc_all.py`, `trace_ldlcn.py`, `lc_changes.py`, `trace_before_lc1.py`, `check_idb_at_ldlc.py` | LC counter loads, LDLCN firing, IDB value at load |
| **PANVC / TVEC dispatch** | `trace_panvc.py`, `trace_panvc2.py`, `trace_tvec.py`, `trace_tvec2.py` | Trap vector dispatch into CGA_MIC_IPOS |
| **Boot / PROM→WCS handoff** | `trace_boot.py`, `trace_restart.py`, `trace_lcs.py`, `trace_wcs0.py`, `trace_wcs_write.py` | CSA=0 master clear, LCS_n rising, WCS write sequence |
| **MOPC / main loop** | `trace_mopc.py` through `trace_mopc4.py`, `trace_exec0.py` | Main opcode fetch/decode loop |
| **MACL / memory access** | `trace_macl.py` through `trace_macl3.py`, `trace_after_macl.py` | Memory access cycle microcode |
| **Signal routing** | `trace_conn.py`, `trace_csidbs.py`, `trace_csidbs2.py`, `trace_mipans.py`, `trace_mipans2.py`, `trace_mapans.py`, `trace_epans_transitions.py`, `trace_ms20.py`, `trace_stop.py`, `trace_icontin.py` | Specific control signal traces |

### Common patterns inside a `trace_*.py`

Most scripts follow this skeleton (see `trace_ldlc2.py` as the canonical
reference for this investigation):

```python
from fst import open_wave
from collections import defaultdict

VCD = "Verilog/sim/waveform.fst"

WANT = {
    "csa":   "s_debug_csa",      # substring match against full scoped name
    "mclk":  "s_debug_mclk",
    "lc":    "s_lc_3_0",
    "ldlcn": "s_ldlc_n",
    # ... add more signals here
}

def find_ids(vcd_path, want):
    # Walk $scope/$upscope/$var in header, return {key: (fst_id, width, full_path)}
    ...

def extract(vcd_path, id_map, tstart, tend):
    # Stream VCD data section, collect (time_ps, value) per key
    ...

def tick(t_ps):
    return t_ps // 10 + 1   # FST timestamps are ps, sim tick = 10ps

# Narrow window around an event of interest
T_CENTER = 8961                 # PANVC dispatch target tick
T_START  = (T_CENTER - 5) * 10
T_END    = (T_CENTER + 12) * 10
```

**Key conventions:**
- FST timestamps are in picoseconds. `tick = t_ps // 10 + 1` converts
  to the simulation tick number you see in `make run` output.
- `s_debug_*` signals are top-level debug taps wired out of ND120_TOP.v
  specifically for probing.
- Bit vectors come across as lines starting with `b` (binary) + the
  FST signal ID. Single bits come across as `0`/`1` + ID (no space).
- Always print CSA as `o{v:06o}`, CSCOMM/CSIDBS/LC as `o{v:02o}`,
  IDB/CD as `o{v:06o}`.

### When to write a new script vs. reuse an existing one

- **Reuse** when an existing script already has the signal set and time
  window you need — just re-run it after `make run`.
- **Copy-and-modify** an existing trace script when you want a similar
  signal set at a different event (different CSA, different tick range).
  `trace_ldlc2.py` is the cleanest template in the tree right now.
- **Write fresh** only when you need a fundamentally different view
  (e.g. statistical counts across the whole run, or multi-signal
  correlation). Even then, start by importing `open_wave` from `fst.py`.
- **Don't use GTKWave** for questions the scripts can answer in tabular
  form. GTKWave is slow to open on a 2M-tick FST and hides numeric
  detail behind cursor sliding. Scripts give you octal tables in seconds.


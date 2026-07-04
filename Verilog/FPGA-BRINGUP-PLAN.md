# ND-120 FPGA Bring-up Plan (redo-idb)

**Full path:** `/mnt/e/Dev/Repos/Ronny/nd-120/Verilog/FPGA-BRINGUP-PLAN.md`
**Branch:** `redo-idb`
**Last updated:** 2026-07-03

This is the working plan for the current phase: get the ND-120 to boot on the
Basys3 FPGA by closing the gap against the working Verilator reference. It
records **what we are fixing**, **which side (WSL vs Windows) does what**, and
**how we validate** an FPGA change against Verilator.

---

## 1. Goal of this phase

The CPU boots correctly in **Verilator** (microcode load, Master Clear, MACL
self-test 7/14, OPCOM works) but does **not** boot on the **Basys3 FPGA**
(`xc7a35tcpg236-1`). Verilator is the golden reference; the FPGA behavior is
captured with the Vivado ILA and compared against it.

**Current known FPGA bug:** the FPGA gets **stuck in boot Phase 3** — the
microcode address `CSA` oscillates `0x0425 <-> 0x0426` (the ALU countdown loop)
and never advances to `0x0427`.

**Success criterion for the active fix:** on the FPGA, `CSA` breaks out of
`0x0425/0x0426` and reaches `0x0427`, then continues into Phase 4 (self-test).

---

## 2. Root cause (why FPGA diverges from sim)

The original ND-120 design uses transparent latches and **combinational
signals as clocks** (`ALUCLK`, `MACLK`, `UCLK`, `MCLK`, PAL outputs) via
`always @(posedge some_derived_signal)`. In real TTL hardware this works
because of physical propagation delay. On a single-clock FPGA it is a **race**:
the derived "clock" rises combinationally *after* setup has closed for the
`sysclk` edge, so flip-flops sample the wrong (data, enable) pair.

The long-term fix is to convert these to synchronous design (sample the derived
clock as *data* on `sysclk`, edge-detect to make single-cycle enables). See
`Verilog/sim/FPGA_REFACTORING_GUIDE.md`.

---

## 3. Active experiment: "MASEL Variant F" (uncommitted)

The Phase 3 stall is suspected to come from the microcode next-address select
(`MASEL`) racing on the `sysclk`/`MCLK` edge, so `regIW` captures the wrong
address.

**Fix under test** (currently uncommitted in the working tree):

- `DELILAH-CPU/CGA_MIC/circuit/CGA_MIC_MASEL.v` — insert a 1-`sysclk` pipeline
  register to break the race:
  ```
  Before:  mux -> regREP (combinational) -> (posedge MCLK) -> regIW
  After:   mux -> regREP_comb -> (posedge sysclk) -> regREP -> (posedge MCLK) -> regIW
  ```
  The mux output is renamed `regREP_comb`; a `default` case avoids an inferred
  latch; `always @(posedge sysclk) regREP <= regREP_comb;` makes `regREP` stable
  for a full `sysclk` before `MCLK` samples it.

- `DELILAH-CPU/CGA_MIC/circuit/CGA_MIC.v` — add `mark_debug`/`DONT_TOUCH` on the
  microcode-address wires (`s_iw_12_0`, `s_ma_12_0_out`, `s_next_12_0`,
  `s_w_12_0`) so they are observable on the Vivado ILA.

> WARNING: This Variant F approach was tried once and reverted as broken on
> hardware (commit `0e4be9d "Revert broken MASEL experiment"`). This is the
> **second attempt**. It must be validated on the real FPGA, not only in
> Verilator, because the previous version passed sim but failed on hardware.

Live investigation notes: `DELILAH-CPU/CGA_MIC/LDLCN_o000016_investigation.md`.

---

## 4. Platform split — who does what

Both sides read the **same source files**: WSL `/mnt/e/...` and Windows
`E:\...` are the same drive. Edit the Verilog once; both toolchains see it. The
split is about tools, not files.

| | WSL / Linux (bash) | Windows 11 (PowerShell + Vivado) |
|---|---|---|
| Role | Edit Verilog, Verilator reference, validation | Synthesize, flash FPGA, capture ILA |
| Source path | `/mnt/e/Dev/Repos/Ronny/nd-120/Verilog` | `E:\Dev\Repos\Ronny\nd-120\Verilog` |
| Vivado project | — | `F:\Xilinx\ND120\ND3202D` (`ND3202D.xpr`) |
| Vivado install | — | `F:\AMDDesignTools\2025.2.1\Vivado` |
| Tools | `verilator`, `iverilog`, `gtkwave`, `python3 vcd_extract.py` | `vivado_build.ps1`, `flash.ps1`, Hardware Manager (ILA) |
| Output | `waveform.vcd`/`.fst` (golden), `trace_*.csv` | `output/ND120_TOP.bit` + `ND120_TOP.ltx` |

**Only file that must be copied:** microcode hex. `vivado_build.ps1` copies
`Code\Microcode\AM27256_4513{2,3}L.hex` into `F:\Xilinx\ND120\ND3202D\` before
synth (Vivado's `$readmemh` runs from the project dir). Missing hex = empty ROM.

---

## 5. The build/validate loop

Do the cheap WSL checks first. Never spend a ~1h synth on a change that already
fails in simulation.

### Inner loop — WSL, seconds to minutes (iterate here)

```bash
# a) Unit-test the MASEL race directly (iverilog, ~1s)
cd /mnt/e/Dev/Repos/Ronny/nd-120/Verilog/DELILAH-CPU/CGA_MIC/sim
make test-masel                 # MASEL_cycle_tb + MASEL_iw_capture_tb

# b) Prove the change did not alter sim behaviour (latch vs FF, ~2 min)
cd /mnt/e/Dev/Repos/Ronny/nd-120/Verilog/sim
make compare                    # "IDENTICAL" (good) or "DIVERGENCE FOUND" -> trace_diff.txt
```

`make compare` builds latch mode (`VERILATOR_SIM`) and FF mode
(`+FPGA_FF_MODE`), samples 16 key signals every `posedge sysclk` into
`trace_latch.csv`/`trace_ff.csv`, and diffs them. A first divergence in `CSA`
before ~cycle 1000 means the change broke the microcode/fetch path. Known
harmless init-transient divergences are listed in
`sim/SIGNAL-COMPARISON-HOWTO.md`.

### Regenerate golden reference — WSL (only if logic changed)

```bash
cd /mnt/e/Dev/Repos/Ronny/nd-120/Verilog/sim
make clean && make all          # produces the reference waveform + opens GTKWave
```

### Outer loop — Windows PowerShell (only once inner loop passes)

```powershell
cd E:\Dev\Repos\Ronny\nd-120\Verilog\fpga\basys3

# Logic changed -> FULL re-synth required (~1h). ps1 default already does full_synth.
.\vivado_build.ps1
#   copies microcode hex, runs vivado_build.tcl, sets up ILA probes (probe0..26),
#   writes F:\Xilinx\ND120\ND3202D\output\ND120_TOP.bit + .ltx
#   (-ReuseSynth ONLY for constraint/probe-only changes, NOT for a logic change)

# Flash to Basys3:
.\flash.ps1 -Quick     # JTAG only, volatile — fast, use while iterating
.\flash.ps1            # JTAG + SPI flash — persistent (survives power cycle)
```

`flash.ps1` also loads `ND120_TOP.ltx` so the ILA probes appear in Hardware
Manager. No `.ltx` = no probe visibility.

### Validate FPGA vs Verilator — Windows capture -> WSL compare

On Windows, after arming and capturing the ILA in Hardware Manager:

```tcl
write_hw_ila_data -csv_file -force C:/temp/ila_capture.csv [upload_hw_ila_data hw_ila_1]
```

On WSL, extract the same signal window from the golden VCD and compare the
microcode address trace:

```bash
cd /mnt/e/Dev/Repos/Ronny/nd-120/Verilog/sim
python3 vcd_extract.py waveform.vcd -e "TOP.CSA_12_0" \
  --tstart 5734355 --tend 7600000 --ticks --table
```

Check: does FPGA `CSA` escape `0x0425/0x0426` and reach `0x0427`?

---

## 6. Signal name mapping (Vivado ILA net <-> Verilator VCD name)

| Purpose | Vivado ILA net | VCD name |
|---|---|---|
| Microcode address | `s_debug_csa[*]` | `TOP.CSA_12_0` |
| Load control store | `s_debug_lcs_n` | `TOP.ND120_TOP.s_debug_lcs_n` |
| Memory clock | `s_debug_mclk` | `TOP.ND120_TOP.s_debug_mclk` |
| Cycle FSM | `s_debug_cc_term[*]` | `TOP.ND120_TOP.s_debug_cc_term` |
| CPU run | `s_run` | `TOP.ND120_TOP.s_run` |
| UART TX | `s_debug_uartTx` | `TOP.ND120_TOP.s_debug_uartTx` |
| ALU Q register | `.../ALU/s_q_15_0[*]` | `TOP.ND120_TOP...ALU.ALU_QREG.Q_15_0` |
| ALU F result | `.../ALU/s_f_15_0[*]` | `TOP.ND120_TOP...ALU.ALU_RALU.F_15_0` |
| Zero flag | `.../DELILAH/s_zf` | `TOP.ND120_TOP...DELILAH.ALU.ZF` |
| Condition | `.../DELILAH/s_cond` | `TOP.ND120_TOP...DELILAH.MIC.COND` |

Full hierarchy prefix: `CPU_BOARD/CPU/PROC/CGA/DELILAH/`.
Adding a probe: put `(* mark_debug = "true", DONT_TOUCH = "true" *)` on the wire
in the submodule, add a `connect_probe` entry in `vivado_build.tcl`, rebuild.

---

## 7. Boot phase reference (correct Verilator behavior)

| Phase | Tick window | CSA behavior |
|---|---|---|
| 1 Microcode load | 7 – 573,437 | `LCS_n=0`, CSA counts 0x0000..0x1FFF, then `LCS_n` high |
| 2 Initialization | 573,438+ | first exec 0x0401; 0x040F -> 0x0BB0 -> 0x0BB8 -> 0x0410 -> ... 0x0424 |
| 3 ALU countdown | 573,799 – 754,018 | CSA alternates 0x0425/0x0426, 16,384 iters, exit on ZF -> 0x0427 |
| 4 Self-test | 754,018+ | 0x0427 -> 0x07C8 -> 0x021D; MACL loop 0x044E-0x0453 |
| 5 OPCOM fetch | ~776K+ | 0x0000 -> 0x0401 -> 0x1xxx -> 0x0000 -> 0x0C00 -> exec -> 0x0065 |

FPGA currently stalls in **Phase 3**.

---

## 8. Gotchas

- **Full synth vs reuse:** a logic change must let `synth_1` actually re-run
  (`vivado_build.ps1` default). `-ReuseSynth` / omitting `full_synth` reuses the
  old checkpoint — fine for probe/constraint tweaks, wrong for a logic change.
- **Microcode hex** must be in `F:\Xilinx\ND120\ND3202D\` or the ROM is empty.
- **`.ltx` must match the `.bit`** — regenerated each build; a stale one
  mislabels probes.
- **Bitstream lives on F:**, not in the git repo:
  `F:/Xilinx/ND120/ND3202D/output/ND120_TOP.bit`.
- **Iteration speed:** `flash.ps1 -Quick` (volatile JTAG) for the debug loop;
  full `flash.ps1` (SPI) only to survive a power cycle.
- **In-FPGA tri-state:** `z` does not work; "3-state" buffers must drive `0`
  when disabled.

---

## 9. Next actions (checklist)

- [ ] Inner loop: `make test-masel` on Variant F — confirm race tests behave.
- [ ] Inner loop: `make compare` — confirm no new sim divergence vs FF mode.
- [ ] Diff Variant F against the reverted version (`0e4be9d`) to confirm what is
      different this second attempt.
- [ ] `make clean && make all` — refresh golden `waveform.vcd`.
- [ ] Windows: `.\vivado_build.ps1` (full synth) then `.\flash.ps1 -Quick`.
- [ ] Capture ILA, export CSV, compare `CSA` against golden — did it pass 0x0427?
- [ ] If pass: commit the two source files + testbenches + this plan + investigation doc.
- [ ] If fail: record the ILA divergence tick/signal in
      `LDLCN_o000016_investigation.md` and iterate.

Boot golden model / comparison automation (see sections 11-12):

- [ ] Decide emitter: sim writes `boot_trace.json` directly (preferred) vs VCD post-process.
- [ ] Write `docs/boot-golden-spec.md` from the microcode listing.
- [ ] Add sim emitter -> `boot_trace.json`; `make golden` commits `boot_golden.json`.
- [ ] Write `compare_boot_trace.py` (structural-vs-benign divergence rule).
- [ ] Add scripted ILA capture (`capture_ila.tcl`) driven over `hw_server` TCP 3121.

---

## 10. Reference documents

- `Verilog/sim/FPGA_DEBUG_RUNBOOK.md` — full Verilator-vs-FPGA workflow
- `Verilog/sim/VCD_ANALYSIS_GUIDE.md` — `vcd_extract.py` usage and signal map
- `Verilog/sim/SIGNAL-COMPARISON-HOWTO.md` — `make compare` latch-vs-FF tool
- `Verilog/sim/FPGA_REFACTORING_GUIDE.md` — synchronous conversion pattern (long-term fix)
- `Verilog/sim/boot_analysis.md` — full boot sequence reference
- `Verilog/worklog-latch-refactor.md` — latch->FF refactor history
- `Verilog/DELILAH-CPU/CGA_MIC/LDLCN_o000016_investigation.md` — active MASEL notes
- `Code/Microcode/ND-120 Mikroprogramlisting-L-ocr.md` — authoritative microcode listing (branch targets)
- `Code/Microcode/ND-06.031.1 ... Microprogrammer's Guide ...pdf` — microcode architecture reference

---

## 11. Boot golden model (async-aware comparison)

### Why a naive tick-by-tick diff fails

Comparing FPGA vs Verilator sample-by-sample produces **false divergences**,
because the boot path is not perfectly timing-deterministic. An investigation of
every external event that can steer the microcode address (`CSA`) found they all
converge on one 4:1 address mux in `CGA_MIC_IPOS.v` (via `TRAP_n` selecting the
`TVEC_3_0` branch, or `MR_n -> LCS_n` for the load sequence), and classify as:

| Event | Steers CSA via | Determinism at boot (this build) |
|---|---|---|
| Master Clear / POR | `MR_n -> LCS_n` load -> start at o02001 | Deterministic (once) |
| Traps (page fault / protect violation) | `TRAP_n -> TVEC` | Deterministic (fault-driven) |
| Panel / keylock / ALD | `PANN`/PANVC vector | Deterministic — 68705 stubbed `STAT=0`, buttons tied inactive (`IO_PANCAL_40.v:168`, `ND120_TOP.v:364-367`) |
| HW interrupts / PIL | `INTRQ -> TVEC` (LEV3) | Quiescent — external bus INT lines tied inactive |
| **RTC / 20 ms clock** | `s_rtc_n -> PANN/PANVC -> TVEC` -> microcode **o016** | **EVENT-DRIVEN — the only genuine async source** |

**Conclusion:** in a clean boot the RTC interrupt is the *single* source of
non-determinism (fires every ~8192 sysclk in sim / 20 ms real, re-armed by
microcode `CLRTC`, `DECODE_DGA_POW.v:332-348`). Its timing relative to microcode
progress differs between Verilator and FPGA and can dispatch to the PANVC handler
at o016 at different points. **Everything else must match exactly.** So compare
the microcode *state machine*, not the timeline.

### The well-known file: `boot_trace.json`

The sim emits a **semantic transition log** (one record per microcode basic-block
transition, annotated with why the branch was taken) instead of a raw per-tick
dump. Schema `nd120-boot-trace/v1`:

```json
{
  "schema": "nd120-boot-trace/v1",
  "build": { "VERILATOR_SIM": true, "FPGA_FF_MODE": false, "USE_LATCHES": true,
             "microcode_sha256": "...", "rtc_period_clk": 8192 },
  "events": [
    { "seq": 1,  "tick": 573438, "phase": "INIT",       "csa": "o02001",
      "kind": "ENTRY",         "branch_cause": "lcs_done", "async": null },
    { "seq": 42, "tick": 737750, "phase": "DELAY_LOOP", "csa": "o02045",
      "kind": "LOOP",          "branch_cause": "ZF", "async": null,
      "loop": { "exit_csa": "o02047", "iters": 180213 },
      "state": { "Q": "0x3FFF" } },
    { "seq": 57, "tick": 741002, "phase": "SELFTEST",   "csa": "o00016",
      "kind": "TVEC_DISPATCH", "branch_cause": "TRAPN", "tvec": 5,
      "async": { "type": "RTC" } }
  ]
}
```

Two fields make timing irrelevant:

- `loop` — collapses a countdown (e.g. o02045/o02046 x 180,213) into one record;
  `iters` is **allowed to differ** (it depends on clock), only entry/exit must match.
- `async` + `branch_cause` — a `TVEC_DISPATCH` with `async:{RTC}` is compared
  **structurally** ("an RTC dispatch to o016 occurred and returned cleanly"), not
  by when or how many times it fired.

### Comparator rule (structural vs benign)

Reduce both the sim `boot_trace.json` and the FPGA ILA CSV to canonical form, then:

- **STRUCTURAL divergence = real bug** — the same `(csa, branch_cause, state)`
  yields a *different* next address. Example: FPGA at o02046 with `ZF=1` loops
  back to o02045 instead of exiting to o02047. (This is the current Phase 3 stall.)
- **BENIGN divergence = ignore** — different `iters`, different RTC dispatch
  count/timing, different absolute `tick`.

An authoritative `docs/boot-golden-spec.md` (reconstructed from the microcode
listing) is the ground truth: a trace that passes the diff but violates the spec
is still flagged.

### Build tasks

1. `docs/boot-golden-spec.md` — phase/branch state machine POR -> o02001 -> delay
   loops -> MACL self-test -> OPCOM, with RTC/PANVC async points marked.
2. Sim emitter — extend `sim/test_nd120.cpp` (already samples `s_debug_csa`,
   `MCLK`, `COND`, `ZF`, `TVEC`, `TRAPN`, RTC like `latch_ff_compare.cpp`) to write
   `boot_trace.json`. `make golden` commits `boot_golden.json`.
3. `sim/compare_boot_trace.py` — normalize sim JSON + FPGA ILA CSV, apply the
   structural-vs-benign rule, print first structural divergence, exit 0/1.

---

## 12. Capture automation (scripted ILA over hw_server)

Goal: make FPGA capture scriptable and drivable from WSL, feeding the same
comparator as the sim.

- **Architecture:** Windows runs `hw_server` (owns the USB-JTAG cable); WSL drives
  captures over TCP `localhost:3121`. Avoids passing the Digilent device into WSL.
  `hw_server.bat` is under `F:\AMDDesignTools\2025.2.1\Vivado\bin\`.
- **`scripts/capture_ila.tcl`** — `connect_hw_server -url`, select ILA, set a real
  **trigger condition** (NOT `-trigger_now`), `run_hw_ila` / `wait_on_hw_ila` /
  `upload_hw_ila_data`, then export CSV in one step with
  `write_hw_ila_data -csv_file` (the existing, version-safe path — do not use the
  fragile `list_hw_samples` two-step).
- **Trigger matters most:** the ILA is only **2048 samples deep** (`f618a9b`), but
  boot runs hundreds of thousands of ticks and Phase 3 spans 16,384 iterations.
  `-trigger_now` captures a random useless window. Set the trigger on a landmark
  (e.g. `s_debug_csa == o02047` exit, or entry to o02045/o02046) so the window
  lands on the divergence, and use the same landmark to align against the golden
  trace.
- **Longer term:** a UART debug-event streamer (compact record: marker + CSA +
  flags per microcode step) escapes the 2048-sample ILA depth and yields a
  full-length boot trace reducible to the same `boot_trace.json` form. Reuses the
  existing UART path; better instrument for whole-boot divergence hunting, while
  ILA stays the tool for zooming into one failure.

Suggested layout under `Verilog/fpga-debug/`: `scripts/` (capture_ila.tcl,
run_capture.sh, run_capture.ps1), `captures/`, `decoder/` (compare_boot_trace.py).

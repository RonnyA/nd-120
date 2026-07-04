# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This repository contains a complete HDL implementation of the 1988 Norsk Data ND-120 CPU, recreated from original design documents and implemented in both Logisim-Evolution and Verilog. The goal is FPGA-synthesizable code that runs as the original ND-120 CPU. The Verilator simulation is the working reference; the FPGA (Basys3 / `xc7a35t`) build synthesizes but does not yet boot correctly, and closing that gap is the current focus.

## Environment

- Work is driven from **Linux / WSL2 with bash**. Refer to files by **repo-root-relative paths** (e.g. `Verilog/readme.md`, `Verilog/sim/Makefile`) — do not use drive letters or absolute root paths. The older docs that say to use PowerShell/`cd E:\path` are stale.
- **Vivado runs on the Windows host** (invoked via `.ps1`/`.tcl`), so the Vivado scripts hard-code Windows host paths internally. That is expected and confined to those TCL scripts — don't replicate that style elsewhere.
- The `nd120-fpga` skill contains detailed, current guidance for FPGA debugging, VCD/waveform analysis, Verilator-vs-Vivado comparison, and latch→FF refactoring. Prefer it for those tasks.

## Architecture

Major functional blocks:

- **DELILAH CPU Gate Array (CGA)** — main CPU: ALU, microcode controller (MIC), memory access controller (MAC), interrupt controller (INTR), trap handler (TRAP), IDB control, write register file (WRF). Submodules live under `Verilog/DELILAH-CPU/CGA_*/circuit/`.
- **Decoder Gate Array (DGA)** — instruction decode (`Verilog/DECODE-GateArray/`).
- **CPU Board 3202D** — full board: memory management/MMU, memory, I/O, support TTL chips (`Verilog/CPU-BOARD-3202/`).
- **PAL chips** — hand-converted from PALASM to Verilog (`Verilog/PAL/`).
- **Shared** — reusable TTL logic, memory modules, support circuits (`Verilog/Shared/`).
- **Top level** — `Verilog/ND120_TOP.v` wires the board, exposes the FPGA pin interface (Basys3 LEDs / 7-seg), and gates sim-vs-FPGA behavior with `ifdef`.

Design flow: **Logisim-Evolution schematics are the source** for most generated Verilog; hand-written modules fill the gaps. Keep new code compatible with the Logisim-generated structure.

### Compile-time build modes

Three defines control behavior; understanding them is essential:

- `VERILATOR_SIM` — set for **all** Verilator sim builds. Enables bus ports, fast UART, and large sim RAM (6MB, `ramSize=2`). Absent for FPGA synthesis, which uses tiny BRAM-friendly RAM (24KB, `ramSize=3`) — the `xc7a35t` only has 100 RAMB18 blocks. Selected automatically in `MEM_RAM_49.v`.
- `FPGA_FF_MODE` — forces edge-triggered flip-flop behavior instead of the original transparent-latch behavior. Added by the Makefiles when `USE_LATCHES=0`.
- `USE_LATCHES` (Makefile var, default `1`) — `1` = transparent latches (matches original hardware), `0` = FF mode (what the FPGA needs). This latch-vs-FF split is the crux of the FPGA boot divergence work.

## Development Commands

### Verilator simulation

Two harnesses under `Verilog/`:

- `sim/` — exercises `ND120_TOP`, writes FST waveforms for GTKWave inspection (`test_nd120.cpp`).
- `runSim/` — runs the full microcode load + CPU self-test, then enables OPCOM (UART) for CPU interaction (`Run120.cpp`).

```bash
# Waveform / signal-level sim (paths relative to repo root)
cd Verilog/sim
make clean
make all               # compile, run, open GTKWave (waveform.fst + top_3202d.gtkw)
make test_nd120        # compile only
make run               # run only
make compile USE_LATCHES=0   # build in FPGA FF mode instead of latch mode

# Full CPU sim (microcode load + self-test + OPCOM)
cd Verilog/runSim
make clean
make compile
make run
```

**Latch vs FF divergence check** (in `sim/`): `make compare` builds both modes, runs each, and diffs the traces (`trace_latch.csv` vs `trace_ff.csv`) → `trace_diff.txt`. Use this to prove a refactor kept behavior identical.

### Testbench conventions

Testbenches live in a `sim/` directory **next to the module** they test — no central test tree.

```
<component>/circuit/module.v      ← source
<component>/sim/Makefile          ← build & run targets
<component>/sim/module_tb.v       ← iverilog testbench   (*_tb.v)
<component>/sim/test_module.cpp   ← Verilator testbench  (test_*.cpp)
<component>/sim/*.gtkw            ← GTKWave configs
```

- **iverilog** (`*_tb.v`) — fast unit tests, race/timing checks. Run via `make test-*` in that `sim/`.
- **Verilator** (`test_*.cpp`) — full-module sim with C++ harness + waveforms. Run via `make all`.
- `Verilog/tests/vivado_warning_fixes/` is **legacy**; new testbenches go in the module's own `sim/`.

### FPGA build (Vivado, on Windows host)

FPGA build/flow files are under `Verilog/fpga/<board>/` (Basys3 = `fpga/basys3/`,
Tang Nano 20K = `fpga/tang-nano-20k/`). See `Verilog/fpga/README.md`.

```
# from Verilog/fpga/basys3/ :
vivado -mode batch -source vivado_build.tcl -tclargs [flags...]
# or: .\vivado_build.ps1   (copies microcode hex, then runs the tcl)
```

Key `vivado_build.tcl` flags: `full_synth` (required for a ~1h full re-synth; otherwise the existing `synth_1` checkpoint is reused), `skip_program`, `no_reset_synth`, `backup_bit`. `vivado_lint.tcl` runs lint only. Part: `xc7a35tcpg236-1`. Microcode `AM27256_4513{2,3}L.hex` must be present or the ROM is empty. Tang Nano 20K (Gowin) build is in progress — see `Verilog/docs/tang-nano-20k-port.md`.

### Code quality

**Always compile before reporting success.** Never create standalone test programs — use the existing sim/ infrastructure. No linter is configured; Verilator warnings (see the `-Wno-*` suppression list in the Makefiles) and `vivado_lint.tcl` are the quality gates.

## Conventions

- Internal signals use the `s_` prefix.
- Bus signals follow `BUSNAME_BITS` (e.g. `CD_15_0`, `FIDB_15_0`); active-low control signals use the `_n` suffix.
- Comments follow the existing header format (component name, design-doc page references, review dates).
- Tri-state note: inside the FPGA, `z` does not work — "3-state" buffers must drive `0` when disabled, not `z` (see `TTL_74245/244/241`, `AM29841`, `AM29861A`).
- Never use LINQ in any code additions.

## Status & known issues

- Verilator: microcode load + Master Clear run; CPU self-test currently passes **7 of 14** tests. OPCOM UART works.
- FPGA: synthesis passes, implementation/boot does not yet work (latch→FF and RAM issues are the leading suspects).
- Live task list: `Verilog/TODO.md` (high-priority items include `CPU_15` IDB/MMU validation and `AM29833A` parity). Historical latch-refactor notes: `Verilog/verilog-remove-latch.md`, `Verilog/worklog-latch-refactor.md`.

## Files to reference

(paths relative to repo root)

- `README.md` — project overview and history
- `Verilog/readme.md` — Verilog implementation status, testbench + RAM-config details
- `Verilog/nd120-plan.md` — detailed CPU architecture
- `Verilog/TODO.md` — current issues and tasks
- `Verilog/boot-sequence.md`, `Verilog/sim/boot_analysis.md` — boot walkthrough
- `Verilog/sim/FPGA_DEBUG_RUNBOOK.md`, `Verilog/sim/VCD_ANALYSIS_GUIDE.md` — FPGA debug + VCD workflow

# ND-120 Build-Time Defines (sim vs FPGA) and Unification Plan

**Full path:** `Verilog/docs/build-defines.md`
**Last updated:** 2026-07-04

Every compile-time `ifdef` that makes the Verilog build differently for Verilator
simulation vs FPGA synthesis, what it does, and whether it can be **unified to a
single code path**. Goal: land on one build as far as possible, keeping only the
differences that are genuinely per-target (memory size/type, FPGA vendor
primitives, and the sim-harness bus ports).

## Inventory

| Symbol | Uses | Defined by | Purpose | Unify? |
|---|---|---|---|---|
| `VERILATOR_SIM` | 16 | Makefiles (`-DVERILATOR_SIM`, always on for Verilator) | Master sim switch: exposes external memory-bus ports, fast UART, large sim RAM | **Partial** — keep only for bus ports + RAM (per-target); narrow the rest |
| `USE_TRANSPARENT_LATCHES` | 10 | derived in `ND120_TOP.v:23-27` = `VERILATOR_SIM && !FPGA_FF_MODE` | Selects transparent-latch behavior (original HW) vs edge FF | **YES — retire** (see below) |
| `FPGA_FF_MODE` | 1 | Makefiles when `USE_LATCHES=0` | Forces FF behavior in a sim build | **YES — retire with latches** |
| `GOWIN` | 3 | `CPU_CS_PROM_19.v:11` (commented out; Xilinx default) | Gowin vs Xilinx PROM/BRAM primitive | **NO — legit per-vendor** (document) |
| `_OLD_WAY_` | 2 | never defined anywhere | Dead legacy incrementer path | **YES — delete dead code** |
| `BOARD_CLK_FREQ` | 2 | `SC2661_UART.v:141` default `100_000_000` | Board clock for UART baud divisor | **Already unified** (param + default) |
| `UART_BAUD_RATE` | 2 | `SC2661_UART.v:144` default `115_200` | UART baud for divisor | **Already unified** (param + default) |

## Detail and rationale

### `VERILATOR_SIM` — keep, but only for what's genuinely per-target
Three distinct things hide under this one symbol; they should be understood
separately:

1. **External memory-bus ports** (`ND120_TOP.v`, several `ifdef` blocks) — sim
   exposes bus ports so the C++ harness (`simDevices/NDBus.cpp`, `NDDevices.cpp`)
   can attach memory/peripherals. The FPGA has no external bus. **This is a real
   sim-harness necessity — cannot unify away**, but it should be the *only* thing
   that key uses `VERILATOR_SIM` for.
2. **RAM size/type** (`MEM_RAM_49.v:19-23`, `RamSize` param; `SIP1M9`) — sim uses
   large RAM (`ramSize=2`, ~1M/6MB); FPGA uses tiny BRAM (`ramSize=3`, 4KB/24KB)
   because `xc7a35t` has only 100 RAMB18. **This is the memory-per-FPGA difference
   you called out — legitimately per-target.** Different FPGAs (more BRAM, or
   external DRAM) would pick a different `ramSize`. Keep, document per board.
3. **Fast UART** — sim shortcuts UART timing. This one could be unified by relying
   on `BOARD_CLK_FREQ`/`UART_BAUD_RATE` (below) instead of a `VERILATOR_SIM`
   fast-path, so sim and FPGA use the same UART logic at different clock params.

### `USE_TRANSPARENT_LATCHES` / `FPGA_FF_MODE` — RETIRE (now justified)
This is the latch-vs-FF split, the crux of the whole FPGA effort. The original
design used transparent latches; the FPGA needs edge FFs.

**As of 2026-07-04, FF mode in Verilator boots identically to latch mode** (a
fresh `make compare` shows all 16 tracked signals match except the documented
harmless BDRY cycle-0 init transient; FF reaches exec start `o002001` and the
Phase-3 exit `o002047` just like latch mode). The latch path was kept only as the
"known-good original-hardware reference." Now that FF matches it, the latch path
is redundant for building.

**Recommendation:** make FF behavior the single path for both sim and FPGA, and
remove `USE_TRANSPARENT_LATCHES` / `FPGA_FF_MODE` / the `USE_LATCHES` Makefile
var. This collapses 10 `ifdef` sites + 1 derived define + 1 override into one
behavior. **Do it as a reviewed step, not blindly:**
1. Keep `make compare` working until the switch (it is the proof tool).
2. For each of the 10 `USE_TRANSPARENT_LATCHES` sites, delete the latch branch,
   keep the FF branch.
3. Re-run the full boot in sim; diff CSA path against the pre-change latch golden
   (`boot-golden-spec.md`) — must be identical except the BDRY transient.
4. Retire `USE_LATCHES` from `sim/Makefile`, `runSim/Makefile`, and the module
   sim Makefiles.
The latch code stays in git history if ever needed as the HW reference.

Files with `USE_TRANSPARENT_LATCHES`: the PAL set (`PAL_44302B`, `44303B`,
`44304E`, `44310D`, `44401B`, `45001B`, `45008B`, `45009B`), `AM29841.v`,
`CPU_CS_ACAL_17.v`, and the derivation in `ND120_TOP.v`.

### `GOWIN` — keep (per-FPGA-vendor, like memory)
`CPU_CS_PROM_19.v` only; currently commented out (`//`define GOWIN`), so Xilinx
BRAM inference is the default. Selects the vendor-specific PROM/BRAM primitive.
This is the same class as the RAM-size difference: a legitimate per-target choice
for a different FPGA family. Keep it, document that Basys3/Artix-7 leaves it off.

### `_OLD_WAY_` — delete (dead code)
`CGA_MAC_APOS_INC.v:23` and `CGA_MIC_IINC.v:25` guard a legacy incrementer with
`ifdef _OLD_WAY_`, but the symbol is never defined, so the `else` branch is always
taken. Remove the `ifdef _OLD_WAY_ ... else` wrapper and keep the live branch.

### `BOARD_CLK_FREQ` / `UART_BAUD_RATE` — already the right pattern
`SC2661_UART.v` parameterizes the baud divisor with sensible defaults (100 MHz,
115200) and allows override per board. This is exactly how per-target differences
*should* be expressed — a parameter with a default, not a sim/FPGA fork. Leave as
is; extend this pattern if the fast-UART path (above) is unified.

## Target end state

After the cleanup, the only intentional sim-vs-FPGA / per-board differences left
are:

1. **Memory** — `MEM_RAM_49.v` `ramSize` (and vendor RAM primitive). Per-FPGA.
2. **FPGA vendor primitive** — `GOWIN` vs Xilinx PROM/BRAM. Per-FPGA.
3. **Sim-harness bus ports** — `VERILATOR_SIM` exposes the external bus so the
   C++ device models can attach. Sim-only by nature.
4. **Clock/baud parameters** — `BOARD_CLK_FREQ`/`UART_BAUD_RATE`. Per-board, via
   defaults.

Everything else (latch vs FF, `_OLD_WAY_`) collapses to a single code path. That
is "one set" with only the unavoidable per-hardware memory/vendor differences you
anticipated.

## Cross-reference
- `sim/Makefile`, `runSim/Makefile` — `USE_LATCHES` / `SIM_DEFINES` wiring.
- `ND120_TOP.v:20-27` — `USE_TRANSPARENT_LATCHES` derivation.
- `MEM_RAM_49.v:19-23,148` — RAM size selection.
- `docs/fpga-debug-methodology.md` — why FF now matches latch (Branch B).
- `Verilog/verilog-remove-latch.md`, `worklog-latch-refactor.md` — latch-refactor history.

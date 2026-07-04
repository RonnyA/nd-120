# FPGA targets

**Full path:** `/mnt/e/Dev/Repos/Ronny/nd-120/Verilog/fpga/`

Per-FPGA build and flow files. The Verilog/HDL source is **shared** and stays
under `Verilog/` - the build scripts reference it by absolute path. Only the
board-specific build/flow files (scripts, constraints, tool projects) live here,
one folder per board.

## Targets

| Target | FPGA | Toolchain | Status | Details |
|--------|------|-----------|--------|---------|
| [**basys3/**](basys3/README.md) | Xilinx Artix-7 `xc7a35tcpg236-1` | Vivado (Windows host) | Synthesis OK; **fails timing** (WNS approx -100 ns), does not boot | [basys3/README.md](basys3/README.md) |
| [**tang-nano-20k/**](tang-nano-20k/README.md) | Gowin `GW2AR-18` | Gowin EDA / OSS (yosys+nextpnr) | **Primary target**, bring-up in progress | [tang-nano-20k/README.md](tang-nano-20k/README.md) |

**Tang Nano 20K is the current focus** (faster synth than Vivado, Linux-native
OSS flow, and 8 MB SDRAM for full main memory). Basys3 is the fallback/second
target once Tang works.

## Shared context (applies to both)

- **The boot blocker is timing, not logic.** The FF-mode Verilator sim boots
  correctly; the FPGAs fail because ~35 modules use derived signals as clock
  nets. The fix (single `sysclk` + clock-enables) is board-independent. See
  [`../docs/fpga-debug-methodology.md`](../docs/fpga-debug-methodology.md) 3.2.
- **Microcode preload:** `SKIP_WCS_LOAD` bitstream-preloads the WCS and skips the
  runtime load phase - verified in Verilator, and required to fit the Tang's
  BSRAM. See [`../docs/skip-wcs-load.md`](../docs/skip-wcs-load.md).
- **Compile-time defines** (per-target behavior): see
  [`../docs/build-defines.md`](../docs/build-defines.md).
- **Golden boot reference** for validation: see
  [`../docs/boot-golden-spec.md`](../docs/boot-golden-spec.md).

## Reference docs

- [`../docs/tang-nano-20k-port.md`](../docs/tang-nano-20k-port.md) - Tang port analysis
- [`../docs/fpga-debug-methodology.md`](../docs/fpga-debug-methodology.md) - Verilator-vs-FPGA debug
- [`../docs/build-defines.md`](../docs/build-defines.md) - compile-time defines
- [`../docs/skip-wcs-load.md`](../docs/skip-wcs-load.md) - preloaded-WCS microcode
- [`../docs/boot-golden-spec.md`](../docs/boot-golden-spec.md) - expected boot sequence
- [`../FPGA-BRINGUP-PLAN.md`](../FPGA-BRINGUP-PLAN.md) - overall bring-up plan

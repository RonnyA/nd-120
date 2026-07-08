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
| [**tang-nano-20k/**](tang-nano-20k/README.md) | Gowin `GW2AR-18` | Gowin EDA / OSS (yosys+nextpnr) | **Primary target**, bring-up in progress; SDRAM test [`tang-nano-20k/sdram-test/`](tang-nano-20k/sdram-test/README.md) **passes on hardware** via the OSS flow | [tang-nano-20k/README.md](tang-nano-20k/README.md) |
| [**mister/**](mister/README.md) | Intel Cyclone V SE `5CSEBA6U23I7` (DE10-Nano / "MiSTer PI", ~110K LE + ARM HPS running Linux) | Quartus Lite 17.0.2 (free, Docker `raetro/quartus:17.0`) | **Planned** - MiSTer core with floppy/HDD as Linux-side image files, OSD menu, microcode upload from file; phase plan with validated links in [`mister/docs/00-overview.md`](mister/docs/00-overview.md) | [mister/README.md](mister/README.md) |
| [**qmtech-a35t/**](qmtech-a35t/README.md) | Xilinx Artix-7 `xc7a35tcsg325-1` (QMTECH XC7A35T SDRAM core board) | Vivado (Windows host), same flow as Basys3 | **Paused side experiment** - stages 1-2 (LED smoke test + mem-test port) written and sim-verified, nothing run on hardware yet; resume via [`qmtech-a35t/HANDOFF-qmtech-a35t-bringup.md`](qmtech-a35t/HANDOFF-qmtech-a35t-bringup.md) | [qmtech-a35t/README.md](qmtech-a35t/README.md) |
| [**cmod-a7-35t/**](cmod-a7-35t/README.md) | Xilinx Artix-7 `xc7a35t-1cpg236` (Digilent Cmod A7-35T DIP module, 512 KB external SRAM) | Vivado (Windows host), same flow as Basys3 (same part) | **Research only** - not planned for purchase/porting (too expensive vs the Tang Nano 20K); folder holds the collected docs + backend sketch | [cmod-a7-35t/README.md](cmod-a7-35t/README.md) |

## Priority order (2026-07-08)

1. **Tang Nano 20K - primary target** (faster synth than Vivado, Linux-native
   OSS flow, 8 MB SDRAM for full main memory). It is also the project's
   **value-for-money benchmark**: under 300 NOK for SDRAM + microSD +
   USB-JTAG/UART + HDMI - judge any new board suggestion against it.
2. **Basys3** - fallback/second target once Tang works; currently the active
   debugging line for the board-independent timing work.
3. **QMTECH XC7A35T** - paused side experiment (Ronny owns it). Same die as
   the Basys3 + 32 MB SDRAM (2 MB main-memory target). Stages 1-2 written and
   sim-verified, nothing run on hardware yet.
4. **MiSTer** - future "full machine" target (disk images served from the
   board's Linux side); starts once FF-mode boot works.
5. **Cmod A7-35T** - research only, no purchase planned: 1039 NOK for less
   functionality than the sub-300-NOK Tang Nano 20K. The folder keeps the
   collected docs and the SRAM-backend sketch.

Per-board detail lives **with the board** (README, vendor docs, plans and
handoffs in each `<board>/` folder) - this file is only the directory. For
the QMTECH resume instructions specifically, see
[`qmtech-a35t/HANDOFF-qmtech-a35t-bringup.md`](qmtech-a35t/HANDOFF-qmtech-a35t-bringup.md).

## Building - one API for every board

Every board folder has a `Makefile` with the **same targets**, whatever the
toolchain underneath. From WSL (the Windows-hosted tools are reached via
`powershell.exe` - works because the repo lives on a Windows drive):

| Target | Meaning |
|--------|---------|
| `make` | Build the bitstream (no board needed) |
| `make load` | Program the FPGA - **volatile** (JTAG/SRAM; gone at power-cycle) |
| `make flash` | Program **persistent** config flash (survives power-cycle) |
| `make sim` | Run the board folder's iverilog testbenches (where present) |
| `make clean` | Remove build outputs (where present) |

Board-specific extras: `basys3` adds `make reuse` (skip the ~1h resynth,
reuse the `synth_1` checkpoint) and `make lint`; `qmtech-a35t` takes
`TEST=led-test|mem-test` (default `mem-test`) and has no `flash` flow yet;
`mister` is a placeholder until the Quartus project exists; `cmod-a7-35t`
is research-only (no Makefile). The standalone
`tang-nano-20k/sdram-test/` keeps its own Makefile with the same
`all`/`load`/`flash`/`sim`/`clean` targets (Linux-native OSS flow).

**On the Windows host** the underlying scripts are the direct entry points
(the Makefiles just delegate to them):

```powershell
cd E:\Dev\Repos\Ronny\nd-120\Verilog\fpga\basys3
.\vivado_build.ps1              # bitstream ('make'); -ReuseSynth / -LintOnly / -Program
.\flash.ps1 -Quick              # 'make load' (JTAG only); omit -Quick for 'make flash'

cd ..\tang-nano-20k
.\gowin_build.ps1               # bitstream ('make'); copies WCS preload + checks EX3988

cd ..\qmtech-a35t\mem-test      # or led-test
vivado -mode batch -source build.tcl -tclargs skip_program   # 'make'
vivado -mode batch -source build.tcl                         # 'make load'
```

Programming transport per board: Basys3 and Cmod A7 = onboard USB-JTAG;
Tang Nano 20K = `openFPGALoader` from WSL (usbipd-attached) or the Gowin
programmer GUI; QMTECH = Xilinx Platform Cable USB II on the JTAG header.

## Shared context (applies to all boards)

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

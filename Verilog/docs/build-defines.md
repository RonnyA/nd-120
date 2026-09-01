# ND-120 Verilog build options - the one reference

**Full path:** `Verilog/docs/build-defines.md`
**Last updated:** 2026-08-30 (was a 04-JUL unification plan; that plan is kept
at the bottom, with its stale parts marked)

Every knob that changes what gets built or how the built machine behaves,
grouped by the LAYER where you meet it:

1. [Verilog `define` symbols](#1-verilog-define-symbols) - the ground truth the other layers set
2. [Verilator sim make variables](#2-verilator-sim-make-variables) (`sim/`, `runSim/`)
3. [Nexys 4 DDR build.tcl arguments](#3-nexys-4-ddr-buildtcl-arguments) (incl. the clock table)
4. [Tang Nano 20K switches](#4-tang-nano-20k-switches) (gowin_build.ps1, OSS Makefile, tang20k_defines.v)
5. [Basys3 vivado_build.tcl arguments](#5-basys3-vivado_buildtcl-arguments)
6. [MiSTer](#6-mister)
7. [Debug and trace build defines](#7-debug-and-trace-build-defines) (pointers, not copies)
8. [Runtime environment variables](#8-runtime-environment-variables-runsim-harness) - runSim probes; runtime, NOT build options

Every `define` here is normally set by a build flow (layer 2-6), never by
editing RTL. The one exception is `fpga/tang-nano-20k/src/tang20k_defines.v`,
which IS a build file - the Tang's per-board configuration lives there as
hand-edited defines.

---

## 1. Verilog `define` symbols

### Target and mode selection

| Define | What it does | Who sets it | Default per target |
|---|---|---|---|
| `VERILATOR_SIM` | Master sim switch: exposes the external memory-bus ports for the C++ harness, fast UART, large sim RAM (`MEM_RAM_49.v`) | `sim/Makefile:11`, `runSim/Makefile:16` (always) | Sim: ON. Every FPGA: OFF (must never be set there) |
| `FPGA_FF_MODE` | Edge-triggered flip-flops instead of the original transparent latches. Required on every FPGA | Makefiles when `USE_LATCHES=0`; `fpga/nexys4ddr/build.tcl:299`; `fpga/tang-nano-20k/src/tang20k_defines.v:20`; `fpga/basys3/vivado_build.tcl:214`; `fpga/mister/nd120.qsf:102` | `sim/`: OFF (latch mode). `runSim/`: ON. Every FPGA: ON |
| `USE_TRANSPARENT_LATCHES` | Derived, never set directly: `VERILATOR_SIM && !FPGA_FF_MODE` (`ND120_TOP.v:23-27`). Guards the latch branches in the PALs, `AM29841.v`, `CPU_CS_ACAL_17.v` | derived | follows the two above |
| `TARGET_NEXYS4DDR` / `TARGET_TANG20K` / `TARGET_BASYS3` / `TARGET_CMOD_A7` / `TARGET_XILINX7` | Board/vendor markers for the few places RTL must know the board (clock wiring in `ND120_TOP.v`, board tops) | each board's build flow | one per board build; none in sim |
| `GOWIN` | Gowin BRAM/PROM primitives instead of Xilinx inference (`CPU_CS_PROM_19.v`) | `fpga/tang-nano-20k/src/tang20k_defines.v:14` | Tang: ON. Everything else: OFF |

### Memory backend (exactly one per FPGA build - `MEM_43.v` errors if none is selected)

| Define | What it does | Who sets it |
|---|---|---|
| `MAIN_RAM_DDR2` | DDR2 main memory with a BRAM cache in front (`fpga/nexys4ddr/ddr2/MEM_RAM_49_DDR2.v`). Full 4 MB per bank | Nexys default (`build.tcl:296`) |
| `MAIN_RAM_BLOCKRAM` | Block-RAM backend (`MEM_RAM_49_BLOCKRAM.v`). With `ND120_BLOCKRAM_ADDR_BITS=16` it holds 64K words per bank and everything above word 0o200000 in a bank ALIASES onto low memory - SINTRAN cannot run on that | Basys3 (`vivado_build.tcl:239`); Nexys `-tclargs bramram` (`build.tcl:294`) |
| `MAIN_RAM_SDRAM` | The Tang's embedded 8 MB SDRAM through `MEM_RAM_49_SDRAM` (2 banks, 4 MB; upper half reserved for the disk-image cache) | `tang20k_defines.v:27` |
| `ND_SDRAM_PACK16` | Packed memory: 16 data bits only, two ND words per 32-bit SDRAM location, parity recomputed on read. See `docs/nd120-parity-analysis.md` | `tang20k_defines.v:35`; `runSim/Makefile` `PACK16=1` (default) |
| `ND_STORAGE_PORT` | nd_storage device port on the SDRAM backend (own `stor_clk` domain, upper-half storage region only) | `tang20k_defines.v` |
| `ND120_SIM_RAM_64K` | Sim-only: shrink the sim RAM to 64K words per bank (`MEM_RAM_49.v:22`) to reproduce the BRAM-aliasing class of bug in Verilator | `EXTRA_VDEFINES="-DND120_SIM_RAM_64K"` (runSim) |

### Microcode load

| Define | What it does | Who sets it | Default per target |
|---|---|---|---|
| `SKIP_WCS_LOAD` | Preload the WCS from the 33 `wcs_*.hex` nibble images and skip the original machine's runtime PROM->WCS load. The microcode PROM (`CPU_CS_PROM_19`) is then never read and its ROM arrays are compiled out (~7850 LUTs). Details: `docs/skip-wcs-load.md` | `SKIP_WCS=1` (both sim Makefiles); `build.tcl:313` (Nexys, unless `-promload`); `tang20k_defines.v:24`; `vivado_build.tcl:225` (Basys3) | Sims: OFF (the runtime load is part of what they verify). Nexys/Tang/Basys3: ON |

### CPU cache

The RTL knob is `ND120_NO_CACHE` (`CPU-BOARD-3202/circuit/CPU_MMU_CACHE_25.v`):
it compiles out the five cache memories and the used-bit PAL, forces the
cache-off switch position, and makes the machine report the cache as disabled.
`ND120_FORCE_CACHE` is Tang-only plumbing that suppresses the Tang's default
`ND120_NO_CACHE`. One switch per flow (all landed 30-AUG-2026):

| Flow | Switch | Default | Mechanism |
|---|---|---|---|
| Verilator `sim/` | `make ... CACHE=0` | cache IN (`sim/Makefile:21`) | adds `-DND120_NO_CACHE` |
| Verilator `runSim/` | `make ... CACHE=0` | cache IN (`runSim/Makefile:25`) | adds `-DND120_NO_CACHE` |
| Nexys `build.tcl` | `-tclargs nocache` (`cache` = the default) | cache IN (`build.tcl:334`); runtime: slide switch sw[4] is the console's cache switch | adds `ND120_NO_CACHE` |
| Tang Gowin `gowin_build.ps1` | `-Cache` | cache OUT | emits `` `define ND120_FORCE_CACHE `` into `build\tang20k_variant.v` |
| Tang OSS `make` | `CACHE=1` | cache OUT (`fpga/tang-nano-20k/Makefile:64`) | `-DND120_FORCE_CACHE` to yosys |

The Tang default-off authority is `tang20k_defines.v`: `` `ifndef
ND120_FORCE_CACHE `` -> `` `define ND120_NO_CACHE ``. The Tang switch exists for
symmetry, but a live cache needs 28330 logic cells against the GW2AR-18's
20736 (measured 25-AUG-2026) - expect overflow until that gap is closed.
Status and open faults: `docs/CACHE-STATUS.md`.

### Panel clock

| Define | What it does | Who sets it | Default per target |
|---|---|---|---|
| `ND120_PANEL_CLOCK` | Emulate the MC68705/MM58274 hardware clock (`IO_PANCAL_40.v` -> `PANCAL_68705_CLOCK.v`) so SINTRAN can set/read the time via `TRR PANC` / `TRA PANS`. Without it the panel is a stub and SINTRAN prints "ND-100 PANEL CLOCK INCORRECT" at every boot. Details: `docs/panel-clock-68705.md` | `PANEL_CLOCK=1` (both sim Makefiles); Nexys `build.tcl:351`; Tang `gowin_build.ps1:228` | Sims: OFF (keeps the golden traces unchanged). Nexys/Tang: ON; disable with `nopanelclock` (Nexys tclarg) / `-NoPanelClock` (Tang) |

### Clock and console

| Define | What it does | Who sets it | Default |
|---|---|---|---|
| `BOARD_CLK_FREQ` | The CPU/bus clock in Hz. Every derived count (UART baud divisor, RTC tick, watchdogs) comes from it - it MUST match the real clock or the console garbles | `Shared/support/SC2661_UART.v:140` fallback; Nexys clk table; Basys3 `=16666667`; runSim `EXTRA_VDEFINES` | fallback 100000000 |
| `UART_BAUD_RATE` | Console wire speed. The emulated SC2661 times bits off `DELAY_FRAMES = BOARD_CLK_FREQ / UART_BAUD_RATE` (`SC2661_UART.v:157`), regardless of the 9600-max thumbwheel the microcode believes - so the machine can THINK 9600 while the wire runs 115200 | `SC2661_UART.v:143` fallback; Nexys `baud` arg; Basys3 `=9600` | 115200 (Basys3: 9600) |
| `ND120_N4DDR_MMCM_DIV` | Nexys MMCM divider off the 1000 MHz VCO; the CPU period in ns equals the divider. Set together with `BOARD_CLK_FREQ` by the clk table, never alone | `build.tcl` clk table; fallback `nd120_nexys4ddr_top.v:128` | 60.0 (16.667 MHz) |
| `ND120_CONSOLE_VGA` / `ND120_CONSOLE_BAUD` | The Nexys VGA console + USB keyboard next to the serial console (serial keeps working in parallel) | `build.tcl:359-360` | Nexys: ON (`novgaconsole` to drop) |
| `ND120_MIPS_TAP` | Builds the CGA-side tap that feeds the panel MIPS counter (`CGA_ALU.v` `XGPRLOAD_DBG` = `ALUCLK_EN & GPRC[0] & ~GPRC[1]`, the instruction-register load). Set automatically with the VGA console, since that panel is the only thing that displays it; without it the net is tied to 0, keeping the extra fanout off `ALUCLK_EN` and `GPRC` on boards with no panel (Tang, Basys3, sims) | Nexys `build.tcl` with `vgaconsole` | ON with the VGA console |
| `ND120_TERMINAL_VT100` | Selects which of the two SEPARATE, compile-time-only terminal modules the VGA console builds: VT100 (SINTRAN type 6) if defined, TDV2200/type 93 if not. `terminal_ctrl.v`/`ps2_ascii_table.v`/`key_vt100.v` vs `terminal_ctrl_tdv.v`/`ps2_ascii_table_tdv.v`/`key_tdv2200.v` - never both elaborated in the same build (`ifdef` in `terminal_top.v` and `nd120_nexys4ddr_top.v`). PED/LED are built for the Tandberg keyboard's own key set, not VT100 CSI input (`Terminals/docs/SPEC-tdv2200.md`) | Nexys `-VT100Terminal` (only matters with the VGA console on) | TDV2200 (undefined) |
| `TANG_VARIANT_CRAWL` / `_MID` / `_FULL` / `_FAST20` | Tang clock variants, consumed by `tang20k_defines.v`. No variant define = slow (6.75 MHz) | generated `build\tang20k_variant.v` (ps1) or `-DTANG_VARIANT_*` (OSS Makefile) | slow |

### Sim device stack

| Define | What it does | Who sets it |
|---|---|---|
| `ND120_VERILOG_DEVICES` | The real Verilog device stack in the sim: `ND_BUS_SLAVE` + `ND_TAPE_400` inside `ND120_TOP`, fed by the SD-FAT RTL - the same RTL that runs on Tang. Also passed to the C++ harness | `runSim/Makefile` `VERILOG_TAPE=1` (default) |
| `ND120_SD_STORAGE` / `ND120_SD_CARD_IMG` | Feed the tape device from the real SD-FAT stack reading a simulated card image (implies Verilator `--timing`) | `runSim/Makefile` `SD_STORAGE=1` (default) |

### Behavior escape hatches (default OFF - defined by no build; set via `EXTRA_VDEFINES` only to reproduce old behavior)

| Define | What it restores | Where |
|---|---|---|
| `ND120_INTR_STATUS_FENCE_OFF` | The historical dead Am2914 status fence (pre-fix READ VECTOR behavior). The fence being ON is the validated RTL default | `DELILAH-CPU/CGA_INTR/circuit/CGA_INTR_CNTLR_VECGEN_STAT.v:176`, `..._SBIT.v:118` |
| `ND120_MOR_TIED_OFF` | The old tied-off Memory Out of Range input (no level-12 MOR interrupts). `MORN` wired is the default | `DELILAH-CPU/CGA_INTR/circuit/CGA_INTR.v:122` |
| `ND120_EPANS_REGISTERED` | The registered variant of the EPANS compensation in the DGA | `DECODE-GateArray/DGA/circuit/DECODE_DGA_IDBS.v:613` |

---

## 2. Verilator sim make variables

Both harnesses build from WSL (`cd Verilog/sim` or `Verilog/runSim`). A
variable on the `make` command line, e.g. `make compile CACHE=0 PANEL_CLOCK=1`.

### `sim/Makefile` (waveform harness, `test_nd120.cpp`)

| Variable | Default | What it does |
|---|---|---|
| `USE_LATCHES` | **1** (latch mode) | 0 adds `FPGA_FF_MODE`. This harness defaults to the original-hardware latch behavior; `make compare` diffs the two modes |
| `CACHE` | 1 | 0 compiles the CPU cache out (`ND120_NO_CACHE`) |
| `PANEL_CLOCK` | 0 | 1 adds `ND120_PANEL_CLOCK` |
| `SKIP_WCS` | 0 | 1 adds `SKIP_WCS_LOAD` (needs the `wcs_*.hex` files here) |
| `ND120_LOG_CAP` | 1G | Hard ceiling on any `make run-log` output file |

### `runSim/Makefile` (full boot + self-test + OPCOM, `Run120.cpp`)

| Variable | Default | What it does |
|---|---|---|
| `USE_LATCHES` | **0** (FF mode) | 1 is a one-off debug escape hatch only. NOTE: the opposite default from `sim/` |
| `CACHE` | 1 | 0 compiles the CPU cache out |
| `PANEL_CLOCK` | 0 | 1 adds `ND120_PANEL_CLOCK` |
| `PACK16` | 1 | Packed-memory contract (`ND_SDRAM_PACK16`, matches the Tang). 0 = classic stored-parity DRAM model |
| `SKIP_WCS` | 0 | 1 adds `SKIP_WCS_LOAD` |
| `VERILOG_TAPE` | 1 | The real Verilog device stack (`ND120_VERILOG_DEVICES`). 0 = legacy C papertape model, only via `make run-c`, screams a banner |
| `SD_STORAGE` | 1 | Tape fed from the real SD-FAT RTL + card image (implies `TIMING=1`). 0 = C tape file server |
| `SD_CARD_IMG` | `../SD-FAT/sim/nd_boot_card.img` | The card image (build artefact; `make card` builds it) |
| `TIMING` | 0 (forced 1 by SD_STORAGE) | Verilator `--timing` - changes the scheduler for the whole build |
| `DEVICECORE` (+ `DEVICECORE_FLOPPY` / `_DEMODMA` / `_BUSMASTER` / `_TAPE`, `NDDEVICECORE_DIR`) | 0 | Compile in the portable-C NDDeviceCore device models (the NDModulE seam) |
| `EXTRA_VDEFINES` | empty | Extra Verilog defines, e.g. `-DRTC_REAL_PERIOD -DBOARD_CLK_FREQ=16666667`, `-DND120_SIM_RAM_64K`, the escape hatches above |
| `EXTRA_CFLAGS` | empty | Extra C++ defines for the harness, e.g. `-DND120_COUNT_STERR` (execution-phase STERR counter, `Run120.cpp:693`), `-DND120_TRACE_VERIFY` (golden-trace emitter, `Run120.cpp:2100`) |
| `FLOPPY_IMG`, `RTC_BPUN` | see Makefile | Test images for specific targets |

---

## 3. Nexys 4 DDR build.tcl arguments

`vivado -mode batch -source build.tcl -tclargs <args...>` from
`fpga/nexys4ddr/`. Flags match with or without a leading dash, case-blind
(`build.tcl:103` `has_flag`), because cmd.exe splits `clk=10` into two words -
both `clk=10` and `clk 10` are accepted.

| Argument | Default | What it does |
|---|---|---|
| `clk=<MHz>` | 16 | CPU clock. Sets `ND120_N4DDR_MMCM_DIV` AND `BOARD_CLK_FREQ` together from the table below |
| `baud=<9600\|115200>` | 115200 | Console speed (`UART_BAUD_RATE`, and `ND120_CONSOLE_BAUD` for the VGA console) |
| `-noburn` | burn | Build only, no JTAG program |
| `-promload` | WCS preload | Runtime PROM->WCS load instead of `SKIP_WCS_LOAD` |
| `bramram` | DDR2 | Old BRAM-only backend (`MAIN_RAM_BLOCKRAM` + `ND120_BLOCKRAM_ADDR_BITS=16`) - ALIASING, forbids SINTRAN; A/B experiments only |
| `nocache` / `cache` | cache IN | `nocache` compiles the cache out (`ND120_NO_CACHE`). Runtime: sw[4] on the board |
| `nopanelclock` | panel clock ON | Falls back to the panel stub |
| `novgaconsole` / `vgaconsole` | VGA console ON | Drops the VGA console + keyboard (serial stays either way) |
| `-VT100Terminal` | TDV2200 | Builds the VT100 (type 6) terminal module instead of the default TDV2200 (type 93) - see `ND120_TERMINAL_VT100` above |
| `ila` / `ilaslim` / `ilacache` | off | JTAG ILA probe sets; all three add `ND120_ILA_MARK_DEBUG` so the probed nets survive synthesis |
| `errfaprobe` | off | `ND120_ERRFA_PROBE`: latch the SINTRAN ERRFATAL register saves (0o4347-0o4353) and repeat them on the console TX after the halt. Zero BRAM |
| `physopt` | off | Post-place physical optimization (26-AUG clock-up work) |
| `timingexplore` | off | `opt_design -directive ExploreWithRemap`, `place_design -directive ExtraTimingOpt`, `route_design -directive AggressiveExplore`. Measured 31-AUG on clk=45 with cache: WNS -6.780 -> -6.440, i.e. 0.34 ns of the 6.4 ns needed. Routing effort is not the lever |

Clock table (`build.tcl:70`): `clk=` 8, 10, 12, 16, 20, 25, 27, 33, 35, 38,
40, 42, 45, 50, 100. The deployed proven speed is 45 (45.45 MHz); the build
gate refuses to write a bitstream with negative slack. The deployed
configuration rule (cache + VGA, matching the newest `build-*.log`) is in the
project memory note `project_nexys_deployed_config`.

---

## 4. Tang Nano 20K switches

Two flows, one source of truth: both put their pre-defines ahead of
`src/tang20k_defines.v` in the one ordered compilation unit. Primary flow is
the OSS suite (`make` in `fpga/tang-nano-20k/`); Gowin EDA is the backup
(`docs/tang20k-build-flows.md`).

### `gowin_build.ps1` (Windows PowerShell, Gowin EDA)

| Switch | Default | What it does |
|---|---|---|
| `-Variant slow\|crawl\|mid\|full\|fast20` | slow (6.75 MHz) | Clocking: crawl 3.375, mid 13.5, fast20 20.25 (**timing-clean, TNS 0 all clocks, Fmax 22.932 MHz = 13.2% margin after the 31-AUG sdc fixes** - the fastest signed-off clock), full 27 MHz (**13 failing endpoints, worst -0.839 ns** - the old "1667 violations" figure predates the sdc work and was mostly an unconstrained crossing; still NOT clean, do not trust unattended). Intermediate clocks are NOT usable - only simple ratios of the 27 MHz crystal can be signed off, see `fpga/tang-nano-20k/README.md` |
| `-Cache` | cache OUT | `ND120_FORCE_CACHE` - see the cache section above; does not currently fit this part |
| `-NoPanelClock` | panel clock ON | Falls back to the panel stub |
| `-DiscsUncached` | cached | `ND_STORAGE_DISCS_UNCACHED`: every disc client direct, no storage-cache reuse |
| `-NoStorageCache` | cache synthesized | `ND_STORAGE_NO_CACHE`: storage-cache directory not built at all (forces `-DiscsUncached` behavior) |
| `-Gao` | off | Gowin Analyzer Oscilloscope core |
| `-PfCapture` / `-PcHistory` / `-JplCapture` / `-PtwrCapture` / `-PfPath` / `-PtOrder` / `-PfLog` / `-PgWrite` / `-StageTimer` | off | Capture-ring diagnostics (`TANG_*` defines). MUTUALLY EXCLUSIVE - one 16-bit debug port, one ring; the script refuses combinations. Each prints its decode script; see also `DEBUG-OPTIONS.md` in that dir |

### OSS `Makefile` (yosys/nextpnr, WSL)

| Variable / target | Default | What it does |
|---|---|---|
| `VARIANT=slow\|crawl\|full` | slow | Clock variant via `-DTANG_VARIANT_*`. NOTE: does NOT accept `mid`/`fast20` (the ps1 does) - see the stale list at the bottom |
| `CACHE=1` | 0 (cache OUT) | `-DND120_FORCE_CACHE` |
| `make check` | - | Netlist gates: `IO_sdram_dq` tristate + latch census |
| `make load` / `flash` | - | Program SRAM / config flash |
| `make gowin` | - | Delegates to `gowin_build.ps1` |

### Hand-edited defines in `src/tang20k_defines.v`

Board configuration that has no command-line switch yet - the file is the
authority and every define carries its own long comment:

- Device set: `TANG_FLOPPY` (ON), `TANG_WD` (ON), `TANG_SMD` (OFF - mutually
  exclusive with `TANG_WD` by BSRAM budget, guarded at elaboration).
- Always-on board facts: `GOWIN`, `TARGET_TANG20K`, `FPGA_FF_MODE`,
  `SKIP_WCS_LOAD`, `MAIN_RAM_SDRAM`, `ND_SDRAM_PACK16`, `ND_STORAGE_PORT`,
  and the `ifndef ND120_FORCE_CACHE -> ND120_NO_CACHE` cache default.
- A long tail of commented-out capture defines (`TANG_WD_TRACE_DUMP`,
  `ND_WD_TRACE_*`) - read the comments there before enabling any; several
  take over the console permanently once they fire.

---

## 5. Basys3 vivado_build.tcl arguments

`fpga/basys3/` drives the out-of-repo Vivado project
`F:/Xilinx/ND120/ND3202D`. This board synthesizes but does not meet timing
and does not boot.

| Argument | What it does |
|---|---|
| `full_synth` | REQUIRED for a real ~1h re-synthesis; without it the existing `synth_1` checkpoint is reused |
| `skip_program` | No Hardware Manager / JTAG / SPI flash |
| `no_reset_synth` | With `full_synth`: keep the previous run instead of `reset_run synth_1` |
| `backup_bit` | With `full_synth`: save the previous bitstream as `ND120_TOP.before_synth.bit` |

Fixed defines the script enforces (`vivado_build.tcl:213-256`):
`FPGA_FF_MODE`, `SKIP_WCS_LOAD`, `MAIN_RAM_BLOCKRAM`,
`BOARD_CLK_FREQ=16666667`, `UART_BAUD_RATE=9600` (console COM3 9600 7E1 -
this board stays at the thumbwheel-true 9600).

---

## 6. MiSTer

`fpga/mister/` (Quartus, `nd120.qpf`/`nd120.qsf`) is the early Cyclone V
port. ND-side defines in the .qsf so far: `FPGA_FF_MODE=1` only
(`nd120.qsf:102`, with the explicit warning that `VERILATOR_SIM` must never
be set there). The commented `MISTER_*` macros above it are the standard
MiSTer framework options, not ND-120 options. No `MAIN_RAM_*` backend is
selected in the .qsf yet.

**Storage (01-SEP-2026):** no `SD_STORAGE`, no SD card, no FAT. The images
are files mounted from the OSD; `nd120.sv` instantiates `hps_io` with
`VDNUM=5, BLKSZ=2, WIDE=1` and `rtl/nd_storage_mister_devices.v` serves the
core's FDISK/WDISK/TAPE seams from them through `rtl/nd_storage_hps.v`
(hps_io's block interface, one 2048-byte storage block = one 4-block HPS
transaction). Slot map = OSD `S<n>` line = hps_io index: 0 floppy drive 0,
1 floppy drive 1, 2 Winchester unit 0, 3 Winchester unit 1, 4 paper tape
(`.BPU`/`.TAP`, the HPS matches 3-character extension groups). One
parameter matters: `BYTE_SWAP` on `nd_storage_hps` (default 1: HPS words
little-endian, ND image words big-endian) - it is a reading of the
framework, to be confirmed by the Phase-4 board test in
`docs/PLAN-mister-storage.md`. Gates: `fpga/mister/sim` `test-storage-hps`,
`test-storage-devices`. The `INCLUDE_*` parameters of `ND120_CORE` in
`nd120.sv` are TAPE/FLOPPY/WD = 1, SMD = 0.

---

## 7. Debug and trace build defines

These change observability, not the machine. They are documented where they
live - this section only says where that is:

- **Tang capture rings and probes** (`TANG_PF_CAPTURE`, `TANG_PC_HISTORY`,
  `TANG_JPL_CAPTURE`, `TANG_WD_TRACE_DUMP`, `ND_WD_TRACE_*`, ...):
  `fpga/tang-nano-20k/DEBUG-OPTIONS.md`, `fpga/tang-nano-20k/TRACE-CAPTURE-GUIDE.md`,
  and the comments in `src/tang20k_defines.v` / `gowin_build.ps1`.
- **Nexys ILA / probes** (`ND120_ILA_MARK_DEBUG`, `ND120_ERRFA_PROBE`):
  `fpga/nexys4ddr/build.tcl` comments and `docs/ILA-PROBE-SEMANTICS.md`.
- **RTL trace defines** sprinkled through the sources (`ND120_SMD_TRACE`,
  `ND120_WD_TRACE`, `ND120_PARFLAG_TRACE`, `ND120_PANEL_CLOCK_TRACE`,
  `ND120_MEMTRACE`, `ND120_DMA_STALL_DBG`, ...): grep for the symbol; each is
  commented at its `ifdef`. Enable via `EXTRA_VDEFINES` in `runSim/`.
- **C++ harness probes** (`ND120_COUNT_STERR`, `ND120_TRACE_VERIFY`): compile
  into `Run120.cpp` via `EXTRA_CFLAGS` (section 2).

---

## 8. Runtime environment variables (runSim harness)

These are NOT build options: `Run120.cpp` reads them with `getenv()` when the
already-built sim starts, so no recompile is needed. Grep `runSim/Run120.cpp`
for the name to see each one's exact behavior. Grouped:

- **Golden-trace verify:** `ND120_TVERIFY_OUT`, `ND120_TVERIFY_SYMS`,
  `ND120_TVERIFY_MAX`, `ND120_TVERIFY_NOEXIT`, `ND120_TVERIFY_ARM_ADDR`
  (with the `ND120_TRACE_VERIFY` compile-time probe).
- **Cache probes:** `ND120_CACHE_TRACE`, `ND120_CACHE_PPN`,
  `ND120_CACHE_PPN_DT`, `ND120_CACHE_WIN`, `ND120_CWIN_AT`,
  `ND120_CWIN_PPN`, `ND120_CWIN_WRITE`, `ND120_INHIBIT_TRACE`.
- **Traces:** `ND120_LIVE_TRACE`, `ND120_START_TRACE`, `ND120_INSTR_TRACE`
  (env-gated), `ND120_DMA_TRACE`, `ND120_WCS_TRACE`, `ND120_WCS_RD`,
  `ND120_WCLIM_TRACE`, `ND120_CSA_WATCH`, `ND120_STSCHG_MIN`,
  `ND120_CYC_WINDOW`.
- **Input / load pacing:** `ND120_SEND_GAP`, `ND120_STDIN_GAP`,
  `ND120_STDIN_DEBUG`, `ND120_SCRIPT_GAP`, `ND120_SCRIPT_BUDGET`,
  `ND120_SCRIPT_DEBUG`, `ND120_AMP_SETTLE`, `ND120_BINLOAD_FILE`,
  `ND120_BINLOAD_GAP`, `ND120_BINLOAD_SETTLE`, `ND120_BINLOAD_CHECK`.
- **Images / preload:** `ND120_FLOPPY_IMG`, `ND120_FLOPPYCORE_IMG`,
  `ND120_PRELOAD_BPUN`.
- **Run limits:** `ND120_MAX_TICKS`, `ND120_MAX_CNT`.
- **DMA test rig:** `ND120_DMA_TEST`, `ND120_DMA_GAP`, `ND120_DMA_XCHECK`.

---

## Appendix: the 04-JUL-2026 unification plan (historical)

The original version of this file was a plan to collapse sim-vs-FPGA `ifdef`s
to one code path. Status of its points as of 30-AUG-2026:

- **Retire `USE_TRANSPARENT_LATCHES` / `FPGA_FF_MODE` / `USE_LATCHES`** - NOT
  done, and the split is now load-bearing the other way around: FF mode is
  the shipped path everywhere (runSim default, every FPGA), while `sim/`
  keeps latch mode as the original-hardware reference and `make compare`
  (latch-vs-FF golden trace diff) is a standing `make test-full` gate. The
  plan's "delete the latch branches" step is superseded by keeping both as a
  proof tool.
- **Delete `_OLD_WAY_` dead code** (`CGA_MAC_APOS_INC.v`, `CGA_MIC_IINC.v`) -
  still present, still dead (the symbol is defined nowhere).
- **`BOARD_CLK_FREQ` / `UART_BAUD_RATE` as parameters with defaults** -
  confirmed as the right pattern and now used by every flow (section 1).
- **`VERILATOR_SIM` narrowed to bus ports + RAM** - not narrowed; its three
  roles (harness bus ports, sim RAM size, fast UART) all remain under the one
  symbol.
- The plan's use counts (e.g. "`FPGA_FF_MODE`: 1 use") are long stale - the
  symbol appears at ~69 RTL sites today.

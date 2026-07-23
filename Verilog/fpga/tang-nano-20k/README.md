# Tang Nano 20K (Gowin GW2AR-18) FPGA target

**Full path:** `/mnt/e/Dev/Repos/Ronny/nd-120/Verilog/fpga/tang-nano-20k/`

Gowin build/flow for the Sipeed **Tang Nano 20K**. This is the **primary FPGA
target** going forward - chosen for faster synthesis than Vivado, a Linux-native
open-source toolchain option, and 8 MB of SDRAM that lets the FPGA run the full
memory config like the simulator. Full analysis and staged plan:
`../../docs/tang-nano-20k-port.md`.

## Board / device

**Hardware reference:** [Sipeed wiki - Tang Nano 20K](https://wiki.sipeed.com/hardware/en/tang/tang-nano-20k/nano-20k.html)
(datasheets/schematics: [dl.sipeed.com](https://dl.sipeed.com/shareURL/TANG/Nano_20K/),
official examples: [sipeed/TangNano-20K-example](https://github.com/sipeed/TangNano-20K-example),
local clone: `/home/ronny/repos/TangNano-20K-example`).

| Item | Value |
|------|-------|
| Board | Sipeed Tang Nano 20K (22.55 mm x 54.04 mm) |
| FPGA | Gowin **`GW2AR-LV18QN88C8/I7`** (GW2AR-18, QN88) |
| Logic | 20,736 LUT4, 15,552 FF, 48 18x18 multipliers, 8 I/O banks |
| Block RAM (BSRAM) | **828 Kbit** (46 blocks) + 41,472 bit shadow SRAM |
| Big RAM | **8 MB SDRAM** (64 Mbit, 32-bit SDR, embedded in the GW2AR package; no package pins - see sdram-test/) |
| Config flash | 64 Mbit |
| Clock | 27 MHz crystal + MS5351 clock chip (3 extra clocks, BL616-controlled), 2 PLLs (use a Gowin `rPLL` for the CPU clock) |
| Programmer | BL616 onboard USB (JTAG + USB-UART + USB-SPI + MS5351 control); openFPGALoader-compatible; enumerates as one USB serial port (COM5 on Ronny's machine) |
| Peripherals | HDMI, 40-pin RGB LCD connector, TF-card slot, MAX98357A audio amp |
| UI | 6 LEDs (active low, pins 15-20), 1 WS2812 RGB LED, 2 buttons (S1 = pin 88, S2 = pin 87) |

**Factory firmware:** the flash ships with a **LiteX SoC** (VexRiscv_Min @ 48 MHz,
from the `litex/` folder of the TangNano-20K-example repo; prebuilt
`litex/tang_nano_20k_litex.fs`). Its BIOS talks at **115200** baud and has
`mem_test` / `mem_speed` / `sdram_test` commands - an independent check that the
SDRAM hardware works. Its boot report confirms the SDRAM at **48 MHz CL-2** with a
clean 2 MB memtest, mapped at `0x40000000` (8 MB). Loading a bitstream into SRAM
(openFPGALoader without `-f`) leaves it intact; flashing replaces it (restore with
`openFPGALoader -b tangnano20k -f .../litex/tang_nano_20k_litex.fs`).

### vs Basys3
Fewer LUTs (20,736 LUT4 vs 33,280 LUT6) and less BSRAM (828 vs ~1,800 Kbit), but
adds 8 MB SDRAM and a much faster, Linux-friendly toolchain. **Fit is the top
risk** (see [Memory architecture](#memory-architecture)).

## Toolchain (two options)

### Option 1 - Gowin EDA (authoritative)
`gw_sh` (Tcl, scriptable) or the GUI, using the existing `../../ND-120-Gowin/`
project. Uses a Synplify-based synth that tolerates the design's TTL-style
flip-flops (clock + async preset + async clear). Has **GAO** (Gowin Analyzer
Oscilloscope), the on-chip logic analyzer = Vivado ILA equivalent. This is the
reliable path to a real bitstream today.

### Option 2 - OSS flow (Linux-native, WSL)
`yosys synth_gowin` -> `nextpnr-himbaechel --device GW2AR-LV18QN88C8/I7` ->
`gowin_pack` -> `openFPGALoader`. Runs entirely on WSL/Linux (no Windows context
switch).

**Install (oss-cad-suite - the whole chain in one prebuilt bundle, no sudo):**
```bash
cd ~
# resolve the latest linux-x64 tarball via the GitHub API, then extract
URL=$(curl -s https://api.github.com/repos/YosysHQ/oss-cad-suite-build/releases/latest \
  | grep -oE '"browser_download_url":[^,]*linux-x64[^"]*\.tgz' | grep -oE 'https://[^"]*')
curl -L -o oss-cad-suite.tgz "$URL"
tar xzf oss-cad-suite.tgz            # -> ~/oss-cad-suite/

# activate in each shell that uses the tools:
source ~/oss-cad-suite/environment
yosys --version                       # expect 0.4x+ (not the distro's 0.9)
which nextpnr-himbaechel gowin_pack openFPGALoader
```
(Lighter alternative for a yosys-only fit check: `pip install yowasp-yosys`.)

**Known caveat (as of 2026-07):** `yosys synth_gowin` (even 0.66) rejects several
TTL flip-flop primitives with **multiple edge-sensitive events** (clock + async
preset + async clear in one `always`), e.g. `Shared/logisim/D_FLIPFLOP.v`,
`T_FLIPFLOP.v`, `J_K_FLIPFLOP.v`, `DECODE-GateArray/DGA/circuit/F617.v`, `F714.v`,
`Shared/support/TTL_74373.v`, `FIFO_8BIT.v`, `CGA_MIC_MASEL_REPEAT.v`. Error:
`Multiple edge sensitive events found for this signal`. Gowin EDA (Option 1)
handles these as-is. For the OSS flow these modules need synchronous rewrites
(the same latch/derived-clock -> single-`sysclk` refactor that fixes FPGA timing
overall - see `../../docs/fpga-debug-methodology.md`), or synth-friendly stubs for
a rough fit estimate. Also note: `ND120_TOP.v` instantiates the Xilinx
`MMCME2_BASE`/`BUFGMUX_CTRL` clock primitives (FPGA branch) - for Gowin these must
be replaced by a `rPLL` clock module; a fit run stubs them as passthroughs.

**OSS flow + embedded SDRAM:** nextpnr does **not** auto-connect the on-package
SDRAM the way Gowin EDA does with the magic `O_sdram_*`/`IO_sdram_dq` port names -
they must be pinned explicitly to internal pseudo-pins (`IOL13A` etc.). The pin
list (from [Seyviour/sdram-tang-nano-20k-os-example](https://github.com/Seyviour/sdram-tang-nano-20k-os-example))
is vendored at `sdram-test/src/sdram_pins_oss.cst` and must be kept **out** of
the Gowin EDA constraints.

Prior `../../Verilog.json`/`Verilog_pnr.json` (2024, gitignored) show an OSS run
was attempted before.

## Full ND-120 build (G1 bring-up, added 8-JUL-2026)

The complete ND-120 CPU now has a Tang top-level and Gowin project here:

| File | Purpose |
|------|---------|
| `src/ND120_TANG20K_TOP.v` | Board top: instantiates `ND3202D`, ties off the external bus, S1 = Master Clear, OPCOM UART 9600 on the BL616 (pins 69/70), 6-LED bring-up set (grants, UART RX/TX, parity, heartbeat) |
| `src/tang20k_defines.v` | **Must stay FIRST in the project** - defines `GOWIN`, `TARGET_TANG20K`, `FPGA_FF_MODE`, `SKIP_WCS_LOAD`, `MAIN_RAM_SDRAM`, `BOARD_CLK_FREQ=27_000_000`, `UART_BAUD_RATE=9600` |
| `src/gowin_rpll_27_54.v` | One rPLL: 54 MHz (SDRAM ctrl) + 54 MHz shifted (SDRAM chip) + 27 MHz (CPU/bus/OSC) |
| `src/nd120_tang20k.cst` / `.sdc` | Pins (verified 20K pinout) + 27 MHz input clock |
| `nd120_tang20k.gprj` | Gowin GUI project - 247 files, generated from the Verilator dependency list (single source of truth for the tcl too) |
| `gowin_build.tcl` / `gowin_build.ps1` | Scripted build on the Windows host: `.\gowin_build.ps1` copies the 32 WCS preload hex files (`Code/Microcode/wcs/`), runs `gw_sh` (`C:\Utils\Gowin\Gowin_V1.9.10.02_x64\IDE\bin\gw_sh.exe`) -> `build\impl\pnr\nd120_tang20k_build.fs` |
| `lint/rpll_stub.v` | Lint-only rPLL stub (Verilator elaboration check; not in the Gowin build) |

Build config: microcode is **bitstream-preloaded** (`SKIP_WCS_LOAD`, PROM never
read), main memory is the **8 MB embedded SDRAM** through
[`sdram-bridge/`](sdram-bridge/README.md) (2 banks = 4 MB), CPU/bus at 27 MHz.
The whole file set elaborates cleanly under Verilator lint with all defines
active; the Verilator sim build is unaffected (regression-checked). **The OSS
yosys flow cannot build the full CPU** (TTL flip-flop primitives with multiple
edge-sensitive events) - Gowin EDA only for now.

**First build results (8-JUL-2026):** synthesis + PnR + bitstream all pass.
**Fit is confirmed**: logic 29% (5,851/20,736), registers 11%, **BSRAM 90%**
(the `SKIP_WCS_LOAD` strategy fits the microcode). **Timing at 27 MHz fails as
predicted**: CPU-domain Fmax 9.38 MHz (31 levels), derived-clock domains down
to 4.7 MHz (`s_mclk`) - the same derived-clock architecture problem as Basys3.

**Slow bring-up mode (default):** `TANG_SLOW_BRINGUP` in `src/tang20k_defines.v`
runs CPU/bus at **6.75 MHz** and the SDRAM pair at 13.5 MHz - under every
measured Fmax with margin - so G1 can validate a *booting* CPU while the
clock-enable refactor closes 27 MHz separately. It switches the rPLL and
`BOARD_CLK_FREQ` together, and the SDRAM bridge derives its refresh counts
from `BOARD_CLK_FREQ` automatically. Comment the define out for 27/54 MHz.

First light checklist: heartbeat LED blinking -> OPCOM console at **9600 8N1**
on the board's USB serial -> compare boot behaviour against
[`../../docs/boot-golden-spec.md`](../../docs/boot-golden-spec.md).

## Files here (legacy)

| File | Purpose |
|------|---------|
| `ND120_TOP.cst` | **STALE - Tang Nano 9K pinout** (clock pin 52, LEDs 10-16). Superseded by `src/nd120_tang20k.cst`. Kept only until the 9K is ever targeted; do not use for the 20K. |
| [`sdram-test/`](sdram-test/README.md) | **Standalone SDRAM bring-up test** - nand2mario controller + ND-120 UART (9600 8N1) reporting every read/write. Gowin EDA project + OSS Makefile + iverilog testbench. **PASSES on hardware** (2026-07-08, OSS-flow bitstream, **full 8 MB** write+verify OK). |
| [`sdram18-test/`](sdram18-test/) | **Standalone sdram18.v hardware test** - drives the ND-120 18-bit-word controller with the full build's exact 13.5 MHz slow-bring-up clocking (same PLL module). 4-word demo + full 2M-word write/verify over UART. **PASSES on hardware** (2026-07-09, OSS flow) - exonerates the controller; the deposit bug is full-build cross-domain timing (see `../../docs/HANDOFF-basys3-memory-write.md`). |
| [`sdram-bridge/`](sdram-bridge/README.md) | **ND-120 sheet-49 SDRAM backend** - `MEM_RAM_49_SDRAM.v` maps the measured ND-120 DRAM protocol onto the SDRAM (2x-clock bridge, self-scheduled refresh, 2 banks = 4 MB). Protocol-validated in simulation; awaits the Tang top-level (G1) for full integration. Design doc: [`../../docs/nd120-dram-memory.md`](../../docs/nd120-dram-memory.md). |

**Existing Gowin EDA project:** `../../ND-120-Gowin/` (`ND-120-Gowin.gprj`). Its
source files are referenced by absolute path, so it is independent of this
folder's location. Whether to consolidate it here is an open decision. Gowin
build scripts (a `gw_sh` tcl and/or an OSS `Makefile`) will be added to this
folder as the flow is set up.

## Memory architecture (the key design point)

BSRAM (828 Kbit) is too small to hold **both** the microcode PROM (~512 Kbit) and
the WCS (~512 Kbit), unlike the Basys3. Plan:

| Memory | Where on Tang |
|--------|---------------|
| Microcode | **Bitstream-preload the WCS** via `SKIP_WCS_LOAD` (see `../../docs/skip-wcs-load.md`); drop the separate PROM BRAM (never read once load is skipped). |
| Writable Control Store (WCS) | BSRAM (~512 Kbit) |
| Main memory | **8 MB SDRAM** via the [nand2mario Tang-Nano-20K controller](https://github.com/nand2mario/sdram-tang-nano-20k) - validated standalone in [`sdram-test/`](sdram-test/README.md) first |

`SKIP_WCS_LOAD` is already implemented and verified in Verilator (preloaded WCS
boots byte-identical to the normal load).

**BSRAM is the binding resource on this board** - the 10-JUL-2026 PnR measured
**41 of 46 blocks (90%)**, of which **32 are the WCS** (logic 30%, registers 12%,
DSP 0%). Full analysis: [`BSRAM-BUDGET.md`](BSRAM-BUDGET.md). Two things live
there, both analysis-only / not implemented:

- **Reclaim 8 blocks (90% -> ~72%).** The UUA half of the WCS only holds real
  microcode in words 0..1355 - the top two thirds is a computable address ramp -
  so repacking that bank as one 2048x64 array frees 8 blocks. Note the naive fix
  (just narrowing the chips to 2048 deep) saves *nothing*; the doc explains why.
- **Floppy / SMD need a sync-read refactor before they fit at all.** Their 2 KB
  sector buffers (`s_buffer[0:1023]`) are 1 BSRAM block each and the budget is
  fine, but as written they use three *asynchronous* read ports - BSRAM is
  sync-read only, so they will not infer and cannot fit as registers either.
  Blocker, not an optimisation. Same fix serves Basys3.

## Planned build defines

Introduce a board target (`TARGET_TANG20K`) that derives:
`GOWIN` (vendor primitives), `BOARD_CLK_FREQ 27_000_000`, `SKIP_WCS_LOAD`
(preloaded WCS), and a planned `MAIN_RAM_SDRAM` (SDRAM backend). See
`../../docs/build-defines.md`.

## New modules to build

1. Tang top / board wrapper - 27 MHz input, `rPLL` for the CPU clock (+ a
   phase-shifted SDRAM clock), Tang pinout.
2. Gowin `rPLL` clock module (replaces the Xilinx MMCM).
3. SDRAM adapter - bridge the ND-120 memory interface (`AA_9_0`, `BANK*`, `RAS`,
   `CAS`, `MWRITE50_n` in `MEM_RAM_49.v`) to the nand2mario SDRAM controller.
4. `.cst` / build scripts here.

## On-chip debug

- **THE working method: [`TRACE-CAPTURE-GUIDE.md`](TRACE-CAPTURE-GUIDE.md)** -
  512-sample on-chip analyzer in the ND-120 top, dumped over the console UART;
  full build/capture/decode walkthrough (usable by a person or an LLM). This is
  what cracked the memory-write bug.
- **GAO** (Gowin Analyzer Oscilloscope) - captures internal nets to BSRAM, read
  back over JTAG. But BSRAM is scarce here (WCS uses most of it), so GAO capture
  depth is shallow.
- **Preferred: UART debug streamer** (BSRAM-free) for full-length boot traces;
  fast Gowin roundtrip makes re-flashing to move probes cheap. See
  `../../FPGA-BRINGUP-PLAN.md` (capture automation).

## Staged plan (see docs/tang-nano-20k-port.md)

- **G0 Fit check (first):** synth for `GW2AR-18`, read LUT + BSRAM utilization.
  Go/no-go and decides microcode placement.
- **G1 Minimal bring-up:** Tang top + `rPLL` + `.cst`; WCS preloaded; small BSRAM
  main RAM. Goal: boot reaches the golden phases.
- **G2 Validate:** GAO / UART capture -> compare against `../../docs/boot-golden-spec.md`.
- **G3 SDRAM:** full 8 MB main memory (parity with the sim). Controller is
  validated standalone in [`sdram-test/`](sdram-test/README.md).
- **G4 Clock up:** validate at 27 MHz first, then raise the CPU/SDRAM clock
  via the rPLL (54 MHz setting exists in the vendored `gowin_rpll.v`; the
  SDRAM controller is good to 66.7 MHz, LiteX runs it at 48 MHz). See
  `Verilog/TODO.md`.

## Related docs

- [`TRACE-CAPTURE-GUIDE.md`](TRACE-CAPTURE-GUIDE.md) - on-chip trace capture + analysis how-to (this board).
- `../../docs/tang-nano-20k-port.md` - full port analysis (this board's design doc).
- `../../docs/skip-wcs-load.md` - preloaded-WCS microcode (needed for the fit).
- `../../docs/build-defines.md` - the board-target define scheme.
- `../../docs/fpga-debug-methodology.md` - shared FPGA debug workflow.

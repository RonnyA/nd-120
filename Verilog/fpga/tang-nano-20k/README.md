# Tang Nano 20K (Gowin GW2AR-18) FPGA target

**Full path:** `Verilog/fpga/tang-nano-20k/`

Gowin build/flow for the Sipeed **Tang Nano 20K**. This is the **primary FPGA
target** going forward - chosen for faster synthesis than Vivado, a Linux-native
open-source toolchain option, and 8 MB of SDRAM that lets the FPGA run the full
memory config like the simulator. Full analysis and staged plan:
`../../docs/tang-nano-20k-port.md`.

## Bring-up: getting the board talking (do this first)

Every session starts here. The whole USB dance is already scripted - it does
not need to be done by hand, and doing it by hand is how most of the wasted
time on this board has been spent.

```bash
cd Verilog/fpga/tang-nano-20k
make usb            # find the Tang on the Windows host, attach it to WSL,
                    # open the raw USB node AND /dev/ttyUSB* permissions
make flash-gowin    # program the current bitstream
```

After `make usb` you have:

| Device | Use |
|--------|-----|
| `/dev/ttyUSB0` | JTAG side (openFPGALoader) |
| `/dev/ttyUSB1` | OPCOM console, **9600 8N1** |

**Reflashing reboots the design - no power cycle needed.** Measured
09-AUG-2026: `make flash-gowin` restarts the ND-120 and the console comes back
to the `#` prompt on its own. So a build/flash/test cycle can run unattended.

**A real power cycle is different.** Pulling power detaches the device from
WSL and the host busid CHANGES (seen 3-3, then 2-4, then 5-2 on different
days). After a power cycle, run `make usb` again - never assume the old busid.

### When it will not talk

| Symptom | Cause | Fix |
|---------|-------|-----|
| `unable to open ftdi device: -4 (usb_open() failed)` | the raw USB node's permissions reset when the device re-enumerated | `make usb`, or `sudo chmod 666 $(lsusb -d 0403:6010 \| sed -E 's#Bus ([0-9]+) Device ([0-9]+).*#/dev/bus/usb/\1/\2#')` |
| `unable to open ftdi device: -3 (device not found)` | not attached to WSL at all | `make usb` |
| `cannot open /dev/ttyUSB1: No such file or directory` | attached, but `ftdi_sio` has not created the serial nodes | `make usb` |
| `openFPGALoader: command not found` | running the command on the Windows side instead of inside WSL | run it from WSL |

### Driving the console

OPCOM is picky and the rules are not guessable:

- **UPPERCASE only.**
- **~0.30 s between characters.** At 0.12 s characters are dropped silently in
  the middle of a number and OPCOM answers `?` - which looks like a machine
  fault and is not one.
- 9600 8N1 on `/dev/ttyUSB1`.

Use the committed driver rather than writing another one:

```bash
python3 ../../tools/ndconsole.py --seconds 90 --out run.log '400$'
```

Command reference: `Verilog/docs/opcom-console.md` and the `nd120-fpga` skill.

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
| `src/ND120_TANG20K_TOP.v` | Board top: instantiates `ND3202D`, ties off the external bus, S1 = Master Clear, OPCOM UART 9600 on the BL616 (pins 69/70), 6 LEDs: block-read/write activity, tape byte served, SD status pair, heartbeat (see the LED table below) |
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

## Clock variants and measured boot timings (24-AUG-2026)

Clock variants, selected with `gowin_build.ps1 -Variant
<slow|mid|fast20|full>`. `clk_cpu` is always exactly half of `clk2x`;
slow/mid/full share one 864 MHz VCO, `fast20` uses 648 MHz.

| Variant | CPU | SDRAM | Setup violations | CPU-domain Fmax (Gowin STA) |
|---------|-----|-------|------------------|------------------------------|
| `crawl` | 3.375 MHz | 6.75 MHz | - | - |
| `slow` (default) | 6.75 MHz | 13.5 MHz | **0** | 17.68 MHz |
| `mid` | 13.5 MHz | 27 MHz | **0** | 19.03 MHz |
| `fast20` (26-AUG-2026) | **20.25 MHz** | 40.5 MHz | **0** | **20.556 MHz** |
| `full` | 27 MHz | 54 MHz | **1667** | 19.55 MHz |

`fast20` is the fastest TIMING-CLEAN variant (TNS 0; margin over Fmax is
only 1.5%, so every rebuild must re-check its own `.tr`). It also switches
the console to **115200 baud** (7E2) - slow/mid/full stay at 9600 so their
tooling is untouched. The physical baud is the `UART_BAUD_RATE` build
constant alone; the microcode's BAUDV thumbwheel value (8 = 9600) is stored
by the SC2661 emulation but never used for bit timing, proven on the Nexys
and now here. **Silicon 26-AUG-2026: SINTRAN III boots on `fast20`,
banner + Watchdog in ~40 s, clean text on a 115200 7E2 console. Soaked
27-AUG: 4 unattended hours, 8/8 console probes.** Since 27-AUG the console
is 115200 for EVERY variant, and all the python console tools in this
directory default to it (`--baud 9600` for pre-27-AUG bitstreams).

### Measured on silicon, SINTRAN III booting from WD0

Cold boot each time (reflash, then `20500&`), driven by `measure_s3.py`.
`banner` = to `SINTRAN III RUNNING`; `watchdog` = to
`ERS/SINTRAN III Watchdog has started`, i.e. ready for login; `S3` = from the
CR that submits `S3` to its first output byte, after `SET-T-T,,93`.

All figures are SECONDS (decimal), not minutes:seconds. `2.4 sec` means two
point four seconds - S3 responds almost immediately at every clock. The
minute:second equivalents are given in brackets for the longer ones.

| CPU clock | banner | watchdog (login ready) | S3 first output |
|-----------|--------|------------------------|-----------------|
| 6.75 MHz  | 168.2 sec (2 min 48) | 539.3 sec (8 min 59) | 3.9 sec |
| 13.5 MHz  | 119.0 sec (1 min 59) | 480.1 sec (8 min 00) | 2.7 sec |
| 27 MHz    | 101.9 sec (1 min 42) | 451.9 sec (7 min 32) | 2.4 sec |

**Boot is NOT CPU-bound.** Four times the clock buys only 1.65x on the banner
and 1.19x on time-to-login. The banner->watchdog segment barely moves at all -
371 s, 361 s, 350 s - so that phase is essentially clock-independent. That is
consistent with it being disc-bound: the SD/storage stack deliberately runs off
the fixed 27 MHz crystal (`clk_stor = sys_clk`) regardless of the CPU clock,
because `sd_file_reader`'s identification divider is only in spec there.

**S3 starts in under 4 seconds at every clock.** A "slow S3 start" is therefore
not S3 being slow - it is almost certainly the machine still being in the long
post-banner phase, before the watchdog line says it is ready. Wait for the
watchdog before concluding anything about S3.

### Which variant to use

`full` (27 MHz) runs SINTRAN, LIST-FILES and S3, and is the fastest measured -
but it does NOT close timing (1667 setup violations against a 19.55 MHz Fmax),
so its margin over temperature and voltage is unquantified. `mid` (13.5 MHz)
closes with zero violations and gives most of the gain: 1.41x on the banner
against `slow`, versus 1.65x for `full`.

Note the `.sdc` is a single `create_clock` line with no multicycle on the known
52 ns WCS->ACAL path to a clock-enable pin, so these Fmax figures are a floor,
not a verdict. Real constraints are the route to a fast build that is also
defensible.

Known clock-dependent constant, NOT slaved to `BOARD_CLK_FREQ`: the debug
dumper baud divisor, `ND120_TANG20K_TOP.v` `DELAY_FRAMES(1406)`, assumes
clk2x = 13.5 MHz. Capture dumps come out garbage at any other variant. The
console UART and the RTC do scale correctly.

## LEDs (active low, pins 15-20; map of 07-AUG-2026)

| LED | Meaning |
|---|---|
| `led[0]` | **Storage BLOCK READ** - flashes ~150 ms per floppy/Winchester block read (`FDISK_REQ`/`WDISK_REQ` with WR low), solid under sustained reads |
| `led[1]` | **Storage BLOCK WRITE** - same stretcher, for block writes (WR high) |
| `led[2]` | A tape byte was served - the SD -> TAPE-400 path delivered data (`400$` working) |
| `led[3]` | `sd_status[0]` \ together: `00` = mount never ran, `01` = no card, |
| `led[4]` | `sd_status[1]` / `10` = mount/FAT error, `11` = SD-FAT OK (both lit) |
| `led[5]` | Heartbeat ~0.8 Hz - `clk_cpu` alive at all |

Reading it: `led[4]`+`led[3]` both lit = the whole SD-FAT chain works. After
`400$`, `led[2]` dark = the CPU never got tape bytes. `led[0]`/`led[1]` are
the disc activity lights: one flash per block, a steady glow during a
transfer burst. (Before 07-AUG, `led[0]`/`led[1]` were the bring-up
indicators tape-request-seen / SD-clock-seen; those are retired.)

## Storage build: SD-FAT + floppy + SMD (measured 3-AUG-2026)

The SD-FAT reader, the floppy at 1560 and the SMD disc at 1540 are all in one
bitstream and it places and routes. This is the build to use for disc work.

**Defines** (`src/tang20k_defines.v`, both active):

| Define | Effect |
|---|---|
| `TANG_FLOPPY` | floppy-only base build: `ND_FLOPPY_DMA` at 1560 + `nd_storage` client for `FLOPPY1.IMG`. **Drops the papertape** - `TANG_INC_TAPE` goes to 0, so `400$` is not available in this bitstream. |
| `TANG_SMD` | adds `ND_SMD` at 1540 with its own `ND_DMA_MASTER`, plus `nd_storage_disc_adapter` serving `SMD0.IMG` (client 3, slot 1376 blocks -> image limit 2,818,048 bytes). |

They resolve to `TANG_INC_FLOPPY = 1`, `TANG_INC_SMD = 1`, `TANG_INC_TAPE = 0`
in `src/ND120_TANG20K_TOP.v`, applied both to the core (which devices exist) and
to `nd_storage_devices` (which client the SD-FAT reader serves).

With either define set, the SD-FAT slimming cut `SDFAT_NO_STORAGE_CHECK` is
suppressed automatically - floppy and SMD do random access and writeback, so the
mount-time contiguity checker (`nd_storage_fatchk.v`) must stay in. That cut is
for the tape-only build.

**Measured utilization** (Gowin EDA flow, `VARIANT=slow`, 3-AUG-2026, from
`build/nd120_tang20k_build/impl/pnr/nd120_tang20k_build.rpt.html`):

| Resource | Used | % |
|---|---|---|
| LUT/ALU/ROM16 | 14464 (12955 LUT, 1509 ALU) | - |
| CLS | 9103/10368 | 88% |
| Register | 7579/15915 | 48% |
| - as Latch | 0/15552 | 0% |
| - as FF | 7529/15552 | 49% |
| BSRAM | 34 SP10 SDPB | 96% |
| DSP | 2 MULTALU36X18 | 9% |
| PLL | 1/2 | 50% |

Read those two numbers together: **BSRAM 96% and CLS 88%** is what "everything
fits, with nothing to spare" looks like on this board. The SMD's 1024x16 sector
buffer is the last BSRAM block; dropping `TANG_SMD` alone is the intended escape
hatch if something else needs one. **Register as Latch is 0** - no inferred
latches, which is a standing gate for every build here.

This supersedes the older claim below that floppy and SMD "need a sync-read
refactor before they fit at all": that refactor was done, both sector buffers
are synchronous-read now, and the build above is the measurement.

Build and program (Gowin EDA flow, Windows host):

```
.\gowin_build.ps1 -Variant slow      # or: make gowin VARIANT=slow
make load-gowin                      # SRAM  - gone at power-off
make flash-gowin                     # SPI flash - survives a power cut
```

Power-cycle the board after every loader operation before judging anything on
the console.

Note before flashing rather than loading: this build's SMD write path is live
(full aligned 1024-word blocks only; anything else answers `disk_err`), and a
flashed bitstream comes up on its own at every power-on, so it can write
`SMD0.IMG` on the card without anyone asking.

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
- **Floppy / SMD sync-read refactor - DONE, no longer a blocker.** Their 2 KB
  sector buffers (`s_buffer[0:1023]`) once used three *asynchronous* read ports,
  which BSRAM cannot do; they are synchronous-read now and both devices are in a
  placed bitstream (see [Storage build](#storage-build-sd-fat--floppy--smd-measured-3-aug-2026)
  - BSRAM 96% with both in). Same fix serves Basys3.

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

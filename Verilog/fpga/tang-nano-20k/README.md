# Tang Nano 20K (Gowin GW2AR-18) FPGA target

**Full path:** `/mnt/e/Dev/Repos/Ronny/nd-120/Verilog/fpga/tang-nano-20k/`

Gowin build/flow for the Sipeed **Tang Nano 20K**. This is the **primary FPGA
target** going forward - chosen for faster synthesis than Vivado, a Linux-native
open-source toolchain option, and 8 MB of SDRAM that lets the FPGA run the full
memory config like the simulator. Full analysis and staged plan:
`../../docs/tang-nano-20k-port.md`.

## Board / device

| Item | Value |
|------|-------|
| Board | Sipeed Tang Nano 20K |
| FPGA | Gowin **`GW2AR-LV18QN88C8/I7`** (GW2AR-18) |
| Logic | 20,736 LUT4, 15,552 FF |
| Block RAM (BSRAM) | **828 Kbit** (46 blocks) |
| Big RAM | **8 MB SDRAM** (64 Mbit, 32-bit SDR, embedded in the GW2AR package) |
| Config flash | 64 Mbit |
| Clock | 27 MHz crystal + MS5351 clock chip, 2 PLLs (use a Gowin `rPLL` for the CPU clock) |
| Programmer | BL616 onboard USB (JTAG + USB-UART + USB-SPI); openFPGALoader-compatible |

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

Prior `../../Verilog.json`/`Verilog_pnr.json` (2024, gitignored) show an OSS run
was attempted before.

## Files here

| File | Purpose |
|------|---------|
| `ND120_TOP.cst` | Gowin physical constraints - pin `IO_LOC`/`IO_PORT` assignments (LEDs, clock, UART). This is the Tang pinout. |

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
| Main memory | **8 MB SDRAM** via the nand2mario Tang-Nano-20K controller |

`SKIP_WCS_LOAD` is already implemented and verified in Verilator (preloaded WCS
boots byte-identical to the normal load).

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
- **G3 SDRAM:** full 8 MB main memory (parity with the sim).

## Related docs

- `../../docs/tang-nano-20k-port.md` - full port analysis (this board's design doc).
- `../../docs/skip-wcs-load.md` - preloaded-WCS microcode (needed for the fit).
- `../../docs/build-defines.md` - the board-target define scheme.
- `../../docs/fpga-debug-methodology.md` - shared FPGA debug workflow.

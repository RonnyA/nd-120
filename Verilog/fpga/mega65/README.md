# ND-120 on the MEGA65

**Status: THE WHOLE MACHINE BUILDS, 02-SEP-2026 - unproven on a real
MEGA65.** ND-120 CPU board with 4 MB main memory, TDV2200 terminal on the
MEGA65's own keyboard and screen, floppy 0/1, Winchester 0/1 and paper tape
on the framework's virtual drives, one `.cor` per board revision. Every
piece has run on the DE10-Nano (MiSTer) or the Nexys 4 DDR, or passes its
bench here; this exact combination has not met a MEGA65 yet. The living
plan, with a "Next" line at the top, is [`docs/00-plan.md`](docs/00-plan.md).

**Two memories, picked by the board revision at build** (Ronny, 02-SEP-2026):

| Boards | Memory | Path |
|---|---|---|
| R3 / R3A | 8 MiB HyperRAM (the only memory it has) | the Nexys variable-latency seam (`MEM_RAM_49_DDR2` cache + MEM_HOLD) over `rtl/nd_avalon_port.v` on M2M's HyperRAM port |
| R4 / R5 / R6 | 64 MB SDRAM ("the latest memory") | the MiSTer sheet-49 bridge + `sdram18`, unchanged; M2M itself never drives this chip, so `CORE/vhdl/framework-overrides/` hands the pins into the core |

There is still no MEGA65 here; friends who own one test what we send. Each
round trip costs days, so every bitstream must report its own result on the
MEGA65's own screen - the rules are the remote-testing gate in the plan.

Target: the MEGA65 retro computer, every board revision M2M supports
(R3/R3A, R4, R5, R6). The goal is the full consumer story: an `ND-120.cor`
file per revision plus the disc images on one SD card, flashed from the
machine's own menu - SINTRAN III in a Commodore case, no cables, no toolchain.

## Why this board

Verified 27-AUG-2026 from the mega65-core build scripts and board XDCs
(details + sources in [`docs/00-plan.md`](docs/00-plan.md)):

| Item | MEGA65 R4+ | vs the proven Nexys 4 DDR |
|---|---|---|
| FPGA | Xilinx **XC7A200T fbg484, speed -2** | 2x the fabric of the Nexys A100T, one speed grade FASTER |
| Oscillator | 100 MHz | identical - our MMCM scheme drops in |
| Main memory | **64 MiB SDR SDRAM (32M x 16)** on plain fabric pins + 8 MiB HyperRAM | replaces the DDR2 MIG; a plain SDR controller is simpler than the MIG, and the design needs only 4 MiB |
| SD card | two slots (internal microSD + external), **wired directly to fabric pins** | same native 1-bit drive as the Nexys |
| Utilization | ~13% LUT, ~26% BRAM projected (from the measured Nexys reports) | 71% BRAM on the Nexys |
| Console | no built-in USB-UART: TE0790 JTAG/UART module on the internal JB1 header, or keyboard+video | the one regression vs the Nexys |
| Distribution | `.cor` file flashed from SD via the built-in menu (8 QSPI slots) | beats every other board's deployment story |
| Toolchain | same Vivado, free tier covers the A200T | pin XDC and part string change, flow identical |

## Architecture (decided 02-SEP-2026)

- **Framework:** MiSTer2MEGA65 (GPL-3, VHDL) as the git submodule `m2m/`.
  It owns the per-revision tops and XDCs, keyboard scan, VGA + HDMI output,
  the OSD, virtual drives and `.cor` packaging. Our side is a thin VHDL
  `MEGA65_Core` wrapper with everything inside it in Verilog.
- **Memory:** the table above. Both backends sit behind the sheet-49 seam;
  nothing above it changes.
- **Devices:** `vdrives` speaks the MiSTer `sd_rd/sd_wr/sd_buff` protocol,
  so `../mister/rtl/nd_storage_hps.v` ports to it. Throughput of the
  QNICE-served discs is the open measurement (build B4 in the plan).
- **Console/display:** `../../Terminals/` on the framework's video path,
  the MEGA65 keyboard through a key-number-to-ASCII table of ours. There is
  no UART console on this board at all.

## Files

| File | Purpose |
|---|---|
| [`docs/00-plan.md`](docs/00-plan.md) | The living plan: decisions, verified framework facts, the two memory backends, build sequence B0-B5, layout |
| `m2m/` | MiSTer2MEGA65 framework, git submodule (`git submodule update --init --recursive`) |
| `Makefile`, `build.tcl` | `make toolchain` (once), `make all BOARD=r6` (or r3/r4/r5) -> `build/<board>/nd120_mega65_<board>.bit` + `.cor`. Working since 02-SEP-2026 on Vivado 2026.1 |
| `CORE/` | our side of the framework contract (the framework's `CORE/` template, copied and edited): `vhdl/main.vhd` is the thin VHDL skin over our Verilog, `vhdl/config.vhd` the OSD texts/menu, `CORE.xdc` our constraints, `m2m-rom/` the QNICE firmware build |
| `rtl/` | the MEGA65 glue in Verilog: `m65_keys_to_ps2.v` (keyboard scan -> PS/2 events, keycap-faithful), `nd120_console_mega65.v` (the shared terminal on the framework's video/keyboard) |
| `sim/` | their testbenches (`make test-keys`, `make test-console`, `make lint`), registered in `Verilog/tests/run_all_tests.sh` |
| [`docs/01-using-the-core.md`](docs/01-using-the-core.md) | using the core: flashing, the SD card layout, every menu line (drives, colour, panel, cache, HDMI), what persists (`nd120cfg`) and what does not (mounts), booting, keys, differences from the MiSTer core |
| [`docs/SEND-NOTE.md`](docs/SEND-NOTE.md) | what goes to a tester with the `.cor` files: which file, how to flash, how to boot SINTRAN, what to photograph |
| `sdcard/nd120/nd120cfg` | the 35-byte settings file for `/nd120/` on the card - with it the menu settings survive a power cycle |
| `tools/` | gitignored; `make toolchain` fetches MEGA65's `coretool` (the `.cor` packer) here |

Reuse pointers: `../nexys4ddr/build.tcl` (the Vivado flow to clone),
`../nexys4ddr/ddr2/` (the seam + cache that port unchanged),
`../nexys4ddr/timing.md` (the microcycle bottleneck analysis - fabric is
the same family, so it transfers).

## Ecosystem context (m65-altcores survey, 27-AUG-2026)

Source: the community alternative-core catalogue at
<https://kugelblitz360.github.io/m65-altcores/> (site last updated
21-JUL-2026 at survey time). What it establishes for this port:

- **~34 alternative cores exist, all community-built**, catalogued at
  <https://kugelblitz360.github.io/m65-altcores/quick-core-overview.html>.
  Non-Commodore machines are normal there: Amiga 500, ZX Spectrum,
  Game Boy / Game Boy Color, TI-99/4A, Nascom2, MSX-1 all ship as
  "fully/mostly functional"; Apple II, Sinclair QL and C128 are in
  development. A non-Commodore core is established practice - but **no
  minicomputer core exists in the catalogue**; the ND-120 would be the
  first, consistent with the plan's note that no non-MiSTer core has yet
  gone through the M2M framework.
- **Most cores are MiSTer ports via MiSTer2MEGA65** ("Many of the Cores
  for the MEGA65 started out as MiSTer projects, like the C64 and Game
  Boy Cores" -
  <https://kugelblitz360.github.io/m65-altcores/creating-new-cores-for-mega65.html>).
- **Distribution convention:** one download entry per core on
  **files.mega65.org** (per-core UUID URL) plus the author's GitHub repo.
  Several cores ship separate R3 and R6 `.cor` files (Ghosts'n Goblins,
  Xevious on the overview page), and repo names carry the compatibility
  (`..._R3_R6`). Catalogue listing is by mail to the site maintainer
  (boris@dreisechzig.net, per the site's contact note).
- **Slot count note:** the install guide
  (<https://kugelblitz360.github.io/m65-altcores/how-to-use-alternative-cores.html>)
  says 8 slots numbered 0-7 - matching the "8 QSPI slots" claim in the
  table above - while the site's front page says "seven slots"; the site
  is internally inconsistent on this. The install guide recommends
  keeping slot 1 for the stock MEGA65 core.

## Links

| Link | What it is |
|---|---|
| <https://kugelblitz360.github.io/m65-altcores/> | Community alt-core catalogue (source of the survey above) |
| <https://kugelblitz360.github.io/m65-altcores/quick-core-overview.html> | Every released/in-dev alt core, with download + repo links |
| <https://kugelblitz360.github.io/m65-altcores/mega65-revisions-and-cores.html> | R3-vs-R6 core-compatibility guide (end-user view) |
| <https://kugelblitz360.github.io/m65-altcores/how-to-use-alternative-cores.html> | End-user `.cor` install procedure (slots, key combos) |
| <https://kugelblitz360.github.io/m65-altcores/creating-new-cores-for-mega65.html> | Core-development pointers (M2M framework) |
| <https://files.mega65.org> | The filehost every released core distributes through |
| <https://github.com/sy2002/MiSTer2MEGA65/wiki> | MiSTer2MEGA65 framework wiki |
| <https://mega65.org/> | MEGA65 project home |
| <https://www.forum64.de/index.php?board/457-mega65/> | Forum64 MEGA65 board (mostly German) |

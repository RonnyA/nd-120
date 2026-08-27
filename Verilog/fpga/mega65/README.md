# ND-120 on the MEGA65

**Status: PLANNING (27-AUG-2026).** Target: the MEGA65 retro computer,
board revisions **R4 and later** (R4/R5/R6 are electrically equivalent for
our purposes). The goal is the full consumer story: an `ND-120.cor` file
plus the disc images on one SD card, flashed from the machine's own menu -
SINTRAN III in a Commodore case, no cables, no toolchain.

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

## Planned architecture

- **Memory:** new `nd_sdram_port` implementing the exact `nd_ddr2_port`
  request/response contract (one op outstanding, 128-bit data + 16-bit
  mask, bounded latency, never drop/reorder) so the proven
  `MEM_RAM_49_DDR2` cache + MEM_HOLD freeze layer ports UNCHANGED. An
  existing community controller is preferred over writing one - survey in
  progress (MJoergen/HyperRAM, mega65-core's sdram_controller, MiSTer SDR
  controllers).
- **Devices:** evaluate the MiSTer2MEGA65 framework's **virtual-drive**
  facility (disk images served from SD by the framework Shell) as a
  replacement for our own FAT stack on this platform, with the ND-120's
  tape/floppy/Winchester seams riding it; fall back to porting our SD-FAT
  stack against the fabric-wired slot if the model does not fit.
- **Console/display:** the framework's keyboard + VGA/HDMI path as a
  terminal (the real end goal on this machine), TE0790 UART as the
  bring-up console.
- **Framework decision** (bare-metal vs MiSTer2MEGA65 vs hybrid) is OPEN
  pending the two research reports - see the plan.

## Files

| File | Purpose |
|---|---|
| [`docs/00-plan.md`](docs/00-plan.md) | The phase plan, hardware facts with sources, open decisions |
| `Makefile` | Standard board API - placeholders until the port starts |

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

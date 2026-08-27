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

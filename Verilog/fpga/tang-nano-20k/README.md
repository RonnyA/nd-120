# Tang Nano 20K (Gowin GW2AR-18)

**Full path:** `/mnt/e/Dev/Repos/Ronny/nd-120/Verilog/fpga/tang-nano-20k/`

Build/flow files for the Sipeed Tang Nano 20K. Full port analysis (memory
architecture, define scheme, staged plan) is in
`/mnt/e/Dev/Repos/Ronny/nd-120/Verilog/docs/tang-nano-20k-port.md`.

## Target
- FPGA: Gowin `GW2AR-LV18QN88C8/I7` (GW2AR-18): 20,736 LUT4, 828 Kbit BSRAM,
  8 MB embedded SDRAM.
- Clock: 27 MHz crystal (use a Gowin `rPLL` for the CPU clock).
- Programmer: BL616 USB (openFPGALoader-compatible).

## Files here
- `ND120_TOP.cst` - Gowin physical constraints (pin `IO_LOC`/`IO_PORT` for
  LEDs, clock, UART, ...). This is the Tang pinout.

## Existing Gowin project
There is an existing Gowin EDA project at
`/mnt/e/Dev/Repos/Ronny/nd-120/Verilog/ND-120-Gowin/` (`.gprj`). Its source files
are referenced by absolute path, so it is independent of this folder's location.
Whether to consolidate that project dir under here is an open decision.

## Planned build (see docs/tang-nano-20k-port.md)
- Toolchain: Gowin EDA (`gw_sh`) or OSS (yosys `synth_gowin` + nextpnr-himbaechel
  + `gowin_pack` + `openFPGALoader`) - the OSS flow runs natively on WSL/Linux.
- Memory: microcode via `SKIP_WCS_LOAD` preloaded WCS (BSRAM); main memory via
  the nand2mario SDRAM controller (8 MB).
- First milestone (G0): a fit check - synth for `GW2AR-18` and read LUT + BSRAM
  utilization.

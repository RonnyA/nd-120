# FPGA build flows

**Full path:** `/mnt/e/Dev/Repos/Ronny/nd-120/Verilog/fpga/`

Per-FPGA build and flash files. The Verilog/HDL source stays under `Verilog/`
(the build scripts reference it by absolute path); only the board-specific
build/flow files live here.

| Folder | FPGA | Toolchain | Status |
|--------|------|-----------|--------|
| [`basys3/`](basys3/) | Digilent Basys3 (Xilinx `xc7a35tcpg236-1`) | Vivado (Windows host) | Working synth; boot blocked by derived-clock timing (see `../docs/fpga-debug-methodology.md`) |
| [`tang-nano-20k/`](tang-nano-20k/) | Sipeed Tang Nano 20K (Gowin `GW2AR-18`) | Gowin EDA / OSS (yosys+nextpnr) | Target in progress (see `../docs/tang-nano-20k-port.md`) |

## Basys3 (Vivado)
Scripts in `basys3/` (run from the Windows host):
- `vivado_build.ps1` / `vivado_build.tcl` - synth + implement (see the tcl header
  for flags: `full_synth`, `skip_program`, ...).
- `vivado_lint.tcl` - lint only.
- `flash.ps1` / `flash.tcl` - program FPGA (JTAG) and/or SPI flash.
- `constraints_tie_unused.xdc` - constraints for unused pins.
- Helpers: `vivado_impl_only.tcl`, `list_flash.tcl`, `check_rom.tcl`, `find_nets.tcl`.

Each `.ps1` finds its companion `.tcl` in this same folder - keep them together.

## Tang Nano 20K (Gowin)
See `tang-nano-20k/README.md`. Microcode note: with `SKIP_WCS_LOAD`
(`../docs/skip-wcs-load.md`) the WCS is bitstream-preloaded, which is what makes
the microcode fit the Tang's 828 Kbit BSRAM.

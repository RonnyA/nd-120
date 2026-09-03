# ND-120 on MiSTer — Overview

The ND-120 core for the MiSTer FPGA platform (Terasic DE10-Nano board), with
floppy/Winchester/tape served as image files from the Linux (HPS/ARM) side, the
console on the machine's own screen and keyboard (a TDV2200 terminal, also on
the HPS serial line), and microcode loaded from files instead of baked-in hex.

**The port is done.** SINTRAN III boots on real hardware (DE10-Nano), verified
02-SEP-2026: it comes up at the `#` MOPC monitor, and with a Winchester image
mounted in the OSD, `&` boots SINTRAN. The self-test passes (green `G` lamp),
and the TDV2200 box-drawing font and keyboard work. Shipping build: 20 MHz CPU
clock, 4 MB main memory in the SDRAM module, WCS in block RAM, cache off. The
hardware-verified `.rbf` is the MiSTer artifact in Release 2
(`../../RELEASE-NOTES-release2.md`).

- User quickstart (ready-built `.rbf`, load, boot): [`../../QUICKSTART-mister.md`](../../QUICKSTART-mister.md)
- Core README (status, build, shipping config): [`../README.md`](../README.md)

The external links in these documents were fetched and verified on 2026-07-08.
Anything *inferred* rather than verified is explicitly marked **[inferred]**.

## The documents

These started as a bring-up plan and are now the developer reference for the
finished core.

| Doc | What it covers |
|-----|----------------|
| [01-getting-started.md](01-getting-started.md) | Hardware, MiSTer SD install, network access, learning resources |
| [02-building.md](02-building.md) | Template_MiSTer structure, Quartus 17.0.2, Docker build, project files |
| [03-deploy-and-test.md](03-deploy-and-test.md) | Getting the .rbf onto the MiSTer: scp, hot-load, JTAG, SD folders |
| [04-core-config-menu.md](04-core-config-menu.md) | CONF_STR syntax, hps_io, the OSD menu, status bits |
| [05-devices-block-char.md](05-devices-block-char.md) | Block-device protocol (disk images), ioctl (microcode upload), UART/char devices; PDP2011 case study |
| [06-debugging.md](06-debugging.md) | SignalTap, LEDs, UART debug, Linux console, Verilator harness |
| [07-links.md](07-links.md) | Every validated link in one place |

## The one-paragraph mental model

You never own the FPGA top level. The MiSTer framework (`sys/sys_top.v`) owns the pins,
HDMI scaler, audio, and the bridge to the ARM. You write ONE module called `emu`
(port list fixed by the framework) containing your core plus an `hps_io` instance.
`hps_io` carries everything to/from Linux over an opaque 46-bit bus: the OSD menu
definition (a string constant — **no Linux-side code needed**), option bits, file
uploads, and a block-device protocol where your logic asks for sector N and the Linux
side reads it from a mounted image file. Compile with Quartus 17.0.2 (free, runs in
Docker), producing one `.rbf` file you copy to the MiSTer's SD card.

## How the pieces landed

- The full ND-120 machine (`ND3202D`) runs inside `emu`, clocked at 20 MHz from
  a Quartus PLL off the board's 50 MHz.
- Main memory is 4 MB (2M words) in the DE10-Nano SDRAM add-on module; WCS is in
  block RAM. The SDRAM path was the hardest silicon-only work - see the memory
  notes in [05-devices-block-char.md](05-devices-block-char.md).
- Floppy/Winchester/tape images are mounted from the OSD and served over the
  `sd_rd/sd_wr/sd_buff` block protocol against Linux-mounted image slots.
- Microcode is uploaded from the HPS at core load rather than baked into BRAM.
- The console is the machine's own screen and keyboard (a TDV2200 terminal),
  re-implemented clean-room and shared with the MEGA65 port; the CPU serial line
  is also on the HPS `/dev/ttyS1` at 115200 7E1.

## What carried over from existing work

- All `FPGA_FF_MODE` / clock-enable / latch-removal work — Cyclone V has the same
  constraints as the Artix-7 (no transparent latches, no internal tri-states, no
  gated clocks).
- The Verilator harnesses (`Verilog/sim/`, `Verilog/runSim/`) stay the reference;
  there is a MiSTer-specific Verilator template (see 06) built on the same idea.
- Tang Nano SDRAM bridge experience mapped to the MiSTer SDRAM add-on (PDP2011
  ships its own SDRAM controller the same way).

## The PDP2011 core is the map

A maintained MiSTer core of a 1970s minicomputer (PDP-11) with disk images, serial
console AND a built-in video terminal already exists:
https://github.com/MiSTer-Enhanced/PDP2011_MiSTer — it was the case study for the
block-device and console work; [05-devices-block-char.md](05-devices-block-char.md)
dissects it.

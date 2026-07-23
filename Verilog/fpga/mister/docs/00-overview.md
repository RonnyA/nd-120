# ND-120 on MiSTer — Plan Overview

Target: an ND-120 core for the MiSTer FPGA platform (Terasic DE10-Nano board), with
floppy/HDD served as image files from the Linux (HPS/ARM) side, OPCOM console on a
serial terminal, and microcode loaded from files instead of baked-in hex.

Every external link in these documents was fetched and verified on 2026-07-08.
Anything *inferred* rather than verified is explicitly marked **[inferred]**.

## The documents

| Doc | Phase | What it covers |
|-----|-------|----------------|
| [01-getting-started.md](01-getting-started.md) | 0 | Hardware, MiSTer SD install, network access, learning resources |
| [02-building.md](02-building.md) | 1 | Template_MiSTer structure, Quartus 17.0.2, Docker build, project files |
| [03-deploy-and-test.md](03-deploy-and-test.md) | 2 | Getting the .rbf onto the MiSTer: scp, hot-load, JTAG, SD folders |
| [04-core-config-menu.md](04-core-config-menu.md) | 3 | CONF_STR syntax, hps_io, the OSD menu, status bits — with a draft ND-120 menu |
| [05-devices-block-char.md](05-devices-block-char.md) | 4 | Block-device protocol (disk images), ioctl (microcode upload), UART/char devices; PDP2011 case study |
| [06-debugging.md](06-debugging.md) | all | SignalTap, LEDs, UART debug, Linux console, Verilator harness |
| [07-links.md](07-links.md) | ref | Every validated link in one place |

## The one-paragraph mental model

You never own the FPGA top level. The MiSTer framework (`sys/sys_top.v`) owns the pins,
HDMI scaler, audio, and the bridge to the ARM. You write ONE module called `emu`
(port list fixed by the framework) containing your core plus an `hps_io` instance.
`hps_io` carries everything to/from Linux over an opaque 46-bit bus: the OSD menu
definition (a string constant — **no Linux-side code needed**), option bits, file
uploads, and a block-device protocol where your logic asks for sector N and the Linux
side reads it from a mounted image file. Compile with Quartus 17.0.2 (free, runs in
Docker), producing one `.rbf` file you copy to the MiSTer's SD card.

## Phases at a glance

- **Phase 0 — setup (a weekend):** Get MiSTer running on the DE10-Nano as a *user*
  first (SD image, F12 menu, run an existing core, ssh into it). Pull the Docker
  image and compile the unmodified Template. You now have the full loop working
  before any ND-120 code is involved.
- **Phase 1 — skeleton core:** Fork Template, rename to `nd120`, put a trivial
  design in `emu` (blink LED_USER from a PLL clock, print a banner on UART_TXD).
  Deploy it, see "ND120" in the menu. Milestone: *your* core name in the OSD.
- **Phase 2 — ND-120 boots:** Instantiate `ND3202D` in `emu` (FPGA_FF_MODE, small
  BRAM RAM config), clock from a PLL (50 MHz in, ~39.06 MHz out), wire OPCOM UART to
  `UART_TXD/RXD`, microcode still baked into BRAM init. Milestone: OPCOM `#` prompt
  on a terminal connected to the MiSTer.
  **Prerequisite: the FF-mode design must boot — same fight as Basys3, no shortcut.**
- **Phase 3 — real menu + microcode from file:** CONF_STR with reset trigger and
  options; load WCS/EPROM images via the ioctl download path (`F` menu entries or
  auto-loaded boot ROM) instead of hex init.
- **Phase 4 — memory + disks:** Main memory to 6 MB (`ramSize=2`) via HPS DDR3
  (`DDRAM_*` ports, as ao486 does) or the SDRAM add-on; then floppy/SMD controllers
  speaking the `sd_rd/sd_wr/sd_buff` block protocol against Linux-mounted `S0:`/`S1:`
  image slots. Milestone: SINTRAN boots from an image file on the SD card.

## What carries over from existing work

- All `FPGA_FF_MODE` / clock-enable / latch-removal work — Cyclone V has the same
  constraints as the Artix-7 (no transparent latches, no internal tri-states, no
  gated clocks).
- The Verilator harnesses (`Verilog/sim/`, `Verilog/runSim/`) stay the reference;
  there is a MiSTer-specific Verilator template (see 06) built on the same idea.
- Tang Nano SDRAM bridge experience maps to the MiSTer SDRAM add-on (PDP2011 ships
  its own SDRAM controller the same way).
- The `~39.06 MHz` CPU/bus clock target: one Quartus PLL from the board's 50 MHz.

## The PDP2011 core is the map

A maintained MiSTer core of a 1970s minicomputer (PDP-11) with disk images, serial
console AND a built-in video terminal already exists:
https://github.com/MiSTer-Enhanced/PDP2011_MiSTer — study it alongside these docs;
[05-devices-block-char.md](05-devices-block-char.md) dissects it.

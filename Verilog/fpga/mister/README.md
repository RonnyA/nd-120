# ND-120 MiSTer core (DE10-Nano / MiSTer Pi)

**Full path:** `Verilog/fpga/mister/`

Port of the ND-120 CPU board to the [MiSTer FPGA](https://mister-devel.github.io/MkDocs_MiSTer/) platform.

![ND-120 MiSTer boot screen at the MOPC `#` monitor](docs/images/boot-screen-mopc.png)

*The core on real hardware (DE10-Nano, 02-SEP-2026), at the `#` MOPC monitor
before SINTRAN is loaded: the four-line power-on banner (core / console / build
stamp / board+clock+memory), the operator panel across the bottom, and the CPU
`G` lamp lit green (self-test passed). Mount a Winchester image in the OSD and
type `&` at `#` to boot SINTRAN.*

**Plan: [docs/00-overview.md](docs/00-overview.md)** - phase by phase (setup,
building, deploy/test, OSD menu, block/char devices, debugging), every external
link validated. `docs/07-links.md` is the full link collection.

- **Board:** Terasic DE10-Nano, or the Retro Remake **MiSTer Pi** clone - same
  Intel Cyclone V SoC `5CSEBA6U23I7` (~110K LE fabric + dual-core ARM Cortex-A9
  "HPS" running Linux, 1 GB DDR3 on the HPS side). SDRAM is an add-on module on
  both (128 MB; the MiSTer Pi "Turbo Pack" bundles it). The core is the same
  `.rbf` either way - nothing in this folder is DE10- or Pi-specific.
- **Goal:** ND-120 CPU core with floppy/HDD images served as files from the
  Linux (HPS) side via the MiSTer `hps_io` block-device protocol, console on
  the machine's own screen and keyboard (see the terminal plan below),
  microcode uploaded from the HPS at core load.

## Status (02-SEP-2026)

**SINTRAN III boots on real hardware (DE10-Nano).** The whole ND-120 machine
is in the build and running on silicon: it comes up at the `#` MOPC monitor
(the screenshot above), and with a Winchester image mounted in the OSD, `&`
boots SINTRAN. Verified this day on the board.

Shipping configuration of that build (stamp `e5bdea5+`):

| Item | Value |
|---|---|
| CPU clock | 20 MHz (PLL output) |
| Main memory | 4 MB (2M words) in the DE10-Nano SDRAM module, WCS in block RAM |
| Cache | off |
| Console | TDV2200, on the MiSTer's own screen + keyboard; also on the HPS `/dev/ttyS1` at 115200 |
| Storage | floppy 0/1, Winchester 0/1, paper tape - mounted from the OSD |
| `output_files/nd120.rbf` | 3,173,376 bytes |

Confirmed working on the board: boot to OPCOM, SINTRAN boot from a mounted
Winchester, CPU self-test (green `G` lamp), the TDV2200 box-drawing font, and
the keyboard. This `.rbf` is the hardware-verified MiSTer artifact in
Release 2 (`../RELEASE-NOTES-release2.md`).

**Framework cost, for reference** (measured 27-AUG-2026 from the bare template,
before any ND-120 RTL - the floor every figure sits on):

| Resource | Framework alone | Device |
|---|---|---|
| ALMs | 7,232 | 41,910 (17%) |
| Block RAM | 59 | 553 |
| DSP | 33 | 112 |
| PLLs | 3 | 6 |

**This board was the priority (Ronny, 28-AUG-2026)**; that goal is now met. The
sections below are the phase-by-phase bring-up history, kept for the record.

### Build 1 - the console, with no ND-120 in it (28-AUG-2026)

Ronny's call was to reach "CPU + BRAM + terminal console" in **two** builds
rather than one, so that a black screen has only one possible cause at a time.
Build 1 is the first half: the terminal only.

What it does when it runs: prints a self-test message, then echoes what you
type. No ND-120 is compiled in at all.

| Piece | Where |
|---|---|
| Board glue | `rtl/nd120_console_mister.v` |
| Its testbench | `sim/nd120_console_mister_tb.v` (`cd sim && make test-console`) |
| The terminal itself | `../../Terminals/` - shared, unchanged, not copied |
| Pixel clock | 40.000 MHz for 800x600@60, from the template PLL retuned in place |

**Why a banner and not just an echo.** The message turns one useless symptom
into two useful ones. Text on screen means the clock, the sync timing, the font
ROM, the character RAM, the scroll mapping and the whole write path all work,
so a keyboard that does nothing is the keyboard. No text at all means the video
half. Without it, "nothing happens" costs a build cycle to narrow down - cheap
here, expensive on the MEGA65 where the board belongs to someone else.

**Status: simulated, never synthesized, never on hardware.** The testbench
passes and Verilator lint is clean, which is not the same as Quartus accepting
it. The three things most likely to bite, in order:

1. **The font path.** `$readmemh` resolution differs between Vivado and
   Quartus and the Quartus rule is NOT verified here - so the build covers both
   (a `SEARCH_PATH` in `nd120.qsf` and a `make font` copy into the project
   directory). Blank boxes instead of glyphs means neither worked.
2. **The PLL.** `rtl/pll/pll_0002.v` was retuned from 20 to 40 MHz by editing
   the `output_clock_frequency0` string. Quartus recomputes the counters from
   it, so no GUI round trip is needed - but this has not been through Quartus
   yet, and a regeneration of the IP would silently undo it.
3. **The video mode.** 800x600@60 goes to the framework scaler, which is
   documented to take arbitrary timings. Not verified on this framework.

Test on hardware by looking at the screen and typing. There is nothing to
measure and no host tool involved, which is the point.

What landed:

| File | State |
|---|---|
| `sys/` | MiSTer framework, copied as-is from Template_MiSTer. **Never edit** - framework updates erase changes |
| `rtl/` | `nd120_console_mister.v` + the PLL IP (retuned to 40 MHz). The template's demo core (`mycore.v`, `lfsr.v`, `cos.sv`) is no longer in the build - the files are still on disk but nothing references them |
| `nd120.qpf/.qsf/.sdc/.srf/.sv` | renamed from `Template.*`; `PROJECT_REVISION = "nd120"`, OSD core name `"ND120;;"` |
| `nd120.qsf` | carries `VERILOG_MACRO "FPGA_FF_MODE=1"` (and deliberately NOT `VERILATOR_SIM`) |
| `files.qip` | the console glue + the shared terminal core, referenced in place under `../../Terminals/` rather than copied. The ND-120 sources join it in build 2 |
| `Makefile` | real Docker/Quartus flow: `make build`, `make check`, `make clean`, `make load` |

**Licence note (decided 27-AUG-2026, Ronny):** this repo is MIT; the MiSTer
framework in `sys/` is **GPL-2.0** (`LICENSE-MiSTer-framework-GPLv2`), and every
MiSTer core must ship `sys/` as-is, so the two licences sit in one repo. That is
accepted for now - it keeps the work in one place. Standard MiSTer practice is
one repo per core, so **if this core is ever released, split it out then**.

**Prerequisite for phase 2:** the latch-to-FF / clock-enable work must boot on
FPGA - Cyclone V has the same constraints as the Artix-7 (no transparent
latches, no internal tri-states, no gated clocks), so `FPGA_FF_MODE` carries
over directly. That prerequisite is now **met on other boards** (SINTRAN boots
on Tang Nano 20K and Nexys 4 DDR), so this is no longer a blocker.

## Build

Quartus Prime Lite **17.0.2** exactly - MiSTer standardizes on it; newer
Quartus breaks the project files and buys nothing on Cyclone V. Nothing needs
installing on the host: the community image `raetro/quartus:17.0`
(<https://github.com/raetro/sdk-docker-fpga>) carries that version.

```bash
# from Verilog/fpga/mister/, in WSL (needs the docker daemon running)
make check     # is docker up, is the image pulled, is the project intact
make build     # -> output_files/nd120.rbf
make load      # scp the .rbf to the MiSTer  (MISTER=root@... to override)
```

The Quartus GUI is needed for **adding** PLL output clocks (that changes the
port list) and for SignalTap. It is NOT needed to change a PLL *frequency* -
that is a string parameter in `rtl/pll/pll_0002.v` which altera_pll turns into
counter settings at synthesis, and it is how the 40 MHz pixel clock was set.
This README claimed otherwise until 28-AUG-2026.

## Port plan

1. **Skeleton** (scaffolded): compile the template, see "ND120" in the OSD,
   blink `LED_USER` off the PLL, bytes out of `UART_TXD`.
2. **ND-120 boots:** instantiate `ND3202D` inside `emu`, one PLL (50 MHz in ->
   CPU/bus domain), small BRAM RAM config, OPCOM UART on the framework serial.
   Milestone: OPCOM prompt.
3. **Menu + microcode from file:** CONF_STR options; WCS/EPROM images through
   the `ioctl` download path instead of baked-in hex.
4. **Memory + disks:** 6 MB (`ramSize=2`) via the **SDRAM add-on module**
   (Ronny has one, 27-AUG-2026) - closest to the Tang Nano 20K SDRAM bridge
   that already works, so that experience transfers. HPS DDR3 (`DDRAM_*`, the
   ao486 pattern) stays the fallback. Then floppy/SMD controllers speaking the
   `sd_rd`/`sd_wr`/`sd_buff` 512-byte block protocol against Linux-mounted
   image slots. Milestone: SINTRAN boots from an image file on the SD card.
5. **Console on the machine itself:** screen + keyboard instead of a USB serial
   cable - see **[`../../Terminals/docs/PLAN-vt100-terminal-core.md`](../../Terminals/docs/PLAN-vt100-terminal-core.md)**.
   Shared with the MEGA65 port. `hps_io` hands us `ps2_key` for free.

## Why this board goes first (28-AUG-2026)

Ronny's call, and there is a hardware reason behind it beyond "he owns one".

**The feedback loop.** This board is on his desk, so a bad bitstream costs
minutes. The MEGA65 has to be tested by friends who own boards - every round
trip there is days, and you cannot debug interactively at all. Anything that
can be found on hardware he controls should be found here first.

**The SDRAM path is genuinely shared.** Verified 28-AUG-2026 from
`sys/emu_ports.vh:112-122`: the MiSTer SDRAM add-on is **16-bit DQ, 13-bit
address, 2-bit bank** - the same interface shape as the MEGA65 R4+ part
(32M x 16 SDR on plain fabric pins, see `../mega65/docs/00-plan.md`). Both are
ordinary SDR SDRAM on FPGA pins, unlike the Nexys's DDR2-behind-a-MIG. So the
`nd_sdram_port` adapter and the controller behind it are **one piece of work
serving two boards**, and debugging it here means the MEGA65 inherits a memory
path that has already met real silicon.

That is the strongest argument for this ordering: the memory backend is
exactly where the silicon-only bugs live (the Nexys DDR2 grew three before
SINTRAN booted, and the Tang's bank-decode fault was invisible in Verilator).
Sending friends a bitstream whose memory path has never met hardware is asking
them to debug our worst class of bug remotely.

**Controller choice follows the MEGA65 decision, for the same reason:**
MJoergen/SDRAM (MIT, Avalon-MM) rather than MiSTer's own `sdram.sv`, which is
GPL and would not travel to the MEGA65. Note that `sdram.sv` is a *per-core*
file on MiSTer, not part of `sys/` - confirmed by its absence from `sys/` in
this tree - so nothing forces us to use theirs.

## Reference cores

- [PDP2011_MiSTer](https://github.com/MiSTer-Enhanced/PDP2011_MiSTer) - a
  maintained MiSTer core of a 1970s minicomputer with disk images, a serial
  console AND a built-in VT100/VT105 terminal, switched by an OSD bit. The
  closest thing to what we are building; dissected in
  [docs/05-devices-block-char.md](docs/05-devices-block-char.md). **Its
  terminal files are non-free (personal/non-commercial only) - reference only,
  never vendored.** See the terminal plan for what that means in practice.
- ao486 - the DDR3 main-memory pattern.
- Template: <https://github.com/MiSTer-devel/Template_MiSTer>
- emu module: <https://mister-devel.github.io/MkDocs_MiSTer/developer/emu/>

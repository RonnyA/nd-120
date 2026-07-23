# ND-120 on QMTECH XC7A35T SDRAM core board (planned side experiment)

**Full path:** `/mnt/e/Dev/Repos/Ronny/nd-120/Verilog/fpga/qmtech-a35t/`

Side experiment; **Basys3 stays the main Artix-7 target.** The point of this
board: same FPGA die as the Basys3 but with 32 MB SDRAM on board, which removes
the Basys3's 24 KB BRAM main-memory limit.

## Status

**PAUSED (2026-07-08)** - side experiment shelved for now; resume with
[`HANDOFF-qmtech-a35t-bringup.md`](HANDOFF-qmtech-a35t-bringup.md)
(exact next actions + stage-3 design notes).

Stages 1 and 2 are written and sim-verified, nothing hardware-verified yet:
the LED smoke test lints clean, and the mem-test port **passes its iverilog
testbench** (all 8 vectors, serial stream decodes to PASS). Both build and
JTAG-program with one `vivado -mode batch -source build.tcl` each.

## Files

| File | Purpose |
|------|---------|
| [`Makefile`](Makefile) | Standard board API (see [`../README.md`](../README.md) "Building"): `make [TEST=led-test\|mem-test]` = bitstream only, `make load` = build + JTAG program, `make sim` = run the mem-test testbench (passes), `make clean`. |
| [`board-pins.xdc`](board-pins.xdc) | Reference pin map - every pin confirmed from the vendor XDCs/manual (50 MHz clock `R2`, LEDs `C8`/`D8` **active-low**, key `H18`, full 39-pin SDRAM map, config properties). Copy ports from here; don't re-derive. Includes commented placeholders for future OPCOM UART header pins. |
| [`led-test/`](led-test/) | Stage-1 smoke test: `led_test_top.v` (1 Hz heartbeat on `led_n[0]`, key echo on `led_n[1]`), `led_test.xdc`, `build.tcl` (in-memory synth -> impl -> bitstream -> JTAG program, modeled on [`../basys3/mem-test/build.tcl`](../basys3/mem-test/build.tcl)). Run on the Windows host: `vivado -mode batch -source build.tcl` |
| [`mem-test/`](mem-test/) | Stage-2: port of [`../basys3/mem-test/`](../basys3/mem-test/) (same FSM/vectors/`MEM_RAM_49`, directly comparable with the Basys3 run that passes on silicon). 50 MHz MMCM math; no UART pin - `msg_printer` TX is an internal `mark_debug` net for ILA; result on the LEDs: running = fast blink, PASS = 1 Hz blink, FAIL = both solid. Sim: `cd mem-test/sim && iverilog -g2012 -DNO_MMCM -o tb qmtech_mem_test_tb.v ... && vvp tb` (passes). |
| [`docs/`](docs/) | Local copies of the vendor user manual + board schematic, and [`docs/board-notes.md`](docs/board-notes.md) - the distilled analysis of both plus the vendor SDRAM/LED sample projects. |

Hardware notes discovered while writing these (from the schematic/manual):
LEDs are **active-low** (3V3 -> 1k -> LED -> pin; drive 0 = lit); only 2 of
the "4 LEDs" are user-drivable (the others are the 3.3 V power indicator and
`FPGA_DONE`); the key on `H18` is active-low with a 4.7k pull-up; JP2/JP3
net names are `IO_<pin>` so header pins map straight to FPGA pins, but
**pin 1 = USB_5V and pin 2 = 3V3 on both headers** - don't wire signals there.

## Board facts

Source: official QMTECH repo
<https://github.com/ChinaQMTECH/QMTECH_XC7A15T_35T_CSG325_CORE_BOARD>
(schematic `Hardware/QMTECH_XC7A15T_35T_50T_CSG325_SDRAM_V1.pdf`, sample
projects with full pin XDCs under `Software/`).

- **FPGA:** XC7A35T-1CSG325C - the **same die** as the Basys3 `xc7a35t`, only
  the package differs. Vivado part string: `xc7a35tcsg325-1`. Anything that
  synthesizes / meets timing / gets fixed on the Basys3 applies here unchanged.
- **Clock:** 50 MHz crystal on pin `R2` (Basys3 is 100 MHz - MMCM settings
  differ, the target CPU/bus frequency does not).
- **SDRAM:** 32 MB Winbond `W9825G6KH-6`, **16-bit** data bus. Same chip family
  as the Tang Nano 20K `sdram-test` that already passes on hardware, but the
  Tang bridge ([`../tang-nano-20k/sdram-bridge/`](../tang-nano-20k/sdram-bridge/README.md))
  assumes a 32-bit SDRAM word - this board needs a **burst-of-2 variant**
  (two 16-bit beats per 18-bit ND word: data beat + parity beat).
- **Main-memory target:** 2 MB (1M ND words = 4 MB of the 32 MB chip).
- **I/O:** 4 user LEDs (sample XDC: `C8`, `D8`), 3 switches (reset on `H18`),
  two 50-pin 2.54 mm headers, Micro-SD slot, 8 MB `N25Q064A` SPI flash for
  standalone boot.
- **No on-board USB-UART.** Programming and debug go over JTAG (6-pin header,
  Xilinx Platform Cable USB II): bitstream + SPI flash, ILA and VIO all work
  through it, so the existing [`../basys3/`](../basys3/README.md) `ila_*.tcl`
  workflow carries over. OPCOM console options:
  1. BSCANE2-based JTAG-UART bridge,
  2. VIO character poking (manual, bring-up only),
  3. OPCOM TX/RX on header pins to an external 3.3 V USB-serial adapter -
     put those pins in the XDC from day one.

## Planned bring-up order

1. Board files here: XDC translated from the QMTECH sample project +
   build script adapted from [`../basys3/`](../basys3/README.md). *(done -
   `board-pins.xdc`, `led-test/build.tcl`)*
2. LED smoke test (clock + JTAG programming proven). *(written, awaiting a
   run on the board)*
3. Port of the standalone [`../basys3/mem-test/`](../basys3/README.md)
   (same die - should behave identically).
4. 16-bit SDRAM bridge variant: protocol testbench first, then a standalone
   hardware test like the Tang's `sdram-test`.
5. Full ND-120 build with SDRAM main memory (2 MB).

## See also

- [`../README.md`](../README.md) - all FPGA targets
- [`../basys3/README.md`](../basys3/README.md) - same die, same Vivado flow
- [`../tang-nano-20k/sdram-bridge/README.md`](../tang-nano-20k/sdram-bridge/README.md) -
  SDRAM bridge to derive the burst-of-2 variant from

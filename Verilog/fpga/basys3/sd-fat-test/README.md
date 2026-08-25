# Basys3 SD-FAT test - SD-card Pmod on JB (top-right connector)

**Full path:** `Verilog/fpga/basys3/sd-fat-test/`
**Date:** 13-JUL-2026. Basys3 port of the hardware-proven Tang Nano 20K
SD-FAT test (`Verilog/fpga/tang-nano-20k/sd-fat-test/`).
The test design and all SD/FAT RTL are reused unchanged from
`Verilog/SD-FAT/circuit/` and the Tang `sd-fat-test/src/`; only this thin
wrapper (MMCM + pins) is Basys3-specific.

## Hardware setup

1. Plug the SD Pmod (Digilent Pmod MicroSD or Pmod SD - same pin mapping)
   into **Pmod JB - the TOP-RIGHT Pmod connector** (JA is upper-left,
   JC lower-right, JXADC is the analog one next to the 7-segment display;
   JXADC is deliberately NOT used - its anti-alias filter routing "might
   limit the data speeds when used for digital signals" per the Basys3
   reference manual).
2. Card: same recipe as the Tang test - FAT32 stick with `BOOT.BPUN`,
   pre-created `TEST.TXT` and `IO.DAT` (see
   `Verilog/fpga/tang-nano-20k/sd-fat-test/README.md`
   for the exact card preparation and the WRITE-PATH SAFETY POLICY in
   `Verilog/SD-FAT/README.md`).
3. USB cable to the Basys3 micro-B (J4): serial console at **9600 8N1**
   (same FT2232 COM port as JTAG). Menu prompt `#`: 1=LIST, 2=DUMP,
   3=COPY, 4=WRBLK1, speed tests, H=help.
4. btnC (center) = full reset (S1). btnU = same (S2). LEDs LD0-LD5 mirror
   the Tang's status LEDs (polarity converted to Basys3 active-high).

## Build + program (Windows host with Vivado)

```
cd Verilog/fpga/basys3/sd-fat-test
vivado -mode batch -source build.tcl              # build + JTAG program
vivado -mode batch -source build.tcl -tclargs -noburn   # build only
```
Bitstream: `basys3_sd_fat.bit` in this directory (volatile JTAG load, like
`../mem-test`). Reports: `util.rpt`, `timing.rpt`.

## Design notes

- **Clock:** MMCM makes 27.027 MHz from the 100 MHz crystal (VCO 1000 MHz
  / 37). `CLK_FREQ = 27_027_027` is passed exactly, so every divider,
  baud rate and watchdog stays at the Tang-proven values (SD init
  ~137 kHz, 4-bit data phase ~13.5 MHz, 0.1% off nominal - well inside
  UART and SD tolerances). Reset is held until MMCM lock.
- **Pull-ups:** the stack needs CMD/DAT0-3 idling high when released
  (DAT3 high at CMD0 keeps the card in SD mode). The Tang board had
  external 10K pulls; here the FPGA internal pull-ups are enabled in the
  XDC (`PULLUP true`) so the design works regardless of which pulls the
  Pmod module carries.
- **Pinout (Pmod JB / Digilent SD Pmod):**

  | Pmod pin | Signal | JB pin | FPGA |
  |---|---|---|---|
  | 1 | ~CS / DAT3 | JB1 | A14 |
  | 2 | MOSI / CMD | JB2 | A16 |
  | 3 | MISO / DAT0 | JB3 | B15 |
  | 4 | SCK | JB4 | B16 |
  | 7 | DAT1 | JB7 | A15 |
  | 8 | DAT2 | JB8 | A17 |
  | 9 | CD (card detect) | JB9 | unused |

- **Simulation:** the test design's self-checking tbs are board-agnostic
  and already registered (`Verilog/tests/run_all_tests.sh` sd-fat entries);
  this wrapper adds only Xilinx primitives (MMCM/BUFG) and is validated by
  the Vivado build + hardware, like `../mem-test` and the main CPU top.
- After bring-up, eyeball the synthesis log for the `sd_cmd`/`sd_dat*`
  IOBUF inferences (Vivado handles the top-level ternary tristates
  correctly, unlike the yosys collapse documented in
  `Verilog/fpga/tang-nano-20k/sd-fat-test/sim/check_tristate.py`
  - verify, don't assume).

## Scope

This proves card + Pmod + the full SD/FAT stack on the Basys3. It does
NOT bring `nd_storage` (the ND-120 disk-image cache) to the Basys3: that
architecture preloads images into the Tang's 8 MB SDRAM, and the Basys3
has no external RAM. Basys3 ND-120 storage needs the tag-based-cache mode
(storage plan Phase 4) or a UART sector-server - see
`Verilog/docs/usb-storage-options.md`.

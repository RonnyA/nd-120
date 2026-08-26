# Quickstart - ND-120 on the Digilent Nexys 4 DDR (Nexys A7-100T)

Run the 1988 Norsk Data ND-120 on this board from a ready-built bitstream -
no FPGA toolchain needed. Two deployment paths: **USB** (proven, used for
every build in this repo) and **microSD card** (vendor-documented,
verification on our hardware pending - see the banner in that section).

What you need:

- Digilent Nexys 4 DDR (also sold as Nexys A7-100T)
- A micro-USB cable (the PROG/UART port powers the board and carries both
  programming and the serial console)
- A microSD card, FAT32 (for the disc image - and, on the SD path, the
  bitstream too)
- A serial terminal program (picocom, PuTTY, TeraTerm, ...)
- A bitstream from the GitHub Release. The filename tells you the CPU
  clock and the console speed:
  - `nd120_nexys4ddr_45MHz_115200.bit` - fast build, console 115200
  - `nd120_nexys4ddr_16MHz_9600.bit` - safe build, console 9600

## Console settings (both paths)

The machine talks **7 data bits, EVEN parity, 2 stop bits**, no flow
control. Baud comes from the bitstream filename.

```
picocom -b 115200 -y e -d 7 -p 2 /dev/ttyUSB1     # fast build
picocom -b 9600   -y e -d 7 -p 2 /dev/ttyUSB1     # safe build
```

PuTTY: Serial, speed as above, 7 data bits, parity Even, 2 stop bits,
flow control None. On Windows the board's COM port appears when the
USB cable is plugged in (Device Manager -> Ports).

If every character shows as `?` or accented garbage, the terminal is
open at 8N1 - the parity bit is being read as data. Fix the framing,
not the cable.

## Path 1: USB (proven)

### 1a. Volatile load over JTAG - gone at power-off

Best for trying things out. Two tool options:

**Vivado Lab Tools** (free, no licence, ~3 GB; or any full Vivado):

1. Install "Vivado Lab Edition" from AMD/Xilinx.
2. Open Hardware Manager -> Open target -> Auto connect.
3. Program device -> pick the downloaded `.bit` -> Program.

This is exactly what this repo's own flow does
(`nexys4ddr/program_only.tcl`), so it is the path with hundreds of
successful uses behind it.

**openFPGALoader** (small, open source; in oss-cad-suite, or
`apt install openfpgaloader` / `brew install openfpgaloader`):

```
openFPGALoader --detect                 # confirm it sees the board
openFPGALoader -b nexys_a7 <file>.bit   # volatile SRAM load
```

Not yet exercised on this board in this project - if `-b nexys_a7` is
not accepted by your version, `--detect` prints the FTDI cable and
`--list-boards` the supported names.

### 1b. Persistent - write the onboard QSPI flash, survives power-off

In Vivado (Lab) Hardware Manager: Add Configuration Memory Device on the
xc7a100t (the Nexys 4 DDR carries a Spansion S25FL128S quad-SPI flash),
point it at the `.bit` (Vivado converts internally), program, then set
jumper **JP1 to QSPI**. From then on the board boots the ND-120 at every
power-on with no PC attached. To go back to a plain board, reprogram the
flash or move JP1 back.

### 2. Disc image and boot

1. Copy a Winchester disc image onto the FAT32 microSD (root directory)
   and insert it. The image is **not** part of the release - it contains
   SINTRAN III, which is not this project's to distribute. The ND software
   preservation community keeps images; `ndtool` builds and inspects them.
2. Open the terminal (settings above). You are at the machine's OPCOM
   console - that is the no-image smoke test: press ENTER and the
   microprogram answers. This proves the bitstream and the console.
3. Boot the operating system: type `20500&`
4. First output within ~30 s, `SINTRAN III RUNNING` and the Watchdog
   banner shortly after. Log in and enjoy 1988.

## Path 2: microSD card - no software on the PC at all

> **STATUS: vendor-documented, NOT yet verified on this project's
> hardware.** The Digilent Nexys 4 DDR reference manual (section "FPGA
> Configuration") states the board's config controller loads a `.bit`
> from a FAT-formatted microSD at power-on. What has NOT been tested
> here yet: that path with OUR bitstream, and the hand-over of the SD
> slot to the running design afterwards (the ND-120 uses the same card
> for its disc image). This section will be tightened after that test;
> until then, treat it as the manual's claim, with Path 1 as the
> known-good fallback.

The idea, per the reference manual:

1. Format the microSD FAT32. Copy **both** files to the root:
   - the `.bit` (the manual warns config picks a `.bit` it finds - keep
     exactly ONE .bit on the card)
   - the Winchester disc image
2. Move jumper **JP1** to the **USB/SD** position (it sits next to the
   JTAG header; the three positions are JTAG / QSPI / USB-SD).
3. Insert the card, power the board on. The BUSY/DONE LED behaviour
   during config is described in the manual; configuration from SD takes
   a few seconds for a 3.8 MB bitstream.
4. Open the terminal exactly as in Path 1 and continue from the OPCOM
   smoke test.

Points the pending hardware test must settle (the manual is thin here):

- whether the config controller and the ND-120's SD/FAT stack coexist on
  one card (config releases the slot to the fabric after DONE - measured
  behaviour wanted, not assumed);
- whether the disc-image file's presence confuses the `.bit` search;
- exact JP1/JP2 jumper positions on this board revision, photographed.

## Troubleshooting

| Symptom | Cause |
|---|---|
| Terminal shows `?`-garbage | 8N1 framing - set 7 bits, EVEN parity, 2 stop bits |
| Nothing on the terminal at all | Wrong baud for the bitstream (read the filename), or wrong COM/tty (the board exposes one port; on Linux usually `/dev/ttyUSB1`) |
| OPCOM answers, `20500&` prints nothing | No disc image on the card, image not in the FAT root, or card not FAT32 |
| Board dark after power-cycle | The JTAG load (path 1a) is volatile - use 1b (QSPI) or path 2 (SD) for persistence |
| LD16 lit red | The DDR2 watchdog tripped - power-cycle; if it repeats, report it with the LED/7-segment state (`nexys4ddr/DEBUG-PANEL.md`) |

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
  clock; the console is 115200 on every release file:
  - `nd120_nexys4ddr_45MHz_115200.bit` - fast build (45.45 MHz CPU)
  - `nd120_nexys4ddr_16MHz_115200.bit` - safe build (16.667 MHz CPU,
    large timing margin - try this one if the fast build misbehaves)

## Console settings (both paths)

The machine talks **115200 baud, 7 data bits, EVEN parity, 2 stop bits**,
no flow control - the same setting for every release bitstream.

```
picocom -b 115200 -y e -d 7 -p 2 /dev/ttyUSB1
```

PuTTY: Serial, 115200, 7 data bits, parity Even, 2 stop bits, flow
control None. On Windows the board's COM port appears when the USB cable
is plugged in (Device Manager -> Ports).

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

> **STATUS: NOT yet verified on this project's hardware.** The steps
> below are read straight from the board's reference manual
> (`nexys4ddr/docs/nexys4ddr_rm.pdf`, section 3.3 "USB Host and MicroSD
> Programming" and the Figure 3 callouts), so the jumpers and LED
> behaviour are the vendor's word, not guesswork. The one thing the
> manual does NOT answer and only a test on this board can: whether the
> config controller hands the SD slot cleanly to the running ND-120,
> whose SD/FAT stack then mounts the disc image on the SAME card. Until
> that run passes, Path 1 is the known-good fallback.

Steps, per the reference manual:

1. Format the microSD FAT32. Copy **both** files to the root:
   - **exactly ONE `.bit`** - the manual requires "a single .bit
     configuration file in the root directory". A `.bit` built for a
     different FPGA part is rejected, so a wrong-board file fails safe.
   - the Winchester disc image (the ND-120's requirement - its FAT
     reader only looks in the root)
2. Two jumpers, one-time:
   - **JP1** (Programming Mode, callout 16 - up by the mode/DONE LEDs):
     set to **USB/SD**
   - **JP2** (Media Select, callout 3 - next to the microSD slot): set
     to the **SD** side (it chooses microSD vs USB pen drive)
3. Insert the card, power on (or push the **PROG** button). The
   **BUSY** LED is steady while the card is read, pulses slowly if no
   medium is found, and **DONE** lights when configuration succeeds -
   a few seconds for a 3.8 MB bitstream.
4. Open the terminal exactly as in Path 1 and continue from the OPCOM
   smoke test.

What the pending hardware test must still settle:

- the SD-slot hand-over: config controller done, ND-120's own SD/FAT
  stack mounts the disc image from the same card (measured, not assumed);
- that the disc-image file next to the `.bit` does not disturb the
  single-`.bit` search.

## Troubleshooting

| Symptom | Cause |
|---|---|
| Terminal shows `?`-garbage | 8N1 framing - set 7 bits, EVEN parity, 2 stop bits |
| Nothing on the terminal at all | Wrong baud (release builds are all 115200; bitstreams older than 26-AUG-2026 were 9600), or wrong COM/tty (on Linux usually `/dev/ttyUSB1`) |
| OPCOM answers, `20500&` prints nothing | No disc image on the card, image not in the FAT root, or card not FAT32 |
| Board dark after power-cycle | The JTAG load (path 1a) is volatile - use 1b (QSPI) or path 2 (SD) for persistence |
| LD16 lit red | The DDR2 watchdog tripped - power-cycle; if it repeats, report it with the LED/7-segment state (`nexys4ddr/DEBUG-PANEL.md`) |

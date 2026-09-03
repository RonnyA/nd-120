# Nexys 4 DDR board check

**Full path:** `Verilog/fpga/nexys4ddr/board-test/`
**Date:** 20-AUG-2026.

A small design that proves the board resources the ND-120 build depends on,
so that a later failure can be blamed on the CPU instead of the hardware.
Nothing from the ND-120 design is compiled here.

> **Status:** UART paths verified in simulation (banner, echo, BTNC report all
> come out correctly at 9600 baud against a bit-level decoder). The board
> itself is now a known-good, deployed platform - it boots SINTRAN III from
> the full ND-120 build - so this harness is here for bringing up a *fresh*
> board, not for proving the design.

## What it proves

| Resource | How |
|---|---|
| 100 MHz oscillator + MMCM | The same MMCM shape the ND-120 build uses (VCO 1000 MHz / 60 = 16.667 MHz). Green tri-colour LED16 = locked. Nothing else runs if it fails. |
| All 16 switches, all 16 LEDs | Each switch lights its LED - the factory demo's behaviour, so the two tests can be compared directly |
| All 8 seven-segment digits, all segments | Default: a 32-bit hex counter, so every digit and every segment changes. `SW15` up: every segment and both decimal points lit at once |
| 5 buttons | Pressing any button shows the button bits + switch value on the display and lights LED17 green |
| CPU RESET button (active low) | Held down = counter frozen and banner re-sent on release |
| USB-UART, 9600 8N1 | Banner on reset, every typed character echoed, BTNC prints `SW=xxxx CD=x` |
| microSD slot | `SD_RESET` driven low (slot powered) and the card-detect line reported on LED16 red and in the `CD=` field. **The polarity of `SD_CD` is not stated in the reference manual** - insert and remove a card while watching LED16 red, and that settles it. |

Not covered here: DDR2, VGA, Ethernet, accelerometer, temperature sensor,
microphone, audio, USB-HID. The **factory demo already in the board's QSPI
flash** covers those - run it first, see `../README.md`.

## Build and program

```bash
cd Verilog/fpga/nexys4ddr/board-test
make            # build + JTAG program
make build      # build only
```

Or on the Windows host:

```powershell
vivado -mode batch -source build.tcl                    # build + program
vivado -mode batch -source build.tcl -tclargs -noburn   # build only
```

## Expected result

1. Connect the USB cable to J6 and open the board's COM port at **9600 8N1**.
   On this machine that is **COM11** from Windows, or `/dev/ttyUSB*` from WSL
   after `../usb-attach.sh`. Either works - see the console section in
   `../README.md`:

   ```bash
   powershell.exe -NoProfile -ExecutionPolicy Bypass -File ../console.ps1 -Seconds 60
   # or, from WSL:
   ../usb-attach.sh && picocom -b 9600 /dev/ttyUSBn
   ```
2. Program the board. Within a second the terminal shows:

```
NEXYS4DDR BOARD CHECK
MMCM 16.667MHz LOCKED
Type - chars echo. BTNC = switches.
```

3. LED16 lights green (MMCM locked); LED17 blinks blue about once a second.
4. Move each of the 16 switches - the LED above it follows.
5. The 7-segment display counts in hex on all eight digits.
6. Flip `SW15` up - every segment of every digit lights, decimal points
   included. A missing segment here is a hardware fault.
7. Type characters in the terminal - each one comes back.
8. Press **BTNC** - the terminal prints `SW=xxxx CD=x`, where `xxxx` is the
   switch value in hex and `CD` is the microSD card-detect line.
9. Press the red **CPU RESET** button - the banner is printed again on release.

Any step that fails is a board, cable, constraint or toolchain problem. Fix it
before building the ND-120 bitstream, or the CPU debugging will be chasing a
hardware fault.

# Tang Nano 20K SDRAM test

**Full path:** `Verilog/fpga/tang-nano-20k/sdram-test/`

> **Status: PASSES on hardware - full 8 MB.** 2026-07-08: OSS-flow bitstream
> loaded over usbipd/WSL2, runs observed on the board's UART at 9600 - all 4
> verbose read/writes OK, and the block test now covers **all 8 MB**
> (write + verify, progress dot per 256 KB), `PASS`, repeatable. The iverilog
> testbench passes with the same sources. The Gowin EDA flow is set up but not
> yet exercised.

A small standalone project that proves the Tang Nano 20K's **8 MB embedded
SDRAM** works with the [nand2mario SDRAM controller](https://github.com/nand2mario/sdram-tang-nano-20k)
before we wire that controller into the ND-120 memory system (`MEM_RAM_49.v`).
Every memory operation is reported over **UART at 9600 baud 8N1** using the
UART TX/RX state machines borrowed from the ND-120's own
`Verilog/Shared/support/SC2661_UART.v`, so you can watch reads and writes
happen on a serial terminal.

## Board hardware (Sipeed Tang Nano 20K)

Reference: [Sipeed wiki hardware page](https://wiki.sipeed.com/hardware/en/tang/tang-nano-20k/nano-20k.html)
- datasheets/schematics at [dl.sipeed.com](https://dl.sipeed.com/shareURL/TANG/Nano_20K/)
- examples at [sipeed/TangNano-20K-example](https://github.com/sipeed/TangNano-20K-example).

| Item | Value |
|------|-------|
| FPGA | Gowin **GW2AR-LV18QN88C8/I7** (GW2AR-18, QN88 package) |
| Logic | 20,736 LUT4, 15,552 FF, 48 18x18 multipliers, 2 PLLs, 8 I/O banks |
| BSRAM | 828 Kbit (46 blocks) + 41,472 bit shadow SRAM |
| SDRAM | **64 Mbit (8 MB), 32-bit SDR**, embedded in the FPGA package |
| Config flash | 64 Mbit (bitstream storage) |
| Clocks | 27 MHz crystal + **MS5351** clock generator (3 extra clocks, controlled by the BL616) |
| USB | **BL616** MCU: JTAG programmer + USB-UART + USB-SPI + MS5351 control |
| Display | HDMI + 40-pin RGB LCD connector |
| Storage | TF-card slot |
| Audio | MAX98357A PCM amplifier |
| UI | 6 LEDs (active low), 1 WS2812 RGB LED, 2 buttons (S1, S2) |
| Size | 22.55 mm x 54.04 mm |

Pins used here (from the Sipeed examples, confirmed in
`TangNano-20K-example/uart`): 27 MHz clock = pin 4, S1 = pin 88,
UART TX -> BL616 = pin 69, UART RX <- BL616 = pin 70, LEDs = pins 15-20.
The SDRAM has **no package pins** - in the Gowin EDA flow the "magic" top-level
port names (`O_sdram_*`, `IO_sdram_dq`) are connected to the SDRAM die
automatically; the OSS flow must pin them explicitly (see below).

## Factory firmware: LiteX BIOS

Out of the box the board's flash contains a **LiteX SoC** (VexRiscv_Min @
48 MHz) from the `litex/` folder of
[sipeed/TangNano-20K-example](https://github.com/sipeed/TangNano-20K-example)
(local clone: `/home/ronny/repos/TangNano-20K-example`, prebuilt bitstream
`litex/tang_nano_20k_litex.fs`). It talks on the BL616 USB serial at
**115200** baud and its BIOS has `mem_test`, `mem_speed`, `sdram_test`
commands - a handy independent cross-check of the SDRAM hardware.

Useful facts from its boot report (observed on our board, 2026-07-08):

- SDRAM runs at **48 MHz, CL-2 CWL-2**, memtest of 2 MB passes -
  independently confirming the CL=2 timing the nand2mario controller uses.
- Measured speed: write 12.9 MiB/s, read 16.1 MiB/s (CPU-bound, not a
  controller limit).
- Memory map: ROM `0x00000000` (128 KB), SRAM `0x10000000` (8 KB),
  **MAIN_RAM `0x40000000` (8 MB = the SDRAM)**, CSR `0xf0000000`.

Loading this test into **SRAM** (`make load` / openFPGALoader without `-f`) is
volatile and leaves the factory image alone. Writing **flash** (`make flash`)
replaces LiteX - restore it with
`openFPGALoader -b tangnano20k -f /home/ronny/repos/TangNano-20K-example/litex/tang_nano_20k_litex.fs`.

## What the test does

1. After power-up it prints a banner + prompt and waits for **S1** or **any
   UART character**.
2. Verbose demo - shows single-byte reads/writes: writes 4 bytes to 4 spread
   addresses (bank 0, bank 1, last byte of the 8 MB), reads them back, prints
   every operation.
3. Block test - writes **all 8 MB** with an address-derived pattern, reads it
   back and verifies every byte, with a progress dot every 256 KB (32 dots per
   phase). Auto-refresh runs every 15 us throughout, so retention is tested
   too. Takes a few seconds per phase.
4. Prints `PASS` or `FAIL` (also shown on the LEDs: `{error, pass, state}`
   active low). Press S1 / any key to run again.

Expected terminal output (9600 8N1 on the board's USB COM port):

```
ND120 TN20K SDRAM TEST 9600-8N1
PRESS S1 OR ANY KEY
W 000000=A5
W 000001=5A
W 200000=3E
W 7FFFFF=ED
R 000000=A5 OK
R 000001=5A OK
R 200000=3E OK
R 7FFFFF=ED OK
WRITE BLOCK
................................VERIFY BLOCK
................................
PASS
```

## Files

| File | Purpose |
|------|---------|
| `src/sdram_test_top.v` | Test state machine, clocking, refresh scheduling |
| `src/sdram.v` | **Vendored** nand2mario SDRAM controller (Apache-2.0, `src/LICENSE.nand2mario`), byte-based, CL=2, auto-precharge |
| `src/gowin_rpll/gowin_rpll.v` | **Vendored** rPLL config: 27 MHz `clkout` + 180-degree `clkoutp` for the SDRAM |
| `src/uart_tx.v`, `src/uart_rx.v` | 8N1 UART, state machines borrowed from `Verilog/Shared/support/SC2661_UART.v` |
| `src/msg_printer.v` | Formats "W aaaaaa=dd" / "R aaaaaa=dd OK" lines and fixed messages |
| `src/nano20k.cst` | Package pins (clock, S1, UART, LEDs) |
| `src/sdram_pins_oss.cst` | Embedded-SDRAM pseudo-pins - **OSS flow only** (from [Seyviour/sdram-tang-nano-20k-os-example](https://github.com/Seyviour/sdram-tang-nano-20k-os-example)) |
| `sdram_test.gprj` | Gowin EDA project |
| `Makefile` | OSS flow: yosys -> nextpnr-himbaechel -> gowin_pack -> openFPGALoader |
| `sim/` | iverilog testbench + behavioral SDRAM model (CL=2) |

## Build & deploy

### Option 1 - Gowin EDA

Open `sdram_test.gprj` in the Gowin IDE (or drive it with `gw_sh`), run
Synthesize + Place & Route, then program with the Gowin Programmer (SRAM mode
for iteration, embFlash mode for persistence) or with openFPGALoader as below.
The magic SDRAM ports connect automatically; `src/nano20k.cst` is the only
constraint file this flow uses.

### Option 2 - OSS toolchain (Linux/WSL)

```bash
source ~/oss-cad-suite/environment   # yosys, nextpnr-himbaechel, gowin_pack, openFPGALoader
cd Verilog/fpga/tang-nano-20k/sdram-test
make            # -> build/sdram_test_top.fs
make load       # program SRAM (volatile, keeps factory LiteX in flash)
make flash      # program flash (persistent, REPLACES factory LiteX)
```

Key OSS-flow detail (learned from the Seyviour fork): **nextpnr does not
auto-connect the embedded SDRAM** - the magic ports must be pinned to internal
pseudo-pins (`IOL13A` etc.). The Makefile appends `src/sdram_pins_oss.cst` to
the package-pin CST automatically.

### USB access from WSL2 (usbipd)

WSL2 has no USB devices by default, so `make load` fails with
`unable to open ftdi device` until the board is forwarded from Windows with
[usbipd-win](https://github.com/dorssel/usbipd-win). One-time setup in an
**elevated (Administrator) PowerShell**:

```powershell
winget install usbipd
usbipd list          # find the board's BUSID
usbipd bind --busid <BUSID>          # one-time: mark shareable (admin)
usbipd attach --wsl --busid <BUSID>  # forward to WSL (repeat after replug)
```

Gotchas observed on this machine (2026-07-08):

- The Tang Nano 20K's BL616 enumerates as an FTDI pair, VID:PID **`0403:6010`**
  ("USB Serial Converter A, USB Serial Converter B"). The **Basys3 uses the
  exact same VID:PID**, so with both boards plugged in, two identical entries
  appear (here: `1-7` and `3-3`) and `usbipd list` cannot tell them apart.
  Disambiguate by unplugging/replugging the Tang and seeing which BUSID
  disappears, or attach both and identify by JTAG IDCODE
  (`openFPGALoader --detect`: GW2AR-18 = `0x0000081b`, Basys3's Artix-7 =
  `0x0362d093`).
- While attached to WSL, the board's **COM port disappears from Windows**; the
  serial console is reachable from WSL instead (e.g. `/dev/ttyUSB1` - the BL616
  is a two-channel FTDI: channel A = JTAG, channel B = UART). Give it back
  with `usbipd detach --busid <BUSID>`.
- `usbipd attach` must be re-run after every replug or WSL restart
  (`bind` persists, `attach` does not).
- WSL2 has no udev, so the forwarded device is root-only. After every attach:
  `sudo chmod 666 /dev/bus/usb/<bus>/<dev>` (find it with `lsusb`) before
  openFPGALoader works without root.

### Serial console from WSL2 (how the hardware run was verified)

Once the board is usbipd-attached, the UART can be driven from WSL directly.
One-time preparation per attach:

```bash
sudo modprobe ftdi_sio          # FTDI serial driver is not auto-loaded in WSL (once per WSL boot)
ls /dev/ttyUSB*                 # -> ttyUSB0 (channel A = JTAG), ttyUSB1 (channel B = UART)
sudo chmod 666 /dev/ttyUSB1     # no udev in WSL -> nodes are root-only (after every attach)
```

**Interactive terminal (recommended)** - type a key to start the test, watch
the output live. Either of:

```bash
# screen (usually preinstalled)
screen /dev/ttyUSB1 9600
#   exit: Ctrl-A then k (kill, confirm y); Ctrl-A d detaches instead

# picocom (sudo apt install picocom) - shows settings on start, keeps scrollback
picocom -b 9600 /dev/ttyUSB1
#   exit: Ctrl-A then Ctrl-X
```

Only one process can have the port open at a time - a stray `cat` or a second
terminal steals characters.

**Scripted (no terminal)** - how the first automated run was captured:

```bash
stty -F /dev/ttyUSB1 9600 cs8 -cstopb -parenb raw -echo
cat /dev/ttyUSB1 &              # watch the output
printf 'G' > /dev/ttyUSB1       # any character starts / restarts the test
```

Notes from the real runs (2026-07-08, verified both scripted and interactively
via screen - several consecutive full passes):

- Opening/configuring the port can glitch the RX line and trigger a run on its
  own - harmless, the test is restartable.
- From the `PASS`/`FAIL` end state, the first key press reprints the banner +
  prompt and the **second** key press starts the next run. The S1 button does
  the same as a key press.
- Verified output matched the simulation byte-for-byte (see expected output
  above), 1 MB block test included, repeatable back-to-back.

Alternative without usbipd: program from the Windows side (Gowin Programmer
GUI or a Windows openFPGALoader) using
`Verilog/fpga/tang-nano-20k/sdram-test/build/sdram_test_top.fs`
in SRAM mode, and keep the serial terminal on the Windows COM port.

### Serial terminal

The BL616 exposes one USB serial port (this board enumerated as **COM5** on
Windows). Connect at **9600 8N1** for this test (the factory LiteX BIOS uses
115200 - different bitstream, different baud). Any terminal works: PuTTY,
TeraTerm, `screen /dev/ttyACM0 9600`, etc. Press a key to start the test.

## Simulation

```bash
cd Verilog/fpga/tang-nano-20k/sdram-test/sim
make            # iverilog + vvp; decodes the UART, expects TB_RESULT: PASS
```

The testbench runs the complete sequence against a behavioral SDRAM model
(4 banks x 2K rows x 256 cols x 32 bit, CL=2) with a fast UART (16 clocks/bit)
and a 64-byte block, and starts the test through the UART RX path - so both
borrowed SC2661 state machines are exercised.

## Notes for the ND-120 integration (next step)

- The controller is **byte-based** with 5-cycle operations and 4-cycle read
  latency at up to 66.7 MHz - the ND-120 bridge (`MEM_RAM_49.v` interface:
  `AA_9_0`, `BANK*`, `RAS/CAS`, `MWRITE50_n`) will need a small FSM in front
  of it, plus refresh arbitration exactly like the one in this test.
- The 180-degree `clkoutp` phase relationship is load-bearing; keep the rPLL
  configuration when changing the clock frequency.
- LiteX proves the silicon is fine at 48 MHz CL-2, so any failure seen with
  our controller is our logic/constraints, not the RAM.

# Plan - ND-120 console on the Nexys 4 DDR's own screen and keyboard

**Full path:** `Verilog/fpga/nexys4ddr/PLAN-vga-console.md`
Written 27-AUG-2026 (Ronny's request). Companion to
[`../../Terminals/README.md`](../../Terminals/README.md) - the terminal RTL is
board-independent and lives there; this document is only the Nexys wiring.

## Why the Nexys is the right place to test the terminal first

It is the only board that has all three at once, today:

- it **already boots SINTRAN III** (25-AUG-2026) at 45.45 MHz with a working
  console, so there is a real byte stream to render from minute one;
- it has a **VGA connector**;
- it has a **USB host** that presents a keyboard to the FPGA as plain PS/2.

MiSTer and MEGA65 both need their whole port built before a terminal can be
tried on them. Here the terminal is the *only* new thing. And because
`Verilog/Terminals/` knows nothing about any board, whatever passes on the
Nexys drops onto the other two with just the two ends re-wired.

## Verified board facts (read 27-AUG-2026 from `Nexys-4-DDR-Master.xdc`)

Not from a datasheet or from memory - from the board's own master constraints
file in this folder.

| Thing | Pins | Line |
|---|---|---|
| VGA red `[3:0]` | A3, B4, C5, A4 | 156-159 |
| VGA green `[3:0]` | C6, A5, B6, A6 | 161-164 |
| VGA blue `[3:0]` | B7, C7, D7, D8 | 166-169 |
| VGA HS / VS | B11 / B12 | 171-172 |
| **USB HID (PS/2)** `PS2_CLK` / `PS2_DATA` | F4 / B2 | 226-227 |

Two things follow, and both are good news:

1. **12-bit colour (4:4:4)** through a resistor ladder. A text terminal needs
   two colours; we have 4096. Colour is a non-problem.
2. The section in the master XDC is headed **`##USB HID (PS/2)`** - the board's
   onboard microcontroller does the USB host job and hands the FPGA a **plain
   PS/2 clock/data pair**. So "USB keyboard" costs us a ~50-line PS/2 receiver,
   **not** a USB stack. This is the same shape as MiSTer, where `hps_io` hands
   over `ps2_key` after Linux has done the USB work.

**No pin conflicts:** `nd120_nexys4ddr.xdc` mentions neither VGA nor PS2 - all
14 pins are free today.

## Clocking - a free exact pixel clock already exists

`nd120_nexys4ddr_top.v:108` runs one `MMCME2_BASE` with **VCO = 1000 MHz**
(`CLKFBOUT_MULT_F = 10.0` from the 100 MHz `clk100`). Taps in use:

| Tap | Divide | Frequency | Used for |
|---|---|---|---|
| CLKOUT0 | `ND120_N4DDR_MMCM_DIV` | CPU / bus (45.45 MHz deployed) | the machine |
| CLKOUT1 | 37 | 27.027 MHz | SD/FAT stack |
| CLKOUT2 | 5 | 200 MHz | DDR2 controller |
| **CLKOUT3** | **25** | **40.000 MHz - exact** | **proposed: pixel clock** |

40.000 MHz is exactly the 800x600@60 pixel clock, and it falls out of the
existing VCO with an integer divide - no second MMCM, no fractional divide, no
tolerance argument. (640x480@60 would want 25.175 MHz; the best this VCO gives
is 25.000 MHz, 0.7% low. Most monitors accept it, but why argue when 800x600
is exact.) **Recommendation: 800x600@60.** An 80x24 screen of 8x16 cells is
640x384 pixels - it centres inside 800x600 with a comfortable border, or the
same font gives a 100x37 screen if we ever want the room.

## The seam - and the one genuinely awkward part

The console byte leaves the machine as an already-serialized RS-232 bit stream:
`nd120_nexys4ddr_top.v:377` `.TXD(cpu_txd)`, and `:322/:324`
`assign uart_rxd_out = cpu_txd ...`. Inbound is `:376` `.RXD(uart_txd_in)`.
Inside the board the console is a **`SC2661_UART`** (Signetics 2661 EPCI,
`CPU-BOARD-3202/circuit/IO_UART_42.v:179`) - and that chip is **software
programmable**. Baud and framing are set at run time by the machine, not fixed
in RTL.

So the framing is a **configuration fact, not a constant**, and this repo's own
tooling says so plainly: `console.ps1:17` - *"The ND-120 OPCOM console is 7E1
in some configurations; the board check is plain 8N1"*, with a 9600 default,
while the deployed fast builds run a **115200** console (`CLAUDE.md`).

> Note for the MEGA65 plan: it says "tap the console TX byte BEFORE 7E2
> serialization". **7E2 is not confirmed anywhere I can find** - the evidence
> in this repo says 7E1, hedged. Whoever writes that tap should check the
> SC2661 mode-register writes rather than trust either number.

Two ways to get bytes, and the cheap one is also the more honest one:

**(A) Deserialize `cpu_txd` in the Nexys top - recommended.**
A plain UART receiver in `fpga/nexys4ddr/`, matched to the configured baud and
framing, feeding the terminal; and a transmitter driving `uart_txd_in` with
keyboard bytes. **Zero changes to shared RTL** - nothing under
`CPU-BOARD-3202/` or `Shared/` is touched, so no other board can regress. It
also exercises the real framing end to end, which is the thing most likely to
be wrong. Cost: the receiver must be told the framing (a parameter, or read it
off the same configuration the machine uses).

**(B) Add a parallel byte tap to `SC2661_UART`.**
Cleaner in principle - the byte before serialization, no framing question at
all - and it is what the MEGA65 plan assumes. But `SC2661_UART` is shared RTL
used by every board and by the Verilator reference; a new port there needs the
full unit suite re-run. Worth doing eventually, for all boards at once. Not
worth doing to get a picture on a screen.

## Keep the serial console - do not replace it

Ronny asked for "a special version that doesn't use the USB serial for the
console". The version should **add** the screen, not **remove** the serial:
`uart_rxd_out` keeps being driven exactly as today, in parallel. Reasons:

- `console.ps1`, the board tests, the deposit loader and the 4-hour soak
  scripts all drive that port. Cutting it silently breaks the whole test rig.
- When the screen shows nothing, the serial port is how you find out whether
  the machine is dead or the terminal is.

Selection by build define, in the style the board folders already use:
**`ND120_CONSOLE_VGA`** - when defined, instantiate the terminal, the PS/2
receiver and the pixel-clock tap, and merge keyboard bytes into `RXD`
alongside the PC's. When undefined the build is bit-for-bit today's.

## Phases

| # | Work | Exit criterion |
|---|---|---|
| 1 | VGA timing + a static test pattern at 800x600@60 on CLKOUT3; no ND-120 involvement | a stable picture on a real monitor |
| 2 | Character generator: font ROM + 80x24 character RAM + cursor; fill it from a counter | readable text on screen, right cell size |
| 3 | PS/2 receiver on F4/B2 + scancode-to-ASCII; echo typed characters into the character RAM | typing on a USB keyboard puts characters on the screen - **the whole console loop proven with no CPU at all** |
| 4 | Wire the seam: deserialize `cpu_txd` into the terminal, transmit keyboard bytes to `uart_txd_in`, behind `ND120_CONSOLE_VGA` | **SINTRAN III banner appears on the VGA monitor**, and a login works from the USB keyboard, with the serial console still working in parallel |
| 5 | The VT100/ECMA-48 escape handling from `Verilog/Terminals/` | whatever SINTRAN actually sends renders correctly (the must-have list is still pending from `retroterm-09`) |

Phases 1-3 need **no ND-120 RTL at all** - they can be built and tested as a
standalone bitstream while the rest of the machine is untouched. That is the
main reason to do this here.

## Two risks worth naming now

1. **Timing.** This board's 45.45 MHz was hard-won (`timing.md`), and the
   critical path is the CPU microcycle. The terminal must live entirely in the
   40 MHz pixel domain with the two byte FIFOs as the only crossing, properly
   constrained. **Re-read the post-route report after adding it** - do not
   assume a "small" block is free on a board with this little margin.
2. **BRAM.** Character RAM 80x24x2 bytes = 3840 B, font ROM 256x16x1 = 4 KB.
   Against ~607 KB on the `xc7a100t` that is noise - stated so nobody worries
   about it, and so we notice if the real number ever comes out different.


## Update 28-AUG-2026 - what changed under this plan while MiSTer went first

Ronny's ordering call on 28-AUG was **MiSTer first** (his board, minutes per
iteration, and the same SDRAM interface shape as the MEGA65). Building the
MiSTer console found three things in the SHARED terminal core, so they land
here too - this board inherits all of them without any change to its own top
level:

1. **`terminal_top` was passing `ORIGIN_Y = 108`**, the value that centres a
   24-row grid, left behind when the terminal became 80x25. It overrode the
   corrected 100 in `text_screen.v`, and this board does not override the
   parameter - so the grid would have been drawn 8 pixels low and off centre.
   Both origins are now COMPUTED from the row/column counts and the video mode,
   so they cannot go stale again.

2. **The byte handshake into the terminal was fire-and-forget.** `terminal_ctrl`
   has always had a `ready` output documented "low while clearing"; `terminal_top`
   discarded it, on the argument that a 115200 console byte arrives every ~87 us
   and the longest clear-screen sweep is ~48 us, so nothing could be lost. That
   argument was sound and its premise held only while the sole source was a
   UART. It is now a real handshake. **For this board specifically:** the risk
   was never in normal typing, it was at reset - the power-on clear runs 2000
   cells, and anything the machine says during it was being dropped.

3. **The PS/2 keyboard is split** into `ps2_keyboard.v` (the 11-bit serial
   framing, which THIS board needs because its onboard microcontroller hands the
   FPGA a raw clock/data pair) and `ps2_decoder.v` (modifiers, caps lock,
   control characters, the TDV cursor keys - shared with MiSTer and the MEGA65).
   `build.tcl` has been updated; no change to `nd120_nexys4ddr_top.v`.

**Not done here, deliberately:** the power-on banner (`term_banner.v`) is wired
into the MiSTer console but NOT into this board's top level. The sources are in
`build.tcl` so it compiles, but nothing instantiates it. Adding it would be a
small and clearly useful change - it is what tells a blank screen apart from a
dead keyboard - but this board's top level is untouched until Ronny asks for a
Vivado build, and changing it now would mean the first synthesis run tests two
things at once.

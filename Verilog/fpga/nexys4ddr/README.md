# Nexys 4 DDR / Nexys A7-100T (Xilinx Artix-7) FPGA target

**Full path:** `Verilog/fpga/nexys4ddr/`

Vivado build flow for the Digilent **Nexys 4 DDR** board (Digilent now sells
the same board as **Nexys A7-100T**; the Nexys 4 DDR product page is marked
legacy and points there). Built from the **Basys3 flow as template** - same
compile-time defines, same source set, same fail-on-negative-slack gate - and
extended from there.

> **Status (25-AUG-2026): SINTRAN III boots on this board.** DDR2-backed
> main memory with a BRAM cache, 16.667 MHz CPU clock, timing-clean
> (WNS +1.46). 5/5 reprogram+`20500&` cycles reach the banner and the
> Watchdog, ~40 s to banner, and a console login works. The full root-cause
> and validation record is [`SINTRAN-BOOT-25AUG.md`](SINTRAN-BOOT-25AUG.md).
> Earlier milestones: tape boot + MEMORY-REFERENCE diagnostics on DDR2,
> SD/FAT storage and floppy server proven, ILA capture kit in place.

## Board / device

| Item | Value |
|------|-------|
| Board | Digilent Nexys 4 DDR (= Nexys A7-100T) |
| FPGA | Xilinx Artix-7 **`xc7a100tcsg324-1`** |
| Logic | ~101,440 logic cells, ~63,400 LUT, ~126,800 FF |
| Block RAM | 4,860 Kbit (~607 KB) - about 2.7x the Basys3 |
| DSP | 240 DSP48E1 |
| Clocking | 100 MHz oscillator (E3), 6 CMT (MMCM/PLL) |
| Big RAM | **128 MiB DDR2** - Micron `MT47H64M16HR-25:H`, single rank, 16-bit |
| Storage | microSD slot, 16 MB Quad-SPI configuration flash |
| Other I/O | 16 switches, 5 buttons + CPU RESET, 16 LEDs, 2 RGB LEDs, 8-digit 7-seg, USB-UART, USB-JTAG, VGA, 10/100 Ethernet, 4 Pmod + XADC Pmod, accelerometer, temp sensor, microphone, PWM audio |
| Programmer | Digilent USB-JTAG (on board - no external cable) |

Compared to the Basys3 (`xc7a35tcpg236-1`): roughly 3x the logic, 2.7x the
block RAM, plus real external memory and a microSD slot. That is what makes it
interesting here - the Basys3 is BRAM-only, so it can never hold ND-120 main
memory.

## Vendor documentation

- Reference manual (web): <https://digilent.com/reference/programmable-logic/nexys-4-ddr/reference-manual>
- Reference manual (PDF, in this repo): [`docs/nexys4ddr_rm.pdf`](docs/nexys4ddr_rm.pdf)
  (Digilent original, downloaded 19-AUG-2026 from
  <https://digilent.com/reference/_media/reference/programmable-logic/nexys-4-ddr/nexys4ddr_rm.pdf>)
- Pin source of truth: [`Nexys-4-DDR-Master.xdc`](Nexys-4-DDR-Master.xdc)
  (Digilent official master XDC for Rev. C, from
  <https://github.com/Digilent/digilent-xdc>). Every pin in
  `nd120_nexys4ddr.xdc` is copied from that file - none are inferred.

## Files

| File | Purpose |
|------|---------|
| `build.tcl` | The whole flow: in-memory project, synth, impl, timing gate, bitstream, JTAG program. No out-of-repo `.xpr` (unlike the Basys3 flow, which drives a GUI project on `F:`). |
| `Makefile` | Standard board API - `make`, `make build`, `make load`, `make clean`, `CLK=<MHz>`. |
| `nd120_nexys4ddr_top.v` | Board wrapper around `ND120_TOP` (8-digit display, active-low CPU RESET button, SD power gate). |
| `nd120_nexys4ddr.xdc` | Active pin constraints. |
| `nd120_timing.xdc` | Clock-group constraints (sysclk vs clk_cpu), same shape as the Basys3 file. |
| `Nexys-4-DDR-Master.xdc` | Digilent master XDC, kept whole as the pin reference. |
| `usb-attach.sh` | Bring the board into WSL over usbipd as `/dev/ttyUSB*` (selects by FTDI serial, since the Tang shares the same VID:PID); `--detach` returns it to Windows. |
| `console.ps1` | Serial console for the board's USB-UART, run from the Windows host (`-Port`, `-Baud`, `-Send`, `-Pace`). |
| `ddr2/` | The DDR2 memory stack: `nd_ddr2_port.v` (MIG wrapper, one op at a time), `MEM_RAM_49_DDR2.v` (sheet-49 main-memory backend - BRAM cache, write-through, miss freezes the control PALs via MEM_HOLD), `nd_ddr2_arb.v` (two-client arbiter: main memory + storage), `nd_ddr2_storage.v` (storage region 64 MiB in). |
| `SINTRAN-BOOT-25AUG.md` | The SINTRAN boot record: stale-cached-word root cause, the hit_q fix, and the 5/5 silicon validation. |
| `ila_ddr2hang.tcl` | ILA capture modes for the memory funnel (snap/at/wrat/wratraw/wrpage/wrval/rdval/trap/hold). |
| `ddr2-test/` | `gen_mig.tcl` + the generated MIG controller (`ip/`), from Digilent's own MIG project file. |
| `sd-fat-test/` | The SD/FAT menu tool on the on-board microSD slot, with the memory tests as menu commands `B` and `M`. |
| `board-test/` | Board bring-up check - switches, LEDs, 7-seg, buttons, UART, SD detect. Run this before the CPU build. |
| `EXTENSIONS-PLAN.md` | The two planned extensions: **microSD** and **DDR2 main memory**. |
| `docs/nexys4ddr_rm.pdf` | Digilent reference manual. |

## Bring-up: validating a brand-new board

Do these in order. Each step needs only what the step before it proved.

**1. Factory self-test - no tools, no bitstream (2 minutes).**
Every Nexys 4 DDR ships with a demonstration configuration in its Quad-SPI
flash, loaded during manufacturing. Set the **JP1** programming-mode jumper to
**SPI Flash**, power the board on, and check what the reference manual
(section 17) says the demo does:

- each user LED lights when its switch is on
- BTNL / BTNC / BTNR turn the tri-colour LEDs red / green / blue; BTND cycles colours
- BTNU records 5 seconds from the microphone and plays it back on the audio
  jack - **the recording is stored in the DDR2**, so this exercises the memory
- the 7-segment display shows a moving snake pattern
- the VGA port shows microphone / temperature / accelerometer feedback, and a
  mouse on the USB-HID port moves the pointer

This is the only test that covers DDR2, VGA, Ethernet-adjacent power, audio,
microphone and USB-HID without writing any RTL. Digilent state that all boards
are 100% tested in manufacturing, so a failure here means transport damage.

**Console - two ways, pick per situation.** The board's FT2232 carries **both**
the USB-JTAG and the USB-UART on one device, so only one operating system can
own it at a time.

*From Windows (leaves Vivado able to program the board):* the UART shows up as
a COM port - **COM11** on this machine (FTDI serial `210292A4BE00B`).

```bash
powershell.exe -NoProfile -ExecutionPolicy Bypass -File console.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File console.ps1 -Send "1" -Seconds 60
```

*From WSL (same usbipd route as the Tang):*

```bash
./usb-attach.sh            # attach; prints which /dev/ttyUSB* is the console
picocom -b 9600 /dev/ttyUSBn
./usb-attach.sh --detach   # hand the board back to Windows before a Vivado build
```

One-time setup, from an **elevated Windows prompt**: `usbipd bind --busid <id>`.

Two things to know about the WSL route:

- **Both boards are `0403:6010`.** The Tang Nano 20K and the Nexys are
  indistinguishable by VID:PID, so `../tang-nano-20k/usb-attach.sh` can grab
  the wrong one when both are plugged in. This board's script selects by FTDI
  **serial** (Digilent serials start with `210`) and refuses to guess when two
  unattached candidates are present.
- **While attached to WSL the board disappears from Windows**, COM11 included,
  and Vivado can no longer program it over JTAG. Detach first, or use the
  Windows console above when a build is running.

**2. JTAG and the toolchain.**
Connect the micro-USB cable to J6, power on, and open Vivado's Hardware
Manager. The board must enumerate as `xc7a100t`. JTAG programming works
regardless of the JP1 setting. The **DONE** LED lights after a successful
configuration.

**3. This repo's board check ([`board-test/`](board-test/README.md)).**
A small design that exercises exactly the pins, the MMCM and the UART the
ND-120 build uses - all 16 switches and LEDs, all 8 display digits and every
segment, all 5 buttons, the CPU RESET button, the console UART in both
directions, and the microSD power gate and card-detect line. Its README lists
the expected result step by step. Build it with `cd board-test && make`.

**4. Only then the ND-120 bitstream** (below). If step 3 passed and the CPU
build misbehaves, the fault is in the CPU work, not the board.

## Build

From WSL (Vivado runs on the Windows host):

```bash
cd Verilog/fpga/nexys4ddr
make build              # bitstream only, no board needed
make                    # bitstream + JTAG program
make CLK=33             # try a 33.333 MHz CPU clock instead of 16.667 MHz
make clean
```

On the Windows host, call the tcl directly:

```powershell
vivado -mode batch -source build.tcl -tclargs -noburn        # build only
vivado -mode batch -source build.tcl -tclargs clk=50         # 50 MHz attempt
vivado -mode batch -source build.tcl -tclargs -skipwcs       # preload the WCS
```

Microcode `AM27256_4513{2,3}L.hex` is copied automatically from
`Code/Microcode/`; the build aborts if either file is missing (an absent image
means an empty microcode ROM, which looks like a dead CPU).

## Configuration of the current build

| Item | Setting | Why |
|------|---------|-----|
| Main memory | `MAIN_RAM_DDR2` (default) - full DDR2-backed main RAM with BRAM cache | The BRAM-only config (`-tclargs bramram`, 64 K words/bank) aliases high addresses onto low memory, which forbids SINTRAN. |
| Clocking | `FPGA_FF_MODE`, one clock domain | The latch model never ships on FPGA. |
| CPU clock | 16.667 MHz (`clk=16`, MMCM divider 60.0) | The only speed proven on Artix-7 silicon (Basys3). The microengine's WCS-read-to-next-address path measured ~49 ns there. |
| WCS load | runtime load from the PROM images | The -100T has BRAM to spare; `-skipwcs` switches to the Basys3-style bitstream preload. |
| Console | 9600 8N1 / 7E1 on the USB-UART | `UART_BAUD_RATE=9600` matches the microcode's baud thumbwheel, exactly as on the Basys3. |

### Raising the clock

The board oscillator is 100 MHz and the MMCM branch `TARGET_NEXYS4DDR` in
`Verilog/ND120_TOP.v` takes the divider as a build flag, so `clk=<MHz>` selects
CPU speed. Supported: **16, 20, 25, 27, 33, 50, 100** MHz (VCO fixed at
1000 MHz).

`clk=` sets the MMCM divider **and** `BOARD_CLK_FREQ` together - they must
always move as a pair, or the UART baud divisor, the RTC tick and every
watchdog count are wrong even though the CPU still runs.

Every setting above 16.667 MHz is an **experiment until its own timing report
is clean**. `build.tcl` reads WNS after routing and refuses to write a
bitstream when it is negative, so a missed target fails the build instead of
producing a board that boots erratically.

## Board I/O map

| Board control | Wired to | Meaning |
|---|---|---|
| **CPU RESET** button (red, C12, active low) | `ND120_TOP.btn1` | Held down = ND-120 held in reset; released = full boot sequence restarts |
| **BTNC** (N17) | OR'ed into the same reset | Second reset button |
| **SW0** (J15) | `ND120_TOP.btn2` | 7-segment source: off = microcode address (CSA), on = latched address bus |
| LD0-LD15 | `ND120_TOP.led[15:0]` | Basys3 LED map - LD0 CPU RED, LD1 CPU GREEN, LD2 RUN, LD3 reset released, LD4 UART TX, LD5 heartbeat, LD6 MCLK, LD7 LCS (microcode loaded), LD8 MR_n, LD11-LD15 CC0-3 + TERM |
| 7-segment | `seg`/`an` via `SevenSegDebug` | Only the **right-hand four digits** are used; the left four are blanked |
| USB-UART (C4/D4) | OPCOM console | 9600 baud |
| microSD | `sd_reset` driven low (slot powered), bus not connected yet | See `EXTENSIONS-PLAN.md` |

## Extensions

Both planned extensions have their design, risks and acceptance criteria
written up in [`EXTENSIONS-PLAN.md`](EXTENSIONS-PLAN.md):

1. **microSD** - DONE: the SD/FAT stack runs on the on-board slot (1-bit
   bus; the Tang runs 4-bit - the likely lever if boot speed matters here).
2. **DDR2 main memory** - DONE: `ddr2/MEM_RAM_49_DDR2.v` + `nd_ddr2_arb.v`
   replaced the BRAM config on 25-AUG-2026; the no-wait-state deadline is
   met by freezing the control PALs on a cache miss (MEM_HOLD). Known open
   items live in `SINTRAN-BOOT-25AUG.md`.

## Related docs

- `../README.md` - the FPGA target directory and the shared board build API.
- `../basys3/README.md` - the template this build was derived from.
- `../../docs/build-defines.md` - the compile-time defines.
- `../../docs/nd120-dram-memory.md` - the measured ND-120 DRAM protocol and the
  sheet-49 backend contract (what any DDR2 bridge must satisfy).

## Unattended board operations (24-AUG-2026)

Everything here runs from WSL with no human at the board. Vivado lives on
the Windows host; the scripts invoke it through `powershell.exe`.

### Reset / program (the reset button, in software)

    vivado -mode batch -source program_only.tcl        # plain bitstream
    vivado -mode batch -source ila_capture.tcl -tclargs program   # with ILA probes

Both need `XILINXD_LICENSE_FILE` set (enterprise licence) and force JTAG
TCK to 5 MHz (faster corrupts ILA uploads, Labtools 27-3312).

### Self-checking board tests (send / expect / hang detection)

    ./run_board_test.sh lfn                 # FILSYS LIST-FILE-NAMES regression
    ./run_board_test.sh tpe_boot            # TPE monitor boot + live prompt
    ./run_board_test.sh sintran_boot        # SINTRAN boot (ERRFATAL = precise FAIL)
    ./run_board_test.sh <name> -ila         # bitstream has an ILA: on any FAIL,
                                            # a capnow of the LIVE machine is saved

Each run: JTAG-resets the board, drives the console through
`board_expect.ps1` (`boardtests/<name>.bt` scripts: SEND / EXPECT
<sec> <regex> / FAILON <regex> / QUIET <sec>), and leaves artifacts in
`boardtest-results/<name>-<stamp>/` (timestamped console log, verdict,
optional ILA capture). Verdict line: `BOARD_TEST: PASS|FAIL`. A HANG
leaves the machine untouched until after the ILA capture, so the stuck
state is inspectable. If a human holds COM11 the runner reports
port-busy and exits without touching anything.

These need the physical board, so they are NOT in `run_all_tests.sh`;
run them after every bitstream change.

### Known traps

- usbipd "Shared" state on the FT2232 blocks Vivado's hw_target while
  COM11 still works: `usbipd unbind --busid <id>` + replug.
- A finishing background build overwrites `nd120_nexys4ddr.bit/.ltx`;
  never capture while a build is writing out - see
  `../../docs/ILA-PROBE-SEMANTICS.md` for this and every other capture
  lesson.
- Console: 9600 8N1, commands UPPERCASE, pace characters (the .bt driver
  paces at 150 ms/char).
- Golden dialogs for expect scripts: `../../tests/golden-console/`.
- Machine invariants (register maps, address-space contract, board
  differences): `../../docs/nd120-facts.md`.

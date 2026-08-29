# Nexys 4 DDR / Nexys A7-100T (Xilinx Artix-7) FPGA target

**Full path:** `Verilog/fpga/nexys4ddr/`

Vivado build flow for the Digilent **Nexys 4 DDR** board (Digilent now sells
the same board as **Nexys A7-100T**; the Nexys 4 DDR product page is marked
legacy and points there). Built from the **Basys3 flow as template** - same
compile-time defines, same source set, same fail-on-negative-slack gate - and
extended from there.

> **Status (26-AUG-2026): SINTRAN III boots on this board at 45.45 MHz
> with the console at 115200 baud** (`clk 45 ilaslim physopt`, WNS +0.020,
> Ronny-verified on the board) - the deployed configuration. 50 MHz also
> booted (9600-baud build, WNS +0.007), but that closure is single-seed
> fragile; see [`timing.md`](timing.md). **27-AUG: SD-card deployment
> works end to end** - the board configures itself from the microSD and
> boots SINTRAN from the same card, no PC software; needs a post-fix
> bitstream (the SD slot is now power-cycled at configuration, reset,
> MACL and system clear - see
> [`../QUICKSTART-nexys4ddr.md`](../QUICKSTART-nexys4ddr.md)).
> **Soaked 27-AUG: 4 unattended hours at 45.45 MHz, 8/8 console probes
> answered byte-identically.** The original 25-AUG milestone:
> 16.667 MHz, timing-clean (WNS +1.46), 5/5 reprogram+`20500&` cycles to
> banner and Watchdog, ~40 s to banner, console login works. The full root-cause
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
picocom -b 115200 /dev/ttyUSBn   # 9600 for builds older than 26-AUG-2026
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
vivado -mode batch -source build.tcl -tclargs nopanelclock   # drop the panel clock (make PANELCLOCK=0)
vivado -mode batch -source build.tcl -tclargs novgaconsole   # drop the VGA console (make VGACONSOLE=0)
```

Microcode `AM27256_4513{2,3}L.hex` is copied automatically from
`Code/Microcode/`; the build aborts if either file is missing (an absent image
means an empty microcode ROM, which looks like a dead CPU).

## Configuration of the current build

| Item | Setting | Why |
|------|---------|-----|
| Main memory | `MAIN_RAM_DDR2` (default) - full DDR2-backed main RAM with BRAM cache | The BRAM-only config (`-tclargs bramram`, 64 K words/bank) aliases high addresses onto low memory, which forbids SINTRAN. |
| Clocking | `FPGA_FF_MODE`, one clock domain | The latch model never ships on FPGA. |
| CPU clock | **45.45 MHz** (`clk 45` + `physopt`) since 26-AUG-2026 | Boots SINTRAN on silicon. The frequency search and bottleneck analysis are in [`timing.md`](timing.md); `clk=16` remains the high-margin fallback. |
| WCS load | runtime load from the PROM images | The -100T has BRAM to spare; `-skipwcs` switches to the Basys3-style bitstream preload. |
| VGA console | `ND120_CONSOLE_VGA` (default since 29-AUG-2026) - console on the VGA connector + USB keyboard, serial console kept in parallel | Every deployed image since 28-AUG had it. `novgaconsole` / `make VGACONSOLE=0` leaves it out to save space; the screen is then dark and only the serial console works. |
| Panel clock | `ND120_PANEL_CLOCK` (default since 29-AUG-2026) - the MC68705/MM58274 hardware clock emulated in `CPU-BOARD-3202/circuit/PANCAL_68705_CLOCK.v`, 1 Hz tick derived from `BOARD_CLK_FREQ` so it follows `clk=` | Proven on the Tang (SINTRAN takes the time across a master clear, TPE starts without "clock is not updated"). `nopanelclock` / `make PANELCLOCK=0` brings back the old stub if the space is needed for something else; then SINTRAN prints "ND-100 PANEL CLOCK INCORRECT" at every boot. Details: `Verilog/docs/panel-clock-68705.md`. |
| Console | **115200** 7E1 on the USB-UART since 26-AUG-2026 | The physical rate is the `UART_BAUD_RATE` build constant alone: the emulated SC2661 stores the microcode's BAUDV mode value (thumbwheel 8 = 9600 - the 1988 table tops out there) but times every bit off the compile-time divider, and TX-ready is a polled flag. The machine believes 9600; the wire runs 115200. |

### Raising the clock

The board oscillator is 100 MHz and the MMCM branch `TARGET_NEXYS4DDR` in
`Verilog/ND120_TOP.v` takes the divider as a build flag, so `clk=<MHz>` selects
CPU speed. Supported: **16, 20, 25, 27, 33, 35, 38, 40, 42, 45, 50, 100** MHz
(VCO fixed at 1000 MHz; the 35-45 entries are fractional dividers added by the
26-AUG-2026 clock-up campaign).

Measured post-route STA results, one run each, Vivado 2026.1, `ilaslim`
config (evidence: `timing-analysis/run_clk*/`, analysis:
`timing-analysis/TIMING_CLOSURE_REPORT.md`):

| clk= | period | CPU-domain WNS | verdict |
|------|--------|----------------|---------|
| 16 | 60 ns | +26.455 | PASS (shipped, SINTRAN boots) |
| 25 | 40 ns | +9.293 | PASS |
| 33 | 30 ns | +1.282 | PASS |
| 35 | 28 ns | +1.308 | PASS |
| 38 | 26 ns | +0.316 | PASS |
| 40 | 25 ns | +0.319 | PASS |
| 42 | 24 ns | +0.152 | PASS |
| 45 | 22 ns | +0.085 | PASS (razor-thin, single seed) |
| 50 | 20 ns | **-2.546** | **FAIL** (1213 endpoints, gate refuses bitstream) |

STA passing is NOT functional validation by itself. Silicon-verified
26-AUG-2026: SINTRAN boots at 45.45 MHz (115200 console, deployed) and at
50 MHz (9600 build). No soak yet at either; the two auto-inserted
loop-breaking false paths (CGA IDB ring remnants, see `build.tcl`) make
every CPU WNS a floor, not a guarantee; and the 50 MHz closure died on a
one-constant edit (`timing.md`), so every new build must pass its own gate.

`clk=` sets the MMCM divider **and** `BOARD_CLK_FREQ` together - they must
always move as a pair, or the UART baud divisor, the RTC tick and every
watchdog count are wrong even though the CPU still runs.

Every setting above 16.667 MHz is an **experiment until its own timing report
is clean**. `build.tcl` reads WNS after routing and refuses to write a
bitstream when it is negative, so a missed target fails the build instead of
producing a board that boots erratically.

## Board I/O map

**The complete indicator reference is [`DEBUG-PANEL.md`](DEBUG-PANEL.md)** -
every LED, both tri-colour LEDs, all 8 display digits, switches and buttons,
plus the how-to for reading a frozen machine off the panel. Summary:

| Board control | Meaning |
|---|---|
| CPU RESET (red) / BTNC | ND-120 reset - held = in reset, released = full boot restart |
| LD0-LD2 | storage/SD activity |
| LD3-LD10 | reset, UART TX, heartbeat, RUN, microcode loaded, MR_n, DDR2 calibrated, SD mounted |
| LD11-LD15 | microcode CC0-CC3 + TERM |
| **LD16 (RGB)** | DDR2/arbiter health: green = healthy, red = watchdog `dbg_stuck`, blue = orphan response |
| **LD17 (RGB)** | green = CPU running, red = MEM_HOLD (cache-miss) activity, blue = storage on the DDR2 port |
| 7-segment right 4 digits | CSA / LA / FDISK counters, selected by sw15:14 + sw0 |
| 7-segment left 4 digits | live panel: PIL, DDR2 bridge state, arbiter health flags |
| USB-UART (C4/D4) | OPCOM console, 115200 baud (9600 before 26-AUG-2026) |
| microSD | the boot disc (SD/FAT stack, 1-bit bus) |

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
- Console: 115200 8N1 host-side since 26-AUG-2026 (9600 for older builds;
  pass `-Baud 115200` to board_expect.ps1/console.ps1), commands UPPERCASE,
  pace characters (the .bt driver paces at 150 ms/char).
- Golden dialogs for expect scripts: `../../tests/golden-console/`.
- Machine invariants (register maps, address-space contract, board
  differences): `../../docs/nd120-facts.md`.


## Console on the board's own screen and keyboard (built, not yet synthesized - 28-AUG-2026)

The Nexys has a VGA connector and an onboard USB host that presents a keyboard
to the FPGA as **plain PS/2** (`Nexys-4-DDR-Master.xdc:226-227`, in the section
headed `##USB HID (PS/2)`) - so a keyboard costs a ~50-line PS/2 receiver, not
a USB stack. Since this board already boots SINTRAN III, it is the cheapest
place to prove the shared terminal core in `Verilog/Terminals/`: the terminal
is the only new thing in the build, and phases 1-3 need no ND-120 RTL at all.

Plan: [PLAN-vga-console.md](PLAN-vga-console.md). The serial console is kept
live in parallel - the build define `ND120_CONSOLE_VGA` *adds* the screen, it
does not remove the UART - so `console.ps1`, the board tests and the soak
scripts keep working.

**That parallel serial console is the whole reason this board goes first**
(Ronny, 28-AUG-2026). `Terminals/rtl/ps2_ascii_table.v` says of itself that
every scancode in it is "a claim, not a fact" until someone types on a real
keyboard - and this is the only board where the claim can be CHECKED, because
you can watch both paths at once. Press a key: the screen shows what our table
produced, and the serial terminal shows what the machine actually received. A
screen on its own looks perfectly healthy whatever the table produced. No other
board can do this - MiSTer's console echoes locally and has no machine behind
it.

### What is built

```bash
vivado -mode batch -source build.tcl -tclargs -noburn                # VGA console is the default
vivado -mode batch -source build.tcl -tclargs novgaconsole -noburn   # serial console only
```

The VGA console is ON BY DEFAULT since 29-AUG-2026 (`novgaconsole` drops it).
It adds the 12 terminal sources, copies the font next to `font_rom.v`
(Vivado resolves `$readmemh` relative to the .v, not the project), reads the
extra XDC, and defines `ND120_CONSOLE_VGA` plus the console baud. `-noburn`
builds without programming the board - **`build.tcl` programs over JTAG by
default**, which would replace whatever is currently running.

The console prints a power-on self-test message before the machine says
anything, then gets out of the way permanently. That is deliberate: it turns a
blank screen from one useless symptom into two useful ones. Text on screen but
no response to typing means the keyboard half; nothing at all means the video
half. The banner and the banner/machine priority are shared with the MiSTer and
MEGA65 consoles (`Terminals/rtl/term_console_feed.v`), so the three boards
cannot drift apart.

### First build, 28-AUG-2026 - SYNTHESIZED, PROGRAMMED, AND SINTRAN STILL BOOTS

`vivado -mode batch -source build.tcl -tclargs vgaconsole`, Vivado 2026.1,
default `clk_sel 16` and 115200 baud. Measured, not estimated:

| | |
|---|---|
| Setup | **WNS +1.460 ns**, TNS 0.000 |
| Hold | WHS +0.016 ns, THS 0.000 |
| DRC | 0 errors |
| Bitstream | `nd120_nexys4ddr.bit`, 3,825,999 bytes |
| Programmed | yes, over JTAG |

So the terminal core fits and closes timing on top of the whole ND-120, with
+1.46 ns of setup margin left. Hold margin is thin (+0.016 ns) but positive.

**SINTRAN III boots on the resulting bitstream** - confirmed by reading COM11
while the board came up:

```
 09.45.15     16 SEPTEMBER   1994
 SINTRAN III - VSX/500 M
--- NEXYS4 FPGA ---
 CPU TYPE:      102      CPU NUMBER:    120
SINTRAN III RUNNING -
PAGES FOR SWAPPING:   3074B
```

That is the important negative result too: adding the console did NOT break the
machine. The serial console still works exactly as before, which is the whole
premise of testing the terminal on this board.

**Still unverified, and only a monitor can answer it:** whether anything
appears on the VGA connector, whether the font ROM loaded (blank boxes = the
`$readmemh` path), and whether the keyboard table is right. That last one is
the reason this board was chosen - type a key and compare the screen against
what COM11 shows the machine actually received.

Simulation coverage behind it: 8 testbenches (7 in `Terminals/sim` including a
1,920,000-pixel frame comparison, 1 for the MiSTer glue), Verilator lint clean,
zero inferred latches, and the default non-console bitstream proven unchanged by
preprocessing the top level both ways.


### Slide switches

They have accumulated; this is the map.

| Switch | 0 | 1 |
|---|---|---|
| `sw[0]` | 7-segment shows CSA | shows LA *(always zero - see below)* |
| `sw[1]` | US keyboard + font | **Norwegian** (NS 4551-1) |
| `sw[2]` | 800x600 @ 40 MHz | **1920x1080 @ 148.4 MHz** |
| `sw[3]` | operator panel hidden | **operator panel shown** |
| `sw[15:14]` | 7-segment right-hand source select | |

`sw[13:4]` are free.

**`sw[1]` switches the keyboard AND the font together, from one bit.** That is
deliberate: a national variant is not a font choice and not a keyboard choice,
it is one agreement about what six byte values mean. Selecting them separately
would allow the state where you type AE and the screen draws `[`, which looks
like a font bug and is not one.

**`sw[2]` switches the pixel clock as well as the timing**, through a
`BUFGMUX_CTRL`. A plain logic mux on a clock produces runt pulses, and a runt on
the pixel clock does not give a glitchy picture - it gives flip-flops latching
garbage into the character RAM. The console UART's divisor follows the same bit,
because the console shares that clock domain: 347 clocks per bit at 40 MHz,
1288 at 148.4 MHz.

**`sw[3]` hides the panel; it does not remove it.** The logic is in the
bitstream either way, so the switch costs one LUT and saves screen space, not
fabric.

### The operator panel

A recreation of the machine's own folio panel, drawn below the console text.
The fields are not a design choice: the ND-120's panel processor - an MC68705U3
at board position 35C, schematic sheet 40 of 50 dated 5-OCT-1987, transcribed
here as `IO_PANCAL_40.v` - samples exactly these on its Port D, and
`ND3202D.DBG_PANEL` now brings the same five signals out in the same bit order.

| Field | Signal |
|---|---|
| PROTECT RING | `PCR_1_0` |
| PAGING ON/OFF | `PONI` |
| INTERRUPT ON/OFF | `IONI` |
| CACHE HIT RATE | `HIT` - the ND-120's **own** cache, not the FPGA line cache |
| UTILIZATION | `LEV0` - idle is "running at level 0", so the bar is `!LEV0` |
| CURRENT LEVEL | `PIL`, with afterglow |

Two fields deliberately depart from the real panel, because the alternative
would look right and be wrong:

- **CURRENT LEVEL, not ACTIVE LEVEL.** The real display lights every *active*
  level at once, fed from the microprogram in PANC packets. We have PIL, the one
  level running now. Same picture, different claim - so the caption changed.
- **`UP:hh:mm:ss`, not DAY/TIME.** The real clock is a battery-backed MM58274 on
  standby power. Since 29-AUG-2026 the CPU build does carry an emulated panel
  clock (`ND120_PANEL_CLOCK`, table above), but its day/time counters
  (`TIME_HALFDAYS` / `TIME_SECONDS` in `PANCAL_68705_CLOCK.v`) are not brought
  out to `DBG_PANEL` yet, so the VGA panel still shows uptime. Uptime is counted
  in *frames*, not clocks, so it stays correct when `sw[2]` changes the pixel
  clock.

Design mockup and the full provenance of every field:
<https://claude.ai/code/artifact/65f75e7c-ce77-4724-89ab-8b219d19f9a9>


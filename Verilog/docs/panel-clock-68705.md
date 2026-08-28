# Panel clock: MC68705U3 + MM58274 emulation (sheet 40)

> 28-AUG-2026. RTL: `Verilog/CPU-BOARD-3202/circuit/PANCAL_68705_CLOCK.v`,
> wired in `Verilog/CPU-BOARD-3202/circuit/IO_PANCAL_40.v` behind
> `ND120_PANEL_CLOCK`. Unit test: `Verilog/CPU-BOARD-3202/circuit/sim/IO_PANCAL_40_clock_tb.v`
> (`make test-pancal-clock` / `make test-pancal-clock-ff`, both registered in
> `tests/run_all_tests.sh`). ROM analysis: `Code/68705/U3/U3-COMPLETE.MD`
> (corrected the same day, see its section 17).

## What the CPU sees

SINTRAN and the test programs set and read the hardware clock with the ND-100
panel-processor protocol (ND-06.014 ch. 4.3, `ND-HWCLCK`):

```
TRR PANC   A = | 0 0 RD 0 0 PFUNC(3) | WPAN(8) |     RD = bit 13, PFUNC = bits 10:8
TRA PANS   A = | PRES FUL~ READ VAL | STAT3..0 | RPAN(8) |
```

| PFUNC | byte |
|-------|------|
| 4 | seconds within the half-day (0..43199), low byte |
| 5 | seconds, high byte |
| 6 | half-days since 1979-01-01 00:00, low byte |
| 7 | half-days, high byte |
| 0-3 | nothing happens (no answer) |

Write: four `TRR PANC` with RD=0 and PFUNC 4,5,6,7 - each is answered with the
byte echoed in RPAN, READ=0, STAT2:0 = PFUNC, VAL=1; the clock takes the new
value when PFUNC 7 arrives. Read: four `TRR PANC` with RD=1, PFUNC 4..7 - the
answer byte is in RPAN with READ=1; a fresh snapshot of the clock is taken on
PFUNC 4 so the four bytes are consistent. `TRA PANS` clears VAL.

This is what the ROM in the MC68705 does (0x06BE); the panel converts the four
bytes to a calendar for its display and for the MM58274, but the CPU never sees
the calendar - so the emulation keeps the raw 32-bit value and needs no
calendar arithmetic.

## How it is wired (sheet 40 → RTL)

```
DGA FIFO ──XA_7_0 (while RMM~ low)──► PA7:0 ──► PANCAL_68705_CLOCK
   ▲ RMM~ (PB3)                                 │ WMM~ (PB0) ┐
   EMP~ = not empty ───────────────────────────►│            ▼
                                                │      74LS374 32B ──► IDB7:0  (EPANS)
                    READ(PB6) STAT4(PB5) STAT2:0(PC2:0) ──► 74LS244 33B ──► IDB13, DGA VAL→IDB12, IDB10:8
```

- `EMP_n` is the DGA's `XEMN = ~fifo_empty` (1 = a byte is waiting). The 68705
  polls it (PD7) and reads with `RMM~` low; the DGA pops one byte per XCLK
  while `RMM~` is low. The emulator therefore needs the FIFO clock: `CLK` in
  latch mode, `CLK_EN` in `FPGA_FF_MODE` (new `IO_PANCAL_40` ports, fed from
  `IO_37`).
- The answer byte goes to the 74LS374's D through a mux
  (`s_pa_bus = PA_DRIVE ? PA_OUT : PA_7_0`) - the FPGA has no bidirectional PA.
- `STAT4` (PB5) is 1 at reset (PORTB = 0x2F), 0 while a clock command is being
  answered, 1 after the answer, and drops again ~2 ms later (the ROM's display
  pipeline, `HOLD_CYCLES`). The DGA (DECODE_DGA_IDBS A282) turns it into VAL
  and clears VAL on `TRA PANS` (MAPANS). The unit test models that handshake.
- Text/display commands (command byte bit 3 = 1) are drained from the FIFO
  with the ROM's byte counts and never answered, so a `TRR PANC` text write
  cannot leave stray bytes that would be read as the next command.
- PFUNC 0-3 are answered by nothing - and, as in the ROM, the second RPANC
  byte (WPAN) stays in the FIFO and is read as the next command byte.
- A missing data byte is waited for `HOLD_CYCLES`, then taken as 0 (the ROM
  would read an empty FIFO and get 0).
- `CLEAR_n` resets the ports and the state machine but not the time (the
  MM58274 is battery-backed).

## Time base

`TICK_CYCLES` sysclk per second:

| build | value |
|-------|-------|
| FPGA (`BOARD_CLK_FREQ` defined by every board build) | `BOARD_CLK_FREQ` |
| Verilator (`VERILATOR_SIM`) | 50 × the DGA's simulated 20 ms RTC period (8192 or `RTC_SIM_20MS`) = 409600, so the panel second and the OS 20 ms tick stay on one time scale |
| `RTC_REAL_PERIOD` | `BOARD_CLK_FREQ` |
| explicit | `-DND120_PANEL_CLOCK_TICK_CYCLES=n` |

The clock starts at 0 = 1979-01-01 00:00 at FPGA power-up; SINTRAN's `@UPDAT`
/ `@CLOCK` set it. There is no host preset yet (`TIME_HALFDAYS` /
`TIME_SECONDS` are brought out of the module for that purpose).

## Enabling it

Off by default everywhere - the Tang Nano 20K is nearly full.

| where | how |
|-------|-----|
| Tang Nano 20K | `.\gowin_build.ps1 -Variant fast20 -PanelClock` (adds `` `define ND120_PANEL_CLOCK`` to `build/tang20k_variant.v`) |
| Nexys 4 DDR | `build.tcl ... panelclock` (adds `ND120_PANEL_CLOCK` to the synth defines) |
| Verilator `sim/` and `runSim/` | `PANEL_CLOCK=1` on the make line (also reaches the `probe*` engines in `sim/`) |
| unit tests | always built (`test-pancal-clock`, `test-pancal-clock-ff`); the stub contract test `test-pancal` still builds without the define |

`PANCAL_68705_CLOCK.v` is in `nd120_tang20k.gprj` (the one file list both the
Tang and the Nexys builds read); without the define it is an unused module.

## Verified

- TPE Monitor B01 floppy boot in Verilator: start-up clock probe passes (see
  "Two DGA bugs" below for what had to be fixed on the CPU side).
- `make test-pancal-clock` / `-ff`: 223 checks each, PASS (reset state, PFUNC
  0-3, write/echo, read-back after N ticks, snapshot consistency, 43199 wrap,
  text-command drain, missing-byte recovery, CLEAR_n keeps the time).
- `make test-pancal` (stub, no define): 8194 checks, PASS - the default build
  is unchanged.
- Verilator lint (`-Wall`, latch and FF) of `IO_PANCAL_40` with the define: clean.
- Full-tree `sim/ make test_nd120 PANEL_CLOCK=1 USE_LATCHES=0`: the same 82
  pre-existing `-Wall` warnings as without the define (CGA_WRF/CGA_MAC
  PINMISSING etc.), none in the new or edited files.

## Not modelled (display only)

- DISP1-5 (PC3-PC7) serial output to the panel display.
- The Port D statistics: PCR1:0 (protect ring, sampled only while PONI=1, ROM
  0x09D4), PONI, IONI, LHIT (cache-hit bar = hits in the last 128 timer ticks,
  ROM 0x0985) and LEV0 (busy bar = ticks not on level 0). No PIL ever reaches
  the panel.
- STAT3 (PB4): the ROM pulses it high→low in its idle loop every 255 EMP~
  polls (~3 ms, ROM 0x0153) - a periodic panel request (PRQ → MOPC). The
  emulator keeps STAT3 = 0 like the stub, because the Tang analysis
  (`fpga/tang-nano-20k/ANALYSIS-cga-intr-masked-grant-root-cause.md` 3f) found
  that manufactured PRQ pulses trip the CGA_INTR/INTRQN lag bug. That analysis
  states the real chip "keeps PB4 low in the idle loop"; the ROM bytes say
  otherwise. Whether to add the idle pulse is a separate decision.

## Two DGA bugs that hid every panel command (found 28-AUG-2026, measured)

The emulator alone did not make TPE happy - its start-up probe still said
`==TPE42=> The clock is not updated (display panel wrong or unexisting)`.
A sim-only trace (`-DND120_PANEL_CLOCK_TRACE`, `[panel]`/`[dga]` lines) and
the probe scripts `sim/examples/panel_pans_probe.py` / `panel_pans_capture.py`
(a 9-word program: `TRA PANS; STA; LDA; TRR PANC; TRA PANS; STA ...`) showed
two faults in the recreated DGA, both independent of the panel clock:

1. **`TRA PANS` returned 000000 to A** although the sheet-40 drivers held
   PRES=1. `DECODE_DGA_IDBS.v` had made `EPANSN` purely combinational (a
   WCS-latency workaround for the microcode's 20 ms `IDBS,MIPANS; COND,F15`
   check). The capture shows the panel data on the IDB for exactly one CLK
   period, one phase before the ALU samples FIDBI; a working reference (the
   UART read, IDBS o37, CLK0-registered `RUARTN`) holds its data one phase
   later. Fix: `EPANSN = comb(o20) & ~MAPANS` - the comb window stays for
   o20 (MIPANS, needed by `COND,F15`), o21 (MAPANS, the macro read) uses the
   existing A275 CLK0-registered decode. Two other variants (registered term
   for both codes, or comb AND registered) were tried first and both killed
   OPCOM console input - the extra window lands in the next microinstruction's
   IDB data phase. The IDBS and DGA-top unit tests model the split.
2. **`TRR PANC` never wrote the FIFO.** `LDPANC~ = ~(EROF & ldpanc_latched)`;
   EROF is the CYC/PAL_44307C "misc write pulse" (cycle state d), ONE sysclk
   wide, mid-cycle. The FIFO that replaced the PFIF* blocks wrote on XCLK
   rises (`XCLK_EN` in FF mode, `posedge XCLK` in latch mode) - the pulse
   never coincides with one, so the write pointer stayed at 0 forever. Fix
   (`DECODE_DGA.v`): FIFO on sysclk in both modes, write on the detected
   falling edge of `LDPANC~`, pop on the XCLK rise while `RMM~` is low.

With both fixes the microcode's own panel traffic appears for the first time
(0x0D at MACL, then command 0x0A + the ACTLV word every 20 ms - the ACTIVE
LEVEL row), and TPE's probe works:

```
[panel] cmd byte 24 (bit3=0 rd=1 pfunc=4)   answer 5c READ=1 STAT2:0=4  time hd=0 sec=92
[panel] cmd byte 25 (bit3=0 rd=1 pfunc=5)   answer 00 READ=1 STAT2:0=5
[panel] cmd byte 26 (bit3=0 rd=1 pfunc=6)   answer 00 READ=1 STAT2:0=6
[panel] cmd byte 27 (bit3=0 rd=1 pfunc=7)   answer 00 READ=1 STAT2:0=7
    TPE Monitor, ND-100 series - Version: B01 - 1988-10-07
The command HELP gives you the full list of available commands
TPE>
```

No "clock is not updated" line - the same console nd100x shows. (Before the
fixes the message came between the banner and the HELP line.)

## Full-system check (how it was run)

`runSim`: `make compile VERILOG_TAPE=0 SD_STORAGE=0 DEVICECORE=1
DEVICECORE_FLOPPY=1 PANEL_CLOCK=1 EXTRA_VDEFINES="-DND120_PANEL_CLOCK_TRACE"
EXTRA_CFLAGS="-DSCRIPT_INPUT -DSCRIPT_CMD_FBOOT"` then
`ND120_FLOPPYCORE_IMG=FLOPPY1.IMG ND120_MAX_CNT=400000000 ./obj_dir/VND120_TOP`
boots the TPE Monitor B01 floppy with `1560&`. NOTE: at HEAD the Verilator
builds in `sim/` and `runSim/` stop on 82 pre-existing `-Wall` warnings
(IMPLICIT `DBG_PPN`/`DBG_PTW`/`PF_CAPTURED`/`DBG_WDSTAGE`, PINMISSING
`DBG_PTW_LVL`/`DBG_PANEL`, all from the 25-AUG squash); the runs above passed
`SUPPRESS_FLAGS="... -Wno-IMPLICIT -Wno-PINMISSING"` on the make line only.

Not yet done: SINTRAN `@UPDAT` / `@CLOCK` / `@DATCL` round trip on silicon
(Tang `-PanelClock`, Nexys `panelclock`).

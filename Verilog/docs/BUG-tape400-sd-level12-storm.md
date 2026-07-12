# BUG REPORT: `400$` tape boot triggers a continuous level-12 interrupt storm (SD/FAT rewiring)

**For:** the LLM/owner of the SD-card + FAT filesystem + sim device wiring work
**Filed from:** the instruction-verify campaign (running INSTRUCTION-B via `400$`)
**Repo:** `/mnt/e/Dev/Repos/Ronny/nd-120`, dir `Verilog/`
**Date:** 2026-07-12

## One-line summary

Booting INSTRUCTION-B from the tape device with `400$` produces a **continuous
level-12 interrupt storm** (tens of thousands of `Generating interrupt at level
12` / `Clearing interrupt at level 12` cycles). The tests still *complete and
pass*, but the sim crawls through the storm, making full-length runs
impractical. The storm appeared after the SD-card / FAT filesystem rewiring of
the sim device path.

## Environment / how to reproduce

- Build (default device config = the **C** papertape model, `VERILOG_TAPE=0`):
  ```
  cd Verilog/runSim
  make compile USE_LATCHES=0
  printf '400$ARGUMENT\r' | ND120_MAX_CNT=20000000000 ND120_STDIN_GAP=300000 ./obj_dir/VND120_TOP
  ```
- The device that serves `400$` is the papertape/tape-400 at **interrupt level
  12** (octal ident 02), feeding `INSTRUCTION-B.BPUN`.

## Observed behaviour

Console (trimmed), right after the BPUN loads (`Words read 054731`) and the
`400$` command is entered:

```
#400 ... $ PaperTape Reading from address: 400 value: 0
Generating interrupt at level 12
PaperTape Reading from address: 402 value: 11
PaperTape Reading from address: 400 value: 0
PaperTape Writing value: 4005 to address: 403
Clearing interrupt at level 12
Generating interrupt at level 12
        ... (repeats ~35,950 times) ...
```

The storm begins essentially at boot and continues *through* the test run. It
does NOT block correctness: given enough sim time the test still prints its
verdict, e.g. ARGUMENT reaches, with **no error lines**:

```
== RUNNING TESTS ON LEVEL 1 ==
== ARGUMENT INSTRUCTIONS                == END OF TEST ==
== RUNNING TESTS ON LEVEL 2 ==
== RUNNING TESTS ON LEVEL 3 ==
```

So the CPU-side instruction execution is fine; the problem is the **tape device
model re-asserting its level-12 interrupt far more than it should**, so the CPU
spends most cycles in the tape ident/handler path instead of the test.

## Relevant code

- `Verilog/simDevices/NDDevices.cpp` - `PaperTape` device, `InterruptLevel = 12`
  (thumbwheel 0 and 1, lines ~37/43). `PaperTape::Write` (`WriteControlWord`)
  calls `SetInterruptStatus(interruptEnabled && readyForTransfer)` twice per
  control write (lines ~148 and ~181); `PaperTape::IDENT` clears the interrupt
  and disables `interruptEnabled` (lines ~188-198).
- `Verilog/simDevices/NDDevices.h` - `GenerateInterrupt` / `ClearInterrupt`
  (the storm print sites, lines ~120/132), guarded to levels 10-13.
- `Verilog/simDevices/NDBus.cpp` - the `OUTIDENT` -> `IDENT(level)` dispatch
  (bus_address 022 -> level 12, line ~100).
- `Verilog/runSim/Makefile` - `VERILOG_TAPE` flag (default 0 = C model;
  `=1` swaps in the Verilog `ND_BUS_SLAVE + ND_TAPE_400` stack that serves raw
  tape bytes through the `TAPE_BYTE_*` ports).

## Suspected cause

The SD-card / FAT filesystem rewiring of the sim device path changed how the
`400$` tape byte source is fed / how its ready/interrupt handshake is driven, so
the tape's level-12 interrupt re-arms every cycle instead of one interrupt per
byte transferred (and then quiescing once the loader stops requesting bytes).

## Desired end state (owner preference)

**Preferred:** run through the **Verilog tape reader (`ND_TAPE_400`) connected
to the SD card**, booting off tape with `400$` - i.e. the SD/FAT layer serves
`INSTRUCTION-B.BPUN` as the tape byte source, and the Verilog tape device
presents it on the bus with a correct one-interrupt-per-byte handshake (no
storm).

**Acceptable alternative:** restore the old C tape-reader wiring so `400$`
boots cleanly - BUT it must be selectable via a **config/define** (like the
existing `VERILOG_TAPE`) so BOTH variants (C tape model AND Verilog-tape-over-SD)
remain buildable and testable side by side. Do not delete one path for the
other.

## Acceptance criteria

1. `printf '400$ARGUMENT\r' | ... ./obj_dir/VND120_TOP` boots INSTRUCTION-B and
   runs to `== END OF TEST ==` **without** the level-12 interrupt storm
   (at most one interrupt per tape byte during load; quiet during the test).
2. The chosen tape source (SD-backed Verilog tape preferred) is selected by a
   documented build define/flag, and the other variant still builds.
3. A full `400$<AREA>` run reaches its verdict in reasonable wall-clock time
   (today the storm balloons a run into tens of thousands of interrupt cycles).

## Note for the instruction-verify side (context, not part of the fix)

The instruction-verify comparison (`Verilog/tests/instruction-verify/`) only
depends on the tape delivering `INSTRUCTION-B.BPUN` intact and quietly. Once the
storm is gone, each `400$<AREA>` run can be driven to `== END OF TEST ==` and its
INSTRUCTION-B error output (if any) captured directly - which is the real
per-area pass/fail signal, deeper than the current 400-instruction golden-trace
window.

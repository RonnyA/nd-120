# BUG REPORT: `400$` tape boot triggers a continuous level-12 interrupt storm (SD/FAT rewiring)

## ROOT CAUSE & FIX (13-JUL-2026) - CONFIRMED FIXED ON REBUILD

Verified by the instruction-verify session after rebuilding with these edits:
the `400$` boot log dropped from ~9.5 MB of interrupt spam to 59 lines, zero
level-12 noise; ARGUMENT ran all 9 levels to `== END OF TEST ==` in 60M cycles
with no failures; the test now visibly reaches its post-area stress phase
(`CLOCK STARTED`, `DUMMY OUTPUT STARTED`) instead of drowning. C-device
interrupts now actually reach the CPU via the repaired `BINTxx_n` lines (they
never did before). Original diagnosis below.


Read directly from the source (not the earlier "suspected cause"), the storm is
**console `printf` spam, not the CPU spinning in an interrupt handler**:

- `simDevices/NDBus.cpp:238-241` drove the interrupt lines as
  `BINTxx_n = !((interruptBits & 1<<xx) == 1)`. `interruptBits & (1<<12)` is 0 or
  4096 - **never `== 1`** - so BINT10..13 were *always deasserted*. The C
  papertape's level-12 interrupt never actually reached the CPU; `400$` boots by
  **polling**. (This bug dates to commit 468aec0, 2025-03-24 - it predates the
  SD/FAT rewiring, so the storm was mis-attributed to it.)
- `simDevices/NDDevices.h` (`GenerateInterrupt`/`ClearInterrupt`/`TickIODelay`)
  did **unconditional** `printf`s, and `NDDevices.h:33-39` force-`#define`d
  `DEBUG_PT`/`DEBUG_INTERRUPT`/etc. So every tape byte emitted several console
  lines; ~46K bytes x several lines = hundreds of thousands of console writes,
  which dominates wall-clock. That is the "storm".

**Fix applied (source only - not yet rebuilt, another session was live on
`runSim/obj_dir`):**
1. Silenced the per-byte spam: the `DEBUG_*` channels are now OPT-IN (commented
   out), and the previously-unconditional interrupt/IDENT `printf`s are gated
   behind `#ifdef DEBUG_INTERRUPT` / `if (DEBUG_BIF)`. This alone removes the
   slowdown and is independent of the interrupt fix.
2. Corrected the `== 1` interrupt-line bug so C-model interrupts deliver
   properly (one per byte, cleared by IDENT). Guarded by
   `NDBUS_ASSERT_C_INTERRUPTS` (NDBus.h, default 1); set 0 to restore the old
   poll-only behaviour if a boot path regresses - the spam stays gone either way.

**TO VERIFY after the other session frees `obj_dir`:**
```
cd Verilog/runSim && make clean && make compile USE_LATCHES=0
printf '400$ARGUMENT\r' | ND120_MAX_CNT=20000000000 ND120_STDIN_GAP=300000 ./obj_dir/VND120_TOP
```
Expect: no "Generating/Clearing interrupt at level 12" flood, boot to
`== END OF TEST ==` in reasonable wall-clock. If the boot itself regresses (as
opposed to just being quiet), flip `NDBUS_ASSERT_C_INTERRUPTS` to 0 and rebuild;
the run should still be quiet/fast (poll boot) while we investigate the handler.

---


**For:** the LLM/owner of the SD-card + FAT filesystem + sim device wiring work
**Filed from:** the instruction-verify campaign (running INSTRUCTION-B via `400$`)
**Repo:** ``, dir `Verilog/`
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

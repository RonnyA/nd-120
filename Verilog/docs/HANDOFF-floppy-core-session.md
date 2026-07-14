# HANDOFF - floppy DMA/PIO manual conformance, tape storm, SD-FAT tape, ND120_CORE plan

**Branch:** `clock-enable-fix`. **Date:** 14-JUL-2026.
ASSUME NOTHING - verify in code before trusting any claim below.

**Commit state:** the ND120_CORE extraction (steps 1-3) IS COMMITTED on this
branch. Everything else described here - the floppy DMA manual conformance, the
tape-400 level-12 storm fix, the SD boot card, nd_tape_sdfat_source, and the
emulator handoffs - is still UNCOMMITTED in the working tree.

## DONE + VERIFIED this session

1. **ND_FLOPPY_DMA.v manual conformance (ND-11.021.01).** `make test-floppy-dma`
   -> `TB_RESULT: PASS`; both fixes negative-tested (revert => tb fails).
   - Two DISTINCT status words (the manual is explicit; nd100x C + the old
     Verilog conflated them): IOX +2 AND +4 return the **hardware status word**
     (bit 15 dual-density, bit 4 OR-of-errors, NO error code); the **CB+6
     memory writeback** is Status Word 1 (error code **bits 9-14**, bit 15
     unused). `s_hwstat` vs `s_sw1` in the RTL.
   - Earlier same-session fixes also in: C1 sector-count mode (w4 OPWCH, 24-bit
     count), C3 partial-write stale-tail, M1 real octal error codes, C2 no-drive
     watchdog (DISK_TIMEOUT param, default 0=off).
   - Spec (verified, quoted from manual): `docs/floppy-3112-register-spec-ND-11.021.md`.
   - Review resolution log: `docs/floppy-review-findings.md` (top section).

2. **Tape 400$ level-12 interrupt storm - FIXED, confirmed on rebuild.**
   Root cause was NOT the CPU spinning: (a) `NDBus.cpp:238-241` drove
   `BINTxx_n = !((interruptBits & 1<<xx)==1)` - never `==1`, so C-device
   interrupts NEVER reached the CPU (400$ booted by polling); (b) unconditional
   per-byte `printf`s (`NDDevices.h` GenerateInterrupt/ClearInterrupt/TickIODelay,
   force-on `DEBUG_*`). Fix: gated all per-byte prints behind
   `#ifdef DEBUG_INTERRUPT` / `if (DEBUG_BIF)` (now opt-in), and corrected the
   BINT lines (guarded by `NDBUS_ASSERT_C_INTERRUPTS` in NDBus.h, default 1;
   set 0 to fall back to poll-only). Files: `simDevices/NDDevices.{h,cpp}`,
   `simDevices/NDBus.{h,cpp}`. The other (instruction-verify) session rebuilt
   and confirmed: 9.5 MB of spam -> 59 lines, ARGUMENT ran all 9 levels.
   Detail: `docs/BUG-tape400-sd-level12-storm.md`.

3. **Emulator handoffs (for the other-repo LLMs).** Both grounded in the manual,
   file:line before/after, do-not-change lists:
   - `docs/HANDOFF-nd100x-floppy-dma-manual-fixes.md` (nd100x C DMA: error bit
     8->9, +4 = hardware status not format word, split the two status words).
   - `docs/HANDOFF-floppy-pio-c-and-csharp-fixes.md` (PIO 3027: C = read-only
     image breaks writes + FORMAT_TRACK off-by-one; C# = `Debug.Assert(false)`
     landmines in FORMAT_TRACK/CONTROL_RESET; shared control-reset/device-clear/
     auto-increment deviations vs ND-06.015.02 sec B.4).

4. **Boot SD card image.** `SD-FAT/sim/make_boot_card.sh` builds
   `nd_boot_card.img` (FAT16, contiguous, fsck-clean) with **BOOT.BPUN =
   byte-identical copy of runSim/INSTRUCTION-B.BPUN**. sd_file_reader matches it
   by VFAT long name (4-char ext). Ran + verified byte-identical.

5. **Board-agnostic SD-FAT tape byte source.**
   `ND-BUS-DEVICES/TAPE-400/circuit/nd_tape_sdfat_source.v` - packages
   nd_storage (FILE0_NAME="BOOT.BPUN", PRELOAD_MASK=1) + nd_storage_tape_adapter
   + a mount->open sequencer, exposing ND_TAPE_400's byte-source port + SD pads
   + SDRAM mem_* + status. Elaborates cleanly against the real SD-FAT stack.

## REVERTED (do not redo)

The papertape `BOOT.BPUN` filename change was made then REVERTED at Ronny's
direction (don't hardcode a boot filename into the C papertape). `NDDevices.cpp`
paper-tape is back to original `"INSTRUCTION-B.BPUN"`; NDBus.cpp, Makefile,
run_area_test.sh, README env-var edits all reverted. The correct architecture is
the ND120_CORE extraction below (tape byte source behind nd_storage, board-
selected), NOT a C-model filename edit.

## ND120_CORE extraction: STEPS 1-3 DONE + COMMITTED 14-JUL-2026

Full detail + evidence: `/mnt/e/Dev/Repos/Ronny/nd-120/Verilog/docs/PLAN-nd120-core-extraction.md`.

Files created/changed by the core extraction (COMMITTED on clock-enable-fix):
- NEW  `/mnt/e/Dev/Repos/Ronny/nd-120/Verilog/ND120_CORE.v`
- `/mnt/e/Dev/Repos/Ronny/nd-120/Verilog/ND120_TOP.v`                          (instantiates CORE; external ports UNCHANGED)
- `/mnt/e/Dev/Repos/Ronny/nd-120/Verilog/fpga/tang-nano-20k/src/ND120_TANG20K_TOP.v` (CORE #(0,0,0), device-less)
- `/mnt/e/Dev/Repos/Ronny/nd-120/Verilog/fpga/tang-nano-20k/nd120_tang20k.gprj`      (added ND120_CORE.v to the file list)
- `/mnt/e/Dev/Repos/Ronny/nd-120/Verilog/runSim/Makefile`, `/mnt/e/Dev/Repos/Ronny/nd-120/Verilog/sim/Makefile` (added `-I..`)
- `/mnt/e/Dev/Repos/Ronny/nd-120/Verilog/runSim/Run120.cpp`,
  `/mnt/e/Dev/Repos/Ronny/nd-120/Verilog/sim/latch_ff_compare.cpp`,
  `/mnt/e/Dev/Repos/Ronny/nd-120/Verilog/sim/test_nd120.cpp`  (`__DOT__` prefix: CPU_BOARD/s_csbits now under CORE)

PROVEN behaviour-neutral (not assumed): trace_ff.csv + trace_latch.csv both
byte-identical to golden; pre-refactor (HEAD worktree + current C models) vs
post-refactor runSim console byte-identical; 48/48 units, tape, dma-rtl,
dma-xcheck, Tang vtest all green.

TWO THINGS THAT ARE **NOT** THE CORE REFACTOR (do not chase them as regressions):
1. `test-memchain` still fails -- PRE-EXISTING, TODO.md:83.
2. `/mnt/e/Dev/Repos/Ronny/nd-120/Verilog/runSim/golden/console_ff_golden.log`
   is STALE: it still holds 20 C-model debug-print lines that THIS session's
   own uncommitted change gated behind `#ifdef DEBUG_INTERRUPT` (NDDevices.cpp)
   and `if (DEBUG_BIF)` (NDBus.cpp:115, DEBUG_BIF=0). The pre-refactor baseline
   shows the SAME 20-line delta, so it is the print gating, not the core.
   **Regenerating that golden belongs to this (floppy/tape) workstream.**

Remaining: step 4 = `make test-full` (blocked only by the two items above),
then the Tang Phase-2 follow-up (INCLUDE_TAPE(1) + nd_tape_sdfat_source).

## ORIGINAL plan notes (approved) for extract ND120_CORE.v

Full grounded plan + Ronny's approvals: **`docs/PLAN-nd120-core-extraction.md`**.
Behavior-preserving refactor: pull a board-independent core (ND3202D + device
chain) out of ND120_TOP.v so Basys3/sim, Tang, and future boards share it.
Approved decisions: Run120.cpp `__DOT__` path-prefix edit CLEARED; Tang goes
device-LESS first; follow the RTL for the RAM seam (SDRAM-PHY pass-through only -
the brief's "MEM_RAM_49-facing" seam does NOT exist; RAM is inside ND3202D).

Two critical gotchas (in the plan): (1) `runSim/Run120.cpp` reaches into
`ND120_TOP__DOT__CPU_BOARD__DOT__...` - interposing the core renames ~15
accessors; fix = keep instance name `CPU_BOARD` + one mechanical prefix edit.
(2) ND120_TOP's external port list (33-151) must NOT change.

Execution steps (tasks #2-#4, gates keep the tree green at each commit):
- **Step 1** (task #2): create `ND120_CORE.v` new-file-first, do NOT instantiate,
  elaborate-only (verilator --lint-only / iverilog). Zero behavior change.
- **Step 2** (task #3): switch ND120_TOP.v to `ND120_CORE #(1,1,1) CORE(...)` +
  Run120.cpp prefix edits. Gates: `make test`, `make test-tape`,
  `make test-dma-rtl`, `make test-dma-xcheck`, runSim console-vs-golden.
- **Step 3** (task #4): switch ND120_TANG20K_TOP.v to `ND120_CORE #(0,0,0)`.
  Gate: `fpga/tang-nano-20k/sim` `make vtest`. Then `make test-full`.
- Follow-up (separate change): Tang `INCLUDE_TAPE(1)` + `nd_tape_sdfat_source`
  on the board reading BOOT.BPUN from the real SD card.

## Git note
Working tree has BOTH this session's floppy/tape work AND the other
(instruction-verify/MPY) session's files (MPY*.BPUN, shift-tests/, ndcomm,
csa_trace.csv, trace_verify.md). Don't commit blindly - separate concerns or
ask Ronny. This session's files: ND_FLOPPY_DMA.v, nd_floppy_dma_tb.v,
simDevices/ND{Bus,Devices}.{h,cpp}, nd_tape_sdfat_source.v, make_boot_card.sh,
docs/{floppy-3112-register-spec-ND-11.021, HANDOFF-nd100x-floppy-dma-manual-fixes,
HANDOFF-floppy-pio-c-and-csharp-fixes, PLAN-nd120-core-extraction,
BUG-tape400-sd-level12-storm, floppy-review-findings}.md.

# HANDOFF - Tang Nano 20K: BPUN boot from SD card

Written 14-JUL-2026. Branch `clock-enable-fix`.
Commits: `30e8e02`, `64fe9c4`, `bff68b5`, `5ba5b02`.

**State: the storage side is PROVEN ON SILICON. The open blocker is that
`400$` HANGS the CPU on hardware, while the identical RTL completes the same
boot in Verilator.**

Every path below is absolute on purpose - this doc is read cold.

---

## 1. What is proven on the real board

Bitstream `0b3b4e12...` (Gowin flow, VARIANT=slow), loaded volatile.

- `sd_status = OK` (LEDs 4+3 lit). The mount FSM only reaches `M_OK` via
  `M_SCAN -> M_LOAD -> M_PARK -> M_CHK`, so this ALONE proves: SD card init at
  the 136.4 kHz identification clock, FAT16 walk, `BOOT.BPUN` located,
  **the whole file preloaded THROUGH the SDRAM device port**, and the
  contiguity check passed.
- `400$` lights LED 0 (CPU asked the tape) and LED 2 (a byte was served).
- **Memory really does receive the file.** Dumped `0<77` off the board and
  diffed against the card's BPUN: every word matched except 7 that the running
  program had scribbled (decoded to `''LP'ommands'T` = fragments of "All
  commands" from its own HELP text). So the SD -> tape -> CPU byte path
  delivers correct data into low memory.
- BSRAM **44/46 (96%)**: 34 SP + 10 SDPB, up from the 41/46 device-less
  baseline. The storage stack costs 3 blocks, 2 spare. Tape needed NO
  sync-read refactor (floppy/SMD still will - see
  `Verilog/fpga/tang-nano-20k/BSRAM-BUDGET.md`).

## 2. THE BLOCKER: `400$` hangs on hardware

Measured directly over the console (not inferred):

- `400$` echoes `400$`, then **60 s of complete silence**. No `?`, no prompt.
- **ESC does NOT recover it** (6 ESCs, then CR -> zero bytes back). This is a
  hard hang, unlike the `20!`/HELP hang Ronny can ESC out of.
- Only S1 (Master Clear) recovers. S1 preserves SDRAM, so the loaded image
  survives a reset - that is how to get a pristine dump (see section 4).
- After S1 + `20!` the loaded program RUNS and answers `HELP` - but the command
  list is **not as complete as it should be** (Ronny's call; he knows the
  expected list). Unexplained. Could be a partial load higher up, could be
  something else. **NOT yet measured - do not assume.**

In Verilator (`cd Verilog/runSim && make run`) the
SAME RTL completes `400$` and boots the program fully. So this is
hardware/FF-mode-specific, not a storage-logic bug.

**Prime suspect to test first: the tape-400 level-12 interrupt storm**
(`Verilog/docs/BUG-tape400-sd-level12-storm.md`).
In sim the storm only makes things slow; on real silicon a storm could livelock
the CPU. This is a HYPOTHESIS, unverified.

## 3. Things that turned out NOT to be bugs (do not re-chase)

- **`?` after `400$`** = BPUN **checksum error**, and the machine was RIGHT:
  the card's `BOOT.BPUN` was corrupted by a test program. Microcode proof,
  `/mnt/e/Dev/Ronny/nd120uc/source/nd-120-delilah-L-from-K.uc:6212`:
  after "ALL WORDS ARE PLACED IN MEMORY" it reads the checksum, `XORAB`s it
  against the running sum, and branches to `ILLEG` (prints `?`) on mismatch.
  Ronny fixed the file. The loader + its checksum arithmetic WORK on hardware.
- **`400$` not auto-starting the program.** All three BPUNs have
  **execute = 000000**, i.e. action code 0 = "load only, do not start"
  (BPUN sections A-I, see `loadfile()` in
  `Verilog/runSim/Run120.cpp`). `20!` is the
  intended way to start. NOTE: this explains a clean load that returns to the
  prompt - it does **NOT** explain the hard hang above. Do not conflate them.
- **Words 1..15 reading `000001..000017`.** That address ramp IS the program's
  real content - an independent parse of the BPUN predicts it exactly.
- **Contiguity.** `sd_file_reader.v:37` DOES walk the FAT chain. The
  contiguity requirement is `nd_storage` v1's own contract, enforced at mount
  by `nd_storage_fatchk.v`, because the engine block-addresses by arithmetic
  for random access. Ronny's card already PASSES it (that is what `sd_status =
  OK` means). Not a live issue.

## 4. How to reproduce / measure (exact recipe)

**Board attach (needed after every replug):**
```
powershell.exe -NoProfile -Command "usbipd list"          # Tang = 0403:6010, was busid 2-3
powershell.exe -NoProfile -Command "usbipd attach --wsl --busid 2-3"
sudo chmod 666 /dev/bus/usb/001/006      # openFPGALoader; bus path CHANGES per attach
sudo chmod 666 /dev/ttyUSB0 /dev/ttyUSB1 # console
```
WARNING: the Basys3 is ALSO `0403:6010` (busid 1-7). Do not pick by VID:PID.

**Build + load (the OSS flow CANNOT PnR - see section 5):**
```
cd Verilog/fpga/tang-nano-20k
make gowin VARIANT=slow      # Gowin EDA on the Windows host
make load-gowin              # volatile SRAM; a power cycle wipes it
```

**Console: input MUST be paced ~0.3 s/char** or MOPC drops characters. An
unpaced `0<77` returns nothing at all. Console is `/dev/ttyUSB1` @ 9600 8N1.

**The pristine-image dump (the measurement still owed):**
1. `400$` (it will hang)
2. **press S1** - resets the CPU, KEEPS SDRAM
3. do NOT run `20!` (it scribbles its own scratch into memory)
4. dump every block and diff:
```
cd Verilog/tools
./check_bpun_memory.py --bpun ../runSim/CONFIGURATIO-C08.BPUN --commands
#   -> prints the n<y commands (1K-word blocks) for the whole image
#   ... capture the console to cap.log ...
./check_bpun_memory.py --bpun ../runSim/CONFIGURATIO-C08.BPUN --dump cap.log
```
It reports a per-block OK/BAD table and the FIRST mismatching address. It also
states how much was NOT dumped and calls that UNVERIFIED. The tool is proven
both ways: PASS on a real capture, FAIL on a single corrupted word.

**The card currently holds `CONFIGURATIO-C08.BPUN`** - identified from the
dumped bytes (7/64 words differ vs 37 and 47 for the other two candidates),
not from its command names. Diff against the RIGHT file.

## 5. Toolchain landmines

- **The OSS flow (yosys/nextpnr) CANNOT PnR.** 22 combinational loops in
  `CGA_INTR ... IRQ_REG.RQBIT_*` (the gate-level SR latch). PROVEN
  pre-existing: a device-less worktree at HEAD fails identically with the same
  11 RQBIT instances, and reverting the 13-JUL fence commits does NOT fix it.
  Use `make gowin`. Details: memory `tang-oss-flow-comb-loops`.
- **`make` used to LIE**: nextpnr writes nothing on failure and `| tee` hid its
  exit status, so `test -f` passed against a PREVIOUS run's file - a failed PnR
  reported success and would flash a 2-day-old bitstream. Fixed with
  `rm -f` + `pipefail` + `.DELETE_ON_ERROR`. **Do not remove those.**
- **`/mnt/e` (NTFS via WSL) serves stale files.** `obj_dir` there kept mixing
  files from different Verilator runs even after `rm -rf`. The identical
  sources build clean on ext4 (`/tmp`). If runSim fails with a missing
  generated header or "has no member named `__Vtrigprevexpr...`", it is the
  filesystem, not the code.
- **Never start a Verilog comment with the word `verilator`** - it lexes as a
  metacomment and `-Wno-*` cannot suppress it.

## 6. Verilator side (all green)

```
cd Verilog/runSim
make run          # INSTRUCTION-B from the simulated card (default SD_STORAGE=1)
make run-config   # CONFIGURATIO-C08 - RUN probes devices
make run-fs       # FILSYS-INV-Q04  - looks INTO floppy/SMD images
```
`400$` boots off the simulated card **with RAM starting empty** - the harness's
BPUN pre-deposit is now OFF under `ND120_SD_STORAGE`. That pre-deposit used to
put INSTRUCTION-B in RAM before every run (its default `DEBUG.BPUN` is
byte-identical to `INSTRUCTION-B.BPUN`), which made every earlier "boots from
SD" claim worthless. See memory `bpun-predeposit-contamination`.
`Verilog/sim/` KEEPS its pre-deposit on purpose
(Ronny's ruling): no tape exists there, it is the injection method, and the
traces are the latch-vs-FF golden gate.

## 7. Next steps

1. **The pristine dump** (section 4) - does the load complete, or stop partway?
   The first bad/never-written address is the bug's fingerprint.
2. **Test the level-12 storm hypothesis** for the hang (section 2).
3. Phase 4 (floppy from SD) needs the sync-read buffer refactor first.
   `FILSYS-INV` + `CONFIG`'s `RUN` are then the validation levers.

## 8. Ownership - hands off

**INSTRUCTION-B's `RUN` is another session's** (level-14 livelock). Do not use
it as a test or a gate; it errors, that is known. This is UNRELATED to
CONFIGURATION-C08's `RUN` command, which is a device probe and is fine.

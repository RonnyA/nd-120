# Floppy Verilog Validation Campaign

Location of this plan: `/mnt/e/Dev/Repos/Ronny/nd-120/Verilog/floppyTester/PLAN-floppy-validation.md`
Owner: floppy-validation work (this session). Status: PLAN APPROVED by Ronny 20-JUL-2026, execution starts at Phase 0.

## Goal

Validate the floppy Verilog stack (`ND_FLOPPY_DMA` + bus + DMA + SD-FAT serving)
bottom-up with self-checking testbenches, from single IOX register accesses to a
full `1560&` boot off a simulated SD card, so that the Tang floppy boot can be
trusted. SMD gets the same treatment AFTER the floppy is validated (Ronny).

## Ground rules

- **Oracle:** `/home/ronny/repos/nd100x/src/devices/floppy/deviceFloppyDMA.c`
  (+ `.h`) is the behavioral truth for floppy semantics (Ronny 20-JUL).
  Tiebreaker when the C and the 3112 manual disagree: ND-11.021
  (see `/mnt/e/Dev/Repos/Ronny/nd-120/Verilog/docs/floppy-3112-register-spec-ND-11.021.md`).
- **Canonical test image:** the diskette with the test programs — content =
  `/mnt/e/Dev/Repos/Ronny/nd-120/Verilog/runSim/FLOPPY.IMG` (1,261,568 B, FLOMON
  boot sector, TPE-MON-100-A02:BPUN + 20 :TEST programs), named `FLOPPY1.IMG`
  on SD cards. (Assumed identical to the card's FLOPPY1.IMG — confirm with Ronny.)
- **FLOMON:** the boot-sector format on real diskettes ("almost like BPUN",
  Ronny). Phase 0 determines whether the microcode `&` loader accepts it or the
  gap is in our device/loader; decision on implementing follows that analysis.
- **Success prompt for a real boot:** TPE ends at a `TPE>` prompt (Ronny).
- **CO-EXISTENCE RULE (boundary agreed from the NDDeviceCore plan, 20-JUL):**
  the NDDeviceCore team validates their PORTABLE C floppy (RP2350/Pico card) by
  driving raw ND bus signals from C in Verilator, with ALL Verilog devices
  disconnected (`VERILOG_TAPE=0`, no ND120_VERILOG_DEVICES). Ownership split:
  | Theirs | Ours |
  |---|---|
  | NDDeviceCore repo, simDevices/NDCoreShim*, NDCoreBlockBackend*, NDDeviceCoreAdapter | ND_FLOPPY_DMA.v, ND_BUS_SLAVE.v, ND_DMA_MASTER.v, ND_TAPE_400.v, SD-FAT stack, floppyTester/ |
  | flags DEVICECORE/DEVICECORE_FLOPPY, env ND120_FLOPPYCORE_IMG, gate test-floppy-core | flag VERILOG_FLOPPY (P6), env ND120_FLOPPY_IMG, gates test-floppy-p1..p5 / test-floppy-boot / test-floppy-sdfat |
  They never touch the Verilog device cores; we never touch their C core/shim.
  SHARED FILES (merge care, additive edits only): runSim/Makefile, Run120.cpp,
  Verilog/Makefile, and possibly ND120_TOP.v (their sim-only master-signal
  ports behind `ifdef VERILATOR_SIM`).
  Handled 20-JUL in Run120.cpp: ND120_FLOPPYCORE_IMG now also counts as a
  mounted boot medium (suppresses the DEBUG.BPUN default pre-deposit that
  would contaminate THEIR 1560& gate), and ND120_PRELOAD_BPUN set-but-empty =
  explicitly no pre-deposit in any build.
  WARNING passed to them: their portable-C autoload is to be modeled on the
  nd100x oracle (deviceFloppyDMA.c), NOT on our ND_FLOPPY_DMA.v autoload -
  ours is exactly the logic under investigation here (FLOMON `?`); they test
  with BPUN-only images so they will never see the FLOMON failure themselves.
  Share our P0 CONFORMANCE.md findings with them.
- Console framing fact (checked 20-JUL): runSim's console injector is ALREADY
  7 data bits + parity + 2 stop (matching the 7E2 the boot microcode programs
  into the SC2661) — NOT 8N1. 8N1 is used ONLY for the 300$ binary stream
  (`tx8n1`, Run120.cpp:477-481). The `0!`/`20!` `?` was empty RAM, not framing.
  P1 re-verifies the parity bit value against the SC2661 config.

## Deliverables layout

```
/mnt/e/Dev/Repos/Ronny/nd-120/Verilog/floppyTester/
  PLAN-floppy-validation.md      this file
  CONFORMANCE.md                 Phase 0 output: Verilog-vs-C matrix
  Makefile                       all phase targets (test-floppy-p1 .. p5)
  floppy_iox_tb.v                Phase 1
  floppy_bus_tb.v                Phase 2
  floppy_dmam_tb.v               Phase 3
  floppy_cmd_tb.v                Phase 4
  floppy_tester.cpp              Phase 5 Verilator harness (own obj_dir)
  testdata/                      generated diskettes (BPUN + FLOMON variants)
```
Every phase prints `TB_RESULT: PASS/FAIL` and is registered in
`/mnt/e/Dev/Repos/Ronny/nd-120/Verilog/tests/run_all_tests.sh`.

## Phases

### Phase 0 — Conformance analysis (no RTL edits)
1. Line-by-line matrix `ND_FLOPPY_DMA.v` vs `deviceFloppyDMA.c`: every IOX
   register (+0..+7), every status bit (both status words), command-block words
   0-11, geometry/format table, error codes, boot/autoload state machine,
   interrupt + IDENT behavior, test-mode.
2. Bus contract review: `ND_BUS_SLAVE.v`, `ND_DMA_MASTER.v` vs nd100x bus
   semantics.
3. Microcode `&` mass-boot loader analysis (listing + nd120uc .uc): exactly what
   stream format it accepts — resolves WHY FLOMON gets `?` and where support
   belongs (microcode already OK? device +0 stream? loader?).
4. Adjudicate on paper the two open anomalies: the combined-tb 7/8 DMA errors,
   and the Tang silent `1560&` (RAM at 002000 never verified against image).
Deliverable: `CONFORMANCE.md` listing every mismatch, each tagged
BUG / INTENTIONAL / UNKNOWN.

### Phase 1 — IOX register level (device alone)
Drive `iox_*` ports directly (no bus): all registers vs the C truth table —
+0 constant/boot stream, +2/+4 hardware status (bit-for-bit), +3 control
(device clear, int enable, test mode, autoload priority), +5/+7 pointers;
reset values; read side-effects (boot-stream consume). Gate: `test-floppy-p1`.

### Phase 2 — Bus signal level (through ND_BUS_SLAVE)
Same ops through real bus signals with per-edge assertions:
BAPR/BIOXE/BINPUT/BDAP/BDRY/BINACK sequencing and timing, address decode
1560-1567, drive-0-when-idle discipline, IDENT cycle, interrupt assert/clear.
Gate: `test-floppy-p2`.

### Phase 3 — DMA master + grant chain (adjudicate the 7/8 errors)
`ND_DMA_MASTER` against (a) the hand BCU model from the old tb AND (b) the real
board bus RTL (BIF/BCU as runSim presents it). BREQ/INGRANT/OUTGRANT, BMEM,
address/data phases, read vs write, timeout, MIN_GAP, back-to-back. This PROVES
whether the combined-tb DMA errors were harness or device. Fix what falls out.
Gate: `test-floppy-p3`.

### Phase 4 — Full command execution (device + DMA + memory)
Command-block fetch, read sector -> DMA -> memory (data byte-compared), write,
multi-sector + partial tail, sector-count mode, watchdog, status writeback,
READ FORMAT, and the `&` autoload boot stream fed BOTH a BPUN and a FLOMON
diskette (expected behavior per Phase 0 finding). Gate: `test-floppy-p4`.

### Phase 5 — floppy_tester.cpp: full stack against the SD card
Verilator harness in `floppyTester/` (side by side with runSim, own obj_dir):
`ND_FLOPPY_DMA` + `ND_BUS_SLAVE` + `ND_DMA_MASTER` + `nd_tape_sdfat_source`
(INCLUDE_TAPE=0, INCLUDE_FLOPPY=1 — the exact Tang config) + `sd_card_model`
(card carrying FLOPPY1.IMG) + `nds_mem_model`. Scripted escalation: mount ->
IOX regs -> sector reads byte-diffed against the card image -> writes -> boot
stream. Gate: `test-floppy-p5`.

### Phase 6 — Integration + system gates + silicon
1. Integrate the validated Verilog floppy into runSim behind a NEW dedicated
   make target (e.g. `make run-floppy-v` / VERILOG_FLOPPY=1) that serves the
   diskette through nd_storage instead of the C backend — WITHOUT touching the
   C-team's targets (co-existence rule).
2. runSim `1560&` gate with a TPE-MON diskette: extract
   `TPE-MON-100-A02:BPUN` from FLOPPY1.IMG with ndtool
   (`/mnt/e/Dev/Ronny/norskdata-ndfs`), build a bootable diskette, boot to the
   `TPE>` prompt (the pass pattern). FLOMON path per Phase 0 decision.
3. Tang: Gowin build, flash, `1560&`; if silent, diff Tang RAM 002000+ against
   the sim's loaded RAM (the unfinished test).

## Already-fixed alongside this plan (20-JUL)
- `make run-floppy` now pre-deposits `FILSYS-INV-Q04.BPUN` (the file-system
  investigator) so `20!` starts it against the mounted diskette; INSTRUCTION-
  VERIFY is deliberately NOT preloaded there. Empty-RAM floppy-BOOT testing
  uses the gates, not run-floppy.

# PLAN: extract board-independent ND120_CORE.v (behavior-preserving)

Grounded design (line-accurate against the real RTL). Execute from this.

## APPROVED 14-JUL-2026 (Ronny):
- Run120.cpp `__DOT__` path-prefix edit: CLEARED to edit (do it in step 2).
- Tang: move to a DEVICE-LESS core first (behavior-preserving); enabling
  tape/SD-FAT on Tang is a SEPARATE follow-up, not part of this refactor.
- Follow the RTL for the RAM seam (SDRAM-PHY pass-through only), not the
  "MEM_RAM_49-facing" wording in the original brief.

Execution status: **steps 1-3 DONE + COMMITTED (14-JUL-2026) on clock-enable-fix.**
`Verilog/ND120_CORE.v` is instantiated by both
tops. Step 1 (new-file-first, instantiated by nothing) elaborated clean in every
configuration:
- verilator --lint-only -Wall (runSim suppression set), top-module ND120_CORE:
  (1,1,1) sim; (0,0,0) sim; (1,0,0) sim; (1,1,1) FPGA FF-mode (no
  VERILATOR_SIM); (0,0,0) Tang defines incl. MAIN_RAM_SDRAM against the
  nd120_tang20k.gprj file list -- proves the (b) SDRAM PHY pass-through group.
- iverilog -g2012 elaborate, (1,1,1) and (0,0,0): rc=0.
- Gate: `make test` = 48/48 (the only failure is the PRE-EXISTING
  test-memchain, identical two lines to TODO.md:83; it fail-fast-aborts the
  suite, so the run was repeated with only that entry filtered out).
At step 1 this was zero behavior change by construction: no build globs the
Verilog root, so an unreferenced new file could not enter any build.

**Step 2 DONE (14-JUL-2026).** ND120_TOP.v now instantiates
`ND120_CORE #(1,1,1) CORE(...)` under `ND120_VERILOG_DEVICES` (and #(0,0,0)
with the storage seam tied off otherwise). External port list UNCHANGED.

- **PLAN CORRECTION: the `__DOT__` edit is 3 files, not 1.** The plan said only
  runSim/Run120.cpp; in fact:
  - `Verilog/runSim/Run120.cpp`          120 refs
  - `Verilog/sim/latch_ff_compare.cpp`    18 refs  <- the latch-vs-FF golden gate in test-full
  - `Verilog/sim/test_nd120.cpp`           4 refs
  Only TWO symbol classes needed rewriting, both mechanical:
  `ND120_TOP__DOT__CPU_BOARD` -> `ND120_TOP__DOT__CORE__DOT__CPU_BOARD` and
  `ND120_TOP__DOT__s_csbits` -> `ND120_TOP__DOT__CORE__DOT__s_csbits`.
  The other top-level symbols readers touch (clockTicks, s_debug_fidbo,
  s_debug_mr_n, s_test_4_0) stay at ND120_TOP or are unused by the C++.
- **Also needed:** `-I..` (the Verilog root, where ND120_CORE.v lives) added to
  VERILATOR_DIRS in `Verilog/runSim/Makefile` and
  `Verilog/sim/Makefile` -- otherwise Verilator
  cannot find ND120_CORE.

**BEHAVIOUR-NEUTRALITY PROVEN (not inferred).** Built HEAD's pre-refactor RTL in
a throwaway git worktree, overlaid with the CURRENT simDevices C models so both
sides share identical print gating, same flags
(`USE_LATCHES=0 -DSCRIPT_INPUT -DSCRIPT_CMD_GOLDEN`):
pre-refactor console == post-refactor console, **BYTE-IDENTICAL**.

**The runSim golden `runSim/golden/console_ff_golden.log` is STALE, and NOT
because of this refactor.** It still contains 20 C-model debug-print lines that
the floppy/tape session's uncommitted change gated behind `#ifdef DEBUG_INTERRUPT`
(NDDevices.cpp) and `if (DEBUG_BIF)` (NDBus.cpp:115, DEBUG_BIF=0). Proof that it
is theirs, not ours: the PRE-refactor baseline differs from the golden by the
SAME 20 lines, and `diff` of the two diffs is empty -- identical delta with and
without the core. Zero non-print lines differ. Regenerating that golden belongs
to the floppy/tape workstream.

Gates green after step 2: `make test` 48/48 (memchain filtered, as above);
`make test-tape` PASSED (Verilog tape-400 == C model, INSTRUCTION-B boots);
`make test-dma-rtl` PASSED (real arbiter granted, real RAM read+written);
`make test-dma-xcheck` PASSED (OPCOM-written word read back over DMA).

**Step 3 DONE (14-JUL-2026).**
`Verilog/fpga/tang-nano-20k/src/ND120_TANG20K_TOP.v`
now instantiates `ND120_CORE #(0,0,0) CORE(...)` instead of ND3202D directly
(device-LESS = previous Tang behaviour). Board keeps rPLL/POR/tie-offs/
LED-write-analyzer/clockTicks; its duplicate installation_number / s_high /
s_low / SEL_TESTMUX / baud-rate wires are dropped (now core-internal).
- **Also needed:** the Tang flow uses an EXPLICIT file list, not -I dirs, so
  `<File path="../../ND120_CORE.v" .../>` was added to
  `Verilog/fpga/tang-nano-20k/nd120_tang20k.gprj`
  (right before src/ND120_TANG20K_TOP.v). Without it Gowin/vtest cannot find
  the core.
- Gate: `make -C fpga/tang-nano-20k/sim vtest` -> **TB_RESULT: PASS**
  (boots, OPCOM prompt, deposit 22/054321 readback verified). This exercises
  the (b) SDRAM PHY pass-through AND the all-devices-absent wired-AND collapse
  on real RTL, not just lint.

## Step 4: every test-full stanza PASSES individually. The aggregate
## `make test-full` still aborts on ONE pre-existing failure that is not ours:
`test-memchain` (TODO.md:83), which its `test` prerequisite hits fail-fast.

Stanza-by-stanza, all green:
- unit suite 48/48 (memchain filtered)
- `make -C sim compare`: trace_ff.csv AND trace_latch.csv **BYTE-IDENTICAL** to
  their goldens -- cycle-by-cycle signal-level proof, in BOTH latch and FF mode,
  that the extraction changed nothing. (Also exercises the rewritten
  `sim/latch_ff_compare.cpp` hierarchical paths.)
- runSim FF console vs golden: **BYTE-IDENTICAL** (see the print-gating note below)
- Tang `make vtest`: TB_RESULT: PASS
- `make test-tape`, `make test-dma-rtl`, `make test-dma-xcheck`: PASSED
- `make test-floppy-stdin`: PASSED
- `make test-instr-argument`: TB_RESULT: PASS (400 aligned instructions match)
- pre-refactor vs post-refactor runSim console: byte-identical (see above).

### The console golden gate: debug prints are compiled in for THIS GATE ONLY
`golden/console_ff_golden.log` was recorded while the C device models printed
their IDENT/interrupt trace unconditionally. The floppy/tape session gated those
prints OFF by default (they drowned a 400$ load --
docs/BUG-tape400-sd-level12-storm.md), which made the golden unreproducible.
Resolution (Ronny's call 14-JUL): do NOT re-record the golden and do NOT turn the
prints back on globally -- compile them in **only for the gate**:
- `Verilog/Makefile` test-full passes `-DDEBUG_INTERRUPT` on the console-gate
  compile ONLY. Default runs stay quiet (verified: 0 debug lines by default,
  20 with the define).
- `-DDEBUG_INTERRUPT` is exactly right; **`-DDEBUG_BIF=1` is NOT** -- it also
  emits the BAPR/BIOXE bus trace, which the golden does not contain.
- One dependency: `simDevices/NDBus.cpp`'s `IDENT LVL[..]` print had been placed
  under `DEBUG_BIF`; it is IDENT tracing, so it now also fires under
  `DEBUG_INTERRUPT`. Without that hunk the gate is 4 lines short.
Result: gate reproduces the golden byte-for-byte, prints stay off in normal runs.

## TWO findings that reshape the task framing

1. **RAM is NOT at the top level — the "MEM_RAM_49-facing RAM backend" in the
   task brief does not exist as a top boundary.** `ND120_TOP.v` never
   instantiates `MEM_RAM_49`; RAM lives `ND3202D → MEM_43 → MEM_RAM_49`
   (ND3202D.v:961). Sim/Basys3 = on-chip BRAM *inside* MEM_RAM_49; Tang SDRAM is
   selected *inside* MEM_43 by `ifdef MAIN_RAM_SDRAM` and threaded UP through
   ND3202D's conditional port group (ND3202D.v:155-172). So the core's "RAM
   backend" seam is ONLY the SDRAM-PHY pass-through group (present under
   `MAIN_RAM_SDRAM`); on sim/Basys3 there is NO RAM port at all. Following the
   literal "MEM_RAM_49-facing" framing would break the build.

2. **Hierarchical-path breakage (highest risk).** `runSim/Run120.cpp` reaches
   into `ND120_TOP__DOT__CPU_BOARD__DOT__...` (Run120.cpp:498-502, 613-621, 669+)
   and `ND120_TOP__DOT__s_csbits` (:613). Interposing ND120_CORE renames every
   such path → ~15 accessors break. Fix = keep a fixed core instance name
   (`CORE`) + one mechanical prefix edit in Run120.cpp
   (`ND120_TOP__DOT__CPU_BOARD` → `ND120_TOP__DOT__CORE__DOT__CPU_BOARD`, and
   `s_csbits`). NDBus.cpp is SAFE (top-level ports only, no `__DOT__`).
   ND120_TOP's EXTERNAL port list (lines 33-151) must NOT change.

## ND120_CORE.v = ND3202D `CPU_BOARD` + device chain (440-730) + wired-AND. No PLL/POR/7-seg/LED-map/SDRAM-primitive/clockTicks.

Params: `INCLUDE_TAPE, INCLUDE_FLOPPY, INCLUDE_SMD` (default 0), via `generate`.

Port groups:
- **(a) clock/reset:** `clk_cpu` (the net feeding ND3202D.sysclk/CLOCK_1/CLOCK_2 + s_dev_clk — one net in both branches), `sys_rst_n`.
- **(b) RAM backend — only under `MAIN_RAM_SDRAM`:** pass-through of ND3202D.v:158-171 (`clk2x, clk2x_sdram, O_sdram_*, IO_sdram_dq[31:0], O_sdram_addr[10:0], O_sdram_ba[1:0], O_sdram_dqm[3:0], DBG_MEMW[15:0]`). Absent on sim/Basys3.
- **(c) storage backend (byte/disk SOURCE ports; board supplies impl) — per INCLUDE_*:**
  - tape: `TAPE_BYTE_REQ`o `TAPE_BYTE_VALID`i `TAPE_BYTE_DATA[7:0]`i `TAPE_REWIND`o
  - floppy: `FDISK_REQ/WR`o `FDISK_LSECT[15:0]`o `FDISK_FORMAT[1:0]`o `FDISK_DRIVE[1:0]`o `FDISK_WORDCOUNT[10:0]`o `FDISK_DONE/ERR`i `FDISK_MEDIA_FMT[3:0]`i `FDBUF_ADDR[9:0]`i `FDBUF_WDATA[15:0]`i `FDBUF_WE`i `FDBUF_RDATA[15:0]`o
  - smd: `SDISK_START/REQ/WR`o `SDISK_BLKADDR1/2[15:0]`o `SDISK_UNIT[2:0]`o `SDISK_WORDCOUNT[10:0]`o `SDISK_DONE/ERR`i `SDBUF_*` like floppy
  - dma-test client (gate with INCLUDE_FLOPPY||INCLUDE_SMD): `DMA_REQ/WR/ADDR[23:0]/WDATA[15:0]`i `DMA_RDATA[15:0]/ACK/ERR/BUSY`o
- **(d) UART:** `RXD`i `TXD`o.
- **(e) C-PLUG bus — ALWAYS present (drop the VERILATOR_SIM gating; board drives-or-ties):** ins `BREQ_n,BINT10..13_n,BINT15_n,POWSENSE_n,BD_23_0_n_IN[23:0],SEMRQ_n_IN,BINPUT_n_IN,BDAP_n_IN,BDRY_n_IN,BAPR_n_IN`; outs `BD_23_0_n_OUT[23:0],SEMRQ_n_OUT,BINPUT_n_OUT,BDAP_n_OUT,BDRY_n_OUT,BAPR_n_OUT,BREF_n,BERROR_n,BINACK_n,BIOXE_n,BMEM_n,OUTGRANT_n,OUTIDENT_n,MCL`. FPGA tie-offs (ND120_TOP:158-193, Tang:100-116) move to the BOARD.
- **(f) debug/LED (all out):** `LED[6:0]`(s_cpu_led), `RUN_n`(s_run), `CSA_12_0[12:0]`, `LA_23_10[13:0]` (route from the CPU internal `s_debug_la_23_10` @795, NOT the stubbed ND3202D port @556 or the 7-seg goes dark), `CA_9_0[9:0]`, `DEBUG_CC_TERM[4:0]`, `DEBUG_MCLK/LCS_n/FETCH/MR_n/CLEAR_n/REFRQ_n/INTRQ_n/POWFAIL_n`, `DEBUG_FIDBO_15_0[15:0]`.

## Move-map (ND120_TOP.v)
- 33-151 port list → STAYS (ND120_TOP contract unchanged).
- 158-193 FPGA bus tie-offs → STAYS-IN-BOARD; bus signals BECOME core ports.
- 196-215 installation_number/s_high/s_low/oc_select/SEL_TESTMUX/baud → MOVE-TO-CORE (constants; drop Tang's dup installation_number).
- 217-266 debug wires → gen MOVE-TO-CORE; the `mark_debug` board wires (231-240) STAY (ILA is board).
- 267,409-413 clockTicks → STAYS-IN-BOARD. 269-299 POR → STAYS (sys_rst_n = core input). 301-364 MMCM/clk1 → STAYS (clk_cpu = core input). 366-407 LED map → STAYS. 415-432 7-seg → STAYS.
- 434-730 device chain + wired-AND + no-device else → MOVE-TO-CORE (INCLUDE_* generate).
- 732-838 `ND3202D CPU_BOARD` → MOVE-TO-CORE (KEEP instance name `CPU_BOARD`).

ifdef resolution: keep `USE_TRANSPARENT_LATCHES`/`FPGA_FF_MODE` global (submodule-internal). `MAIN_RAM_SDRAM` = board defines it + wires PHY; core conditionally exposes (b). `ND120_VERILOG_DEVICES` → INCLUDE_* params. `VERILATOR_SIM` bus gating → bus ports unconditional on core, tie/drive on board. `s_dev_clk` collapses to `clk_cpu`.

## Device parameterization (generate; graceful degradation)
All shared nets are OR-buses / daisy chains — tie ABSENT devices to inactive in the generate-else, then the existing expressions are safe verbatim:
- IOX OR-bus / int / ident (462-465): absent device's `s_*_rdata=16'd0, intp=4'd0, hit=1'b0, code=16'd0`.
- IDENT grant chain (510-511/543/621): absent stage `grant_out=grant_in` (pass-through); head=1'b1.
- DMA grant chain (588/667/698): absent master `OUTGRANT_n=INGRANT_n`. **Keep DMA_MASTER present whenever any master exists** (it's the chain head, INGRANT=CPU OUTGRANT_n @697) — gate dma-test with INCLUDE_FLOPPY||INCLUDE_SMD.
- Bus wired-AND (709-718): absent device bus contribs tied `24'hFFFFFF`/`1'b1` so the AND stays. The else (719-730) = all-absent case. Declare all chain wires up front (forward-ref s_grant_fdma_smdm_n used @589 declared @650).

## Storage seam = the byte/disk SOURCE ports at the core boundary; nd_storage adapter lives on the BOARD.
Core instantiates ND_TAPE_400, wires byte_req/valid/data/rewind → core TAPE_BYTE_* ports; core knows nothing of SD-FAT. Sim board forwards TAPE_BYTE_* to ND120_TOP ports (NDBus.cpp file model, unchanged). Tang board instantiates `nd_tape_sdfat_source` pin-for-pin. DO NOT pull the nd_storage client port to the core boundary (would break the C reference path + test-tape gate). Clock note: nd_tape_sdfat_source needs clk_stor + clk_cpu; board feeds its clk_cpu with the SAME net as core clk_cpu, supplies clk_stor from storage domain; rst_cpu_n aligned to sys_rst_n. clk_stor never enters the core.

## Top rewiring
- ND120_TOP.v (Basys3+sim): unchanged external ports; keeps POR/MMCM/LED/7-seg/heartbeat/FPGA-tie-offs; instantiates `ND120_CORE #(.INCLUDE_TAPE(1),.INCLUDE_FLOPPY(1),.INCLUDE_SMD(1)) CORE(...)` forwarding clk_cpu, sys_rst_n, C-PLUG bus (ports in sim / tie-offs in FPGA), RXD/TXD, all TAPE_BYTE_*/DMA_*/FDISK_*/SDISK_* 1:1, debug bundle → s_debug_*/s_cpu_led/s_run. DMA-test stays wired to sim ports (683-706) so DMA gates pass.
- ND120_TANG20K_TOP.v: keeps rPLL/POR/tie-offs/LED-write-analyzer/clockTicks; replaces direct ND3202D (294-405) with `ND120_CORE #(0,0,0)` for **Phase 1** (device-less = current Tang behavior, keeps vtest green); feeds clk_cpu, sys_rst_n, (b) SDRAM pass-through, tied bus, uart, DBG_MEMW; drops local installation_number. Phase 2 (separate change): INCLUDE_TAPE(1) + nd_tape_sdfat_source on board.
- Future boards: ND120_CORE + own I/O; no device-chain copy = no drift.

## Validation staging (green at every commit)
1. **New-file-first:** add ND120_CORE.v, do NOT instantiate. Elaborate-only (verilator --lint-only / iverilog). Zero behavior change. Commit.
2. **Switch sim/Basys3 top** to instantiate CORE + apply Run120.cpp `__DOT__` prefix edits (only harness change). Gates: `make test`, `make test-tape`, `make test-dma-rtl`, `make test-dma-xcheck`, runSim console-vs-golden (test-full middle stanza). Commit when green.
3. **Switch Tang top** to device-less CORE. Gate: `fpga/tang-nano-20k/sim make vtest` (+Verilator vtest). Proves SDRAM pass-through + no-device wired-AND collapse. Commit.
4. **Full sweep:** `make test-full` (+ optionally test-floppy-boot/test-smd-boot/test-instr). Commit.

## Risks
Hierarchical paths (Run120.cpp, #1 — mechanical prefix, verify CSA/console traces after step 2); interleaved ifdefs (keep latch/FF globals untouched); single-clk_cpu collapse (verified valid both branches); DMA-test = grant-chain head (keep present with any master); single reset source (board POR only, no 2nd reset in core); undriven-wire silent mis-decode (tie every absent-device contrib; lint UNDRIVEN/UNOPTFLAT after step 1); LA_23_10 stub (route from s_debug_la_23_10 @795 not the @556 stub).

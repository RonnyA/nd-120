# Plan: eliminate all 47 unconstrained-clock warnings (17 rogue clock nets)

**Full path:** `/mnt/e/Dev/Repos/Ronny/nd-120/Verilog/docs/plan-fix-unconstrained-clocks.md`
**Date:** 9-JUL-2026
**Branch:** clock-enable-fix
**Why:** the Tang deposit bug was measured down to cross-clock-domain timing:
every ND-120 layer, the SDRAM bridge FSM, and sdram18.v (dedicated hardware
test at 13.5 MHz) are proven correct in isolation; the full build fails with
per-bitstream-stable wrong reads - the signature of unconstrained
register-as-clock domains. The Gowin log's 47 "WARN (TA1117) can't calculate
clocks' relationship" are 47 symmetric pairs over 17 nets used as clock pins.
Fixing all 17 IS the clock-enable refactor this branch exists for.
Background: `docs/HANDOFF-basys3-memory-write.md`,
`fpga/tang-nano-20k/TRACE-CAPTURE-GUIDE.md`.

## The 17 rogue clock nets

| #  | Net (Gowin name)          | Clocks what                                        | Phase |
|----|---------------------------|----------------------------------------------------|-------|
| 1  | `s_clk` (CYC CLK)         | DGA F924s (incl. the WRITE flop), IO consumers     | P2e   |
| 2  | `s_uclk_Z`                | microcode pipeline registers                       | P2c   |
| 3  | `s_mclk_Z`                | MCLK-domain registers                              | P2d   |
| 4  | `s_aluclk_Z`              | ALU registers (CGA_ALU_*)                          | P2b   |
| 5  | `s_rfclk`                 | WRF write strobes                                  | P2a   |
| 6  | `s_clk3_n_10`             | DGA internal inverted clk3                         | P2e   |
| 7  | `MEM/s_rdata`             | MEM_DATA_46.v:219,245 AM29861A read latches        | P1a   |
| 8  | `s_refrq_n`               | MEM_ADEC_45.v:175 D_FLIPFLOP                       | P1b   |
| 9  | `s_dbg_memw_0[2]` = **ECREQ** (v4 dbg layout bit2; NOT MWRITE50_n) | MEM_ADEC_45.v:235,238 `.CK(s_ecreq)` | P1c   |
| 10 | `BGNT_n_9`                | BIF_DPATH_BDLBD_10.v:75,94,113 TTL_74646/648 `.CLKBA(s_bgnt_n)` | P1d   |
| 11 | `DSTB_n_34`               | BIF_DPATH_CDLBD_11.v:77,93 TTL_74646 `.CLKAB(s_dstb_n)` | P3    |
| 12 | `BIF/SPES_12`             | BIF_DPATH_PESPEA_13 parity registers               | P3    |
| 13 | `s_ibapr_n_Z`             | BIF bus-address capture                            | P3    |
| 14 | `DELILAH/s_ldirv_2835`    | CGA_CPU_ALU_CONTR.v:657,669 IR registers           | P3    |
| 15 | `IO/s_sioc_n`             | IO_37 registers                                    | P3    |
| 16 | `DCD/s_div_16`, `s_XRTOSC`| IO_DCD_38.v:403 RTC divider chain                  | P3    |
| 17 | `sys_rst_n`               | `sys_rst_n_s0/F` (per .tr; find RTL flop in P4)    | P4    |

### P0 inventory addendum (9-JUL-2026, RTL clock-port sweep)

Additional register-as-clock consumers found by grepping every clock-capable
port hookup (`.CK/.CP/.CLK/.clock/.CLKAB/.CLKBA/.LE/.RAS_n/.CAS_n`) in
`CPU-BOARD-3202/circuit`, `DECODE-GateArray`, `DELILAH-CPU`. These do not all
appear as separate TA1117 clocks (some merge or optimize in synthesis) but
they are the same disease and get fixed in the same phase as their neighbors:

| Net             | Clocks what                                            | Phase |
|-----------------|--------------------------------------------------------|-------|
| `s_dbapr`       | MEM_ADEC_45.v:270,273 `.CK(s_dbapr)`                   | P1c   |
| `s_ddbapr`      | MEM_ADEC_45.v:163 `.clock(s_ddbapr)` D_FLIPFLOP        | P1c   |
| `s_spesl`       | MEM_ERROR_47.v:114 `.CK(s_spesl)`                      | P3    |
| RAS_n/CAS_n     | MEM_RAM_49.v:170-272 SIP1M9 row/col/write capture      | P1e   |
| `s_clk1/s_clk2/s_clk3(_n)` | DECODE_DGA_COMM.v:959-1146 F924 banks (internal CYC-derived) | P2e |
| `s_mclk` as LE  | CPU_PROC_32.v:324 `.LE(s_mclk)` AM29841 latch          | P2d   |

Clock Summary cross-check (`build/nd120_tang20k_build/impl/pnr/*.tr` 2.2):
19 base clocks = sys_clk + the 18 rogue roots; matches the table above plus
`s_ldirv` (source `DCD/GATES_10/s_ldirv_s3/F` - a LUT output as clock).
Max-frequency reality check from the same report: `s_clk` domain Fmax
**2.689 MHz**, `s_mclk` 2.732 MHz, `s_aluclk` 5.286 MHz - even the
*constrainable* paths are 5-10x too slow for the 13.5 MHz clk2x, and TNS
on aluclk is -40862 ns over 355 endpoints. P2 does not just constrain
these paths, it moves them onto sysclk where the tools can finally retime.

Rules that bind every phase:
- **Never modify `Verilog/PAL/PAL_*.v`** - conversions live in consumers or
  `_D` wrapper modules (CYC_CC_D / PAL_44446B_D pattern).
- **Convert a clock domain whole, never partially** (R41P lesson: a
  half-converted domain creates phase skew between its own registers).
- One net / one domain per commit - every step revertable and bisectable.
- All conversions sit behind `FPGA_FF_MODE`; latch mode (original hardware
  semantics) stays byte-identical.

## Phase 0 - inventory + golden baselines (no RTL changes)

1. Extract the exact register list per rogue clock from the Gowin timing
   report Clock Summary (`build/nd120_tang20k_build/impl/pnr/*.tr`, "Objects"
   column) - closes the two TBDs (#9, #10) and sizes every P2 domain.
2. Capture golden references (see the validation harness below):
   `Verilog/sim/golden/trace_{ff,latch}_golden.csv` and
   `Verilog/runSim` golden console log (boot + deposit + `0!` + `20!`).
3. **Mechanism confirmation build (SDC-only, throwaway):** add
   `create_generated_clock` for the five CYC clocks and `set_max_delay` on
   the control-strobe paths to `nd120_tang20k.sdc`, rebuild, `make load`,
   deposit on the console. A constrained build that suddenly deposits
   correctly proves the diagnosis for ~30 min of work. Whatever the result,
   the SDC probe is then REVERTED - the RTL refactor is the real fix (the
   Basys3/Vivado build needs it too, and generated-clock constraints on
   gated clocks are fragile).

## Phase 1 - memory-path capture points (deposit-critical, smallest blast radius)

Convert #7-#10 to the proven sysclk edge-capture pattern (`AM29C821`
`USE_SYSCLK=2` - one capture per detected CK rise, no routed clock; the same
fix that solved the MEM_ADDR_44 deposit regression):

- **P1a** MEM_DATA_46 RDATA read latches (add USE_SYSCLK-style mode to
  AM29861A, matching AM29C821's).
- **P1b** MEM_ADEC_45:175 refrq_n flop -> sysclk + refrq edge detect.
- **P1c** MWRITE50_n-as-clock consumer (from P0 inventory).
- **P1d** BGNT_n-as-clock consumer (from P0 inventory).
- **P1e** SIP1M9 / MEM_RAM_49 RAS-edge row capture -> sysclk + RAS edge
  detect (Basys3 evidence: PAL_44902 RAS_n is an unconstrained root clock
  feeding the BRAM row capture - deposit-critical on the Basys3; see the
  Basys3 appendix).

After P1: Gowin rebuild, expect the corresponding TA1117 pairs gone; board
deposit test. There is a real chance deposits start working here, before P2.

## Phase 2 - the CYC_36 generated CPU clocks (the branch thesis)

`CYC_36` additionally emits one-sysclk-wide enable pulses aligned with each
level-registered clock: `CLK_EN, UCLK_EN, MCLK_EN, ALUCLK_EN, RFCLK_EN`.
Consumers convert from `posedge s_xclk` to `posedge sysclk + if (XCLK_EN)`,
one whole domain per commit, smallest first:

- **P2a** s_rfclk domain (WRF)
- **P2b** s_aluclk domain (CGA_ALU)
- **P2c** s_uclk domain (microcode pipeline)
- **P2d** s_mclk domain
- **P2e** s_clk domain (DGA XCLK + IO). Converting the DGA turns F924 into
  sysclk+CE and dissolves the internal clk2/clk3/clk3_n (#6) for free.

## Phase 3 - control-strobe clocks (#11-#16)

Same edge-capture conversion, batched per module: BIF batch (DSTB_n, SPES,
ibapr_n), CGA batch (LDIRV), IO batch (sioc_n, div_16, XRTOSC divider chain
-> sysclk counter with terminal-count enables).

## Phase 4 - sys_rst_n as clock (#17)

Find the flop clocked by the reset net (P0 inventory); replace with an
async-assert / sync-release reset synchronizer in the sysclk domain.

## Phase 5 - zero-warning enforcement + Basys3

- Final Gowin build: **0 x TA1117 required.**
- Add a post-build check to `gowin_build.tcl`: grep the log for TA1117 and
  fail loudly - the bug class must not silently return.
- Board acceptance: deposit `22/ 054321` readback + `0!`/`20!` expected text.
- Rebuild Basys3 (Vivado) from the same RTL; `check_timing` must report no
  unconstrained memory-path domains; retest deposit there.

---

## Validation harness - every conversion, one by one, same five gates

Golden capture (once, Phase 0):

```bash
cd Verilog/sim
make compare                          # builds latch + FF, runs both, diffs
mkdir -p golden
cp trace_ff.csv    golden/trace_ff_golden.csv
cp trace_latch.csv golden/trace_latch_golden.csv

cd ../runSim
make clean && make compile USE_LATCHES=0 && make run
# scripted session -> golden/runsim_ff_golden.log:
#   boot to '#'; deposit 22/ 054321 CR 22/ -> /054321; 0! and 20! full text
```

Per conversion - stop at the first failing gate and REVERT (never patch
forward on a red gate):

1. **Module equivalence tb** (iverilog, seconds, in the module's own `sim/`):
   original + converted instantiated side by side, identical stimulus
   (directed + random), outputs asserted equal every cycle. Same pattern as
   the PAL_44446B_D / CYC_CC_D equivalence tbs. Must PASS - and where
   practical, must FAIL when run against a deliberately broken conversion
   (proves the tb has teeth, like MEM_ADDR_44_tb did against 9b005c2).
2. **Verilator trace identity** (minutes): `cd Verilog/sim && make compare`;
   `diff trace_ff.csv golden/trace_ff_golden.csv` and
   `diff trace_latch.csv golden/trace_latch_golden.csv` both EMPTY.
   Byte-identical, not "equivalent-looking".
3. **Verilator full-CPU gate** (`runSim`, FF mode): console output
   byte-identical to `golden/runsim_ff_golden.log` (boot, deposit readback,
   `0!`, `20!`), self-test STERR not regressed from the 7/14 baseline.
4. **Tang full-build compile gate** (seconds):
   `cd fpga/tang-nano-20k/sim && make nd120_tang20k_tb.vvp` - the exact
   Gowin file list still elaborates.
5. **Hardware gate** (~10 min): Gowin rebuild -> TA1117 count drops by
   exactly the pairs owned by the converted net (per-item proof) ->
   `make load` -> deposit readback + `0!` on the 9600 console. On a board
   regression with green sim gates: on-chip analyzer per
   `fpga/tang-nano-20k/TRACE-CAPTURE-GUIDE.md`.

Bookkeeping: a running table in this file (net -> commit -> TA1117 count
after) so progress toward 0 is visible and any regression bisects to one
commit.

| Step | Net(s) | Commit | TA1117 after | Board deposit |
|------|--------|--------|--------------|---------------|
| baseline | - | - | 47 | FAIL |

---

## Per-step evaluation checklist - foreseen traps (read BEFORE each step)

Everything below is a lesson this project has already paid for once, or a
trap visible in the code today. Each conversion step must answer the
questions that apply to it, in writing (one line each in the commit
message is enough).

### Cross-cutting (every step)

- **Level vs edge - the 9b005c2 question.** For every capture conversion:
  "how many captures happen per original clock edge?" A LEVEL enable
  re-captures on every sysclk while the strobe stays high (that exact bug
  broke MEM_ADDR_44 deposits); the answer must be EXACTLY ONE -> edge
  detect (`USE_SYSCLK=2` semantics).
- **Added latency audit.** Sysclk edge-detect delays the capture by 1-2
  sysclk. For each conversion, name the downstream consumer and verify the
  captured value is still stable/valid when consumed - per board (Basys3
  sysclk 100 MHz vs Tang 27 MHz: different margins in ns, different in
  cycles).
- **Glitchy strobe check.** Edge-detect on a COMBINATIONAL strobe (NAND
  tree output) can double-capture on a glitch. Before converting: is the
  source a registered PAL output (clean) or combinational logic
  (RDATA is - see P1a)? If combinational, either capture from the
  registered upstream signal instead, or require 2-cycle stability -
  and then re-run the latency audit.
- **Clock-as-data.** Several "clocks" are ALSO read as logic inputs
  (`s_uclk` feeds DGA A237 NAND as DATA; CLK feeds gate logic). Converting
  a domain to enables must KEEP the level-shaped net alive for data
  consumers. P0 inventory must list, per rogue clock: edge consumers
  (convert) vs data consumers (keep net).
- **Negedge users.** Some flops clock on the INVERTED net (`s_clk3_n`).
  Inventory must tag posedge vs negedge users; negedge users need their
  own falling-aligned enable, not the rising one.
- **ifdef hygiene.** Conversions live under `FPGA_FF_MODE`; latch mode
  keeps the original clocking. Gate 2 checks BOTH traces - a diff in
  trace_latch.csv means the ifdef leaked. The equivalence tb should use
  the latch-mode original as the reference model.
- **PNR-lottery rule.** v1-v3 vs v4 bitstreams proved a green board test
  on ONE bitstream does not prove timing correctness. At each phase
  boundary (end of P1, each P2 domain, end of P3): build TWICE (touch a
  comment / change seed) and BOTH bitstreams must pass the board gates.
- **Sim-green + board-red = timing model, not logic.** Zero-delay
  Verilator can hide (or invent) phase overlaps (designer's note: real
  ASIC+TTL delays differ). If gates 1-4 are green and gate 5 fails, do
  NOT loop on RTL guesses - go straight to the on-chip analyzer
  (TRACE-CAPTURE-GUIDE.md); the bus is already pointed at the memory path.
- **Interpretation guards for board data:** AM29833A drives hard 0 when
  disabled (reads-as-0 is not "clean"); uninitialized SDRAM returns
  STABLE junk, not random; OPCOM input must be paced >= 0.3 s/char; after
  an analyzer dump the console is dead until S1/reprogram.
- **Golden discipline.** Goldens change ONLY in a dedicated commit with a
  written reason ("intentional behavior change because X"), never inside
  a conversion commit. "Shifted but consistent" traces are a red gate
  until explicitly signed off.
- **Debug infrastructure survives.** Conversions must not break the
  DBG_MEMW tap or the analyzer trigger (bit [7] convention) - they are
  the gate-5 diagnosis tool.

### P0 specifics

- Gowin `.tr` names are post-synth (`_Z`, `_10` suffixes, flattened
  hierarchy); Vivado names differ again. Build the inventory as a
  three-column map: RTL net -> Gowin name -> Vivado name, or later steps
  will chase ghosts.
- Tag each rogue clock with which builds contain it (Tang / Basys3 /
  both) - some sit inside board-specific ifdefs.
- SDC-probe interpretation is asymmetric: deposits working = mechanism
  PROVEN; deposits still broken = NOT disproven (generated-clock
  constraints on stoppable/gated clocks like UCLK are approximations).
  Do not let a failed probe cancel the plan.

### P1 specifics

- **P1a RDATA** is combinational in MEM_DATA_46 - the glitch check above
  applies in full. Prefer capturing from the registered signal upstream
  of RDATA if one exists; identify it in P0.
- **P1b refrq_n**: refresh interacts with the SDRAM bridge's self-timed
  refresh on Tang - verify no double-refresh assumptions break.
- **P1e SIP1M9 RAS row capture**: RAS comes from a registered PAL
  (clean edge), but the row must be captured BEFORE AA switches to
  column (1 OSC cycle later). Do the per-board latency math: Basys3
  100 MHz sysclk = fine; confirm for the BLOCKRAM path too
  (MEM_RAM_49_BLOCKRAM has its own capture).
- After each P1 item on a still-failing board: rerun the analyzer BEFORE
  the next item - phase-1 items can interact, and the trace tells which
  one moved the behavior.

### P2 specifics

- **Enable/clock alignment is THE risk.** CYC_36 FF-mode clocks are
  LEVEL-registered (`q <= next` - the fix for the 0!/20! hang). Each
  enable must assert in the sysclk cycle whose edge corresponds to that
  clock's RISE. An off-by-one shifts the whole domain; gate 2 catches it
  as a byte-diff - treat as red, never rationalize.
- **MACLK/ACAL interlock:** MACLK's LEVEL feeds ACAL latch transparency
  (that was the 0!/20! hang). When converting mclk/uclk domains, keep the
  level nets driving ACAL until ACAL itself is converted; re-verify
  execution (`0!` AND `20!`), not just boot - the original bug booted
  fine.
- **WRF write strobes (P2a):** pulse-width-sensitive - the enable must
  produce exactly one write per WPN assertion; check both WPN polarity
  and the InvertClockEnable parameter usage in D_FLIPFLOP.
- **DGA port threading (P2e):** CLK2/CLK3 enter the DGA as ports (XCLK).
  Enables need new ports through DECODE_DGA -> IO_DCD_38 -> IO_37 ->
  ND3202D. Design the port additions ONCE up front (like the sysclk
  threading for the _D PALs), not incrementally per flop.
- **Self-referencing producers:** CYC_36 consumes clocks it generates.
  Convert CYC's own consumers LAST within each domain, and only after the
  external consumers are green.
- **Microword-derived clocks (Basys3 WCS DOADO finding):** clocks decoded
  from microword bits change when the microword changes - the enable
  generation must sample the DECODED signal at the same point in the
  microcycle as the original clock edge did. Evaluate against the nd120uc
  microcode bitfield doc when in doubt about a field's intent.

### P3 specifics

- **LDIRV (IR load):** confirm pulse-vs-level and whether the IR is read
  later in the SAME microcycle (fast decode paths) - added capture
  latency could feed decode stale IR bits.
- **BIF strobes (DSTB/SPES/IBAPR):** the external ND-100 bus is tied off
  on both boards - parts of this logic may be UNEXERCISED by every gate.
  Convert anyway (warning-zero goal) but mark residual risk in the
  commit: gates prove nothing for dead logic. Do not spend evenings
  building tbs for logic no board path exercises.
- **MMU TMM / PROM data-as-clock (Basys3 list):** these live in shared
  chip models (`TMM2018D_25`, PROM path) used by ALL builds and
  Verilator - a fix there hits everything; run the full gauntlet plus
  `runSim` latch mode, and check ramSize/board ifdefs inside the models.
- **RTC dividers (XRTOSC/div16):** derive every count from
  `BOARD_CLK_FREQ` (established rule from the OPCOM speed fix) - no
  magic numbers.

### P4 specifics

- por_done/LOCKED clock 41 flops each - likely init logic. Reset
  sequencing matters: WCS preload (SKIP_WCS_LOAD) and MMCM lock order
  must be preserved; write down the intended reset ordering (lock ->
  por -> sys_rst_n release -> first CPU cycle) and verify each converted
  flop still initializes before first use. Async-assert / sync-release
  only; no flop may remain CLOCKED by a reset.

### P5 specifics

- Vivado gets the same enforcement as Gowin: fail the build if
  `check_timing` no_clock count != 0 (add to vivado_build.tcl next to the
  TA1117 grep in gowin_build.tcl).
- Multicycle constraints (the -33.6 ns follow-on): every
  `set_multicycle_path` must cite its justification from the CYC/
  microcode cycle structure (which OSC cycle launches, which consumes).
  Blanket multicycles or unexplained false paths are forbidden - that is
  how real failures get constrained into silence.

---

## Appendix: Basys3 / Vivado evidence (9-JUL-2026 build, logs in `fpga/basys3/logs/`)

The 9-JUL Vivado build (`vivado_build.log`, `timing_impl.rpt`, Vivado
2025.2.1, routed) confirms the same disease and measures it more deeply.
Board symptom matches the Tang exactly: OPCOM starts, memory writes wrong.

**1. Same unconstrained-clock problem, much bigger measured extent.**
`check_timing` reports **32,522 register pins with no clock**, tracing to
**813 distinct rogue root-clock registers** (Gowin's 47 TA1117 pairs were
only the domains Gowin tried to relate). All 17 Tang nets are present, plus
classes Gowin never named:

| Rogue clock class (Basys3)                  | Where                                  | Plan phase |
|---------------------------------------------|----------------------------------------|------------|
| WCS BRAM data outputs (33 chips x DOADO)    | `CPU/CS/WCS/CHIP_*` - microword bits clock downstream flops | P2 (same microword-derived clocks) |
| **PAL_44902 RAS_n as clock**                | `MEM/RAMC` -> SIP1M9 RAS-edge row capture | **P1e (NEW - Basys3 deposit-critical)** |
| MMU PT/CACHE RAM outputs (TMM chips)        | `CPU/MMU/PT/CHIP_2xG`, `CACHE/CHIP_20F` | P3 (add) |
| PROM regData[15:0] as clocks                | `CPU/CS/PROM`                          | P3 (add) |
| BIF PAL registered outputs                  | 44401 Q1/Q2, 44801 CACT, 45001 RERR + SYNC latches, PESPEA | P3 |
| por_done / MMCM LOCKED as clocks (41 pins each) | reset structure                    | P4 |

**Action taken in the plan:** P1 gains **P1e - SIP1M9/MEM_RAM_49 RAS-edge
capture -> sysclk edge-detect** (same USE_SYSCLK=2 pattern). RAS-as-clock
on the BRAM row capture is the direct Basys3 analog of the Tang finding
and is deposit-critical there.

**2. NEW information Gowin did not show: the CONSTRAINED domain also fails
timing outright.** `clk_cpu_pre` period 60 ns (16.67 MHz): **WNS -33.6 ns,
TNS -8942 ns over 406 endpoints**. Worst path `CYC/PAL_44601 CC3 ->
BIF/PAL_44801 MEM_reg`: 93.5 ns data path, **142 logic levels**, 71%
routing. Even with every clock constrained, this netlist cannot run at
16.67 MHz - actual Fmax on that path is ~10 MHz. Consistent with the
earlier WCS->ACAL 52 ns / 76-level finding; this is a SEPARATE work item
from the 47-clock cleanup:
- classify the >60 ns paths: genuinely multicycle by ND-120 design
  (grant/arbitration settle over several OSC cycles) -> add
  `set_multicycle_path` constraints; or real single-cycle -> needs logic
  restructuring.
- the clock-enable refactor does not fix logic depth, but it makes the
  paths VISIBLE and constrainable - do the classification after P2, when
  the timing report is finally trustworthy.

**3. Defined clocks in the Basys3 build** (explore_clocks.rpt): sys_clk
100 MHz, MMCM-derived clk_100_pre / clk_12p5_pre (auto-derived, fine).
Everything else in the design is an undeclared register-clock domain.

## Progress log

**9-JUL-2026 - P0 executed:**
- **P0.1 inventory: DONE.** TBDs closed (see addendum after the 17-net
  table): #9 = ECREQ (not MWRITE50_n), consumers MEM_ADEC_45.v:235,238;
  #10 BGNT_n -> BIF_DPATH_BDLBD_10.v CLKBA transceivers. New finds:
  s_dbapr/s_ddbapr (MEM_ADEC_45), s_spesl (MEM_ERROR_47), s_dstb_n CLKAB
  (BIF_DPATH_CDLBD_11).
- **P0.2 goldens: DONE.** `sim/golden/trace_{ff,latch}_golden.csv` +
  `checksums.md5`; determinism proven (re-run byte-identical).
  `runSim/golden/console_ff_golden.log` captured with the new
  `-DSCRIPT_INPUT -DSCRIPT_CMD_GOLDEN` build of Run120.cpp
  (`22/054321` deposit + readback + `0!` + `20!`, 40M-cycle budget stop);
  determinism proven. NOTE: FF-mode Verilator readback shows **054321
  correctly** - the deposit bug is board-only, as diagnosed.
  Golden rebuild recipe:
  `cd Verilog/runSim && make clean && make compile USE_LATCHES=0
  EXTRA_CFLAGS="-DSCRIPT_INPUT -DSCRIPT_CMD_GOLDEN" && ./obj_dir/VND120_TOP
  </dev/null > console.log` then diff against the golden.
- **P0.3 SDC probe: bitstream BUILT, board test pending.** Gowin SDC
  lessons (they cost three build iterations - remember them for P5):
  1. The SDC parser is a tiny Tcl subset: **no foreach/variables** -
     flat commands only.
  2. **PLL output pins are not clock sources until explicitly declared** -
     chain create_generated_clock from [get_ports sys_clk] first.
  3. **Auto-inferred clocks are not addressable objects** - get_clocks on
     a .tr auto-clock name fails with TA2004 at parse time; declare an
     explicit create_clock on the source PIN (from the .tr Source column),
     then reference the explicit name.
  Result: TA1117 dropped **47 -> 3** (only sys_rst_n pairs remain = P4).
  Probe SDC lives between the THROWAWAY banners in
  `fpga/tang-nano-20k/src/nd120_tang20k.sdc` - REVERT after the board test.
- **P0.3 board test #1 (constrained @ 6.75 MHz): deposits STILL FAIL**
  (`22/` -> 000000, deposit 054321, readback 000000; reads all-zero like
  the v1-v3 bitstreams). BUT the .tr shows the constraints were defined
  and NOT MET: clk_cpu setup TNS **-14,399 ns / 418 endpoints** (Fmax
  4.84 MHz vs 6.75 needed), gen_mclk TNS -2,537 ns / 81 endpoints, 700
  setup-violated endpoints total. A build that misses setup by 3x a full
  period on 418 paths is expected to misbehave, so this is a CONSISTENT
  result, not a refutation: constraining alone cannot rescue a netlist
  whose real Fmax is below its clock. (The 89 "hold violations" are
  probe artifacts - the p_* base clocks assume phase-0 alignment they do
  not really have; another reason the SDC-only approach is a dead end.)
- **P0.3 probe #2 (crawl clocking): deposits STILL FAIL, identically.**
  Added `TANG_CRAWL_BRINGUP` (tang20k_defines.v + gowin_rpll_27_54.v,
  kept as a commented-out option): CLKOUT 6.75 MHz / CPU 3.375 MHz -
  under the measured 4.84 MHz Fmax. Constrained crawl build: setup
  violations dropped 700 -> 19 endpoints (the 19, and the 92 "hold"
  violations, are all probe-phase artifacts on p_*/gen_* fake clocks).
  Board test: `22/` -> 000000, deposit 054321, readback 000000 - the
  EXACT same failure as at 6.75 MHz. A pure setup-timing failure should
  change behavior at half speed; it did not change AT ALL.
  (SDC probe reverted as planned; one extra fragility noted: synthesis
  uniquification suffixes in pin names change between builds - the
  p_ecreq pin was s_dbg_memw_2_s17/F in one build, _s2/F in the next.)

**P0 CONCLUSION - diagnosis revised.** The unconstrained-clock disease is
real (it must be fixed regardless; Fmax 2.7-4.8 MHz domains cannot ship),
but it is NOT the proximate cause of the deposit failure:
1. Deposit failure is frequency-independent (identical at 6.75 and
   3.375 MHz) and constraint-independent.
2. Reads return per-bitstream-stable values; on both constrained builds
   they read 000000 before AND after a deposit.
3. **Coverage hole found:** `MAIN_RAM_SDRAM` (the MEM_RAM_49_SDRAM
   bridge + sdram18.v path) is only buildable via ND3202D/MEM_43 ifdefs;
   the Verilator sim tops (ND120_TOP for sim/ and runSim/) never build
   it, and the iverilog Tang tb is far too slow to boot. The runSim
   golden deposits fine - but through the BRAM RAM, not the bridge.
   **No simulation has ever executed a deposit through the SDRAM
   bridge.** All silicon captures (v1-v4) traced the WRITE side to the
   bridge FSM issuing s_wr with correct data; the READ side (bridge
   read FSM -> RDATA latches -> LBD -> IDB -> console) was never traced
   nor simulated.
Prime suspect at that point: functional bug vs physical race - decided by
P0.4 below.

- **P0.4 Verilator full-build sim: PASSES.** Made the existing Tang tb
  runnable under `verilator --binary --timing` (new `make vtest` target in
  `fpga/tang-nano-20k/sim/Makefile`; three fixes: named-fork `disable`
  replaced with a polling loop, `-CFLAGS "-std=gnu++20 -fcoroutines"` for
  g++ 11, and - critically - char pacing raised to 130 ms/char because
  MOPC only polls the console once per RTC tick; the old 95 us pacing
  produced a HOLLOW pass where zero chars were ever echoed). The tb now
  HARD-checks the readback (tail must contain "22/054321").
  Result: the EXACT Tang configuration (GOWIN + FPGA_FF_MODE +
  MAIN_RAM_SDRAM bridge + sdram18 + TANG_SLOW_BRINGUP + SKIP_WCS_LOAD)
  boots, deposits through the real bridge, and reads back 054321
  correctly. ~100 s wall for 3 s sim.

**P0 FINAL CONCLUSION - the mechanism, precisely:**
1. Zero-delay sim of the full Tang config PASSES (P0.4).
2. Board fails IDENTICALLY at 6.75 and 3.375 MHz (P0.3) - frequency-
   independent.
3. Wrong values are stable per bitstream, different across bitstreams.
4. Setup-only fixes (constraints, slower clocks) change NOTHING.
=> The failure is a **HOLD-type / clock-skew race on the fabric-routed
register-as-clock nets**: a rogue clock's insertion delay through LUTs
and routing exceeds the data delay of the signals it captures, so the
capturing flop samples post-transition data. Hold races are immune to
frequency reduction (both edges slide together) - exactly what P0.3
observed - and their outcome depends on relative routing delays, i.e.
the PNR lottery - exactly the per-bitstream signature. Gowin cannot even
ANALYZE these paths (TA1117), let alone fix them.
The fix remains the clock-enable refactor (P1/P2): moving every capture
onto sysclk with enables gives the tools a single skew-managed clock
tree, which kills the race class structurally. Frequency changes never
will.

**Validation-gauntlet upgrade:** gate 4 is now `make vtest` in
`fpga/tang-nano-20k/sim/` - a REAL boot + deposit + verified readback of
the exact Tang build (was: "file list elaborates"). Run it before every
Gowin build.

**9-JUL-2026 - P1a DONE (all 5 gates green).** The rogue net was actually
clocking **AM29833A** parity-error flops (the plan table said AM29861A -
that chip is combinational and needed nothing). AM29833A gained the
AM29C821-style USE_SYSCLK=2 edge capture (sync dominant CLR_n); selected
under FPGA_FF_MODE in MEM_DATA_46 with sysclk=OSC. Gates: equivalence tb
504/0 + teeth (`Shared/support/sim make test-am29833a`), both trace goldens
byte-identical, runSim console byte-identical, vtest deposit PASS, Gowin
TA1117 **47 -> 44** with s_rdata gone from the .tr; board boots/examines,
no regression. NOTE for later (separate from this refactor): the capture
condition `!ReceiveMode` checking T-port parity looks inverted vs the
datasheet receive-side semantics - matches the open "AM29833A parity" item
in Verilog/TODO.md.
Remaining P1: P1b refrq_n, P1c ECREQ + dbapr/ddbapr, P1d BGNT_n, P1e
SIP1M9 RAS (Basys3).

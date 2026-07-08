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
| 9  | `s_dbg_memw_0[2]` = MWRITE50_n | consumer identified in P0 inventory           | P1c   |
| 10 | `BGNT_n_9`                | consumer identified in P0 inventory                | P1d   |
| 11 | `DSTB_n_34`               | BIF_DPATH_10/11 bus-data latches                   | P3    |
| 12 | `BIF/SPES_12`             | BIF_DPATH_PESPEA_13 parity registers               | P3    |
| 13 | `s_ibapr_n_Z`             | BIF bus-address capture                            | P3    |
| 14 | `DELILAH/s_ldirv_2835`    | CGA_CPU_ALU_CONTR.v:657,669 IR registers           | P3    |
| 15 | `IO/s_sioc_n`             | IO_37 registers                                    | P3    |
| 16 | `DCD/s_div_16`, `s_XRTOSC`| IO_DCD_38.v:403 RTC divider chain                  | P3    |
| 17 | `sys_rst_n`               | a flop clocked by the reset net                    | P4    |

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

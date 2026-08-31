# HANDOFF - panel MIPS, the Nexys clock, and the parked cache

**Full path:** `Verilog/docs/HANDOFF-mips-and-clock.md`
Written 30-AUG-2026, evening; **updated 31-AUG-2026 after the reboot**
(host memory freed, WSL alive again - see the two sections marked UPDATE).
Companion to
[`PLAN-cache-and-panel.md`](PLAN-cache-and-panel.md) (outstanding work) and
[`CACHE-STATUS.md`](CACHE-STATUS.md) (the cache evidence log).

## RESOLVED 31-AUG: the MIPS tap is fixed in RTL and validated in sim

**Do not rebuild the Nexys expecting the staged CFETCH tap to work - it was
DEAD. It is now re-pointed at the GPR-load strobe and measured end to end.**

The event that is genuinely one-per-instruction is the instruction register
taking a new opcode: `CGA_ALU_GPR`'s `MUX41P` selects `D1 = CD_15_0` when
`GPRC[1:0] == 01`, captured on the `ALUCLK_EN` pulse.

Changed (debug-only, additive, no functional path touched):
- `DELILAH-CPU/CGA_ALU/circuit/CGA_ALU.v` - new `XGPRLOAD_DBG` output,
  `assign XGPRLOAD_DBG = s_aluclk_en_i & s_gprc_2_0[0] & ~s_gprc_2_0[1];`
- `DELILAH-CPU/CGA/circuit/CGA.v` - `XCFETCH_DBG` now driven from it.
  `s_cfetch` still feeds DCD/MIC/TESTMUX; only the debug tap moved.
- The six pass-through files (CPU_PROC_CGA_33, CPU_PROC_32, CPU_15, ND3202D,
  ND120_CORE, ND120_TOP) are unchanged - the staged wiring carries it.

Measurements, all via `tests/instruction-verify/run_area_test.sh` with
`ND120_COUNT_CFETCH=1` (the area gate itself PASSED in every run, so the
machine was executing correctly):

| what was measured | pulses | reference instructions | note |
|---|---|---|---|
| CFETCH (old tap), internal | 0 | 460 | dead |
| GPR<-CD, internal, REGISTER-OPERATIONS | 469 | 460 | ratio 1.0196 |
| GPR<-CD, internal, MEMORY-REFERENCE | 469 | 460 | ratio 1.0196 - IDENTICAL |
| **routed `ND120_TOP.s_debug_cfetch_dbg`** | **469** | 460 | full 7-level path proven |

**Why the +9 is not an error in the tap.** The two areas trace different
windows (first instruction `022347:171406` vs `022343:171404`) with very
different instruction mixes, yet both give exactly 469/460. A tap that also
counted the second word of two-word instructions would have ballooned on
MEMORY-REFERENCE; it did not move at all. The offset is CONSTANT, not
proportional. 4 of the 9 are loads whose opcode equals the previous opcode -
the `ND120_TRACE_VERIFY` detector needs the opcode word to CHANGE, so it
cannot see those; the rest is service code the same rules exclude
(it requires `GPR != 0` and both P and opcode to change). The residual is the
REFERENCE's blind spot, and ~2% is far below what a MIPS display resolves.

**Root cause of the dead tap, for the record:** `CGA_DCD.v:1041` `CFETCH_FF`
is a `SCAN_FF_EN` whose `.D(s_cfetchff_q)` is tied to its own
`.Q(s_cfetchff_q)`. It holds forever and can only reload through the scan
path (`TE(s_brk)`, `TI(s_ifetchn)`), so CFETCH is "fetch state latched at
BRK", never a per-instruction strobe. Three taps in a row were chosen from a
signal's NAME; this is the first one chosen from its logic.

**What is left:** a Nexys build with the MIPS tap, at 45.45 MHz `nocache`
(cache cannot reach 45 - see the ceiling section below). Not run - builds
need Ronny's go-ahead.

## Superseded note: how the CFETCH tap was found dead

Run: `tests/instruction-verify/run_area_test.sh REGISTER-OPERATIONS` with
`ND120_COUNT_CFETCH=1`. The area itself PASSED (`TRACES EQUIVALENT: 400
aligned instructions match exactly`), so the machine was executing properly.
Over the traced window: **CFETCH rises = 0 against 460 macro instructions.**
Whole run: 3 rises against 316,098 macro boundaries.

**Root cause, from the RTL:** `CGA_DCD.v:1041` `CFETCH_FF` is a `SCAN_FF_EN`
whose `.D(s_cfetchff_q)` is tied to its own `.Q(s_cfetchff_q)` - it holds
forever and can only reload through the SCAN path (`TE(s_brk)`,
`TI(s_ifetchn)`). So CFETCH is "fetch state latched at BRK", not a
per-instruction strobe. The name is what misled the pick; this is the THIRD
tap chosen from a name instead of a measurement.

**The tap that should work,** derived from the RTL rather than a name: the
instruction register taking a new opcode. `CGA_ALU_GPR` loads GPR from
`CD_15_0` when the `MUX41P` selects D1, i.e. `GPRC[1:0] == 01`
(`CGA_ALU_GPR.v:110-118`), captured on the `ALUCLK_EN` pulse. Probe
`[gprld]` in `Run120.cpp` counts exactly that; it must print
`EXACT 1:1 - THIS is the MIPS tap` before anything is wired to the panel.

## CFETCH is CORRECT AS TRANSCRIBED - do not "fix" it (31-AUG-2026)

Verified against the schematic: **DELILAH.pdf page 69, `/CGA/DCD` SHEET 5 OF
10**, the `FD1S` cell that drives CFETCH. The drawing shows:

- **D tied to Q** - the feedback wire loops from the D pin up, across and back
  into Q. The self-feedback is ORIGINAL, not a transcription artefact.
- `TI` <- the FETCH flip-flop's Qbar (`IFETCHN`)
- `TE` <- `BRKN` through inverter `IVA`, i.e. BRK active-high
- `CP` <- MCLK; `QN` -> `CFETCH`
- the `FD1S` has **no CL pin** - the flip-flop above it has PR/CL, this one
  does not, so BRK_n CANNOT clear it.

`CGA_DCD.v:1041` matches that pin for pin. So CFETCH holds by design and
reloads `IFETCHN` only when BRK asserts: "hold, and on a break capture the
fetch state". It is a microcode CONDITION (input 4 of `CGA_MIC_CSEL`'s
PLEXERS_1), not a per-instruction strobe, and measuring 0 pulses in 460
instructions is CORRECT behaviour, not a fault.

**A rewrite was attempted on 31-AUG** (D driven from `s_ifetchn`, BRK as an
async clear via `D_FLIPFLOP_EN` with `ASYNC_RESET`) on the theory that a
schematic CLEAR pin had landed on the scan-test pins. **It broke SINTRAN boot
("system malfunction") and was reverted.** The theory was wrong: there is no
clear pin to land anywhere. Do not repeat this.

## Next action, in one line

**Build and flash the Nexys at 45.45 MHz WITHOUT the cache, with the MIPS
counter fed by CFETCH** - everything is staged, the ONLY blocker is host
memory (see "The machine is out of commit" below).

```
# from the build worktree E:\Dev\Repos\Ronny\nd-120-build\Verilog\fpga\nexys4ddr
vivado -mode batch -source build.tcl -tclargs clk=45 nocache physopt
```

## Where the machine stands

- **Board right now:** build 11 - `clk=33.333` (WNS +0.037), cache ON,
  VT100 terminal, MIPS counter present but reading ~00.00 (wrong tap, see
  below). Flashed 17:25. JTAG-volatile: a power cycle loses it, re-flash
  `nd120_nexys4ddr_build11_clk33.bit` with `program_only.tcl`.
- **Decision, 30-AUG (Ronny):** *speed beats cache*. "if the board cannot
  go 44+ mhz because of caching, then caching is not something we need.
  going to 33 MHz instead of 45-50 is absolutely not worth including
  caching." So the deployed configuration is **45+ MHz, `nocache`**. The
  cache stays one build flag away (`cache` at 33 MHz) for diagnostics.

## The MIPS counter - two wrong taps, and the fix that is staged

`Terminals/rtl/mips_counter.v` counts rising edges of whatever it is fed,
10000 edges = +0.01 MIPS, published once a second as 4 BCD digits. The
counter itself is PROVEN (`make test-mips-counter`: 250 pulses -> 0025,
idle -> 0000, saturation -> 9999). Every wrong reading so far has been the
INPUT, not the counter:

1. **`DEBUG_FETCH`** (builds 8): the board FETCH net is a MEMORY-CYCLE
   qualifier. Build 8 was the first image whose cache really hit, and a
   cached fetch runs no memory cycle - the counter starved to `00.00`.
2. **`MAP_n`** (builds 9-11): the board MAP net comes from `PAL_44307C`
   (`MAP_n = ~(FORM & BRK_n & CC2 & TERM_n)`, `PAL/PAL_44307C.v:114`) - it
   is gated by FORM and the cycle state, i.e. another bus-cycle signal, not
   one edge per macro instruction. Ronny measured the result: "most of the
   time 00.00 but sometimes a low number".
3. **`CFETCH` - STAGED, NOT YET BUILT.** The CGA's own Command Fetch
   state, registered inside `CGA_DCD`, is the once-per-macro-instruction
   event and is independent of the cache. Wired out as a pure read-only
   fan-out (no logic added to the gate array), following the existing
   `XMIC_DBG_15_0` debug-output precedent:
   `CGA.v XCFETCH_DBG` -> `CPU_PROC_CGA_33` -> `CPU_PROC_32` -> `CPU_15`
   -> `ND3202D DEBUG_CFETCH` -> `ND120_CORE` -> Nexys top
   `s_debug_cfetch` -> `mips_counter.fetch`. Also brought out in
   `ND120_TOP.v` as `s_debug_cfetch_dbg` with a
   `/* verilator public_flat_rd */` marker for the sim check.

**STILL UNVALIDATED, say so to anyone who asks:** nobody has proved in
simulation that CFETCH pulses exactly once per macro instruction. Two
earlier probes in this very design were lost to sampling an unverified
signal (the CGA's own comments record both). The validation is cheap and
is written down - see "When WSL comes back", item 2. Until it runs, the
panel number is plausible, not verified. Sanity expectation at 45 MHz:
roughly `01.xx`-`04.xx` with code running, near `00.00` at the OPCOM
prompt (MOPC executes very few macro instructions).

## The clock: what 45 MHz costs with a cache, and why nocache is free

Every 45.45 MHz boot before 30-AUG ran the BROKEN cache, which synthesised
to almost nothing. With the cache real:

| build | config | result |
|---|---|---|
| 10 | clk=45, cache, physopt | FAIL WNS -6.552, 4248 endpoints. Worst: `MIC/LAA_REG` -> WCS BRAM address, 36 logic levels, 27.986 ns vs 22 ns |
| 12 | clk=45, cache, physopt, **+N=2 multicycle** | FAIL WNS -6.780. Worst moved to `WRF/RBLOCK/R2_REG_10` -> same WCS address port |
| 11 | clk=33, cache, physopt | **PASS WNS +0.037** - flashed |
| 13 | clk=45, **nocache**, physopt | never finished: Vivado ran out of host memory |

The N=2 multicycle exception (`fpga/nexys4ddr/nd120_timing.xdc`, derived in
`fpga/nexys4ddr/docs/wcs-multicycle-analysis.md`) **works and is correct at
every clock - keep it.** Build 12 proved it applied (no `[Vivado 12-4739]`,
`LAA_REG` gone from the violation list) and that the next path in line is
the one the analysis deliberately refused to relax: WRF register outputs,
where `WRFSTB` writes land one clock before an open RWCS capture window
with traps enabled and no masking proof exists. The whole
WRF -> ALU -> TVGEN -> ACAL -> WCS cone is ~28 ns whoever launches it, and
it closed at +0.085 ns BEFORE the cache existed - so the cache did not add
logic to that cone, it added ~1900 LUTs of ROUTING pressure (the path is
72% route). Routes to 45 MHz *with* cache, rising cost: placement/strategy
runs; a masking proof for the WRF launch family; pipelining the ACAL cone
(RTL surgery). **Parked by Ronny 30-AUG.** Full record:
`fpga/nexys4ddr/timing.md`, 30-AUG section.

**The cache clock ceiling, as a number (31-AUG):** the build-12 routed worst
path is **28.039 ns**, so with the cache in, the design cannot run faster
than **1/28.039 ns = 35.66 MHz** however the clock is chosen. The build
table's `clk=35` is exactly 28.0 ns - a 0.039 ns miss, i.e. right on the
edge with no margin over temperature or voltage. **33.333 MHz is the only
cache clock with real margin, and 45 MHz with cache is not reachable
without shortening that cone.** What has NOT been tried is a
placement/strategy sweep, so "impossible" is too strong - but the path is
75% route across 4269 failing endpoints, which is a great deal to ask of
the router. Also never measured: whether 33 MHz WITH cache beats 45 MHz
WITHOUT it at real work. The cache buys memory cycles back and the clock
ratio is only 1.38x, so "nocache is faster" is an assumption, not a
result.

## The machine WAS out of commit - CLEARED 31-AUG (UPDATE)

Build 13 died with Vivado's own `The application has run out of memory`:
commit was 140.8 GB of a 143.7 GB limit, with the hung WSL VM (`vmmemWSL`)
reserving 28.8 GB at 0.00 GB working set. Physical RAM was never the
problem - 63.7 GB was free.

**After the reboot (31-AUG, 02:xx): commit 41.6 GB of 143.7 GB, and WSL
answers again.** Vivado and Verilator both have room. The lesson stands:
when a build dies of memory, measure commit charge against the COMMIT
LIMIT before blaming Vivado, the design, or the hardware.

## When WSL comes back - three checks, ONE JOB AT A TIME

**Ronny's hard limit, 30-AUG, after the pile-up caused OOM and crashes
across his PC: never more than 5 concurrent processes / WSL jobs.** When a
command hangs, WAIT for it - never launch a second copy of the same
question. That mistake is what broke the machine.

1. **CACHE-1X0-A00 test 3 golden trace.** The one remaining cache failure,
   board-specific (passes in Verilator, hangs on the Nexys at
   `P=124563B`). The mechanism is already pinned by disassembly - it is
   the FIRST newly-cacheable instruction fetch after a `TRR LCIL`, in the
   window before the `TRR CCL` cache clear, when the sweep reaches
   LCIL=53 and the test's own code page (page 52) leaves the inhibit
   window. Full reconstruction:
   `scratchpad\test3-disasm\RECONSTRUCTION.md` (session temp dir) and
   `CACHE-STATUS.md`. Needs a cache build (33 MHz) to reproduce on board.
2. **CFETCH once-per-instruction validation - STARTED 31-AUG (UPDATE).**
   The probe is now written: `ND120_COUNT_CFETCH=1` in `Run120.cpp` counts
   RISING edges of `s_debug_cfetch_dbg`, and `g_macro_boundaries` counts
   every macro-instruction boundary the `ND120_TRACE_VERIFY` detector sees
   (unfiltered - before arming, the PIL filter and the 400 cap), so one run
   prints `[cfetch] rises=N macro=M ratio=R`. **The tap is proven only if
   the ratio is 1.0000.** Build:
   `make compile EXTRA_VDEFINES="--public-flat-rw" EXTRA_CFLAGS="-DND120_TRACE_VERIFY"`.
   NOTE while doing this: the `[map]` probe added 30-AUG had a REAL newline
   inside its format string instead of `
`, so it never compiled and
   `[map]` has never produced a number - fixed 31-AUG. Original text: Run runSim with
   `ND120_TRACE_VERIFY` (one line per macro instruction) and an edge
   counter on `s_debug_cfetch_dbg` over the same window; the two numbers
   must agree. The `[map]` probe already in `Run120.cpp`
   (`ND120_COUNT_MAP=1`) is the copy-paste template - point it at the
   CFETCH wire.
3. **The N=2 multicycle assertion.** The derivation's weakest link is that
   every MCLK_EN launch is followed one clock later by TERM or state a
   (equivalently TRAPN==1 and MAP_n==1 at every window-closing edge). One
   assertion over a runSim boot settles it; extend
   `make test-cycle-timeline` in `CPU-BOARD-3202/circuit/sim`.

## Uncommitted work in the tree (30-AUG evening)

**Mine, ready to commit:**
- CFETCH wiring: `DELILAH-CPU/CGA/circuit/CGA.v`,
  `CPU-BOARD-3202/circuit/{CPU_PROC_CGA_33,CPU_PROC_32,CPU_15,ND3202D}.v`,
  `ND120_CORE.v`, `ND120_TOP.v`, `fpga/nexys4ddr/nd120_nexys4ddr_top.v`
  (also still carries the earlier MAP_n tap - harmless, kept as a probe)
- `fpga/nexys4ddr/nd120_timing.xdc` + `fpga/nexys4ddr/docs/wcs-multicycle-analysis.md` (new)
- `runSim/Run120.cpp` (the `[map]` probe), `CYC_36.v` + `CGA_MIC_IPOS.v`
  (MAP comment corrections only), `docs/PLAN-cache-and-panel.md`,
  `fpga/nexys4ddr/timing.md`

**NOT mine - leave alone:** `Terminals/rtl/ps2_ascii_table.v`,
`Terminals/sim/{key_vt100_tb,ps2_keyboard_tb}.v`,
`Terminals/docs/SPEC-vt100-keys.md` belong to the RTC session's keyboard
work in progress. Do not sweep them into a commit.

## Facts worth not relearning

- **Vivado runs on Windows and needs no WSL.** Synthesis, implementation
  and JTAG flashing are all Windows-side; only Verilator/iverilog need WSL.
- **The Nexys build needs `physopt`** since the DGA RWCS-gate change
  (build 7): plain args miss timing, physopt closes it.
- **The build worktree** `E:\Dev\Repos\Ronny\nd-120-build` exists so a
  ~40-minute Vivado run reads a frozen snapshot while other sessions edit
  the shared tree. Sync it with a path-limited `git checkout <commit> --
  <paths>`, and sync the WHOLE terminal set at once - a partial sync is
  what caused the `byte_fifo not found` failure on build 8.
- **The Tang cannot host the cache**: a live cache needs 28330 logic cells
  against the GW2AR-18's 20736. `ND120_NO_CACHE` is its committed default,
  now with a `-Cache` escape hatch (`gowin_build.ps1`) for whoever attacks
  the fit. The cache RAMs are async-read, so they land in LUT-RAM (cheap on
  Xilinx, catastrophic on Gowin); the WCS is clocked and lives happily in
  block RAM on both.
- **COM11 is the Nexys console** and Ronny often holds it via RetroTerm.
  Never fight for the port - JTAG flashing does not need it.

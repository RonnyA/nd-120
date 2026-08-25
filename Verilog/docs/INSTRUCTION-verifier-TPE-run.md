# INSTRUCTION verifier (TPE Monitor, floppy) — run guide + failure analysis

**Full path:** `Verilog/docs/INSTRUCTION-verifier-TPE-run.md`
**Date:** 2026-07-23
**Status:** ACTIVE. This is the PREFERRED CPU-correctness test to drive from the
floppy-booted TPE Monitor — it is fast, prints every instruction as it runs,
completes all levels (does not loop forever like the MEMORY test), and it
already exposes a concrete, reproducible failure (page-fault -> no level-14
interrupt). Use THIS instead of the MEMORY test for instruction/CPU debugging.

Related: `Verilog/docs/HANDOFF-tpe-memory-test-corruption.md`
(boot path, probe TXBYTE/TXSTROBE extension, sim-speed findings).

> **BUILD TRAP (cost hours, 2026-07-24): the floppy-TPE boot needs FF mode.**
> A probe engine built **without** `-DFPGA_FF_MODE` (i.e. latch mode, the
> `USE_LATCHES=1` default) boots the microcode self-test fine but **never
> reaches the floppy `TPE>` prompt** — the console stops right after the
> `1560&` echo and produces no further output, at any tick count. This is
> silent: no crash, no error, just no boot. Confirmed by bisect: the engine
> `obj_dir_probe_dbg` (has `-DFPGA_FF_MODE`) boots to `TPE>` at ~44M ticks; an
> otherwise-identical build without it does not, at 122M+.
> - Verify a built engine's mode:
>   `grep -o FPGA_FF_MODE <objdir>/VND120_TOP__verFiles.dat` (empty = latch = will not floppy-boot).
> - The `Makefile` probe targets (`make probe-floppycore`) add `-DFPGA_FF_MODE`
>   automatically because the probe defaults to `USE_LATCHES=0`. **Hand-rolled
>   build scripts must add `-DFPGA_FF_MODE` explicitly** or the engine will not
>   boot the floppy. All three of the 2026-07 helper scripts under
>   `/tmp/.../` (`build_fast_probe.sh`, `build_rtc_probe.sh`, `build_rtc_var.sh`)
>   originally OMITTED it — every RTC-fix verification built on them silently
>   failed to boot and produced misleading "still booting at 180M ticks" reads.

---

## 1. How to run it

1. Boot the real TPE Monitor: at the `#` prompt send **`1560&`** (floppy
   autoload, portable C core; image
   `Verilog/runSim/FLOPPY1.IMG`). Reaches `TPE>`
   in ~17-20 min at ~46k ticks/s. (Send-gap fix confirmed — boots real B01.)
2. At `TPE>` load the INSTRUCTION diagnostic: **`INSTRUCTION`** (abbrev `inst`
   likely accepted, by analogy with `mem`->MEMORY). Banner:
   `INSTRUCTION - Version: C03 - 1988-03-04`.
3. **Set parameters FIRST** (so each instruction name is printed and we can see
   which one runs and how it behaves):
   ```
   TPE>set-para,N,N,Y,N,Y
   ```
   5 comma-separated flags. Exact meaning of each flag is NOT yet confirmed
   (INFERRED: one Y enables per-instruction console echo; others select
   loop/stop-on-error/level range). Use this exact string until the flag
   semantics are documented. TODO: confirm each flag from the C03 test or the
   TPE-MON reference.
4. Run: `TPE>run`

The whole run (9 levels) is quick in wall-clock on real hardware (banner
timestamps span 15:36:08 -> 15:36:20, ~12 s). Ends with `=== End of run ===`
and returns to `TPE>`.

---

## 2. CPU configuration banner (expected, from a known-good run)

```
    INSTRUCTION - Version: C03 - 1988-03-04

CPU type.............: ND-100/CX upgraded for 16 PITs
Floating format......: 48 bits
Memory management....: MMS-2
Cache................: Manually disabled
ALD register content.: 1560B
Cpu cycle............: Fast
```

NOTE the config says **Floating format: 48 bits** and the test includes a
`48 bits floating instructions` group (DNZ NLZ FMU FDV FAD FSB). Our PROM
microcode implements the **32-bit** float option
(`Verilog/docs/48bit-float-not-configured.md`),
so behaviour of that group may differ from this reference — track separately.

---

## 3. Test structure

The verifier runs **9 levels** (`=== Running Tests on Level 1 ===` ...
`Level 9`). Each level executes the SAME sequence of instruction groups, echoing
every instruction mnemonic as it is exercised. In Level 1 each group closes with
`=== End of test ===`; levels 2-9 print just the mnemonics then the
internal-interrupt section.

Instruction groups per level (in order), with the mnemonics printed:

| Group | Mnemonics |
|-------|-----------|
| Argument | SAA(x2) SAT(x2) SAB(x2) SAX(x2) AAA AAT AAB AAX |
| Memory reference | STZ STA STT STX LDA LDT LDX MIN(x2) LDF STF LDD STD SBYT LBYT ADD(x3) SUB(x3) AND(x2) ORA(x2) MPY(x2) |
| Sequencing | JMP JPL JAP JAN JAZ JAF JXN JPC JNC JXZ SKP |
| Register | RADD RSUB RAND(x2) RORA(x2) REXO(x2) SWAP COPY RMPY RDIV MIX EXR |
| Bit | BLDA(x2) BSTA BSTC BLDC BANC(x2) BORC(x2) BAND(x2) BORA(x2) BSKP(x3) BSET(x4) |
| Shift | SHA(x9) SHT(x9) SHD(x9) SAD(x9) |
| 48 bits floating | DNZ NLZ FMU FDV FAD FSB |
| Privileged | LOAD/STORE REGISTER BLOCK ; TRA/TRR PID/PIE |
| Byte | BFILL MOVB MOVBF |
| Physical memory | SEX EXAM LDATX LDXTX LDDTX LDBTX STATX STZTX STDTX |
| Binary coded decimal | ADDD SUBD COMD SHDE PACK UPACK |
| Cx | TSET RDUS MOVEW {PT,APT,PHYS} => {PT,APT,PHYS} (9 combos) |
| Stack | INIT LEAVE |
| Segment | SETPT CLEPT CLNREENT CHREENTPAGES CLEPU |
| Internal interrupts | (see below) |

### Internal interrupts group (walks each internal-interrupt source)

Sources printed, in order:
```
Not assigned / IOX-error / Not assigned / Privileged instr. / Not assigned /
Error indicator (z) / Not assigned / Illegal instruction / Not assigned /
Page fault / Not assigned / Protect violation / Not assigned / Monitor call /
Not assigned
```

---

## 4. THE FAILURE (concrete, reproducible, every level)

In the Internal-interrupts group, the **Page fault** source fails at EVERY level
(1 through 9), identically:

```
Page fault

*** ERROR ***  Operation was: Page fault           Time: 1996.07.23 15:36:08
No interrupt generated on level 14

Interrupt provoked by:    Page fault
```

- ALL other internal-interrupt sources (IOX-error, Privileged instr., Error
  indicator, Illegal instruction, Protect violation, Monitor call) pass — only
  **Page fault** errors.
- The verifier PROVOKES a page fault and expects the CPU to raise the
  **level-14 internal interrupt**. Our CPU **does not generate it** ("No
  interrupt generated on level 14").
- Consistent across all 9 levels; the run still reaches `=== End of run ===`.

### Interpretation (to be confirmed — ASSUME NOTHING)

- ND page faults are an internal interrupt delivered on **level 14**. The failure
  says the page-fault detection is NOT producing the level-14 request.
- Suspect chain: MMU page-fault detection (PGU / page-fault signal in
  `CPU_MMU_*`) -> internal-interrupt source into the interrupt controller
  (`Verilog/DELILAH-CPU/CGA_INTR/`) -> level-14 request. One of these links is
  missing/mis-wired for the page-fault source specifically (the other internal
  sources work).
- Related prior level-14 work: RUN livelock / Am2914 status fence / MOR-on-
  level-12 wiring (see CLAUDE.md "Status & known issues" and
  `Verilog/docs/RUN-level14-livelock-analysis.md`,
  `Verilog/docs/HANDOFF-mor-level12-wiring.md`).
  This is a DIFFERENT symptom (page fault, not MOR/RUN) but the same level-14
  delivery machinery — check for a common root.

This may instead be a test-setup issue (the fault not actually provoked in our
config). That is exactly what the trace capture in §5 resolves.

---

## 5. Plan: tick-correlated windowed trace of the page-fault handling

The probe counts sysclk ticks (`g_globalTick`) and can gate a full-hierarchy FST
to a tick window (fst_on/fst_off), so we can capture the exact page-fault ->
(missing) level-14 sequence at signal level.

Two-pass method (fast, one boot each — or one boot if we keep the process live):

1. **Locate pass** — run `INSTRUCTION` with `set-para,N,N,Y,N,Y` then `run`,
   logging the tick count at each output character (via `TXBYTE`/`TXSTROBE`).
   Detect the console substring `Page fault` (and the following `*** ERROR ***`)
   and record the tick range `[T_pf_start, T_pf_err]` for Level 1 (the first
   occurrence — earliest, cheapest).
2. **Trace pass** — re-run to just before `T_pf_start`, enable the windowed FST
   sink over `[T_pf_start - margin, T_pf_err + margin]`, and capture. Analyse in
   GTKWave for: the MMU page-fault detect signal, the internal-interrupt source
   lines into `CGA_INTR`, the level-14 request/priority, and why level 14 is not
   asserted.

Signals to add to the probe registry for this (TODO — currently not registered):
- MMU page-fault / PGU detect (from `CPU_MMU_*`).
- `CGA_INTR` internal-interrupt source bits + the level-14 request line.
- The Am2914 / priority-encoder level output.

Because the Internal-interrupts group runs LAST in each level (after all the
instruction groups), `T_pf_start` is well into the level; the Level-1 occurrence
is the earliest. Use `TXSTROBE`-based console-string detection to find it without
guessing tick numbers.

---

## 6. Reproduce (driver)

```
cd Verilog/sim
# instrumented probe: obj_dir_probe_dbg (TXBYTE/TXSTROBE), -Os single-thread.
export TPE_CMD=INSTRUCTION TPE_SETPARA="set-para,N,N,Y,N,Y"
python3 <driver> obj_dir_probe_dbg/VND120_TOP inst
```
Driver: boot 1560& -> TPE> -> send `INSTRUCTION` -> send `set-para,N,N,Y,N,Y` ->
send `run` -> log per-char ticks, detect `Page fault`/`*** ERROR ***`, record
the tick range for the trace pass. (Driver to be added to `sim/examples/`.)

---

## 6b. OUR SIM'S ACTUAL BEHAVIOR (measured 2026-07-23) — the REAL first bug

Driven with the prompt-aware driver (`/tmp/claude-1000/tpe_instr.py`, waits for
the `C03` banner before `set-para`, and the echo before `run`) on the
instrumented probe `obj_dir_probe_dbg`:

- Boot -> `TPE>` at ~44M ticks. `INSTRUCTION` loads; the `Version: C03` banner
  appears ~73M ticks (the load is SLOW — ~29M ticks after the command; a
  fixed-timing driver that sends `set-para` too early gets it dropped — this is
  why prompt-aware waiting is mandatory).
- `set-para,N,N,Y,N,Y` accepted; `run` issued at ~106M ticks.
- **On `run`, our CPU prints (nulls interspersed but readable):**
  ```
  *** TPE initialization error ***
  Impossible to clear '0' '1' '2' ... '15'  IDENT  interrupt  on level
  ```
  then **derails into pure garbage** (non-printable bytes) and never runs the
  instruction levels.

So OUR sim fails at INSTRUCTION-test **initialization**: it **cannot clear the
IDENT interrupts on levels 0-15**. The reference run (which reaches all 9 levels
and only errors on page-fault/level-14) has NO such init error. This IDENT-clear
failure is therefore an **earlier, more fundamental bug** and must be fixed
FIRST — the page-fault/level-14 item (section 4) cannot even be reached until the
test initializes.

- Failure tick window: `run` at ~106M ticks, error text begins ~107M ticks
  (very early after run — cheap to reach and trace).
- Likely locus: interrupt controller IDENT / request-latch clear path
  (`Verilog/DELILAH-CPU/CGA_INTR/`). The software "clear interrupt on level N"
  (PID write / MST) is not clearing the request latch, so IDENT interrupts stay
  pending on all 16 levels. Ties to commit `7ebab81` ("Fix IDENT stale-bus
  leak") and the RQBIT async-latch work (memory: rqbit-v2-loop-free,
  intr-verilog-is-truth).
- Secondary: the post-error output is garbage (character corruption family, cf.
  the MEMORY banner `MEMORY`->`MEMO\x7f\x7f`). The nulls interspersed in the
  error message ("clear '\x00 0'\x00 1'...") may be the same corruption or the
  test's field formatting — TBD; the semantic message is unambiguous.

### Next step (trace pass)
Because console strings are partly corrupted, do NOT rely on matching "Page
fault"/level text. Instead trace the IDENT-clear directly: reach ~run+ (~106M),
enable a windowed FST over ~106M-125M ticks, and watch the CGA_INTR request
latches (RQBIT / PID / PIE) and the IOX/MST clear strobe to see why a
clear-write does not reset the level's request bit. Add those interrupt-clear
signals to the probe registry first.

## 6c. Interrupt-clear RTL mechanism + hypotheses (mapped 2026-07-23)

Instance path (Verilator): `ND120_TOP.CORE.CPU_BOARD.CPU.PROC.CGA.DELILAH.INTR`
(-> `.CNTLR` -> `.IRQ` / `.CLR_CLEAR_CONTROL` / `.MDCD`).

**The clear equation (per level, RQBIT_V2):**
`INR (=LREQ[n]) = (~PN | s_b) & ~CLR`, where `PN=IREQ_15_0_N[n]` (active-low
request SOURCE), `CLR=CLRQ[n]` (active-high, dominant), `s_b` a catcher FF that
re-sets whenever `PN` is low. **A clear only STICKS if the request SOURCE `PN`
is deasserted.** `PN` is purely combinational in `CGA_INTR_IRSRC.v` (no state):
`IREQ_N[n]` low whenever `EMPID & FIDBO[n]` (a PID-write set) or a hardware/error
line is active. Files: `CGA_INTR_CNTLR_IRQ_REG_RQBIT_V2.v:94-117`,
`CGA_INTR_IRSRC.v:88,93-235`, `CGA_INTR_CNTLR_CLR_CLRBIT.v:56-89`,
`CGA_INTR_CNTLR_MDCD.v:410-478` (Am2914 command decode: cmd0/1=clear-all,
cmd2/3=clear-by-data FIDBO, cmd4=clear-single-decoded-level).

**Ranked hypotheses for "impossible to clear on all 16 levels":**
- **H1 (top):** the PID set path (`EMPID & FIDBO`) keeps re-driving every level's
  `PN` low during/after the clear, so each RQBIT re-arms. Levels 0-9,14 have ONLY
  this source, so an all-16 failure points here (EMPIDN/FIDBO timing vs the clear
  strobe). `CGA_INTR_IRSRC.v:88,93-99`; `RQBIT_V2.v:95-102`.
- **H2:** RQBIT_V2 clears `s_b` only while `CPN(=~MCLK)=1` (MCLK low); if the
  clear strobe `CLRQ[n]` is only valid during MCLK-high, `s_b` never clears. The
  known "load-bearing async latch" fragility. `RQBIT_V2.v:96`; note `regLAA_3_0`
  retiming TODO `CGA_INTR.v:168-173`.
- **H3:** cmd-4 single-level clear needs group-select FFs `MEMORY_42/43`
  (`MDCD.v:428-478`) primed; if not, neither `HIK`/`LOK` asserts and the clear
  never fires. J-based clears (cmd0-3) are immune.
- **H4:** a sim device holds `BINTxxN` through IDENT (levels 10-13 only; cannot
  explain all 16). Commit `7ebab81` touched ONLY this C device layer
  (`NDBus.cpp` IDENT-bus release), not the RTL clear path.

**Probe signals added** (group `INTR` in `sim/nd120_probe.cpp`): `INTR_lreq`,
`INTR_ireq_n`, `INTR_clrq`, `INTR_mireq_n`, `INTR_empid_n`, `INTR_fidbo`,
`INTR_laa`, `INTR_hik`, `INTR_lok`, `INTR_j`, `INTR_mclk` (+ CSA).

**Decision tree (trace at the init-clear window ~106-125M ticks):** for a failing
level n across an MCLK period — `CLRQ[n]` pulses but `INTR_ireq_n[n]` stays 0 ->
**H1** (inspect `INTR_empid_n`/`INTR_fidbo`); `CLRQ[n]` high only while
`INTR_mclk`=1 and `INTR_lreq[n]` never drops -> **H2**; `CLRQ[n]` never asserts
under a cmd-4 (`INTR_laa`=4) -> **H3**. Driver: `/tmp/claude-1000/tpe_intr_trace.py`
(rule on `INTR_clrq != 0`, captures the INTR group per clear attempt).

## 6d. ROOT CAUSE (signal-traced 2026-07-23) — level-13 RTC interrupt, NOT the INTR RTL

Traced with the INTR-instrumented probe (`obj_dir_probe_dbg`, group `INTR`) over
the init-clear window (~106M ticks). CSV `sim/tpe_intr_idc.csv`.

**Measured at each level-3 clear attempt** (octal): `clrq=10` (bit 3),
`laa=2` (clear-by-data cmd), `j=1`, `fidbo=10`, `empid_n=1` (EMPID OFF),
`lreq=10` stuck, `ireq_n=177767` (bit 3 = 0, source held). Time-evolution:
CLRQ[3] pulses -> `lreq` bit3 DOES clear to 0 on the next MCLK rise -> then
**re-arms to 1** on the following MCLK rise, because `ireq_n` bit3 (the source)
never releases. So the clear WORKS; the source re-drives. **H1 confirmed.**

**The source chain (RTL, verified):**
- `IREQ_N[3] = ~(FIDBO[3] & EMPID) & BINT13N` (`CGA_INTR_IRSRC.v` GATES_25,
  NOR bubbled = AND). EMPID off => `IREQ_N[3] = BINT13N`. Measured 0 => BINT13N=0.
- `ND3202D.v:467  s_bint13_n = BINT13_n & s_io_bint13_n`. External bus `BINT13_n=1`
  (no C device at level 13) => the ON-BOARD `s_io_bint13_n = 0`.
- `IO_REG_41.v:148  s_bint13_n = ~(s_ioc_3 & s_ioc_0)`. So **IOC bit3 AND bit0 are
  both set**: bit0 = "enable clock interrupt on level 13", bit3 = "clock interrupt
  generated from RTC trap handler" (`IO_REG_41.v:180-183`, TTL_74273 CHIP_28A_IOC).

**Conclusion:** the stuck level-13 request is the **RTC (real-time clock)
interrupt**, held asserted because IOC bit3 (clock-int-generated) & bit0 (enable)
are both set and not clearing. The INSTRUCTION test clears level 13 by writing
**PID** (clears the interrupt-controller request latch only) — it does NOT clear
the **IOC bit-3 source**, so it re-arms every MCLK. The RTC free-runs from master
clear (`DECODE_DGA_POW.v:363`); memory note `rtc-free-running`.

**The interrupt-controller RTL (RQBIT/CLR/IRSRC) is CORRECT and schematic-faithful**
(RQBIT_V2 INR equation identical to the Page-78 original; clears then re-arms
exactly as designed). Do NOT change it.

**REFINED (idle observation at TPE>, IOC/RTC-instrumented probe):** `s_ioc_3` is
NOT stuck — it **TOGGLES** (1,0,0,0,1,0,...) and `INTR_ireq_n[3] = ~s_ioc_3`
tracks it; `s_ioc_0`=1 throughout (OS-enabled); `s_rtc_cnt` free-runs and wraps
(~8192, sim-shortened). So at idle the level-13 RTC interrupt **PULSES normally**
(OS clock handler services it) — it is NOT permanently stuck.

=> The INSTRUCTION-test failure is a **TIMING RACE (hypothesis A)**: the
sim-shortened RTC fires far faster than the real 20 ms, so the test's
"clear level 13 then verify" loop is longer than one RTC period — the RTC
re-asserts `s_ioc_3` mid-verify and the test never catches level 13 cleared
=> "Impossible to clear". On real HW the 20 ms RTC is slow enough that the
clear-verify fits the gap (reference passes).

**Fix decision (needs confirming):**
- (A) sim RTC too fast — slow the `VERILATOR_SIM` short RTC count in
  `DECODE_DGA_POW.v` so level 13 pulses at a realistic rate; OR
- (B) the test DISABLES level 13 (writes IOC bit0=0 / masks) before clearing and
  our RTL doesn't honor it — then it's an IOC-write / mask RTL bug. Needs an
  IOC/RTC trace over the TEST's clear window (does the test write `s_ioc_0`=0?).
- `s_ioc_0` stayed 1 across the idle window; unknown during the test.

Probe signals added for this (group `IOCRTC` in `sim/nd120_probe.cpp`): `IOC_0`,
`IOC_3`, `SIOC_n`, `RTC`, `RTC_CNT`. Driver `/tmp/claude-1000/tpe_rtc_probe.py`
(NOTE: its end-of-run tally has a bug — `Probe.events()` returns Event objects,
not dicts, so use attribute access `e.trig` not `e.get("trig")`; the sampled
idle values printed fine before the crash).

### CONFIRMED: hypothesis A (IOC trace over the TEST clear window, `tpe_intr_idc2.csv`)
Watching `IOCRTC` during the INSTRUCTION clear sweep (36,800 rows):
- **`IOC_0` = 1 in ALL rows** — the test NEVER disables level 13.
- **`IOC_3` toggles** (30,024 rows 0, 6,776 rows 1) — the RTC keeps re-generating
  the clock interrupt during the test.
- When the clear targets bit3 (`INTR_clrq`=10): 64 samples have `ioc3=1` (RTC just
  re-fired, clear loses the race), 304 have `ioc3=0`; `ioc0=1` always.

=> **A, definitively.** The test relies on the RTC period being long; our
sim-shortened RTC re-fires mid-clear so level 13 is never caught cleared.

### THE FIX (RTC period, `DECODE_DGA_POW.v` — do NOT touch the INTR RTL)
`DECODE_DGA_POW.v:357-361` (VERILATOR_SIM branch):
```
localparam RTC_20MS = 21'd8192;   // Matches original ~8K-cycle period (TESTE=1 baseline)
localparam RTC_5MS  = 21'd2048;   // Proportional (1/4 of 20ms)
```
The comment (`:359`) already records this exact failure class:
"256 was too fast (32x) - instruction verify programs couldn't execute enough
instructions per RTC period" — 256 was bumped to 8192. **8192 is still too fast
for the INSTRUCTION verifier's clear-and-verify loop.** Fix = give level 13 a
longer period, one of:
- Bump the VERILATOR_SIM `RTC_20MS`/`RTC_5MS` further (e.g. 8192 -> 65536+,
  keeping the 4:1 ratio) until the clear-verify fits; OR
- Build with `-DRTC_REAL_PERIOD` (`:352-356`) to use the true 20 ms/5 ms period
  (`BOARD_CLK_FREQ/50` ~= 780K cycles at 39 MHz) — most faithful, but RTC-timed
  tests then take realistic (longer) sim time.
Tradeoff: a slower sim RTC costs some sim throughput and changes RTC-timing tests;
the `RTC_REAL_PERIOD` and FPGA branches are the safe, faithful choice. This is a
one-parameter, sim-only change; the FPGA/`RTC_REAL_PERIOD` paths are untouched.
**Verify:** rebuild + re-run the INSTRUCTION test; level 13 should clear and the
run should proceed past init to the 9 levels (then the page-fault/level-14 item
in section 4 becomes reachable).

### 6f. PARTIAL mitigation, NOT a deterministic fix (corrected 2026-07-24, FF mode)

> **CORRECTION.** An earlier version of this section claimed slowing the RTC
> "fixes" the init failure "deterministically". That was an OVERCLAIM based on a
> single passing run. Re-tested: at RTC period 524288, the init sweep is
> **inconsistent** - it passed once (rtff64, reached Level 1) and FAILED another
> time (rtff64d, `Impossible to clear` at 97M, reached no level). Slowing the
> RTC REDUCES the collision probability but does not eliminate it.
>
> **Why it can't be a pure-rate fix:** the RTC counter is 21-bit
> (`reg [20:0] s_rtc_cnt`), so the maximum period is ~2,097,151 ticks. If the
> init sweep's level-13 vulnerable window is longer than that (plausible - the
> sweep walks all 16 levels), the RTC fires at least once during it at ANY
> period, so a collision is always possible. Rate alone cannot drive the failure
> probability to zero within 21 bits.
>
> **Also note:** real ND-120 hardware runs the RTC at a 20 ms period = ~333,333
> cycles at 16.67 MHz, which is FASTER (shorter period) than the 524288 that
> sometimes passes in sim - yet real TPE passes reliably. That inconsistency
> means the pure-rate model is INCOMPLETE: there is a second factor (candidate:
> the RTC trap handler that clears IOC bit3 does not run / does not clear bit3
> the same way in this sim context; or the test disables interrupts during init
> and the clear path differs). UNRESOLVED - needs the level-13 clear path traced,
> not just the rate.

### 6g. MECHANISM (traced 2026-07-24) - RTC fires during the interrupt-MASKED init sweep

Continuous trace at the default RTC 8192 (`sim/tpe_ioc3_idc3.csv`, 30,664 rows,
tick 107.0M-118.9M, capturing every RTC fire / IOC write / CLRQ). Findings:

- IOC bit 3 is NOT stuck-set: it toggles **460 up / 459 down**, every edge at an
  IOC write. Software DOES clear the source repeatedly - my earlier "never
  clears the source" hypothesis was WRONG.
- bit 3 is high **64%** of the time. LOW windows median ~7.4K ticks; HIGH windows
  median 787 but with a long tail (**p90 = 75K ticks, max 77K**).
- The init sweep RETRIES **112 times** (CLRQ bursts ~25-35K ticks each, ~100K
  apart) over 12M ticks, then gives up -> "Impossible to clear ... level".

**Mechanism:** the sweep masks interrupts while it clears the 16 request latches.
While masked, the RTC fires and sets IOC bit 3 (the level-13 source), but the RTC
trap handler cannot run to clear it (interrupts are masked) - so bit 3 stays high
for the entire masked window (the ~75K-tick HIGH tail), and the level-13 verify
INSIDE that window sees level 13 still requesting -> "Impossible to clear". At the
fast sim RTC (period 8192) a fire lands in nearly every masked sweep window, so it
fails all 112 retries. On real hardware the masked window is short in TIME and the
20 ms RTC almost never fires inside it -> passes.

This resolves the "real HW period is shorter yet passes" paradox: what matters is
not the raw period but **whether an RTC fire lands inside the masked sweep window**
(~75K ticks). Predicted per-burst failure prob = 75K / RTC_period: ~14% at 524288
(hence rtff64 pass / rtff64d fail), ~3.6% at the 21-bit max ~2.1M (should pass
reliably within a few retries). TEST IN PROGRESS: RTC poked to 2,000,000.

If 2M still fails, the fix is not rate at all but to keep the RTC from firing
while interrupts are masked (e.g. widen the counter, or gate/pause the RTC during
the mask) - a sim-faithfulness question about the shortened RTC vs real timing.

Below is what WAS observed on the one passing run (rtff64) - useful as the
"reaches the levels" datapoint, but NOT a reliable, repeatable result:

1. Boot at the fast default (8192) -> reach `TPE>` at ~44M ticks.
2. `p.rtc(524288)` at the prompt -> RTC period retuned live to 524288/131072
   (~0.29 % level-13 exposure) with no reboot.
3. `INSTRUCTION` loads (Version C ~58M), `set-para,N,N,Y,N,Y`, `run`.
4. **No init error.** The "Impossible to clear IDENT interrupt" sweep that
   previously blocked the run is GONE. The run proceeds into the test levels.
5. `=== Running Tests on Level 1 ===` -> **Argument instructions PASS**
   (`=== End of test ===`, no error lines).
6. **Memory reference instructions FAIL**: `*** ERROR *** Operation was: STA`,
   then `STT`, `STX`, ... - the store instructions. This is the page-fault group
   of section 4, now REACHABLE and reproduced in our sim.

Conclusion: there is no "second mechanism" - the sole cause of the init failure
was the too-fast sim RTC re-arming level 13 inside the clear-verify window.
Slowing it fixes init deterministically. The *next* real bug is the store /
page-fault handling in the Memory-reference test (section 4).

**Two knobs now exist** (both sim-only, both default-preserving):
- **Build-time** `-DRTC_SIM_20MS=<cycles>` (section 6e) - sets the compiled-in
  period. BUT the boot is RTC-paced, so a large value multiplies boot time by
  the same factor (8x => boot still short of `TPE>` at 177M ticks vs 44M).
- **Run-time** `rtc [20ms [5ms]]` probe command / `Probe.rtc(cycles)` - retunes
  the period live. Requires the RTL vars (`s_rtc_20ms_var`/`s_rtc_5ms_var`, under
  `VERILATOR_SIM`) AND the engine built with `-DND120_RTC_RUNTIME` (the probe
  guards the member access on that define so it still builds against stock RTL).
  **This is the preferred path**: boot fast at 8192, then poke to a realistic
  period only for the rate-sensitive test.

**SEQUENCING (important - input is RTC-paced too):** OPCOM services one *typed*
character per RTC tick, not just output. So if you poke the RTC slow and THEN
type a command, characters drop (observed: `set-para` arrived as `t-para` ->
`*** No such command`). Type every command (`INSTRUCTION`, `set-para`, `run`) at
the fast default RTC; send `run`, let it be received (~2M ticks), and only THEN
poke the RTC slow - before the init-clear sweep, which is ~20M ticks into the
run. The sweep is what needs the slow RTC; the typing does not. (An earlier note
here said send-gap scaling was unnecessary after boot - that was wrong; the fix
is the poke-after-typing order, not a bigger gap.)

### 6e. Quantified rate model + the `RTC_SIM_20MS` knob (measured 2026-07-24)

Numbers extracted from `Verilog/sim/tpe_intr_idc2.csv`
(46 capture windows, 36,800 data rows, span tick 106,039,663 .. 106,924,431):

| Quantity | Measured |
|---|---|
| probe tick : sysclk : `RTC_CNT` increment | 1 : 1 : 1 (verified over a window: 799 ticks = 799 counts) |
| RTC period at the 8192 default | 8,193 ticks |
| Test clear-then-verify loop, repeat interval | median 7,427 ticks (min 3,521 / max 79,583) |
| `IOC_3` high duration | > 800 ticks (8 of 46 windows are high end-to-end; no complete pulse fits an 800-tick window) |
| `IOC_3` duty cycle | 18.41 % (6,776 / 36,800 rows) |
| `IOC_0` (enable level 13) | `1` in **every** row — the test never disables level 13 |
| `SIOC_n` strobes (IOC register writes) | 16 rows — the IOC write path is **not** dead |

So the RTC fires almost exactly **once per level check**. That is the collision.

**Trap when reading the CSV:** the probe prints multi-bit values in **octal**.
`RTC_CNT` maxes at `20000` = 8192 decimal, which is the `RTC_20MS` default — not
a 20,000-cycle period. Reading it as decimal makes the RTL look wrong when it is not.

**`RTC_REAL_PERIOD` cannot be used as-is.** A boot on that build never reached
`TPE>` in 252 M ticks; the console showed only `#1&`. Cause is in the harness, not
the CPU: `Verilog/sim/nd120_probe.cpp:609` sends one
input character every `ND120_SEND_GAP` ticks (default 300,000), but OPCOM input is
serviced once per RTC tick. At a 2,000,000-tick RTC period the harness typed ~6.7x
faster than MOPC could consume, and the middle characters of `1560&` were dropped.
**Any change to the RTC period must scale `ND120_SEND_GAP` with it.**

**New knob (default-preserving)** — `DECODE_DGA_POW.v`, VERILATOR_SIM branch:

```
`ifdef RTC_SIM_20MS
  localparam RTC_20MS = 21'd`RTC_SIM_20MS;
  localparam RTC_5MS  = 21'd`RTC_SIM_20MS / 21'd4;
`else
  localparam RTC_20MS = 21'd8192;   // historical baseline - golden traces assume it
  localparam RTC_5MS  = 21'd2048;
`endif
```

Undefined => byte-identical to the old behaviour, so existing golden traces are
unaffected. Use it instead of `-DBOARD_CLK_FREQ=...`, which would also retune the
`SC2661_UART` baud divisor and desync it from the probe's fixed `DELAY_FRAMES=16`.

Build a swept variant with
`Verilog/sim/` +
`RTCVAL=65536 MDIR=obj_dir_probe_r8 bash <build script>` (~192 s). Confirm the
value actually reached the RTL by grepping the generated eval for the compare
constant — for 65536 it reads `? 0x10000U : 0x4000U`.

### Who sets `IOC_3` — measured, not assumed

`IOC` bit 3 lives in `TTL_74273 CHIP_28A_IOC` (`IO_REG_41.v:169-186`). Its D input is
the IDB only, so the bit has **no hardware set and no hardware auto-clear** (just the
master `CLR_n`) — it is written by software, matching the RTL comment "clock
interrupt generated from RTC trap handler".

Confirmed in the trace: of the two `IOC_3` rising edges captured, **each is preceded
one tick earlier by an `IOC` write strobe**, and each write follows an RTC counter
wrap by ~50-200 ticks:

```
RTC_CNT wrap @106,045,535 -> IOC write strobe @106,045,583 -> IOC_3=1 @106,045,584
RTC_CNT wrap @106,901,949 -> IOC write strobe @106,902,142 -> IOC_3=1 @106,902,143
```

So the causal chain is: **RTC fires -> RTC trap handler writes IOC bit 3 -> level 13
asserted.** TPE's clear reaches the request latch but never bit 3, so the level
re-arms. Slowing the RTC reduces how often bit 3 is re-set, which is why the period
is the right knob.

### Why real hardware still passes (corrected arithmetic)

Only the **level-13** check is exposed to this race, not all 16 levels — an earlier
estimate that multiplied the risk across 16 checks was wrong. Exposure per attempt is
`IOC_3` high-time / RTC period:

| RTC period | Failure probability per level-13 check |
|---|---|
| 8,192 (sim default) | ~18 % — observed to fail |
| 65,536 (8x) | ~2.3 % |
| 524,288 (64x) | ~0.3 % |
| 333,333 (real 20 ms @ 16.67 MHz) | ~0.45 % — acceptable for a shipped diagnostic |

If a slower sim RTC still fails the init sweep, the rate model is wrong and there is
a second mechanism — abandon rate tuning rather than pushing it further.

## 6h. Two firm results (measured 2026-07-24) — RTC rate disproven; banner word-2 all-ones is RTC-independent

Two independent, measured findings this iteration:

**(A) RTC-rate is NOT the init fix.** A run with the RTC runtime-poked to period
`2,000,000` (near the 21-bit `s_rtc_cnt` ceiling of ~2.097M) STILL hit
`*** TPE initialization error *** Impossible to clear ... IDENT`. Per section 6g,
the permanent fix is therefore NOT rate at all — the RTC must be prevented from
firing *while interrupts are masked* during the init sweep (gate/pause it during
the mask, or widen the counter beyond 21 bits). Rate tuning within 21 bits cannot
guarantee a clear. (Engine `obj_dir_probe_rtff`, `tpe_instr_rt.py`, TPE_RTC=2000000.)

**(B) The banner string-read corruption is deterministic and RTC-INDEPENDENT,
always at word-index 2.** Measured at the DEFAULT fast RTC (period 8192, no poke),
with the verifier's own auto-run — the corruption prints BEFORE any `run` I issue,
so it is decoupled from the init/RTC entirely:
- Typed echo `INSTRUCTION` is CLEAN (input path fine).
- The verifier's OWN banner reads `INST\x7f\x7fCTION` — `\x7f` = octal 0177 = a
  byte with all 7 bits set. "RU" (the 3rd 16-bit word) reads as **all-ones**; the
  rest of the banner ("- Version: C03 - 1988-03-04") is CLEAN. Only 2 bytes wrong.
- Packing: the banner is stored in `FLOPPY1.IMG` (offset 592402) as plain
  sequential ASCII `I N S T R U C T I O N ...`, i.e. 2 chars/word `[IN][ST][RU]...`.
  So the corrupt word is **word-index 2**.
- This matches the earlier `MEMORY` banner `MEMO\x7f\x7f`: `[ME][MO][RY]` — `RY` is
  ALSO word-index 2. (The MEMORY datum is a prior note, not re-run today —
  corroborating, not independently re-verified.) Two DIFFERENT strings corrupt at
  the SAME iteration index -> the fault is in the print loop's 3rd read, not in
  string content. This rules out the print routine as a whole (rest is clean),
  a broad memory fault (one word), and the input path (echo clean).

**Decisive experiment — RESULT (2026-07-24, `/tmp/claude-1000/ram_probe_banner.py`,
engine `obj_dir_probe_rtff`): RAM IS CORRECT -> the bug is in the CPU READ/PRINT
path, NOT the DMA load.** The probe `examine` backdoor (reads the same sim RAM the
CPU reads) found THREE copies of the banner in RAM (octal addresses 05252, 07422,
012023) and at ALL THREE the word-2 cell holds the correct value:
```
word0=044516 (0x494E 'IN')  word1=051524 (0x5354 'ST')  word2=051125 (0x5255 'RU')  <- CLEAN
```
So the floppy-DMA load deposited the word correctly; the RAM is intact everywhere.
When the print routine READS word-index 2, the CPU delivers `0177777` (all-ones)
instead of `0x5255`. This is a genuine CPU read/access bug, reachable at LOAD time
with NO passing init — the cleanest available handle on the (2)-class
memory-reference failure.

IMPORTANT (not yet proven, next experiment): `0177777` all-ones is the classic
UNMAPPED / bus-timeout read value. So the 3rd read may be targeting a WRONG or
unmapped address (an addressing / auto-increment bug) rather than the read data
path corrupting a correct-address fetch. That would tie directly to the failing
memory-reference instructions (STA/ADDD/TSET...). DECISIVE next test: capture the
memory ADDRESS + DATA bus at the moment word-2 is read during the banner print
(~73M ticks). If address == the banner word-2 address (e.g. 05254) but data reads
all-ones -> read-data-path bug at the correct address. If address != that -> an
addressing/increment bug that walks off into unmapped space. Do NOT assert which
until traced.

## 6i. OVERTURN (measured 2026-07-24) — the memory FETCH is clean; corruption is DOWNSTREAM

Direct bus capture (`/tmp/claude-1000/bus_capture_banner.py`, engine
`obj_dir_probe_rtff` with the new `BUSRD` probe group: `MEMRD_ADDR`=`MEM.s_lbd_23_0_in`,
`MEMRD_DATA`=`MEM.s_lbd_15_0_out` the 16-bit fetched word, `RAM_IDX`=`MEM.RAM.idx0`,
`RAM_Q`=`MEM.RAM.q0`, `CSA`) recorded every read touching the three banner copies
during the corrupt banner print. Findings (CSV `sim/bus_banner_bus.csv`, 14252 rows):

- `MEMRD_DATA` is **NEVER `0177777`** (all-ones count = 0 in the entire capture).
- The fetched-word bus delivers the CORRECT banner words, INCLUDING word-2:
  `051125` (0x5255 'RU') appears **260 times**; also `044516`('IN'), `051524`('ST'),
  `041524`('CT'), `044517`('IO').
- `MEMRD_ADDR` DOES present the word-2 address (octal 5254 / 7424 / 12025 — decimal
  2732/3860/5141), 177 times. There is NO addressing skip and NO unmapped read.

**Therefore the §6h "0177777 = unmapped/bus-default read" and the addressing/
auto-increment lead are DISPROVEN by measurement.** The memory subsystem fetches
'RU' correctly. The `\x7f\x7f` (0177 0177) seen on the console originates DOWNSTREAM
of the memory fetch — in the CPU datapath (byte-select / register / ALU handling of
the fetched word) or the character-output path — NOT in memory, DMA, or addressing.
(§6h's proven part still stands: RAM holds correct 'RU'; the DMA load is correct.
Only the mechanism guess — read/addressing fault — was wrong.)

Note on 0x5255 -> 0x7F7F: both bytes 'R'(0x52) and 'U'(0x55) become 0x7F (low-7-bits
set). Not yet explained; do NOT assume a specific transform. NEXT: capture the CPU
output-byte stream (probe `TXBYTE`/`TXSTROBE`) across the banner print and correlate
the 0x7F emissions back to the register / IDB value feeding the UART at word-index 2,
to locate where the correctly-fetched 'RU' is turned into 0x7F7F. This is still the
clean pre-init handle on a real CPU datapath bug (candidate: same class as the
failing memory-reference instructions, but that is unproven).

## 6j. Localization (measured 2026-07-24) — transmitted byte is 0xFF; datapath localized to the UART-write

New `OUT` probe group (`CD16`=`DELILAH.s_cd_15_0`, `AREG`=WRF A_REG_5.regFF, `TREG`,
`FIDBO`=`DELILAH.s_FIDBO_15_0`, `CPUIDB`=`s_cpu_idb_15_0_out`, `IOIDB8`=`IO.s_idb_7_0_in`
byte lane, `THR`=UART transmit holding reg, `TXBYTE`). Captured the real banner
print at tick ~71.667M (`sim/out_banner_out.csv`). Key finding:

- The **transmitted byte for the word-2 chars is `0377` (0xFF, all 8 bits)** — NOT
  `0x7F`. The console `\x7f` is the 7-bit serial reconstruction of `0xFF` (7 data
  bits all 1). So the corruption is an **all-ones byte reaching the UART**, matching
  the "all-ones" theme but now precisely: 8-bit `0xFF`.
- At the sampled ticks the CPU datapath holds the CORRECT char: e.g. tick 71667641
  `CD16`=002522 (low byte 0x52='R'), `FIDBO`=002522, `IOIDB8`=0122 (0x52='R') — the
  byte lane presents 'R' correctly — yet `THR`=0377 (0xFF). So the corruption is at
  the **byte-lane -> UART transmit-holding-register boundary**, NOT upstream in the
  CGA (CD16/FIDBO/AREG are correct for 'R').

CAVEAT: the OUT capture was rule-triggered/sparse and did not catch the exact THR
LOAD edge, so the alignment of 'R'-on-lane vs THR=0xFF is not yet cycle-exact. IN
PROGRESS: `WRUART` group + `/tmp/claude-1000/wruart_capture.py` triggers on the
actual THR-write cycle (`UART_CE_n==0 && UART_WR==1 && UART_ADDR==0`, from
`SC2661_UART.v:304-311` where `regTransmitHoldingRegister <= s_data_in`) and records
`UART_DIN` (the byte latched) for every banner char in order (I,N,S,T,?,?,C,T,I,O,N).
If word-2's two writes show `UART_DIN`=0377 while the good chars are correct, the
wrong byte is presented to the UART data input at the write strobe — corruption in
the IDB byte-lane routing/timing at that write. Result pending
(`/tmp/claude-1000/wruart_capture.stdout`). NOTE: uses default fast RTC; no init
needed; this is a pre-init, deterministic CPU/IO datapath bug.

## 6k. DEFINITIVE (cycle-exact, 2026-07-24) — the CPU drives 0xFF as the output byte; memory/UART/byte-lane all clean

`WRUART` probe group triggered on the exact UART transmit-holding-register write
cycle (`UART_CE_n==0 && UART_WR==1 && UART_ADDR==0`; `SC2661_UART.v:310`
`regTransmitHoldingRegister <= s_data_in`). Captured every banner char's written
byte (`UART_DIN`) in order (`sim/wruart_wr.csv`, `/tmp/claude-1000/wruart_capture.py`).
The banner "    INSTRUCTION - Version..." writes, in sequence:

    I  N  S  T  0377  0377  C  T  I  O  N   ...   V e r s i o n ...   (all others correct)

- The two word-2 chars ('R'=0122, 'U'=0125) are each written as **0377 (0xFF)**.
- At those two write cycles (ticks 71662332 / 71694120): `UART_DIN`=0377,
  `IOIDB8`=0377, **`FIDBO`=0377, `CD16`=0377** — the value is ALREADY 0xFF on the
  CPU's internal data bus (`FIDBO`=`DELILAH.s_FIDBO_15_0`) and CD bus, not just at
  the UART input. Every other char writes its correct code (I=0111, N=0116, etc.).

**Conclusion (measured, not inferred): the CPU itself drives 0xFF as the output
byte for the print loop's 3rd character-pair.** Memory delivered the correct 'RU'
(§6i), the UART and the IDB byte-lane faithfully pass whatever the CPU drives, so
they are all exonerated. The corruption is in the CPU datapath PRODUCING the output
byte, and it is position-locked to word-index 2 (value-independent: both 'R' and 'U'
-> 0xFF; MEMORY's 'RY' corrupts at the same index) = the 3rd iteration of the shared
TPE string-print routine. This supersedes the §6j "byte-lane->UART boundary" guess:
the value is already 0xFF one stage earlier, inside the CGA.

Cross-check from the OUT run: the A register read 0177777 (0xFFFF) throughout the
banner even for correctly-printed chars, so A is NOT the char source; the output
char is sourced from another register/GPR via the ALU/IDBCTL onto FIDBO. NEXT:
capture the WRF registers (D/B/T/X) + ALU GPR at each banner UART write to find
which register holds 0xFFFF for word-2 (and whether the word-2 LOAD - which fetched
0x5255 correctly on MEMRD_DATA - wrote 0xFFFF into its destination register).

## 6l. Source register identified (2026-07-24) — output char = A register; A holds 0x00FF for word-2

`WRREGS` probe group snapshots all 7 WRF registers (P,D,B,L,A,T,X) at each banner
UART write (`sim/wrregs_rg.csv`, `/tmp/claude-1000/wrregs_capture.py`). Result:

- **`RA` (A register) == `UART_DIN` for EVERY banner char** (I->0111, T->0124,
  C->0103, ... and the two corrupt chars -> **0377 = 0x00FF**). `FIDBO`==`RA` too.
  So the output character is sourced from the **A register** (low byte -> UART).
- All other registers are constant across the banner (RP=03044, RD=055672,
  RL=03026, RT=000305; RB/RX tick once late = likely the string pointer). So A is
  the per-char output register.
- For word-2's two chars, **A = 0x00FF** (should be 0x52 'R' / 0x55 'U'). Both
  bytes of word-2 emerge as 0xFF => the word-2 value the routine extracts from is
  effectively **0xFFFF**.
- Since BUSRD proved **no memory read ever returns 0xFFFF** (the bus delivers the
  correct 0x5255), the 0xFF is **generated internally by the CPU**, not fetched.

**Chain complete to the register level:** memory delivers 0x5255 -> the CPU's
handling of the string's 3rd word yields 0xFFFF -> byte-extract puts 0x00FF in A ->
A's low byte 0xFF is written to the UART -> console shows `\x7f` (7-bit form of
0xFF). Position-locked to word-index 2 (the print loop's 3rd iteration),
value-independent, pre-init, deterministic. This is a real CPU datapath/instruction
bug and a strong candidate for the same root as the memory-reference instruction
failures (STA/ADDD/TSET...).

OPEN (microcode level, next): find the instruction/CSA that loads word-2 and yields
0xFFFF - trace the A-register write (and the register that holds the word-2 word)
during the load, watching CSA + the ALU/IDBCTL source, to see whether it is a
byte-extract producing 0xFF or a load/latch that fills 0xFFFF on the 3rd iteration.
The output loop runs at CSA=0476; the word-2 load is at an earlier CSA.

## 6m. Compute-not-stored; next step is microcode-level (2026-07-24)

Two more measured facts narrow the mechanism:
- The banner print does NOT re-read the 3 correct string copies (05252/07422/012023)
  at output time (MEMLOAD trace: zero reads of the word-2 addresses during the
  >71M print window). And the earlier RAM scan (0..0x80000) found NO stored copy of
  the banner with word-2 = 0xFFFF. So the 0xFF char is NOT sourced from a
  corrupted stored buffer.
- The RA-origin trace shows the A register holding a full **0177777 (0xFFFF)**
  during a computation at CSA 01151-01156, which is then byte-masked to 0x00FF
  (the output byte). So the word-2 value is COMPUTED as 0xFFFF, not fetched.

Conclusion: word-2's char is produced by a CPU computation that yields 0xFFFF on
the 3rd word, then masked to 0xFF and sent via A. This is consistent with a real
instruction/microcode defect in the shared TPE string-print routine that our CPU
mis-executes on that iteration (candidate: same class as the memory-reference
instruction failures). Pure probe traces have localized it fully at the
register/bus level; pinpointing the exact microinstruction now needs the microcode
ROM disassembly. NEXT: map the CSA addresses seen while A=0xFFFF (01145, 01151-01156,
06046, 07465) to microinstructions via the nd120uc sister project
(/mnt/e/Dev/Ronny/nd120uc, EPROM-validated .uc source) to identify the operation
that produces 0xFFFF; and/or confirm with Ronny (he knows the sheets/microcode).

Reusable probe instrumentation added this session (UNCOMMITTED, nd120_probe.cpp):
groups `BUSRD`, `OUT`, `WRUART`, `WRREGS`, `MEMLOAD` + registry signals for the
MEM read path, CGA datapath (CD16/FIDBO), WRF registers (P/D/B/L/A/T/X), and the
UART write path. All observable under the existing --public-flat-rw build; only the
C++ harness relinks (no re-Verilate).

## 6n. Authoritative word-2 output trace (2026-07-24) — both chars identical, char = 0x00FF (computed)

Mining the RA-origin CSV for the marks nearest the two KNOWN word-2 UART writes
(ticks 71662332 and 71694120) gives the clean, char-specific trace (the 71.05M
clusters in 6m were unrelated A=255 events - the `RA==0377` trigger is coarse). The
two word-2 char clusters (starting 71662216 and 71694004) are **byte-identical**:

    ...read ADDR=03075 -> DATA=0377 (0x00FF), CD16=0377 -> FIDBO=0377 ... A <- 0377

- Both word-2 chars read the SAME fixed address 03075 and both get DATA=0377
  (0x00FF); then FIDBO=0377 and finally RA=0377 -> output byte 0xFF.
- Same address + same value for two DIFFERENT chars ('R' then 'U') => this is NOT a
  per-char character-array walk (that would use two different addresses); 0x00FF is
  a computed / fixed-operand value that replaces the real char for word-2.
- Refines (does not contradict) BUSRD: the value is 0377 (0x00FF), never 0177777
  (0xFFFF) - so "no memory read returns all-ones" still holds; the OUTPUT byte 0xFF
  is the low byte of 0x00FF.

Net measured chain (authoritative): correct packed string in RAM (0x5255) -> the
verifier's print routine, on its 3rd word, produces 0x00FF (not the real char) via
a read of a fixed location 03075 / a compute at CSA around 0172 & 06500 -> A=0x00FF
-> UART -> console `\x7f`. Position-locked to word-2, value-independent, pre-init,
deterministic; the monitor's typed-echo path is unaffected. Root cause is a
microcode/instruction defect in the shared print routine's 3rd-iteration handling.
REMAINING work is microcode/program-level (map CSA 0172/06500 to microinstructions
via nd120uc, and/or disassemble the print routine) - beyond register/bus probing.

## 6o. Microcode decode (2026-07-24) — 0377 is a MEMORY-READ result, not a mask: effective-address bug

Decoded the traced CSAs against the EPROM-exact microcode
`/mnt/e/Dev/Ronny/nd120uc/source/ND-120-DELILAH-L.uc` (fields per
`nd120uc/docs/ND120-microcode-bitfields.md`):
- **06500 `LDT`**: `ALUF,A+Q  COMM,AREAD,*` = compute effective address `A+Q`, issue
  an R-relative memory READ. This is where the value enters.
- **0172 `LDT1`**: `IDBS,DBR  ALUF,PASSD  ALUD,B` = forward the data-bus register
  (the just-read word) UNCHANGED to dest. No mask, no shift.
- **07465** (RADD family): `ALUF,A+1` = a register increment (pointer/index advance).
- None of the traced microinstructions does a byte-extract/mask/swap or applies
  0377; the byte routines (LBYT@07422, SBYT@07426, BTL/BTR/BFILL) are NOT entered.

=> The corrupt 0377 is **the result of a memory READ whose effective address (A+Q)
resolved to octal 03075**, then forwarded verbatim. So the defect is in the
**effective-address / index computation** (the `A+Q` add at 06500, or the `A+1`
advance at 07465) selecting the wrong address on word-2's chars — NOT a byte-mask.
This is an ALU/addressing datapath bug and is consistent with the memory-reference
instruction failures. (Address 03075 is main memory, not control store; the
microcode can't say what's there - needs a RAM examine.)

Testable prediction: capturing the memory-read effective address per banner char
should show a clean incrementing sequence for the good chars and a deviation to
octal 03075 for word-2's two chars. NEXT experiment set up to verify + examine what
octal 03075 holds.

## 6p. CORRECTION (2026-07-25) — the "reads address 03075" pairing is UNRELIABLE

An examine + per-char read-address capture forces a correction to 6n/6o:
- `examine[03075] = 0164` (NOT 0377). So 03075 does not hold the corrupt byte at
  examine time. Combined with the DRAM being time-multiplexed (MEMRD_ADDR and
  MEMRD_DATA update on DIFFERENT cycles), pairing the `ADDR=03075` sample with the
  `DATA=0377` sample by proximity (as in 6n) is UNSOUND. **Do not treat "word-2
  reads octal 03075 and gets 0377" as established.**
- The per-char source-read heuristic (first non-zero MEMRD_ADDR in the pre-window)
  returned 03043 for EVERY char - too crude to isolate the char-specific read. So
  this run did NOT confirm a per-char effective-address deviation.
- `examine[03060..03073]` look like ND-120 opcodes (0134055, 0124355, ...) = likely
  code; `03074+` is scratch (`[03100]=055672` == the RD register value seen in
  traces = a register-save area).

What REMAINS solid (unaffected by the pairing issue): the output byte for word-2 is
0xFF, present on the CPU-internal FIDBO/CD16 and in A (=0x00FF); memory/DMA/RAM/UART
/byte-lane are clean; position-locked to word-index 2; value-independent; pre-init;
the typed-echo path works. The microcode decode (6o) shows the value is a
memory-READ result forwarded unchanged (no byte-mask), so an effective-address /
index-arithmetic defect is the leading HYPOTHESIS - but it is NOT yet confirmed at
the address level, because reliable ADDR<->DATA pairing needs a cycle-accurate
capture that accounts for the DRAM mux (or a disassembly of the print routine).

Honest status: the bug is exhaustively characterized at the register/bus level and
strongly narrowed at the microcode level, but the exact faulting instruction/address
is NOT yet pinned. Next approaches (either): (a) a cycle-accurate capture keyed to
the memory read strobe (BDRY/maclk) so ADDR and DATA are sampled from the same
transaction; (b) disassemble the verifier/monitor print routine to learn its char
loop; (c) confirm direction with Ronny (microcode/sheets knowledge) before deeper
hunts, per project practice.

## 6q. CONSOLIDATED STATUS (2026-07-25) — solid characterization; exact instruction NOT yet pinned

Two attempts to confirm the effective-address hypothesis at the instruction level
were both INCONCLUSIVE:
- Per-char source-read address (6p): DRAM-mux made ADDR<->DATA pairing unsound.
- Per-char A+Q from registers at CSA=06500 (this run, `sim/eacomp_ea.csv`): the
  A+Q at the caught 06500 is just 1 or 0116400 and does NOT differ between word-2's
  chars and good chars -> the 06500 I catch is not the char-source read. So the
  effective-address defect is neither confirmed nor refuted. Root problem: I do not
  know the print routine's per-char algorithm, so I cannot key a probe to its
  char-source read.

**What is SOLID and reproducible (the actionable result):**
1. Symptom: verifier banner "INSTRUCTION"->"INST\x7f\x7fCTION"; word-index 2 only;
   value-independent (MEMORY corrupts identically at its word-2); deterministic;
   pre-init; RTC-independent.
2. The transmitted byte is 0xFF (0377); console \x7f is its 7-bit serialization.
3. The byte is driven by the CPU itself: at the UART write, the CPU-internal FIDBO
   and CD16 = 0377 and the A register = 0x00FF; A==UART_DIN for every char.
4. Exonerated by measurement: RAM/DMA (deliver correct 0x5255, bus never all-ones),
   the UART, the IDB byte-lane, and the monitor's typed-echo path (prints RU fine).
5. Microcode: the value is a memory-READ result forwarded unchanged (LDT/LDT1); no
   byte-mask/shift is involved.

**Leading hypothesis (unconfirmed):** an effective-address / index-arithmetic defect
in the shared TPE string-print routine, mis-executed by our CPU on its 3rd word -
same class as the memory-reference instruction failures (STA/ADDD/TSET...).

**To pin it (needs a different method than register/bus probing):**
- (a) Disassemble the verifier/monitor print routine (find its char loop) so a probe
  can be keyed to the exact char-source read; then re-run the A/Q/base capture.
- (b) A cycle-accurate capture strobed by the memory-read-complete signal so
  ADDR/DATA pair from one transaction.
- (c) Confirm direction with Ronny (microcode/sheet knowledge) before deeper hunts.

Reusable probe instrumentation (UNCOMMITTED in `sim/nd120_probe.cpp`): groups
BUSRD, OUT, WRUART, WRREGS, MEMLOAD, SRCADDR, EACOMP + registry signals for the MEM
read path, CGA datapath (CD16/FIDBO), all 7 WRF regs, ALU Q, and the UART write
path. Harness-only relink (no re-Verilate) on the existing obj_dir_probe_rtff.

## 6r. BREAKTHROUGH comparison (2026-07-25) — good vs corrupt char differ ONLY in the value A receives at CSA 0172

Compared a good char ('T') vs the word-2 char, cycle-by-cycle, from eacomp_ea.csv:
- The CSA micro-program is BYTE-FOR-BYTE IDENTICAL (70 steps; both run 0170, 0172,
  06440, 06500, 07730, 07504). Control flow is NOT the difference.
- At CSA 0172, EVERY captured signal is identical (CD16=050033, MEMRD_DATA, QREG=1,
  RB=07672, RX=07504) EXCEPT the value loaded into A:
    good 'T':  A <- 0124  (= 'T', correct)
    word-2:    A <- 0377  (= 0x00FF, corrupt)
- The loaded char value is NOT on CD16 (=050033 for both) and the two visible reads
  (044035, 050033) are IDENTICAL for good and corrupt chars. So A's value at 0172
  arrives via the internal IDB/data-bus register (microcode `IDBS,DBR`) from a char
  source not in the captured set, and it is 0377 for word-2 vs the real code for
  good chars.

Interpretation: the character is one value per output (not the packed 0x5255), so
the print source is a ONE-CHAR-PER-WORD buffer, and word-2's cell(s) hold 0377.
The earlier RAM scan only searched the PACKED `[IN][ST]` form (found 3 correct
copies) - it never scanned for a one-char-per-word buffer. DECISIVE next test: scan
RAM for the one-char-per-word sequence (0111,0116,0123,0124 = I,N,S,T) and read the
word-2 cells; if they hold 0377 the unpack/store that populated the buffer is the
bug (memory-content), if they hold the correct code it is a read/forward bug.

(Consistent with 6i/6n before the DRAM-mux confusion: the char is a buffer read;
0377 is 0x00FF not 0xFFFF, so BUSRD "never all-ones" still holds. The microcode
6o/6q shows no mask, so if the buffer cell is correct the fault is in the datapath
forwarding it to A at 0172; if the cell is 0377 the fault is in the byte-unpack that
wrote the buffer.)

### 6s. DECISIVE: the corrupt 0377 char is NOT stored anywhere in RAM (datapath-generated)

Ran a fast C-side RAM scan (`scanseq` command added to `nd120_probe.cpp`;
`/tmp/claude-1000/fastscan.py`) over RAM 0..06000000 octal (~1.5M words) right
after the corrupt banner prints. Results (25-JUL):

- PACKED `044516,051524,051125` (= `[IN][ST][RU]`, word-2 = `RU`) -> **8 clean
  copies** in RAM. The packed banner is intact, word-2 included.
- ONE-CHAR-PER-WORD `0111,0116,0123,0124` (= I,N,S,T) -> **0 matches**. There is
  NO one-char-per-word print buffer.
- ONE-CHAR-PER-WORD corrupt form `...0377` -> **0 matches**.
- PACKED with word-2 = `000377` -> **0 matches**.
- PACKED with word-2 = `0177777` -> **0 matches**.

VERDICT: the `0xFF`/`0xFFFF` value the print routine emits for word-2 exists
NOWHERE in RAM. The only stored form of the banner is the clean packed string.
Therefore the corruption is **datapath-generated**, not a stored-buffer /
byte-unpack bug. This kills the 6r "one-char-per-word buffer" hypothesis: the
routine unpacks the packed word on the fly, and for the 3rd word (word-2) the
value it obtains internally is `0xFFFF` instead of the clean `0x5255` that the
memory-fetch bus (BUSRD, measured 6i) demonstrably delivered.

So the fault is localized to the CPU's read-word capture/forward on the 3rd
iteration of the print loop. Microcode 0172 = `IDBS,DBR PASSD` forwards the DBR
(Data Bus Register, `CGA_ALU_DBR.v`) onto the IDB; DBR is loaded from CD earlier
when `LDDBRN` is low. Next measurement (`/tmp/claude-1000/dbrload_capture.py`,
new `DBRLOAD` probe group): capture DBR + LDDBRN + CD16 + CSA across each char's
window to find the exact cycle where DBR loads word-2's char as `0xFF` (and what
CD carried at that load) vs a good char.

### 6t. DECISIVE: char read from fixed scratch cell 03075; bug is in char-GENERATION (byte unpack)

Offline mining of the DBRLOAD + SRCADDR CSVs (no new sim), aligning a GOOD char
('T'=0124) window against the CORRUPT char (0377) window by CSA (25-JUL):

- The two windows are **byte-identical in CSA sequence AND addresses** up to the
  divergence. First divergence at CSA=00000: good `MEMRD_DATA=000124`, corrupt
  `MEMRD_DATA=000377`. The char value enters on the **memory data-output bus**,
  then flows DBR<-char -> A(RA)<-char at CSA 0172 -> UART. (This RECONCILES the old
  "BUSRD clean" claim: that scan looked for 0xFFFF and correctly never found it -
  the corrupt value is 0377 = 0x00FF, a one-BYTE read, which the packed-form scan
  also missed.)
- The char-source READ address is **03075 (octal) for EVERY char** - I, N, S, T,
  R, U, C, T, I, O, N all read 03075 exactly 4 ticks before the char data appears.
  Rock-solid across 11 chars with identical timing => 03075 is the true address,
  NOT a DRAM-mux artifact, and it is a **fixed per-char SCRATCH CELL** (the routine
  writes the current char there, then reads it back to output). Read side is
  perfect: 03075->0111(I), ->0116(N), ->0123(S), ->0124(T), ->**0377**(R!),
  ->**0377**(U!), ->0103(C)...
- Therefore the corruption is entirely in **what gets WRITTEN to 03075**: for the
  two word-index-2 chars (R,U = string index 4,5 = packed word `[RU]`=0x5255) the
  value computed and stored is 0377 (0x00FF) instead of 0122/0125.

Since (6i) the packed word-2 `0x5255` is delivered cleanly by memory and (6s) the
packed banner in RAM is clean, the fault is the **byte-unpack / datapath that turns
packed word-2 into its two output bytes**: it yields 0xFF,0xFF. Either the packed
word lands in the unpack register as 0xFFFF (datapath capture bug on word-2) or the
byte-extract op (CGA_ALU_SWAP / mask) mis-produces 0xFF for word-index-2. This is
the memory-reference / datapath class bug. NEXT capture: trace the packed-word read
(MEMRD_DATA==051125) -> destination register -> byte extract -> store to 03075,
comparing word-2 (051125) vs word-0 (044516).

## 7. Why this test, not MEMORY

- MEMORY (D04) runs enormous loops and is very slow; poor for iteration.
- INSTRUCTION (C03) is fast, prints every instruction, completes, and already
  isolates a specific failure (page-fault level-14). It is the right harness for
  CPU-instruction/interrupt debugging from the floppy-booted monitor.
```

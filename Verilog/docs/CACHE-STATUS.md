# The ND-120 cache: what is actually known

**Measured 28-AUG-2026 on the Nexys 4 DDR**, by building with `-tclargs cache`
and running the machine's own diagnostic — `CACHE-120-A00` under the TPE
monitor, from the SINTRAN disc image. Before this the cache was described only
as "the never-validated subsystem". It is now characterised, and the answer is
specific.

## It builds, fits and boots

| | |
|---|---|
| Synthesis / place / route | passes, `WNS +0.166 ns` |
| SINTRAN III | **boots normally** |
| TPE hardware investigation | `Cache: Yes`, `NO ERRORS DETECTED` |

The concern recorded in `fpga/nexys4ddr/build.tcl` — that `MMU/CACHE/CHIP_21F`
falls back to LUTRAM on this part and might not fit or close — did not
materialise. It cost about 0.1 ns of margin against the same build with the
cache compiled out.

So `ND120_NO_CACHE` being the default is **no longer justified by "it might not
build"**. It is justified by what follows.

## It does not work, and the failure is precise

`CACHE-120-A00:NEXT`, run under TPE:

| Test | Result |
|---|---|
| 1. Control Store verification (upper 1k) | fails — **unrelated**, see below |
| 2. Basic functions | **fails** |
| 3. Inhibit limits | fails |
| 4. Enable/Inhibit pages | fails |
| 5. Cache "Used bit memory" | **fails** |
| 6. Cache "Data memory" | **PASSES** |

Test 6 passing matters: the cache **data RAMs are fine**. What is broken is the
bookkeeping around them.

Test 5, which is the sharpest evidence:

```
Cache memory   Used bit
  Address    Expected Found  Cache in use
   0000B         1      0    Data Cache
   0001B         1      0    Data Cache
   ...
```

The used bit never sets. Test 2 then reports exactly what follows from that:

```
CUP does not work (Bit 0 in Cache Status)
DATA is NOT COPIED to DATA CACHE when READING from memory
DATA is taken FROM MEMORY when present in DATA CACHE
INSTRUCTION is NOT COPIED to INSTRUCTION CACHE when READING from memory
MIXED UP ADDRESSING between DATA CACHE and INSTRUCTION CACHE
```

Nothing is ever written into the cache, so nothing is ever read from it.

## Why the operator panel's CACHE HIT RATE reads zero

It is correct. From `CPU_MMU_CACHE_25.v`:

```verilog
assign s_hit = !s_used_n & !s_hit_1_0_n[0] & !s_hit_1_0_n[1] & !s_cwr;
```

`HIT` **requires the used bit**. The used bit never sets, so `HIT` can never
assert, so the hit rate is genuinely 0% - not a measurement fault. The panel and
the machine's own diagnostic agree.

## What has been ruled out

Both of the obvious "the cache is switched off" explanations are wrong:

- **`CON` (the SW1 cache on/off switch).** `ND120_CORE.v:1184` ties
  `SW1_CONSOLE` to `s_high`, so `CON` is high - the ON position. Were it low,
  `CPU_MMU_HIT_27.v:74` would force `HIT0_n` high and no hit could ever be
  reported, which would look identical. It is not that.
- **`PD2`.** It gates the used-bit PAL's output enable *and* the cache RAMs'
  chip selects. `ND3202D.v:603` ties it to 0, so the PAL drives and the RAMs are
  selected. It is not that either.

## The fault, found 28-AUG-2026

`CUP` never asserts, and the reason is one character in a Verilog file.

The original PALASM, `DesignDocuments/PAL-Code/SRC/44511A.txt`:

```
IF (VCC) CWR  = MREQ * WCA + CWR * /CLK      <- '='  combinational
        /CUP := /CWR * MREQ + /CUP * /MREQ   <- ':=' registered
```

In PALASM `=` declares a combinational output and `:=` a registered one. On a
PAL16R4 only Q0-Q3 carry flip-flops; `CWR` is pin B0, which has none. Our
`PAL_44511A.v` evaluated it inside the clocked `always` block anyway, so `CWR`
only moved on a clock edge.

`/CUP := /CWR * MREQ` needs both terms in the **same** cycle. With `CWR` one
edge late, `MREQ` has already gone, so `CUP` never asserted at all. Every line
of the diagnostic above follows from that: no `CUP`, so the used-bit PAL never
writes, so `CHIP_21F` stays zero, so `HIT` - which requires `!s_used_n` - can
never fire. Test 6 passing fits exactly: the data RAMs were always fine, and
the bookkeeping around them never ran.

**The deviation was already known.** `PAL/sim/PAL_44511A_EN_tb.v` documented it
as "DEVIATION 1", pinned it with a check named
`CWR_IS_CLOCKED_NOT_COMBINATIONAL_DEVIATION`, and even stated the consequence -
*"a mid-cycle MREQ \* WCA does not reach the pin"*. It was recorded as an
accepted difference and the algebra was called equivalent. It was not
equivalent, and that sentence was the bug description all along.

Fixed in `PAL_44511A.v` and `PAL_44511A_EN.v` (commit `e178f04`): combinational
set term, hold term qualified by `/CLK` so it dies at the start of the next
cycle. Modelled in FF mode (`USE_LATCHES=0`, the path the FPGA builds); the
residual difference from the level-sensitive original is written out in both
files. The testbench expectations were re-derived from the listing rather than
from either RTL (commit `5cec840`) - 9244 checks, 0 failures, full PAL suite
green.

**Not yet measured on hardware.** Whether this makes `CACHE-120-A00` pass is an
open question until the build with the fix is flashed and the diagnostic re-run.
Nothing in this section claims the cache works.

Two things this does not explain and which stay open:

- the earlier `CON` and `PD2` checks above ruled those out, and they stay
  ruled out - this is a third, separate cause;
- `PAL/sim` has a provenance gate that reports "22 PALs agree with their
  listing on every output", and it passed throughout. It did not catch this,
  so whatever it compares does not include combinational-vs-registered intent.
  Worth understanding before trusting it on another PAL.

Second, unrelated finding: **test 1, control-store verification of the upper
1k, fails** with `Found 140000B, Expected 000000B` across `017000B`-`017004B`.
That is the WCS, not the cache, and this build carries `SKIP_WCS_LOAD`. Worth
checking on its own terms rather than assuming it is a cache symptom.

## Recommendation

Leave `ND120_NO_CACHE` as the default. Not because the cache might not build -
it does - but because it is now *known* to be functionally incorrect, and a
cache that silently never hits is a worse configuration than no cache at all.
Change the default when `CUP` is fixed and `CACHE-120-A00` passes.

## 28-AUG-2026, later - the CWR fix did NOT fix it, and the trail moved

Flashed the CWR fix (WNS +0.075 ns, cache enabled) and re-ran the diagnostic
from the floppy: `1560&` -> TPE -> `LOAD-PROGRAM CACHE-1X0-A00:TEST`.

**Test 2 still fails identically** - `CUP does not work (Bit 0 in Cache
Status)`, `DATA is NOT COPIED to DATA CACHE`. So the PALASM deviation was real
and worth fixing, but it was not the cause. Said plainly because the earlier
section of this document was written as though it would be.

Two things now known that were not before:

1. **The config probe and the functional test disagree.** `CACHE-1X0-A00`
   prints `Cache updated bit.........: Working` at load time, on the very same
   bitstream where test 2 reports CUP dead. Whatever the load-time probe reads,
   it is not what test 2 exercises. Do not trust that line as evidence.

2. **The machine points at the inhibit logic.** `PRINT-NOTE 6`, the
   diagnostic's own note for this error:

   > The fault may come from the inhibit logic, and in such a case many other
   > troubles will occur as many test sequences disable the whole cache by
   > setting the lower and upper inhibit registers to 0:37777 [...] Test
   > section 3 must be able to find if the fault comes from the inhibit logic
   > or from the status register itself.

   Test 3 then reports `Cache not updated (Use of limit registers)` for three
   limit/page combinations.

**The chain, traced through the RTL** (all verified by reading, none assumed):

```
inhibit-bit RAM CHIP_20G  ->  WCINH_n   (CPU_MMU_PT_29.v:155)
  -> s_ewc_n = ~(s_brk_n & s_con & s_wcinh_n)   (CPU_MMU_CACHE_25.v:178)
  -> PAL_44402D_EN: WCA_n = ~((RT_n & DT & EWC & CYD & FMISS_n & LSHADOW_n)|..)
  -> PAL_44511A_EN: CWR = MREQ * WCA
  -> /CUP := /CWR * MREQ                          -> Cache Status bit 0
```

Ruled out along the way, so nobody re-checks them: `PD1` is tied 0
(`ND3202D.v:602`) so the 44511A output enable is not gating CUP; the
`assign s_wca_n = 1'b1` tie-off in `CPU_MMU_CACHE_25.v:210` is inside
`ifdef ND120_NO_CACHE` and does not apply to a cache build; and CUP genuinely
comes from the `PAL_44511A_EN` instance `PAL_44511_ULEV0`
(`CPU_PROC_CMDDEC_34.v:130`), which is the one that was fixed.

**The current suspect, NOT yet proven.** The inhibit bit is stored per page in
`IMS1403_25 CHIP_20G`, addressed by

```verilog
assign s_ims_ppn_25_10_in = s_ppn_25_10_in | s_ppn_25_10_out;
// maybe do a conditional expression here to select which PPN to write to RAM chip 20G
```

`CPU_MMU_PT_29.v:71`. The comment is the original author's own doubt. ORing the
incoming and outgoing PPN yields neither address once both are non-zero, so a
write could land on one page and the read-back come from another - which is
exactly "cache not updated (use of limit registers)". It is a hypothesis with a
motive, not a measurement.

**Next step, and do it in this order.** `CPU_MMU_PT_29` has three testbenches
(`_tb`, `_replay_tb`, `_shadow_rmw_tb`) and NONE of them checks WCINH_n - each
mentions it twice, both times a port connection. None appears in
`tests/run_all_tests.sh`. Write the missing unit test first: set the inhibit
bit for page X, read it back for page X and for page Y, with both PPN busses
non-zero. If the OR is wrong the test says so, and only then change the RTL.
Changing that line on the strength of a comment would be guessing at the CPU.

## Correction, same evening - the inhibit-RAM lead is NOT the fault

I wrote the section above pointing at `CPU_MMU_PT_29.v:71` and its ORed PPN
address. Reading **sheet 29 of the 3202D schematic** (page 29 of
`DesignDocuments/CPU-BOARD-3202/3202-REV-D-OCT-87-600DPI-ocr.pdf`) kills that
lead, and it should be killed loudly because it was recorded as promising.

The sheet shows **one** bidirectional bus, `PPN(25:10)`, feeding the IMS1403's
address pins (PPN10-PPN23) and its data pin (PPN25). There are not two busses.
So the OR is a **wired-OR model of a tri-state bus** - the standard trick - and
it is correct provided the non-driver contributes 0. It does:

```verilog
// CPU_15.v:406
assign s_lapa_ppn_25_10[15:0] = s_lapa_n ? 16'b0 : {2'b0, s_la_23_10[13:0]};
```

The CPU side is all zeroes whenever `LAPA_n` is high. The mixture my testbench
forces - both sides non-zero at once - is therefore probably unreachable in the
real design, which is exactly the caveat that bench was committed with.

A second theory died on the way as well: `{2'b0, ...}` looked like it hardwired
PPN25 (the inhibit RAM's data bit) to 0, which would have meant the inhibit bit
could never be set to 1. It does not - `CPU_MMU_PPNX_28` drives PPN25-PPN18
from the IDB (chips 10B/9B/8B on that sheet). That is how the bit gets written.

**Where that leaves the cache.** CUP is still dead and the cause is still not
found. What is now excluded, with evidence rather than by inspection: CON, PD2,
PD1, the `ND120_NO_CACHE` WCA tie-off, the 44511A CWR timing, and the PPN
addressing into the inhibit RAM. What has NOT been examined: `CON` and `BRK_n`
as they actually behave at run time in `s_ewc_n = ~(s_brk_n & s_con &
s_wcinh_n)`, and whether the limit registers are ever successfully WRITTEN -
`WCLIM_n` itself has never been observed. The next measurement should be
whether `WCLIM_n` ever goes low on hardware, because everything downstream is
moot if the limit RAM is never written.


---

## 28-AUG-2026, late evening: the full test-2 output, on hardware

Everything above worked from one line of the diagnostic, "CUP does not work".
The whole of test 2 says considerably more. Captured from the board over the
115200 console after flashing the `vgaconsole cache` build:

```
   2. Basic functions

*** ERROR *** In test  2.
CUP does not work (Bit 0 in Cache Status) (See note 6).
DATA is taken FROM MEMORY when present in DATA CACHE (See note 1).
  >Paging: Off  Addressing: Physical
DATA is taken FROM MEMORY when present in DATA CACHE (See note 1).
  >Paging: On , Addressing: Through normal page table
DATA is NOT COPIED to DATA CACHE when READING from memory (See note 1).
INSTRUCTION is taken FROM MEMORY when present in INSTRUCTION CACHE (See note 1).
INSTRUCTION is NOT COPIED to INSTRUCTION CACHE when READING from memory (See note 1).
MIXED UP ADDRESSING between DATA CACHE and INSTRUCTION CACHE (See note 21).
```

Read that as a whole rather than line by line. The cache is **inert in both
directions, in both halves, paged and unpaged**: nothing is ever written into
it, and nothing is ever read out of it. CUP being dead is not a separate fault
to chase - it is what a never-written cache looks like from the status register.

Note 21 ("Data Cache and Instruction Cache were written with two different data
... when using Data Cache, the data from Instruction Cache is found") is most
likely a CONSEQUENCE, not a second fault. If both caches are dead, both reads
fall through to main memory and return whichever of the two patterns was
written there last - which the test cannot distinguish from a cross-wired
address. Stated as the reading it is, not as a measurement.

### What that rules in

A cache write is `PAL_44402D` asserting WCA. From the PALASM
(`DesignDocuments/PAL-Code/SRC/44402D.txt`):

```
IF (VCC) WCA = /RT * DT * EWC * CYD * /FMISS * /LSHADOW    ; WRITE OUTSIDE SHADOW
              + RT * /IHIT * EWC * CYD * /FMISS * /LSHADOW ; FETCH/READ WITHOUT HIT
```

Both terms need `EWC` and `CYD` high and `FMISS` and `LSHADOW` low.

**Checked and cleared tonight, against the listing rather than by inspection:**

- `PAL_44402D_EN.v` is transcribed correctly. Both product terms match term for
  term, and so does the registered/combinational split: `WCA` and `USED` are
  `=` (combinational, pins 18 and 19), only `IHIT`, `NUBI` and `NUBD` are `:=`
  (pins 14-17, the four flip-flops a PAL16R4 actually has). This is the exact
  axis on which `PAL_44511A` was wrong, so it was worth checking here first.
- `CON` is not the blocker. With the cache enabled `s_con = SW1_CONSOLE`, and
  `ND120_CORE.v:1184` ties `SW1_CONSOLE` high.
- The cache RAMs really are present in this build. The block that omits them
  sits inside `ifdef ND120_NO_CACHE`, and `cache` was passed, so the `else`
  branch with the five real memories is what got built. (Worth stating because
  the omission block reads alarmingly like the bug when skimmed.)

**That leaves exactly five candidates:** `WCINH_n`, `BRK_n`, `CYD`, `FMISS`,
`LSHADOW`. None of them is tied off anywhere in the hierarchy - checked - so
reading the source cannot choose between them. It has to be measured running.

### Standing suspect, NOT verified

`FMISS`. It is Q0 of flip-flop `A160` in `DECODE_DGA_COMM.v`, and its D input
comes back through `A177 = NAND(LCS_n, MREQ, FMISS)` - a self-hold. Once FMISS
sets it stays set for as long as MREQ is asserted. The PAL's own revision note
says why that would be fatal here:

```
;D 030987 JLB: ... WCA SHOULD NOT APPEAR WHEN FMISS (TSET FAILS).
```

A stuck FMISS blocks both WCA terms and produces precisely the symptom
measured. This is a suspicion with a mechanism, not a finding.

### The measurement now armed

`DBG_CACHE` carries all six signals from `CPU_MMU_24` up through `CPU_15`,
`ND3202D` and `ND120_CORE` to `s_ila_cache` at the top, on the ILA:

```
[0] LSHADOW  [1] FMISS  [2] CYD  [3] BRK_n  [4] WCINH_n  [5] WCA_n
```

Build it with `-tclargs vgaconsole cache ila` and capture while CACHE-1X0-A00
test 2 runs. If WCA_n never falls, the other five bits name the term holding it
off, and the guessing stops.

This supersedes the earlier "next measurement should be whether `WCLIM_n` ever
goes low". WCLIM_n is downstream of the same question and narrower; if nothing
is ever written to the cache at all, the limit registers are not where to start.


---

## 29-AUG-2026, 00:40: MEASURED. FMISS is innocent; WCINH_n is the story

ILA capture on the running board (`-tclargs ilacache`, `ila_cache_run.tcl`),
armed on WCA_n going low, while CACHE-1X0-A00 was loaded and test 2 ran.
1024 samples. Bits: `[0]LSHADOW [1]FMISS [2]CYD [3]BRK_n [4]WCINH_n [5]WCA_n`.

| hex  | WCA_n | WCINH_n | BRK_n | CYD | FMISS | LSHADOW | samples |
|------|-------|---------|-------|-----|-------|---------|---------|
| `2c` | 1     | **0**   | 1     | 1   | 0     | 0       | 514     |
| `28` | 1     | **0**   | 1     | 0   | 0     | 0       | 400     |
| `38` | 1     | 1       | 1     | 0   | 0     | 0       | 63      |
| `1c` | **0** | 1       | 1     | 1   | 0     | 0       | 24      |
| `3c` | 1     | 1       | 1     | 1   | 0     | 0       | 16      |
| `30` | 1     | 1       | 0     | 0   | 0     | 0       | 4       |
| `34` | 1     | 1       | 0     | 1   | 0     | 0       | 3       |

**Three things this settles.**

1. **WCA_n DOES go low.** The `1c` rows are real cache writes. The earlier
   working theory - "WCA never asserts, nothing is ever written" - is WRONG as
   an absolute. The cache is written, just very rarely.
2. **FMISS is innocent.** It is 0 in every one of the 1024 samples. It was the
   standing suspect on the strength of its self-hold through `A177` and the
   PAL's own "WCA SHOULD NOT APPEAR WHEN FMISS" note. The mechanism was real
   and the suspicion was still wrong. LSHADOW is likewise 0 throughout, and
   BRK_n is high in all but 7 samples.
3. **WCINH_n is low - the cache INHIBITED - in 914 of 1024 samples, 89%.**
   Every sample where WCA fires has WCINH_n high. The pattern is consistent
   and simple: when the page is not inhibited and CYD is high, the cache is
   written; the reason it almost never happens is that almost every access is
   marked inhibited.

That puts the fault back exactly where the diagnostic's own PRINT-NOTE 6 put
it - the inhibit logic - and it was previously written off in this document as
"excluded with evidence". That exclusion was wrong. What had been checked was
the PPN ADDRESSING into the inhibit RAM, which is a different question from
whether the RAM holds the right BITS.

**Honest limits of this capture.** 1024 samples is one window around one WCA
event, not the whole of test 2, and the trigger could have fired at any point
while the machine was running rather than inside the test proper. The 89%
figure is "89% of this window", not a duty cycle over the test. What the window
does establish beyond doubt: WCA can fire, FMISS is not blocking it, and
WCINH_n is low the overwhelming majority of the time.

**Next.** Find out why the inhibit bit reads set for nearly every page. Two
candidates worth separating before anything else: whether the inhibit RAM is
ever correctly WRITTEN (it has no reset - `IMS1403_25.v` says Vivado would not
take one - so an untouched cell is whatever the block RAM powers up as), and
whether the CPU ever clears it for normal pages. A capture triggered on
WCLIM_n, the inhibit-RAM write strobe, answers the first directly.


---

## 29-AUG-2026, afternoon: the inhibit map is written CORRECTLY - measured in Verilator

Everything above was measured on the board through a 6-8 bit ILA window.
This section is measured in Verilator (`runSim`, floppy-core build,
`USE_LATCHES=0` - the FPGA's flip-flop mode) with a run-time probe on the
inhibit RAM's own write strobe, address and data input
(`ND120_WCLIM_TRACE=1` in `runSim/Run120.cpp`), which also counts the 16384
map bits after every write burst.

**What the microcode does with the map.** Scanning `AM27256_4513{2,3}L.hex`
(64-bit microwords, PROM word k*4+q = bits 16q+15..16q, confirmed against the
C# loader) finds exactly three microwords carrying the WCHIM command
(COMM field bits 36:32 = 021 with MIS bits 43:42 = 00): **01071, 02046 and
03713**.

1. **Power-up sweep, microwords 02045/02046.** Right after the control store
   finishes loading (LCS falls at cnt 557168) the microcode loops 02045 ->
   02046 16384 times, one page per 11 sim cycles. Every write is
   `page = IDB[13:0]` counting 0..037777 and `data = IDB[15] = 0`. Map after:
   **16384 pages = 0 = INHIBITED, 0 enabled.** That is the reset state of the
   cache on this CPU: everything inhibited until the limits are set.
2. **`TRR LCIL` / `TRR UCIL` each re-sweep the whole map through microword
   01071** (16385 writes per TRR). A 5-word OPCOM-deposited program
   (`LDA; TRR LCIL; LDA; TRR UCIL; ...`, encodings checked with nd100-dis)
   gave:
   - limits `0 : 037777` -> map after: 0 enabled, 16384 inhibited;
   - limits `000100 : 000200` -> map after: **16319 enabled, 65 inhibited** -
     exactly pages 100..200 octal.

So address, data bit, transceiver steering (PAL 44306A: EIPU = EIPL = WCHIM),
the `WCLIM_n = WCHIM_n | EORF_n` gate and the IMS1403 model all do the right
thing, in FF mode, on the same RTL the board runs.

**What this does to the board reading above.** WCINH_n low in ~90% of samples,
and 69 writes in a window, is what an all-inhibited map or a `0:37777` sweep
looks like. The diagnostic's own PRINT-NOTE 6 says many of its sequences set
exactly that. The board capture therefore does not localise a fault; the
`CPU_MMU_PT_29.v:71` OR and "the write is misaddressed" theories are closed.

**Two probe traps found on the way, recorded so they are not repeated:**

- The probe block in `runSim/Run120.cpp` runs once per sysclk period, always
  with `top->sysclk == 1`. A probe gated on `top->sysclk == 0` never fires and
  reads as "the strobe never happens" - that false reading cost most of an
  afternoon before `ND120_CYC_WINDOW` showed WCLIM_n low at cycle state d.
- Verilator folds plain alias wires (`assign s_wchim_n = WCHIM_n`) even under
  `--public-flat-rw`, and `--public-flat-rw` itself makes the whole sim ~4x
  slower. The names that survive a normal build are in the probes.

**Open:** whether CACHE-1X0-A00 test 2 passes in the sim. The program loads
and prints its config (`Cache: Yes`, `Cache updated bit: Working`), `RUN 2`
asks `Initialize memory : >`, the program does not echo, and the memory init
of the 6 MB sim RAM is slow. That run is the next step in
`PLAN-cache-and-panel.md`.


---

## 29-AUG-2026, evening: FAULT 1 FOUND AND FIXED - the CUP PAL forgot every cache write

**CACHE-1X0-A00 test 2 reproduces in Verilator** (FF mode, 64K-word sim RAM,
`runSim` floppy-core build): the same eight lines as the board, `CUP does not
work` first. That made it traceable, and `ND120_CACHE_TRACE` (every transition
of WCA, CWR, CWR_hold and CUP_n with MREQ/CYD/hits) showed it on the very first
cache write of the boot:

```
[cache] cnt=24688707 csa=00000 wca=1 cwr=1 hold=0 cup_n=1 | mreq=1 cyd=1 ...
[cache] cnt=24688711 csa=00000 wca=0 cwr=0 hold=0 cup_n=1 | mreq=1 cyd=0 ...
```

WCA and CWR were up for four sysclk, `CWR_hold` never set, `CUP_n` never
cleared. **Why:** in `PAL_44511A_EN.v` the hold term was a flop loaded only on
the CLK rise (`if (EN) CWR_hold <= MREQ & WCA`), so the only WCA it could
remember was one still present AT the rise. WCA lives in cycle state d (PAL
44402D: `... * CYD * ...`) and CLK rises at TERM, four states later
(`ND120_CYC_WINDOW` dump: d -> 0110 -> 0111 -> 0101 -> 0100/TERM). By the rise,
WCA and CWR were gone, and `/CUP := /CWR * MREQ` sampled a dead CWR. The
file's own comment had called this a "residual deviation" and said the set
term was all CUP needed; it was not - the set term is over long before CUP
samples.

**Fix (`PAL_44511A_EN.v`, `PAL_44511A.v`):** model the listing's
`CWR = MREQ*WCA + CWR*/CLK` as the level latch it is - set on MREQ*WCA, held
while CLK is low, dead once CLK is high. FF mode samples it every sysclk
(not gated by EN); latch mode is an `always @(*)` set-dominant latch. At the
EN sample CLK is still low (CLK_EN is the cycle before the rise, CYC_36.v), so
CUP now sees the held CWR. The golden testbench `PAL_44511A_EN_tb.v` was
re-derived for the latch (a clock edge with unchanged inputs no longer changes
CWR); 9244 checks pass, the EN-vs-original equivalence bench passes (9216),
the whole `PAL/sim make test-all` is green including the 22-PAL provenance
gate.

**Measured effect:** with the fix, test 2 no longer reports `CUP does not
work`, and the probe counts real cache traffic during the test (WCA high in
259515 evals vs 4 before). CUP was the first fault, not the only one.

## FAULT 2 - open: hits do not return cache data, reads do not fill it

Test 2 with the CUP fix in:

```
DATA is taken FROM MEMORY when present in DATA CACHE        (paging off, physical)
DATA is taken FROM MEMORY when present in DATA CACHE        (paging on, normal PT)
DATA is NOT COPIED to DATA CACHE when READING from memory
INSTRUCTION is taken FROM MEMORY when present in INSTRUCTION CACHE
INSTRUCTION is NOT COPIED to INSTRUCTION CACHE when READING from memory
MIXED UP ADDRESSING between DATA CACHE and INSTRUCTION CACHE
==TPE42=> UNEXPECTED INTERNAL INTERRUPT  level 2, code 4 (Illegal instruction)
          Address 177006B  Instruction 162000B
```

The crash is new and is itself a clue: the run without the fix ended cleanly
("- End of test -"); with cache writes and CUP alive the CPU executes a wrong
word. That is what a hit returning the wrong data, or a write landing on the
wrong line, looks like. `ND120_CACHE_WIN` in `runSim/Run120.cpp` dumps, from
the n-th WCA on, the cache address, the PPN on the bus, the tag and data the
cache RAMs read back, the used bits, both HIT comparators and the CD bus into
the MMU and the CPU, per eval - the capture to read next.

Two things in the RTL worth holding in mind while reading it (not measured
yet, listed so they are not rediscovered): the TMM2018D model reads
SYNCHRONOUSLY (`data_out_reg` one sysclk after the address), and
`CPU_MMU_CACHE_25.v` gates the cache's CD output with HIT
(`CD_15_0_OUT = s_hit ? ... : 0`, a 26-JUL banner fix) - so a HIT that arrives
a cycle late, or a HIT decided on a stale tag, returns memory data instead of
cache data and looks exactly like "DATA is taken FROM MEMORY".

**Board confirmation (29-AUG-2026, 16:34).** The CUP fix was copied into the
build worktree (`E:\Dev\Repos\Ronny\nd-120-build`, detached at `268c61d`),
built for the Nexys 4 DDR (`build.tcl -tclargs clk=16`, cache + VGA console +
panel clock are the defaults there now; WNS +0.112 ns, TNS 0), programmed over
JTAG, and CACHE-1X0-A00 test 2 was run on the board
(`fpga/nexys4ddr/boardtests/cache_test2_cupfix.log` in that worktree). The
board prints exactly what Verilator prints with the fix: `CUP does not work`
is gone, the six DATA/INSTRUCTION lines remain, and it ends in the same
`UNEXPECTED INTERNAL INTERRUPT ... Illegal instruction, address 177006B,
instruction 162000B`. Board and sim now agree line for line on fault 2.

**Fault 2, first capture (`ND120_CACHE_WIN`, sim, with the CUP fix).** In
the 1500 evals after the test's first cache write: the write itself looks
right (line `ca=2001`, tag 60 = PPN 60, data 146542 = the memory word, used
bit set, CUP set). Every later access in the window is a miss with the tag
RAMs reading back 0 - those are pages 0 and 1 (the program), which the test
keeps inhibited, so no fill is expected there. Two timing facts stand out:

- the TMM2018D model reads SYNCHRONOUSLY: the tag comes out one sysclk after
  CA changes. In FF mode one cycle-controller state is one sysclk, and the
  HIT-terminate terms of PAL 44601 sit at states b and c (`... * HIT * ...`),
  so HIT is decided a state too late to end the cycle early, but early enough
  to suppress the memory request at state d (DGA A233/A239: no ECRQ when
  HIT). A cycle that neither ends on the hit nor fetches from memory is what
  the crash looks like. The real TMM2018 is a 25 ns async SRAM, and the
  model already carries a faithful switch: `-DTMM_ASYNC_READ`.
- CA10 (instruction/data half) is a DGA flop with an ASYNC reset on
  WRITE & UCLK (A237), so it falls to 0 mid-cycle at state c on data writes.
  That is the gate array's own structure, not a transcription slip; noted
  because it makes the first tag lookup of such a cycle use the other half.

Experiment running: the same test with `-DTMM_ASYNC_READ`.

**Async cache RAM read - measured (29-AUG-2026 evening).** Test 2 rerun in the
sim with `-DTMM_ASYNC_READ`: the illegal-instruction trap is GONE (clean
`- End of test -`); the six DATA/INSTRUCTION lines stay. So the crash was the
tag arriving a state late, and the six lines are something else. Made
permanent as a per-instance parameter: `TMM2018D_25 #(.ASYNC_READ(1))` on
the four cache chips only (`CPU_MMU_CACHE_25.v`), distributed RAM on the FPGA,
page-table chips unchanged. Cache module gates green (`test-mmucache` 3 x
1637 checks, `test-mmucache-dma` 2 x PASS, `test-mmucache-nocache` 197).

## FAULT 2, mechanism seen: a DATA write is cached in the INSTRUCTION half

`ND120_CACHE_PPN=60` (one line per cycle end on the test's own page, plus
every WCA) on the async build, test 2:

```
[cpg] cnt=743160426 WCA  csa=16000 ca=2000 ppn=00060 ...            <- the test's data write, CA10 = 1
[cpg] cnt=743160439 TERM csa=00675 ca=0000 ppn=00060 tag=000060 dat=150010 ...   <- RAM output still showing line 2000
[cpg] cnt=743160442 TERM csa=00326 ca=0000 ppn=00060 tag=000000 ...   <- line 0000 (data half) is EMPTY
... every later data read at ca=0000: tag=000000, hit0n=1 -> miss -> memory
... instruction fetches at ca=2000/2001: tag=000060, used=1, hit0n=0, ihit=1 -> hit
```

The write landed on line 2000 (CA10 = 1, the instruction half) although it
was a data write; data reads of the same word look in line 0000 and miss.
That is the diagnostic's "DATA is taken FROM MEMORY when present in DATA
CACHE", "NOT COPIED", and "MIXED UP ADDRESSING between DATA CACHE and
INSTRUCTION CACHE" in one mechanism.

Why CA10 is still 1: CA10 is a DGA flop (DECODE_DGA_COMM MEMORY_63) loaded
on the CLK rise and cleared ASYNCHRONOUSLY by A237 = WRITE & UCLK. PAL
44307C makes UCLK high in cycle state c only (`/UCLK = CC3 + CC2 + /CC1 +
/CC0 + TERM`), so on the real board CA10 falls in state c, before WCA writes
the RAMs in state d. In the FF model the [cwin] dump shows CA10 still 1 at
the WCA rise of a write cycle. Whether UCLK (`uclk_pa`, the registered
"next level") or WRITE (A160 Q3) is the late one is the capture being taken
now (`ND120_CWIN_PPN=60 ND120_CWIN_WRITE=1`, prints ca10q / ca10rst / uclk /
write per eval).

## Test 1 (upper 1K of the control store) - the pattern Ronny pointed at

Board, no-abort run (`nd-120-build/.../cache_run1_noabort.log`): every
failing 16-bit group reads back `expected OR 0xE700` - bits 8, 9, 10, 13, 14,
15 stuck high - in groups 0, 1 and 3, never group 2. NOTE 10: the upper 1K
(16000B-17777B) is the microinstruction cache store, read and written as
four 16-bit groups; NOTE 12: the address test writes each group with its own
address plus the group number in bits 14-15.

Sim, same test: ALSO fails, but with `expected OR 0x8000` (bit 15 only) in
groups 0 and 1, STATIC section clean. Same shape (an OR), different mask -
the board has more of it.

The RTL shape that fits an OR: `CPU_CS_WCS_21_22.v:104` merges the lower and
the upper bank with `lower | upper`, and `IDT6168A_20.v` gates each chip's
output with a REGISTERED copy of CE_n (`regCE_n`), so a deselected bank keeps
driving its last word for one more sysclk. A read-back captured in that
cycle is the upper word OR'd with the lower bank's last word. NOT proven:
the `ND120_WCS_TRACE` probe (prints at the TCV capture edge) saw both bank
outputs and the captured word as ZERO on every one of 3000 upper-1K reads
while the CPU nevertheless read the right low bits - so the value the test
sees does NOT come through `TCV.r_cs_capture` the way I assumed, and the
read path for the upper 1K has to be traced properly before touching it.

**Board, second build (29-AUG-2026 19:24, `cache_test2_asyncactlv.log` in
the build worktree):** CUP fix + async cache RAM read + ACTLV panel row.
WNS +0.231 ns, TNS 0; +1014 LUTs (+961 LUT-as-memory, the four cache chips
as distributed RAM), -2 BRAM tiles. Console up. Test 2: the illegal-
instruction trap is gone on the board too - `- End of test -`,
`Test finished`, back at `TPE>`. The six DATA/INSTRUCTION lines remain,
identical to the sim. Board and sim still agree line for line.

## 29-AUG-2026, night: a dropped used-bit write, fixed - but test 2 STILL fails

Captured with `ND120_CACHE_WIN=1:60 ND120_CWIN_PPN=60 ND120_CWIN_WRITE=1`
(the test's first data WRITE on its own page), per eval:

```
cnt=744420294 CC=0010 ca=0000 ppn=00060 wca=1 write=1 ca10q=0 | sweep=1 nubi_reg=1 nubd_reg=0 used_mem=0 cclr_n=1
cnt=744420295 ...                                                  sweep=1 ...                     used_mem=0
cnt=744420298 CC=0101 ca=0000 ... wca=0                            sweep=1 ...                     used_mem=0
```

The write goes to the right half (`ca=0000`, CA10 = 0 - the CA10 theory
above is dead: the DGA clears it in time), the tag and data RAMs take it,
the used-bit PAL presents "data used = 1" (`nubd_reg=0` -> pin NUBD = 1) -
and `Am9150 CHIP_21F` is in its clear SWEEP (`sweep=1`): the 24-AUG model
cleared the array with a 1024-step write sweep after every cache clear and
DROPPED every external write while it ran ("only a spurious later miss",
said its comment). The diagnostic issues a cache clear and writes its test
word a few hundred clocks later; the line ends up tag-valid, data-valid,
used = 0, and never hits: "DATA is taken FROM MEMORY when present in DATA
CACHE", "NOT COPIED", and "MIXED UP ADDRESSING" (the instruction half's
fetch fills, which happen later, do get their used bit). The real Am9150
resets its whole array "in two cycle times" (datasheet).

**Fix (`Shared/support/Am9150.v`):** one valid flip-flop per location
(1024 FFs); /R low clears them all in one clock; a write sets its location's
valid bit with the data; a never-written location reads 0. Nothing is
swept, nothing is dropped, power-up is clean without a sweep. The chip's
testbench `Shared/support/sim/Am9150_tb.v` now pins "a write right after
power-up is KEPT" (29 checks pass); the cache module gates are green
(`test-mmucache` 3 x 1637, `test-mmucache-dma` 2 x PASS,
`test-mmucache-nocache` 197), `test-am9150-clk` passes.

**Verified 29-AUG-2026 23:00: NOT ENOUGH.** CACHE-1X0-A00 test 2 in Verilator
with the Am9150 fix prints the same six lines. The dropped write was real
and the fix stands (the model was wrong), but the diagnostic's read of the
written word still does not come from the cache. Next capture: the per-cycle
page-60 log with the fix in, to see whether the read now HITS (used=1,
hit0n=hit1n=0) and, if it does, why the CPU still gets the memory word.

## 29-AUG-2026, 22:00: with the fix in, the DATA half's used bit still ends up 0

Per-cycle page-60 log (`ND120_CACHE_PPN=60`, run 16, Verilator, Am9150 fix
in). Read in order, the test's own accesses to its line at CA 0 / CA 2000
(same used-bit index, CA[9:0] = 0; the two halves are CA10):

```
cnt=743595936 WCA  csa=00000 ca=0000 ... cd=177777        <- the test's data write, cached
cnt=743968922 TERM csa=00170 ca=0000 tag=000060 dat=177777 used=0 hit0n=0 hit1n=0 ihit=0 cd_cpu=140000
cnt=760061681 WCA  csa=00675 ca=2000 ... 
cnt=760061698 WCA  csa=00145 ca=2001 ...
cnt=760449640 TERM csa=00000 ca=2000 tag=000060 dat=171000 used=0 ihit=0 cd_cpu=136000   <- memory word
cnt=760449657 TERM csa=00145 ca=2001 tag=000060 dat=146542 used=1 ihit=1 cd_cpu=146542   <- cache word: a HIT
```

So: the tag and data RAMs hold the written word (`tag=60`, `dat=` the word
written), both tag comparators match (`hit0n=hit1n=0`), and the line still
misses because its used bit reads 0 - while the neighbouring line at CA 2001,
written a few clocks later by a fetch fill, has its bit (`used=1`, bit 0 =
instruction half per `PAL_44402D`: NUBD_n is bit 1, NUBI_n bit 0) and HITS,
returning the cache word. Nothing between those two writes and reads cleared
the chip (index 1 survived, so no CCLR). Same six test-2 lines on the Nexys
with this fix (build 3, 21:58), so it is not a model-only effect.

The `used` column above is the chip's registered `data4bit` copy - one clock
stale, and the address moves at TERM - so it cannot say WHAT was written.
Run 17 (started 22:07) prints, for every clock of the WCA pulse, the RAM's
real contents at the index (`umem`/`uval`), the PAL's data into it (`din`),
and the PAL inputs that make that data: `pd2` (the PAL's output enable - our
model drives 0 = "not used" on both bits while it is high; the tag RAMs share
it as chip select), `dt_n`, `rt_n`, the NUBI/NUBD registers, `we_n`, `cclr_n`.
The suspect that fits everything seen so far: the used-bit RAM (chip select
tied low) keeps writing on every clock of the WCA pulse after PD2 has already
deselected the PAL and the tag RAMs, and the last clock writes zeros. To be
read from the log, not assumed.

Six wires in `CPU_MMU_CACHE_25.v` carry a `/* verilator public_flat_rd */`
mark now so the probe can see them (Verilator had folded them away); that is
a simulator annotation, not a logic change.

## 29-AUG-2026, 22:45: run 17 - the used bit IS written now; the READ still misses

Every clock of the test's data write (run 17, extended `[cpg]` fields):

```
cnt=743433851 WCA  ca=0000 din=2 pd2=0 dt_n=0 rt_n=1 nubd_reg=0 we_n=0   umem=1 uval=0   <- pulse starts
cnt=743433852 wca- ca=0000 din=2 ...                          we_n=0   umem=2 uval=1   <- written: data-used, valid
cnt=743433854 wca- ...                                        we_n=0   umem=2 uval=1
```

PD2 stays low for the whole pulse, the PAL presents "data used" (`din=2`,
bit 1 = NUBD pin), the RAM takes it and keeps it. The PD2-during-the-pulse
suspect from 22:00 is dead. Then the test's read of that word:

```
cnt=743806838 TERM csa=00170 ca=0000 tag=000060 dat=177777 hit0n=0 hit1n=0 dt_n=0 rt_n=0
              umem=2 uval=1 pd2=0 we_n=1 cclr_n=1 ihit=0 cd_cpu=140000
```

Tags match on both comparators, the used-bit RAM holds "data used" and it is
valid, RT and DT are both asserted (a data read), PD2 low, no write, no clear
- every input of `s_hit = !used_n & !hit0n & !hit1n & !cwr` is right at TERM
- and the CPU gets `140000`, the memory word (the cache holds `177777`, the
word it wrote). `IHIT` never registered the hit. So the hit is either decided
too late for the cycle FSM (`PAL_44601B` terminates on HIT only in states b
and c, `0001`/`0011`) or blocked by CWR during those states. Run 18 (started
22:50, `ND120_CACHE_PPN_DT=1`) prints every clock of every data cycle on the
page: FSM state, `s_hit`, both comparators, OUBI/OUBD, RT/DT, CWR and its
hold, BRK, WCA, the CD bus - to see the clock at which HIT should have been
high and which input was not.

## 29-AUG-2026, 23:30: FAULT 2 FOUND - the CWR pin's polarity blocked every hit

Run 18 (`ND120_CACHE_PPN_DT=1`, every clock of every data cycle on page 60).
The test's read of the word it wrote, clock by clock (`csa=00170`, CA 0):

```
cnt=744315547 CC=0 hit=0 h0n=0 h1n=0 oubd=1 rt_n=0 dt_n=0 cwr=0 brk_n=1 we_n=1 pd2=0   umem=2 uval=1 tag=000060 dat=177777
cnt=744315548 CC=1 hit=0 ...                                                              <- state b: HIT would terminate here
cnt=744315549 CC=3 hit=0 ... ihit=1                                                       <- state c: the PAL's IHIT DID register the hit
cnt=744315550 CC=2 hit=0 ... cyd=1                                                        <- no early terminate: full memory cycle
...
cnt=744315562 CC=5 hit=0 ... cd_cpu=000000                                                <- memory word delivered
```

Every input of sheet 25's HIT is true on every clock - both comparators
match, the used bit reads 1, RT and DT, no write, PD2 low, BRK high - and
`s_hit` is 0 throughout. `s_hit = !used_n & !hit0n & !hit1n & !s_cwr`, so
the term that kills it is `s_cwr`, the PAL 44511A's pin 19.

**The hardware, read off the drawings (not the Logisim copy):**
- Sheet 25: HIT is the output of a 74S260 5-input NOR (21H). Inputs, read
  off a 12x crop of the 600 dpi scan: pin 1 `USED~`, pins 2/3 `HIT~1`/`HIT~0`,
  pin 12 the net `CWR`, pin 13 ground. HIT is high only when all five are LOW.
- Sheet 34: net `CWR` is pin 19 of the 44511A (26H), wired straight to the
  connector. No inverter.
- Listing `DesignDocuments/PAL-Code/SRC/44511A.txt`: pin 19 is declared
  `/CWR`, `IF (VCC) CWR = MREQ * WCA + CWR * /CLK ; SET ON WRITE TO CACHE`.

So the board can only hit on a read if pin 19 is LOW on a read and HIGH
across a cache write: the pin FOLLOWS the CWR expression. Our model drove
`~CWR` (the convention the 44402D's `/USED` and `/WCA` pins use, correctly),
which made HIT possible only WHILE the cache was being written - never on a
read. Every read ran the full memory cycle and took the memory word: "DATA
is taken FROM MEMORY when present in DATA CACHE" and the rest. The listing's
`/CWR` and the schematic's `CWR` (no ~, where every other active-low net on
those sheets has one) disagree about this net; the measurement decides.

**Fix:** `PAL/PAL_44511A_EN.v` and `PAL/PAL_44511A.v`: `assign CWR_n = OE_n ?
1'b0 : CWR;` with the chain above in a comment. `PAL/sim/PAL_44511A_EN_tb.v`
re-derived for the pin (9244 checks PASS); `test-44511a-en` PASS;
`test-mmucache` 3 x 1637, `test-mmucache-dma`, `test-mmucache-nocache` PASS.
Sim run 19 (test 2) and Nexys build 4 are running with it.

Why fault 1 (CUP) and this one could hide each other: CUP uses the PAL's
INTERNAL CWR and was wrong for a different reason (the hold latch); the pin
polarity only matters to the HIT gate. Fixing CUP made test 2 stop saying
"CUP does not work" and left the six hit/fill lines, which is exactly what
was seen.

## 29-AUG-2026, 23:55: CONFIRMED ON THE BOARD - test 2 passes on the Nexys

Build 4 (build 3 + the pin-19 fix; WNS +0.162 ns, TNS 0; LUTs 18852, FFs
13684, unchanged within 2). CACHE-1X0-A00 `RUN 2`, verbatim:

```
   2. Basic functions                        - End of test -
Test finished. Time: 1979.01.01 00:00:36
```

No error block. Builds 1-3 printed the six DATA/INSTRUCTION lines and MIXED
UP ADDRESSING here every time. Both cache faults are now fixed and
board-confirmed:

| Fault | Where | What |
|---|---|---|
| 1 | `PAL_44511A(_EN).v` CWR hold | CWR was registered / never held, so CUP never set ("CUP does not work") |
| 2 | `PAL_44511A(_EN).v` pin 19 | pin driven as `~CWR`; sheet 25's NOR needs it LOW on a read, so HIT never fired |

Also real and kept, found on the way: the Am9150 used-bit model dropped
writes during its clear sweep (fixed, per-location valid bit); the cache
tag/data RAMs read synchronously and tripped an illegal-instruction trap
(fixed, async LUT-RAM read). Test 1 (upper 1K of the control store) is
unchanged and still open - see the section above and the plan.

## 30-AUG-2026, 00:20: test 2 passes in Verilator too; TEST 1 IS STILL A CACHE FAILURE

Sim run 19 (test 2 with the pin-19 fix): `2. Basic functions - End of test -`,
no error block - same as the board. But CACHE-1X0-A00 is NOT clean: test 1
("Control Store verification (Upper 1k)" - the microinstruction cache store,
NOTE 10) still fails on the board (build 4) with found = expected OR `163400`
on bits 48:63 at every address (017000B..). The program as a whole still
reports errors; saying "the cache is fixed" on test 2 alone was wrong.

Test 1 measurement in progress: sim run 20 with `ND120_WCS_RD=1`, a
per-clock log of every RWCS microinstruction (cycle state, ELOW/EUPP, LUA and
UUA addresses, BOTH banks' outputs - the WCS output is their wired-OR and the
IDT6168A model deselects one sysclk late - and the TCV capture). The OR-ed
constant is the same at every address, so it is a stale bank output or a
stale register, not data.

**00:18, board, whole program.** `RUN 1-8` and `RUN 2-8` with "never abort":
CACHE-1X0-A00 has only tests 1 and 2. Test 2 clean. Test 1 aborts on its
first block, and this time the STATIC test comes first:

```
017000B   0D:15D  163400B  000000B
017000B  16D:31D  163400B  000000B     (same for 017001B..017004B)
```

So the SAME 16-bit constant `163400` is OR-ed into groups 0, 1 and 3 alike.
That rules out the WCS bank wired-OR as the source (a stale 64-bit word would
give a different constant per group): the OR happens on the 16-bit side,
after the TCV's group select - on the IDB, where every driver is OR-ed. Run
21 (`ND120_WCS_RD=1`, extended) prints every IDB driver (CS, MMU, PROC,
board, BIF, MEM, IO reg/uart/panel) per clock of every RWCS microinstruction
next to the TCV capture, to name the driver that is on when it should not be.
In Verilator the constant was `100000` (bit 15 only) on the earlier run - a
different driver value, same mechanism, if this reading is right.

**01:10, sim run 20 (test 1):** in Verilator the read-back is expected OR
`100000` (bit 15 only) - `017000B 0D:15D found 117000B expected 017000B`,
`16D:31D found 157000B expected 057000B` - where the board ORs `163400`.
Same shape (one constant on every group), different value, so the mechanism
is a driver whose stale value differs between the two. The run's per-clock
log hit its print cap inside the write sweep (1024 words x 4 groups, ~70k
lines) before the first read; run 22 has the cap at 400k and every IDB
driver in the line. The Nexys ILA build (build 5) targets the same moment.

## 30-AUG-2026, 01:10: TEST 1 ROOT CAUSE - the DGA's combinational EPANS bypass

**Measured on the board (build 4, test 1 without abort, 20062 error lines):**
found XOR expected is not one constant. Over the run it is `020400`,
`120400`, `160400`, `163400`, `142400`, `100400`, `042400`, `140400`,
`102400`, `122400`, `040400` - bit 8 always set, bits 11 and 12 never, bits
9, 10, 13, 14, 15 varying. On sheet 40 the panel's 74LS244 (33B) drives
`{PRES, FUL~, READ, VAL}` on IDB 15:12 and the 68705 status on 11:8. That
is the panel status word, changing as the panel processor runs. In
Verilator, whose panel is a stub, the constant is `100000` = PRES alone.
The 74LS244 is enabled by EPANS.

**Why EPANS is on during a control-store read:** `DECODE_DGA_IDBS.v` had a
COMBINATIONAL decode of the live CSIDBS field for o20 (MIPANS) - a "latency
bypass" added in our RTL, not in the gate array (every IDBS enable in the
DGA is an F924 flop; A259 Q0 is EPANSN). During an RWCS read the control
store outputs the DATA WORD being read from EWCA to ECSL (and the word
being written during WCSTB); test 1 writes each word's own address into it,
`017000B` has bits 41:37 = o20, so while it is read back the bypass decodes
MIPANS, the panel driver goes onto the IDB, and its word is OR-ed with the
TCV's. Every address whose bits 41:37 hit any decode is exposed the same
way (o21 panel, o37 UART, o35 RINR, o26 ALD ...). The real DGA cannot do
this: its flops sample at CLK edges, when the store shows the next
microinstruction, never a data word.

**Fix:** `DECODE_DGA_IDBS.v` - EPANSN = A259.Q0 (registered), the bypass
behind `-DND120_EPANS_COMB_BYPASS` (off). This moves the RTL TOWARD the
gate array, not away from it.

**Regression checks added:** `DECODE_DGA_IDBS_tb.v` layer F walks every
IDBS code through CSIDBS with NO clock edge (the RWCS read-back window) and
requires all ten enables to hold; the model has EPANSN registered
(49638 / 49494 checks PASS, both build modes). With the bypass switched
back on the tb FAILS (proven). `DECODE_DGA_tb.v` (top level) re-derived the
same way (PASS, both modes).

**Open (01:35):** in Verilator the build with the registered EPANSN boots to
the OPCOM `#` prompt and then the harness never types (no `[stdin] sent`
lines even with a byte pushed into the fifo; gdb shows the main loop
running normally in `eval_step`). Whether that is the harness's stdin gate
or the CPU no longer polling the console is NOT known. The old bypass
comment claims a registered o20 window "kills OPCOM console input" - which
would be the WCS 1-sysclk read latency putting the registered decode one
microinstruction late. Ronny asked for the board instead: build 6 (build 4
+ this change) is being flashed; step 1 there is "does OPCOM echo".

## 30-AUG-2026, 02:10: build 6 verdict, and the final shape of the fix

**Build 6 (registered EPANSN, the pin-exact gate array): OPCOM console DEAD
on the Nexys** - no `#`, no echo, three attempts (agent log
`cache_build6.log`, 01:52). Same symptom as Verilator. With our 1-sysclk
control-store read latency the registered window lands one microinstruction
late; the bypass was written for exactly this. Build 3 was programmed back
at 01:56 to give the board a console (build 4's bitstream had not been
kept).

**The fix as it now stands** (`DECODE_DGA_IDBS.v` + `DECODE_DGA.v`, nothing
outside the DGA): the combinational MIPANS window stays - OPCOM needs it -
but it is shut for the whole of any RWCS microinstruction, using the DGA's
OWN RWCS decode (the COMM sheet's `XRWN` net, wired into the IDBS sheet as
`RWCSN`). During RWCS the control store carries data words and the RWCS
microword's own IDBS field is 0, so nothing legitimate is lost - the same
reasoning as the LCS_n term that was already in the bypass. The pin-exact
registered variant stays behind `-DND120_EPANS_REGISTERED` (console dead,
measured twice). No board-level plumbing: the DGA already generates RWCS.

**Checks:** `DECODE_DGA_IDBS_tb.v` re-based on the committed comb model +
`RWCSN`: layer F drives RWCSN low and walks every code through CSIDBS with
no clock - all ten enables must hold (and o20 with RWCSN high must still
assert, F_comb_alive). 49639/49495 checks PASS both modes; with the gate
removed from the RTL the bench FAILS (proven). `DECODE_DGA_tb.v` restored
to its committed form - it passes unchanged, its COMM holds XRWN high.
`CPU_MMU_CACHE_DMA_tb.v` has PAL 44511A in the loop for fault 2 (44 checks
both modes; FAILS against the inverted pin, proven). Running: sim run 26
(test 1) and Nexys build 7.

**Found on the way, NOT mine, NOT fixed:** `make test` has been broken at
its FIRST target since 28-AUG - `tests/tb_catalog.py` (commit `4249fd0`)
has two unterminated string literals (lines 50, 59; I closed them, 2
insertions). With the registry runnable again, `test-iodcd38-latch` FAILS
against the COMMITTED tree too - `CCLR_n`, `CA10`, `PA_7_0` "never went
high" - so it came in with the DGA panel-path commits (`1a8c0e1`/`d80ef7f`)
and nobody could see it. Needs its own session; the tb hint says "missing
or wrong DGA pin".

## 30-AUG-2026, 03:00 - run 25's [wcs] probe: the sim group-mixing, measured

Run 25 (OLD binary, no RWCS gate, probe build) reached test 1's readback of
words 017000B-017003B. What the trace SHOWS (facts, /tmp/nd_out25.log in WSL):

- **The ascending write pass is CORRECT.** Writing all four slices of word
  017002B back-to-back (values 017002, 057002, 117002, 157002) leaves lane 0
  (up15_0) = 017002 and lane 3 (up63_48) = 157002 - verified on the RAM
  outputs at cnt=779829004 and cnt=797403299.
- **A later per-slice sweep pass corrupts it.** That pass writes slice 0 of
  every word, then slice 1 of every word, etc. (~2.4M cycles between visits
  to the same word). After it, lane 0 of word 017002B = 117002 (slice 2's
  value) - seen at cnt=799782772 BEFORE the slice-2 sweep had reached the
  word, so the corruption came from the slice-0 or slice-1 sweep itself.
- **Readback returns only +100000-family values.** rf=0 -> 117002, rf=1 ->
  157002, rf=2 -> 117002, rf=3 -> 157002. The values 017002 and 057002 never
  appear on any probed output after the sweep passes.
- **rf = ~cswan, bitwise, on every line** (cswan=11 -> rf=0, 10 -> 1,
  01 -> 2, 00 -> 3), and ew_n tracks rf correctly (rf=0 -> ew_n=e enables
  lane 0). So the write-lane decode follows rf, and in the back-to-back pass
  that lands the right lane.

**RESOLVED, same tick (03:20): there is no group-mixing fault.** Every
corrupted lane value in the trace is exactly the written value OR 100000 -
lane 0: 017002 -> 117002, lanes 1/3: 057002 -> 157002 - and on the very
write lines that corrupted them, `io_pan=100000` was live (`board=100000
io_pan=100000`). Run 25 is the OLD binary: the EPANS data-window leak was
enabling the panel status driver DURING the sweep pass's writes, and on the
wired-OR IDB the store then captured data|panel_word. The ascending pass
wrote clean because the panel driver happened to be off on those lines
(`io_pan=000000`). One fault, not two; the RWCS gate fixes the writes and
the reads alike. Confirmed twice: build 7 on the Nexys ran test 1 with 0
error lines (was 20062), and run 26 (the gated binary in Verilator) is
running test 1 with 0 errors where run 25 erred immediately.
rf = ~cswan is simply how the design counts - not a bug.

## 30-AUG-2026, 04:35 - sim verdicts: test 1 CLEAN, test 3 PASSES in Verilator

Run 26 (the RWCS-gated binary, FLOPPY1.IMG, /tmp/nd_out26.log in WSL):
- **Test 1 (Control Store upper 1K): "- End of test -", zero ERROR lines.**
  Sim now agrees with the board (build 7: 0 error lines, was 20062).
- **Test 3 (Inhibit limits): "- End of test -" in sim** (typed into the live
  console by /tmp/nd_run26_t3.sh after test 1 finished). On the Nexys the
  same test hangs ("hanging on level: 0D - P=124563B", builds 4 and 7
  identically). So the test-3 fault is BOARD-SPECIFIC - present at 45.45 MHz
  on silicon, absent in Verilator - which points at timing/CDC/memory-speed
  territory, not core RTL logic. That changes the investigation: ILA on the
  board, or a slower-clock build, beats more sim tracing.

Also: the full unit registry is green end-to-end for the first time since
28-AUG - **ALL 342 TESTS PASSED** (2604 s, /tmp/make_test_30aug_3.log).
The three blockers cleared tonight, in order: tb_catalog.py syntax error
(committed 4249fd0, fixed), test-iodcd38-latch (stale tb - liveness names
off by two AND reliance on the pre-1a8c0e1 FIFO over-write; tb fixed, RTL
proven correct), and the sd-fat-test fat16.img/payload.bin stale pair
(image from the 00:42 stand-in experiment vs payload from 09:46 - both
regenerated together, test-verilator PASS standalone).

## 30-AUG-2026, 06:25 - build 8 on the board: everything but test 3

Build 8 (= build 7's cache/DGA set + MIPS counter + the VT100 terminal
rewrite, commits 1c02698 + 191bdee + e26f44b) closed timing at WNS +0.211 ns
(TNS 0; the VT100 cursor paths took three attempts: -0.328/11 endpoints ->
-0.001/1 -> clean after RTC's two-phase apply), flashed 06:21, and the full
CACHE-1X0-A00 RUN 1-8 ran over the console: tests 1,2,4-8 "- End of test -"
with 0 error lines in the whole run; test 3 the identical board-specific
hang (P=124563B). Utilization vs build 7: +702 LUTs, +542 regs, +2.5 BRAM.
Log: nd-120-build worktree, fpga/nexys4ddr/cache_run1to8_build8.log.

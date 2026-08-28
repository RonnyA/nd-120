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

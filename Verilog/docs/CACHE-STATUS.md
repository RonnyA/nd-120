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

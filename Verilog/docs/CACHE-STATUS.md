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

## Where the fault is likely to be

`CUP` - Cache UPdate - is an **output of `CPU_PROC_32`**, i.e. it comes from the
microcode/decode path, and an input to `CPU_MMU_24`. The diagnostic's very first
complaint is `CUP does not work (Bit 0 in Cache Status)`, read back through the
Cache Status Register (`CPU_MMU_CSR_26.v:42`, `idb = {1'b1, ~CON, CON, CUP}`).

If `CUP` never asserts, the used-bit PAL `PAL_44402D_EN` never writes a new used
bit, `CHIP_21F` stays zero, and every symptom above follows from that one cause.

**Next step for anyone picking this up:** determine whether `CUP` ever asserts.
It is not currently observable at the top level; `DBG_PANEL` has one spare bit
(`[7]`) if a probe is wanted, which is how `LAPA_n` was brought out for the
panel's hit-rate denominator.

Second, unrelated finding: **test 1, control-store verification of the upper
1k, fails** with `Found 140000B, Expected 000000B` across `017000B`-`017004B`.
That is the WCS, not the cache, and this build carries `SKIP_WCS_LOAD`. Worth
checking on its own terms rather than assuming it is a cache symptom.

## Recommendation

Leave `ND120_NO_CACHE` as the default. Not because the cache might not build -
it does - but because it is now *known* to be functionally incorrect, and a
cache that silently never hits is a worse configuration than no cache at all.
Change the default when `CUP` is fixed and `CACHE-120-A00` passes.

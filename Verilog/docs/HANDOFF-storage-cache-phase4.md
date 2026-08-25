# HANDOFF — storage Phase 4: the region became a block CACHE

Status: **14 of 14 storage testbenches green.** Nothing flashed to silicon yet.
No commits made.

Date: 04-AUG-2026, updated 05-AUG-2026

---

## 1. Why this work exists

A real ND Winchester image (`WD0.IMG`, e.g. 78,643,200 bytes) could not be
served at all. Symptom on the Tang, from DISC-TEMA:

```
***ERROR*** DISC-74MB-1 Unit 0
            Hardware Status: 060010b
            Controller finished
            Controller not active after activate
            Operation was: Read
```

...and every word read back as `00000000`.

**The Winchester controller was innocent.** Decoding status `060010b` against
`ND-BUS-DEVICES/WINCHESTER/circuit/ND_WINCHESTER.v` (the `s_status` assembly):

| bit | value | meaning |
|-----|-------|---------|
| b14 | 1 | on cylinder |
| b13 | 1 | card identity (3041) |
| b3  | 1 | `s_rft` — finished |
| b2  | 0 | `s_active` — not active |
| b11..b4 | 0 | no error bits at all |

The card did the operation, got nothing, finished cleanly. The fault was in the
storage backend.

### Root cause

`nd_storage` v1 mapped an image block straight onto a region block, in one line
of `SD-FAT/circuit/nd_storage_engine.v`:

```verilog
s_blk_abs <= s_slot_base_g[10:0] + s_op_block[s_grant][10:0];
```

That makes the region a **copy** of the image, so an image could never exceed
its slot, and `SD-FAT/circuit/nd_storage_mount.v` enforced it:

```verilog
if (found_size > s_slot_bytes) ... M_FAIL
```

Client 6 (`WD0.IMG`) had a 128-block slot = **262,144 bytes** against a
**78,643,200 byte** image. The mount failed, every block request answered with
the zero-fill error path, and the guest saw exactly the symptom above.

The region cannot simply be enlarged: it is capped at 2048 blocks (4 MB)
because `s_blk_abs` is `[10:0]` and feeds `mem_addr = {blk_abs, word}`, which
reaches into `ND120_CORE.v`, `ND3202D`, `MEM_43` and the SDRAM bridge.

### The design (owner's instruction, 04-AUG)

> "no fucking image should be preloaded ... its read cache (pr unit/device), a
> dynamic cache with write through, caches the most used blocks and evicts the
> not so often"
>
> "we do not cache floppy or tape ... the sd card is quick enough, its the smd
> and wd that needs caching so the SINTRAN OS can run quick"
>
> "we should be able to enable/disable caching pr device class"

Chosen organisation (owner picked from options): **one SHARED pool over all
cached clients**, 4-way set-associative, true LRU, write-through. Shared rather
than per-unit so the disc doing the work gets the whole pool and an idle second
unit costs nothing.

---

## 2. What is implemented

### New file

`SD-FAT/circuit/nd_storage_cache.v` — the tag/LRU directory.

- `set = client_block[SETIDX-1:0]`, `tag = {client[2:0], client_block[15:SETIDX]}`
- `region block = POOL_BASE_BLK + set*WAYS + way`
- The client id is **inside the tag**, so unit 0 block 5 and unit 1 block 5
  cannot alias.
- All WAYS tags of a set live in ONE word → one registered read, all ways
  compare in the same cycle, no multi-port RAM.
- Tags: BSRAM-shaped (registered read, **never reset**). Valid bits and LRU
  ranks: flip-flops, because they need a defined value out of reset.
- Reset kicks off a **walking clear** (one set/cycle). Do not replace it with a
  `for` loop over the arrays — see pitfalls below.
- Interface: `lookup_req/done/hit/way/line`, `alloc_req/done`, `inval_req/done`.
  One outstanding lookup; the engine serialises anyway.

### Changed files

| file | change |
|------|--------|
| `SD-FAT/circuit/nd_storage_engine.v` | `E_GRANT` no longer does the 1:1 map. Cached clients go through `C_LOOK`; a miss runs `C_SEC_GO`/`C_SEC_WAIT` (4 card sectors via `sd_writer` `rd_mode=1`), reuses `W_MEM` to write the line, publishes the tag in `C_ALLOC`, then serves. New ports: `sdw_rd_mode`, `sdw_burst_len`, `sdw_rx_we/addr/data`, `cache_*`. New params `CACHE_MASK`, `STAGE_BASE_BLK`. |
| `SD-FAT/circuit/nd_storage_mount.v` | `PRELOAD_MASK` deleted. `size > slot` refusal deleted. `M_LOAD` (the preload streamer) removed from the path — **left in the file, unreachable**, for one release so the diff stays reviewable. Mount now establishes geometry only. |
| `SD-FAT/circuit/nd_storage.v` | `CACHE_MASK` replaces `PRELOAD_MASK`; cache instantiated; `sd_writer` `burst_len`/`rd_mode` driven by the engine (checker mux preserved); `no_stream=1` on the reader. |
| `SD-FAT/circuit/sd_file_reader.v` | new input `no_stream`: on a directory match, publish `found_*` and end at `H_FINISH` instead of streaming the file. |
| `ND-BUS-DEVICES/TAPE-400/circuit/nd_storage_devices.v` | `CACHE_MASK` (disc classes cached, tape/floppy DIRECT). SMD0 slot remap deleted — slots no longer bound image size, and the remap's overlap hazard went with it. |
| `fpga/tang-nano-20k/nd120_tang20k.gprj`, `SD-FAT/sim/Makefile` | `nd_storage_cache.v` added to the file lists. |

### Behaviour now

- `CACHE_MASK[c]=1` → cached. Image size bounded only by the 16-bit block
  count (128 MB), never by the region.
- `CACHE_MASK[c]=0` → DIRECT: **one shared** staging line at `STAGE_BASE_BLK`,
  every request fetched from the card. Safe because the arbiter grants one
  client at a time and a DIRECT op fetches *and* serves inside its own grant.
- Write-through, write-allocate, card-first/region-second ordering preserved.
- Bytes at or past `size_bytes` read as **zero** (see regression 3 below).
- Enabling the floppy later is one bit in `CACHE_MASK`.

---

## 3. Root causes found along the way (all real, all fixed)

**1. Parking the SD reader mid-transfer corrupts the card.**
Killing `rd_run` the instant `file_found` asserts leaves the card mid-CMD17.
The next card user then fails — the contiguity checker on the same open, or
simply the *next open* when the checker is stripped. v1 never exposed this
because its only early-park path went straight to `M_FAIL` and never touched
the card again. Fix: `no_stream` makes the reader stop at `H_DIR_NX`, which is
entered with the card idle, and the mount waits for `scan_done`.
**Consequence worth keeping in mind: an open is now O(directory), not O(file).**

**2. Staging-line overlap.** The engine allocated a staging line *per client*
(`STAGE_BASE_BLK + s_grant`, blocks 0..7) while `POOL_BASE_BLK = 1`. Every
DIRECT client except client 0 wrote into cache pool lines — silent
cross-corruption. Fixed to one shared line.

**3. Tail zero-padding regression (introduced by this work).** v1 zero-padded
the tail of a file. A fetch pulls whole 2048-byte blocks, so the last block of
a non-multiple-of-2048 file drags in cluster slack. `TAPE.BPUN` (3001 bytes)
started returning junk at byte 3001. Fixed: the engine zero-fills at/past
`size_bytes` during the fill.

**4. Undefined LRU ranks.** Dropping the reset loop to get BSRAM inference left
ranks `x`. Early eviction tests had been passing *by luck*. Fixed by keeping
ranks/valid in reset flip-flops.

---

## 4. Test status

From `SD-FAT/sim` — all green (05-AUG-2026):

| test | result |
|------|--------|
| `test-writer` | PASS |
| `test-writer-div1` | PASS |
| `test-nds-cdc` | PASS |
| `test-nds-engine` | PASS |
| `test-nds-write` | PASS (was the one failure; fixed 05-AUG, section 5) |
| `test-nds-mount` | PASS |
| `test-nds-fatchk-unit` | PASS |
| `test-nds-fatchk` | PASS |
| `test-nds-cache` | PASS (directory in isolation, 23 checks) |
| `test-nds-cachepath` | PASS (new 05-AUG — the cached path end to end) |
| `test-storage` | PASS (Verilator) |
| `test-nds-tape` | PASS |
| `test-nds-floppy` | PASS |
| `test-nds-smd` | PASS |

`test-nds-cache` and `test-nds-cachepath` are both registered in
`tests/run_all_tests.sh`.

### Testbench contract changes (v1 assertions that were inverted, not deleted)

- Region-content checks → **client-port block reads** (`check_blocks()` in
  `nd_storage_tb.v`, and the same in `sim/test_nd_storage.cpp`). Reading the
  region directly is meaningless when nothing is staged.
- "a masked-out client opens with ZERO card traffic" → "a cached client OPENS
  and must go and look".
- "an oversize file fails the open" → "it opens; and a mount must produce ZERO
  mem pulses" — that last one is what actually proves the preload is gone (it
  read 751 before `M_LOAD` came out of the path).
- "concurrent reads produced ZERO SD traffic" → inverted to `!=`.
- engine tb region traffic `8*512` → `8*1024`: a DIRECT op is 512 fill writes
  plus 512 serve reads. A CACHED **hit** is the 512 reads only, with no card
  traffic — that is the win the cache buys.
- `nd_storage_engine_tb.v` gained a **behavioural card responder** on `sdw_*`
  (one sector per `sdw_start`, content keyed on absolute sector) and distinct
  `first_sector` per client, so the cross-client-leak check has teeth.
- `check_sdram_old` in `nd_storage_write_tb.v` was **removed, not repaired**:
  both its premises are gone, and the call site already proves the stronger,
  address-independent invariant (`mem_starts` must not move across a failed
  write).

---

## 5. RESOLVED 05-AUG: `test-nds-write`, and what it was hiding

The failure was in the testbench, not the RTL, exactly as diagnosed:
`nd_storage_write_tb.v` predated the fetch path. It did not connect
`sdw_rd_mode`, `sdw_burst_len`, `sdw_rx_we/addr/data` or the `cache_*` ports,
and its `sd_writer` was hard-wired `.rd_mode (1'b0)`.

Fixed: those ports are wired, and an `nd_storage_cache` instance sits in the
testbench so it sees the same connection `nd_storage.v` makes (both clients
there are DIRECT, so the directory is never consulted — the point is that the
wiring is identical).

Two of its checks had also gone blind and were repaired, not just re-pointed:

- **The mid-write ordering peek** (check b) sampled region block
  `(BASE0+1)*512`. Under Phase 4 a DIRECT write only ever touches the shared
  staging line, so it was peeking at a block the write never writes — it would
  have passed no matter what the engine did. It now peeks at the staging line,
  and the preload was moved there too.
- **The recovery read** (check e) expected an SDRAM preload that no longer
  exists. It now reads back **the block written in check (a)** and requires the
  written words, so it proves engine recovery AND that a write round-trips
  through the card. It also asserts the read costs exactly 4 card sectors.

---

## 5a. NEW 05-AUG: `test-nds-cachepath` — the cached path end to end

`nd_storage_cachepath_tb.v`: engine with `CACHE_MASK` bit 0 set + the real
directory + the real `sd_writer` in `rd_mode` + the card model, at a tiny
2 sets x 2 ways geometry so eviction is reached in four reads. Proves:

- cold fill returns the card's bytes as client words;
- a re-read is a **hit**: zero `sd_writer` starts, zero region writes;
- a cold pool fills both ways before evicting;
- the third distinct tag in a set evicts **the LRU way** — the survivor is
  checked *before* the evicted block is re-read, because re-reading the victim
  first would itself evict the survivor and the check would be meaningless;
- write-allocate: the card holds the written bytes and the next read hits;
- write-through to a resident line returns the **new** data (a stale hit here
  would be the worst failure this cache can have);
- an out-of-range block answers done+err with zero card and zero region
  traffic;
- the DIRECT client never raises a lookup.

**Teeth proven**, not assumed: rebuilding it with `CACHE_MASK = 0` (every
client DIRECT) makes it fail with 6 errors, all of them hit/eviction checks.

---

## 6. Work not started / open

1. ~~Cache-specific stack test~~ **DONE 05-AUG** — section 5a.
2. ~~Sizing synthesis~~ **DONE 05-AUG, and it found a fatal problem.** See
   section 6a. The directory now costs ~700 LUT-class cells + 2 BSRAM.
3. **Contiguity checker for the WD clients — GUARD FIXED 05-AUG, NOT BUILT.**
   The cache computes card sectors as `first_sector + block*4`, which requires
   a contiguous file. `SDFAT_NO_STORAGE_CHECK` was excluded for `TANG_FLOPPY`
   and `TANG_SMD` but **not for `TANG_WD`**, so the Winchester build — random
   access and writeback over a 75 MB image — was mounting with no contiguity
   gate at all. `fpga/tang-nano-20k/src/tang20k_defines.v` now excludes
   `TANG_WD` too. Cost: ~1177 LUT+ALU on a part that was already near its LUT4
   limit. **This has not been synthesised.** If `TANG_WD` no longer fits, slim
   something else — do not drop this gate; the failure mode it prevents is
   silent wrong-sector reads *and writes* on a disc.
4. **`M_LOAD` removal** from `nd_storage_mount.v` — still dead, still there
   (it was deliberately left one release for reviewability). Removing it also
   reclaims its 8x32 FIFO, the 24-bit byte packer and their counters.
   `s_slot_bytes` (line 178) is now unused.
5. **Slot parameters are vestigial** — `SLOTn_SIZE_BLK` no longer bounds
   anything.
6. **Region utilisation.** The pool is `CACHE_SETS * CACHE_WAYS` = 256 x 4 =
   1024 lines at `POOL_BASE_BLK = 1`, with the DIRECT staging line at block 0.
   The region is 2048 blocks, so **1023 blocks (~2 MB) are unused**. A
   power-of-two pool plus one staging line cannot reach 2048; the honest
   options are to accept it, or to use `CACHE_WAYS = 3` with
   `CACHE_SETS = 512` (1536 lines, 3-way LRU — the 2-bit rank field and the
   `WAYW` derivation already handle 3). Measured: 512 sets costs **no more
   logic** than 256, because it all lives in block RAM. Not changed — the
   geometry is Ronny's call.
7. **Nothing is on silicon.** No commits, no flash.

---

## 6a. Sizing synthesis — the measurement that mattered

Run standalone, seconds each:

```
yosys -p "read_verilog nd_storage_cache.v; hierarchy -top nd_storage_cache; \
          synth_gowin -json /dev/null"
```

| version of the directory | result at 512 sets x 4 ways |
|---|---|
| separate `rank_ram`/`valid_ram` FF arrays, read combinationally | **187 283 AND gates** |
| merged into one word, still written inside the async-reset process | **844 694 AND gates** |
| merged, written in its own reset-free process | **~700 LUT-class cells + 2 BSRAM + ~190 FF, 0.8 s** |

Two independent causes, both fatal, both invisible without measuring:

- **An indexed array read combinationally and written by index becomes a
  SETS-deep multiplexer plus a decoder, per bit.** `rank_ram` and `valid_ram`
  were split out of the tag word because the valid bits need a mass clear.
  That decision alone was tens of thousands of LUT4 on a part with 20 736.
- **An array written inside `always @(posedge clk or negedge rst_n)` cannot
  infer block RAM.** The asynchronous reset in the process is enough to stop
  it dead, even when the array itself is never reset — the array came out as
  28 672 flip-flops and their multiplexers. The write must live in its own
  `always @(posedge clk)` with no reset of any kind, fed by a combinational
  write-enable/address/data triple.

The module now has a single `dir_ram` holding
`{ valid(WAYS) | rank(WAYS*2) | tag(WAYS*TAGW) }` per set, one write port, one
registered read, and no reset. Both cache testbenches pass unchanged across
the rewrite. **This is a module-level number: the whole-design Gowin build has
still not been run.**

---

## 7. Pitfalls (things that already cost time)

- **Verilator rejects delayed assignment to an array inside a `for` loop**
  (`BLKLOOPINIT`). Both the cache reset and the invalidate sweep hit it. Use a
  walking clear and a combinationally-built mask.
- **A `for`-loop reset over an array forces flip-flops**, not BSRAM. The first
  version of the directory cost ~26k FF at 512 sets — more than the part has.
- **An async reset anywhere in the process that writes an array also kills
  BSRAM inference**, even if the array is never reset. Section 6a.
- **Never split a directory's valid/rank bits into their own indexed arrays**
  read combinationally. Section 6a.
- **A testbench check can go blind without failing.** Two of
  `nd_storage_write_tb.v`'s checks were still passing while asserting things
  about addresses the design no longer writes. When an architecture changes,
  re-derive what each check is looking at — do not just confirm it is green.
- **`file_found` in `sd_file_reader.v` is a LEVEL, not a pulse.** An
  `if (file_found) ... else if (scan_done)` chain never reaches the second
  branch.
- **`sd_writer.v` is a sector READ/WRITE engine**, not just a writer:
  `rd_mode=1` gives CMD17/CMD18 with an `rx_we/rx_addr/rx_data` sink. No new SD
  protocol logic was needed for the cache fill.
- `burst_len` 0 and 1 are equivalent (`sd_writer` tests `burst_len[8:1] != 0`).
- The mount test image (`SD-FAT/sim/make_storage_image.sh`) contains only
  `TAPE.BPUN`, `FLOPPY1.IMG` and `FRAG.IMG` — there is **no** `SMD0.IMG`, so a
  client-3 open legitimately fails as not-found.

---

## 8. Separate finding, unrelated to the cache

`Verilog/SD-FAT/circuit/sd_file_reader.v` scans the **root directory only** —
there is no code path that descends into a subdirectory (`dclu` is loaded from
`g_rootc` and nowhere else; every target match is guarded `!pattr[4]`).
Card files must be in the root. Name matching **is** case-insensitive
(`ucase()` applied to both sides); the strict part is the **length**, which
must equal `FILEn_LEN`.

---

## 9. How to resume

```
cd Verilog/SD-FAT/sim
make test                    # 10 testbenches, all green
make test-storage test-nds-tape test-nds-floppy test-nds-smd   # 4 more
```

The open items are section 6: the `TANG_WD` contiguity gate has been switched
back on but never synthesised, `M_LOAD` is still dead code, and the pool leaves
~2 MB of the region unused.

Full suite registry: `Verilog/tests/run_all_tests.sh`.

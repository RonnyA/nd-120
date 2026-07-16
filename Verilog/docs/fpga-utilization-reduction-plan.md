# Tang Nano 20K — FPGA utilization reduction plan (BSRAM + LUT)

> **PLAN / ANALYSIS ONLY. No RTL changed, no build run, no bitstream flashed.**
> Written 16-JUL-2026. Every number below is read from an on-disk PnR report or
> from the RTL source (file:line cited). Anything not directly measured is
> labelled **inferred** or **unverified**.
>
> Companion doc (do not duplicate): the WCS repack maths lives in
> `/mnt/e/Dev/Repos/Ronny/nd-120/Verilog/fpga/tang-nano-20k/BSRAM-BUDGET.md`.
> This plan extends it to cover the **storage stack** that was added to the Tang
> build *after* that doc was written, and to answer Ronny's FAT-cache question.

---

## 0. The situation, with measured numbers

Device: **GW2AR-18** (part `GW2AR-LV18QN88C8/I7`), 46 BSRAM18 blocks
(828 Kbit), 10368 CLS, 20736 LUT-equivalent, 15552 logic registers.

Two real PnR reports on disk bracket the problem:

| build | BSRAM | CLS | Logic (LUT/ALU) | SSRAM(RAM16) | Registers | placed? |
|---|---|---|---|---|---|---|
| **10-JUL, no storage stack** (quoted in `BSRAM-BUDGET.md`) | 41/46 = 90% (34 SP + 7 SDPB) | 3842/10368 = 38% | 6157 | 0 | 1872 | yes |
| **14-JUL, WITH storage stack** (`build/.../pnr/nd120_tang20k_build.rpt.txt`, created Tue Jul 14 16:01:48 2026) | **44/46 = 96%** (34 SP + **10** SDPB) | **8553/10368 = 83%** | **10995** (9879 LUT + 1116 ALU) | **264** | 5986 | yes (just) |
| **current, post-RQBIT→V2 fix** (task-reported; gprj modified 15-JUL 23:43, no on-disk report) | **~97%** | **~88% LUT4** | — | — | — | **NO — "Unable to find legal placement"** |

**What changed between the two on-disk reports:** the SD-FAT + TAPE-400 storage
stack was added to the Tang project file list
(`fpga/tang-nano-20k/nd120_tang20k.gprj`). Its cost, measured as the delta:

- **+3 BSRAM blocks** (SDPB 7 → 10; SP unchanged at 34)
- **+4838 LUT/ALU** (6157 → 10995)
- **+264 SSRAM RAM16** (distributed LUT-RAM, was 0)
- **CLS 38% → 83%** (+45 points)

The RQBIT→V2 loop fix then added a little more logic on top of an already-96%/83%
design, tipping placement over the edge. **So the storage stack is the dominant
*new* pressure** — Ronny's instinct that "the SD/FAT stuff is the reason" is
directionally correct. The precise attribution below shows it is the storage
*logic + data buffers* as a whole, not the FAT cache specifically.

BSRAM floor context (from `BSRAM-BUDGET.md`, netlist-traced, not guessed):
- **32 blocks = WCS** (`CPU_CS_WCS_21_22.v`, 32× `IDT6168A_20` = 16 LUA `_C` +
  16 UUA `_D`). 78% of all BSRAM. Main memory is on SDRAM = **0 BSRAM**.
- **9 blocks** = `tmm_`/`am_`/`ims_` MMU/cache arrays (`Shared/support/Am9150*.v`
  and friends) — CPU-correctness, leave alone.
- That is the 41 baseline. Storage added the +3 on top → 44, now ~45.

---

## (a) Ronny's FAT-cache hypothesis — REFUTED as the primary cause, with numbers

> Ronny: *"maybe the caching of the FAT filesystem is the reason; in that case we
> should have a #ifdef to turn off FAT caching."*

I enumerated **every** memory array in the SD-FAT + nd_storage + tape stack that
is compiled into the Tang build (all read directly from source):

| array | file:line | width × depth | bits | role | read port | maps to |
|---|---|---|---|---|---|---|
| `secbuf` | `SD-FAT/circuit/sd_file_reader.v:289` | 512 × 8 | 4 Kbit | reader's **one** working 512-byte SD sector (data *or* dir/FAT sector during a walk) | **sync** (`fsm_q <= secbuf[..]`, :294) | 1 BSRAM **or** SSRAM |
| `s_staging` | `SD-FAT/circuit/nd_storage_engine.v:278` | 512 × 32 | 16 Kbit | engine block **staging** buffer (SD ↔ SDRAM transfer) | **sync** (:293) | **1 BSRAM (SDPB)** |
| `fbuf` | `SD-FAT/circuit/nd_storage_fatchk.v:79` | 512 × 8 | 4 Kbit | **the FAT-sector buffer** — holds ONE FAT sector during the mount-time contiguity check (`s_cur_sec`, :127) | **sync** (`fb_q <= fbuf[..]`, :85) | ≤1 BSRAM / SSRAM |
| `s_blkbuf` | `SD-FAT/circuit/nd_storage_tape_adapter.v:78` | 1024 × 16 | 16 Kbit | tape **1-block data cache** (`s_cur_blk`/`s_have_blk`, :91-92) | **sync** (:155) | **1 BSRAM (SDPB)** |
| `s_fifo` | `SD-FAT/circuit/nd_storage_mount.v:234` | 8 × 32 | 256 bit | mount output byte FIFO | (small) | distributed |
| `s_op_*`, `r_size/r_nblk/r_first` | engine :162-163, mount :198-200 | ≤32 × N_CLIENTS(=7) | tiny | per-client request/geometry regfiles | — | distributed |

**Key findings:**

1. **The only literal FAT cache is `fbuf` (fatchk), and it is at most ONE block
   — and it is ALREADY behind an ifdef.** `fbuf` holds one FAT sector at a time
   for the mount-time contiguity gate. Its instantiation is gated by
   `SDFAT_STORAGE_CHECK` in `nd_storage.v:405` (defined via
   `SDFAT_STORAGE`+`SDFAT_CHECK` in `SD-FAT/circuit/sd_fat_features.vh:67-78`).
   The escape hatch Ronny wants already exists: **`SDFAT_NO_STORAGE_CHECK`**
   (or `SDFAT_NO_CHECK`). At 4 Kbit `fbuf` most likely lands in the 264 SSRAM
   distributed RAM, not BSRAM — so turning it off saves **≈0–1 BSRAM** plus the
   checker FSM's LUTs.

2. **FAT caching is NOT what fills BSRAM. The WCS is (32 of ~45 blocks). The
   whole storage stack is only +3 BSRAM.** Turning off FAT caching alone cannot
   get you under budget — it is roughly a 1-block, 2%-of-device lever.
   **Hypothesis REFUTED as the primary cause.**

3. **What Ronny is *feeling* is real, just mislabelled:** the storage stack as a
   whole (its two big FSMs `sd_file_reader.v` 57 KB and `sd_writer.v` 29 KB, plus
   `s_staging` + `s_blkbuf` = 2 BSRAM, plus 264 SSRAM) is the new pressure that
   pushed CLS 38%→83% and BSRAM 41→44. The blocker is **storage logic + data
   buffers**, not the FAT *cache*.

### The exact ifdef proposal (do this, it's cheap and safe — just don't expect it to fix placement by itself)

- **Knob:** define `SDFAT_NO_STORAGE_CHECK` for the Tang build (add to
  `fpga/tang-nano-20k/src/tang20k_defines.v`, or drop
  `SD-FAT/circuit/nd_storage_fatchk.v` from the gprj — the Gowin flow uses the
  gprj file list, not `-D`, so both are equivalent).
- **What it gates:** the `nd_storage_fatchk` instance (`nd_storage.v:405-444`) —
  removing `fbuf` (the FAT-sector buffer) and the contiguity-checker FSM. With it
  stripped, the mount FSM's `M_CHK` passes straight through.
- **Functional cost:** no mount-time contiguity gate. **Safe here** because the
  card recipe guarantees contiguous files (see `sd_fat_features.vh:70-76` and the
  nd120-storage-phases handoff — BOOT.BPUN is written contiguously). A fragmented
  file would no longer be *rejected* at open; on a correctly-built card there is
  no behavioural change to boot.
- **Estimated saving:** **0–1 BSRAM + a few hundred LUT/CLS.** Real, worth taking,
  but not sufficient on its own.

> A second, *narrower* "no cache" knob is possible if wanted: the tape adapter's
> `s_blkbuf` (`nd_storage_tape_adapter.v:78`) is a genuine 1-block **data** cache
> (1 BSRAM). It could be reduced from a full 1024×16 block to a much smaller
> line, or bypassed to re-read every block. That saves **1 BSRAM** but costs a
> re-read per repeated block access (slower tape re-reads). This is a *data*
> cache, not a FAT cache — see Lever 5.

---

## (b) Ranked reduction levers (savings / risk)

Ranked best-first by (BSRAM saved ÷ risk). "Path" = whether it touches
CPU-correctness logic or only the storage/device path.

### Lever 1 — Repack the WCS UUA bank: **−8 BSRAM** ★ primary
- **Saving:** 16 → 8 blocks. 44 → **36 (~78%)**, or 45 → 37. Definitive BSRAM
  headroom, single biggest lever, **storage-independent** (works with or without
  the SD stack).
- **What / why it's safe-ish:** the UUA (`_D`) half of the WCS only has real
  microcode in words 0..1355; words 1356..4095 are a *computable address ramp +
  one constant bit* (proven bit-exact in `BSRAM-BUDGET.md` Part 1). Repack the 16
  separate 4-bit chips as one 2048×64 sync RAM (8 blocks in 2Kx9 mode) and
  generate the fill for addr ≥ 1356. On Tang this is authoritative because
  `SKIP_WCS_LOAD` is set (`tang20k_defines.v:24`) — the hex images *are* the WCS.
- **Risk:** **MEDIUM–HIGH.** Touches the microcode sequencer. The 1-cycle
  write-first read latency of `IDT6168A_20.v` is load-bearing for correctness
  (WCS→CSBITS→…→LUA feedback loop). Must preserve it exactly. Two open checks
  listed in `BSRAM-BUDGET.md` §"What still needs checking" (post-load writes to
  UUA≥1356; CSBITS field identity).
- **Path:** CPU-correctness (but bit-exact by construction; regression-gated by
  the sim latch/FF golden traces).
- **CLS relief:** ~none. BSRAM only.

### Lever 2 — CPU-boot-only bitstream: drop the whole storage stack: **−3 BSRAM + ~4800 LUT + 264 SSRAM**
- **Saving:** returns to the **measured-placeable** 10-JUL state: 41/46 BSRAM
  (90%), CLS 38%, LUT 6157. This is the *largest combined* (BSRAM + LUT + CLS)
  relief and the only lever proven to place.
- **What:** remove `SD-FAT/circuit/*` + `ND-BUS-DEVICES/TAPE-400/*` from the Tang
  gprj (and `ND_STORAGE_PORT`/tape wiring) for a bring-up bitstream whose goal is
  just to get the **CPU booting on silicon in FF mode**. BOOT.BPUN can still be
  staged into SDRAM via the host/`ND_STORAGE_PORT` deposit path (nd120-storage
  and ndcomm handoffs) without the on-FPGA FAT reader.
- **Risk:** **MEDIUM** functionally (you lose *on-card* SD boot for that
  bitstream), **LOW** technically (it's exactly the config that placed on 14-JUL
  minus storage). Fully reversible; reintroduce storage after Lever 1 buys the
  BSRAM back.
- **Path:** storage-only. Does not touch CPU correctness.

### Lever 3 — Shrink `N_CLIENTS` 7 → 1 (or 2): LUT/register relief, ~0 BSRAM
- **Saving:** the storage facade defaults to `N_CLIENTS=7`
  (`nd_storage.v:47`; engine default 4, `nd_storage_engine.v:59`). The Tang boot
  path uses **one** client (the tape). Dropping to 1–2 shrinks the per-client
  vectors/regfiles and scan logic in the engine + mount (`s_op_*`, `s_pend_*`,
  `r_size/r_nblk/r_first`, the round-robin scanner). Relieves the **CLS/LUT
  congestion** that is the co-blocker, not BSRAM.
- **Risk:** **LOW** — a parameter that already exists; engine header says ≤4 is
  tb-safe (`nd_storage_engine.v:41`). Verify 1 client actually serves the tape
  boot before relying on it (**unverified** that N=1 is exercised).
- **Path:** storage-only.

### Lever 4 — Strip the mount-time FAT contiguity checker (Ronny's ifdef): **0–1 BSRAM + a few hundred LUT**
- Detailed in section (a). `SDFAT_NO_STORAGE_CHECK` → removes `fbuf` + checker.
- **Risk:** **LOW** (card is contiguous). **Path:** storage-only. Take it, but it
  is a top-up, not a fix.

### Lever 5 — Collapse/shrink the two 16 Kbit storage data buffers: **≤1 BSRAM**
- `s_staging` (512×32, engine) and `s_blkbuf` (1024×16, tape adapter) are 1 BSRAM
  each. They live in different modules/clock relationships, so sharing one block
  is non-trivial. Alternatively shrink `s_blkbuf` to a partial line (re-read on
  miss).
- **Risk:** **MEDIUM**, low value (≤1 BSRAM, slower re-reads). Only if desperate.
- **Path:** storage-only.

### Lever 6 — LUT/CLS on the CPU gate-array itself: **do NOT pursue for area**
- The 88% LUT4 / 83% CLS is driven by (i) the storage FSMs (Levers 2–4 address
  this) and (ii) the fixed CPU gate-array combinational logic (CGA_INTR, CGA_ALU,
  MAC, etc.). The CPU logic is correctness-critical and not compressible without
  risking the boot behaviour that is the whole point. **Leave it.** Relieve CLS
  via Levers 2/3/4 instead.

### Levers explicitly rejected (see `BSRAM-BUDGET.md` for the full reasoning)
- **Move the running WCS to SDRAM** — no; pointer-chased dependent load, ~10×
  too slow, adds a third timing regime to the sequencer where the boot bug lives.
- **Load microcode from SD to "save BSRAM"** — does not save BSRAM; changes where
  microcode *comes from*, not where it *lives* (the blocks are the readable
  store). Workflow win only.
- **Narrow `IDT6168A_20` from 4096→2048 deep** — saves *zero*; each 4-bit chip
  still consumes one whole block. The saving only comes from the wide-array
  repack (Lever 1).

---

## (c) Recommended sequence to get under 100% BSRAM with least risk

Pick the branch that matches the immediate goal.

**Branch A — "I need the CPU booting on silicon NOW, storage can wait":**
1. **Lever 2** — build a storage-free bring-up bitstream. This is the *known
   placeable* 41/46 BSRAM / 38% CLS configuration; zero new RTL risk. It unblocks
   the FF-mode CPU-boot work immediately.
2. Later, **Lever 1** (UUA repack) to reclaim 8 BSRAM, *then* reintroduce the
   storage stack on top of the headroom.

**Branch B — "I want to keep SD/tape boot AND fit":**
1. **Lever 1 (mandatory)** — UUA repack, −8 BSRAM → ~36–37/46. This is the only
   lever that gives real BSRAM margin while keeping storage. Gate it with the
   sim latch/FF golden-trace compare (byte-identical) before trusting it.
2. **Lever 3** — `N_CLIENTS`→1/2 to relieve the CLS/LUT congestion that is the
   *other* half of "unable to find legal placement" (BSRAM alone at 78% won't
   help if CLS is still ~85%).
3. **Lever 4** — `SDFAT_NO_STORAGE_CHECK` (Ronny's ifdef) as a safe top-up:
   removes the FAT-sector buffer + checker, a few hundred LUT and ≤1 BSRAM.
4. Only if still tight: **Lever 5**.

**Why this order:** BSRAM and CLS are *both* near the wall (96–97% / 83–88%), and
Gowin's "unable to find legal placement" at those levels is congestion, not a
single-resource overflow. Lever 1 fixes BSRAM decisively; Levers 3/4 fix the CLS
side; neither touches CPU correctness except Lever 1, which is bit-exact and
sim-gated. Branch A is the zero-risk escape hatch if boot bring-up is the real
priority.

---

## References (full paths)

- `/mnt/e/Dev/Repos/Ronny/nd-120/Verilog/fpga/tang-nano-20k/BSRAM-BUDGET.md` — WCS repack maths + Part 2 device-buffer sync-read note (companion doc)
- `/mnt/e/Dev/Repos/Ronny/nd-120/Verilog/fpga/tang-nano-20k/build/nd120_tang20k_build/impl/pnr/nd120_tang20k_build.rpt.txt` — 14-JUL PnR report (44/46 BSRAM, CLS 83%, with storage)
- `/mnt/e/Dev/Repos/Ronny/nd-120/Verilog/fpga/tang-nano-20k/nd120_tang20k.gprj` — Tang source file list (storage stack now included)
- `/mnt/e/Dev/Repos/Ronny/nd-120/Verilog/fpga/tang-nano-20k/src/tang20k_defines.v` — `SKIP_WCS_LOAD`, `MAIN_RAM_SDRAM`, `ND_SDRAM_PACK16`, `ND_STORAGE_PORT`
- `/mnt/e/Dev/Repos/Ronny/nd-120/Verilog/SD-FAT/circuit/sd_fat_features.vh` — `SDFAT_NO_*` feature-strip macros (incl. `SDFAT_NO_STORAGE_CHECK`)
- `/mnt/e/Dev/Repos/Ronny/nd-120/Verilog/SD-FAT/circuit/sd_file_reader.v:289` — `secbuf` 512×8
- `/mnt/e/Dev/Repos/Ronny/nd-120/Verilog/SD-FAT/circuit/nd_storage_engine.v:278` — `s_staging` 512×32; `:59` `N_CLIENTS`
- `/mnt/e/Dev/Repos/Ronny/nd-120/Verilog/SD-FAT/circuit/nd_storage_fatchk.v:79` — `fbuf` 512×8 (the FAT-sector buffer)
- `/mnt/e/Dev/Repos/Ronny/nd-120/Verilog/SD-FAT/circuit/nd_storage_tape_adapter.v:78` — `s_blkbuf` 1024×16 (tape 1-block data cache)
- `/mnt/e/Dev/Repos/Ronny/nd-120/Verilog/SD-FAT/circuit/nd_storage.v:47,167,225,405` — facade: `N_CLIENTS`, reader/writer/fatchk instances + `SDFAT_STORAGE_CHECK` gate
- `/mnt/e/Dev/Repos/Ronny/nd-120/Verilog/CPU-BOARD-3202/circuit/CPU_CS_WCS_21_22.v` — the WCS (32 chips)
- `/mnt/e/Dev/Repos/Ronny/nd-120/Verilog/Shared/support/IDT6168A_20.v` — 4096×4 chip model; read the timing comment before Lever 1

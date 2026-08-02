# PLAN: SD-backed storage for the ND-120 — phases 2..5 (tape → floppy → SMD)

> **Status: PLAN. Phase 1 is DONE+COMMITTED; phases 2..5 are NOT STARTED.**
> Written 14-JUL-2026. Grounded: every claim below carries a file:line or a
> measured number. Where something is **UNVERIFIED** it says so — do not
> promote those to fact without checking.
>
> Companion docs (read them, they are load-bearing):
> - `Verilog/docs/PLAN-nd120-core-extraction.md` — phase 1, the core seam
> - `Verilog/fpga/tang-nano-20k/BSRAM-BUDGET.md` — the BSRAM analysis this plan depends on
> - `Verilog/SD-FAT/HANDOFF-nd-storage.md` — the storage stack's own handoff

## The goal in one paragraph

`ND120_CORE` exposes a storage seam (`TAPE_BYTE_*`, `FDISK_*`/`FDBUF_*`,
`SDISK_*`/`SDBUF_*`). Today that seam is served by **C file-servers** in
`Verilog/simDevices/NDBus.cpp` in sim, and by
**nothing** on Tang. The goal is to serve it from the **real Verilog SD-FAT
stack reading a simulated/real SD card**, in *both* Verilator runSim and on
Tang, so the same devices and the same images are exercised in both places —
`BOOT.BPUN`, `FLOPPY1.IMG`, `SMD0.IMG`.

---

## Decisions taken (Ronny, 14-JUL-2026) — do not re-litigate

1. **`SD_STORAGE=1` is the DEFAULT in runSim.** The C backends stay available
   and must keep compiling; `make` supports both paths and `make help` documents
   both.
2. **Test images are real, local, gitignored.** Already in place:
   - `Verilog/ND-BUS-DEVICES/testdata/210523I01-XX-01D.img`
     (1,261,568 B) ← `/home/ronny/repos/nd100x/images/Nd-210523I01-XX-01D.img` → serves **FLOPPY1.IMG**
   - `Verilog/ND-BUS-DEVICES/testdata/BIGDISK0-L2-100.IMG`
     (78,643,200 B) ← `F:\RC\RonnyTest\HDLC1\BIGDISK0-L2-100.IMG` → serves **SMD0.IMG**
   - Both already matched by `.gitignore:94-95` (`testdata/*.img`, `testdata/*.IMG`). Keep it that way.
3. **TWO boot BPUNs**, both served as `BOOT.BPUN` (one per card variant):
   - `INSTRUCTION-B.BPUN` (46,566 B) — the existing instruction-verify boot
   - `CONFIGURATIO-C08.BPUN` (47,052 B) ← `/home/ronny/repos/nd100x/images/CONFIGURATIO-C08.BPUN`
     — the CONFIG tool: boot it, at the `TPE>` prompt run `RUN`, analyse the
     output to confirm the tape/floppy/SMD controllers are **detected
     correctly**. This gets its own unit test and grows a device per phase.
4. **BSRAM is validated at every phase** (synthesize Tang, read the PnR number).
   The WCS UUA repack (BSRAM-BUDGET Part 1, +8 blocks) is a **contingency**, done
   only when a phase's BSRAM gate actually fails — not before.

---

## The five facts that shape everything

1. **Make the Verilog card model MUX-BASED — no tristates. RONNY 14-JUL:
   "we fucking need to get the verilog code validated", and "tristates + pullup
   is ONLY needed IF we plan to have external bus activated to talk to other
   cards via external ND bus — that we are at the moment not planning".**

   `Verilog/SD-FAT/sim/sd_card_model.v:69-73` uses
   `inout sd_cmd/sd_dat*` + `pullup()` in the TB, which is iverilog-only and
   already violates the repo's own no-tristate rule
   (`SD-FAT/circuit/nd_storage.v:24-25`; CLAUDE.md: "inside the FPGA `z` does not
   work"). ⇒ **Convert it to split `_i`/`_o`/`_oe` ports and resolve with a mux.
   One card model, both simulators, no `z` anywhere.**

   Do NOT validate the stack against a C++ model under Verilator and a Verilog
   model under iverilog — two models that can disagree is exactly the divergence
   to avoid.

   **The pattern already exists in-repo** — copy it, don't invent:
   `SD-FAT/sim/nd_storage_vtop.v:8-11` resolves each SD line as "DUT
   output-enable wins, then the card model, then the bus pullup (1)". That is
   the mux. `nd_storage` itself already exposes only `_i`/`_o`/`_oe`.

   **No tristate wrapper, no compatibility shim** (per the ruling — nothing here
   needs a real bidirectional bus). The ~8 existing iverilog TBs that currently
   do `pullup()` on an `inout` get updated to the same mux resolve:
   `nd_storage_tb.v:82-83,192-193`, `nd_storage_tape_adapter_tb.v:220-221`,
   `nd_storage_floppy_adapter_tb.v:361-362`, `nd_storage_fatchk_tb.v:73-74`, plus
   `sd_writer_tb.v` / the engine+write TBs.
   **Gate: every one of those TBs must still pass after the conversion** — that
   is the regression proof. They are all registered in
   `Verilog/tests/run_all_tests.sh`.

   **The ONLY real tristate is the physical SD pad on Tang**, and it already
   lives at the board top where it belongs — `nd_storage` deliberately exposes
   `_i`/`_o`/`_oe` so the single tristate sits there (`nd_storage.v:24-25`).
   Note `sd-fat-test` found silicon-only tristate bugs (yosys nested-ternary `z`
   collapse), which is why the `test-tristate` netlist gate exists. Keep it.

   **The 75 MB problem is solvable in Verilog:** today the model `$fread`s the
   whole file at time 0 (`sd_card_model.v:100-107`, `MAX_BYTES` default 8 MB) —
   no good for a 76 MB card. Use `$fseek`/`$fread` **on demand** per sector
   (both iverilog and Verilator support them).

   **The existing C++ card model is not deleted** — it is the silicon-proven
   lineage (`test_nd_storage.cpp:6-12` from
   `fpga/tang-nano-20k/sd-fat-test/sim/test_sd_fat.cpp`) and already gates
   `test-storage`. Two independent models cross-checking the same DUT is a
   feature; two models each validating a *different* simulator's build is the
   bug. The **Verilog** model is the one in the runSim path.

2. **`nd_storage` REQUIRES a `mem_*` backend — it is not optional.** All reads
   are served from memory, never from the card
   (`SD-FAT/circuit/nd_storage_engine.v:20-21`: "READ path: 512 mem-port reads").
   runSim has **no SDRAM** (`MEM_43.v:517` selects `MEM_RAM_49_SIM` under
   `VERILATOR_SIM`). But `mem_*` is a **generic 32-bit word port**
   (`nd_storage.v:84-90`), and a **proven C++ behavioral mem model already
   exists** (`test_nd_storage.cpp:13-14`, same contract + randomized 4..40-cycle
   latency as `SD-FAT/sim/nds_mem_model.v`).
   ⇒ **No SDRAM model is needed in runSim.** Reuse the C++ mem model.

3. **RONNY'S RULING 14-JUL: floppy and SMD are NOT 100% cached in RAM.**
   This overrides the v1 design and my first draft of this plan.
   - **Tape**: full preload is fine and stays — small, read-only, and `rewind`
     is just a pointer reset with zero card traffic
     (`nd_storage_tape_adapter.v:25-27`).
   - **Floppy**: **NOT preloaded. Caching can probably be disabled entirely** —
     an SD card is quicker than any real floppy ever was, so serve each sector
     request straight from the card. (Sanity check: the drive it emulates does
     ~300 rpm / ~100 KB-per-second-class transfer; SD at 13.5 MHz 4-bit measured
     **5981 KB/s read** on Tang silicon. Two orders of magnitude of headroom.)
   - **SMD**: **NOT preloaded** (impossible anyway, see below). A **block cache
     keyed on most-recently-used / most-active blocks**, not a fixed window.

   The preload arithmetic that forced this:

   | file | size | blocks (2048 B) | slot | slot capacity | verdict |
   |---|---|---|---|---|---|
   | `BOOT.BPUN` (either) | ~47 KB | 23 | SLOT0 = 32 | 65,536 B | preload, fine |
   | `FLOPPY1.IMG` | 1,261,568 B | 616 | SLOT1 = 640 | 1,310,720 B | *would* fit — **but do not preload it** |
   | **`SMD0.IMG`** | **78,643,200 B** | **38,400** | SLOT3 = 160 | 327,680 B | **240x too big — never an option** |

   The whole slot map is 1952 blocks = 3.81 MB (`nd_storage.v:61-67`) against a
   75 MB pack. `nd_storage.v:31-33` already anticipates this: SMD clients are
   "Phase-4 cache windows", sit OUTSIDE `PRELOAD_MASK` (default `7'b0000111`,
   `:52`) and "answer open_err immediately".

   **What this costs us: v1 has NO on-demand card-read path.** Today the card is
   touched only at mount/preload; every block read is served from SDRAM
   (`nd_storage_engine.v:20-21` "READ path: 512 mem-port reads";
   `nd_storage_mount.v:193` "preload only writes"). Serving a floppy sector
   straight off the card is therefore **new engine work**, not a parameter
   change — and it is now needed in Phase 4, not just Phase 5.
   Consistent with the ruling: `nd_tape_sdfat_source.v` already sets
   `PRELOAD_MASK(7'b0000001)` — tape only.

   **Upside:** dropping the floppy preload frees SLOT1+SLOT2 (1280 blocks =
   2.6 MB of the 3.81 MB region) for the SMD block cache. Re-size the slot map
   deliberately in Phase 5 rather than inheriting the v1 defaults.

4. **There is no SMD adapter.** `SD-FAT/circuit/` has
   `nd_storage_tape_adapter.v` and `nd_storage_floppy_adapter.v` only; a
   repo-wide search for an SMD one finds nothing but a mention in
   `docs/floppy-smd-completion-plan.md`. The `SDISK_*` seam
   (`ND120_CORE.v:132-144`) is unserved.

5. **The Tang BSRAM budget is a CPU-ONLY measurement.** The Tang project file
   list (`fpga/tang-nano-20k/nd120_tang20k.gprj`) contains **zero** storage
   sources — verified. So the 41/46 blocks (90%) in BSRAM-BUDGET.md is *before*
   any SD-FAT. **The BSRAM cost of the storage stack itself is UNMEASURED and
   lands in Phase 2.** This is the single most likely "surprise" and is why
   every phase gates on a real PnR number.

---

## Cross-cutting: the BSRAM rule (applies to EVERY phase)

Per phase, in this order:

1. **Measure before**: record the current PnR BSRAM from
   `fpga/tang-nano-20k/build/nd120_tang20k_build/impl/pnr/nd120_tang20k_build.rpt.txt`.
2. **Measure after**: re-synthesize; read the same line. Record both numbers in
   the phase's section of this doc. Baseline: **41/46 (90%), 5 free**
   (BSRAM-BUDGET.md, PnR of 10-JUL-2026).
3. **If it does not fit**: do BSRAM-BUDGET **Part 1** (repack the UUA half of the
   WCS: 16 → 8 blocks, +8 free, 90% → ~72%). Preconditions there are real —
   especially "does anything write the UUA bank at runtime after load?"
   (BSRAM-BUDGET.md:215-222, **UNVERIFIED**) and the 1-cycle read latency being
   load-bearing for correctness (`Shared/support/IDT6168A_20.v` header;
   BSRAM-BUDGET.md:236-243). Do not start Part 1 speculatively.
4. **Never** let a phase land on Tang without a fresh PnR number in this doc.

---

# PHASE 1 — device-less core on Tang ✅ DONE + COMMITTED (8b71136)

`ND120_TANG20K_TOP.v` instantiates `ND120_CORE #(0,0,0)`. Behaviour-neutral,
proven byte-identical. See PLAN-nd120-core-extraction.md. Nothing to do.

---

# PHASE 2 — TAPE from SD (runSim default + Tang)
## runSim half: **DONE 14-JUL-2026** (commits 54532ff, ffdc745). Tang half: NEXT.

**`400$` boots BOOT.BPUN off a simulated SD card through the real Verilog
SD-FAT stack** — INSTRUCTION-B loads and executes, 46441 tape bytes served from
the card. `SD_STORAGE=1` is the runSim default; `SD_STORAGE=0` keeps the C
server; both boot. Negative test: point SD_CARD_IMG at a missing file and the
boot dies, so the SD path is provably load-bearing.

Findings from doing it (all measured):
- **`--timing` is FREE.** sd_card_model drives the SD bus from tasks so the
  whole runSim build needs Verilator `--timing`. Measured before adopting:
  console byte-identical to golden, 1m23.5s vs 1m25.1s. No dilemma after all.
- **nd_tape_sdfat_source had a DEADLOCK** (never instantiated anywhere, so never
  caught): it waited for `sd_status == OK` before opening, but a mount only runs
  on `open_req` (`nd_storage_mount.v:8`) and sd_status is only set at mount end
  (`nd_storage.v:35`). No open -> no mount -> no status -> no open; sd_clk never
  toggled. The mount IS the bring-up; status is its RESULT. Fixed: pulse open
  once after reset, like every proven tb does.
- **-I resolves modules by FILENAME**: `nds_sync.v` (nds_sync_pulse/level) and
  `sd_file_reader.v` (sd_card_ctrl) need `-v` LIBRARY entries, kept OUT of
  VERILATOR_DIRS (that variable is also handed to g++ via -CFLAGS, which tried
  to LINK the .v files). Gated on SD_STORAGE.
- runSim needs **no SDRAM**: nds_mem_model on the generic mem_* port. Confirmed.


**Goal:** `ND_TAPE_400` is fed by the real SD-FAT stack in runSim *and* on Tang.
`400$` boots `BOOT.BPUN` off a simulated/real card. C backends still available.

**Why first:** it is the only device whose adapter exists, whose file fits a
full-preload slot, and whose board-side wrapper (`nd_tape_sdfat_source.v`) is
already written and elaborates — it just has **no instantiation anywhere in the
repo** (verified).

### Step 2.1 — Verilator-clean Verilog card model + mem backend ✅ DONE (54532ff)
**(a) Card model — convert to mux, no tristates (fact 1).** Give
`sd_card_model.v` split `_i`/`_o`/`_oe` pads, resolve with the mux pattern from
`nd_storage_vtop.v:8-11`, and update the ~8 iverilog TBs that `pullup()` an
`inout`. Add on-demand `$fseek`/`$fread` so a 76 MB card needs no 76 MB array.
**Gate: every existing iverilog storage tb still passes** (`test-nds-mount`,
`test-nds-tape`, `test-nds-floppy`, `test-nds-fatchk`, `test-writer`, …) — all
in `Verilog/tests/run_all_tests.sh`.

**(b) Mem backend for runSim.** nd_storage's `mem_*` is mandatory but generic
(fact 2). Reuse the proven behavioral mem model — the C++ one from
`test_nd_storage.cpp:13-14` or `SD-FAT/sim/nds_mem_model.v` — with the same
contract and randomized 4..40-cycle latency. **No SDRAM model in runSim.**

- **Regression gate for the whole step:** `SD-FAT/sim` `test-storage` must still
  pass. Register any new tb in `tests/run_all_tests.sh` with a strict
  `TB_RESULT: PASS` pattern.
- BSRAM: N/A (sim only).

### Step 2.2 — Multi-file card builder
`SD-FAT/sim/make_boot_card.sh` writes **exactly one file** and refuses sources
> 65,536 B (`:39-43`, `:48`). Needed: a card carrying BOOT.BPUN **+**
FLOPPY1.IMG **+** SMD0.IMG.
- Extend it (or add `make_nd_card.sh`) to place N files, keeping **every**
  guarantee it already enforces — contiguous chains, intact EOC, fsck-clean,
  delete-image-on-failure (`:50-120`). `nd_storage` v1 REQUIRES contiguity
  (`:16-17`).
- Filename matching is **VFAT long name** (4-char extensions like `BOOT.BPUN`
  get a mangled 8.3 + LFN chain, `:70-73`; reader side
  `sd_file_reader.v:30-36`). Keep the by-attribute verifier; do not match short names.
- **Two card variants** (decision 3): `BOOT.BPUN` = INSTRUCTION-B, and
  `BOOT.BPUN` = CONFIGURATIO-C08.
- Phase 2 card can be small (BOOT only). Grow it in 3 and 5. Cards are
  gitignored (`.gitignore:102` covers `SD-FAT/sim/*.img`).
- **Unit test:** builder self-verification is the test (it already fails hard);
  add a check that each file is contiguous **and** that a 76 MB card still
  fsck's clean once SMD lands.

### Step 2.3 — runSim: `SD_STORAGE` path, default ON ✅ DONE (ffdc745)
- `runSim/Makefile`: add `-I../SD-FAT/circuit` to `VERILATOR_DIRS` (**missing
  today** — verified; first hard blocker). Add `SD_STORAGE ?= 1`.
- Wire `nd_tape_sdfat_source` (or `nd_storage` + tape adapter) into the sim
  harness, feeding the core's `TAPE_BYTE_*`; C++ card model on the SD pads, C++
  mem model on `mem_*`. Set `SIMULATE=1` (short SD init,
  `nd_tape_sdfat_source.v:33`).
- `SD_STORAGE=0` selects the existing C path (`process_verilog_tape`,
  `NDBus.cpp:299-337`). **Both must build and pass.**
- **`make help` must document both** (decision 1).
- **Two clocks:** the board/harness supplies `clk_stor` from the storage domain
  and `clk_cpu` from the *same net* as the core's `clk_cpu`; `clk_stor` never
  enters the core. Use a non-integer ratio in sim to stress the CDC — the
  storage tests already use ~27.03/23.04 MHz (`test_nd_storage.cpp:15-16`).
- **Gate:** `400$` boots INSTRUCTION-B from the card and reaches the same
  banner the tape gate checks. Ideally reuse `make test-tape`'s landmark
  approach (`Makefile:93-99`) — a byte-diff of consoles is impossible.

### Step 2.4 — The CONFIG tool gate (new, reusable across phases)
Boot `BOOT.BPUN` = CONFIGURATIO-C08, drive to the `TPE>` prompt, send `RUN`,
capture and assert on the output: **is the tape controller detected correctly?**
- New target (suggest `make test-config-tape`), new `SCRIPT_CMD_CONFIG` in
  `Run120.cpp` (pattern: the existing `SCRIPT_CMD_*` block, `:139-192`).
- **UNVERIFIED and must be established empirically before asserting anything:**
  the exact `TPE>` interaction and what CONFIG prints for each controller.
  First run it, capture real output, *then* write the assertion. Do not invent
  expected text.
- Extend with floppy in Phase 4 and SMD in Phase 5 — same test, more devices.

### Step 2.5 — Tang: instantiate `nd_tape_sdfat_source`
- `ND120_CORE #(1,0,0)` on Tang; hang `nd_tape_sdfat_source` off `TAPE_BYTE_*`.
- Resolve the SD tristate **at the board top** — `nd_storage` exposes only
  `_i`/`_o`/`_oe` (`nd_storage.v:24-25`). Note `sd-fat-test` found silicon-only
  tristate bugs (yosys nested-ternary `z` collapse) — the `test-tristate` gate
  exists for this.
- `mem_*` ← `MEM_RAM_49_SDRAM` with `-DND_SDRAM_PACK16 -DND_STORAGE_PORT`,
  wiring `stor_clk`/`stor_rst_n` (`MEM_RAM_49_SDRAM.v:114-129`). Device traffic
  is forced to the upper half (`{1'b1, mem_addr[19:0]}`, `:36-38`) and granted
  only in idle slots so "CPU accesses always win" (`:39-44`).
- Add every SD-FAT source to `nd120_tang20k.gprj` (explicit file list).
- ⚠️ **BSRAM gate — the big unknown.** This is the first time storage enters the
  Tang build. Baseline 41/46. Measure. If it exceeds 46, do BSRAM Part 1.
- **Gate:** `make -C fpga/tang-nano-20k/sim vtest` still passes; then real
  hardware boot from a real SD card.

**Phase 2 exit:** `400$` boots from card in runSim (default) and on Tang; C path
still green; CONFIG tool sees the tape controller; PnR BSRAM recorded here.

---

# PHASE 3 — Device-buffer sync-read refactor (BSRAM Part 2)

**This is a hard prerequisite for floppy/SMD on ANY FPGA — Tang and Basys3
alike. It is not an optimisation** (BSRAM-BUDGET.md:247-251). Do it *before*
putting floppy on hardware, not before putting floppy in runSim.

**The defect, verified firsthand:** each 2 KB buffer has **three async read
ports at three independent addresses** plus two write sites:
- `ND-BUS-DEVICES/FLOPPY-DMA/circuit/ND_FLOPPY_DMA.v:233` buffer; async reads at
  `:234`, `:259`, `:539`; writes `:357`, `:590`
- `ND-BUS-DEVICES/SMD/circuit/ND_SMD.v:149`; reads `:150`, `:174`, `:393`;
  writes `:251`, `:437`
- `ND-BUS-DEVICES/FLOPPY/circuit/ND_FLOPPY_PIO.v:94` — **worse**: `:358`/`:362`
  are **read-modify-write** on `s_buffer[s_bufptr]`, not just reads
Gowin cannot map that to BSRAM; as registers, 1024x16 = 16,384 bits **exceeds
the 15,552 logic registers on the whole device for a single buffer**. Invisible
in Verilator, which is why it has not bitten.

**Preconditions (BSRAM-BUDGET.md:334-341):**
- **UNVERIFIED:** that the three readers are mutually exclusive per FSM state.
  Confirm from the FSMs, or budget a true dual-port (SDPB) block. **Verify before
  designing the mux.**
- Decide whether `ND_FLOPPY_PIO.v` needs it or is Verilator-only.

**The work:** one sync read port + one write port (the `IDT6168A_20.v` template
— read its timing comment first), then **absorb the 1-cycle latency in the
FSMs**, including the `dma_issue` call site and the `iox_rdata` boot path.

**Unit tests:** `ND-BUS-DEVICES/FLOPPY-DMA/sim` `test-floppy-dma`,
`ND-BUS-DEVICES/SMD/sim` `test-smd`, `ND-BUS-DEVICES/FLOPPY/sim`
`test-floppy-pio` must all still pass — **the extra cycle will move tb timing
expectations**, so expect to update them, carefully and visibly. All three are in
the registry. Also re-run `make test-dma-rtl` / `test-dma-xcheck` /
`test-floppy-stdin` (real arbiter + real RAM).

**BSRAM gate:** budget says floppy + SMD = **2 blocks** (1Kx18, one per buffer),
fitting today's 5 free without Part 1. Verify by synthesis — and note the Phase-2
storage cost lands first, so "5 free" may already be gone.

---

# PHASE 4 — FLOPPY from SD (runSim + Tang)

**Goal:** `1560&` boots from `FLOPPY1.IMG` on the card, in runSim and on Tang.

The floppy adapter exists and its `disk_*` port is **pin-compatible** with the
core's `FDISK_*` seam (verified against `nd_storage_floppy_adapter.v:79-90`).
Per the ruling in fact 3, **FLOPPY1.IMG is NOT preloaded** — drop client 1 out of
`PRELOAD_MASK` and serve sectors on demand from the card. So this is NOT just
wiring; it needs the on-demand read path (gap 4d), plus three known gaps:

### Gap 4a — `media_fmt` is not driven by the adapter
The core seam needs `FDISK_MEDIA_FMT` (`ND120_CORE.v:128`); the adapter has **no
media_fmt output** (verified: zero mentions). The C model derives it from file
size (`NDBus.cpp:365-378`): default `0xF`; `315392` → `0x0` (8-inch);
`>= 1261568` → `0xF` (5.25" 1.2 MB). The adapter has `c_size_bytes` (`:60`).
⇒ Add media_fmt derivation to the adapter, replicating that rule **exactly**.
Our image is 1,261,568 B → `0xF`.

### Gap 4b — drive select is real now
The C backend **ignores `FDISK_DRIVE`** entirely (verified). The adapter is
**per-drive** (`parameter DRIVE`, one instance per drive, outputs OR-combined,
`:31-36`). Serving FLOPPY1+FLOPPY2 = two adapter instances. This is a
**behaviour change, not a swap** — call it out in the test.

### Gap 4c — writes are RMW and the tail-block rule is a hard rule
Adapter writes are read-modify-write (`:45-49`) and it must **never write the
partial tail block** of a non-2048-multiple file (`:56-59`). Our floppy image is
1,261,568 = 616 x 2048 exactly, so no tail — but do not let that hide the rule.
Also honour the standing SD write-safety rule: no card-write bitstream before
sim proves the write path, the legal-sector assertion, post-run fsck health, and
cold-start coverage.

### Gap 4d — on-demand card reads (NEW, from the ruling)
v1 serves block reads from SDRAM only; the card is touched at mount/preload
only. A non-preloaded floppy needs a **read-through-to-card path** in
`nd_storage_engine`. Decide explicitly whether floppy uses **no cache at all**
(simplest; Ronny's lean — SD is ~60x faster than the drive being emulated) or
reuses the Phase-5 block cache. Recommend **no cache for floppy**: it removes
coherency questions on the write path (adapter writes are RMW, gap 4c) and the
latency budget is enormous.

**Steps:** card grows FLOPPY1.IMG (2.2) → engine on-demand read path (4d) →
drop client 1 from `PRELOAD_MASK` → runSim `SD_STORAGE` floppy wiring →
CONFIG gate extended to assert floppy detection → Tang (needs Phase 3 done).

**Unit tests:** `SD-FAT/sim` `test-nds-floppy` (already two-tier: scripted stub +
real stack, verified). Plus `make test-floppy-boot` / `test-floppy-stdin`
against the SD path. **BSRAM gate** on the Tang step.

---

# PHASE 5 — SMD from SD (the big one)

**Goal:** `1540&` boots from the 75 MB `SMD0.IMG`.

Three pieces of genuinely new work, in order:

### 5.1 — MRU/most-active BLOCK CACHE in `nd_storage` (the hard part)
Per the ruling: a **block cache keyed on most-recently-used / most-active
blocks**, NOT the fixed "window" the v1 comments imply. 38,400 blocks vs a
160-block slot; 75 MB vs a 3.81 MB region — the pack can never be resident, so
the cache is the whole design.

Needs: a **tag store** (block# -> slot), hit/miss detection, fetch-on-miss,
**eviction policy (LRU / activity-ranked)**, and a write-back or write-through
decision. None of it exists — v1 is full-preload only
(`nd_storage_mount.v:193`; clients outside `PRELOAD_MASK` refused at `:350`).
Builds on the on-demand read path from gap 4d. **Design it properly; this is not
wiring.** Re-size the slot map first: with floppy no longer preloaded, SLOT1+2
(1280 blocks = 2.6 MB) are free for SMD.

### 5.2 — Write the SMD adapter
None exists. Model it on `nd_storage_floppy_adapter.v`, serving the `SDISK_*` /
`SDBUF_*` seam (`ND120_CORE.v:132-144`). Note the C backend's position math for
reference: `2 * (SDISK_BLKADDR2*2048 + SDISK_BLKADDR1*64)` bytes
(`NDBus.cpp:511-512`), and that it **ignores `SDISK_UNIT`** (trace-only, `:516`)
— a real stack serving SMD0..3 is a behaviour change.

### 5.3 — Wire runSim, then Tang
- The C++ card model must `fseek` the 76 MB card (built in at 2.1).
- **UNVERIFIED / likely blocker:** whether the Tang SDRAM storage region can host
  an SMD window *and* the tape+floppy slots. BSRAM-BUDGET.md:364-369 flags SDRAM
  contention as unanalysed. Measure before promising SMD on Tang.
- **BSRAM gate** again (SMD buffer = 1 block, post-Phase-3).

**Unit tests:** new `test-nds-smd` mirroring `test-nds-floppy`'s two tiers.
Card builder must place a 75 MB contiguous file (2.2). CONFIG gate extended to
assert SMD detection. `make test-smd-boot` against the SD path.

---

## Test matrix (what proves each phase)

| | runSim SD | runSim C | Tang vtest | Tang silicon | BSRAM PnR | CONFIG tool |
|---|---|---|---|---|---|---|
| P2 tape | `400$` boot | still green | pass | boot from card | **measure** | tape detected |
| P3 buffers | n/a | n/a | pass | — | measure (+2 blk) | — |
| P4 floppy | `1560&` boot | still green | pass | boot from card | measure | +floppy |
| P5 SMD | `1540&` boot | still green | pass | if SDRAM allows | measure | +SMD |

**Standing rules:** every new tb goes in
`Verilog/tests/run_all_tests.sh` with a strict
`TB_RESULT: PASS` pattern — a test that can pass silently can fail silently.
`make test` must stay 48/48 (modulo the pre-existing `test-memchain`,
TODO.md:83), and `sim/`'s latch/FF trace goldens must stay byte-identical —
**they link the C models and never define `ND120_VERILOG_DEVICES`
(`sim/Makefile:60`), which is exactly why the C path must keep compiling.**

## Optional future: expose the ND bus to REAL external cards (Ronny, 14-JUL)

**Keep the internal bus exactly as it is — it is already right.** The ND-100
C-PLUG bus in `ND120_CORE.v` is **split IN/OUT with a wired-AND merge and zero
tristates** (`ND120_CORE.v:59-71` ports; merge at `:616-625`). Multiple devices
(bus slave + 3 DMA masters) already share it that way. The only `inout` in the
core is `IO_sdram_dq`, a real SDRAM pad. **Nothing to change.**

This is not a workaround — it is what the hardware does. The real ND bus is
**open-collector**: assert = pull low, release = drive high and let the bus
terminator's pullup win. That is why `BIF_BCTL_BDRV_7.v` exposes **no
output-enable** and why an AND of every contributor is the correct model.

**⚠️ Do not confuse this with the SD card bus.** `sd_card_model.v`'s tristates
are the SD CMD/DAT bus — unrelated to the ND bus, and still converted to a mux
per fact 1.

**Later, if we want to talk to real ND cards:** it is a **board-top pad
transform behind a `define`**, no core or device changes:

```verilog
`ifdef ND_EXTERNAL_BUS
  // open-drain pad per line: drive 0 to assert, release to let the
  // bus terminator pull high. One line shown; same for every ND bus signal.
  assign BD_pad[i]       = BD_23_0_n_OUT[i] ? 1'bz : 1'b0;
  assign BD_23_0_n_IN[i] = BD_pad[i];
`else
  // internal only: today's tie-off (FPGA) or C-harness drive (sim)
`endif
```

The core already exposes every ND-bus line unconditionally (the `VERILATOR_SIM`
gating was deliberately dropped in phase 1 — "board drives-or-ties"), so this
costs a board-level wrapper and pin constraints, nothing more.

**UNVERIFIED, and the one thing to check first:** that the CPU truly RELEASES BD
(drives all-1s) whenever a DMA master owns the bus. The internal wired-AND
already depends on it, so it is probably true — but on a real bus a wrong answer
means two drivers fighting. Prove it in sim (assert BD_23_0_n_OUT == 24'hFFFFFF
whenever OUTGRANT_n is asserted to a device) before making pins. Also note the
`test-tristate` netlist gate exists because yosys collapsed nested-ternary `z`
on silicon — any real pad work must re-run it.

## Known landmines

- `runSim/golden/console_ff_golden.log` is a **C-model** golden, bit-compared
  (`Makefile:58-68`). If `SD_STORAGE=1` changes console output on the default
  path, that golden must be re-recorded deliberately — not silently.
- `nd_storage` hard max is **7 files** (FILE0..FILE6, 3-bit client index,
  `PRELOAD_MASK[6:0]`). Our set is 3. Fine, but do not plan an 8th.
- `SIMULATE=1` shortens SD init in sim (`nd_tape_sdfat_source.v:33`). Hardware
  needs 0. Do not ship a bitstream with 1.
- `sd_fat_features.vh`: `SDFAT_STORAGE` requires `SDFAT_WRITE` (`:62-66`);
  `SDFAT_STORAGE_CHECK` requires `SDFAT_CHECK` (`:67-78`).
- WSL `/mnt/e` serves stale files — verify sha256 before flashing (standing rule).

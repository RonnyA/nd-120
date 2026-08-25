# P3 — DMA master vs the real board bus: adjudicating the 7/8 errors

**Status: DONE + MEASURED (2026-07-26).** A standalone Verilator harness was
built (its own dir + Makefile + obj_dir, NOT touching `sim/` or `runSim/`), it
drives the real `ND_DMA_MASTER` against the real arbiter (`PAL_44801A` via BIF)
and real RAM, and it **passes**. The "7/8 errors" were adjudicated: writes and
reads through the real bus are correct; the recovery gap (`MIN_GAP_TICKS`) was
proven **load-bearing** by reproducing the documented "every second read lost".
Sections 1-7 below are the original design/analysis (kept for background); the
measured outcome is in **§0 RESULTS** immediately below. All paths are absolute;
facts are cited by path+line.

**Bus protocol reference** (what this P3 work validates the DMA master against):
`Verilog/docs/nd100-bus-dma.md` (writeup; §10.8 =
measured DMA findings) and `Verilog/docs/nd100-bus-deck.pptx`
(slide deck, all bus phases). See also `../ND-BUS-DEVICES/README.md`.

---

## 0. RESULTS (built + measured, 2026-07-26)

**Harness:** `Verilog/dmaSim/` — own `Makefile`,
own `obj_dir`, own C++ main `dma_p3_main.cpp` (+ copied `AM27256_4513{2,3}L.hex`
microcode PROMs). Verilates `ND120_TOP` (`-DVERILATOR_SIM -DFPGA_FF_MODE
-DND_SDRAM_PACK16 -DND120_VERILOG_DEVICES --timing`) and drives ONLY the DMA
test-client ports (`DMA_REQ/WR/ADDR/WDATA -> DMA_RDATA/ACK/ERR`), so the Verilog
`ND_DMA_MASTER` (instantiated at `ND120_CORE.v:622`) requests the bus from the
real arbiter and runs real memory cycles — true cycle-steal while the CPU idles.
Links against the harness alone (the RTL is pure Verilog, no DPI). Bring-up =
reset + clock to a settle count (CPU reaches its OPCOM idle loop, freeing the
bus); verification reads the Verilated RAM byte arrays directly
(`...MEM__DOT__RAM__DOT__b0_lo/hi`).

**Gates (in `dmaSim/Makefile`):**

| Target | Config | Result |
|---|---|---|
| `test-dma-p3` | shipping RTL, 32-word DMA write+read back-to-back | **PASS** (all words correct) |
| `test-dma-p3-repro` | recovery OFF: `MIN_GAP_TICKS=0` + `EARLY_REREQ=1` | **7 / 64 reads stale** — hazard reproduced |
| `test-dma-p3-recovery` | shipping: `EARLY_REREQ=0` + `MIN_GAP_TICKS=32` | **0 / 64 stale** — clean |
| `test-dma-p3-teeth` | runs both above | the gap is load-bearing |

**Findings (measured, not inferred):**

1. **Adjudication of the "7/8 errors": the device is CORRECT.** DMA writes AND
   reads through the real arbiter return the right data. An initial "reads return
   0" symptom was a **HARNESS bug** (the state machine consumed the trailing
   write `dma_ack` — high for one sysclk = two half-cycle samples, and lingering
   across the write->read phase change — as the first read's result). Gating ACK
   handling on an in-flight-request flag fixed it. So the original combined-tb
   "7/8" is consistent with a harness/ACK-sampling artifact, not a device fault.
2. **The recovery gap is load-bearing.** With `MIN_GAP_TICKS=0` and
   `EARLY_REREQ=1` (re-assert BREQ overlapping BDRY), 7 of 64 back-to-back reads
   returned stale data — the exact "every second read lost" of
   `ND_DMA_MASTER.v:55-72` / `nd100-bus-dma.md` §10.8. The shipping default
   (`EARLY_REREQ=0`, `MIN_GAP_TICKS=32`) is clean (0/64).
3. **`EARLY_REREQ=1` DEFEATS `MIN_GAP`** and must never be used (as the RTL
   comment warns): `ST_END` re-asserts `BREQ_n` (`ND_DMA_MASTER.v:265`) before
   the gap counter gates it, so `EARLY_REREQ=1 + MIN_GAP=32` still loses reads.
   `MIN_GAP` alone (`EARLY_REREQ=0`) also shows the hazard at gap 0 (thin margin,
   1/64), confirming the gap itself — not only the re-request discipline — is the
   fix.
4. **Why writes always survived:** memory captures the address on a single
   sysclk-sampled rising edge of `BCGNT50` (`MEM_ADDR_44.v:90-113`,
   `AM29C821 USE_SYSCLK=2`) and this board buffers DMA writes — so a lost grant
   round drops a READ cycle but a WRITE still lands. Reads have no such buffer.

**RTL footprint:** two inert compile-time hooks added to
`Verilog/ND-BUS-DEVICES/DMA/circuit/ND_DMA_MASTER.v`
(`` `ND_DMA_MIN_GAP_TICKS `` / `` `ND_DMA_EARLY_REREQ ``) — no normal build
defines them, so every shipping build is byte-identical. They exist only so the
teeth targets can rebuild with the recovery disabled.

**Note on the ladder below:** §2 framed a Tier-1 iverilog stand-in and a
Verilator Tier-2 as owner-fenced. That was overtaken — a *separate* Verilator
harness (own obj_dir) was authorized and is what was built, so the authoritative
Tier-2 gate exists now without touching the fenced `sim/`/`runSim/` trees.

---

## 1. The problem this solves

`CONFORMANCE.md` §8 leaves one anomaly open:

> **Combined-tb 7/8 DMA errors**: unresolved — P3's job (hand-BCU vs real board RTL).

`PLAN-floppy-validation.md` §"Phase 3" states the task: run `ND_DMA_MASTER`
against **(a)** the hand-written BCU model from the combined tb **and** **(b)** the
real board bus RTL, to prove whether the combined-tb DMA errors were **harness**
(the hand-BCU) or **device** (the master), and fix what falls out. Gate:
`test-floppy-p3`.

The behaviour under suspicion is already characterised in the RTL itself. From
`Verilog/ND-BUS-DEVICES/DMA/circuit/ND_DMA_MASTER.v`
lines 55–64 (the `MIN_GAP_TICKS` comment):

> MEASURED on the real CPU-board RTL (full-RTL gate): the memory-side grant and
> decode chain (BLRQ/BCGNT 25/50 ns stages) needs time to unwind after BDRY
> before it can latch the next externally strobed address — a back-to-back
> re-request wins the bus grant but the RAM cycle never happens (**every second
> read lost**). Real ND-100 controllers re-request at 1.4 µs+ periods … so
> hardware never hit this.

So the "7/8 errors" are almost certainly this: a fast back-to-back DMA re-request
losing every other memory cycle against the real grant/refresh timing. The fix
already in the master is a recovery gap, `MIN_GAP_TICKS = 32` (same file, line
64). **P3 is the missing proof that (i) reproduces the loss and (ii) shows the gap
clears it — against real arbiter RTL, not a hand model.**

---

## 2. The validation fidelity ladder

One DMA master, four fidelities. Each tier catches a different class of bug; none
replaces the one below it.

```
 Tier 0  hand-BCU tb            ND_DMA_MASTER + a behavioural BCU FSM in the tb
         (test-floppy-dma)      HAVE — green. Proves the master's own FSM:
                                BREQ/grant, address/data phases, read/write,
                                status writeback, multi-sector. Does NOT model
                                the real grant/refresh/decode timing.

 Tier 1  real-arbiter tb        ND_DMA_MASTER + the REAL arbiter PAL_44801A +
         [NEW — iverilog]       the REAL BIF freeze/grant logic, with a MODELLED
                                memory-cycle + refresh timing wrapper.
                                Proves the back-to-back grant behaviour against
                                the real arbiter state machine; reproduces
                                "every second read lost" and the MIN_GAP fix.
                                Fidelity-limited: the memory/refresh TIMING around
                                the arbiter is a model, not the board.

 Tier 2  full-RTL DMA gate      ND_DMA_MASTER inside ND120_CORE against the whole
         [EXISTS — Verilator,   BIF_5 -> BIF_BCTL_6 -> PAL_44801A + real RAM,
          fenced off now]       driven via the top-level DMA_* ports. This is
                                where "every second read lost" was measured.
                                Cycle-accurate, but needs the whole CPU board and
                                runs under Verilator (owner-coordinated).

 Tier 3  real silicon          Tang / Basys3 DMA against real memory timing.
         [future]              the only tier with real electricals.
```

**What each tier is worth**

- **Tier 0** (`test-floppy-dma`) is green and stays the master's unit gate. It can
  never see the grant/refresh timing bug — its BCU is a hand FSM.
- **Tier 1** is the new, *iverilog-runnable* win: it puts the **real** arbiter RTL
  in the loop, so a grant/freeze/back-to-back bug fails on a laptop with a
  waveform. Its blind spot is the memory/refresh *timing model* around the
  arbiter — see §4 and §7.
- **Tier 2** already exists (§3) and is the authority for the timing, but it is
  Verilator + whole-CPU-board and currently owner-fenced. Tier 1 is explicitly a
  *cheaper stand-in that cannot be cross-checked against Tier 2 while Verilator is
  off-limits* — that limit is stated, not hidden.

---

## 3. What exists vs what is new

**Exists (verified in tree):**

- The **full-RTL DMA gate** — `ND_DMA_MASTER` wired to the real bus interface
  inside the core:
  - `Verilog/ND120_CORE.v:467` (floppy DMA master)
    and `:567` (SMD DMA master), each connected to the real `BIF_5` bus interface.
  - Driven by the top-level DMA test-client ports —
    `Verilog/ND120_TOP.v:104` ("DMA test client
    (full-RTL DMA gate: ND_DMA_MASTER against the real bus arbiter and RAM …)"),
    ports `DMA_REQ/DMA_WR/DMA_ADDR/DMA_WDATA/DMA_RDATA/DMA_ACK/DMA_ERR/DMA_BUSY`.
- The **real arbiter**, standalone-instantiable in iverilog:
  `Verilog/PAL/PAL_44801A.v` (PAL16R8 "BARB"), with
  an existing iverilog tb
  `Verilog/PAL/sim/PAL_44801A_tb.v`.
- The **BIF bus-control + freeze/grant** RTL:
  `Verilog/CPU-BOARD-3202/circuit/BIF_BCTL_6.v`
  (instantiates the arbiter), `BIF_BCTL_BDRV_7.v` (the DMA-request-freeze / grant
  search, documented at `:50–56`), `BIF_5.v` (the bus-interface wrapper).
- The **memory grant chain** already exercised in iverilog:
  `Verilog/CPU-BOARD-3202/circuit/sim/MEM_CHAIN_tb.v`
  (drives BCGNT/BLRQ) — **NOTE:** its gate `test-memchain` is the one known-failing
  entry in the suite (memory workstream); if Tier 1 reuses that RAM/grant slice,
  its state matters. See §8.
- The master's own recovery-gap logic and its tunables:
  `Verilog/ND-BUS-DEVICES/DMA/circuit/ND_DMA_MASTER.v`
  (`MIN_GAP_TICKS`, `EARLY_REREQ`, `HOLD_BINPUT` parameters, all unit-noted).
- Tier 0 gate:
  `Verilog/ND-BUS-DEVICES/FLOPPY-DMA/sim/nd_floppy_dma_tb.v`
  (`test-floppy-dma`, green).

**New (this plan):**

1. **Tier 1 tb** `test-floppy-p3` (or `test-dma-p3`) — `ND_DMA_MASTER` + real
   `PAL_44801A` + the real BIF freeze/grant logic + a **modelled** memory-cycle
   and refresh-timing wrapper (§4). iverilog, no Verilator, no CPU. Startable in
   the device lane **iff** §8 open decision 1 resolves that the real
   arbiter/freeze logic is instantiable without the CPU cycle fabric.
2. **Tier 2 revival** — when Verilator is unfenced, a dedicated DMA-only harness
   over the existing `DMA_*` top-level ports (no CPU program needed) to
   cross-check Tier 1's timing model. **Deferred + coordinated** with the
   CPU-core owner.

---

## 4. Deliverable — the Tier 1 tb (design)

**Instantiate the real arbiter, model only the memory-side timing.**

The honest constraint (traced, not assumed): `BIF_5` is **not** a clean CPU-free
slice. `Verilog/CPU-BOARD-3202/circuit/BIF_5.v:30–80`
shows ~40 inputs pulled from across the CPU-board fabric — microcode bits (`MIS0`,
`WRITE`, `MWRITE_n`, `TERM_n`, `RT_n`), the CPU data bus (`CD_15_0`), the
cycle-timing chain (`OSC`, `GNT50_n`, `BDAP50_n`, `BDRY50_n`), refresh (`REFRQ_n`),
parity/error (`PS_n`, `PA_n`, `LERR_n`, `MOR25_n`), power (`PD1/PD3`), semaphore.
And the arbiter `PAL_44801A`
(`Verilog/PAL/PAL_44801A.v:29–49`) is a **cycle-state
machine** clocked by `OSC` and gated by `CRQ_n`/`IORQ_n`/`REFRQ50_n` — its
grant/refresh interleave (the thing that loses every second read) is a *product of
that timing chain*, not of a standalone part.

So Tier 1 cannot be "the real board minus the CPU." It is deliberately narrower:

- **Real:** `ND_DMA_MASTER`, `PAL_44801A`, and the BIF DMA-request-freeze / grant
  search (`BIF_BCTL_BDRV_7.v`), wired exactly as `BIF_BCTL_6` wires them.
- **Modelled (the fidelity limit):** a small tb wrapper that supplies the
  arbiter's *memory-cycle timing environment* — `OSC` ticks, the BLRQ/BCGNT
  25/50 ns grant-recovery stages, `BDRY25_n`, and a periodic `REFRQ50_n` refresh —
  plus a RAM behind a `BMEM/BAPR/BDAP/BDRY` handshake that honours the recovery
  delay the `MIN_GAP` comment describes.

**Assertions (the adjudication):**

1. With the recovery-timing wrapper active and `MIN_GAP_TICKS = 0`, back-to-back
   single-word reads **reproduce "every second read lost"** — the exact §1
   symptom, now against the real arbiter.
2. With the default `MIN_GAP_TICKS = 32`, **all** transactions land correctly.
3. **Sweep** `MIN_GAP_TICKS` to find the minimum value that passes against the
   modelled timing, and record the margin.
4. Cross the outcome against Tier 0: if the hand-BCU tb passes the identical
   pattern that Tier 1 fails at gap 0, that **proves the 7/8 errors were the
   harness masking the timing, i.e. the device needs the gap** — the §8 verdict.

This is a *second* description of the memory timing (the wrapper), so — like the
`TANG-LATCH-EMULATION.md` §4.2 fallback — it can rot. It is a stepping stone; the
**Tier 2 Verilator gate remains the timing authority** and must confirm the sweep
threshold once Verilator is unfenced.

---

## 5. Reconciliation with the campaign docs (do this when adopted)

- `CONFORMANCE.md` §8: change "Combined-tb 7/8 DMA errors — unresolved" to cite
  the Tier 1 finding (harness-masked timing) + the Tier 2 authority once run.
- `PLAN-floppy-validation.md` §"Phase 3": note that (b) "the real board bus RTL"
  splits into Tier 1 (real arbiter, modelled memory timing, iverilog) and Tier 2
  (full-RTL, Verilator), because `BIF_5` is not CPU-separable (§4).
- **Not editing either doc yet** — left intact until this approach is approved, to
  avoid churning docs a concurrent session may be reading.

---

## 6. Constraints honoured

- **No Verilator, no runSim** (current standing constraint): Tier 1 is pure
  iverilog. Tier 2 is explicitly deferred.
- **CPU-board RTL is another agent's** right now: this plan **reads** that RTL and
  proposes to **instantiate** it read-only in a new device-lane tb — it edits none
  of it. The Tier 2 revival is gated on coordination.
- **Device lane only** for anything startable now: the new tb lands under
  `Verilog/ND-BUS-DEVICES/DMA/sim/` (or
  `FLOPPY-DMA/sim/`), registered in
  `Verilog/tests/run_all_tests.sh` with a strict
  `TB_RESULT: PASS`.

---

## 7. Open decisions (do not guess)

1. **Is the real arbiter + BIF freeze/grant instantiable without the CPU cycle
   fabric?** §4 shows `BIF_5` is not; the question for Tier 1 is whether the
   *inner* slice (`PAL_44801A` + `BIF_BCTL_BDRV_7` freeze/grant) can be driven by a
   tb-supplied `OSC`/`CRQ_n`/`IORQ_n`/`REFRQ50_n` environment and still exhibit
   the grant behaviour faithfully. **[ASSUMPTION]** yes for the grant/back-to-back
   behaviour, since that logic is local to the arbiter + freeze register; needs a
   read of `BIF_BCTL_6.v`'s internal wiring to confirm the minimal driven set.
2. **Memory-cycle timing model fidelity.** How faithfully must the BLRQ/BCGNT
   25/50 ns recovery + refresh interleave be modelled for the sweep threshold to
   mean anything? This is the piece only Tier 2 can validate — Tier 1's number is
   provisional until then. Needs the CPU-board-RTL owner's input on the real
   stage timing.
3. **Reuse `MEM_CHAIN` or model fresh?** `MEM_CHAIN_tb.v` already drives BCGNT/BLRQ,
   but `test-memchain` is failing. Decide whether Tier 1 borrows that RAM/grant
   slice (and inherits its state) or builds an independent minimal model. **[LEAN]**
   independent minimal model, to keep the P3 gate green-able regardless of the
   memory workstream.
4. **Wait for Verilator instead?** A Tier 1 gate that cannot be cross-checked
   against Tier 2 is a weak gate. Option: park P3 until Verilator is unfenced and
   do Tier 2 directly (cycle-accurate, authoritative). **[LEAN — recommend]** park,
   unless a fast iverilog reproduction of "every second read lost" against the real
   arbiter is wanted now as an early smoke test.

See also:
`Verilog/floppyTester/CONFORMANCE.md`,
`Verilog/floppyTester/PLAN-floppy-validation.md`,
`Verilog/ND-BUS-DEVICES/DMA/circuit/ND_DMA_MASTER.v`,
`Verilog/PAL/PAL_44801A.v`,
`Verilog/CPU-BOARD-3202/circuit/BIF_5.v`.

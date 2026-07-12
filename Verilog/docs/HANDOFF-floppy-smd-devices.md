# HANDOFF - floppy / SMD / DMA / tape device work

**Written:** 13-JUL-2026. **Branch:** `clock-enable-fix`.
**Goal (Ronny's priority):** get **floppy (1560) and SMD (1540) working on the
ND120** - NOT the standalone DMA test client, which is only a bus-engine
exercise.

**RULE ABOVE ALL:** ASSUME NOTHING. Verify in the code or ASK Ronny. Do not
infer owners, state, or intent. (This handoff itself only states things that
were verified this session; unknowns are marked UNKNOWN.)

---

## Done and committed this session (commit `ae2cfa9`)

Verified, not assumed:

1. **SMD `dma_err` (review C3) - FIXED.**
   `ND-BUS-DEVICES/SMD/circuit/ND_SMD.v`: both DMA states (`E_MEM_WR`,
   `E_MEM_RD`) now check `dma_err` with `dma_ack`; on a bus/memory timeout
   they set `s_hw_err` (status **bit 7** "hardware error / no memory
   contact", which ORs into **bit 4**) and abort to `E_DELAY` instead of
   silently completing with corrupt data. A fresh command clears the bit.
   New tb **test 7** in `ND-BUS-DEVICES/SMD/sim/nd_smd_tb.v` injects a DMA
   timeout via a new `mem_stall` flag and asserts the error + recovery.
   `make test-smd` -> `TB_RESULT: PASS`. Already in `run_all_tests.sh:81`.
   Which-bit question is now settled: **bit 7**, no invented bit.

2. **DMA full-RTL gate + OPCOM cross-check - PASS.**
   - `make test-dma-rtl` (pre-existing) verified: `[dmatest] RESULT: PASS`.
   - NEW `make test-dma-xcheck` (`Verilog/Makefile`): CPU deposits known
     words via OPCOM, `ND_DMA_MASTER` DMA-reads the same word addresses,
     asserts equality -> `[dmaxcheck] RESULT: PASS`. Proves DMA and CPU
     address the same memory; confirmed `DMA_ADDR` is a WORD address.
   - Harness added by me in `runSim/Run120.cpp` (`dma_xcheck_tick`,
     `SCRIPT_CMD_DMAXCHECK`), purely additive + env-gated (`ND120_DMA_XCHECK`),
     compiled only under `ND120_VERILOG_DEVICES` - golden console gate
     untouched. Plan doc: `docs/dma-test-plan.md`.

3. **Floppy `E_FINAL` / real `status2` fix is in the tree** (author UNKNOWN -
   was uncommitted when I arrived, now committed in `ae2cfa9`). Per
   `ND-BUS-DEVICES/FLOPPY-DMA/NEVER-READY-ANALYSIS.md` it fixes the TPE
   "Device ... Never Ready / Status:000003" hang: `E_FINAL` re-writes the
   command-block status word (CB+6) READY=1/BUSY=0 at completion, and a real
   `s_status2` register is loaded from a new `disk_media_fmt` input.
   **NOT verified by me at the `1560&` boot level** (blocked - see below).

---

## Ronny's standing rulings this session (do not re-litigate)

- **One tape drive on the bus.** Keep the C `PaperTape` / `FloppyPIO` classes
  in the source tree, but **NO C driver drives the ND120 bus** - all bus
  activity (IOX, interrupts, IDENT, DMA) comes from the Verilog device stack
  (`ND_TAPE_400`, `ND_FLOPPY_DMA`, `ND_SMD`) only. The C side may still feed
  tape *bytes* into `TAPE_BYTE_*` from a file (data, not bus activity). This
  also erases the level-12 interrupt storm, which lives entirely in the C
  `PaperTape` bus/interrupt path (`simDevices/NDDevices.cpp`
  `SetInterruptStatus` per control-write; ~46K interrupts for a 23K-word
  BPUN). See `docs/BUG-tape400-sd-level12-storm.md`.
- Priority is floppy+SMD working, not the DMA test client.

---

## OPEN work (the plan)

Recommended order (Ronny to confirm): SMD C1 -> SMD C2 -> floppy criticals.

1. **SMD C1** (data-destroyer, do first) - word-count 0 not guarded; wraps to
   64K and DMAs over ND memory + disk image. `docs/smd-review-findings.md`.
2. **SMD C2** - invented linear geometry instead of real CHS.
3. **Floppy criticals C1/C2/C3** (`docs/floppy-review-findings.md`): sector-
   count mode missing, absent-drive wedge, partial-write stale tail.
   **MUST re-verify against the just-committed `ND_FLOPPY_DMA.v`** - it got
   the `E_FINAL` changes and I do NOT know if the criticals were touched.
4. **Verify the floppy fix** at runSim `1560&` (TPE banner appears) - blocked.
5. **Tape flip** - make the Verilog stack the sole bus path, C off the bus,
   re-baseline the golden console log, rework `test-tape` from a C-vs-Verilog
   equivalence check into a single Verilog-tape boot gate - blocked.

---

## BLOCKED / COORDINATION (verified via Ronny relaying the other session)

There **is** another active session (Ronny confirmed - not my inference now).
It is doing instruction-verify + an MPY-overflow probe and has a **live
background build** against `Run120.cpp`, `NDBus.cpp`, `ND120_TOP.v`.

**DO NOT** edit `runSim/Run120.cpp`, `simDevices/NDBus.cpp`, `ND120_TOP.v`, or
rebuild `runSim/obj_dir` until Ronny says that session is done. This blocks
items 4 and 5 above.

Safe to work now (own iverilog builds, not in the hands-off list):
`ND-BUS-DEVICES/SMD/*` and `ND-BUS-DEVICES/FLOPPY-DMA/*` - BUT confirm with
Ronny that nothing is actively editing `ND_FLOPPY_DMA.v` first (item 3).

Disclosure already made to Ronny: earlier this session (before the other
session's boundaries were known) I edited `Run120.cpp` (the DMA cross-check)
and rebuilt `runSim/obj_dir` twice. So `Run120.cpp` has interleaved
uncommitted-then-committed work from more than one author; `ae2cfa9` snapshots
it all (Ronny said "don't untangle, just commit").

---

## Two questions pending for Ronny (tomorrow)

1. Is anything actively editing `ND_FLOPPY_DMA.v` right now, or safe to work?
2. Priority: SMD C1/C2 first (recommended - C1 is a data-destroyer), or floppy
   criticals first?

## The other session's ask (relayed, for whoever picks it up)
MPY sets overflow via microcode+databus (FIDBO / STS,LO) gated by a
`COND,F=0` branch at 004431/004432, not only the ALU OVF->D1 auto path.
Schematic-review asks: (a) `CGA_ALU_STS.v` `GATES_1` NAND inputs -> `bit5_D1 =
OVF | STS5`; (b) `MUX31LP` select truth table vs `CSTS_1_0` for the `STS,LO`
write (does it select D0/FIDBO for bit 5); (c) `OVF` generation in
`CGA_CPU_ALU_RALU.v` (`s_ovf_out` from `s_ovf1/s_ovf2`) - valid at the sampled
microcycle? Read-only, in CGA files - no device-file collision.

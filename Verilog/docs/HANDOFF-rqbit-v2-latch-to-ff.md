# HANDOFF — refactor CGA_INTR_CNTLR_IRQ_REG_RQBIT into a loop-free V2

Written 15-JUL-2026. Branch `clock-enable-fix`. Repo root `/mnt/e/Dev/Repos/Ronny/nd-120`.
All paths absolute — this doc is read cold. Do NOT mention any AI tool in code,
comments, commits, or docs.

## The job (in one line)
Create a NEW module `CGA_INTR_CNTLR_IRQ_REG_RQBIT_V2` that is **functionally
identical** to `CGA_INTR_CNTLR_IRQ_REG_RQBIT` but contains **no combinational
feedback loop** (a real edge-triggered register instead of the cross-coupled
OR/NAND SR latch). Prove it identical with the testbenches, then — and only
then — swap the parent over to V2.

## Why this matters (three symptoms, one root cause)
The current RQBIT holds its request in a cross-coupled async SR latch
(`s_ff_or_out` ↔ `s_ff_nand_out`). That combinational loop is confirmed to:
1. **block the OSS FPGA flow** — yosys/nextpnr reject it (22 combinational loops,
   all in these RQBIT latches); see memory `tang-oss-flow-comb-loops`.
2. **hang a plain event simulator** — driving the parent `CGA_INTR_CNTLR` request
   path from X-init makes these NAND latches oscillate (iverilog times out).
3. **be the leading suspect for the Tang `400$` silicon hang** — see
   `/mnt/e/Dev/Repos/Ronny/nd-120/Verilog/docs/HANDOFF-tang-sd-tape-boot.md` and
   memory `tang-400-hang-validated`: RQBIT_2 latches the tape's level-12 request
   and, on Gowin fabric, the async feedback can glitch/fail-to-hold where
   zero-delay Verilator settles cleanly.

Removing the loop (V2 as a synchronous register) is expected to fix all three at
once. This experiment is also the test of that theory: after V2, re-run the OSS
flow and see whether the 22 loops are gone.

## Files — READ these (do not trust this summary; read the source)
- RTL to replace:
  `/mnt/e/Dev/Repos/Ronny/nd-120/Verilog/DELILAH-CPU/CGA_INTR/circuit/CGA_INTR_CNTLR_IRQ_REG_RQBIT.v`
  (the SR latch is `GATES_1..4` + `MEMORY_5`; `INR = qBar`).
- The behaviour CONTRACT (already reverse-engineered from the gates, exhaustively
  checked against the DUT) is documented in the header of:
  `/mnt/e/Dev/Repos/Ronny/nd-120/Verilog/DELILAH-CPU/CGA_INTR/sim/CGA_INTR_CNTLR_IRQ_REG_RQBIT_tb.v`
  — read that header. The reduced synchronous behaviour it proves is:
  on each rising `CP` (=MCLK): `if (CLR) L<=0; else if (!PN) L<=1; else HOLD;`
  `INR = L`. PN = request active-LOW, CLR = clear active-HIGH (dominates),
  INR = pending active-HIGH. `CPN` is driven as `~CP`.
- Parent that instantiates RQBIT (this is where the SWAP happens — find the
  instantiation and confirm the port wiring):
  `/mnt/e/Dev/Repos/Ronny/nd-120/Verilog/DELILAH-CPU/CGA_INTR/circuit/CGA_INTR_CNTLR_IRQ_REG.v`
- FF primitive + mode handling (V2 must keep this):
  `/mnt/e/Dev/Repos/Ronny/nd-120/Verilog/Shared/ndlib/` (the `D_FLIPFLOP_EN`
  used by RQBIT) and the `FPGA_FF_MODE` / `MCLK_EN` pattern already in RQBIT.v
  lines 51-58, 116-129. Also `docs/plan-fix-unconstrained-clocks.md`.
- Logisim gate primitives (bubble/inversion semantics) for deriving the golden:
  `/mnt/e/Dev/Repos/Ronny/nd-120/Verilog/Shared/logisim/`
- Context / rules:
  `/mnt/e/Dev/Repos/Ronny/nd-120/Verilog/docs/HANDOFF-interrupt-trap-testbenches.md`
  (the 29 interrupt/trap testbenches, the generic `iv-%` runner, how they are
  registered), memory `p2-domains-convert-together`, `ff-exec-divergence-fixed`,
  `clock-enable-refactor`.

## V2 requirements (drop-in)
- Same module name suffix `_V2`, in
  `/mnt/e/Dev/Repos/Ronny/nd-120/Verilog/DELILAH-CPU/CGA_INTR/circuit/CGA_INTR_CNTLR_IRQ_REG_RQBIT_V2.v`.
- **Identical port list** to RQBIT (`sysclk, MCLK_EN, CLR, CP, CPN, PN → INR`) so
  it is a pure drop-in.
- **No combinational feedback loop** — the request is held in an edge-triggered
  flip-flop, not a cross-coupled latch.
- **Keep both build modes working**: the `FPGA_FF_MODE`/`MCLK_EN` capture path
  (posedge `sysclk` gated by `MCLK_EN`) and the non-FF path (posedge `CP`), the
  same way RQBIT does today via `D_FLIPFLOP_EN`. Behaviour must match the
  original in BOTH modes.
- Functionally identical to RQBIT for every input sequence the (extended)
  testbench exercises.

## EXTEND THE TESTBENCHES TO TEST **ALL** SCENARIOS  ← mandatory, do this first
The existing tb
(`/mnt/e/Dev/Repos/Ronny/nd-120/Verilog/DELILAH-CPU/CGA_INTR/sim/CGA_INTR_CNTLR_IRQ_REG_RQBIT_tb.v`)
covers persistence/clear/hold + a randomized soak, but it drives inputs only
while `CP=0` and only in non-FF mode. Before trusting V2, EXTEND it (and add a
V2 tb, or better: one tb that instantiates BOTH RQBIT and RQBIT_V2 and asserts
their `INR` is bit-identical every step) to cover EVERY scenario, including:
- both modes: `FPGA_FF_MODE` defined (MCLK_EN gated) AND not defined;
- exhaustive `(latch-state, CLR, PN)` transitions from BOTH states (already
  partly there) — keep it exhaustive;
- input changes at different phases relative to `CP` (mid-high, near the edge,
  glitches on PN/CLR between edges) — this is where an async latch and a clean
  FF could legally differ; characterise it and decide what "identical" means
  under the real `CGA_INTR_CNTLR` timing discipline;
- `CLR` and `!PN` asserted simultaneously (clear dominates);
- long multi-clock HOLD; repeated set/clear; back-to-back edges;
- power-on / X-init behaviour (the original oscillates from X — V2 must reach a
  defined state);
- `MCLK_EN` de-asserted for several `sysclk` (no capture) then asserted.
Keep the `-DTEETH_TEST` perturbation and the `TB_RESULT: PASS/FAIL` verdict.
A dual-instantiation equivalence tb (RQBIT vs RQBIT_V2, assert equal) is the
strongest proof and is the preferred deliverable.

## Validation gates (in order — do NOT swap until all green)
1. Extended unit tb: RQBIT_V2 matches RQBIT bit-for-bit over ALL scenarios above;
   `TB_RESULT: PASS`; teeth (`-DTEETH_TEST`) forces FAIL. Run via the generic
   rule: `make -C /mnt/e/Dev/Repos/Ronny/nd-120/Verilog/DELILAH-CPU/CGA_INTR/sim iv-<tbname>`.
2. Do the SWAP: change the instantiation in
   `.../CGA_INTR_CNTLR_IRQ_REG.v` from RQBIT to RQBIT_V2 (keep RQBIT.v on disk).
3. The 29 interrupt/trap tbs still pass, especially the CNTLR-top tb
   (`.../sim/CGA_INTR_CNTLR_tb.v`) and IRQ tbs — run them via the `iv-%` rule.
4. Behaviour-neutral at the system level: `cd /mnt/e/Dev/Repos/Ronny/nd-120/Verilog/sim
   && make compare` — the latch-vs-FF golden traces
   (`trace_ff.csv`/`trace_latch.csv` vs `sim/golden/*`) must stay byte-identical.
   Also the full unit suite: `cd /mnt/e/Dev/Repos/Ronny/nd-120/Verilog && make test`.
5. THE PAYOFF CHECK: run the OSS FPGA flow and confirm the combinational loops
   are gone — `cd /mnt/e/Dev/Repos/Ronny/nd-120/Verilog/fpga/tang-nano-20k && make all`
   (yosys → nextpnr-himbaechel → gowin_pack). If nextpnr now PnRs (no
   "combinational loop" errors), the theory holds. (Do NOT flash hardware — that
   is Ronny's; report that a board run is the final proof of the `400$` hang fix.)

## Notes / landmines
- There are 16 request bits (RQBIT ×16 in IRQ_REG) — the swap at the IRQ_REG
  instantiation covers all of them. There are also PICMASK mask-bit latches
  (`CGA_INTR_CNTLR_IRQ_MASK_MASKBIT`) of the same async-latch family; those are a
  SEPARATE follow-up, out of scope here unless Ronny says otherwise — but note
  the OSS flow may still see loops from THEM until they are converted too. Report
  the remaining loop count after the RQBIT swap.
- Prior lesson (memory `p2-domains-convert-together`): same-edge cross-domain
  transfers can break if converted piecemeal — if the goldens diverge after the
  swap, that is the signal, investigate before forcing it.
- Never start a Verilog comment with the word "verilator" (lexes as a metacomment;
  `-Wno-*` can't suppress it) — memory `verilator-comment-gotcha`.
- Keep RQBIT.v in place until the swap is proven; the swap is a one-line
  instantiation change in IRQ_REG.v, easy to revert.
- Do not commit without Ronny's explicit permission; no "claude" in any commit.

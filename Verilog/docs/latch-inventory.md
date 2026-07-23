# ND-120 Datapath Latch Inventory (latch → clock-enabled-FF refactor)

**Full path:** `/mnt/e/Dev/Repos/Ronny/nd-120/Verilog/docs/latch-inventory.md`
**Created:** 2026-07-07

## SOLVED (2026-07-07) — see the summary before the refactor plan below

The root cause was NOT that the latches needed converting to clock-enabled FFs.
It was that the `sysclk`-sampled latch model (`always @(posedge sysclk) if(L)
reg<=D`) was itself the bug — a retrofit that sampled the latch enable on an
unrelated clock, racing the data in zero-delay sim. FIX (commit `8876b4a`):
model `L8`/`L4`/`LATCH` as REAL transparent latches — combinational
`always @(*) if(L) reg=D` in latch mode, synthesizable `assign Q = L ? D : reg`
(mux over a sysclk-held FF) in FF mode. Result: CPU self-test STERR 18→0 in BOTH
modes, FF address sequence byte-identical to latch (seqcheck PASS), and **the
Basys3 FPGA runs OPCOM for the first time.** The per-latch refactor plan below is
retained as reference but was superseded by this simpler model fix.

---


Complete map of every transparent/sysclk-sampled latch in the CGA datapath, for the
latch→FF conversion. Goal: make the **FF-mode Verilator** (`FPGA_FF_MODE`) match the
FPGA by converting these fragile latches to deterministic clock-enabled FFs, while
keeping **latch mode** (`USE_LATCHES=1`, default `runSim`) as the golden reference.

## Why this matters

All three latch primitives share one fragile pattern:
```verilog
always @(posedge sysclk) if (enable) reg <= D;   // samples PRE-edge D → zero-delay race
```
In zero-delay Verilog the capture races the data path (data becomes valid *at* the
same sysclk edge). Only real-silicon propagation delay makes it work on the FPGA.
Proven at the console-baud read: the FPGA reads o5670 (correct), both latch- and
FF-mode Verilator read o5660 (stale). See
`memory/sim-vs-fpga-idb-read-race.md`.

## The 14 datapath latches (L8 / L4 / LATCH — all sysclk-sampled)

### CGA_MIC — microcode / control (4)   ← the console-baud jump race
| Latch | Register / role | Enable | Data → Output | File:line |
|---|---|---|---|---|
| `L8 IRLATCH` | Instruction Register (**race #1**) | `s_ldirv` (LDIRV) | `s_cd_15_0[6:0]` → `s_ir_6_0` | `DELILAH-CPU/CGA_MIC/circuit/CGA_MIC.v:783` |
| `L8 WL_HI` | MASEL next-addr W (hi) (**race #2**) | `s_mclk_n` | `s_rep_12_0[12:5]` → `s_w_12_0_out` | `DELILAH-CPU/CGA_MIC/circuit/CGA_MIC_MASEL.v:283` |
| `L8 WL_LO` | MASEL next-addr W (lo) | `s_mclk_n` | `s_rep_12_0[4:0]` → `s_w_12_0_out` | `DELILAH-CPU/CGA_MIC/circuit/CGA_MIC_MASEL.v:320` |
| `LATCH CSEL_LATCH` | Condition select (ALUCLK/CSEL) | (see file) | → `s_cond_n_out` | `DELILAH-CPU/CGA_MIC/circuit/CGA_MIC_CSEL.v:156` |

### CGA_MAC — memory address (6)
| Latch | Role | File:line |
|---|---|---|
| `L8 L_HI` / `L8 L_LO` | APOS address calc | `DELILAH-CPU/CGA_MAC/circuit/CGA_MAC_APOS_CALCA.v:234,199` |
| `L8 PCR_HI` / `L4 PCR_LO` | PCR register | `DELILAH-CPU/CGA_MAC/circuit/CGA_MAC_SEGPT_PCR.v:76,110` |
| `L8 SEG_L` | Segment | `DELILAH-CPU/CGA_MAC/circuit/CGA_MAC_SEGPT_SEG.v:82` |
| `L4 XPT_L` | XPT | `DELILAH-CPU/CGA_MAC/circuit/CGA_MAC_SEGPT_XPT.v:103` |

### CGA_WRF — write register file (4)
| Latch | Role | File:line |
|---|---|---|
| `L8 L_15_8` / `L8 L_7_0` | LR16 register | `DELILAH-CPU/CGA_WRF/circuit/CGA_WRF_RBLOCK_LR16.v:214,250` |
| `L8 L_PR_7_0` / `L8 L_PR_8_15` | PREG | `DELILAH-CPU/CGA_WRF/circuit/CGA_WRF_RBLOCK_PREG.v:191,228` |

## Latch primitives (Shared/ndlib)
- `L8.v`, `L4.v` — 8/4-bit gated latch, `always @(posedge sysclk) if (L) reg<=D`.
- `LATCH.v` — 1-bit, `always @(posedge sysclk) if (ENABLE) regD<=D`.

## Plus 9 `USE_TRANSPARENT_LATCHES` sites (latch↔FF conditional, separate from above)
8 PALs — `PAL_44302B, 44303B, 44304E, 44310D, 44401B, 45001B, 45008B, 45009B` — and
`Shared/support/AM29841.v`. `ND120_TOP.v:21-25` derives `USE_TRANSPARENT_LATCHES =
VERILATOR_SIM && !FPGA_FF_MODE`. NOTE: the PALs are hand-converted PALASM golden
source — do NOT edit them directly; any latch/FF change goes through their existing
`USE_TRANSPARENT_LATCHES` guard.

## Refactor plan
1. **Pilot: the jump path** — `IRLATCH` (LDIRV) + `WL_HI`/`WL_LO` (MCLK_n). Convert to
   coherent clock-enabled FFs so the captured data is stable before the edge.
   Acceptance gate: FF-sim baud read flips o5660 → **o5670** AND `sim/seqcheck.py`
   stays clean (boot sequence unchanged vs latch reference).
2. **Roll out** the same pattern to the remaining 11 datapath latches, validating each
   against seqcheck + the baud read.
3. Keep `USE_LATCHES=1` (latch mode) as the golden reference throughout; the refactor
   only improves the `FPGA_FF_MODE` path to be phase-deterministic.

Transparent-latch semantics to preserve: Q holds the value D had when `enable` fell.
The FF conversion must capture that same settled value on a sysclk edge, coherently
phased with the data path (the crux — a naive `if(L) reg<=D` samples stale D).

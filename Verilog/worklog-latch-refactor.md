# Worklog — LATCH refactor (CSEL_LATCH)

## Full path
`E:\Dev\Repos\Ronny\nd-120\Verilog\worklog-latch-refactor.md`

## Branch
`redo-idb`

## Current state at this entry
- `Shared/ndlib/LATCH.v` — level-sensitive sysclk capture (no ifdef)
- `DELILAH-CPU/CGA_MIC/circuit/CGA_MIC_CSEL.v` — has new `sysclk` port, threads to `CSEL_LATCH`
- `DELILAH-CPU/CGA_MIC/circuit/CGA_MIC.v` — passes `sysclk` to `CGA_MIC_CSEL CSEL`
- `CPU_CS_ACAL_17.v` and `CPU_CS_16.v` — untouched, still at FF+CE pattern from last reviewed commit
- `AM29841.v` and its instantiation in `CPU_PROC_32.v` — untouched

## Commits on this branch (newest first)
- `ee3806e` — Phase 1: route LATCH.v through sysclk (drop posedge-ENABLE pattern)
  - This commit did the **edge-detect** version of LATCH.v
  - **Replaced in working tree (not yet committed)** by the level-sensitive version
- `6af6fd9` — Baseline before latch refactor: tooling updates only
- `d04a09d` — Fix MIPANS dispatch, ACAL LUA lag, FPGA timing, and ILA debug probes (the previous reviewed state of ACAL/CSEL)

## Observations and decisions

### Phase 1a — edge-detect LATCH (committed as ee3806e)
- Replaced `always @(posedge ENABLE) regD <= D;` with sysclk + `if (ENABLE & ~en_prev)`.
- Verilator: passes (`runSim` reaches OPCOM as before).
- FPGA: **broken**. LCS load gets stuck at `CSA=o000231`.
- Root cause: during LCS load, `s_aluclk_n` is held high constantly
  (because `s_lcs=1` makes `ALUCLK = 0` fixed). No rising edge on `ENABLE`
  ever appears, so the edge-detect FF only fires once (or zero times)
  during reset and then is stuck. `CSEL_Q` ends up frozen at the init
  value `0`, which causes the microcode at `o000231` to take a wrong
  conditional path and self-loop.

### Phase 1b — level-sensitive LATCH (current working tree, not yet committed)
- `always @(posedge sysclk) if (ENABLE) regD <= D;`. Equivalent to
  `L4.v` / `L8.v`. Removes the LCS-load failure mode by tracking D
  whenever ENABLE is high.
- Verilator: still reaches OPCOM, but a **slight behavioural regression**
  was observed:
  - In the BPUN program's `HELP` command output, two lines of `*******`
    that used to print under text headers are now missing.
  - Hypothesis: original `posedge ENABLE` captured D at *start* of the
    idle window; level-sensitive sysclk captures D at *end* of the idle
    window. Some `s_pcond_n` MUX inputs change late in the idle window,
    so the two patterns disagree on a small number of conditional
    branches.
- FPGA: **not yet tested with this version.**

## Decision
Proceed to FPGA build with the level-sensitive version. The FPGA result
will tell us whether `s_aluclk_n` being constant-high during LCS load is
indeed the root cause of the stuck-at-`o000231` failure.

If LCS load completes on FPGA but the BPUN regression matters,
investigate a hybrid pattern (edge-detect that also handles the
constant-high case explicitly).

## Rollback procedures

### Rollback the working-tree level-sensitive change (keep commit ee3806e)
```
cd E:/Dev/Repos/Ronny/nd-120/Verilog
git checkout Shared/ndlib/LATCH.v
```
This restores the **edge-detect** version that is committed on `ee3806e`.

### Rollback the entire LATCH refactor (back to before Phase 1)
```
cd E:/Dev/Repos/Ronny/nd-120/Verilog
git revert ee3806e
```
This re-introduces `posedge ENABLE` semantics in `LATCH.v` and removes
the new `sysclk` port from `CGA_MIC_CSEL.v` / `CGA_MIC.v`. Use this if
both edge-detect and level-sensitive turn out to be wrong on FPGA and
you want to go back to the last reviewed FPGA build (commit `d04a09d`
state of LATCH).

### Rollback to the absolute baseline before this work session
```
cd E:/Dev/Repos/Ronny/nd-120/Verilog
git reset --hard 6af6fd9
```
**Destructive.** Discards `ee3806e` and any uncommitted edits in the
Verilog tree. Tooling state (Makefile, vivado_build.tcl, etc.) is
preserved. Use only if everything from Phase 1 onward needs to be
discarded.

### Rollback to the last reviewed reference commit (d04a09d)
```
cd E:/Dev/Repos/Ronny/nd-120/Verilog
git reset --hard d04a09d
```
**Destructive.** Drops all of `redo-idb`'s extra commits (`6af6fd9`,
`ee3806e`) and any uncommitted edits. This is the state from before any
of the latch-refactor experiments.

## What is NOT changed and why
- `AM29841.v` and `CHIP_25F` (in `CPU_PROC_32.v`) — `LE = s_mclk` is a
  1-sysclk pulse. Neither edge-detect nor level-sensitive on sysclk can
  capture this reliably. Needs the fast-clock approach
  (`fast-clock-design-ida.md`) or a different scheme.
- `CPU_CS_ACAL_17.v` — same problem with `MACLK`. Also needs the
  fast-clock approach. Currently still on FF+CE pattern from `d04a09d`.

## Open questions / next decisions
1. Does the level-sensitive `LATCH.v` make LCS load complete on FPGA?
2. If yes, does the o002335 MACL self-test still fail the same way (LUA
   lag in ACAL)?
3. Is the BPUN HELP regression a one-off cosmetic glitch, or evidence of
   deeper timing-mismatch problems?
4. Move ahead with the fast-clock design (Option B from
   `fast-clock-design-ida.md` — slower CPU clock from existing MMCM,
   latch sample clock stays at 100 MHz)?

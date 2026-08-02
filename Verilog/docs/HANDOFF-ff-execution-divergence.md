# HANDOFF: FF-mode program-execution divergence (Verilator)

**Full path:** `Verilog/docs/HANDOFF-ff-execution-divergence.md`
**Written:** 2026-07-07 · Repo: nd-120 (ND-120 CPU HDL) · Branch: `clock-enable-fix`

You are picking up ONE self-contained bug. Another engineer is working the UART/RAM
issues in parallel — **stay in your lane: only the FF-vs-latch execution divergence
below.** Do not touch `Shared/support/SC2661_UART.v`, `MEM_RAM_49.v`, or `SIP1M9.v`.

## The bug in one sentence
In the Verilator sim, running a loaded program (`0!` or `20!` in OPCOM) **works in
latch mode but hangs in FF mode** — even though the two modes were proven byte-
identical through boot. So there is a latch-vs-FF divergence in the instruction-
EXECUTION path that the boot `seqcheck` never exercised.

## Essential background (how this codebase's two modes work)
- `USE_LATCHES=1` (default, `make run`): **latch mode**, define `USE_TRANSPARENT_LATCHES`.
  Derived clocks are combinational; L8/L4/LATCH are true transparent latches.
- `USE_LATCHES=0` (`make run USE_LATCHES=0`): **FF mode**, define `FPGA_FF_MODE`.
  This is the FPGA path: derived clocks are FF-generated (`CYC_36.v` `aluclk_pa`/
  `clk_pa` registered on `sysclk`); L8/L4/LATCH are synthesizable mux+FF transparent
  latches (`assign Q = L ? D : reg` over a sysclk-held FF).
- Only 3 `FPGA_FF_MODE` sites differ: `CYC_36.v:171`, `CYC_36.v:300`, `ND120_TOP.v:24`.
- Recent win (commit 8876b4a, tag `fpga-opcom-working-basys3`): modelling the latches
  as REAL transparent latches drove CPU self-test STERR 18->0 and got OPCOM booting
  on the FPGA. Boot `sim/seqcheck.py` shows FF == latch byte-identical THROUGH BOOT.
  Your bug is the SAME CLASS (a phase-sensitive microcode branch) but in EXECUTION.

## What is already known (do not re-derive)
- Repro program: the sim auto-loads **INSTRUCTION-B** (1983 instruction-verify test,
  the `Word count 054731` loader output at boot). `0!` runs it from addr 0 (prints a
  header), `20!` from addr 20 (goes to the `>` test prompt).
- Instrumentation is ALREADY in `runSim/Run120.cpp` (guarded, committed-or-local):
  - `-DTRACE_CSA` logs `CSA_12_0` (octal) changes to `csa_trace.csv` after boot.
  - `-DSCRIPT_INPUT -DSCRIPT_CMD='"0!\r"'` auto-injects the command after the `#`
    prompt. CRITICAL: it injects with an inter-char gap (`g_next_inject_cnt += 300000`)
    because the SC2661 RX overruns if you type faster — keep that.
  - Makefile passes `EXTRA_CFLAGS`. Build+run example:
    ```
    cd runSim
    make clean && make compile EXTRA_CFLAGS="-DTRACE_CSA -DSCRIPT_INPUT" USE_LATCHES=1
    ./obj_dir/VND120_TOP </dev/null > out_latch.log ; mv csa_trace.csv csa_latch.csv
    make clean && make compile EXTRA_CFLAGS="-DTRACE_CSA -DSCRIPT_INPUT" USE_LATCHES=0
    ./obj_dir/VND120_TOP </dev/null > out_ff.log ; mv csa_trace.csv csa_ff.csv
    ```
- CONFIRMED RESULT: latch `0!` prints the full VERIFY header + IDENT device scan; FF
  `0!` prints NOTHING (just `#0!` then the cycle-budget stop) — it hangs, spinning in
  the instruction-fetch loop (FF has MORE `o0`/`o2001` fetches, 2.7M vs 2.3M, but no
  output progress).
- **FIRST CSA DIVERGENCE (the "goes to hell" point):** dedup both CSA streams
  (`awk -F',' '{if($2!=p){print $2;p=$2}}'`) and diff. They are identical until:
  common tail `... 145 0 2001 16000 0 6000 7250`, then **latch -> o143, FF -> o145**.
  So microcode CSA **o7250's conditional next-address goes o143 in latch, o145 in FF**
  (differs in bit 1). That is the exact phase-sensitive branch to explain.

## Your task
Find WHY `o7250`'s jump resolves to o143 (latch) vs o145 (FF), fix it so FF matches
latch (and thus the FPGA runs the program), WITHOUT breaking boot `seqcheck` or the
self-test STERR=0 gate.

1. Map CSA `o7250` / `o143` / `o145` to the actual microcode + the CGA_MIC next-address
   / condition logic. NOTE: the runtime CSA (13-bit, 0-8191) is the WCS address; the
   OCR'd listing `Code/Microcode/ND-120 Mikroprogramlisting-L-ocr.md` uses a different
   address column, so map carefully (the boot loads WCS from the AM27256 hex).
2. Identify the CONDITION o7250 branches on (a condition-code / status / flag). It is
   almost certainly a signal that is captured by one of the mux+FF transparent latches
   or a derived-clock FF, and is read one phase off in FF mode — the same failure shape
   as the baud-read jump documented in `memory/sim-vs-fpga-idb-read-race.md` and the
   fix in `memory/selftest-acceptance-gate.md`.
3. Fix it coherently (transparent-latch model or clock-enable phasing), the same
   discipline as commit 8876b4a. Validate: (a) FF `0!`/`20!` now runs INSTRUCTION-B
   (VERIFY header / `>` prompt appears in `out_ff.log`); (b) FF CSA == latch CSA past
   the o7250 point; (c) `cd sim && make compare_ff` -> `seqcheck.py` still PASS and
   STERR=0 (`awk 'NR>8193 && $1==1134' on the deduped exec trace` == 0).

## Key files
- `DELILAH-CPU/CGA_MIC/circuit/CGA_MIC.v` + `CGA_MIC_MASEL*.v` (next-address / jump mux)
- `CPU-BOARD-3202/circuit/CYC_36.v` (the 3 FF-mode clock sites)
- `Shared/ndlib/L8.v` / `L4.v` / `LATCH.v` (the transparent-latch model — reference only)
- `sim/seqcheck.py`, `sim/Makefile` (`make compare_ff` / `compare_latch`)
- Memory notes (context): `memory/selftest-acceptance-gate.md`,
  `memory/sim-vs-fpga-idb-read-race.md`, `memory/hw-timing-vs-verilog.md`
- Overall issue tracker: `docs/fpga-bringup-issues.md` (issue #2 is this bug)

## Hard constraints (from the repo owner)
- Never mention AI/Claude in commits or docs. No LINQ. No unicode in code/comments.
- Do NOT edit the PAL_*.v files (hand-converted PALASM golden source).
- Always compile before claiming success; the acceptance gates are seqcheck PASS +
  STERR=0, plus the program actually producing output in FF mode.

# HANDOFF: OPCOM console output is far too slow on the FPGA

**Full path:** `Verilog/docs/HANDOFF-opcom-output-speed.md`
**Written:** 2026-07-07 · Repo: nd-120 (ND-120 CPU HDL) · Board: Basys3 (xc7a35t) at
`clk_cpu ≈ 16.67 MHz` · Branch: `clock-enable-fix`

## The problem (repo owner's own words, and he is right)
On the real FPGA, OPCOM console OUTPUT is far too slow: **~5-10 characters take about
a second** (~100-200 ms PER CHARACTER). CPU execution itself is fast (restart -> `#`
prompt is instant; the `MACL` command returns to `#` immediately). So the CPU is fine
— it is the **rate at which characters are emitted** that is broken.

## What it is NOT (already ruled out — do not re-chase these)
- **NOT the baud rate.** 9600 baud = ~1 ms/char, so 5-10 chars would be ~10 ms, not
  1 s. Bumping to 115200 (done, commit 5cb849d) will NOT fix this and should probably
  be reverted or ignored for this issue. The owner correctly rejected the baud theory.
- **NOT the SC2661 TxEMT status flag.** There WAS a real bug there (SR2/TXEMT_n was
  read-cleared, wrong reset) — fixed in commit 196c444 and kept (no regression) — but
  re-synthesising with it did NOT change the speed. So OPCOM polls TxRDY (SR0, already
  correct), not TxEMT. Dead end for the speed issue.
- **NOT reproducible in the current Verilator sim.** The sim runs FASTER than real
  time and uses a sped-up UART (`SC2661_UART.v`: `DELAY_FRAMES=16` under VERILATOR_SIM
  vs `BOARD_CLK_FREQ/UART_BAUD_RATE=1736` on FPGA), so the per-char real-time gate is
  invisible. Any sim-based reproduction MUST first make the relevant timer(s) run at
  the real FPGA period (see "How to reproduce" below).

## The actual mechanism (root cause, from the owner's microcode analysis — TRUST THIS)
OPCOM's own output (prompts, register dumps — NOT programs like INSTRUCTION-B, which
use a different path) is emitted by the microcode routine **MOPC**, and MOPC sends
**at most ONE character per invocation**. MOPC is invoked from the **MS20** path — the
routine tied to the ~20 ms periodic (real-time-clock / panel) interrupt. So:

    output rate  =  how often MS20 -> MOPC runs and sends a char  =  the MS20 gate

and that gate is ~100-200 ms/char on the FPGA. **The fix is to make the MS20 -> MOPC
-> send happen much more often (or send more per pass), i.e. the "jmp to MS20" must go
quicker.** That is the owner's exact diagnosis and it is correct.

### Microcode map (octal CSA; source: `Code/Microcode/ND-120 Mikroprogramlisting-L-ocr.md`)
- `o2333` MS20 — entered on the ~20 ms interrupt; scans panel/mem-mgmt.
- `o2335` reads `IDBS.MIPANS` (memory-management panel request).
- `o2337` -> calls MOPC IF there is a panel request.
- `o2341` MOPC/MRET1: `AB,PRCHR ... COND,F=0` — read PRCHR (char to output); if 0,
  nothing to send.
- `o2342` `IDBS,IOR` — read UART status register into Q.
- `o2343` `A,16 ALUF,ANDDQ ... COND,F=0` (comment: **CC TBMT**) — check transmit-
  buffer-empty; only send if the buffer already drained. (20 ms >> 1 ms/char so this
  always passes — NOT the bottleneck.)
- `o2344` `A,17 ... OUTPT` (comment: **CC DA**) — check receive-data-available.
- `o2345` "OUTPUT STOPPED BY INPUT" — if input is waiting, read/discard, do not send.
- `o2347` `AB,PRCHR ... COMM,UART.DATA` — **THE SEND** (PRCHR -> UART data register).
- `o2350-2357` — post-send handling (CR/LF, multi-digit octal number continuation).

## Your task
Make OPCOM console output run at a usable speed on the FPGA (target: at least the
9600-baud limit, ~960 chars/sec, ideally faster). The lever is the MS20/MOPC
invocation rate, NOT baud and NOT the UART flags.

Investigate, in order:
1. **Find what generates the ~20 ms period** that gates MS20/MOPC on the FPGA. Likely
   the ND real-time-clock / panel interrupt. Candidate RTL: `CPU-BOARD-3202/circuit/
   IO_37.v`, `IO_PANCAL_40.v` (MC68705 panel-processor interface — MIPANS/MAPANS read
   at IO addr o20/o21, see `IO_37.v:290`), `IO_DCD_38.v`, `IO_REG_41.v:169`
   (`s_ioc_3` "clock interrupt generated from RTC trap handler"), and the interrupt
   controller `DELILAH-CPU/CGA_INTR/`. NOTE: a static grep for the timer counter did
   NOT find an obvious `VERILATOR_SIM`-gated period counter in the board I/O (only
   `MEM_RAM_49.v` has that guard), so the period may come from the panel processor
   model, an external bus interrupt, or a counter I did not locate — find it.
2. **Test the owner's half-speed hypothesis:** the design targets ~33 MHz but runs at
   16.67 MHz. If the RTC/panel period is a fixed clock-count calibrated for the faster
   clock, the real period DOUBLES (20 ms -> 40 ms), making output 2x slower than even
   intended. Check the counter's terminal value against `BOARD_CLK_FREQ`.
3. **Decide the fix.** Options, roughly in increasing invasiveness:
   (a) Recalibrate the RTC/panel timer for 16.67 MHz (fixes 40->20 ms; still only
       50 chars/sec — probably not enough alone).
   (b) Drive OPCOM output from a faster trigger — e.g. have the UART TxRDY (SR0)
       raise the panel/output request so MOPC runs at ~baud rate instead of the 20 ms
       tick. This is how console output "should" work (interrupt-at-baud), and is the
       most likely correct fix. Requires wiring TxRDY into whatever sets MIPANS / the
       panel request, WITHOUT breaking the 20 ms real-time-clock used for timekeeping.
   (c) Change the microcode so MOPC loops sending until PRCHR queue empty / TBMT busy
       (RISKY — microcode is original ND golden source; prefer not to).
   Whatever you pick, do NOT slow down or break the real-time-clock tick used for OS
   timekeeping, and keep the 20 ms interrupt itself intact.

## How to reproduce in Verilator (so you can iterate fast, not on 90-min FPGA builds)
The sim hides this because its UART and (effectively) its timer run fast. To see the
gate you must run the RELEVANT timer at the real FPGA period in a sim build:
- Instrumentation already exists in `runSim/Run120.cpp` (guarded, committed 138fcff):
  `-DTRACE_CSA` logs `CSA_12_0` (octal) to `csa_trace.csv`; `-DSCRIPT_INPUT
  -DSCRIPT_CMD='"..."'` auto-injects an OPCOM command after the `#` prompt (inject
  with the built-in inter-char gap or the SC2661 RX overruns). Makefile forwards
  `EXTRA_CFLAGS`.
- Reproduce OPCOM OUTPUT specifically: inject a command that makes OPCOM print via
  MOPC (o2347), e.g. repeated Enters (each re-emits `#`) or a register-examine, and
  measure the clock-spacing between consecutive `o2347` (=octal 2347) rows in the
  trace. On a proper repro the spacing should be the real ~20 ms (~333k clocks at
  16.67 MHz) or ~40 ms (~666k). (My earlier ~8240-clock spacing was MS20 reached via
  the OPCOM idle loop during an INSTRUCTION-B run where o2347 was never hit — it was
  NOT the output gate. Do a real OPCOM-output repro.)
- Consider forcing the FPGA UART timing in the sim (temporary: make the SC2661
  `DELAY_FRAMES` use the FPGA formula even under VERILATOR_SIM) so the TBMT interaction
  is realistic while you measure.
- Validate a fix by: (i) the o2347 send spacing drops dramatically in the repro;
  (ii) `cd sim && make compare` -> `seqcheck.py` PASS and self-test STERR=0 still hold
  (do not regress boot); (iii) confirm on one FPGA synth that a register dump is snappy.

## State of the tree / related work (coordination)
- Commit 196c444: SC2661 TxEMT fix (kept, not the cause).
- Commit 5cb849d: baud 9600->115200 in `fpga/basys3/vivado_build.tcl` (NOT the fix;
  revert if it confuses testing — terminal would need to be 115200).
- `CYC_36.v` currently has an UNCOMMITTED fix from another task (FPGA_FF_MODE clocks:
  register the next LEVEL, not a 1-sysclk pulse) that makes the FPGA execute loaded
  programs. Do not revert it. It is unrelated to output speed.
- Issue tracker: `docs/fpga-bringup-issues.md`. Separate open bug: FPGA RAM broken
  (issue #3, `SIP1M9.v` ramSize=3 DRAM) — not yours.

## Hard constraints (repo owner)
- Never mention AI/Claude in commits or docs. No LINQ. No unicode in code/comments
  (1980s C toolchain). Do NOT edit the `PAL_*.v` files (PALASM golden source). Prefer
  NOT to edit the microcode. Always compile before claiming success. Acceptance gates:
  seqcheck PASS + STERR=0 must still hold, and OPCOM output must be visibly faster.

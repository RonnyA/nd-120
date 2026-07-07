# ND-120 FPGA Bring-up Issues & Test Plan

**Full path:** `/mnt/e/Dev/Repos/Ronny/nd-120/Verilog/docs/fpga-bringup-issues.md`
**Started:** 2026-07-07 (Basys3, xc7a35t, after OPCOM first came up on silicon)

Tracks the open issues found once the FPGA started running OPCOM, with the plan to
reproduce/test each. Distinguish FPGA-only bugs (BRAM RAM, real UART timing) from
sim-reproducible ones.

## 0. UART loopback test program  [LOW PRI - fallback if no other UART fix found]
- Ronny's request (2026-07-07): write a small standalone FPGA program that drives
  the SC2661 UART directly: when you type `1` it sends `A`..`Z`; every other
  character is echoed back. Purpose: isolate UART TX/RX behaviour from the whole
  CPU/OPCOM stack to test throughput/correctness. Keep as LOW PRIORITY - only build
  if the UART issue can't be resolved another way.

## 1. UART output slow (register dump takes 1-2s)  [FIX DID NOT HELP - reclassified]
- UPDATE 2026-07-07: FPGA re-synth WITH the TxEMT fix -> still slow ("works as
  before"). So OPCOM polls TxRDY (bit0, already correct), NOT TxEMT -> the TxEMT
  fix (commit 196c444) was a real bug fix but NOT the slowness cause. Keep it
  (no regression). Slowness scales with char count AND with baud (sim DELAY_FRAMES
  =16 is fast, FPGA=1736 slow), and OPCOM emits "a lot of debug text" -> most likely
  just 9600 baud x output volume. PLAN: revisit by moving to 115200 once the rest
  works; not chasing as a bug now. See issue 0 for a UART isolation test.
--- (original analysis, still valid as a latent bug that was fixed) ---
- Symptom: CPU execution is fast (restart -> `#` is instant), but each output
  CHARACTER stalls ~100-200ms, so multi-char output (e.g. `A/`) takes 1-2s.
  Scales with char count => per-char stall.
- Root cause (found via `Shared/support/sim/SC2661_UART_tb.v`): TxEMT status
  (SR2 / TXEMT_n, "transmit shift register empty") was NOT a proper level -
  reset value 0, never cleared at TX start, and CLEARED on every status read.
  A console driver polling TxEMT reads it once, its own read wipes it, then it
  waits for it to re-assert -> per-char stall.
- Fix (commit 196c444): SR2 driven as a level like SR0 (TxRDY) - reset=1,
  cleared at TX start, set at DONE/idle, no read-clear. Testbench verifies.
  Self-test STERR still 0, seqcheck PASS.
- STATUS: FPGA re-synth in progress; confirm register dump is now snappy.

## 2. `20!` (execute from addr 20) HANGS in Verilator FF mode  [RESOLVED 2026-07-07]
- ROOT CAUSE: the FPGA_FF_MODE "phase-accurate" clocks in
  `CPU-BOARD-3202/circuit/CYC_36.v` were generated as 1-sysclk RISE PULSES
  (en = next_level & ~current_level), not as the full clock LEVEL. Rising edges
  were correct (that is what boot seqcheck validated), but every consumer that
  uses the clock as a LEVEL saw a collapsed high phase. The killer instance:
  `CPU_CS_ACAL_17` - its 74373/AM29841 address latches are TRANSPARENT while
  MACLK is HIGH, feeding the WCS address (LUA) from CSA. With a 1-sysclk MACLK
  pulse, LUA froze for the rest of the microcycle, so the mid-cycle CSA change
  during instruction dispatch (DGA handler address via WCA, e.g. o7250 in the
  fetch path) NEVER reached the WCS. CSBITS stayed at the previous microword
  (o6000, jump target o145) and MASEL captured the stale jump target: latch
  went o7250->o143 (correct), FF went ->o145 (fetch loop) - the CPU never
  executed any dispatched instruction, P just marched on. Proven by a per-sysclk
  trace (-DTRACE_MIC in runSim/Run120.cpp): FF held CSA=o7250 for 7 sysclks with
  CSBITS never updating; latch showed CSBITS=word[o7250] one sysclk after CSA.
- FIX: register the predicted next LEVEL instead of a rise pulse in CYC_36
  FPGA_FF_MODE: `mclk_pa <= s_mclk_next`, `maclk_pa <= s_maclk_next`,
  `uclk_pa <= uclk_next`. Rising edges land on the SAME sysclk as before (no
  boot regression); the full high phase is now also reproduced, so level
  consumers (ACAL transparency, MASEL regW hold via MCLKN, ACAL FF+CE on FPGA)
  behave like the latch/combinational clocks. ALUCLK/CLK were already levels
  (high = TERM window).
- VALIDATED: (a) FF `0!` and `20!` now run INSTRUCTION-B (VERIFY header /
  `>` prompt); (b) deduped CSA sequence of the ENTIRE 40M-cycle `0!` run is
  IDENTICAL latch vs FF (11.89M transitions, 0 diffs); (c) `make compare` +
  seqcheck.py PASS (162060 transitions identical); (d) self-test STERR=0
  (no o1134 visits after WCS load in trace_ff.csv).
- Symptom: `make run USE_LATCHES=0` (FF mode = FPGA path): OPCOM comes up, but
  running a loaded program via `20!` hangs. `make run` (latch mode) works.
- Significance: a REPRODUCIBLE sim divergence between latch and FF (=FPGA) mode
  in the program-EXECUTION path. seqcheck only validated BOOT, not execution.
- Method: instrumented `runSim/Run120.cpp` (guarded -DTRACE_CSA -DSCRIPT_INPUT,
  -DSCRIPT_CMD='"0!\r"') auto-injects the command after `#` and logs CSA_12_0.
  IMPORTANT: inject chars with an INTER-CHAR GAP (g_next_inject_cnt += 300000) or
  the SC2661 RX overruns and only the trailing char survives.
- RESULT 2026-07-07 (`0!` = run INSTRUCTION-B from addr 0): LATCH runs the full
  program (header + IDENT device scan). FF produces NO program output at all -
  just `#0!` then nothing (hangs). First CSA divergence at dedup line 519652:
  LATCH -> o143, FF -> o145. That microcode branch goes different ways in FF vs
  latch = the "goes to hell" point. NOTE: this is in the SIM (big working RAM),
  so it is a CPU timing/latch divergence in the EXECUTION path, NOT the RAM (issue
  3 is separate). NEXT: read microcode o143/o145 + the branch condition just before
  line 519652; likely a latch/clock phase signal feeding a microcode jump that
  seqcheck's boot path never exercised. Traces in scratchpad: csa_latch_0.csv /
  csa_ff_0.csv, s0l.txt/s0f.txt (deduped).

## 3. RAM addressing + data corruption  [FPGA ONLY - TO INVESTIGATE]
- Symptoms (Ronny, on the Basys3):
  - ALL memory addresses read back the SAME value: write 377->addr0, dump 0..10
    all show 357; write 0->addr1, all addresses show 0. => RAM address input
    effectively ignored (every access hits one cell). PRIMARY bug.
  - Data corruption on that cell (octal): 11->11 (ok), 103->123, 377->357. That
    is bit 4 (0x10) flipping inconsistently (103 sets it, 377 clears it, 11
    unchanged) -> not a simple stuck bit.
- CONFIRMED on FPGA 2026-07-07: memory write does not stick, read returns 0;
  registers (A,B) work fine. So CPU core + bus OK, RAM path broken.
- ROOT ANALYSIS (Shared/support/SIP1M9.v, ramSize=3): the RAM is a DRAM model,
  two FPGA-specific failures (both masked in sim by big array + zero-delay):
  (a) ADDRESS OVERFLOW: `sip_address = {hi_address[9:0], ADDRESS[9:0]}` is a 20-bit
      index, but ramSize=3 array `sdram[0:4094]` is only 4095 deep. Any access with
      sip_address >= 4095 is OUT OF BOUNDS -> write lost / read 0. INSTRUCTION-B
      (23K words) can't fit at all; depending on the MAC row/col split even modest
      addresses may overflow.
  (b) ASYNC DRAM CLOCKING: clocked by `negedge CAS_n` (a decoded control signal,
      NOT sysclk) and output `Q8 = (CAS_n==0 && W_n) ? reg_Q8 : 0` is combinational,
      valid ONLY while CAS_n low. On silicon this is a timing race (same class as
      the latch bug): if the CPU samples Q8 after CAS_n rises it reads 0 -> matches
      "read returns 0" exactly.
- LIKELY FIX: make the RAM a proper SYNCHRONOUS BRAM (sysclk-clocked, address wide
  enough or properly masked, registered read data held past CAS) instead of the
  async RAS/CAS DRAM model. Same discipline as the latch->FF fix, applied to RAM.
- TEST PLAN: reproduce in Verilator by forcing ramSize=3 in a sim build (add a
  -DFORCE_SMALL_RAM guard in MEM_RAM_49.v), run an OPCOM memory write+read, capture
  the RAS/CAS/address/data/Q waveform, confirm which failure mode (a)/(b) dominates.
  Sim uses ramSize=2 (big RAM) and works. Relates to [[fpga-clocking-requirements]].
- TEST PLAN:
  1. From OPCOM, write a UNIQUE value to each of addresses 0..17 (e.g. addr N <- N
     or N+100), then dump 0..17. Characterize: is EVERY address the same (full
     alias), or do low bits work and high bits alias (partial decode)?
  2. Write a walking-1s / walking-0s data pattern to ONE address, read back, to
     map which data bits corrupt (confirm/deny the bit-4 pattern with more points).
  3. In RTL: inspect MEM_RAM_49.v ramSize=3 path - address width/wiring, byte/9th
     bit lanes, write-enable/strobe, and whether the MAC/bus drives the full
     address to the BRAM on FPGA. Compare against the ramSize=2 (sim) path that works.
  4. Reproduce in Verilator FF mode if possible by forcing ramSize=3 (small RAM)
     in a sim build, to get a waveform of the RAM address/data/we during an
     OPCOM write+read.

## Notes
- The transparent-latch fix (commit 8876b4a, tag fpga-opcom-working-basys3) is what
  first got OPCOM running on the FPGA. See [[selftest-acceptance-gate]].
- USE_LATCHES=0 in sim = FPGA FF path; USE_LATCHES=1 (default runSim) = latch
  reference. Only 3 FPGA_FF_MODE sites differ (CYC_36 clocks x2, ND120_TOP x1);
  the rest is USE_TRANSPARENT_LATCHES (now functionally equal after 8876b4a).

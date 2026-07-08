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

## 1. UART output slow (register dump takes 1-2s)  [ROOT CAUSE FOUND + FIXED 2026-07-07, FPGA synth pending]
- ROOT CAUSE (two parts, neither baud nor the UART flags):
  OPCOM output is emitted by microcode MOPC, invoked from the PAN (panel)
  interrupt. On this board the ONLY active PAN source was the DGA RTC tick
  (the 68705 panel processor that raises PRQ is a stub). And that tick was
  miscalibrated: `DECODE_DGA_POW.v` hard-coded RTC_20MS=1_999_999 assuming a
  100 MHz clock, but the Basys3 CPU/board domain is 16.67 MHz -> the "20 ms"
  tick was really ~120 ms. One char per tick = ~8 chars/sec (observed
  "5-10 chars take a second"). The OS timebase (level-13 clock, MS20) was
  also 6x slow.
- FIX PART 1 (`DECODE-GateArray/DGA/circuit/DECODE_DGA_POW.v`): RTC terminal
  count derived from `BOARD_CLK_FREQ` (vivado_build.tcl already defines
  16666667) -> a true 20 ms / 5 ms tick. Also adds -DRTC_REAL_PERIOD to force
  the real period in a Verilator build (repro tooling).
- FIX PART 2 (`CPU-BOARD-3202/circuit/IO_37.v`, console output kick): each
  time the UART transmit holding register drains (TBMT 0->1), pulse STAT3
  towards the DGA (only the DGA copy - the PANCAL MIPANS readout is
  untouched). The DGA's original PRQ edge detector latches it into a
  panel-request interrupt whose vector (PRQ: o2340 -> MOPC) sends the next
  pending char immediately. Output then STREAMS at UART line rate; the
  RTC/MS20 timekeeping path is untouched (PRQ and RTC are separate PAN
  sources with separate clears).
- VALIDATED in Verilator with the REAL tick period (EXTRA_VDEFINES=
  "-DRTC_REAL_PERIOD -DBOARD_CLK_FREQ=16666667", runSim SCRIPT_CMD_CRS /
  SCRIPT_CMD_EXAM repros, o2347 send spacing in csa_trace.csv):
  before: exactly one send per tick (spacing = RTC period). After: memory
  examine `/` value streamed 7 chars back-to-back at char rate; remaining
  tick-waits are input-side only (typed chars are read on the tick, which
  is fine at human typing speed). Gates re-run with the kick active:
  seqcheck PASS (latch==FF, 162053 transitions), STERR=0, INSTRUCTION-B
  `0!` still runs to the `>` prompt in FF mode.
- EXPECTED ON FPGA: first char of a burst starts within 20 ms, then ~960
  chars/sec at 9600 baud (line-rate limited). PENDING: one Basys3 re-synth
  to confirm a register dump is snappy.
--- (earlier analysis below) ---
- (was) [FIX DID NOT HELP - reclassified]
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

## 3. RAM addressing + data corruption  [MEMORY MODULE PROVEN GOOD ON SILICON -> bug is MAC integration]
- BREAKTHROUGH 2026-07-08: standalone Basys3 memory test (`fpga/basys3/mem-test/`)
  drives MEM_RAM_49 -> SIP1M9 sync BRAM with the real DRAM RAS/CAS/AA protocol and
  PASSES ON HARDWARE: all 8 addresses write+read correct, no aliasing (0 vs 4
  distinct), last read 0x42 confirmed on LEDs. So the BRAM memory PATH is CORRECT on
  silicon. The CPU's read-0 failure is therefore NOT the memory module / SIP1M9 fix
  -- it is the CPU MAC/bus INTEGRATION driving the memory interface wrong on the FPGA
  (RAS/CAS/AA/DD/MWRITE50_n/banks from MEM_RAMC_50/PAL_44902A, MEM_ADDR_44,
  MEM_DATA_46). Same FF-mode/real-timing class as the CYC_36 fix; zero-delay sim
  hides it (memory works in sim). NEXT: snoop the CPU's actual memory-interface
  signals on the board (reuse the mem-test UART dump) during an OPCOM memory access,
  compare to the known-correct timing the standalone test uses, find the wrong signal.
  NOTE (Basys3 gotcha): btn1=SW0=V17; the mem-test holds reset when SW0 is UP (opposite
  of the CPU's "SW0 UP=run") -- set SW0 DOWN to run it. Fix polarity in a rebuild.

--- (below: the SIP1M9 sync BRAM fix -- correct, keep) ---
- FIX (2026-07-07): `Shared/support/SIP1M9.v` now has a proper SYNCHRONOUS BRAM path
  for `ramSize==3` (generate block `g_fpga_bram`), leaving the zero-delay DRAM sim
  model for `ramSize==2` untouched. Sysclk-clocked; RAS_n/CAS_n treated as level
  enables (they are PAL outputs registered on OSC=sysclk, per the MAC-timing map);
  read data REGISTERED and HELD (RDATA samples it late while CAS low); address
  reconstructed to the LINEAR word address `{col,row}=LBD[19:0]` and the low
  FPGA_ADDR_BITS (=13 => 8K words/chip) used, so it is CONTIGUOUS and does NOT alias
  (the old `sip_address={row,col}` reordered bits so consecutive addresses landed
  1024 apart and wrapped). Bank OR-combine preserved (Q gated by bank-gated CAS_n).
- UNIT TEST: `Shared/support/sim/SIP1M9_bram_tb.v` drives the real RAS-before-CAS
  protocol and passes: basic write/read, NO aliasing (addr 0 vs 4, 1 vs 5 distinct),
  the exact FPGA bug octals (377->377, 103->103, 011->011 -- were 357/123), address
  spread distinct, read stability. `iverilog -g2012 SIP1M9_bram_tb.v ../SIP1M9.v`.
- PENDING: (a) confirm Verilator ramSize=2 sim still builds + STERR=0/seqcheck (the
  generate wraps the old model unchanged); (b) FPGA synth -> check BRAM utilization
  fits (8K x9 x6 chips = 432Kb + microcode ROM) and that on-board write/read now
  works; tune FPGA_ADDR_BITS up if there is BRAM headroom. Note: INSTRUCTION-B is 23K
  words so will NOT fit 8K/bank -- use small test programs, or raise the size / bank.

--- original analysis (still valid) ---
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

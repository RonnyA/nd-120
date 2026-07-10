# Serial binary loader (300$) - status and findings

10-JUL-2026. Goal: load BPUN programs fast by typing `300$` at the OPCOM
prompt and streaming the raw BPUN file bytes into the console UART - the
BPUN format IS the microcode loader's wire format, no conversion needed.
Reference: RetroTerm docs ND110-OPCOM-MICROCODE-REFERENCE.md (sections on
ETLO1, the 300$ transfer sequence, and the C appendix).

## What works

- The ND-120 microcode (DELILAH-L) HAS the full loader: ETLO1, SEEK/SIKI
  (ASCII preamble), EXFOU ('!' -> binary), BIN, STLP, INCH, DVACT, and
  the on-CPU-board console dispatch IOXG -> IOXX1 -> TERMX -> TRMVC with
  handlers TRM0 (IOX 300 data), TRM2 (IOX 302 status), TRM3 (IOX 303
  control). Confirmed in nd120uc source + L listing.
- `$` is dispatched (DOLOA/ETLOA -> LOAD1 -> ETLO1); the CPU enters the
  loader and its INCH polling loop. Confirmed by CSA trace in simulation.
- Host-side transfer tool: fpga/tools/ndcomm (-b mode) types 300$ and
  streams the file with settle delay + pad; estimated ~49 s for the full
  23001-word INSTRUCTION-B at 9600 baud (vs ~45 min via deposits).
- Feed-rate analysis: the 9600 line cannot be overfed from the host (the
  kernel blocks); once INCH polls, the microcode consumes bytes ~50x
  faster than the line delivers them, so no pacing or flow control is
  needed mid-transfer; too slow is safe (INCH polls forever). The only
  loss window is between typing '$' and ETLO1 polling (MOPC dispatch is
  RTC-tick paced and the SC2661 buffers ONE char) - covered by the
  tool's settle delay (-w ms, default 400) and leading pad spaces.

## The blocker: JMP0-3 vector dispatch lands on entry 0

Reproduced in Verilator (runSim, -DSCRIPT_CMD_BINLOAD + the
ND120_BINLOAD_FILE env harness in Run120.cpp) and identical on hardware.

CSA trace signature of the hang (repeats forever):

    2310 2311 2312 2313   INCH: compute IOX N+2, test DA bit, loop
    477 500 501 502 503   IOXG / IOXX1: 16-bit IOX, detect device 30x
    504 511               ... TERMX
    3720                  TRMVC vector base
    515 516 517           TRM0 (IOX **300** handler - WRONG, expected
                          TRM2 at 3722 for IOX 302)

INCH polls IOX 302 (console input status), but the TERMX 4-way dispatch
(`T,JMP0-3 TRMVC` - "jump; IR0-3 drive low address bits", see nd120uc
ND120-microcode-bitfields.md) always lands on TRMVC+0. The status
handler TRM2 never runs, the DA bit is never reported, INCH spins.
Meanwhile the SC2661 shows rxEnabled=1, RxRDY=1 and an overrun - the
data is there; the microcode just cannot see it.

Checked and exonerated:

- SC2661 8-bit RX path (RHR is full 8 bits, no 7-bit strip in hardware).
- The P3 LDIRV strobe conversion (rebuilt with LDIRV_CE=0: identical
  failure), so this is NOT a clock-enable regression.
- The IOC register (holds 0x28 throughout - but the handover comes via
  TRM3, which is never reached).

Conclusion: the CGA_MIC next-address logic does not implement (or gets
zero from) the JMP0-3 OR-dispatch of IR bits 0-3 into the low CS address
bits **in the MOPC/IOXG context**. Macro-instruction execution dispatch
works (real programs run - the RTC test passes on silicon), so the bug
is specific to how IR0-3 reach the sequencer on this path - possibly the
IR is loaded differently (or not at all) when the microcode itself
issues the IOX, or the OR path is masked.

This path was NEVER exercised before (no test, no OS): pre-existing bug,
first surfaced by the 300$ experiment.

## Repro (fast, simulation)

    cd Verilog/runSim
    make compile USE_LATCHES=0 EXTRA_CFLAGS="-DSCRIPT_INPUT -DSCRIPT_CMD_BINLOAD -DTRACE_CSA"
    ND120_BINLOAD_FILE=<raw bpun stream> ND120_BINLOAD_CHECK=1000:5 ./obj_dir/VND120_TOP </dev/null
    # csa_trace.csv tail shows the 2310..3720,515-517 loop
    # RAM check prints the target words - unchanged = loader never wrote

The test stream used: 8 pad spaces + a 5-word tiny BPUN at 1000 with the
action field replaced by "1\r" (no autostart).
ND120_BINLOAD_SETTLE / ND120_BINLOAD_GAP (cnt units) tune the timing.

## Next steps

1. Find the JMP0-3 implementation in CGA_MIC (next-CSA formation) and
   how IR0-3 are sourced during microcode-initiated IOX; compare with
   the CGA design docs. Fix, then the sim repro above must load the
   tiny BPUN (RAM check = 123456 000001 177777 054321 000000) and
   return to '#'.
2. Re-run the full gauntlet (this touches the CPU core sequencer:
   traces must stay golden - the dispatch is supposedly inert in all
   currently-golden flows, so byte-identity should hold).
3. Then ndcomm -b -n -v on hardware, then INSTRUCTION-B with -b -g.
4. Note for the SD/tape-device plan (docs/sd-bpun-device-plan.md): the
   device-400 boot path uses general bus IOX, not TRMVC - but IOX-based
   device I/O in general should get a regression test once this works.

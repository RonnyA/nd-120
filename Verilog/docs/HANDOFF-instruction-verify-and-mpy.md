# HANDOFF - instruction-verify campaign + MPY overflow fix (13-JUL-2026)

Branch: `clock-enable-fix`.

> **13-JUL UPDATE - MPY BUG FOUND AND FIXED.** Section 3 below is OBSOLETE
> (the WRF-hazard conclusion was a probe artifact and is retracted). The real
> bug: `CGA_ALU_QREG.v` MUXQ15 input D3 (shift-right-double serial input) was
> wired to Q[0] (a rotate) instead of F[0], so the FMU multiply never streamed
> the product's low word from R5 into Q: EVERY MPY product read 0, and
> +/-32768-boundary overflows missed the O/Q status bits (the INSTRUCTION-B
> "DYNAMIC OVERFLOW BIT NOT SET" failure). One-input fix, both latch and FF
> modes, verified against the nd100x reference on a 10-operand-pair deposited
> sweep (MPYSWEEP2.BPUN). Full story + retraction:
> `Verilog/docs/MPY-dynamic-overflow-rootcause.md` (final section).

## 1. Instruction-verify campaign - DONE for available scope

Goal: validate every ND-120 macro instruction by comparing our Verilator RTL
(runSim) against ND-110 golden traces of INSTRUCTION-B (per area).

- Home: `Verilog/tests/instruction-verify/` (README.md = the plan + calibration).
- Comparator `compare_trace.py`: architectural hard-gate (A D T X B L P STS +
  addr/opcode/PIL); resync alignment for WAIT/panel service; interrupt-level
  (PIL>=10) filter; scratch (R1-R7/Q/F/GPR/LC) = non-fatal warnings; on any
  deviation writes a full register+context+microcode `.divergence.md`.
- Gate: `Verilog/Makefile` pattern rule `make test-instr-<AREA>` + `make test-instr`
  (INSTR_AREAS = the 9 passing areas); `run_area_test.sh` arms our emitter at the
  golden's own first-section address (ND120_TVERIFY_ARM_ADDR) and MAX=460.
- RESULT: 9 areas match golden 400/400 EXACTLY (ARGUMENT, STACK, BYTE-STRING,
  MEMORY-REFERENCE, SEQUENCE, REGISTER-OPERATIONS, BIT-OPERATIONS,
  SHIFT-INSTRUCTIONS, 48-BITS-FLOATING). Scratch differences = panel display-
  refresh noise (benign). See MEMORY [[instruction-verify-campaign]].
- CAVEAT the golden trace only covers the FIRST ~400 of ~44,000 instructions per
  test (ND-110 MACRO_CAP=400). So the trace match validates the first 400 only;
  the DEEP validation is INSTRUCTION-B's OWN self-check output ("== END OF TEST =="
  with no error lines), which requires running each area to completion.
- 5 areas have EMPTY (0-macro) golden from the ND-110 side: 32-BITS-FLOATING,
  PRIVILEGED, ND100-24BIT, BCD, ND100-CX. RUN has a golden but is BLOCKED (below).

## 2. Tape-storm BUG (blocks full-length runs) - handoff to FAT/devices owner

`400$` INSTRUCTION-B boot triggers a continuous level-12 interrupt storm from the
C tape device model (SD/FAT rewiring). The tests still complete but the sim
crawls (tens of thousands of interrupt cycles). ARGUMENT was confirmed to reach
"== END OF TEST ==" with NO errors (a PASS) despite the storm. RUN cannot run at
all (stress levels 10-14 add to the storm). Bug report + desired fix (Verilog
tape reader fed by SD, or old C tape behind a config/define, both testable):
`Verilog/docs/BUG-tape400-sd-level12-storm.md`.

## 3. MPY "dynamic overflow bit not set" - DEFINITIVE root cause (WRF write hazard)

Full detail + trace evidence: `Verilog/docs/MPY-dynamic-overflow-rootcause.md`.
Overnight diagnostics OVERTURNED the initial condition-latch hypothesis.

MEASURED (per-eval probes on the fast harness, overflow MPY 040000x040000):
- The branch at CS 004432 is CORRECT: s_etrue=0, s_efalse=1 -> FALSE seq = NEXT =
  fall through (NOT a jump). It correctly proceeds to the overflow-set. (The
  earlier "branch wrongly taken" was a misread of R4=174001 = pre-load scratch.)
- 004433 ("...IDBS,ARG 60") CORRECTLY loads R4=060 (ARG reaches 000060, write
  fires, R4 becomes 000060) - but it commits ONE MICROCYCLE TOO LATE.
- 004434 (MPY3, the IMMEDIATELY next word) "A,STS B,R4 ALUF,ORAB STS,LO" latches
  STS on the SAME edge 004433's R4=060 commits -> non-blocking read gets the
  PRE-edge R4=000000 (from 004432's ALUF,ZERO). STS <- STS OR 0 = unchanged.
  Overflow bits 4/5 never set.

ROOT CAUSE: a WRF register WRITE-TO-IMMEDIATE-READ hazard - a value written to a
WRF register by microinstruction N (004433 R4=060) is NOT visible to N+1's read
(004434). The write lands one microcycle too late. Real HW forwards; our zero-
delay FF-mode sim does not. Affects EVERY back-to-back write-then-read; MPY is
just the case a test visibly catches.

NOT the condition latch (branch correct). NOT ALU/STS (both audited correct).
NOT the ARG constant. Both ZF-register fix attempts were WRONG and broke boot
(ZF is already pipelined - do NOT register the flags). Ignore the CSEL/CONDREG
analysis for this bug.

FIX DIRECTION (delicate, do fresh): make a CGA_WRF register write by
microinstruction N visible to N+1's read (write-forwarding, or advance the WRF
write commit one microcycle in FF mode). Read CGA_WRF RBLOCK reg-write clocking
(R*_REG cells, s_wr enable, clock vs the read/B-operand path) + CYC_36 MACLK/
ALUCLK phase. HIGH RISK (a clock change broke boot once). Bounded-verify.

FAST HARNESS (the key enabler, works, ~40s):
  cd Verilog/runSim
  make compile USE_LATCHES=0 EXTRA_VDEFINES="--public-flat-rw" EXTRA_CFLAGS="-DND120_PROBE_MPY"
  printf '1000!\r' | ND120_STDIN_GAP=300000 ND120_MAX_CNT=6000000 stdbuf -oL ./obj_dir/VND120_TOP MPYOVF2.BPUN
  -> [mpy] lines: at csa=4434 R4 should be 060 when fixed; STS at 4435 bit5=040.
  Boot must reach "#" (regression check). MPYOVF2.BPUN = deposited 040000x040000
  overflow MPY at octal 1000, started via MOPC "1000!" (pacing + stdbuf -oL are
  BOTH required: pacing so 1000! is not dropped, stdbuf so probe output is live).
  loadfile() has `regP=B` commented out (Run120.cpp:1401) so no autostart - MOPC
  "1000!" is how you start a deposited program.
  MPY probe = ND120_PROBE_MPY block in Run120.cpp (csa 4425-4435, exits after 600
  samples). Committed in ae2cfa9.

## 4. UPDATED PLAN (resume order)

A. MPY fix, phase-correct (highest value, delicate):
   1. Read CYC_36 (Verilog/CPU-BOARD-3202/... CYC_36) to get the exact ALUCLK vs
      MCLK phase and when the branch next-address is latched vs when the ALU
      result settles.
   2. Build ONCE with -DTRACE_CSA, run the (re-applied) hung ZF-fix, and find
      WHICH CSA the boot self-test loops on -> the specific jump the pipeline
      shifted -> pins the phase.
   3. Fix in CGA_MIC_CSEL.v CSEL_LATCH (make it hold the COND-word condition
      through CONDENABL consistently) rather than a front-end register; or the
      correct-phase capture of the ALU flags. Verify with the harness: overflow
      MPY R4=060 + STS bit5; no-overflow MPY correct; boot reaches "#"; then a
      couple instruction-verify areas' first-400 unchanged.
   4. Extend to OVF/CRY/F11/F15 (same mechanism). Commit as one .v change.
B. Tape-storm fix (FAT/devices owner) -> unblocks full-length INSTRUCTION-B runs
   and RUN, and lets each area run to its own END-OF-TEST verdict (the real deep
   validation beyond the 400-instruction golden window).
C. After the storm fix: run each of the 9 areas to END OF TEST, capture
   INSTRUCTION-B's own error output; for any failure use the divergence dump +
   the fast-harness pattern to root-cause the specific instruction.
D. RUN + the 5 empty-golden areas: pending ND-110 side delivering content.

## 5. Housekeeping
- RTL reverted (CGA_MIC.v clean); working binary rebuilt; git tree clean.
- Scratch state: `<scratchpad>/MPY-INVESTIGATION-STATE.md`, `MPYOVF2.BPUN` (+
  MPYSTD_OVF/NO, MPYNOOVF) in runSim/.
- All analysis agents completed; none left running.

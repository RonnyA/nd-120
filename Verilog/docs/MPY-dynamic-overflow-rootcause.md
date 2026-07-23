# MPY "dynamic overflow bit not set" — root-cause analysis (12-JUL-2026)

Symptom (from INSTRUCTION-B MEMORY-REFERENCE, user-observed):
`DYNAMIC OVERFLOW BIT NOT SET. SHOULD HAVE BEEN -> "MPY" FAILED (MPY2OP)`

## Bottom line
**Not an ALU bug. Not an STS-register bug.** Two independent source audits confirm
the ALU overflow logic and the STS register write path are correct. The failure
is a **condition-latch transparency (clock-phase) issue in the microcode
sequencer** — i.e. in the CYC_36 / ALUCLK clock-enable domain currently being
reworked on the `clock-enable-fix` branch, NOT in ALU/STS combinational logic.

STATUS: strongly evidenced by source; **awaiting the one confirming measurement**
(R4 at CSA 004434 on an overflowing MPY) via the fast micro-harness.

## How MPY is supposed to set overflow (verified from the DELILAH listing)
`ND-120-DELILAH-K.LISTING.TXT` 11642-11665, multiply loop MPY1/MPY2 (CSA 4424-4434):
- 004431: `B,R5 ALUF,PASSB ALUD,SRD ... COND,F=0 F,NEXT F,HOLD` — evaluates the
  F=0 condition on the (shifted) multiply result in R5.
- 004432: `B,R4 ALUF,ZERO ALUD,B ... T,JMP MPY3 CONDENABL` — conditional jump to
  MPY3. NOTE this word's own ALU op is `ALUF,ZERO` (result 0 -> live ZF=1).
- 004433 (fall-through = overflow): `B,R4 ALUF,PASSD ALUD,B IDBS,ARG 60` — load R4=060.
- 004434 MPY3: `A,STS B,R4 ALUF,ORAB ... STS,LO` — STS <- STS OR R4, sets bits
  4 (static ovf, 020) and 5 (dynamic ovf, 040).
Intended: overflow => branch NOT taken => 004433 runs (R4=060) => both bits set.

## What is CORRECT (audited to source, do NOT re-review these for this bug)
- STS register `CGA_ALU_STS.v` ("Page 51"): bit4 = STS4_MUX, bit5 = STS5_MUX;
  CSTS=11 selects D0 (databus FIDBO) for both; bits 4/5 are structurally
  identical on the databus path -> the register cannot set bit4 while dropping
  bit5. STS,LO decodes to CSTS_1_0=11 (verified via CGA_CPU_ALU_CONTR).
- ALU overflow `CGA_CPU_ALU_RALU.v`: s_ovf = signed-add overflow (correct);
  ALU zero-flag ZF polarity correct (ZF=1 iff F==0), via GATES_6/7/11.
- MIC condition select `CGA_MIC_CSEL.v`: F=0 token (0o340) -> TSEL selects the ZF
  mux input (idx6); JMP/NEXT true/false mapping correct. No static wiring bug.

## The actual root cause (condition latch)
`CGA_MIC_CSEL.v:156` instantiates `LATCH CSEL_LATCH (.D(s_pcond_n),
.ENABLE(s_aluclk_n=~ALUCLK), .Q(s_cond_n_out))`.
`Shared/ndlib/LATCH.v` in FF mode is `Q = ENABLE ? D : regD` — **combinationally
transparent while ENABLE (=~ALUCLK) is high** (kept level-sensitive on purpose:
an edge-detect version broke LCS loading — see the LATCH.v comment).

Because the condition latch is transparent while ALUCLK=0, and the CONDENABL
word **004432 itself forces ZF=1** (its `ALUF,ZERO`), the branch can sample
004432's live ZF=1 instead of the multiply-result condition held from 004431.
Result: the T,JMP is **always taken -> 004433 (R4=060) is skipped -> overflow
(both bits) never set.** MPY is uniquely exposed because its CONDENABL word
happens to drive the same condition (F=0) the branch tests; other conditional
jumps are unaffected, which is why ARGUMENT etc. pass.

## The confirming measurement (still needed)
Run one MPY with operands whose signed product overflows 16 bits; read R4 at CSA
004434 (MPY3):
- **R4 = 060** -> branch fine; look elsewhere (would contradict the hypothesis).
- **R4 = 0 (or its stale input, e.g. 2)** -> 004433 skipped -> CONFIRMS the
  condition-latch-captures-004432-ZF timing bug.
Also capture s_aluclk, s_zf (CGA_ALU), CGA_MIC.s_cond_n at 004431->004432.

## Fix direction (if confirmed) — clock-domain, delicate
The condition evaluated at the COND word (004431) must be HELD through the
CONDENABL word (004432)'s sample, i.e. the condition must be captured at the
COND-word boundary rather than level-tracked into the CONDENABL word. This is a
latch->FF / clock-enable-alignment change in CSEL_LATCH's capture phase, and it
must NOT reintroduce the LCS-load failure the current level-sensitive code was
written to avoid (LATCH.v comment). This belongs to the clock-enable-fix work,
not an ALU/STS schematic change.

## Method note
All of the above read directly from source (assume-nothing). The only unproven
link is the runtime sample-phase interaction, which the harness measurement will
settle. Agents: branch-condition trace + STS-write audit (both complete);
fast MPY micro-harness (in progress).

## Fix attempt 1 (13-JUL) - REVERTED (broke boot)

Grounded in the ND branching spec the user supplied:
  "The test is on the result of the set condition in the PREVIOUS microinstruction.
   If a test object changes state, one microinstruction will be executed before
   the change is detected (pipelining of ALU and sequencing)."
So the CSEL condition inputs must be the PREVIOUS microinstruction's values.

Three source-audit agents established WHICH CSEL test objects are the buggy
combinational-live ones vs already-pipelined:
- NEED the 1-microinstruction pipeline (combinational ALU-result flags, live at CSEL):
  ZF (bit14), OVF (bit10), CRY (bit11), F11 (bit12), F15 (bit13).
- ALREADY-OK (do NOT touch): DZD/OOD (MCLK-registered FF outputs), LCZ (derives
  only from the MCLK-registered loop counter), STP (control-state FF, not ALU),
  IRQ (registered interrupt status - MUST NOT delay), RESTR (mode level),
  CFETCH (MCLK-registered), COND (bit7 = MEMORY_32, itself the MCLK pipeline of
  CONDN - do NOT double-register). CONDREG holds TSEL/FS/LCC (which condition),
  already MCLK-gated by CSSCOND.

ATTEMPT: in CGA_MIC.v, registered s_zf one microinstruction on MCLK
(`if (MCLK_EN) s_zf_pipe <= s_zf`) and fed CSEL `.ZF(s_zf_pipe)`.
RESULT: builds clean, but BOOT HANGS after "RUNTIME LOAD" (never reaches the
MOPC "#" prompt within 25M cnt; boot is identical up to cnt 158k then diverges).
Could not even confirm the MPY overflow-set because boot dies before the program
runs. REVERTED (git checkout CGA_MIC.v).

REFINED DIAGNOSIS: a front-end MCLK register is the wrong mechanism. The
CSEL_LATCH (transparent on ~ALUCLK) is the DESIGN's intended pipeline delay - in
real HW it captures the previous, settled condition via ALU propagation delay.
Its delay is PHASE-DEPENDENT on ALUCLK vs the branch-sample point: for MPY's
004432 branch it is effectively transparent (0 delay -> the live-ZF bug), but for
the boot self-test conditional jumps it apparently already provides ~1
microinstruction of delay in FF mode. Adding a separate MCLK register therefore
DOUBLE-delays those boot jumps (off-by-one) and hangs the self-test.

=> The correct fix belongs IN the CSEL condition capture (CGA_MIC_CSEL.v
CSEL_LATCH and/or the CYC_36 ALUCLK/MCLK phase), making it CONSISTENTLY hold the
COND-word's condition through the CONDENABL word for ALL jumps - without the
level-sensitive LCS-load regression the current LATCH.v comment guards against.
This needs the exact CYC_36 ALUCLK/MCLK phase relationship (read CYC_36 first)
and per-jump verification, not a front-end register. Recommended next step:
build once with -DTRACE_CSA, run the hung ZF-fix, and see WHICH CSA the boot
self-test loops on - that identifies the specific jump the pipeline shifted and
pins down the phase.

STATUS: root cause CONFIRMED and fix DIRECTION confirmed; phase-correct
implementation is open (delicate CYC_36 clock work). Working boot restored.

## Phase diagnostics (13-JUL, ND120_PROBE_MPYPHASE) - key evidence for the fix

Fast bounded harness proven: working build reaches program MPY at cnt ~2.946M;
test cap = MAX_CNT=3,300,000 (~45s). Broke-boot => no post-boot [mpy] in window.

Signal probe every eval across the post-boot overflow MPY branch (paths verified
via obj_dir root header). CSA-reported = executing-word + 1 (confirmed: SCOND
`cond` bit =1 at csa-reported 4432 = executing 004431=COND; ECOND `econd` bit =1
at csa-reported 4433 = executing 004432=CONDENABL). Microcycle = 3 evals
[aluclk=0][enables pulse: mclk_en=maclk_en=aluclk_en=1][aluclk=1].

FINDING 1 (CRITICAL): ZF is ALREADY pipelined ~1 microinstruction. 004432's
ALUF,ZERO forces result 0 but zf=1 does not appear at csa 4432 (zf=0 there); it
appears ~1 microcycle later at csa 4433/4434. => registering the flags (attempt 1)
DOUBLE-delays and hangs boot. Do NOT register the flags.

FINDING 2: branch logic (CGA_MIC.v GATES_5/6/8, verified): with ECOND active and
not LCS/loop: s_etrue = ~s_cond_n, s_efalse = s_cond_n. 004432 is "T,JMP MPY3"
(true=JMP), false-seq = NEXT (from 004431 "COND,F=0 F,NEXT F,HOLD"). So
condn(=s_cond_n)=0 -> TRUE -> JMP MPY3 (skip 004433, overflow NOT set);
condn=1 -> FALSE -> NEXT -> 004433 (R4=060, overflow set).

FINDING 3 (UNRESOLVED): at the branch (econd=1, csa-reported 4433, cnt ~2946010),
the probe shows condn=1, which by Finding 2 should be FALSE->NEXT->set overflow
(R4=060). But the observed R4 at MPY3 = 174001 (004433 did NOT run) => the branch
effectively took TRUE (JMP), i.e. behaved as condn=0. This inconsistency (condn
sampled =1 but branch acts as 0) is not resolvable from the discrete samples -
needs probing the ACTUAL next-microaddress select bits (CGA_MIC s_etrue/s_efalse
and the NOR GATES_19-22 next-addr) at the exact latch edge, OR is a delay-slot
side-effect subtlety. pcondn (pre-latch mux out) = ~zf when tsel=F=0(e): it is 1
at cnt 2946008-2946010 (zf=0) then 0 at 2946011 (zf=1) - so the "correct" no-jump
value flips within the branch window; the exact sample edge decides it.

RAW TRACE saved: scratchpad/mpy_phase_trace.txt (+ first_pass.txt). Reproduce:
build -DND120_PROBE_MPY -DND120_PROBE_MPYPHASE (Run120.cpp, uncommitted MPYPHASE
probe), run the fast harness.

## Evaluation of fix options (updated with the evidence)
- (X) register ALU flags on MCLK/MACLK/etc -> WRONG (ZF already pipelined; broke boot).
- (?) adjust the CSEL_LATCH capture/sample phase so the branch samples condn at the
  edge where it reflects 004431's (previous-word) F=0 result, not the transient.
  This is the live candidate but needs Finding 3 resolved (which edge / which
  pcondn value is correct) - probe the next-addr select bits to decide.
- Recommended next step (fast, one build): extend the probe to log s_etrue,
  s_efalse, and the next-microaddress select at the branch latch edge; that
  resolves Finding 3 and pins the exact one-line phase fix. Then bounded-test.

## *** MAJOR CORRECTION (13-JUL, s_etrue/s_efalse probe) - branch is NOT the bug ***

The s_etrue/s_efalse probe (the ACTUAL jump controls) at the CONDENABL branch
(econd=1) shows: etrue=0, efalse=1. Per the branch logic that means the FALSE
sequence = NEXT = FALL THROUGH (no jump). For the overflow MPY that is the
CORRECT behaviour (fall through to 004433 -> set overflow). So the condition
latch / ZF timing is NOT the bug. The whole "branch wrongly taken" hypothesis was
a MISREAD of R4=174001 (that is just the pre-load pipeline value, not proof
004433 was skipped). BOTH prior fix attempts (register-the-flags) targeted the
wrong thing - abandon that direction entirely.

REAL BUG (evidence): the branch correctly falls through, but the overflow-SET
never produces its result. Across the whole run R4 NEVER becomes 000060 and STS
stays 010100 (bits 4/5 never set). R4 progression through the MPY: 174001 (panel
scratch) ... then 000000 - never 060. So 004433 ("B,R4 ALUF,PASSD ALUD,B
IDBS,ARG 60" - load R4 with the ARG constant 60) is NOT loading 060 into R4.
=> The bug is in the R4/ARG-constant load path (004433), i.e. the constant "60"
not reaching WRF reg12, OR 004433's R4 write not firing. This is the path Agent 3
flagged as the highest-value unverified check. It is a DATA-path issue (ARG
register CGA_ALU_ARG regArg <= CSBIT on ALUCLK; possible off-by-a-microcycle ARG
value, or the LDGPR/write-enable), NOT the delicate condition-latch clock work -
likely more tractable.

FINAL DIAGNOSTIC (running): probe R4, s_arg_15_0, ALU_ARG.regArg, R4_REG_12.s_wr
every eval around 004433 -> shows whether ARG=60 reaches the ALU, whether R4's
write-enable fires, and what value R4 receives. That pins the exact bug.

REVISED FIX DIRECTION: fix the 004433 R4=060 constant load (ARG path / write),
NOT the condition pipeline. Verify with the same fast bounded harness
(R4=060 at MPY3, STS bit5=040, boot reaches #).

## *** DEFINITIVE ROOT CAUSE (13-JUL, R4/ARG probe) - WRF write-to-read hazard ***

Fine-grained probe (R4=WRF reg12, arg=s_arg_15_0, regarg=ALU_ARG.regArg,
r4wr=R4_REG_12.s_wr) every eval across the post-boot overflow MPY:

  cnt      csa   r4       arg      r4wr
  2946013  4433  174001   004434   1     <- panel scratch still in R4
  2946014  4434  000000   000060   1     <- 004432 ALUF,ZERO write of R4=0 committed
  2946015  4435  000000   000060   1
  2946016  4435  000000   000060   1
  2946017  4435  000060   100000   0     <- 004433 write of R4=060 FINALLY commits

So 004433 DOES correctly load R4=060 (arg reaches 000060, write-enable fires,
R4 becomes 060) - but it commits at cnt 2946017. The MPY3 word (004434, the
IMMEDIATELY NEXT microinstruction) does "A,STS B,R4 ALUF,ORAB STS,LO" and latches
STS on that SAME edge (2946017). By non-blocking ordering STS reads the PRE-edge
R4 = 000000 (from 004432's ALUF,ZERO), not the 060 004433 just wrote. So
STS <- STS OR 000000 = unchanged (stays 010100, bits 4/5 never set).

ROOT CAUSE: a WRF register write-to-immediate-read data hazard. A value written
to a WRF register by microinstruction N (004433, R4=060) is NOT available to
N+1's read (004434/MPY3). The write lands one microcycle too late. The microcode
legitimately does write-R4-then-immediately-OR-R4-into-STS; on real HW the write
forwards to the next read, in our zero-delay FF-mode sim it does not.

=> NOT the condition latch (branch is correct, efalse=1 fall-through). NOT the
ALU or STS register (both correct). NOT the ARG constant (arg=060 correctly).
The bug is WRF/GPR WRITE TIMING (CGA_WRF write clocked one microcycle too late
relative to the same-cycle read) - a P2 clock-enable / latch->FF forwarding
matter, same family as the clock-enable-fix work.

FIX DIRECTION: make a WRF register write by microinstruction N visible to N+1's
read (write-forwarding, or advance the WRF write commit one microcycle in FF
mode). Read CGA_WRF (RBLOCK reg write clocking - the R*_REG cells, s_wr enable,
which clock/enable they use vs the read/B-operand path) and CYC_36 MACLK/ALUCLK
phase. This likely affects EVERY back-to-back write-then-read in microcode; MPY
is just the case that visibly fails a test. Verify with the fast bounded harness
(R4=060 reaching MPY3's STS OR; STS bit5=040; boot reaches #).

CONFIDENCE: high - directly measured. Supersedes ALL earlier hypotheses in this
file (condition latch / register-the-flags). Those are WRONG; do not pursue.

## *** FINAL ROOT CAUSE (13-JUL, fixed) - QREG shift-right wiring, NOT a WRF hazard ***

The "WRF write-to-immediate-read hazard" above is WRONG - retracted after
re-measurement. Two probe errors produced it: (1) the [mpy] probe read WRF
scratch register 8 as "STS" (MPY3 never writes reg8; the real status register
is CGA_ALU_STS), and (2) the probe window ended before ALU_STS's capture edge.
Direct re-measurement (probing CGA_ALU s_sts_15_0 every eval) shows the WRF
write pipeline is CORRECT: word N's write commits at the end of N's execute
window and IS visible to N+1 (R4=060 reaches MPY3's OR; ALU_STS becomes 010160
at MPY3's own TERM edge). Micro level fine, macro level fine (TRA STS + BSKP
ONE SSQ/SSO both read the bits; proven with a deposited check program), and the
bits survive a forced level-0->1->0 round trip (per-level STS save/restore OK).

The REAL bug (found via a 10-pair MPY operand sweep, deposited program
MPYSWEEP2.BPUN, results read back from RAM):

  EVERY MPY returned product 000000, and boundary overflows (product exactly
  +32768: 000002x040000, 100000x177777) failed to set the overflow bits.

Root cause: CGA_ALU_QREG.v MUXQ15 input D3 (the qsel=11 shift-right-double
serial input) was wired to Q[0] - a 16-bit ROTATE of Q onto itself - instead
of F[0], the bit leaving the R-side shifter. In the FMU multiply loop
(microword 004427: ALUF,A+B ALUD,SRD ALUM,FMU) the product's low bits stream
from R5 into Q via exactly that input; Q is cleared at MPY entry (004424
ALUF,ZERO ALUD,Q), so with the rotate wiring Q stayed 0 through the whole
loop: product low word always 0, PASSQ (004436) returned A=0, and the SLD
overflow probe (004430, RLI=Q15) lost the +/-32768 boundary bit -> the
INSTRUCTION-B "DYNAMIC OVERFLOW BIT NOT SET" failure. Every other bit of the
qsel=11 mux chain takes Q[i+1] (a true right shift), and the mirror link for
shift-LEFT-double already existed (RLI = Q15 in CGA_CPU_ALU_CONTR GATES_18/40),
which confirms the intent. Schematic reference: CGA page 43 (QREG), MUXQ15.

FIX (one input): CGA_ALU_QREG.v MUXQ15 .D3(s_f_15_0[0]) (was s_q_15_0_out[0]).
Data-path transcription bug - present in BOTH latch and FF modes, no clocks
involved.

VERIFIED after the fix (both USE_LATCHES=0 and =1):
- all 10 sweep products correct (2x037777=077776, 177777x177777=000001, ...);
- overflow bits (Q=020 dynamic, O=040 static) match the nd100x reference
  emulator's MPY rule "abs(result) > 32767 -> set O and Q" on all 10 pairs,
  including product exactly -32768 (fits, but the negate-first microcode
  algorithm still flags it - nd100x does the same);
- boot reaches "#".

NOTE while validating: `make test` currently fails at test-memchain
(CPU-BOARD-3202/circuit/sim, bit-8/9th-bit drops: dback bank1 col3
got=177377 exp=177777) on COMMITTED code whose dependency list does not
include CGA_ALU_QREG.v - a pre-existing failure from the parallel
memory/device work, unrelated to this fix.

SCHEMATIC CONFIRMED (13-JUL, Ronny, CGA page 43): MUXQ15 inputs on the
original schematic are D0=Q15, D1=F15, D2=Q14, D3=F0, mux output to the R81P
A input whose QA output is Q15. The error was in the LOGISIM DRAWING (the
original PDF scan is very unclear at exactly this point), and the generated
Verilog inherited it. The fix (.D3(F[0])) matches the original hardware.

WARNING - REGENERATION HAZARD: Logisim is the source for this generated
Verilog. Until the Logisim CGA_ALU QREG sheet is corrected (MUXQ15 D3 wire:
Q0 -> F0), regenerating CGA_ALU_QREG.v from Logisim will REINTRODUCE this
bug. Fix the drawing before any regeneration.

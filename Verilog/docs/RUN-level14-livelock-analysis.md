# RUN area level-14 livelock: measured analysis (13-JUL-2026, in progress)

INSTRUCTION-B `RUN` stalls right after `== DUMMY OUTPUT STARTED ==` and never
prints `IOX-ERROR STARTED`. Everything below is probe-measured on the FF-mode
runSim build (probes: `ND120_PROBE_RUNIDENT` in `runSim/Run120.cpp`), after
the tape-storm fix (C-device interrupts now actually assert BINT lines) and
both CPU fixes (QREG dc61bd6, SSEL 2e2ea37).

## Measured chain

1. RUN starts its stressors. The dummy-output phase performs IOX writes that
   raise real IOX-error internal interrupts (`ioxerr_n` input pulses,
   ~every 1000 evals).
2. Each pulse latches request bit 10 in `CGA_INTR` (IRSRC bit map: bits 0-3 =
   external levels 10-13; bits 8-13 = internal detects: 8=Z, 10=IOXERR,
   11=PARERR, 12=NOR, 13=POWFAIL; latched in IRQ_REG RQBITs, set/hold until
   CLRQ).
3. The CPU switches to PIL 14 correctly (measured PIL trace: ...10, 13, 12,
   then 14).
4. THE FAULT: at PIL 14, EVERY macro instruction boundary re-dispatches the
   internal-interrupt service (csa 03756 -> EXT14 -> PLINT -> MACRI):
   measured 14,487 EXT14 dispatches for 14,486 MACRI boundaries in 1.1M
   evals, while TAIIC (the `TRA IIC` microcode at csa 03665, which ends in
   `CLR14: R1:=037760; CLRXX: PIC,MCLPID` = the internal-detect clear) stays
   FROZEN at 21 entries. The level-14 handler never executes its dismissal,
   the detect bit is immortal, levels 10-13 starve.

## Why re-dispatch is not suppressed

`CGA_INTR` has NO PIL input - suppression of requests at-or-below the
current level is done via the PIC mask register (MPIE, `PICMASK` in
CNTLR/IRQ_MASK). The level-switch microcode reloads it on every switch
(PLINT -> PLVO -> PICFM/PICF2, `PIC,LMSK`); for a switch TO level 14 the
mask must disable the internal detect bits (the microcode's own constant
077760 = bits 4-13 appears at PICF2+1 for exactly this).

Measured during the storm: PICMASK stuck at 100562 (bits 9-13 = the internal
detects LEFT ENABLED) and never rewritten - the PLINT loop cycles
01133-01142 (PLINT/PLVO+1/PLVO+2) taking the `COND,F=0 F,RETURN` early path
and never reaches PICFM/PICF2 (01163-01171). The 21 successful TAIIC entries
during startup prove the flow works in other conditions.

## ROOT CAUSE FOUND: SBIT (status register bit) mis-wiring - schematic p.87

The DELILAH interrupt system is a close copy of the **Am2914** Vectored
Priority Interrupt Controller (Ronny, 13-JUL; confirmed against the 1978
Am2900 Family Data Book). The Am2914 rule that RUN depends on:

> "The Read Vector microinstruction ... **also automatically loads the value
> 'vector plus one' into the Status Register**." (Am2900 Family Data Book)

The Status Register is the fence that stops the interrupt just taken from
being re-dispatched. Our `CGA_INTR_CNTLR_VECGEN_STAT` implements it as six
`SBIT` cells (schematic p.87), whose D input is:

```
D = (SIN & DCDG & DCDF & GPE)      <- load S-bus data   (LDSTAT)
  | (DCDG & DCDFN & STS)           <- hold
  | (VINN & DCDF & DCDGN)          <- load vector+1     (RDVECT)
```

TWO transcription bugs, both now schematic-verified with Ronny (13-JUL):

1. **Cell** (`..._STAT_SBIT.v` GATES_3): the vector-load NAND's middle input
   was `GPE`; the sheet's SBIT detail box shows **`DCDF`**. With `GPE` there
   the vector+1 load could not fire.
2. **Instances** (`..._STAT.v`, all six): the six SBIT blocks on the sheet
   are drawn WITHOUT pin names (only the detail box names them), so the
   original transcription had to guess the pin order - and four pins were
   rotated. Verified pin reads (Ronny, top SBIT = HISTAT2, pins from top):
   pin2 = the XNOR increment output (**VINN** = the vector+1 bit),
   pin3 = **HIF** (the group F strobe, also on HISTAT1/HISTAT0),
   pin6 = **G_N** (same on all six SBITs).
   Correct wiring: `VINN`=XNOR chain, `DCDF`/`DCDFN`=HIF/HIFN (LOF/LOFN),
   `DCDG`/`DCDGN`=G_N/G, `GPE`=HIF (LOF), `SIN`=S-bus.
   As previously wired (`GPE`=HIF **with** `DCDG`=HIF_n) the S-bus load term
   was self-contradictory (`HIF & HIF_n`), and `VINN` was tied to a uniform
   strobe instead of the per-bit increment - which is why the status
   registers only ever read all-zeros or all-ones (LOSTAT = 0 or 7,
   HISTAT = 0) in every probe.

Net effect: **the Am2914 status fence never worked anywhere in this
machine.** Nothing but RUN exercises it (all 13 other INSTRUCTION-B areas
pass with the fence dead), so it went unnoticed until the IOX-error stress
storm - where the missing fence lets EXT14 re-dispatch at every macro
boundary, starving the level-14 handler before it can reach its `TRA IIC`
dismissal.

REGENERATION HAZARD: the Logisim CGA_INTR sheet needs the same corrections
(cell GATES_3 input + the six instance pin maps) or regenerating
`CGA_INTR_CNTLR_VECGEN_STAT*.v` reintroduces both bugs.

## STATUS 13-JUL late: FENCE FIX WORKS - livelock gone; a NEW bug is next

With the corrected wiring (below), enabled via `ND120_INTR_STATUS_FENCE`:

| | fence dead (before) | fence live (now) |
|---|---|---|
| EXT14 re-dispatches in the storm window | **14 487** | **1** |
| TRA IIC reached (the handler's dismissal) | 21 (all pre-storm) | **22 - it runs** |
| HISTAT / LOSTAT | stuck 0 / {0,7} | real values (7,3,2,5...) |
| CPU self-test | passes | **passes** (no regression) |
| INSTRUCTION-B boots | yes | **yes** |

The level-14 livelock is FIXED. The final wiring (all four cases fall out of
the confirmed cell equation + the MDCD strobe polarities):

    DCDF/DCDFN = HIF / HIF_n     (group F strobe: RDVECT-of-this-group, LDSTAT)
    DCDG/DCDGN = G / G_N         (G is ACTIVE LOW: 1 idle, 0 on RDVECT/MCLR)
    VINN       = XNOR chain      (the vector+1 bits)
    GPE        = HIGE / LOGE     (group-enable, the FIDBO3/FIDBO4 buffers)
    SIN        = S-bus
      idle -> hold | LDSTAT -> load S-bus | RDVECT -> load vector+1 | MCLR -> clear

The earlier "self-test hangs with the fence on" was MY error, not a second RTL
bug: I had DCDG/DCDGN swapped because I read G as active-high. The comparator
(VECGEN_CMP/MAGCMP, p.88 - computes VGES = (V >= S), the correct Am2914 rule)
and IRGEL (p.90-95) were AUDITED and are CORRECT - no changes needed there.

## NEXT BUG (new, exposed by the working fence): bogus IIC = "Memory Out of Range"

RUN now runs the level-14 handler properly, reads the internal-interrupt code,
and INSTRUCTION-B aborts with:

    Internal Interrupt. IIC: 11 -Memory Out of Range
    PES: 136000   PEA: 000000

But `CGA.v:114` has `assign s_nor_n = 1; //TODO: Fix MORN;` - the
memory-out-of-range input is TIED OFF, so the CPU cannot raise a real MOR.
Meanwhile the measured hardware vector is 2 = IREQ bit 10 = **IOX error**,
which IS what RUN's stressor should raise (the reference ND-110 prints
"IOX-ERROR STARTED" here). So the vector -> IIC read path decodes the wrong
code. Suspects: the PICV/PICS -> IDB path (`CGA_IDBCTL` SEL6 muxes, IDBS,PICVC)
and the AIIC/TRA IIC microcode's expectations; also the tied-off MORN itself
(a real gap - the ND-100 MOR source is not modelled).

Probe next: capture the IDB value the microcode reads at AIIC (csa 00725-00731)
together with PICV_2_0 / PICS_2_0, and compare with the IIC code INSTRUCTION-B
expects for an IOX error.

## Previous status (superseded)

Both corrections are in the tree behind **`ND120_INTR_STATUS_FENCE`
(default OFF)**; the default build keeps the historical fence-inert
behaviour (13/14 areas + 48/48 unit tests green).

WHY IT IS OFF: with the fence live, the machine hangs EARLIER - in the CPU
self-test's interrupt scan (microcode `APID3`, csa 00716-00717: the
`PIC,LOSTS` / `COND,IRQ` level scan), before INSTRUCTION-B even boots. So the
status register now holds real values and something downstream disagrees
with them. That points at the next unverified link:

- `CGA_INTR_CNTLR_VECGEN_CMP` / `..._CMP_MAGCMP` (p.88) - the priority
  comparator that gates a request against the status fence, and
- `CGA_INTR_CNTLR_IRGEL_*` (p.90-95) - the group request generate logic.

Both were written when the fence was permanently inert, so a polarity or
compare-direction error there would never have shown up. They need the same
schematic + Am2914 cross-check the STAT sheet just had. The Am2914 rule to
verify against: a request is enabled only when its vector is **>= the status
register value** (status = "lowest level that may still interrupt"), and
Status Overflow (vector 7 read) disables all.

Reproduce the hang: `make compile USE_LATCHES=0
EXTRA_VDEFINES="-DND120_INTR_STATUS_FENCE"` then `400$RUN`; probes
`ND120_PROBE_RUNIDENT` print `[irgel]`/`[pil]` lines. The candidate wiring is
also saved in the session scratchpad (`CANDIDATE_STAT.v`, `CANDIDATE_SBIT.v`).

## Earlier suspect (superseded, kept for the record)

The PLVO early return is BY DESIGN: `PLVO` compares BMG(new level) against
BMG(PIL) and returns when equal - a repeat entry at the current level is
SUPPOSED to skip the switch. And `LVSWP` contains no `PIC,LMSK` - the MPIE
mask is not per-level-maintained by the switch path. So the mask theory is
out.

The real suppressor must be the ND-100 "internal interrupts dispatch once,
re-armed only by reading IIC" rule. The livelock is a PREEMPTION-RESTART
loop: every new EXT14 dispatch restarts the level-14 handler from its entry,
so it never advances the several instructions to its `TRA IIC` while IOX
errors arrive every ~1000 evals. On real hardware the once-only gate lets
the handler run to completion between events.

Suspect location: `CGA_INTR_CNTLR_IRGEL` (schematic pages 90-95) - the
request-generate logic with its own flops, fed by the MDCD `S` strobe
(RDVECT&EPIC) and `H` strobe ({MCLR, RDVECT, LDSTAT}&EPIC) which look like
the arm/re-arm controls for exactly this gate. Note the EXT14 flow itself
issues `PIC,LOSTS` (= LDSTAT, an H-strobe member) at EXT14+3 on every entry
- if H re-arms the gate, correct behavior depends on fine ordering our RTL
may not honor.

Next probe: log the IRGEL flop states + the IRQ decision across a WORKING
startup EXT14->TAIIC sequence vs the storm entries; the divergent flop is
the bug.

## Verified NOT the cause

- MDCD HIK/LOK strobe gates: match the schematic (p.96) exactly - D0N/D1N/
  D4N with EPICN and the vector-clear-enable flops. A-OP 1 = CLRMPID and
  A-OP 4 = LCLRMPID are real PIC commands (Microprogrammer's Guide ND-06.031
  ch.3) missing from the ND110Compile token table, but the DELILAH microcode
  NEVER issues them - DELILAH dismisses internal detects via CLR14/MCLPID
  (data-path J clear, measured working).
- RQBIT latch semantics, IRSRC bit mapping, priority X-codes: all measured
  correct.
- Unanswered IDENTs: handled gracefully (INSTRUCTION-B's init sweeps all
  levels with no devices answering and proceeds fine).
- The C-model tape: answers and releases its level-12 IDENT correctly.

## HIVCE hold-term input: ruled R (scan illegible - decided by analysis)

The schematic scan (p.96) is unreadable at the HIVCE flop's hold input -
could be `P` or `R` (Ronny: leaning R, 13-JUL). RULED **R** by analysis:
(1) the HI/LO halves are mirror-symmetric everywhere else and LOVCE legibly
uses R; (2) R = the {MCLR,CLRMPID,LCLRMPID,RDVECT}&EPIC strobe, which gives
the flop exactly the "armed by RDVECT until the next clear-family command"
lifetime that LCLRMPID ("clear int for LAST vector read") requires; (3) the
only P-candidate (IRGEL PD) has no functional story here. Our
`CGA_INTR_CNTLR_MDCD.v` already uses the R-equivalent (`s_gates41_out`) for
both flops - **correct as-is, no change**. Functionally inert either way on
this machine (DELILAH microcode never issues LCLRMPID); re-verify only if
some future microcode uses the vector-read clear.

## Next steps

1. Probe the PLVO+1 condition inputs (F value) and the PICF2 rotate result
   during a successful pre-storm level switch vs the failing level-14 switch.
2. Compare the LMSK value written on switch-to-13 (works) vs switch-to-14
   (never happens).
3. Check the DELILAH listing comments around PLINT/PLVO/PICFM (nd120uc
   source) for the intended mask algorithm.

## 15-JUL: IIC=11 mechanism PINNED (measured), one semantic question open

Fence is ON+default. RUN passes the livelock; the remaining fatal is the
`TRA IIC` -> `IIC: 11 - Memory Out of Range` at PIL 14. Full [scan] probe
(runSim/Run120.cpp, ND120_PROBE_RUNIDENT) through the error window:

MEASURED, all datapath components VERIFIED CORRECT by read+sim:
- priority encoder PTYENC: IOX bit10->hivec2, MOR bit12->hivec4, INT14 bit14->hivec6 (correct)
- vector-hold VHR: holds hivec faithfully (HX=6 for INT14)
- magnitude comparator MAGCMP: VGES=(V>=S), hand-verified correct for V=6 vs S=5/6/7
- OSMUX: clean 2:1 status mux (PICS = selected group's 3-bit status)
- status LOAD path: during the IOX scan, HISTAT faithfully tracks the microcode's
  hisin fence writes (hisin3->histat3, hisin2->histat2, ...); comparator flips
  exactly right; the IOX scan finds vector 2 CORRECTLY and IOX is handled.

THE ANOMALY (dynamic, not a static miswire):
- After IOX is handled, at CLRXX/MCLPID (csa 01162) hisin=7 is presented and
  HISTAT latches 7 (LOSTAT stays 0). 
- INT14 is now pending (hidet=1, hivec=6) but 6 < 7 -> hivges=0 -> INT14 is
  FENCED OUT, never dispatched. CPU runs macro instructions with INT14 blocked.
- The test then executes `TRA IIC` (AIIC microcode: start Q=25oct, scan down,
  COND,IRQ). It returns level 12 (=IIC 11, MOR) instead of level 14 (=IIC 13,
  INT14). i.e. the scan's threshold lands at hi-vector 4, not 6.
- Asymmetry: LOW-group status rests at 0 (allows all) after its handling;
  HIGH-group status rests at 7 (blocks all) after IOX. High vs low differ.

OPEN SEMANTIC QUESTION (needs ND-120 ground truth): after servicing a
high-group internal interrupt (IOX, hi-vec2), what SHOULD the high status
(HISTAT) rest at - 0/low (allowing the pending INT14 hi-vec6 to dispatch), or
7 (blocking)? And what should CLRXX/`PIC,MCLPID` do to HISTAT - clear to 0, or
leave the fence? If HISTAT should be low, the bug is the MCLPID/clear path
leaving 7 (interacts with the status-fence fix); if 7 is correct, INT14 must
be dispatched by a different path and the AIIC down-scan mapping is the bug.

Probe staged to add G/HIF/RDVECT/MCLR/VINN strobes at csa 01162 to decide
whether the 7 comes from an LDSTAT(hisin=7), a mis-fired vector+1 load
(hivec+1: note hivec6+1=7!), or the MCLR path.

## 15-JUL (cont): AIIC scan fully mapped; divergence is the two-interrupt case

Microcode (ND-120-DELILAH-L.LISTING, CS 000725):
  AIIC1 725: RMSK->R6; 726: Q=IIE; 727: Q=IIE&37760; 730: LMSK=~Q;
        731: Q=25oct(=21); 732: PIC,ION B,13 (COND,F=0);
        733: PIC,LOSTS status=Q; 734: A=R3-Q (COND,F=0 F,RETURN);
        735: Q=Q-1, CLIRQ, loop-while-COND,IRQ; 736: Q=0 ->AIIC2;
        737 AIIC3: Q=Q-12oct; 740: A,16 SMPID; 742 AIIC2: LOSTS=R5 ->CLR14.
  Fence Q maps to chip status by bits: FIDBO_2_0=Q[2:0], FIDBO3=Q[3](HIGE=~),
  FIDBO4=Q[4](LOGE=~). So Q selects high vs low group and the 3-bit status.

MEASURED at the failing TRA IIC (probe [scan], csa 725-745):
- At CS 732 (PIC,ION B,13) hivec drops 6->2: the INT14 request (mireq bit14)
  is CLEARED mid-handler, leaving IOX (bit10, hivec2) as the top high request.
- The scan then runs against hivec=2 and the low-group requests, and the
  computed A cycles 11/12/13; the machine ends with IIC 11.
- histat=7 during macro execution is CORRECT (same-level fence at PIL 14).

STATE: every datapath block verified correct (PTYENC encoder, VHR, MAGCMP
comparator, OSMUX, and the status LOAD path - histat faithfully tracks the
microcode's fence writes in the clean IOX scan). The divergence is in the
DYNAMIC two-interrupt AIIC scan (IOX + INT14 both pending, INT14 cleared at
CS 732), and/or the Q->(HIGE/LOGE,status) fence encoding for that case.
Hand-simulating the decrement loop with the group-enable pipeline is where
solo analysis stalls (loop direction vs fence encoding ambiguous without the
ND-120 fence-value semantics). Next best measurements: (a) the C# internal-IIC
(IIC) scan for the IOX-ERROR phase - the golden per-step Q/status/IIC; or
(b) confirm the intended Q->group/status mapping and loop exit condition.

## 15-JUL: IIC architecture confirmed (nd100x + ND-120 uc-emulator) - the exact mapping

TRA IIC (nd100x cpu_instr.c:1888) returns calcIIC() = HIGHEST SET BIT of
(IID & IIE), then clears IID/IIC. IID is a SEPARATE register from the Am2914
IREQ. IID bit -> IIC code (console prints code in OCTAL):
  bit5=Z bit6=PI bit7=IOX bit8=PTY(10o) bit9=MOR(11o) bit10=POW(12o)

ND-120 uc-emulator note (Ronny): the two internal sources use DIFFERENT
conventions in the model:
  IOX -> SetInterruptDetectbits(1<<10)   = Am2914 IREQ bit 10 (hivec 2)
  MOR -> InternalInterruptLvl14(1<<9,..) = IID bit 9 directly

Reconciled mapping for our DELILAH hardware (IRSRC IREQ bits -> IIC):
  IOX IREQ10(hivec2) -> IID/IIC bit 7  (IIC 7)
  PAR IREQ11(hivec3) -> IID/IIC bit 8  (IIC 10o)
  MOR IREQ12(hivec4) -> IID/IIC bit 9  (IIC 11o)
  POW IREQ13(hivec5) -> IID/IIC bit 10 (IIC 12o)
  => IIC_bit = IREQ_bit - 3  (= hivec + 5)

THE BUG, quantified: console shows IIC 11o = bit 9 = MOR = IREQ bit 12
(hivec 4). But at the failure NO IREQ bit 12 is pending (mireq active =
bits 0,2,3,14; IOX bit10 already cleared). So the AIIC scan produces a code
(bit 9) that corresponds to NO pending source - a miscomputed scan result,
and it is exactly +2 from IOX's correct bit 7. The +2 (hivec2->as-if-hivec4,
or IREQ10->as-if-IREQ12) is the recurring signature. Root cause is in the
AIIC fence-scan arithmetic / Am2914-vector->IIC-code translation for the
high group, NOT a datapath miswire (all datapath verified correct).
Awaiting C# per-step IID/IIE/IIC trace to pin the exact divergent step.

## 15-JUL: ROOT CAUSE FOUND + FIXED - FIDBO[1]<->[2] swap (RUN passes)

THE BUG: CGA_INTR_CNTLR.v:109-111 swapped FIDBO bits 1 and 2 on the
status-fence write path (s_fidbo_2_0 -> VECGEN.FIDBO_2_0 -> HISIN/LOSIN, the
value the microcode LDSTAT writes into the Am2914 status register):
    s_fidbo_2_0[1] = s_fidbo_15_0[2];   // WRONG (swapped)
    s_fidbo_2_0[2] = s_fidbo_15_0[1];   // WRONG (swapped)
The swap maps 2<->4 and 3<->5 (values where bit1!=bit2); 0,1,6,7 unchanged.

WHY IT MISDECODES IOX AS MOR: the AIIC (TRA IIC) microcode scans the status
fence: writes fence=Q, checks IRQ = (hivec >= status). The hardware stored
histat = swap(Q&7) but the comparator used the UNSWAPPED hivec. For IOX
(hivec 2): hivges passes only when swap(Q&7) <= 2, i.e. Q&7 in {0,1,4};
highest = 4. So the microcode brackets IOX at ITS fence value 4 and computes
the IIC for vector 4 = MOR = IIC 11 octal, instead of vector 2 = IOX = IIC 7.

WHY ONLY RUN FAILED: only the LDSTAT (microcode-written status) path goes
through this swap. The normal interrupt fence uses the hardware RDVECT
vector+1 auto-load (VINN), which does NOT go through s_fidbo_2_0. So self-
test, RTC (level 13), and all 13 instruction areas - which use RDVECT-based
fencing - passed, and only RUN's internal-interrupt TRA IIC scan (LDSTAT-
based, and the only test exercising vectors 2/3 through it) failed.

RED HERRINGS RULED OUT along the way (all measured):
- The IIE&37760 mask DOES work: LMSK sets PICMASK[14]=1, hivec drops 6->2.
  (The C# LLM's "bit 14 leaks / mask missing" hypothesis was wrong for us.)
- MOR wiring not firing (MOR-off run byte-identical).
- Encoder (PTYENC), VHR, comparator (MAGCMP), OSMUX all verified correct.
- The swap initially looked ruled-out because post-swap histat=2 read as
  "found vec 2" - but that was swap(4); the microcode's fence was 4.

FIX: CGA_INTR_CNTLR.v now defaults to NO swap; escape hatch
ND120_INTR_FIDBO_SWAP_ORIG restores the original. VALIDATED 15-JUL:
self-test 0 STERR, unit suite 49/49, RUN handles IOX-ERROR and reaches
LEVEL 13 / ARGUMENT == END OF TEST == (the reference RUN-console-ND120.log
sequence). Full 13-area golden regression in progress.

C# behavior (TRA IIC clears IOX/MOR sources, keeps level-14 bit 14) is
CORRECT - matches nd100x (gIID=0 clears sources, gPID bit14 separate). Not
a bug.

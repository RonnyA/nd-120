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

## STATUS 13-JUL evening: fix implemented but GATED OFF - more work needed

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

# PLAN - find why SINTRAN does not finish booting from Winchester

Written 19-AUG-2026. Method-first plan. The previous approach - inventing a
probe, reading its output, building a theory - produced five findings that were
all artifacts. This plan replaces it with a self-validating comparison against
the nd100x oracle, which boots the same image correctly.

## Ground truth (measured, survives scrutiny)

| fact | evidence |
|---|---|
| The oracle boots `WD0-sim.IMG` to `SINTRAN III RUNNING` | banner between 17M and 18M instructions, bisected |
| Sim RTC ticked 16.5x too fast | `VERILATOR_SIM` hardcodes `RTC_20MS=8192`; Tang uses 134,999 |
| Fixing it is a real gain | PIL profile matched the oracle (user 50.4 vs 49.0, kernel 42.0 vs 42.6); 97 disc ops in 8 h -> 151 in 4.5 h |
| The boot reaches ~70% of the way | control-write landmark 687 of the ~986 at the banner |
| Then it stops | disc frozen at op 151, level 1 idling, no banner |
| Both machines execute identically at the start | ND-120 and oracle traces match row-for-row, PC+opcode, for 2,036 instructions |
| First divergence is BENIGN | at ~2,037: `--boot=wd` loads core directly, we load through the card, so the card's status differs |

## Retracted - do not rebuild on these

PGF gate counted as faults; "op 71 stall"; "180x slower"; "indirect JPL lands
one word early"; "T=0 triggers it". Each came from misreading a hand-built
probe. See the memory notes for why each died.

---

## PHASE 0 - protect what works  (est. 1 h)

- [ ] 0.1 Decide the status of the RTC fix. It is a SIM-ONLY parameter, not
      original design: `RTC_REAL_PERIOD` + `BOARD_CLK_FREQ`. Options: leave as
      an opt-in flag, or make it the sim default. RONNY DECIDES - it changes
      every future sim result.
- [ ] 0.2 Record the exact build line that reaches landmark 687 so it can be
      reproduced cold.
- [ ] 0.3 Confirm the `test-mac-replay` harness reports SKIP (not FAIL) with no
      capture, so it cannot break `make test`.

**Exit:** the best-known-good build is reproducible by anyone from the notes.

## PHASE 1 - make the comparison trustworthy  (est. 2-3 h)

Tool: `lockstep.py` (timing-tolerant comparator, already written).
Tolerances implemented: drop PIL>=10 interrupts; fold repeated loop CYCLES;
compare equal COLLAPSED work; flag only addresses one machine never executes.

- [ ] 1.1 Build the KNOWN-BENIGN CATALOGUE. Every difference the comparator
      reports must be explained once and then suppressed by name:
      - boot mechanism (oracle loads core directly, we load via the card)
      - disc wait-loop re-entry (oracle's disc is instant)
      - anything else found - each needs a written reason, not a hand-wave.
- [ ] 1.2 Prove the catalogue is complete over a span where BOTH machines are
      known healthy (early boot, before landmark 277). Target: zero unexplained
      differences there.
- [ ] 1.3 Only when 1.2 passes is the tool trusted. **If it never passes, the
      tool is wrong - fix it, do not start interpreting its output.**

**Exit:** a clean run over healthy territory, with every difference either
matched or in the catalogue.

## PHASE 2 - find the first REAL divergence  (est. 4-6 h, mostly machine time)

- [ ] 2.1 Produce one ND-120 trace that reaches the stop point (~16M
      instructions) with the RTC fix. One run, ~4.5 h. Already done once -
      reuse `nd120_jpl.trc` if it is intact.
- [ ] 2.2 Run the comparator in windows across the whole boot, not one pass:
      the traces drift, so compare landmark-anchored segments.
- [ ] 2.3 For each flagged difference, apply the discriminator: does the oracle
      EVER execute those addresses? Only "never" counts.
- [ ] 2.4 Take the EARLIEST surviving difference. That is the lead.

**Exit:** one instruction address, with the oracle's behaviour and ours side by
side, and a reason to believe it is not in the catalogue.

## PHASE 3 - root-cause it in RTL  (est. 1-2 days)

- [ ] 3.1 Identify the instruction and what it depends on (register, memory
      word, device register).
- [ ] 3.2 Read the ORIGINAL DRAWING for that logic before touching anything.
      Faithfulness to the drawings is the rule; a transcription error is the
      expected class of bug, not a redesign.
- [ ] 3.3 Write a unit testbench that reproduces the wrong behaviour from
      captured inputs, in BOTH latch and FF mode. Must fail before the fix.
- [ ] 3.4 Only then propose a change, with the drawing reference.

**Exit:** a failing testbench that isolates the fault to one module.

## PHASE 4 - fix and prove  (est. 1 day)

- [ ] 4.1 Apply the minimal change. No adjacent "improvements".
- [ ] 4.2 Unit tb passes in both modes; register it in `tests/run_all_tests.sh`
      with a strict pass pattern.
- [ ] 4.3 `make test` green.
- [ ] 4.4 Re-run the boot; the landmark count must move past 687.
- [ ] 4.5 Re-run the comparator; the divergence must be gone and no new one
      introduced before it.

**Exit:** boot progresses further, with a regression test that would catch the
bug returning.

## PHASE 5 - repeat or finish  (unbounded)

- [ ] 5.1 If the banner appears: run the full boot to a login, then move to
      silicon.
- [ ] 5.2 If it stops again: return to PHASE 2 from the new stop point. Each
      cycle should be faster - the catalogue and the tooling carry over.

---

## Rules for this hunt (learned the hard way)

1. **Never report a finding from a single instrument.** Cross-check against the
   oracle or a second signal first.
2. **Know the instrument's semantics before reading it.** The trace prints
   `P-1`; `OP=000027` is the trap signature, not an instruction; the PGF gate
   is a signal, not an event.
3. **A probe that never fires is a RESULT.** The silent ring on `144162` was
   the truth; the window was not at fault.
4. **Timing differences are not bugs.** The oracle's disc is instant and its
   boot load bypasses the card. Any comparison must tolerate that by
   construction.
5. **Judge progress by instructions and landmarks, never by device-op counts.**
6. **Testbenches, not boots, for module questions.** A boot costs hours and
   answers one bit; a tb costs seconds, runs both clocking modes, and becomes a
   permanent regression test.

# PAL_44601B (CYCFSM) Transcription Analysis

Analysis target: `Verilog/PAL/PAL_44601B.v`
Design-intent sources: `Verilog/cycle_clock.md`, `Verilog/CycleControl.png`
Wiring context: `Verilog/CPU-BOARD-3202/circuit/CYC_36.v`

Scope: read-only review for a possible PALASM-to-Verilog transcription
error. No Verilog file was modified.

--------------------------------------------------------------------

## 1. Summary verdict

The PAL counts CORRECTLY. `PAL_44601B` implements a full 16-state
4-bit Gray-code counter (CC3..CC0) that free-runs one Gray step per
clock and is force-reset to 0000 by the registered TERM output. Every
one of the 16 state-to-state advances is an exact single-bit Gray step.
TERM asserts in exactly the intended states (a, b, c, f, g, p) under the
correct input conditions, and the resulting cycle lengths match the
documented 50 / 75 / 100 / 175 / 205 ns cycles and the p (XSLOW)
backstop.

No functional transcription error was found. Confidence: high - every
state and every next-state register bit was derived by hand from the
active equations and cross-checked against the Gray sequence and the
`Verilog/CycleControl.png` state diagram.

Two purely COSMETIC comment mislabels were found (they do not affect
logic). They are listed in section 5.

--------------------------------------------------------------------

## 2. Design intent (from cycle_clock.md and CycleControl.png)

The CC field is a standard 4-bit Gray code. The documented ring is:

```
  a=0000  b=0001  c=0011  d=0010  e=0110  f=0111  g=0101  h=0100
  i=1100  j=1101  k=1111  l=1110  m=1010  n=1011  o=1001  p=1000
```

Each adjacent pair differs by exactly one bit, and p=1000 wraps back to
a=0000. This is exactly the reflected binary Gray sequence for 0..15.

Intended behaviour:

- The counter starts each cycle at a=0000 (after a TERM reset).
- Each clock it advances one Gray step, UNLESS the current state meets
  its "terminate" condition, in which case TERM is asserted and the
  counter is pulled back to 0000 on the following clock.
- The state that asserts TERM sets the cycle length. From the diagram
  the horizontal "exit to t" arrows (TERM) leave from states a, b, c,
  f, g and from p ("the rest").
- States d and e are wait states: they hold (loop on themselves) until
  a bus / boundary condition resolves, then advance.

Intended TERM states and conditions (from the `//` comments and the
picture):

| State | CC    | TERM condition                         | Cycle    |
|-------|-------|----------------------------------------|----------|
| a     | 0000  | SHORT & DLY0_n & CSDELAY0_n            | 50.2 ns  |
| b     | 0001  | (SHORT | HIT) & BRK_n & DLY1_n         | 76.8 ns  |
| c     | 0011  | (SHORT | HIT) & BRK_n                  | 102.4 ns |
| f     | 0111  | BRK                                    | 179.2 ns |
| g     | 0101  | SLOW                                   | 205.4 ns |
| p     | 1000  | (unconditional: state = 1000)          | 435.2 ns |

Intended wait branches:

| State | CC    | Advance (leave) condition               | Loop (stay) condition          |
|-------|-------|-----------------------------------------|--------------------------------|
| d     | 0010  | CGNTCACT | WAIT1_n | BRK                | CGNTCACT_n & WAIT1 & BRK_n     |
| e     | 0110  | CGNTCACT_n | BRK | WAIT2_n              | CGNTCACT & WAIT2 & BRK_n      |
| c     | 0011  | not (CGNTCACT & BRK_n)  -> go to d      | CGNTCACT & BRK_n (prev write) |

Note the deliberate CGNTCACT polarity FLIP between d (advances on
CGNTCACT) and e (advances on CGNTCACT_n). This looks like it could be a
transcription slip but it is correct - the picture labels d "wait for
bus /CGNTCACT" and e "wait for bdry CGNTCACT", i.e. opposite bus
senses.

--------------------------------------------------------------------

## 3. What the Verilog equations actually compute

Conventions used below: c3,c2,c1,c0 = CC3_reg..CC0_reg (current);
T = s_term_n_int = ~TERM_reg (1 => not terminating). All CCx next-state
terms are AND-gated by T, so when TERM_reg=1 every term is 0 and the
next state is 0000 (a). That is the "reset to a" mechanism.

The register equations reduce cleanly (all reductions verified by
enumerating the relevant states):

TERM_reg (PAL_44601B.v lines 112-123, active in the `if (s_term_n_int)`
block):
```
TERM_reg <=
    (c3_n & c2_n & c1_n & c0_n & SHORT & DLY0_n & CSDELAY0_n)  // line 113  state a (0000)
  | (c3_n & c2_n & c1_n & c0   & SHORT & BRK_n  & DLY1_n)      // line 114  state b (0001)
  | (c3_n & c2_n & c1_n & c0   & HIT   & BRK_n  & DLY1_n)      // line 115  state b (0001)
  | (c3_n & c2_n & c1   & c0   & SHORT & BRK_n)                // line 116  state c (0011)
  | (c3_n & c2_n & c1   & c0   & HIT   & BRK_n)                // line 117  state c (0011)
  | (c3_n & c2   & c1   & c0   & BRK)                          // line 118  state f (0111)
  | (c3_n & c2   & c1_n & c0   & SLOW)                         // line 119  state g (0101)
  | (c3   & c2_n & c1_n & c0_n)                                // line 120  state p (1000)
```
Every product term selects exactly one of a, b, c, f, g, p and carries
exactly the intended input literals. This matches section 2 term for
term.

CC0_reg (lines 87-90 CC0_COMMON, plus lines 228-239):
```
CC0_COMMON = (c3_n&c2_n&c1_n&T) | (c3&c2&c1_n&T) | (c3&c2_n&c1&T)
```
Reduces to CC0=1-next for states a,b (0000/0001), i,j (1100/1101),
m,n (1010/1011) - i.e. the states whose Gray successor has CC0=1 for a
"common" reason.

CC0 else-branch (c0=0), lines 236-238, adds the state-e advance:
```
(c3_n&c2&c1 & CGNTCACT_n & T) | (c3_n&c2&c1 & BRK & T) | (c3_n&c2&c1 & WAIT2_n & T)
```
= state e (0110) sets CC0 (advance e->f) when CGNTCACT_n | BRK | WAIT2_n.

CC0 if-branch (c0=1), lines 231-232, adds the state-c prev-write hold:
```
(c3_n&c2&c1&T)                              // f (0111) keeps CC0=1 -> f->g
(c3_n&c2_n&c1 & CGNTCACT & BRK_n & T)       // c (0011) holds CC0=1 (prev write) -> stay c
```

CC1_reg (lines 197-208) reduces to:
- from c1=1 states: CC1 stays 1 unless (c0=1 & c3!=c2). It clears only
  at f=0111 and n=1011. Both are correct Gray transitions
  (f->g clears CC1, n->o clears CC1).
- from c1=0 states: CC1 sets when (c0=1 & c3==c2). It sets only at
  b=0001 and j=1101 (b->c, j->k). Correct.

CC2_reg (lines 169-181) reduces to:
- from c2=1 states: CC2 stays 1 unless (c3 & c1 & c0_n). Clears only at
  l=1110 (l->m). Correct.
- from c2=0 states: CC2 sets only at d=0010, gated by
  (CGNTCACT | WAIT1_n | BRK) (d->e advance / wait). Correct.

CC3_reg (lines 141-152):
- forced set when (c2 & c1_n & c0_n) -> states h=0100 and i=1100. This
  both performs h->i (set CC3) and holds CC3=1 in i (whose persistence
  OR would otherwise fail because i has c1=0,c0=0). This is essential
  and correct.
- else, when c3=1, persistence reduces to (c1 | c0): CC3 stays 1 in
  j,k,l,m,n,o and clears only at p=1000 (p->a wrap). Correct.

--------------------------------------------------------------------

## 4. State-by-state comparison (intended vs actual)

Each row was derived by substituting the current state into the actual
equations with T=1 and the advance branch chosen. "Bits changed" is the
XOR of current and next CC.

| Cur state | Cur CC | Actual next CC | Next state | Bits changed | Gray step? |
|-----------|--------|----------------|------------|--------------|------------|
| a | 0000 | 0001 | b | 1 (CC0) | yes |
| b | 0001 | 0011 | c | 1 (CC1) | yes |
| c | 0011 | 0010 | d | 1 (CC0) | yes (or hold c if prev-write) |
| d | 0010 | 0110 | e | 1 (CC2) | yes (or hold d if bus wait) |
| e | 0110 | 0111 | f | 1 (CC0) | yes (or hold e if bdry wait) |
| f | 0111 | 0101 | g | 1 (CC1) | yes |
| g | 0101 | 0100 | h | 1 (CC0) | yes |
| h | 0100 | 1100 | i | 1 (CC3) | yes |
| i | 1100 | 1101 | j | 1 (CC0) | yes |
| j | 1101 | 1111 | k | 1 (CC1) | yes |
| k | 1111 | 1110 | l | 1 (CC0) | yes |
| l | 1110 | 1010 | m | 1 (CC2) | yes |
| m | 1010 | 1011 | n | 1 (CC0) | yes |
| n | 1011 | 1001 | o | 1 (CC1) | yes |
| o | 1001 | 1000 | p | 1 (CC0) | yes |
| p | 1000 | 0000 | a | 1 (CC3) | yes (wrap; TERM also asserts) |

Result: all 16 advances are exact single-bit Gray steps. No transition
flips more than one CC bit.

Reachability / deadlock:
- Every state is reachable via the ring a..p->a.
- The only holding states are c (prev-write), d (bus wait) and e
  (boundary wait). Each holds only while an external bus/wait signal is
  unresolved and advances as soon as it resolves - normal bus handshake,
  not a logic deadlock.
- p=1000 asserts TERM unconditionally (line 120 has no input literal),
  so the longest possible cycle always terminates. There is no runaway
  and no unreachable state.

TERM placement / cycle length check (base clock ~25.6 ns):
- a: TERM at 0000 -> 2 clocks -> ~51 ns   (matches 50.2 / 51.2 ns)
- b: TERM at 0001 -> 3 clocks -> ~77 ns   (matches 76.8 ns)
- c: TERM at 0011 -> 4 clocks -> ~102 ns  (matches 102.4 ns)
- f: TERM at 0111 -> 7 clocks -> ~179 ns  (matches 179.2 ns)
- g: TERM at 0101 -> 8 clocks -> ~205 ns  (matches 205.4 ns)
- p: TERM at 1000 -> ~17 clocks -> ~435 ns (matches 435.2 ns)

All TERM conditions carry the correct input literals (SHORT, HIT,
BRK_n, DLY0_n, DLY1_n, CSDELAY0_n, SLOW), matching the picture labels.

--------------------------------------------------------------------

## 5. Suspected errors

Functional transcription errors: NONE FOUND.

The one construct most likely to be mistaken for an error - the
CGNTCACT polarity difference between state d (advance on CGNTCACT,
line 178) and state e (advance on CGNTCACT_n, line 236) - was checked
against `Verilog/CycleControl.png` and is CORRECT (d = "wait for bus
/CGNTCACT", e = "wait for bdry CGNTCACT", opposite bus senses by
design).

Cosmetic-only comment mislabels (no logic impact, listed for accuracy):

1. `Verilog/PAL/PAL_44601B.v` line 88, CC0_COMMON comment
   `// a+b+f+i+j+m+N`.
   The term `(s_cc3_n_int & s_cc2_n_int & s_cc1_n_int & s_term_n_int)`
   is true for states a (0000) and b (0001) only; together with the two
   other CC0_COMMON terms the covered set is a,b,i,j,m,n. The letter
   `f` in the comment is spurious (f=0111 has CC1=1 and cannot match
   this product term). Suggest reading it as `a+b+i+j+m+n`. Logic is
   correct; only the comment is off.

2. `Verilog/PAL/PAL_44601B.v` line 232, comment `// e PREV WRITE`.
   This term is inside the `if (CC0)` branch and is
   `(s_cc3_n_int & s_cc2_n_int & CC1 & CGNTCACT & BRK_n & s_term_n_int)`,
   which selects CC = 0011 = state c, not state e. The picture labels
   the prev-write self-loop on state c ("previous write CGNTCACT*/BRK").
   The comment should say `c PREV WRITE`. Logic is correct; only the
   comment is mislabelled.

--------------------------------------------------------------------

## 6. Conclusion

`PAL_44601B` is a faithful transcription of the CYCFSM cycle-control
state counter. It realises the intended 16-state Gray-code sequence with
single-bit transitions throughout, correct wait-state hold/advance
logic for states c, d and e (including the intentional CGNTCACT
polarity flip between d and e), and TERM assertion in exactly states a,
b, c, f, g and p with the correct input qualifiers and cycle lengths.
No PALASM-to-Verilog transcription error affecting behaviour was found.
The only discrepancies are two inaccurate `//` comments (lines 88 and
232), which have no effect on the synthesised or simulated logic.

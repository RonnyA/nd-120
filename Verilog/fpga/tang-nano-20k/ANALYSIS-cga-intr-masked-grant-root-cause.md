# ANALYSIS — Tang "masked level-10 grant": root-cause investigation (OPEN)

**Full path:** `/mnt/e/Dev/Repos/Ronny/nd-120/Verilog/fpga/tang-nano-20k/ANALYSIS-cga-intr-masked-grant-root-cause.md`
**Status:** ROOT-CAUSE HUNT IN PROGRESS. An earlier trap-side guard was written and
then **REVERTED** (18-JUL) at Ronny's direction — it treated the symptom, not the
cause, and it deviated from the schematics. We are now finding the real cause.
**Answering:** `/mnt/e/Dev/Repos/Ronny/nd-120/Verilog/fpga/tang-nano-20k/HANDOFF-cga-intr-masked-grant-analysis.md`.

---

## 1. The mechanism (measured + source-verified — this part stands)

The Tang "masked level-10 grant" is a **cause-less trap dispatch**, not an Am2914
grant:

- `INTRQN` (CGA/INTR p.74, `CGA_INTR.v` `MEMORY_2`) = a one-MCLK-delayed register
  of `PAN | IRQ` (D = NAND(IRQN,PANN); async clear CLIRQN; **no hold feedback** —
  schematic-confirmed by Ronny 18-JUL).
- The trap break trigger is `IFETCH & INTRQ` (CGA/TRAP/BRKDET p.103, `INTR` NAND —
  schematic-confirmed: exactly two inputs).
- The panel-vs-macro classification is the 5-input NAND (CGA/TRAP/TVGEN p.104,
  `GATES_6` → `L3V0_FF`): inputs VTRPN, IFETCH, INTRQ, PAN, DSTOPN —
  schematic-confirmed: exactly five, **no IRQ/claim input**. PAN up → trap vec 16
  (panel); PAN down → trap vec 17 (macro interrupt).
- Trap vec 17 microcode does `PIC,RVECT` (CS 000017). With nothing claiming the
  read returns 0, and the interrupt vector table `ITSRV` (CS 003740) maps **entry
  0 → Q=12 octal = level 10**.

So a dispatch taken off the **lagged** INTRQN, after its cause dropped, is
classified "macro interrupt" (live PAN=0), reads an **empty** vector = 0, and
switches to **level 10**. Measured signature (`piltrace.log`): PIL 0→10, PIE=0,
P never advanced (instruction stream not involved). A *genuinely pending* level-10
would read 010 octal → level 14, not 10 — confirming the read was empty.

**Schematic validation (Ronny, 18-JUL):** all four transcription points above
(TBUF inverters, TVGEN 5-input NAND, BRKDET INTR NAND, INTRQN FF D-cone) match the
original DELILAH sheets. **The window exists in the design as drawn.** So the trap
logic is NOT where a transcription bug lives.

## 2. Why this is a ROOT-CAUSE question, not a patch target

The real machine ran this design for years without wedging. Two things differ on
our board and are the actual suspects for *why the window is reachable here*:

### Suspect A — clock-phase fidelity of the FF conversion (PRIME)
The two racing captures use **different clocks**: INTRQN on MCLK, the vec-17
classification FF (`L3V0`) on TCLK. On the real chip TCLK/MCLK are fixed phases of
one microcycle with a guaranteed order. In our FPGA FF-mode conversion (this
branch's whole topic) both became sysclk clock-enable pulses (`MCLK_EN`, `TCLK_EN`)
placed by CYC_36. **If our enable ordering does not reproduce the original
TCLK-vs-MCLK phase order, we may have created or widened the lag window ourselves.**
That would be a faithful-to-fix implementation bug, no schematic deviation.
→ ACTION: audit CYC_36 enable placement vs the timing sheets; watch MCLK_EN,
   TCLK_EN, INTRQN, PAN, IRQ, TVEC, BRKN together in Verilator.

### Suspect B — the missing MC68705U3 panel controller (PRIME)
The real panel-attention signal comes from the on-board **MC68705U3** panel
microcontroller (CPU board sheet 40). It is NOT implemented. In its place,
`IO_37.v` (`s_conkick`, lines ~330-360) fabricates a **32-sysclk STAT3 pulse on
every UART TBMT drain** to stream console output. That synthetic panel traffic is
un-original and is a leading candidate for injecting the PAN pulses whose lag
produces the misfire.
→ ACTION: study the real U3 behaviour (`Code/68705/U3/`) — how it raises/holds the
   panel-attention line and its timing relative to the CPU handshake — and either
   model it faithfully or, while it is absent, ensure the stand-in cannot raise a
   panel interrupt in a way the real chip never would.

## 3. Plan (agreed with Ronny 18-JUL)

1. **Verilator signal-watch + clock analysis (do first, no hardware):** trace the
   CYC_36 phase generation and watch MCLK_EN / TCLK_EN / MCLK / TCLK / INTRQN / PAN /
   IRQ / TVEC / BRKN across the failure cadence (`RTC_REAL_PERIOD`,
   `BOARD_CLK_FREQ=27000000`, real-rate UART) to see whether the window is a phase
   artefact. Prefer fixing without GAO.
2. **68705U3 study:** analyse `Code/68705/U3/Analysis-U3.md`, `Commands-U3.md`,
   `C-code-u3.md` and sheet 40; decide faithful model vs. safe stand-in; at minimum
   stop the missing-panel stand-in from triggering spurious interrupts.
3. **GAO only if needed** (Ronny prefers not).

## 3b. Experiment A RESULT — Verilator does NOT reproduce it (18-JUL, measured)

Non-invasive probe added to `runSim/Run120.cpp` behind `-DND120_PROBE_VEC17`
(no RTL changed; all signal paths compiler-verified via `--public-flat-rw`).
Two triggers: (1) entry to macro-interrupt vector CS 000017; (2) the ACTUAL
silicon signature — PIL switching 0->nonzero. Each dumps the full claim picture
(IRQ, IREQ_n, MIREQ, PICV, PAN_n, INTRQN) plus a 64-sample history ring.

Run 1 — normal sim cadence, `20!`, 3M cycles:
- CS 000017 entered 80x, **every time with PAN asserted** (pann=0), IRQ=0,
  PIL stays 0, no wedge. These are legitimate panel/console dispatches (PAN is
  the cause; the panel path does not use the maskable IRQ mechanism).
- A dispatch with PAN de-asserted (pann=1) + IRQ=0 (the bug fingerprint):
  **never occurs.**
- **This DISPROVES the "empty macro-vector dispatch -> level 10" story** — sim
  does that empty dispatch 80x, harmlessly.

Run 2 — faithful silicon cadence (`-DRTC_REAL_PERIOD -DBOARD_CLK_FREQ=27000000`,
Tang 27 MHz), `20!`, ~9M cycles (~17 real RTC ticks):
- Every PIL switch is **0->13** (21 of them), one per ~540 000-cycle RTC
  period = the OS clock interrupt at level 13, driven by a real pending request
  (ireq_n bit 3 = 0), executing the normal PLINT/PLVO/LVSWP microcode
  (CSA 01140->01155). Legitimate.
- **PIL->10 (the silicon wedge) NEVER occurs. No masked/causeless grant.**
- The one PILSW flagged "EMPTY-CLAIM" was the *tail* of a legitimate level-13
  switch (cause already consumed earlier in the routine) — a false positive of
  the empty test, not a real event.

**Conclusion of A:** Verilator does not reproduce the grant even at faithful
real cadence. This **kills the cadence hypothesis** and confirms the effect is
genuinely **silicon-specific real-timing** on Gowin (as the original handoff
framed it) — not a logic/cadence artifact, and not the trap-classification
path I first proposed. The lag/skew between IRQ and the request register IS
present in sim (visible on the level-13 switches: IRQ=0 while a request is
pending) but is **benign** there because a real cause is always present when a
switch happens. On silicon a switch happens to **level 10 with a pending-but-
not-enabled PID bit 10** (PID=002000, PIE=0) — the Am2914 masked-grant framing.
So the refocused suspect is the **grant cone** (int_req_q enable FF / mask /
priority) on Gowin real delays, NOT the CGA_TRAP dispatch.

## 3c. Experiment B (next — needs silicon; A did not answer it)

A did not reproduce, so B is required: observe on the physical Tang what the
grant actually does. Options (Ronny prefers to avoid GAO):
- **B1 (GAO-free, preferred):** extend the existing 512-sample debug capture in
  `ND120_TANG20K_TOP.v` to record CSA + PIL + PICMASK[2] + int_req_q(HI/LO) +
  IREQ[10] + PID[10] + PAN, triggered on the PIL->10 edge; single-step the cold
  start and read it back. Shows whether the grant comes through the Am2914
  claim (HVE/LVE) or a level-switch strobe, and whether int_req_q was 1.
- **B2 (GAO):** trigger on the grant net directly.
- **B3 (OPCOM only):** during the single-step trace, also read PICMASK / int-
  req state each step (I2/I3-type reads) to see the enable/mask at the grant.

Recommendation: B1 — it is the decisive, GAO-free measurement and reuses the
capture block already in the Tang top.

### B1 — BUILT (18-JUL), ready to flash. How to run it

RTL instrumentation is in and compile-clean (both build modes). Files touched
(all instrumentation, gated / passthrough — default builds unaffected):
- `/mnt/e/Dev/Repos/Ronny/nd-120/Verilog/ND120_CORE.v` — new `PIL[3:0]` output
  passthrough (the board's PIL was left unconnected; now forwarded).
- `/mnt/e/Dev/Repos/Ronny/nd-120/Verilog/fpga/tang-nano-20k/src/ND120_TANG20K_TOP.v`
  — the 512-sample analyzer's source/trigger/split switch on `TANG_GRANT_CAPTURE`.
- `/mnt/e/Dev/Repos/Ronny/nd-120/Verilog/fpga/tang-nano-20k/src/tang20k_defines.v`
  — the (commented) `TANG_GRANT_CAPTURE` define + doc.

Steps:
1. Uncomment `` `define TANG_GRANT_CAPTURE `` in
   `/mnt/e/Dev/Repos/Ronny/nd-120/Verilog/fpga/tang-nano-20k/src/tang20k_defines.v`.
2. Full Gowin rebuild (`make gowin`) and flash. (Mind the load-gowin
   stale-bitstream trap: verify the flashed .fs mtime/sha vs the fresh build.)
3. Reproduce the wedge as before: btn1 (MACL, keeps SDRAM) -> software `MACL`
   -> deposit P=0 -> single-step (`Z`) until PIL switches to 10 (~step 18).
4. On that step the capture fires; the debug UART TX then streams **512 lines
   of 4 hex digits** at 9600. Capture them (they replace the console output;
   the console is dead post-wedge anyway).
5. Decode each line `HHHH`: **PIL = hex digit 1** (`H[15:12]`), **CSA =
   lower 3 hex digits** (`H[11:0]`) — then read CSA in OCTAL. The samples are
   oldest-first; the last ~64 are post-switch, the ~448 before are the lead-up.

What the CSA sequence tells us (the decisive fork):
- If CSA marches `...01133(PLINT) -> 01140(PLVO) -> 01146..01155(LVSWP)` into
  the PIL=10 sample => the microcode *deliberately* switched to level 10, i.e.
  the Am2914 priority/enable told it level 10 was the top enabled request ->
  root cause is in the **grant cone** (int_req_q enable FF / mask / priority),
  and B1-stage-2 adds those bits.
- If CSA does something else (jumps straight, or through 00017/00016, or a
  path with no PLINT) => the switch is NOT a normal microcode level-change and
  the mechanism is elsewhere (trap dispatch or a hardware level-load strobe).

Either outcome narrows it decisively without GAO. If stage 1 implicates the
grant cone, stage 2 threads int_req_q(HI/LO) + HVE + PICMASK[10] + IREQ[10]
up (leaf signals already carry `syn_keep`) into the spare capture-word bits.

**Validated in sim (18-JUL):** the Tang `vtest` (Verilator) built with
`-DTANG_GRANT_CAPTURE` still PASSES (boot + deposit 22/054321 + readback +
BREAK reset). The capture rings silently and never fires (sim never reaches
PIL=10), so the instrumentation is proven non-disruptive to normal operation —
it only seizes the UART if PIL actually hits 10 on the board.

**Practical run note (silicon):**
- `make gowin` runs on the Windows host (PowerShell `gowin_build.ps1`) — build
  there, then flash the fresh `.fs` (verify mtime/sha; the load-gowin trap).
- Step with `/mnt/e/Dev/Repos/Ronny/nd-120/Verilog/fpga/tang-nano-20k/scratch_piltrace.py`
  as before. At the step where PIL->10 (~18), the capture arms cap_done, waits
  a few seconds (hold_cnt), then the debug dumper SEIZES the console TX and
  streams the 512 hex lines. So: once piltrace reports the PIL=10 grant, STOP
  stepping and just record the raw UART for ~5-10 s — those 512 `HHHH` lines
  are the capture. (I can add a tiny post-wedge raw-UART reader to the script
  when you get to this step.)

## 3d. Experiment B1 RESULT — MEASURED ON SILICON (18-JUL) — DECISIVE

Flashed the `TANG_GRANT_CAPTURE` bitstream (built here via `make gowin`, PnR fit),
attached the Tang, ran `grant_capture.py`: single-step from P=0 wedged at
**step 18 (P 0o21->0o24, STS=015000, PIL=10, PID=002000, PIE=0)** and the on-chip
capture dumped the CSA path of that fatal step. Measured de-duplicated CSA
sequence (octal), verbatim:

    ... 07310  00214  00017  00053 00054 00055 00056 00057  03740
        01131  01133 01134..01137  01140 01141..01145  01146 01147 01150
        01151 01152 01153 01154 01155  ->  [PIL=10] 01155 01156 01157 ...

Decode against the microcode:
- `00214 -> 00017`: a **trap dispatch to the MACRO-INTERRUPT vector** (CS 000017,
  "17/ % MACRO INTERRUPT", PIC,RVECT->MACRI) interrupts the cold-start stream.
- `00053..00057` = **MACRI** (`A,R1 ... JMPAOPR ITSRV`).
- `03740` = **ITSRV entry 0**. Reaching ITSRV+0 PROVES the vector read (R1) was
  **0 = EMPTY claim** (ITSRV+0: `B,12` -> Q=12 octal = **level 10**).
- `01133 PLINT -> 01140 PLVO -> 01146..01155 LVSWP`: the normal level-switch
  microcode runs and lands PIL=10 at 01155 (LVSWP+7, ACTLV/PIL update). PID bit
  10 (=002000) is set here by PLINT as part of the switch.

**CONCLUSION (proven on silicon): the wedge is a MACRO-INTERRUPT trap dispatch
(vector 17) taken with an EMPTY vector claim, which MACRI maps through ITSRV
entry 0 to LEVEL 10.** It is NOT a hardware Am2914 grant-cone glitch; it goes
through the CGA_TRAP dispatch + the ordinary level-switch microcode.

**This VINDICATES the original section-1 mechanism and CORRECTS Experiment A's
misread.** In sim, the 80 CS-000017 dispatches had PAN *asserted* (a real panel
cause) so MACRI read a real vector, not entry 0 - harmless. The *truly empty*
dispatch (PAN already dropped -> classified macro -> read 0 -> ITSRV+0 -> level
10) does not occur in sim's cadence but DOES on silicon. So the reverted
CGA_TRAP guard (qualify INTRQ with the live cause PAN|IRQ) was aimed at exactly
the right mechanism - we now have the silicon proof the analysis lacked.

Still to pin (B1 stage 2): the trap fires on `IFETCH & INTRQ`; with no maskable
claim pending the only thing that sets INTRQN is a PAN pulse (RTC 20 ms tick or
the un-original IO_37 `conkick` console-pacing STAT3->PRQ->PAN). Stage 2 adds
INTRQ / PAN / IRQ (and a conkick-vs-RTC discriminator) to the capture word to
show the stale-INTRQN directly (INTRQ=1, PAN=0, IRQ=0 at the 00017 dispatch) and
identify which PAN source triggered it - which decides the FAITHFUL fix:
- if it is the `conkick` (the missing-68705 stand-in raising panel interrupts
  the real command/response chip never would): remove/gate that path - faithful,
  no schematic deviation. (Ronny's steer: "avoid it triggering any interrupt.")
- if it is the real RTC PAN: the schematic window is genuinely exercised and the
  choice is the CGA_TRAP live-cause guard (a knowing deviation) vs a phase fix.

## 3e. ROOT CAUSE — DIRECTLY CONFIRMED ON SILICON (18-JUL)

Via the on-chip capture (grant_capture.py, TANG_GRANT_CAPTURE), stepping to the
wedge and reading a debug word = {PAN, IRQ, INTRQ, PICV, MIREQ}. Measured
sequence around the dispatch:

    PAN=1 IRQ=0 INTRQ=1 PICV=0 MIREQ=0   <- PAN pulses; INTRQN asserts (from PAN)
    PAN=0 IRQ=0 INTRQ=1 PICV=0 MIREQ=0   <- PAN GONE, INTRQN STILL asserted = THE LAG
    PAN=0 IRQ=0 INTRQ=0 PICV=0 MIREQ=0   <- INTRQN clears
Summary: PAN pulsed=True, IRQ never asserted, INTRQ asserted, max PICV=0 (empty),
MIREQ never nonzero.

**THE ROOT CAUSE (proven, not inferred):**
1. A **PAN (panel request) PULSE** sets the INTRQN flip-flop (CGA_INTR.v
   MEMORY_2, `d = PAN | IRQ`). PAN here is a panel/PRQ pulse from console
   activity (the MOPC/PRQ output path - NOT a maskable interrupt).
2. INTRQN is a **registered snapshot** (holds a full MCLK period, cleared only
   by CLIRQ), so it **OUTLIVES the PAN pulse** - the measured `PAN=0 INTRQ=1`.
3. There is **NO real interrupt**: IRQ never asserts, MIREQ/IREQ are empty, PICV
   is always 0 (measured across the whole window and in two prior dedicated
   captures).
4. The trap unit fires on the **stale INTRQN**, but the panel-vs-macro
   classifier (CGA_TRAP_TVGEN_P2 GATES_6) uses **live PAN**, which is now 0 ->
   it dispatches a **MACRO interrupt (trap vector 17)**, not a PANEL interrupt
   (vector 16).
5. Trap-17 microcode does `PIC,RVECT` -> reads the empty vector `{PD=0,PICV=0}`
   = R1=0 -> `ITSRV+0` -> **PIL level 10** (Agent C's table; level 10 is the
   default decode of "grant with empty vector").

So the "masked level-10 grant" is **a stale-INTRQN panel pulse mis-taken as a
macro interrupt, reading an empty vector that defaults to level 10.** It is NOT
an Am2914 masked grant, NOT a real level-10 source, NOT metastability
(deterministic; it is the registered-snapshot lag), and NOT IOXERR/RTC/conkick
(all disable-tested with no effect - because the PAN source is the general
panel/PRQ path, confirmed by TANG_NO_PAN breaking the console entirely).

**Why Verilator never shows it:** the lag (INTRQN holding after PAN drops) exists
in the RTL in both worlds, but on silicon the real cadence (9600-baud console
PRQ pulses, real MCLK/TCLK phases) deterministically lands a PAN-pulse's lag
window on the JAZ instruction fetch (step 18, CSA 00214 CONTINUE). Zero-delay
Verilator's aligned delta-cycles + fast-UART cadence never place the lag window
on an instruction boundary, so the stale-INTRQN is always re-evaluated
consistently. This is the "real-timing effect zero-delay sim collapses" class.

**Structural fault (Agent D):** INTRQN (the grant, latched) is not interlocked
with the live panel-vs-macro classifier or the live vector read (PICV, strobed
by S). The fix must make the trap act on a cause that is still valid - which is
exactly what the reverted CGA_TRAP guard (`intrq & (pan | IRQ)`) did. Fix
options (Ronny's call, faithfulness constraint):
- (a) the CGA_TRAP live-cause guard (schematic deviation, directly blocks it);
- (b) latch PAN alongside INTRQN so trigger and classifier use one snapshot
  (a faithful interlock);
- (c) address the un-original console PRQ/conkick pulse generation so panel
  pulses are not manufactured the way the real 68705 never did.

## 3f. The real MC68705U3 behavior + the FAITHFUL FIX (18-JUL)

Agent read the U3 firmware analysis AND the sheet-40 schematic
(`/mnt/e/Dev/Repos/Ronny/nd-120/Code/68705/3202D_PANCAL_SHEET40.png`). Findings:
- STAT3 = PB4, a firmware-HELD LEVEL: set at panel-command completion, cleared
  at idle, ACKed by the CPU reading PANS (`TRA PANS` / EPANS/MIPANS). Not a
  hardware one-shot; the DGA A282/A283 turns its rising edge into PRQ.
- The 68705 is a command/response SLAVE: it raises STAT3/PRQ ONLY as the tail of
  an LDPANC command the CPU itself issued. Its timer/RTC ISR raises no CPU
  attention.
- **At cold start it raises NO panel request** (boot sets PB4=0, idle loop keeps
  it low).
- **It has no connection to the console UART** - a console output character never
  touches it and would never toggle STAT3.

CONCLUSION: the recreation's `conkick` (IO_37.v: pulse STAT3 once per console-TX
character) is **un-faithful** - it manufactures PRQ->PAN edges the real chip
never generates, including at cold start. Those spurious PAN pulses are what the
CGA_INTR/CGA_TRAP INTRQN lag mis-dispatches as a phantom macro-interrupt ->
level 10. So the phantom grant is, in normal (free-run) operation, an
**emulation artifact of the conkick.**

FAITHFUL FIX (prototype, 18-JUL): IO_37.v now drives STAT3 from real panel
activity only (IO_PANCAL) by DEFAULT; the old console-speedup conkick is behind
opt-in `ND120_CONKICK_CONSOLE_SPEEDUP` (default OFF). This matches the real
68705: STAT3 low at cold start and during console I/O. Cost: OPCOM console
output reverts to the slower RTC-tick pacing (the conkick's original purpose) -
the correct place to speed console output is the console/UART path, which on
real hardware does NOT go through the panel; that is a separate follow-up.

VALIDATION (must be FREE-RUN, not single-step): single-stepping injects its own
panel Stop/Continue PAN pulses, so it cannot test the conkick fix. A fresh
free-run cold start (400$ autostart, or MACL+P=0+run) has no panel-step ops, no
console output yet, and no RTC tick in the first ~tens of us - so with the
conkick gone there is no PAN pulse at the P=21 wedge point. If 400$ now boots
past the wedge, the conkick was the free-run trigger and the faithful fix cures
the real-operation failure.

RESIDUAL / belt-and-suspenders: the INTRQN lag (a real RTL structural bug, see
3e) still makes ANY brief PAN pulse (a legitimate panel op, an RTC tick landing
on a fetch) potentially fatal. For full robustness, ALSO add the interlock so
the CGA_TRAP panel-vs-macro classifier and the INTRQN trigger use one consistent
snapshot (or hold PAN as a level like the real STAT3). The faithful STAT3 fix
removes the un-original trigger; the interlock hardens against legitimate ones.

## 4. What was reverted (for the record)

The trap-side guard `INTRQ := INTRQ & (PAN | IRQ)` in CGA_TRAP (+ IRQ port wired in
CGA.v, + tb golden) was implemented, passed all sim gates, then **reverted** — it is
a schematic deviation and a symptom patch. The three files are back to their
committed state (verified `git diff` empty). The S3 HVE/LVE int-req-enable gate in
`CGA_INTR_CNTLR_IRGEL_HIRL.v` / `_LORL.v` remains uncommitted from before; it is
Am2914-ground-truth-correct but is NOT this bug's cure (the claim was already empty).

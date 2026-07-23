# ND-120 Boot Sequence Analysis - Verilator Reference Trace

Generated from `waveform.fst` (Verilator simulation, working boot).
Use this as reference when debugging Vivado FPGA boot.

**Trace format**: FST (compressed, indexed). Tool: `vcd_extract.py` with `fst` module.
**Trace window**: startTrace=730000 in test_nd120.cpp (captures from tick 730K onward).
For full boot including PROM load, set `startTrace = 0` and rebuild.

## Boot Timeline Summary

clockTicks increments every 10ps on both edges of sysclk (100MHz).
Formula: `clockTick = time_ps / 10 + 1` (approximately).

The o2045/o2046 delay loop is a **reusable subroutine** called from multiple places
during boot. The testbench logs show three exits:

| Abs Tick  | Loop Iters | Context                               |
|:----------|:-----------|:--------------------------------------|
| 72,363    | 136        | First delay (early init)              |
| 557,536   | 6          | Second delay (short)                  |
| 737,750   | 180,213    | Third delay (main countdown, biggest) |

### Full boot timeline (from full trace, startTrace=0)

| clockTick  | Event                              | Signal            |
|:-----------|:-----------------------------------|:------------------|
| ~7         | LCS_n=0 (start microcode loading)  | s_debug_lcs_n=0   |
| ~100       | Reset deasserted                   | sys_rst_n=1       |
| ~573,437   | LCS_n=1 (execution begins)         | s_debug_lcs_n=1   |
| ~573,438   | First executed microcode: o02001   | CSA_12_0=o02001   |
| 72,363     | 1st delay loop exit (136 iters)    | CSA_12_0=o02047   |
| 557,536    | 2nd delay loop exit (6 iters)      | CSA_12_0=o02047   |
| 737,750    | 3rd delay loop exit (180213 iters) | CSA_12_0=o02047   |
| ~739,217   | OPCOM "0!" command received        | Self-test starts  |

### Current trace window (startTrace=730000)

| Abs Tick   | Event                              |
|:-----------|:-----------------------------------|
| 730,000    | Trace starts (in 3rd delay loop)   |
| 737,748    | Loop exits to o02047 (705 iters in window) |
| 737,750    | -> o03710 (utility call)           |
| ~737,930   | MACL self-test loop o02116-o02124  |
| ~738,268   | UART output routine o03666->o00702 |
| ~739,217   | OPCOM "0!" command                 |

## Phase 1: Microcode Loading (LCS_n=0)

- **Duration**: tick 7 to 573,437 (~573K ticks / 5,734,355ps)
- **CSA pattern**: Sequential count o00000 to o17777 (8192 addresses = all 13-bit microcode space)
- **Step rate**: ~68 ticks per address (one MCLK cycle = ~680ps)
- **Total addresses loaded**: 8192 (o00000-o17777)
- **Source**: Microcode ROM -> DRAM cache via WCA register
- **First CSA increment**: tick ~16,416 (there is a startup delay before counting begins)

### What to verify in Vivado ILA:
1. CSA_12_0 must count sequentially o00000 through o17777
2. LCS_n must stay LOW during entire loading
3. MCLK must be toggling (drives the loading)
4. cc_term[4:0] pattern should match: cycling through FSM states
5. After o17777, CSA wraps to o00000 and LCS_n goes HIGH

## Phase 2: Initialization (o02001 - self-test entry)

First instruction executed is **o02001** at tick 573,438. This is the microcode entry point.

### Init sequence (69 microcode instructions):
```
o02001-o02017: Sequential init (15 instructions)
  -> JUMP to o05660, then o05670, returns to o02020
o02020-o02026: Continue init (7 instructions)
  -> CALL o01006: Subroutine at o01006-o01013 (6 instr)
  -> CALL o01020: Single instruction, returns
  -> JUMP to o02027-o02030
o02030: -> CALL o03707 (utility), -> CALL o01021
o01021: -> CALL o01163-o01165 (register setup?)
  -> CALL o01022-o01027 (6 instructions)
  -> CALL o01112-o01116 (5 instructions, bus/memory init?)
  -> o02031-o02041 (9 instructions)
  -> CALL o02173-o02201 (7 instructions)
  -> o02042-o02044 (setup complete)
```

### What to verify in Vivado:
- First CSA after LCS_n=1 must be **o02001**
- The jump pattern o02017 -> o05660 -> o05670 -> o02020 is critical
- If Vivado shows different first address or stuck address, the IPOS mux selection is wrong

## Phase 3: Delay Loop (o02045/o02046) - Reusable Subroutine

The o02045/o02046 loop is a **reusable delay subroutine**, not a one-shot init wait.
It is called three times during boot with different iteration counts depending on the
Q register value loaded before each call.

### Three invocations during boot:

| Call | Abs Tick | Iterations | Q value | Context |
|:-----|:---------|:-----------|:--------|:--------|
| 1st  | ~72,363  | 136        | small   | Early init delay |
| 2nd  | ~557,536 | 6          | small   | Short delay |
| 3rd  | ~737,750 | 180,213    | 0x3FFF  | Main countdown (biggest) |

### Mechanism (ALU countdown):

**Setup (before loop entry):**
- COMM,LDEXM loads Q register with a value (e.g., 0x3FFF for the big delay)

**Loop body (o02045 / o02046):**
- o02045: ALUF A-Q, with A sourced from R1 register
- o02046: Conditional branch - if ZF=0 (result not zero), jump back to o02045
- Each iteration: F = A - Q

**What actually happens per the Verilator trace:**
- At loop start: Q=0x3FFF, R1=0x0000, A=0x0000
- First iteration: F = 0x0000 - 0x3FFF = 0xC001 (with borrow), then F=0x0001
- The F output alternates between 0xCxxx and 0x000x patterns each half-cycle
- F values increment: 0x0001, 0x0002, 0x0003... (counting UP toward match)
- After 16383 iterations: F reaches 0x3FFF, then next iteration F=0x0000
- ZF goes HIGH at tick 754,016 when F=0x0000
- COND goes HIGH at tick 754,019
- Loop exits to o02027 at tick 754,017

**ALU signal values at key moments:**

| Moment | Tick | Q | F | ZF | COND | CSA (oct) |
|:-------|:-----|:--|:--|:---|:-----|:----------|
| Q loaded | 573,803 | 0x3FFF | 0xC001 | 0 | 1 | o02025 |
| 1st iter | 573,806 | 0x3FFF | 0x0001 | 0 | 0 | o02026 |
| 2nd iter | 573,817 | 0x3FFF | 0x0002 | 0 | 0 | o02026 |
| 3rd iter | 573,828 | 0x3FFF | 0x0003 | 0 | 0 | o02026 |
| ... | ... | 0x3FFF | counting up | 0 | 0 | o02025/6 |
| Near end | 753,997 | 0x3FFF | 0x3FFE | 0 | 0 | o02026 |
| Near end | 754,008 | 0x3FFF | 0x3FFF | 0 | 0 | o02026 |
| EXIT | 754,016 | 0x3FFF | 0x0000 | **1** | 0 | o02025 |
| Post-exit | 754,019 | 0x3FFF | 0x4000 | 0 | **1** | o02026 |
| Continue | 754,017 | - | - | - | - | **o02027** |

### FPGA Bug: Loop never exits

  * ***FPGA: Stuck in o02025/o02026 loop, never reaches o02027***
  * NOT a POWFAIL issue - this is an ALU countdown loop


### Signals to add to Vivado ILA probes:

These signals must be added as `mark_debug` probes to diagnose why the FPGA loop never exits:

| Signal | Width | Purpose | What to check |
|:-------|:------|:--------|:--------------|
| ALU.ALU_QREG.Q_15_0 | 16 | Q register | Must be 0x3FFF at loop entry, stay constant during loop |
| ALU.ALU_RALU.F_15_0 | 16 | ALU result (F) | Must count up: 0x0001, 0x0002... and eventually reach 0x0000 |
| ALU.A_15_0 | 16 | ALU A input | Source operand (from R1 via register file) |
| ALU.B_15_0 | 16 | ALU B input | Should show register values being fed |
| ALU.ZF | 1 | Zero flag | MUST go HIGH when F=0x0000 - if not, this is the bug |
| ALU.CRY | 1 | Carry flag | Tracks borrow in subtraction |
| MIC.COND | 1 | Condition output | Fed by CSEL, must go HIGH to exit loop |
| MIC.CSEL.CONDN | 1 | Condition (inverted) | Should go LOW when condition met |
| WRF.RBLOCK.R1_REG_9.REG_15_0 | 16 | R1 register | One of the ALU operands |

### Most likely FPGA failure modes:

1. **Q not loaded**: Q register doesn't get 0x3FFF at o02044 -> F never reaches 0x0000
2. **F not computing correctly**: ALU subtraction broken -> F never equals zero
3. **ZF not asserting**: F reaches 0x0000 but zero detect combinatorial logic fails
4. **COND not propagating**: ZF is correct but CSEL/CONDN path doesn't reach address mux
5. **ALUCLK timing**: Condition latch in CSEL clocked at wrong time -> COND never sampled as 1


## Phase 4: Self-Test (post delay-loop, tick ~737,748)

After exiting the 3rd delay loop at o02047 (abs tick ~737,748):

### Immediate post-loop sequence (from current FST trace):
```
o02047 -> o03710 (utility call)
o03710 -> o01035-o01037 (3 instr)
o01037 -> o02050 -> o03710 -> o01035-o01037 -> o02051
o02051 -> o01172-o01173 (register init)
o01173 -> o02052 (return)
o02052-o02057 (sequential)
o02057 -> o02156 -> o02060 (via dispatch at o02156)
o02060-o02064 -> o02063 loop (short)
o02064-o02072 (sequential)
o02072-o02077 -> o02155 -> o02100 (via dispatch)
o02100-o02112 (sequential)
o02112 -> o02156 -> o02113 (via dispatch)
o02113-o02124 (self-test loop body)
```

### MACL Self-Test Loop (o02116-o02124):
The self-test loop pattern has changed from the old trace. It now includes
a dispatch via o02156 (oct 2156) that wasn't present before. The loop is:
```
o02116-o02120 -> o02156 -> o02121 -> o02122-o02124 -> o02116 (repeat)
```
The jump through o02156 appears to be a condition dispatch (likely from
Verilog changes to async->sync conversion).

### UART Output Routine (o00702-o00724):
- Called via o03666 -> o00702
- UART busy-wait loop at o00714-o00717
- Returns via o00745 -> caller

### Condition behavior at o01165-o01167 changed:
Old trace: o01165 -> o01167 (COND SKIP o01166)
New trace: o01165 -> o01166 -> o01167 (NO SKIP - condition evaluates differently)
This is expected if async-to-sync refactoring changed timing of CSEL latch.
- Q register shifts: 0x8000 -> 0x4000 -> ... -> 0x0001 -> wraps to 0x8000
- After loop completes: o02124-o02127 -> o02153 -> o02130-o02141
- **VERIFIED IDENTICAL on FPGA and Verilator** — same Q values, same count, same exit

### Post-MACL Self-Test Sequence:
```
o02124-o02127 -> o02153 -> o02130-o02141  (test completion)
o02141 -> o03666 -> o00702               (first APID2 call)
o00702-o00745                             (APID2/TRA PID routine)
  inner loop: o00714-o00717              (iterates several times)
  exit: o00720-o00724 -> o00745
o00745 -> o02142-o02143                   (continue self-test)
o02143 -> o03706 -> o01030-o01033        (utility calls)
  subroutine: o01112-o01116
o02144-o02145 -> o03666 -> o00702        (second APID2 call)
  ... more test iterations ...
o02152 -> o02160-o02167                   (final test section)
o02167 -> o01146-o01160                   (subroutine)
o02170-o02172                             (COMM,CONTINUE — self-test complete)
```

### Self-Test Exit Status:
- **o02156 (STERR) is NEVER hit** on either FPGA or Verilator — self-test passes
- **o02172 IS reached** on both — self-test completes with COMM,CONTINUE
- LED0 (RED) stays on — this is NOT a self-test failure indicator

### APID2 First Divergence (o00707):
The first APID2 call at o00702 diverges at step o00707:
- **Verilator**: o00707 -> o00711 (skips o00710)
- **FPGA**: o00707 -> o00710 -> o00711 (executes o00710)

This is a conditional branch at o00707 where the condition evaluates differently:
- FPGA: ALU_F = 0x4020 at o00707, COND=0 -> falls through to o00710
- Verilator: different ALU_F value, COND=1 -> skips to o00711

The 0x4000 bit difference likely traces back to a small ALU_F difference
at o02125 right after MACL exit (FPGA: 0x1000, VCD: 0x0070).

This divergence affects interrupt mask setup but does NOT prevent self-test
from completing. Both paths eventually converge at o02142.


## Phase 5: Post Self-Test — OPCOM Entry

After o02172 (COMM,CONTINUE), the CPU enters the trap/interrupt driven OPCOM mode.

### Panel Interrupt Mechanism:
Trap vector o016 (panel interrupt) jumps to PANVC based on IDBS.PANEL value
loaded into LC (COMM.LDLC). PANVC is a vector table at o03760-o03767:

```
o03760  PANVC[0] -> STOP     (stop/idle)
o03761  PANVC[1] -> MS20     (20ms timer handler at o02333)
o03762  PANVC[2] -> PRQ      (panel request at o020201)
o03763  PANVC[3] -> SING2    (single step)
o03764  PANVC[4] -> LOAD     (load)
o03765  PANVC[5] -> CONT     (continue, with COMM,CLRTC)
o03766  PANVC[6] -> RSTRT    (restart)
o03767  PANVC[7] -> MACL     (master clear, with COMM,ERWT)
```

### Phase 5a: First MS20 Call (both FPGA and Verilator)

After self-test exit, both versions enter the fetch loop and hit the
panel interrupt, dispatching to MS20:

```
o02172 -> o00000 (fetch)
o00000 -> o00050 -> o00051 -> o00052 (fetch decode)
o00052 -> o03761 (PANVC[1] = MS20!)
o03761 -> o02333 (MS20 entry)
o02333 -> o02334 -> o00513 -> o00514 -> o02335 -> o02336
o02336 -> o02341-o02346 -> o00145 (instruction complete)
```

**VERIFIED**: Both FPGA and Verilator hit o03761 (MS20) on the first
panel interrupt after self-test.

### Phase 5b: MS20 Processing Divergence

After the first MS20 call:

**Verilator** (working):
```
MS20 at o02333 processes fully:
o02333-o02354 -> o02367 -> o02370 -> o02341
-> o02422 -> o02475-o02477 -> o02500-o02503
-> o03637 -> o02540-o02546 -> o02501
-> o00145 (instruction complete)
Then: o00000 -> o00016 -> o00051 -> o00052 -> o03760 (PANVC[0]=STOP)
-> o02203 (MOPC entry)
-> o02203-o02207 -> o03624 (BREAKPOINT IS FINISHED, PRINT)
-> o03625 -> o03627 -> o02674-o02675
-> o00145
```
Verilator MOPC reaches o02206 (PRCHR -> UART DATA) and outputs characters.
The fetch loop pattern includes: o00016 (via trap o016 panel interrupt path).

**FPGA** (not working):
```
MS20 at o02333 exits quickly:
o02333 -> o02334 -> o00513 -> o00514 -> o02335 -> o02336
-> o02341-o02346 -> o00145 (done — exits much sooner)
Then: o00000 -> o00050 -> o00051 -> o00052 -> o03760 (PANVC[0]=STOP)
-> o02203 (MOPC entry)
-> o02203-o02205 (loops here, never reaches o02206)
```
FPGA MOPC loops o02203->o02205 without reaching o02206.
The MOPC check at o02203 tests PRCHR register — if empty (F=0),
it skips output and returns. PRCHR is never loaded with a character.

### Phase 5c: Steady-State OPCOM Loop

**Verilator** repeating pattern:
```
o00000 -> o00016 -> o00051 -> o00052 -> o03760 -> o02203
-> o02204 -> o02205 -> o02206 -> o02207
-> o03624 -> o03625 -> o03627
-> o02674 -> o02675
-> o00145 -> o00000  (back to fetch)
```
Note: enters via o00016 (panel interrupt trap path).
MOPC outputs characters — UART TX active.

**FPGA** repeating pattern:
```
o00000 -> o00050 -> o00051 -> o00052 -> o03760 -> o02203
-> o02204 -> o02205
-> o03624 -> o03625 -> o03627
-> o02674 -> o02675 -> o02676 -> o02677
-> o00000 -> o00145  (back to fetch)
```
Note: enters via o00050 (normal fetch path, NOT panel interrupt).
MOPC checks but PRCHR is empty — never outputs.

### Key Differences in Phase 5:

1. **Fetch path**: Verilator goes o00000->o00016 (panel interrupt trap),
   FPGA goes o00000->o00050 (normal fetch). This means the FPGA is NOT
   getting panel interrupts after the first one.

2. **MS20 processing**: Verilator fully processes MS20 (sets up RTC,
   character buffer), FPGA exits MS20 early without full setup.

3. **MOPC output**: Verilator reaches o02206 (UART write), FPGA stops
   at o02205 (PRCHR empty, nothing to write).

4. **FPGA hits o02206-o02207 once** (first MOPC call after first MS20),
   but subsequent calls only reach o02205.

### Root Cause Analysis:

The panel interrupt system (trap o016) is not firing repeatedly on FPGA.
After the first MS20 call, subsequent fetches take the normal path (o00050)
instead of the panel interrupt path (o00016).

This points to the **20ms RTC timer in DGA_POW** not generating periodic
panel request interrupts. The F595 latch fix enabled the initial boot
(POWFAIL/CLEAR/MR sequence) but the RTC timer chain uses F714 flip-flops
clocked by RTOSC — these may have similar edge-triggered vs level-sensitive
issues on FPGA.

### Signals to investigate:
- DGA_POW RTOSC: is the real-time oscillator running?
- DGA_POW s_rtc_n: does the 20ms RTC timer fire?
- DGA_POW s_pan_n (PAN_n): does the panel request assert?
- PANOSC: panel oscillator output
- The IDBS.PANEL value when panel interrupt fires (determines PANVC index)

### Key microcode address regions:
| Range (oct)     | Purpose                             |
|:----------------|:------------------------------------|
| o00000          | Fetch entry point                   |
| o00016          | Panel interrupt fetch (via trap)    |
| o00050-o00052   | Normal fetch decode                 |
| o00145          | Instruction complete                |
| o00152          | Instruction complete (alt)          |
| o00215          | Memory operation complete           |
| o00702-o00745   | APID2/TRA PID routine               |
| o01006-o01177   | Subroutine library                  |
| o02001-o02377   | Self-test / init code               |
| o02203-o02207   | MOPC (monitor OPCOM) UART handler   |
| o02333-o02354   | MS20 (20ms timer handler)           |
| o02674-o02675   | Instruction execution               |
| o03624-o03627   | Breakpoint print / OPCOM output     |
| o03666-o03706   | Utility routines (APID2 etc)        |
| o03760-o03767   | PANVC panel interrupt vector table  |
| o05660-o05670   | Trap/interrupt handlers             |
| o06000-o07777   | Instruction decode dispatch         |
| o10000-o17777   | Instruction microcode               |

## Signal Checklist for Vivado ILA Debug

### Critical signals (must monitor):
| Signal (Vivado name)    | VCD equivalent                    | What to check         |
|:------------------------|:----------------------------------|:----------------------|
| s_debug_csa[12:0]       | TOP.CSA_12_0                      | Microcode address     |
| s_debug_lcs_n           | TOP.ND120_TOP.s_debug_lcs_n       | Load phase indicator  |
| s_debug_mclk            | TOP.ND120_TOP.s_debug_mclk        | Master clock          |
| s_debug_cc_term[4:0]    | TOP.ND120_TOP.s_debug_cc_term     | Cycle FSM state       |
| s_debug_fetch           | (MEM.ERROR.s_fetch)               | Fetch signal          |
| s_debug_mr_n            | (MIC.MIC_MASEL.s_mr_n)            | Master reset          |
| s_debug_powfail_n       | (not in VCD - check DCD module)   | Power fail            |
| s_debug_clear_n         | (not in VCD)                      | Clear signal          |
| s_debug_intrq_n         | (TRAP.TBUF.s_intrq_n)             | Interrupt request     |

### Additional signals for deep debug:
| Signal                    | Purpose                               |
|:--------------------------|:--------------------------------------|
| FIDBO[15:0]               | Internal data bus (microcode data)    |
| CD_15_0_OUT[15:0]         | Command/data bus output               |
| s_wca_12_0[12:0]          | Write cache address (during loading)  |
| TRAP_n                    | Trap active (affects MA selection)     |
| MAP_n                     | Memory address present                |
| SC[6:3]                   | MIC control: address source select    |
| W_12_0[12:0]              | Working address (pre-IPOS mux)        |

## MIC Address Generation (how CSA is computed)

The microcode address (MA_12_0 / CSA_12_0) is selected by a 3-stage pipeline:

### Stage 1: Address Source Selection (MASEL)
SC5/SC6 select one of 4 sources:
- **SC5=0, SC6=0**: JUMP address from microword bits
- **SC5=1, SC6=0**: RETURN from stack (subroutine return)
- **SC5=0, SC6=1**: NEXT (IW + 1, sequential execution)
- **SC5=1, SC6=1**: REPEAT (same address, for loops)

### Stage 2: Final Mux (IPOS)
Selects between:
- **Normal**: W_12_0 from MASEL (normal execution)
- **Cache Write**: WCA_12_0 (during loading, LCS_n=0)
- **Trap Vector**: CD[15:6] + TVEC[3:0] (on trap/interrupt)

### Stage 3: Output
MA_12_0 -> CSA_12_0 (microcode ROM address)

## Debugging Decision Tree for Vivado

```
Does CSA count o00000-o17777 during loading?
  NO -> Check: MCLK toggling? WCA register incrementing? LCS_n stuck?
  YES ->
    Does LCS_n go HIGH after o17777?
      NO -> Check: Counter overflow detection, DCD power-on logic
      YES ->
        Is first exec address o02001?
          NO -> Check: IPOS mux (TRAP_n, MAP_n, EWCA_n values)
                If o00000: TRAP_n may be asserted incorrectly
                If WCA value: LCS_n not properly deasserted to IPOS
          YES ->
            Does o02017 jump to o05660?
              NO -> Check: Microcode ROM content, CSBIT connections
              YES ->
                Does o02025/o02026 loop start?
                  NO -> Check: Conditional jump logic (CSEL, CONDN)
                  YES ->
                    Does loop eventually exit?
                      NO -> Check: ALU Q reg, F result, ZF, COND
                      YES -> Self-test is running, compare output
```

## cc_term[4:0] Cycle Clock Pattern

The cc_term signal encodes {TERM_n, CC3_n, CC2_n, CC1_n, CC0_n}.
During loading, it cycles rapidly through FSM states.
Key values observed at boot:
- 0x1E, 0x1C, 0x1D, 0x19, 0x18, 0x1A, 0x1B (loading FSM)
- 0x0B, 0x0C, 0x0F (transition states)
- The TERM bit (bit 4) going LOW indicates cycle completion

Compare the cc_term pattern in Vivado with this trace at equivalent boot phases.

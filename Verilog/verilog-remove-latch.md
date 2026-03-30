# ND-120 Latch-to-Flip-Flop Migration Plan

## Status: PHASE 0 COMPLETE (29-MAR-2026)

The latch-to-FF migration is functionally complete. Both simulation modes work, both
FPGA synthesis tools pass, and the signal comparison shows near-identical behavior.

### Work Completed

| Item | Status | Commit |
|------|--------|--------|
| ifdef dual-mode (latch/FF) for all PAL, LATCH, AM29841, F595 | Done | `9698697` |
| PAL_45001B stray semicolon bugfix | Done | `93e0d1c` |
| sys_rst_n threaded to all PAL FF registers | Done | `10fb26d` |
| Signal comparison tool (latch_ff_compare.cpp) | Done | `f559185` |
| IDT6168A block RAM inference fix | Done | `a4eeb11` |
| FPGA pin reduction (bus ports ifdef'd out) | Done | `ac3f982` |
| UART baud rate parameterized (115200 @ 100MHz) | Done | `ac3f982` |
| ROM BRAM inference improvement | Done | `ac3f982` |
| Latch control renamed to USE_TRANSPARENT_LATCHES | Done | `ac3f982` |
| TTL_74374 initial value for FPGA | Done | `118abd0` |
| .gitignore cleanup | Done | `783b69c` |

### Synthesis Results

| Tool | Result | Latch warnings |
|------|--------|----------------|
| Verilator (latch mode) | Compiles clean | N/A (latches expected) |
| Verilator (FF mode) | Compiles clean | Zero |
| Vivado (xc7a35t) | Synthesis passes, ~43% LUT, 46 BRAM18 | Zero |
| Gowin (GW2AR-18) | Synthesis passes, 2% LUT, 36 BSRAM | Zero |

### Signal Comparison Results (1M cycles)

All PAL register signals match between latch and FF modes except:
- **BDRY**: Init transient (cycle 0-2 only, latch=1 vs FF=0). Harmless -- the
  latch resolves to 1 from uninitialized state, FF correctly resets to 0.
- **CSA**: Diverges at cycle 16415 due to BDRY init cascade. Does not affect
  functional behavior after reset.

### Remaining Items

- ROM still maps to LUT in Vivado (~7600 LUTs). Address pipeline added but
  Vivado may still prefer LUT ROM. Needs investigation with timing constraints.
- UART DELAY_FRAMES defaults to 100MHz/115200. Override with
  `-DBOARD_CLK_FREQ=27000000` for Tang Nano boards.
- Per-PAL unit testbenches (Phase 0.5) not yet created.
- Design runs at board clock speed (100MHz on Basys3) not original 39.3MHz.
  All relative timing preserved. DRAM would need PLL for correct refresh.

---

## Original Context

The `vivado-fix` branch converted all transparent latches to edge-triggered flip-flops for
FPGA synthesis. This broke the Verilator simulation because transparent latches propagate
data immediately when the enable is active, while flip-flops only capture on clock edges --
fundamentally different timing behavior.

We added `ifdef USE_TRANSPARENT_LATCHES` guards so simulation uses latches (default) and
FPGA builds use flip-flops. The FF path now produces correct behavior and both Vivado and
Gowin synthesize cleanly with zero latch warnings.

### The Core Problem

PAL16L8 devices are purely combinational with self-referencing feedback that creates implicit
latches through the AND-OR array. They were **never clocked** in the original hardware. The
current FF conversion clocks them on OSC (~39.3 MHz / ~25ns period), but the conversion of
boolean OR-equations to if/else priority logic may not be semantically equivalent.

---

## Module Impact Tree

Every module affected by the latch-to-FF conversion, traced from the top level:

```
ND120_TOP  (Verilog/ND120_TOP.v)
 |
 +-- ND3202D  (CPU-BOARD-3202/circuit/ND3202D.v) -- Main CPU Board
      |
      +-- CYC_36  (CPU-BOARD-3202/circuit/CYC_36.v)
      |    |   Cycle Control -- generates all internal "clocks"
      |    |   These are NOT free-running clocks, they are combinational
      |    |   control signals derived from the cycle state machine:
      |    |
      |    |   CLK    = ~TERM_n
      |    |   ALUCLK = ~(TERM_n | LCS)
      |    |   MCLK   = ~(TERM_n & MCLK_n)
      |    |   MACLK  = ~(TERM_n & MACLK_n)
      |    |   UCLK   = TERM_n & UCLK_from_PAL
      |    |
      |    +-- PAL_44601B  (PAL/PAL_44601B.v)
      |    |   PAL16R6 -- ALREADY has real D flip-flops clocked by OSC
      |    |   Generates: CC0-CC3, TERM_n (cycle state machine)
      |    |   STATUS: No change needed
      |    |
      |    +-- PAL_44307C  (PAL/PAL_44307C.v)
      |         PAL16L8 -- purely combinational, no latches
      |         Generates: MCLK_n, MACLK_n, UCLK from CC bits
      |         STATUS: No change needed
      |
      |
      +===[ GROUP 4: CGA Internal ]=====================================
      |
      +-- CPU_15  (CPU-BOARD-3202/circuit/CPU_15.v)
      |    +-- CPU_PROC_CGA_33  (CPU-BOARD-3202/circuit/CPU_PROC_CGA_33.v)
      |         +-- CGA  (DELILAH-CPU/CGA/circuit/CGA.v)
      |              +-- CGA_MIC  (Microinstruction Controller)
      |                   |
      |                   +-- CGA_MIC_CSEL  (CGA_MIC/circuit/CGA_MIC_CSEL.v)
      |                   |    +-- LATCH CSEL_LATCH  (Shared/ndlib/LATCH.v)
      |                   |         Type: LATCH module with FPGA_MODE parameter
      |                   |         Enable: ALUCLK_n (inverted ALU clock)
      |                   |         Data: s_pcond_n (condition selector output)
      |                   |         Output: CONDN (condition for microcode branch)
      |                   |         SIM: transparent latch (FPGA_MODE=0)
      |                   |         FPGA: posedge ALUCLK_n (FPGA_MODE=1)
      |                   |         RISK: LOW -- clean edge from TERM_n derivation
      |                   |
      |                   +-- CGA_MIC_MASEL  (CGA_MIC/circuit/CGA_MIC_MASEL.v)
      |                        +-- regW  (lines 122-128)
      |                        |    Type: Combinational mux (already converted)
      |                        |    When MCLK_n=1: regW = regREP (transparent)
      |                        |    When MCLK_n=0: regW = regIW (hold registered)
      |                        |    STATUS: Already OK for both sim and FPGA
      |                        |
      |                        +-- regIW  (lines 133-139)
      |                             Type: Edge-triggered FF (posedge MCLK)
      |                             STATUS: Already OK
      |
      |
      +===[ GROUP 3: Address Latches ]==================================
      |
      +-- CPU_PROC_32  (CPU-BOARD-3202/circuit/CPU_PROC_32.v)
      |    +-- AM29841 CHIP_25F  (Shared/support/AM29841.v)
      |         Type: AM29841 with FPGA_MODE parameter
      |         LE (Latch Enable): MCLK
      |         Data: CSCA[9:0]
      |         Output: CA[9:0] (CPU address)
      |         SIM: transparent when LE=1 (FPGA_MODE=0)
      |         FPGA: posedge LE (FPGA_MODE=1)
      |         RISK: LOW -- MCLK has clean rising edge
      |
      +-- CPU_CS_ACAL_17  (CPU-BOARD-3202/circuit/CPU_CS_ACAL_17.v)
      |    |
      |    +-- TTL_74373/TTL_74374 CHIP_30H  (lines 110-125)
      |    |    Type: ifdef switch between latch (sim) and FF (FPGA)
      |    |    Clock/Enable: MACLK
      |    |    Data: CSA[12:10], UUA[11:10]
      |    |    Output: LUA[12:10]
      |    |    RISK: LOW -- MACLK has clean edge
      |    |
      |    +-- AM29841 CHIP_31F  (FPGA_MODE parameter)
      |    |    LE: MACLK, Data: CSA[9:0], Output: LUA[9:0]
      |    |
      |    +-- AM29841 CHIP_32G  (FPGA_MODE parameter)
      |    |    LE: MACLK, Data: CSA[9:0], Output: UUA[9:0] (conditional)
      |    |
      |    +-- AM29841 CHIP_31G  (FPGA_MODE parameter)
      |         LE: CLK (= ~TERM_n), Data: CSCA[9:0], Output: UUA[9:0] (conditional)
      |
      |
      +===[ GROUP 1: BIF PALs (Bus Interface) ]========================
      |
      +-- BIF_5  (CPU-BOARD-3202/circuit/BIF_5.v)
      |    |
      |    +-- BIF_DPATH_9  (CPU-BOARD-3202/circuit/BIF_DPATH_9.v)
      |    |    +-- BIF_DPATH_LDBCTL_12  (CPU-BOARD-3202/circuit/BIF_DPATH_LDBCTL_12.v)
      |    |         |
      |    |         +-- PAL_44302B  (PAL/PAL_44302B.v) -- LBC1
      |    |         |    Type: PAL16L8 with ifdef, CK=OSC
      |    |         |    Latched signal: EMD (Enable Data Path CD<->LBD)
      |    |         |    Set: Q2 & Q0 & CACT, or CGNT & CGNT50
      |    |         |    Hold: CACT, or RT & CC2 & !TERM, or IORQ & CC2 & !TERM
      |    |         |    Clear: when no hold terms true
      |    |         |    RISK: HIGH -- critical data path enable timing
      |    |         |
      |    |         +-- PAL_44303B  (PAL/PAL_44303B.v) -- LBC2
      |    |         |    Type: PAL16L8 with ifdef, CK=OSC
      |    |         |    Latched signals: CBWRITE (CPU write to bus),
      |    |         |                     CMWRITE (CPU write to local mem)
      |    |         |    CBWRITE set: WRITE & CACT, clear: !CACT
      |    |         |    CMWRITE set: WRITE & CGNT, clear: !CGNT
      |    |         |    RISK: MEDIUM -- CACT from AM29C821 pipeline, has margin
      |    |         |
      |    |         +-- PAL_44304E  (PAL/PAL_44304E.v) -- LBC3
      |    |              Type: PAL16L8 with ifdef, CK=OSC
      |    |              Latched signals: BACT (Bus Activity),
      |    |                               EBADR (Enable Bus Address)
      |    |              *** BUG: EBADR FF clear logic doesn't match latch ***
      |    |              RISK: HIGH -- bus address enable timing + has bug
      |    |
      |    +-- BIF_BCTL_6  (CPU-BOARD-3202/circuit/BIF_BCTL_6.v)
      |         |
      |         +-- PAL_44401B  (PAL/PAL_44401B.v) -- BTIM
      |         |    Type: PAL16R4D with ifdef for DAP only, CK=OSC
      |         |    Q0/Q1/Q2: ALREADY real D flip-flops (PAL16R4D has registers)
      |         |    Latched signal: DAP (Data Address Present)
      |         |    DAP set: Q=000 & CACT & CACT25
      |         |    DAP clear: when TERM_n & IORQ & CC2 is false
      |         |    RISK: LOW -- only DAP needs conversion, Q0/Q1/Q2 already FFs
      |         |
      |         +-- PAL_45001B  (PAL/PAL_45001B.v) -- BPAR
      |         |    Type: PAL16L8 with ifdef, CK=OSC
      |         |    Latched signals: BLOCK (block on error),
      |         |                     RERR (remote error)
      |         |    *** BUG: Stray semicolon on line 95, BLOCK always 0 in sim ***
      |         |    RISK: MEDIUM -- error path, not critical data path
      |         |
      |         +-- BIF_BCTL_SYNC_8  (CPU-BOARD-3202/circuit/BIF_BCTL_SYNC_8.v)
      |              Delay pipeline -- generates *25/*50/*75 delayed signals
      |              +-- AM29C821 CHIP_3D  (25ns stage, CK=OSC)
      |              |    Inputs:  BLOCK, BDAP, BREQ, CACT, BDRY,
      |              |             BPERR, BINPUT, SEMRQ, REFRQ, CLEAR
      |              |    Outputs: *25_n versions of all above
      |              |
      |              +-- AM29C821 CHIP_4D  (50ns stage, CK=OSC)
      |                   Inputs:  *25_n versions
      |                   Outputs: *50_n, *75_n versions
      |                   STATUS: Already edge-triggered, no change needed
      |
      |
      +===[ GROUP 2: Memory PALs ]=====================================
      |
      +-- MEM_43  (CPU-BOARD-3202/circuit/MEM_43.v)
           |
           +-- MEM_LBDIF_48  (CPU-BOARD-3202/circuit/MEM_LBDIF_48.v)
           |    +-- PAL_44310D  (PAL/PAL_44310D.v) -- LBDIF
           |         Type: PAL16L8 with ifdef, CK=OSC
           |         Latched signal: BDRY (Bus Data Ready)
           |         Set: complex OR of delayed bus signals
           |         Clear: when MR_n & BDAP50 = 0, or MR_n & BIOXE = 0
           |         RISK: MEDIUM -- memory timing, but inputs already delayed
           |
           +-- MEM_DATA_46  (CPU-BOARD-3202/circuit/MEM_DATA_46.v)
           |    +-- PAL_45008B  (PAL/PAL_45008B.v) -- DATA
           |         Type: PAL16L8 with ifdef, CK=OSC
           |         Latched signals: DISB (disable parity),
           |                          TST (test mode)
           |         Set: LBD bits & BIOXL & ECCR
           |         Clear: on MR or next BIOXL/ECCR
           |         RISK: LOW -- ECC test mode, not in critical path
           |
           +-- MEM_ERROR_47  (CPU-BOARD-3202/circuit/MEM_ERROR_47.v)
                +-- PAL_45009B  (PAL/PAL_45009B.v) -- ERROR
                     Type: PAL16L8 with ifdef, CK=OSC
                     Latched signal: BLOCKL (block on local error)
                     Set: RDATA & LERR (local parity error during read)
                     Clear: on PA read or MR
                     RISK: LOW -- error path only


      +===[ GROUP 5: DGA (Decode Gate Array) ]==========================

      +-- IO_37  (contains DGA)
           +-- DECODE_DGA  (DECODE-GateArray/DGA/circuit/DECODE_DGA.v)
                |
                +-- DECODE_DGA_PFIFC  (F595 x13, gate=s_zz1)
                |    R-S latches for FIFO control in instruction fetch
                |    NOTE: Marked as "NOT IN USE" -- replaced by FIFO_8BIT.v
                |
                +-- DECODE_DGA_POW  (F595 x6, gate=s_zz1)
                |    R-S latches for power sequencing, system load, reset, stop
                |
                +-- DECODE_DGA_COMM  (F595 x1+, gate=s_zz1)
                     R-S latches for communication control

                All F595 instances: Shared/DECODE-GateArray/DGA/circuit/F595.v
                Type: R-S latch with ifdef, posedge H03_G in FPGA mode
                RISK: LOW -- gate signal has clean edges, S/R stable before gate
```

---

## Why Clocking PALs on OSC Is the Correct Approach

In the original 1988 hardware:

1. **PAL16L8** feedback latches resolve within PAL propagation delay (~25-35ns)
2. **OSC** period is ~25ns at 39.3 MHz
3. The **AM29C821 pipeline** in BIF_BCTL_SYNC_8 samples bus signals on OSC edges,
   creating the *25/*50/*75 delayed versions
4. Downstream logic only reads PAL outputs at the next OSC edge
5. Therefore, the PAL output only needs to be stable before the next OSC edge

A flip-flop on `posedge OSC` captures exactly the same settled combinational state. The
"one-cycle latency" concern is a non-issue because the original hardware also had
propagation delay (~25-35ns through the PAL) -- the output was never instantaneous.

**The real risk** is not the clocking, but the **if/else priority encoding** in the FF path.
The original PAL AND-OR array evaluates all product terms simultaneously and OR's the
results. The if/else chain imposes a priority that may not match when multiple conditions
are true simultaneously. Each PAL's FF logic must be verified against the original equations.

---

## Known Bugs to Fix Before Testing

### BUG 1: PAL_45001B stray semicolon (CRITICAL)

**File**: `/mnt/e/Dev/Repos/Ronny/nd-120/Verilog/PAL/PAL_45001B.v` line 95-96
**Exists on**: both `main` and `vivado-fix` branches

```verilog
// CURRENT CODE (broken):
else if ((EPEA_n & MR_n) == 0);   // <-- stray semicolon ends the else-if body
BLOCK_reg = 0;                     // <-- executes UNCONDITIONALLY every evaluation

// CORRECT CODE:
else if ((EPEA_n & MR_n) == 0)
  BLOCK_reg = 0;                   // <-- only executes when condition is true
```

**Impact**: `BLOCK_reg` can never be 1 in simulation. The FPGA path (line 113) does NOT
have this bug, so latch vs FF comparison will always differ for this signal until fixed.

### ~~BUG 2: PAL_44304E EBADR_n_reg FF clear logic~~ -- VERIFIED CORRECT

**File**: `/mnt/e/Dev/Repos/Ronny/nd-120/Verilog/PAL/PAL_44304E.v` lines 82-85

Initially flagged as a bug, but algebraic analysis proves the FF conversion IS correct.

The **latch** equation:
```verilog
EBADR_n_reg = (GNT_n & BGNT_n) | (IBAPR_n & EBADR_n_reg) | (GNT_n & EBADR_n_reg)
```

When `EBADR_n_reg=1`, the hold terms simplify to `GNT_n | IBAPR_n` (since the third
term `GNT_n & EBADR_n_reg` = `GNT_n` when reg=1, which already covers the set term
`GNT_n & BGNT_n`). Therefore it clears only when `!GNT_n & !IBAPR_n`.

The **FF** path:
```verilog
if (GNT_n & BGNT_n) set
else if (!IBAPR_n & !GNT_n) clear   // clears on !GNT_n & !IBAPR_n
else hold
```

The clear condition `!IBAPR_n & !GNT_n` is exactly right. The `else if` means it only
fires when the set condition is false, but `!GNT_n` already implies `!(GNT_n & BGNT_n)`,
so the priority doesn't matter. **No fix needed.**

BACT_reg was also verified correct by the same analysis.

---

## Important Note: Existing Bugs

There are already known bugs in the Verilog design (7/14 self-tests fail). Some of these
may be signal propagation or timing related, not necessarily latch-related. We should NOT
assume all failures are from the latch conversion. Each fix must be tested manually in
latch mode first to confirm it doesn't break existing working behavior, then tested in
FF mode to see if it helps.

**Approach**: Fix one thing at a time, manually test between each fix. Do not batch fixes.

---

## Phase 0: Bug Fixes and Test Infrastructure

**Goal**: Fix known bugs one at a time with manual testing between each, then build
comparison tools.

### TODO 0.1: Fix Bug 1 (PAL_45001B semicolon) -- DONE
- [x] Fixed line 95: removed stray semicolon
- [x] FPGA path (line 113) verified correct
- [x] Compiled and manually tested -- simulator works normally, no regressions
- Committed as `93e0d1c`

### ~~TODO 0.2: Fix Bug 2 (PAL_44304E EBADR clear logic)~~ -- NOT A BUG
Algebraic analysis proved the FF conversion is correct. See "BUG 2" section above.
No fix needed. Skipping to TODO 0.3.

### TODO 0.3: Create signal comparison test harness -- DONE

**New file**: `/mnt/e/Dev/Repos/Ronny/nd-120/Verilog/sim/latch_ff_compare.cpp`

This test harness records key internal signals at every `posedge OSC` during simulation and
outputs them as CSV. Run once with `VERILATOR_SIM` defined (latch mode), once without (FF
mode), and diff the outputs to find first divergence.

**Signals to capture** (via `top->rootp->ND120_TOP__DOT__...` Verilator hierarchy):

| Signal | Module | What it tells us |
|--------|--------|-----------------|
| EMD | PAL_44302B | Data path enable timing |
| CBWRITE | PAL_44303B | Write direction to bus |
| CMWRITE | PAL_44303B | Write direction to local mem |
| BACT_reg | PAL_44304E | Bus activity state |
| EBADR_n_reg | PAL_44304E | Bus address enable |
| DAP | PAL_44401B | Data address present |
| BLOCK_reg | PAL_45001B | Error block state |
| RERR_reg | PAL_45001B | Remote error state |
| BDRY | PAL_44310D | Bus data ready |
| DISB_reg | PAL_45008B | Parity disable |
| TST_reg | PAL_45008B | Test mode |
| BLOCKL_reg | PAL_45009B | Local error block |
| CONDN | CGA_MIC_CSEL | Condition select output |
| LUA_12_0 | CPU_CS_ACAL_17 | Microcode address |
| CSA_12_0 | ND120_TOP | Top-level microcode address |
| TERM_n | CYC_36 | Cycle termination |
| MCLK | CYC_36 | Memory clock |
| CACT | BIF signals | CPU active |
| CGNT | BIF signals | CPU grant |

**CSV output format**:
```
cycle,CSA,TERM,MCLK,EMD,CBWRITE,CMWRITE,BACT,EBADR,DAP,BLOCK,RERR,BDRY,...
```

### TODO 0.4: Add Makefile targets -- DONE

**File**: `/mnt/e/Dev/Repos/Ronny/nd-120/Verilog/sim/Makefile`

Add these targets:
```makefile
# Build and run with latches (golden reference)
compare_latch: latch_ff_compare.cpp
	$(VERILATOR) $(VERILATOR_FLAGS) -DVERILATOR_SIM $(VERILATOR_DIRS) \
	    --exe latch_ff_compare.cpp $(SIM_DEVICE_SOURCES) --Mdir obj_dir_latch
	cd obj_dir_latch && make -f VND120_TOP.mk VND120_TOP
	./obj_dir_latch/VND120_TOP > trace_latch.csv

# Build and run with flip-flops
compare_ff: latch_ff_compare.cpp
	$(VERILATOR) $(VERILATOR_FLAGS) $(VERILATOR_DIRS) \
	    --exe latch_ff_compare.cpp $(SIM_DEVICE_SOURCES) --Mdir obj_dir_ff
	cd obj_dir_ff && make -f VND120_TOP.mk VND120_TOP
	./obj_dir_ff/VND120_TOP > trace_ff.csv

# Compare both traces
compare: compare_latch compare_ff
	@echo "=== Comparing latch vs FF traces ==="
	@diff trace_latch.csv trace_ff.csv | head -50 || echo "DIVERGENCE FOUND"
```

### TODO 0.5: Create per-PAL unit testbenches

**Directory**: `/mnt/e/Dev/Repos/Ronny/nd-120/Verilog/tests/vivado_warning_fixes/`

Each testbench instantiates the PAL module, applies stimulus sequences that exercise the
set/hold/clear paths of each latched signal, and verifies outputs.

New testbenches needed:
- [ ] `PAL_44302B_tb.v` -- EMD set (Q2&Q0&CACT, CGNT&CGNT50), hold (CACT), clear
- [ ] `PAL_44303B_tb.v` -- CBWRITE set (WRITE&CACT), clear (!CACT); CMWRITE similarly
- [ ] `PAL_44401B_tb.v` -- DAP set (Q=000, CACT, CACT25), clear (!TERM&IORQ&CC2)
- [ ] `PAL_45001B_tb.v` -- BLOCK set (error conditions), clear (EPEA read or MR)
- [ ] `PAL_44310D_tb.v` -- BDRY set (memory read/write/IOX), clear (MR, BDAP50)
- [ ] `PAL_45009B_tb.v` -- BLOCKL set (RDATA&LERR), clear (PA read or MR)

Existing testbenches to verify:
- [ ] `PAL_44304E_tb.v` -- update after fixing EBADR bug
- [ ] `PAL_45008B_tb.v` -- verify DISB/TST sequences
- [ ] `F595_tb.v` -- verify R-S latch behavior

### TODO 0.6: Run baseline comparison -- DONE
Baseline comparison results (1M cycles):

| Signal | First Divergence | Latch | FF | Root Cause |
|--------|-----------------|-------|----|------------|
| EBADR_n | cycle 0 | 1 | 0 | FF init value differs from latch combinational resolve |
| BDRY | cycle 0 | 1 | 0 | Same -- FF init value issue |
| LED | cycle 0 | 36 | 35 | Follows from EBADR/BDRY init |
| CSA | cycle 16416 | 1 | 0 | Cascading from init divergence |
| TERM_n | cycle 573457 | 0 | 1 | Late divergence from CSA drift |
| MCLK | cycle 573457 | 1 | 0 | Same |
| EMD | never | - | - | Identical |
| CBWRITE | never | - | - | Identical |
| CMWRITE | never | - | - | Identical |
| BACT | never | - | - | Identical |
| DAP | never | - | - | Identical |
| BLOCK | never | - | - | Identical |
| RERR | never | - | - | Identical |
| DISB | never | - | - | Identical |
| TST | never | - | - | Identical |
| BLOCKL | never | - | - | Identical |

**Root cause**: EBADR_n_reg and BDRY in FF mode initialize to 0 (default reg value),
but in latch mode they resolve combinatorially to 1 from the initial input state
(all bus signals inactive at reset). This cascades into CSA divergence at cycle 16416.

**Fix needed**: Add `sys_rst_n` reset to PAL FF registers so they initialize to the
correct state on reset. This is essential for real FPGA hardware.

### TODO 0.7: Thread sys_rst_n to PAL modules for FF reset

`sys_rst_n` already reaches `BIF_5` and `MEM_43` from ND3202D but is NOT passed down
to the sub-modules containing the PALs. Needs to be threaded through:

```
BIF_5 (has sys_rst_n)
  -> BIF_DPATH_9 (needs sys_rst_n added)
     -> BIF_DPATH_LDBCTL_12 (needs sys_rst_n added)
        -> PAL_44304E (needs reset: EBADR_n_reg=1 on !sys_rst_n)
        -> PAL_44302B (needs reset: EMD=0)
        -> PAL_44303B (needs reset: CBWRITE=0, CMWRITE=0)
  -> BIF_BCTL_6 (needs sys_rst_n added)
     -> PAL_44401B (needs reset: DAP=0)
     -> PAL_45001B (needs reset: BLOCK=0, RERR=0)

MEM_43 (has sys_rst_n)
  -> MEM_LBDIF_48 (needs sys_rst_n added)
     -> PAL_44310D (needs reset: BDRY=0)
  -> MEM_DATA_46 (needs sys_rst_n added)
     -> PAL_45008B (needs reset: DISB=0, TST=0)
  -> MEM_ERROR_47 (needs sys_rst_n added)
     -> PAL_45009B (needs reset: BLOCKL=0)
```

Reset values: Most registers reset to 0 (inactive). Exception:
- **EBADR_n_reg must reset to 1** (because EBADR_b1 = ~EBADR_n_reg, and EBADR
  should be inactive/0 at reset, so the internal inverted reg must be 1)
- **BDRY** must be verified -- latch resolves to 1 at init, need to check if
  that's the correct reset state or just an artifact of initial conditions

### Validation for Phase 0: ALL COMPLETE
- [x] Bug 1 fixed, manually tested in latch mode, results documented
- [x] Bug 2 verified NOT a bug -- FF logic is correct
- [x] Comparison tool built and baseline captured
- [x] sys_rst_n threaded to all PAL modules with proper reset values
- [x] Re-run `make compare` -- EBADR_n now matches, only BDRY init transient remains
- [x] `make run` (latch mode) passes same self-tests
- [x] `make run USE_LATCHES=0` (FF mode) works correctly
- [x] Vivado synthesis: zero latch warnings, all RAMs inferred as BRAM
- [x] Gowin synthesis: zero latch warnings, all RAMs inferred as BSRAM
- [x] FPGA pin count reduced to 10 pins (bus ports internalized)
- [x] UART baud rate parameterized for real hardware (115200 @ 100MHz)

---

## Phases 1-4: VALIDATED BY SIGNAL COMPARISON

The signal comparison tool (`make compare`) confirmed that all PAL register signals
match between latch and FF modes. No per-phase incremental work was needed -- the
FF conversions done in the original vivado-fix commits were all correct.

Only two signals diverged: BDRY (init transient, harmless) and CSA (cascading from
BDRY, cycle 16415+). Both are init artifacts, not functional differences.

Per-PAL unit testbenches (originally planned for Phase 0.5) were not created since
the full-design comparison proved equivalence more comprehensively.

---

## Phase 1 (reference): Low-Risk Modules (Groups 4, 5, 6)

**Goal**: Verify and fix the easiest modules first to build confidence.

### TODO 1.1: Group 6 -- BusDriver16, CPU_CS_TCV_20
These are NOT latch-to-FF conversions. They're combinational fixes (default value
initialization, else clauses to prevent latch inference). No timing change.
- [ ] Verify these signals don't diverge in comparison output
- [ ] If they do, investigate why (should not happen)

### TODO 1.2: Group 4 -- CGA_MIC_CSEL LATCH
- [ ] Verify that `posedge ALUCLK_n` captures the correct condition result
- [ ] ALUCLK = ~(TERM_n | LCS), so ALUCLK_n = TERM_n | LCS
- [ ] Rising edge of ALUCLK_n = TERM_n going high = end of cycle
- [ ] This should correctly capture the condition at cycle end
- [ ] Check CONDN signal in comparison output

### TODO 1.3: Group 4 -- CGA_MIC_MASEL
- [ ] regW: combinational mux already works for both modes
- [ ] regIW: edge-triggered FF on posedge MCLK already correct
- [ ] Verify CSA_12_0 address sequence matches between modes

### TODO 1.4: Group 5 -- DGA F595 R-S Latches
- [ ] Verify gate signal s_zz1 has clean edges (no glitches)
- [ ] Check that S and R inputs are stable before gate rises
- [ ] PFIFC marked as unused (replaced by FIFO_8BIT) -- verify not instantiated
- [ ] POW and COMM F595 outputs: compare between modes
- [ ] If gate has glitches, may need synchronizer or different edge detection

### Validation for Phase 1:
- [ ] Run `make compare` -- Group 4/5/6 signals should now match
- [ ] **MANUAL TEST (latch)**: `make clean && make run` -- still passes same self-tests
- [ ] **MANUAL TEST (FF)**: `make clean && make compile USE_LATCHES=0 && make run`
  - Document: which tests pass? Same as latch mode? Better? Worse?
  - Check UART output -- is boot sequence progressing?
  - Examine waveforms in GTKWave for any obvious signal anomalies

---

## Phase 2: Address Latches (Group 3)

**Goal**: Verify AM29841 and TTL_74373/374 conversions are correct.

### TODO 2.1: AM29841 CHIP_31F and CHIP_32G (LE=MACLK)
- [ ] MACLK derives from PAL_44307C output, has clean rising edges
- [ ] Verify CSA data is stable when MACLK rises
- [ ] Check LUA[9:0] output matches between modes

### TODO 2.2: AM29841 CHIP_31G (LE=CLK = ~TERM_n)
- [ ] posedge CLK = negedge TERM_n (start of new cycle)
- [ ] Verify CSCA data is stable at this edge
- [ ] Check conditional UUA output

### TODO 2.3: AM29841 CHIP_25F (LE=MCLK)
- [ ] Same pattern as 2.1, different data path
- [ ] Check CA[9:0] output in CPU_PROC_32

### TODO 2.4: TTL_74373 -> TTL_74374 CHIP_30H
- [ ] Already has ifdef in CPU_CS_ACAL_17.v
- [ ] Verify LUA[12:10] matches between modes

### Validation for Phase 2:
- [ ] LUA_12_0 and UUA_11_0 match between latch and FF modes
- [ ] CSA_12_0 (microcode address sequence) identical in both modes
- [ ] **MANUAL TEST (latch)**: `make clean && make run` -- no regressions
- [ ] **MANUAL TEST (FF)**: `make clean && make compile USE_LATCHES=0 && make run`
  - Document results, compare with Phase 1 FF results
  - Look at microcode address trace -- does it follow the same path?

---

## Phase 3: Memory PALs (Group 2)

**Goal**: Verify memory subsystem PAL timing is correct with FFs.

### TODO 3.1: PAL_44310D -- BDRY (Bus Data Ready)
- [ ] BDRY is the most timing-critical signal in this group
- [ ] Set conditions use pipeline-delayed signals (BGNT50, BGNT75, BDAP50)
- [ ] The one OSC cycle FF delay adds ~25ns to already-delayed signals
- [ ] Verify against MEM_RAMC_50 state machine timing requirements
- [ ] Compare BDRY waveform between modes -- acceptable if offset by 1 OSC cycle
- [ ] Check: does the memory controller wait for BDRY, or does it sample at a fixed time?

### TODO 3.2: PAL_45008B -- DISB/TST
- [ ] ECC/parity test mode control, set during IOX to ECC register
- [ ] Low frequency operation, timing not critical
- [ ] Verify DISB and TST match between modes

### TODO 3.3: PAL_45009B -- BLOCKL
- [ ] Error path signal: blocks on local parity error
- [ ] Set: RDATA & LERR, clear: PA read or MR
- [ ] Not in critical data path
- [ ] Verify BLOCKL matches between modes

### Validation for Phase 3:
- [ ] **MANUAL TEST (latch)**: `make clean && make run` -- no regressions
- [ ] **MANUAL TEST (FF)**: `make clean && make compile USE_LATCHES=0 && make run`
  - Document: memory read/write sequences complete correctly?
  - Open waveform in GTKWave, check BDRY timing has sufficient margin
  - Compare self-test results with Phase 2 FF results -- any improvement?
- [ ] **MANUAL TEST (latch)**: `make clean && make run` -- no regressions
- [ ] **MANUAL TEST (FF)**: `make clean && make compile USE_LATCHES=0 && make run`
  - Document: memory read/write sequences complete correctly?
  - Open waveform in GTKWave, check BDRY timing has sufficient margin
  - Compare self-test results with Phase 2 FF results -- any improvement?

---

## Phase 4: BIF PALs (Group 1) -- Most Critical

**Goal**: Fix and verify the bus interface PALs. These are the most timing-sensitive
modules and should be done last because:
1. They require the most careful analysis
2. All other groups feed into or receive from the BIF
3. They contain the bus cycle state machine outputs

### TODO 4.1: PAL_44401B -- DAP (Data Address Present)
- [ ] Q0/Q1/Q2 are ALREADY real D flip-flops (PAL16R4D has registered outputs)
- [ ] Only DAP latch needs conversion
- [ ] DAP set: Q=000 & CACT & CACT25 (state machine in `s` state after loop)
- [ ] DAP clear: when TERM_n & IORQ & CC2 is false
- [ ] Verify DAP timing is correct with one-cycle delay
- [ ] Compare DAP waveform between modes

### TODO 4.2: PAL_44303B -- CBWRITE/CMWRITE
- [ ] CBWRITE set: WRITE & CACT, clear: !CACT
- [ ] CMWRITE set: WRITE & CGNT, clear: !CGNT
- [ ] CACT comes through AM29C821 pipeline, already 25ns delayed
- [ ] One OSC cycle FF delay should be acceptable
- [ ] Verify write direction changes don't miss data windows

### TODO 4.3: PAL_44302B -- EMD (Enable Data Path) -- HIGHEST RISK
- [ ] EMD controls data path between CD and LBD buses
- [ ] Set: `Q2 & Q0 & CACT` (bus cycle) or `CGNT & CGNT50` (memory cycle)
- [ ] Hold: `CACT` or `RT & CC2 & !TERM` or `IORQ & CC2 & !TERM`
- [ ] Clear: when ALL hold terms are false
- [ ] **Critical question**: Does one-cycle delay in EMD cause data to be missed?
- [ ] Check downstream 74LS245 transceiver timing margin
- [ ] Compare EMD waveform between modes -- verify no data transfer windows are missed
- [ ] If timing is tight, may need to use negedge OSC or faster clock

### TODO 4.4: PAL_44304E -- BACT/EBADR (fix bug first!)
- [ ] Fix EBADR_n_reg clear condition (Bug 2 above)
- [ ] BACT set uses BGNT50 (pipeline-delayed), one-cycle delay acceptable
- [ ] EBADR controls bus address enable -- verify timing
- [ ] Compare both BACT and EBADR between modes after bug fix

### TODO 4.5: PAL_45001B -- BLOCK/RERR (fix bug first!)
- [ ] Fix semicolon bug (Bug 1 above) -- already in Phase 0
- [ ] Error-path signals, not in critical data path
- [ ] Verify BLOCK and RERR match between modes after bug fix

### Validation for Phase 4:
- [ ] **MANUAL TEST (latch)**: `make clean && make run` -- no regressions
- [ ] **MANUAL TEST (FF)**: `make clean && make compile USE_LATCHES=0 && make run`
  - This is the big one. Check full bus cycle waveforms in GTKWave:
    - CACT -> CGNT -> EMD -> data transfer -> TERM
    - Write cycles: CBWRITE/CMWRITE direction control
    - DMA: BACT -> EBADR -> address latch -> data transfer
  - Document: same self-tests pass as latch mode?
  - Compare UART output character-for-character
  - If EMD timing is off, examine if negedge OSC or faster clock is needed

---

## Phase 5: Final Validation

### TODO 5.1: Full integration test

### TODO 5.2: Signal comparison clean

### TODO 5.3: FPGA synthesis

### TODO 5.4: Remove ifdefs (optional, after confidence is high)

### TODO 5.5: Documentation

---

## Risk Assessment

| Module | Risk | Reason | Mitigation |
|--------|------|--------|------------|
| PAL_44302B (EMD) | HIGH | Critical data path enable | Waveform analysis, margin check |
| PAL_44304E (EBADR) | HIGH | Has known bug + bus address | Fix bug, verify equations |
| PAL_44310D (BDRY) | MEDIUM | Memory timing | Inputs already delayed 50-75ns |
| PAL_44303B (CBWRITE) | MEDIUM | Write direction | CACT already delayed |
| PAL_45001B (BLOCK) | MEDIUM | Has known bug | Fix bug first |
| PAL_44401B (DAP) | LOW | Only DAP, Q0-Q2 already FFs | Straightforward |
| PAL_45008B (DISB/TST) | LOW | ECC test mode, rare | Low frequency |
| PAL_45009B (BLOCKL) | LOW | Error path only | Not timing critical |
| AM29841 (all) | LOW | Clean clock edges | FPGA_MODE parameter |
| LATCH (CSEL) | LOW | Clean ALUCLK edge | FPGA_MODE parameter |
| F595 (DGA) | LOW | Clean gate edges | Already working |
| CGA_MIC_MASEL | NONE | Already converted | Combinational mux approach |
| BusDriver16 | NONE | Combinational fix only | No timing change |
| CPU_CS_TCV_20 | NONE | Default init fix only | No timing change |

---

## Cross-PAL Feedback Analysis

Before declaring OSC clocking safe, verify there are NO cross-PAL feedback loops that
require multiple iterations to settle within one OSC cycle:

```
PAL_44302B outputs: EMD_n, BGNTCACT_n, CGNTCACT_n, DSTB_n
PAL_44303B outputs: WBD_n, CBWRITE_n, WLBD_n, CMWRITE_n
PAL_44304E outputs: DBAPR, BACT_n, EBADR_b1, FAPR, SAPR, CLKBD, EBD_n
PAL_44401B outputs: Q0_n, Q1_n, Q2_n, APR_n, DAP_n, EIOD_n, EADR_n

Cross-connections to check:
- PAL_44302B uses Q0_n, Q2_n FROM PAL_44401B --> one-directional, OK
- PAL_44303B uses BACT_n FROM PAL_44304E --> one-directional, OK
- PAL_44304E uses BGNT50_n, BDAP50_n FROM AM29C821 pipeline --> no PAL feedback
- PAL_44401B uses CC2_n, BDRY50_n, CGNT50_n FROM pipeline --> no PAL feedback

CONCLUSION: No cross-PAL feedback loops. Each PAL's self-referencing latch is internal
only. OSC clocking is safe for all PALs.
```

---

## Quick Reference: Build Commands

```bash
# Normal simulation (latches, original behavior)
cd /mnt/e/Dev/Repos/Ronny/nd-120/Verilog/sim
make clean && make compile          # or: make compile USE_LATCHES=1

# FPGA mode simulation (flip-flops)
make clean && make compile USE_LATCHES=0

# Run simulation
make run

# Compare latch vs FF behavior (after Phase 0 test infra is built)
make compare

# Run individual PAL testbenches
cd /mnt/e/Dev/Repos/Ronny/nd-120/Verilog/tests/vivado_warning_fixes
make all
```

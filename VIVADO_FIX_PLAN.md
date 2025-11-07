# Vivado Synthesis Fix Plan

**Date:** 2025-11-07
**Target Device:** xc7a35tcpg236-1 (Artix-7)
**Status:** Synthesis FAILS - Multiple errors and warnings

---

## CRITICAL ERROR - Must Fix First! 🚨

### ERROR 1: RAM Capacity Exceeded

```
ERROR: [Synth 8-5834] Design needs 3496 RAMB18 which is more than device capacity of 100
```

**Impact:** SYNTHESIS CANNOT COMPLETE
**Priority:** P0 - CRITICAL
**Effort:** High

#### Problem Analysis

The xc7a35t device has:
- 50 RAMB36 blocks (can be split into 100 RAMB18)
- Your design needs 3496 RAMB18 = **35x more than available**

From the synthesis report:
```
|16    |RAMB18E1      |    40|
|17    |RAMB36E1      |  1728|
```

This indicates 1728 RAMB36 blocks are being inferred - this is the main memory!

#### Root Cause

The ND-120 CPU design includes **6x 1MB RAM chips** (8Mbit):
```
+---RAMs :
    8191K Bit (1048575 X 8 bit) RAMs := 6     # 6 x 1MB = 6MB total
    1023K Bit (1048575 X 1 bit) RAMs := 6     # Additional 1MB
```

**Total onboard RAM: ~7MB** - This CANNOT fit in FPGA BRAM!

#### Solutions (Choose ONE)

##### **Solution A: Use External Memory (RECOMMENDED)**

**Best for:** Actual hardware implementation

1. **Modify memory controller to use external DRAM/SRAM**
   - Current: Infers BRAM in `MEM_RAM_49.v`, `SIP1M9.v`
   - Target: Interface with external memory chips

2. **Files to modify:**
   ```
   Verilog/CPU-BOARD-3202/circuit/MEM_RAM_49.v
   Verilog/CPU-BOARD-3202/circuit/MEM_43.v
   Verilog/Shared/support/SIP1M9.v
   ```

3. **Implementation steps:**
   - Replace BRAM inference with external memory controller
   - Add memory interface signals to ND120_TOP
   - Use FPGA board's DRAM (most Artix-7 boards have external RAM)
   - Keep small caches in BRAM (CPU_MMU_CACHE)

**Advantages:**
- Matches original hardware architecture
- Can support full 4MB RAM
- Better for actual CPU operation

**Effort:** 2-3 weeks

##### **Solution B: Reduce Memory Size for Simulation**

**Best for:** Testing and verification only

1. **Reduce RAM size to fit in BRAM**
   ```verilog
   // In SIP1M9.v, change:
   // OLD: localparam DEPTH = 1048576; // 1MB
   // NEW: localparam DEPTH = 4096;    // 4KB (fits in BRAM)
   ```

2. **Modify memory controller PALs:**
   - `PAL_44445B.v` (CADEC) - Address decoder
   - `PAL_44446B.v` (BADEC) - Bank decoder
   - Adjust for reduced address space

3. **Add synthesis attributes:**
   ```verilog
   (* ram_style = "block" *) reg [7:0] memory [0:4095];
   ```

**Advantages:**
- Quick fix for testing
- Can verify CPU logic
- Good for simulation

**Disadvantages:**
- Won't run real programs (need >4KB)
- Not representative of actual system
- Microcode may fail if it expects full memory

**Effort:** 1-2 days

##### **Solution C: Upgrade to Larger FPGA**

**Best for:** If you have hardware flexibility

Target devices with more BRAM:
- **xc7a200t**: 730 RAMB18 (still not enough for 7MB!)
- **xc7k325t**: 1190 RAMB18 (closer but still insufficient)
- **xczu9eg** (Zynq UltraScale+): 2160 RAMB18 (would work!)

**Reality check:** Even large FPGAs can't hold 7MB in BRAM. External memory is still needed.

#### Recommended Approach

**PHASE 1 (Immediate):** Solution B - Reduce memory to 4KB
- Gets synthesis passing
- Enables testing of CPU logic
- Timeline: 1-2 days

**PHASE 2 (Long-term):** Solution A - External memory interface
- Production-ready implementation
- Full functionality
- Timeline: 2-3 weeks

---

## Priority 1: Latch Inference Warnings (66 instances)

These are the latches identified in `LATCH_ANALYSIS.md`. Vivado confirms they're being synthesized as latches.

### P1.1: Critical Latches (Already Documented)

| File | Line | Variable | Action |
|------|------|----------|--------|
| AM29841.v | 25 | Q_Latch_reg | Convert to posedge LE |
| TTL_74373.v | 29 | Q_Latch_reg | Convert to posedge C |
| LATCH.v | 18 | regD_reg | Convert to posedge ENABLE |
| CGA_MIC_MASEL.v | 83 | regW_reg | Fix variable ordering |
| CPU_CS_TCV_20.v | 46 | regCSBITS_reg | Convert to clocked |

**Action:** Follow the conversion plan in `LATCH_ANALYSIS.md`

### P1.2: PAL Latches (Additional)

| File | Line | Variable | Fix |
|------|------|----------|-----|
| PAL_44310D.v | 71 | BDRY_reg | Add to posedge CK |
| PAL_45008B.v | 83-84 | TST_reg, DISB_reg | Add to posedge CK |
| PAL_45009B.v | 83 | BLOCKL_reg | Add to posedge CK |
| PAL_44303B.v | 58,63 | CBWRITE_reg, CMWRITE_reg | Add to posedge CK |
| PAL_44302B.v | 73 | EMD_reg | Add to posedge CK |
| PAL_44401B.v | 114 | DAP_reg | Already documented |
| PAL_45001B.v | 96 | RERR_reg | Add to posedge CK |

### P1.3: DGA Latches

| File | Line | Variable | Action |
|------|------|----------|--------|
| F595.v | 37-38 | regQ_reg, regQn_reg | Keep (NEC primitive) |
| BusDriver16.v | 35 | IO_reg_reg | Fix tri-state logic |

**F595 is intentional** (R/S latch), but BusDriver16 needs fixing:

```verilog
// Current (WRONG):
always @(*) begin
    if (OE_n == 0)
        IO_reg = D;  // Latch inferred!
end

// Fixed:
assign Q = OE_n ? 16'bZ : D;  // Proper tri-state
```

---

## Priority 2: Variable Declaration Order

```
WARNING: [Synth 8-6901] identifier 'regIW' is used before its declaration
```

### Files to Fix:

1. **CGA_MIC_MASEL.v:82-83**
   ```verilog
   // WRONG ORDER:
   assign s_something = regIW;  // Line 82 - regIW used
   reg regIW;                   // Line 100 - regIW declared

   // FIX: Move declarations before usage
   reg regIW;
   reg regW;
   assign s_something = regIW;
   ```

2. **PAL_45008B.v:71,75,79**
   ```verilog
   // WRONG:
   assign output1 = TST;   // Line 71 - used
   assign output2 = DISB;  // Line 75 - used
   reg TST;                // Line 100 - declared

   // FIX: Move reg declarations to top of module
   ```

**Quick Fix Script:**
```bash
# For each file, move all reg/wire declarations to top of module
# after parameters and before any assign statements
```

---

## Priority 3: Registers with Set/Reset Priority Issues

```
WARNING: [Synth 8-7137] Register regQ_reg in module F714 has both Set and reset
with same priority. This may cause simulation mismatches.
```

### Files to Fix:

1. **FIFO_8BIT.v** - mem_reg
2. **F714.v:37-38** - regQ_reg, reqQ_n_reg
3. **F617.v:41-42** - N01_Q_reg, N02_QB_reg

#### Problem:
```verilog
// Current:
always @(posedge CLK or posedge SET or posedge RESET) begin
    if (SET | RESET) begin  // BOTH checked together - priority unclear
        if (SET) Q <= 1;
        if (RESET) Q <= 0;
    end
end
```

#### Fix:
```verilog
// Fixed - Clear priority:
always @(posedge CLK or posedge SET or posedge RESET) begin
    if (RESET) begin        // RESET has priority
        Q <= 0;
    end else if (SET) begin // Then SET
        Q <= 1;
    end else begin          // Then CLK
        Q <= D;
    end
end
```

**Files:**
- `Verilog/Shared/support/FIFO_8BIT.v`
- `Verilog/DECODE-GateArray/DGA/circuit/F714.v`
- `Verilog/DECODE-GateArray/DGA/circuit/F617.v`

---

## Priority 4: Port Width Mismatch

```
WARNING: [Synth 8-689] width (6) of port connection 'LED' does not match
port width (7) of module 'ND3202D'
```

**File:** `ND120_TOP.v:245`

### Fix:

```verilog
// Current:
output [6:0] LED // ND3202D expects 7 bits (0-6)

wire [5:0] s_cpu_led;  // Only 6 bits provided (0-5)

ND3202D CPU_BOARD (
    .LED(s_cpu_led[5:0])  // Only 6 bits connected!
);

// Fix Option 1: Connect bit 6 to ground
assign led[6] = 1'b0;
wire [6:0] s_cpu_led_full = {1'b0, s_cpu_led};

// Fix Option 2: Expand s_cpu_led to 7 bits
wire [6:0] s_cpu_led;  // Now 7 bits
```

---

## Priority 5: Unused Default Blocks

```
INFO: [Synth 8-226] default block is never used
```

These are INFO messages but indicate unreachable code:

### Files to Fix:

1. **Multiplexer_4.v:19**
   ```verilog
   always @* begin
       case(sel)
           2'b00: out = in0;
           2'b01: out = in1;
           2'b10: out = in2;
           2'b11: out = in3;
           default: out = 1'b0;  // NEVER REACHED (2-bit sel covers all)
       endcase
   end

   // Fix: Remove default or change to x
   default: out = 1'bx;  // Helps synthesis optimize
   ```

2. **Decoder_8.v:23**
3. **CGA_MIC_MASEL.v:96**
4. **Multiplexer_8.v:22**
5. **SC2661_UART.v:286**

---

## Priority 6: RAM Implementation Warnings

```
WARNING: [Synth 8-4767] Trying to implement RAM 'mem_reg' in registers.
Block RAM or DRAM implementation is not possible
```

### Issue: FIFO_8BIT Async Reset

**File:** `Verilog/Shared/support/FIFO_8BIT.v`

```verilog
// Current:
always @(posedge CLK or posedge RESET) begin
    if (RESET)
        mem[addr] <= 0;  // Async reset prevents BRAM inference
end

// Fix: Use synchronous reset
always @(posedge CLK) begin
    if (RESET)
        mem[addr] <= 0;  // Sync reset allows BRAM
end
```

---

## Priority 7: Unused Sequential Elements

```
WARNING: [Synth 8-3332] Sequential element (DCD/DGA/POW/A570/regQ_reg)
is unused and will be removed
```

These are optimization messages - **OK to ignore** if the removed elements are truly unused.

**Elements being removed:**
- Power-on-reset logic elements (A570, A576, A574, A569, A575, A600)
- COMM logic (A207)

**Action:** Review if these were intentionally unused, or if they should be connected.

---

## Priority 8: Unconnected Ports (78 warnings)

These are low priority but should be cleaned up for good practice.

### Categories:

1. **Intentionally unused sysclk/sys_rst_n** (combinational modules)
   - Action: Add `(* DONT_TOUCH = "true" *)` or remove from port list

2. **Test/debug signals not connected:**
   - `DEBUGFLAG`, `btn2`, `led[6]` in ND120_TOP
   - Action: Connect or remove from top-level

3. **Module ports not used:**
   - `tick` in D_FLIPFLOP (can remove from module definition)
   - UART signals: BRCLK, CTS_n, RXC_n, TXC_n
   - Memory signals: CAS9_n

---

## Implementation Plan

### Phase 0: Memory Fix (CRITICAL)

**Timeline:** 1-2 days
**Priority:** P0

1. Reduce memory size to 4KB for initial synthesis:
   ```verilog
   // In SIP1M9.v:
   localparam DEPTH = 4096;  // Was 1048576
   ```

2. Update address decoders in PAL chips

3. Verify synthesis completes

### Phase 1: Latch Conversions

**Timeline:** 1 week
**Priority:** P1

Follow `LATCH_ANALYSIS.md` plan:
1. Convert TTL_74373 and AM29841 together
2. Convert LATCH module
3. Convert PAL latches
4. Fix BusDriver16 tri-state

### Phase 2: Quick Fixes

**Timeline:** 2-3 days
**Priority:** P2

1. Fix variable declaration order (4 files)
2. Fix Set/Reset priority (3 files)
3. Fix LED port width mismatch (1 file)
4. Remove unreachable default blocks (5 files)

### Phase 3: RAM and Optimization

**Timeline:** 1 week
**Priority:** P3

1. Fix FIFO_8BIT async reset
2. Review unused sequential elements
3. Clean up unconnected ports
4. Add proper synthesis attributes

### Phase 4: External Memory (Long-term)

**Timeline:** 2-3 weeks
**Priority:** P2 (after Phase 0-3 complete)

1. Design external memory interface
2. Implement memory controller
3. Test with real DRAM
4. Restore full 4MB capacity

---

## Quick Reference: Critical Files to Modify

### Must Fix for Synthesis to Pass:

1. **Verilog/Shared/support/SIP1M9.v**
   - Reduce DEPTH from 1048576 to 4096

2. **Verilog/CPU-BOARD-3202/circuit/MEM_RAM_49.v**
   - Adjust memory size

3. **Verilog/PAL/PAL_44445B.v** (CADEC)
   - Update for smaller address space

4. **Verilog/PAL/PAL_44446B.v** (BADEC)
   - Update bank decode logic

### Should Fix for Clean Synthesis:

5. **Verilog/Shared/support/AM29841.v** (latch)
6. **Verilog/Shared/support/TTL_74373.v** (latch)
7. **Verilog/Shared/ndlib/LATCH.v** (latch)
8. **Verilog/DELILAH-CPU/CGA_MIC/circuit/CGA_MIC_MASEL.v** (declaration order + latch)
9. **Verilog/CPU-BOARD-3202/circuit/CPU_CS_TCV_20.v** (latch)
10. **Verilog/ND120_TOP.v** (LED port width)

---

## Testing Strategy

### After Phase 0 (Memory Fix):

```bash
cd Verilog
vivado -mode batch -source synthesize.tcl

# Check for:
# - Synthesis completes without errors
# - BRAM usage < 100 blocks
# - Latch warnings still present (expected)
```

### After Phase 1 (Latch Fix):

```bash
# Check for:
# - No latch inference warnings
# - Timing reports show proper clock domains
# - Simulation still passes
```

### After Phase 2 (Quick Fixes):

```bash
# Check for:
# - No variable declaration warnings
# - No set/reset priority warnings
# - No port width mismatches
```

### Validation:

1. Run Verilator simulation with reduced memory
2. Verify microcode loads
3. Check CPU self-test (may fail due to memory size)
4. GTKWave waveform analysis

---

## Expected Results

### After Phase 0:
```
Synthesis: PASS
BRAMs Used: ~60/100 (60%)
Latches: 66 (warnings)
Timing: Unknown (need implementation)
```

### After Phase 1:
```
Synthesis: PASS
BRAMs Used: ~60/100 (60%)
Latches: 1 (F595 only - intentional)
Timing: Improved
```

### After Phase 2:
```
Synthesis: PASS
Warnings: <20 (mostly unconnected ports)
Clean slate for implementation
```

### After Phase 3:
```
Implementation: Ready to attempt
Clean synthesis output
All major issues resolved
```

---

## Risk Assessment

| Phase | Risk Level | Mitigation |
|-------|-----------|------------|
| Phase 0 | LOW | Memory reduction well understood |
| Phase 1 | MEDIUM | Follow proven latch conversion plan |
| Phase 2 | LOW | Simple code fixes |
| Phase 3 | LOW | Cleanup and optimization |
| Phase 4 | HIGH | External memory requires hardware |

---

## Appendix: Synthesis Resource Summary

### Current Design (FAILS):

```
RAMs:
  - RAMB36E1: 1728 (needs 1728, have 50) ❌
  - RAMB18E1: 40

Registers: 1,489 flip-flops
Latches: 151 (66 unique warnings) ❌
LUTs: ~30,000 (estimated)
```

### Target After Phase 0 (4KB RAM):

```
RAMs:
  - RAMB36E1: ~30 ✓
  - RAMB18E1: ~20 ✓

Total BRAM: ~60/100 (60%) ✓
```

### Target After Phase 1 (Latch Fix):

```
Latches: 1 (F595 only) ✓
Flip-flops: 1,600 (more than before) ✓
```

---

## Document Version

**Version:** 1.0
**Date:** 2025-11-07
**Author:** Analysis by Claude
**Related:** LATCH_ANALYSIS.md

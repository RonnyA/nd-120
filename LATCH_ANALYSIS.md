# ND-120 Verilog Latch Analysis and Conversion Plan

**Date:** 2025-11-07
**Purpose:** Identify all latches in the ND-120 Verilog codebase and provide recommendations for converting them to clocked (synchronous) flip-flops for improved FPGA implementation.

---

## Executive Summary

The ND-120 Verilog codebase contains **6 primary latch implementations** that need attention for modern FPGA synthesis. Latches were common in 1980s designs but cause issues in modern FPGAs:

- **Timing complexity:** Latches create complex timing paths
- **Synthesis warnings:** Most FPGA tools generate warnings/errors for latches
- **Verification challenges:** Static timing analysis is harder with latches
- **Metastability risks:** Level-sensitive latches are more prone to metastability

**Total Latches Found:** 6 distinct implementations used in multiple locations

---

## Detailed Latch Inventory

### 1. **F595 - NEC R/S Latch** ⚠️ CRITICAL

**Location:** `Verilog/DECODE-GateArray/DGA/circuit/F595.v:15`

**Type:** True R/S latch with gated enable (level-sensitive)

**Description:**
```verilog
always @* begin
    if (H03_G) begin  // Gate Enable
        if (H01_S & H02_R) begin
            regQ  = 1'b1;
            regQn = 1'b1;
        end else if (H02_R & !H01_S) begin
            regQ  = 1'b0;
            regQn = 1'b1;
        end else if (!H02_R & H01_S) begin
            regQ  = 1'b1;
            regQn = 1'b0;
        end
    end
end
```

**Status:** Intentional - part of DGA gate array primitive

**Recommendation:**
- **KEEP AS-IS** - This is a hardware-accurate representation of the NEC F595 cell
- Alternative: Convert to edge-triggered D flip-flop if H03_G can be used as clock
- Risk: May change timing behavior of DGA decode logic

**Usage:** Used in DGA (Decode Gate Array) for instruction decode logic

---

### 2. **TTL_74373 - 8-bit Transparent Latch** ⚠️ HIGH PRIORITY

**Location:** `Verilog/Shared/support/TTL_74373.v:14`

**Type:** 8-bit transparent latch with tri-state outputs

**Description:**
```verilog
always @(*) begin
    if (C) begin
        Q_Latch = D;  // Transparent mode: follows input when C is high
    end else begin
        Q_Latch = Q_Latch; // Hold value when C is low
    end
end
```

**Usage Locations:**
- `CPU_CS_ACAL_17.v:110` - Microcode address calculation (CHIP_30H)
  - Controlled by `MACLK` signal
  - Latches microcode address bits CSA[12:10] → LUA[12:10]

**Recommendation:** ✅ **CONVERT TO FLIP-FLOP**

**Conversion Strategy:**
```verilog
// OPTION 1: Rising edge D flip-flop
always @(posedge C) begin
    Q_reg <= D;
end

// OPTION 2: Dual-edge flip-flop (if timing requires both edges)
always @(posedge C or negedge C) begin
    Q_reg <= D;
end
```

**Impact:**
- May shift timing by half clock cycle
- Need to verify MACLK timing relationships in microcode sequencing
- Should coordinate with AM29841 conversion (see below)

---

### 3. **AM29841 - 10-bit Bus Latch** ⚠️ HIGH PRIORITY

**Location:** `Verilog/Shared/support/AM29841.v:13`

**Type:** 10-bit transparent latch with tri-state outputs

**Description:**
```verilog
always @(*) begin
    if (LE)
        Q_Latch = D;  // Transparent when LE is high
    else
        Q_Latch = Q_Latch; // Hold when LE is low
end
```

**Usage Locations:**
- `CPU_CS_ACAL_17.v:117` - Microcode address (CHIP_31F & CHIP_32G)
  - Controlled by `MACLK` signal
  - Latches CSA[9:0] → LUA[9:0]
- `CPU_PROC_32.v` - Additional usage in processor logic

**Recommendation:** ✅ **CONVERT TO FLIP-FLOP**

**Conversion Strategy:**
```verilog
// Convert to rising edge D flip-flop
always @(posedge LE) begin
    Q_reg <= D;
end
```

**Impact:**
- Coordinates with TTL_74373 conversion
- Both use MACLK, so timing shift should be consistent
- Critical path: Microcode address calculation

---

### 4. **Generic LATCH Module** ⚠️ MEDIUM PRIORITY

**Location:** `Verilog/Shared/ndlib/LATCH.v:10`

**Type:** Generic transparent D-latch

**Description:**
```verilog
always @(D or ENABLE) begin
    if (ENABLE) begin
        regD <= D;  // Transparent when ENABLE is high
    end
    // Hold value when ENABLE is low
end
```

**Usage Locations:**
- `CGA_MIC_CSEL.v:155` - Condition select latch (CSEL_LATCH)
  - Enable signal: `ALUCLK_n` (inverted ALU clock)
  - Latches condition code from multiplexer → CONDN output

**Recommendation:** ✅ **CONVERT TO FLIP-FLOP**

**Conversion Strategy:**
```verilog
// Convert to falling edge flip-flop (since enabled by ALUCLK_n)
always @(negedge ALUCLK) begin
    regD <= D;
end

// OR if positive edge is preferred:
always @(posedge ALUCLK) begin
    regD_next <= D;  // May need pipeline adjustment
end
```

**Impact:**
- Critical path in ALU condition evaluation
- Used in microcode condition selection logic
- Verify timing with ALUCLK and condition register

---

### 5. **PAL_44401B - DAP Latch** ⚠️ MEDIUM PRIORITY

**Location:** `Verilog/PAL/PAL_44401B.v:111`

**Type:** Combinational latch in PAL logic

**Description:**
```verilog
always @(*) begin
    if (Q2_n & Q1_n & Q0_n & CACT & CACT25)
        DAP = 1'b1;
    else if ((TERM_n & IORQ & CC2) == 0)
        DAP = 1'b0;
    // Else: DAP holds previous value (latch behavior)
end
```

**Recommendation:** ✅ **CONVERT TO FLIP-FLOP**

**Conversion Strategy:**
```verilog
// Convert to clocked logic using CK signal
always @(posedge CK) begin
    if (Q2_n & Q1_n & Q0_n & CACT & CACT25)
        DAP <= 1'b1;
    else if ((TERM_n & IORQ & CC2) == 0)
        DAP <= 1'b0;
    // else: DAP retains value (explicit in flip-flop)
end
```

**Impact:**
- DAP (Data Present) signal in bus timing logic
- Used in I/O cycle control (see comments at line 146-150)
- Verify with BTIM PAL timing requirements

**Note:** Original PALASM comment indicates this was a timing fix (line 148):
```
; 060387 JLB: DAP HELD INTO ADDRESS PART OF IOX CYCLES AFTER A
```

---

### 6. **CGA_INTR - LAA_3_0 Latch** ⚠️ LOW PRIORITY

**Location:** `Verilog/DELILAH-CPU/CGA_INTR/circuit/CGA_INTR.v:126`

**Type:** Level-sensitive register

**Description:**
```verilog
always @(LAA_3_0) begin
    regLAA_3_0 <= LAA_3_0;
end
```

**Comment in code (line 124):**
```verilog
// Need to add delay to changing of LAA_3_0 so that if it changes when MCLK
// changes we don't get the "new and wrong value"
// TODO: Review if this can be solved with rising edge on sysclk
```

**Recommendation:** ✅ **CONVERT TO FLIP-FLOP**

**Conversion Strategy:**
```verilog
// Convert to synchronous flip-flop on MCLK
always @(posedge MCLK or posedge sysclk) begin
    regLAA_3_0 <= LAA_3_0;
end

// OR use sysclk as suggested in TODO:
always @(posedge sysclk) begin
    regLAA_3_0 <= LAA_3_0;
end
```

**Impact:**
- Interrupt controller address latching
- Low risk - adds one cycle delay to interrupt address
- May improve timing margin

---

## Additional Findings

### Correctly Implemented Flip-Flops ✅

These components are **already correctly implemented** as edge-triggered flip-flops:

1. **F617** - D Flip-Flop with reset/set (DGA/circuit/F617.v:35)
   ```verilog
   always @(posedge H02_C or posedge s_set or posedge s_reset)
   ```

2. **F714** - T Flip-Flop with reset/set (DGA/circuit/F714.v:41)
   ```verilog
   always @(posedge s_t or posedge s_reset or posedge s_set)
   ```

3. **F924** - 4-bit D Flip-Flop (DGA/circuit/F924.v:68-115)
   - Uses D_FLIPFLOP module instances

4. **PAL_44601B** - State machine flip-flops (PAL/PAL_44601B.v:89)
   ```verilog
   always @(posedge CK)
   ```

5. **Most PAL chips** - Correctly use registered outputs with posedge CK

---

## Conversion Priority and Risk Assessment

### Priority 1: HIGH RISK - Coordinate Together

These latches work together in the microcode path and should be converted simultaneously:

| Component | File | Line | Risk | Effort |
|-----------|------|------|------|--------|
| TTL_74373 | TTL_74373.v | 26 | HIGH | Medium |
| AM29841 (x2) | AM29841.v | 23 | HIGH | Medium |

**Rationale:** Both are controlled by MACLK in CPU_CS_ACAL_17. Converting together maintains timing relationships.

### Priority 2: MEDIUM RISK - Independent Conversions

| Component | File | Line | Risk | Effort |
|-----------|------|------|------|--------|
| LATCH (CSEL) | LATCH.v | 28 | MEDIUM | Low |
| PAL_44401B (DAP) | PAL_44401B.v | 111 | MEDIUM | Low |

**Rationale:** Independent paths, can be converted and tested separately.

### Priority 3: LOW RISK

| Component | File | Line | Risk | Effort |
|-----------|------|------|------|--------|
| CGA_INTR (LAA) | CGA_INTR.v | 126 | LOW | Low |

**Rationale:** Interrupt path, one cycle delay acceptable. Already has TODO comment.

### Keep As-Is: Historical Accuracy

| Component | File | Line | Reason |
|-----------|------|------|--------|
| F595 (R/S Latch) | F595.v | 34 | NEC gate array primitive - intentional design |

---

## Implementation Plan

### Phase 1: Preparation (Week 1)

1. ✅ **Identify all latches** - COMPLETED
2. **Create test benches for each module:**
   - CPU_CS_ACAL_17 (microcode address path)
   - CGA_MIC_CSEL (condition select)
   - PAL_44401B (bus timing)
   - CGA_INTR (interrupt controller)
3. **Document current timing:**
   - Capture GTKWave traces of current behavior
   - Document MACLK, ALUCLK, and CK timing relationships

### Phase 2: Convert Priority 1 (Week 2)

**Target:** TTL_74373 + AM29841 (microcode path)

1. **Create new modules:**
   - `TTL_74374.v` - Edge-triggered version of 74373
   - `AM29841_DFF.v` - Edge-triggered version of AM29841

2. **Modify CPU_CS_ACAL_17.v:**
   - Replace TTL_74373 with TTL_74374
   - Replace AM29841 with AM29841_DFF
   - Keep MACLK connections

3. **Test:**
   - Run microcode load test
   - Verify MACL execution
   - Compare timing traces (before/after)
   - Validate address calculation paths

4. **Verify:**
   - Run full CPU test suite
   - Check all 14 self-tests
   - Ensure OPCOM communication still works

### Phase 3: Convert Priority 2 (Week 3)

**Target:** LATCH (CSEL) + PAL_44401B (DAP)

1. **CGA_MIC_CSEL conversion:**
   - Replace LATCH with D_FLIPFLOP
   - Use `@(negedge ALUCLK)` since currently uses ALUCLK_n
   - Test condition code evaluation

2. **PAL_44401B conversion:**
   - Convert DAP to clocked logic
   - Use `@(posedge CK)`
   - Test bus timing cycles

3. **Validate:**
   - Test ALU operations
   - Test I/O cycles
   - Verify bus timing (BTIM)

### Phase 4: Convert Priority 3 (Week 4)

**Target:** CGA_INTR (LAA)

1. **Simple conversion:**
   - Change to `@(posedge MCLK)` or `@(posedge sysclk)`
   - Test with existing comment's suggestion

2. **Test interrupt handling:**
   - Verify BINT10-15 interrupts
   - Check interrupt latency (may increase by 1 cycle)

### Phase 5: Validation & Optimization (Week 5)

1. **Full system testing:**
   - Run complete test suite
   - Boot microcode
   - Execute INSTRUCTION-B.BPUN test program
   - Verify all 14 tests pass

2. **FPGA Synthesis:**
   - Synthesize for target FPGA (Gowin)
   - Check for latch warnings (should be eliminated)
   - Verify timing constraints met
   - Check resource utilization

3. **Documentation:**
   - Update module documentation
   - Create timing diagrams
   - Document any behavioral changes

---

## Detailed Conversion Examples

### Example 1: TTL_74373 → TTL_74374

**Before (Transparent Latch):**
```verilog
module TTL_74373 (
    input wire [7:0] D,
    input wire C,         // Transparent when high
    input wire OC_n,
    output wire [7:0] Q
);
    reg [7:0] Q_Latch;

    always @(*) begin
        if (C) begin
            Q_Latch = D;  // Transparent
        end else begin
            Q_Latch = Q_Latch; // Hold
        end
    end

    assign Q = OC_n ? 8'b0 : Q_Latch;
endmodule
```

**After (Edge-Triggered Flip-Flop):**
```verilog
module TTL_74374 (
    input wire [7:0] D,
    input wire CLK,       // Clock edge
    input wire OC_n,
    output wire [7:0] Q
);
    reg [7:0] Q_reg;

    always @(posedge CLK) begin
        Q_reg <= D;  // Capture on rising edge
    end

    assign Q = OC_n ? 8'b0 : Q_reg;
endmodule
```

**Key Changes:**
- `C` renamed to `CLK` for clarity
- `always @(*)` → `always @(posedge CLK)`
- Removed conditional assignment (always captures)
- Timing: Data captured on rising edge instead of level-sensitive

---

### Example 2: Generic LATCH → D_FLIPFLOP

**Before (Transparent Latch):**
```verilog
module LATCH (
    input  wire D,
    input  wire ENABLE,
    output wire Q,
    output wire QN
);
    reg regD;

    always @(D or ENABLE) begin
        if (ENABLE) begin
            regD <= D;
        end
    end

    assign Q = regD;
    assign QN = ~regD;
endmodule
```

**After (D Flip-Flop):**
```verilog
module D_LATCH_TO_DFF (
    input  wire D,
    input  wire CLK,      // Was ENABLE
    output wire Q,
    output wire QN
);
    reg regD;

    always @(posedge CLK) begin
        regD <= D;
    end

    assign Q = regD;
    assign QN = ~regD;
endmodule
```

**Usage Update in CGA_MIC_CSEL.v:**
```verilog
// Before:
LATCH CSEL_LATCH (
    .D(s_pcond_n),
    .ENABLE(s_aluclk_n),  // Inverted clock
    .Q(s_cond_n_out),
    .QN()
);

// After (Option 1 - use negedge):
D_FLIPFLOP #(.InvertClockEnable(0)) CSEL_DFF (
    .clock(s_aluclk),
    .d(s_pcond_n),
    .preset(1'b0),
    .q(s_cond_n_out),
    .qBar(),
    .reset(1'b0),
    .tick(1'b1)
);
// Note: Change sensitivity from negedge to posedge by removing _n from enable

// After (Option 2 - use negedge explicitly):
reg s_cond_reg;
always @(negedge s_aluclk) begin
    s_cond_reg <= s_pcond_n;
end
assign s_cond_n_out = s_cond_reg;
```

---

### Example 3: PAL_44401B DAP Signal

**Before (Combinational Latch):**
```verilog
reg DAP;

always @(*) begin
    if (Q2_n & Q1_n & Q0_n & CACT & CACT25)
        DAP = 1'b1;
    else if ((TERM_n & IORQ & CC2) == 0)
        DAP = 1'b0;
    // Implicit: else DAP holds value (latch)
end

assign DAP_n = ~DAP;
```

**After (Clocked Logic):**
```verilog
reg DAP;

always @(posedge CK) begin
    if (Q2_n & Q1_n & Q0_n & CACT & CACT25)
        DAP <= 1'b1;
    else if ((TERM_n & IORQ & CC2) == 0)
        DAP <= 1'b0;
    // Explicit: else DAP retains previous value (D flip-flop behavior)
end

assign DAP_n = ~DAP;
```

**Key Changes:**
- `always @(*)` → `always @(posedge CK)`
- Blocking assignment `=` → Non-blocking assignment `<=`
- Timing: DAP changes on clock edge instead of immediately

---

## Testing Strategy

### Unit Tests

For each converted module, create testbench:

```verilog
module test_TTL_74374;
    reg [7:0] D;
    reg CLK;
    reg OC_n;
    wire [7:0] Q;

    TTL_74374 DUT (
        .D(D),
        .CLK(CLK),
        .OC_n(OC_n),
        .Q(Q)
    );

    // Clock generation
    initial CLK = 0;
    always #5 CLK = ~CLK;  // 10ns period

    initial begin
        // Test 1: Capture on rising edge
        OC_n = 0; D = 8'hAA;
        @(posedge CLK);
        #1; assert(Q == 8'hAA);

        // Test 2: Change during low (should not affect)
        D = 8'h55;
        #4; assert(Q == 8'hAA);  // Still old value

        // Test 3: Capture new value on next edge
        @(posedge CLK);
        #1; assert(Q == 8'h55);

        // Test 4: Tri-state control
        OC_n = 1;
        #1; assert(Q == 8'h00);  // Disabled

        $display("All tests passed!");
        $finish;
    end
endmodule
```

### Integration Tests

1. **Microcode Path Test:**
   - Load microcode (tests TTL_74373/AM29841)
   - Verify address sequencing
   - Check LUA and UUA outputs

2. **ALU Condition Test:**
   - Execute conditional instructions (tests LATCH)
   - Verify condition codes
   - Check branches work correctly

3. **Bus Timing Test:**
   - Execute I/O operations (tests PAL_44401B)
   - Verify DAP signal timing
   - Check IORQ cycles

4. **Interrupt Test:**
   - Trigger interrupts (tests CGA_INTR)
   - Verify interrupt address latching
   - Check interrupt priority

---

## Timing Analysis

### Current Timing Issues

1. **MACLK relationship to sysclk:**
   - Determine if MACLK is derived from sysclk
   - Check phase relationship
   - Verify setup/hold times

2. **ALUCLK relationship to sysclk:**
   - Check if ALUCLK is sysclk or derived
   - Understand _n (inverted) usage

3. **Latch transparency windows:**
   - Document when each latch is transparent
   - Measure transparency duration
   - Check for races

### Expected Timing Changes

| Signal Path | Before (Latch) | After (FF) | Delta |
|-------------|----------------|------------|-------|
| CSA → LUA | Transparent during MACLK high | Captured on MACLK↑ | -½ cycle |
| Condition → CONDN | Transparent during ALUCLK low | Captured on ALUCLK↓ | -½ cycle |
| DAP set/clear | Immediate | On next CK↑ | +1 cycle |

---

## Risk Mitigation

### Potential Issues

1. **Timing shifts:**
   - **Risk:** ½ cycle shift may violate timing
   - **Mitigation:** Add pipeline stage if needed
   - **Test:** Verify with GTKWave traces

2. **Functional changes:**
   - **Risk:** Edge-triggered may miss fast pulses
   - **Mitigation:** Review all signal durations
   - **Test:** Compare waveforms before/after

3. **Race conditions:**
   - **Risk:** Removing latches may expose races
   - **Mitigation:** Add explicit synchronizers
   - **Test:** Run extended simulation

### Rollback Plan

1. Keep original latch modules with `_LATCH` suffix
2. Use `define CONVERT_LATCHES to enable new modules
3. Create git branch for conversions
4. Tag working version before major changes

---

## FPGA Synthesis Benefits

### Expected Improvements

1. **Eliminate latch warnings:**
   - Current: ~6 latch inference warnings
   - After: 0 latch warnings

2. **Improved timing analysis:**
   - Static timing analysis more accurate
   - Clock domain crossing easier to identify
   - Setup/hold checks simpler

3. **Better resource utilization:**
   - FPGAs optimize for flip-flops
   - May reduce LUT usage
   - May improve Fmax

4. **Easier verification:**
   - Formal verification possible
   - Clearer clock domain structure
   - Simpler CDC analysis

---

## References

### Datasheets

1. **74373** - 8-bit Transparent Latch
   https://www.ti.com/lit/ds/symlink/sn54ls373-sp.pdf

2. **74374** - 8-bit Edge-Triggered Flip-Flop
   https://www.ti.com/lit/ds/symlink/sn74ls374.pdf

3. **AM29841** - 10-bit Bus Latch
   https://www.alldatasheet.com/datasheet-pdf/pdf/107079/AMD/AM29841.html

4. **PAL16R4/R6/R8** - Registered PAL Devices
   https://rocelec.widen.net/view/pdf/c6dwcslffz/VANTS00080-1.pdf

### ND-120 Documentation

- Design Documents: `DesignDocuments/`
- Logisim Schematics: `Logisim/`
- Current Verilog: `Verilog/`

---

## Conclusion

Converting latches to flip-flops in the ND-120 design is **feasible and recommended** for modern FPGA implementation. The conversions should be done in phases with thorough testing at each stage.

**Key Takeaways:**

1. ✅ 6 latches identified
2. ✅ 5 should be converted (1 keep as-is)
3. ✅ Priority 1: Microcode path (coordinated conversion)
4. ✅ Estimated effort: 4-5 weeks with testing
5. ✅ Expected benefits: Better synthesis, timing, verification

**Next Steps:**

1. Review this analysis with team
2. Create test benches for current behavior
3. Begin Phase 1 conversions
4. Validate with simulation before FPGA testing

---

**Document Version:** 1.0
**Author:** Analysis by Claude (Anthropic)
**Last Updated:** 2025-11-07

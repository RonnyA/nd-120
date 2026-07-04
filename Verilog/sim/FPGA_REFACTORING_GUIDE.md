# FPGA Refactoring Guide: Converting Asynchronous TTL-Style Logic to Synchronous Design

## 1. Problem Statement

The current Verilog design is a direct structural recreation of a late-1980s minicomputer implemented using:

* TTL logic
* PALs / ASICs
* PCB-level propagation delays

This design relies on **implicit timing through signal delays**.

When mapped into:

* Verilator (zero-delay simulation)
* FPGA (different physical delays)

The result is:

* ~50% instruction correctness in simulation
* Unstable behavior on FPGA

---

## 2. Root Cause

The design uses **combinational signals as clocks**, e.g.:

```verilog
always @(posedge some_signal)
```

This creates:

* Undefined event ordering
* Race conditions
* Dependency on physical propagation delays

### Original Hardware Behavior

```
Signal A arrives first
Signal B arrives later
→ Register triggered by B sees stable A
```

### In Verilator

```
A and B evaluated in arbitrary order
→ nondeterministic behavior
```

### In FPGA

```
Different routing delays
→ inconsistent ordering and glitches
```

---

## 3. Key Insight

The original system encodes timing in **delays**.

FPGA systems require timing to be encoded in **state and clocked logic**.

---

## 4. Fundamental Rule

❌ NEVER use:

```verilog
always @(posedge some_signal)
```

Unless `some_signal` is a real clock (BUFG, PLL, etc.)

---

## 5. Correct Transformation Pattern

### Replace this:

```verilog
always @(posedge some_signal)
    regA <= data;
```

### With this:

```verilog
reg some_signal_d;

always @(posedge clk)
    some_signal_d <= some_signal;

wire pulse = some_signal & ~some_signal_d;

always @(posedge clk) begin
    if (pulse)
        regA <= data;
end
```

---

## 6. What This Change Does

| Aspect             | Before                | After         |
| ------------------ | --------------------- | ------------- |
| Trigger source     | Arbitrary signal edge | Global clock  |
| Ordering           | Implicit / undefined  | Explicit      |
| Stability          | Delay-dependent       | Deterministic |
| FPGA compatibility | Invalid               | Valid         |

---

## 7. Why This Fixes the Problem

### Before

* Data and control signals change at different times
* Register may latch unstable data

### After

* All signals sampled on same clock edge
* Pulse generated after stable sampling
* Register updates deterministically

---

## 8. What Must Be Converted

Search for all occurrences of:

* `always @(posedge <anything not clk>)`
* Derived clocks from PALs / LUTs
* Signals like:

  * UCLK
  * BANKx_n
  * MWRITE
  * PAL outputs

These are NOT real clocks — they are **events**.

---

## 9. Migration Strategy

### Step 1: Do NOT rewrite everything

Work incrementally.

### Step 2: Pick one failing instruction or module

### Step 3: Identify signals used as clocks

### Step 4: Apply transformation pattern

### Step 5: Re-test in Verilator

Expected outcome:

* Improved determinism
* Increased instruction success rate

---

## 10. Important Notes

### Pulses in original hardware

Original system uses narrow pulses.

In FPGA these must become:

→ **single clock-cycle enables**

---

### Do NOT attempt

* Adding delays (# delays)
* Using LUT outputs as clocks
* Fixing via constraints
* Ignoring warnings

These do not solve the root problem.

---

## 11. Mental Model

### Original System

> "Events happen when signals transition"

### FPGA System

> "Events happen on clock edges, controlled by state"

---

## 12. End Goal

Transform the system into:

* Single clock domain
* Explicit event ordering
* Deterministic behavior

---

## 13. Summary

The issue is NOT logic correctness.

The issue is:

> Implicit timing assumptions based on physical delays

The solution is:

> Make timing explicit using clock + enable signals

---

## 14. One-Line Rule

> Treat all derived "clocks" as data, not clocks

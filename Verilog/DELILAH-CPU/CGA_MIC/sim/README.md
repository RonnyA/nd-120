# CGA_MIC Simulation & Testbenches

**Full path:** `E:\Dev\Repos\Ronny\nd-120\Verilog\DELILAH-CPU\CGA_MIC\sim\`

## Testbench convention

Testbenches are placed in a `sim/` subdirectory next to the module source
code. This is the standard practice across the project:

```
DELILAH-CPU/CGA_MIC/
  circuit/
    CGA_MIC.v               ← module source
    CGA_MIC_MASEL.v          ← submodule source
  sim/
    Makefile                 ← build targets for all tests
    test_mic.cpp             ← Verilator full-module testbench
    MASEL_cycle_tb.v         ← iverilog MASEL cycle/race testbench
    MASEL_iw_capture_tb.v    ← iverilog MASEL IW capture timing testbench
    mic.gtkw                 ← GTKWave config
```

## Running MASEL testbenches (iverilog)

```bash
cd /mnt/e/Dev/Repos/Ronny/nd-120/Verilog/DELILAH-CPU/CGA_MIC/sim

# Run both MASEL testbenches
make test-masel

# Run individually
make test-masel-cycle    # full-cycle test (14 tests: JMP/NEXT/RET/REPEAT + race conditions)
make test-masel-iw       # IW capture timing test (race + stability monitoring)
```

## Running full CGA_MIC test (Verilator)

```bash
make all    # compile + run + open GTKWave
make run    # compile + run (no GTKWave)
```

## MASEL testbench details

### MASEL_cycle_tb.v

Tests the full microcode address cycle including the IINC feedback loop
(NEXT = IW + 1). Validates:

- Sequential NEXT progression (IW increments correctly)
- JMP target capture (13-bit address from CSBIT fields)
- RETURN path (from stack)
- REPEAT path (IW feeds back to itself)
- SC5/SC6 race conditions (SC transitions at the same edge as MCLK)
- 1-sysclk active phase (FPGA-realistic tight timing)
- Active-phase stability (IW and W must not glitch while MCLK=1)

**Current baseline:** 11 PASS / 3 FAIL (race tests fail with original
`posedge s_mclk` in iverilog — expected because the testbench models the
FPGA race where SC and MCLK transition at the same sysclk edge).

### MASEL_iw_capture_tb.v

Focused test on the regIW capture timing. Includes a parallel
negedge-sysclk variant (V_NEG) for side-by-side comparison. Tests
capture correctness and stability of IW_12_0 / W_12_0 during held
MCLK phases.

## Viewing waveforms

Both testbenches generate VCD files:

```bash
gtkwave MASEL_cycle_tb.vcd &
gtkwave MASEL_iw_capture_tb.vcd &
```

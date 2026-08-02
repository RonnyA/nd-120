# HW timing model vs our Verilog - designer's notes

**Full path:** `Verilog/docs/hw-timing-vs-verilog.md`
**Source:** design intent per **Lasse Bockelie**, who designed the ND-110 and ND-120 CPUs.
**Last updated:** 2026-07-05

Keep this in the back of your mind for ALL signal / timing analysis on this project.

## What the designer said

- The microcode was written to run as many instructions as possible on the
  **SHORT cycle path** (cycle-control state `a` straight back to terminate `t`)
  for speed - see `DesignDocuments/Other/CPU-Timing.md` and `Verilog/cycle_clock.md`
  for the Gray-code cycle states and their lengths (a=51.2 ns ... p=435.2 ns).
- In the real machine, **not all microinstructions run at the same speed**. Chip
  and signal propagation delays stretch some cycles; **the UART path is especially
  slow**. The cycle-control FSM (`PAL_44601B`, "Terminate Bus Cycle" = TERM)
  lengthens the cycle (states d/e/f/g/h ... p) to wait for slow paths.
- The original hardware was **two ASICs plus TTL**:
  - **CGA** = the DELILAH CPU gate array (ALU, MIC, MAC, TRAP, INTR, WRF, ...).
  - **DGA** = the decode gate array.
  - Everything else was **TTL chips on the CPU board (3202D)**.
  Signals inside an ASIC are fast; signals crossing chip/ASIC/TTL boundaries and
  the board buses have real, non-uniform propagation delay.

## Why this matters for us

Our implementation is **fully behavioral Verilog**. In Verilator (and in the FPGA
after the latch->FF work) signals effectively settle within one `sysclk`/delta -
there is **no model of the per-chip / inter-ASIC / TTL propagation delays** the real
board had. So our *effective* timing and phase relationships between signals differ
from the real hardware, even when the logic (equations) is correct.

**Consequence for signal analysis:** a divergence between our sim/FPGA and the
"intended" behaviour can be a **timing-model artifact** (we behave differently
because we collapsed the real delays), NOT a logic bug. Before assuming a module is
functionally wrong, ask: *is this just because our Verilog has different signal
speeds than the ASIC+TTL original?*

**Consequence for the fix:** to make the Verilog behave correctly we may have to
**deliberately re-introduce / adjust signal speeds** - insert the right delays,
pipeline stages, or clock-enable phasing - so the model reproduces the real
inter-chip timing, rather than assuming zero-delay is correct. The "correct" phase
of a clock like ALUCLK (the terminate-latch of the ALU/condition-register) is
defined by the real HW timing after propagation, not by whatever our zero-delay
Verilog happens to produce.

## Concrete example (the clock-enable work)

The clock-enable refactor (`docs/clock-enable-refactor.md`) hit exactly this: naive
migrations of ALUCLK to sysclk shift the ALU/condition-register capture by one
sysclk and flip a microcode branch (STS test 7, o2133). The right target is not
"whatever the current FF sim does" but the **real terminate-relative phase**; the
phase-accurate enable has to place the capture on the correct edge, which is a
timing-model decision, exactly as above.

## Rule of thumb

1. Logic equations: validate against the design docs / PALASM (e.g. the
   `PAL_44601B` cycle counter is verified correct - `PAL_44601B_analysis.md` +
   `PAL_44601B_tb.v`).
2. Timing/phase: expect our zero-delay Verilog to differ from the ASIC+TTL HW;
   treat phase mismatches as things we may need to MODEL (add delay/phasing), not
   as proof of a logic bug.
3. The slow paths (UART, LCS/RWCS, slow I/O = cycle states g/h..p) are where the
   real machine spent extra cycles - watch those when our timing diverges.

## References
- `DesignDocuments/Other/CPU-Timing.md` - cycle-state timings (51.2 ... 435.2 ns).
- `Verilog/cycle_clock.md` - cycle-control state diagram.
- `Verilog/SignalReport.md` - descriptive signal dictionary (drivers/consumers).
- `Verilog/docs/clock-enable-refactor.md` - the ALUCLK/terminate-phase work.
- `Verilog/docs/fpga-debug-methodology.md` - three-worlds sim/FPGA model.

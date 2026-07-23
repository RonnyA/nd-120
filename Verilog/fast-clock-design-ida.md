# Fast-Clock Design Idea

## Full path
`E:\Dev\Repos\Ronny\nd-120\Verilog\fast-clock-design-ida.md`

## Problem this is trying to solve

The ND-120 design uses several 74xx-style transparent latches in the
microcode and ALU paths:

| Latch | File | ENABLE source |
|---|---|---|
| `CSEL_LATCH` | `LATCH.v` (in `CGA_MIC_CSEL.v`) | `s_aluclk_n` |
| `CHIP_25F`  | `AM29841.v` (in `CPU_PROC_32.v`) | `s_mclk` |
| `CHIP_30H/31F/32G/31G` | `CPU_CS_ACAL_17.v` (inlined) | `s_maclk`, `s_clk` |

In the original hardware these are *transparent latches*: while ENABLE=1,
Q follows D combinationally with only chip propagation delay. The signals
that drive ENABLE (`MCLK`, `MACLK`, `ALUCLK`) come from `CYC_36.v` and are
themselves combinational outputs of FFs, so they rise at the same instant
the data they gate (e.g., CSA, PCOND, CSCA) starts to settle.

On FPGA, when CPU clock = sysclk, the fundamental race is:

1. CPU FFs flip on `posedge sysclk` at edge N.
2. ENABLE (`MCLK`/`MACLK`/etc.) rises *combinationally* a few hundred ps
   after edge N — this is **after setup time has closed for edge N**.
3. Any FF clocked by the same sysclk samples ENABLE as 0 at edge N.
4. By edge N+1, ENABLE may have already fallen back to 0 (1-sysclk pulse)
   *and* the data D has advanced to the next step's value.
5. The FPGA latch never captures the right (D, ENABLE) pair.

This is the underlying reason `LUA=o05140` at `CSA=o002335`, why the
edge-detect rewrite of `LATCH.v` broke LCS loading at `CSA=o000231`, and
why the FF+CE pattern in ACAL only worked sporadically.

## Proposed solution

Run the CPU's *clock-derived* signals (MCLK, MACLK, ALUCLK, TERM_n, ...)
on a **slower base clock** than the clock that samples the latches.

Two equivalent ways to do this:

### Option A — fast sysclk for latches, slow CPU clock from same MMCM

```
                +----------------+
                |     MMCM       |
  100 MHz in -->|                |
                |  CLKOUT0 (200) |---BUFG---> fast_sysclk (latch sampling)
                |  CLKOUT1 (25)  |---BUFG---> cpu_clk     (CPU FFs, CYC_36)
                +----------------+
```

* `cpu_clk` drives every FF in the CPU (including TERM_n, MCLK_N, MACLK_N).
* `fast_sysclk` drives only the latch sample registers (LATCH.v,
  AM29841.v, ACAL_17.v).
* Frequency ratio (200:25 = 8:1) means a 1-`cpu_clk` MCLK pulse becomes
  8 `fast_sysclk` cycles wide. The latch sees ENABLE=1 stable on its
  sampling clock for 7-8 cycles → easy to capture cleanly.
* Both clocks come from the same MMCM → synchronous (related), no
  metastability.

### Option B — keep sysclk = fast clock, divide it to make CPU clock

```
                +----------------+
                |     MMCM       |
  100 MHz in -->|                |
                |  CLKOUT0 (100) |---BUFG-----> sysclk (latches)
                |  CLKOUT1 (12.5)|---BUFGMUX-+
                +----------------+           |
                                             +---> cpu_clk (selectable)
                                             |
                          (the existing      |
                           BUFGMUX in        |
                           ND120_TOP)        |
```

This is the smaller change because the existing Basys3 build already
has an MMCM with CLKOUT0=100MHz / CLKOUT1=12.5MHz and a BUFGMUX selector
on a switch (per `basys3-fpga` skill). What changes:

* The CPU and CYC_36 are clocked by the BUFGMUX output (`cpu_clk`).
* The latches stay clocked by the always-on 100 MHz `sysclk` (BUFG of
  CLKOUT0).
* No new MMCM outputs, no new BUFG instances, no new ports threaded
  through the hierarchy beyond what already exists.

**Option B is the recommended starting point** because it touches less
plumbing.

## What changes in the Verilog

Minimum-impact version (Option B):

1. `ND120_TOP.v`:
   * Output the BUFGMUX-selected clock as `cpu_clk` (currently called
     `sysclk` in the rest of the hierarchy).
   * Keep the always-on 100 MHz BUFG output as `latch_sysclk`.
   * Pass both into `ND3202D`.
2. `ND3202D` and `CPU_15` get a new `latch_sysclk` port and forward it
   *only* to the modules that contain latches.
3. `LATCH.v`, `AM29841.v`, `CPU_CS_ACAL_17.v` use `latch_sysclk` (not
   `sysclk`/`cpu_clk`) as their sampling edge clock.
4. Everything else continues to be clocked by `cpu_clk` (renamed
   `sysclk` if we want to keep the existing port names — purely
   cosmetic).

## XDC / timing constraint changes

* Both clocks are derived from the same MMCM, so Vivado already knows
  they are *related*.
* Add a **`set_clock_groups -asynchronous`** between `latch_sysclk` and
  `cpu_clk` ONLY if you want to skip cross-clock STA. Better: leave them
  *related* and let Vivado prove the cross-clock paths meet timing.
* Latch outputs (sampled on `latch_sysclk`) feed back into CPU FFs
  (clocked on `cpu_clk`). At 100 MHz / 12.5 MHz this gives the slow side
  ~80 ns of margin to read a value that updates on the fast side every
  10 ns. Vivado STA will report this as a normal multi-cycle path or
  pass it cleanly.

## Pros

* **Recreates the original chip semantics**: the fast sample clock makes
  the FPGA latch sampling fine-grained enough to look like the original
  74xx propagation delay.
* **Generic** — same fix works for CSEL_LATCH, CHIP_25F, *and* the four
  ACAL latches. One mechanism replaces three different ad hoc workarounds.
* **No Verilog ifdefs** — same code path runs in Verilator and on FPGA.
* **No latch inference** — every storage element is a clean
  `posedge sample_clk` FF, fully analyzable by STA.

## Cons

* **CDC discipline required.** Even with related clocks, fast→slow paths
  have to meet setup; slow→fast paths have to be guaranteed stable.
* **Not free in resources**: one extra BUFG (Option A) or rewiring of an
  existing one (Option B). Both fit easily on a 7-series (16 BUFGs
  available; this design uses ~3).
* **CYC_36.v glitch model unchanged**: MCLK/MACLK are still 1-`cpu_clk`
  pulses. The fast clock just gives the latches enough time to *see*
  them. If the design ever depends on what happens *between* CPU edges
  (e.g., a glitch on a combinational signal), the fast clock will sample
  it too — for better or worse.

## Portability across different FPGAs

The mechanism described above relies on three things, each of which has
near-equivalents on every modern FPGA family:

| Mechanism | Xilinx 7-series (Basys3) | Xilinx UltraScale/+ | Lattice ECP5 | Intel/Altera Cyclone V | Gowin GW1N |
|---|---|---|---|---|---|
| Multi-output PLL/MMCM | `MMCME2_BASE` | `MMCME4`/`PLLE4` | `EHXPLLL` | `ALTPLL` / `IOPLL` | `rPLL` |
| Global clock buffer | `BUFG` | `BUFG_GT`, `BUFGCE`, `BUFGCTRL` | `DCCA` | `clkctrl` | `BUFG`/`BUFG_GT` |
| Clock mux | `BUFGMUX_CTRL` | `BUFGCTRL` | `DCS` | `clkctrl` (multi-input) | `BUFGCE`/`DQCE` |

What this means in practice:

* **The Verilog is portable as-is.** `posedge sample_clk` and
  `posedge cpu_clk` are vendor-neutral primitives.
* **The MMCM/PLL instantiation is vendor-specific.** Today the
  ND120_TOP wraps `MMCME2_BASE` directly, which is Xilinx 7-series only.
  To port, this would have to move into a small wrapper module
  (`pll_wrapper.v`) with `ifdef`s or per-target files (`pll_xilinx7.v`,
  `pll_lattice_ecp5.v`, etc.). That isolation is the *only* portability
  cost of this design.
* **The BUFG clock-buffer instances are vendor-specific.** Same
  treatment: a wrapper module (`clock_buffer.v`) per target. On most
  vendors the synthesizer infers a global buffer automatically when it
  sees a signal driving many FFs, so the explicit `BUFG` instance can
  often be deleted entirely on non-Xilinx targets.
* **Constraint files are vendor-specific.** XDC for Xilinx, LPF for
  Lattice, SDC/QSF for Intel, CST for Gowin. Each vendor wants
  declared input clocks and (if required) clock-group statements. The
  *content* — declare the two MMCM outputs as related, ensure
  cross-clock paths are analyzed — is the same idea expressed in
  different syntax.
* **Cross-clock sampling discipline is universal.** Every vendor's STA
  will check setup/hold across clock domains the same way, provided
  both clocks are declared and related to the same source.

### Sketch of a portable wrapper

```verilog
// clock_gen.v — single file the user picks per target
module clock_gen (
    input  wire clk_in,
    output wire latch_sysclk,   // fast, always 100 MHz
    output wire cpu_clk,        // selectable: 100 MHz or 12.5 MHz
    input  wire sel_slow,
    output wire locked
);

`ifdef TARGET_XILINX7
    // Instantiate MMCME2_BASE + BUFGs + BUFGMUX_CTRL here
`elsif TARGET_LATTICE_ECP5
    // Instantiate EHXPLLL + DCCAs + DCS here
`elsif TARGET_INTEL_CYCLONE5
    // Instantiate altpll + clkctrls here
`elsif TARGET_GOWIN_GW1N
    // Instantiate rPLL + BUFG/DQCE here
`else
    `error "Define a TARGET_* macro for clock_gen.v"
`endif
endmodule
```

Everything *outside* `clock_gen.v` is portable Verilog. The CPU,
microcode, ACAL, latches all use `latch_sysclk` and `cpu_clk` as plain
inputs and don't care which family produced them.

## Decision needed before implementing

1. Option A (200 MHz fast / 25 MHz slow, new MMCM output) or
   Option B (reuse existing 100 MHz CLKOUT0 as latch clock, drive CPU
   from CLKOUT1=12.5 MHz via existing BUFGMUX)?
2. Should the CPU clock remain switchable on a Basys3 slide switch, or
   become a fixed slow clock once we trust the design?
3. Same physical port name (`sysclk`) used for *both* clocks today —
   pick clean names: `latch_sysclk` and `cpu_clk` (or `slow_clk`).

## Status

**Idea only — no code changes made.** This file is the baseline for the
discussion. Validate the simple `LATCH.v` level-sensitive fix first,
confirm whether ACAL/CHIP_25F still need help, then revisit this design.

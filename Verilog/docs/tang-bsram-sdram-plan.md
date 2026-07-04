# Tang Nano 20K: BSRAM Rearrange + SDRAM Implementation Plan

**Full path:** `/mnt/e/Dev/Repos/Ronny/nd-120/Verilog/docs/tang-bsram-sdram-plan.md`
**Last updated:** 2026-07-04

## Context

A real Gowin synth (`yosys synth_gowin`, GW2AR-18) showed the ND-120 **fits LUTs
easily (~8-10k of 20,736)** but **overflows BSRAM: 89 blocks vs 46 available**
(see `tang-nano-20k-port.md` 3b). The overflow is three memories that should not
all be BSRAM on the Tang:

1. the microcode **PROM** (~30-32 blocks) - a boot-only copy, redundant once the
   WCS is preloaded. **Removable.**
2. **main memory** in BSRAM (~11 blocks) - belongs in the 8 MB SDRAM. **Movable.**
3. the **WCS** (~29-32 blocks) - the *dominant, fixed* consumer (8192 x 64 =
   512 Kbit). Cannot shrink; one `reg[63:0]` array packs to about the same block
   count as the 32 `IDT6168A` chips, so a WCS rewrite is a **preload
   simplification, not a block saver**.

This plan drives BSRAM under 46 by **removing the PROM and moving main RAM to
SDRAM**. Target end state: BSRAM ~= WCS (~30) + control-store cache + small ~=
**~35-46 blocks - a tight fit** (the WCS floor leaves little headroom, so all
other arrays must map to logic). LUTs unchanged (fit easily).

## Build defines (all under the `TARGET_TANG20K` board target)

| Define | Effect | Status |
|--------|--------|--------|
| `SKIP_WCS_LOAD` | Preload WCS, skip runtime load phase | **done** (`skip-wcs-load.md`) |
| `GOWIN` | Drop the PROM BRAM (`CPU_CS_PROM_19` empty branch) | exists (branch is a stub) |
| `WCS_SINGLE_ARRAY` | One `reg[63:0] wcs[0:8191]` instead of 32 `IDT6168A` | **new** |
| `MAIN_RAM_SDRAM` | SDRAM backend for `MEM_RAM_49` | **new** |

Keep every default (no define) = current faithful behavior, so Verilator latch/FF
sim and the Basys3 build are unaffected.

---

## Phase B1 - Drop the microcode PROM BRAM  (~30 blocks freed)

The PROM (`CPU-BOARD-3202/circuit/CPU_CS_PROM_19.v`) is only read during the load
phase. With `SKIP_WCS_LOAD` the load never runs, so the PROM is dead. Its `ifdef
GOWIN` branch already returns `regData <= 0` (no `$readmemh`, no BRAM).

- **Action:** ensure `TARGET_TANG20K` defines `GOWIN` so `rom_lo`/`rom_hi` are not
  instantiated. Verify in synth that no BSRAM comes from `CPU_CS_PROM_19`.
- **Risk:** none functionally (PROM unused when WCS is preloaded). Confirm the
  boot still reaches OPCOM in Verilator with `SKIP_WCS_LOAD` + `GOWIN`.

## Phase B2 - WCS single-array restructure  (preload simplification, ~0 blocks)

Note: this does **not** materially reduce BSRAM (the WCS is ~30 blocks either
way). Its value is a **much simpler preload** (one `wcs_image.hex` instead of 32
nibble files) and cleaner RTL for the Tang. Optional for the fit; do it because it
makes `SKIP_WCS_LOAD` on Gowin far simpler. Replace the 32 `IDT6168A_20`
instances in
`CPU-BOARD-3202/circuit/CPU_CS_WCS_21_22.v` with one inferred synchronous BRAM,
behind `WCS_SINGLE_ARRAY`:

```verilog
`ifdef WCS_SINGLE_ARRAY
  (* ram_style="block", syn_ramstyle="block_ram" *)
  reg [63:0] wcs [0:8191];
  `ifdef SKIP_WCS_LOAD
    initial $readmemh("wcs_image.hex", wcs);   // unified image - ONE file
  `endif
  reg [63:0] rdata;
  wire [12:0] a_rd = ...;   // full 13-bit addr from LUA/UUA + bank select
  always @(posedge sysclk) begin              // write-first, 1-cycle read latency
    if (<write enable>) wcs[a_wr] <= <byte-masked CSBITS_63_0>;
    rdata <= wcs[a_rd];
  end
  assign CSBITS_63_0_OUT = <output-enable> ? rdata : 64'b0;
`else
  ... existing 32 IDT6168A instances ...
`endif
```

Critical correctness points (must be preserved exactly):

- **1-cycle registered read latency** - load-bearing (a combinational read breaks
  the TVEC dispatch loop; see `IDT6168A_20.v` header).
- **Two-bank addressing** - today lower bank uses `ELOW_n` + `LUA_11_0`, upper uses
  `EUPP_n` + `UUA_11_0` (`CPU_CS_16.v:130-146`). The single array is indexed by the
  full 13-bit address; reproduce the exact bank/address selection for both read and
  write.
- **Per-16-bit write masking** - `WW3..0`/`WU3..0` write the four 16-bit lanes.
- **Preload uses the unified `wcs_image.hex`** (already emitted by
  `Code/Microcode/gen_wcs_image.py`) - so `WCS_SINGLE_ARRAY` also **simplifies the
  preload from 32 nibble files to one 64-bit image**.

- **Verify:** in Verilator, diff the `MA @ posedge MACLK` boot path of the
  single-array WCS against the 32-chip WCS - must be byte-identical
  (`boot-golden-spec.md`). This is the acceptance test for B2.

## Phase B3 - Main memory to SDRAM  (the feature)

Move `MEM_RAM_49` main memory off BSRAM onto the Tang's 8 MB SDRAM, behind
`MAIN_RAM_SDRAM`.

1. **Controller:** vendor in the nand2mario controller
   (https://github.com/nand2mario/sdram-tang-nano-20k) under
   `fpga/tang-nano-20k/` (or `Shared/`). It exposes a simple
   read/write + refresh interface and needs its own (phase-shifted) SDRAM clock.
2. **Clocking:** add a Gowin `rPLL` in the Tang top - 27 MHz in -> CPU clock +
   SDRAM clock (nand2mario runs the chip ~84 MHz with a phase-shifted output
   clock). The CPU can stay slow; SDRAM clock is separate.
3. **Adapter** (`MEM_RAM_49.v` new backend): bridge the ND-120 memory interface
   (`AA_9_0`, `BANK0/1/2`, `RAS`, `CAS`, `MWRITE50_n`, data `DD_17_0` in/out) to
   the controller's `addr/din/dout/rd/wr/ready`. Map the ND word (16 data + parity)
   into SDRAM words; use `BANK*` + `AA_9_0` as the SDRAM address.
4. **Wait states (the hard part):** SDRAM read/write is multi-cycle; the ND-120
   memory cycle must **stall until the access completes**. Investigate how the
   cycle controller (`CYC_36.v`) and memory-access controller (`CGA_MAC`) time a
   memory access, and gate cycle advance on the controller's `ready`/`valid`. If
   the ND-120 cycle FSM has no wait-state hook, add one (a memory-not-ready ->
   hold signal). This is the main design risk; scope it first.

- **Verify:** a Verilator SDRAM model (or the controller's own model) so the full
  boot + a memory-exercising program (`1<100` dump) runs against SDRAM in sim,
  matching the BSRAM main-RAM behavior, before hardware.

## Phase B4 - Fit + boot verification

- Re-run `yosys synth_gowin` (oss-cad-suite) with `TARGET_TANG20K` (all four
  defines) -> confirm **BSRAM < 46 blocks** and LUTs still fit. Method: the fit
  flow in `../scratch` (stub Xilinx clock prims, `setattr -unset ram_style m:*`
  between `begin:coarse` and `map_ram:`).
- Get the **placed** number via Gowin EDA synth (authoritative) or fix the
  `.cst`/apicula pin format for nextpnr.
- Verilator: `SKIP_WCS_LOAD`+`GOWIN`+`WCS_SINGLE_ARRAY` boots identical to golden;
  `MAIN_RAM_SDRAM` boots against the SDRAM sim model.
- Then G1 hardware bring-up (Tang top + rPLL + `.cst`) per `tang-nano-20k-port.md`.

## Sequencing / risk

1. **B1 first** (drop PROM) - trivial, sim-verifiable, frees ~30 blocks
   (89 -> ~57). Still over 46 on its own.
2. **B3 (main RAM -> SDRAM)** is required for the fit, not optional - it removes
   the ~11 main-RAM blocks (~57 -> ~46). Both B1 and B3 are needed to fit; the
   WCS floor (~30) means there is no slack. **Re-measure BSRAM after B1 and after
   B3** (the fit flow in `../scratch`) - if still over 46, the control-store cache
   / any stray array must be forced to logic, or the microcode word trimmed.
3. **B2 (WCS single-array)** any time - it does not change the block count, just
   simplifies the preload. Nice-to-have alongside B1.
4. B3 is the bigger, hardware-coupled task (rPLL + wait-state work + a real board
   to validate) and also unlocks *full* main memory (parity with the sim's large
   RAM). Scope the `CYC_36`/`CGA_MAC` wait-state hook first - it is the main risk.

## Files touched

- `CPU-BOARD-3202/circuit/CPU_CS_PROM_19.v` - confirm GOWIN drops the BRAM (B1).
- `CPU-BOARD-3202/circuit/CPU_CS_WCS_21_22.v` - `WCS_SINGLE_ARRAY` path (B2).
- `CPU-BOARD-3202/circuit/MEM_RAM_49.v` - `MAIN_RAM_SDRAM` backend (B3).
- `ND120_TOP.v` - Tang branch: `rPLL` clocks, SDRAM ports (B3), board target.
- `CYC_36.v` / `CGA_MAC` - memory wait-state hook (B3, investigate first).
- `fpga/tang-nano-20k/` - SDRAM controller, `rPLL`, updated `.cst`, build script.
- `Code/Microcode/gen_wcs_image.py` - already emits `wcs_image.hex` (B2 preload).

## References
- `tang-nano-20k-port.md` (3b fit result), `skip-wcs-load.md`, `build-defines.md`.
- nand2mario SDRAM: https://github.com/nand2mario/sdram-tang-nano-20k

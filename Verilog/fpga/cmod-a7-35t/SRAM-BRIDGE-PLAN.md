# TODO: pack16 SRAM bridge for the Cmod A7 (512 KB main memory at 27-33 MHz)

**Full path:** `Verilog/fpga/cmod-a7-35t/SRAM-BRIDGE-PLAN.md`
**Date:** 13-JUL-2026. Status: PLANNED, not started. The first-version Cmod
build (`build.tcl` in this directory) uses BRAM main memory; this plan
upgrades it to the on-board 512 KB SRAM = **256K ND words**, 4-8x the BRAM
ceiling.

## 0. Why pack16 is mandatory (validated 13-JUL-2026)

`Verilog/docs/basys3-memory-speed-validation.md`
section 4.3 invalidated the originally recorded plan (~4 byte-accesses per
18-bit word): the protocol budget is **3 OSC cycles from column-known
(N+1) to data-valid (start of N+4)**, no wait states possible, so a
4-beat-per-word scheme misses the deadline AT ANY FREQUENCY. The only
viable shape is **pack16**: store the 16 DATA bits as 2 bytes, drop the 2
parity bits, regenerate parity on the read path (odd parity, AM29833A
convention) - the exact contract already proven on the Tang
(`ND_SDRAM_PACK16`, semantics pinned by
`Verilog/docs/nd120-parity-analysis.md`:
the self-test never reads stored parity; runtime uses only the PES/PEA/IIC
error machinery).

Validated envelope: **comfortable at <= 33 MHz OSC, zero-slack at 40 MHz**
on the Cmod's dedicated short traces. At the build's 27 MHz
(37.04 ns/cycle, budget 111 ns) there is real margin.

## 1. Hardware facts

- SRAM: ISSI **IS61WV5128BLL-10BLI** - 512K x 8, async, **tAA 10 ns**
  (datasheet <https://www.issi.com/WW/pdf/61-64WV5128Axx-Bxx.pdf>; the
  "8 ns" sometimes quoted is the faster bin - use 10 ns for margin math).
- Dedicated FPGA pins (NOT the Pmod, NOT the DIP pins - no conflict with
  anything): 19 address `MemAdr[18:0]`, 8 data `MemDB[7:0]`, and control
  (`RamOEn`, `RamWEn`, `RamCEn`) - all in `Cmod-A7-Master.xdc` in this
  directory (Sch=sram-a[*]/sram-dq[*]). Single 3.3 V rail, no level issues.
- Capacity as pack16 main memory: 512 KB / 2 bytes per word = **262,144 ND
  words** = one quarter of an ND bank plus... = 256K words. Boot-time
  memory sizing detects it (partial-memory machines were normal;
  row-granular presence like `CPU_PART_ROWS` on the Tang bridge).

## 2. Bridge design (MEM_RAM_49_SRAM.v, sheet-49 backend)

New file `Verilog/fpga/cmod-a7-35t/MEM_RAM_49_SRAM.v`
implementing the sheet-49 contract (same interface as
`MEM_RAM_49_BLOCKRAM` / `MEM_RAM_49_SDRAM`; the contract table is in
`Verilog/docs/nd120-dram-memory.md` section 1),
selected in `MEM_43.v` by a new define **`MAIN_RAM_SRAM`** in the existing
backend chain (`MAIN_RAM_SDRAM` / `MAIN_RAM_BLOCKRAM` / `VERILATOR_SIM` /
default - add the new arm, everything else untouched).

Single clock domain: the bridge runs on OSC (= clk_cpu = sysclk on FPGA,
one domain in FF mode) - **no CDC, no second PLL output needed** at
27-33 MHz. (Only a 40 MHz attempt would want a 2x clock to create
mid-cycle address-change points; out of scope here.)

Cycle-by-cycle at 27 MHz (37 ns/cycle; SRAM round trip per byte:
Tco+OBUF ~5 + trace <1 + tAA 10 + IBUF+setup ~5 = ~21 ns - fits ONE cycle
with 16 ns slack):

```
READ (MWRITE50_n=1):
  N   : RAS rise seen - capture row (AA_9_0), bank/partition presence
  N+1 : column on AA - drive MemAdr = {row, col[9:1], 1'b0} (byte 0 = low)
  N+2 : capture MemDB -> byte_lo; drive MemAdr byte 1 (addr | 1)
  N+3 : capture MemDB -> byte_hi; assemble
        DD_17_0_OUT <= {~^hi, hi, ~^lo, lo}  (parity regenerated)
        -> registered, driven from start of N+4 while CAS high. DEADLINE MET
          with one cycle of the >=2-cycle-per-byte margin unused at 27 MHz.
  CORR_n: computed word is always "correct" - same formula as the Tang
  bridge (CORR_n = (^dd[8:0]) & (^dd[17:9]) evaluates to 1).

WRITE (MWRITE50_n=0):
  DD_17_0_IN valid at N+2 (use the OR-accumulation capture only if the
  Cmod shows the same sub-cycle drive pulse as the Tang did - START simple:
  direct registered capture at N+2/N+3, escalate to OR-accumulation only
  on evidence).
  N+3 : write byte 0 (MemDB driven, RamWEn low one cycle, address settled
        at N+2) - async SRAM tSA/tPWE at 10 ns grade fit a 37 ns cycle
  N+4 : write byte 1
  Budget: RAS-to-RAS floor is 11 cycles - both byte writes finish by N+5,
  6 cycles of slack. Writes are never the constraint.
  IMPORTANT: MemDB is a bidirectional bus - drive it ONLY during write
  strobes (the clean top-level ternary 1'bz idiom, exactly like
  sdram18.v's SDRAM_DQ - Vivado infers IOBUFs; keep the tristate at the
  TOP-LEVEL assign, never nested in an inner ternary).
```

Partition/presence: parameter like the Tang's `CPU_PART_ROWS` - the SRAM
holds 256K words = ND rows 0..255 of BANK0 ({bank,row} < 256); rows above
report absent (read 0, writes dropped), boot sizing shrinks accordingly.

## 3. What must be written (work list)

1. `MEM_RAM_49_SRAM.v` - the bridge above (~150-250 lines; the Tang
   `MEM_RAM_49_SDRAM.v` is the structural template, minus controller/CDC).
2. `MEM_43.v` - one new `elsif MAIN_RAM_SRAM` arm + the MemAdr/MemDB/
   control ports threaded up through `ND3202D.v` -> `ND120_TOP.v` (under
   `ifdef MAIN_RAM_SRAM`, mirroring how the SDRAM pins were threaded for
   the Tang - see that diff for the pattern).
3. `nd120_cmod_top.v` + `nd120_cmod.xdc` - add the 30 SRAM pins from
   `Cmod-A7-Master.xdc` (uncomment/rename), pass through the wrapper.
4. **Testbench BEFORE hardware** (registered in
   `Verilog/tests/run_all_tests.sh`,
   `TB_RESULT: PASS`): protocol-replay tb mirroring
   `Verilog/fpga/tang-nano-20k/sdram-bridge/sim/mem_ram_49_sdram_tb.v`
   (measured 6-cycle access signature, late-N+4/N+5 sampling, adjacent-word
   independence, bad-parity absorption, partition boundary, 2000-access
   soak) plus a behavioral IS61WV model with real tAA delay so the
   one-byte-per-cycle assumption is actually exercised.
5. Vivado build variant: `build.tcl -tclargs -sram` (or a second tcl) with
   `MAIN_RAM_SRAM`; keep the BRAM build as the fallback.
6. Timing: the WNS gate in build.tcl already fails loudly; the SRAM pins
   need `set_output_delay`/`set_input_delay` constraints against sys_clk
   derived from the ~21 ns round-trip budget (write them from the
   datasheet numbers, don't skip - unconstrained I/O timing is how silent
   corruption ships).

## 4. Acceptance

- Protocol tb PASS (incl. the SRAM-latency model), registered in the suite.
- Vivado timing met at 27 MHz with the I/O delays constrained.
- On hardware: boot banner + self-test unchanged, OPCOM deposit/examine
  round-trip across the 256K-word range, boot sizing reports the partial
  bank, and the runSim-golden console behavior unchanged on the
  Verilator side (the define is FPGA-only, Verilator never sets it).

Estimated effort: **2-4 days** (bridge + tb are the bulk; the plumbing
through ND3202D/ND120_TOP is mechanical but wide).

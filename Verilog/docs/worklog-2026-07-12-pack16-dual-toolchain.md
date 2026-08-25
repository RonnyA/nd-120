# Worklog 11/12-JUL-2026: packed 16-bit SDRAM memory + dual-toolchain Tang builds

**Full path:** `Verilog/docs/worklog-2026-07-12-pack16-dual-toolchain.md`
**Branch:** `clock-enable-fix`. Commits (oldest first): `d26fd66`, `879410a`,
`b79b96d`, `2c44efb`, `5d58328`. All pushed.

Two work packages, executed back to back: (1) the parity/pack16 memory
refactor from the work order `nd120-parity-refactor-order.md`, and (2) the
owner's follow-on directive to support BOTH FPGA toolchains for every Tang
Nano 20K build variant, OSS primary / Gowin EDA backup.

---

## Package 1: store 16 bits, not 18 - parity is computed (d26fd66..2c44efb)

### The investigation that unlocked it

The blocker was folklore: "the self-test writes bad parity and reads it
back, so parity must be stored." Microcode analysis
(`docs/nd120-parity-analysis.md`, EPROM-validated sources) proved:

- **The CPU self-test never touches memory parity.** All 8 subtests
  (o2053-o2156) are CPU-core-only (ALU, shifts, register file, STS, LC,
  SWAP, PIC/PID). The `IDBS,PEA` at o2123 is a don't-care select in a
  loop-control word (`ALUD,NONE` + `LCOUNT`, comment "LOOP BACK").
- **STERR is at o2156** (not o1134 as older notes said - that is FWLO3),
  and it is a display/halt routine, not a counter: a failing subtest parks
  showing its R2 error code.
- Runtime software consumes parity ONLY through the error machinery
  (`TRA PES` o3673, `TRA PEA` o3675, IIC on level 14). Nothing reads
  stored parity bits as data.
- The "AM29833A is a stub" claim in TODO.md was stale - real parity logic
  has been in `Shared/support/AM29833A.v` since MAR-2025. Corollary: the
  7/14 self-test failures CANNOT be parity-related; real suspects remain
  the microcode-fidelity items (JMP0-3, IDB OR-merge).

### The refactor (`ND_SDRAM_PACK16`, on by default for Tang)

- `sdram18.v`: 22-bit half-word address, TWO ND words per 32-bit SDRAM
  location, **DQM lane-masked 16-bit writes** - single access, no
  read-modify-write, measured N+4/N+11 protocol untouched. DQM restored
  after the write burst (read DQM latency = 2 cycles; a stale mask would
  blank the next read on silicon - invisible to the sim model).
- `MEM_RAM_49_SDRAM.v`: BANK0+BANK1 fold into the LOWER half of the chip
  (CPU keeps its full 4 MB, boot sizing unchanged; the address MSB is
  hardwired 0 so the CPU physically cannot reach the upper half). Parity
  regenerated as odd parity on read; CORR_n always "correct". The
  CPU/storage split is a parameter (`CPU_PART_ROWS`, ND-row granularity,
  default 2048 = 4 MB) per the work order's forward-looking requirement.
- **The upper 4 MB is now free for the nd_storage disk-image cache**
  (`nd-storage-design.md` section 5.2: device port addresses locations
  `{1'b1, mem_addr[19:0]}`). Nobody lost memory - the 14 wasted bits per
  location paid for the whole storage region.
- Two real bugs found by the new tbs and fixed in the bridge:
  1. refresh starvation on runs of absent-row accesses (B_TAIL now hosts
     a refresh slot; the partition tb caught a 20 us gap),
  2. the stale-DQM read-blank hazard above.
- `MEM_RAM_49_SIM.v` (b79b96d): runSim models the packed contract by
  default (`PACK16 ?= 1`; parity recomputed at the OUTPUT stage - placing
  it at capture made Verilator dead-code the preload arrays and broke
  Run120.cpp's hooks).

### Validation

- Bridge tbs, one source, three registered targets: legacy 18-bit
  (bit-identical, stored-bad-parity round-trip preserved), `test-pack16`
  (adjacent-word independence, lane masking, bad-parity absorption),
  `test-pack16-part` (partition boundary + absent-row semantics).
- Tang full-boot vtest PASS with packing on (OPCOM deposit 22/054321
  readback through the packed path).
- runSim FF-mode golden console BYTE-IDENTICAL with the packed contract on.
- Define scope proven Tang-only by grep; non-Tang builds untouched.

Handoff note for the FPGA session: `docs/nd120-pack16-defines-note.md`.

---

## Package 2: dual-toolchain Tang builds (5d58328)

Owner directive: support both toolsets for all Tang 20K build variants,
well documented, make + ps1 for every combination, OSS primary / Gowin
backup. Full reference: `docs/tang20k-build-flows.md` (the matrix doc).

### What landed

From `fpga/tang-nano-20k/`:

- `make [VARIANT=slow|crawl|full]` - full-CPU bitstream via yosys +
  nextpnr-himbaechel + gowin_pack -> `build/nd120_tang20k_oss-<variant>.fs`
- `make check` - netlist gates: `IO_sdram_dq` must stay a `$tribuf`-driven
  inout (the yosys silent-collapse class that burned the SD DAT pads), and
  zero inferred latches in FPGA_FF_MODE.
- `make load` / `make flash` - openFPGALoader (SRAM / persistent).
- `make gowin [VARIANT=...]` / `.\gowin_build.ps1 -Variant slow|crawl|full`
  - the Gowin EDA backup, same variants (generated
  `build/tang20k_variant.v` added as first project file by the tcl).
- ONE source of truth: both flows compile the ordered `.gprj` file list
  with `src/tang20k_defines.v` first; variants are `TANG_VARIANT_*`
  pre-defines consumed by the defines file (verified: yosys keeps defines
  across a single read_verilog list, matching Gowin's compilation unit).

### Porting findings (all fixes `ifdef YOSYS`, other flows bit-identical)

1. `ram_style="block"` on an async-read memory is advisory to Vivado/Gowin
   but a hard ERROR to yosys: `Am9150` (MMU cache) and `CPU_PROC_32`
   `registerBlock` now select distributed LUT RAM under yosys.
2. GW2A FF power-up value must equal its async-set value
   (`SCAN_WITH_SET_N_EN` inits to 1 under yosys - which is what the
   silicon does through POR anyway).
3. The OSS synth runs `proc; attrmap -remove init` before `synth_gowin`,
   reproducing vendor/silicon behavior (POR logic is all-zeros init = the
   GW2A default, so nothing depends on FF inits).
4. nextpnr does not auto-connect the embedded SDRAM: the Makefile
   concatenates the package CST with `sdram-test/src/sdram_pins_oss.cst`.
5. WSL drvfs staleness can fail a build on a file that exists; re-run.

Regression: Tang full-boot vtest re-run PASS after the RTL accommodations.

### THE finding: full speed may already close

nextpnr Fmax, first OSS builds (all three variants built end-to-end):

| VARIANT | clk_cpu need | clk_cpu Fmax | clk2x need | clk2x Fmax |
|---|---|---|---|---|
| slow  | 6.75 MHz  | 47.98 MHz | 13.5 MHz | 161.76 MHz |
| crawl | 3.375 MHz | 48.99 MHz | 6.75 MHz | ~180 MHz |
| full  | 27 MHz    | **57.51 MHz** | 54 MHz | 180.86 MHz |

GowinSynthesis measured 9.38 MHz on the same RTL - the number that forced
the whole TANG_SLOW_BRINGUP strategy. The OSS netlist closes the FULL
27/54 MHz target with >2x margin. **If hardware confirms, `VARIANT=full`
becomes the default and the slow-bringup era ends.**

---

## Next steps (hardware, needs the board attached)

```bash
cd Verilog/fpga/tang-nano-20k
make load                                  # slow variant first (safe)
make VARIANT=full && make load VARIANT=full   # then the big one
```
Console 9600 8N1: boot banner, OPCOM prompt, deposit/examine round-trip
(`docs/boot-golden-spec.md`). Both bitstreams carry `ND_SDRAM_PACK16`, so
either run also validates the packed memory on silicon.

Open items elsewhere: the nd_storage device port rides on the freed upper
4 MB (storage workstream, in progress in this same working tree); the 7/14
self-test hunt now has parity eliminated and a per-subtest error-code map
in `nd120-parity-analysis.md` section 3.

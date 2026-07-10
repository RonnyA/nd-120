# ND-120 Verilog TODO

> Last updated: 11-JUL-2026

---

## SD-FAT stack (Milestone 1 of docs/sd-bpun-device-plan.md) - built incl. WRITES, sims pass, NOT yet on hardware

Reusable SD/FAT library in `SD-FAT/`: vendored WangXuan95 reader (marked
mods: runtime file name, dir-entry name/size/date/is-dir outputs,
first-sector output, split sdcmd tristate) + CLEAN-ROOM `sd_writer.v`
(CMD24, MIT, own unit tb `SD-FAT/sim :: test-writer`). Tang test project
`fpga/tang-nano-20k/sd-fat-test/`: UART menu (9600 8N1, `#` prompt):
1=LIST (size + DD-MMM-YYYY date + name, <DIR> entries), 2=DUMP BOOT.BPUN
(hex/octal, byte-verified), 3=COPY BOOT.BPUN over pre-created TEST.TXT
(in-place sector rewrite, Route B), 4=WRBLK1 (word[w]=w pattern into 1KW
block 1 = sectors first+4..7, range-guarded), H=help; persistent `SD:`
status; watchdogs everywhere. `make console` = interactive Verilator UART.
Verilator system test verifies dump bytes, list columns, copy content and
that WRBLK1 touched ONLY block 1. Bitstream builds (OSS flow).
Block map convention: 1KW block N of contiguous file = 4 SD sectors at
first_sector+4N (SD-FAT/README.md).

Next actions:
1. `make load` on the Tang, card from the README recipe -> acceptance
   A3-A6 + menu 3/4 on real silicon.
2. OWNER DECISION: GPL-3.0 vendored files in the MIT repo (before commit).
3. Milestone 2: ND_BUS_DEV_IF + TAPE_READER_400 against the Verilator bus
   ports, then `$` boot from card (plan sections 8 and 10); floppy device
   builds on the 1KW block map.

---

## QMTECH XC7A35T board (PARKED side experiment)

Stages 1-2 (LED smoke test + Basys3 mem-test port) written and sim-verified
under `fpga/qmtech-a35t/`; **nothing run on hardware yet**. Resume point with
exact next actions and stage-3 design notes (16-bit burst-of-2 SDRAM bridge):
`fpga/qmtech-a35t/HANDOFF-qmtech-a35t-bringup.md`.

---

## Tang Nano 20K bring-up

### Integrate the SDRAM controller as ND-120 main memory (Tang only)

The 8 MB embedded SDRAM is validated standalone
(`fpga/tang-nano-20k/sdram-test/` - passes on hardware, full-8MB write+verify).
Next: bridge the nand2mario controller behind the `MEM_RAM_49.v` interface
(`AA_9_0`, `BANK0-2`, `RAS`/`CAS`, `MWRITE50_n`, `DD_17_0`), gated behind a
Tang-only define (`TARGET_TANG20K` / `MAIN_RAM_SDRAM`) so Verilator and Basys3
builds are completely unaffected. 8 MB of RAM available is acceptable.

**Files**: `CPU-BOARD-3202/circuit/MEM_RAM_49.v`, `Shared/support/SIP1M9.v`,
new adapter module under `fpga/tang-nano-20k/`.

**Design analysis done** (8-JUL-2026): the full protocol measurement (25k
accesses traced), the per-board backend plan (replace the MEM_RAM_49 body per
target instead of more SIP1M9 ifdefs), the 2x-clock SDRAM bridge design with
timing budget, refresh strategy, and the 18-bit-in-32 word mapping (2 banks =
4 MB) are documented in `docs/nd120-dram-memory.md`.

**Bridge implemented and protocol-validated** (8-JUL-2026):
`fpga/tang-nano-20k/sdram-bridge/` - `MEM_RAM_49_SDRAM.v` + `sdram18.v`, with
a testbench that replays the measured protocol (2000-access soak, parity
round-trip, refresh cadence) - PASSES.

**Tang top-level built** (8-JUL-2026): `fpga/tang-nano-20k/` -
`src/ND120_TANG20K_TOP.v` + rPLL (27/54 MHz) + cst/sdc + `nd120_tang20k.gprj`
(247 files) + `gowin_build.tcl`/`.ps1` (gw_sh on the Windows host). SDRAM pins
threaded through `MEM_43`/`ND3202D` under `ifdef MAIN_RAM_SDRAM` (Verilator
regression-checked; full Tang file set elaborates under Verilator lint).
Remaining: run the first Gowin build (`.\gowin_build.ps1` on Windows), check
fit + timing, flash, compare boot against `docs/boot-golden-spec.md` on the
9600-baud console.

### CPU clock above 27 MHz (after 27 MHz validation)

The Tang's 27 MHz crystal is only the PLL reference - the `rPLL` can multiply
it. Plan: **validate everything at 27 MHz first**, then raise the CPU/SDRAM
clock via the rPLL. Data points: the vendored `gowin_rpll.v` has a ready-made
54 MHz setting (commented out), the nand2mario controller's timing parameters
are good to 66.7 MHz, and the factory LiteX SoC runs this SDRAM at 48 MHz
CL-2. So 27 -> 54 MHz is the natural step (keep `BOARD_CLK_FREQ` and all
UART/RTC counts derived from it, per the OPCOM speed fix).

---

## Future boards / peripherals (captured 8-JUL-2026)

### CMOD A7-35T target (Digilent)

> Board folder created 2026-07-08: `fpga/cmod-a7-35t/` (README + plan live
> there now; this entry is the origin note). **Downgraded to research-only
> the same day:** at ~1039 NOK it is too expensive and less functional than
> the Tang Nano 20K - no purchase planned.

Same `xc7a35t-1cpg236` die as Basys3 in a DIP module: 20,800 LUT, 225 KB
BRAM, **512 KB external SRAM (8-bit bus, 8 ns)**, 4 MB QSPI, USB-JTAG/UART,
2 LEDs + 1 RGB, 2 buttons, one Pmod + 44 DIP I/O. Backend plan: start with
`MAIN_RAM_BLOCKRAM` (raise `BANK_ADDR_BITS`; 225 KB BRAM minus WCS budget),
later a `MEM_RAM_49_SRAM` backend for the 512 KB external SRAM (8-bit bus ->
~4 byte-accesses per 18-bit word; needs its own protocol bridge like the
SDRAM one). Reference manual:
https://digilent.com/reference/programmable-logic/cmod-a7/reference-manual
Demo: https://github.com/Digilent/Cmod-A7-35T-OOB (QSPI flash mx25l3273f).

### SD-card block devices across all boards

Goal: floppy/HDD images from SD card (FAT filesystem) so the ND-120 can load
software on every target:
- **Basys3 + CMOD A7:** SD-card Pmod on the Pmod connector (same module,
  same SPI-mode controller on both).
- **Tang Nano 20K:** on-board microSD (TF) slot.
- **MiSTer:** different route - images served by the ARM/Linux side (see
  `fpga/mister/`).
Shared piece: one SPI SD + FAT reader core (or soft-CPU-less FAT16/32
reader) behind a common "block device" interface feeding the ND-120 I/O
(floppy controller emulation). Design doc needed before implementation.

---

## High Priority

> Items that may affect self-test failures (7/14 tests currently fail)

### CPU_15: IDB output assignment

Add assign of IDB out of `CPU_15` based on IDB out from PROC or CS. Also validate:

- `s_rt_n` -- also output from `CPU_PROC_32`. Verify which source to use (PROC or PCB top module).
- `s_rwcs_n` -- also output from `CPU_PROC_32`. Same question.

**File**: `CPU-BOARD-3202/circuit/CPU_15.v`

### CPU_15: MMU/LAPA/STOC validation

Previously marked as fixed but needs double-checking. IN/OUT signal assignments must be validated.

**File**: `CPU-BOARD-3202/circuit/CPU_15.v`

### AM29833A: Parity and error not implemented

Error flag and parity output are hardcoded:

```verilog
assign ERR_n = 1;    // Should detect parity errors
assign PAR_OUT = 0;  // Should compute parity
```

This affects parity error testing and may cause self-test failures.

**File**: `Shared/support/AM29833A.v`

---

## Medium Priority

### CPU_MMU_WCA_31: WCA_n polarity check

Should `WCA_n` be switched in this assignment?

```verilog
assign PPN_23_10 = WCA_n ? 14'b0 : CPN_23_10;
```

**File**: `CPU-BOARD-3202/circuit/CPU_MMU_WCA_31.v`

### 3-state outputs: Verify all return 0 not z

For FPGA, tri-state (`z`) doesn't work internally. Check that all "3-state" buffers output `0` when disabled, not `z`.

**Relevant modules**: `TTL_74245`, `TTL_74244`, `TTL_74241`, `AM29841`, `AM29861A`

### Search for `TODO:` in code

Periodic cleanup -- grep for `TODO:` comments and address remaining items.

---

## Low Priority

### CGA/MAC and CGA_MAC_FASTADD: Unit tests

No dedicated unit tests. CPU self-test exercises these through the ALU path. Lower priority unless specific MAC bugs found.

### Tang Nano: SPI flash for microcode ROM

Gowin project has `` `ifdef GOWIN `` placeholder in `CPU_CS_PROM_19.v` but no SPI flash implementation yet. Needed for Tang Nano deployment.

**File**: `CPU-BOARD-3202/circuit/CPU_CS_PROM_19.v`

### MEM_ADDR_44: Add test code

No dedicated test. Works in full sim.

**File**: `CPU-BOARD-3202/circuit/MEM_ADDR_44.v`

### MEM_RAM_49: Refactor DD_17_0 signals for hardware

RAM works in simulation. For real FPGA hardware, the `DD_17_0` IN/OUT signals may need refactoring depending on memory type.

**File**: `CPU-BOARD-3202/circuit/MEM_RAM_49.v`

---

## Completed

| Item | Status |
|------|--------|
| `s_logisimNet`/`s_logisimBus` cleanup | Done -- dead PFIFC/PFIFD files deleted |
| BusDriver16 | Validated working |
| Static/Dynamic RAM refactoring for FPGA | IDT6168A BRAM fix done |
| Bus Connectors A-B-C | All connected in ND3202D |
| `s_acond_n` | Connected from `CGA_MIC_CONDREG` (was hardcoded to 1) |
| `s_brk_n` | Connected through CGA TRAP/INTR path |
| `s_inr_7_0` | Connected from `installation_number` via `INR_7_0` port |
| MEM_ADEC_45, MEM_DATA_46, MEM_LBDIF_48 | Logisim naming cleaned up |
| MEM_RAMC_50 | PAL chips connected |
| Latch-to-FF migration | Complete -- see `verilog-remove-latch.md` |
| LINT and latches | All latches converted to FFs with ifdef guards |
| CPU_15 "disconnected" signals | Verified: `s_eccr` -> MEM_43, `s_ioni` -> IO_37, `s_rrf_n` -> CYC_36, `s_mreq_n` is input from CYC_36. All properly connected. |

---

## Microcode-execution fidelity (added 10-JUL-2026)

### Fix the JMP0-3 vectored-jump dispatch (CGA_MIC)

The microsequencer's vectored jump (`T,JMP0-3`, microword bit 25 VECT)
always lands on the vector base: the low-4-bit OR (IR(0-3) or A-operand,
selected by MIS0) never contributes. Blocks the 300$ serial binary
loader (INCH polls IOX 302 but dispatches to the IOX 300 handler) and
any microcode-issued vectored device I/O. Pre-existing (fails in latch
mode too, first exercised 10-JUL). Full analysis + 2-minute sim repro:
docs/serial-binload-300.md. Reference implementations to compare
against (ASK before porting C# behavior - it may contain hacks):
E:\Dev\Repos\Ronny\ND110Compile\ND110CPU (Cpu.cs ~783 vector dispatch,
~1310 LDIRV loads IR from the IDB - note our IRLATCH samples CD instead)
and NorskData-Doc ND-06.031.1 Microprogrammer's Guide (bit 25 / MIS0).

### Audit: microorder-by-microorder fidelity sweep

The JMP0-3 find suggests a class: microorders that no current test
exercises may be wrong or unimplemented, and could explain part of the
7/14 self-test failures and macro-instruction bugs. Plan: extract the
COMM/IDBS/condition decode tables from the Microprogrammer's Guide,
diff against what CGA_MIC/CGA_DCD/DGA actually implement, and give each
divergence a targeted unit test (the C# CPU at ND110Compile is a
working oracle for expected behavior - verify against the guide before
copying). Candidates to check first: vectored jumps (this bug), LDIRV
data source (IDB vs CD), MANIR/manual-IR flows, SCOND/hold-register
condition pipeline, COMM decodes marked "changed" in the ND-110->ND-120
delta (5, 36.2, 36.3).

### Evaluate: replace IDB OR-bus merging with muxes

Today many IDB/CD readers OR together all source outputs (inactive
sources drive 0). Evaluate switching to explicit muxes: pros - a wrong
enable produces an X/detectable in sim instead of silently OR-corrupted
data, clearer synthesis, kills a class of sim-vs-FPGA divergences
(EIOR-style read races); cons - large mechanical change across
generated code, must keep Logisim-structure compatibility, and the
golden byte-identity gates must hold throughout. Decision needed on
scope (board-level buses only vs inside gate arrays too).

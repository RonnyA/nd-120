# PLAN - MiSTer main memory on the SDRAM module (4 MB)

> Living plan, outstanding work only. Started 01-SEP-2026; implemented
> 02-SEP-2026 in `7e1e35f`. Requirement from Ronny: 4 MB of main memory,
> the WCS untouched.

## Next

Ronny retries fs.BPU LIST-FILE-NAMES on floppy and WD0 on build v50,
which is on the board.

Build v50 (02-SEP-2026): 0 errors, ALMs 20,474 (49%), M10K 165/553 (was
423 - the block-RAM main memory is gone), CPU clock slack +6.0 ns, clk2x
+4.2 ns. One miss: FPGA_CLK2_50, the framework's HPS clock, -1.9 ns
(v48 had +0.39 on the same clock; placement moved it). FLASHED: boots to
`#` with the images mounted - the self-test's memory reference test runs
on the SDRAM and passes (green lamp).

## What landed (`7e1e35f`)

- The Tang's sheet-49 bridge `fpga/tang-nano-20k/sdram-bridge/
  MEM_RAM_49_SDRAM.v` + controller `sdram18.v` are used AS IS, with a new
  16-bit-module mode behind `ND_SDRAM_DQ16` (needs `ND_SDRAM_PACK16`): one
  ND word per 16-bit location, `addr[20:0]` is the location, both DQM
  lanes on, the full-location port zero-extended, only DQ[15:0] connected
  inside the bridge. `ND_SDRAM_REFRESH_US` (default 15) is 7 on the
  MiSTer for an 8192-row die. Without the defines both files are
  unchanged: the four Tang bridge gates and the controller gate still
  pass; `test-dq16` is the same protocol replay in the 16-bit mode,
  registered in `tests/run_all_tests.sh`.
- This replaced the earlier draft here (separate `sdram16.v` /
  `MEM_RAM_49_SDRAM16.v` modules and a `MAIN_RAM_SDRAM16` backend arm):
  two defines in the existing files cost nothing on the Tang and avoid a
  second copy of 900 lines of proven bridge.
- `rtl/pll_cpu.v` now produces 20 MHz (CPU), 40 MHz (clk2x) and 40 MHz at
  180 degrees (the chip clock) - one PLL, so the bridge's synchronous
  sampling of RAS/CAS holds. `nd120.sv` drives the SDRAM_* pins through
  `ND120_CORE`'s existing `MAIN_RAM_SDRAM` pass-through; A[12:11] = 0, the
  upper DQ/DQM bits unconnected. `nd120.qsf`: `MAIN_RAM_SDRAM`,
  `ND_SDRAM_PACK16`, `ND_SDRAM_DQ16`, `ND_SDRAM_REFRESH_US=7`; the BLOCKRAM
  defines are gone. `files.qip` lists the two bridge files.
- Map: 2M words = 4 MB as BANK0 + BANK2, BANK1 absent - the Tang/Nexys
  map. Any 16-bit module with >= 2048 rows x 256 columns x 4 banks holds
  it, so the 32/64/128 MB question only sets the refresh cadence, and 7 us
  covers all of them.
- Whole-top Verilator lint with the new define set: exit 0.

## Outstanding

- [ ] FPGA_CLK2_50 setup miss (-1.9 ns, framework HPS clock): find the
      path; if it is the hps_io <-> core boundary it needs a proper
      constraint, if it is placement noise a seed or physopt setting.
- [ ] Flash; boot to `#`; tape `400$` FILSYS; LIST-FILE-NAMES on floppy
      and WD0 (the 64K-wrap test that failed on v48); TPE from floppy;
      SINTRAN from WD0 (`201540&` or `&`).
- [ ] If the board misbehaves in a way that smells like pin timing:
      `nd120.sdc` has NO SDRAM constraints (neither has the Tang nor the
      PDP2011 port). Add `create_generated_clock` on `SDRAM_CLK` and
      input/output delays against it. At 40 MHz with a 180-degree chip
      clock the margins are wide; do this on evidence, not by reflex.
- [ ] A memtest bitstream (write + verify the whole 4 MB, pass/fail on
      the console) if the CPU-level tests do not settle the question.
- [ ] `test-memchain-sdram` behind the real MEM_RAMC_50 PALs, cloned from
      `MEM_CHAIN_DDR2_tb.v` - the missing sim gate.
- [ ] README storage/memory rows for the MiSTer.

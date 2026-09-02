# PLAN - MiSTer main memory on the SDRAM module (4 MB)

> Living plan, outstanding work only. Started 01-SEP-2026; implemented
> 02-SEP-2026 in `7e1e35f`. Requirement from Ronny: 4 MB of main memory,
> the WCS untouched.

## Next

Flash v51 (banner stamp) when it exits; then build v52 with the 7E1
console receiver and flash it - the SINTRAN boot lines must then be clean.

## ROOT CAUSE of the dropped boot characters (02-SEP-2026, measured)

The framework routes emu's UART_TXD to the HPS peripheral UART, which is
`/dev/ttyS1` on the board. A raw 115200 capture of it during the `&` boot
shows SINTRAN's first lines with EVEN SOFTWARE PARITY in bit 7 (CR = 8D,
space = A0, '4' = B4, '1' = B1; even-ones characters unchanged) and the
later lines as plain 7-bit. `terminal_ctrl` drops bytes >= 7F. The MiSTer's
`console_uart_rx` was 8N1 (DATA_BITS 8, PARITY 0) and passed bit 7 through;
the Nexys's is 7E1 and discards it, hence clean there. Fixed in `nd120.sv`
(7E1, like the Nexys). Gate: `sim/console_burst_tb.v` now sends the
parity-tagged stream - with the 8N1 receiver it prints the board's exact
"SNAN-VS500M", with 7E1 the full line; PASS at 40 MHz and 139.7 MHz.

## BOARD RESULTS, build v50 (Ronny at the keyboard, 02-SEP-2026 00:30-00:50)

- fs.BPU from tape: LIST-USERS and LIST-FILE-NAMES on floppy and WD0 - the
  64K-wrap runaway is GONE.
- `1560&` with runSim FLOPPY1.IMG in drive 0: TPE Monitor B01 banner, `TPE>`.
  TPE CONFIG, INSTRUCTION, PAGING and MEMORY all pass - the SDRAM main
  memory is validated by the machine's own diagnostics. (The earlier "garbage"
  after 1560& was a d:
d\s image that is not a boot floppy.)
- `&` (ALD autoload = 20500&) from WD0.IMG: **SINTRAN III boots** - paging
  ON, ring 2, "ERS/SINTRAN III Watchdog has started", ESC gives a login.
  The first ~12 lines of the boot text arrive with characters dropped
  ("SNAN-VS500M", "PAGSSAPPNG:30B") and CRs missing (staircase); the INFO
  line and everything after are clean. Subset of the real text, so not a
  baud or framing mismatch. HDD R/W lamps on the panel line never lit
  during the boot - a second, separate observation.
- Banner build stamp added to the MiSTer build (`make banner`), same as the
  Nexys; shows at the next build.

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

- [ ] FPGA_CLK2_50 setup miss (-1.9 ns): FOUND - the CPU status-lamp
      register into the framework's mcp23009 LED driver, an asynchronous
      LED path. `nd120.sdc` now declares FPGA_CLK2_50 an asynchronous
      group; takes effect at the next build - confirm TNS 0 there.
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

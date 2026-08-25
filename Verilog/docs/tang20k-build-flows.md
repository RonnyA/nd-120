# Tang Nano 20K: dual-toolchain build flows (OSS primary, Gowin EDA backup)

**Full path:** `Verilog/docs/tang20k-build-flows.md`
**Date:** 12-JUL-2026. Decision by the project owner: support BOTH toolchains
for the full ND-120 CPU bitstream, all clock variants, with the OSS suite as
the primary flow and Gowin EDA as the backup.

---

## 1. The matrix

Everything runs from `Verilog/fpga/tang-nano-20k/`.

| | OSS CAD Suite (PRIMARY) | Gowin EDA (BACKUP) |
|---|---|---|
| Tools | yosys + nextpnr-himbaechel + gowin_pack (Project Apicula) | GowinSynthesis + PnR via `gw_sh.exe` |
| Where it runs | Linux / WSL (auto-detects `~/oss-cad-suite`, override `OSS_CAD=`) | Windows host (`C:\Utils\Gowin\...\gw_sh.exe`) |
| Build | `make` `[VARIANT=slow\|crawl\|full]` | `make gowin [VARIANT=...]` or `.\gowin_build.ps1 [-Variant ...]` |
| Bitstream | `build/nd120_tang20k_oss-<variant>.fs` | `build/nd120_tang20k_build/impl/pnr/nd120_tang20k_build.fs` |
| Load (SRAM, volatile) | `make load [VARIANT=...]` | `make load-gowin` |
| Flash (persistent!) | `make flash [VARIANT=...]` | `make flash-gowin` |
| Netlist gates | `make check` (tristate + latch, see section 4) | EX3988 empty-WCS check in gowin_build.ps1 |
| Logs | `build/nd120_tang20k_oss-<variant>-synth.log`, `...-pnr.log` | `build/nd120_tang20k_build/impl/gwsynthesis/*.log` |

Clock variants (same meaning in both flows):

| VARIANT | CPU / bus | SDRAM pair | Defines in effect | Use |
|---|---|---|---|---|
| `slow` (default) | 6.75 MHz | 13.5 MHz | `TANG_SLOW_BRINGUP` | bring-up default, under every measured Fmax |
| `crawl` | 3.375 MHz | 6.75 MHz | `TANG_SLOW_BRINGUP` + `TANG_CRAWL_BRINGUP` | mechanism probe (timing-vs-logic bisection) |
| `full` | 27 MHz | 54 MHz | neither | target speed - needs timing closure first |

## 2. One source of truth (how the variants work)

Both flows compile the **same ordered file list** parsed out of
`nd120_tang20k.gprj`, with `src/tang20k_defines.v` as the first file, so all
`` `define``s (GOWIN, FPGA_FF_MODE, SKIP_WCS_LOAD, MAIN_RAM_SDRAM,
ND_SDRAM_PACK16, BOARD_CLK_FREQ, ...) come from one place. yosys keeps
defines across the files of a single `read_verilog` command, matching the
Gowin ordered-compilation-unit behavior (verified empirically).

The clock variant is selected WITHOUT editing any file, via a
`TANG_VARIANT_FULL` / `TANG_VARIANT_CRAWL` pre-define that
`src/tang20k_defines.v` consumes:

- OSS: the Makefile passes `-DTANG_VARIANT_*` to `read_verilog`.
- Gowin: `gowin_build.ps1 -Variant ...` generates `build/tang20k_variant.v`
  and `gowin_build.tcl` adds it as the FIRST project file. The file is
  rewritten on every build (stateless); absent file = slow.

No variant define = `slow`, byte-identical to the historical default.

## 3. What the OSS flow needed (differences vs Gowin EDA)

Recorded so nobody re-discovers them:

1. **`ram_style="block"` is a hard requirement to yosys, advisory to
   Vivado/Gowin.** Two memories have asynchronous read ports (impossible in
   a BSRAM) and forced block style; both now select distributed LUT RAM
   under `` `ifdef YOSYS `` (yosys pre-defines `YOSYS`; all other flows are
   untouched):
   - `Shared/support/Am9150.v` (MMU cache CHIP_21F, 1024x4 = ~256 LUT4)
   - `CPU-BOARD-3202/circuit/CPU_PROC_32.v` `registerBlock` (2048x16 =
     ~2K LUT4)
2. **GW2A FF power-up value must equal its async-set value.** yosys
   `dfflegalize` hard-errors on `reg q = 1'b0` + async preset to 1 (Xilinx
   FFs allow INIT != preset, so Vivado never minded).
   `Shared/ndlib/SCAN_WITH_SET_N_EN.v` inits to 1 under `` `ifdef YOSYS ``
   - which is also what the silicon does, since S_n is asserted through POR.
3. **SDRAM "magic" ports are not auto-connected by nextpnr** the way Gowin
   EDA connects them. The Makefile appends
   `sdram-test/src/sdram_pins_oss.cst` (internal pseudo-pins for
   `O_sdram_*` / `IO_sdram_dq`) to `src/nd120_tang20k.cst` into
   `build/oss.cst`.
4. **WCS preload hex** (`$readmemh("wcs_XXC.hex")`, 32 files +
   `wcs_image.hex`): resolved against the yosys cwd; `make wcs-hex`
   refreshes the board-dir copies from `Code/Microcode/wcs/`. An empty WCS
   is a dead CPU - the Gowin flow greps its log for EX3988; in the OSS flow
   a missing hex is a hard `$readmemh` error at synthesis time.
5. **No SDC in the OSS flow**: nextpnr-himbaechel takes only the CST; judge
   timing by the Fmax it reports in `...-pnr.log` against the variant's
   clock (that is exactly the slow/crawl strategy). The Gowin flow still
   uses `src/nd120_tang20k.sdc`.

   Measured on the first OSS builds (12-JUL-2026):

   | VARIANT | clk_cpu need | clk_cpu Fmax | clk2x need | clk2x Fmax |
   |---|---|---|---|---|
   | slow  | 6.75 MHz  | 47.98 MHz | 13.5 MHz | 161.76 MHz |
   | crawl | 3.375 MHz | 48.99 MHz | 6.75 MHz | ~180 MHz |
   | full  | 27 MHz    | **57.51 MHz** | 54 MHz | 180.86 MHz |

   The OSS netlist closes the FULL 27/54 MHz target with >2x margin -
   where GowinSynthesis measured 9.38 MHz Fmax on the same RTL (the
   number that forced the slow-bringup strategy). Needs hardware
   confirmation before declaring the slow era over, but the OSS flow may
   make `VARIANT=full` the default.
6. **`rPLL`** (`src/gowin_rpll_27_54.v`) is the only vendor hard primitive;
   synth_gowin blackboxes it and gowin_pack/apicula implements it. The
   variant defines switch its FBDIV/IDIV/ODIV inside the wrapper.
7. **WSL drvfs staleness**: with the repo on the Windows drive, a compiler
   occasionally misses a just-written file ("No such file or directory" on
   a file that exists). Re-run the build; it cures itself. (Known class,
   also seen with Verilator under runSim.)

## 4. Netlist gates (`make check`)

Run after any RTL change, before hardware:

1. **Tristate integrity** - reuses `sd-fat-test/sim/check_tristate.py`
   (born from the 12-JUL-2026 DAT1-3 silicon failure: yosys silently
   collapsed a `1'bz`-in-inner-ternary pad into an always-driving OBUF;
   simulators, honoring z-semantics, cannot catch this class). The full CPU
   has exactly ONE reachable pad-tristate, `IO_sdram_dq` (driven in
   `sdram-bridge/sdram18.v` with the clean top-level ternary idiom); the
   gate asserts it stays a true inout driven only by `$tribuf` cells.
2. **Latch census** - FPGA_FF_MODE builds must contain no inferred latches
   (`select -assert-none t:$dlatch t:$dlatchsr`).

## 5. Programming and console

- Board attached to WSL via usbipd; `openFPGALoader -b tangnano20k <fs>`
  (`make load` / `make load-gowin`). `flash` variants are PERSISTENT and
  replace whatever is in config flash (e.g. the factory LiteX image).
- Console: 9600 8N1 on the board USB-UART. Expected boot behavior:
  `docs/boot-golden-spec.md` (self-test banner, OPCOM prompt; deposit /
  examine round-trip is the standard smoke test).

## 6. Regression expectations

- The OSS-flow RTL accommodations are all `` `ifdef YOSYS `` (see section
  3) - Verilator golden, runSim golden console, Basys3 Vivado and Gowin EDA
  builds are bit-identical to before by construction.
- Sim gates unchanged: `make sim` here (sdram-bridge + sdram-test tbs),
  `Verilog/tests/run_all_tests.sh` for the full registry,
  `fpga/tang-nano-20k/sim` vtest for the pre-synth full-boot gate.

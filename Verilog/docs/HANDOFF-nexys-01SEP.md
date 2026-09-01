# HANDOFF: Nexys 4 DDR - cache, MIPS, panel lamps, QSPI (31-AUG / 01-SEP-2026)

**Full path:** `Verilog/docs/HANDOFF-nexys-01SEP.md`
Companion to [`HANDOFF-tdv-keyboard-01SEP.md`](HANDOFF-tdv-keyboard-01SEP.md)
(terminal/keyboard work from a concurrent session) and
[`HANDOFF-mips-and-clock.md`](HANDOFF-mips-and-clock.md) (the MIPS tap
derivation in full).

## What is on the board

**Build 24**, banner `build c0c2c65+ 01-Sep-2026 18:04`, flashed over JTAG
(volatile - a power cycle loses it).

| | |
|---|---|
| clock | 33.333 MHz (`clk=33`) |
| cache | **ON** |
| terminal | TDV2200 (type 93), the default |
| panel | LED panel + panel clock (datetime) |
| MIPS | 7.52 MIPS at the SINTRAN login screen |
| timing | WNS +0.024, TNS 0, 0 failing endpoints of 59887 |
| build cmd | `vivado -mode batch -source build.tcl -tclargs clk=33 cache physopt -noburn` |

Kept bitstreams in `fpga/nexys4ddr/`: `..._build24_ledfix.bit` (current),
`..._build20_ledpanel_tdv.bit`, `..._build17_tdv2200.bit`,
`..._build11_clk33.bit`.

**Always pass `-noburn`** when you intend to flash separately - `build.tcl`
programs the board itself at the end otherwise (line ~739), so build + a
`program_only.tcl` run reconfigures the board TWICE.

## The cache is worth ~3x, and the 30-AUG decision was reversed

Measured on silicon with the panel MIPS counter, running SINTRAN:

| build | clock | cache | MIPS | clocks/instruction |
|---|---|---|---|---|
| 15 | 45.45 MHz | off | 2.44 | 18.6 |
| 16+ | 33.33 MHz | **on** | **7.52** | **4.4** |

**~3x the throughput on a 26% SLOWER clock.** The machine is memory-latency
bound: without cache every instruction fetch is a DDR2 read, and DDR2 does not
get faster when the CPU clock rises. A one-word loop (`124000`, `JMP` to its own
address - no operand, no write, no IO) ran at **17.1 clocks/instruction at BOTH
45.45 and 33.33 MHz**, throughput scaling exactly with the clock. Three
independent uncached readings agree at 17.1.

The earlier "speed beats cache" call came from a MIPS counter fed by a
MEMORY-CYCLE signal, which goes blind exactly when the cache starts working:
both configurations read 2.44 and the cache looked worthless. **Never compare
two numbers taken with different instruments.**

### 45 MHz with cache is not reachable - closed, do not re-litigate

- Cone is ~28 ns at every endpoint (27.986 / 28.039 / 28.047 ns across builds
  10, 12, 18 on three different worst paths), 75-80% ROUTING.
- Build effort is exhausted: `timingexplore` (opt ExploreWithRemap, place
  ExtraTimingOpt, route AggressiveExplore) moved WNS -6.780 -> -6.440. That is
  0.34 ns of the 6.4 ns needed.
- Not congestion: 31% LUTs, 47% slices. It is DISTANCE - BRAM is 68% and the
  WCS BRAMs sit spread across fixed BRAM columns.
- **It is architectural.** DELILAH.pdf page 103 (`/CGA/TRAP/BRKDET`) has NO
  flip-flops at all: page-table bits, `IPCR`, `IWRITE`, `IFETCH`, `VACC` reach
  `BRKN` and `TRAPN = NAND(BRKN, CBRK, ETRAPN)` combinationally. Page 104
  (`/CGA/TRAP/TVGEN` sheet 2) registers every trap TERM on TCLK, but `TVEC3` is
  a bare NAND of `LEV1`/`LEV2` and those same signals select the `MUX31LP`s for
  TVEC0-2 - and LEV1/LEV2 are combinational from `VACC` + page-table bits.
  So the memory-protection decision reaches the control-store address with no
  register in between, by design; `ETRAP_n` makes it safe in TIME, not by
  pipelining.

Ceiling with cache is ~35.6 MHz (1/28.04 ns); `clk=35` is 28.0 ns exactly and
untested. The only real fix is a pipeline stage in the protection path, which
moves every memory fault a cycle later machine-wide.

## MIPS counter - fourth tap, and the first one measured first

`CGA_ALU` `XGPRLOAD_DBG` = `ALUCLK_EN & GPRC[0] & ~GPRC[1]` - the instruction
register taking a new opcode (`CGA_ALU_GPR`'s MUX41P selects D1 = `CD_15_0`
when `GPRC[1:0] == 01`). Gated by **`ND120_MIPS_TAP`**, set with the VGA
console, so boards with no panel tie it off instead of relying on synthesis to
strip a dangling output.

Three earlier taps were picked from a signal's NAME and all read 00.00:
`DEBUG_FETCH` (memory-cycle qualifier, starved by a warm cache), board `MAP_n`
(gated by FORM and cycle state), and `CFETCH` - **0 pulses in 460 executed
instructions**, because `CGA_DCD.v` `CFETCH_FF` ties `.D` to its own `.Q` and
only reloads through the BRK scan path. **That is CORRECT as transcribed** -
verified against DELILAH.pdf page 69 (`/CGA/DCD` sheet 5 of 10): the FD1S cell
has D looped back to Q, TI from the FETCH flop's Qbar, TE from BRKN via
inverter IVA, and NO CL pin. Do not "fix" it; a rewrite on 01-SEP broke SINTRAN
boot and was reverted.

Validation recipe: `tests/instruction-verify/run_area_test.sh <AREA>` with
`ND120_COUNT_CFETCH=1`. Run TWO areas with different instruction mixes -
`REGISTER-OPERATIONS` and `MEMORY-REFERENCE` both gave 469 pulses vs 460
reference instructions, a CONSTANT offset, which is what proves the tap is not
counting operand fetches.

## Panel CPU lamps - ACTIVE LOW, and that is measured

`nd120_nexys4ddr_top.v` inverts both: `.panel_cpu_red(~s_cpu_led[0])`,
`.panel_cpu_green(~s_cpu_led[1])`. **GREEN lights correctly with these in
place** (build 24, confirmed on hardware).

Do NOT remove them. The MiSTer port measured this on 31-AUG - "passing them
straight through showed every lamp backwards"
(`fpga/mister/nd120.sv:511-518`). The IOC register comments in `IO_REG_41.v`
say "red LED ON1" / "green LED on1"; reading those as active-high and dropping
the inversion is the mistake made on 01-SEP. Symptom of the missing inversion:
RED lit while master clear is NOT running, because `s_emcl_n` idles high.
This also closed open item 3 in the TDV handoff - that session's wiring
inspection was correct and it was looking at the broken build.

## QSPI flash - the demo, and the part-name trap

The board's factory Digilent demo is archived in
`fpga/nexys4ddr/qspi_factory_backup.zip` (both a 4 MiB and a full 16 MiB dump,
0.56 MB zipped). Contents, measured: ONE bitstream, sync word `AA995566` at
`0x30`, last non-erased byte `0x3A607B` (3.65 MiB), nothing above 4 MiB.

- `readback_qspi.tcl` - dump a board's flash, writes nothing
- `restore_qspi.tcl` - write a RAW image back (`write_cfgmem -loaddata`)
- `flash.tcl` - write a `.bit` permanently

**NAME the flash part: `s25fl128sxxxxxx0-spi-x1_x2_x4`.** A filter like
`s25fl128*` also matches `s25fl128l` - the S25FL128**L**, a different device
with a different command set - and this board carries an S25FL128**S**. A
readback with the L part failed at the Tcl level with
`[Labtools 27-3307]` **and still destroyed the factory demo**, because Vivado
had already loaded its programming bitstream and driven the wrong opcodes at
the chip. A script that only intends to read is not automatically safe. The
lookalike `s25fl128s-3.3v-qspi-x4-single` is UltraScale-only; Artix-7 refuses
it with `[Labtoolstcl 44-655]`.

The demo was restored from the archive and verified. Note the TDV handoff
reports a QSPI burn blocked by "cannot set write enable bit or block(s)
protected" - that did NOT recur with `restore_qspi.tcl`, which erased,
programmed and verified successfully.

## Build stamp

The power-on banner now carries the build identity:

```
ND-120/CX CPU CORE
80x25 TDV2200 console
build c0c2c65+ 01-Sep-2026 18:04
```

`build.tcl` regenerates `term_banner_rom.v` per build with the git short hash
(`+` if the tree was dirty) and timestamp, into a build-local file so the
committed ROM is never dirtied. Falls back to the committed ROM if git or
python is missing. Run by hand with no argument the generator writes
`build dev`.

## Open items

1. **Full validation suite has never run** on the current RTL - 13
   instruction-verify areas + unit suite + latch-vs-FF compare. Started twice,
   killed both times for board work. Nothing suggests breakage (the machine
   boots, all 8 cache tests pass) but it is unverified.
2. **CACHE-1X0-A00 now passes all 8 tests** including test 3, which used to
   hang at `P=124563B`. Attribution uncertain: it was last seen failing on the
   16.667 MHz build and was never re-run on board after the 30-AUG RTL fixes.
   If it returns, re-test at 16.667 MHz first to see whether it is
   clock-dependent.
3. **`clk=35` with cache untested** - 28.0 ns against a 28.04 ns path, so it
   misses by 0.039 ns on paper. Probably not worth the margin.
4. Terminal/keyboard items are in the TDV handoff (Left arrow is a keyboard
   hardware fault, box-drawing fix not yet visually confirmed, Insert
   unverified).

## Process notes

- **Two sessions shared this repo all day.** Several commits carry the other
  session's in-flight work because the same files could not be separated -
  each such commit says so in its message. One `.git/index.lock` collision
  happened; wait for the lock, never delete it.
- **`git push` needs the GitHub CLI here**: there is no private key in
  `~/.ssh` and no agent, but `gh` is authenticated. `gh auth setup-git` then
  push to the HTTPS URL. `origin` is left as SSH.
- A comment line beginning with the word `Verilator` is parsed as a lint
  metacomment and kills every Verilator build (`Unknown verilator comment`).
  Cost a build cycle on 01-SEP; fixed in `IDT6168A_20.v`.

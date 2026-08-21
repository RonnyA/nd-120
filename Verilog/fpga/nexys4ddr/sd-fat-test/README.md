# Nexys 4 DDR SD-FAT test, with memory tests in the menu

**Full path:** `Verilog/fpga/nexys4ddr/sd-fat-test/`
**Date:** 20-AUG-2026.

The hardware-proven SD/FAT test tool, ported to this board's **on-board
microSD slot**, with two memory-test commands added to its menu.

The test design and all SD/FAT RTL are reused unchanged from
`Verilog/SD-FAT/circuit/` and the Tang `sd-fat-test/src/` - exactly as the
Basys3 port does. Only the wrapper, the pins and the two new commands are
specific to this board.

## Menu

Everything the Tang and Basys3 builds offer (`1` LIST, `2` DUMP, `8` BLOCK,
`9` SECTOR, `R` RANGE, `N` name, `H` help), plus:

| Key | Command | What it proves |
|-----|---------|----------------|
| **`B`** | ND-120 memory path | Drives the measured DRAM RAS/CAS/AA protocol against `MEM_RAM_49` (`SIP1M9`, sync BRAM) with the same eight vectors as `../../basys3/mem-test/`. A PASS means the ND-120 memory path is sound and a memory fault lives in the CPU/MAC integration. |
| **`M`** | DDR2 | Writes an address-derived pattern over the whole 128 MiB, reads it back and verifies it. |

`B` output:

```
NDMEM START
ND 00000 W A5 R A5 OK
ND 00001 W 5A R 5A OK
ND 00002 W 3C R 3C OK
ND 00004 W C3 R C3 OK
ND 00010 W FF R FF OK
ND 00100 W 11 R 11 OK
ND 000FF W 77 R 77 OK
ND 003FF W 42 R 42 OK
NDMEM PASS
```

`M` output:

```
DDR2 CALIB OK
DDR2 WRITE 00
... one line per 16 MiB ...
DDR2 READ 00
...
DDR2 PASS
```

On a failure it prints `DDR2 FAIL AT xxxxxxx` (the first bad address) followed
by `DDR2 ERRS nnnn` (the count), so a single weak bit and a dead half of the
device look different in the log.

## Files

| File | Purpose |
|------|---------|
| `nexys4ddr_sd_fat_top.v` | Board wrapper: MMCM (27.027 MHz console/SD + 200 MHz for the DDR2 controller), reset, LED polarity, SD power gate, DDR2 pins |
| `nd_memtest_mux.v` | Routes a menu command id to the right test, and answers for tests not compiled into the bitstream |
| `nd_memtest_bram.v` | The ND-120 memory-path test (key `B`) |
| `nd_memtest_ddr2.v` | The DDR2 test (key `M`), including the MIG instance and the clock-domain crossings |
| `nexys4ddr_sd_fat.xdc` | Pins, all from `../Nexys-4-DDR-Master.xdc`. **No DDR2 pins here** - those come from the MIG core's own generated constraints |
| `build.tcl` | Build + JTAG program, with a WNS gate |
| `program.tcl` | Program the existing bitstream without rebuilding |

## Build

The DDR2 controller must exist first (generated once, takes a few minutes):

```bash
cd Verilog/fpga/nexys4ddr/ddr2-test
vivado -mode batch -source gen_mig.tcl

cd ../sd-fat-test
vivado -mode batch -source build.tcl -tclargs -noburn   # build only
vivado -mode batch -source build.tcl                    # build + program
vivado -mode batch -source program.tcl                  # program what is built
```

Console: **9600 8N1**, COM11 on this machine, or `/dev/ttyUSB*` after
`../usb-attach.sh`. See the console section in `../README.md`.

## Three things this port had to solve

These are recorded because none of them is obvious from the Basys3 version:

1. **The microSD slot has a power gate.** Reference manual section 12: after
   configuration the on-board microcontroller releases the SD bus and
   `SD_RESET` must be **actively driven low by the FPGA** to power the slot.
   Without it the slot is dead and every command times out.
2. **`$bits` is rejected in plain Verilog mode.** `status_printer.v` and
   `hex_dumper.v` use it, so `build.tcl` reads those two files with
   `read_verilog -sv`. The shared source is not edited for this.
3. **The 64 KB file buffer would not go into block RAM.** Vivado mapped it to
   24,704 distributed-RAM cells against 19,000 available sites, so placement
   failed outright. Two changes in `sd_fat_test_top.v` fixed it: an
   `ifdef SDFAT_BUF_BLOCKRAM`-gated `ram_style = "block"`, and - the one that
   actually mattered - **muxing the two write branches into a single write
   port**. Written as two `if/else` branches with different address
   expressions, Vivado counts them as two write ports, needs a third for the
   read, and rejects block RAM with "Infeasible attribute ram_style". After
   the fix: 517 LUTs as memory and 17 block RAM tiles.

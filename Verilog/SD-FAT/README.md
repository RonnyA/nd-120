# SD-FAT - reusable SD card + FAT filesystem library

Board-independent SD card access for the ND-120 project. This is the
storage backend for the planned ND-100 device emulation stack (paper
tape reader 400, floppy, SMD - see `Verilog/docs/sd-bpun-device-plan.md`)
and for the standalone board test projects.

First proven consumer: `Verilog/fpga/tang-nano-20k/sd-fat-test/`
(interactive UART menu: list directory, dump a BPUN file).

## Contents

| File | Origin | Function |
|---|---|---|
| `circuit/sdcmd_ctrl.v` | vendored WangXuan95, unmodified | SD CMD line bit engine (48-bit commands, responses, CRC7) |
| `circuit/sd_reader.v` | vendored WangXuan95, unmodified | Card init (CMD0/8/55/ACMD41/2/3/7/16) + CMD17 single-sector reads, SD-native 1-bit mode, SDv1/SDv2/SDHC |
| `circuit/sd_file_reader.v` | vendored WangXuan95, MODIFIED | MBR/DBR parse, FAT16/FAT32 mount, root-directory search (8.3 + VFAT long names), cluster-chain following, file byte stream |
| `circuit/LICENSE.WangXuan95` | upstream | GPL-3.0 license of the three files above |
| `circuit/sd_writer.v` | project (MIT) | CLEAN-ROOM single-sector CMD24 writer for an already-initialized card; used for in-place file rewrites (COPY, 1KW block updates). Deliberately independent of the GPL reader. |
| `sim/sd_card_model.v` | project | Behavioral SD card for iverilog testbenches: serves sector reads from a raw image file, ACCEPTS CMD24 writes into the image (CRC16 checked), checks command CRC7, answers with real CRCs |
| `sim/sd_writer_tb.v` + `sim/Makefile` | project | sd_writer unit test (registered in the global test registry as `SD-FAT/sim :: test-writer`) |

Upstream: https://github.com/WangXuan95/FPGA-SDcard-Reader (GPL-3.0).
NOTE: this repository is MIT-licensed; the three vendored files remain
GPL-3.0 (kept with their license text). Owner decision recorded before
committing: see the risk table in `Verilog/docs/sd-bpun-device-plan.md`.

## Project modifications to sd_file_reader.v (all marked in-source)

1. `scan_done` output - the internal filesystem FSM reached DONE
   (file fully streamed, file not found, or unmountable filesystem).
2. `found_file_size` output - byte size of the found file.
3. Runtime target file name (`target_name`, byte 0 in the low byte,
   case-insensitive + `target_len`) instead of the synthesis-time
   `FILE_NAME` parameter. `target_len = 0` never matches: directory
   scan only ("LIST" mode).
4. Directory-entry outputs (`dir_entry_valid` / `dir_entry_name` /
   `dir_entry_len` / `dir_entry_size` / `dir_entry_date` /
   `dir_entry_is_dir`) - every plain file AND subdirectory root entry
   walked during a scan is reported (long name if present, else 8.3,
   uppercase; raw FAT date word; directory flag).
5. `found_file_first_sector` output - absolute first data sector of the
   found file (valid with `file_found`); with the contiguity convention
   this is the base of the block map below.
6. The SIMULATE-mode `$finish` was removed (the IP is simulated inside
   larger testbenches); one ternary gained parentheses (yosys lexes
   `'hB ?` as a wildcard literal); the 8.3 parser no longer appends a
   trailing '.' to extension-less names; the `sdcmd` inout is split
   into `sdcmd_i/_o/_oe` through the whole chain (repo rule: the only
   tristate lives at the board top level).

## Block access (ND-120 1-kiloword blocks)

Convention used by the device emulation stack: 1 block = 1024 x 16-bit
words = 2048 bytes = 4 SD sectors. For a CONTIGUOUS file (the card
recipes create them contiguously on a fresh card):

    block N of file  <->  SD sectors (found_file_first_sector + 4*N) .. (+3)
    valid N          =    0 .. file_size/2048 - 1  (writers must refuse
                          any block that does not lie entirely inside
                          the file - past the cluster chain is the
                          NEXT file's data)

Reads: the vendored reader streams whole files; sector-level random
reads go through `sd_reader`'s `rstart/rsector` interface. Writes:
`sd_writer` (CMD24) writes any single sector of an already-initialized
card; the sd-fat-test menu command 4 demonstrates the full
locate-file -> block-address -> 4-sector write chain and its
out-of-range guard. The general random-access block device with its
own sector buffer (floppy/SMD emulation) builds on exactly this
mapping - see the plan document, Milestone 3.

## Using the library on a board

The modules are plain Verilog with the SD signals as ports - nothing is
board- or pin-specific. Per board you provide:

1. Pin locations in that board's constraint file.
2. A top level that drives `sd_dat1/2/3 = 1` (keeps the card in
   SD-native mode) and connects `sdclk/sdcmd/sddat0`.
3. `CLK_DIV` parameter for your clock (3'd1 up to 25 MHz, 3'd2 for
   25-50 MHz, see the header of `sd_file_reader.v`).

Proven: Tang Nano 20K on-board microSD slot (CLK=83, CMD=82, DAT0=84,
DAT1=85, DAT2=80, DAT3=81, all LVCMOS33 - see
`Verilog/fpga/tang-nano-20k/sd-fat-test/src/nano20k_sd.cst`).

Planned: Basys3 with a Digilent Pmod MicroSD on header JA. The Pmod
wires all six card lines, so the same SD-native 1-bit core works
unchanged - only the XDC differs (pin table, UNVERIFIED until the
adapter is in hand, in `Verilog/docs/sd-bpun-device-plan.md` 6.2).

## Simulating against the library

- iverilog: instantiate `sim/sd_card_model.v` on the SD pins (needs a
  `pullup` on `sd_cmd`), serve a real FAT16 image built with
  `mkfs.vfat -F 16 -s 1` + `mcopy`. Working example incl. image build
  script: `Verilog/fpga/tang-nano-20k/sd-fat-test/sim/`.
- Verilator: the event-driven Verilog card model cannot run under
  Verilator; use the C++ card model in
  `Verilog/fpga/tang-nano-20k/sd-fat-test/sim/test_sd_fat.cpp`
  (same protocol subset) plus the tristate-resolving wrapper
  `sd_fat_test_vtop.v` there.

## Known limitations (by upstream construction)

- The reader never writes (all writes go through the separate
  `sd_writer.v`, and only into existing file data sectors - see
  "Write path status").
- Root directory only; one file target per scan.
- FAT32: the directory entry's high first-cluster word is ignored
  (16-bit cluster numbers) - files with first cluster >= 65536 are not
  found. Use FAT16 cards (recipe in the sd-fat-test README) or a small
  FAT32 volume.
- Entries with attribute bits beyond Archive (0x20) / Directory (0x10)
  are skipped (e.g. read-only or hidden files).

## Write path status

IMPLEMENTED (Route B of the plan): `sd_writer.v` + in-place rewriting
of pre-created contiguous files. This covers file-content overwrite
(COPY) and random 1KW-block updates - exactly what floppy/SMD image
emulation needs. NOT implemented (and deliberately so, for now):
creating files, growing files, subdirectory creation - any FAT
METADATA writes. That tier remains the Route A decision (block-level
SD + picorv32 softcore running ChaN's FatFs, proven on this board by
nand2mario's iosys) if full card-side file management ever becomes a
requirement; see `Verilog/docs/sd-bpun-device-plan.md` section 6.4.

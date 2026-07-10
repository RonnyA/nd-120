# Tang Nano 20K SD-FAT test

Milestone 1 of the SD-BPUN device plan
(`Verilog/docs/sd-bpun-device-plan.md`): prove the reusable SD/FAT
library (`Verilog/SD-FAT/`) on real silicon with an interactive UART
menu - no CPU, no ND-100 bus. Once this works on hardware, Milestone 2
wires the same byte stream into an ND-100 paper tape reader device
(400 octal) so the microcode binary loader can boot BPUN files from
the card.

## What it does

USB serial console (the BL616 port of the board), **9600 baud 8N1**:

```
SD-FAT TEST 10-JUL-2026
SD: NOT CHECKED
1=LIST 2=DUMP 3=COPY 4=WRBLK1 H=HELP
# 
```

- `1` - init the card, mount the FAT16/FAT32 filesystem, list the root
  directory with size, date and name (directories show `<DIR>`):

  ```
        7026  11-JUL-2026  BOOT.BPUN
        8192  11-JUL-2026  TEST.TXT
       <DIR>  11-JUL-2026  HDD
  ```

- `2` - init the card, find `BOOT.BPUN` in the root directory, buffer
  it in a 64 KB BRAM and dump it:

  ```
  CARD: SDHC
  FS: FAT16
  FILE: FOUND
  000000: 00 00 00 00 00 00 00 00  00 00 00 00 00 00 00 00 
  ...
  OCTAL WORDS (FIRST 8): 000000 000000 ...
  LENGTH: 000000007026 BYTES
  DONE
  ```

- `3` - COPY `BOOT.BPUN` over the PRE-CREATED `TEST.TXT`, rewriting its
  data sectors in place with the project `sd_writer` (CMD24). No FAT
  metadata is touched, so the filesystem stays consistent; the card
  recipe below pre-creates a contiguous `TEST.TXT` big enough.
- `4` - WRBLK1: write a counter pattern into **1-kiloword block 1** of
  `BOOT.BPUN`. ND-120 block framing: 1 block = 1024 x 16-bit words =
  2048 bytes = 4 SD sectors; block N of a file lives at
  `file_first_sector + 4*N`. The pattern is 1024 big-endian words with
  `word[w] = w`, so every sector of the block is distinct. The command
  refuses (`ERROR: BLOCK OUT OF RANGE`) if the file is smaller than
  `(N+1)*2048` bytes - writing past the cluster chain would corrupt the
  next file. Validate with `2`: the dump shows the pattern in bytes
  0x800-0xFFF and the original content in blocks 0 and 2.
- `H` - detailed help; any other key reprints the menu.
- `S1` button - full reset.

Every command is a complete SD re-init, so the card can be swapped
between commands, and this restart path is exactly the future
device-400 "tape rewind". Nothing hangs without a diagnosis: a
watchdog (10 s) aborts a dead card / stuck read with an `ERROR:` line
and the menu `SD:` status shows `NOT CHECKED` / `NO CARD` / `ERROR` /
`OK`.

LEDs (active low): `0` alive, `1` FS mounted, `2` file found,
`3` command done, `4` file truncated (>64 KB), `5` error.

Files larger than the 64 KB buffer are truncated with an
`ERROR: FILE TRUNCATED TO BUFFER` message (the dump then shows the
first 64 KB). Large enough for every BPUN in `Verilog/runSim/`.

## Card preparation (goes with acceptance test A3)

```bash
# whole-card FAT16 - avoids the vendored core's FAT32 16-bit
# first-cluster limitation; 1 sector/cluster keeps it a REAL FAT16
sudo mkfs.vfat -F 16 -n ND120 /dev/sdX
mcopy -i /dev/sdX Verilog/runSim/INSTRUCTION-B.BPUN ::BOOT.BPUN
# COPY target: pre-created, contiguous (fresh card = contiguous), and
# at least as big as BOOT.BPUN (64 KB covers anything the buffer holds)
dd if=/dev/zero of=TEST.TXT bs=1024 count=64
mcopy -i /dev/sdX TEST.TXT ::TEST.TXT
# files must be in the ROOT directory with plain Archive attribute
```

Verify the dump on the host with `xxd BOOT.BPUN` (spot-check the
first/last 64 bytes and the LENGTH line).

## Build and load (OSS flow)

```bash
source ~/oss-cad-suite/environment
make          # yosys -> nextpnr-himbaechel -> gowin_pack -> build/sd_fat_test_top.fs
make load     # volatile load into SRAM (fast iteration)
make flash    # persistent: writes the config flash
```

Resource check (GW2AR-18): 32/46 BSRAM (the 64 KB buffer), Fmax
~77 MHz against the 27 MHz crystal - comfortable.

## Simulation (run BEFORE hardware, in this order)

```bash
cd sim
make test-dumper     # iverilog unit tb (seconds)
make test-verilator  # Verilator full-system test (~2 min) - the hardware gate
make test-system     # same plan in pure iverilog (SLOW: 30-60 min, manual)
```

**Interactive console** - drive the menu yourself against the simulated
board (same FAT16 image), before any hardware exists:

```bash
make console         # from the project root or from sim/
```

Your terminal becomes the UART: the banner and menu appear, keys
`1`/`2`/`3`/`H` execute live, `ESC` exits the simulation.
`make help` (project root and `sim/`) lists every target.

Both system tests drive the menu like a terminal user against a real
FAT16 image (`make_test_image.sh`: mkfs.vfat + mcopy, payload
`Verilog/runSim/RTC.BPUN` served as `BOOT.BPUN`) and verify the dumped
bytes against the payload file byte-for-byte, plus the LIST output and
the SD status lines. Verdict line: `TB_RESULT: PASS`.

`test-dumper` and `test-verilator` are registered in the global
`make test` registry (`Verilog/tests/run_all_tests.sh`); `test-system`
is the manual pure-iverilog equivalent (iverilog is ~1000x slower than
Verilator on this design).

## Structure

```
Makefile              OSS build (sources the SD/FAT lib from ../../../SD-FAT)
src/sd_fat_test_top.v menu FSM, 64 KB buffer, SD status tracking,
                      COPY + 1KW-block write control
src/status_printer.v  fixed status/menu lines -> shared uart_tx
src/hex_dumper.v      hex + octal-words + LENGTH + DONE formatter
src/buf_text_printer.v raw buffer printer (LIST output)
src/uart_tx.v/uart_rx.v  9600-8N1 (copies of the sdram-test ones)
src/nano20k_sd.cst    pins: clock 4, S1 88, UART 69/70, LEDs 15-20,
                      SD CLK=83 CMD=82 DAT0=84 DAT1=85 DAT2=80 DAT3=81
sim/                  testbenches + SD card image build script
```

Baud note: 9600 8N1 for bring-up (matches every other board test);
the `BAUD` parameter takes 115200 later without further changes - the
testbenches already run the same logic at 1 Mbaud.

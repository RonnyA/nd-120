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
  directory with size, date, first cluster (hex) and name:

  ```
        7026  11-JUL-2026  00000002  BOOT.BPUN
        7026  11-JUL-2026  00001812  TEST.TXT
       <DIR>  11-JUL-2026  00000011  HDD
  ```

- `2` - init the card, find `BOOT.BPUN` in the root directory, buffer
  it in a 64 KB BRAM and dump it:

  ```
  CARD: SDHC
  FS: FAT16
  FILE: FOUND
  000000: 00 00 00 00 00 00 00 00  00 00 00 00 00 00 00 00 
  ...
  OCTAL WORDS AFTER LEADER: 105015 030060 ...
  LENGTH: 000000007026 BYTES
  DONE
  ```

  (BPUN tapes start with a zero leader; the octal line shows the first
  8 words from the first NONZERO byte, so it is readable at a glance.)

- `3` - COPY `BOOT.BPUN` to `TEST.TXT` (which must exist, ANY size).
  If TEST.TXT's allocation is big enough, its data sectors are rewritten
  in place and only the directory size field is patched. If it is too
  small (a 9-byte "test txt", say), it is REPLACED: `sd_fat_rewrite`
  frees the old cluster chain, allocates a fresh CONTIGUOUS chain and
  patches the directory entry (both FAT copies), then the data is
  written. The filesystem stays consistent - the simulation gate runs
  `fsck.vfat` over the post-copy card image. Fails cleanly with
  `ERROR: NO SPACE FOR TEST.TXT` if no contiguous free run exists.
- `4` - WRBLK1: write a counter pattern into **1-kiloword block 1** of
  `BOOT.BPUN`. ND-120 block framing: 1 block = 1024 x 16-bit words =
  2048 bytes = 4 SD sectors; block N of a file lives at
  `file_first_sector + 4*N`. The pattern is 1024 big-endian words with
  `word[w] = w`, so every sector of the block is distinct. The command
  refuses (`ERROR: BLOCK OUT OF RANGE`) if the file is smaller than
  `(N+1)*2048` bytes - writing past the cluster chain would corrupt the
  next file. Validate with `2`: the dump shows the pattern in bytes
  0x800-0xFFF and the original content in blocks 0 and 2.
- `5` - CHECK ("fsck-lite"): walks every root file's cluster chain
  through the FAT and reports first cluster, reachable chain length and
  the length expected from the size - `OK` or `BAD` per file:

  ```
  BOOT.BPUN   CL 00000002 LEN 00014 EXP 00014 OK
  TEST.TXT    CL 00001812 LEN 00014 EXP 00014 OK
  HDD         CL 00000011 DIR
  CHECK DONE
  ```

  LEN and EXP are in CLUSTERS: LEN is the chain length actually
  reachable through the FAT, EXP is what the size field demands
  (ceil(size / cluster bytes) - e.g. 46566 bytes on a 32 KB-cluster
  card = 2). A chain that hits a free entry, an out-of-range pointer
  or a loop, or whose length disagrees with the size, is flagged
  BAD - exactly the damage a wrong FAT write leaves behind. Read-only.
- `6` - WRITE SPEED: rewrites `IO.DAT` (which must exist, any size -
  it is deleted/reallocated first, like COPY) with 1000 one-kiloword
  blocks (2,048,000 bytes) of pattern data. The write goes over the
  MIT engine's 13.5 MHz bit clock in CMD25 multi-block bursts of
  min(128, remaining) sectors (ACMD23 pre-erase + CMD12 per burst;
  IO.DAT is allocated contiguously so consecutive sectors are legal),
  timed with a 27 MHz cycle counter; prints `WRITE NNNNN KB/S`.
- `7` - READ SPEED: reads the whole `IO.DAT` back in CMD18 multi-block
  bursts through the same MIT engine (the MIT FAT reader only mounts
  the filesystem and locates the file) and prints `READ NNNNN KB/S`.
  Refuses with `ERROR: IO.DAT WRONG SIZE - RUN 6 FIRST` unless `6`
  ran before (the size check also guarantees the contiguity that the
  burst addressing relies on).
- `5` - CHECK ("fsck-lite"): walks every root file's cluster chain
  through the FAT and reports first cluster, reachable chain length and
  the length expected from the size - `OK` or `BAD` per file:

  ```
  BOOT.BPUN   CL 00000002 LEN 00014 EXP 00014 OK
  TEST.TXT    CL 00001812 LEN 00014 EXP 00014 OK
  HDD         CL 00000011 DIR
  CHECK DONE
  ```

  LEN and EXP are in CLUSTERS: LEN is the chain length actually
  reachable through the FAT, EXP is what the size field demands
  (ceil(size / cluster bytes) - e.g. 46566 bytes on a 32 KB-cluster
  card = 2). A chain that hits a free entry, an out-of-range pointer
  or a loop, or whose length disagrees with the size, is flagged
  BAD - exactly the damage a wrong FAT write leaves behind. Read-only.
- `6` - WRITE SPEED: rewrites `IO.DAT` (which must exist, any size -
  it is deleted/reallocated first, like COPY) with 1000 one-kiloword
  blocks (2,048,000 bytes) of pattern data. The write goes over the
  MIT engine's 13.5 MHz bit clock in CMD25 multi-block bursts of
  min(128, remaining) sectors (ACMD23 pre-erase + CMD12 per burst;
  IO.DAT is allocated contiguously so consecutive sectors are legal),
  timed with a 27 MHz cycle counter; prints `WRITE NNNNN KB/S`.
- `7` - READ SPEED: reads the whole `IO.DAT` back in CMD18 multi-block
  bursts through the same MIT engine (the MIT FAT reader only mounts
  the filesystem and locates the file) and prints `READ NNNNN KB/S`.
  Refuses with `ERROR: IO.DAT WRONG SIZE - RUN 6 FIRST` unless `6`
  ran before (the size check also guarantees the contiguity that the
  burst addressing relies on).
- `H` - detailed help; any other key reprints the menu.
- `S1` or `S2` button - full reset.

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

## Card preparation

Full guide incl. formatting, payload choices and the first-run sanity
sequence: CARD-SETUP.md in this directory. Short form:

```bash
# whole-card FAT16 - avoids the vendored core's FAT32 16-bit
# first-cluster limitation; 1 sector/cluster keeps it a REAL FAT16
sudo mkfs.vfat -F 16 -n ND120 /dev/sdX
mcopy -i /dev/sdX Verilog/runSim/INSTRUCTION-B.BPUN ::BOOT.BPUN
# COPY target: must exist, any size (COPY reallocates it when needed)
printf 'test\n' > TEST.TXT
mcopy -i /dev/sdX TEST.TXT ::TEST.TXT
# speed-test target for menu 6/7: same rule, any size
printf 'io\n' > IO.DAT
mcopy -i /dev/sdX IO.DAT ::IO.DAT
# files must be in the ROOT directory with plain Archive attribute
```

Verify the dump on the host with `xxd BOOT.BPUN` (spot-check the
first/last 64 bytes and the LENGTH line).

## Build and load (OSS flow)

```bash
make          # yosys -> nextpnr-himbaechel -> gowin_pack -> build/sd_fat_test_top.fs
make load     # volatile load into SRAM (fast iteration)
make flash    # persistent: writes the config flash
```

The Makefile finds oss-cad-suite by itself (default `~/oss-cad-suite`,
override with `make OSS_CAD=/path`). Console: 9600 8N1 on the BL616 USB
serial; if its `TangNano20K />` CLI answers instead of the menu, type
`choose uart` once to switch the chip into UART-bridge mode. Loading
resets the USB device - reconnect the terminal afterwards.

Resource check (GW2AR-18): 32/46 BSRAM (the 64 KB buffer), Fmax
~77 MHz against the 27 MHz crystal - comfortable.

### USE_4BIT - SD bus width (speed switch)

Top-level parameter in `src/sd_fat_test_top.v` (speed ladder rung c,
see `Verilog/docs/sd-speed-plan.md`):

| Setting | Data wires | Bulk transfer speed (sim) | When to use |
|---|---|---|---|
| `USE_4BIT = 1` | DAT0-DAT3 | ~5.9 MB/s write, ~6.4 MB/s read | THE production setting - full speed |
| `USE_4BIT = 0` | DAT0 only | ~1.6 MB/s | diagnosis / boards with only DAT0 wired (e.g. some PMODs) |

Only the data payload widens: commands, responses, CRC status and busy
signalling stay on their single lines in both modes, and the card is
switched per-operation (ACMD6), so the setting is safe to flip freely.
The FAT mount/scan path (sd_file_reader) always runs 1-bit; bulk data
(speed tests, CHECK/COPY/WRBLK1 FAT and payload traffic through
sd_writer) follows this switch.

11-JUL-2026 hardware status: 4-bit is sim-proven (all safety gates) but
FAILED its first silicon run (CHECK reported every cluster chain BAD =
FAT sector reads returning garbage on DAT0-3 while all 1-bit paths
worked). USE_4BIT is parked at 0 while the 4-bit signal path on the
Tang slot is being debugged; flip back to 1 once resolved.

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

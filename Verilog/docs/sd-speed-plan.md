# SD interface speed plan (11-JUL-2026 research)

Measured baseline on Tang Nano 20K hardware: 137 KB/s sequential write
(menu 6: 1000 x 2048 B, single-sector CMD24 at a 2.7 MHz bit clock).

## Where the time actually goes

One sector at 2.7 MHz: data on the wire 1.52 ms + command overhead
0.04 ms + CARD PROGRAM BUSY ~2.2 ms = 3.74 ms/sector. The card's
per-single-sector programming busy DOMINATES - raising the clock alone
gives less than 2x. The fix that matters is CMD25 multi-block write,
which amortizes the busy across a burst (the card buffers and programs
in the background; this is what SD Speed Class ratings are defined on).

## Facts about the current cores

- The vendored GPL reader (WangXuan95) has a hard architectural ceiling
  of clk/4 = 6.75 MHz (its real divider formula is
  sdclk = clk/(2*(clkdiv+2)); the README formula is inexact). At our
  CLK_DIV=2 its INIT clock is 70 kHz - below the spec's 100-400 kHz
  identification range. CLK_DIV=1 is the correct setting regardless.
- Our MIT sd_writer reaches 13.5 MHz TODAY with CLKDIV 5 -> 1 (sdclk
  toggles every sysclk). 13.5 MHz is inside the 25 MHz default-speed
  limit that every SD card must support - no CMD6 needed, no
  card-dependence.

## The ladder (sequential write, 64 KB granularity)

| Rung | Change | Expected | Effort | Risk |
|---|---|---|---|---|
| a | writer CLKDIV 5->1 (13.5 MHz), reader CLK_DIV 2->1 | ~0.25 MB/s (busy-bound) | 2 params | very low |
| b | CMD18/CMD25 multi-block + ACMD23 + CMD12 in OUR writer; GPL reader demoted to FAT mount only | ~0.9-1.3 MB/s | +150-250 lines + tb | low-moderate |
| c | 4-bit bus (ACMD6; CRC16 per DAT line = 4 LFSR instances; DAT1-3 already wired+constrained, proven on this slot by MiSTeryNano) | ~2.5-4 MB/s | +80-150 lines | moderate |
| d | CMD6 high-speed + 27 MHz 1:1 clocking (ODDR clock forward, IOB capture, SDC input delays); 50 MHz needs phase-tuned capture | ~5-8 MB/s | clocking rework | high (unproven on this slot) |

Recommended order: a immediately (after the FAT-write bug fix lands),
then b, then c; stop and measure before d. Rung b also evicts the GPL
core from the fast data path entirely (license benefit: MIT fast path,
GPL confined to mount).

## Status

- Rung a: IMPLEMENTED 11-JUL-2026. sd_writer default CLKDIV 5 -> 1
  (13.5 MHz; BUSY_TIMEOUT default rescaled to keep ~1 s), reader
  CLK_DIV 2 -> 1 in sd_fat_test_top (init 137 kHz - now inside the
  100-400 kHz identification band - data 3.375 MHz).
- Rung b: IMPLEMENTED 11-JUL-2026. sd_writer grew a burst interface
  (burst_len[8:0], rca[15:0], block_next) next to the untouched
  single-sector API: CMD18 multi-read, CMD55+ACMD23+CMD25 multi-write
  with per-block CRC-status/busy, CMD12 termination (R1b + final
  busy), CMD12-then-err on a mid-burst CRC-status reject. Menu 6
  writes IO.DAT in CMD25 bursts of min(128, remaining) sectors; menu
  7 reads it back in CMD18 bursts through the same MIT engine - the
  GPL reader is only used to mount and locate the file. The RCA for
  CMD55 is snooped from the CMD3 response at the top level (the GPL
  reader keeps it internal). Both card models (iverilog + C++) cover
  CMD18/CMD25/ACMD23/CMD12 incl. inter-block and final busy; the C++
  always-on reserved-region assertion checks every block of a burst.
  nd_storage and COPY/WRBLK1 stay on the single-sector path,
  unchanged. All gates green (writer tb burst cases, sd-fat-test
  FAT16/cold/FAT32/fat32big + fsck, full registry).
- Rung c: IMPLEMENTED 11-JUL-2026. sd_writer grew a 4-bit data engine
  behind a runtime `use_4bit` input (unconnected/0 = the original 1-bit
  engine, bit-exact - nd_storage and DAT0-only wirings unchanged): every
  operation is prefixed with CMD55(RCA)+ACMD6(arg 2) since the reader
  re-initializes the card to 1-bit between commands; data then moves as
  1024 nibbles on DAT3..DAT0 (MSB nibble first) with a CRC16 PER DAT
  line, both TX (4 LFSRs) and RX, on the single-sector AND burst paths;
  CRC-status and busy stay on DAT0 (spec) - those states are shared with
  the 1-bit engine. sd_fat_test_top wires DAT1-3 as pad-level tristates
  (parked high outside the writer phase to keep DAT3 high through init;
  cst pulls DAT1-3 UP) and enables 4-bit by default (USE_4BIT=1). Both
  card models (iverilog + C++) implement ACMD6, nibble framing, per-line
  CRC16 and a per-line CRC-error injection hook; the always-on
  reserved-region assertion decodes and validates 4-bit blocks. Sim
  numbers (Verilator sd-fat-test menus 6/7, 20 x 2 KB blocks): WRITE
  1607 -> 5972 KB/s, READ 1636 -> 6389 KB/s (3.7-3.9x; the sim card's
  programming busy is optimistic, hardware will land lower). The
  sd_file_reader stays 1-bit by decision: it only mounts and locates
  files in the fast paths, so converting its streaming engine buys
  nothing for the menus/nd_storage and was cut from this rung.
- Rung c PROVEN ON HARDWARE 12-JUL-2026: Tang Nano 20K, real 32 GB
  SDHC FAT32 card, menus 6/7 (1000 x 2048 B in IO.DAT):
  WRITE 3418 KB/s, READ 5981 KB/s - vs the 137 KB/s baseline that
  opened this plan (25x / ~44x). Read is within 7% of sim; the write
  gap vs sim is real card programming time. LIST freescan and CHECK
  (full FAT walk incl. a 75 MB image) also run over 4-bit.
  Three silicon-only bugs had to fall first (full story in
  docs/sd-cmd18-block-gap-research.md + the gates):
  (1) nested-ternary z pad idiom -> yosys silently emits an always-on
      OBUF (pad loses the tristate; FPGA fought the card on DAT1-3
      during reads). Single-ternary pads only; guarded forever by the
      test-tristate netlist gate (yosys proc+tribuf audit) + runtime
      contention assertions in every harness. cst: DAT1-3
      PULL_MODE=NONE (board has external 10K pulls).
  (2) menu-7 handover parked the mount reader mid-CMD17, leaving the
      card in SENDING-DATA where the next command is ignored; fix =
      wait for scan_done; the C++ card model is now state-aware so
      this class reproduces in sim.
  (3) the writer's RCA must be latched from the reader's CMD3 export,
      not snooped off the CMD line.
  Error texts are now operation-truthful and pinned by the registered
  test-errtexts exact-text gate; accepted menu keys echo back +CRLF.
- Rung d (CMD6 high-speed, 50 MHz): not started - rung-c hardware
  speeds already exceed every device budget in nd-storage-design.md.
- 12-JUL-2026: the GPL reader itself is GONE - replaced by the
  clean-room MIT sd_file_reader.v, whose data phase runs at clk/2
  (13.5 MHz at 27 MHz, CLK_DIV=1) and streams files in CMD18
  multi-block runs; the clk/4 ceiling described above is history and
  the mount/locate path is no longer license-constrained.

Full research with spec citations (SD Physical Layer v3.01/v6.00
sections, timing budgets, core survey incl. ZipCPU SDIO front-end
patterns, Gowin SDC guidance) is preserved in the workstream notes;
key spec points: 25 MHz default-speed is mandatory on all cards,
CMD6 mode-1 (arg 0x80FFFFF1, 512-bit status block on DAT, 8-clock
switch window) unlocks 50 MHz, multi-write CRC-status/busy stays on
DAT0 in all bus widths, block-gap busy timeout budget 250-500 ms.

# PLAN - MiSTer storage: floppy, Winchester and paper tape from OSD-mounted files

> Living plan, outstanding work only. Started 01-SEP-2026.

## Next

Phase 4: Quartus build (~25 min Docker) and the board checks, byte order
first. Every build and flash on Ronny's go.

Phase 3 landed 01-SEP-2026: `nd120.sv` carries the five `S` lines
(`S0,IMG,Floppy drive 0` .. `S3,IMG,Winchester unit 1`, `S4,BPUTAP,Paper
tape`), `hps_io` with `VDNUM=5, BLKSZ=2, WIDE=1` and all block ports, and
`nd_storage_mister_devices` in place of the tie-offs; `files.qip` lists
the backend, the aggregator and the three adapters; `build-defines.md`
section 6 documents it. `clk_sys` into hps_io is 40 MHz (>= 20 required).
Proof: Verilator lint of the WHOLE `emu` top with the framework's
`hps_io.sv` and PLL black boxes, the qsf's define set - exit 0, nothing
flagged in any ND file (the only suppressed classes are two Verilator
limitations in the framework's own PS/2 and video code, which Quartus
built unchanged in v47). Not yet: a Quartus run.

Decided (Ronny, 01-SEP-2026): the mount flags and the tape fault code are
NOT displayed - the OSD shows what is mounted, and the FDISK/WDISK error
codes reach SINTRAN. The nets stay in `nd120.sv` for a probe.

Phase 4 in progress. Build v48 (Quartus in Docker, from WSL - from Git
Bash the container's working directory gets rewritten to a Windows path
and the run dies before Quartus starts) done 01-SEP-2026, 22:47 elapsed:
0 errors, TNS 0.000 on every clock (worst slack 0.394 ns), ALMs
20,702/41,910 (49%, was 45%), M10K 423/553 (was 405), uninferred RAM 1
(the register file, as in v47). No warning class touches the storage
code. FLASHED: the board boots to the `#` prompt with the storage wired,
and again after `load_core /media/fat/ND120-storage-test.mgl` mounts
slots 0, 1, 2 and 4 - mounting does not disturb the CPU. Whether the
mounts took cannot be seen (no display, by decision); the next checks are
typed at OPCOM.

Board prep done 01-SEP-2026: `/media/fat/games/ND120/` holds `FLOPPY.IMG`,
`FLOPPY1.IMG` (runSim's 1.2 MB images), `INSTRUCTION-B.BPU` (the tape,
renamed for the 3-char extension) and `WD0.IMG` (78 643 200 bytes,
extracted from `SD-FAT/sim/nd_wd_card.img` with mtools, md5 verified).
`/media/fat/ND120-storage-test.mgl` mounts slots 0, 1, 2 and 4 on core
load: `load_core /media/fat/ND120-storage-test.mgl`.

BOARD RESULTS with v48 (Ronny at the keyboard, 01-SEP-2026 evening):
- `400$` from the tape slot loads FILSYS (fs.BPU) - the tape path and the
  byte order are RIGHT (a swapped stream cannot parse a BPUN).
- FILSYS LIST-USERS works on FLOPPY-DISC-1 and on DISC-74MB-1 (WD0): both
  disc read paths deliver correct pages.
- FILSYS LIST-FILE-NAMES runs away on both. Same signature as the Nexys
  on 24-AUG-2026, whose root cause is in `docs/nd120-facts.md`: a 32K-word
  bank (`ND120_BLOCKRAM_ADDR_BITS=15`) wraps every address >= 0o100000.
  The MiSTer qsf had 15. Fixed in `d26540d`: 64K-word banks, and a new
  `BANK_SLOTS` parameter (3 on the MiSTer) so they fit - 3 x 64K x 16 =
  308 M10K instead of 512 with the unreachable fourth slot. Main memory
  is now 384 KB of block RAM; SINTRAN still needs the SDRAM job.
- Also removed on request: the Console baud OSD option (`ad320fc`).
- Build v49 with 64K-word banks DID NOT FIT (Fitter: 7802 LABs of 4191,
  140K registers, M10K 534/553). Block RAM cannot hold this machine's
  memory; the board stays on v48 (192 KB, wraps) and main memory moves
  to the SDRAM module: `docs/PLAN-mister-sdram.md`. LIST-FILE-NAMES is
  retested there.
- On the board now: 32 floppy images from `d:
d\s` plus the two runSim
  ones, all 18 runSim tapes as `.BPU`, `WD0.IMG`.

Typing OPCOM commands over ssh does NOT work yet: a `/dev/uinput` keyboard
(`mister_type.py`, on the board in the games folder) is registered by the
kernel but neither the console nor the F12 OSD react, so either MiSTer's
main binary ignores uinput devices or the screenshot leaves out the OSD
overlay. Until that is solved, the `400$` / `1560&` / OPCOM byte-order
steps need Ronny at the keyboard while the screenshots are pulled here.

Phase 2 landed 01-SEP-2026: `Verilog/fpga/mister/rtl/nd_storage_mister_devices.v`
(two floppy adapters DRIVE 0/1, two Winchester adapters UNIT 0/1 with the
8x9x1024 geometry, the tape adapter, outputs ORed per controller as the
Tang aggregator does) and `Verilog/fpga/mister/sim/nd_storage_mister_devices_tb.v`
(8 checks at the controller seams: empty-slot NOTOPEN, media format per
drive, reads on drive 0/1 and unit 0/1 each from its own slot, floppy and
Winchester read-modify-write sector writes with the neighbour sector
intact, tape stream across a block edge, rewind, EOF silence without a
fault, no-image fault). `make test-storage-devices`, registered. Verilator
lint clean. The floppy `DISK_TIMEOUT` is not needed for a missing image
any more (the backend answers NOTOPEN at once); it stays a Phase 3 item
only as insurance against a silent HPS.

Phase 1 landed 01-SEP-2026: `Verilog/fpga/mister/rtl/nd_storage_hps.v`
(the backend), `Verilog/fpga/mister/sim/hps_io_model.v` (signal-level
ARM+hps_io model that also checks the handshake rules) and
`Verilog/fpga/mister/sim/nd_storage_hps_tb.v` (8 checks: unmounted slot,
open semantics, read, write + round trip, read-only, range, two clients at
once, unmount). `make test-storage-hps`, registered. Teeth: BYTE_SWAP=0
fails on exactly the byte-order checks; passes at 20/40, 31/56 and 50/40
MHz clock ratios. Verilator lint clean. Slot map: 0 floppy 0, 1 floppy 1,
2 WD0, 3 WD1, 4 tape.

## What is already true (verified 01-SEP-2026, so the plan does not re-derive it)

- The controllers (`ND_FLOPPY_DMA`, `ND_WINCHESTER`, `ND_TAPE_400`) never talk
  to an SD card. They talk to the storage client bus defined in
  `Verilog/docs/nd-storage-interface-spec.md`: one request moves ONE
  2048-byte block (1024 ND words), file-relative 16-bit block number, the
  backend masters the client's own buffer with `buf_addr/buf_wdata/buf_we`.
  The controller-facing adapters (`nd_storage_floppy_adapter`,
  `nd_storage_disc_adapter`, `nd_storage_tape_adapter` in
  `Verilog/SD-FAT/circuit/`) are board-agnostic and stay as they are.
- On the MiSTer every one of those seams is tied off in
  `Verilog/fpga/mister/nd120.sv:704-760`; `hps_io` is instantiated with no
  storage ports at all (`nd120.sv:90-105`); `CONF_STR` has no `S` lines; the
  physical SD pins are tristated. There is no storage on the MiSTer today.
- Our vendored `Verilog/fpga/mister/sys/hps_io.sv` has `VDNUM`, `BLKSZ`
  (default 2 = 512-byte blocks) and `sd_blk_cnt[VDNUM]` ("number of
  blocks-1, total size must be <= 16384"). So one 2048-byte client block can
  be ONE HPS transaction with `sd_blk_cnt = 3`, not four.
- `WIDE=1` gives 16-bit `sd_buff_dout/din`. HPS words are little-endian
  (`{byte 2w+1, byte 2w}`); ND image words are big-endian
  (`{byte 2w, byte 2w+1}`, `nd_storage_disc_adapter.v:37-38`). The backend
  swaps bytes once, in both directions.
- `sd_lba` is file-relative on MiSTer: the HPS resolves the mounted file.
  The whole FAT layer (`sd_file_reader`, `nd_storage_fatchk`, contiguity
  rule, 8.3 root names) is not needed here.
- The Winchester card has a ONE-bit unit field (control word b9,
  `ND_WINCHESTER.v:59-60,181`): TWO units, WD0 and WD1. The four-unit device
  in this design is the SMD card (`ND_SMD`, units 0-2 wired, `INCLUDE_SMD=0`
  on the MiSTer today).
- Only ONE floppy adapter (DRIVE 0) and ONE disc adapter (UNIT 0) are
  instantiated anywhere in the tree (`nd_storage_devices.v:373,502`). The
  adapters ignore requests for other drives, so more instances can be ORed;
  the second instances have never been built or tested.
- The paper tape reader is a pure byte stream: `byte_req` -> `byte_valid` +
  `byte_data`, `source_rewind` on device clear. One file, read from the
  start. EOF and "no image" are both silence (RFT never rises); the only
  place that tells them apart is the adapter's sticky `fault/fault_code`.
- `ND_FLOPPY_DMA` has a `DISK_TIMEOUT` parameter that defaults to 0 =
  disabled; `ND_WINCHESTER` has no backend timeout. A backend that never
  answers hangs the guest.
- SINTRAN from the Winchester needs main memory above 0o200000, which the
  MiSTer's BRAM main memory does not provide (memory file
  `project_mister_memory_alignment`). That is the queued SDRAM job, not this
  plan. This plan's boot targets are the floppy (`1560&`) and the tape
  (`400$`); the Winchester path is proven with OPCOM deposits/reads and the
  Verilator-identical image bytes until SDRAM lands.

## The HPS contract (official docs, Main_MiSTer/user_io.cpp, the Template
## hps_io.sv, and a survey of 11 official cores - all read 01-SEP-2026)

Decision: drive `sd_rd/sd_wr` DIRECTLY, one OSD slot per drive. That is
what 7 of the 11 mainstream computer cores do (Atari ST and Archie
floppies, Apple II, C64, BK0011M, TRS-80, ZX Spectrum's floppy slot); the
drive-select line picks the slot bit, `sd_lba` comes from the geometry,
`img_mounted` is edge-detected to latch present/size/write-protect. The
`sys/sd_card.sv` virtual SPI card appears in no doc page and is used only
where the GUEST software bit-bangs an SPI card (DivMMC, MSX SD mapper,
Acorn MMFS). PDP2011 uses it three times because its controllers were
written for SPI, and nobody in the mainstream set copies that shape. Ours
were never SPI. The remaining cores (ao486, PCXT, Minimig) use an
ARM-served protocol that needs Main_MiSTer C++ changes - not for us.

The rules of the block interface, from the code:

- The ARM POLLS. It never sees `sd_rd` change; it reads a status word
  (`{1, sd_blk_cnt[sdn], BLKSZ, sdn, sd_wr, sd_rd}`) up to 4 times per main
  loop pass, picks ONE slot by rotating round-robin, reads that slot's
  `sd_lba` in the same transaction, then runs one data transaction with
  `sd_ack[slot]` high for its whole length. So:
  - hold `sd_rd`/`sd_wr` until `sd_ack` RISES, then clear it (the official
    `sys/sd_card.sv` does exactly this); the FALLING edge means done;
  - `sd_lba` and `sd_blk_cnt` stable from request until ack;
  - several slots may request at once; they are served one per poll.
- `sd_blk_cnt = 3` with `BLKSZ = 2` (512) = one 2048-byte transaction, one
  ack, `sd_buff_addr` running 0..1023 words in WIDE mode. BLKSZ is one
  value for ALL slots. The HPS clamps at 16384 bytes.
- Data arrives at the HPS SPI rate, not one word per clock; `sd_buff_wr`
  pulses one `clk_sys` cycle per word, address increments two cycles later,
  saturates, never wraps. For writes the core must present
  `sd_buff_din = buffer[sd_buff_addr]` from address 0 the moment ack rises.
  The buffer bus is BROADCAST: qualify every buffer write with the slot's
  own `sd_ack` bit.
- `clk_sys` into `hps_io` must be >= 20 MHz (sorgelig, Main_MiSTer #683).
- A read on an unmounted or short image is still acked and returns ZEROS.
  "No image" is only knowable from the mount pulse: `img_mounted[n]` is a
  few-cycle PULSE, `img_size`/`img_readonly` are valid during it and the
  size is sent first; unmount is the same pulse with `img_size == 0`.
- Writes go to the file immediately (`O_SYNC`, fwrite+fflush). A write
  past EOF is trimmed; an image cannot grow through the core. Read-only is
  only reported (`img_readonly`), never enforced on the HPS side.
- `S{slot}` is documented as 0-3 but the code accepts 0-9, `hps_io.sv`
  allows VDNUM 1..10, and TRS-80_MiSTer ships `S4` with `VDNUM(5)`. Slot 4
  is proven. (Bit 7 of the mount word is the read-only flag, so 7+ would
  collide; irrelevant at five slots.) TRS-80 also found that an `FS`
  save-file line clobbers slot 0 - we have no such line.
- The HPS automounts `boot0.vhd`..`boot3.vhd` / `ND120.VHD` from the core's
  folder into slots 0-3 at start. Do not ship such files.
- Tapes in official cores (PDP-1, ZX Spectrum, C64, TRS-80) are `F`
  downloads via `ioctl_*`, never `S` mounts. PDP-1 paces the download with
  `ioctl_wait` from the reader (no buffer, no rewind, OSD dead until the
  tape is consumed); ZX/C64 download into SDRAM and play from there. Our
  tape adapter already reads blocks, gives rewind for free and holds one
  2048-byte block, so the tape stays on an `S` slot (slot 4). Fallback if
  that misbehaves on the board: an `F` line with `ioctl_wait` pacing, the
  PDP-1 shape.

## Phase 4 - board (needs Ronny's go for every build and flash)

- [ ] `1560&`: floppy boot from slot 0. Then drive 1 from slot 1.
- [ ] Winchester: mount `WD0.IMG`, read known sectors with OPCOM and compare
      bytes against the Verilator run (`ND120_WD_IMG`, same CHS->LBA); write
      a sector, unmount, verify the file changed on the Linux side.
- [ ] Unmount/remount while idle; a mount while a request is pending.

## Phase 5 - close out

- [ ] `Verilog/fpga/mister/README.md`: storage section rewritten from
      "roadmap" to "how it works", with the slot map and image sizes
      (floppy 315 392 B / >= 1 261 568 B, WD 8x9x1024 cylinders x 1024 B).
- [ ] Handoff updated; this plan deleted when everything above is green.

## Decided by Ronny (01-SEP-2026)

- Two Winchester slots (WD0, WD1), matching the card. SMD is not built.
- Paper tape: one file, one slot.

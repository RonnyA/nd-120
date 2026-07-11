# ND bus devices - master TODO (tape-400, floppy, SD-FAT)

Created 11-JUL-2026. Supersedes the planning half of
docs/sd-bpun-device-plan.md (which stays as the research/spec reference:
pins, core evaluation, register semantics, CDC strategy, card recipe).
Goal: real device emulation for the FPGA ND-120 behind the authentic
external ND-100 bus interface, fed by files on a FAT-formatted microSD.

Reference implementations (read these before coding each phase):
- Verilog/simDevices/NDDevices.cpp - WORKING C models used by runSim:
  papertape reader (device 400), floppy PIO, ident/interrupt handling.
  The Verilog devices must match this behavior (runSim golden gates it).
- Verilog/simDevices/NDBus.cpp proccess_bif_signal() - the external-bus
  handshake FSM (BAPR/BIOXE/BINPUT/BINACK/BDAP/BDRY/OUTIDENT, active-low
  BD bus). The Device Bus Interface is a Verilog port of exactly this.
- nd100x emulator floppy code - semantics source for the floppy
  controller (Ronny points to the exact files when P3 starts).
- RetroCore NDBusPapertapeReader.cs + ND-06.015.02 appendix - tape-400
  register spec (quoted in sd-bpun-device-plan.md).
- SIGNAL flow note: device 400 uses the GENERAL IOX bus path (CS
  000506-000510) - no vectored dispatch, unaffected by the closed 300$
  issue (docs/serial-binload-300.md).

## Phase 0 - SD card + FAT (IN PROGRESS - parallel workstream)

Milestone 1 committed 11-JUL-2026 (8b3da27); development CONTINUES in a
parallel session (uncommitted work in Verilog/SD-FAT/ and
fpga/tang-nano-20k/sd-fat-test/: sd_fat_rewrite.v cluster-chain
reallocation, sd_fat_check.v, COPY and WRBLK1 1-kiloword block writes,
interactive `make console` sim). Do not modify those trees from this
workstream while that session is active.

- [x] Verilog/SD-FAT/ library (WangXuan95 core vendored, LICENSE kept):
      sd_reader, sd_file_reader, sdcmd_ctrl, sd_writer + sd_card_model tb
- [x] fpga/tang-nano-20k/sd-fat-test/ standalone project: read BPUN from
      FAT microSD, hex-dump over UART
- [x] 3 self-checking tbs registered (suite = 27, all green)
- [ ] Finish the write path (COPY / block writes / fsck-gated rewrite) -
      owned by the parallel SD-FAT session
- [ ] Hardware validation on the Tang microSD slot (real card, real dump)
      - the milestone-1 acceptance from sd-bpun-device-plan.md
- [ ] LIBRARY REFACTOR (after sd-fat-test is finished): fold the
      test project's reusable logic into the generic library so the
      ND-120 devices consume ONE clean interface. Rules:
      - Verilog/SD-FAT/ is the home of everything generic (card init,
        FAT mount, file find/read/write, block read/write, status);
        board glue (pins, UART menu, LEDs) stays in fpga/<board>/
      - NOTHING SD/FAT-related goes into the CPU trees:
        DELILAH-CPU/ (CGA), DECODE-GateArray/ (DGA), CPU-BOARD-3202/
        stay pure ND-120 hardware; devices talk to the library through
        a byte/word-stream port on the ND-BUS-DEVICES side
      - target interface for devices: open(fixed name)/rewind,
        stream-read bytes, block read/write by 1KW block number
        (the tape-400 and floppy cores program against this, not
        against sd_reader directly)
      - the SD card is SHARED BY ALL DEVICES (one physical slot,
        many clients): nd_storage gets N client ports with per-client
        file state (name, first cluster, position) in front of ONE
        sector engine, arbitrated round-robin at block granularity;
        the tape byte stream buffers a block at a time so it cannot
        starve floppy/HDD block requests

## Phase 1 - Device Bus Interface (DONE 11-JUL-2026, commit ba27bc5)

- [x] ND-BUS-DEVICES/BUS-IF/circuit/ND_BUS_SLAVE.v - ports
      NDBus.cpp proccess_bif_signal() to a sysclk FSM. Two latent
      C-model issues FIXED in the port: BINT10-13 are actually driven
      (the C '== 1' mask bug never asserted them - devices worked by
      polling only), and an IDENT answer takes priority on BINACK over
      the stale IOX direction from the level-code address (the C model
      would have taken the READ branch; its IDENT path was never
      exercised).
- [x] Device parameters (BASE_ADDR/IDENT_CODE/INT_LEVEL) + ident
      daisy-chain grant ports on each core; decode inside the core
      like the C model's IsInAddress
- [x] ND120_TOP.v: devices instantiated behind ND120_VERILOG_DEVICES,
      wired-AND onto the active-low bus inputs; builds are bit-identical
      with the define off (baseline compile verified)
- [x] tb: scripted bus master, IOX read/write + IDENT, TWO tape cores
      proving chain priority + clear-on-IDENT; registered in the suite
- [x] Semantics reference doc: docs/nd100x-device-semantics.md
      (interrupt layers, IDENT rules, floppy PIO/DMA + SMD register
      maps, C-model hacks flagged)

## Phase 2 - Tape reader, device 400 (Verilog/ND-BUS-DEVICES/TAPE-400/)

## Phase 2 - Tape reader, device 400 (Verilog/DEVICE-TAPEREADER/)

- [x] Register core per NDDevices.cpp: ND_TAPE_400.v (IOX 400 read data
      clears RFT, 402 status bit3, 403 control bits 0/2/3/4; ident 02,
      level 12; byte source is a port). Divergence from the C model,
      on purpose: pending = intEnabled AND readyForTransfer evaluated
      continuously (level-sensitive, matches nd100x PID mirroring and
      real hardware) instead of the C model's stale latched flag.
- [x] Byte source A (sim): TAPE_BYTE_* ports on ND120_TOP served by
      process_verilog_tape() in NDBus.cpp; runSim `make compile
      VERILOG_TAPE=1` swaps the C papertape out (addDevices skips it)
- [x] Acceptance gate A PASSED 11-JUL-2026: `make test-tape` (top-level
      Makefile) boots INSTRUCTION-B via '400$' with the C model and the
      Verilog device - console tails and loaded RAM identical; the
      INSTRUCTION VERIFY banner prints and the '>' monitor prompt comes
      up in both. Golden console (default build) re-verified unchanged.
- [ ] Byte source B (hardware): SD-FAT file reader streaming a .BPUN
      from the card (fixed filename first, per the core's limitation);
      SDRAM full-preload per the cache design rule
- [ ] Tang integration: device instantiated on the new bus interface
      (the ifdef + wired-AND path in ND120_TOP is ready for it)
- [ ] ACCEPTANCE: '$' at the OPCOM prompt boots INSTRUCTION-B from the
      microSD on silicon (ALD already straps to 400 - zero CPU changes)

## SDRAM disk-image cache (design rule, lands with Phase 3)

The SD card is slow; the Tang SDRAM is 8 MB and the ND-120 memory
partition uses only part of it. Use the spare SDRAM as the disk layer:

- CACHE UNIT = ONE BLOCK = 2048 bytes (1 kiloword = 4 SD sectors),
  chosen to map 1:1 onto the SD card's block read/write interface
  (the nd_storage 1KW-block port, same framing sd-fat-test WRBLK1
  already uses). ONE block unit through the whole stack: device
  request = cache block = nd_storage block = 4 consecutive SD
  sectors - a cache fill or write-through is exactly one nd_storage
  block transfer, no partial blocks, no unit conversion anywhere
- Floppy (~1.2 MB image = ~600 blocks): PRELOAD the whole image
  block-by-block into SDRAM at mount, serve ALL reads from SDRAM (no
  eviction ever needed), WRITE-THROUGH every written 2048-byte block
  to SDRAM + SD card so the card is always consistent (safe to pull
  anytime)
- HDD/SMD later (37-75 MB, does not fit): real cache with per-block
  tags (2048-byte blocks) over the same SDRAM region, same
  write-through policy
- SDRAM map: fixed partition - low region ND-120 main memory (as
  today), high region disk-image slots; document the map in one place
- sdram18.v gets a second (device) port; ARBITRATION RULE: CPU memory
  traffic has absolute priority, the device port takes leftover cycles
  only - a floppy preload must never stall a CPU access
- Tape/BPUN: ALSO 100% cached - preload the whole .BPUN into SDRAM at
  open (biggest BPUN in the repo is ~46 KB = ~23 blocks, loads in a
  blink), then the byte stream is served entirely from SDRAM;
  read-only, so no write-through path needed; "rewind" = reset the
  SDRAM read pointer, no card access at all
- nd_storage clients then see the SAME picture for every device:
  SDRAM-backed (tape = byte stream, floppy/HDD = block port), with
  the SD card only touched at preload/mount and for write-through

## Phase 3 - Floppy (PIO first)

- [x] Semantics extracted (docs/nd100x-device-semantics.md) and core
      written: ND-BUS-DEVICES/FLOPPY/circuit/ND_FLOPPY_PIO.v -
      registers, geometry, command set, errors, auto-increment,
      completion-delay interrupt; tb through the bus slave with an
      image-backed disk model (registered in the suite).
      NOT ported (ask Ronny): RSR1 "magic" diagnostic bits, autoload
      boot blob, deleted-sector shadow array.
      The disk backend is a port (disk_*/dbuf_*): sim harness serves
      an image; hardware serves the SDRAM-cached image (2048-byte
      blocks, write-through per the cache design rule).
- [ ] Read-only floppy: FAT image file (.IMG) on the SD card as the disk
- [ ] Write support: wire sd_writer.v path (writer tb already passing) -
      in-place writes to a pre-allocated contiguous image file
      (recommended approach from sd-bpun-device-plan.md - no FAT
      allocation logic in hardware)
- [ ] Acceptance: boot 1560 floppy load on silicon (ALD 1560 exists in
      the switch table); later SINTRAN/tools from floppy

## Phase 4 - Later

- [ ] Floppy DMA variant (NDDevices.cpp marks it TBD - semantics from
      nd100x)
- [ ] SMD/HDD controller on the same bus shell (mass-storage loader path
      CS 002147 MASS already in microcode; ALD 500/1540)
- [ ] FAT robustness: FAT32 first-cluster fix or replacement core,
      filename selection UI (console command?), multiple images
- [ ] Basys3 port via PMOD microSD (pins in sd-bpun-device-plan.md)

## Standing constraints

- Every new tb self-checking + registered in tests/run_all_tests.sh
- Golden gates (trace compare, runSim console, vtest) must stay green at
  every phase - the Verilog tape device replacing the C model in runSim
  is itself gated by the console golden
- Clock-enable discipline: no new clock domains except the SD side
  behind its FIFO; nothing register-driven as a clock (P5 zero-warning
  goal stands)
- GPL-3.0 vendored core: approved by owner for SD-FAT (LICENSE file in
  tree)
- SD/FAT code lives ONLY in Verilog/SD-FAT/ (generic library) and
  fpga/<board>/ (board glue) - never in DELILAH-CPU/, DECODE-GateArray/
  or CPU-BOARD-3202/

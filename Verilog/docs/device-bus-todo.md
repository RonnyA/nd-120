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

## Phase 1 - Device Bus Interface (reusable, Verilog/ND-BUS-DEVICES/)

- [ ] Port NDBus.cpp proccess_bif_signal() to a Verilog bus-slave FSM:
      BAPR/BIOXE/BINPUT/BINACK/BDAP/BDRY handshake, OUTIDENT/ident
      daisy-chain, active-low BD_23_0_n bus, interrupt-level lines
- [ ] Parameterized device shell: device number, ident code, interrupt
      level; register read/write strobes toward the device core
- [ ] Un-tie the external bus inputs in ND120_TOP.v / the Tang top
      (currently tied off) behind an ifdef so boards without devices
      stay identical
- [ ] Unit tb: scripted bus master driving IOX read/write/ident against
      a dummy device; register in tests/run_all_tests.sh
- [ ] CDC note: bus side runs in the CPU sysclk domain; SD side keeps
      its own clock + async FIFO (per sd-bpun-device-plan.md)

## Phase 2 - Tape reader, device 400 (Verilog/DEVICE-TAPEREADER/)

- [ ] Register core per NDDevices.cpp/NDBusPapertapeReader.cs:
      IOX 400 read data (clears RFT), 402 read status (bit 3 = ready),
      403 write control (bit 0 int enable, bit 2 activate, bit 4 clear);
      ident code 2 octal, level 12
- [ ] Byte source A (sim): file-backed model so runSim can swap the C
      papertape for the Verilog device - acceptance: runSim console
      golden byte-identical with the Verilog device serving the BPUN
- [ ] Byte source B (hardware): SD-FAT file reader streaming a .BPUN
      from the card (fixed filename first, per the core's limitation)
- [ ] Tang integration: device instantiated on the new bus interface
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
- nd_storage clients then see: tape = SD byte stream (unchanged),
  floppy/HDD = SDRAM-backed block port with SD write-through behind it

## Phase 3 - Floppy (PIO first)

- [ ] Extract the floppy PIO register/command semantics from
      NDDevices.cpp + the nd100x floppy emulator (bus-interface flavor)
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

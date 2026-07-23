# HANDOFF - SD-FAT / nd_storage workstream (11-JUL-2026)

Resume point for the storage workstream. Read this top to bottom, then
continue at "NEXT ACTIONS". Everything referenced lives relative to the
repo root /mnt/e/Dev/Repos/Ronny/nd-120/.

## The four documents that govern this work

1. Verilog/docs/nd-storage-interface-spec.md - the OWNER'S SPEC (binding):
   N client ports, 2048-byte blocks (1 kiloword = 4 SD sectors), SDRAM
   preload, round-robin no-queue arbiter, write-through-before-done.
2. Verilog/docs/nd-storage-spec-validation.md - 3 factual findings +
   16 gap decisions (folded into the design).
3. Verilog/docs/nd-storage-design.md - THE PLAN OF RECORD: module specs,
   port lists, CDC rules, byte order, 10-step implementation order with
   live status block. Implementers code from this.
4. Verilog/docs/sd-speed-plan.md - the SD speed ladder (rungs a+b done).

Also: Verilog/SD-FAT/README.md (library state + the MANDATORY WRITE-PATH
SAFETY POLICY at the top), Verilog/fpga/tang-nano-20k/sd-fat-test/
CARD-SETUP.md (card prep), Verilog/docs/nd120-parity-refactor-order.md
(executed by the CPU workstream -> ND_SDRAM_PACK16, commit d26fd66).

## State of the 10-step nd_storage plan

- Step 1 DONE  nds_sync.v (CDC primitives)            gate test-nds-cdc
- Step 2 DONE  nd_storage_engine.v read path + arbiter gate test-nds-engine
- Step 3 DONE  engine write path vs real sd_writer     gate test-nds-write
- Step 4 DONE  nd_storage_mount.v + nd_storage.v top   gate test-nds-mount
               (7 clients: TAPE.BPUN, FLOPPY1/2.IMG preloaded,
               SMD0-3.IMG = open_err until Phase 4; PRELOAD_MASK param)
- Step 5 DONE  nd_storage_fatchk.v contiguity checker behind
  SDFAT_STORAGE_CHECK; gates test-nds-fatchk-unit + test-nds-fatchk
  registered and green; mount M_CHK live; fragmented-image case in
  make_storage_image.sh; design doc status block updated by the
  implementer.
- Step 6 DONE  Verilator system gate; registered SD-FAT/sim ::
  test-storage. nd_storage_vtop.v (full stack, resolved SD lines, no
  'z'; clients 0..3, client 3 inside PRELOAD_MASK = missing-file case)
  + test_nd_storage.cpp (C++ card model from test_sd_fat.cpp with the
  illegal-write assertion tightened to file-data-sectors-only + C++
  nds_mem_model-contract mem model; 27.03/23.04 MHz). Acceptance
  1/2/3/5 all in one program: preload byte-exact, behavioral n_blocks,
  3-way concurrency (zero SD traffic), write-through with the card-
  first/SDRAM-second ordering measured, injected CMD24 failure (SDRAM
  intact, card unchanged, open_ok up, retry OK), missing file,
  out-of-range with zero traffic; post-run fsck in C++ (boot/dirs/
  chains + whole-image compare) AND fsck.vfat -n in the Makefile.
  make_storage_image.sh now also emits a self-verified
  nds_storage_full.img (3001/12288/8192 B files, SMD0.IMG absent).
  Gate first ran green against the clean-room sd_file_reader.v.
  FLAG for steps 7/8: never WRITE the partial tail block of a file
  whose size is not a 2048 multiple - the 4 CMD24s would spill past
  the cluster chain into the next file (tape is read-only; floppy/SMD
  images are block multiples).
- Step 7 DONE  nd_storage_tape_adapter.v (spec section 5, design doc 2.5);
  gate test-nds-tape registered and green. Pin-for-pin ND_TAPE_400 byte
  port (byte_req/byte_valid/byte_data/source_rewind) + one client port +
  open_start pulse; single clock clk_cpu; EOF/not-open = silence with
  zero traffic; rewind = position 0, buffer dropped, in-flight fetch
  discarded; c_err = silent + retryable. READ-ONLY by construction
  (c_wr/c_buf_rdata tied 0) - the step-6 tail-write FLAG holds trivially.
  Two-tier tb: scripted stub (poisoned tail, boundary/rewind/err cases)
  + the real stack on client 0 vs nds_storage.img (whole-file byte
  compare, EOF silence, rewind re-read).
- Step 8 DONE  nd_storage_floppy_adapter.v (design doc 2.6 AS-BUILT);
  gate test-nds-floppy registered and green. RETARGETED 11-JUL (owner
  interview) to ND_FLOPPY_DMA's backend, NOT ND_FLOPPY_PIO's sector
  port (1560& mass boot is the proven path). NOTE: the device SOURCE
  contract differs from the interview guess - it is one logical SECTOR
  per request (disk_req/wr/lsect[15:0]/format[1:0]/drive[1:0]/
  wordcount[10:0] -> disk_done/disk_err + dbuf_addr/wdata/we/rdata),
  not disk_start/blkaddr1/blkaddr2/unit; section 2.6 documents the
  real thing. Parameter DRIVE picks the served drive (two instances =
  FLOPPY1/2.IMG on clients 1/2, outputs OR-combined; mismatched drive
  = total silence). Local 1024x16 buffer doubles as a one-block cache;
  writes are RMW with the step-6 tail rule as a hard gate
  ((block+1)*2048 <= size_bytes); every failure = disk_done+disk_err,
  retryable, never a wedge. Two-tier tb: scripted stub/driver with a
  full expectation-shadow after every write (RMW preservation) + the
  real stack on client 1 vs nds_storage.img (card.mem verified at
  first_sector, disk-port read-back, whole-4MB stray-write shadow).
  Other interview outcomes: SMD images are 75 MB -> SMD stays Phase 4;
  step 10 ND120_TOP/Tang integration is the DEVICE workstream's (we
  deliver a black box + written handoff); order 6 -> 7 -> 8 stands.
- Step 9 DONE  SDRAM board glue; gate fpga/tang-nano-20k/sdram-bridge/sim
  :: test-storage-port registered and green (existing test/test-pack16/
  test-pack16-part re-run green UNMODIFIED - the measured CPU protocol
  timing is untouched). New define ND_STORAGE_PORT (requires
  ND_SDRAM_PACK16; only the gate and the future Tang storage build set
  it - every existing build is bit-identical without it).
  sdram18.v: new acc32/din32/dout32 ports = full-location access (rd/wr
  with acc32=1 moves the whole 32-bit location at addr[21:1]; writes
  drive all four DQM lanes; same 5-cycle machine; acc32=0 identical).
  MEM_RAM_49_SDRAM.v: the section-5.2 mem port verbatim (stor_clk
  domain, mem_start/we/addr/wdata/rdata/busy/done, toggle CDC both
  ways); grants ride the SAME slots as refresh (B_POST after each CPU
  access, B_TAIL absent-row accesses, B_IDLE behind the idle_cnt
  watchdog guard) and always sit BEHIND refresh priority. The HALF-WORD
  caveat is closed structurally: the grant issues half-word address
  {1'b1, mem_addr[19:0], 1'b0} - the leading 1 is forced, so a device
  op can never touch the CPU half (tb writes the CPU alias words, fires
  a below-partition device write, proves both sides intact). Con-
  currency proven: 1800+ device ops served during the 2000-access CPU
  replay soak with every access still passing the late-N+4/N+5 checks.
- Step 10: Tang top integration (device workstream's side): define
  ND_STORAGE_PORT, wire MEM_RAM_49_SDRAM's stor_clk/stor_rst_n + mem_*
  group 1:1 to nd_storage's mem port (contract identical to
  SD-FAT/sim/nds_mem_model.v).

## sd-fat-test board program (proven on hardware)

Menu 1=LIST(size/date/cluster) 2=DUMP 3=COPY(creates TEST.TXT)
4=WRBLK1 5=CHECK(fsck-lite) 6/7=IO speed tests (create IO.DAT) H=HELP.
Console 9600 8N1 ttyUSB1; BL616 CLI answers first -> type `choose uart`.
make load auto-finds oss-cad-suite. S1/S2 reset.

- Speed rungs a+b IMPLEMENTED: 13.5 MHz bit clock; menu 6 = CMD25 bursts
  (128 sectors), menu 7 = CMD18 bursts through the MIT sd_writer (the
  file reader mounts/locates; RCA snooped from CMD3 at the top). Sim
  speeds ~1.6 MB/s; expected hardware ~1.1-1.4 MB/s write (was 137 KB/s).
  Since 12-JUL the reader itself is the clean-room MIT sd_file_reader.v
  (13.5 MHz data phase, CMD18 file streaming).
- Bitstream WITH the card-killer fix + bursts: built 11-JUL 13:15,
  build/sd_fat_test_top.fs - gate-approved, NOT yet run on hardware.
  NOTE build/*.json are stale vs a later synth check; make load
  rebuilds automatically.
- Rung c (4-bit bus, ~3 MB/s) researched, not started.

## THE CARD-KILLER (fixed) and the safety policy

sd_fat_rewrite.v S_DIR_W wrote the patched directory sector to the raw
dir_sector INPUT (0 on cold-start create) instead of internal dsec_r ->
CMD24 to sector 0 destroyed a real card's boot sector. Old gates passed
by SEQUENCE MASKING (key 3 before 6 pre-populated the register).
Fix in place + kclust/chain_i widened to 13 bits. Permanent gates since:
card-model illegal-sector assertion (always-on, covers burst blocks),
boot-region byte-identity, fsck, cold-start plans (+plan=cold),
big-geometry FAT32 gate (test-verilator-fat32big). THE POLICY (owner
rule, SD-FAT/README.md top): never load/flash write-capable bitstreams
before ALL FOUR gate classes pass.

## Test registry state

bash Verilog/tests/run_all_tests.sh -> ALL 39 TESTS PASSED (436 s) as of
step 4 (before step-5 additions). SD-FAT/sim targets: test-writer,
test-writer-div1, test-nds-cdc, test-nds-engine, test-nds-write,
test-nds-mount. Heavy manual (unregistered) targets documented in the
sim Makefile headers.

## Uncommitted work (deliberate - owner commits on request)

The whole SD-FAT/nd_storage stretch sits in the working tree: SD-FAT
circuit+sim additions, sd-fat-test burst/menu changes, docs, registry.
The parallel DEVICE workstream commits independently (floppy/SMD/DMA
commits c6c7565..74d56a3 are theirs; sd_file_reader.v/sd_writer.v have
SHARED mods - coordinate before committing). ND-BUS-DEVICES/*_tb.v
local edits are theirs, not ours.

## Loose ends at handoff

1. Step 5 completed in-session (11-JUL afternoon, after two
   session-limit interruptions); registry entries verified.
2. TWO STALE vvp processes (sd_fat_test_tb.vvp, PIDs from 11-JUL
   morning) burn CPU; owner permission required to kill (standing rule:
   never kill processes without explicit approval).
3. Hardware validation pending: fast bitstream on a fresh card
   (CARD-SETUP.md; sequence 1,5,2,3,6,7) - expect ~8-10x speed lines.
4. Card-detect: none (no CD pin); detection is per-command. Idle-time
   CMD13 poller sketched as a future nicety (queue after step 8).
5. RESOLVED 12-JUL-2026: the vendored GPL reader files were replaced by
   a clean-room MIT `sd_file_reader.v` (public SD/FAT specifications;
   13.5 MHz data phase, CMD18 streaming; identical interface, all
   registered gates green). The whole SD-FAT library is now project MIT
   code; the old files and their license text are deleted.
6. sd-fat-test build/*.json committed artifacts are large and churn -
   owner may want them out of git (raised 10-JUL, no decision).

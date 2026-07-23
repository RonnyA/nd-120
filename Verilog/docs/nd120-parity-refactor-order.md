# Work order: refactor parity out of main-memory storage (16-bit words in SDRAM)

For the ND-120 CPU/memory workstream. Goal decided 11-JUL-2026 by the
project owner. Companion docs: Verilog/docs/nd120-dram-memory.md (the
bridge design and the original store-18-bits decision),
Verilog/docs/nd-storage-design.md (the storage layer that consumes the
freed half of the SDRAM), Verilog/docs/device-bus-todo.md (master plan).

## 1. The goal in one paragraph

Today the Tang Nano 20K SDRAM bridge stores ONE 18-bit ND word (16 data
+ 2 parity) per 32-bit SDRAM location: 2M locations = 4 MB of CPU
memory consuming the ENTIRE 8 MB chip, wasting 14 bits per location.
Refactor the memory path so only the 16 DATA bits are stored, packed
TWO ND words per 32-bit location. Then 1M locations (half the chip)
still give the CPU its full 4 MB main memory, and the other half
(1M x 32 = 4 MB) becomes the disk-image/cache region for nd_storage.
Nobody loses memory; the wasted bits pay for the disk cache.

## 2. Why parity is the blocker, and what to actually find out

Parity in this machine is NOT a pure function of the data: the CPU can
deliberately write BAD parity (self-test exercises the parity-error
machinery), so a store-nothing design cannot simply recompute parity on
read - the round trip would come back "correct" and the test would see
no error.

BUT: the current Verilog does not honor this anyway. AM29833A.v has the
parity path STUBBED (assign ERR_n = 1; assign PAR_OUT = 0 - listed in
Verilog/TODO.md as a high-priority suspect for the 7/14 self-test
failures). The "must store parity" rule is inherited analysis, not
implemented behavior. So the first task is INVESTIGATION, not code:

- What does the CPU self-test actually do with parity? Read the
  microcode/self-test documentation (the nd120uc sister repo at
  /mnt/e/Dev/Ronny/nd120uc has the EPROM-validated microcode source and
  bitfield docs; also docs/boot-golden-spec.md and the self-test
  analysis notes). Determine: does any test (a) write bad parity and
  expect to READ BACK the stored parity bits, or (b) write bad parity
  and expect the parity-ERROR FLAG/interrupt to fire on readback, or
  (c) merely exercise the parity generate/check datapath without
  storing? Which addresses does it touch?
- What does SINTRAN / normal software expect from parity at runtime?
  (Likely: parity errors raise a memory-error condition; nothing reads
  parity bits as data.)

## 3. Acceptable implementation shapes (pick based on section 2 findings)

a. COMPUTED PARITY: store 16 bits; generate parity on write path,
   check on read path (implement the real AM29833A behavior while at
   it - that TODO is overdue). If the self-test only needs the ERROR
   path (case b above), add a small "bad parity written here" shim:
   a tiny BRAM/CAM of the last N deliberately-bad-parity writes, or a
   test-mode flag, sized to what the microcode actually does. If the
   self-test truly requires case (a) readback semantics, then:
b. SIDE-BAND WINDOW: a small on-chip BRAM stores the 2 parity bits for
   a LIMITED address window covering the self-test's parity targets
   (findings from section 2 tell you the window). Outside the window,
   computed parity. 828 Kbit BSRAM total on the GW2AR-18, most already
   budgeted - keep this under a few Kbit.
c. (Fallback, discouraged) full side-band parity region in SDRAM -
   doubles accesses, threatens the bridge's measured protocol timing.
   Only if (a) and (b) are both impossible; escalate to the owner
   before choosing this.

## 4. Hard constraints

- The SDRAM bridge protocol timing is MEASURED and hard-won (25k-access
  trace, N+4 data deadline, N+11 next-access rule - see
  docs/nd120-dram-memory.md and the sdram-bridge tb). The 2-per-word
  packing must not change observable CPU-port timing. Note the packing
  makes two ADJACENT ND words share one SDRAM location: a 16-bit CPU
  write becomes a read-modify-write UNLESS the controller uses the DQM
  byte lanes to write only the addressed half - sdram18.v drives all
  four DQM lanes today; extend it to lane-selective writes (the SDRAM
  die supports per-byte masks; the sim model already models DQM).
  Lane-masked writes keep single-access timing - no RMW needed.
- Verilator remains the reference: latch-vs-FF golden compare and the
  runSim golden console must stay green. The refactor must sit behind
  a build define so non-Tang builds are bit-identical.
- Boot-time memory sizing must report 4 MB (BANK0+BANK1 as today) with
  the define on; the physical mapping folds both ND banks into
  addr[20]=0 (1M locations). addr[20]=1 is RESERVED for the storage
  region - its port contract is nd-storage-design.md section 5.2
  (already being implemented by the storage workstream; coordinate the
  define name: ND_STORAGE_PARTITION currently gates the interim
  2 MB split - this refactor upgrades it to 4 MB + 4 MB).
- Registered self-checking testbenches for everything new
  (TB_RESULT: PASS, registry in tests/run_all_tests.sh), including a
  parity-behavior tb that encodes whatever section 2 discovered as the
  contract (so the semantics are pinned by test, not by folklore).

## 5. Sequencing and the bigger picture

- The storage workstream proceeds NOW with the interim partition
  (CPU 2 MB) so device bring-up is not blocked; this refactor flips
  the partition to 4 MB + 4 MB when it lands. nd_storage reads its
  region base from parameters - nothing on that side moves.
- Forward-looking requirement from the owner: if SD-card transfer
  speeds cannot be raised far enough, the system will need MORE
  caching, especially for HDD/SMD image emulation (Phase 4:
  tag-based caching of images larger than their slots). Therefore DO
  NOT hardcode the 4 MB/4 MB boundary: make the CPU/storage split a
  parameter (bank/row granularity), so a future build can trade CPU
  memory for cache (e.g. 2 MB CPU + 6 MB cache) without another
  refactor. Design the address decode accordingly.

## 6. Deliverables checklist

1. Section-2 findings written to docs/nd120-parity-analysis.md
   (what the self-test does, with microcode line references).
2. Chosen shape (a/b/c) + implementation in the memory path
   (AM29833A.v real parity logic included).
3. sdram18.v lane-masked 16-bit writes; bridge packing; define-gated.
4. Boot sizing reports 4 MB; self-test parity tests behave per the
   pinned contract; no regression in the 7/14 baseline (ideally the
   parity fix IMPROVES it - that is a hoped-for side effect).
5. All existing gates green (sdram-bridge protocol replay, latch/FF
   compare, runSim golden); new parity tb registered.
6. Partition boundary parameterized per section 5.

# To: nd-120 FPGA main session
# From: parity-refactor session
# Re: defines and parameters introduced by the 16-bit packed SDRAM refactor (commit d26fd66, branch clock-enable-fix, pushed 11-JUL-2026)

## The one new define

**`ND_SDRAM_PACK16`** - packed main memory for the Tang Nano 20K SDRAM
backend. Store 16 DATA bits only, TWO adjacent ND words per 32-bit SDRAM
location, DQM lane-masked single-access writes (no read-modify-write, no
change to the measured N+4/N+11 protocol timing), parity COMPUTED on the
read path (odd parity, AM29833A convention - CORR_n always "correct").
CPU keeps its full 4 MB (BANK0+BANK1 fold into SDRAM locations with
bit 20 = 0); the upper 4 MB (location bit 20 = 1) is RESERVED for the
nd_storage disk-image cache and is physically unreachable from the CPU
port (its address MSB is hardwired 0 in the bridge).

Semantics contract: `Verilog/docs/nd120-parity-analysis.md` section 6
(microcode-proven: the self-test never touches memory parity; runtime uses
only the PES/PEA/IIC error machinery). Deliberately-bad-parity writes are
ABSORBED in this mode - data round-trips, parity comes back computed-good.

## Where it is set

- `Verilog/fpga/tang-nano-20k/src/tang20k_defines.v` - **ENABLED for the
  Gowin build** (right after `MAIN_RAM_SDRAM`). The next bitstream carries it.
- `Verilog/fpga/tang-nano-20k/sim/Makefile` - added to `DEFS` (the full-boot
  pre-synth sim mirrors tang20k_defines.v). vtest PASSES with it on
  (OPCOM deposit 22/054321 readback through the packed path).
- Referenced ONLY by files under `fpga/tang-nano-20k/` (sdram18.v,
  MEM_RAM_49_SDRAM.v, their tb). Verilator golden / Basys3 / runSim never
  see it - non-Tang builds are bit-identical by construction.
- Only meaningful together with `MAIN_RAM_SDRAM`. Without the define, the
  bridge/controller compile to the OLD 18-bit one-word-per-location
  behavior, byte-for-byte (the legacy tb still passes unchanged).

## The new parameter

**`MEM_RAM_49_SDRAM #(CPU_PART_ROWS)`** - CPU/storage split at ND-row
granularity, only active in pack16 mode. Units: 1K-ND-word rows
({bank, row[9:0]}, 0..2048). Default **2048 = full 4 MB CPU**. Rows at or
above the value report ABSENT (reads 0, writes dropped, like an
unpopulated bank), so boot-time memory sizing shrinks accordingly - e.g.
1024 = 2 MB CPU + 6 MB cache. Keep it a multiple of 1024 so whole ND banks
appear/disappear. Do NOT hardcode the 4/4 boundary anywhere downstream;
this parameter is the owner-mandated knob (work order section 5).

## Relation to ND_STORAGE_PARTITION

`ND_STORAGE_PARTITION` (the interim "give up BANK1 for 2 MB CPU" split from
nd-storage-design.md) was never implemented in RTL and is now SUPERSEDED:
with `ND_SDRAM_PACK16` the storage region exists WITHOUT sacrificing CPU
memory. Storage-side addressing is unchanged from the section 5.2 contract:
the device port addresses 32-bit locations `{1'b1, mem_addr[19:0]}` (upper
1M locations). Note sdram18.v's CPU-side `addr` in pack16 mode is a 22-bit
HALF-WORD address ([21:1] = location, [0] = half); a future 32-bit device
port should use the full-location view, not the half-word view.

## Tests that pin all of this (registered in tests/run_all_tests.sh)

- `fpga/tang-nano-20k/sdram-bridge/sim :: test` - legacy 18-bit mode,
  must stay green forever (proves the define-off path is untouched)
- `:: test-pack16` - packed contract: adjacent-word independence (lane
  masking), computed parity, bad-parity absorption
- `:: test-pack16-part` - CPU_PART_ROWS=1024 build: partition boundary,
  absent-row semantics, and refresh cadence under absent-row traffic

## Two silicon-relevant fixes that rode along (both inside the bridge)

1. DQM is restored to 4'b0 right after each masked write burst - read DQM
   latency is 2 cycles, so a stale mask would blank the next read's data
   window on real silicon (the behavioral sim model does not catch this).
2. B_TAIL (absent bank/row access) now hosts a refresh slot - a run of
   absent-row accesses previously starved refresh past the 15 us cadence
   (caught by the partition tb, gap reached 20 us).

## Stale-doc corrections you should trust going forward

- AM29833A.v is NOT a stub (TODO.md entry corrected) - real parity since
  MAR-2025.
- The self-test cannot fail because of memory parity; STERR is at octal
  o2156 (not o1134) and is a display/halt loop, not a counter.
- nd120-dram-memory.md section 6's "rejected: recompute parity" note is
  superseded; boot-golden-spec's Phase 4 loop is self-test TEST 6
  (LC/shift), not a parity test.

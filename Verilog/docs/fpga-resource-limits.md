# ND-120 FPGA resource limits & optimization levers (Tang Nano 20K)

Last updated 16-JUL-2026. Board = Tang Nano 20K, Gowin **GW2AR (GW2A-18C)**.
Numbers are from the OSS flow (yosys -> nextpnr-himbaechel). All paths absolute.
This is the board-independent-ish summary; the detailed analyses are:
- `/mnt/e/Dev/Repos/Ronny/nd-120/Verilog/docs/fpga-utilization-breakdown.md`
- `/mnt/e/Dev/Repos/Ronny/nd-120/Verilog/docs/fpga-utilization-reduction-plan.md`
- `/mnt/e/Dev/Repos/Ronny/nd-120/Verilog/docs/fat-reader-slimming-plan.md`
- `/mnt/e/Dev/Repos/Ronny/nd-120/Verilog/fpga/tang-nano-20k/BSRAM-BUDGET.md`
  (older BSRAM-only budget; its "logic has huge headroom" premise is now STALE -
  see below).

## Current state (why the OSS flow can't place)

Ground truth, the repo's own failing run
(`fpga/tang-nano-20k/build/nd120_tang20k_oss-slow-pnr.log`):

| Resource | Used | % | Notes |
|---|---|---|---|
| LUT4 | 18404 / 20736 | **88%** | **the binding constraint** |
| BSRAM (block RAM) | 45 / 46 | **97%** | saturated, but PACKS FINE - not the placement failure |
| RAM16SDP4 (distributed) | 328 / 648 | 50% | LUT-fabric SSRAM |
| DFF | ~53% | | |

nextpnr error: "Unable to find legal placement for all cells." The 45 BSRAM
blocks drop trivially into 46 dedicated sites; the placer dies on the **logic
fabric (LUT4/CLS congestion)**. So: **LUT is what blocks placement now; BSRAM is
the tightest for any FUTURE memory growth.** (The Gowin EDA flow `make gowin`
still builds - it packs differently and produced the on-silicon bitstream.)

## What consumes each resource

**BSRAM (45 blocks):** dominated by the **WCS microcode ROM = 32 blocks (70%)**
(32x IDT6168A_20 4096x4, `CPU-BOARD-3202/circuit/CPU_CS_WCS_21_22.v`). Then MMU
page-table+cache 8, MMU IMS1403 1, and the four storage sector buffers (tape
adapter, engine staging, SD reader secbuf, FAT-check fbuf) 1 each. Main memory =
SDRAM = **0 BSRAM**. CPU register file = distributed LUT-RAM, not BSRAM.

**LUT4 (88%):** the SD-FAT / tape-boot stack roughly **DOUBLED** LUT4 (was 42%
before storage was added). `sd_file_reader` alone ~8930 LUTs (the single biggest
logic block); the whole SD-FAT stack ~13,400 LUTs. The FAT reader is SHARED
infrastructure - one parser for all devices - so adding floppy/SMD/serial is
cheap (per-device adapter ~176 LUTs), the cost is parsing FAT in hardware at all.

## Optimization levers (ranked)

Estimates from the analysis docs; the FAT-reader ones are being implemented as
reversible ifdefs, switched off for the TAPE build only.

| Lever | Saves | Where | Risk / cost |
|---|---|---|---|
| **Drop VFAT long-filename parsing** (`SDFAT_NO_LFN`) | ~1800 LUT | `SD-FAT/circuit/sd_file_reader.v` | none - BOOT.BPUN is an 8.3 name; the only weight we carry over the WangXuan95 reference reader |
| **Drop contiguity check** (`SDFAT_NO_STORAGE_CHECK`) | ~1177 LUT | `nd_storage_fatchk` (existing ifdef) | safe for TAPE (sequential read follows the FAT chain already); only matters for random-access SMD on a fragmented file |
| **Drop the card-write engine** (`sd_writer`) | ~1081 LUT | `nd_storage.v` | loses floppy/SMD writeback until re-enabled |
| **CPU-boot-only bitstream (drop the storage stack)** | ~-4800 LUT, -3 BSRAM | Tang top / defines | returns to the proven-placeable 41/46 / 38% CLS state; reversible |
| **WCS microcode ROM repack** | -8 BSRAM (44->36) | WCS store | med-high risk (sequencer timing; must be bit-exact + sim-gated). BSRAM-only - does not help the LUT blocker |
| `N_CLIENTS` 7->1 (single tape client) | some LUT/CLS | nd_storage | relieves the CLS congestion co-blocker |

Key facts the levers turn on:
- **Subdirectory traversal does NOT exist** in our reader (root-only already) -> that lever = 0 LUT.
- **Dropping FAT32 saves ~0** - the 32-bit cluster/sector datapath is used for FAT16 too.
- **BSRAM relief alone will NOT place it** - both BSRAM and LUT are at the wall; you must trim LUT (storage logic) to place.
- **Reading in order (tape) already handles fragmentation for free** - `sd_file_reader` walks the FAT chain (`sd_file_reader.v:37`). The contiguity check protects the higher `nd_storage_engine` layer, which addresses blocks by arithmetic (`first_sector + N`, `nd_storage_engine.v:485`) for cheap random access (the SMD path), not the reader.

## Device status (what is proven, and where)

| Device | Verilator (sim) | Tang silicon | Notes |
|---|---|---|---|
| Tape reader (ND_TAPE_400 over SD-FAT) | validated (`make run`, `make test-tape`) | PROVEN (serves 400$ bytes) | the only device in the Tang synth today |
| Floppy (DMA floppy @1560) | validated (`make run-floppy`; gate `test-floppy-stdin`, part of `make test-full`) | not synthesized on Tang | test diskette `ND-BUS-DEVICES/testdata/210523I01-XX-01D.img`; boot with `1560&` |
| SMD hard disk @1540 | sim only (`test-smd`, `test-nds-*`) | not synthesized on Tang | needs random access -> keeps the contiguity requirement |

To test floppy boot in Verilator yourself:
```
cd /mnt/e/Dev/Repos/Ronny/nd-120/Verilog/runSim
make run-floppy      # then type 1560& at the '#' prompt
```

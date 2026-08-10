# PLAN: runtime FAT-chain walking in nd_storage (replace the contiguity fence)

Date: 07-AUG-2026. Direction from Ronny: stop REQUIRING contiguous files and
stop merely CHECKING for them - walk the FAT chain per access, correctly, and
let the block cache absorb the cost ("yes it's slow, but that's why we have
caching"). This also frees the mount-time checker's logic, which is what the
tape+floppy+WD Tang build needs (that build overflows the device by 114 logic
cells with the checker in - see the resource notes in
`Verilog/fpga/tang-nano-20k/src/tang20k_defines.v`).

## What changes

1. **`Verilog/SD-FAT/circuit/nd_storage_engine.v`** - the two card-sector
   computations (`C_SEC_GO` cache fill, `W_SEC_GO` write-through) currently do
   `first_sector[client] + block*4 + sec`, i.e. contiguity assumed. They get a
   RESOLVE step in front:
   - `target_sector_in_file = block*4 + sec`
   - `target_cluster_idx = target_sector_in_file >> log2(cluster_size)`
   - resolve `target_cluster_idx -> cluster` by walking the FAT from the
     nearest known point, then
     `lba = data_start + (cluster-2)*cluster_size + (target_sector_in_file & (cluster_size-1))`
2. **Per-client walk memo** (small regs, no RAM): `(memo_idx, memo_cluster)`
   per client, plus per-client `first_cluster`. Forward target: walk
   `target-memo` steps from the memo. Backward target: restart from
   `first_cluster` (idx 0). Sequential and block-local access - the normal
   case - costs 0 or 1 FAT hops.
3. **FAT hop with NO sector buffer**: one hop = CMD17 of the FAT sector
   holding the current cluster's entry
   (`fat0_sector + (cluster*ENTSZ)/512`, ENTSZ 4 for FAT32 / 2 for FAT16),
   capturing ONLY the entry's 2/4 bytes as the rx stream passes offset
   `(cluster*ENTSZ)%512`. Entry masks and EOC rules exactly as
   `nd_storage_fatchk.v` (FAT16 masked >= 0xFFF7, FAT32 bits[27:0], masked
   >= 0x0FFFFFF7). EOC or entry<2 before reaching the target idx =>
   done+err to the client (honest failure, no wrong-sector I/O).
   Consecutive clusters usually share a FAT sector but we deliberately
   re-read per hop - zero RAM, and the memo makes steady state ~1 hop.
4. **Geometry plumbing**: the mount already latches per-file
   `chk_first_cluster`, `chk_cluster_size`, `chk_fat0_sector`,
   `chk_is_fat32` (currently for fatchk). Capture per-client
   `first_cluster[c]` at that client's `open_ok`; cluster_size/fat0/is_fat32
   are volume-global - latch once. `data_start` needs no new mount work:
   `data_start = first_sector[c] - (first_cluster[c]-2)*cluster_size`
   (cluster_size is a power of two -> shift, no multiplier).
5. **`nd_storage_fatchk.v` + `SDFAT_STORAGE_CHECK`**: the mount-time
   contiguity verdict becomes meaningless (fragmented files are now simply
   correct) - the checker is retired from the builds; the flag can stay for
   a diagnostic build but nothing defines it.
6. **Spec updates**: `docs/nd-storage-interface-spec.md` sections 6/8 drop
   the "contiguous files are REQUIRED in v1" fence.

## Ordering constraint in the engine

The resolve must run BEFORE the write path stages client data is committed to
card (`W_SEC_GO`) and before the cache-fill CMD17s (`C_SEC_GO`). Both paths
already funnel through single-request serialization, so the resolve is a
linear state insertion; the only shared resource is the sd_writer command
port, which the engine already owns in those states.

## Validation

- All 14 storage acceptance tests (`SD-FAT/sim`, `make -C Verilog test`
  subset) must stay green - they use contiguous images, which the walker must
  serve with identical results (memo path).
- NEW test: a deliberately fragmented image (two-extent file: allocate,
  interleave a second file, extend the first) - read across the extent seam
  and verify bytes; write across it and verify the card image. This is the
  test that COULD NOT pass before.
- System gates: DISC-TEMA DU-DI-C clean (sim + Tang), 400$ FILSYS-INV boot,
  `make test` full suite.
- Tang build: tape+floppy+WD (TANG_FLOPPY with TANG_INC_TAPE=1) must FIT once
  fatchk is out; report the new utilization numbers.

## Status (07-AUG-2026)

- [x] engine resolve states + memo + geometry latch
      (`nd_storage_engine.v` F_RES/F_STEP/F_FAT_GO/F_FAT_WAIT, past-EOF
      read-zeros/write-drop handling; `nd_storage_mount.v` exports per-client
      `first_cluster`; `nd_storage.v` wires the geometry through)
- [x] retire fatchk from builds (`sd_fat_features.vh`: the gate now needs
      an explicit `-DSDFAT_FORCE_STORAGE_CHECK`; the fatchk testbenches
      build with it forced so the diagnostic keeps its coverage)
- [x] fragmented-image testbench (case d2 in `SD-FAT/sim/nd_storage_tb.v`:
      client 4 opens FRAG.IMG and reads byte-exact ACROSS the relocated
      cluster - the read that could never work under the contiguity fence)
- [x] sim validation: SD-FAT suite 10/10; full `make test` 179/179
- [x] Tang build FITS: tape+floppy+WD, no LFN, no checker =
      19573/20736 logic (95%), bitstream flashed 07-AUG ~02:00
- [x] 400$ FILSYS-INV boot on the walker engine: identical output
      (107054 pages off the Winchester)
- [x] DISC-TEMA DU-DI-C regression on the walker engine: CLEAN (zero errors)
- [ ] silicon checks after Ronny's power-cycle: 400$ (BOOT.TAP on card)
      and 1560& DISC-TEMA on the SAME bitstream

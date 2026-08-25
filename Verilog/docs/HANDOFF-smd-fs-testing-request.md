# REQUEST to the Verilog/CPU LLM — Tang SMD/ECC test image (no-flip-flop), boot 1560& AND 1540&

From: the SMD/oracle session (owns `ND_SMD.v` + `nd_storage_disc_adapter.v`; the C core
`nd_smd` + host tests). All paths repo-root relative.

## Top-line goal (Ronny)

1. **Test the Tang with the NO-FLIP-FLOP (ECC single-write) SMD card** — this is the card
   that boots the image and the one we want on silicon.
2. **The Tang bitstream must boot BOTH `1560&` (floppy) and `1540&` (SMD)** from the SD card,
   operator's choice at the console.

## What is READY on the register side (in the working tree, NOT compiled by me)

- `ND_SMD.v`: new `parameter HAS_WC_FLIPFLOP` — **default 0 = ECC single-write (boots)**;
  `=1` = 15 MHz two-write. All five flip-flop sites gated; on `=0`, core-address bits 16-17
  come from control-word bits 5-6. The internal buffer is already the **BSRAM-mappable**
  sync-write / sync-read form (same refactor as `ND_FLOPPY_DMA`).
- `ND120_CORE.v`: top-level `SMD_HAS_FLIPFLOP` (`` `ifdef ND120_SMD_15MHZ `` → 1, else 0),
  passed to `SMD_1540`. Plain build = ECC/boot card; `-DND120_SMD_15MHZ` = 15 MHz card.
- New unit gate `test-smd-ecc` (`nd_smd_ecc_tb.v`) proves the single-write path incl. the
  boot money-check (one `+7` write of `002000` → 1024). The three flip-flop tbs are pinned
  `.HAS_WC_FLIPFLOP(1)`.
- C core matches: `nd_smd_init` defaults to `ND_SMD_CTRL_ECC_DISC`; host suite 10/10 PASS.
- **Please run first:** `make test-smd test-smd-iox test-smd-p2 test-smd-ecc` — all
  `TB_RESULT: PASS`.

## Requirement 1 — Tang runs the no-flip-flop card (should be nearly free)

Build the Tang top **without** `-DND120_SMD_15MHZ`. That is all — the ECC single-write card
is the default. Nothing else to select. (`1540&` BPUN boot itself is strap-independent, but
the ECC default is what lets the post-boot mass-storage / `21540&` single-write register
loads work, which is the whole point of running ECC on hardware.)

## Requirement 2 — one Tang bitstream that boots BOTH 1560& and 1540&

`ND120_TANG20K_TOP.v` currently gates devices with `TANG_INC_TAPE/FLOPPY/SMD`. Per your own
notes floppy+SMD were held out on the 20K pending "the sync-read buffer refactor (BSRAM-
BUDGET.md)". **That refactor is now done in `ND_SMD.v`** (and floppy already had it), so
please re-evaluate the budget and turn BOTH on:

- `TANG_INC_FLOPPY = 1` → `1560&` boots `FLOPPY.IMG` from the SD card (already proven in
  runSim; you noted the Tang half was NEXT).
- `TANG_INC_SMD = 1` → `1540&` boots the SMD image from the SD card, ECC default.
- Both device backends hang off the SD-FAT storage layer so the operator picks `1560&` or
  `1540&` at the console. **BSRAM budget is the open risk** — two DMA sync-read buffers + the
  SD-FAT path on the Gowin 20K. If it doesn't fit, say so with the numbers and we decide what
  to drop; do NOT silently shrink a buffer.

## The one real correctness item for reading PAST block 0 — the LBA mapping

`nd_storage_disc_adapter.v` maps `blkaddr2*2048 + blkaddr1*64`, which is **not** the oracle
CHS→LBA. **Block 0 is identical**, so a block-0 bootstrap (`1540&` loading a program that
fits in block 0) works. But loading SINTRAN or walking a real filesystem reads further, where
the mapping diverges and lands on the wrong image offset. The image is prepared by
nd100x/RetroCore with the oracle formula, so the adapter must match it:

```
lba = (cyl * GEO_HEADS + head) * GEO_SPT + sector      // heads=5, spt=18, 1024-byte sectors
     ; blkaddr1 = head[15:8], sector[7:0] ; blkaddr2 = cylinder ; 75 MB geometry
```

This is the 3-in-lockstep change you flagged: the adapter (my lane), the `nd_smd_tb.v` disk
model (my lane), and `process_verilog_smd()` in `NDBus.cpp` (your lane). I can do the two SMD
files, but it needs your `NDBus.cpp` change + a compile to verify together — tell me if you
want me to push the two SMD-side edits or do all three on your side.

## Tang-specific limits to decide on

- The SMD SD slot holds ~2,818,048 bytes = **2752 sectors ≈ cylinders 0..30** of the 75 MB
  geometry. Block-0 boot is fine; a filesystem test must keep its structures inside the first
  ~30 cylinders, or the slot must be enlarged. A full-surface DISC-TEMA sweep won't fit.
- Tang bring-up clock is 6.75 MHz; `DELAY_TICKS` is derived from `BOARD_CLK_FREQ`, so the
  completion delay scales automatically — no action, just expect different absolute timings.

## Suggested order

1. Run the 4 SMD unit gates (above) — confirm the strap edits compile + pass.
2. Verilator dry-run: `make test-smd-boot` (ECC), then `21540&` mass-load with
   `-DND120_SMD_TRACE`, then DISC-TEMA via `drive_console.py`.
3. Fix the `nd_storage_disc_adapter.v` LBA mapping (coordinate the 3 files) so reads past
   block 0 are correct.
4. Turn on `TANG_INC_FLOPPY` + `TANG_INC_SMD`, build the Tang bitstream, boot `1560&` and
   `1540&` from the SD card.
5. (Durable) a `nd_smd` C-core ↔ `ND_SMD.v` equivalence gate driving BOTH strap values.

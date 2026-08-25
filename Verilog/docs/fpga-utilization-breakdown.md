# Tang Nano 20K OSS-flow utilization breakdown — what consumes BSRAM and LUT4

> **Status: MEASUREMENT / ANALYSIS ONLY.** No RTL, no build state, and no
> hardware were touched. Every number below is read from an actual synthesis /
> place-and-route run, not estimated. Where a figure could not be measured it is
> labelled **unknown** or **inferred**.
>
> Written 16-JUL-2026. Ronny Hansen project.

## What was run

- **Target:** Gowin `GW2AR-LV18QN88C8/I7`, device GW2AR-18 (Tang Nano 20K),
  family `GW2A-18C`. Top = `ND120_TANG20K_TOP`.
- **Flow measured:** the OSS CAD flow the Tang Makefile drives
  (`Verilog/fpga/tang-nano-20k/Makefile`),
  `yosys` (oss-cad-suite build 0.66+183 at
  `/home/ronny/oss-cad-suite/bin/yosys`) → `nextpnr-himbaechel` → `gowin_pack`,
  VARIANT=slow (the default).
- **Source list:** the ordered `.v` list from
  `Verilog/fpga/tang-nano-20k/nd120_tang20k.gprj`
  with defines file `src/tang20k_defines.v` first and `-I../../SD-FAT/circuit`,
  exactly as the Makefile assembles them.
- **Ground-truth PnR report:** the repo already contains today's failing run at
  `Verilog/fpga/tang-nano-20k/build/nd120_tang20k_oss-slow-pnr.log`
  (16-JUL 00:26). All utilization percentages below are quoted from it. The
  per-memory and per-module attributions were reproduced independently in a
  scratch synthesis in `/tmp/utilscan` (not in the repo build tree).

## 1. Ground-truth device utilisation (the failing run)

From `build/nd120_tang20k_oss-slow-pnr.log`, `Info: Device utilisation:` block,
immediately before the fatal `ERROR: Unable to find legal placement for all
cells, design is probably at utilisation limit`:

| Resource | Used / Avail | % | Notes |
|---|---|---|---|
| **BSRAM** | **45 / 46** | **97%** | block RAM — 1 block free |
| **LUT4** | **18404 / 20736** | **88%** | general logic LUTs |
| RAM16SDP4 | 328 / 648 | 50% | distributed (LUT-fabric) SSRAM |
| DFF | 8348 / 15552 | 53% | registers |
| ALU | 2410 / 15552 | 15% | carry-chain arithmetic |
| MUX2_LUT5 | 1519 / 10368 | 14% | wide-mux fabric |
| MULT9X9 | 4 / 96 | 4% | DSP (not BSRAM) |
| rPLL | 1 / 2 | 50% | clock |
| IOB | 35 / 384 | 9% | pins |

The synthesised primitive census that produces the 45 BSRAM blocks (yosys
`stat` after `synth_gowin`, `/tmp/utilscan/stat_oss.log`): `SP`=33, `SPX9`=8,
`SDPX9B`=1, `DPX9B`=3 → **33+8+1+3 = 45 BSRAM18 blocks**. This matches the PnR
report's 45/46 exactly.

## 2. BSRAM attribution — every one of the 45 blocks

yosys logs the primitive choice for each memory
(`mapping memory <path> via $__GOWIN_{SP,DP,SDP}_`, `/tmp/utilscan/stat_oss.log`
lines 26185–26283). Each listed memory maps to exactly one BSRAM18 block. Device
has 46 blocks.

| Design element | Geometry | Blocks | % of 46 | Source (file : line / module) |
|---|---|---:|---:|---|
| **WCS microcode store** — 32× `IDT6168A_20` | 4096×4 each | **32** | **69.6%** | `CPU-BOARD-3202/circuit/CPU_CS_WCS_21_22.v` (32 chip instances); array `Shared/support/IDT6168A_20.v:64` |
| MMU page-table + cache SRAM — 8× `TMM2018D_25` | 2048×8 each | 8 | 17.4% | 4× in `CPU-BOARD-3202/circuit/CPU_MMU_PT_29.v`, 4× in `CPU_MMU_CACHE_25.v`; array `Shared/support/TMM2018D_25.v:39` |
| MMU SRAM — 1× `IMS1403_25` | 16384×1 | 1 | 2.2% | instanced in `CPU_MMU_PT_29.v`; array `Shared/support/IMS1403_25.v:44` |
| Tape adapter sector buffer | 1024×16 | 1 | 2.2% | `SD-FAT/circuit/nd_storage_tape_adapter.v:78` (`s_blkbuf`) |
| Storage engine staging buffer | 512×32 | 1 | 2.2% | `SD-FAT/circuit/nd_storage_engine.v:278` (`s_staging`) |
| SD reader sector buffer | 512×8 | 1 | 2.2% | `SD-FAT/circuit/sd_file_reader.v:289` (`secbuf`) |
| FAT-check sector buffer | 512×8 | 1 | 2.2% | `SD-FAT/circuit/nd_storage_fatchk.v:79` (`fbuf`) |
| **TOTAL** | | **45** | **97.8%** | |

**Single biggest consumer: the WCS (writable control store), 32 blocks = 71% of
all BSRAM in use, 69.6% of the whole device.** Nothing else is remotely close.
This is the same conclusion the earlier
`fpga/tang-nano-20k/BSRAM-BUDGET.md` reached for the Gowin-EDA flow, and it holds
identically in the OSS flow.

Notes / things that do **not** cost BSRAM here:
- **Main memory costs zero BSRAM** — it lives on the embedded 8 MB SDRAM die via
  `sdram-bridge/MEM_RAM_49_SDRAM.v` (`MAIN_RAM_SDRAM` + `ND_SDRAM_PACK16` in
  `src/tang20k_defines.v`). Contrast with Basys3 where main RAM is the dominant
  BRAM cost.
- **The CPU register file does NOT use BSRAM in this flow.**
  `CPU-BOARD-3202/circuit/CPU_PROC_32.v:455-456` forces
  `registerBlock[0:2047]` (2048×16) to `ram_style="distributed"` **under
  `YOSYS`** because its asynchronous read cannot map to a BSRAM and yosys treats
  `ram_style="block"` as a hard requirement (unlike Vivado / Gowin EDA which
  fall back silently). It therefore lands in the LUT fabric — see §3.
- The `nd_storage_mount` register files (`r_size`, `r_nblk`, `r_first`,
  `s_fifo`; `SD-FAT/circuit/nd_storage_mount.v:198-234`) are tiny (4–8 entries)
  and were mapped to flip-flops, not BSRAM (`stat_oss.log` "created N $dff cells"
  around line 26615).

## 3. LUT4 attribution — top combinational consumers

Per-module local `$lut` counts from a hierarchy-preserving LUT4 mapping in
`/tmp/utilscan/lut_hier.log` (generic `abc -lut 4`; these are pre-Gowin-pack
counts, so absolute numbers run higher than the 18404 packed LUT4, but the
**relative** ranking is the signal). The design's own CPU/DELILAH logic is split
across hundreds of small modules (each `CGA_*`, `PAL_*`, gate primitive is tens
of LUTs), whereas the storage stack concentrates huge logic in a few modules:

| Module | Local LUTs (generic) | Source |
|---|---:|---|
| **`sd_file_reader`** | **8930** | `SD-FAT/circuit/sd_file_reader.v` |
| `nd_storage_engine` | 1382 | `SD-FAT/circuit/nd_storage_engine.v` |
| `sd_writer` | 941 | `SD-FAT/circuit/sd_writer.v` |
| `nd_storage_fatchk` | 815 | `SD-FAT/circuit/nd_storage_fatchk.v` |
| `nd_storage_mount` | 477 | `SD-FAT/circuit/nd_storage_mount.v` |
| `sd_card_ctrl` (inside reader/writer) | 441 | `SD-FAT/circuit/sd_file_reader.v` / `sd_writer.v` |
| `SC2661_UART` | 335 | `Shared/support/SC2661_UART.v` |
| `MEM_RAM_49_SDRAM` | 246 | `sdram-bridge/MEM_RAM_49_SDRAM.v` |
| `sdram18` | 223 | `sdram-bridge/sdram18.v` |
| `nd_storage_tape_adapter` | 176 | `SD-FAT/circuit/nd_storage_tape_adapter.v` |
| `CPU_15` | 156 | `CPU-BOARD-3202/circuit/CPU_15.v` |

The **SD-FAT / storage stack** (reader + engine + writer + fatchk + mount +
card-ctrl + tape-adapter + `nd_storage`) sums to **≈ 13,400 generic LUTs — the
majority of all combinational logic in the design.** `sd_file_reader` alone
(FAT-parsing FSM, directory scan, cluster arithmetic) is the single largest
logic block by a wide margin.

**Second structural LUT cost: the CPU register file as distributed RAM.** The
2048×16 `registerBlock` forced distributed (see §2) shows up as **328
RAM16SDP4** cells (50% of the 648 SSRAM-capable slices,
`nd120_tang20k_oss-slow-pnr.log`), plus its address-decode muxing. These occupy
CLS/LUT-fabric sites. It is a **yosys-flow-specific** cost — the Gowin-EDA flow
maps the same array to BSRAM instead (`CPU_PROC_32.v:458`). Its footprint is
called out in the source comment as "~2K LUT4" (`CPU_PROC_32.v:453`).

## 4. Which is the binding constraint?

**Highest-utilisation resource: BSRAM (97.8%, 1 block free).** By raw
percentage this is the tightest resource on the device and leaves essentially no
room for any new memory.

**But the resource that actually fails placement is most consistent with the
LUT4 / CLS logic fabric, not BSRAM.** Evidence, from
`build/nd120_tang20k_oss-slow-pnr.log`:

1. The fatal error is raised **during logic placement**: "Creating initial
   analytic placement for **14904 cells** … Running main analytical placer …
   ERROR: Unable to find legal placement for all cells." Those 14904 cells are
   LUT4 / DFF / ALU / SSRAM fabric cells. The 45 BSRAM blocks are packed earlier
   ("Info: Pack BSRAMs…") and are **trivially placeable** — 45 used of 46
   dedicated BSRAM sites is not a placement conflict.
2. The fabric is what is congested: **LUT4 88%** plus **RAM16SDP4 50%** (the
   distributed register file competes for the same CLS columns) plus **DFF
   53%** and 1519 wide-mux cells. GW2A packs LUT4+DFF+SSRAM into shared CLS, so
   legalisation gets hard well before any single count hits 100%.

**Conclusion:** BSRAM is the most *saturated* resource and the correct thing to
watch for future memory growth, but on the evidence the *immediate* PnR
legalisation failure is driven by **LUT4 / CLS-fabric congestion**, which the
newly-added SD-FAT stack (§3) and the yosys-forced distributed CPU register file
inflated. Treat this as **both resources are near the wall, with the placement
failure attributable to the logic fabric** — not to BSRAM alone. (Certainty:
high that BSRAM=45/46 is not itself a placement blocker; the "utilisation limit"
message is generic, so the fabric attribution is strong-but-not-proven. The
clean experiment to confirm: reduce the SD-FAT LUT footprint OR free BSRAM and
re-run PnR — whichever unblocks the placer identifies the true binder. **Not
run here** — running PnR to a pass/fail verdict was out of scope.)

## 5. What grew — reconciling against the memory notes

The memory note claims "Tang BSRAM 41/46 CPU-only baseline" and "44/46 with
storage (+3)". Measured against the two PnR reports in the build tree:

| Build | Date | sd_file_reader present? | BSRAM | LUT4 |
|---|---|---|---:|---:|
| `nd120_tang20k_oss-full-pnr.log` | 12-JUL | **no** (grep count 0 in `-full-synth.log`) | **41 / 46 (89%)** | 8731 / 20736 (42%) |
| `nd120_tang20k_oss-slow-pnr.log` | 16-JUL (today) | **yes** (801 refs in `-slow-synth.log`) | **45 / 46 (97%)** | 18404 / 20736 (88%) |

- The **41-block CPU-only baseline is confirmed exactly**: 32 WCS-IDT + 8
  MMU-TMM + 1 MMU-IMS = 41 (§2).
- **The SD-FAT / tape-boot storage stack is what grew the design.** It was
  absent from the 12-JUL build and is present today. Git shows it was wired into
  the Tang project by commit `64fe9c4` ("tang20k: boot the tape from the real SD
  card"), and commit `9d5a1cb` (the RQBIT→V2 loop fix) then removed the
  combinational loops that had blocked PnR, letting it reach the placer.
- Storage added **+4 BSRAM** (41→45): the tape-adapter, engine-staging,
  SD-reader and FAT-check sector buffers (§2). The memory's "+3" figure is one
  short of the OSS measurement — **inferred** cause: the Gowin-EDA flow may pack
  two 512×8 buffers into one block, or the FAT-check buffer was added after that
  note. Not confirmed.
- Storage also **roughly doubled LUT4** (8731→18404, 42%→88%), driven by
  `sd_file_reader` and the rest of the SD-FAT stack (§3). This is the larger and
  less-documented growth: the earlier `BSRAM-BUDGET.md` treats the build as
  BSRAM-bound with "logic … enormous headroom (30%)"; that headroom is **gone**
  now that the SD-FAT stack is in — LUT4 is at 88%.

## References (all absolute)

- `Verilog/fpga/tang-nano-20k/build/nd120_tang20k_oss-slow-pnr.log` — today's failing PnR utilisation + error (ground truth)
- `Verilog/fpga/tang-nano-20k/build/nd120_tang20k_oss-full-pnr.log` — 12-JUL pre-storage PnR (41 BSRAM / 42% LUT4)
- `Verilog/fpga/tang-nano-20k/nd120_tang20k.gprj` — ordered source list
- `Verilog/fpga/tang-nano-20k/src/tang20k_defines.v` — SKIP_WCS_LOAD / MAIN_RAM_SDRAM / ND_SDRAM_PACK16 / ND_STORAGE_PORT
- `Verilog/fpga/tang-nano-20k/BSRAM-BUDGET.md` — prior (Gowin-EDA, pre-storage) WCS analysis and reclaim plan
- `Verilog/CPU-BOARD-3202/circuit/CPU_CS_WCS_21_22.v` — WCS, 32 IDT6168A_20 instances
- `Verilog/Shared/support/IDT6168A_20.v` — 4096×4 chip model (block-RAM template)
- `Verilog/Shared/support/TMM2018D_25.v` — 2048×8 SRAM
- `Verilog/Shared/support/IMS1403_25.v` — 16384×1 SRAM
- `Verilog/CPU-BOARD-3202/circuit/CPU_PROC_32.v` — CPU register file (distributed under YOSYS, lines 449-459)
- `Verilog/SD-FAT/circuit/sd_file_reader.v` — largest single LUT consumer; `secbuf` at line 289
- `Verilog/SD-FAT/circuit/nd_storage_engine.v` — `s_staging` at line 278
- `Verilog/SD-FAT/circuit/nd_storage_tape_adapter.v` — `s_blkbuf` at line 78
- `Verilog/SD-FAT/circuit/nd_storage_fatchk.v` — `fbuf` at line 79

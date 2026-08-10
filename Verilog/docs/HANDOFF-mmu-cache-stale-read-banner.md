# HANDOFF — MMU data cache serves stale all-ones on a cache-inhibit read (TPE banner `INST␡␡CTION`)

Status date: 2026-07-26. Board-independent (CPU/MMU core RTL); applies to every build.

All paths below are absolute so this document can be read cold.

---

## 1. One-paragraph summary

The TPE INSTRUCTION verifier printed its banner `INSTRUCTION` as `INST\x7f\x7fCTION`
(word-index-2 = the 3rd packed word `RU`/`0x5255` came out `0xFF,0xFF`, masked to
`0x7F` by the terminal). Root cause: the DELILAH CPU board's **MMU data cache**
(`Verilog/CPU-BOARD-3202/circuit/CPU_MMU_CACHE_25.v`)
drives its data SRAM onto the wired-OR `CD` bus for the whole read, gated only by
`ECD` (no `HIT` term — confirmed against the schematic). On a normal miss the memory
data survives that wired-OR only because the refill (`WCA`) forces the cache SRAM
output to `0` while it writes the line. For a **cache-inhibit page** (`WCINH`) the
refill is suppressed, so a cache line still holding **stale non-zero data**
(`0177777`, cached during an earlier init-clear, then the memory rewritten by floppy
DMA which bypasses the cache) **jams the wired-OR** over memory's correct word.
A one-line HIT-gate on the cache output fixes it; the banner now prints clean.

## 2. Symptom (measured)

- Booting `Verilog/runSim/FLOPPY1.IMG` (`1560&` → TPE
  monitor → INSTRUCTION verifier C03), the banner printed `INST\x7f\x7fCTION`.
- Content-independent, always **word-index-2**: `MEMORY` → `MEMO\x7f\x7f` (`RY`).
- The nd100x oracle (`/mnt/e/Dev/Emulators/ND/nd100x`, `--cputype=ND120CX`) runs the
  SAME floppy and prints the banner **clean** → our RTL bug, not the floppy code/data.
  (nd100x has no data cache, so it can't guide the cache-gating detail.)

## 3. Root cause — full measured chain

Measured entirely offline from a full-hierarchy FST
(`Verilog/sim/lbyt_full.fst`, ~71.6M-tick window over the
banner print) using `Verilog/sim/vcd_extract.py`.

1. **RAM is intact.** Backdoor scan (C-side `scanseq`) shows the packed banner word
   `66014` = `051125` ('RU') in every copy, the whole time. Not a store/DMA-load bug.
2. **The read is a byte-extract via `LBYT` (opcode `142200`, macro-P `016676`).** For
   byte index 4/5 it reads packed word `66014`; the memory data bus
   (`MEM.s_lbd_15_0_out`) delivers the correct `051125`, yet the CGA's read-data
   register `CD` (`...DELILAH.ALU.s_cd_15_0`) latches `0177777`.
3. **`CD` is a bit-wise wired-OR of the cache output and the memory output.** The cache
   drives via `ECD` for the whole read-transfer; memory drives via `EMD`
   (`Verilog/CPU-BOARD-3202/circuit/BIF_DPATH_CDLBD_11.v:60`).
   In the failing read the cache drives `MMU.CACHE.s_cd_15_0_out = 0177777`, so
   `aluCD = 0177777 | 051125 = 0177777`. The DBR captures `0177777` →
   `LBYT` byte-extract yields `0xFF` → terminal `& 0x7F` → `\x7f`.
4. **Why the cache holds stale `0177777` and why memory can't win:**
   - The cache line for `66014` (data-SRAM index `CA=14`) holds `0177777`, loaded during
     an earlier init-clear (when those pages were still cacheable). The floppy DMA then
     rewrote memory word `66014` = `051125` but **DMA bypasses the cache** → line stale.
   - Normally a miss refills (`WCA`), and the `TMM2018D` cache SRAM drives `0` while
     `W̄` is low, so memory passes the OR. But this page is **cache-inhibit**:
     `WCINH_n = 0` (from the cache-inhibit map `IMS1403 CHIP_20G` in
     `Verilog/CPU-BOARD-3202/circuit/CPU_MMU_PT_29.v:149`)
     → `EWC = BRK_n·CON·WCINH_n = 0` → `WCA` never fires → nothing zeroes the stale
     cache output. `HIT=0` throughout (no valid hit), but the ungated `ECD` keeps the
     stale SRAM driving.
   - Good words survive only because their cache cells happen to hold `0`.

## 4. Schematic / PALASM verification (no transcription bug)

Sheet 25 (CPU/MMU/CACHE) of
`DesignDocuments/CPU-BOARD-3202/3202-REV-D-OCT-87-600DPI.pdf`
(page 25) and the PAL sources under
`DesignDocuments/PAL-Code/{SRC,IMG}/` confirm the RTL is
faithful:

- Cache data SRAMs `23F` (CD15:8) / `24F` (CD7:0): `C̄S̄ = ECD~`, `W̄ = WCA~`,
  `OE = GND`. No `HIT`/`WCINH` gate on the output. Matches `CPU_MMU_CACHE_25.v`.
- `PAL_44306A` (`ECD`): `ECD = WCA·/LSHADOW + RT·/LSHADOW·/CC2`; comment "ENABLE IN THE
  FIRST PART OF READ/FETCH CYCLES" — the speculative drive is **by design**.
- `PAL_44402D` (`WCA`/`IHIT`/`USED`): `WCA = /RT·DT·EWC·CYD·/FMISS·/LSHADOW +
  RT·/IHIT·EWC·CYD·/FMISS·/LSHADOW`. Matches the Verilog term-for-term.

So this is a design-level coherency gap (cache holds stale data for a page that became
non-cacheable), not a mis-transcribed equation.

## 5. The fix (applied)

File: `Verilog/CPU-BOARD-3202/circuit/CPU_MMU_CACHE_25.v`
(around line 109):

```verilog
`ifdef ND120_CACHE_DRIVE_UNGATED
  assign CD_15_0_OUT = s_cd_15_0_out[15:0];
`else
  assign CD_15_0_OUT = s_hit ? s_cd_15_0_out[15:0] : 16'b0;
`endif
```

Gating the cache output by `HIT` makes it contribute `0` to the wired-OR on any
miss/inhibit (`s_hit=0`, measured on the bad read), so memory passes cleanly. `s_hit`
has no dependence on `CD_15_0_OUT` → no combinational loop. Escape hatch
`-DND120_CACHE_DRIVE_UNGATED` restores the raw schematic behaviour.

**Nature of the fix:** functional, not hardware-faithful. The schematic drives the cache
speculatively with no `HIT` gate and relies on refill-zeroing (which cache-inhibit
breaks); HIT-gating is a correct superset that gives up the speculative-read speedup
(free in sim; possibly one cycle on FPGA). The hardware-faithful alternative is coherency
(§7 option 2).

## 6. Verification status

- **Banner: PASS.** Rebuilt FF-mode engine with the fix and re-ran floppy-TPE INSTRUCTION;
  it now prints `INSTRUCTION - Version: C03 - 1988-03-04` — no `\x7f`.
- **CACHE-1X0 hardware diagnostic: RAN, fix validated for the data path.** The TPE floppy
  carries `CACHE-1X0-A00:TEST` (list with `li-fi c`, run with `cac`). Our sim reports the
  cache **enabled** (`Cache: Yes`, `SW1_CONSOLE = s_high`) — unlike a cache-off emulator — and
  correctly identifies the board: `CPU ND-120/CX`, `MMS-2`, `Print 3202`, release `D`,
  `Microprogram 100014B`, `ECO P`. It gets cleanly through the config/cache-detect stages
  (which exercise cache reads) with NO data errors, then stops at a pre-check reporting
  **`Cache updated bit: Not working`** and returns to `TPE>`. That "updated bit" is the CUP
  (Cache-Updated) status, read back via the CSR onto IDB0 (`CPU_MMU_CSR_26.v:17`, from
  `s_cup` in `CPU_PROC_32.v`) — a SEPARATE path from the `CD_15_0_OUT` this fix gated, so it
  is PRE-EXISTING and independent of the HIT-gate. Net: the HIT-gate did not disturb
  legitimate cache reads (banner clean + diagnostic data stages clean). The CUP/used-bit
  status gap is a separate follow-up (not the banner bug).
- **Self-test STERR gate: PENDING.** Build a runSim engine with `-DND120_COUNT_STERR`
  (fresh Mdir to avoid clobbering `Verilog/runSim/obj_dir`)
  and confirm 0 execution-phase STERR visits. (Prior known-good baseline is 0.)
- **Not yet run:** latch-vs-FF golden trace compare; full unit suite (no cache-specific
  unit tb exists, so the unit suite does not exercise this path).

## 6b. Second cache bug found + fixed — CUP (Cache-Updated bit) transcription error

The CACHE-1X0 `Cache updated bit: Not working` was a second, independent transcription bug,
now fixed. CUP is the cache-updated status bit read via the cache-status register
(`CPU_MMU_CSR_26.v:42`, onto IDB0 when `ECSR_n` low), generated by `PAL_44511A` (FF-mode
variant `PAL_44511A_EN`). The OCR+PNG
(`DesignDocuments/PAL-Code/{SRC,IMG}/44511A.*`) give the
registered equation `/CUP := /CWR*MREQ + /CUP*/MREQ` (intent `CUP := CWR*MREQ + CUP*/MREQ` —
SET on write-to-cache, hold until next MREQ). The Verilog had the MREQ polarity flipped
(`if ((CWR_n & MREQ_n)==1) CUP_n_reg<=0; else if (MREQ_n==0) CUP_n_reg<=1;`) — wrong in two
states: on a cache write it gave `CUP=0` (should SET), and when idle it spuriously set `CUP=1`.

Fix (both `Verilog/PAL/PAL_44511A.v` and
`Verilog/PAL/PAL_44511A_EN.v`):
```verilog
CUP_n_reg <= (CWR_n & MREQ) | (CUP_n_reg & MREQ_n);   // /CUP := /CWR*MREQ + /CUP*/MREQ
```
Safe: CUP is status-only (feeds only the CSR read, no control logic). Still to validate:
re-run CACHE-1X0 and confirm `Cache updated bit` now reports working and the pattern tests run.

## 7. Open items / options for the next session

1. Finish the **CACHE-1X0** diagnostic run and the **STERR** gate (above). If both are
   clean, the HIT-gate fix is validated for the hit path.
2. **Hardware-faithful coherency fix (option 2)** if the speculative-read behaviour must
   be preserved: ensure the cache never holds stale data for pages that become
   cache-inhibit — e.g. set up the cache-inhibit map before the init-clear can cache those
   pages, and/or clear the `TMM2018D` data SRAM on `CCLR` (today `CCLR` resets only the
   `AM9150` used-bits, not the data SRAM), and/or invalidate on DMA writes.
3. Decide whether the HIT-gate is acceptable for FPGA (loses the speculative-read
   speedup) or whether option 2 is required.

## 8. Build & reproduction (absolute paths)

FF-mode probe engine WITH the fix (built into a fresh dir, does not clobber others):
```
cd Verilog/sim
# recipe = `make -n probe-floppycore USE_LATCHES=0` with --Mdir swapped to obj_dir_probe_cachefix
# engine: Verilog/sim/obj_dir_probe_cachefix/VND120_TOP
```
Floppy image for the probe engine (env var):
`ND120_FLOPPYCORE_IMG=Verilog/runSim/FLOPPY1.IMG`

Key measurement/verification scripts (scratch; copy anything worth keeping into the repo):
- `/tmp/claude-1000/verify_cachefix.py`  — boot TPE, type INSTRUCTION, assert banner clean.
- `/tmp/claude-1000/run_cachetest.py`     — boot TPE, `li-fi c`, run `cac` (CACHE-1X0).
- `/tmp/claude-1000/fst_readbus.py`, `fst_alu.py`, `fst_cdchain.py`, `fst_wca.py`,
  `fst_ecdemd.py` — the offline FST analyses that produced §3 (operate on
  `Verilog/sim/lbyt_full.fst`).

Method notes: the sim RAM sync-read means `RAM.idx0`↔`RAM.q0` same-tick pairing is
UNSOUND (1-cycle pipeline); RAM WRITES pair `idx0`/`DD_17_0_IN`/`MWRITE50_n` same-tick
fine. Backdoor `examine`/`scanseq` read the TRUE stored bytes (no DRAM-mux). Macro-PC is
probe registry `RP` (`WRF.RBLOCK.s_reg2_p_15_0`). Floppy boot REQUIRES `USE_LATCHES=0`
(`-DFPGA_FF_MODE`); a latch build silently never boots.

## 9. Related

- Campaign log (auto-memory): `tpe-banner-word2-read-bug` (full investigation history).
- `Verilog/docs/INSTRUCTION-verifier-TPE-run.md`.

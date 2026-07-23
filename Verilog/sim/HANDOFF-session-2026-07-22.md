# Session handoff — 2026-07-22 (ND-120 store/177777 hunt + generic sim probe)

**Full path:** `E:\Dev\Repos\Ronny\nd-120\Verilog\sim\HANDOFF-session-2026-07-22.md`
Reboot imminent — all changes below are ON DISK (survive reboot) but **NOT git-committed**.
Background agents + WSL sim processes will be KILLED by the reboot; re-kick as noted.

---

## TL;DR of what was proven

1. **The CPU store datapath is NOT the bug.** `make test-instr-MEMORY-REFERENCE` (WSL, FF mode)
   PASSES 400/400 vs the ND-110 golden. STA/STT/STX/STD/STF execute correctly. The earlier
   "CDLBD FF-capture store bug" hypothesis is DEAD — do not reopen.
2. **The real bug is address-specific:** every memory-WRITE to **logical 177777 (0xFFFF, the top
   page)** under PAGING reads back 0. Physical (paging-off) round-trips 177777 fine. It is the
   MMU top-page shadow-vs-main routing, "upstream of main RAM". Still UNRESOLVED (not yet
   reproduced in a capturable harness — see below).
3. **The "probe boots INSTRUCTION-B not TPE-MON" mystery is SOLVED + FIXED** (see §Fix).

## Built this session (durable, on disk)

- **Generic scriptable Verilator probe** (the big reusable asset):
  - `sim\nd120_probe.cpp` — engine: line protocol (load/deposit/examine/watch/watch group/
    `rule add <name> when "<expr>" do <acts>`/set pre|post/capture csv|fst/run/runto/get/reset/
    send/console/quit). Rule condition = boolean expr over ANY signals; actions log/fst_on/
    fst_off/csv/event/mark/stop. Signals via `--vpi --public-flat-rw` (any dotted name) + a
    root-path registry floor. **Just fixed** (§Fix): UART `send` inter-char pacing gap.
  - `sim\nd120_probe.py` — pexpect-style driver (mirrors nd100x `tools/nd100x_expect.py`).
  - `sim\examples\tpe_paging_capture.py`, `sim\examples\mmu_177777_probe.py`.
  - `sim\PROBE-DESIGN.md`, `sim\PROBE-README.md`.
  - Makefile targets (additive): `probe`, `probe-floppy` (Verilog floppy), `probe-floppycore`
    (portable C floppy core = the run-tpe backend). Build WSL: `make probe-floppycore USE_LATCHES=0`.
- **Real paging capture:** `sim\tpe_paging.csv` — INSTRUCTION-B's MMS-II bring-up: identity page
  table, PON high at tick 12,129,409 AFTER table populated, VPN63(page o77)->PPN o77, PT=162000.
- **Regression tb:** `CPU-BOARD-3202\circuit\sim\CPU_MMU_PT_29_replay_tb.v` + `test-mmupt-replay`
  (registered in `tests\run_all_tests.sh`), replays the real VPN63 vectors, TB_RESULT PASS.
- **Verilog floppy DMA validated:** `ND-BUS-DEVICES\FLOPPY-DMA\` — 3 tbs green + NEW
  `sim\nd_floppy_boot_tb.v` (`test-floppy-boot`, drives the real 1560& protocol). One real
  defect FIXED in `circuit\ND_FLOPPY_DMA.v` (autoload failure now does boot_fail = err o50 +
  hard error + leave boot mode; oracle-cited). Manual-decision items: `docs\HANDOFF-nd100x-
  floppy-dma-manual-fixes.md`.

## THE FIX (root cause of "wrong program", found late this session)

The probe never booted the floppy. `send` transmitted chars back-to-back with NO inter-char gap;
MOPC has no RX FIFO, so "1560&" was MANGLED - the "1560" dropped, only "&" survived -> autoload
ran from **ALD=400 = the PAPERTAPE device, armed with INSTRUCTION-B.BPUN** (`simDevices\NDDevices.cpp:55`).
Hence INSTRUCTION-B / ND-100/CX / ">" prompt instead of TPE Monitor B01 / ND-120/CX / "TPE>".
runSim/Run120.cpp documents this exact hazard (`ND120_STDIN_GAP=300000`).
**FIX applied to `sim\nd120_probe.cpp serviceUartTx()`:** inter-character pacing gap, default
300000, env `ND120_SEND_GAP`. NOT yet rebuilt/verified (reboot).

## NEXT STEPS (resume here after reboot)

1. **Rebuild the probe with the send-gap fix** (WSL, ~7 min each):
   `wsl.exe -e bash -lc 'cd /mnt/e/Dev/Repos/Ronny/nd-120/Verilog/sim && make probe-floppycore USE_LATCHES=0'`
   (also `probe-floppy` if needed).
2. **Verify the fix**: drive `reset; send 1560&; run 100000000` and confirm the console now shows
   **"TPE Monitor" / "TPE>" / ND-120/CX**, NOT "INSTRUCTION VERIFY / INSTRUCTION-B / >". If still
   wrong, bump `ND120_SEND_GAP` (600000) before anything else.
3. **Reach the failing test**: at `TPE>` drive `config`+`run` (Run120 SCRIPT_CMD_FBOOTCFG =
   `1560&config\rrun\r`) or `instr`+`run`. Watch the known TPE42 clock/interrupt init stall
   (separate RTC bug) - if it stalls before "=== Memory reference instructions ===", report it.
4. **Capture the failing 177777 DATA store**: rule `s_write==1 && s_cyd && s_la_20_10==o77 &&
   s_wmap_n==1`, tight fst_on/fst_off, PRE/POST; backdoor-examine MAIN[177777] AND the mapped
   physical page (from captured PPN). Honest MAIN-vs-SHADOW verdict with a control.
5. **If reproduced**, extend `CPU_MMU_PT_29_replay_tb.v` with the store vectors as a repro tb.
6. **Fallback if the RTL boot path stays blocked**: capture from the C# RetroCore ND-120 microcode
   CPU per `sim\HANDOFF-csharp-paging-capture.md` (paging works there; independent reference).

An agent (id ac5176117f50265e5) was mid-rebuild/verify of steps 1-4 when the reboot hit; its work
is lost on reboot - just re-run steps 1-2 manually or re-launch.

## Uncommitted changes (on disk, review before committing)
- MODIFIED: `sim\nd120_probe.cpp` (send-gap fix), `sim\Makefile` (probe*/floppy targets),
  `ND-BUS-DEVICES\FLOPPY-DMA\circuit\ND_FLOPPY_DMA.v` (boot_fail), `.../FLOPPY-DMA\sim\Makefile`,
  `tests\run_all_tests.sh`, `CPU-BOARD-3202\circuit\sim\Makefile`.
- NEW: `sim\nd120_probe.py`, `sim\examples\*.py`, `sim\PROBE-*.md`, `sim\HANDOFF-*.md`,
  `ND-BUS-DEVICES\FLOPPY-DMA\sim\nd_floppy_boot_tb.v`, `CPU-BOARD-3202\circuit\sim\
  CPU_MMU_PT_29_replay_tb.v` (+ MEM_ERROR_47_tb.v, MEM_RAM_49_SIM_PARITY_tb.v, CPU_MMU_PT_29_tb.v
  from earlier), `docs\HANDOFF-nd100x-floppy-dma-manual-fixes.md`.
- Nothing committed (per your rule). RTL edited: ONLY `ND_FLOPPY_DMA.v` (device core, you
  authorized floppy work) — NO CPU-BOARD-3202 RTL was touched.

## Guardrails still in force
WSL-only for all Verilator/iverilog/make. CPU-BOARD-3202 RTL is REPORT-ONLY. Memory index:
`MEMORY.md` -> `nd120-mmu-shadow-ram`, `nd120-sim-probe-harness`, `nd120-verilog-floppy-validation`,
`nd120-sim-wsl-only`.

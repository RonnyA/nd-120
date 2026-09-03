# fpga-soak: close every open claim on the published release

Branch `fpga-soak`, started 27-AUG-2026. Priority-ordered phases; each item
carries its verdict when done. Goal: nothing in the bitstreams-2026-08
release or the 26/27-AUG documentation rests on an unmeasured claim, and
the small debt items are cleared.

## Phase 1 - the release artifacts (highest value, board time)

| # | Item | How | Status |
|---|------|-----|--------|
| 1.1 | Boot-check the exact `nd120_nexys4ddr_16MHz_115200.bit` release file | JTAG program the staged file, `20500&` to banner at 115200 7E1 | **PASS 27-AUG** (banner + Watchdog) |
| 1.2 | Boot-check the exact `nd120_tang20k_slow_6.75MHz_115200.fs` release file | openFPGALoader SRAM load, `20500&` on /dev/ttyUSB1 at 115200 7E1 | **PASS 27-AUG** (Watchdog in 106 s) |
| 1.3 | Nexys soak at 45.45 MHz | JTAG the 45 MHz release file, boot SINTRAN, leave running with hourly console probes (ESC attention), 4+ hours, no hang/ERRFATAL/watchdog-red | **PASS 27-AUG: 8/8 probes alive over 4 h, identical 104-byte attention responses every 30 min** |
| 1.4 | Tang soak at 20.25 MHz (fast20) | same recipe on /dev/ttyUSB1 | **PASS 27-AUG: 8/8 probes alive over 4 h, identical 78-byte responses** |
| 1.5 | SD-config boot at 16.667 MHz (fix verified at 45 only) | needs Ronny: swap the .bit on the card, power-cycle | NEEDS RONNY |
| 1.6 | SD-card WRITE at speed (dirty-page flush during a session) | part of the soak if SINTRAN writes during it; a deliberate write test is follow-up | follow-up |

## Phase 2 - Tang tooling still says 9600

Every Tang bitstream built after 26-AUG talks 115200 7E1. Sweep
`Verilog/fpga/tang-nano-20k/` for scripts/docs that open 9600
(`pf_capture_run.py`, boardtest drivers, README console lines) and update
them; note the memory files are already flagged via the skill. | **DONE 27-AUG** (18 scripts + usb-attach.sh) |

## Phase 3 - test-gate backlog (TODO.md, Ronny's 21-AUG decision)

| # | Item | Status |
|---|------|--------|
| 3.1 | Re-check `DELILAH-CPU/CGA/sim/ND120_PF_CAPTURE_tb.v` - may elaborate now that `ND120_PF_CAPTURE.v` gained `c_pgs_at_read` | **PASSES** (was already registered) |
| 3.2 | 4 orphan testbenches: register or delete each (PT_stale_read_tvec, 2x winchester, nd_storage_ticks) | **ALL 4 REGISTERED, all pass** |
| 3.3 | 101 unregistered testbenches from the 21-AUG sweep: register or delete each, NO baselining away | **101 -> 5**; 100 entries added, all proven; the 5 rest documented in TODO.md (one is a live finding: CYC_STRETCH) |
| 3.4 | `test-memchain` pre-existing failure - diagnose, fix or document | **RESOLVED**: SIM-variant stale expectation of pre-11-AUG parity handling; tb fixed, 4/4 variants pass + sim/blockram now registered |

## Phase 4 - small debts

| # | Item | Status |
|---|------|--------|
| 4.1 | Trim MEMORY.md under its 24.4 KB load limit (index lines only, content stays in topic files) | **DONE** (27.9 -> 23.4 KB) |
| 4.2 | Pages workflow Node-20 deprecation: bump actions versions | edited; commit needs Ronny's workflow-scope push |

## Phase 5 - the IDB ring cut (structural, own campaign)

Cut the remaining CGA IDB combinational ring in RTL (the "PARKED DEBT" in
`nexys4ddr/build.tcl`: 2 auto false paths, 6 check_timing loops). Payoff:
CPU WNS becomes a guarantee instead of a floor, and the OSS Tang flow
unblocks (route to CI-built releases). This is a full campaign with its own
regression gates (latch-vs-FF golden traces, instruction-verify); this
branch only records the entry point: `EXTENSIONS-PLAN.md` + the 20-AUG
analysis in `build.tcl`. | out of scope here

Execution notes: 1.1/1.2 run BEFORE the soaks (quick, and the soaks then
occupy both boards for hours). Phases 2-4 run while the soaks tick.

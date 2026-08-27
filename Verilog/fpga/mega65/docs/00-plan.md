# MEGA65 port - phase plan

Written 27-AUG-2026, planning stage. Target: MEGA65 **R4 and later**
(XC7A200T fbg484 -2, 64 MiB SDR SDRAM, 8 MiB HyperRAM, dual SD slots on
fabric pins, 100 MHz oscillator). Sources for every hardware claim: the
mega65-core Vivado scripts (`mega65r4/r5/r6_gen.tcl`, part string), the
board XDCs (`src/vhdl/mega65r5.xdc`: 100 MHz on V13, SDRAM/SD pin blocks),
the MEGA65 user-guide appendix (R4 SDRAM addition), and the MEGA65 wiki
("Bitstream and Corefile Know-How" - .cor slots). Full source URLs in the
27-AUG feasibility report (session record); re-verify against the R6 XDC
when the pin file is written.

## Decisions taken

- **R4+ only.** R3's HyperRAM-only memory is a second backend for no
  gain; R3 owners can run the Nexys-class experience later if someone
  wants the work.
- **The Nexys memory seam is the porting boundary.** Everything above
  `nd_ddr2_port` (the `MEM_RAM_49_DDR2` cache, MEM_HOLD freeze,
  write-FIFO ordering) ports byte-for-byte. The new backend implements
  the same contract against the SDR SDRAM.
- **Prefer an existing proven controller** over writing one. Candidates
  under evaluation (research in progress): mega65-core
  `sdram_controller.vhdl`, MJoergen/HyperRAM (MIT, MEGA65-proven, for the
  R3 fallback question), MiSTer-family SDR controllers (the R4+ chip is a
  MiSTer-class 32Mx16 part), the MiSTer2MEGA65 framework's memory layer.
- **Virtual drives + display/keyboard emulation are goals, not extras**
  (Ronny, 27-AUG): the framework's Shell serves disk images from SD and
  owns keyboard/video - if the ND-120's device seams can ride that, our
  FAT stack is not needed on this platform and the machine gets a real
  console on its own keyboard and screen.

## Open decision: bare-metal vs MiSTer2MEGA65 vs hybrid

Two research reports pending (RAM-controller survey; M2M framework study
incl. the make_release.py release flow and a worked ported-core example).
The decision rests on: does the M2M virtual-drive model (sector-addressed
images via the QNICE co-processor) fit the ND-120's tape/floppy/Winchester
block seams, and how much MiSTer-shaped core contract would we fight?
Fill in here when the reports land.

## Phases

| Phase | Content | Exit gate |
|---|---|---|
| 0 | Research: RAM controller pick + M2M decision (running) | both reports in, decision recorded here |
| 1 | Memtest bitstream: chosen SDRAM controller + `nd_sdram_port` adapter + the nexys4ddr `sd-fat-test`-style memtest, on real R4+ silicon | measured latency table; the port contract benched (mirror `test-ddr2port`/`test-ddr2arb` benches) |
| 2 | Bring-up top: ND-120 core + SDRAM backend + TE0790 UART console + our SD-FAT stack on the internal slot; OPCOM answers | OPCOM over the TE0790 at 115200 7E2 |
| 3 | SINTRAN boot from SD image (still our FAT stack) | banner + Watchdog, boardtest scripts pass |
| 4 | M2M integration (if the phase-0 decision says so): virtual drives replace the FAT stack; keyboard+video console via the framework Shell | boot + login using only the MEGA65's own keyboard/screen/SD |
| 5 | Release: `.cor` packaging (bit2core / make_release.py style), QUICKSTART, entry in the bitstream release | a downloadable ND-120.cor that boots SINTRAN on a stock MEGA65 |

## Reuse ledger

| Existing material | Reused how |
|---|---|
| `Verilog/fpga/nexys4ddr/build.tcl` | Clone as `mega65/build.tcl`: same in-memory Vivado flow, clk table, per-run report battery, WNS gate - part string + XDC swapped |
| `Verilog/fpga/nexys4ddr/ddr2/MEM_RAM_49_DDR2.v` | Unchanged above the seam (rename pending: it is the seam-facing cache, not DDR2-specific) |
| `Verilog/fpga/nexys4ddr/ddr2/nd_ddr2_port.v` | The CONTRACT (header + benches); the new `nd_sdram_port` implements it |
| `CPU-BOARD-3202/circuit/sim/ND_DDR2_PORT/ARB benches` | Re-point at the new port for the phase-1 gate |
| `Verilog/SD-FAT/` stack | Phase 2-3 device backend; possibly retired on this platform in phase 4 |
| `Verilog/fpga/nexys4ddr/timing.md` | Same fabric family one grade faster: the 45 MHz closure and the one-family microcycle analysis transfer as the starting expectation |
| SD power-cycle lesson (`nexys4ddr` fix-sd-card) | The MEGA65 slots have their own reset/power semantics - apply the power-cycle-at-reset pattern from day one |
| `HISTORY.md` / release flow | `.cor` joins the bitstream release when phase 5 lands |

## Known risks (from the Nexys experience)

- The memory backend is where the silicon-only bugs live: the DDR2
  equivalent grew three (posted-write reorder, stale-line refill,
  stale-tag hit) before SINTRAN booted. Phase 1's memtest-first
  methodology exists precisely because of that.
- Console framing is 7E2 and the machine believes 9600 regardless of the
  physical baud (UART_BAUD_RATE constant) - the M2M/QNICE UART path must
  cope with 7E2 or the console core must.
- No switch bank / debug LEDs like the Nexys panel: plan the debug
  surface early (the framework OSD could show what LD16/the 7-seg shows
  today).

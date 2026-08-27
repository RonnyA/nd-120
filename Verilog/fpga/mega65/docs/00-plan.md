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

## Phase-0 decisions (both research reports in, 27-AUG-2026)

**RAM controller: MJoergen/SDRAM** (github.com/MJoergen/SDRAM, MIT) -
Avalon-MM, ONE 166 MHz clock, no IDELAY tuning, source-stated latency
(read 12 clk / write 8 clk; a fully serialized 8-beat line refill ~0.66 us
worst case - bounded, in-order, well inside MEM_HOLD tolerance), 64 MB,
ships its own simulation environment. The seam's toggle CDC is
frequency-agnostic (verified in MEM_RAM_49_DDR2.v), so 166 MHz simply
becomes ui_clk. Adapter ~150 lines; the ONE trap: our req_wmask is
ACTIVE-LOW, Avalon byteenable is active-high - invert per beat. Fallback
for R3 boards: MJoergen/HyperRAM (same author, same Avalon shape, real
burst, three clocks + IDELAY; heavily field-proven - it ships inside
production M2M cores). Rejected: mega65-core's own controllers (8-bit
VIC-IV-entangled, unclear license), MiSTer sdram.v (GPL, never on
MEGA65). NOTE: MEM_RAM_49_DDR2.v parks the storage region at 64 MiB
offset, which does not exist on a 64 MB part - REGION_BASE_UNITS moves
(e.g. 32 MiB), one parameter + the arbiter.

**Framework: HYBRID - bare-metal first, M2M as the release face.**
The M2M study (source-verified against M2M/vhdl/vdrives.vhd and the
make_release.py wiki page): the virtual-drive facility implements the
MiSTer SD protocol (per-drive LBA + block buffer, BLKSZ 128..16384, up to
10 drives, read AND write with dirty/flush management, proven read/write
in the shipping C64 core) and maps structurally ~1:1 onto our
tape/floppy/WD seams - it could retire the whole SD-FAT stack on this
platform, with the Shell's OSD file browser for image selection. TWO
gates before committing to it: (a) THROUGHPUT UNKNOWN - sectors are
served by the 50 MHz QNICE soft CPU parsing FAT32 in firmware, designed
for floppy-class traffic; SINTRAN is measured disc-bound with
Winchester-class random paging, and no M2M core with a hard-disc-class
vdrive exists as precedent. Benchmark sd_rd->sd_ack for random LBAs in a
75 MB image FIRST. (b) The console: M2M's UART belongs to QNICE's debug
monitor; the framework's native I/O is keyboard+HDMI, so an M2M ND-120
needs a terminal-emulator front-end (char generator + screen buffer +
key mapping) - the single largest new item, and once built it serves the
bare-metal top equally. Bare-metal meanwhile drives the same
JTAG-adapter UART pins directly, exactly like the Nexys console.
No non-MiSTer core has been ported through M2M yet - the ND-120 would be
the first. make_release.py packages per-revision .cor files + config
persistence + versioning (needs CORE/release.toml, version constant in
config.vhd); bare-metal can still emit a .cor via bit2core but gets no
config/slot conventions.

## Phases

| Phase | Content | Exit gate |
|---|---|---|
| 0 | Research: RAM controller pick + M2M decision | **DONE 27-AUG** - MJoergen/SDRAM + hybrid path, above |
| 1 | Memtest bitstream: chosen SDRAM controller + `nd_sdram_port` adapter + the nexys4ddr `sd-fat-test`-style memtest, on real R4+ silicon | measured latency table; the port contract benched (mirror `test-ddr2port`/`test-ddr2arb` benches) |
| 2 | Bring-up top: ND-120 core + SDRAM backend + TE0790 UART console + our SD-FAT stack on the internal slot; OPCOM answers | OPCOM over the TE0790 at 115200 7E2 |
| 3 | SINTRAN boot from SD image (still our FAT stack) | banner + Watchdog, boardtest scripts pass |
| 3.5 | QNICE vdrive throughput benchmark (the M2M gate): random-LBA sd_rd->sd_ack latency against a 75 MB image on real hardware | a measured table that says Winchester-class paging is feasible or not |
| 4 | M2M integration (gated on 3.5): virtual drives replace the FAT stack; terminal-emulator front-end (char gen + screen buffer + MEGA65-key mapping) gives the console on the machine's own keyboard/HDMI | boot + login using only the MEGA65's own keyboard/screen/SD |
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

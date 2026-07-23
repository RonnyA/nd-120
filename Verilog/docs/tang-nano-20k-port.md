# ND-120 on Tang Nano 20K (Gowin GW2AR-18) — Port Analysis

**Full path:** `/mnt/e/Dev/Repos/Ronny/nd-120/Verilog/docs/tang-nano-20k-port.md`
**Last updated:** 2026-07-04

Analysis of moving the ND-120 FPGA target from Basys3 (Xilinx `xc7a35t`) to the
Tang Nano 20K (Gowin `GW2AR-18`): the define scheme needed, the memory
architecture (the one real catch), and whether the Gowin roundtrip beats Vivado.

## 1. Board comparison

| Resource | Basys3 (`xc7a35t`) | **Tang Nano 20K (`GW2AR-18`)** | Impact |
|---|---|---|---|
| LUTs | 33,280 (LUT6) | **20,736 (LUT4)** | Fewer + LUT4 — **fit is the top risk** |
| Flip-flops | 41,600 | 15,552 | Fewer |
| Block SRAM | ~1,800 Kbit (50xRAMB36) | **828 Kbit (46 blocks)** | **Less BRAM — microcode won't all fit (see 3)** |
| Big RAM | none (Basys3 has no DRAM) | **8 MB SDRAM (64 Mbit, 32-bit SDR)** | **Killer feature — full main memory** |
| Clock | 100 MHz | 27 MHz xtal + MS5351 + **2 PLLs** | Need Gowin `rPLL` for CPU clock |
| Config flash | — | 64 Mbit | Can hold microcode |
| Programmer | Digilent JTAG | BL616 USB (JTAG/UART/SPI), openFPGALoader | **Linux-native programming possible** |

Net: the Tang has **less logic and less BRAM** but **8 MB SDRAM** and a
**faster, Linux-friendly toolchain**. The SDRAM and toolchain are the wins; the
LUT/BRAM budget is the risk.

## 2. Why this helps the project

1. **SDRAM = run the full memory config, like the sim.** The Basys3 forced
   `MEM_RAM_49` to `RAM_SIZE=3` (4 KB) because it has no large RAM. With 8 MB
   SDRAM, the FPGA main memory can match the sim's large RAM — **removing the
   biggest sim-vs-FPGA `ifdef` difference** (the one you wanted to keep as the
   only legit divergence). See `docs/build-defines.md`.
2. **Faster roundtrip.** `GW2AR-18` is small; Gowin place & route is minutes vs
   Vivado's ~1 h full synth. Iteration cost drops a lot.
3. **Linux-native flow.** The OSS toolchain (yosys `synth_gowin` +
   nextpnr-himbaechel/apicula + openFPGALoader) runs on **WSL/Linux** — no
   Windows/Vivado context switch. Prior artifacts (`Verilog/Verilog.json`,
   `Verilog_pnr.json`) show yosys+nextpnr was already run here in 2024. This can
   collapse the current "some on WSL, some on Windows" split into one flow.

## 3. The catch: BSRAM is too small for PROM + WCS together

The microcode path uses (confirmed from `CPU_CS_16.v`: `CSBITS` is **64-bit
wide**, `LUA_12_0` is **13-bit** = 8192 words) up to THREE block memories:
- **Microcode PROM** (`CPU_CS_PROM_19.v`) — 64 KB (32K x 8 x 2) = **512 Kbit**.
- **Writable Control Store (WCS)** (`CPU_CS_WCS_21_22.v`) — 8192 x 64-bit =
  **512 Kbit**. This is the copy the CPU actually executes from.
- **TCV/TCW** (`CPU_CS_TCV_20.v`) — another 64-bit control-store store used during
  load — potentially up to another ~512 Kbit.

**Your plan "BSRAM only for the EPROM AND the WCS copy" does NOT fit:** PROM
(512) + WCS (512) = **1024 Kbit alone, already > 828 Kbit**, before TCV/cache.
On the Basys3 (1800 Kbit) both fit; on the Tang they cannot.

**But you do not need the microcode in BSRAM twice.** Note there is no real
"EPROM" inside the FPGA — both the "EPROM" and the WCS are just block RAM.
Contents get into block RAM either (A) **baked into the bitstream** via
`$readmemh` (the FPGA pre-loads the BRAM at power-on — what the Basys3 build does
today), or (B) **loaded at runtime** by a state machine from external flash/SDRAM.
The design keeps the microcode in BRAM *twice* (EPROM copy + WCS copy) only
because it faithfully reproduces the hardware's EPROM->WCS boot copy (the LCS
sequence = Phase 1). On Tang, de-duplicate — three options:

| Option | EPROM | WCS | Boot copy | BSRAM |
|---|---|---|---|---|
| A. Duplicate (current) | BRAM (bitstream) | BRAM | runs LCS | ~1024 Kbit — won't fit |
| B. EPROM in flash | config flash | BRAM | loader flash->WCS | ~512 Kbit — fits |
| C. **Bitstream-init WCS directly** | gone | BRAM (bitstream) | skip/no-op LCS | ~512 Kbit — fits, simplest |

**Option C is cleanest for FPGA:** `$readmemh` the microcode straight into the
WCS BRAM (one copy, pre-loaded by the bitstream), drop the separate EPROM BRAM,
and skip the ~573K-tick load phase. **Caveat:** the reset/boot logic
(`LCS_n` state machine in `CYC_36`/`CPU_CS_16`) expects to run the LCS sequence;
with a pre-loaded WCS that must become a harmless no-op or be bypassed — verify
against the boot logic. Option B keeps the LCS sequence intact (sources it from
flash instead of EPROM-BRAM) — more faithful, more work. This is what the empty
`ifdef GOWIN` branch in `CPU_CS_PROM_19.v` was reaching toward.

**This is exactly why the `GOWIN` branch in `CPU_CS_PROM_19.v` contemplated SPI
flash** (currently an empty placeholder, `regData <= 0`). The right Tang memory
architecture is:

| Memory | Basys3 | **Tang Nano 20K** |
|---|---|---|
| Microcode source (PROM) | BSRAM (`$readmemh`) | **64 Mbit config flash** (read at boot) or SDRAM |
| Writable Control Store (WCS) | BSRAM | **BSRAM** (keep here — fast, single-cycle) |
| Control-store cache (IDT6168A) | BSRAM | BSRAM |
| Main memory | tiny BSRAM (4 KB) | **8 MB SDRAM** (via nand2mario controller) |

So PROM moves out of BSRAM (to flash/SDRAM), freeing BSRAM for WCS + cache, and
main memory moves to SDRAM.

## 3b. Fit check RESULT (real Gowin synth, 2026-07)

`yosys synth_gowin` for `GW2AR-18` completed (via oss-cad-suite on WSL) after
stubbing the Xilinx MMCM/BUFGMUX clock prims, swapping 5 TTL FF primitives for
yosys-mappable equivalents, and forcing the async-read register file + MMU cache
to logic. Flattened result:

| Resource | Used | GW2AR-18 has | Verdict |
|----------|------|--------------|---------|
| **LUT4** | 5,997 base (LUT1-4) + ~1,645 wide-mux + 320 distributed-RAM ~= **8-10k effective** | 20,736 | **fits easily (~40-50%)** |
| **DFF** | ~1,370 | 15,552 | trivial |
| **BSRAM** (SP 51 + SPX9 38) | **89 blocks** | **46** | **~1.9x OVER - does NOT fit** |

**Corrected conclusion: LUTs are NOT the risk (they fit with big headroom).
BSRAM is the constraint, and tighter than first estimated.** 89 blocks vs 46:

Approximate block budget (512 Kbit / 18 Kbit-block):
- **WCS** (512 Kbit) ~= **29-32 blocks** - the dominant consumer (~65% of the 46),
  and *fixed* (microcode is 8192 x 64). One `reg[63:0]` array vs the 32 `IDT6168A`
  chips packs to about the same block count - so restructuring the WCS is a
  **preload simplification, not a block saver**.
- **PROM** (512 Kbit) ~= **30-32 blocks** - removable (boot-only copy).
- **main RAM** (ramSize=3) ~= **~11 blocks** - movable to SDRAM.

- **The real BSRAM wins are: drop the PROM (SKIP_WCS + GOWIN) and move main RAM to
  SDRAM.** After both, BSRAM ~= WCS (~30) + control-store cache + small ~= **~35-46
  blocks - a tight fit.** The WCS floor (~30) means there is little headroom; the
  control-store cache and any other array must stay out of BSRAM (map to logic).

The BSRAM-rearrange + SDRAM implementation plan: `docs/tang-bsram-sdram-plan.md`.
(Exact *placed* utilization needs nextpnr; blocked because `ND120_TOP.cst` uses
Gowin-EDA pin syntax that apicula's parser rejects - or use Gowin EDA synth.)

## 4. Proposed define scheme (board-target)

Today `GOWIN` is scattered/placeholder and `VERILATOR_SIM` overloads three
concerns (see `docs/build-defines.md`). Introduce **one board-target selector**
and derive capabilities from it:

```verilog
// Exactly one target is defined by the build:
//   VERILATOR_SIM    simulation
//   TARGET_BASYS3    Xilinx xc7a35t
//   TARGET_TANG20K   Gowin GW2AR-18

`ifdef TARGET_TANG20K
  `define GOWIN                      // vendor primitives (BSRAM, rPLL, etc.)
  `define BOARD_CLK_FREQ 27_000_000  // consumed by SC2661_UART.v (already parameterized)
  `define MICROCODE_IN_FLASH         // PROM source = config flash, not BSRAM
  `define MAIN_RAM_SDRAM             // MEM_RAM_49 backend = SDRAM controller
`endif
`ifdef TARGET_BASYS3
  `define BOARD_CLK_FREQ 100_000_000
`endif
```

Guidelines:
- Keep `BOARD_CLK_FREQ`/`UART_BAUD_RATE` as-is — they are already the correct
  parameterized pattern; the Tang just sets 27 MHz (or the PLL output).
- Replace the empty `ifdef GOWIN` in `CPU_CS_PROM_19.v` with a real backend:
  either `MICROCODE_IN_FLASH` (SPI read state machine) or, for a first bring-up,
  keep `$readmemh` BSRAM **only if** the fit check (section 3) says it fits.
  Note the existing attribute already has `syn_ramstyle="block_ram"` for Gowin,
  so generic `$readmemh` BSRAM inference works on Gowin where it fits.
- Gate the SDRAM main-memory path behind `MAIN_RAM_SDRAM` inside `MEM_RAM_49.v`,
  leaving the BSRAM path for Basys3/first-bring-up.

## 5. What needs to be built (new modules)

1. **Tang top-level** `ND120_TOP_TANG20K.v` (or a board wrapper) — 27 MHz clock
   input, `rPLL` instance to generate the CPU clock (+ a phase-shifted SDRAM
   clock), Tang pinout constraints (`.cst` file), LEDs/UART pins.
2. **Gowin `rPLL` clock module** — replaces the Xilinx clocking. 27 MHz -> CPU
   clock; SDRAM needs its own (often ~64-84 MHz) phase-shifted clock.
3. **SDRAM adapter** — bridge the ND-120 memory interface (`MEM_RAM_49`:
   `AA_9_0`, `BANK0/1/2`, `RAS`, `CAS`, `MWRITE50_n`) to the nand2mario
   Tang-Nano-20K SDRAM controller. The ND-120 already models DRAM with RAS/CAS,
   so the mapping is conceptually aligned but needs an FSM + read latency handling.
4. **Microcode-from-flash loader** (if `MICROCODE_IN_FLASH`) — SPI read of the
   64 Mbit config flash into WCS at boot, replacing the PROM->WCS copy.
5. **Gowin `.cst` constraints** + build script (Gowin `gw_sh` or the OSS flow).

## 6. Toolchain and roundtrip

Two options, both viable:

**A. Gowin EDA (vendor)** — `gw_sh` (Tcl) for scripted synth+P&R, or GUI. Runs on
Windows or Linux. Minutes per run. Has GAO (Gowin Analyzer Oscilloscope) = the
ILA equivalent for on-chip capture.

**B. OSS flow (recommended to try — Linux-native)** —
`yosys -p 'synth_gowin -json out.json'` -> `nextpnr-himbaechel --device GW2AR-...`
-> `gowin_pack` -> `openFPGALoader`. All on WSL. Prior `Verilog.json`/`_pnr.json`
show this was started in 2024. No Windows needed for build; programming via
openFPGALoader over the BL616 USB (may need `usbipd` USB passthrough into WSL, or
just program from Windows).

**Roundtrip verdict:** **yes, expect it to be faster than Vivado** — smaller
device (minutes not ~1 h) and, with the OSS flow, no Windows context switch. The
trade-offs: (a) the design must **fit** 20,736 LUT4 (fewer than Basys3 — verify),
(b) OSS Gowin support for large designs is good but less mature than Vivado, so
be ready to fall back to Gowin EDA if yosys/nextpnr chokes, (c) GAO vs Vivado ILA
for on-chip debug — or lean on the UART debug streamer (fast roundtrip makes
re-flashing cheap).

## 7. Staged plan

- **G0 Fit check (do first):** run Gowin synth (EDA or yosys) on the current RTL
  for `GW2AR-18`; read LUT and **BSRAM** utilization. Decide PROM placement
  (BSRAM vs flash) from the real numbers. Go/no-go on the whole port.
- **G1 Minimal bring-up (BSRAM only):** Tang top + `rPLL` clock + Tang `.cst`;
  microcode from flash **or** trimmed BSRAM; main RAM small in BSRAM (like
  Basys3). Goal: boot reaches the golden `boot-golden-spec.md` phases. Fast
  iteration proves the flow.
- **G2 Validate boot:** capture with GAO (or UART debug stream) -> reduce to
  `MA @ posedge MACLK` -> diff against `docs/boot-golden-spec.md`. Same detection
  rule as the Vivado path.
- **G3 SDRAM main memory:** integrate the nand2mario controller behind
  `MAIN_RAM_SDRAM`, giving full 8 MB main memory = parity with the sim's large
  RAM. Removes the last big sim-vs-FPGA memory `ifdef`.

## 7b. On-chip debug access (can we see internal signals? YES)

We are **not** in trouble on debug — Gowin has an on-chip logic analyzer:

- **GAO (Gowin Analyzer Oscilloscope)** — the direct Vivado-ILA equivalent.
  Captures selected internal nets into BSRAM on a trigger and reads them back over
  JTAG (via the BL616). Set up in Gowin EDA (add a GAO core, pick nets, set
  trigger), then view/export the capture. This is the primary "see internal
  signals" path. Export to CSV -> same `MA @ posedge MACLK` comparison against
  `boot-golden-spec.md`.
- **`mark_debug`/`DONT_TOUCH` in the RTL are Xilinx-oriented.** For GAO, either
  select nets in the GAO GUI, or add Gowin/Synplify keep attributes
  (`syn_keep`/`syn_preserve`) so P&R does not optimize the net away. The existing
  `DONT_TOUCH` helps but may need the Gowin-equivalent keep.

**The catch, and the better primary tool here:** GAO's capture buffer **also uses
BSRAM** — the same scarce 828 Kbit the microcode WCS needs. On Basys3 you already
had to shrink the ILA depth (4096 -> 2048); on the Tang, with WCS consuming most
BSRAM, GAO capture depth will be **very shallow**. So make the **UART debug event
streamer** (see `FPGA-BRINGUP-PLAN.md` Section 12) the primary instrument on Tang:
it uses ~no BSRAM, gives a full-length boot trace, and — because the Gowin
roundtrip is fast — re-flashing to move probes is cheap. Use GAO for short,
zoomed-in captures once you know roughly where to look.

Bottom line: internal-signal visibility exists (GAO), and the BSRAM-free UART
streamer covers the long traces GAO cannot on this small device.

## 8. Risks / open questions

- [ ] **Fit:** does the design fit 20,736 LUT4 and 828 Kbit BSRAM? (G0 answers.)
- [ ] **Timing:** CPU clock from 27 MHz `rPLL` — what target frequency closes?
      The derived-clock logic is now synchronous (proven in FF sim), so this
      should behave, but Gowin timing must still be met.
- [ ] **SDRAM latency:** the ND-120 RAS/CAS memory model vs real SDRAM read
      latency — the adapter FSM must stall the CPU cycle correctly.
- [ ] **USB programming from WSL:** openFPGALoader needs the BL616 device; via
      `usbipd` passthrough, or program from Windows.
- [ ] **OSS maturity:** yosys/nextpnr for `GW2AR-18` at this design size —
      validate against Gowin EDA if issues.

## 9. References
- Board: https://wiki.sipeed.com/hardware/en/tang/tang-nano-20k/nano-20k.html
- SDRAM controller: https://github.com/nand2mario/sdram-tang-nano-20k
- `docs/build-defines.md` — the ifdef unification plan this extends.
- `CPU-BOARD-3202/circuit/CPU_CS_PROM_19.v` — microcode PROM (GOWIN placeholder).
- `CPU-BOARD-3202/circuit/MEM_RAM_49.v` — main RAM (RAM_SIZE / backend).
- `Verilog/Verilog.json`, `Verilog_pnr.json` — prior yosys/nextpnr artifacts.
- `Verilog/TODO.md:71` — Tang Nano SPI-flash-for-microcode note.

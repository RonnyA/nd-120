# ND-120 FPGA — Release 2 (bitstreams-2026-09)

Ready-built bitstreams so you can run the 1988 Norsk Data ND-120 CPU without
installing Vivado, Gowin or Quartus. Attached to this GitHub Release; the
binaries are never checked into git.

**Source commit:** `b09302e` — *mega65: the whole ND-120 machine on the
MiSTer2MEGA65 framework, both revisions*.

**What is new since Release 1 (bitstreams-2026-08):**
- **MEGA65** — the whole machine, first release, two cores (see below).
- **MiSTer (DE10-Nano)** — first release, TDV2200 console.
- The real **TDV2200 box-drawing font** (character set 2, dumped from
  RetroCore), now **embedded in `font_rom.v`** so every board carries the
  correct glyphs with no loose hex file to copy.
- The physical **Left-arrow key** fix (the Nexys USB-PS/2 bridge drops the E0
  prefix; Left arrives as bare `0x6B`).
- A fourth power-on **banner line**: board / CPU clock / cache on-off, filled
  in from the build settings.

**Console settings — every file, no exceptions:** 115200 baud, **7 data bits,
EVEN parity, 1 stop bit**, no flow control. One terminal setting for the whole
release.

---

## Artifacts

| File | Board | Format | CPU clock | Verified |
|---|---|---|---|---|
| `nd120_mega65_rev3_13MHz_115200.cor` | MEGA65 **R3 / R3A** | `.cor` | 13.33 MHz | **Built + timing-clean. NOT yet run on a MEGA65.** |
| `nd120_mega65_r6_20MHz_115200.cor` | MEGA65 **R4 / R5 / R6** | `.cor` | 20 MHz | **Built + timing-clean. NOT yet run on a MEGA65.** |
| `nd120_nexys4ddr_33MHz_115200.bit` | Nexys 4 DDR | `.bit` | 33.333 MHz | *pending — refresh build in preparation* |
| `nd120_tang20k_fast20_20MHz_115200.fs` | Tang Nano 20K | `.fs` | 20.25 MHz | *pending — refresh build in preparation* |
| `nd120_mister_20MHz_115200.rbf` | MiSTer (DE10-Nano) | `.rbf` | 20 MHz | **Built + run on a DE10-Nano (02-SEP-2026): boots to OPCOM, boots SINTRAN from a mounted Winchester image, TDV2200 font and keyboard confirmed.** |
| `SHA256SUMS` | — | — | — | regenerated when the whole set is final |

The two MEGA65 cores and the hardware-verified MiSTer `.rbf` are attached; the
Nexys/Tang refresh is added as each is built and checked, and the combined
`SHA256SUMS` is regenerated at that point.

### SHA-256 (MEGA65 cores + MiSTer)

```
e936a868414cb355dfdaf3b209bc147eea0c40511965543d07e110205ec78dbb  nd120_mega65_rev3_13MHz_115200.cor
28f7d186be0cf914e884d7d0a75526aa833b1b3b76b1a4f3903c111eec312cd0  nd120_mega65_r6_20MHz_115200.cor
deb9e1ea499baa0dab8d6595f01f696a360b4df536209d9d42b0397df680520a  nd120_mister_20MHz_115200.rbf
```

---

## MEGA65 — read this first

**These two cores are built and timing-clean, but no MEGA65 was available to
run them on. You are the verification channel.** They go out labelled
"not yet run on a MEGA65". [`QUICKSTART-mega65.md`](https://github.com/RonnyA/nd-120/blob/bitstreams-2026-09/Verilog/fpga/QUICKSTART-mega65.md) tells you what to see and what
to report back.

**Pick the core for your board revision — the flash menu refuses a
wrong-model `.cor`:**

- **R3 / R3A** → `nd120_mega65_rev3_13MHz_115200.cor` (13.33 MHz). The 4 MB of
  ND-120 memory lives in the board's **HyperRAM** (Nexys cache seam + an Avalon
  port). Timing: WNS +0.093 ns, WHS +0.035 ns.
- **R4 / R5 / R6** → `nd120_mega65_r6_20MHz_115200.cor` (20 MHz). The 4 MB lives
  in the board's **64 MB SDRAM** (the MiSTer sheet-49 bridge). Timing:
  WNS +0.249 ns, WHS +0.003 ns. Built for R6; R4/R5 rebuild from source with
  `BOARD=r4` / `BOARD=r5` (same memory, different top).

Both cores are the whole machine: CPU, 4 MB memory, TDV2200 console on the
MEGA65's own keyboard and screen, and the framework's virtual floppy 0/1 +
Winchester 0/1 + tape. Build stamp `e5bdea5+ 02-Sep-2026 16:27`.

**What to report:** does the power-on banner render (including the box-drawing
lines), does the Left arrow work, does OPCOM answer, does `20500&` run — and the
power LED verdict. Details in [`QUICKSTART-mega65.md`](https://github.com/RonnyA/nd-120/blob/bitstreams-2026-09/Verilog/fpga/QUICKSTART-mega65.md).

---

## How to load them

- **MEGA65** — `.cor` files flash from the MEGA65's own core menu; SD card holds
  the `/nd120` disc images. Full walkthrough: **[`QUICKSTART-mega65.md`](https://github.com/RonnyA/nd-120/blob/bitstreams-2026-09/Verilog/fpga/QUICKSTART-mega65.md)**.
- **Nexys 4 DDR** — microSD config at power-on (one card carries the `.bit` and
  the disc image), or Vivado/openFPGALoader over USB-JTAG.
  See **[`QUICKSTART-nexys4ddr.md`](https://github.com/RonnyA/nd-120/blob/bitstreams-2026-09/Verilog/fpga/QUICKSTART-nexys4ddr.md)**.
- **Tang Nano 20K** — `openFPGALoader -f` writes onboard SPI flash once, boots
  the ND-120 at every power-on after. See **[`QUICKSTART-tang-nano-20k.md`](https://github.com/RonnyA/nd-120/blob/bitstreams-2026-09/Verilog/fpga/QUICKSTART-tang-nano-20k.md)**.
- **MiSTer (DE10-Nano)** — copy `nd120_mister_20MHz_115200.rbf` to the SD card
  as `/media/fat/_Computer/ND120.rbf` and load it from the MiSTer menu. Attach
  a Winchester image (for example `WD0.IMG`) from the OSD, then at the `#`
  monitor type `&` to boot it. The console is the MiSTer's own screen and
  keyboard; the CPU's serial line is also on the HPS `/dev/ttyS1` at 115200.

**Disc image is not in the release** (instructions only): the machine needs a
Winchester image on the card's FAT root. A bitstream with no image still comes
up in OPCOM — the quickstarts use that as the "it works" smoke test.

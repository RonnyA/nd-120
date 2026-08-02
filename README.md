# ND-120 CPU

## Content

This repo contains:

* Original **Norsk Data** ND-120 CPU Design Documents from 1988. Scanned in 2023
* Modern Logisim and HDL implementation from 2023.

You can read more about this [CPU](https://www.ndwiki.org/wiki/3202) and much more in [NDWiki](https://www.ndwiki.org/) and the official website for [Norsk Data](http://sintran.com/)

The goal of this repo is to re-create the schematics and create the HDL files so we can program an FPGA to run as the original ND-120 CPU Card.

On the way to the FPGA code, there will be testable Logisim Circuits and Logisim code that can be converted and tested in C++ using Verilator.

## Current Status

**Simulation (Verilator, the golden reference):**
- Microcode loads, Master Clear executes, and the CPU self-test passes
  clean: **0 execution-phase STERR visits** (measured with the
  `ND120_COUNT_STERR` probe)
- **13 of 13 testable INSTRUCTION-B areas pass** on both layers - each
  area's own end-of-test with zero error lines, and the 400-instruction
  golden-trace comparison against the ND-110 reference
  (`Verilog/tests/instruction-verify/CAMPAIGN-STATUS.md`). The
  48-bit floating area is not applicable: our PROM microcode implements
  the 32-bit float option.
- OPCOM console works; `INSTRUCTION-B` loads and runs from the Verilog
  papertape device; DMA bus mastering against the real arbiter
- Golden-console and latch-vs-FF regression gates keep it all pinned

**FPGA hardware:**
- **Basys3**: OPCOM boots on the board (tag `fpga-opcom-working-basys3`);
  active debug line at 16.67 MHz
- **Tang Nano 20K**: full CPU bitstream with **4 MB SDRAM main memory**
  (packed 16-bit storage, computed parity - `ND_SDRAM_PACK16`), the other
  4 MB reserved for the SD disk-image cache; SD/FAT stack proven on
  hardware (read + write, safety-gated)
- **Dual toolchain**: the Tang builds with the OSS CAD Suite
  (yosys/nextpnr, primary) and Gowin EDA (backup) - all clock variants;
  nextpnr closes the full 27/54 MHz target with >2x margin
  (`Verilog/docs/tang20k-build-flows.md`)
- **Cmod A7-35T**: first build ready (BRAM memory, CPU at 27 MHz);
  512 KB SRAM main-memory bridge planned
  (`Verilog/fpga/cmod-a7-35t/SRAM-BRIDGE-PLAN.md`)
- Memory-backend speed rules for every board (what meets the no-wait-state
  protocol at 40 MHz and what cannot):
  `Verilog/docs/basys3-memory-speed-validation.md`

## Quick Start

```bash
cd Verilog/sim
make clean
make all  # Compiles, runs, and opens GTKWave
```

**Prerequisites:** [Verilator](https://www.veripool.org/verilator/), Icarus Verilog, GTKWave (optional). Development is done on Linux / WSL2 with bash.

See [BUILDING.md](BUILDING.md) for detailed build and test instructions.

## Requirements

The minimum requirements to make the CPU work:

| Component | Schematic | HDL | Status |
|-----------|-----------|-----|--------|
| [DELILAH CPU Gate Array (CGA)](DesignDocuments/DELILAH-CPU/readme.md) | Completed | Logisim generated Verilog | QA on schematic/Verilog ongoing |
| [NEC Decoder Gate Array (DGA)](DesignDocuments/DECODE-GateArray/readme.md) | Completed | Logisim generated Verilog | QA on schematic/Verilog ongoing |
| [ND 3202 CPU Board revision D](DesignDocuments/CPU-BOARD-3202/Readme.md) | Completed | Logisim generated Verilog | QA on schematic/Verilog ongoing |
| [PAL Chips](DesignDocuments/PAL-Code/Readme.md) | All PALASM code has been validated | Verilog and testcode created | QA on Verilog ongoing |

In the CPU Board we will plug in the DELILAH CPU and the Decoder, all PAL chips and several other support chips (74-series, RAM and UART).

## History

The compressed history of the work progress has moved to [HISTORY.md](HISTORY.md).

## Design documents

All the design documents are in the [Design Documents](DesignDocuments/Readme.md) folder.

## Norsk Data documents

Functional Description, Instruction set, Microprogramming guide and more are in the [NorskData-Doc](NorskData-Doc/Readme.md) folder.

## Microcode

The [Microcode](Code/Microcode/readme.md) dump is from a ND-120 3202 CPU Board is Version 14/L
The source code is also for the L version.

## Panel Controller - 6805 CPU CHIP

[ROM dump](Code/68705/readme.md)

The ND-120/CX CPU Board has an on-board MC68705-U3 CPU.

The physical front panel also has an MC68705 CPU, however this chip is not identical to the on on the 3202D CPU Board - its an MC68705-P3 with fewer I/O pins.

The MC68705 is an MC 6805 8-bit CPU with on-chip RAM, I/O and Timer. [Motorola 68HC05](https://en.wikipedia.org/wiki/Motorola_68HC05)

* P3 version = 28 pins, 2x 8 bits I/O ports, 1x 4 bit I/O port
* U3 version = 40 pins, 4x 8 bits I/O ports

We have a ROM dumps from both the *MC68705-U3* chip (from the 3202D CPU Board) and the *MC68705-P3* (from an ND-5000C panel controller).

**Big thanks to Matthieu Benoit for reading the data out of the chips**

Reverse engineering has been done using the free SRE tool [GHIDRA](https://ghidra-sre.org/) from NSA.

## Schematic drawings

### Logisim

All the Logisim files are stored in the [Logisim folder](Logisim/readme.md)

#### Logisim Requirements

You need to install the Logisim-Evolution design tool from [Logisim Evolution Repository](https://github.com/logisim-evolution/logisim-evolution)

The Logisim diagrams has been drawn with [Version 3.8.0](https://github.com/logisim-evolution/logisim-evolution/releases/tag/v3.8.0)

## FPGA

### FPGA Hardware

The project targets several FPGA boards, each with its own folder of build
scripts, pin constraints, vendor documentation and bring-up plans under
[Verilog/fpga/](Verilog/fpga/README.md).

**For the current per-board FPGA status, target line-up and priority order,
see [Verilog/fpga/README.md](Verilog/fpga/README.md).**

### Verilog

Most Verilog files were originally generated from the Logisim drawings using the
Logisim-Evolution FPGA tools. They are **no longer regenerated** - the Verilog and
the schematics are now both maintained by hand, so a fix has to be made in both
places.

All the Verilog files are stored in the [Verilog folder](Verilog/)

### Verilator

To test the Verilog code using Verilator you need to install the [Verilator](https://www.veripool.org/verilator/) tool

## Documentation

Paths in this repository are always relative to the repository root. Where a
document has to point at one of the *other* ND repositories, it writes
`$ND_REPOS/<repo>/...` - set `ND_REPOS` to the directory that holds your ND
checkouts.

| Document | Description |
|----------|-------------|
| [BUILDING.md](BUILDING.md) | Build instructions, testing, and troubleshooting |
| [HISTORY.md](HISTORY.md) | Project history, milestone by milestone |
| [DEVELOPMENT.md](DEVELOPMENT.md) | Architecture, coding standards, and contribution guide |
| [HARDWARE.md](HARDWARE.md) | Hardware specifications and component details |

## Acknowledgments

- **Lasse Bockelie** - Provided original 1988 design documentation
- **Matthieu Benoit** - ROM chip reading and data extraction
- **NDWiki Community** - Comprehensive ND-120 documentation
- **GHIDRA Team** - Reverse engineering tools
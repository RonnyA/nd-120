# SD-card BPUN loading and ND-100 device emulation - design plan

Status: MILESTONE 1 IMPLEMENTED 10/11-JUL-2026 (SD-FAT library +
Tang Nano 20K sd-fat-test: LIST/DUMP/COPY/1KW-block-write menu, all sims
green, bitstream builds - see Verilog/SD-FAT/README.md and
Verilog/fpga/tang-nano-20k/sd-fat-test/README.md; awaiting hardware run).
Sections 1-9 below are the original design; deviations are documented in
the two READMEs (notably: the write path landed EARLY as the clean-room
sd_writer.v with in-place rewrites - Route B - and the 1-kiloword block
map; milestone ordering in docs/device-bus-todo.md supersedes section 10+).
Last reviewed: 11-JUL-2026
Scope: SD card + FAT filesystem access on the FPGA boards, an emulated
ND-100 paper tape reader (device 400 octal) that reads .BPUN files from
the SD card, and the roadmap to floppy and SMD/HDD image emulation on
the same SD stack.

All paths in this document are relative to the repository root
`/mnt/e/Dev/Repos/Ronny/nd-120/` unless written as full paths.
Anything not confirmed against a primary source is marked UNVERIFIED.

---

## 1. Overview

The ND-120 CPU recreation boots ND software the way the original did:
the microcode binary loader (MOPC `$` / `&` / LOAD) reads a BPUN-format
program stream byte-by-byte from an I/O device. In the Verilator
simulation this already works end-to-end: a C++ `PaperTape` device at
IOX address 400 octal (`Verilog/simDevices/NDDevices.cpp`) serves BPUN
files over the emulated ND-100 bus.

On real FPGA hardware there is no such device yet - the ND-100 bus
inputs are tied inactive in `Verilog/ND120_TOP.v` (FPGA branch of the
`ifdef VERILATOR_SIM` blocks). This plan adds:

1. An SD-card + FAT filesystem block (read-only first, read/write later).
2. A reusable "Device Bus Interface" that implements, in Verilog, the
   device side of the ND-100 bus handshake that
   `Verilog/simDevices/NDBus.cpp` implements in C++.
3. A TapeReader device (400 octal) that streams a .BPUN file from the
   SD card into the CPU exactly like a paper tape reader.
4. Later: Floppy (1560 octal) and SMD controller devices backed by
   image files on the same FAT filesystem (requires FAT write).

Milestone 1 (section 9) is deliberately small: a standalone Tang Nano
20K project that mounts the SD card, finds a `.BPUN` file on a FAT
filesystem, and hex/octal-dumps it over UART - proving SD + FAT on
real silicon before any CPU integration.

```mermaid
flowchart LR
  SD[microSD card]:::blue --> FAT[SD/FAT reader]:::teal
  FAT --> FIFO[async FIFO CDC]:::teal
  FIFO --> TAPE[TapeReader dev 400]:::orange
  TAPE --> BUSIF[Device Bus Interface]:::teal
  BUSIF --> CPU[ND-120 CPU BIF]:::green
  classDef blue fill:#E3F2FD,stroke:#0D47A1,color:#0D47A1
  classDef teal fill:#E0F7FA,stroke:#00838F,color:#00838F
  classDef green fill:#E8F5E9,stroke:#2E7D32,color:#2E7D32
  classDef orange fill:#FFF3E0,stroke:#E65100,color:#E65100
```

---

## 2. Requirements

From the project owner:

- R1: Read BPUN files from the microSD slot on the Tang Nano 20K;
  later also on the Basys3 via a Pmod microSD adapter.
- R2: A device-400 tape-reader device that reads BPUN files from a FAT
  filesystem on the SD card.
- R3: Filesystem access read-only is sufficient for BPUN; read/WRITE
  is needed later for floppy and HDD image emulation.
- R4: All new Verilog lives OUTSIDE the CPU board folders
  (`Verilog/CPU-BOARD-3202/`, `Verilog/DELILAH-CPU/`,
  `Verilog/DECODE-GateArray/`) in new reusable component folders:
  one for the Device Bus Interface, one for the FAT filesystem, one
  per device (TapeReader now; Floppy and SMD later). Each component
  follows the repo's `circuit/` + `sim/` convention with iverilog and
  Verilator testbenches.
- R5: First milestone is a small standalone top (pattern:
  `Verilog/fpga/tang-nano-20k/sdram-test/`) that mounts SD, reads FAT,
  finds a .BPUN file and dumps it over UART.

Repo conventions that apply (from the project instructions and existing
code):

- Internal signals `s_` prefix; active-low `_n` suffix; buses
  `NAME_15_0` style.
- No `z` tri-states inside the FPGA - disabled drivers output `0`
  and a mux/OR combines sources (see `Verilog/Shared/support/` TTL
  models such as `TTL_74245`).
- Plain ASCII in all sources and docs.
- Every new self-checking testbench MUST be registered in
  `Verilog/tests/run_all_tests.sh` and print a machine-checkable
  verdict (`TB_RESULT: PASS` convention).
- CPU-side logic is single-clock `sysclk` with clock enables - no new
  derived clock domains on the CPU side (this is the hard-won rule of
  the clock-enable refactor; see
  `Verilog/docs/plan-fix-unconstrained-clocks.md`).

---

## 3. Existing assets inventory

### 3.1 In this repository

| Asset | Path | Relevance |
|---|---|---|
| C++ PaperTape device (register semantics, working in sim) | `Verilog/simDevices/NDDevices.cpp` lines 28-199, `Verilog/simDevices/NDDevices.h` lines 229-317 | Golden reference for TapeReader-400 behavior |
| C++ ND-100 bus device-side protocol | `Verilog/simDevices/NDBus.cpp` (`proccess_bif_signal()`) | Golden reference for the Device Bus Interface FSM |
| C++ FloppyPIO device (1560 octal, register map + status/control unions) | `Verilog/simDevices/NDDevices.cpp` from line 205, `NDDevices.h` lines 319-592 | Milestone 3 floppy spec |
| BPUN loader (format parser) | `Verilog/runSim/Run120.cpp` `loadfile()` lines 543-619 | BPUN format reference |
| ALD strap = 400 octal (paper tape boot) | `Verilog/CPU-BOARD-3202/circuit/IO_REG_41.v` line 134 (`s_ALD[3:0] = 4'b0100`) + ALD table in the tail comment of that file | Confirms the CPU already boots from device 400 on `$`/LOAD |
| CPU bus interface (BIF) | `Verilog/CPU-BOARD-3202/circuit/BIF_5.v`, `BIF_BCTL_6.v`, `BIF_DPATH_9.v` | CPU side of the bus the devices attach to |
| Top-level bus ports (sim) / tie-offs (FPGA) | `Verilog/ND120_TOP.v` lines 53-136 | Integration point for Milestone 2 |
| Standalone test-project pattern | `Verilog/fpga/tang-nano-20k/sdram-test/` (`src/sdram_test_top.v`, `src/nano20k.cst`, `sim/sdram_test_tb.v`, `Makefile` with OSS yosys/nextpnr flow) | Template for Milestone 1 |
| Reusable UART TX/RX (9600 8N1, parameterized) | `Verilog/fpga/tang-nano-20k/sdram-test/src/uart_tx.v`, `uart_rx.v`, `msg_printer.v` | Milestone 1 console output |
| Tang pin-constraint style | `Verilog/fpga/tang-nano-20k/src/nd120_tang20k.cst` | CST style to follow |
| Clock/board defines | `Verilog/fpga/tang-nano-20k/src/tang20k_defines.v` (`BOARD_CLK_FREQ` = 6.75 MHz slow bring-up, 27 MHz full) | Clocking facts |
| Test registry | `Verilog/tests/run_all_tests.sh` | Where new tbs must be registered |
| Example BPUN files | `Verilog/runSim/*.BPUN` (e.g. `INSTRUCTION-B.BPUN`, `TPE-MON-100-B00.BPUN`) | Test payloads |

### 3.2 Owner's other codebases (reference only, do not copy blindly)

| Asset | Full path | Relevance |
|---|---|---|
| C# paper tape reader with the ND-06.015.02 spec text quoted inline, plus the full ndwiki BPUN bootstrap listing | `/mnt/e/Dev/Repos/Ronny/RetroCore/Emulated.HW/ND/CPU/NDBUS/NDBusPapertapeReader.cs` | Best-commented register spec; matches `NDDevices.cpp` |
| C emulator with papertape device | https://github.com/HackerCorpLabs/nd100x `src/devices/papertape/devicePapertape.{c,h}` | Independent cross-check of register semantics |
| SINTRAN IOX/EXR driver architecture notes | `/mnt/d/ND/busi/2-IOX-AND-REGISTERS/SINTRAN-DEVICE-DRIVER-IOX-EXR-COMPLETE.md` | How real drivers use IOXT/EXR; useful for floppy/SMD later |
| BPUN tape library | `/mnt/d/ND/BPUN/` | Test payloads |

### 3.3 Open-source cores evaluated (details in section 6)

| Core | License | Mode | FS | R/W | Link |
|---|---|---|---|---|---|
| WangXuan95 FPGA-SDcard-Reader (`sd_reader.v` + `sd_file_reader.v`) | GPL-3.0 | SD native 1-bit | FAT16/FAT32, file-by-name | Read-only | https://github.com/WangXuan95/FPGA-SDcard-Reader |
| WangXuan95 FPGA-SDcard-Reader-SPI | GPL-3.0 | SPI | FAT16/FAT32, file-by-name | Read-only | https://github.com/WangXuan95/FPGA-SDcard-Reader-SPI |
| ZipCPU sdspi / sdio | GPL-3.0 (commercial available) | SPI or SDIO 1/4-bit | none (block level) | Read+Write, DMA | https://github.com/ZipCPU/sdspi |
| mczerski SD-card-controller (Wishbone) | LGPL-2.1 | SD native 1/4-bit | none (block level) | Read+Write, DMA | https://github.com/mczerski/SD-card-controller |
| nand2mario iosys (picorv32 + FatFs over SPI, proven on Tang Nano 20K) | mixed (FatFs is BSD-style; firmware repo license field empty - UNVERIFIED) | SPI | FAT16/32/exFAT via FatFs in C | Read+Write | https://github.com/nand2mario/nestang `src/iosys/`, https://github.com/nand2mario/firmware-picorv32 |
| wsoltys mist-cores FAT32 FSM | GPL (UNVERIFIED) | SPI | FAT32 read, WIP | Read-only | https://github.com/wsoltys/mist-cores/tree/master/misc/sdcard |

Project F (projf) has no SD projects. WangXuan95 FPGA-SDfake is the
opposite direction (FPGA acts as an SD card) - not applicable.
MiSTer does its filesystem on the ARM/Linux side - not applicable here
(but it is the model for the planned `Verilog/fpga/mister/` port).

---

## 4. ND-100 paper tape reader, device 400 octal - verified spec

Primary sources, cross-checked and in agreement:

- "NORD-100 Input/Output System" ND-06.016.01, Appendix A page A-3
  (device table) and section I.3.5 (standardized PIO status/control):
  http://www.bitsavers.org/pdf/norskData/ND-100-IO-ND-06.016.01_NORD-100_Input_Output_System_1980.pdf
- "ND-100 Functional Description" ND-06.015.02, sections 7.2.2 (ALD)
  and 7.2.5 (binary format load), and appendix B.2 (paper tape reader
  spec, quoted in `NDBusPapertapeReader.cs`):
  http://www.bitsavers.org/pdf/norskData/ND-100-FD-ND-06.015.02_ND-100_Functional_Description_1985.pdf
- https://www.ndwiki.org/wiki/BPUN_File_Format (bootstrap listing)
- `Verilog/simDevices/NDDevices.cpp` (working sim implementation)

### 4.1 Identity

| Property | Value |
|---|---|
| Register address range | 400-403 octal (reader 2: 404-407) |
| Interrupt level | 12 (input-channel PIO level) |
| Ident code | 2 octal (reader 2: 22 octal) |
| SINTRAN logical device | 2 (nd100x uses 3 - manual says 2; punch is 3) |

### 4.2 Register map (register = device number + offset)

| IOX addr (octal) | Dir | Name | Behavior |
|---|---|---|---|
| 400 | read | Read data register | 8 data bits right-justified in A bits 7-0. Reading clears status bit 3 (ready for transfer). Same character may be read repeatedly until the next activate. |
| 401 | write | Write data buffer | Not used by the reader (punch-style slot). Accept and ignore. |
| 402 | read | Read status register | See bits below. |
| 403 | write | Write control word | See bits below. |

IOX addressing rule: even offset = device-to-A (read), odd = A-to-device
(write); address bits 2-0 select the register, higher bits the device
(https://ndwiki.org/wiki/IOX).

### 4.3 Status register bits (IOX 402)

| Bit | Meaning |
|---|---|
| 0 | Interrupt-on-ready-for-transfer enabled (echo of control bit 0) |
| 2 | Read active (device busy fetching a character) |
| 3 | READY FOR TRANSFER - data register holds a valid character. This is the bit the boot loader polls (`BSKP ONE 30 DA`). |
| others | Not used on the reader (return 0) |

Interrupt condition: status bit 0 AND status bit 3 -> raise level 12.
IDENT on level 12 returns ident code 2 and clears the interrupt (and
clears the interrupt-enable bit - both `NDDevices.cpp` `IDENT()` and
`NDBusPapertapeReader.cs` do this).

### 4.4 Control word bits (IOX 403)

| Bit | Meaning |
|---|---|
| 0 | Enable interrupt on ready for transfer |
| 2 | ACTIVATE - fetch the next character from the tape; when it is in the buffer, status bit 3 sets |
| 3 | Test mode (interface self-test; optional - see below) |
| 4 | Device clear - clears control/status, empties the buffer, rewinds the tape (in our case: reopen / seek 0 of the file) |
| others | Not used |

Behavioral contract, distilled from `Verilog/simDevices/NDDevices.cpp`
`PaperTape::Write()` (the version the CPU microcode is proven to boot
against in Verilator):

1. On control write: copy bit0 -> status bit0, bit2 -> status bit2.
2. If bit4 (device clear): clear read-active and ready-for-transfer,
   zero the character buffer, rewind the tape.
3. If read-active: clear ready-for-transfer, fetch one byte from the
   tape stream; on success put it in the data register and set
   ready-for-transfer; on EOF leave ready-for-transfer clear. Then
   clear read-active.
4. Update the interrupt line: level-12 request = status bit0 AND bit3.

Note the hardware nuance: in the real interface the fetch takes tape
time and status bit 2 stays set meanwhile; in the C++ model the fetch
is immediate. The Verilog device should insert a SMALL delay (a few
bus-clock cycles, or "data ready when the SD FIFO has a byte") - the
polling loop tolerates any latency, and instant-ready is also proven
to work in sim, so latency is a free parameter.

Control bit 3 (test mode) lets diagnostics increment the data register
without a reader; implement it only if the ND test programs need it -
mark: OPTIONAL, not needed for boot.

### 4.5 The boot flow (why this device is enough to boot)

The CPU card ALD strap in `Verilog/CPU-BOARD-3202/circuit/IO_REG_41.v`
is already `0100` binary = ALD switch position 11 = ALD value 400 octal
= "BPUN load from paper tape (400) and run". Typing `$` (or `&`) in
OPCOM, or `400&` explicitly, makes the MOPC microcode run its built-in
binary loader ("Octal load is not implemented in ND-100" - the binary
loader is microcode, ND-06.015.02 page 7-20). The microcode issues
exactly the polled loop:

```
rdbyt: SAA 4          A := 4 (control bit 2 = activate)
       IOX 403        write control word
wait:  IOX 402        read status
       BSKP ONE 30 DA skip when status bit 3 set
       JMP * -2
       IOX 400        read the byte
```

### 4.6 BPUN stream format (what comes off the "tape")

From ndwiki BPUN page and ND-06.015.02 section 7.2.5.1 (fields A-I),
matching `loadfile()` in `Verilog/runSim/Run120.cpp`:

| Field | Content |
|---|---|
| A | Preamble: any bytes except `!`. Historically an ASCII bootstrap with even parity; the ND-100 microcode just scans past it. |
| B | Start address, ASCII octal digits terminated by CR (LF ignored) |
| C | Bootstrap loader address, ASCII octal terminated by `!` |
| `!` | Delimiter (41 octal) - binary section begins |
| E | Load address: 2 bytes, MSB first |
| F | Word count: 2 bytes, MSB first |
| G | F 16-bit data words, each MSB first |
| H | Checksum: 16-bit arithmetic sum of G, MSB first |
| I | Action code: 0 = start CPU at address B; nonzero = return to OPCOM with P = B |

Important consequence: the device does NOT parse BPUN. It is a dumb
byte pipe - the microcode does all parsing and checksumming. The
Verilog TapeReader only needs "give me the next byte of the file".

---

## 5. How a device-400 IOX reaches a device in THIS design

There are two distinct I/O paths in the 3202D board and it matters
which one we use:

1. **On-board (internal IDB) devices** - console UART (SC2661 model,
   `Verilog/CPU-BOARD-3202/circuit/IO_UART_42.v`), RTC, panel. Their
   chip selects (`CEUART_n`, `RUART_n`, ...) are decoded inside the
   DECODE gate array (instantiated in
   `Verilog/CPU-BOARD-3202/circuit/IO_DCD_38.v`) and their data goes
   straight onto the internal IDB via the source mux in
   `Verilog/CPU-BOARD-3202/circuit/IO_37.v`. This decode is fixed by
   the DGA - we cannot (and should not) add device 400 here.

2. **External ND-100 bus devices** - everything else, including device
   400. An IOX whose address is not on-board becomes an external bus
   cycle through the Bus InterFace (`Verilog/CPU-BOARD-3202/circuit/
   BIF_5.v` and children), using the active-low multiplexed bus
   `BD_23_0_n` plus the control strobes. In the Verilator sim these
   come out of `Verilog/ND120_TOP.v` as ports and are serviced by
   `proccess_bif_signal()` in `Verilog/simDevices/NDBus.cpp`. The
   PaperTape and FloppyPIO already live there - so the CPU side is
   proven; only the device side must be moved from C++ to Verilog.

### 5.1 The bus protocol to implement (from `Verilog/simDevices/NDBus.cpp`)

All `BD` data/address bits are ACTIVE LOW on the bus (value = `~BD`).
Edge semantics, in order of a typical IOX transfer:

| Event (CPU asserts) | Device action |
|---|---|
| `BAPR_n` falling | Latch address = `~BD_23_0_n & 0xFFFFFF`. Address bit 0 even = READ cycle, odd = WRITE cycle. Deassert `BINPUT_n`. |
| `BIOXE_n` falling | WRITE cycle: data = `~BD_23_0_n & 0xFFFF`; perform the register write; assert `BDRY_n` (data accepted). READ cycle: assert `BINPUT_n` (request to drive the bus) and wait for `BINACK_n`. |
| `BINACK_n` falling | READ cycle: drive `BD_23_0_n = ~data`; assert `BDAP_n` and `BDRY_n`. |
| `BIOXE_n` rising | Release everything: `BDRY_n=1, BDAP_n=1, BINPUT_n=1`, stop driving BD (drive all-ones = inactive). Cycle done. |
| `OUTIDENT_n` falling | The address bus holds the IDENT level code: 004 octal -> level 10, 011 -> 11, 022 -> 12, 043 -> 13. If this device has a pending interrupt on that level: assert `BINPUT_n`, put `~identcode` on BD, then complete via `BINACK_n`/`BDAP_n`/`BDRY_n` as a read. Clear the interrupt. |
| `OUTIDENT_n` rising | Release BD, `BINPUT_n`, `BDRY_n`. |
| (continuous) | Drive `BINT12_n` low while the device requests level-12 interrupt. |

Memory cycles (`BMEM_n`) are ignored by I/O devices.

Inside the FPGA the "bus" is not a real tri-state bus: each device
outputs a 24-bit data word and a drive-enable; a rail module ORs/muxes
them (repo tri-state rule). The active-low inversion is kept at the
rail so the CPU-side BIF sees exactly the polarity it sees in sim.

### 5.2 Where it plugs in on FPGA builds

`Verilog/ND120_TOP.v` currently ties all bus inputs inactive in the
`ifndef VERILATOR_SIM` branch (lines 101-136). Milestone 2 replaces
those tie-offs with an instantiated device rail. The
`ifdef VERILATOR_SIM` port list stays untouched so the C++ device path
keeps working - the C++ and Verilog device stacks must be able to run
the same golden tests.

---

## 6. SD hardware and core selection

### 6.1 Tang Nano 20K microSD slot (primary target)

Pin numbers verified against three independent constraint files:
Sipeed's own https://github.com/sipeed/TangNano-20K-example
(`nestang/src/nestang.cst`), https://github.com/nand2mario/nestang
(`src/boards/nano20k.cst`) and https://github.com/nand2mario/snestang
(`src/boards/nano20k.cst`). Board schematic:
https://dl.sipeed.com/shareURL/TANG/Nano_20K/2_Schematic

| Signal | FPGA pin (QN88) | SD-native role | SPI role |
|---|---|---|---|
| `sd_clk` | 83 | CLK | SCLK |
| `sd_cmd` | 82 | CMD (bidir) | MOSI |
| `sd_dat0` | 84 | DAT0 | MISO |
| `sd_dat1` | 85 | DAT1 (drive 1) | unused (drive 1) |
| `sd_dat2` | 80 | DAT2 (drive 1) | unused (drive 1) |
| `sd_dat3` | 81 | DAT3 (drive 1) | CS |

All `IO_TYPE=LVCMOS33 PULL_MODE=NONE`. Driving DAT1-3 high keeps the
card in SD-native mode / deselected-for-SPI as appropriate. No card
detect line appears in any constraint file (UNVERIFIED whether the
slot has one at all - assume none; detect the card by init success).
Both modes are proven on this exact slot: Sipeed's NESTang example
uses WangXuan95's SD-native 1-bit reader; nand2mario's iosys uses SPI.

### 6.2 Basys3 (second target) - Pmod microSD

The Basys3 has no SD slot; use a Digilent Pmod MicroSD (or compatible)
on Pmod header JA. UNVERIFIED until the adapter is in hand - verify
against the Digilent Basys3 master XDC and the Pmod MicroSD reference
manual. Expected mapping (Basys3 master XDC pin names for JA):

| Pmod pin | JA site | FPGA pin (UNVERIFIED) | Pmod MicroSD signal |
|---|---|---|---|
| 1 | JA1 | J1 | DAT3 / CS |
| 2 | JA2 | L2 | MOSI (CMD) |
| 3 | JA3 | J2 | MISO (DAT0) |
| 4 | JA4 | G2 | SCK |
| 7 | JA7 | H1 | DAT1 |
| 8 | JA8 | K2 | DAT2 |
| 9 | JA9 | H2 | CD (card detect) |
| 10 | JA10 | G3 | (nc) |

Because the wiring is identical minus the connector, the SD/FAT
component must not hard-code pins or vendor primitives - plain
Verilog, pins only in each board's constraint file.

### 6.3 Recommended core (read-only milestone): WangXuan95 sd_file_reader

> SUPERSEDED 12-JUL-2026: the vendored core served the read-only
> milestone and was then REPLACED by a clean-room, project-MIT
> `sd_file_reader.v` (written from the public SD/FAT specifications,
> same interface, 13.5 MHz data phase, CMD18 streaming). The survey
> below is kept as historical research; the licensing caveat no longer
> applies to this repository.

https://github.com/WangXuan95/FPGA-SDcard-Reader - two files,
`RTL/sd_reader.v` (card init + CMD17 sector reads, SD-native 1-bit)
and `RTL/sd_file_reader.v` (MBR/DBR parse, FAT16/FAT32 autodetect,
root-directory search by file name, cluster-chain following, streams
exactly file-size bytes). Verified properties:

- License: GPL-3.0. Vendored copies must keep the license header and a
  `LICENSE` copy in the component folder. NOTE FOR THE OWNER: check
  that GPL-3.0 vendoring is acceptable for this repository's licensing
  intent before committing the files (the alternative SPI variant is
  the same license; there is no permissive-license FAT-in-Verilog core
  of comparable quality).
- Card support: SDv1.1, SDv2, SDHC autodetect (`card_type` output).
- Clock: single input clock, internal divider. `CLK_DIV` parameter:
  2 for 25-50 MHz input (use with 27 MHz crystal clock). Init phase is
  further divided (~400 kHz class), data phase runs at input/CLK_DIV.
  NOTE: older vendored copies (e.g. in Sipeed's example) use CLK_DIV
  values one lower - always follow the header of the copy vendored.
- File lookup: `FILE_NAME` is a SYNTHESIS-TIME parameter (up to 52
  chars, case-insensitive, 8.3 and VFAT long names both supported).
- Fragmentation: handled (follows the FAT chain); the file does NOT
  need to be contiguous.
- Read-only by construction (never drives DAT0).

Known limitations to design around (found by source inspection):

1. Root directory only - no subdirectories. Convention: BPUN files in
   the card root.
2. `file_1st_cluster` is 16 bits - the FAT32 high cluster word (dir
   entry offset 0x14) is ignored. On a big FAT32 volume a file whose
   first cluster is >= 65536 silently fails. MITIGATION: format the
   card FAT16 (up to 2-4 GB partition) or use a small first partition;
   Milestone 1 acceptance test must include this card recipe.
3. Directory-entry attribute must be exactly 0x20 (Archive); a file
   with the read-only attribute set is skipped. Document in the user
   guide.
4. One file name per bitstream. Acceptable for Milestone 1/2 boot
   (name the boot file e.g. `BOOT.BPUN`). Runtime file selection is a
   moderate modification: the name comparator at the end of
   `sd_file_reader.v` is a simple byte comparator against a register
   array - make it a loadable register file (Milestone 2b, optional).

### 6.4 Path to read/write (Milestones 3+)

There is no production-quality pure-Verilog FAT WRITE core. Every
credible write-capable design is a block-level SD core plus FAT in
software. Two realistic routes:

- Route A (recommended): block-level SD core + small softcore CPU
  running ChaN's FatFs. Proven on this exact board: nand2mario's
  `iosys` (picorv32 + `simplespimaster.v` SPI master + FatFs firmware,
  https://github.com/nand2mario/firmware-picorv32). Block core options:
  mczerski Wishbone SD controller (LGPL-2.1, native 4-bit, write+DMA)
  or ZipCPU sdio (GPL-3.0, formally verified). The softcore serves
  "filesystem calls" to the device modules through a command mailbox;
  the ND-side device modules stay pure Verilog.
- Route B: hand-rolled append/update FSM over a PRE-ALLOCATED
  contiguous image file (floppy/SMD images have fixed size, so
  cluster allocation never changes; writes only rewrite existing data
  sectors in place). This avoids FAT metadata writes entirely except
  file timestamps (skip them). Feasible without a softcore, but the
  contiguity assumption must be enforced by the card-preparation tool.

Decision can wait until after Milestone 2. Route B is attractive
precisely because disk images are fixed-size and can be created
contiguously by the host PC; Route A is the general solution and the
MiSTer-like end state. The Device Bus Interface and device register
FSMs are identical under both routes - only the storage backend
differs, which is why the FAT component gets its own folder and a
narrow interface (section 8.3).

---

## 7. Proposed folder layout

New top-level component folders, siblings of `Verilog/Shared/` and
`Verilog/PAL/`, each with the standard `circuit/` + `sim/` split
(testbenches in `sim/` per the repo convention; every self-checking tb
registered in `Verilog/tests/run_all_tests.sh`):

```
Verilog/ND-BUS-DEVICES/                  reusable ND-100 device-bus glue
    circuit/
        ND_BUS_DEV_IF.v                  per-device bus slave FSM (section 8.1)
        ND_BUS_DEV_RAIL.v                combines N devices onto one bus (mux, no tri-state)
    sim/
        Makefile
        nd_bus_dev_if_tb.v               iverilog: replay of NDBus.cpp handshake traces
        test_nd_bus_rail.cpp             Verilator: two devices + IDENT arbitration

Verilog/SD-FAT/                          SD card + FAT filesystem access
    circuit/
        sd_file_reader.v                 project MIT (clean-room, 12-JUL-2026)
        SD_FILE_STREAM.v                 project wrapper (section 8.3)
        BYTE_FIFO_ASYNC.v                dual-clock byte FIFO (CDC boundary)
    sim/
        Makefile
        sd_card_model.v                  behavioral SD card serving a FAT16 image file
        sd_file_stream_tb.v              iverilog: mount + find + stream, self-checking
        make_test_image.sh               builds fat16.img with mkfs.vfat + mcopy (mtools)

Verilog/DEVICE-TAPEREADER/               ND-100 paper tape reader, device 400 octal
    circuit/
        TAPE_READER_400.v                register FSM (section 8.2)
    sim/
        Makefile
        tape_reader_400_tb.v             iverilog: register semantics vs NDDevices.cpp golden
        test_tape_boot.cpp               Verilator: full CPU $-boot of a small BPUN via the
                                         Verilog device instead of the C++ PaperTape

Verilog/DEVICE-FLOPPY/                   (Milestone 3 - folder reserved, empty until then)
Verilog/DEVICE-SMD/                      (Milestone 4 - folder reserved, empty until then)

Verilog/fpga/tang-nano-20k/sd-fat-test/  MILESTONE 1 standalone project (section 9)
    Makefile                             OSS flow, same targets as sdram-test
    README.md                            card-preparation recipe + expected output
    sd_fat_test.gprj                     Gowin EDA project (optional, OSS flow primary)
    src/
        sd_fat_test_top.v
        hex_dumper.v
        nano20k_sd.cst
        uart_tx.v                        copied from ../sdram-test/src/ (or referenced)
    sim/
        Makefile
        sd_fat_test_tb.v
```

Rationale: board-independent Verilog lives under `Verilog/<COMPONENT>/`
(matching `CPU-BOARD-3202`, `DECODE-GateArray`, `PAL`, `Shared`);
board-specific test tops live under `Verilog/fpga/<board>/<test>/`
(matching `sdram-test`, `sdram18-test`, `basys3/mem-test`). Handoff and
board docs stay in the board folder; this document stays in
`Verilog/docs/` because it is board-independent.

---

## 8. Component specifications

Common rules: single clock per module side, synchronous active-low
reset `sys_rst_n` where the module is in the CPU domain, `s_` internal
prefix, no latches, no `z` outputs, comment header in the repo format.

### 8.1 ND_BUS_DEV_IF - device bus interface (CPU/bus clock domain)

One instance per device. Implements exactly the edge protocol of
section 5.1 as a synchronous FSM (edge detect = registered previous
value, the same technique `proccess_bif_signal()` uses, and the same
lesson recorded for control-signal-clock conversions: EDGE-DETECT, do
not use signals as clocks).

```verilog
module ND_BUS_DEV_IF #(
    parameter [15:0] DEV_ADDR_BASE = 16'o400,  // first register address (octal)
    parameter [15:0] DEV_ADDR_LEN  = 16'd4,    // number of registers
    parameter [15:0] IDENT_CODE    = 16'o2,    // IDENT reply
    parameter [3:0]  INT_LEVEL     = 4'd12     // 10..13
) (
    input  wire        sysclk,        // CPU/bus clock (single domain)
    input  wire        sys_rst_n,

    // ND-100 bus, CPU side (polarity exactly as ND120_TOP sim ports)
    input  wire [23:0] BD_23_0_n_IN,  // driven by CPU (address, write data)
    output wire [23:0] BD_23_0_n_OUT, // device drive value (all-ones when idle)
    output wire        bd_drive,      // 1 = this device is sourcing BD
    input  wire        BAPR_n,        // address strobe
    input  wire        BIOXE_n,       // IOX execute strobe
    input  wire        BINACK_n,      // CPU grants input
    input  wire        OUTIDENT_n,    // IDENT search strobe
    output wire        BINPUT_n,      // request to drive the bus
    output wire        BDAP_n,        // data present
    output wire        BDRY_n,        // data ready / accepted
    output wire        BINT_n,        // interrupt request (route to BINT<level>_n)

    // Device register side (simple synchronous port, one clock)
    output wire [2:0]  reg_addr,      // register offset within the device
    output wire        reg_rd_stb,    // one-cycle: device must present reg_rdata
    output wire        reg_wr_stb,    // one-cycle: reg_wdata is valid
    output wire [15:0] reg_wdata,
    input  wire [15:0] reg_rdata,
    input  wire        irq_req        // level: device requests interrupt
);
```

Behavior (FSM states IDLE / WRITE_WAIT / READ_WAIT / DRIVE / IDENT):

- Latch `addr = ~BD_23_0_n_IN` on `BAPR_n` falling edge; the cycle is a
  read when `addr[0] == 0`, write when `addr[0] == 1`; the device is
  selected when `DEV_ADDR_BASE <= addr < DEV_ADDR_BASE + DEV_ADDR_LEN`.
- On `BIOXE_n` falling with select: write -> pulse `reg_wr_stb` with
  `reg_wdata = ~BD_23_0_n_IN[15:0]`, assert `BDRY_n` low; read ->
  assert `BINPUT_n` low, wait `BINACK_n` falling, then pulse
  `reg_rd_stb`, drive `BD_23_0_n_OUT = ~{8'h00, reg_rdata}` with
  `bd_drive = 1`, assert `BDAP_n` and `BDRY_n` low.
- On `BIOXE_n` rising: release everything.
- On `OUTIDENT_n` falling with `~BD` equal to the level code of
  `INT_LEVEL` (level 10 -> 004, 11 -> 011, 12 -> 022, 13 -> 043 octal)
  AND `irq_req` set: answer as a read cycle with `IDENT_CODE` and pulse
  an `ident_ack` back to the device (implementation detail: fold into
  `reg_rd_stb` with a reserved `reg_addr` value or a dedicated output -
  implementer's choice, document it).
- `BINT_n = ~irq_req` (the rail routes it onto the right BINT line).
- Latency: the C++ model answers combinationally within the strobe;
  the CPU-side BIF waits for `BDRY_n`, so taking 1-3 sysclk cycles is
  safe. Verify with `Verilog/DEVICE-TAPEREADER/sim/test_tape_boot.cpp`.

ND_BUS_DEV_RAIL: parameterized N-device combiner. ANDs the active-low
outputs (`BINPUT_n`, `BDAP_n`, `BDRY_n`, `BINT1x_n`) and muxes
`BD_23_0_n_OUT` by the `bd_drive` one-hot (drive all-ones when nobody
drives). Also resolves IDENT priority if two devices interrupt on the
same level (lowest address wins - matches DeviceManager's first-match
loop in `Verilog/simDevices/NDDevices.cpp`).

### 8.2 TAPE_READER_400 - the device (CPU/bus clock domain)

```verilog
module TAPE_READER_400 (
    input  wire        sysclk,
    input  wire        sys_rst_n,

    // register port (connects to ND_BUS_DEV_IF)
    input  wire [2:0]  reg_addr,
    input  wire        reg_rd_stb,
    input  wire        reg_wr_stb,
    input  wire [15:0] reg_wdata,
    output reg  [15:0] reg_rdata,
    output wire        irq_req,
    input  wire        ident_ack,     // IDENT answered: clear int enable

    // byte-stream port (connects to SD_FILE_STREAM through the FIFO)
    input  wire [7:0]  tape_byte,     // next byte of the file
    input  wire        tape_valid,    // a byte is available
    output wire        tape_ready,    // consume it (one-cycle handshake)
    output wire        tape_rewind    // pulse: device clear -> restart file
);
```

Register semantics: exactly section 4.3/4.4 - the golden model is
`PaperTape` in `Verilog/simDevices/NDDevices.cpp`. Differences from
the C++ model, forced by hardware:

- The byte fetch is not instantaneous: on activate (control bit 2),
  clear status bit 3, assert `tape_ready`; when `tape_valid` delivers
  the byte, load the data register and set status bit 3. The microcode
  polling loop (section 4.5) tolerates this by design.
- EOF = FIFO empty and the stream module reports end-of-file: status
  bit 3 simply never sets; OPCOM shows a hung load. Optionally latch a
  diagnostic LED. (Real hardware behaved the same on tape runout.)
- Device clear pulses `tape_rewind`, which makes the stream module
  restart the file from byte 0 (re-run the FAT open).

### 8.3 SD_FILE_STREAM - FAT reader wrapper (SD clock domain) + CDC

```verilog
module SD_FILE_STREAM #(
    parameter FILE_NAME     = "BOOT.BPUN",  // sd_file_reader synthesis-time name
    parameter FILE_NAME_LEN = 9,
    parameter CLK_DIV       = 2             // 2 for 25-50 MHz sd_clk_in
) (
    // SD-side clock domain (27 MHz on Tang, 25 MHz MMCM tap on Basys3)
    input  wire        sd_clk_in,
    input  wire        sd_rst_n,

    // SD card pins
    output wire        sd_pin_clk,
    inout  wire        sd_pin_cmd,    // top level: bidir at pad only
    input  wire        sd_pin_dat0,
    output wire [2:0]  sd_pin_dat321, // drive constant 1

    // control (synchronized internally, safe from either domain)
    input  wire        start,         // pulse: (re)open the file from byte 0
    output wire        mounted,       // card init + FS parse done
    output wire        file_found,
    output wire        stream_done,   // whole file delivered
    output wire [3:0]  status,        // card type / fs type / error code

    // byte stream out, CONSUMER clock domain
    input  wire        cons_clk,      // e.g. CPU sysclk (Milestone 2) or same
                                      // sd_clk_in (Milestone 1)
    output wire [7:0]  out_byte,
    output wire        out_valid,
    input  wire        out_ready
);
```

Internally: `sd_file_reader` (outputs `outen`/`outbyte` at sector-burst
rate) -> `BYTE_FIFO_ASYNC` (dual-clock, 2 KB = 4 sectors deep, gray-code
pointers, standard 2-FF synchronizers) -> valid/ready output. Back
pressure: `sd_file_reader` has NO flow control while a sector is
streaming (UNVERIFIED whether it can pause mid-sector - assume not), so
the wrapper must only issue the next sector read when the FIFO has
>= 512 bytes free. If the vendored core cannot pause between sectors,
the wrapper stalls the reader by gating its clock enable between
sectors - check the core's `rbusy`/`rdone` handshake when implementing
(`sd_reader.v` exposes per-sector `rstart`/`rbusy`/`rdone`; drive it
sector-by-sector from the wrapper instead of letting `sd_file_reader`
free-run, if needed).

`start`/`tape_rewind` note: the vendored `sd_file_reader` runs its
sequence once after reset. Rewind = hold it in reset for a few cycles
and let it re-run card-init + FAT search (~100 ms - fine, a real tape
rewind took seconds). Milestone 2 wires `tape_rewind` (CPU domain) to
`start` through a pulse synchronizer.

CDC rules (the project's hard-won ones): the CPU side stays pure
single-clock `sysclk` + clock enables; every signal crossing between
`sd_clk_in` and `cons_clk` goes through the async FIFO or a 2-FF
synchronizer (controls) / pulse synchronizer (events); no derived or
gated clocks anywhere; both clocks come from PLL outputs declared in
the board constraint files. Add the SD clock to the board SDC
(`Verilog/fpga/tang-nano-20k/src/nd120_tang20k.sdc`) and mark the
FIFO/synchronizer crossings as async clock groups.

---

## 9. MILESTONE 1 - standalone SD + FAT + UART dump (must pass on hardware first)

Goal: on a Tang Nano 20K with a FAT-formatted microSD containing
`BOOT.BPUN`, the board prints the file as a hex/octal dump on the USB
serial console (BL616, 9600 8N1 - same terminal setup as sdram-test).
No CPU, no ND bus. This de-risks: pins, card init, FAT parse, file
lookup, byte streaming, and the vendored core's limitations, all
observable on a terminal.

Project folder: `Verilog/fpga/tang-nano-20k/sd-fat-test/` (layout in
section 7). Pattern to copy: `Verilog/fpga/tang-nano-20k/sdram-test/`
(Makefile OSS flow, README with expected output, `sim/` with iverilog
testbench, PASS/FAIL over UART and LEDs).

### 9.1 Modules

| Module | File | Function |
|---|---|---|
| `sd_fat_test_top` | `src/sd_fat_test_top.v` | Clocking (27 MHz crystal direct - no PLL needed), reset, instantiates everything, drives LEDs |
| `sd_file_reader` + `sd_reader` | `Verilog/SD-FAT/circuit/` (referenced by path, vendored once) | Card + FAT + file byte stream |
| `hex_dumper` | `src/hex_dumper.v` | Formats the byte stream as dump lines, feeds uart_tx |
| `uart_tx` | copy of `Verilog/fpga/tang-nano-20k/sdram-test/src/uart_tx.v` | 9600 8N1 out |

Note: Milestone 1 may use the vendored core directly (single 27 MHz
domain, no FIFO) to keep the first hardware proof minimal; the
`SD_FILE_STREAM` wrapper + FIFO is then built and re-proven in the same
project as step 2 (swap the direct hookup for the wrapper, output must
be byte-identical). Both configurations share this test top.

### 9.2 Top-level behavior

1. Power-up: LED[0] on = out of reset. Wait ~100 ms, start card init.
2. Print banner: `SD-FAT TEST` + build date constant.
3. Print card status as init proceeds:
   `CARD: SDHC` (from `card_type`), `FS: FAT16` (from
   `filesystem_type`), `FILE: FOUND` or `FILE: NOT FOUND`.
4. Stream the file through `hex_dumper`. Dump format (ASCII only):

```
000000: 8D 0A 30 30 36 30 30 30  30 8D 0A B1 36 B4 33 B1   offset hex, 16 bytes
...
OCTAL WORDS (first 8): 105015 030060 ...
LENGTH: 000000000388 BYTES
DONE
```

   Hex is the primary dump (byte-exact compare against `xxd` on the
   host); the octal word line exists because BPUN fields are 16-bit
   MSB-first words and the owner reads octal.
5. End states on LEDs: LED[1] = mounted, LED[2] = file found,
   LED[3] = done, LED[5] = error (any state-machine timeout).
6. S1 button: restart the whole sequence (re-init the card).

Throughput sanity: 9600 baud drains ~960 bytes/s; the dumper is the
bottleneck, so `hex_dumper` must apply back pressure. With the direct
(no-FIFO) hookup the vendored core cannot be back-pressured
mid-sector, so `hex_dumper` needs a 512-byte sector buffer: accept one
sector burst at full speed, print it, then allow the next `rstart`.
(This same buffer becomes `BYTE_FIFO_ASYNC` in step 2.)

### 9.3 Constraints file `src/nano20k_sd.cst`

Follow the style of `Verilog/fpga/tang-nano-20k/src/nd120_tang20k.cst`
(clock 4, S1 88, S2 87, UART 69/70, LEDs 15-20) and add the SD pins
from section 6.1:

```
IO_LOC  "sd_clk"  83;  IO_PORT "sd_clk"  IO_TYPE=LVCMOS33 PULL_MODE=NONE;
IO_LOC  "sd_cmd"  82;  IO_PORT "sd_cmd"  IO_TYPE=LVCMOS33 PULL_MODE=NONE;
IO_LOC  "sd_dat0" 84;  IO_PORT "sd_dat0" IO_TYPE=LVCMOS33 PULL_MODE=NONE;
IO_LOC  "sd_dat1" 85;  IO_PORT "sd_dat1" IO_TYPE=LVCMOS33 PULL_MODE=NONE;
IO_LOC  "sd_dat2" 80;  IO_PORT "sd_dat2" IO_TYPE=LVCMOS33 PULL_MODE=NONE;
IO_LOC  "sd_dat3" 81;  IO_PORT "sd_dat3" IO_TYPE=LVCMOS33 PULL_MODE=NONE;
```

`sd_dat1/2/3` are outputs driven to constant 1 in the top.

### 9.4 Card preparation recipe (goes in the project README)

```
# whole-card FAT16 (avoids the 16-bit first-cluster FAT32 limitation)
sudo mkfs.vfat -F 16 -n ND120 /dev/sdX
mcopy -i /dev/sdX /path/to/INSTRUCTION-B.BPUN ::BOOT.BPUN   # or mount + cp
# file must be in the ROOT directory, attribute plain Archive
```

Test payload: `Verilog/runSim/INSTRUCTION-B.BPUN` (small, already the
default tape in `Verilog/simDevices/NDDevices.cpp`).

### 9.5 Simulation test plan (before hardware)

`sim/sd_fat_test_tb.v` (iverilog, registered in
`Verilog/tests/run_all_tests.sh`):

1. `sim/make_test_image.sh` builds `fat16.img` (1 MB is enough) with
   mtools: `mkfs.vfat -F 16 -C fat16.img 1024` + `mcopy` of a small
   known BPUN file.
2. `sim/sd_card_model.v`: behavioral SD card in native 1-bit mode.
   Must implement: CMD0, CMD8, CMD55+ACMD41 (report SDHC), CMD2, CMD3,
   CMD7, CMD16, CMD17 single-block read with correct CRC7 on CMD
   responses and CRC16 on the data block, serving sector N from
   `fat16.img` via `$readmemh`-converted or `$fread` access. Write
   commands: not implemented (respond illegal). This model is the
   single biggest piece of Milestone 1 sim work - budget accordingly;
   validate it first against `sd_reader.v` alone (init handshake test).
3. The tb instantiates `sd_fat_test_top` with the card model on the SD
   pins, captures UART TX with the standard receiver, and compares the
   dumped bytes against the bytes of the file inside the image.
   Verdict line: `TB_RESULT: PASS` / `TB_RESULT: FAIL <reason>`.
4. Unit tb for `hex_dumper` alone (byte array in, ASCII lines out,
   golden string compare) - cheap and catches formatting bugs without
   the SD model.

### 9.6 Acceptance criteria (Milestone 1 done when ALL hold)

- A1: `make sim` in `Verilog/fpga/tang-nano-20k/sd-fat-test/` passes;
  the tbs are green in the global `make test` registry.
- A2: `make` builds a bitstream with the OSS flow (yosys/nextpnr), and
  `make load` programs it (same Makefile API as every board project -
  see `Verilog/fpga/README.md`).
- A3: On hardware, with the recipe card inserted: banner, `CARD:`,
  `FS: FAT16`, `FILE: FOUND`, complete dump, `DONE`; dump bytes are
  identical to `xxd BOOT.BPUN` on the host (spot-check first/last 64
  bytes and total length).
- A4: Card removed / no card: error LED + `FILE: NOT FOUND` or init
  timeout message within 10 s - no hang without diagnosis.
- A5: S1 restart re-dumps successfully (proves re-init path = the
  future `tape_rewind`).
- A6: Repeat A3 with a FAT32-formatted card (small volume, file as
  first entries): must also pass (documents that FAT32 works within
  the known cluster limitation).

### 9.7 What NOT to do in Milestone 1

- No ND bus, no CPU sources in the project file list.
- No PLL/CDC (single 27 MHz domain) in step 1.
- No file-name UI: fixed `BOOT.BPUN`.
- No Gowin-EDA-only primitives - the sdram-test experience says the
  OSS flow is the fast iteration loop; keep it OSS-clean.

---

## 10. Milestone 2 - CPU integration: boot from SD tape on device 400

Precondition: Milestone 1 passes on hardware; clock-enable refactor
status per `Verilog/TODO.md` at that time decides whether this lands
on the 6.75 MHz slow-bring-up clocking or the full-speed one - the
design below is clock-frequency-agnostic.

Steps, each independently testable:

1. **Verilog device stack in Verilator, against the proven microcode
   path.** Build `ND_BUS_DEV_IF` + `TAPE_READER_400` and, in
   `Verilog/DEVICE-TAPEREADER/sim/test_tape_boot.cpp`, attach them to
   the `VERILATOR_SIM` bus ports of `Verilog/ND120_TOP.v` INSTEAD OF
   calling `proccess_bif_signal()`. The tape byte source in this test
   is a plain `$readmem`-style file streamer (no SD) - the point is
   the bus protocol and register FSM. Acceptance: typing `$` in the
   harness loads and starts `INSTRUCTION-B.BPUN` exactly like the C++
   PaperTape path does today (compare console output golden files, as
   `Verilog/runSim/golden/` does for runSim).
2. **Bus rail inside the FPGA top.** In `Verilog/ND120_TOP.v` replace
   the FPGA-mode tie-offs (lines 101-136) with an internal instance of
   `ND_BUS_DEV_RAIL` behind a new define (suggested: `ND_BUS_DEVICES`,
   documented in `Verilog/docs/build-defines.md` and set in
   `Verilog/fpga/tang-nano-20k/src/tang20k_defines.v`). The Verilator
   port list is untouched; a build with the define off is bit-for-bit
   the current behavior.
3. **SD backend.** Replace the file streamer with `SD_FILE_STREAM` +
   `BYTE_FIFO_ASYNC` (`cons_clk = sysclk`, `sd_clk_in` = 27 MHz
   crystal). On Tang: SD pins added to
   `Verilog/fpga/tang-nano-20k/src/nd120_tang20k.cst`, SD clock and
   async-group constraints added to `nd120_tang20k.sdc`.
4. **Hardware boot test.** Card from the Milestone 1 recipe with
   `BOOT.BPUN` = a known-good test tape. On the OPCOM console: MCL,
   then `$`. Expected: the microcode binary loader performs the
   IOX 403/402/400 polling sequence against the Verilog device, the
   program loads, checksum passes, and it starts (action code 0) or
   returns to OPCOM (nonzero). First payload suggestion:
   `Verilog/runSim/INSTRUCTION-B.BPUN`, then
   `Verilog/runSim/TPE-MON-100-B00.BPUN`.

Timing/latency note: the microcode polls status (IOX 402) in a tight
loop; each IOX is a full external bus cycle. The SD sector fetch
(hundreds of microseconds) simply shows as many not-ready polls -
functionally identical to real tape (10-1000 cps readers). No
interrupt support is required for the boot path (the loader polls),
but implement the level-12 interrupt + IDENT anyway - SINTRAN's reader
driver uses it, and the sim FloppyPIO already exercises the IDENT rail
logic on level 11.

Open item for step 4 (mark: VALIDATION REQUIRED): confirm that the
microcode version in `Verilog/CPU-BOARD-3202/circuit/AM27256_45132L.hex`
/ `45133L.hex` executes the binary-load path in FF mode on hardware -
it is proven in Verilator (latch mode) via the C++ PaperTape; any
FF-mode divergence found here feeds the existing clock-domain work,
not this plan.

---

## 11. Milestones 3+ - outlook

### 11.1 Milestone 3: FloppyPIO device (1560-1567 octal)

- Golden model: `FloppyPIO` in `Verilog/simDevices/NDDevices.cpp`
  (register map IOX +0..+7, RSR1/RSR2/WCWD/WDAD/WSCT bit unions are
  already documented there; ident 21 octal, level 11 UNVERIFIED - the
  C++ ctor sets it, cross-check ND-06.016.01 Appendix A when
  implementing).
- Storage: floppy image file (`FLOPPY.IMG` in `Verilog/runSim/` is the
  sim's) on the FAT card. READ path works with the Milestone 2 stack
  plus random access: the stream wrapper grows a `seek(sector)`
  command (the FloppyPIO transfers whole 1 KB buffers, so
  sector-granular seeks suffice).
- WRITE path forces the section 6.4 decision (Route A softcore+FatFs
  vs Route B contiguous-image in-place writes). Recommendation:
  prototype Route B first - floppy images are 308 KB / fixed size,
  in-place sector rewrite of a contiguous file needs no FAT metadata
  updates at all.
- New folder `Verilog/DEVICE-FLOPPY/` per section 7.

### 11.2 Milestone 4: SMD/HDD controller

- The C++ side has only a stub (`FloppyDMA`) - the register spec must
  come from the ND SMD controller documentation and the owner's other
  emulators (https://github.com/HackerCorpLabs/nd100x has disk
  devices). DMA devices master the bus (BREQ/semaphores), which the
  Device Bus Interface does not cover yet - budget a BUS-MASTER
  extension of `Verilog/ND-BUS-DEVICES/` (use `proccess_bif_signal()`
  plus ND-06.026 quotes at the bottom of `Verilog/simDevices/NDBus.cpp`
  as the protocol starting point).
- Image sizes (tens of MB) still fit Route B contiguous files easily.

### 11.3 Runtime file selection (quality-of-life, any time after M2)

Replace the synthesis-time `FILE_NAME` comparator in the vendored
reader with a register file loadable from: OPCOM-side escape, extra
device registers on the tape reader (e.g. reuse IOX 401 writes to
build a filename buffer - nonstandard but invisible to stock
software), or board buttons cycling `BOOT0.BPUN`..`BOOT9.BPUN`.
Decide with the owner when M2 works.

---

## 12. Risks and open questions

| # | Risk / question | Mitigation |
|---|---|---|
| 1 | ~~GPL-3.0 vendored SD core vs repo licensing intent~~ RESOLVED 12-JUL-2026: the fallback was executed - `sd_file_reader.v` is now a clean-room MIT 1-bit reader (public SD/FAT specs, identical interface, 13.5 MHz data phase); the vendored files are deleted | Registered gates (SD-FAT/sim + sd-fat-test/sim) prove equivalence |
| 2 | ~~Reader FAT32 16-bit first-cluster bug~~ RESOLVED: full 32-bit first clusters (fat32big gate covers it) | FAT16 card recipe; acceptance test A6 documents the FAT32 envelope |
| 3 | Root-dir-only, attribute 0x20-only lookup | Documented card recipe; check attribute in README |
| 4 | `sd_file_reader` flow control mid-sector (none: outen has no backpressure) | Consumers buffer (64 KB BRAM / mount FIFO); byte pacing is >= 16 clk at CLK_DIV=1 |
| 5 | No card-detect line on Tang slot (UNVERIFIED) | Detect by init timeout; S1 = manual retry |
| 6 | Basys3 Pmod pinout unverified | Verify against Digilent master XDC + Pmod MicroSD manual when the adapter arrives; SPI-mode variant of the core may suit the Pmod better |
| 7 | Microcode binary-load path unproven in FF mode on hardware | Milestone 2 step 1 proves the device against the microcode in Verilator first; hardware divergence feeds the clock-domain workstream |
| 8 | Bus-cycle timing tolerances of the real BIF (the C++ model answers within the strobe; Verilog adds cycles) | `test_tape_boot.cpp` sweeps 1..8 cycle response latency and asserts the boot still passes |
| 9 | SD-domain to CPU-domain CDC | Async FIFO + 2-FF/pulse synchronizers only; SDC async clock groups; no new derived clocks (project rule) |
| 10 | FAT write for floppy/SMD | Deferred decision (section 6.4); Route B (contiguous images, in-place writes) is the low-risk default |
| 11 | IDENT arbitration with multiple devices on one level | `ND_BUS_DEV_RAIL` priority = lowest device address; covered by `test_nd_bus_rail.cpp` |

---

## 13. Summary of verified facts (quick reference)

- Tang Nano 20K SD pins: CLK=83, CMD=82, DAT0=84, DAT1=85, DAT2=80,
  DAT3=81, all LVCMOS33 (three independent .cst sources).
- Recommended read-only core: WangXuan95 FPGA-SDcard-Reader
  (GPL-3.0, SD native 1-bit, FAT16/FAT32, find-by-name, follows
  cluster chains, CLK_DIV=2 at 27 MHz).
- Device 400 octal: registers 400 data / 402 status / 403 control;
  status bit 3 = ready-for-transfer (polled by boot loader), control
  bit 2 = activate, bit 4 = device clear, bit 0 = interrupt enable;
  interrupt level 12, ident code 2 octal.
- ALD already strapped to 400 octal in
  `Verilog/CPU-BOARD-3202/circuit/IO_REG_41.v` - `$` at OPCOM boots
  from the tape reader with no CPU-side changes.
- The device does not parse BPUN; the microcode binary loader does.
- Device side of the ND-100 bus protocol to implement =
  `proccess_bif_signal()` in `Verilog/simDevices/NDBus.cpp`, verbatim.

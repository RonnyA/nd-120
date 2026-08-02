# Hardware Specifications

This document details the hardware components, specifications, and requirements for the ND-120 CPU implementation.

> **Provenance note (02-AUG-2026):** this document was drafted in September 2025.
> The component and status tables below have been re-checked against the RTL.
> The numeric timing, power, environmental and mechanical figures further down
> have **not** been traced back to the original Norsk Data documentation - treat
> them as unverified until someone confirms them against `NorskData-Doc/` or the
> design documents.

## System Overview

The ND-120 CPU is a 16-bit minicomputer processor originally designed by Norsk Data in 1988. This implementation recreates the complete system using modern HDL and FPGA technology.

## Core Components

### CPU Board 3202D

The main CPU board contains all essential processing components in a single-board design.

#### Major Integrated Circuits

| Component | Type | Function | Status |
|-----------|------|----------|---------|
| **DELILAH CGA** | Custom Gate Array | CPU execution engine | ✅ Implemented |
| **NEC DGA** | Custom Gate Array | Instruction decoder | ✅ Implemented |
| **MC68705-U3** | 8-bit Microcontroller | Panel controller | ✅ ROM dumped & analyzed |
| **SC2661 UART** | Serial Communication | Console I/O | ✅ Implemented |
| **AM29833A** | Parity Bus Transceiver | Memory data path parity (sheet 46) | ✅ Implemented |

#### Memory Subsystem

| Component | Size | Type | Function | Status |
|-----------|------|------|----------|---------|
| **Microcode ROM** | 64KB | EPROM | Microinstruction storage | ✅ Dumped & implemented |
| **Working Registers** | 32×16-bit | Static RAM | CPU register file | ✅ Implemented |
| **Cache Memory** | Variable | Static RAM | MMU data cache | ⚠️ Implemented, never functionally validated |
| **Main Memory** | Up to 8MB | Dynamic RAM | System memory | ✅ Simulation (6MB) and SDRAM on Tang Nano 20K |

### DELILAH CPU Gate Array (CGA)

Custom ASIC containing the main CPU execution logic.

#### Functional Units

| Unit | Function | Implementation |
|------|----------|----------------|
| **ALU** | 16-bit arithmetic/logic operations | 74181-based design |
| **MAC** | Memory address calculation | Address generation unit |
| **MIC** | Microcode sequencing | Control store access |
| **WRF** | Working register file | 16×16-bit registers |
| **INTR** | Interrupt controller | Priority interrupt handling |
| **TRAP** | Exception handling | Trap vector processing |
| **DCD** | Instruction decode | Machine code to microcode |

#### Signal Interface

**Input Signals**:
- **MCLK**: Master clock (system timing)
- **CD[15:0]**: Command/Data bus
- **FIDB[15:0]**: Fast Internal Data Bus
- **Interrupt Lines**: BINT10-15, various error signals

**Output Signals**:
- **Address Buses**: Memory and I/O addressing
- **Control Signals**: Read/write, bus control
- **Status Flags**: ALU conditions, CPU state

### NEC Decoder Gate Array (DGA)

Custom ASIC for instruction decoding and microcode address generation.

#### Functions
- **Instruction Decode**: Machine language to microcode mapping
- **Address Generation**: Control store addressing
- **Branch Logic**: Conditional execution control
- **Interrupt Vector**: Interrupt address calculation

### PAL Chips

Programmable Array Logic providing various control functions.

#### Implemented PALs

| PAL ID | Function | Status |
|--------|----------|---------|
| **44302B** | Address decode | ✅ Converted |
| **44303B** | Bus control | ✅ Converted |
| **44304E** | Memory control | ✅ Converted |
| **44305D** | I/O decode | ✅ Converted |
| **44306A** | Interrupt control | ✅ Converted |
| **44307C** | Clock generation | ✅ Converted |
| **44310D** | Reset logic | ✅ Converted |
| **44401B-44904B** | Various control | ✅ All converted |
| **45001B-45009B** | System control | ✅ All converted |

### Support Chips

#### Standard TTL Logic

| Chip Series | Function | Usage |
|-------------|----------|-------|
| **74xxx** | Standard logic | Gates, flip-flops, counters |
| **74LSxxx** | Low-power Schottky | High-speed logic |
| **74Sxxx** | Schottky | Very high-speed logic |

#### Memory Controllers

| Controller | Type | Function |
|------------|------|----------|
| **Dynamic RAM Controller** | Custom logic | DRAM refresh and timing |
| **Static RAM Controller** | PAL-based | SRAM access control |
| **ROM Controller** | Address decode | EPROM access |

## Panel Controller System

### MC68705-U3 (CPU Board Controller)

**Specifications**:
- **Architecture**: Motorola 6805 8-bit CPU
- **Package**: 40-pin DIP
- **I/O Ports**: 4× 8-bit ports
- **Memory**: On-chip RAM and ROM
- **Timer**: 8-bit timer with prescaler

**Functions**:
- CPU board status monitoring
- Power-on self-test control
- Diagnostic interface
- Front panel communication

### MC68705-P3 (Front Panel Controller)

**Specifications**:
- **Architecture**: Motorola 6805 8-bit CPU
- **Package**: 28-pin DIP
- **I/O Ports**: 2× 8-bit + 1× 4-bit ports
- **Memory**: On-chip RAM and ROM
- **Timer**: 8-bit timer with prescaler

**Functions**:
- Switch scanning
- LED/display control
- Operator interface
- System control commands

## Memory Architecture

### Microcode Memory

**Organization**:
- **Total Size**: 64KB, split low half + high half
- **Word Width**: 64 bits
- **Technology**: EPROM, AM27256 (the dumps used by the build are
  `AM27256_45132L.hex` and `AM27256_45133L.hex`, microcode version L)
- **Access Time**: <150ns (unverified against the original data sheet)

The hex address map that stood here was internally inconsistent (it labelled
2KB ranges as 32KB) and is not reproduced. For the real control-store layout see
`Verilog/mic-calculation.md` and the microcode listing under `Code/Microcode/`.

**Microcode Fields**:
- **ALU Control**: 9 bits (CSALUI[8:0])
- **Register Select**: 4 bits (CSRASEL, CSRBSEL)
- **Memory Control**: 5 bits (CSCOMM[4:0])
- **Sequencing**: 16 bits (next address, conditions)
- **Miscellaneous**: 30 bits (various control)

### Main Memory

**Dynamic RAM**:
- **Technology**: 4164/41256 series DRAM
- **Organization**: 16-bit words
- **Capacity**: Up to 8MB
- **Refresh**: Every 2ms
- **Access Time**: 150-200ns

**Static RAM**:
- **Technology**: 6264/62256 series SRAM
- **Organization**: 8-bit or 16-bit
- **Usage**: Cache, buffers, register files
- **Access Time**: <70ns

### I/O Address Map

The ND-120 does not use a hex memory-mapped I/O window. Devices are reached with
the `IOX` instruction using **octal device addresses** (for example the floppy /
streamer controller at `1560`). The hex table that stood here was never traced to
any Norsk Data source and has been removed rather than left as fact. The authoritative
per-device addresses are in the Norsk Data functional descriptions under
`NorskData-Doc/`, and in the device models under `Verilog/ND-BUS-DEVICES/`.

## Clock and Timing

### System Clocks

| Clock | Frequency | Function |
|-------|-----------|----------|
| **MCLK** | 10-20 MHz | Master system clock |
| **UCLK** | MCLK/2 | Microcode clock |
| **MEMCLK** | Variable | Memory access clock |
| **UART_CLK** | 1.8432 MHz | Serial communication |

### Timing Constraints

**Setup Times**:
- **Data to Clock**: 10ns minimum
- **Address to Memory**: 50ns minimum
- **Control to Memory**: 20ns minimum

**Hold Times**:
- **Data after Clock**: 5ns minimum
- **Address after Control**: 10ns minimum

## Physical Implementation

### FPGA Requirements

#### Minimum Resources
- **Logic Elements**: ~50,000 LEs
- **Memory**: 2MB+ on-chip RAM
- **I/O Pins**: 200+ pins
- **Clock Networks**: 4+ global clocks

#### Recommended FPGA Families
- **Intel/Altera**: Cyclone V, Arria 10
- **Xilinx**: Artix-7, Kintex-7
- **Lattice**: ECP5, CrossLink-NX
- **GoWin**: GW2A series

### Development Boards

#### Board Support In Tree

Build flows live under `Verilog/fpga/<board>/`, see `Verilog/fpga/README.md`.

| Board | FPGA | State |
|-------|------|-------|
| **Tang Nano 20K** | GoWin GW2AR-18 | CPU boots on silicon; SDRAM and SD/FAT storage proven |
| **Basys3** | Xilinx Artix-7 `xc7a35t` | Synthesises, CPU boot does not work yet |
| **QMTech A35T** | Xilinx Artix-7 | Bring-up paused |
| **Cmod A7-35T** | Xilinx Artix-7 | Research only, no build validated |
| **MiSTer (DE10-Nano)** | Intel Cyclone V SoC | Planned, not started |

## Power Requirements

### Original Hardware
- **Supply Voltage**: +5V, +12V, -12V
- **Power Consumption**: ~50W typical
- **Cooling**: Forced air cooling required

### FPGA Implementation
- **Supply Voltage**: 3.3V, 1.2V (FPGA-dependent)
- **Power Consumption**: 5-15W typical
- **Cooling**: Heat sink sufficient

## Environmental Specifications

### Operating Conditions
- **Temperature**: 0°C to +70°C
- **Humidity**: 10% to 90% non-condensing
- **Altitude**: Sea level to 3000m

### Storage Conditions
- **Temperature**: -40°C to +85°C
- **Humidity**: 5% to 95% non-condensing

## Mechanical Specifications

### Original CPU Board
- **Size**: Eurocard format (160×100mm)
- **Connector**: DIN 41612 connector
- **Mounting**: Standard card cage

### Development Board Variations
- **Form Factor**: Depends on target FPGA board
- **Connectors**: USB, Ethernet, GPIO headers
- **Mounting**: Standoffs or development kit housing

## Interfaces

### System Bus
- **Width**: 16-bit data, 24-bit address
- **Protocol**: Synchronous, master/slave
- **Speed**: Up to 10 MHz
- **Arbitration**: Fixed priority

### Serial Interface (UART)
- **Standard**: RS-232 compatible
- **Baud Rates**: 110 to 19200 bps
- **Data Format**: 7/8 bits, 1/2 stop bits, optional parity
- **Flow Control**: XON/XOFF software control

### Parallel Interface
- **Width**: 8-bit bidirectional
- **Protocol**: Centronics-compatible
- **Speed**: Up to 1 MHz
- **Handshaking**: ACK/BUSY signals

## Expansion Capabilities

### I/O Expansion
- **Slots**: Up to 8 I/O boards
- **Types**: Serial, parallel, network, storage
- **Addressing**: Memory-mapped I/O

### Memory Expansion
- **Main Memory**: Expandable to 8MB
- **Cache Memory**: Optional external cache
- **Storage**: Floppy, hard disk interfaces

### Peripheral Support
- **Terminals**: Multiple serial terminals
- **Printers**: Parallel and serial printers
- **Networks**: Ethernet, token ring
- **Storage**: Floppy disk, hard disk, tape
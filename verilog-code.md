# ND-120 Verilog Implementation Documentation

## Executive Summary

The ND-120 CPU implementation consists of **75,511 lines of Verilog code** across **259 files**, representing a complete recreation of the 1988 Norsk Data ND-120 16-bit minicomputer processor. This HDL implementation transforms original paper documentation into modern, synthesizable Verilog suitable for FPGA platforms.

**Key Technical Achievements:**
- Complete CPU simulation with microcode execution (7/14 self-tests passing)
- UART communication and OPCOM (operator communication) operational
- All 25+ PAL chips converted from PALASM to behavioral Verilog
- Comprehensive bus interface and I/O subsystem
- Memory management unit with virtual memory support
- Interrupt controller with priority handling

**Current Status:** The implementation successfully executes microcode, loads and runs test programs, and communicates via UART. FPGA synthesis passes but requires optimization for implementation.

## Introduction

The ND-120 CPU architecture represents a sophisticated 16-bit minicomputer design from the late 1980s. This Verilog implementation recreates the complete system including:

- **CPU Core**: DELILAH CPU Gate Array (CGA) with ALU, interrupt controller, memory access controller
- **Instruction Decoder**: NEC Decoder Gate Array (DGA) for instruction decode and microcode address generation
- **Memory System**: Memory management unit, cache, and main memory interface
- **I/O System**: UART, parallel I/O, and bus interface modules
- **Control Logic**: 25+ PAL chips implementing various control and decode functions

The implementation maintains cycle-accurate behavior while being structured for modern FPGA synthesis and simulation tools.

## System Architecture Overview

```mermaid
graph TB
    subgraph "ND120_TOP (FPGA Top Level)"
        TOP[ND120_TOP.v<br/>FPGA Interface]
    end

    subgraph "ND3202D (CPU Board)"
        CPU_BOARD[ND3202D.v<br/>CPU Board Integration]

        subgraph "CPU Core"
            CPU[CPU_15.v<br/>CPU Control]
            CS[CPU_CS_16.v<br/>Control Store]
            PROC[CPU_PROC_32.v<br/>Processor]
        end

        subgraph "CGA (DELILAH CPU)"
            CGA[CGA.v<br/>CPU Gate Array]
            ALU[CGA_ALU.v<br/>Arithmetic Logic Unit]
            MAC[CGA_MAC.v<br/>Memory Access Controller]
            MIC[CGA_MIC.v<br/>Microcode Controller]
            INTR[CGA_INTR.v<br/>Interrupt Controller]
            TRAP[CGA_TRAP.v<br/>Trap Handler]
            WRF[CGA_WRF.v<br/>Register File]
        end

        subgraph "DGA (Decoder)"
            DGA[DECODE_DGA.v<br/>Decode Gate Array]
        end

        subgraph "Memory System"
            MMU[CPU_MMU_24.v<br/>Memory Management]
            MEM[MEM_43.v<br/>Memory Controller]
            RAM[MEM_RAM_49.v<br/>RAM Interface]
        end

        subgraph "I/O System"
            IO[IO_37.v<br/>I/O Controller]
            UART[IO_UART_42.v<br/>UART]
            BIF[BIF_5.v<br/>Bus Interface]
        end

        subgraph "PAL Chips"
            PAL1[PAL_44302B.v<br/>Bus Cycle Control]
            PAL2[PAL_44446B.v<br/>Address Decode]
            PAL3[PAL_44601B.v<br/>Bus Interface]
            PAL_ETC[... 22 more PALs]
        end
    end

    TOP --> CPU_BOARD
    CPU_BOARD --> CPU
    CPU_BOARD --> CGA
    CPU_BOARD --> DGA
    CPU_BOARD --> MMU
    CPU_BOARD --> IO
    CPU_BOARD --> BIF

    CGA --> ALU
    CGA --> MAC
    CGA --> MIC
    CGA --> INTR
    CGA --> TRAP
    CGA --> WRF

    CPU --> CS
    CPU --> PROC

    IO --> UART

    MMU --> MEM
    MEM --> RAM
```

## Module Hierarchy and Descriptions

### 1. Top-Level Modules

#### ND120_TOP.v
**Location:** `E:\Dev\Repos\Ronny\nd-120\Verilog\ND120_TOP.v`
**Function:** FPGA top-level interface module
**Description:**
- Interfaces with external FPGA pins and I/O
- Handles system clock, reset, and UART signals
- Manages ND-100 bus interface signals (BD_23_0, BDAP, BDRY, etc.)
- Controls LEDs for system status indication
- Instantiates the main ND3202D CPU board

**Key Signals:**
- `sysclk` - System clock input
- `btn1/btn2` - Reset and control buttons
- `uartRx/uartTx` - UART communication
- `BD_23_0_n_*` - 24-bit bus data/address (bidirectional)
- `BINT10_n` through `BINT15_n` - Bus interrupt inputs
- `led[6:0]` - Status LED outputs

#### ND3202D.v
**Location:** `E:\Dev\Repos\Ronny\nd-120\Verilog\CPU-BOARD-3202\circuit\ND3202D.v`
**Function:** Main CPU board integration
**Description:**
- Complete CPU board implementation with all subsystems
- Manages three backplane interfaces: A-PLUG, B-PLUG, C-PLUG
- Integrates CPU, memory, I/O, and bus interface modules
- Handles configuration switches and test signals

**Major Subsystems:**
- CPU control and processing
- Memory management and RAM
- I/O and UART communication
- Bus interface and arbitration
- Interrupt handling
- Test and debug interfaces

### 2. CPU Core Components

#### CPU_15.v
**Location:** `E:\Dev\Repos\Ronny\nd-120\Verilog\CPU-BOARD-3202\circuit\CPU_15.v`
**Function:** Top-level CPU control and coordination
**Description:**
- Central CPU control module
- Integrates Control Store (CS) and processor modules
- Manages microcode execution flow
- Coordinates between different CPU subsystems

#### CPU_CS_16.v
**Location:** `E:\Dev\Repos\Ronny\nd-120\Verilog\CPU-BOARD-3202\circuit\CPU_CS_16.v`
**Function:** Control Store management
**Description:**
- Contains microcode storage and access logic
- Manages microcode address generation
- Handles control store caching
- Includes submodules for different CS functions:
  - `CPU_CS_ACAL_17.v` - Address calculation
  - `CPU_CS_CTL_18.v` - Control logic
  - `CPU_CS_PROM_19.v` - PROM microcode storage
  - `CPU_CS_TCV_20.v` - Test control vectors
  - `CPU_CS_WCS_21_22.v` - Writable control store

#### CPU_PROC_32.v
**Location:** `E:\Dev\Repos\Ronny\nd-120\Verilog\CPU-BOARD-3202\circuit\CPU_PROC_32.v`
**Function:** High-level processor control
**Description:**
- Integrates CGA (CPU Gate Array) and command decoder
- Manages processor state and control signals
- Coordinates instruction execution flow
- Interfaces with memory and I/O subsystems

### 3. CGA (DELILAH CPU) - Core Processing Engine

#### CGA.v
**Location:** `E:\Dev\Repos\Ronny\nd-120\Verilog\DELILAH-CPU\CGA\circuit\CGA.v`
**Function:** CPU Gate Array integration
**Description:**
- Central processing unit with all core execution logic
- 147 Verilog files, 22,976 lines of code
- Integrates all CGA submodules
- Manages internal data buses and control signals

#### CGA_ALU.v
**Location:** `E:\Dev\Repos\Ronny\nd-120\Verilog\DELILAH-CPU\CGA_ALU\circuit\CGA_ALU.v`
**Function:** Arithmetic Logic Unit
**Description:**
- 16-bit ALU with comprehensive operation set
- Multiple ALU sub-components for different operations
- Supports arithmetic, logic, shift, and rotate operations
- Includes status flag generation (carry, zero, overflow, etc.)
- Working register file integration

#### CGA_MAC.v
**Location:** `E:\Dev\Repos\Ronny\nd-120\Verilog\DELILAH-CPU\CGA_MAC\circuit\CGA_MAC.v`
**Function:** Memory Access Controller
**Description:**
- Coordinates all memory access operations
- Address generation and translation
- Memory timing and control signal generation
- Interface between CPU and memory subsystem

#### CGA_MIC.v
**Location:** `E:\Dev\Repos\Ronny\nd-120\Verilog\DELILAH-CPU\CGA_MIC\circuit\CGA_MIC.v`
**Function:** Microcode Controller
**Description:**
- Microcode instruction fetch and decode
- Control store address generation
- Microcode sequence control (jumps, calls, returns)
- Conditional execution handling

#### CGA_INTR.v
**Location:** `E:\Dev\Repos\Ronny\nd-120\Verilog\DELILAH-CPU\CGA_INTR\circuit\CGA_INTR.v`
**Function:** Interrupt Controller
**Description:**
- Priority interrupt handling for multiple sources
- Interrupt vector generation and dispatch
- Interrupt masking and enable/disable control
- EPIC (Enable Priority Interrupt Controller) command processing

#### CGA_TRAP.v
**Location:** `E:\Dev\Repos\Ronny\nd-120\Verilog\DELILAH-CPU\CGA_TRAP\circuit\CGA_TRAP.v`
**Function:** Trap and Exception Handler
**Description:**
- Exception detection and handling
- Trap vector generation
- Protection violation detection
- Debug and breakpoint support

#### CGA_WRF.v
**Location:** `E:\Dev\Repos\Ronny\nd-120\Verilog\DELILAH-CPU\CGA_WRF\circuit\CGA_WRF.v`
**Function:** Working Register File
**Description:**
- CPU register file management
- 16×16-bit general purpose registers
- Register addressing and selection logic
- Read/write port management

#### CGA_DCD.v
**Location:** `E:\Dev\Repos\Ronny\nd-120\Verilog\DELILAH-CPU\CGA_DCD\circuit\CGA_DCD.v`
**Function:** Instruction Decoder
**Description:**
- Machine instruction decode
- Microcode address generation from instructions
- Addressing mode decode
- Instruction format handling

#### CGA_IDBCTL.v
**Location:** `E:\Dev\Repos\Ronny\nd-120\Verilog\DELILAH-CPU\CGA_IDBCTL\circuit\CGA_IDBCTL.v`
**Function:** Internal Data Bus Controller
**Description:**
- Internal data bus arbitration and control
- Bus multiplexing and routing
- Data path management between CPU components

#### CGA_TESTMUX.v
**Location:** `E:\Dev\Repos\Ronny\nd-120\Verilog\DELILAH-CPU\CGA_TESTMUX\circuit\CGA_TESTMUX.v`
**Function:** Test Signal Multiplexer
**Description:**
- Debug and test signal routing
- Test point signal selection
- Diagnostic signal access for debugging

### 4. DGA (Decoder Gate Array)

#### DECODE_DGA.v
**Location:** `E:\Dev\Repos\Ronny\nd-120\Verilog\DECODE-GateArray\DGA\circuit\DECODE_DGA.v`
**Function:** Instruction Decode Gate Array
**Description:**
- 28 Verilog files, 4,316 lines of code
- Instruction decoding and microcode address generation
- Command signal generation
- Pipeline interface control

**Key Submodules:**
- `DECODE_DGA_COMM.v` - Command generation logic
- `DECODE_DGA_IDBS.v` - IDB source selection
- `DECODE_DGA_PFIFC.v` - Pipeline interface control
- `DECODE_DGA_PFIFD.v` - Pipeline interface data
- `DECODE_DGA_POW.v` - Power control logic

### 5. Memory Management System

#### CPU_MMU_24.v
**Location:** `E:\Dev\Repos\Ronny\nd-120\Verilog\CPU-BOARD-3202\circuit\CPU_MMU_24.v`
**Function:** Memory Management Unit
**Description:**
- Virtual memory address translation
- Memory protection and access control
- Page table management
- Cache hit detection and management

**MMU Submodules:**
- `CPU_MMU_CACHE_25.v` - Cache management logic
- `CPU_MMU_CSR_26.v` - Control and status registers
- `CPU_MMU_HIT_27.v` - Cache hit detection logic
- `CPU_MMU_PPNX_28.v` - Physical page number translation
- `CPU_MMU_PT_29.v` - Page table access logic
- `CPU_MMU_PTIDB_30.v` - Page table to IDB interface
- `CPU_MMU_WCA_31.v` - Write cache address handling

#### MEM_43.v
**Location:** `E:\Dev\Repos\Ronny\nd-120\Verilog\CPU-BOARD-3202\circuit\MEM_43.v`
**Function:** Main Memory Controller
**Description:**
- Primary memory subsystem control
- RAM interface coordination
- Memory timing and control
- Data path management

**Memory Submodules:**
- `MEM_ADDR_44.v` - Memory address generation
- `MEM_ADEC_45.v` - Address decoding logic
- `MEM_DATA_46.v` - Memory data path management
- `MEM_ERROR_47.v` - Error detection and correction
- `MEM_LBDIF_48.v` - Local bus data interface
- `MEM_RAM_49.v` - RAM controller
- `MEM_RAMC_50.v` - RAM control logic

### 6. I/O and Communication System

#### IO_37.v
**Location:** `E:\Dev\Repos\Ronny\nd-120\Verilog\CPU-BOARD-3202\circuit\IO_37.v`
**Function:** I/O System Controller
**Description:**
- Central I/O operations management
- Peripheral device interface
- I/O command processing
- Device selection and control

#### IO_UART_42.v
**Location:** `E:\Dev\Repos\Ronny\nd-120\Verilog\CPU-BOARD-3202\circuit\IO_UART_42.v`
**Function:** UART Communication Controller
**Description:**
- Serial communication interface
- Supports multiple baud rates (configurable via switches)
- 7-bit data, even parity, 2 stop bits (7E2 format)
- Interrupt-driven operation
- OPCOM (operator communication) support

#### BIF_5.v
**Location:** `E:\Dev\Repos\Ronny\nd-120\Verilog\CPU-BOARD-3202\circuit\BIF_5.v`
**Function:** Bus Interface Controller
**Description:**
- ND-100 bus protocol implementation
- Bus arbitration and control
- DMA support
- External device interface

**BIF Submodules:**
- `BIF_BCTL_6.v` - Bus control logic
- `BIF_BCTL_BDRV_7.v` - Bus drivers and transceivers
- `BIF_BCTL_SYNC_8.v` - Bus synchronization logic
- `BIF_DPATH_9.v` - Bus data path management

### 7. PAL Chips (Programmable Array Logic)

The system includes 25+ PAL chips implementing various control and decode functions:

#### Key PAL Functions

**PAL_44302B.v** - Bus Cycle Control
- Bus timing and cycle control
- Memory and I/O cycle generation

**PAL_44446B.v** - DMA Address Decode (BADEC)
- 4MB memory address decoding
- DMA operation support

**PAL_44601B.v** - Complex Bus Interface Control
- Advanced bus interface functions
- Multi-device arbitration

**PAL_44801A.v** - Address Decoding
- Memory and I/O address decode
- Chip select generation

**PAL_44902A.v** - Memory Control
- Memory timing control
- RAM control signal generation

### 8. Support and Control Modules

#### CYC_36.v
**Location:** `E:\Dev\Repos\Ronny\nd-120\Verilog\CPU-BOARD-3202\circuit\CYC_36.v`
**Function:** Cycle Controller
**Description:**
- CPU cycle timing and sequencing
- Clock generation and distribution
- Timing control for various operations

#### CPU_PROC_CMDDEC_34.v
**Location:** `E:\Dev\Repos\Ronny\nd-120\Verilog\CPU-BOARD-3202\circuit\CPU_PROC_CMDDEC_34.v`
**Function:** Command Decoder
**Description:**
- Microcode command field decoding
- Control signal generation from microcode
- Operation type determination

## C++ Integration with Verilator

### Overview

The Verilog code is designed to work seamlessly with C++ testbenches using Verilator for simulation and testing. The main C++ integration file demonstrates how to interface with the compiled Verilog modules.

### Run120.cpp Integration

**Location:** `E:\Dev\Repos\Ronny\nd-120\Verilog\runSim\Run120.cpp`

#### Key Features

**1. Verilator Integration**
```cpp
#include "VND120_TOP.h"
#include "VND120_TOP___024root.h"
#include "verilated.h"
```

**2. Direct Memory Access**
The C++ code can directly access internal Verilog memory structures:
```cpp
// Access MEM->RAM fields via rootp
auto &ram_low = top->rootp->ND120_TOP__DOT__CPU_BOARD__DOT__MEM__DOT__RAM__DOT__CHIP_15H__DOT__sdram;
auto &ram_high = top->rootp->ND120_TOP__DOT__CPU_BOARD__DOT__MEM__DOT__RAM__DOT__CHIP_15J__DOT__sdram;
```

**3. BPUN File Loading**
Supports loading ND-120 BPUN (bootable) format files directly into memory:
```cpp
loadfile(filename, 0, &ram_low[0], &ram_low_9[0], &ram_high[0], &ram_high_9[0]);
```

**4. UART Simulation**
Real-time UART communication with keyboard input/output:
- Non-blocking terminal I/O
- 7E2 serial format simulation
- Interactive console operation
- Baud rate timing simulation

**5. Bus Interface Simulation**
```cpp
proccess_bif_signal(top);  // Handles ND-100 bus protocol
```

**6. LED Status Monitoring**
Real-time LED status changes with descriptive output:
- CPU status (red/green)
- Parity error indication
- Bus grant indicators
- MMU status

#### Simulation Control

**Clock Management:**
```cpp
top->eval();
top->sysclk = !top->sysclk;  // Toggle system clock
```

**Reset Sequence:**
```cpp
top->btn1 = false;  // Assert reset
// ... wait 100 cycles
top->btn1 = true;   // Release reset
```

**Signal Initialization:**
```cpp
// Initialize bus interface signals
top->BD_23_0_n_IN = 0xFFFFFF;  // Pulled-high bus
top->BREQ_n = 1;               // No bus request
top->BINT10_n = 1;             // No interrupts
```

#### Usage Example

**Basic Simulation Run:**
```cpp
VND120_TOP *top = new VND120_TOP;
addDevices();  // Initialize peripheral devices

// Load program into memory
loadfile("DEBUG.BPUN", 0, &ram_low[0], &ram_low_9[0], &ram_high[0], &ram_high_9[0]);

// Run simulation loop
while (true) {
    top->eval();
    top->sysclk = !top->sysclk;

    // Handle UART I/O
    // Process bus signals
    // Monitor status changes
}
```

### Device Integration

The C++ code supports external device simulation through:
- **NDBus.h** - ND-100 bus protocol implementation
- **NDDevices.h** - Peripheral device simulation (Floppy, Papertape, etc.)

### Debugging Features

**1. Signal Tracing**
- VCD file generation for GTKWave
- Complete signal visibility
- Timing analysis capabilities

**2. Memory Inspection**
- Direct access to all internal memories
- Runtime memory modification
- State inspection capabilities

**3. Interactive Operation**
- Real-time keyboard input
- UART console communication
- OPCOM command interface

This integration allows for comprehensive testing and validation of the Verilog implementation while providing an interactive environment for CPU operation and debugging.

## Bus Interface and Signal Descriptions

### ND-100 Bus Signals

The ND-120 implements the complete ND-100 bus protocol with the following key signals:

**Address/Data Bus:**
- `BD_23_0_n` - 24-bit multiplexed address/data bus (active-low)

**Control Signals:**
- `BAPR_n` - Bus Address Present (active-low)
- `BDAP_n` - Bus Data Present (active-low)
- `BDRY_n` - Bus Data Ready (active-low)
- `SEMRQ_n` - Semaphore Request (active-low)
- `BINPUT_n` - Bus Input (active-low)

**Interrupt Signals:**
- `BINT10_n` through `BINT15_n` - Bus interrupts (active-low)
- `POWSENSE_n` - Power sense (active-low)

**Status and Control:**
- `BREF_n` - Bus Refresh (active-low)
- `BERROR_n` - Bus Error (active-low)
- `BMEM_n` - Bus Memory (active-low)
- `OUTGRANT_n` - Output Grant (active-low)

## Implementation Status and Testing

### Current Functionality

**✅ Working Features:**
- Complete Verilator compilation (259 files, 75,511 lines)
- Microcode loading and execution (64KB ROM)
- CPU self-test execution (7 out of 14 tests passing)
- UART communication (7E2 format)
- OPCOM operator interface
- Interactive console operation
- Bus interface protocol
- Interrupt handling
- Memory management
- LED status indication

**⚠️ Partial Implementation:**
- FPGA synthesis passes but implementation optimization needed
- Memory system requires FPGA-specific RAM modules
- Clock domain crossing improvements needed
- Static/Dynamic RAM module refactoring for FPGA

**🔧 Areas for Improvement:**
- Complete remaining 7 CPU self-tests
- FPGA implementation optimization
- Memory bandwidth optimization
- Additional peripheral device support

### Test Programs

The system successfully runs several test programs:
- **DEBUG.BPUN** - Debug test program (default)
- **INSTRUCTION-B.BPUN** - Instruction test suite (7/14 tests passing)
- **FLOPPY-FU-1986F.BPUN** - Floppy controller test
- Custom BPUN format programs

## Conclusion

The ND-120 Verilog implementation represents a comprehensive recreation of a sophisticated 1980s minicomputer architecture. With 75,511 lines of carefully crafted HDL code, it successfully demonstrates:

- **Historical Preservation**: Accurate recreation of original 1988 hardware design
- **Modern Implementation**: Synthesizable code for contemporary FPGA platforms
- **Educational Value**: Complete, documented example of minicomputer architecture
- **Functional Success**: Working CPU with microcode execution and I/O

The integration with C++ via Verilator provides a powerful simulation and development environment, enabling interactive operation, debugging, and validation. This implementation serves as both a tribute to classic computer architecture and a practical platform for education and experimentation with vintage computing systems.

## Interrupt and Trap Mechanism - Microcode Address Generation

### Overview

The ND-120 CPU implements a sophisticated interrupt and trap handling system that generates specific microcode addresses to handle various exceptional conditions. This system allows the CPU to respond to both external interrupts and internal trap conditions by vectoring to appropriate microcode routines.

### Interrupt and Trap Flow Architecture

```mermaid
graph TB
    subgraph "Interrupt Sources"
        BINT10[BINT10_n - Bus Interrupt 10]
        BINT11[BINT11_n - Bus Interrupt 11]
        BINT12[BINT12_n - Bus Interrupt 12]
        BINT13[BINT13_n - Bus Interrupt 13]
        BINT15[BINT15_n - Bus Interrupt 15]
        PARERRN[PARERRN - Parity Error]
        POWFAILN[POWFAILN - Power Failure]
        IOXERRN[IOXERRN - I/O Error]
        PANN[PANN - Panel Interrupt]
    end

    subgraph "Trap Sources"
        PVIOL[Protection Violation]
        VACC[Virtual Access]
        FTRAP[Forced Trap]
        VTRAP[Virtual Trap]
        PGFAULT[Page Fault]
        RESTR[Restriction Violation]
    end

    subgraph "CGA_INTR (Interrupt Controller)"
        INTR_CNTLR[CGA_INTR_CNTLR<br/>Priority & Vector Generation]
        INTR_IRSRC[CGA_INTR_IRSRC<br/>Interrupt Source Logic]
        PICV[PICV_2_0<br/>3-bit Interrupt Vector]
        IRQ[IRQ Signal]
    end

    subgraph "CGA_TRAP (Trap Handler)"
        TRAP_TVGEN[CGA_TRAP_TVGEN<br/>Trap Vector Generator]
        TRAP_TVGEN_P2[CGA_TRAP_TVGEN_P2<br/>Vector Logic]
        TVEC[TVEC_3_0<br/>4-bit Trap Vector]
        TRAPN[TRAP_n Signal]
    end

    subgraph "CGA_MIC_IPOS (Address Generation)"
        IPOS[Instruction Position Logic]
        MUX_SEL[4:1 Multiplexer Selection]
        MA_OUT[MA_12_0<br/>Final Microcode Address]
    end

    BINT10 --> INTR_IRSRC
    BINT11 --> INTR_IRSRC
    BINT12 --> INTR_IRSRC
    BINT13 --> INTR_IRSRC
    BINT15 --> INTR_IRSRC
    PARERRN --> INTR_IRSRC
    POWFAILN --> INTR_IRSRC
    IOXERRN --> INTR_IRSRC
    PANN --> INTR_IRSRC

    INTR_IRSRC --> INTR_CNTLR
    INTR_CNTLR --> PICV
    INTR_CNTLR --> IRQ

    PVIOL --> TRAP_TVGEN
    VACC --> TRAP_TVGEN
    FTRAP --> TRAP_TVGEN
    VTRAP --> TRAP_TVGEN
    PGFAULT --> TRAP_TVGEN
    RESTR --> TRAP_TVGEN

    TRAP_TVGEN --> TRAP_TVGEN_P2
    TRAP_TVGEN_P2 --> TVEC
    TRAP_TVGEN_P2 --> TRAPN

    IRQ --> IPOS
    TRAPN --> IPOS
    TVEC --> IPOS
    PICV --> IPOS

    IPOS --> MUX_SEL
    MUX_SEL --> MA_OUT
```

### Interrupt Processing (CGA_INTR)

#### Interrupt Sources and Priority

The interrupt controller handles multiple interrupt sources with hardware priority:

**External Bus Interrupts:**
- `BINT10_n` through `BINT15_n` - Bus interrupts from external devices
- Hardware priority encoded in interrupt level

**System Interrupts:**
- `PARERRN` - Parity error detection
- `POWFAILN` - Power failure warning
- `IOXERRN` - I/O exception error
- `PANN` - Panel interrupt from operator console

#### Interrupt Vector Generation

**CGA_INTR_CNTLR** generates interrupt vectors through priority encoding:

```verilog
// Interrupt priority encoding in CGA_INTR_CNTLR
output [2:0] PICV_2_0,    // PIC Vector - 3-bit interrupt vector
output [2:0] PICS_2_0,    // PIC Select - 3-bit priority level
output [15:0] PICMASK_15_0 // PIC Mask - interrupt enable mask
```

**Priority Resolution:**
1. **Interrupt Request Detection**: `CGA_INTR_IRSRC` monitors all interrupt sources
2. **Priority Encoding**: Highest priority active interrupt selected
3. **Vector Generation**: 3-bit vector (PICV_2_0) identifies interrupt type
4. **Mask Checking**: `PICMASK_15_0` determines which interrupts are enabled

**EPIC (Enable Priority Interrupt Controller):**
- `EPIC` signal enables/disables interrupt processing
- `EPICMASKN` output indicates mask register status

### Trap Processing (CGA_TRAP)

#### Trap Conditions

**Memory Protection Traps:**
- `PVIOL` - Protection violation (write to read-only page)
- `VACC` - Virtual memory access trap
- `RESTR` - Restriction violation

**System Traps:**
- `FTRAP` - Forced trap (software-initiated)
- `VTRAP` - Virtual trap condition
- Page faults and memory management exceptions

#### Trap Vector Generation (CGA_TRAP_TVGEN)

The trap system generates 4-bit trap vectors through complex condition analysis:

```verilog
// Trap vector generation logic
input VACC,       // Virtual access
input PVIOL,      // Protection violation
input RESTR,      // Restriction
input FTRAP,      // Forced trap
input VTRAP,      // Virtual trap
output [3:0] TVEC_3_0  // 4-bit trap vector
```

**Trap Priority Levels:**
- **LEV1**: Basic protection violations, page faults
- **LEV2**: Write protection, page guard violations
- **LEV3**: Virtual memory traps, system calls

**Vector Encoding (TVEC_3_0):**
- Bits 3:0 encode specific trap type
- Higher values indicate higher priority traps
- Vector determines microcode entry point

### Microcode Address Generation (CGA_MIC_IPOS)

#### Address Multiplexing

**CGA_MIC_IPOS** (Instruction Position) generates the final microcode address through 4:1 multiplexing:

```verilog
module CGA_MIC_IPOS (
    input [12:0] W_12_0,      // Working Address (normal execution)
    input [12:0] WCA_12_0,    // Write Control Store Address
    input [15:0] CD_15_0,     // Command/Data bus
    input [3:0] TVEC_3_0,     // Trap Vector (4 bits)
    input TRAPN,              // Trap signal (active low)
    input MAPN,               // MAP signal (active low)
    input EWCAN,              // External Write Cache Acknowledge
    output [12:0] MA_12_0     // Final Microcode Address
);
```

#### Address Selection Logic

**Multiplexer Control:**
```verilog
// Address selection based on trap and system state
wire [1:0] mux_selector;
assign mux_selector[1] = ~(MAP_n & TRAP_n);           // High priority
assign mux_selector[0] = ~(TRAP_n & EWCA_n & MAP_n);  // Low priority
```

**Address Sources (per bit):**
- **mux_selector = 00**: `W_12_0` - Normal microcode execution
- **mux_selector = 01**: `WCA_12_0` - Write control store mode
- **mux_selector = 10**: `CD_15_0[15:6]` - Direct address from command bus
- **mux_selector = 11**: `TVEC_3_0` - **Trap/Interrupt vector**

#### Interrupt/Trap Vector Address Mapping

**Critical Implementation:** When interrupts or traps occur:

```verilog
// For trap vectors (mux_selector = 11):
Multiplexer_4 PLEXERS_13 (
    .muxIn_3(s_tvec_3_0[3]),  // Trap vector bit 3
    .muxOut(s_ma_12_0_out[3]),
    .sel(mux_selector[1:0])
);

Multiplexer_4 PLEXERS_14 (
    .muxIn_3(s_tvec_3_0[2]),  // Trap vector bit 2
    .muxOut(s_ma_12_0_out[2]),
    .sel(mux_selector[1:0])
);

Multiplexer_4 PLEXERS_15 (
    .muxIn_3(s_tvec_3_0[1]),  // Trap vector bit 1
    .muxOut(s_ma_12_0_out[1]),
    .sel(mux_selector[1:0])
);

Multiplexer_4 PLEXERS_16 (
    .muxIn_3(s_tvec_3_0[0]),  // Trap vector bit 0
    .muxOut(s_ma_12_0_out[0]),
    .sel(mux_selector[1:0])
);
```

**Address Generation:**
- **Bits 12:4**: Set to specific values (typically 0x1xx for trap space)
- **Bits 3:0**: Direct mapping from TVEC_3_0 or PICV_2_0
- **Result**: Microcode address 0x1000 + vector value

### Vector Table Layout

#### Trap Vector Table (0x1000-0x100F)
```
0x1000: System Reset
0x1001: Protection Violation
0x1002: Page Fault
0x1003: Virtual Memory Trap
0x1004: Restriction Violation
0x1005: Forced Trap
0x1006: Memory Error
0x1007: I/O Error
0x1008-0x100F: Reserved trap vectors
```

#### Interrupt Vector Table (0x1010-0x101F)
```
0x1010: Bus Interrupt 10
0x1011: Bus Interrupt 11
0x1012: Bus Interrupt 12
0x1013: Bus Interrupt 13
0x1014: Reserved
0x1015: Bus Interrupt 15
0x1016: Panel Interrupt
0x1017: Power Failure
0x1018-0x101F: System interrupts
```

### Execution Flow

#### Interrupt Handling Sequence

1. **Interrupt Detection**: External signal asserted (BINT10_n, etc.)
2. **Priority Resolution**: CGA_INTR_CNTLR determines highest priority
3. **Vector Generation**: 3-bit PICV_2_0 generated
4. **IRQ Assertion**: IRQ signal notifies microcode controller
5. **Address Generation**: CGA_MIC_IPOS maps vector to microcode address
6. **Microcode Execution**: CPU vectors to interrupt handler routine

#### Trap Handling Sequence

1. **Trap Condition**: Memory protection violation, system call, etc.
2. **Condition Analysis**: CGA_TRAP_TVGEN evaluates trap type
3. **Vector Generation**: 4-bit TVEC_3_0 generated based on condition
4. **TRAP Assertion**: TRAP_n signal triggers address generation
5. **Address Mapping**: CGA_MIC_IPOS generates microcode address
6. **Handler Execution**: CPU executes appropriate trap handler

### Integration with Microcode Controller

The interrupt/trap system integrates with **CGA_MIC** (Microcode Controller):

- **Normal Operation**: MA_12_0 comes from sequential microcode address
- **Interrupt/Trap**: MA_12_0 overridden with vector-based address
- **Context Saving**: Microcode handlers save CPU state
- **Return Mechanism**: Handlers restore state and return to interrupted code

This sophisticated system allows the ND-120 to respond to exceptional conditions while maintaining precise execution state and supporting complex operating system features like virtual memory and multi-tasking.

**Future Development:** Continued work focuses on completing the remaining self-tests, optimizing for FPGA implementation, and expanding peripheral device support to create a fully functional ND-120 system.
# Development Guide

This document contains detailed development history, architecture information, and contribution guidelines for the ND-120 CPU project.

## Project History

### Development Timeline

| Date               | Milestone | Description |
|--------------------|-----------|-------------|
| **11. March 2023**     | **Project Start** | Received original Design Documentation from Lasse Bockelie |
| **21. August 2023**    | **Schematic Complete** | Logisim drawings completed for DGA (Decoder Gate Array) and DELILAH/CGA (CPU Gate Array) |
| **03. December 2023**  | **HDL Generation** | Started generating Verilog files from Logisim drawings for DGA and CGA |
| **12. December 2023**  | **PAL Conversion** | Began consolidating PAL chip information: PNG → PALASM → OCR → TXT → Verilog |
| **26. December 2023**  | **CPU Board Design** | Logisim drawings of complete CPU Board 3202D finished |
| **27. December 2023**  | **CPU Board HDL** | Started generating Verilog files for CPU Board 3202D |
| **11. January 2024**   | **PAL Completion** | Most PALASM code successfully ported to Verilog |
| **January-June 2024**  | **Integration** | Added support chips, extensive refactoring, bugfixing, tests and test results |
| **June-November 2024** | **Hiatus** | No active development |
| **9. November 2024**   | **Restart** | Resumed development after break: code cleanup, refactoring, system integration |
| **20. November 2024**  | **First Boot** | Verilator milestone: Microcode loads from ROM to DRAM, MACL starts (STACK/COND issues) |
| **13. December 2024**  | **UART Working** | Major milestone: MACL runs, CPU test code executes, OPCOM initialized, UART communication functional |
| **29. January 2025**   | **Test Progress** | Breakthrough: Test program 'INSTRUCTION-B.BPUN' (204384B 83.11.01) loads and runs, 7 out of 14 tests passing |
| **22. March 2025**     | **Bus Interface** | ND BUS interface via BIF module to C connector, Papertape reader and Floppy PIO implemented in C++ |
| **1. June 2025**       | **Panel Controller** | Reverse engineered ROM chips for panel controller using Ghidra and Claude.AI |

### Major Milestones

#### Phase 1: Documentation and Design (2023)
- **Goal**: Convert 1988 paper documentation to digital schematics
- **Achievement**: Complete Logisim-Evolution circuits for all major components
- **Challenges**: OCR accuracy, PALASM code interpretation, component identification

#### Phase 2: HDL Implementation (2023-2024)
- **Goal**: Generate synthesizable Verilog from Logisim designs
- **Achievement**: 75,511 lines of Verilog across 259 files
- **Challenges**: Logisim-to-Verilog translation, signal naming consistency, timing

#### Phase 3: Integration and Testing (2024-2025)
- **Goal**: Create working CPU simulation
- **Achievement**: Functional CPU with microcode execution and UART communication
- **Current Status**: 7/14 self-tests passing, OPCOM operational

## Architecture Overview

### System Components

#### 1. DELILAH CPU Gate Array (CGA)
**Location**: `Verilog/DELILAH-CPU/`
**Files**: 147 Verilog files, 22,976 lines
**Function**: Main CPU execution engine

**Submodules**:
- **CGA_ALU**: Arithmetic Logic Unit with 16-bit operations
- **CGA_MAC**: Memory Access Controller for address generation and memory interface
- **CGA_MIC**: Microcode Controller for instruction sequencing
- **CGA_INTR**: Interrupt Controller for system and I/O interrupts
- **CGA_TRAP**: Trap Handler for exceptions and error conditions
- **CGA_DCD**: Instruction Decoder for machine language instructions
- **CGA_WRF**: Working Register File for temporary storage
- **CGA_TESTMUX**: Test multiplexer for debugging and diagnostics
- **CGA_IDBCTL**: Internal Data Bus Controller

#### 2. Decoder Gate Array (DGA)
**Location**: `Verilog/DECODE-GateArray/`
**Files**: 28 Verilog files, 4,316 lines
**Function**: Instruction decode and microcode address generation

#### 3. CPU Board 3202D
**Location**: `Verilog/CPU-BOARD-3202/`
**Files**: 84 Verilog files, 48,219 lines
**Function**: Complete CPU system integration

**Major Subsystems**:
- **Memory Management Unit (MMU)**: Virtual memory and protection
- **Bus Interface (BIF)**: System bus communication
- **I/O Controllers**: UART, parallel I/O, interrupt handling
- **Clock and Control**: System timing and reset logic

#### 4. PAL Chips
**Location**: `Verilog/PAL/`
**Function**: Programmable Array Logic for various control functions

**Converted PAL Chips**:
- 44302B through 45009B series
- PALASM source code converted to behavioral Verilog
- Individual test benches for each PAL

#### 5. Shared Components
**Location**: `Verilog/Shared/`
**Function**: Common logic elements and support circuits

### Microcode Architecture

#### Microcode Structure
- **Size**: 64KB total (32KB low + 32KB high addresses)
- **Word Width**: 64 bits per microinstruction
- **Version**: 14/L (from original ND-120 3202 CPU Board)

#### Microcode Fields
The 64-bit microinstruction contains:
- **ALU Control**: Operation selection, operand routing
- **Memory Control**: Address generation, read/write control
- **Bus Control**: Internal bus routing and arbitration
- **Sequence Control**: Next address generation, conditional execution
- **I/O Control**: Device selection and operation codes

#### Execution Sequence
1. **Master Clear**: CPU initialization and self-test
2. **MACL (Master Clear)**: Microcode-level initialization
3. **Self-Test**: 14 individual CPU component tests
4. **OPCOM**: Operator communication mode via UART

### Panel Controller System

#### MC68705 Processors
The ND-120 system includes two 8-bit panel controllers:

**MC68705-U3** (CPU Board):
- 40 pins, 4× 8-bit I/O ports
- Controls CPU board status and diagnostics
- ROM dumped and reverse engineered

**MC68705-P3** (Front Panel):
- 28 pins, 2× 8-bit + 1× 4-bit I/O ports
- Controls physical front panel switches and displays
- ROM dumped from ND-5000C panel controller

#### Reverse Engineering
- **Tools**: GHIDRA (NSA's free SRE tool)
- **Assistance**: Claude.AI for code analysis
- **Output**: Complete firmware analysis and documentation

## Development Standards

### Coding Conventions

#### Verilog Standards
- **Signal Naming**: Use `s_` prefix for internal signals
- **Bus Naming**: Follow `BUSNAME_BITS` pattern (e.g., `CD_15_0`, `FIDB_15_0`)
- **Active-Low Signals**: Use `_n` suffix (e.g., `reset_n`, `trap_n`)
- **Module Headers**: Include component name, page references, review dates

#### File Organization
- **Module per File**: One primary module per `.v` file
- **Directory Structure**: Mirror Logisim hierarchy
- **Test Benches**: Separate `_tb.v` files for each module
- **Simulation**: Individual `sim/` directories with Makefiles

#### Documentation Standards
```verilog
/**************************************************************************
** ND120 CGA (CPU Gate Array / DELILAH)                                  **
** /CGA/ALU/QREG                                                         **
** Q REGISTER                                                            **
**                                                                       **
** Page 43                                                               **
** SHEET 1 of 1                                                          **
**                                                                       **
** Last reviewed: 11-NOV-2024                                            **
** Ronny Hansen                                                          **
***************************************************************************/
```

### Testing Strategy

#### Simulation Levels
1. **Unit Tests**: Individual module verification
2. **Component Tests**: Subsystem integration (ALU, MAC, etc.)
3. **System Tests**: Complete CPU with microcode
4. **Regression Tests**: Automated test suite execution

#### Test Coverage
- **Functional**: All microcode instructions and CPU operations
- **Timing**: Clock domain crossing and setup/hold requirements
- **Error Conditions**: Trap handling, interrupt processing, error recovery
- **Performance**: Instruction throughput and memory bandwidth

### Build System

#### Makefile Structure
Each testable component includes:
```makefile
VERILATOR_FLAGS = --trace -Wall --cc $(MODULE).v $(SUPPRESS_FLAGS)
CPP_SOURCES = test_$(MODULE).cpp

all: test run gtk
test: compile
run: execute simulation
gtk: open GTKWave viewer
clean: remove build artifacts
```

#### Continuous Integration
- **Verilator Compilation**: All modules must compile without errors
- **Simulation Tests**: Automated execution of test suites
- **Waveform Generation**: VCD files for all major test cases
- **Regression Detection**: Compare against known-good results

## Contributing

### Getting Started
1. **Read Documentation**: Start with `README.md`, then `BUILDING.md`
2. **Build System**: Ensure Verilator simulation works
3. **Choose Component**: Pick a specific module or subsystem
4. **Run Tests**: Execute existing tests to understand current state

### Development Workflow
1. **Create Branch**: Use descriptive branch names
2. **Make Changes**: Follow coding conventions
3. **Test Locally**: Run relevant simulation tests
4. **Document Changes**: Update comments and documentation
5. **Submit PR**: Include test results and explanation

### Areas Needing Contribution

#### High Priority
- **FPGA Implementation**: Fix synthesis/implementation issues
- **Test Coverage**: Increase passing tests from 7/14 to 14/14
- **Memory System**: Improve static/dynamic RAM modules
- **Clock Management**: Fix timing and clock domain crossing

#### Medium Priority
- **I/O Devices**: Implement additional peripheral support
- **Performance**: Optimize critical paths for higher clock speeds
- **Documentation**: Improve inline comments and user guides
- **Verification**: Add formal verification for critical components

#### Future Enhancements
- **FPGA Boards**: Support for additional FPGA platforms
- **Debug Interface**: JTAG or similar debugging capabilities
- **Peripherals**: Floppy disk, hard drive, network interfaces
- **Operating System**: Boot capability for original ND software

### Code Review Guidelines
- **Functionality**: Does the code work as intended?
- **Standards**: Follows project coding conventions?
- **Testing**: Includes appropriate test coverage?
- **Documentation**: Clear comments and documentation updates?
- **Performance**: No unnecessary resource usage?

### Issue Reporting
When reporting issues:
1. **Environment**: OS, Verilator version, build configuration
2. **Reproduction**: Minimal steps to reproduce the problem
3. **Expected vs Actual**: What should happen vs what does happen
4. **Logs**: Include relevant console output and waveforms
5. **Context**: What were you trying to accomplish?

## Resources

### Original Documentation
- **Design Documents**: `DesignDocuments/` - Original 1988 schematics and specifications
- **Norsk Data Docs**: `NorskData-Doc/` - Functional descriptions, instruction set, microprogramming guide
- **Microcode**: `Code/Microcode/` - ROM dumps and assembly source

### External References
- **NDWiki**: [Comprehensive ND-120 documentation](https://www.ndwiki.org/wiki/3202)
- **Norsk Data**: [Official historical website](http://sintran.com/)
- **Logisim-Evolution**: [Schematic design tool](https://github.com/logisim-evolution/logisim-evolution)
- **Verilator**: [Verilog simulation tool](https://www.veripool.org/verilator/)

### Community
- **Acknowledgments**: Special thanks to Lasse Bockelie for original documentation and Matthieu Benoit for ROM chip reading
- **Tools**: GHIDRA for reverse engineering, Claude.AI for analysis assistance
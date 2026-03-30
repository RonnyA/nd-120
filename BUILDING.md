# Building and Testing ND-120

This document provides comprehensive instructions for building, testing, and running the ND-120 CPU implementation.

## Prerequisites

### Required Tools

#### Verilator
Install [Verilator](https://www.veripool.org/verilator/) for Verilog simulation and testing.

**Windows Installation:**
- Download from the official website or use a package manager
- Ensure `verilator` is in your PATH

#### Logisim-Evolution (Optional)
For viewing and modifying the original schematics:
- Install [Logisim-Evolution](https://github.com/logisim-evolution/logisim-evolution)
- Tested with [Version 3.8.0](https://github.com/logisim-evolution/logisim-evolution/releases/tag/v3.8.0)

#### GTKWave (Optional)
For viewing simulation waveforms:
- Install [GTKWave](https://gtkwave.sourceforge.net/)
- Use the `-g` flag for large VCD files (>1GB)
- Use the `-o` flag to convert VCD to FST format

### System Requirements
- **Windows**: PowerShell or Command Prompt (bash not supported)
- **Make**: GNU Make or compatible
- **C++ Compiler**: For Verilator compilation

## Building the Project

### Quick Start
```powershell
# Navigate to main simulation directory
cd E:\Dev\Repos\Ronny\nd-120\Verilog\sim

# Clean previous builds
make clean

# Build and run complete simulation with waveform viewer
make all
```

### Build Targets

#### Main CPU Simulation
```powershell
cd E:\Dev\Repos\Ronny\nd-120\Verilog\sim

# Individual commands
make clean          # Remove build artifacts
make test_nd120     # Compile Verilog to C++
make run           # Execute simulation
make gtk           # Open GTKWave with traces
make all           # Complete build, run, and view cycle
```

#### Full CPU System with Microcode
```powershell
cd E:\Dev\Repos\Ronny\nd-120\Verilog\runSim

make clean
make compile       # Compile with Run120.cpp (includes microcode)
make run          # Run CPU with microcode and self-test
make all          # Compile and run in sequence
```

#### Individual Component Testing

**PAL Chip Testing:**
```powershell
cd E:\Dev\Repos\Ronny\nd-120\Verilog\PAL\44302B\sim
make clean
make all          # Test PAL 44302B
make gtk          # View PAL-specific waveforms
```

**CPU Component Testing:**
```powershell
# Test individual CPU components
cd E:\Dev\Repos\Ronny\nd-120\Verilog\DELILAH-CPU\CGA_ALU\sim
make clean
make all

cd E:\Dev\Repos\Ronny\nd-120\Verilog\CPU-BOARD-3202\circuit\CPU_15\sim
make clean
make all
```

## Build Configuration

### Verilator Flags
The build system uses these Verilator configuration flags:
```makefile
SUPPRESS_FLAGS = -Wno-UNOPTFLAT -Wno-PINCONNECTEMPTY -Wno-UNUSED -Wno-UNDRIVEN -Wno-WIDTH -Wno-EOFNEWLINE -Wno-LATCH
VERILATOR_FLAGS = --trace -Wall --cc ND120_TOP.v $(SUPPRESS_FLAGS)
```

### Include Paths
The build automatically includes:
- `../Shared/logisim` - Logisim-generated components
- `../Shared/ndlib` - ND-120 specific libraries
- `../Shared/support` - Support circuits
- `../CPU-BOARD-3202/circuit` - CPU board modules
- `../DELILAH-CPU/` - CGA submodules
- `../DECODE-GateArray/` - DGA modules
- `../PAL` - PAL chip implementations

## Testing

### Simulation Output
The main simulation produces:
- **Console Output**: CPU state, microcode execution, UART communication
- **VCD Files**: Complete signal traces for waveform analysis
- **Log Files**: Detailed execution logs

### Test Programs
The CPU simulation runs several test sequences:

1. **Microcode Load**: Loads 64KB microcode (32KB low + 32KB high)
2. **Master Clear**: CPU initialization sequence
3. **MACL (Master Clear)**: CPU self-test and initialization
4. **Self-Test**: 14 individual CPU tests (currently 7 passing)
5. **OPCOM Mode**: UART communication interface

### Expected Results
```
Microcode loading: ✓ Success
Master Clear: ✓ Success
MACL execution: ✓ Success
CPU Self-tests: 7/14 passing
UART Communication: ✓ Working
```

### Waveform Analysis
```powershell
# View main CPU waveforms
cd E:\Dev\Repos\Ronny\nd-120\Verilog\sim
make gtk

# GTKWave opens with pre-configured signal groups in top_3202d.gtkw
```

The waveform viewer shows:
- Clock signals and timing
- CPU bus transactions
- ALU operations
- Memory access patterns
- Interrupt handling
- UART communication

### Debugging
For debugging issues:

1. **Check Build Output**: Verilator compilation warnings/errors
2. **Console Logs**: CPU execution traces and error messages
3. **Waveforms**: Signal-level debugging in GTKWave
4. **Component Tests**: Run individual module tests to isolate issues

#### Common Issues
- **Clock Timing**: Check MCLK, UCLK signals in waveforms
- **Memory Access**: Verify address/data bus patterns
- **Microcode**: Ensure ROM files are loaded correctly
- **UART**: Check baud rate and protocol settings

### Performance Testing
```powershell
# Run extended CPU test
cd E:\Dev\Repos\Ronny\nd-120\Verilog\runSim
make run

# Monitor for:
# - Microcode execution speed
# - Memory access patterns
# - Interrupt response times
# - UART throughput
```

## FPGA Synthesis (Experimental)

**Status**: Synthesis passes but implementation fails

The Verilog code can be synthesized for FPGA but requires additional work:
- Static/Dynamic RAM module refactoring needed
- Clock domain crossing fixes required
- Resource optimization for target FPGA

For Tang Nano development:
- Use SPI flash for microcode ROM storage
- Implement proper clock management
- Add FPGA-specific constraints

## Troubleshooting

### Windows-Specific Notes
- **Never use bash commands** like `cd /path`
- **Use PowerShell** or Command Prompt: `cd E:\path`
- **File paths**: Use backslashes or forward slashes consistently

### Build Errors
```powershell
# Clean everything and rebuild
make clean
# Check for file permission issues
# Ensure Verilator is in PATH
# Verify C++ compiler availability
```

### Simulation Errors
- Check microcode ROM files are present
- Verify all Verilog module dependencies
- Review console output for specific error messages
- Use GTKWave to identify signal timing issues

## Advanced Usage

### Custom Test Programs
To run custom test programs:
1. Place binary files in `runSim/` directory
2. Modify `Run120.cpp` to load your program
3. Rebuild and run simulation

### Signal Tracing
Customize signal tracing by editing:
- `top_3202d.gtkw` - Main CPU signals
- `pal.gtkw` - PAL chip signals
- Individual component `.gtkw` files

### Performance Analysis
The simulation provides detailed metrics:
- Clock cycles per instruction
- Memory bandwidth utilization
- Interrupt latency measurements
- UART communication throughput
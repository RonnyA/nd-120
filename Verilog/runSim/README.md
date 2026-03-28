# ND-120 CPU Simulator (runsim)

This directory contains the full ND-120 CPU simulator that executes ND-120 programs using Verilator. The simulator compiles the entire ND-120 CPU Verilog implementation into a C++ executable that provides interactive console I/O and runs real ND-120 code.

## Overview

The simulator:
- Compiles the complete ND-120 CPU implementation (CPU board, CGA, DGA, PALs, memory, I/O)
- Loads bootable program files in BPUN format (Bootable Paper tape UNit) into memory
- Provides UART console I/O for interactive CPU communication
- Simulates the bus interface for connecting peripheral devices
- Monitors CPU LEDs and status indicators

## Building and Running

### Quick Start

```bash
# Build and run with default program (DEBUG.BPUN)
make clean
make compile
make run
```

### Build Commands

```bash
make clean      # Remove all compiled files
make compile    # Compile Verilog + C++ into executable
make run        # Run the simulation
make all        # Clean, compile, and run
```

### Running with Different Programs

By default, the simulator loads `DEBUG.BPUN`. To load a different program:

```bash
./obj_dir/VND120_TOP INSTRUCTION-B.BPUN
```

## Files Loaded on Startup

### Default Boot File: DEBUG.BPUN

The simulator loads `DEBUG.BPUN` by default (see `Run120.cpp` line 148). This is a comprehensive test program that includes:
- Master Clear/Power Clear initialization
- MACL (Machine Clear) routine
- CPU self-test program (Tests 1-14)
- OPCOM interactive command mode

### Microcode ROM Files

The CPU's microcode is embedded in the Verilog modules themselves. The following hex files are present for reference but are loaded by the CPU hardware design:
- `AM27256_45132L.hex` - Low microcode ROM (32KB)
- `AM27256_45133L.hex` - High microcode ROM (32KB)

### Memory Organization

The BPUN file is loaded into simulated RAM at the address specified in the file:
- **RAM Low** (bits 0-7): `ram_low[]` + parity bit `ram_low_9[]`
- **RAM High** (bits 8-15): `ram_high[]` + parity bit `ram_high_9[]`

## Available Test Programs

| File | Description | Size |
|------|-------------|------|
| `DEBUG.BPUN` | Full CPU test suite with OPCOM (DEFAULT) | 1.2 MB |
| `INSTRUCTION-B.BPUN` | Instruction set tests | 46 KB |
| `ONE-CHECK-1192A.BPUN` | Single check test | 6 KB |
| `CONFIGURATIO-C08.BPUN` | Configuration test | 47 KB |
| `TPE-MON-100-B00.BPUN` | Tape monitor program | 56 KB |
| `RTC.BPUN` | Real-time clock test | 2 KB |
| `fs.BPUN` | File system test | 51 KB |
| `four-ch-1418e.bpun` | Four channel test | 4 KB |
| `FLOPPY-FU-1986F.BPUN` | Floppy disk utility (1983) | 7 KB |
| `FLOPPY.IMG` | Floppy disk image | 1.2 MB |

## BPUN File Format

BPUN (Bootable Paper tape UNit) format consists of:
- **Section A**: Header text (ignored until '!')
- **Section B**: (optional) Octal start address terminated by CR
- **Section C**: (optional) Octal value terminated by '!'
- **Section D**: '!' delimiter
- **Section E**: Block start address (2 bytes, MSB first)
- **Section F**: Word count (2 bytes, MSB first)
- **Section G**: Data words (16-bit each)
- **Section H**: Checksum of section G (1 word)
- **Section I**: Action code (if non-zero, start at address B)

## Interactive Operation

### Console I/O

The simulator provides interactive UART console communication:
- **Keyboard input**: Characters typed are transmitted to the ND-120 CPU via UART
- **CPU output**: Characters from CPU are displayed on the console
- **Line endings**: LF is automatically converted to CR for ND-120 compatibility

### UART Configuration

- **Format**: 7N2 (7 data bits, no parity, 2 stop bits)
- **Baud rate**: Simulated with `DELAY_FRAMES = 16` clock cycles per bit
- **Non-blocking**: Terminal is set to non-blocking mode for interactive use

### CPU Status LEDs

The simulator monitors 6 CPU status LEDs:
- **CPU Red LED**: CPU error/halt state
- **CPU Green LED**: CPU running normally
- **Parity Error LED**: Memory parity error detected
- **CPU Grant Indicator**: CPU has bus control
- **Bus Grant Indicator**: External device has bus control
- **MMU LED1**: Memory Management Unit status

## CPU Boot Sequence

When the simulator starts:

1. **Reset Phase** (0-100 clock cycles)
   - All signals initialized
   - System reset active (`btn1 = false`)
   - UART in MARK state
   - Bus interface signals set to defaults

2. **Memory Load** (startup)
   - BPUN file loaded into RAM
   - Parity bits calculated for all memory
   - Load address and word count displayed

3. **CPU Execution** (after 100 clocks)
   - System reset released (`btn1 = true`)
   - CPU starts at microcode address 0
   - Master Clear routine executes
   - Jumps to MACL initialization
   - Runs self-test program
   - Enters OPCOM mode (for DEBUG.BPUN)

## Bus Interface Simulation

The simulator provides a simulated bus interface via `NDDevices.cpp` and `NDBus.cpp`:
- Bus request/grant arbitration
- Interrupt lines (BINT10-15)
- Bus data lines (BD 23-0)
- Control signals (SEMRQ, BINPUT, BDAP, BDRY, BAPR)
- Power sensing

## Compilation Details

### Source Files

- **Main**: `Run120.cpp` - Simulation control and UART I/O
- **Devices**: `../simDevices/NDDevices.cpp` - Peripheral device simulation
- **Bus**: `../simDevices/NDBus.cpp` - Bus interface logic

### Include Paths

The Makefile includes all Verilog module directories:
- `../ND120_TOP.v` - Top-level CPU module
- `../CPU-BOARD-3202/circuit/` - CPU board modules
- `../DELILAH-CPU/CGA*/circuit/` - CGA submodules
- `../DECODE-GateArray/DGA/circuit/` - DGA modules
- `../PAL/` - PAL implementations
- `../Shared/` - Common components

### Verilator Flags

```
--trace                # Enable waveform tracing (if DO_TRACE defined)
-Wall                  # All warnings
--cc                   # Generate C++ code
--exe                  # Create executable
```

**Suppressed warnings**:
- `UNOPTFLAT` - Unoptimized flat arrays
- `PINCONNECTEMPTY` - Empty pin connections
- `UNUSED` - Unused signals
- `UNDRIVEN` - Undriven signals
- `WIDTH` - Width mismatches
- `EOFNEWLINE` - Missing newline at EOF
- `LATCH` - Inferred latches

## Output Directory

All compiled files are in `obj_dir/`:
- `VND120_TOP` - Main executable
- `VND120_TOP.mk` - Generated Makefile
- `VND120_TOP__*.cpp/h` - Generated C++ files

## Debugging

### Enable Waveform Tracing

Uncomment `#define DO_TRACE` in `Run120.cpp` and recompile:

```cpp
#define DO_TRACE
```

This will generate VCD waveform files viewable in GTKWave.

### Console Output

The simulator displays:
- BPUN load information (addresses, checksums)
- CPU output via UART
- LED state changes (if enabled in code)

### Memory Inspection

Memory can be inspected via Verilator's internal structures:
```cpp
top->rootp->ND120_TOP__DOT__CPU_BOARD__DOT__MEM__DOT__RAM__DOT__CHIP_15H__DOT__sdram
```

## Related Files

- `../ND120_TOP.v` - Top-level CPU module
- `../sim/` - Simple test simulation with GTKWave traces
- `../readme.md` - Overall Verilog implementation status
- `../../README.md` - Complete project documentation
- `../../DesignDocuments/` - Original 1988 design documents

## Current Test Results

Running `DEBUG.BPUN`:
- ✅ Microcode load successful
- ✅ Master Clear completes
- ✅ MACL initialization completes
- ✅ UART communication working
- ✅ 7 of 14 CPU tests passing
- ⚠️ Self-test partially working (needs debugging)
- ✅ OPCOM interactive mode accessible

## Notes

- Terminal is set to non-blocking, raw mode for interactive use
- Ctrl+C will terminate the simulation
- The simulation runs indefinitely until stopped
- Memory parity bits are automatically calculated using even parity
- All addresses displayed in octal format (base 8)

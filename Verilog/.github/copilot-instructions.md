# ND-120 CPU Implementation Guide

## Project Overview
The ND-120 project implements a hardware CPU design in Verilog. It's a comprehensive reimplementation with multiple components:

- **DELILAH-CPU**: Core CPU components (CGA - CPU Gate Array)
- **DECODE-GateArray**: Instruction decoder components (DGA)
- **CPU-BOARD-3202**: Complete CPU board implementation
- **PAL**: Programmable Array Logic components
- **Shared**: Common modules used across components
- **sim/runSim**: Simulation environments for testing

## Architecture

### CPU Structure
- 64-bit microcode instruction format
- Key components: ALU, Memory Access Controller, Interrupt Controller, Trap Handler
- Commands are executed via 5-bit CSCOMM field (bits 36-32) with subcommands via MIS bits (43-42)
- Example: Command 5 (UART) has subcommands 5.0-5.3 for different registers

```verilog
// From ND120_TOP.v - Top level module connecting all components
module ND120_TOP
(
    input wire sysclk,    //! System Clock
    input wire btn1,      //! Button 1, mapped to S1
    // ...other signals
);
```

### Key Interfaces
- UART interface for terminal communication
- Bus interface for peripheral communication
- Interrupt handling via PIC (Programmable Interrupt Controller)
- Memory management and address translation

## Workflow

### Building and Testing
- Use Verilator for simulation:
```bash
cd sim
make
make run     # Run simulation with trace output
make gtk     # Open trace in GTKWave
```

- Load test programs into simulated ROM:
```bash
# In sim directory, microcode is automatically loaded from:
# AM27256_45132L.hex and AM27256_45133L.hex
```

### Boot Process
1. Reset components
2. Load microcode (32KB low + 32KB high)
3. Start at address 0 (Master Clear)
4. Initialize registers and UART
5. Run self-test (Tests 1-8)
6. Enter OPCOM mode or auto-load from storage

## Code Conventions

### Verilog Style
- Module names match hardware schematics (e.g., `CPU_CS_16.v` for Control Store sheet 16)
- Signal names preserve original hardware naming (active-low signals end with `_n`)
- Comments describe hardware connections and signal flows

### Documentation
- `nd120-plan.md`: Architecture documentation (microcode format, components)
- `readme.md` files in each directory explain components
- Signal documentation in `SignalReport.md`

## Common Tasks

### Adding New Commands
1. Identify the command number (5-bit CSCOMM field) and subcommand (MIS bits)
2. Update command handling in `CPU_CS_16.v` or related component
3. Document in `nd120-plan.md` under appropriate section
4. Add test cases in simulation

### Debugging Tips
- Use GTKWave to visualize signal traces from `sim/waveform.vcd`
- Trace the CSA (Control Store Address) to follow CPU execution
- Monitor the CD bus and FIDB bus for data flow
- Check LED outputs for system status

### Cross-Component Dependencies
- CGA modules (DELILAH-CPU) depend on PAL components for control logic
- CPU-BOARD-3202 integrates CGA, DGA and external components
- Microcode structure (`nd120-plan.md`) defines the execution model

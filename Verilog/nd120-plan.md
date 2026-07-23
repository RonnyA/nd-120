# ND-120 CPU Architecture Implementation in C

This document outlines the architectural structure of the ND-120 CPU for reimplementation in C, based on analysis of the Verilog codebase.

## 1. Microcode Structure

The CPU uses a 64-bit microcode instruction format with fields allocated as follows:

| Bit Range | Field Name    | Description                    |
|-----------|---------------|--------------------------------|
| 63-55     | CSALUI_8_0    | ALU Instruction (9 bits)       |
| 54-53     | CSSTSS_1_0    | STS control bits (2 bits)      |
| 52-51     | CSRASEL_1_0   | Register A Select (2 bits)     |
| 50        | CSXREF3       | Cross Reference bit            |
| 49-48     | CSRBSEL_1_0   | Register B Select (2 bits)     |
| 47-46     | CSCINSEL_1_0  | Carry Input Select (2 bits)    |
| 45-44     | CSALUM_1_0    | ALU Mode (2 bits)              |
| 43-42     | CSMIS_1_0     | Miscellaneous bits (2 bits)    |
| 41-37     | CSIDBS_4_0    | IDB Select (5 bits)            |
| 36-32     | CSCOMM_4_0    | Command bits (5 bits)          |
| 31-28     | CSTS_6_3      | Status bits (4 bits)           |
| 27-26     | CSDELAY_1_0   | Clock cycle delay (not in CGA) |
| 25        | CSVECT        | Vector control bit             |
| 24        | CSSCOND       | Conditional execution bit      |
| 23        | CSECOND       | Enable condition bit           |
| 22        | CSLOOP        | Loop control bit               |
| 21        | CSDLY         | Delay (not used in CGA)        |
| 20        | CSBIT20       | Control bit 20                 |
| 19-16     | CSRB_3_0      | Register B bits (4 bits)       |
| 15-0      | CSBIT_15_0    | Control bits (16 bits)         |

## 2. Main CPU Components

### 2.1 Data Structures

```c
typedef struct {
    // 64-bit microcode instruction
    uint8_t csalui_8_0;     // ALU Instruction bits [8:0] 
    uint8_t csstss_1_0;     // STS control bits [1:0]
    uint8_t csrasel_1_0;    // Register A Select [1:0]
    uint8_t csxref3;        // Cross Reference bit
    uint8_t csrbsel_1_0;    // Register B Select [1:0]
    uint8_t cscinsel_1_0;   // Carry Input Select [1:0]
    uint8_t csalum_1_0;     // ALU Mode [1:0]
    uint8_t csmis_1_0;      // Miscellaneous bits [1:0]
    uint8_t csidbs_4_0;     // IDB Select [4:0]
    uint8_t cscomm_4_0;     // Command bits [4:0]
    uint8_t csts_6_3;       // Status bits [6:3]
    uint8_t csvect;         // Vector control bit
    uint8_t csscond;        // Conditional execution bit
    uint8_t csecond;        // Enable condition bit
    uint8_t csloop;         // Loop control bit
    uint8_t csbit20;        // Control bit 20
    uint8_t csrb_3_0;       // Register B bits [3:0]
    uint16_t csbit_15_0;    // Control bits [15:0]
} Microinstruction;

typedef struct {
    // Major CPU components
    MicrocodeController mic;
    ArithmeticLogicUnit alu;
    MemoryAccessController mac;
    InterruptController intr;
    TrapHandler trap;
    Decoder dcd;
    
    // CPU state registers
    uint16_t registers[16];      // General purpose registers
    uint16_t cd_bus[16];         // Command/Data bus
    uint16_t fidb_bus_in[16];    // FIDB input bus
    uint16_t fidb_bus_out[16];   // FIDB output bus
    uint16_t csa;                // Control store address (13-bit)
    uint16_t csca;               // Control store cache address (10-bit)
    
    // Control and status flags
    bool acond_n;                // ALU Condition (negated)
    bool poni;                   // Memory protection ON indicator
    bool ioni;                   // I/O Non-maskable interrupt flag
    uint8_t pil[4];              // Processor interrupt level (4-bit)
    bool cgabrk_n;               // CGA Break (negated)
    bool trap_n;                 // Trap flag (negated)
    bool lshadow;                // Shadow register load
    bool double_precision;       // Double precision operations
    uint8_t pcr_1_0;             // Processor Control Register (2-bit)
    
    // Current microinstruction
    Microinstruction current_instr;
} CPU;
```

### 2.2 Microinstruction Controller (MIC)

```c
typedef struct {
    uint16_t cd_15_0;           // Command/Data bus
    uint16_t ma_12_0;           // Microcode Address (13-bit)
    uint16_t mca_9_0;           // Microcode Cache Address (10-bit)
    uint16_t wca_12_0;          // Write Control Store Address
    
    // Stack for microcode subroutine calls
    uint16_t stack[4];          // Stack for addresses
    uint8_t stack_ptr;          // Stack pointer
    
    // Control signals
    bool mclk;                  // Main clock
    bool ewca_n;                // Enable Write Cache Address (negated)
    bool map_n;                 // Memory Address Present (negated)
    bool trap_n;                // Trap (negated)
    bool wcs_n;                 // Write Control Store (negated)
} MicrocodeController;
```

### 2.3 Arithmetic Logic Unit (ALU)

```c
typedef struct {
    // ALU inputs from microcode
    uint8_t csalui_8_0;         // ALU Instruction (9-bit)
    uint8_t csalum_1_0;         // ALU Mode (2-bit)
    uint8_t cscinsel_1_0;       // Carry Input Select (2-bit)
    uint8_t csrasel_1_0;        // Register A Select (2-bit)
    uint8_t csrbsel_1_0;        // Register B Select (2-bit)
    
    // Registers
    uint16_t a_reg;             // A register
    uint16_t b_reg;             // B register
    uint16_t p_reg;             // P register (result)
    uint16_t q_reg;             // Q register (for shifts/rotates)
    
    // Status flags
    bool acond_n;               // ALU Condition (negated)
    bool cry;                   // Carry flag
    bool ovf;                   // Overflow flag
    bool zero;                  // Zero flag
} ArithmeticLogicUnit;
```

### 2.4 Memory Access Controller (MAC)

```c
typedef struct {
    // Control signals
    bool double_precision;      // Double precision operations
    bool ilcs_n;                // Instruction Load Control Signal (negated)
    bool mclk;                  // Master Clock
    bool mr_n;                  // Memory Read (negated)
    bool poni;                  // Memory Protection ON indicator
    
    // Bus interfaces
    uint16_t cd_15_0;           // Code/Data Bus
    uint16_t fidb_in_15_0;      // FIDB Input Bus
    uint16_t fidb_out_15_0;     // FIDB Output Bus
    uint16_t pr_15_0;           // ALU P Register
    uint16_t br_15_0;           // ALU B Register
    
    // Address generation
    uint16_t pcr_15_0;          // Program Counter Register
    uint16_t la_23_10;          // Local Address bits 23-10
    uint8_t laa_3_0;            // Local Address A bits 3-0
    uint8_t lba_3_0;            // Local Bus Address bits 3-0
} MemoryAccessController;
```

### 2.5 Interrupt Controller (INTR)

```c
typedef struct {
    // Interrupt inputs
    bool bint10_n;              // Bus Interrupt 10 (negated)
    bool bint11_n;              // Bus Interrupt 11 (negated)
    bool bint12_n;              // Bus Interrupt 12 (negated)
    bool bint13_n;              // Bus Interrupt 13 (negated)
    bool bint15_n;              // Bus Interrupt 15 (negated)
    bool ioxerr_n;              // IO Exception Error (negated)
    bool mor_n;                 // Memory Error (negated)
    bool pan_n;                 // Panel Interrupt (negated)
    bool parerr_n;              // Parity Error (negated)
    bool powfail_n;             // Power Failure (negated)
    
    // Control signals
    bool clirq_n;               // Clear Interrupt Request (negated)
    bool empid_n;               // Interrupt Disable (negated)
    bool epic;                  // Enable PIC
    uint8_t laa_3_0;            // Latched Address A (4-bit)
    bool mclk;                  // Master Clock
    
    // Status and outputs
    bool epicmask_n;            // EPIC Mask (negated)
    bool intrq_n;               // Interrupt Request (negated)
    bool ioni;                  // I/O Non-maskable Interrupt
    uint16_t picmask_15_0;      // PIC Mask Register
    uint8_t pil_3_0;            // Processor Interrupt Level
    uint8_t pics_2_0;           // PIC Select
    uint8_t picv_2_0;           // PIC Vector
} InterruptController;
```

### 2.6 Trap Handler (TRAP)

```c
typedef struct {
    // Trap condition inputs
    bool cbrk_n;                // Break signal (negated)
    bool dstop_n;               // Stop Debug (negated)
    bool etrap_n;               // Enable Trap (negated)
    bool fetch_n;               // Fetch (negated)
    bool ftrap_n;               // Fetch Trap (negated)
    bool ind_n;                 // Indirect (negated)
    bool intrq_n;               // Interrupt Request (negated)
    bool pan_n;                 // Panel (negated)
    bool vacc_n;                // VAC (negated)
    bool write_n;               // Write (negated)
    
    // CPU state inputs
    uint8_t pcr_1_0;            // Processor Control Register (2-bit)
    bool poni;                  // Memory Protection ON
    uint8_t pt_15_9;            // Page Table bits
    
    // Clock and control
    bool tclk;                  // Trap Clock
    
    // Outputs
    bool brk_n;                 // Break (negated)
    bool pviol;                 // Protection Violation
    bool restr;                 // Restart
    bool trap_n;                // Trap (negated)
    uint8_t tvec_3_0;           // Trap Vector (4-bit)
} TrapHandler;
```

## 3. CPU Execution Cycle

In C, the CPU execution cycle should be implemented as:

```c
void cpu_initialize(CPU *cpu) {
    // Set initial state for all components
    // Initialize registers, buses, and flags
    // Load initial microcode
}

void cpu_cycle(CPU *cpu) {
    // 1. Fetch microinstruction
    fetch_microinstruction(cpu);
    
    // 2. Check for traps and interrupts
    check_traps_and_interrupts(cpu);
    
    // 3. Execute ALU operations
    execute_alu_operations(cpu);
    
    // 4. Handle memory access
    perform_memory_access(cpu);
    
    // 5. Update CPU state
    update_cpu_state(cpu);
    
    // 6. Determine next microinstruction address
    calculate_next_address(cpu);
}

void cpu_run(CPU *cpu, int cycles) {
    cpu_initialize(cpu);
    
    for (int i = 0; i < cycles; i++) {
        cpu_cycle(cpu);
    }
}
```

### 3.1 Detailed CPU Cycle Implementation

The CPU cycle in the ND-120 architecture represents a series of coordinated actions controlled by clock signals and the cycle controller. The hardware implementation uses a cycle sequencer with multiple clock phases (CC0-CC3), but in our C implementation, we can model these operations as discrete function calls.

#### 3.1.1 Fetch Microinstruction Phase

```c
void fetch_microinstruction(CPU *cpu) {
    // This function retrieves the next microinstruction from the control store
    
    // 1. Determine address source
    // The microinstruction address can come from several sources:
    // - The incremented program counter (normal sequential execution)
    // - A jump target address (from a branch instruction)
    // - A trap vector address (when a trap/interrupt occurs)
    // - A return address from the stack (after a subroutine call)
    
    uint16_t address;
    if (cpu->trap.trap_n == 0) {
        // Trap handling - use trap vector address
        address = 0x1000 | (cpu->trap.tvec_3_0 << 4);  // Base trap address + vector
    } else if (cpu->mic.map_n == 0) {
        // MAP (Memory Address Present) - instruction fetch from memory
        // This is used during instruction fetch to map machine code to microcode
        // Use the IDB (Instruction Data Bus) to provide upper bits and predefined
        // pattern for lower bits to form the address
        uint16_t opcode = cpu->dcd.idb_15_0 & 0xFF00;  // Upper 8 bits of instruction
        address = 0x0800 | ((opcode >> 8) << 2);       // Form address from opcode
    } else {
        // Normal execution - use address from CSA (Control Store Address)
        address = cpu->mic.ma_12_0;
    }
    
    // 2. Access control store
    // Check microinstruction cache first
    bool cache_hit = false;
    if (address < 0x400) {  // If address in cache range
        uint16_t cache_addr = address & 0x3FF;  // 10-bit cache address
        
        // Check if cached address matches requested address
        if (cpu->mic.mca_9_0 == cache_addr) {
            // Cache hit - use cached instruction
            cache_hit = true;
            cpu->current_instr = microcode_cache_read(cpu, cache_addr);
        }
    }
    
    // If cache miss, read from control store
    if (!cache_hit) {
        cpu->current_instr = microcode_store_read(cpu, address);
        
        // Update cache if address is cacheable
        if (address < 0x400) {
            uint16_t cache_addr = address & 0x3FF;
            cpu->mic.mca_9_0 = cache_addr;
            microcode_cache_write(cpu, cache_addr, cpu->current_instr);
        }
    }
    
    // 3. Decode control fields from the instruction
    decode_microinstruction(cpu);
}
```

#### 3.1.2 Check for Traps and Interrupts

```c
void check_traps_and_interrupts(CPU *cpu) {
    // This function checks for traps and interrupts that might need handling
    
    // Skip if traps are disabled (during VEX - Vector Exception)
    if (cpu->trap.etrap_n == 0) {
        return;
    }
    
    // Check sources of trap conditions
    bool trap_condition = false;
    
    // 1. Check for break conditions (debugging)
    if (cpu->trap.cbrk_n == 0) {
        trap_condition = true;
        cpu->trap.tvec_3_0 = 0x1;  // Break vector
    }
    
    // 2. Check for interrupts if enabled
    else if (cpu->intr.intrq_n == 0 && cpu->alu.sts.i == 0) {
        trap_condition = true;
        cpu->trap.tvec_3_0 = cpu->intr.picv_2_0 | 0x8;  // Interrupt vector
    }
    
    // 3. Check for memory protection violation
    else if (cpu->trap.poni && cpu->trap.pviol) {
        trap_condition = true;
        cpu->trap.tvec_3_0 = 0x3;  // Protection violation vector
    }
    
    // 4. Check for page fault (PAN - Page Address Not valid)
    else if (cpu->trap.pan_n == 0) {
        trap_condition = true;
        cpu->trap.tvec_3_0 = 0x5;  // Page fault vector
    }
    
    // 5. Special fetch-related traps
    else if (cpu->dcd.fetch == 1 && cpu->trap.ftrap_n == 0) {
        trap_condition = true;
        cpu->trap.tvec_3_0 = 0x7;  // Fetch trap vector
    }
    
    // Set the trap signal if a condition was detected
    cpu->trap.trap_n = !trap_condition;
}
```

#### 3.1.3 Execute ALU Operations

```c
void execute_alu_operations(CPU *cpu) {
    // This function handles all ALU operations based on the current microinstruction
    
    // 1. Select operands based on register selectors (CSRASEL, CSRBSEL)
    uint16_t a_operand = 0;
    uint16_t b_operand = 0;
    
    // Select A operand based on CSRASEL (Register A Select)
    switch (cpu->current_instr.csrasel_1_0) {
        case 0:  // A register
            a_operand = cpu->alu.a_reg;
            break;
        case 1:  // Command/Data bus
            a_operand = cpu->cd_bus[0];
            break;
        case 2:  // FIDB input
            a_operand = cpu->fidb_bus_in[0];
            break;
        case 3:  // General purpose register selected by LAA
            a_operand = cpu->registers[cpu->mac.laa_3_0];
            break;
    }
    
    // Select B operand based on CSRBSEL (Register B Select)
    switch (cpu->current_instr.csrbsel_1_0) {
        case 0:  // B register
            b_operand = cpu->alu.b_reg;
            break;
        case 1:  // Q register
            b_operand = cpu->alu.q_reg;
            break;
        case 2:  // Constant from CSBIT[15:0]
            b_operand = cpu->current_instr.csbit_15_0;
            break;
        case 3:  // General purpose register selected by LBA
            b_operand = cpu->registers[cpu->mac.lba_3_0];
            break;
    }
    
    // 2. Determine carry input based on CSCINSEL
    bool carry_in = false;
    switch (cpu->current_instr.cscinsel_1_0) {
        case 0:  // No carry
            carry_in = false;
            break;
        case 1:  // Carry flag
            carry_in = cpu->alu.sts.c;
            break;
        case 2:  // Always 1
            carry_in = true;
            break;
        case 3:  // Complemented carry flag
            carry_in = !cpu->alu.sts.c;
            break;
    }
    
    // 3. Execute the ALU operation based on CSALUM (mode) and CSALUI (operation)
    uint16_t result = 0;
    bool carry_out = false;
    bool overflow = false;
    bool zero = false;
    bool sign = false;
    
    // Process based on ALU mode
    switch (cpu->current_instr.csalum_1_0) {
        case 0:  // Regular ALU operations (add, subtract, etc.)
            execute_regular_alu(cpu, a_operand, b_operand, carry_in,
                               &result, &carry_out, &overflow, &sign, &zero);
            break;
            
        case 1:  // Shift operations
            execute_shift_operation(cpu, a_operand,
                                   &result, &carry_out, &sign, &zero);
            break;
            
        case 2:  // Logic operations (AND, OR, XOR, etc.)
            execute_logic_operation(cpu, a_operand, b_operand,
                                   &result, &zero, &sign);
            carry_out = cpu->alu.sts.c;  // Logic ops preserve carry
            overflow = cpu->alu.sts.v;   // Logic ops preserve overflow
            break;
            
        case 3:  // Special operations
            execute_special_operation(cpu, a_operand, b_operand,
                                     &result, &carry_out, &overflow, &sign, &zero);
            break;
    }
    
    // 4. Update destination register if BDEST is set
    if (cpu->alu.bdest) {
        // Determine destination based on LBA_3_0
        uint8_t reg_index = cpu->mac.lba_3_0 & 0x0F;
        cpu->registers[reg_index] = result;
    }
    
    // 5. Update ALU internal registers
    cpu->alu.p_reg = result;
    
    // 6. Update status flags if LCZN (Load CZN flags) is set
    if (cpu->alu.sts.lczn) {
        cpu->alu.sts.c = carry_out;
        cpu->alu.sts.z = zero;
        cpu->alu.sts.n = sign;
        cpu->alu.sts.v = overflow;
    }
    
    // 7. Update ACOND_n (ALU condition, negated) for conditional execution
    // The condition code is in CSALUI bits [3:0]
    uint8_t condition_code = cpu->current_instr.csalui_8_0 & 0x0F;
    cpu->acond_n = !test_condition(condition_code, &cpu->alu.sts);
}
```

#### 3.1.4 Handle Memory Access

```c
void perform_memory_access(CPU *cpu) {
    // This function handles memory access operations based on microcode control bits
    
    // Process the memory operation based on CSCOMM (command field)
    uint8_t command = cpu->current_instr.cscomm_4_0;
    
    // For memory operations, determine if we're reading or writing
    bool is_write = (cpu->current_instr.csbit_15_0 & 0x0200) != 0;  // Check WRITE bit
    bool is_fetch = (cpu->current_instr.csbit_15_0 & 0x0400) != 0;  // Check FETCH bit
    
    // Skip if not a memory access command
    if ((command < 0x10 || command > 0x14) && !is_fetch) {
        return;  // Not a memory access command
    }
    
    // Calculate physical address for memory access
    uint32_t physical_address = calculate_physical_address(cpu);
    
    if (is_fetch) {
        // Handle instruction fetch from memory
        uint16_t fetched_data = memory_read(cpu, physical_address);
        cpu->cd_bus[0] = fetched_data;
        cpu->dcd.idb_15_0 = fetched_data;  // Load to IDB for instruction decode
    } else if (!is_write) {
        // Regular memory read operation
        uint16_t read_data = memory_read(cpu, physical_address);
        
        // Determine destination for read data (typically CD bus)
        cpu->cd_bus[0] = read_data;
    } else {
        // Memory write operation - data source is typically B register
        uint16_t write_data = cpu->alu.b_reg;
        memory_write(cpu, physical_address, write_data);
    }
}
```

#### 3.1.5 Update CPU State

```c
void update_cpu_state(CPU *cpu) {
    // This function updates miscellaneous CPU state at the end of the cycle
    
    // 1. Update I/O devices and peripherals
    update_io_devices(cpu);
    
    // 2. Update timer and real-time counters
    update_timers(cpu);
    
    // 3. Process special status register updates
    if ((cpu->current_instr.cscomm_4_0 & 0x18) == 0x18) {  // Status register operation
        update_status_registers(cpu);
    }
    
    // 4. Process Q register updates if required
    if (cpu->alu.qli) {  // Q Load Indicator
        update_q_register(cpu);
    }
    
    // 5. Process special mode flags
    update_mode_flags(cpu);
}
```

#### 3.1.6 Calculate Next Microinstruction Address

```c
void calculate_next_address(CPU *cpu) {
    // This function determines the next microinstruction address
    
    // Default is to increment the current address
    uint16_t next_address = cpu->mic.ma_12_0 + 1;
    
    // Check for jump/branch operations based on CSCOMM field
    uint8_t command = cpu->current_instr.cscomm_4_0;
    
    // Process conditional execution
    bool condition_met = true;
    if (cpu->current_instr.csecond) {  // If condition checking is enabled
        if (cpu->current_instr.csscond) {  // If condition is based on ACOND
            condition_met = (cpu->acond_n == 0);  // ACOND_n is active low
        }
    }
    
    if (condition_met) {
        // Handle different branch types
        switch (command) {
            case 0x1C:  // Jump - unconditional branch
                next_address = cpu->current_instr.csbit_15_0 & 0x1FFF;  // 13-bit address
                break;
                
            case 0x1D:  // Call - push return address and jump
                // Push current address + 1 onto stack
                cpu->mic.stack[cpu->mic.stack_ptr++ & 0x03] = next_address;
                // Jump to target address
                next_address = cpu->current_instr.csbit_15_0 & 0x1FFF;
                break;
                
            case 0x1E:  // Return - pop address from stack
                next_address = cpu->mic.stack[--cpu->mic.stack_ptr & 0x03];
                break;
                
            case 0x1B:  // Conditional Jump
                if (condition_met) {
                    next_address = cpu->current_instr.csbit_15_0 & 0x1FFF;
                }
                break;
        }
    }
    
    // Handle special case for trap conditions
    if (cpu->trap.trap_n == 0) {
        // Trap vector becomes next address, saving current address
        cpu->mic.stack[cpu->mic.stack_ptr++ & 0x03] = next_address;
        next_address = 0x1000 | (cpu->trap.tvec_3_0 << 4);  // Base address + vector offset
    }
    
    // Update microinstruction address for next cycle
    cpu->mic.ma_12_0 = next_address;
}
```

### 3.2 Clock and Timing Considerations

In the hardware implementation, the CPU cycle is controlled by a series of clock signals and cycle control bits (CC0-CC3). These control the precise timing of operations like memory access, ALU execution, and register updates.

In our C implementation, we abstract away the explicit clock signals and instead model the CPU cycle as a sequence of function calls. Each function represents a phase of the CPU cycle that would occur during specific clock phases in the hardware.

The original hardware uses the following major timing signals:
- **TERM** - Terminate signal that marks the end of a cycle
- **CC0-CC3** - Cycle control bits that sequence operations within a cycle
- **MCLK** - Main clock signal for controlling register updates
- **WRFSTB** - Write register file strobe for updating registers
- **MACLK** - Memory address clock for latching addresses
- **UCLK** - Microcode clock for controlling microinstruction sequences

Our software model replaces these hardware timing signals with sequential function calls that model the same behavior.

### 3.3 Integration with Hardware Signals

When implementing the CPU model, it's important to understand how key hardware signals map to software operations:

| Hardware Signal | Description | Software Implementation |
|----------------|-------------|-------------------------|
| ALUCLK | ALU Clock | Triggers ALU operations in `execute_alu_operations()` |
| WRFSTB | Write Register File Strobe | Register updates in `execute_alu_operations()` |
| BDEST | Bus Destination Flag | Controls register write operations |
| TRAP_n | Trap signal (active low) | Checked in `check_traps_and_interrupts()` |
| ETRAP_n | Enable Trap (active low) | Controls whether traps are processed |
| MAP_n | Memory Address Present | Controls instruction fetching in `fetch_microinstruction()` |
| TERM_n | Terminate signal (active low) | Marks the end of cycle in hardware (implicit in our model) |

### 3.4 Interrupt Subsystem Implementation

The ND-120 CPU features a sophisticated interrupt handling subsystem (INTR) that manages multiple interrupt sources and prioritizes them according to predefined rules. This section describes how to implement this subsystem in the C emulation.

#### 3.4.1 Interrupt Controller Structure

```c
void initialize_interrupt_controller(InterruptController *intr) {
    // Reset all interrupt inputs to inactive state
    intr->bint10_n = intr->bint11_n = intr->bint12_n = intr->bint13_n = intr->bint15_n = true;
    intr->ioxerr_n = intr->mor_n = intr->pan_n = intr->parerr_n = intr->powfail_n = true;
    
    // Set control signals to default states
    intr->clirq_n = true;       // No clear interrupt request
    intr->empid_n = true;       // Interrupts not disabled
    intr->epic = false;         // PIC not enabled
    intr->laa_3_0 = 0;          // Default LAA value
    
    // Reset outputs
    intr->epicmask_n = true;    // EPIC mask inactive
    intr->intrq_n = true;       // No interrupt request
    intr->ioni = false;         // I/O non-maskable interrupt inactive
    intr->picmask_15_0 = 0xFFFF; // All interrupts masked by default
    intr->pil_3_0 = 0;          // Priority level 0
    intr->pics_2_0 = 0;         // No PIC selected
    intr->picv_2_0 = 0;         // No vector selected
}
```

#### 3.4.2 Interrupt Sources

The ND-120 CPU handles several types of interrupt sources, each with different priority levels:

1. **Bus Interrupts (BINT10-BINT15)** - External device interrupts coming from the system bus
2. **I/O Exception Error (IOXERR)** - Error during I/O operations
3. **Memory Error (MOR)** - Memory operation failures
4. **Panel Interrupt (PAN)** - Front panel control interrupts
5. **Parity Error (PARERR)** - Memory parity check failures
6. **Power Failure (POWFAIL)** - System power failure notification

#### 3.4.3 Interrupt Processing Logic

```c
void process_interrupts(CPU *cpu) {
    InterruptController *intr = &cpu->intr;
    bool interrupt_detected = false;
    uint8_t vector = 0;
    uint8_t priority = 0;
    
    // Non-maskable interrupts (always processed)
    if (!intr->powfail_n) {
        interrupt_detected = true;
        vector = 0x7;          // Power fail vector
        priority = 15;         // Highest priority
    }
    else if (!intr->mor_n) {
        interrupt_detected = true;
        vector = 0x6;          // Memory error vector
        priority = 14;
    }
    else if (!intr->parerr_n) {
        interrupt_detected = true;
        vector = 0x5;          // Parity error vector
        priority = 13;
    }
    
    // Maskable interrupts (processed only if not masked)
    else if (intr->epic && !intr->epicmask_n) {
        // Bus interrupts processing - check each in priority order
        if (!intr->bint15_n && !(intr->picmask_15_0 & (1 << 15))) {
            interrupt_detected = true;
            vector = 0x7;      // BINT15 vector
            priority = 12;
            intr->pics_2_0 = 0x7; // PIC Select for BINT15
        }
        else if (!intr->bint13_n && !(intr->picmask_15_0 & (1 << 13))) {
            interrupt_detected = true;
            vector = 0x6;      // BINT13 vector
            priority = 11;
            intr->pics_2_0 = 0x6; // PIC Select for BINT13
        }
        else if (!intr->bint12_n && !(intr->picmask_15_0 & (1 << 12))) {
            interrupt_detected = true;
            vector = 0x5;      // BINT12 vector
            priority = 10;
            intr->pics_2_0 = 0x5; // PIC Select for BINT12
        }
        else if (!intr->bint11_n && !(intr->picmask_15_0 & (1 << 11))) {
            interrupt_detected = true;
            vector = 0x4;      // BINT11 vector
            priority = 9;
            intr->pics_2_0 = 0x4; // PIC Select for BINT11
        }
        else if (!intr->bint10_n && !(intr->picmask_15_0 & (1 << 10))) {
            interrupt_detected = true;
            vector = 0x3;      // BINT10 vector
            priority = 8;
            intr->pics_2_0 = 0x3; // PIC Select for BINT10
        }
        
        // I/O Exception
        else if (!intr->ioxerr_n && !(intr->picmask_15_0 & (1 << 4))) {
            interrupt_detected = true;
            vector = 0x2;      // IOXERR vector
            priority = 7;
            intr->pics_2_0 = 0x2; // PIC Select for IOXERR
        }
        
        // Panel interrupt
        else if (!intr->pan_n && !(intr->picmask_15_0 & (1 << 3))) {
            interrupt_detected = true;
            vector = 0x1;      // PAN vector
            priority = 6;
            intr->pics_2_0 = 0x1; // PIC Select for PAN
        }
    }
    
    // Check if the detected interrupt has higher priority than current level
    if (interrupt_detected && priority > intr->pil_3_0) {
        // Set interrupt request flag
        intr->intrq_n = false;
        
        // Set the PIC vector for trap handler
        intr->picv_2_0 = vector & 0x7;
        
        // If this is a non-maskable interrupt, set IONI flag
        if (priority >= 13) {
            intr->ioni = true;
        }
    } else {
        intr->intrq_n = true;
    }
    
    // Handle interrupt clear request
    if (!intr->clirq_n) {
        intr->intrq_n = true;
        intr->ioni = false;
    }
}
```

#### 3.4.4 PIC Mask Management

The Programmable Interrupt Controller (PIC) mask controls which interrupts are enabled. The mask is stored in the `picmask_15_0` register, where a set bit (1) means the corresponding interrupt is masked (disabled). When a bit is clear (0), the interrupt is enabled.

```c
void update_pic_mask(InterruptController *intr, uint16_t value, uint8_t laa) {
    // Only update if EPIC command is active and LAA selects the PIC mask register
    if (intr->epic && laa == 0x8) {
        intr->picmask_15_0 = value;
    }
}
```

#### 3.4.5 Interrupt Identification

When an interrupt is acknowledged, the system needs to identify which device caused the interrupt. This is done using the IDENT command which returns a device-specific identification code.

```c
uint16_t identify_interrupt_source(CPU *cpu, uint8_t level) {
    // In a real system, this would query devices to find which one triggered the interrupt
    // For our emulation, we can track interrupt sources and return appropriate values
    
    uint16_t ident_code = 0;
    
    // Check which device might have raised the interrupt at this level
    switch (level) {
        case 10:
            // Check devices that can trigger BINT10
            // Example: floppy drive controller, terminal, etc.
            ident_code = cpu->devices.interrupting_device_at_level(level);
            break;
            
        case 11:
            // Check devices that can trigger BINT11
            ident_code = cpu->devices.interrupting_device_at_level(level);
            break;
            
        // Other levels...
    }
    
    // Clear the interrupt now that it's been identified
    cpu->intr.clirq_n = false;
    process_interrupts(cpu);
    cpu->intr.clirq_n = true;
    
    return ident_code;
}
```

#### 3.4.6 Programming the Interrupt Subsystem with EPIC

The ND-120 uses the EPIC (Enable Priority Interrupt Controller) command to program and control the interrupt subsystem. This is a powerful command that allows software to configure how interrupts are handled.

```c
void process_epic_command(CPU *cpu, uint8_t command, uint16_t a_operand) {
    InterruptController *intr = &cpu->intr;
    
    // Enable EPIC processing mode
    intr->epic = true;
    
    // Process the command based on the A-operand value
    switch (command) {
        case 0:  // MCLR - Clear registers and enable interrupts
            intr->picmask_15_0 = 0;  // Clear mask (enable all interrupts)
            intr->pil_3_0 = 0;       // Reset priority level
            intr->epicmask_n = false; // Enable interrupt processing
            break;
            
        case 1:  // CLRMPID - Clear all interrupts
            // Reset all interrupt request flags
            intr->intrq_n = true;
            intr->clirq_n = false;  // Pulse clear IRQ signal
            // Small delay would occur here in hardware
            intr->clirq_n = true;
            break;
            
        case 2:  // MCLRMPID - Clear interrupts from M-bus
            // Clear bus interrupts (10-15)
            clear_external_interrupts(cpu);
            break;
            
        case 3:  // ECLRMPID - Clear interrupts from Mask register
            // Clear interrupts that are enabled in the mask register
            clear_masked_interrupts(cpu, intr->picmask_15_0);
            break;
            
        case 4:  // LCLRMPID - Clear interrupt for last vector read
            // Clear the interrupt that corresponds to the last vector processed
            clear_interrupt_by_vector(cpu, intr->picv_2_0);
            break;
            
        case 5:  // RDVECT - Read vector
            // Read the current interrupt vector into A register
            cpu->alu.a_reg = intr->picv_2_0;
            break;
            
        case 6:  // RDSTAT - Read status register
            // Compose status register from various interrupt flags
            cpu->alu.a_reg = compose_interrupt_status(intr);
            break;
            
        case 7:  // RDMPIE - Read mask register
            // Read the current interrupt mask into A register
            cpu->alu.a_reg = intr->picmask_15_0;
            break;
            
        case 10: // LDMPIE - Set mask register: inhibit all interrupts
            // Set all bits in mask register (mask all interrupts)
            intr->picmask_15_0 = 0xFFFF;
            break;
            
        case 11: // LDSTAT - Load status
            // Update status from A operand
            update_interrupt_status(intr, a_operand);
            break;
            
        case 12: // MCLRMPIE - Bit clear mask register
            // Clear specific bits in mask (enable those interrupts)
            intr->picmask_15_0 &= ~a_operand;
            break;
            
        case 13: // MSETMPIE - Bit set mask register
            // Set specific bits in mask (disable those interrupts)
            intr->picmask_15_0 |= a_operand;
            break;
            
        case 14: // CLRMPIE - Clear mask register: enable all interrupts
            // Clear all bits in mask (enable all interrupts)
            intr->picmask_15_0 = 0;
            break;
            
        case 15: // DISINTRQ - Disable interrupt request
            // Disable interrupt request generation
            intr->epicmask_n = true;
            break;
            
        case 16: // LDMPIE - Load mask register
            // Load mask register from A operand
            intr->picmask_15_0 = a_operand;
            break;
            
        case 17: // ENINTRQ - Enable interrupt request
            // Enable interrupt request generation
            intr->epicmask_n = false;
            break;
    }
    
    // Once command is executed, disable EPIC mode
    intr->epic = false;
}

// Helper function to compose interrupt status register
uint16_t compose_interrupt_status(InterruptController *intr) {
    uint16_t status = 0;
    
    // Bits 0-2: Current PIC vector
    status |= intr->picv_2_0;
    
    // Bits 3-5: Current PIC select
    status |= (intr->pics_2_0 << 3);
    
    // Bits 8-11: Current priority level
    status |= (intr->pil_3_0 << 8);
    
    // Bit 15: Interrupt request active
    status |= (!intr->intrq_n << 15);
    
    return status;
}

// Helper function to update interrupt status from A operand
void update_interrupt_status(InterruptController *intr, uint16_t status) {
    // Extract PIL (Priority Interrupt Level) from bits 8-11
    intr->pil_3_0 = (status >> 8) & 0x0F;
    
    // Other status bits might be updated based on architecture specifics
}
```

##### UART Commands (Command 5)

The UART interface is controlled through Command 5, with the MIS field (bits 1:0) selecting different UART registers:

| COMM (Octal) | MIS (Octal) | Command    | Description                           |
|-------------|------------|------------|---------------------------------------|
| 5           | 0          | UART DATA  | Read/write UART data register         |
| 5           | 1          | UART STAT  | Read/write UART status register       |
| 5           | 2          | UART MODE  | Set UART mode register                |
| 5           | 3          | UART COMM  | Configure UART command register       |

- **UART DATA (5.0)**: Access the UART data register for transmitting and receiving bytes
- **UART STAT (5.1)**: Access the status register containing flags like TX ready, RX ready, etc.
- **UART MODE (5.2)**: Configure UART parameters (baud rate, parity, data bits, stop bits)
- **UART COMM (5.3)**: Configure UART operations (enable/disable TX/RX, etc.)
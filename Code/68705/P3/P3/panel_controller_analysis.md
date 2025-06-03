# Panel Controller Firmware Analysis - Complete Memory Dump

## Overview

**Target System**: Norsk Data ND-100/ND-120 minicomputer operator panel
**Panel Processor**: Motorola 68705P3 8-bit microcontroller
**ROM Size**: 2KB (0000-07FF)
**Primary Function**: Operator panel control, display management, and CPU interface for ND-100/ND-120 system

The 68705P3 serves as an intelligent panel processor that manages the operator interface for the ND-100/ND-120 minicomputer system, handling display updates, button input processing, real-time clock management, and bidirectional communication with the main CPU.

## Hardware Architecture

### **CPU Interface Registers**
- **PANC (Panel Control)**: Write-only register for CPU→Panel commands
- **PANS (Panel Status)**: Read-only register for Panel→CPU status/data
  - Upper bits (8-15): Panel processor status information
  - Lower bits (0-7): Data response from panel processor
- **FIFO Buffer**: CY7C401 (512 x 9-bit) buffers commands from CPU microprogram
- **Communication Timing**: 20ms interrupt cycle from ND-120 CPU

### **68705P3 Port Assignments**
- **PORTA (0x0000)**: Input port for button states and external signals
- **PORTB (0x0001)**: Output port for display control and external hardware
- **PORTC (0x0002)**: Output port for additional display/communication control
- **DDRA (0x0004)**: Data Direction Register A (configured as input: 0x00)
- **DDRB (0x0005)**: Data Direction Register B (configured as output: 0xFF)
- **DDRC (0x0006)**: Data Direction Register C (configured as output: 0xFF)
- **Timer_Data_Reg (0x0008)**: Timer data register for timing control
- **Timer_Control_Reg (0x0009)**: Timer control register (observed value: 0x78)

### **Display Hardware Components**
- **HD44100H LCD Driver**: 40-channel LCD driver with serial/parallel conversion
- **CD4035BE Shift Registers**: 16+ cascaded 4-bit shift registers (RCA H 423)
- **LD-H7919 LCD Modules**: 8-digit alphanumeric LCD displays (Epson)
- **LCD SX 423 M4**: 16-segment displays for function indicators
- **Display Organization**:
  - Function section: UTIL, HIT, RING, MODE indicators
  - Address section: 8 digits in XX:XX:XX:XX format (DAY:HR:MIN:SEC)
  - Data section: 8 digits for hexadecimal data display

### **Control Panel Hardware**
- **Push Buttons**: MCL, STOP, LOAD, OPCOM, CONTINUE
- **Key Lock**: 3-position switch (LOCK, ON, STAND-BY)
- **Status Indicators**: POWER ON, RUN, OPCOM LEDs
- **Button Signal Lines**:
  - LOAD_n: C-B12, A-C15
  - CONTINUE_n: C-B15
  - STOP_n: C-B16, A-C17

## Known Firmware Routines

### **Main Functions**
- **RESET (0x00D6)**: System initialization and main loop entry
- **ProcessData (0x0142)**: Main command processing state machine
- **WaitForData (0x025E)**: FIFO polling and data acquisition
- **FUN_011F (0x011F)**: *Function purpose unknown*
- **FUN_01C0 (0x01C0)**: *Function purpose unknown*

### **Display Control Functions**
- **FUN_0690 (0x0690)**: Character positioning and display addressing
- **FUN_05FC (0x05FC)**: Display control strobing and timing
- **FUN_05D2 (0x05D2)**: Character output to display segments
- **FUN_023C (0x023C)**: *Display-related function*
- **FUN_0238 (0x0238)**: *Display-related function*

### **Clock/Timer Functions**
- **FUN_0618 (0x0618)**: *Timer/clock related*
- **FUN_0641 (0x0641)**: *Clock processing function*
- **FUN_041D (0x041D)**: *Clock-related function*
- **FUN_057C (0x057C)**: *Timing function*
- **FUN_0597 (0x0597)**: *Timer function*

### **Hardware Interface Functions**
- **FUN_05C8 (0x05C8)**: *Hardware interface*
- **FUN_060C (0x060C)**: *Interface function*
- **FUN_0623 (0x0623)**: *Hardware control*
- **FUN_06B0 (0x06B0)**: *Interface function*

### **Command Processing Functions**
- **caseD_10 (0x01B7)**: Command case handler
- **caseD_2a (0x01D1)**: Command case handler
- **caseD_34 (0x01DB)**: Command case handler
- **caseD_46 (0x01ED)**: Command case handler
- **caseD_56 (0x01FD)**: Command case handler
- **caseD_5a (0x0201)**: Command case handler
- **caseD_5e (0x0205)**: Command case handler
- **caseD_6c (0x0213)**: Command case handler
- **caseD_a4 (0x024B)**: Command case handler

## Observed Command Structure

### **PANC Command Format** (CPU → Panel)
```
Bits 15-11: Not used (must be zero)
Bits 10-8:  Command type (000-111)
Bits 7-0:   Data from CPU to panel
```

### **Command Types** (Bits 10-8)
- **000**: Illegal command
- **001**: Reserved
- **010**: Message value (Write only)
- **011**: Message control (Write only)
- **100**: Clock Low Seconds (Read/Write)
- **101**: Clock High Seconds (Read/Write)
- **110**: Clock Low Days (Read/Write)
- **111**: Clock High Days (Read/Write)

### **Message Control Commands** (Command 011)
- **000**: Stop rotating message
- **001**: Return display to normal function
- **010**: Clear text buffer and function display
- **100**: Rotate message in text buffer (4 chars at a time)
- **110**: Clear text and start rotation (010 + 100)

### **PANS Status Format** (Panel → CPU)
```
Bit 15: PAN (Panel installed)
Bit 14: FIF (FIFO ready for data)
Bit 13: DAT (Last command requested data)
Bit 12: RDY (Last command completed)
Bits 11-8: Last command processed
Bits 7-0: Data requested by last command
```

## Memory Organization

### **RAM Layout Observations**
- **0x0010-0x0018**: Display buffer area (character/segment data)
- **0x0014-0x0018**: Parameter storage area
- **0x0019-0x001F**: System status and operational flags
- **0x0020-0x0046**: Working buffers and temporary processing
- **0x0025-0x0028**: *Working assumption: command parameter storage*
- **0x0029-0x002C**: *Working assumption: display character buffer*
- **0x002D-0x003E**: *Working assumption: time/date data storage*
- **0x0047-0x0049**: *Working assumption: display control variables*

### **String Constants** (ROM 0x0098-0x00D5)
```
"ON" "OFF" "DAY:" "TIME:" "UTC:" "ADDRESS:" "COUNT:" "YEAR:" "MONTH:"
```

### **Data Tables**
- **0x0080**: Value 0x01 (lookup table entry)
- **0x008B**: Value 0x01 (lookup table entry)
- **0x008C**: Value 0x01 (lookup table entry)
- **0x008D**: Value 0x02 (lookup table entry)

## System Integration

### **Interrupt System**
- **20ms Timer Interrupt**: ND-120 CPU receives regular timer interrupts
- **Panel Interrupt Generation**: 68705P3 signals CPU when buttons pressed
- **FIFO Status Monitoring**: Continuous polling of CY7C401 FIFO status
- **Button Debouncing**: Implemented in firmware for reliable input

### **Communication Flow**
1. **CPU → FIFO → Panel**: Commands buffered through CY7C401
2. **Panel → CPU**: Status and data via PANS register
3. **Microprogram Stream**: 20ms command updates from CPU microprogram
4. **Button Events**: Interrupt-driven communication to CPU

### **Display Update Cycle**
1. **Serial Data Transmission**: 68705P3 → CD4035 shift register chain
2. **Parallel Latch**: Simultaneous update of all display segments
3. **LCD Drive**: HD44100H provides segment drive signals
4. **Multi-Zone Refresh**: Coordinated updates across all display areas

## Working Assumptions

### **Display Control Assumptions**
- *Assumption*: `FUN_0690()` calculates character positions within display memory
- *Assumption*: `FUN_05FC()` provides clock/strobe signals for CD4035 registers
- *Assumption*: `FUN_05D2()` outputs character bitmap data for segment displays
- *Assumption*: Display updates require precise timing due to LCD multiplexing

### **Command Processing Assumptions**
- *Assumption*: `ProcessData()` switch statement handles 8 command types (bits 2-0 of command)
- *Assumption*: Command bit 3 indicates data direction (input vs output)
- *Assumption*: Complex case handlers manage multi-byte command sequences
- *Assumption*: Some commands require parameter bytes following initial command

### **Timer and Clock Assumptions**
- *Assumption*: Internal timer used for display refresh timing
- *Assumption*: Real-time clock backup via external RTC chip
- *Assumption*: Calendar/clock display updates coordinated with CPU requests
- *Assumption*: Timer configuration (0x78) sets specific prescaler for timing

### **Memory Usage Assumptions**
- *Assumption*: Display buffers store character codes for each display zone
- *Assumption*: Status area contains flags for operational state management
- *Assumption*: Working buffers used for serial data preparation
- *Assumption*: Parameter storage for multi-byte command processing

## Display Content Management

### **Function Displays** (16-segment)
- **UTIL**: CPU utilization indicators (8 segments)
- **HIT**: Cache hit rate indicators (8 segments)
- **RING**: Memory protection ring status (4 levels: 0-3)
- **MODE**: System operating mode indicators

### **Time/Date Display** (8-digit alphanumeric)
- **Format**: XX:XX:XX:XX (DAY:HR:MIN:SEC)
- **Real-time Updates**: Continuous clock display
- **Calendar Functions**: Date/time setting via CPU commands

### **Data Display** (8-digit hexadecimal)
- **Address Display**: Memory addresses, register contents
- **System Status**: Various 16-bit status values
- **Bit Position Markers**: Visual indicators for bit positions (15-0)

## Button Processing

### **Button Types and Functions**
- **MCL (Master Clear)**: Forces system initialization, clears displays
- **STOP**: Halts CPU operation, enters stop mode
- **LOAD**: Loads operating system, controlled by ALD switch
- **OPCOM**: Activates operator communication mode
- **CONTINUE**: Resumes operation from stop state

### **Panel Lock Key States**
- **LOCK**: Panel buttons disabled, normal operation mode
- **ON**: Panel buttons active, full functionality
- **STAND-BY**: Main power disabled, standby mode only

### **Button Signal Processing**
- *Assumption*: Button states read via PORTA input scanning
- *Assumption*: Debouncing implemented in software
- *Assumption*: Button events generate interrupts to CPU
- *Assumption*: Service mode requires specific button combinations

## Unresolved Areas and Questions

### **Firmware Analysis Gaps**
- **Unknown Function Purposes**: Many FUN_xxxx functions need analysis
- **Command Parameter Structure**: Multi-byte command formats unclear
- **Display Multiplexing Details**: Exact timing requirements unknown
- **RTC Interface Protocol**: External clock chip communication unclear

### **Hardware Interface Questions**
- **Exact Pin Assignments**: Specific 68705P3 pin usage not fully mapped
- **LCD Drive Timing**: Refresh rates and timing constraints unknown
- **FIFO Interface Details**: Handshaking protocol with CY7C401 unclear
- **Power Management**: Standby mode operation details unknown

### **System Integration Questions**
- **Microprogram Command Set**: Full command repertoire from CPU unknown
- **Error Handling**: Fault detection and recovery mechanisms unclear
- **Diagnostic Features**: Built-in test capabilities unknown
- **Version Differences**: Variations between ND-100 and ND-120 panels unclear

## Previous Analysis Context

This analysis builds upon examination of a related MC68705-based ND-120 Performance Monitor system, which provided insights into:
- Command-driven architecture patterns
- FIFO-based communication mechanisms
- Timer-driven sampling approaches
- Hardware interface conventions
- Memory organization strategies

Key differences identified between the two systems:
- **Performance Monitor**: CPU monitoring and data acquisition focus
- **Panel Controller**: Human interface and display management focus
- **Communication**: Performance monitor uses more complex command structures
- **Display**: Panel controller has more sophisticated multi-zone display system

---

*This memory dump represents complete knowledge as of the current analysis state. All unmarked statements are based on direct observation from Ghidra disassembly or user-provided documentation. Marked assumptions require verification through continued analysis.*
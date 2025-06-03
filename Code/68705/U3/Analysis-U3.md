# MC68705 Panel/Calendar Controller Firmware Analysis

Analysis of the code in the 68705 U3 chip

## Introduction

This document provides a comprehensive technical analysis of the Motorola MC68705 microcontroller firmware used as a Panel/Calendar Controller in the Norsk Data ND-120 computer system. The analysis is based entirely on disassembled code from Ghidra and observable patterns in the binary.

The firmware implements a sophisticated real-time performance monitoring and panel control system that interfaces with the ND-120 CPU through a hardware FIFO queue and bidirectional data bus. The controller operates with dual clock domains: a 4MHz crystal for main execution and a 38.4kHz external timer clock (PANOSC) derived from the ND-120 system clock for precise performance sampling.

The firmware demonstrates several key capabilities:
- Real-time CPU performance monitoring at 1200Hz sampling rate
- FIFO-based command processing responding to ND-120 microcode operations
- MM58274 Real-Time Clock chip interface for time/date management
- Multi-mode 7-segment display control with ROM-based character generation
- Statistical processing of CPU utilization data with sliding window averaging

## Summary of Behavior

### Primary Operating Loop
The firmware operates in a dual-state main loop that continuously polls Port D bit 7 (/EMP_n signal) to detect either FIFO commands from the ND-120 CPU or panel status read operations. When /EMP_n is asserted HIGH, the controller enters an active processing state that handles command parsing, display updates, and response generation.

### Real-Time Monitoring System
A 1200Hz timer interrupt continuously samples ND-120 CPU status signals including:
- LEV0 (CPU Level 0 idle indicator)
- LHIT (cache hit performance)
- PONI/IONI (memory protection and interrupt system status)
- PCR Ring levels (CPU privilege level 0-3)

This data is accumulated in a 15-byte sliding window buffer and processed into CPU utilization percentages and performance metrics.

### Command Processing Architecture
The controller responds to 8 different command types (0-7) sent via the ND-120's LDPANC microcode operation. Commands include time/date setting, display control, system configuration, and performance data requests. Responses are provided through the EPANS microcode interface.

### Display Management
The firmware implements a complex 7-segment display system with 5 distinct operational modes:
- Real-time status display with blinking patterns
- Standard RTC time display  
- CPU utilization data display
- Enhanced diagnostic mode
- Command-driven character display

Character conversion utilizes multiple ROM lookup tables to translate ASCII characters and BCD digits into 7-segment patterns.

## Detailed Technical Analysis

### Memory Organization

#### RAM Layout (0x0010-0x007F)
- **0x0010-0x0013**: Display character buffer (4 bytes)
- **0x0014-0x0018**: Time/date command data storage
- **0x0019**: ND120_CPU_Status_Ring_PONI_IONI - CPU status accumulator
- **0x001A**: System_Configuration_Flags
- **0x001B**: Display_Control_Mode_Flags
- **0x001C**: Last_PANC_Command_Byte
- **0x001D-0x001E**: CPU_Utilization_Parameter_1/2
- **0x001F**: FIFO_Empty_Timeout_Counter
- **0x0020-0x0026**: Software_RTC_* counters (internal time keeping)
- **0x0027-0x0046**: Display_Working_Buffer (32-byte processing area)
- **0x0047-0x004A**: Date/Time offset calculation results
- **0x004B-0x0051**: Display processing parameters and loop counters
- **0x0052-0x0059**: Display_7Segment_Digit_0 through _7 (final display patterns)
- **0x005B-0x005D**: Multi-level timer counters (16/200/2 cycle hierarchy)
- **0x005E**: CPU_Utilization_Buffer_Input
- **0x0061-0x006F**: CPU_Utilization_History_Buffer (15-byte sliding window)
- **0x0071**: LEV0_LHIT_Sample_Counter_128
- **0x0072**: LHIT_Cache_Hit_Accumulator
- **0x0073**: LEV0_CPU_Busy_Time_Accumulator

#### ROM Data Tables
- **0x0CF8**: ROM_7Segment_Character_Table - Primary ASCII to 7-segment conversion
- **0x0D12**: ROM_Display_Character_Table_1 - Command 4 character set A
- **0x0D1A**: ROM_Display_Character_Table_2 - Command 4 character set B  
- **0x0D22**: ROM_Character_To_7Segment_Lookup - 4-character display conversion
- **0x0DDE**: ROM_Days_In_Month_Table - Calendar calculation support
- **0x0DEB**: ROM_Month_Offset_Table - Time offset calculations
- **0x0E1F**: ROM_Hour_Time_Offset_Table - Hour conversion support
- **0x0E37**: ROM_Days_Per_Month_Lookup - Month length table
- **0x0E44**: ROM_BCD_To_7Segment_Table - Decimal digit patterns
- **0x0F0C**: PCR_Ring_Level_Bit_Lookup_Table - Ring level bit masks [1,2,4,8]

### Hardware Interface

#### Port Configuration
```
Port A (PA[7:0]): Bidirectional IDB interface (DDRA controlled)
Port B (PB[7:0]): Output control signals (DDRB = 0xFF)
  - PB0: WMM_n latch control for IDB responses
  - PB1: /WRCLK to MM58274 RTC chip
  - PB2: /ROCLK to MM58274 RTC chip  
  - PB3: WMM strobe for FIFO read operations
  - PB4: Command ready status signal
  - PB5: Synchronization control
  - PB6: RTC operation mode control
Port C (PC[7:0]): Output to MM58274 RTC (DDRC = 0xFF)
  - PC[2:0]: RTC register address
  - PC[7:3]: RTC data and control lines
Port D (PD[7:0]): Input status monitoring (DDRD = 0x00)
  - PD7: /EMP_n (FIFO Empty/Panel Enable)
  - PD6: GND (tied to ground)
  - PD5: LEV0 (CPU Level 0 active - HIGH=idle)
  - PD4: LHIT (Cache hit indicator)
  - PD3: IONI (Interrupt system ON)
  - PD2: PONI (Memory protection ON)
  - PD[1:0]: PCR Ring level (0-3)
```

#### Timer Configuration
```
TCR = 0x35: External clock, /32 prescaler, interrupts enabled
TDR = 3: Timer reload value
Input clock: 38.4kHz PANOSC → 1200Hz interrupt rate
Period: 833.33μs per interrupt
```

### Function Analysis

#### Main Entry Point: Wait_For_FIFO_Commands_And_Process (0x0110)

**Initialization Sequence:**
1. Clear RAM 0x10-0x8F (128 bytes)
2. Initialize timer counters and system variables
3. Configure ports for ND-120 interface
4. Initialize MM58274 RTC chip
5. Configure 1200Hz timer interrupt

**Main Loop Structure:**
```
IDLE_STATE:
  Set timeout counter = 0xFF
  Clear Port B ready signal
  Poll /EMP_n with timeout:
    if /EMP_n HIGH → goto ACTIVE_STATE
    if timeout → restart polling

ACTIVE_STATE:
  Process PANC commands while /EMP_n HIGH:
    1. Parse command from FIFO
    2. Clear working buffer
    3. Load character data from ROM
    4. Multi-phase display processing
    5. RTC interface operations
    6. Timer synchronization
    7. Output response data
  320-cycle inter-command delay
  Return to IDLE_STATE
```

#### Timer Interrupt: Timer_1200Hz_CPU_Performance_Monitor (0x08C8)

**Hierarchical Timing Structure:**
- **Level 1**: 1200Hz base sampling (833μs)
- **Level 2**: 75Hz processing (13.3ms) - Buffer management
- **Level 3**: 6Hz processing (167ms) - Statistics updates  
- **Level 4**: 3Hz processing (333ms) - RTC increment

**Performance Sampling Operations:**
1. Sample_ND120_CPU_Status_Signals() - Read Port D status
2. Update_CPU_Ring_PONI_IONI_Statistics() - Process privilege data
3. Conditional Monitor_LEV0_LHIT_Signals_Update_Display() - Track idle/cache
4. Shift_CPU_Utilization_History_Buffer() every 13.3ms
5. Increment_Software_RTC_Counters() every 333ms

#### Command Processing: Process_PANC_Command_From_FIFO (0x04D8)

**Command Protocol:**
```
Command Byte Format:
Bit 7-4: Command flags and options
Bit 3: Direction (0=MC68705→ND120, 1=ND120→MC68705)
Bit 2-0: Command type (0-7)
```

**Command Set Implementation:**

**Command 0 (0x08): Set Complete Time/Date**
- Input: 5 bytes (seconds, hours, minutes, month, day)
- Processing: Store in RAM_0014-0018, set display to "PEXM" or "PT##"
- Mode selection based on System_Configuration_Flags bit 2

**Command 1 (0x09): Set Time Only**
- Input: 4 bytes (month, day, hours, minutes)  
- Processing: Clear RAM_0014, set time-only mode flag

**Command 2 (0x0A): Read CPU Status**
- Input: 2 bytes (parameters)
- Processing: Format PONI/IONI status for display
- Algorithm: `(status & 0x0F) + 0x10` and `((status & 0x30) >> 4) + 0x3A`

**Command 3 (0x0B): Set Display Mode**
- Input: 3 bytes (mode parameters)
- Processing: Clear specific registers, set display mode flags

**Command 4 (0x0C): Load ROM Characters**
- Input: 1 byte (character selection index)
- Processing: Dual ROM table lookup at 0x0D12 and 0x0D1A
- Algorithm: `bits[1:0] * 2` indexes table 1, `bits[4:3] >> 2` indexes table 2

**Command 5 (0x0D): Set System Configuration**
- Input: 1 byte (configuration flags)
- Processing: Direct storage in System_Configuration_Flags

**Command 6 (0x0E): Set Direct Display Data**
- Input: 4 bytes (display characters)
- Processing: Direct load into display character buffer

**Command 7 (0x0F): System Control**
- Input: 2 bytes (control parameters)
- Processing: Soft reset if param2[7:4] = 0x4, feature control if 0x1
- Reset sequence: Configure registers, clear port directions, jump to reset vector

### Display Processing Pipeline

#### Character Loading: Load_Display_Character_Data_From_ROM (0x01B4)
Converts display characters (RAM_0010-0013) to 7-segment patterns using ROM_Character_To_7Segment_Lookup table. Each character generates 2 bytes of pattern data stored in Display_7Segment_Digit_0 through _7.

#### Pattern Formatting: Format_7Segment_Display_Patterns (0x01ED)

**Mode Selection Logic:**
```
if (Display_Control_Mode_Flags & 2):
  if (Display_Control_Mode_Flags & 4):
    → Blinking status display mode
  else:
    → Standard RTC time display mode
elif (CPU_Utilization_Parameter_1 & 3):
  → CPU utilization data display mode
elif (Display_Control_Mode_Flags & 8):
  → Enhanced diagnostic mode  
else:
  → Standard command display mode
```

#### Bit Manipulation: Process_7Segment_Display_Bit_Manipulation (0x0479)

**Three-Phase Processing:**
- Phase 1: mask=0x40, shift=4 (extract high-order bits)
- Phase 2: mask=0x20, shift=2 (extract middle bits)
- Phase 3: mask=0x10, shift=1 (extract low-order bits)

**Algorithm:**
```
For each display position (4 positions):
  For each bit (8 bits):
    Extract LSB from upper buffer, shift right
    Extract LSB from lower buffer, shift right
    Combine with mask/shift parameters
    Store in working buffer at decremented index
```

### Performance Monitoring System

#### CPU Status Sampling: Sample_ND120_CPU_Status_Signals (0x09D4)

**Ring Level Processing:**
1. Extract PONI/IONI: `(PORTD & 0x0C) << 2`
2. If PONI active, read PCR ring level from PORTD[1:0]
3. Use ring level as index into PCR_Ring_Level_Bit_Lookup_Table
4. Set corresponding bit: table[ring] = [1,2,4,8] for rings [0,1,2,3]

#### Utilization Calculation: Calculate_CPU_Utilization_Percentage (0x066B)

**Multi-Byte Precision Algorithm:**
1. Initialize with ring timing data
2. Perform 24-bit right shift for precision scaling
3. Extract fractional bits for percentage conversion
4. Binary-to-percentage conversion via bit position arithmetic

#### LEV0/LHIT Monitoring: Monitor_LEV0_LHIT_Signals_Update_Display (0x0985)

**Sampling Window: 128 cycles (~107ms)**
```
Signal Processing:
- LHIT (PD4 HIGH): Increment cache hit counter
- LEV0 (PD5 LOW): Increment CPU busy counter (inverted logic)

Display Update (every 128 cycles):
- Cache performance: (hit_count >> 5) + 1 + 0x21 → RAM_0011
- CPU utilization: (busy_count >> 5) + 1 + 0x21 → RAM_0010
- Reset counters for next window
```

### Real-Time Clock Interface

#### MM58274 Initialization: Initialize_MM58274_RTC_Chip (0x0AC0)
```
Sequence:
1. PORTB &= 0xFB (clear /ROCLK - reset RTC)
2. Clear RTC buffer registers 0x20-0x26
3. PORTB |= 0x04 (set /ROCLK - enable RTC)
4. Configure Port A as input
```

#### Software RTC: Increment_Software_RTC_Counters (0x08F9)

**Time Increment Logic (every 333ms):**
Note: Variable names are misleading - these are software counters, not MM58274 registers
```
Software_RTC_Units_Hours (0x25): Actually tenths of seconds (0-59)
Software_RTC_Tens_Minutes (0x24): Actually seconds (0-59)
Software_RTC_Units_Minutes (0x23): Actually minutes (0-23, hours)
Software_RTC_Tens_Seconds (0x22): Actually days (1-31)
Software_RTC_Units_Seconds (0x21): Actually months (1-12)
Software_RTC_Tenths_Seconds (0x20): Actually years
Software_RTC_Tens_Hours (0x26): Actually leap year cycle (0-3)
```

**Carry Propagation:**
1. Increment tenths → seconds → minutes → hours → days
2. Days-in-month lookup using ROM_Days_Per_Month_Lookup (0x0E37)
3. Leap year handling for February (28/29 days)
4. Month rollover and year increment with 4-year cycle

### ND-120 Interface Protocol

#### FIFO Read: Strobe_WMM_Read_From_FIFO (0x09BC)
```
Hardware Sequence:
1. PORTB &= 0xF7 (clear PB3)
2. PORTB |= 0x08 (set PB3 - strobe WMM)
3. return PORTA (read FIFO data)
```

#### Response Output: Output_Response_To_ND120_IDB (0x09C5)
```
Hardware Sequence:
1. PORTA = response_data
2. PORTB &= 0xFE (clear PB0)
3. PORTB |= 0x01 (strobe WMM_n latch)
4. DDRA = 0 (return to input mode)
```

### Time Calculation Functions

#### Calculate_RTC_Date_Time_Offset (0x0803)
Complex date/time offset calculation using software RTC values with leap year handling, month length variations, and ROM table lookups for accurate time conversion.

#### Convert_Time_Offset_To_Software_RTC (0x0715)
Reverse conversion from calculated time offset back to software RTC format using subtraction algorithms and ROM lookup tables for calendar math.

## Memory Map

### MC68705 Address Space
```
0x0000-0x0003: Port registers (PORTA, PORTB, PORTC, PORTD)
0x0004-0x0007: Data direction registers (DDRA, DDRB, DDRC, DDRD)
0x0008-0x000B: Timer and control registers (TDR, TCR, MR, PCR)
0x0010-0x007F: User RAM (112 bytes)
0x0080-0x00FF: Additional RAM/registers
0x0110-0x0AC0: Program ROM (main code)
0x0CF8-0x0E44: Data ROM (lookup tables)
0x0F0C-0x0F0F: PCR ring level lookup table
```

### Functional Memory Regions
```
System Control: 0x0019-0x001F (status, flags, parameters)
Display System: 0x0010-0x0013, 0x0027-0x0059 (characters, buffers, patterns)
Performance Data: 0x005E, 0x0061-0x0073 (utilization, history, counters)
Time Management: 0x0020-0x0026, 0x0047-0x004E (RTC, calculations)
ROM Tables: 0x0CF8-0x0E44 (character conversion, calendar math)
```

## Unidentified or Unclear Regions

### Partially Understood Functions
- **Delay_And_Sample_Port_C (0x04A7)**: Currently implements only delay loops with Port C sampling. Purpose unclear from code structure.
- **Debug_Trace_Address_Marker (0x00FE)**: Set at various points in main loop but usage not evident in disassembly.

### ROM Data Regions
- **0x0080-0x0083**: Constants used in time calculations (RTC_*_Constant_*) but specific values and algorithms need verification.
- **ROM table contents**: While table usage is clear, the actual character patterns and conversion values are referenced but not detailed in the disassembly.

### Timing Dependencies  
- **320-cycle inter-command delay**: Specific timing requirement not explained by code context.
- **Timer synchronization loops**: Some loops wait for specific TDR values without clear timing documentation.

### Hardware Interface Details
- **Port B bit functions**: Some Port B operations appear to have hardware-specific timing requirements not documented in the code.
- **MM58274 communication protocol**: While Port C usage is evident, the complete RTC communication protocol details are inferred from patterns rather than explicit documentation.

This analysis represents the complete observable functionality of the MC68705 firmware based on the disassembled code. All conclusions are grounded in actual code patterns, control flow, and data structure usage evident in the binary.
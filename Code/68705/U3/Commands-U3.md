# Command protocol used by the U3

# MC68705 PANC Command Protocol - Detailed Specification

## Introduction

This document provides a comprehensive specification of the Panel Control (PANC) command protocol used by the MC68705 Panel/Calendar Controller in the ND-120 computer system. The protocol enables bidirectional communication between the ND-120 CPU and the MC68705 through a sophisticated microcode-level interface.

## Protocol Overview

### Communication Architecture

The PANC protocol operates through two complementary microcode operations:

**Command Transmission (ND-120 → MC68705):**
- **LDPANC (Microcode 06.2)**: Loads command/data bytes into hardware FIFO
- **Signal**: /EMP_n goes HIGH when FIFO contains data
- **MC68705 Response**: Polls /EMP_n and processes FIFO contents

**Response Reception (MC68705 → ND-120):**
- **EPANS (IDB Source 20)**: Reads MC68705 Port A data to IDB
- **EPANS+ (IDB Source 21)**: Same as 20 + resets status flags
- **Signal**: /EMP_n goes HIGH during panel status enable

### Register Interface

#### PANS Register (Panel Status) - Read by ND-120
```
    15   14   13   12   11   10    9    8    7    6    5    4    3    2    1    0
   ┌────┬────┬────┬────┬────┬────┬────┬────┬────┬────┬────┬────┬────┬────┬────┬────┐
   │PAN │FIP │DAT │RDY │ 0  │     CMND      │              RPAN               │
   └────┴────┴────┴────┴────┴────┴────┴────┴────┴────┴────┴────┴────┴────┴────┴────┘
```

**Bit Definitions:**
- **PAN (15)**: Panel Installed (1=panel present, 0=no panel)
- **FIP (14)**: FIFO Ready for Data (1=ready, 0=busy)
- **DAT (13)**: Last Command Requested Data (1=data available, 0=no data)
- **RDY (12)**: Command Completed (1=complete, 0=processing) - Cleared by TRA PANS
- **Bit 11**: Reserved (always 0)
- **CMND (10-8)**: Last Command Processed (0-7)
- **RPAN (7-0)**: Response Data from MC68705

#### PANC Register (Panel Control) - Written by ND-120
```
    15   14   13   12   11   10    9    8    7    6    5    4    3    2    1    0
   ┌────┬────┬────┬────┬────┬────┬────┬────┬────┬────┬────┬────┬────┬────┬────┬────┐
   │ 0  │ 0  │DAT │N.A.│ 0  │     CMND      │              WPAN               │
   └────┴────┴────┴────┴────┴────┴────┴────┴────┴────┴────┴────┴────┴────┴────┴────┘
```

**Bit Definitions:**
- **Bits 15-14**: Reserved (always 0)
- **DAT (13)**: Command Requests Data (1=read operation, 0=write operation)
- **Bit 12**: Not Applicable
- **Bit 11**: Reserved (always 0)
- **CMND (10-8)**: Command Type (0-7)
- **WPAN (7-0)**: Data/Parameters to MC68705

## Command Byte Format

All PANC commands use a standardized 8-bit command byte format transmitted as the first byte via LDPANC microcode:

```
     7    6    5    4    3    2    1    0
   ┌────┬────┬────┬────┬────┬────┬────┬────┐
   │RTC │MOD │RW  │RSV │DIR │   COMMAND   │
   └────┴────┴────┴────┴────┴────┴────┴────┘
```

**Bit Field Definitions:**

| Bit | Name | Function | Values |
|-----|------|----------|--------|
| **7** | **RTC** | RTC Operation Mode | 0=Standard, 1=RTC Access |
| **6** | **MOD** | Processing Mode | 0=Normal, 1=Enhanced |
| **5** | **RW** | RTC Read/Write | 0=Read RTC, 1=Write RTC |
| **4** | **RSV** | Reserved | 0=Normal, 1=Special |
| **3** | **DIR** | **Data Direction** | **0=Write to ND-120, 1=Read from ND-120** |
| **2-0** | **CMD** | Command Type | 0-7 (8 possible commands) |

### Direction Control (Bit 3)

**DIR = 0 (Write Operations)**: MC68705 → ND-120
- MC68705 outputs data via Port A
- ND-120 reads using EPANS microcode (IDB Source 20/21)
- Used for time/date output, status responses

**DIR = 1 (Read Operations)**: ND-120 → MC68705  
- ND-120 sends command + parameters via LDPANC
- MC68705 processes and may generate response
- Used for configuration, time setting, display control

## Detailed Command Specifications

### Command 0: Set Complete Time and Date (0x08)

**Purpose**: Sets complete date and time information in the MC68705

**Command Format:**
```
     7    6    5    4    3    2    1    0
   ┌────┬────┬────┬────┬────┬────┬────┬────┐
   │ 0  │ 0  │ 0  │ 0  │ 1  │ 0  │ 0  │ 0  │ = 0x08
   └────┴────┴────┴────┴────┴────┴────┴────┘
```

**Data Sequence (5 bytes via sequential LDPANC operations):**
```
LDPANC 1: Command Byte (0x08)
LDPANC 2: Time Component 1 → RAM_0014
LDPANC 3: Time Component 2 → RAM_0016  
LDPANC 4: Time Component 3 → RAM_0015
LDPANC 5: Time Component 4 → RAM_0018
LDPANC 6: Time Component 5 → RAM_0017
```

**Processing Logic:**
1. Clear Display_Control_Mode_Flags bits 4, 3, 1
2. Set display character 0: RAM_0010 = 'P' (0x50)
3. Mode selection based on System_Configuration_Flags bit 2:

**Normal Mode (Config bit 2 = 0):**
```
Display Pattern: "PEXM"
RAM_0011 = 'E' (0x45)
RAM_0012 = 'X' (0x58)
RAM_0013 = 'M' (0x4D)
```

**Test Mode (Config bit 2 = 1):**
```
Display Pattern: "PT##"
RAM_0011 = 'T' (0x54)
Calculate digits from System_Configuration_Flags:
- Extract bits 4-3, shift right 1
- Combine with bits 1-0
- Convert to ASCII if < 8: value + 0x30
```

**Response**: None (write operation)

### Command 1: Set Time Only (0x09)

**Purpose**: Sets time components while preserving date information

**Command Format:**
```
     7    6    5    4    3    2    1    0
   ┌────┬────┬────┬────┬────┬────┬────┬────┐
   │ 0  │ 0  │ 0  │ 0  │ 1  │ 0  │ 0  │ 1  │ = 0x09
   └────┴────┴────┴────┴────┴────┴────┴────┘
```

**Data Sequence (4 bytes):**
```
LDPANC 1: Command Byte (0x09)
LDPANC 2: Time Byte 1 → RAM_0018
LDPANC 3: Time Byte 2 → RAM_0017
LDPANC 4: Time Byte 3 → RAM_0016
LDPANC 5: Time Byte 4 → RAM_0015
```

**Processing Logic:**
1. Clear RAM_0014 = 0 (preserve date)
2. Update Display_Control_Mode_Flags: clear bit 3, set bit 4
3. Set time-only mode indicator

**Memory Layout After Processing:**
```
RAM_0014: 0x00 (cleared)
RAM_0015: Time Byte 4
RAM_0016: Time Byte 3  
RAM_0017: Time Byte 2
RAM_0018: Time Byte 1
```

**Response**: None (write operation)

### Command 2: Read CPU Status (0x0A)

**Purpose**: Reads and formats ND-120 CPU status for display

**Command Format:**
```
     7    6    5    4    3    2    1    0
   ┌────┬────┬────┬────┬────┬────┬────┬────┐
   │ 0  │ 0  │ 0  │ 0  │ 1  │ 0  │ 1  │ 0  │ = 0x0A
   └────┴────┴────┴────┴────┴────┴────┴────┘
```

**Data Sequence (2 bytes):**
```
LDPANC 1: Command Byte (0x0A)
LDPANC 2: Status Parameter 1 → RAM_0018
LDPANC 3: Status Parameter 2 → RAM_0017
```

**CPU Status Processing:**
Reads ND120_CPU_Status_Ring_PONI_IONI and formats for display:

```
Status Byte (from Port D sampling):
     7    6    5    4    3    2    1    0
   ┌────┬────┬────┬────┬────┬────┬────┬────┐
   │EMP │GND │LEV0│LHIT│IONI│PONI│ PCR_RING│
   └────┴────┴────┴────┴────┴────┴────┴────┘

Display Formatting:
RAM_0012 = (status & 0x0F) + 0x10    // Lower nibble + 0x10
RAM_0013 = ((status & 0x30) >> 4) + 0x3A  // PONI/IONI + 0x3A
```

**Status Bit Interpretation:**
- **IONI (bit 3)**: Interrupt System ON
- **PONI (bit 2)**: Memory Protection ON  
- **PCR_RING (1-0)**: CPU Ring Level (0-3)

**Control Flags Update:**
```
Display_Control_Mode_Flags = (flags & 0xE7) | 0x02
CPU_Utilization_Parameter_1 = 0x10
CPU_Utilization_Parameter_2 = 0x00
```

**Response**: Formatted status data in display characters

### Command 3: Set Display Mode (0x0B)

**Purpose**: Configures display mode and parameters

**Command Format:**
```
     7    6    5    4    3    2    1    0
   ┌────┬────┬────┬────┬────┬────┬────┬────┐
   │ 0  │ 0  │ 0  │ 0  │ 1  │ 0  │ 1  │ 1  │ = 0x0B
   └────┴────┴────┴────┴────┴────┴────┴────┘
```

**Data Sequence (3 bytes):**
```
LDPANC 1: Command Byte (0x0B)
LDPANC 2: Display Mode 1 → RAM_0016
LDPANC 3: Display Mode 2 → RAM_0018
LDPANC 4: Display Mode 3 → RAM_0017
```

**Processing Logic:**
1. Update Display_Control_Mode_Flags: clear bit 4, set bit 3
2. Clear data registers: RAM_0015 = 0, RAM_0014 = 0
3. Store mode parameters for display processing

**Response**: None (write operation)

### Command 4: Load ROM Characters (0x0C)

**Purpose**: Loads display characters from ROM lookup tables

**Command Format:**
```
     7    6    5    4    3    2    1    0
   ┌────┬────┬────┬────┬────┬────┬────┬────┐
   │ 0  │ 0  │ 0  │ 0  │ 1  │ 1  │ 0  │ 0  │ = 0x0C
   └────┴────┴────┴────┴────┴────┴────┴────┘
```

**Data Sequence (1 byte):**
```
LDPANC 1: Command Byte (0x0C)
LDPANC 2: Character Selection Index → BYTE_0052
```

**Character Selection Index Format:**
```
     7    6    5    4    3    2    1    0
   ┌────┬────┬────┬────┬────┬────┬────┬────┐
   │         │TAB2_SEL │         │TAB1_SEL │
   └────┴────┴────┴────┴────┴────┴────┴────┘
```

**ROM Table Lookup Process:**

**Table 1 (ROM_Display_Character_Table_1 at 0x0D12):**
```
index1 = (selection_byte & 0x03) * 2     // Bits 1-0, multiply by 2
RAM_0013 = ROM_TABLE_1[index1]           // Character 3
RAM_0012 = ROM_TABLE_1[index1 + 1]       // Character 2
```

**Table 2 (ROM_Display_Character_Table_2 at 0x0D1A):**
```
index2 = (selection_byte & 0x18) >> 2    // Bits 4-3, shift right 2
RAM_0011 = ROM_TABLE_2[index2]           // Character 1  
RAM_0010 = ROM_TABLE_2[index2 + 1]       // Character 0
```

**Result**: 4 display characters loaded into RAM_0010-0013

**Response**: None (write operation)

### Command 5: Set System Configuration (0x0D)

**Purpose**: Updates system configuration flags

**Command Format:**
```
     7    6    5    4    3    2    1    0
   ┌────┬────┬────┬────┬────┬────┬────┬────┐
   │ 0  │ 0  │ 0  │ 0  │ 1  │ 1  │ 0  │ 1  │ = 0x0D
   └────┴────┴────┴────┴────┴────┴────┴────┘
```

**Data Sequence (1 byte):**
```
LDPANC 1: Command Byte (0x0D)
LDPANC 2: Configuration Value → System_Configuration_Flags (0x1A)
```

**Configuration Flags Usage:**
```
     7    6    5    4    3    2    1    0
   ┌────┬────┬────┬────┬────┬────┬────┬────┐
   │         │FMT_SEL│     │MODE│ OPTIONS │
   └────┴────┴────┴────┴────┴────┴────┴────┘
```

**Bit Functions:**
- **MODE (bit 2)**: Display mode select (0=Normal "PEXM", 1=Test "PT##")
- **FMT_SEL (bits 4-3)**: Test mode format selection  
- **OPTIONS (bits 1-0)**: Test mode options

**Response**: None (write operation)

### Command 6: Set Direct Display Data (0x0E)

**Purpose**: Directly loads 4 display characters

**Command Format:**
```
     7    6    5    4    3    2    1    0
   ┌────┬────┬────┬────┬────┬────┬────┬────┐
   │ 0  │ 0  │ 0  │ 0  │ 1  │ 1  │ 1  │ 0  │ = 0x0E
   └────┴────┴────┴────┴────┴────┴────┴────┘
```

**Data Sequence (4 bytes):**
```
LDPANC 1: Command Byte (0x0E)
LDPANC 2: Display Character 1 → RAM_0011
LDPANC 3: Display Character 0 → RAM_0010
LDPANC 4: Display Character 3 → RAM_0013
LDPANC 5: Display Character 2 → RAM_0012
```

**Processing**: Direct character loading with no transformation

**Display Layout:**
```
Position:  3    2    1    0
Character: RAM_0013 RAM_0012 RAM_0011 RAM_0010
Display:   [  3  ] [  2  ] [  1  ] [  0  ]
           Left                    Right
```

**Response**: None (write operation)

### Command 7: System Control and Reset (0x0F)

**Purpose**: System control operations including soft reset capability

**Command Format:**
```
     7    6    5    4    3    2    1    0
   ┌────┬────┬────┬────┬────┬────┬────┬────┐
   │ 0  │ 0  │ 0  │ 0  │ 1  │ 1  │ 1  │ 1  │ = 0x0F
   └────┴────┴────┴────┴────┴────┴────┴────┘
```

**Data Sequence (2 bytes):**
```
LDPANC 1: Command Byte (0x0F)
LDPANC 2: Control Parameter 1 → CPU_Utilization_Parameter_1
LDPANC 3: Control Parameter 2 → CPU_Utilization_Parameter_2
```

**Control Parameter 2 Format:**
```
     7    6    5    4    3    2    1    0
   ┌────┬────┬────┬────┬────┬────┬────┬────┐
   │    CONTROL_TYPE   │    PARAMETER    │
   └────┴────┴────┴────┴────┴────┴────┴────┘
```

**Control Type Processing:**

**Soft Reset (CONTROL_TYPE = 0x4):**
```
if ((parameter_2 & 0xF0) == 0x40):
    MR_Misc_register = 0x40
    TCR_Timer_Control_Register = 0x47
    PCR_Program_Control_Register = 1
    DDRA = DDRB = DDRC = 0    // Reset all port directions
    RESET()                   // Jump to reset vector - NO RETURN
```

**Feature Enable (CONTROL_TYPE = 0x1):**
```
if ((parameter_2 & 0xF0) == 0x10):
    Display_Control_Mode_Flags |= 0x04    // Enable feature
else:
    Display_Control_Mode_Flags &= 0xFB    // Clear feature
```

**Parameter Processing:**
Complex bit manipulation for CPU utilization parameters:
```
parameter_2 = ((parameter_2 & 0x0F) << 1 | parameter_1 >> 7) << 1 | 
              (parameter_1 << 1) >> 7
parameter_1 = parameter_1 & 0x3F    // Mask to 6 bits
```

**Response**: None for normal operations, system restart for reset

## Write Operations (DIR = 0)

When command bit 3 = 0, the MC68705 performs write operations to the ND-120.

### Write Operation Command Format
```
     7    6    5    4    3    2    1    0
   ┌────┬────┬────┬────┬────┬────┬────┬────┐
   │RTC │MOD │RW  │RSV │ 0  │   ADDRESS   │
   └────┴────┴────┴────┴────┴────┴────┴────┘
```

**Address Field (bits 2-0)**: Selects data source (0-7)
**Bit 2**: Must be 1 for RTC operations to proceed
**Bit 5 (RW)**: Operation mode (0=standard read, 1=RTC write/init)

### Write Operation Processing

**Address Validation:**
```c
if ((command_byte & 0x04) == 0) return;  // Exit if bit 2 clear
```

**Address Inversion:**
```c
rtc_address = (command_byte & 0x03) ^ 0x03;  // XOR with 3
```

**Mode Selection (Bit 5):**

**Standard Read Mode (RW = 0):**
```c
PORTB = PORTB & 0x9F;                    // Clear control bits
data = Strobe_WMM_Read_From_FIFO();      // Read additional data
buffer[rtc_address + 0x47] = data;       // Store in buffer
Output_Response_To_ND120_IDB(data);     // Send to ND-120
PORTB |= 0x20;                          // Set completion flag

if (rtc_address == 0):                   // Special case for address 0
    Convert_Time_Offset_To_Software_RTC()    // Complex time calculation
    Output_Status_Code_1_To_ND120()          // Send completion status
```

**RTC Write Mode (RW = 1):**
```c
PORTB |= 0x40;                          // Set RTC mode
Strobe_WMM_Read_From_FIFO();            // Read data (may be discarded)

if (rtc_address == 3):                   // Special case for address 3
    Initialize_MM58274_RTC_Chip()        // Reinitialize RTC
    Calculate_RTC_Date_Time_Offset()     // Calculate display format

Output_Response_To_ND120_IDB(buffer[rtc_address + 0x47]);  // Output stored data
PORTB |= 0x20;                          // Set completion flag
```

## Response Generation

### Standard Response Format

All responses are output via the Output_Response_To_ND120_IDB() function:

```
     7    6    5    4    3    2    1    0
   ┌────┬────┬────┬────┬────┬────┬────┬────┐
   │STA │ERR │RDY │VAL │TYP │    DATA     │
   └────┴────┴────┴────┴────┴────┴────┴────┘
```

**Response Bit Fields:**
- **STA (7)**: Status flag (system operational state)
- **ERR (6)**: Error flag (operation result)
- **RDY (5)**: Ready flag (completion status)
- **VAL (4)**: Data valid flag (response contains valid data)
- **TYP (3)**: Data type (0=Time/numeric, 1=Status/text)
- **DATA (2-0)**: Data payload or status code

### Response Types

**Time/Date Response:**
- Used for RTC data output
- Contains BCD time values
- TYP bit = 0

**Status Response:**
- Used for system status information
- Contains formatted status codes
- TYP bit = 1

**Completion Response:**
- Indicates command processing complete
- May contain result codes
- RDY bit = 1

### Hardware Output Sequence

```c
void Output_Response_To_ND120_IDB(uint8_t response_data) {
    PORTA = response_data;        // Place data on Port A bus
    PORTB &= 0xFE;               // Clear PB0 (prepare WMM_n)
    PORTB |= 0x01;               // Set PB0 (strobe WMM_n latch)
    DDRA = 0;                    // Return Port A to input mode
}
```

**Signal Flow:**
```
MC68705 Port A → 74LS374 Latch → IDB[7:0] → ND-120 PANS Register
                     ↑
                  WMM_n strobe
```

## Error Handling and Special Cases

### Command Validation
- Commands with invalid bit patterns are ignored
- Bit 2 must be set for RTC operations
- Direction bit controls processing path

### Timeout Handling
- FIFO polling includes 255-cycle timeout
- Prevents infinite blocking on /EMP_n signal
- Automatic retry after timeout

### Reset Recovery
- Command 7 with 0x4X parameter triggers immediate reset
- All registers reinitialized
- System returns to startup state

### Buffer Overflow Protection
- FIFO hardware provides flow control
- MC68705 processes commands sequentially
- No buffer overflow possible with proper microcode timing

## Protocol Timing Considerations

### Microcode Timing
- LDPANC operations complete in microcode cycles
- /EMP_n signal provides hardware handshaking
- No software timing dependencies

### Response Timing  
- MC68705 processes commands asynchronously
- Response available when RDY flag set in PANS
- ND-120 can poll or interrupt on completion

### Inter-Command Delays
- 320-cycle delay between command processing cycles
- Prevents bus conflicts during direction changes
- Ensures proper setup/hold times

This protocol provides a robust, high-performance interface between the ND-120 CPU and MC68705 Panel/Calendar Controller, enabling sophisticated real-time system monitoring and control capabilities.
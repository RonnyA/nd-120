# ND-100/120 Panel Controller 68705 Technical Analysis Report

## Executive Summary

This report analyzes the Motorola 68705P3 microcontroller firmware that serves as the panel processor for the Norsk Data ND-100/120 minicomputer operator interface. The analysis is based on Ghidra disassembly and reveals a sophisticated bidirectional communication system managing display control, button input processing, and real-time status reporting.

## 1. Command Reception Mechanism

### 1.1 Primary Detection Method

**Function**: `WaitForData()` at address `0x025E`

The 68705 detects new commands through a **polling-based interrupt mechanism** using the `readIRQ()` function:

```c
do {
    bVar4 = (bool)readIRQ();    // Poll for FIFO data available
    if (bVar4) {
        // Command processing begins here
        DAT_001a = '\0';
        PORTC = PORTC & 0xfe | 3;   // Set control signals
        goto LAB_0282;              // Begin serial reception
    }
} while ((PORTA & 0x3f) == 0);      // Also check direct input
```

### 1.2 Command Reception Interface

| Component | Function |
|-----------|----------|
| **FIFO Buffer** | CY7C401 (512 x 9-bit) buffers commands from ND CPU |
| **Status Signal** | `readIRQ()` indicates FIFO data available |
| **Data Interface** | PORTA bits 0-2 provide 3-channel serial input |
| **Clock Signal** | PORTC bit 1 provides serial data sampling clock |

### 1.3 Serial Data Reception Process

**Location**: `WaitForData()` at `LAB_0282`

```c
// 8 bytes × 8 bits per channel = 192 bits total
bVar3 = 8;
do {
    do {
        PORTC = PORTC & 0xfd;    // Clear clock
        PORTC = PORTC | 2;       // Set clock  
        DAT_0020 = PORTA;        // Read input data
        
        // Shift data into 3 parallel shift registers
        DAT_0021 = DAT_0021 >> 1;  // ShiftRegister1
        DAT_0022 = DAT_0022 >> 1;  // ShiftRegister2
        DAT_0023 = DAT_0023 >> 1;  // ShiftRegister3
        
        // Input bits (active low - inverted logic)
        if ((PORTA & 1) == 0) DAT_0021 = DAT_0021 | 0x80;
        if ((PORTA & 2) == 0) DAT_0022 = DAT_0022 | 0x80;
        if ((PORTA & 4) == 0) DAT_0023 = DAT_0023 | 0x80;
        
        DAT_001a = DAT_001a + 1;
    } while (DAT_001a != 8);     // 8 bits per byte
    
    // Store completed byte in data buffers
    *(byte *)(bVar3 + 0x2d) = DAT_0021;  // TimeDataBuffer area
    *(byte *)(bVar3 + 0x35) = DAT_0022;  // TimeDisplayBuffer area  
    *(byte *)(bVar3 + 0x3d) = DAT_0023;  // StatusDataBuffer area
    
    bVar3 = bVar3 - 1;
} while (bVar3 != 0);            // 8 bytes total
```

### 1.4 Command Processing Entry Point

**Function**: `ProcessData()` at address `0x0142`

Commands are processed using a lookup table mechanism:

```c
bVar3 = DAT_0012 & 0x3f;         // Extract 6-bit command
if (bVar3 != 0) {
    DAT_0016 = bVar3;            // Store CommandParameter
    bVar7 = 0x80;                // Primary lookup table
    if ((DAT_0014 & 0x10) == 0) goto LAB_0194;
    bVar7 = 0x8b;                // Secondary lookup table
    
    // Massive switch statement with 128+ cases (0x00-0xFE, even numbers)
    switch(bVar7) {
        case 0: bVar4 = switchD_01a4::caseD_34(); return bVar4;
        case 2: bVar4 = switchD_01a4::caseD_2a(); return bVar4;
        // ... (120+ additional cases)
    }
}
```

### 1.5 Timing Details

- **Polling Frequency**: Continuous polling in main loop
- **Serial Clock**: PORTC bit 1 toggled for each bit
- **Processing Delay**: Immediate processing after complete reception
- **Debounce Timer**: 5 cycles via `ButtonDebounceCounter` (0x13)

## 2. Response Generation

### 2.1 Output Interface

**Primary Functions**: 
- `WriteToDisplayPort()` at `0x023C` 
- `OutputToDisplayDriver()` at `0x0238`

| Port | Bit(s) | Function | Direction |
|------|--------|----------|-----------|
| **PORTB** | 7-0 | Response data to CPU | Output |
| **PORTC** | 0 | Data strobe (active high) | Output |
| **PORTC** | 1 | Serial clock | Output |
| **PORTC** | 2 | Command mode select | Output |

### 2.2 Response Generation Sequence

```c
// Standard response protocol
void WriteToDisplayPort(byte param_1) {
    PORTC = PORTC & 0xfe;       // Clear strobe (setup)
    PORTB = param_1;            // Set response data
    PORTC = PORTC | 1;          // Set strobe (valid data)
    // Timing delay loop (32 × 256 = 8192 cycles)
}

// Combined status + data response  
void OutputToDisplayDriver(byte param_1) {
    PORTC = PORTC & 0xfe;       // Clear strobe
    PORTB = (param_1 | DAT_0014) & 0x7f;  // Combine data + status
    PORTC = PORTC | 1;          // Set strobe
    // Timing delay
}
```

### 2.3 Response Data Format

**Status Register** (DisplayControlFlags - `0x14`):
```
Bit 7: CPU communication status
Bit 6: Additional display control
Bit 5: Display enable flag (0x20)
Bit 4: Command table select (0=0x80, 1=0x8B)
Bit 3-0: Display mode and addressing
```

### 2.4 Handshake Protocol

- **No dedicated ready/busy signal observed**
- **Strobe-based validation**: PORTC bit 0 indicates valid data
- **Status integration**: Response combines data with system status
- **Timing-based**: Fixed delay loops ensure signal stability

## 3. Display and Internal Behavior

### 3.1 Display Hardware Control

**Display Components**:
- **HD44100H**: 40-channel LCD driver 
- **CD4035BE**: Cascaded 4-bit shift registers (16+ units)
- **LD-H7919**: 8-digit alphanumeric LCD modules
- **LCD SX 423 M4**: 16-segment function displays

### 3.2 Command Actions by Category

#### 3.2.1 Display Update Commands

**Case 0x34** (`caseD_34` at `0x01DB`):
```c
if ((DAT_0012 & 0x80) == 0) {
    OutputToDisplayDriver(2);     // Send data with status
    OutputToDisplayDriver();      // Send additional data
    caseD_a4();                  // Execute display update
    CompleteCommandProcessing(4); // Finalize with code 4
}
```

**Display Control Functions**:
- `FUN_0690()`: Character positioning within display memory
- `FUN_05D2()`: Character output to display segments  
- `FUN_05FC()`: Display command mode (PORTC bits 3-2 cleared, bit 2 set)

#### 3.2.2 System Status Display

**Function**: `ShowSystemStatusDisplay()` at `0x041D`

Displays CPU status indicators:
```c
// Display utilization bars (8 segments)
for (8 iterations) {
    if ((data_byte & bit_mask) != 0) {
        FUN_05d2(0xdb);          // Display active segment
    } else {
        FUN_05d2(0x5f);          // Display inactive segment  
    }
}

// Display protection ring (0-3)
if ((data_byte & 1) != 0) output = 0x30;    // "0"
if ((data_byte & 2) != 0) output = 0x31;    // "1"  
if ((data_byte & 0x80) != 0) output = 0x32; // "2"
if ((data_byte & 0x40) != 0) output = 0x33; // "3"
```

#### 3.2.3 Time/Date Display  

**Function**: `DisplayTimeData()` at `0x03CF`

Updates time display from received data:
```c
DAT_001e = 9;                    // 9 character positions
while (DAT_001e != 0) {
    char_code = LookupCharacterCode(); // Convert to display code
    if (char_code == -1) {
        DisplayBinaryDigits();    // Show as binary
    } else {
        FUN_05d2();              // Display character
    }
    DAT_001e = DAT_001e - 1;
}
```

### 3.3 Memory Locations for Display Control

| Address | Name | Function |
|---------|------|----------|
| `0x0025-0x0028` | MessageBuffer0-3 | 4-character scrolling message |
| `0x0029-0x002C` | StoredMessageBuffer0-3 | Previous message state |
| `0x002D-0x0034` | TimeDataBuffer | Raw time data from CPU |
| `0x0035-0x003C` | TimeDisplayBuffer | Formatted time display |
| `0x003D-0x0044` | StatusDataBuffer | System status indicators |
| `0x0045` | DisplayModeSelect | Display mode selection |
| `0x0047` | CharacterPosition | Current character position |

### 3.4 Hardware Effects

**Direct Port Control**:
- **PORTB**: 8-bit data to HD44100H LCD driver
- **PORTC bit 0**: Data strobe to CD4035 shift registers
- **PORTC bit 1**: Serial clock for shift register chain
- **PORTC bit 2**: Command/data mode for HD44100H

**No Evidence Of**:
- Audible signal control
- Direct LED control (likely handled by display driver)
- Buzzer control

## 4. Button Press Signaling

### 4.1 Button Input Detection

**Input Method**: Direct PORTA monitoring in `ProcessData()`

```c
bVar4 = PORTA;                   // Read current input
if (PORTA == ButtonStateBuffer) { // Check for stability
    ButtonDebounceCounter = ButtonDebounceCounter - 1;
    if (ButtonDebounceCounter == 0) {  // Debounce complete
        ButtonChangeFlags = PORTA ^ PreviousButtonState;
        if ((ButtonChangeFlags & 0x40) == 0) {  // Button event detected
            // Process button command
        }
    }
} else {
    ButtonDebounceCounter = 5;    // Reset debounce timer
    ButtonStateBuffer = bVar4;    // Update state buffer
}
```

### 4.2 Button State Processing

**Input Encoding**:
- **PORTA bits 5-0**: 6-bit command/button data (`PORTA & 0x3F`)
- **PORTA bit 6**: Button change detection flag (`0x40` mask)
- **PORTA bit 7**: Additional status

### 4.3 Interrupt Generation to CPU

**Function**: Timer-based interrupt via `ProcessData()`

```c
CountdownTimer1 = CountdownTimer1 - 1;
if ((CountdownTimer1 == 0) && (CountdownTimer2 == 0)) {
    DisplayControlFlags = DisplayControlFlags & 0xef;  // Clear bit 4
    if ((DisplayModeFlags & 0x20) == 0) {
        InitDisplayClearPulse();    // Signal CPU
        CountdownTimer2 = 6;        // Reset secondary timer
    }
}
```

**Interrupt Signal Generation**:
```c
void InitDisplayClearPulse(void) {
    FUN_05fc(1);                 // Send command via PORTB=1, PORTC|=4
    // Delay loop (180 cycles)
}
```

### 4.4 CPU Notification Method

**Mechanism**: **Timer-coordinated signaling with 20ms synchronization**

- **No dedicated interrupt pin observed**
- **Timing-based coordination**: Aligns with CPU's 20ms interrupt cycle
- **Status flag method**: CPU likely polls panel status register
- **Command transmission**: Button events sent as commands via normal protocol

### 4.5 Button Processing Locations

| Address | Name | Function |
|---------|------|----------|
| `0x0010` | CountdownTimer1 | Primary interrupt timing |
| `0x0011` | CountdownTimer2 | Secondary interrupt timing |
| `0x0012` | ButtonStateBuffer | Current button state |
| `0x0013` | ButtonDebounceCounter | Software debouncing |
| `0x0015` | PreviousButtonState | Previous state for change detection |
| `0x0017` | ButtonChangeFlags | Detected button changes |

## 5. Summary of Port Usage

### 5.1 PORTA (0x0000) - INPUT PORT (DDRA = 0x00)

| Bit | Function | Active | Description |
|-----|----------|--------|-------------|
| 0 | Serial Data Ch1 | Low | Command data from CPU (inverted to ShiftRegister1 bit 7) |
| 1 | Serial Data Ch2 | Low | Command data from CPU (inverted to ShiftRegister2 bit 7) |
| 2 | Serial Data Ch3 | Low | Command data from CPU (inverted to ShiftRegister3 bit 7) |
| 3 | Panel Lock Key | High | Panel position sense (0=LOCK, 1=ON/STANDBY) |
| 4-5 | Command/Button | - | Additional command data or button inputs |
| 6 | Button Change | - | Button state change flag (0x40 mask) |
| 7 | Status/Control | - | Additional control or status input |

**Usage Patterns**:
- `(PORTA & 0x3F)` - Extract 6-bit command data
- `(PORTA & 0x08)` - Panel lock key position
- `(PORTA & 0x40)` - Button change detection
- `PORTA == ButtonStateBuffer` - Input stability checking

### 5.2 PORTB (0x0001) - OUTPUT PORT (DDRB = 0xFF)

| Usage | Description | Active |
|-------|-------------|--------|
| Display Data | 8-bit data to HD44100H LCD driver | - |
| CPU Response | Response data to CPU PANS register | - |
| Character Codes | Display character and segment data | - |
| Status Combined | Status + data combined output | - |

**Control Sequences**:
```c
PORTB = data;                    // Set 8-bit output
PORTB = (data | status) & 0x7f;  // Combined status + data
```

### 5.3 PORTC (0x0002) - CONTROL OUTPUT PORT (DDRC = 0xFF)

| Bit | Function | Active | Description |
|-----|----------|--------|-------------|
| 0 | Display Strobe | High | Data valid strobe to HD44100H and CD4035 |
| 1 | Serial Clock | High | Clock for serial data sampling |
| 2 | Command Mode | High | Display command vs data mode select |
| 3-7 | Control Signals | - | Additional display/interface control |

**Control Sequences**:
```c
// Data Output Protocol
PORTC = PORTC & 0xFE;  // Clear strobe (setup)
PORTB = data;          // Set data
PORTC = PORTC | 1;     // Set strobe (valid)

// Command Mode Selection  
PORTC = PORTC & 0xF3;  // Clear command bits
PORTC = PORTC | 4;     // Set command mode

// Serial Clock Generation
PORTC = PORTC & 0xFD;  // Clear clock
PORTC = PORTC | 2;     // Set clock
```

## 6. Timing Analysis

### 6.1 Command Processing Timing

- **Command Reception**: Immediate processing when `readIRQ()` true
- **Serial Transfer**: 192 bits (8 bytes × 3 channels × 8 bits)
- **Processing Delay**: Variable based on command complexity
- **Response Generation**: Immediate via PORTB/PORTC strobing

### 6.2 Button Processing Timing

- **Debounce Period**: 5 cycles minimum
- **Change Detection**: Immediate via XOR comparison
- **Interrupt Generation**: Timer-coordinated (20ms alignment)

### 6.3 Display Update Timing

- **Character Output**: Strobed via PORTC bit 0
- **Command Setup**: PORTC bits cleared then set for mode
- **Delay Loops**: Multiple nested loops provide signal stability

## 7. Unresolved Areas

### 7.1 External Function Dependencies

- **`readIRQ()`**: Function not found in disassembly - likely external or hardware-dependent
- **Command lookup tables**: Tables at 0x80 and 0x8B not fully analyzed
- **Character encoding tables**: ROM tables at 0x6BC and 0x759 require detailed analysis

### 7.2 Hardware Interface Details

- **FIFO interface timing**: Exact CY7C401 control signals unknown
- **LCD driver configuration**: HD44100H initialization sequences unclear
- **Shift register timing**: CD4035 latch enable signals not identified

### 7.3 Communication Protocol Details

- **PANC/PANS register mapping**: Exact CPU interface register functions unclear
- **Interrupt acknowledgment**: CPU response to panel interrupts unknown
- **Error handling**: Fault detection and recovery mechanisms not observed

## 8. Conclusions

The 68705P3 panel processor implements a sophisticated bidirectional communication system with the ND-100/120 CPU. Key findings:

1. **Command Reception**: Polling-based detection with 3-channel serial input processing
2. **Response Generation**: Strobe-based output protocol with status integration  
3. **Display Control**: Complex multi-zone display management with character lookup
4. **Button Processing**: Software debouncing with timer-coordinated CPU notification
5. **System Integration**: 20ms synchronization with CPU interrupt cycle

The firmware demonstrates advanced embedded systems design techniques including state machines, lookup tables, software debouncing, and precise timing control - typical of 1980s minicomputer peripheral controllers.

---

*Analysis based on Ghidra disassembly of 68705P3 firmware. All observations grounded in actual code examination. Unresolved areas clearly marked and require additional analysis.*
# MC68705P3 Panel Controller - Complete Pinout and Port Analysis

## 1. MC68705P3 Package and Pin Configuration

### 1.1 Package Type
**28-Pin Dual In-Line Package (DIP-28)**

```
                    MC68705P3
                  ┌─────────────┐
              VBB │ 1       28 │ VDD  
               PC0│ 2       27 │ PC1
               PC2│ 3       26 │ PC3  
               PC4│ 4       25 │ PC5
               PC6│ 5       24 │ PC7
               PB0│ 6       23 │ PA0
               PB1│ 7       22 │ PA1
               PB2│ 8       21 │ PA2
               PB3│ 9       20 │ PA3
               PB4│10       19 │ PA4
               PB5│11       18 │ PA5
               PB6│12       17 │ PA6
               PB7│13       16 │ PA7
               VSS│14       15 │ XTAL/EXTAL
                  └─────────────┘
```

### 1.2 Power Supply Pins

| Pin | Name | Function | ND-120 Panel Usage |
|-----|------|----------|-------------------|
| 1 | VBB | Negative Supply (-5V) | Negative voltage for EPROM programming |
| 14 | VSS | Ground (0V) | System ground |
| 28 | VDD | Positive Supply (+5V) | Main power supply |

### 1.3 Clock/Crystal Pins

| Pin | Name | Function | ND-120 Panel Usage |
|-----|------|----------|-------------------|
| 15 | XTAL/EXTAL | Crystal/External Clock | System clock input (likely 2MHz crystal) |

## 2. Port A Configuration (PA0-PA7)

**Data Direction**: Input (DDRA = 0x00)
**Primary Function**: Command Reception and Button Input

### 2.1 Port A Pinout

| Pin | Signal | Direction | Function | ND-120 Panel Connection |
|-----|--------|-----------|----------|------------------------|
| 23 | PA0 | Input | Serial Data Channel 1 | CPU command data bit 0 (active low) |
| 22 | PA1 | Input | Serial Data Channel 2 | CPU command data bit 1 (active low) |
| 21 | PA2 | Input | Serial Data Channel 3 | CPU command data bit 2 (active low) |
| 20 | PA3 | Input | Panel Lock Key Sense | Panel lock position (0=LOCK, 1=ON/STANDBY) |
| 19 | PA4 | Input | Command/Button Data | Additional command or button input |
| 18 | PA5 | Input | Command/Button Data | Additional command or button input |
| 17 | PA6 | Input | Button Change Flag | Button state change detection (0x40 mask) |
| 16 | PA7 | Input | Status/Control | Additional control or status input |

### 2.2 Port A Usage in Firmware

```c
// Command extraction
command = PORTA & 0x3F;          // Extract 6-bit command (PA5-PA0)

// Serial data reception (active low inputs)
if ((PORTA & 1) == 0) ShiftRegister1 |= 0x80;  // PA0 → data channel 1
if ((PORTA & 2) == 0) ShiftRegister2 |= 0x80;  // PA1 → data channel 2  
if ((PORTA & 4) == 0) ShiftRegister3 |= 0x80;  // PA2 → data channel 3

// Panel lock key sensing
if ((PORTA & 8) == 0) {          // PA3: Panel lock position
    DisplayControlFlags = 0x60;   // LOCK position
} else {
    DisplayControlFlags = 0xE0;   // ON/STANDBY position
}

// Button change detection
ButtonChangeFlags = PORTA ^ PreviousButtonState;
if ((ButtonChangeFlags & 0x40) != 0) { // PA6: Button event detected
    // Process button state change
}
```

## 3. Port B Configuration (PB0-PB7)

**Data Direction**: Output (DDRB = 0xFF)  
**Primary Function**: Display Data and CPU Response

### 3.1 Port B Pinout

| Pin | Signal | Direction | Function | ND-120 Panel Connection |
|-----|--------|-----------|----------|------------------------|
| 6 | PB0 | Output | Response Data Bit 0 | CPU PANS register bit 0 |
| 7 | PB1 | Output | Response Data Bit 1 | CPU PANS register bit 1 |
| 8 | PB2 | Output | Response Data Bit 2 | CPU PANS register bit 2 |
| 9 | PB3 | Output | Response Data Bit 3 | CPU PANS register bit 3 |
| 10 | PB4 | Output | Response Data Bit 4 | CPU PANS register bit 4 |
| 11 | PB5 | Output | Response Data Bit 5 | CPU PANS register bit 5 |
| 12 | PB6 | Output | Response Data Bit 6 | CPU PANS register bit 6 |
| 13 | PB7 | Output | Response Data Bit 7 | CPU PANS register bit 7 |

### 3.2 Port B Usage in Firmware

```c
// Combined status + data response  
PORTB = (data | DisplayControlFlags) & 0x7F;  // 7-bit response + status

// Direct data output
PORTB = data;                                 // 8-bit direct data

// Display command/data output
PORTB = display_command;                      // HD44100H LCD driver input
PORTB = character_code;                       // Character data to display
PORTB = DisplayControlFlags;                  // Status output to CPU
```

### 3.3 Port B Data Flow

**To CPU (PANS Register)**:
- Response data from command processing
- Status information (DisplayControlFlags)
- Button state acknowledgments
- Real-time clock data

**To Display System**:
- Commands to HD44100H LCD driver
- Character codes for display
- Display addressing information
- Control signals for CD4035 shift registers

## 4. Port C Configuration (PC0-PC7)

**Data Direction**: Output (DDRC = 0xFF)
**Primary Function**: Control Signals and Timing

### 4.1 Port C Pinout

| Pin | Signal | Direction | Function | ND-120 Panel Connection |
|-----|--------|-----------|----------|------------------------|
| 2 | PC0 | Output | Display Data Strobe | HD44100H/CD4035 data valid strobe |
| 27 | PC1 | Output | Serial Clock | Serial data sampling clock |
| 3 | PC2 | Output | Display Command Mode | HD44100H command/data select |
| 26 | PC3 | Output | Display Control 1 | Additional display control signal |
| 4 | PC4 | Output | Display Control 2 | Additional display control signal |
| 25 | PC5 | Output | Display Control 3 | Additional display control signal |
| 5 | PC6 | Output | Display Control 4 | Additional display control signal |
| 24 | PC7 | Output | Display Control 5 | Additional display control signal |

### 4.2 Port C Usage in Firmware

**PC0 - Display Data Strobe** (Primary response signaling):
```c
// Standard strobe protocol for all responses
PORTC = PORTC & 0xFE;        // Clear strobe (setup phase)
PORTB = data;                // Set data on Port B
PORTC = PORTC | 1;           // Set strobe (data valid)
```

**PC1 - Serial Clock** (Command reception timing):
```c
// Serial data sampling clock
PORTC = PORTC & 0xFD;        // Clear clock
PORTC = PORTC | 2;           // Set clock
SerialInputData = PORTA;     // Sample data on clock edge
```

**PC2 - Display Command Mode** (LCD driver control):
```c
// Command mode for HD44100H
PORTC = PORTC & 0xF3;        // Clear mode bits (bits 3-2)
PORTC = PORTC | 4;           // Set command mode
```

**PC3-PC7 - Additional Control** (Display system control):
- Likely connected to CD4035 latch enables
- Display module selection
- LCD backlight control
- Status LED control

## 5. Hardware Interface Connections

### 5.1 CPU Interface (ND-120 Connection)

**Command Input Path**:
```
ND-120 CPU → PANC Register → CY7C401 FIFO → External Logic → PA0-PA2 (Serial Data)
                                                            → PA3-PA7 (Control/Status)
```

**Response Output Path**:
```
PB0-PB7 (Data) → External Logic → PANS Register → ND-120 CPU
PC0 (Strobe)   →
```

**Control Signals**:
```
External readIRQ() signal → 68705P3 interrupt detection
External Button Matrix   → PA4-PA7 inputs
Panel Lock Key          → PA3 input
```

### 5.2 Display System Interface

**HD44100H LCD Driver**:
```
PB0-PB7 → HD44100H Data Input (8-bit)
PC0     → HD44100H Enable/Strobe
PC2     → HD44100H Command/Data Select  
PC3-PC7 → HD44100H Additional Control
```

**CD4035 Shift Register Chain**:
```
PB0-PB7 → CD4035 Serial Data Input
PC0     → CD4035 Latch Enable (all registers)
PC1     → CD4035 Clock (shift register timing)
```

**LCD Modules**:
```
HD44100H Outputs → LD-H7919 8-digit displays (time/date)
                 → LCD SX 423 M4 16-segment displays (status)
```

### 5.3 Button/Panel Interface

**Button Matrix**:
```
Button Switches → External Encoding Logic → PA4-PA7
Panel Lock Key  → Direct Connection → PA3
Status LEDs     → Display System Control → PC3-PC7
```

## 6. Signal Timing and Protocols

### 6.1 CPU Communication Timing

**Command Reception** (20ms cycle coordination):
```
1. CPU writes to PANC register (every 20ms from microprogram)
2. CY7C401 FIFO buffers command  
3. readIRQ() signals data available to 68705P3
4. 68705P3 performs serial reception via PA0-PA2
5. ProcessData() executes command handler
```

**Response Generation** (immediate):
```
1. Command handler prepares response data
2. PORTC bit 0 cleared (strobe setup)
3. PORTB set with response data  
4. PORTC bit 0 set (strobe active)
5. CPU reads PANS register
6. Fixed delay ensures signal stability
```

### 6.2 Display System Timing

**Character Output** (HD44100H protocol):
```
1. PORTB set with character/command data
2. PC2 set/clear for command/data mode
3. PC0 strobed for data valid
4. HD44100H processes and updates display
```

**Shift Register Control** (CD4035 chain):
```
1. Serial data clocked into registers via PC1
2. Parallel data latched via PC0  
3. Display segments updated simultaneously
```

### 6.3 Button Processing Timing

**Debouncing Sequence**:
```
1. PA4-PA7 monitored for state changes
2. Software debouncing (5 cycles @ ButtonDebounceCounter)
3. Stable state detection via comparison
4. Button event processed as command
5. CPU notification via timer-coordinated interrupt
```

## 7. Power and Clock Requirements

### 7.1 Power Supply

| Supply | Voltage | Current | Function |
|--------|---------|---------|----------|
| VDD | +5V ±5% | ~50mA | Main logic power |
| VSS | 0V | - | Ground reference |
| VBB | -5V | ~1mA | EPROM programming (if used) |

### 7.2 Clock System

**Crystal Oscillator** (Pin 15):
- **Frequency**: Likely 2MHz (based on timing loops)
- **Type**: Parallel resonant crystal
- **Accuracy**: ±0.01% for timing-critical operations

**Internal Clock Generation**:
- Internal divide-by-4 → 500kHz instruction cycle
- Timer prescaling via Timer_Control_Reg (0x78)
- 20ms synchronization with CPU interrupt cycle

## 8. Design Considerations

### 8.1 Signal Integrity

**Input Protection**:
- PA0-PA7 likely have pull-up resistors for CMOS logic levels
- Button inputs may have external debouncing capacitors
- Serial inputs (PA0-PA2) require clean signal transitions

**Output Drive**:
- PB0-PB7 must drive HD44100H inputs and external logic
- PC0-PC7 provide control signals with adequate current
- All outputs designed for 5V CMOS/TTL compatibility

### 8.2 Thermal Considerations

**Heat Dissipation**:
- Low power CMOS design (~250mW total)
- No heat sink required in normal operation  
- Adequate PCB copper for thermal distribution

### 8.3 EMC/EMI Considerations

**Noise Immunity**:
- Critical timing signals (PC0, PC1) require clean routing
- Power supply decoupling capacitors essential
- Ground plane recommended for high-frequency noise reduction

## 9. Summary

The MC68705P3 in the ND-120 panel controller serves as a sophisticated interface processor with:

- **24 I/O pins** (PA0-PA7, PB0-PB7, PC0-PC7) for complete system control
- **Dual-function design**: CPU communication + display management  
- **Real-time operation**: 20ms synchronization with CPU interrupts
- **Complex protocol handling**: Serial reception, strobe signaling, status integration
- **Multi-interface capability**: Simultaneous CPU, display, and button processing

Each pin serves a specific, well-defined role in the overall system architecture, enabling the 68705P3 to function as an intelligent peripheral controller managing all aspects of the operator panel interface for the ND-120 minicomputer system.
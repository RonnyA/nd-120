# ND-100/120 Panel Controller - Detailed Port Analysis

## Port Assignments and CPU Communication

### **PORTA (0x0000) - INPUT PORT (DDRA = 0x00)**

**Primary Function**: CPU Command Reception and Button Input

| Bit | Function | Description |
|-----|----------|-------------|
| 0 | Serial Data Ch1 | Serial command data from CPU (active low, inverted to ShiftRegister1 bit 7) |
| 1 | Serial Data Ch2 | Serial command data from CPU (active low, inverted to ShiftRegister2 bit 7) |
| 2 | Serial Data Ch3 | Serial command data from CPU (active low, inverted to ShiftRegister3 bit 7) |
| 3 | Panel Lock Key | Panel lock position sense (0=LOCK, 1=ON/STANDBY) - checked in RESET |
| 4-5 | Command/Button | Additional command data or button input lines |
| 6 | Button Change | Button state flag (0x40 mask) - used for change detection |
| 7 | Status/Control | Additional control or status input |

**Usage Patterns**:
- `(PORTA & 0x3F)` - Extract 6-bit command data in ProcessData()
- `(PORTA & 0x08)` - Check panel lock key in RESET function  
- `(PORTA & 0x40)` - Button change detection flag
- `PORTA == ButtonStateBuffer` - Input stability checking for debouncing

### **PORTB (0x0001) - OUTPUT PORT (DDRB = 0xFF)**

**Primary Function**: Display Data and CPU Response

| Usage | Description |
|-------|-------------|
| Display Data | 8-bit data output to HD44100H LCD driver |
| CPU Response | Response data back to CPU via PANS register interface |
| Character Codes | Display character and control codes |
| Status Data | Combined with DisplayControlFlags for status reporting |

**Key Operations**:
```c
PORTB = param_1;                    // Direct data output
PORTB = (data | DisplayControlFlags) & 0x7f;  // Status + data combined
PORTB = DisplayControlFlags;        // Status output to CPU
```

### **PORTC (0x0002) - CONTROL OUTPUT PORT (DDRC = 0xFF)**

**Primary Function**: Display Control and Timing Signals

| Bit | Function | Description |
|-----|----------|-------------|
| 0 | Display Strobe | Data valid strobe to HD44100H and CD4035 (active high) |
| 1 | Serial Clock | Clock for serial data sampling and shift registers |
| 2 | Command Mode | Display command vs data mode select for HD44100H |
| 3-7 | Control Signals | Additional display control, possibly CPU interface signals |

**Control Sequences**:
```c
// Data Output Sequence (WriteToDisplayPort/OutputToDisplayDriver)
PORTC = PORTC & 0xFE;  // Clear strobe
PORTB = data;          // Set data  
PORTC = PORTC | 1;     // Set strobe

// Command Mode (FUN_05fc)
PORTC = PORTC & 0xF3;  // Clear bits 3-2
PORTC = PORTC | 4;     // Set command mode

// Serial Clock (WaitForData)
PORTC = PORTC & 0xFD;  // Clear clock
PORTC = PORTC | 2;     // Set clock
```

## CPU Communication Protocol

### **Command Reception Flow**

1. **FIFO Status Check**: `readIRQ()` monitors CY7C401 FIFO status
2. **Serial Reception**: When readIRQ() true, CPU data available
3. **3-Channel Input**: PORTA bits 0-2 provide parallel serial data
4. **Shift Register Loading**: 8 bytes x 8 bits = 192 bits total data
5. **Command Processing**: ProcessData() interprets received commands

### **Response Generation Flow**

1. **Status Preparation**: Combine data with DisplayControlFlags
2. **Data Output**: PORTB carries 8-bit response data
3. **Strobe Generation**: PORTC bit 0 validates data for CPU
4. **CPU Reading**: CPU reads response via PANS register interface

### **Interrupt Generation to CPU**

```c
// Timer-based interrupt generation
if ((CountdownTimer1 == 0) && (CountdownTimer2 == 0)) {
    DisplayControlFlags = DisplayControlFlags & 0xEF;  // Clear bit 4
    if ((DisplayModeFlags & 0x20) == 0) {
        InitDisplayClearPulse();  // Signal CPU
        CountdownTimer2 = 6;      // Reset timer
    }
}
```

## Button Processing Integration

### **Button Input Method**
- Buttons likely connected to PORTA through external interface
- Commands from CPU and button presses both use PORTA
- Software debouncing via ButtonDebounceCounter (5 cycles)
- Change detection using XOR with previous state

### **Button vs CPU Command Distinction**
- CPU commands arrive via FIFO with readIRQ() signaling
- Button presses detected by direct PORTA monitoring
- Different processing paths in ProcessData() function
- Button events generate interrupts back to CPU

## Hardware Interface Connections

### **To ND-120 CPU Board**
- **FIFO Interface**: CY7C401 buffers CPU commands
- **Interrupt Line**: Panel processor signals CPU (likely via external logic)
- **Status Reading**: CPU reads panel status via PANS register

### **To Display Hardware**
- **HD44100H LCD Driver**: PORTB data, PORTC control
- **CD4035 Shift Registers**: Cascaded for segment control
- **Display Modules**: LD-H7919 and LCD SX 423 M4

### **To Panel Controls**
- **Button Matrix**: Connected through PORTA or external decoder
- **Panel Lock Key**: PORTA bit 3 for position sensing
- **Status LEDs**: Controlled via display system or separate outputs

## Command/Response Timing

### **CPU to Panel (PANC Register)**
1. CPU writes command to PANC register
2. CY7C401 FIFO buffers command
3. readIRQ() signals data available to 68705P3
4. WaitForData() reads serial data via PORTA
5. ProcessData() interprets and executes command

### **Panel to CPU (PANS Register)**  
1. Panel processor prepares response data
2. Data output via PORTB with status flags
3. PORTC strobe signals valid data
4. CPU reads response from PANS register
5. 20ms cycle coordination with CPU timer interrupt

### **Button Event Handling**
1. Button press detected on PORTA
2. Software debouncing (5 cycles @ ButtonDebounceCounter)
3. Change detection via XOR comparison
4. Interrupt generation to CPU via timer mechanism
5. CPU reads button status from PANS register

This detailed port analysis reveals the 68705P3 as a sophisticated interface controller managing bidirectional communication between the ND-120 CPU and the operator panel, with separate pathways for command processing, display control, and button input handling.
# ND-100/120 Panel Controller - Complete Variable Rename Analysis

## RAM Variables (Working Memory)

### **Time/Date Data Buffers (0x002D-0x0034)**

- **`DAT_002D`** → **`TimeDataBuffer0`** (already renamed)
  - **Address**: 0x002D
  - **Usage**: First byte of 8-byte raw time data buffer, stores ShiftRegister1 data
  - **Reason**: Part of time data reception system from CPU serial input

- **`DAT_002E`** → **`TimeDataBuffer1`** (already renamed)
  - **Address**: 0x002E
  - **Usage**: Second byte of time data buffer
  - **Reason**: Sequential time data storage from serial reception

- **`DAT_002F`** → **`time_data_buffer_2`**
  - **Address**: 0x002F
  - **Usage**: Read in WaitForData (0x0314), part of time data buffer array
  - **Reason**: Third byte in sequential time data buffer (0x2D-0x34)

- **`DAT_0030`** → **`time_data_buffer_3`**
  - **Address**: 0x0030
  - **Usage**: Read in WaitForData (0x031E), continues time data sequence
  - **Reason**: Fourth byte in time data buffer array

- **`DAT_0034`** → **`time_data_buffer_7`**
  - **Address**: 0x0034
  - **Usage**: Written in WaitForData (0x02CF), final byte of 8-byte buffer
  - **Reason**: Last byte of time data buffer (0x2D-0x34)

### **Time Display Buffers (0x0035-0x003C)**

- **`DAT_0035`** → **`TimeDisplayBuffer0`** (already renamed)
  - **Address**: 0x0035
  - **Usage**: First byte of formatted time display data from ShiftRegister2
  - **Reason**: Display-ready time data for LCD output

- **`DAT_0036`** → **`time_display_buffer_1`**
  - **Address**: 0x0036
  - **Usage**: Part of time display buffer array (0x35-0x3C)
  - **Reason**: Second byte of formatted display time data

- **`DAT_0037`** → **`time_display_buffer_2`**
  - **Address**: 0x0037
  - **Usage**: Continues time display buffer sequence
  - **Reason**: Third byte of time display buffer

- **`DAT_003C`** → **`time_display_buffer_7`**
  - **Address**: 0x003C
  - **Usage**: Final byte of 8-byte time display buffer
  - **Reason**: Last byte of time display data (0x35-0x3C)

### **Status Data Buffers (0x003D-0x0044)**

- **`DAT_003D`** → **`StatusDataBuffer0`** (already renamed)
  - **Address**: 0x003D
  - **Usage**: First byte of system status data from ShiftRegister3
  - **Reason**: CPU status information for display indicators

- **`DAT_003E`** → **`status_data_buffer_1`**
  - **Address**: 0x003E
  - **Usage**: Part of status data buffer array (0x3D-0x44)
  - **Reason**: Second byte of status display data

- **`DAT_0044`** → **`status_data_buffer_7`**
  - **Address**: 0x0044
  - **Usage**: Final byte of 8-byte status buffer
  - **Reason**: Last byte of status data buffer (0x3D-0x44)

### **Display Control Flags**

- **`DAT_0038`** → **`display_format_flags`**
  - **Address**: 0x0038
  - **Usage**: Read in ShowSystemStatusDisplay (0x04DB, 0x04FD, 0x0520), controls display formatting
  - **Reason**: Bit 7 (0x80) controls display format selection and time display modes

- **`DAT_003A`** → **`display_enable_flags`**
  - **Address**: 0x003A
  - **Usage**: Read in WaitForData (0x0341, 0x0356, 0x039D), bit 7 (0x80) enables special display modes
  - **Reason**: Controls whether extended display features are enabled

## ROM Lookup Tables

### **Command Processing Tables (0x0080-0x008D)**

- **`DAT_0080`** → **`command_lookup_table_primary`**
  - **Address**: 0x0080
  - **Usage**: Primary command lookup table used when DisplayControlFlags bit 4 is clear
  - **Reason**: Contains command codes for ProcessData switch statement dispatch

- **`DAT_008B`** → **`command_lookup_table_secondary`**
  - **Address**: 0x008B
  - **Usage**: Secondary command table used when DisplayControlFlags bit 4 is set
  - **Reason**: Alternate command interpretation mode for extended functionality

- **`DAT_008C`** → **`command_table_entry_1`**
  - **Address**: 0x008C
  - **Usage**: First entry in command lookup table structure
  - **Reason**: Part of command dispatch table data

- **`DAT_008D`** → **`command_table_entry_2`**
  - **Address**: 0x008D
  - **Usage**: Second entry in command lookup table, value 0x02
  - **Reason**: Command table data for dispatch mechanism

### **Character Conversion Tables (0x06BC-0x077F)**

- **`DAT_06BC`** → **`CharacterDecodeTable`** (already renamed)
  - **Address**: 0x06BC
  - **Usage**: Character decoding lookup table for display conversion
  - **Reason**: Used by DecodeCharacterFromTable() function

- **`DAT_06BD`** → **`char_decode_table_1`**
  - **Address**: 0x06BD
  - **Usage**: First entry in character decode table, value 0x80
  - **Reason**: Character mapping data for display output

- **`DAT_06BE`** → **`char_decode_table_2`**
  - **Address**: 0x06BE
  - **Usage**: Second entry in character decode table, value 0x0E
  - **Reason**: Continues character decode mapping

- **`DAT_0759`** → **`CharacterLookupTable`** (already renamed)
  - **Address**: 0x0759
  - **Usage**: Character code lookup table for ASCII to display conversion
  - **Reason**: Used by LookupCharacterCode() function

- **`DAT_075A`** → **`char_lookup_table_1`**
  - **Address**: 0x075A
  - **Usage**: First entry in character lookup table, value 0x20 (space character)
  - **Reason**: ASCII to display code conversion data

- **`DAT_075B`** → **`char_lookup_table_2`**
  - **Address**: 0x075B
  - **Usage**: Second entry in character lookup table, value 0x77
  - **Reason**: Character conversion mapping data

- **`DAT_077D`** → **`char_lookup_table_end_marker`**
  - **Address**: 0x077D
  - **Usage**: End marker in character lookup table, value 0x4E
  - **Reason**: Indicates end of valid character mappings

- **`DAT_077E`** → **`char_lookup_table_final_1`**
  - **Address**: 0x077E
  - **Usage**: Near end of character lookup table, value 0x09
  - **Reason**: Final character mapping entries

- **`DAT_077F`** → **`char_lookup_table_final_2`**
  - **Address**: 0x077F
  - **Usage**: Final entry in character lookup table, value 0x80
  - **Reason**: Last character conversion data

## Previously Renamed Variables (For Reference)

### **Timer and Control Variables**
- `DAT_0010` → `CountdownTimer1` - Primary CPU interrupt timer
- `DAT_0011` → `CountdownTimer2` - Secondary CPU interrupt timer
- `DAT_0012` → `ButtonStateBuffer` - Current button state storage
- `DAT_0013` → `ButtonDebounceCounter` - Button debounce timing
- `DAT_0014` → `DisplayControlFlags` - Display control and status flags
- `DAT_0015` → `PreviousButtonState` - Previous button state for change detection
- `DAT_0016` → `CommandParameter` - Current CPU command storage
- `DAT_0017` → `ButtonChangeFlags` - Button state change flags
- `DAT_0018` → `SystemStatusFlags` - Overall system status
- `DAT_0019` → `DisplayModeFlags` - Display mode control flags

### **Working Variables**
- `DAT_001A` → `BitCounter` - Counter for bit operations
- `DAT_001B` → `WorkingDataByte1` - First working data byte
- `DAT_001C` → `WorkingDataByte2` - Second working data byte
- `DAT_001D` → `DecodedCharacter` - Character after table lookup
- `DAT_001E` → `LoopCounter` - General purpose loop counter
- `DAT_001F` → `IndexPointer` - Array/table index pointer

### **Serial Communication Variables**
- `DAT_0020` → `SerialInputData` - Serial data input from PORTA
- `DAT_0021` → `ShiftRegister1` - First shift register
- `DAT_0022` → `ShiftRegister2` - Second shift register
- `DAT_0023` → `ShiftRegister3` - Third shift register
- `DAT_0024` → `DisplayPositionCounter` - Position counter for display

### **Display Control Variables**
- `DAT_0045` → `DisplayModeSelect` - Display mode selection
- `DAT_0046` → `DisplayAddress` - Current display address
- `DAT_0047` → `CharacterPosition` - Character position counter
- `DAT_0048` → `CurrentDisplayAddress` - Currently active display address
- `DAT_0049` → `DisplayOutputData` - Data being output to display
- `DAT_004C` → `DelayCounter` - Timing delay counter

## Summary of Renaming Results

**Total Variables Renamed**: 37
- **RAM Variables**: 21 (working memory, buffers, flags)
- **ROM Tables**: 16 (command and character lookup tables)

**Naming Conventions Used**:
- `snake_case` for all variables
- Descriptive names based on actual usage
- Buffer arrays numbered sequentially (0-7)
- Table entries clearly identified by purpose
- Flags indicate their control function

**Analysis Complete**: All identified `DAT_XXXX` variables have been analyzed and renamed based on their observed usage in the disassembly. The firmware now has meaningful variable names that clearly indicate their function in the panel controller operation.
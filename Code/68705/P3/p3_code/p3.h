/*
 * MC68705P3 Microcontroller Firmware Emulator - Header File
 * Hardware Interface Definitions and Constants
 */

#ifndef MC68705_EMULATOR_H
#define MC68705_EMULATOR_H

#include <stdint.h>
#include <stdbool.h>

// Hardware Constants
#define MC68705_CRYSTAL_FREQ    2000000  // 2MHz crystal
#define FIFO_BUFFER_SIZE        512      // CY7C401 FIFO depth
#define SERIAL_PACKET_BITS      192      // 8 bytes × 3 channels × 8 bits
#define DISPLAY_COLUMNS         40       // Assumed display width
#define DISPLAY_ROWS            2        // Assumed display height

// Port Bit Definitions
// PORTA (Input Port) - Command reception and button input
#define PA_SERIAL_DATA_1        0x01     // Serial data channel 1 (active low)
#define PA_SERIAL_DATA_2        0x02     // Serial data channel 2 (active low)  
#define PA_SERIAL_DATA_3        0x04     // Serial data channel 3 (active low)
#define PA_LOCK_KEY             0x08     // Panel lock key position
#define PA_COMMAND_MASK         0x3F     // 6-bit command mask (bits 5-0)
#define PA_BUTTON_CHANGE        0x40     // Button state change flag
#define PA_STATUS_BIT           0x80     // Status/control bit

// PORTB (Output Port) - Display data and CPU responses
#define PB_DATA_MASK            0x7F     // 7-bit data output mask
#define PB_STATUS_BIT           0x80     // Status integration bit

// PORTC (Output Port) - Control signals and timing
#define PC_STROBE               0x01     // Data strobe signal
#define PC_SERIAL_CLOCK         0x02     // Serial sampling clock
#define PC_DISPLAY_CONTROL      0x04     // Display control signal

// Display Control Flags (DAT_0014)
#define DISP_FLAG_TABLE_SELECT  0x10     // Lookup table selection
#define DISP_FLAG_STATUS_1      0x20     // Status flag 1
#define DISP_FLAG_STATUS_2      0x40     // Status flag 2
#define DISP_FLAG_LOCK_STATE    0x80     // Lock key state

// System Status Flags (DAT_0019)
#define SYS_FLAG_DATA_READY     0x02     // Data ready for display
#define SYS_FLAG_BINARY_MODE    0x04     // Binary display mode
#define SYS_FLAG_TIME_MODE      0x10     // Time display mode
#define SYS_FLAG_MESSAGE_MODE   0x20     // Message display mode

// Command Categories
#define CMD_DISPLAY_UPDATE      0x00     // Display update operations
#define CMD_CONDITIONAL_UPDATE  0x01     // Conditional display update
#define CMD_MULTI_STAGE_UPDATE  0x02     // Multi-stage update
#define CMD_BUTTON_POLL_START   0x08     // Button polling operations start
#define CMD_BUTTON_POLL_END     0x0C     // Button polling operations end
#define CMD_DIRECT_OUTPUT_START 0x48     // Direct data output start
#define CMD_DIRECT_OUTPUT_END   0x4A     // Direct data output end
#define CMD_SERIAL_DATA_START   0x77     // Serial data reception start
#define CMD_SERIAL_DATA_END     0x7F     // Serial data reception end

// Dispatch Codes (from lookup table processing)
#define DISPATCH_DISPLAY_UPDATE     0x00     // Display update operations
#define DISPATCH_CONDITIONAL        0x02     // Conditional update
#define DISPATCH_MULTI_STAGE        0x04     // Multi-stage update
#define DISPATCH_HANDLER_56         0x06     // Command handler 0x56
#define DISPATCH_HANDLER_5A         0x08     // Command handler 0x5A
#define DISPATCH_HANDLER_5E         0x0A     // Command handler 0x5E
#define DISPATCH_HANDLER_6C         0x0C     // Command handler 0x6C
#define DISPATCH_BUTTON_POLL        0x10     // Button polling (wait for release)
#define DISPATCH_SPECIAL_STATUS     0xA2     // Special status return
#define DISPATCH_DIRECT_OUTPUT      0x90     // Direct data output
#define DISPATCH_SERIAL_START       0xEE     // Serial reception start
#define DISPATCH_SERIAL_END         0xFE     // Serial reception end

// Timer Constants
#define DEBOUNCE_COUNT              5        // Button debounce counter
#define SPECIAL_TIMER_VALUE         0x50     // Special command timer (80 decimal)
#define DISPLAY_REFRESH_TIMER       0x06     // Display refresh counter
#define TIMEOUT_COUNTER_INIT        0x30     // Timeout initialization value

// Memory Layout Constants
#define RAM_BASE                    0x0010   // RAM start address
#define MESSAGE_BUFFER_SIZE         4        // Message buffer length
#define TIME_DATA_BUFFER_SIZE       8        // Time data buffer length
#define DISPLAY_BUFFER_SIZE         8        // Display buffer length  
#define STATUS_BUFFER_SIZE          8        // Status buffer length

// ROM String Addresses (from disassembly)
#define ROM_STRING_ON               0x0098   // "ON " string
#define ROM_STRING_OFF              0x009C   // "OFF" string
#define ROM_STRING_DAY              0x00A0   // "DAY:" string
#define ROM_STRING_TIME             0x00A5   // "  TIME:" string
#define ROM_STRING_UTC              0x00AD   // "   UTC:" string
#define ROM_STRING_ADDRESS          0x00B5   // "ADDRESS:" string
#define ROM_STRING_COUNT            0x00BE   // "P COUNT:" string
#define ROM_STRING_YEAR             0x00C7   // "YEAR:" string
#define ROM_STRING_MONTH            0x00CD   // "  MONTH:" string

// Character Decode Table Addresses
#define ROM_CHAR_DECODE_TABLE       0x06BC   // Character decode table start
#define ROM_CHAR_LOOKUP_TABLE       0x0759   // Character lookup table start
#define ROM_CHAR_TABLE_END          0x077F   // Character table end

// Command Lookup Table Addresses  
#define ROM_CMD_TABLE_PRIMARY       0x0080   // Primary command lookup table
#define ROM_CMD_TABLE_SECONDARY     0x008B   // Secondary command lookup table

// Display Commands
#define LCD_FUNCTION_SET            0x38     // 8-bit, 2-line, 5x7 font
#define LCD_DISPLAY_ON              0x0C     // Display on, cursor off
#define LCD_ENTRY_MODE              0x06     // Increment, no shift
#define LCD_CLEAR_DISPLAY           0x01     // Clear display
#define LCD_CURSOR_HOME             0x02     // Return cursor home
#define LCD_SHIFT_LEFT              0x18     // Shift display left

// Function Prototypes - Core System Functions
void RESET(void);
void WaitForData(void);
uint8_t ProcessData(void);
void UpdateTimersAndWait(void);

// Function Prototypes - Display Functions
void DisplayTimeData(uint8_t buffer_base);
void ShowSystemStatusDisplay(void);
void ShowMessageAndTime(void);
void InitDisplayClearPulse(void);
void SendDisplayCommand(uint8_t cmd);
void WriteToDisplayPort(uint8_t data);
void OutputCharacterToDisplay(uint8_t character);
void DisplayStringUntilQuote(void);
void CalculateDisplayPosition(uint8_t position);
void DisplayBinaryBars(void);
void DisplayBinaryDigits(void);
void DisplayDecimalPoint(void);

// Function Prototypes - Character Processing
uint8_t DecodeCharacterFromTable(void);
uint8_t LookupCharacterCode(uint8_t code);

// Function Prototypes - Command Handlers
uint8_t CompleteCommandProcessing(uint8_t status);
uint8_t cmd_display_update(void);
uint8_t cmd_conditional_update(void);
uint8_t cmd_multi_stage_update(void);
uint8_t cmd_handler_10(void);
uint8_t cmd_handler_56(void);
uint8_t cmd_handler_5a(void);
uint8_t cmd_handler_5e(void);
uint8_t cmd_handler_6c(void);
uint8_t cmd_handler_a4(void);

// Function Prototypes - Hardware Interface
bool readIRQ(void);
void setExternalInput(uint8_t input);
void setIRQStatus(bool status);

// Function Prototypes - Simulation Helpers
void simulate_button_press(uint8_t button_mask);
void simulate_cpu_command(uint8_t command);
void simulate_serial_data(uint8_t *time_data, uint8_t *display_data, uint8_t *status_data);
void print_system_state(void);
void print_buffer_contents(void);

// Error Codes
typedef enum {
    EMU_SUCCESS = 0,
    EMU_ERROR_INVALID_COMMAND,
    EMU_ERROR_TIMEOUT,
    EMU_ERROR_HARDWARE_FAULT,
    EMU_ERROR_BUFFER_OVERFLOW,
    EMU_ERROR_CHECKSUM_FAIL
} emulator_error_t;

// System State Enumeration
typedef enum {
    STATE_RESET = 0,
    STATE_INIT,
    STATE_WAIT_DATA,
    STATE_PROCESS_COMMAND,
    STATE_SERIAL_RECEIVE,
    STATE_DISPLAY_UPDATE,
    STATE_BUTTON_POLL,
    STATE_ERROR
} system_state_t;

// Hardware Configuration Structure
typedef struct {
    uint32_t crystal_frequency;
    uint16_t fifo_depth;
    uint8_t display_columns;
    uint8_t display_rows;
    bool lock_key_enabled;
    bool debug_mode;
} hardware_config_t;

// Statistics Structure
typedef struct {
    uint32_t commands_processed;
    uint32_t serial_packets_received;
    uint32_t display_updates;
    uint32_t button_presses;
    uint32_t timeouts;
    uint32_t errors;
} system_stats_t;

// External Global Variables (defined in main .c file)
extern system_state_t current_state;
extern hardware_config_t hw_config;
extern system_stats_t stats;

#endif // MC68705_EMULATOR_H
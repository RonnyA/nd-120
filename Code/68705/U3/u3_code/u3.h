/*
 * MC68705 ND-120 Performance Monitor Firmware Emulator - Header File
 * Reconstructed from Ghidra disassembly analysis
 * 
 * Hardware: Motorola 68705 Panel/Calendar Controller
 * System: ND-120 Performance Monitor with Real-Time Clock
 */

#ifndef MC68705_EMULATOR_H
#define MC68705_EMULATOR_H

#include <stdint.h>
#include <stdbool.h>
#include <string.h>

/*
 * Hardware Constants and Addresses
 */

// MC68705 Register Addresses
#define PORTA_ADDR      0x0000
#define PORTB_ADDR      0x0001
#define PORTC_ADDR      0x0002
#define PORTD_ADDR      0x0003
#define DDRA_ADDR       0x0004
#define DDRB_ADDR       0x0005
#define DDRC_ADDR       0x0006
#define DDRD_ADDR       0x0007
#define TDR_ADDR        0x0008
#define TCR_ADDR        0x0009
#define MR_ADDR         0x000A
#define PCR_ADDR        0x000B

// System RAM Layout
#define RAM_START       0x0010
#define RAM_END         0x007F
#define WORKING_BUFFER  0x0027
#define WORKING_BUF_END 0x0046

// ROM Data Tables (from disassembly)
#define ROM_CHAR_TABLE_1_ADDR   0x0D12
#define ROM_CHAR_TABLE_2_ADDR   0x0D1A

// Function Entry Points (from disassembly)
#define MAIN_LOOP_ADDR                      0x0110
#define LOAD_DISPLAY_CHAR_ADDR              0x01B4
#define FORMAT_7SEGMENT_ADDR                0x01ED
#define PROCESS_DISPLAY_ALT_ADDR            0x037B
#define PROCESS_7SEG_BIT_MANIP_ADDR         0x0479
#define DELAY_SAMPLE_PORTC_ADDR             0x04A7
#define PROCESS_PANC_COMMAND_ADDR           0x04D8
#define CALC_CPU_UTIL_PERCENT_ADDR          0x066B
#define PROCESS_PERF_STATS_ADDR             0x0694
#define UPDATE_CPU_RING_STATS_ADDR          0x06B2
#define OUTPUT_RTC_TIME_ADDR                0x06BE
#define CONVERT_TIME_OFFSET_ADDR            0x0715
#define CALC_RTC_DATE_TIME_ADDR             0x0803
#define TIMER_1200HZ_INTERRUPT_ADDR         0x08C8
#define INCREMENT_RTC_COUNTERS_ADDR         0x08F9
#define SHIFT_CPU_UTIL_HISTORY_ADDR         0x0948
#define MONITOR_LEV0_LHIT_ADDR              0x0985
#define STROBE_WMM_READ_FIFO_ADDR           0x09BC
#define OUTPUT_RESPONSE_ND120_ADDR          0x09C5
#define SAMPLE_ND120_CPU_STATUS_ADDR        0x09D4
#define OUTPUT_STATUS_CODE_1_ADDR           0x09EE
#define INITIALIZE_MM58274_RTC_ADDR         0x0AC0

/*
 * Timer and Clock Configuration
 */

// System clocks
#define CPU_CLOCK_HZ        4000000     // 4MHz main CPU clock
#define TIMER_CLOCK_HZ      38400       // 38.4kHz timer input (PANOSC)
#define TIMER_PRESCALER     32          // Timer prescaler value
#define INTERRUPT_RATE_HZ   1200        // 38.4kHz ÷ 32 = 1200Hz
#define SAMPLE_PERIOD_US    833         // 833.33μs between samples

// Timer Control Register (TCR) bits
#define TCR_TIM_BIT         0x01        // Timer interrupt enable
#define TCR_TIN_BIT         0x02        // Timer input select
#define TCR_TIE_BIT         0x04        // Timer external input enable
#define TCR_PS_MASK         0x38        // Prescaler mask (bits 5-3)
#define TCR_PS_DIV32        0x28        // Prescaler ÷32 value (101b)

// Standard TCR configuration: 0x35 = TIM=1, TIN=1, TIE=1, PS=101
#define TCR_CONFIG_1200HZ   0x35

/*
 * Port D Signal Definitions (ND-120 CPU Status)
 */

// Port D bit assignments
#define PORTD_EMP_N_BIT     0x80        // PD7: /EMP_n FIFO/Panel enable
#define PORTD_GND_BIT       0x40        // PD6: GND (tied to ground)
#define PORTD_LEV0_BIT      0x20        // PD5: LEV0 (HIGH=idle, LOW=busy)
#define PORTD_LHIT_BIT      0x10        // PD4: LHIT (HIGH=cache hit)
#define PORTD_IONI_BIT      0x08        // PD3: IONI (Interrupt system ON)
#define PORTD_PONI_BIT      0x04        // PD2: PONI (Memory protection ON)
#define PORTD_PCR_MASK      0x03        // PD[1:0]: PCR Ring (0-3)

/*
 * PANC/PANS Register Interface
 */

// PANC command byte format
#define PANC_CMD_MASK       0x07        // Bits 2-0: Command type
#define PANC_DAT_BIT        0x08        // Bit 3: Data direction
#define PANC_FLAGS_MASK     0xF0        // Bits 7-4: Command flags

// PANS status register format  
#define PANS_RPAN_MASK      0x00FF      // Bits 7-0: Response data
#define PANS_CMND_MASK      0x0700      // Bits 10-8: Last command
#define PANS_RDY_BIT        0x1000      // Bit 12: Command completed
#define PANS_DAT_BIT        0x2000      // Bit 13: Last command requested data
#define PANS_FIP_BIT        0x4000      // Bit 14: FIFO ready
#define PANS_PAN_BIT        0x8000      // Bit 15: Panel installed

/*
 * Display Control Flags
 */

#define DISPLAY_MODE_MASK       0x1A    // Display mode bits
#define DISPLAY_FEATURE_BIT     0x04    // System feature enable
#define DISPLAY_STATS_BIT       0x02    // Statistics display mode
#define DISPLAY_ALT_MODE_BIT    0x08    // Alternative display mode
#define DISPLAY_TIME_MODE_BIT   0x10    // Time display mode

/*
 * System Configuration Flags
 */

#define CONFIG_TEST_MODE_BIT    0x04    // Test mode vs normal mode
#define CONFIG_FORMAT_MASK      0x18    // Test format selection
#define CONFIG_OPTIONS_MASK     0x03    // Test mode options

/*
 * MM58274 RTC Control
 */

// Port B RTC control
#define PORTB_ROCLK_BIT     0x04        // PB2: /ROCLK (0=reset, 1=enable)
#define PORTB_READY_BIT     0x10        // PB4: Ready signal
#define PORTB_STATUS_BIT    0x20        // PB5: Status signal

/*
 * Performance Monitoring Constants
 */

// Timing hierarchy (interrupt-driven counters)
#define TIMER_16_CYCLES         16      // 13.3ms intervals
#define TIMER_200_CYCLES        200     // 167ms intervals  
#define TIMER_2_CYCLES          2       // 333ms intervals

// History buffer management
#define CPU_UTIL_HISTORY_SIZE   3       // 15-sample sliding window (simplified)
#define CPU_UTIL_BUFFER_MASK    0xFE    // Buffer shift mask

/*
 * Function Prototypes
 */

// Main system functions
void wait_for_fifo_commands_and_process(void);
void timer_1200hz_cpu_performance_monitor(void);
void initialize_mm58274_rtc_chip(void);

// Command processing
void process_panc_command_from_fifo(void);
uint8_t strobe_wmm_read_from_fifo(void);
void output_response_to_nd120_idb(void);

// Display processing
void load_display_character_data_from_rom(void);
void format_7segment_display_patterns(void);
void process_7segment_display_bit_manipulation(void);
void process_display_data_alternative_mode(void);

// Performance monitoring
void sample_nd120_cpu_status_signals(void);
void update_cpu_ring_poni_ioni_statistics(void);
void monitor_lev0_lhit_signals_update_display(void);
void calculate_cpu_utilization_percentage(void);
void process_performance_statistics(void);
void shift_cpu_utilization_history_buffer(void);

// RTC functions
void increment_software_rtc_counters(void);
void delay_and_sample_port_c(void);

// Simulation functions
void display_system_status(void);
void simulate_ldpanc_command(uint8_t cmd_byte, uint8_t *params, int param_count);
void simulate_epans_read(void);
void simulate_nd120_cpu_activity(uint8_t ring, bool poni, bool ioni, bool lev0, bool lhit);

/*
 * Utility Macros
 */

// Bit manipulation helpers
#define SET_BIT(reg, bit)       ((reg) |= (bit))
#define CLEAR_BIT(reg, bit)     ((reg) &= ~(bit))
#define TOGGLE_BIT(reg, bit)    ((reg) ^= (bit))
#define TEST_BIT(reg, bit)      (((reg) & (bit)) != 0)

// Port D status extraction
#define GET_PCR_RING(portd)     ((portd) & PORTD_PCR_MASK)
#define IS_CPU_IDLE(portd)      TEST_BIT(portd, PORTD_LEV0_BIT)
#define IS_CACHE_HIT(portd)     TEST_BIT(portd, PORTD_LHIT_BIT)
#define IS_IONI_ON(portd)       TEST_BIT(portd, PORTD_IONI_BIT)
#define IS_PONI_ON(portd)       TEST_BIT(portd, PORTD_PONI_BIT)
#define IS_FIFO_ACTIVE(portd)   TEST_BIT(portd, PORTD_EMP_N_BIT)

// Command parsing
#define GET_PANC_CMD(cmd)       ((cmd) & PANC_CMD_MASK)
#define IS_PANC_INPUT(cmd)      TEST_BIT(cmd, PANC_DAT_BIT)
#define GET_PANC_FLAGS(cmd)     (((cmd) & PANC_FLAGS_MASK) >> 4)

/*
 * Debug and Tracing
 */

#ifdef DEBUG_TRACE
#define DEBUG_TRACE_MARKER(addr) do { \
    debug_trace_marker = (addr); \
    printf("TRACE: 0x%04X\n", addr); \
} while(0)
#else
#define DEBUG_TRACE_MARKER(addr) do { \
    debug_trace_marker = (addr); \
} while(0)
#endif

/*
 * Error Codes and Status
 */

typedef enum {
    STATUS_OK = 0,
    STATUS_FIFO_TIMEOUT,
    STATUS_INVALID_COMMAND,
    STATUS_RTC_ERROR,
    STATUS_SOFT_RESET,
    STATUS_HARDWARE_ERROR
} SystemStatus;

/*
 * External Global Variables
 */

extern uint8_t debug_trace_marker;

#endif /* MC68705_EMULATOR_H */
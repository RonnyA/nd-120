/**************************************************************************
** ND120 - Tang Nano 20K build defines                                   **
**                                                                       **
** This file MUST be the FIRST Verilog file in the Gowin project so the  **
** macros are visible to every following file (GowinSynthesis compiles   **
** the file list as one ordered compilation unit).                       **
** See docs/build-defines.md for what each define does.                  **
**                                                                       **
** Last reviewed: 8-JUL-2026                                             **
** Ronny Hansen                                                          **
***************************************************************************/

// FPGA vendor: Gowin primitives (PROM_19 drops the Xilinx BRAM ROM path)
`define GOWIN

// Board target marker
`define TARGET_TANG20K

// Edge-triggered flip-flop mode (CYC_36 generated-clock handling)
`define FPGA_FF_MODE

// Bitstream-preloaded WCS; the runtime microcode load phase is skipped and
// the microcode PROM is never read (required to fit the 828 Kbit BSRAM)
`define SKIP_WCS_LOAD

// Main memory = embedded 8 MB SDRAM through MEM_RAM_49_SDRAM (2 banks, 4 MB)
`define MAIN_RAM_SDRAM

// Slow bring-up clocking (G1): first Gowin build measured CPU-domain Fmax at
// 9.38 MHz (31 levels) with derived-clock domains down to 4.7 MHz - the known
// derived-clock architecture problem. Until the clock-enable refactor closes
// timing at 27 MHz, run CPU/bus at 6.75 MHz (SDRAM pair at 13.5 MHz), which
// sits under every measured Fmax with margin. Comment this out for the full
// 27/54 MHz build (gowin_rpll_27_54.v switches on the same define).
`define TANG_SLOW_BRINGUP

// Clock/baud parameters - keep ALL derived counts slaved to these
`ifdef TANG_SLOW_BRINGUP
`define BOARD_CLK_FREQ 6_750_000
`else
`define BOARD_CLK_FREQ 27_000_000
`endif
`define UART_BAUD_RATE 9600

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

// Packed main memory: store 16 DATA bits only, two ND words per 32-bit SDRAM
// location (DQM lane-masked writes, parity computed on read). CPU keeps the
// full 4 MB in the LOWER half of the chip; the upper 4 MB is reserved for the
// nd_storage disk-image cache. Semantics pinned by docs/nd120-parity-analysis.md;
// tbs: sdram-bridge/sim test-pack16 / test-pack16-part. Only meaningful with
// MAIN_RAM_SDRAM; no effect on Verilator/Basys3 builds.
`define ND_SDRAM_PACK16

// nd_storage device port on the SDRAM backend (requires ND_SDRAM_PACK16):
// a start/busy/done port in its own stor_clk domain that reads/writes whole
// 32-bit locations at {1'b1, mem_addr} - the upper-half storage region ONLY,
// the leading 1 is forced inside MEM_RAM_49_SDRAM so device traffic physically
// cannot reach the CPU's memory. This is what nd_tape_sdfat_source uses to
// stage BOOT.BPUN off the SD card for the '400$' tape boot.
// Threaded ND120_TANG20K_TOP -> ND120_CORE -> ND3202D -> MEM_43 -> the backend.
// tb: sdram-bridge/sim test-storage-port.
`define ND_STORAGE_PORT

// ---- Clock variant selection (slow / crawl / full) ----------------------
// Slow bring-up clocking (G1): first Gowin build measured CPU-domain Fmax at
// 9.38 MHz (31 levels) with derived-clock domains down to 4.7 MHz - the known
// derived-clock architecture problem. Until the clock-enable refactor closes
// timing at 27 MHz, run CPU/bus at 6.75 MHz (SDRAM pair at 13.5 MHz), which
// sits under every measured Fmax with margin.
//
// Crawl bring-up (P0 mechanism probe): halve the slow bring-up again -
// CPU/bus 3.375 MHz, SDRAM pair 6.75 MHz. The probe .tr measured the
// CPU-domain Fmax at 4.84 MHz, so at 3.375 MHz the SAME netlist meets
// timing. Crawl = TANG_CRAWL_BRINGUP defined IN ADDITION to
// TANG_SLOW_BRINGUP (it overrides the PLL and clock counts).
//
// The variant is selected WITHOUT editing this file: the build flows
// pre-define TANG_VARIANT_FULL or TANG_VARIANT_CRAWL on top of this
// compilation unit (OSS: `make VARIANT=full|crawl|slow` passes -D flags;
// Gowin: `gowin_build.ps1 -Variant ...` emits build/tang20k_variant.v as
// the first project file). No variant define = slow bring-up, the same
// default as before. See docs/tang20k-build-flows.md.
`ifdef TANG_VARIANT_FULL
  // full speed 27/54 MHz: neither SLOW nor CRAWL defined
`elsif TANG_VARIANT_CRAWL
  `define TANG_SLOW_BRINGUP
  `define TANG_CRAWL_BRINGUP
`else
  `define TANG_SLOW_BRINGUP
`endif

// Clock/baud parameters - keep ALL derived counts slaved to these
`ifdef TANG_CRAWL_BRINGUP
`define BOARD_CLK_FREQ 3_375_000
`elsif TANG_SLOW_BRINGUP
`define BOARD_CLK_FREQ 6_750_000
`else
`define BOARD_CLK_FREQ 27_000_000
`endif
`define UART_BAUD_RATE 9600

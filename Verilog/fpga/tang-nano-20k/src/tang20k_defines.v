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

// ---- Storage device select (Ronny 19-JUL: don't carry tape+floppy at once) --
// TANG_FLOPPY = floppy-only build (1560&, ND_FLOPPY_DMA + nd_storage FLOPPY1.IMG
// client; NO tape). Comment it out for the DEFAULT tape-only build (400$, the
// proven silicon config). Consumed by ND120_TANG20K_TOP.v (TANG_INC_TAPE/FLOPPY)
// and by the SDFAT_NO_STORAGE_CHECK guard below.
`define TANG_FLOPPY

// ---- TAPE-ONLY SD-FAT reader slimming (docs/fat-reader-slimming-plan.md) ----
// The Tang tape boot path is READ-ONLY of a contiguous boot file. These cuts
// reclaim FPGA LUT+ALU so the OSS placer fits. They are SAFE ONLY while the SD
// path is tape-read-only; REMOVE them when a floppy/SMD build is added here
// (random-access / writeback needs the full FAT reader and the contiguity
// gate).
//
//   SDFAT_NO_STORAGE_CHECK  - drop the mount-time contiguity checker
//                             (nd_storage_fatchk.v, ~1177 LUT+ALU); the card
//                             recipe alone guarantees a contiguous boot image.
//                             Mount M_CHK passes straight through. ENABLED FOR
//                             TAPE ONLY - a floppy build (TANG_FLOPPY) needs the
//                             contiguity gate back (random access), so the cut
//                             is guarded off there.
`ifndef TANG_FLOPPY
`define SDFAT_NO_STORAGE_CHECK
`endif

//   SDFAT_NO_LFN            - strip VFAT long-filename parsing in
//                             sd_file_reader.v (~1800 LUT+ALU); files matched
//                             by 8.3 short name only. *** NOT ENABLED ***:
//                             the tape client searches for "BOOT.BPUN"
//                             (nd_tape_sdfat_source.v FILE0_NAME), whose 4-char
//                             ".BPUN" extension is NOT 8.3-representable - FAT
//                             stores it as a mangled short name (BOOT~1.BPU)
//                             plus a VFAT long entry, so the name is only
//                             reachable via LFN. Enabling this cut breaks the
//                             tape open (verified: oerr=1). To claim the saving,
//                             first rename the boot file to a real 8.3 name
//                             (<=8 base, <=3 ext) and update FILE0_NAME to
//                             match; THEN uncomment the line below. The ifdef
//                             machinery in sd_file_reader.v is implemented and
//                             validated - this is a one-line flip once renamed.
// `define SDFAT_NO_LFN

//   TANG_GRANT_CAPTURE     - DEBUG PROBE for the masked-level-10 grant.
//                            Repurposes the on-chip 512-sample analyzer to
//                            record {PIL[3:0], CSA[11:0]} and trigger on PIL
//                            entering level 10 (448 pre + 64 post). On the
//                            wedge it takes the console TX and streams 512
//                            hex lines "hhhh" (PIL = hex digit 1, CSA = lower
//                            3 hex digits, octal-decode the CSA). Reveals
//                            whether PIL->10 runs the normal level-switch
//                            microcode (PLINT 01133 / LVSWP 01146-01155) or
//                            bypasses it. See ANALYSIS-cga-intr-masked-grant-
//                            root-cause.md sec 3c. Instrumentation only; leave
//                            OFF for normal builds.
`define TANG_GRANT_CAPTURE

//   TANG_NO_CONKICK - DIAGNOSTIC: disable the IO_37 console-pacing STAT3 pulse
//   (the un-original missing-68705 stand-in) so console traffic raises NO panel
//   request. Tests whether the conkick is the PAN source of the phantom macro-
//   interrupt / PIL->10 wedge. If the wedge vanishes, this is the faithful fix.

//   TANG_NO_RTC_PAN - DIAGNOSTIC: drop the RTC's contribution to PAN (panel
//   request). With conkick already off, this removes the last PAN source. If
//   the PIL->10 wedge vanishes, the held RTC PAN is the confirmed trigger.
// `define TANG_NO_IOXERR   (turned OFF for IREQ capture - let bit10/IOXERR show)

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

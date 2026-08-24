# Project History

Compressed history of the work progress on the ND-120 recreation:

| Date | Area | Description |
|------|------|-------------|
| 11. March 2023 | DOC | Received Design Documentation from Lasse Bockelie |
| 21. August 2023 | SCHEM | Logisim Drawings completed for DGA and DELILAH/CGA |
| 03. December 2023 | CPU | Using Logisim drawings to start generate Verilog files for DGA and CGA |
| 12. December 2023 | CPU | Starting to consolidate all information about PAL chips (PNG for PALASM code, OCR to TXT and write Verilog version of PAL code) |
| 26. December 2023 | SCHEM | Logisim drawings of CPU Board 3202D completed |
| 27. December 2023 | CPU | Using Logisim drawings to start generate Verilog files for CPU Board 3202D |
| 11. January 2024 | CPU | Most PALASM code has been ported to Verilog |
| January-June 2024 | CPU | Adding support chips, refactoring and bugfixing. Adding tests and test results |
| April 2024 | CPU | Control store finished in Verilog (sheets 16, 18, 19, 20, 21, 22 and ACAL 17); the whole CPU board compiles in Verilator for the first time; microcode moved into block RAM as hex files; every `inout` split into separate IN and OUT ports so the design can be synthesised at all |
| May 2024 | TEST | Support-chip and PAL cleanup, first testbenches and recorded test results |
| June-November 2024 | | No work done |
| 9. November 2024 | CPU | Starting up again after a long break. Cleaning up code, refactoring and testing. Connecting everything together. |
| November 2024 | CPU | Code standardised for synthesis: the `s_` internal-signal convention, module and top-file renaming, and the first simulation harness for the whole 3202D board |
| 20. November 2024 | CPU | Verilator - Microcode is loaded from ROM to DRAM. MACL microcode starts but fail on STACK operations, and fails on COND operations. |
| 13. December 2024 | CPU | Verilator - Microcode MACL starts, CPU test code runs. OPCOM is initialized and communication over UART works. |
| 29. Januar 2025 | TEST | Verilator - Testprogram 'INSTRUCTION-B.BPUN' (204384B 83.11.01) loads and starts. 7 out of 14 tests succeed. |
| January 2025 | CPU | First transcription errors caught by re-reading the schematics: swapped inputs in BRKDET and TBUF, and PAL 45001B's TEST pin wired to a dead net. BPUN programs can now be loaded from the command line |
| 22. Mars 2025 | DEV | Verilator & C++ - Interface with ND BUS via BIF module to C connector. Added support for Papertape reader and Floppy PIO written in C++ |
| 1. June 2025 | DOC | Reverse engineered the ROM chips for the panel controller's with help of Ghidra |
| June 2025 | CPU | Signal-documentation sweep across the CGA, MIC, MMU and I/O modules, and the first debug probes (control store address trace, DEBUGFLAG) |
| November 2025 | FPGA | First Vivado campaign: latch analysis, latch-to-flip-flop phase 1, the first `xc7a35t` (Basys3) constraints, and compile-time RAM sizing that separates simulator memory from FPGA block RAM |
| March-April 2026 | FPGA | Basys3 bring-up: Vivado batch build and lint scripts, 16-LED / 7-segment / ILA debug infrastructure, combinational-loop and block-RAM-inference fixes, `LATCH.v` rerouted through `sysclk`, and the MASEL race experiment tried and reverted |
| 7. July 2026 | SILICON | OPCOM boots on Basys3 hardware (tag `fpga-opcom-working-basys3`); FF-mode clock architecture fixes |
| 11. July 2026 | SILICON | SD/FAT stack proven on Tang Nano 20K hardware (read+write); microcode analysis proves the self-test never touches memory parity -> packed 16-bit SDRAM storage (`ND_SDRAM_PACK16`): CPU keeps 4 MB, 4 MB freed for the disk cache |
| 12. July 2026 | FPGA | Dual-toolchain Tang builds: OSS CAD Suite (yosys/nextpnr) primary, Gowin EDA backup; nextpnr closes the full 27/54 MHz clock target with >2x margin |
| 13. July 2026 | FPGA | Basys3 SD-Pmod port; memory-backend speed validation vs the no-wait-state protocol for every board; Cmod A7-35T activated (first 27 MHz BRAM build + SRAM bridge plan) |
| 13. July 2026 | TEST | Instruction validation campaign complete: 13/13 testable INSTRUCTION-B areas pass vs ND-110 golden traces; MACL self-test clean (STERR=0); two CPU transcription bugs found and fixed (MPY product low word, ROT/shift control) |
| 14. July 2026 | SILICON | Board-independent `ND120_CORE` extracted from `ND120_TOP`; Tang Nano 20K boots the papertape from a real SD card - proven on silicon |
| 15. July 2026 | CPU | RUN test area unblocked: Am2914 interrupt status fence made default, MOR (memory-out-of-range) wired to level 12; 29 new interrupt/trap gate-level testbenches |
| 19. July 2026 | SILICON | **First CPU boot on FPGA silicon** (Tang Nano 20K) - WCS read-address transparent-latch fix |
| 20. July 2026 | DEV | Portable C device cores (NDDeviceCore) added as a submodule; ND-BUS seam gate validates the C cores against the real `ND_BUS_SLAVE.v` in Verilator |
| 23.-26. July 2026 | DEV | ND-BUS device campaign: floppy/SMD/DMA IOX conformance testbenches; DMA master validated against the real bus arbiter |
| 27. July 2026 | DEV | Floppy boot (`1560&`) works in Verilator - FLOMON + TPE monitor load from a floppy image (DMA zero-word capture fix) |
| 30. July 2026 | SILICON | PAL transcription audit vs the original PALASM: 8 equation fixes; PAGING test suite passes 11/11 on Tang silicon (MMU page-table fix in PAL 44306A) |
| 31. July 2026 | SILICON | MOVEW APT-to-APT word-drop and double-trap phantom-vector-7 fixed; full INSTRUCTION multi-level run (levels 1-9) passes clean on Tang silicon |
| 03.-04. August 2026 | DEV | SMD illegal-load and status-read conformance with real CHS->LBA mapping; ST506/8-inch Winchester disc controller written in RTL at IOX 500 |
| 04. August 2026 | FPGA | Parity is never stored on an FPGA target (computed on the read path instead); stale SDRAM bank map corrected |
| 10. August 2026 | DEV | SD storage hub reworked: per-client ports instead of flat concatenations, per-client bus slices gated so a dropped one cannot hide, failure reasons carried out to each controller's status, sub-block writes served by read-modify-write |
| 10. August 2026 | CPU | Sheet-20 control-store capture was missing, so `TRA CS` read 000000; CDLBD's own output was absent from the LBD wired-OR; ALD strap set to bootstrap-load the Winchester |
| 11. August 2026 | CPU | PAL/sheet audit batch, eight fixes: parity could never be reported (sheets 43 and 46), the cache comparator was fed the wrong bus and the wrong tag bits (sheets 24 and 27), the PPN<->IDB transceiver outputs were ungated (sheet 28), the ND-bus data lines were not released on direction change (sheet 10), and the BANK/MWRITE idle condition was inverted (sheet 45) |
| 11. August 2026 | FPGA | `ND120_NO_CACHE` compile-time cache removal - the machine reports the cache as disabled, matching the board's own SW1 switch |
| 21. August 2026 | FPGA | Nexys 4 DDR board port added |
| 22. August 2026 | CPU | IDB combinational ring cut - FIDBO is OUTMUX-only and the PCR readback is registered; BRAM inference for main RAM and sysclk edge-capture for the parity-error latches |
| 23. August 2026 | CPU | Level-10 interrupt request was wired to `BINPUT~` (sheet 5C) |
| 24. August 2026 | SILICON | **SINTRAN III boots on the Tang Nano 20K.** The memory bank was decoded from the wrong side of the bus transceiver (`ND3202D.v:533`), so every DMA write landed in BANK0 - disc data reached the right row in the wrong bank and the CPU fetched zeros from a page nothing had written, halting in ERRFATAL after exactly 143 s on every boot |
| 24. August 2026 | FPGA | 42 storage seam nets were implicit 1-bit (declared below first use); moving the declarations took `EX3638` from 42 to 0 and made the disc-activity LEDs work. Winchester read cache re-enabled |
| 24. August 2026 | SILICON | Clock raised from 6.75 MHz: a 13.5 MHz variant added that closes with 0 setup violations, and 27 MHz boots SINTRAN and is visibly faster. Gowin puts the CPU-domain Fmax at 17.7-19.6 MHz and reports 1667 setup violations at 27 MHz, so that speed is fast but not timing-clean; whether it is actually correct is still open |
| 24. August 2026 | TEST | Regression guards for the bank decode (`make test-bdbank`) and for flip-flop mode on every board (`make test-no-latches`); board `preflight.sh` and a hard sim log-size cap |

## Area tags

Every entry carries one area tag. Choose it by **where the result landed, not
where the work happened**: a PAL fix proven on a board is `SILICON`, the same
fix proven only in Verilator is `CPU`. If a day produced two results in
different areas, write two rows for that date rather than tagging one row twice.

The set is fixed. Do not invent new tags - if something genuinely does not fit,
change this list deliberately.

| Tag | Covers |
|-----|--------|
| `DOC` | Original design documentation, ROM dumps, reverse engineering of the paper and the chips |
| `SCHEM` | Logisim-Evolution schematics |
| `CPU` | CPU and board logic in Verilog, including the PAL conversions and the bug fixes, proven in simulation |
| `DEV` | Peripherals and the ND bus: papertape, floppy, SMD disc, DMA, SD storage |
| `TEST` | Verification: testbenches, instruction campaigns, regression gates |
| `FPGA` | Synthesis, constraints, boards, toolchains, debug infrastructure |
| `SILICON` | Proven working on real hardware |

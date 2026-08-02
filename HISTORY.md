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

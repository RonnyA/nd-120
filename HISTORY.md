# Project History

Compressed history of the work progress on the ND-120 recreation:

| Date | Description |
|------|-------------|
| 11. March 2023 | Received Design Documentation from Lasse Bockelie |
| 21. August 2023 | Logisim Drawings completed for DGA and DELILAH/CGA |
| 03. December 2023 | Using Logisim drawings to start generate Verilog files for DGA and CGA |
| 12. December 2023 | Starting to consolidate all information about PAL chips (PNG for PALASM code, OCR to TXT and write Verilog version of PAL code) |
| 26. December 2023 | Logisim drawings of CPU Board 3202D completed |
| 27. December 2023 | Using Logisim drawings to start generate Verilog files for CPU Board 3202D |
| 11. January 2024 | Most PALASM code has been ported to Verilog |
| January-June 2024 | Adding support chips, refactoring and bugfixing. Adding tests and test results |
| June-November 2024 | No work done |
| 9. November 2024 | Starting up again after a long break. Cleaning up code, refactoring and testing. Connecting everything together. |
| 20. November 2024 | Verilator - Microcode is loaded from ROM to DRAM. MACL microcode starts but fail on STACK operations, and fails on COND operations. |
| 13. December 2024 | Verilator - Microcode MACL starts, CPU test code runs. OPCOM is initialized and communication over UART works. |
| 29. Januar 2025 | Verilator - Testprogram 'INSTRUCTION-B.BPUN' (204384B 83.11.01) loads and starts. 7 out of 14 tests succeed. |
| 22. Mars 2025 | Verilator & C++ - Interface with ND BUS via BIF module to C connector. Added support for Papertape reader and Floppy PIO written in C++ |
| 1. June 2025 | Reverse engineered the ROM chips for the panel controller's with help of Ghidra |
| November 2025 | Vivado synthesis push begins: latch-to-FF conversion Phase 1, first xc7a35t (Basys3) constraints |
| March-April 2026 | Basys3 FPGA bring-up: Vivado batch build/lint scripts, LED/7-seg/ILA debug infrastructure, combinational-loop and BRAM-inference fixes |
| 7. July 2026 | OPCOM boots on Basys3 hardware (tag `fpga-opcom-working-basys3`); FF-mode clock architecture fixes |
| 11. July 2026 | SD/FAT stack proven on Tang Nano 20K hardware (read+write); microcode analysis proves the self-test never touches memory parity -> packed 16-bit SDRAM storage (`ND_SDRAM_PACK16`): CPU keeps 4 MB, 4 MB freed for the disk cache |
| 12. July 2026 | Dual-toolchain Tang builds: OSS CAD Suite (yosys/nextpnr) primary, Gowin EDA backup; nextpnr closes the full 27/54 MHz clock target with >2x margin |
| 13. July 2026 | Basys3 SD-Pmod port; memory-backend speed validation vs the no-wait-state protocol for every board; Cmod A7-35T activated (first 27 MHz BRAM build + SRAM bridge plan) |
| 13. July 2026 | Instruction validation campaign complete: 13/13 testable INSTRUCTION-B areas pass vs ND-110 golden traces; MACL self-test clean (STERR=0); two CPU transcription bugs found and fixed (MPY product low word, ROT/shift control) |
| 14. July 2026 | Board-independent `ND120_CORE` extracted from `ND120_TOP`; Tang Nano 20K boots the papertape from a real SD card - proven on silicon |
| 15. July 2026 | RUN test area unblocked: Am2914 interrupt status fence made default, MOR (memory-out-of-range) wired to level 12; 29 new interrupt/trap gate-level testbenches |
| 19. July 2026 | **First CPU boot on FPGA silicon** (Tang Nano 20K) - WCS read-address transparent-latch fix |
| 20. July 2026 | Portable C device cores (NDDeviceCore) added as a submodule; ND-BUS seam gate validates the C cores against the real `ND_BUS_SLAVE.v` in Verilator |
| 23.-26. July 2026 | ND-BUS device campaign: floppy/SMD/DMA IOX conformance testbenches; DMA master validated against the real bus arbiter |
| 27. July 2026 | Floppy boot (`1560&`) works in Verilator - FLOMON + TPE monitor load from a floppy image (DMA zero-word capture fix) |
| 30. July 2026 | PAL transcription audit vs the original PALASM: 8 equation fixes; PAGING test suite passes 11/11 on Tang silicon (MMU page-table fix in PAL 44306A) |
| 31. July 2026 | MOVEW APT-to-APT word-drop and double-trap phantom-vector-7 fixed; full INSTRUCTION multi-level run (levels 1-9) passes clean on Tang silicon |

/****************************************************************************
** Build configuration for the Tang Nano 20K SD-FAT test tool               **
**                                                                         **
** SDFAT_TEST_READONLY - the DEFAULT build. The tool is a DIAGNOSTIC        **
** instrument: it is pointed at cards whose contents are already suspect,   **
** and a bitstream that can write is a bitstream that can destroy the very  **
** evidence being collected. So the writing commands (3 COPY, 4 WRBLK1,     **
** 6 WRITE SPEED) are compiled OUT, not merely hidden:                      **
**                                                                         **
**   - SDFAT_NO_REWRITE below removes the FAT surgeon (sd_fat_rewrite) and, **
**     through the dependency chain in sd_fat_features.vh, the speed tests  **
**     (6 and 7) that reallocate IO.DAT.                                    **
**   - the key-4 (WRBLK1) branch of the menu FSM is inside                  **
**     `ifndef SDFAT_TEST_READONLY in sd_fat_test_top.v.                    **
**   - the sd_writer engine's rd_mode input is tied to a CONSTANT 1 in      **
**     sd_fat_test_top.v, so its CMD24/CMD25 command paths have no          **
**     reachable driver and synthesis removes them. The engine itself stays **
**     because the READ side of it is what serves menu 5/8/9 and the LIST   **
**     free-space scan.                                                     **
**                                                                         **
** To build the write-capable variant, comment out the `define below (the   **
** simulation gates that must exercise the write paths instead pass         **
** -DSDFAT_TEST_WRITE_ENABLE on the compiler command line, which the        **
** `undef at the bottom honours - that keeps ONE source of truth here).     **
**                                                                         **
** Last reviewed: 10-AUG-2026                                               **
** Ronny Hansen                                                             **
*****************************************************************************/
`ifndef SD_FAT_TEST_CONFIG_VH
`define SD_FAT_TEST_CONFIG_VH

// ---- comment out the next line to build the write-capable tool ----------
`define SDFAT_TEST_READONLY

// build systems that need the write paths (the write-side simulation gates)
// pass -DSDFAT_TEST_WRITE_ENABLE instead of editing this file
`ifdef SDFAT_TEST_WRITE_ENABLE
  `undef SDFAT_TEST_READONLY
`endif

`ifdef SDFAT_TEST_READONLY
  // strips sd_fat_rewrite (menu 3) and, by the dependency chain in
  // sd_fat_features.vh, the IO.DAT speed tests (menu 6 and 7)
  `ifndef SDFAT_NO_REWRITE
    `define SDFAT_NO_REWRITE
  `endif
`endif

`endif  // SD_FAT_TEST_CONFIG_VH

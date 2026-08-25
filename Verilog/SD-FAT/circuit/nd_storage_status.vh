//****************************************************************************
//** nd_storage_status.vh - WHY a storage operation failed                   **
//**                                                                         **
//** THE PROBLEM THIS SOLVES                                                 **
//**                                                                         **
//** Every failure in the SD-FAT stack used to arrive at the guest as one    **
//** bit: err. The four controllers then each turned that single bit into    **
//** one fixed status bit - the Winchester called EVERYTHING a CRC error -   **
//** so "no SD card", "WD0.IMG is not on the card", "block past the end of   **
//** the image", "the FAT chain is broken" and "the card stopped answering"  **
//** were indistinguishable from the guest, from the console, and from a     **
//** waveform. Diagnosing a storage fault meant guessing.                    **
//**                                                                         **
//** Worse, some failures were not reported AT ALL: a block request for a    **
//** client that never mounted was silently dropped (no busy, no done), so   **
//** the controller waited for a completion that could never come. A card    **
//** that answers "finished, no error" while handing over a zero-filled      **
//** block is the same class of fault and is the reason the 08-AUG-2026      **
//** Winchester investigation took as long as it did.                        **
//**                                                                         **
//** RULE, and it is not negotiable: an operation either MOVES THE DATA it   **
//** was asked to move, or it completes with err=1 and a reason code below.  **
//** Never done-without-error on a failure, and never done-never.            **
//**                                                                         **
//** WHERE THE CODES ARE ALLOWED TO GO                                       **
//**                                                                         **
//** The SD-FAT stack (nd_storage*, sd_*) is clean-room code, so carrying a  **
//** reason code through it is free. The CONTROLLERS are not: ND_WINCHESTER, **
//** ND_SMD, ND_FLOPPY_DMA and ND_TAPE_400 reproduce real ND cards, and      **
//** their status registers may only ever set bits their own manuals define. **
//** So a controller MAPS a reason code onto an existing, documented status  **
//** bit - it never invents one. Where a card has no bit that fits, the      **
//** mapping falls back to that card's most general fault bit and the reason **
//** stays visible on the storage seam for a testbench or a probe.           **
//**                                                                         **
//** WHERE EACH CODE ENDS UP - the whole map in one place. Every entry is a **
//** bit or value the named MANUAL already defines; the full reasoning for  **
//** each choice is in the mapping block of the controller itself.          **
//**                                                                        **
//**  code       ND_WINCHESTER      ND_SMD            ND_FLOPPY_DMA   TAPE  **
//**             ND-11.015.01 3.5   ND-11.020.01 2.5  ND-11.021.01    400   **
//**                                                  3.4/3.9              **
//**  ---------  -----------------  ----------------  --------------  ----  **
//**  NOCARD     b7 disk fault      b7 hw error 2     oct 20 not rdy   -    **
//**  NOTOPEN    b7 disk fault      b7 hw error 2     oct 20 not rdy   -    **
//**  CARDIO     b9 CRC error       b10 comparer      5 CRC            -    **
//**  FATCHAIN   b9 CRC error       b10 comparer      5 CRC            -    **
//**  RANGE      b8 addr mismatch   b8 addr mismatch  oct 20 not rdy   -    **
//**  TIMEOUT    b6 timeout         b6 timeout        oct 20 not rdy   -    **
//**  WRPROT     b9 CRC error       b5 illegal load   oct 16 wr prot   -    **
//**  WRALIGN    b9 CRC error       b5 illegal load   oct 16 wr prot   -    **
//**                                                                        **
//** The TAPE column is empty on purpose: the ND-100 paper tape reader has  **
//** no error bit and no error code anywhere in its four registers, so it   **
//** keeps its runout silence and the reason is published instead on the    **
//** sticky TDISK_FAULT / TDISK_ERR_CODE seam, which no ND logic reads.     **
//** The reasoning is written out in ND_TAPE_400.v's header.                **
//**                                                                        **
//** Ronny Hansen                                                            **
//****************************************************************************/

`ifndef ND_STORAGE_STATUS_VH
`define ND_STORAGE_STATUS_VH

// 4 bits, carried per client alongside err. Valid when done pulses with
// err=1; NDS_ERR_NONE whenever err=0.
`define NDS_ERR_NONE     4'd0   // no error - the data really moved
`define NDS_ERR_NOCARD   4'd1   // no SD card, or card init never completed
`define NDS_ERR_CARDIO   4'd2   // card command failed: CMD17/CMD24 error,
                                // CRC, or the card stopped answering
`define NDS_ERR_NOTOPEN  4'd3   // this client has no mounted file: the name
                                // is not in the FAT root, or the mount failed
`define NDS_ERR_RANGE    4'd4   // block number is past the end of the image
`define NDS_ERR_FATCHAIN 4'd5   // FAT chain broken, circular, or it ended
                                // before the target block
`define NDS_ERR_TIMEOUT  4'd6   // the engine watchdog fired: the operation
                                // never made progress
`define NDS_ERR_WRPROT   4'd7   // write refused: the write path is not built
                                // into this configuration. RESERVED - no
                                // site emits it today (no build strips the
                                // engine's write path); the controllers all
                                // map it anyway so adding such a build later
                                // needs no controller change.
`define NDS_ERR_WRALIGN  4'd8   // request refused for its SHAPE, not its
                                // address: a partial or unaligned write
                                // (read-modify-write is not implemented), or
                                // a transfer that straddles a block boundary

`endif

/**************************************************************************
** ND CORE SHIM - the C bus MASTER + the nd_bus_hal DMA primitives       **
**                                                                       **
** This is the file nd_bus_hal.h names:                                  **
**     "nd-120 sim  -> simDevices/NDCoreShim.cpp (drives ND120_TOP ports)"**
**                                                                       **
** WHY A C MASTER AND NOT ND_DMA_MASTER.v                                **
** ---------------------------------------                               **
** In a DEVICECORE gate NO Verilog IO device is elaborated (VERILOG_TAPE=0**
** -> INCLUDE_TAPE/FLOPPY/SMD = 0 -> ANY_DMA_MASTER = 0), so ND_DMA_MASTER**
** does not exist and its DMA_REQ/DMA_ACK client ports are not even on    **
** ND120_TOP - they live inside the `ifdef ND120_VERILOG_DEVICES block    **
** (ND120_TOP.v:104-113). The RAW bus signals DO survive (ND120_TOP.v:    **
** 61-93, outside that ifdef), which is exactly what we need: our C code  **
** IS the card, driving the bus in both directions, the same way the      **
** RP2350 will through PIO.                                              **
**                                                                       **
** So this FSM is a faithful C reimplementation of ND_DMA_MASTER.v's      **
** cycle. That RTL is the reference; where this disagrees with it, this   **
** is wrong. Protocol per ND-06.016.01 chapter V.                        **
**                                                                       **
** DIRECTION MAP (verified against ND120_TOP.v, do not guess):           **
**   WE DRIVE (ND120_TOP inputs) : BREQ_n, BAPR_n_IN, BDAP_n_IN,         **
**                                 BINPUT_n_IN, BD_23_0_n_IN            **
**   WE READ  (ND120_TOP outputs): OUTGRANT_n (== our INGRANT, wired at  **
**                                 ND120_CORE.v:636), BMEM_n,           **
**                                 BDRY_n_OUT, BD_23_0_n_OUT            **
**                                                                       **
** Ronny Hansen                                                          **
***************************************************************************/

#ifndef NDCORESHIM_H
#define NDCORESHIM_H

#include "VND120_TOP.h"

extern "C" {
#include "nd_bus_hal.h"
}

/**
 * Bind the shim to the Verilated top. MUST be called once before any tick.
 * Also puts every master-driven line into its released (idle) state.
 */
void ndcore_shim_attach(VND120_TOP *top);

/**
 * Advance the bus-master FSM by one clock.
 *
 * Call every half-clock from proccess_bif_signal(); the shim itself filters
 * down to one step per RISING sysclk edge, so it advances at exactly the rate
 * ND_DMA_MASTER.v's `always @(posedge sysclk)` would.
 */
void ndcore_shim_bus_tick(VND120_TOP *top);

/**
 * The HAL a DMA-capable core is initialised with. dma_start/dma_poll/dma_busy
 * are backed by the FSM in NDCoreShim.cpp; trace goes to NDCoreTrace.
 */
const nd_bus_hal *ndcore_shim_hal(void);

/** Print a one-line summary of master activity (cycles, errors, collisions). */
void ndcore_shim_report(void);

#endif /* NDCORESHIM_H */

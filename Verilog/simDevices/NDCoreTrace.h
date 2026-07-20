/**************************************************************************
** NDDeviceCore TRACE SINK for the ND-120 Verilator harness               **
**                                                                       **
** NDDeviceCore may never include stdio (that is what lets the identical  **
** .c compile into this sim AND into the RP2350 firmware), so its cores   **
** emit fixed-size NUMERIC records through nd_bus_hal.trace and the       **
** CONSUMER formats them. This file is that consumer for the harness: it  **
** printf()s each record as a readable line so a gate run can be read     **
** directly, e.g. against                                                  **
**   NDDeviceCore/docs/floppy-autoload-microcode-contract.md              **
**                                                                       **
** Off by default - set ND120_CORE_TRACE=1 in the environment. A gate     **
** that greps for a specific line must set it explicitly.                  **
**                                                                       **
** COMPILED ONLY under -DND120_DEVICECORE.                                **
***************************************************************************/

#ifndef NDCORETRACE_H
#define NDCORETRACE_H

#include <stdint.h>

extern "C" {
#include "nd_trace.h"
}

/**
 * The sink to install in nd_bus_hal.trace. Prints one line per record when
 * tracing is enabled, otherwise returns immediately.
 *
 * Signature matches nd_trace_fn exactly.
 */
void ndcore_trace(void *ctx, uint16_t evt, uint32_t a, uint32_t b, uint32_t c);

/** True when ND120_CORE_TRACE is set to something other than "0". */
bool ndcore_trace_enabled();

/** Number of records emitted so far (a gate can assert the core was used). */
unsigned long ndcore_trace_count();

#endif // NDCORETRACE_H

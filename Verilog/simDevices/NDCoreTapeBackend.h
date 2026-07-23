/**************************************************************************
** NDDeviceCore PAPERTAPE BACKEND for the ND-120 Verilator harness        **
**                                                                       **
** Feeds the portable nd_tape400 core from a host FILE through the legacy **
** streaming nd_storage seam (get_byte / rewind) - a papertape is a pure  **
** sequential byte stream with no block structure, which is exactly what  **
** that seam models.                                                      **
**                                                                       **
** On the RP2350 the same seam is a FatFs file on the SD card. The DEVICE **
** code is identical either way.                                          **
**                                                                       **
** EOF IS REPORTED HONESTLY as -1. Do NOT copy the two existing harness   **
** implementations here: NDDevices.cpp:165 and process_verilog_tape both  **
** do `getc(f) & 0377`, which turns EOF's -1 into 0377, making their own  **
** EOF branch dead code and feeding the CPU endless 0377 bytes. The gate  **
** never caught it because INSTRUCTION-B.BPUN is fully consumed first.     **
**                                                                       **
** COMPILED ONLY under -DND120_DEVICECORE_TAPE.                            **
***************************************************************************/

#ifndef NDCORETAPEBACKEND_H
#define NDCORETAPEBACKEND_H

#include <stdio.h>
#include <stdint.h>

extern "C" {
#include "nd_storage.h"
}

struct NDCoreTapeBackend
{
    FILE         *fp;
    unsigned long bytes;     ///< bytes handed to the core (diagnostics)
    unsigned long eofs;      ///< how often EOF was reported
    unsigned long rewinds;   ///< device-clear rewinds
    char          path[512];
};

/** Zero the backend; no file opened yet. */
void ndcore_tape_backend_init(NDCoreTapeBackend *b);

/**
 * Mount a papertape image. Prints what it mounted, or why it could not - a
 * gate that boots from tape MUST show which file it actually read.
 * @return true if the file was opened and is non-empty.
 */
bool ndcore_tape_backend_mount(NDCoreTapeBackend *b, const char *path);

/** Close the mounted image. */
void ndcore_tape_backend_close(NDCoreTapeBackend *b);

/** The nd_storage view to hand to nd_tape400_init(). */
nd_storage ndcore_tape_backend_storage(NDCoreTapeBackend *b);

#endif // NDCORETAPEBACKEND_H

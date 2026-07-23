/**************************************************************************
** NDDeviceCore BLOCK BACKEND for the ND-120 Verilator harness            **
**                                                                       **
** Supplies an nd_storage_dev (the async block seam) backed by a plain    **
** disk-image FILE, so the portable nd_floppy_dma / nd_smd cores get real **
** media without learning anything about the host.                        **
**                                                                       **
** On the RP2350 this same seam is SD+FatFs on core 0 with a cross-core   **
** message per request; here the file access completes on the very next   **
** poll(). The DEVICE code is identical either way - that is the point of **
** the seam, and it is why a gate run here predicts the card's behaviour. **
**                                                                       **
** Deliberately NOT read-only-by-accident: the image is opened "r+b" when **
** writable and "rb" otherwise, and a write to a read-only unit fails the **
** request rather than being silently dropped - a silently dropped write  **
** would let a broken WRITE_DATA path pass a gate.                        **
**                                                                       **
** COMPILED ONLY under -DND120_DEVICECORE_FLOPPY.                          **
***************************************************************************/

#ifndef NDCOREBLOCKBACKEND_H
#define NDCOREBLOCKBACKEND_H

#include <stdio.h>
#include <stdint.h>

extern "C" {
#include "nd_storage.h"
}

/** One unit (drive). The harness gate needs only unit 0, but the shape
 *  matches the real controller's multi-drive model. */
#define NDCORE_BLOCK_UNITS 4

struct NDCoreBlockBackend
{
    FILE     *fp[NDCORE_BLOCK_UNITS];
    uint64_t  size[NDCORE_BLOCK_UNITS];
    bool      read_only[NDCORE_BLOCK_UNITS];

    // Exactly one request in flight, like the real (single SD stack) backend.
    bool      pending;

    // Diagnostics a gate can assert on.
    unsigned long reads;
    unsigned long writes;
    unsigned long errors;
};

/** Zero the backend. No file is opened yet. */
void ndcore_block_backend_init(NDCoreBlockBackend *b);

/**
 * Attach a disk image to a unit.
 * @return true if the file was opened and has non-zero length.
 * Prints what it attached (or why it could not) - a gate that boots from an
 * image MUST be able to see in the log which file it actually used.
 */
bool ndcore_block_backend_attach(NDCoreBlockBackend *b, uint8_t unit,
                                 const char *path, bool writable);

/** Close every attached image. */
void ndcore_block_backend_close(NDCoreBlockBackend *b);

/** The nd_storage_dev view to hand to nd_storage_queue_init(). */
nd_storage_dev ndcore_block_backend_dev(NDCoreBlockBackend *b);

#endif // NDCOREBLOCKBACKEND_H

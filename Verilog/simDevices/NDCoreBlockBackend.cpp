/**************************************************************************
** NDDeviceCore BLOCK BACKEND - see NDCoreBlockBackend.h                  **
***************************************************************************/

#include "NDCoreBlockBackend.h"
#include "NDCoreTrace.h"

#include <string.h>

void ndcore_block_backend_init(NDCoreBlockBackend *b)
{
    memset(b, 0, sizeof(*b));
}

bool ndcore_block_backend_attach(NDCoreBlockBackend *b, uint8_t unit,
                                 const char *path, bool writable)
{
    if (unit >= NDCORE_BLOCK_UNITS || path == NULL || path[0] == '\0')
    {
        printf("[ndcore] block backend: no image for unit %u\r\n", unit);
        return false;
    }

    FILE *f = fopen(path, writable ? "r+b" : "rb");
    if (f == NULL && writable)
    {
        // Fall back to read-only rather than failing outright: a boot gate
        // only reads, and a write-protected archive image is a normal thing
        // to be handed. Say so in the log - never pretend it is writable.
        f = fopen(path, "rb");
        writable = false;
    }

    if (f == NULL)
    {
        printf("[ndcore] block backend: CANNOT OPEN %s for unit %u\r\n", path, unit);
        return false;
    }

    fseek(f, 0, SEEK_END);
    long len = ftell(f);
    fseek(f, 0, SEEK_SET);

    if (len <= 0)
    {
        printf("[ndcore] block backend: %s is EMPTY (unit %u not attached)\r\n",
               path, unit);
        fclose(f);
        return false;
    }

    b->fp[unit]        = f;
    b->size[unit]      = (uint64_t)len;
    b->read_only[unit] = !writable;

    printf("[ndcore] block backend: unit %u <- %s (%ld bytes, %s)\r\n",
           unit, path, len, writable ? "read/write" : "READ-ONLY");
    fflush(stdout);
    return true;
}

void ndcore_block_backend_close(NDCoreBlockBackend *b)
{
    for (int u = 0; u < NDCORE_BLOCK_UNITS; u++)
    {
        if (b->fp[u] != NULL)
        {
            fclose(b->fp[u]);
            b->fp[u] = NULL;
        }
    }
}

// --- the nd_storage_dev seam -------------------------------------------- //

static bool blk_start(void *ctx, nd_storage_request *req)
{
    NDCoreBlockBackend *b = (NDCoreBlockBackend *)ctx;
    (void)req;

    if (b->pending)
        return false;      // one request in flight, exactly like the SD stack

    b->pending = true;
    return true;
}

static bool blk_poll(void *ctx, nd_storage_request *req)
{
    NDCoreBlockBackend *b = (NDCoreBlockBackend *)ctx;

    if (!b->pending)
        return false;

    b->pending = false;

    if (req->unit >= NDCORE_BLOCK_UNITS || b->fp[req->unit] == NULL)
    {
        req->error  = true;
        req->result = -1;
        b->errors++;
        return true;
    }

    FILE *f = b->fp[req->unit];

    // Reading PAST the end is not an error in itself: the boot byte server
    // reads a fixed chunk that may straddle the end of a short image. Serve
    // what exists and report the short count; the core decides what it means.
    if (req->position >= b->size[req->unit])
    {
        req->error  = false;
        req->result = 0;
        return true;
    }

    uint64_t avail = b->size[req->unit] - req->position;
    uint32_t want  = req->byte_count;
    if ((uint64_t)want > avail)
        want = (uint32_t)avail;

    if (fseek(f, (long)req->position, SEEK_SET) != 0)
    {
        req->error  = true;
        req->result = -1;
        b->errors++;
        return true;
    }

    switch (req->op)
    {
    case ND_STORAGE_READ_BLOCK:
    {
        size_t got = fread(req->buffer, 1, want, f);
        req->error  = false;
        req->result = (int32_t)got;
        b->reads++;
        break;
    }

    case ND_STORAGE_WRITE_BLOCK:
        if (b->read_only[req->unit])
        {
            // Fail loudly. A silently dropped write would let a broken
            // WRITE_DATA path sail through a gate.
            req->error  = true;
            req->result = 0;
            b->errors++;
            break;
        }
        {
            size_t put = fwrite(req->buffer, 1, want, f);
            fflush(f);
            req->error  = false;
            req->result = (int32_t)put;
            b->writes++;
        }
        break;
    }

    return true;
}

static bool blk_busy(void *ctx)
{
    return ((NDCoreBlockBackend *)ctx)->pending;
}

static bool blk_info(void *ctx, uint8_t unit,
                     uint64_t *out_size, bool *out_ro, bool *out_attached)
{
    NDCoreBlockBackend *b = (NDCoreBlockBackend *)ctx;

    if (unit >= NDCORE_BLOCK_UNITS)
        return false;

    if (out_size)     *out_size     = b->size[unit];
    if (out_ro)       *out_ro       = b->read_only[unit];
    if (out_attached) *out_attached = (b->fp[unit] != NULL);
    return true;
}

nd_storage_dev ndcore_block_backend_dev(NDCoreBlockBackend *b)
{
    nd_storage_dev d;
    d.start = blk_start;
    d.poll  = blk_poll;
    d.busy  = blk_busy;
    d.info  = blk_info;
    d.ctx   = b;
    return d;
}

/**************************************************************************
** NDDeviceCore PAPERTAPE BACKEND - see NDCoreTapeBackend.h               **
***************************************************************************/

#include "NDCoreTapeBackend.h"
#include "NDCoreTrace.h"

#include <string.h>

void ndcore_tape_backend_init(NDCoreTapeBackend *b)
{
    memset(b, 0, sizeof(*b));
}

bool ndcore_tape_backend_mount(NDCoreTapeBackend *b, const char *path)
{
    if (path == NULL || path[0] == '\0')
    {
        printf("[tapecore] no papertape image named\r\n");
        return false;
    }

    // "rb": the tape is BINARY. Opening text-mode would silently mangle 0x0A /
    // 0x0D bytes inside a BPUN stream on some platforms - and a BPUN checksum
    // failure looks like a load error, not a file-mode bug.
    b->fp = fopen(path, "rb");
    if (b->fp == NULL)
    {
        printf("[tapecore] CANNOT OPEN papertape image %s\r\n", path);
        return false;
    }

    fseek(b->fp, 0, SEEK_END);
    long len = ftell(b->fp);
    fseek(b->fp, 0, SEEK_SET);

    if (len <= 0)
    {
        printf("[tapecore] papertape image %s is EMPTY\r\n", path);
        fclose(b->fp);
        b->fp = NULL;
        return false;
    }

    snprintf(b->path, sizeof(b->path), "%s", path);
    printf("[tapecore] papertape mounted: %s (%ld bytes)\r\n", path, len);
    fflush(stdout);
    return true;
}

void ndcore_tape_backend_close(NDCoreTapeBackend *b)
{
    if (b->fp != NULL)
    {
        fclose(b->fp);
        b->fp = NULL;
    }
}

// --- the nd_storage seam ------------------------------------------------- //

static int tape_get_byte(void *ctx)
{
    NDCoreTapeBackend *b = (NDCoreTapeBackend *)ctx;

    if (b->fp == NULL)
        return -1;

    int c = getc(b->fp);
    if (c == EOF)
    {
        // Honest EOF. The core handles it; masking to 0377 here is the bug the
        // header warns about.
        b->eofs++;
        return -1;
    }

    b->bytes++;
    return c & 0xFF;
}

static void tape_rewind(void *ctx)
{
    NDCoreTapeBackend *b = (NDCoreTapeBackend *)ctx;

    if (b->fp == NULL)
        return;

    // Device clear rewinds the tape. Resolved in favour of the RTL:
    // ND_TAPE_400.v:122 pulses source_rewind, while the C++ PaperTape only has
    // a comment saying it should.
    b->rewinds++;
    ::rewind(b->fp);
}

nd_storage ndcore_tape_backend_storage(NDCoreTapeBackend *b)
{
    nd_storage s;
    s.get_byte    = tape_get_byte;
    s.rewind      = tape_rewind;
    s.read_block  = NULL;   // a papertape has no blocks
    s.write_block = NULL;
    s.ctx         = b;
    return s;
}

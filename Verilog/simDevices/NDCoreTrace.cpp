/**************************************************************************
** NDDeviceCore TRACE SINK - see NDCoreTrace.h                            **
**                                                                       **
** Everything is printed in OCTAL, because that is the only base the ND   **
** world is ever discussed in (register addresses, control words, status  **
** words, ident codes). A trace read next to the microcode listing or the **
** autoload contract doc must not need mental base conversion.            **
***************************************************************************/

#include "NDCoreTrace.h"

#include <stdio.h>
#include <stdlib.h>

static int           g_enabled = -1;    // -1 = not yet resolved
static unsigned long g_count;

bool ndcore_trace_enabled()
{
    if (g_enabled < 0)
    {
        const char *e = getenv("ND120_CORE_TRACE");
        g_enabled = (e != NULL && e[0] != '\0' && e[0] != '0') ? 1 : 0;
    }
    return g_enabled != 0;
}

unsigned long ndcore_trace_count()
{
    return g_count;
}

void ndcore_trace(void *ctx, uint16_t evt, uint32_t a, uint32_t b, uint32_t c)
{
    (void)ctx;

    // Count even when printing is off, so a gate can still prove the core was
    // actually driven without drowning the log.
    g_count++;

    if (!ndcore_trace_enabled())
        return;

    const char *name = nd_trace_event_name(evt);

    // Per-event formatting where a raw triple would be unreadable. Anything
    // not special-cased falls through to the generic form at the bottom.
    switch (evt)
    {
    case ND_TRACE_IOX_READ:
        printf("[ndcore] IOX READ   %06o -> %06o\r\n", a, b);
        return;

    case ND_TRACE_IOX_WRITE:
        printf("[ndcore] IOX WRITE  %06o <- %06o\r\n", a, b);
        return;

    case ND_TRACE_IRQ:
        printf("[ndcore] IRQ level %lu %s\r\n",
               (unsigned long)a, b ? "ASSERT" : "clear");
        return;

    case ND_TRACE_IDENT:
        if (b == 0)
            printf("[ndcore] IDENT level %lu -> not mine (pass daisy chain)\r\n",
                   (unsigned long)a);
        else
            printf("[ndcore] IDENT level %lu -> code %03o\r\n",
                   (unsigned long)a, b);
        return;

    case ND_TRACE_FLP_CONTROL:
        // 004005 is the microcode's autoload activate (DVACT); call it out so
        // the log says WHY, not just WHAT.
        printf("[ndcore] FLP control %06o%s\r\n", a,
               (a == 04005u) ? "   (DVACT - autoload activate)" : "");
        return;

    case ND_TRACE_FLP_STATUS:
        printf("[ndcore] FLP status  %06o  RFT=%lu active=%lu\r\n",
               a, (unsigned long)b, (unsigned long)c);
        return;

    case ND_TRACE_FLP_BOOT_ENTER:
        printf("[ndcore] FLP autoload ENTER (unit %lu) - PIO byte server, no DMA\r\n",
               (unsigned long)a);
        return;

    case ND_TRACE_FLP_BOOT_ACTIVATE:
        printf("[ndcore] FLP autoload activate: buffer %lu/%lu%s\r\n",
               (unsigned long)a, (unsigned long)b,
               c ? "" : "   (first)");
        return;

    case ND_TRACE_FLP_BOOT_REFILL:
        printf("[ndcore] FLP autoload refill: %lu words from byte pos %lu (unit %lu)\r\n",
               (unsigned long)b, (unsigned long)a, (unsigned long)c);
        return;

    case ND_TRACE_FLP_BOOT_WORD:
        // The microcode masks to 7/8 bits and only ever uses the LOW byte, so
        // show the character too - that is what makes a BPUN leader readable.
        {
            unsigned ch = b & 0xFFu;
            printf("[ndcore] FLP autoload word[%lu] = %06o  low=%03o '%c'\r\n",
                   (unsigned long)a, b, ch,
                   (ch >= 32u && ch < 127u) ? (char)ch : '.');
        }
        return;

    case ND_TRACE_FLP_BOOT_FAIL:
        printf("[ndcore] FLP autoload FAIL: %s (byte pos %lu)\r\n",
               nd_trace_reason_name(a), (unsigned long)b);
        return;

    case ND_TRACE_FLP_BOOT_EXIT:
        printf("[ndcore] FLP autoload EXIT after %lu words (byte pos %lu)\r\n",
               (unsigned long)a, (unsigned long)b);
        return;

    case ND_TRACE_STORAGE_SUBMIT:
        printf("[ndcore] STORAGE submit pos %lu bytes %lu op %lu\r\n",
               (unsigned long)a, (unsigned long)b, (unsigned long)c);
        return;

    case ND_TRACE_STORAGE_DONE:
        printf("[ndcore] STORAGE done   pos %lu moved %lu %s\r\n",
               (unsigned long)a, (unsigned long)b, c ? "ERROR" : "ok");
        return;

    default:
        break;
    }

    printf("[ndcore] %s a=%lu b=%lu c=%lu\r\n", name,
           (unsigned long)a, (unsigned long)b, (unsigned long)c);
}

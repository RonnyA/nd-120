/**************************************************************************
** SIM-SIDE nd_char_dev CAPTURE BACKEND - implementation                   **
** See NDCoreCharBackend.h for the story.                                  **
***************************************************************************/

#include "NDCoreCharBackend.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/* A couple of ticks per op, exactly like NDDeviceCore's own fake backend, so
 * the device's ready-for-transfer phase machine is really exercised (an
 * instantaneous backend would hide a stuck-busy bug). */
#define NDCORE_CHAR_LATENCY 2

/* ---- verdict ---------------------------------------------------------- *
 * Checked after EVERY captured byte, so the PASS line appears the instant
 * the expected text has been printed - we never depend on the simulation
 * terminating cleanly. */
static void ndcore_check_verdict(NDCoreCharBackend *b)
{
    if (b->passed || b->expect == NULL)
        return;

    size_t want = strlen(b->expect);
    if (want == 0 || (size_t)b->tx_len[0] < want)
        return;

    const uint8_t *tail = &b->tx[0][(size_t)b->tx_len[0] - want];
    if (memcmp(tail, b->expect, want) == 0)
    {
        b->passed = true;
        printf("[democore] captured the expected %u bytes\r\n", (unsigned)want);
        printf("[democore] RESULT: PASS\r\n");
        fflush(stdout);
    }
}

static bool ndcore_start(void *ctx, nd_char_request *req)
{
    NDCoreCharBackend *b = (NDCoreCharBackend *)ctx;
    (void)req;

    if (b->pending)
        return false;   /* backend busy - the queue will retry */

    b->pending = true;
    b->latency = NDCORE_CHAR_LATENCY;
    return true;
}

static bool ndcore_poll(void *ctx, nd_char_request *req)
{
    NDCoreCharBackend *b = (NDCoreCharBackend *)ctx;

    if (!b->pending)
        return false;
    if (--b->latency > 0)
        return false;
    b->pending = false;

    uint8_t ch = req->channel;
    if (ch >= NDCORE_CHAR_CHANNELS)
    {
        /* Unknown channel: complete with an error rather than corrupt state. */
        req->error     = true;
        req->have_byte = false;
        return true;
    }

    if (req->op == ND_CHAR_PUT)
    {
        if (b->tx_len[ch] < NDCORE_CHAR_CAPACITY)
            b->tx[ch][b->tx_len[ch]++] = req->value;

        /* Echo so a run log shows the byte arriving through the REAL bus. */
        printf("[democore] ch%u PUT %03o '%c'\r\n",
               (unsigned)ch, (unsigned)req->value,
               (req->value >= 0x20 && req->value < 0x7F) ? (char)req->value : '.');
        fflush(stdout);

        req->have_byte = false;
        if (ch == 0)
            ndcore_check_verdict(b);
    }
    else /* ND_CHAR_GET */
    {
        if (b->rx[ch] != NULL && b->rx_pos[ch] < b->rx_len[ch])
        {
            req->have_byte = true;
            req->value_in  = (int32_t)b->rx[ch][b->rx_pos[ch]++];
        }
        else
        {
            /* Live endpoint with nothing typed - NOT an error, just no byte. */
            req->have_byte = false;
            req->value_in  = -1;
        }
    }

    return true;
}

static bool ndcore_busy(void *ctx)
{
    NDCoreCharBackend *b = (NDCoreCharBackend *)ctx;
    return b->pending;
}

static bool ndcore_rx_ready(void *ctx, uint8_t channel)
{
    NDCoreCharBackend *b = (NDCoreCharBackend *)ctx;
    if (channel >= NDCORE_CHAR_CHANNELS)
        return false;
    return (b->rx[channel] != NULL) && (b->rx_pos[channel] < b->rx_len[channel]);
}

static void ndcore_reset_channel(void *ctx, uint8_t channel)
{
    NDCoreCharBackend *b = (NDCoreCharBackend *)ctx;
    if (channel >= NDCORE_CHAR_CHANNELS)
        return;
    /* "Rewind" the injected input. The captured paper is deliberately KEPT:
     * a device clear must not erase the evidence the gate is built on. */
    b->rx_pos[channel] = 0;
}

void ndcore_char_backend_init(NDCoreCharBackend *b)
{
    memset(b, 0, sizeof(*b));
    b->expect = getenv("ND120_DEMOCORE_EXPECT");
}

nd_char_dev ndcore_char_backend_dev(NDCoreCharBackend *b)
{
    nd_char_dev d;
    d.start    = ndcore_start;
    d.poll     = ndcore_poll;
    d.busy     = ndcore_busy;
    d.rx_ready = ndcore_rx_ready;
    d.reset    = ndcore_reset_channel;
    d.ctx      = b;
    return d;
}

void ndcore_char_backend_set_input(NDCoreCharBackend *b,
                                   uint8_t channel,
                                   const uint8_t *data,
                                   int len)
{
    if (channel >= NDCORE_CHAR_CHANNELS)
        return;
    b->rx[channel]     = data;
    b->rx_len[channel] = len;
    b->rx_pos[channel] = 0;
}

void ndcore_char_backend_report(NDCoreCharBackend *b)
{
    if (b->verdict_printed)
        return;
    b->verdict_printed = true;

    for (int ch = 0; ch < NDCORE_CHAR_CHANNELS; ch++)
    {
        if (b->tx_len[ch] == 0)
            continue;

        printf("[democore] ch%d paper (%d bytes): \"", ch, b->tx_len[ch]);
        for (int i = 0; i < b->tx_len[ch]; i++)
        {
            uint8_t c = b->tx[ch][i];
            if (c >= 0x20 && c < 0x7F)
                putchar((char)c);
            else
                printf("\\%03o", (unsigned)c);
        }
        printf("\"\r\n");
    }

    if (b->expect == NULL)
        printf("[democore] RESULT: FAIL (ND120_DEMOCORE_EXPECT not set)\r\n");
    else if (!b->passed)
        printf("[democore] RESULT: FAIL (expected \"%s\")\r\n", b->expect);
    else
        printf("[democore] RESULT: PASS\r\n");

    fflush(stdout);
}

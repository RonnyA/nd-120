/**************************************************************************
** SIM-SIDE nd_char_dev CAPTURE BACKEND                                   **
**                                                                       **
** The "paper" behind an NDDeviceCore CHARACTER device inside the ND-120  **
** Verilator harness. Modelled on the fake_backend in NDDeviceCore's      **
** test/test_lineprinter.c (minus the test asserts):                       **
**                                                                       **
**   PUT -> the byte is appended to a per-channel capture buffer (this is **
**          what proves the ND-120 CPU really drove our portable core over **
**          the real bus RTL), and echoed to stdout as a [democore] line.  **
**   GET -> answered from an optional per-channel injected input string,   **
**          or "no byte yet" when the string is exhausted.                 **
**                                                                       **
** The backend deliberately takes a couple of ticks to finish an op, so   **
** the device's phase machine (ready-for-transfer clearing and re-arming)  **
** is genuinely exercised rather than short-circuited.                     **
**                                                                       **
** GATE VERDICT. Set ND120_DEMOCORE_EXPECT to the exact string the ND-100  **
** program is supposed to print. The moment the capture ends with that     **
** string this prints                                                      **
**     [democore] RESULT: PASS                                             **
** and at process exit a summary line is printed either way, so a run that **
** dies early still yields a machine-checkable                             **
**     [democore] RESULT: FAIL                                             **
**                                                                       **
** COMPILED ONLY under -DND120_DEVICECORE (runSim: make DEVICECORE=1).     **
***************************************************************************/

#ifndef NDCORECHARBACKEND_H
#define NDCORECHARBACKEND_H

#include <stdint.h>
#include <stdbool.h>
#include <stddef.h>

extern "C" {
#include "nd_char.h"
}

#define NDCORE_CHAR_CHANNELS 4     ///< channels this sim backend serves
#define NDCORE_CHAR_CAPACITY 512   ///< captured bytes kept per channel

/**
 * Capture/injection state for the sim character backend. One instance serves
 * every channel on one nd_char_queue.
 */
struct NDCoreCharBackend
{
    /* --- captured PUT bytes, per channel (the "paper") ------------------ */
    uint8_t  tx[NDCORE_CHAR_CHANNELS][NDCORE_CHAR_CAPACITY];
    int      tx_len[NDCORE_CHAR_CHANNELS];

    /* --- optional injected GET bytes, per channel ----------------------- */
    const uint8_t *rx[NDCORE_CHAR_CHANNELS];
    int      rx_len[NDCORE_CHAR_CHANNELS];
    int      rx_pos[NDCORE_CHAR_CHANNELS];

    /* --- one in-flight op (the queue serialises them anyway) ------------ */
    bool     pending;
    int      latency;

    /* --- verdict bookkeeping ------------------------------------------- */
    const char *expect;   ///< ND120_DEMOCORE_EXPECT, or null
    bool     passed;      ///< expect was seen at the tail of channel 0's capture
    bool     verdict_printed;
};

/** Zero the backend and read ND120_DEMOCORE_EXPECT from the environment. */
void ndcore_char_backend_init(NDCoreCharBackend *b);

/** Build the nd_char_dev vtable view of this backend. */
nd_char_dev ndcore_char_backend_dev(NDCoreCharBackend *b);

/** Feed bytes a GET on this channel should return (borrowed, not copied). */
void ndcore_char_backend_set_input(NDCoreCharBackend *b,
                                   uint8_t channel,
                                   const uint8_t *data,
                                   int len);

/** Print the captured paper + the final RESULT: PASS/FAIL line. */
void ndcore_char_backend_report(NDCoreCharBackend *b);

#endif // NDCORECHARBACKEND_H

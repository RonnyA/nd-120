/**************************************************************************
** ND CORE SHIM - the C bus MASTER + the nd_bus_hal DMA primitives       **
** See NDCoreShim.h for why this exists and the verified direction map.  **
***************************************************************************/

#include "NDCoreShim.h"
#include "NDCoreTrace.h"

#include <stdio.h>

/* ===================================================================== *
 * BUS POLARITY INVARIANT - get this wrong and everything silently breaks
 *
 * The ND-100 bus is ACTIVE LOW and pulled HIGH when idle. That applies to
 * the data/address bus AND to every control signal (they all carry _n).
 *
 *   BD_23_0_n : idle 0xFFFFFF, asserted as ~value & 0xFFFFFF
 *   BREQ/BAPR/BDAP/BINPUT/BDRY/BMEM/INGRANT : idle 1, asserted 0
 *
 * It is a WIRED-AND (open-collector) bus: ND120_CORE.v:643-652 ANDs every
 * contributor and ABSENT devices contribute all-ones. So we MUST drive
 * 0xFFFFFF / 1 whenever we are not actively asserting. Leaving a line low
 * while idle jams the bus and the CPU wedges with NO error message.
 * Always release explicitly.
 * ===================================================================== */
#define BD_IDLE 0xFFFFFFu

/* Recovery gap between granted cycles, in sysclk ticks. MEASURED value from
 * ND_DMA_MASTER.v:55-64: the memory-side grant/decode chain (BLRQ/BCGNT 25/50ns
 * stages) needs time to unwind after BDRY before it can latch the next
 * externally strobed address. Back-to-back re-requests WIN the grant but the
 * RAM cycle never happens - every second read is silently lost. Real ND-100
 * controllers re-request at 1.4us+, so hardware never hit this.
 * The client request is ACCEPTED any time; only BREQ assertion is deferred. */
#define MIN_GAP_TICKS 32u

/* Local hang guard, same intent as ND_DMA_MASTER.v's TIMEOUT_TICKS: the real
 * guard is the BCU's. This only stops a wedged FSM from hanging the sim. */
#define TIMEOUT_TICKS 4096u

typedef enum
{
    ST_IDLE = 0,
    ST_REQ,      /* BREQ out, waiting for BMEM + INGRANT      */
    ST_ADDR,     /* address on BD with BAPR                   */
    ST_DATA,     /* BDAP out, waiting for BDRY                */
    ST_END       /* BDRY seen: complete, wait for release     */
} shim_state;

static VND120_TOP *g_top = nullptr;

static shim_state g_state = ST_IDLE;
static bool     g_wr        = false;
static uint32_t g_addr      = 0;
static uint16_t g_wdata     = 0;

static uint16_t g_rd_capture   = 0;
static bool     g_rd_captured  = false;

static bool     g_ack_pending  = false;   /* one-shot, consumed by dma_poll */
static uint16_t g_ack_rdata    = 0;
static bool     g_ack_err      = false;

static unsigned g_gap_cnt    = 0;
static unsigned g_phase_cnt  = 0;
static unsigned g_tick_cnt   = 0;

/* --- REQUEST FREEZE (the arbitration handshake I wrongly dropped) --------- *
 * ND_DMA_MASTER.v latches its request status at the BMEM leading (falling)
 * edge - Figure V.4.1 "DMA REQ STATUS IS FROZEN". This is NOT about competing
 * DMA masters: it is what makes us claim ONLY the bus cycle the arbiter started
 * IN RESPONSE TO OUR BREQ, instead of grabbing whatever cycle happens to be
 * running. The CPU's own IOX and memory cycles ALSO pull BMEM_n low, so without
 * this latch we drive the bus on top of the CPU (the 93 "IOX collisions") and
 * our DMA read/address gets clobbered. The design spec required it
 * ("grant = BMEM low AND INGRANT low AND request frozen at the BMEM falling
 * edge"); I removed it and that was the bug. */
static bool     g_prev_bmem_n = true;
static bool     g_req_frozen  = false;

/* Statistics / diagnostics */
static unsigned long g_cycles_done = 0;
static unsigned long g_cycles_err  = 0;
static unsigned long g_collisions  = 0;
static unsigned long g_aborts      = 0;   /* cycles aborted+retried due to IOX */

/* Diagnostics: without these, "0 cycles" is ambiguous between "the core never
 * asked", "we never got granted" and "the tick never ran". Each is a different
 * bug, so count them separately rather than guessing. */
static unsigned long g_start_ok    = 0;   /* dma_start accepted            */
static unsigned long g_start_busy  = 0;   /* dma_start refused (busy)      */
static unsigned long g_ticks_run   = 0;   /* rising edges the FSM saw      */
static unsigned long g_req_waits   = 0;   /* ticks spent waiting for grant */
static unsigned long g_calls       = 0;   /* every entry, before any filter */
static unsigned long g_sysclk_hi   = 0;   /* entries seeing sysclk == 1     */

/* --------------------------------------------------------------------- */
/* Release every line we drive. Call whenever we are not asserting.       */
static void bus_release(VND120_TOP *top)
{
    top->BREQ_n       = 1;
    top->BAPR_n_IN    = 1;
    top->BDAP_n_IN    = 1;
    top->BINPUT_n_IN  = 1;
    top->BD_23_0_n_IN = BD_IDLE;
}

void ndcore_shim_attach(VND120_TOP *top)
{
    g_top = top;
    g_prev_bmem_n = true;      /* BMEM idle-high; no stale falling edge */
    g_req_frozen  = false;
    bus_release(top);
}

/* --------------------------------------------------------------------- *
 * SHARED-LINE HAZARD - loud, never silent.
 *
 * NDBus.cpp's IOX slave path drives the SAME ND120_TOP input ports we do
 * (BD_23_0_n_IN, BDAP_n_IN, BINPUT_n_IN, BDRY_n_IN). On a real backplane
 * those are one wired-AND wire; in C they are plain variables, so the last
 * writer in a half-clock wins.
 *
 * In a correct bus this cannot bite: the CPU runs ONE cycle at a time, and
 * while we hold the grant it is not driving an IOX cycle. But "cannot
 * happen" is exactly the assumption that costs weeks, so we DETECT it: if
 * BIOXE_n goes active while we hold the bus, count it and say so. A silent
 * corruption becomes a visible number in the report.
 * --------------------------------------------------------------------- */
static void check_collision(VND120_TOP *top)
{
    const bool granted = (g_state == ST_ADDR || g_state == ST_DATA || g_state == ST_END);
    if (granted && top->BIOXE_n == 0)
    {
        if (g_collisions == 0)
        {
            /* With the exclusivity interlock in place this should NEVER fire:
             * we abort ST_ADDR/ST_DATA before it, and ST_END has already
             * captured its data. If it does fire, the interlock has a hole. */
            printf("[shim] *** IOX cycle overlapped a held DMA cycle in state %d "
                   "- interlock hole, data may be corrupt\r\n", (int)g_state);
            fflush(stdout);
        }
        g_collisions++;
    }
}

/* --------------------------------------------------------------------- */
void ndcore_shim_bus_tick(VND120_TOP *top)
{
    /* Lazy attach: the harness has no single init point that knows `top`, and
     * an un-attached master must never be a silent no-op. First tick binds and
     * releases every line we drive. */
    if (g_top == nullptr) ndcore_shim_attach(top);
    if (top != g_top) return;

    /* Mirror ND_DMA_MASTER.v's `always @(posedge sysclk)`: advance exactly
     * once per RISING edge. proccess_bif_signal() runs every HALF clock, so
     * without this filter the FSM would run at twice the RTL's rate and the
     * strobe widths / recovery gap would all be half as long as measured. */
    /* ONE STEP PER CALL - and that is exactly one step per FULL sysclk period.
     *
     * MEASURED 20-JUL-2026, do not "restore" an edge filter here. Run120.cpp
     * toggles top->sysclk TWICE per loop iteration (line 647 before
     * proccess_bif_signal, and again at line 1708 at the end of the loop), so
     * by the time we are called sysclk is ALWAYS the same phase. A
     * rising-edge filter therefore fires exactly ONCE in the whole run: the
     * instrumented build reported
     *     120000000 calls (120000000 with sysclk=1), 1 ticks
     * and the FSM sat frozen in ST_REQ forever.
     *
     * The widely-repeated claim that proccess_bif_signal "runs every
     * half-clock" is WRONG - it runs once per full clock, which is precisely
     * the rate ND_DMA_MASTER.v's always @(posedge sysclk) advances at. So
     * ticking unconditionally is both simpler and correct. */
    g_calls++;
    if (top->sysclk != 0) g_sysclk_hi++;

    g_ticks_run++;
    check_collision(top);

    if (g_gap_cnt != 0) g_gap_cnt--;

    /* --- request-freeze latch (mirrors ND_DMA_MASTER.v:115-124,167-171) --- *
     * s_bmem_fall  = BMEM_n went low this tick.
     * g_req_frozen = "at the last BMEM falling edge, we were in ST_REQ with
     *                 BREQ asserted" - i.e. this grant round is OURS.
     * frozen_eff   also covers the edge tick itself (the latch updates a tick
     *                 later, exactly as the RTL's registered version does). */
    const bool bmem_fall = (top->BMEM_n == 0) && (g_prev_bmem_n == true);

    if (top->BMEM_n == 1)
        g_req_frozen = false;                       /* round over, clear */
    else if (bmem_fall)
        g_req_frozen = (g_state == ST_REQ) && (top->BREQ_n == 0);

    const bool frozen_eff =
        g_req_frozen ||
        (bmem_fall && g_state == ST_REQ && top->BREQ_n == 0);

    /* ================================================================= *
     * C-HARNESS ARBITER EXCLUSIVITY (Ronny, 20-JUL-2026)
     *
     * Per ND-06.016.01 II.4.1.2, "an already allocated bus is not
     * interruptible" - a granted DMA cycle and a CPU cycle cannot overlap.
     * But VERIFIED here: the Verilog CPU does NOT stall for an EXTERNAL C bus
     * master. It keeps executing IOX (status polls) and starts an IOX cycle
     * (BIOXE_n -> 0) WHILE we legitimately hold a granted memory cycle waiting
     * for BDRY (grant dump showed BIOXE_n=1 at every grant; collisions showed
     * BIOXE_n=0 in ST_DATA). The Verilog's native ND_DMA_MASTER never hits
     * this because it lives inside the RTL and IS serialised; our raw-port
     * master is not, so we must enforce the exclusivity here.
     *
     * If an IOX cycle is in progress while we hold the address/data window,
     * both drive the shared BD/strobe ports and our address (or read data)
     * is clobbered -> the 0xFFFF garbage in the command block. So: if BIOXE
     * goes active during ST_ADDR/ST_DATA, ABORT this word - release the bus,
     * wait out the IOX (recovery gap), and re-request. A memory read/write of
     * the same address is idempotent, so retry is safe and lossless. ST_END
     * is safe: read data is already captured by then. */
    if (top->BIOXE_n == 0 && (g_state == ST_ADDR || g_state == ST_DATA))
    {
        bus_release(top);
        g_req_frozen = false;
        g_gap_cnt    = MIN_GAP_TICKS;   /* let the IOX finish before retrying */
        g_state      = ST_REQ;          /* re-request the SAME transfer        */
        g_aborts++;
        g_prev_bmem_n = (top->BMEM_n != 0);
        return;
    }

    switch (g_state)
    {
    case ST_IDLE:
        /* nothing to do; lines already released by whoever left this state */
        break;

    /* Wait for the allocation: BMEM active AND the grant token reaching us
     * AND our request FROZEN at the BMEM falling edge.
     *
     * The frozen_eff term is the fix for the 93 IOX collisions. Without it, the
     * condition BMEM_n==0 && OUTGRANT_n==0 && BREQ_n==0 is ALSO true during the
     * CPU's own IOX / memory cycles (those pull BMEM_n low too), so we would
     * jump to ST_ADDR and drive the address bus ON TOP OF the CPU - clobbering
     * either our address or the CPU's data. frozen_eff makes us claim ONLY a
     * bus cycle whose BMEM falling edge happened while WE were requesting, i.e.
     * a cycle the arbiter opened FOR US. This is ND_DMA_MASTER.v:201 verbatim
     * (s_frozen_eff), which I had wrongly dropped as "ceremony". */
    case ST_REQ:
        g_req_waits++;
        if (top->BREQ_n == 1 && g_gap_cnt == 0)
        {
            top->BREQ_n = 0;               /* assert once the gap expired */
        }
        if (top->BMEM_n == 0 && top->OUTGRANT_n == 0 && top->BREQ_n == 0
            && frozen_eff && top->BIOXE_n == 1)   /* start ONLY when no IOX active */
        {
            /* Granted: drop the request, start the address cycle.
             * BD is driven INVERTED (gotcha 1). */
            top->BREQ_n       = 1;
            top->BD_23_0_n_IN = (~g_addr) & 0xFFFFFFu;
            top->BAPR_n_IN    = 0;
            top->BINPUT_n_IN  = g_wr ? 0 : 1;   /* low = write into memory */
            g_phase_cnt       = 2;
            g_state           = ST_ADDR;
        }
        break;

    /* Hold address + BAPR for two clocks, then move to the data part. */
    case ST_ADDR:
        if (g_phase_cnt != 0)
        {
            g_phase_cnt--;
        }
        else
        {
            top->BAPR_n_IN = 1;
            /* BINPUT is an ADDRESS-PHASE signal: memory latched the direction
             * at BAPR, so after BAPR it carries no meaning (ND_DMA_MASTER.v
             * :42-44, confirmed against Figure V.4.2). Release it with BAPR. */
            top->BINPUT_n_IN = 1;

            if (g_wr)
            {
                /* Write: data on BD combined with BDAP, inverted. */
                top->BD_23_0_n_IN = (~(uint32_t)g_wdata) & 0xFFFFFFu;
            }
            else
            {
                /* Read: remove the address, BD free for memory to drive. */
                top->BD_23_0_n_IN = BD_IDLE;
            }
            top->BDAP_n_IN = 0;
            g_rd_captured  = false;
            g_state        = ST_DATA;
        }
        break;

    /* Wait for memory's BDRY.
     *
     * GOTCHA 2 - LATCH READ DATA ACROSS THE WHOLE WINDOW, NOT AT THE BDRY
     * EDGE. The board's BDRY25/BDRY50 delay chains release the data drivers
     * BEFORE the externally visible BDRY edge, so a master that samples only
     * at BDRY reads all-ones -> inverts to a plausible-looking but totally
     * wrong 0x0000. Silent corruption, not a crash. Capture every non-idle
     * BD value seen during the window and use the last one.
     * "Data present" is detected as BD != 0xFFFFFF (someone pulled lines
     * low), NOT by a strobe edge. */
    case ST_DATA:
        if (!g_wr && top->BD_23_0_n_OUT != BD_IDLE)
        {
            g_rd_capture  = (uint16_t)((~top->BD_23_0_n_OUT) & 0xFFFFu);
            g_rd_captured = true;
        }
        if (top->BDRY_n_OUT == 0)
        {
            if (!g_wr)
            {
                g_ack_rdata = g_rd_captured
                                ? g_rd_capture
                                : (uint16_t)((~top->BD_23_0_n_OUT) & 0xFFFFu);
            }
            /* Leading edge of BDRY terminates the grant: release our strobes
             * and our data. */
            top->BDAP_n_IN    = 1;
            top->BD_23_0_n_IN = BD_IDLE;
            top->BINPUT_n_IN  = 1;
            g_state           = ST_END;
        }
        break;

    /* Trailing edge of BDRY releases the bus; complete toward the client. */
    case ST_END:
        if (top->BDRY_n_OUT == 1)
        {
            g_ack_pending = true;
            g_ack_err     = false;
            g_gap_cnt     = MIN_GAP_TICKS;
            g_cycles_done++;
            g_state       = ST_IDLE;
        }
        break;
    }

    /* Local hang guard (sim safety net; the real guard is the BCU's). */
    if (g_state != ST_IDLE)
    {
        if (++g_tick_cnt >= TIMEOUT_TICKS)
        {
            bus_release(top);
            g_ack_pending = true;
            g_ack_err     = true;
            g_ack_rdata   = 0;
            g_gap_cnt     = MIN_GAP_TICKS;
            g_cycles_err++;
            if (g_cycles_err <= 3)
            {
                printf("[shim] *** DMA TIMEOUT after %u ticks (addr %06o %s) - "
                       "no BDRY from memory\r\n",
                       TIMEOUT_TICKS, g_addr, g_wr ? "write" : "read");
                fflush(stdout);
            }
            g_state = ST_IDLE;
        }
    }
    else
    {
        g_tick_cnt = 0;
    }

    /* Save BMEM for next tick's falling-edge detection (mirrors the RTL's
     * registered s_prev_bmem_n). Kept LAST so the edge is measured across
     * whole ticks. */
    g_prev_bmem_n = (top->BMEM_n != 0);
}

/* ===================================================================== *
 * nd_bus_hal implementation - the non-blocking client port
 * ===================================================================== */

static bool shim_dma_start(void *ctx, uint32_t address, bool is_write, uint16_t wdata)
{
    (void)ctx;
    if (g_state != ST_IDLE || g_ack_pending) { g_start_busy++; return false; }

    g_start_ok++;
    g_wr        = is_write;
    g_addr      = address & 0xFFFFFFu;
    g_wdata     = wdata;
    g_tick_cnt  = 0;
    g_state     = ST_REQ;
    return true;
}

static bool shim_dma_poll(void *ctx, uint16_t *out_rdata, bool *out_err)
{
    (void)ctx;
    if (!g_ack_pending) return false;

    if (out_rdata) *out_rdata = g_ack_rdata;
    if (out_err)   *out_err   = g_ack_err;
    g_ack_pending = false;          /* true exactly once, on completion */
    return true;
}

static bool shim_dma_busy(void *ctx)
{
    (void)ctx;
    return (g_state != ST_IDLE) || g_ack_pending;
}

static const nd_bus_hal g_shim_hal = {
    /* irq_set  */ nullptr,          /* harness drives BINT10-13 from tick() */
    /* dma_start*/ shim_dma_start,
    /* dma_poll */ shim_dma_poll,
    /* dma_busy */ shim_dma_busy,
    /* ticks    */ nullptr,
    /* trace    */ ndcore_trace
};

const nd_bus_hal *ndcore_shim_hal(void)
{
    return &g_shim_hal;
}

void ndcore_shim_report(void)
{
    printf("[shim] bus master: %lu cycles, %lu timeouts, %lu IOX collisions, "
           "%lu IOX-aborts+retries\r\n",
           g_cycles_done, g_cycles_err, g_collisions, g_aborts);
    printf("[shim] diag: %lu calls (%lu with sysclk=1), %lu ticks, "
           "dma_start %lu ok / %lu refused, %lu grant waits, final state %d\r\n",
           g_calls, g_sysclk_hi, g_ticks_run,
           g_start_ok, g_start_busy, g_req_waits, (int)g_state);
    fflush(stdout);
}

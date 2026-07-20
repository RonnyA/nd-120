/**************************************************************************
** NDDeviceCore -> ND-120 harness ADAPTER - instantiation + registration   **
**                                                                       **
** This file owns the concrete portable cores that the gate exercises. It  **
** is the ONLY place the harness learns that NDDeviceCore exists, and it   **
** is compiled ONLY under -DND120_DEVICECORE (runSim: make DEVICECORE=1).  **
**                                                                       **
** Registered today (Axis A of docs/rtl-gate-plan.md - CHARACTER devices,  **
** no DMA, no memory backdoor):                                            **
**                                                                       **
**   nd_lineprinter, thumbwheel 0  -> IOX 0430-0433, ident 03, level 10    **
**                                                                       **
** The line printer is deliberately first: it needs nothing but the        **
** IOX/IDENT/BINT path the harness already proves with PaperTape/FloppyPIO,**
** and its address window collides with NOTHING else on this bus (tape     **
** 0400-0403, floppy 1560, SMD 1540), so DeviceManager::Claims() can never **
** steal a cycle from a Verilog device.                                    **
**                                                                       **
** The terminal core is NOT registered: on this machine 0300-0307 is the   **
** CPU-internal console (MOPC), and answering it from the bus would fight  **
** the console the whole harness is driven through.                        **
***************************************************************************/

#include "NDDeviceCoreAdapter.h"
#include "NDCoreCharBackend.h"
#include "NDCoreTrace.h"

#ifdef ND120_DEVICECORE_FLOPPY
#include "NDCoreBlockBackend.h"
#endif

#ifdef ND120_DEVICECORE_BUSMASTER
#include "NDCoreShim.h"     /* the C bus master backing nd_bus_hal's dma_* */
#endif

#ifdef ND120_DEVICECORE_TAPE
#include "NDCoreTapeBackend.h"
#endif

#include <stdio.h>
#include <stdlib.h>
#include <memory>

extern "C" {
#include "nd_lineprinter.h"
#ifdef ND120_DEVICECORE_FLOPPY
#include "nd_floppy_dma.h"
#endif
#ifdef ND120_DEVICECORE_TAPE
#include "nd_tape400.h"
#endif
#ifdef ND120_DEVICECORE_DEMODMA
#include "nd_demo_dma.h"
#endif
}

extern DeviceManager deviceManager;   // the one instance, defined in NDBus.cpp

/* ---- the portable cores + their seam ---------------------------------- *
 * File-scope statics: NDDeviceCore never allocates, so the consumer must
 * supply the storage. The adapter only BORROWS these. */
static NDCoreCharBackend g_backend;
static nd_char_dev       g_chardev;
static nd_char_queue     g_charq;
static nd_lineprinter    g_lineprinter;

/* No HAL services are needed by a character device: irq_set is optional and
 * the harness already polls Tick()'s interruptBits onto BINT10..13, and there
 * is no DMA on this axis. All-NULL is the documented configuration. */
static const nd_bus_hal  g_hal = {
    NULL,           /* irq_set   - harness polls Tick()'s interruptBits      */
    NULL,           /* dma_start - no DMA on the character axis             */
    NULL,           /* dma_poll                                              */
    NULL,           /* dma_busy                                              */
    NULL,           /* ticks                                                 */
    ndcore_trace    /* trace     - ND120_CORE_TRACE=1 to see the records     */
};

static void ndcore_atexit_report()
{
    ndcore_char_backend_report(&g_backend);
}

/* ======================================================================= **
** FLOPPY-DMA 3112 (ND120_DEVICECORE_FLOPPY)                              **
**                                                                        **
** Registers the PORTABLE nd_floppy_dma core at IOX 1560-1567, ident 021,  **
** level 11 - the address the CPU's `1560&` autoload talks to. This build  **
** must therefore have NO other floppy on the bus: build with              **
** VERILOG_TAPE=0 (which sets every INCLUDE_* to 0, disconnecting the      **
** Verilog device cores AND the ND-BUS-SLAVE/DMA-MASTER RTL), and the      **
** legacy C++ FloppyPIO is suppressed in NDBus.cpp addDevices().           **
**                                                                        **
** NOTE the HAL: dma_* are still NULL. The `1560&` autoload path is PURE   **
** IOX - a PIO byte server over registers +0/+2/+3, no DMA, no command     **
** block (see NDDeviceCore/docs/floppy-autoload-microcode-contract.md).    **
** The DMA engine exists only so the core's ordinary command path can be   **
** constructed; it is never driven on the autoload path. The C bus-master  **
** cycle (NDCoreShim) is the NEXT milestone, not this one.                 **
** ======================================================================= */
#ifdef ND120_DEVICECORE_FLOPPY

/* ===== LAYER 2 of the "no Verilog IO device may exist" guarantee ========= *
 *
 * Testing our C device against a bus that ALSO carries a Verilog device at the
 * same IOX window is worthless: the two race per cycle, and the failure looks
 * like intermittent wrong data rather than an error. Worse, a PASS would be
 * meaningless - we could be grading the Verilog core's answers.
 *
 * Three independent layers enforce this; all three must hold:
 *   1. runSim/Makefile  - $(error) if DEVICECORE_FLOPPY=1 without VERILOG_TAPE=0
 *                         (blocks the bad combo before anything is built)
 *   2. THIS #error      - catches ND120_VERILOG_DEVICES arriving by any other
 *                         route, e.g. hand-passed EXTRA_CFLAGS
 *   3. `make verify-devicecore-c-only` - greps the ELABORATED model's symbol
 *                         table for device instances. That one is evidence,
 *                         not a flag: it inspects what verilator actually
 *                         built, so it holds even if a flag lies.
 *
 * Layer 3 exists because a flag-based check is only as good as the flag. It
 * was worth building: the obvious structural test (do the FDISK_ / TAPE_
 * backend ports exist?) turns out to PROVE NOTHING - those ports are present
 * even with every device excluded. Only the instance symbols disappear. */
#ifdef ND120_VERILOG_DEVICES
#error "ND120_DEVICECORE_FLOPPY with ND120_VERILOG_DEVICES: the Verilog floppy \
would also drive IOX 1560-1567 and race our C core every cycle. Build the \
C-device gate with VERILOG_TAPE=0 (which sets INCLUDE_TAPE/FLOPPY/SMD = 0 and \
leaves no Verilog IO device instantiated at all)."
#endif

/* --- the "no bus master yet" DMA HAL ------------------------------------ *
 * The C bus-master cycle (NDCoreShim, driving BREQ/BAPR/BDAP/BDRY on the raw
 * bus) is the NEXT milestone and does not exist yet. But nd_dma_engine_init()
 * rightly REFUSES a DMA engine whose HAL has no DMA primitives, so we cannot
 * simply pass NULLs here.
 *
 * These stubs therefore fail LOUDLY instead of silently. That turns "the
 * autoload path uses no DMA" from a claim into something the gate PROVES: if
 * anything ever reaches the bus master on this path, the log says so in
 * capitals and the transfer errors rather than quietly returning zeros. */
/* RATE-LIMITED (Ronny, 20-JUL-2026: "do not allow log files bigger than 500MB").
 *
 * A refused DMA is not a one-shot event: the device core re-submits the request
 * every tick, so an unthrottled printf here emits 3 lines per retry FOREVER.
 * Measured: the `1560&` boot ran to its cycle limit and produced a 2.2 GB log,
 * of which the first ~1000 lines carried ALL the information - the rest was this
 * message repeating byte-for-byte.
 *
 * So: shout the first few times (that is what makes the failure impossible to
 * miss), then latch and stay silent, reporting the total once via atexit. The
 * diagnostic value is preserved; the disk-filling is not. */
#define DMA_UNIMPL_MAX_PRINTS 3u
static unsigned long g_dma_unimpl_count = 0;

static void ndcore_dma_unimpl_summary(void)
{
    if (g_dma_unimpl_count > DMA_UNIMPL_MAX_PRINTS) {
        printf("[floppycore] *** DMA-with-no-bus-master happened %lu times total\r\n"
               "[floppycore] *** (further messages suppressed after %u)\r\n",
               g_dma_unimpl_count, DMA_UNIMPL_MAX_PRINTS);
        fflush(stdout);
    }
}

static bool ndcore_dma_start_unimpl(void *ctx, uint32_t address, bool is_write,
                                    uint16_t wdata)
{
    (void)ctx; (void)wdata;

    if (g_dma_unimpl_count == 0)
        atexit(ndcore_dma_unimpl_summary);   /* registered once, on first refusal */

    if (++g_dma_unimpl_count <= DMA_UNIMPL_MAX_PRINTS) {
        printf("[floppycore] *** DMA %s at %06o BUT THERE IS NO BUS MASTER YET ***\r\n"
               "[floppycore] *** the 1560& autoload path is pure IOX - reaching here\r\n"
               "[floppycore] *** means the core took the COMMAND path, not autoload\r\n",
               is_write ? "WRITE" : "READ", address);
        fflush(stdout);
    }
    return false;      /* never accepted */
}

static bool ndcore_dma_poll_unimpl(void *ctx, uint16_t *out_rdata, bool *out_err)
{
    (void)ctx;
    if (out_rdata) *out_rdata = 0;
    if (out_err)   *out_err   = true;
    return false;      /* nothing is ever in flight */
}

static bool ndcore_dma_busy_unimpl(void *ctx)
{
    (void)ctx;
    return false;
}

static const nd_bus_hal g_hal_dma = {
    NULL,                       /* irq_set - harness polls Tick()          */
    ndcore_dma_start_unimpl,
    ndcore_dma_poll_unimpl,
    ndcore_dma_busy_unimpl,
    NULL,                       /* ticks                                    */
    ndcore_trace
};

static NDCoreBlockBackend g_blk;
static nd_storage_dev     g_sdev;
static nd_storage_queue   g_squeue;
static nd_dma_engine      g_dma;
static nd_floppy_dma      g_floppy;

static void ndcore_floppy_atexit()
{
    printf("[floppycore] backend: %lu reads, %lu writes, %lu errors; "
           "%lu core trace records\r\n",
           g_blk.reads, g_blk.writes, g_blk.errors, ndcore_trace_count());
    fflush(stdout);
    ndcore_block_backend_close(&g_blk);
}

static void addFloppyCore()
{
    const char *img = getenv("ND120_FLOPPYCORE_IMG");

    ndcore_block_backend_init(&g_blk);

    if (img == NULL || img[0] == '\0')
    {
        printf("[floppycore] FATAL: ND120_FLOPPYCORE_IMG is not set - there is "
               "no diskette to serve\r\n");
        return;
    }

    /* Read-only: a boot gate must never be able to damage a real archive
     * diskette image, and nothing on the autoload path writes. */
    if (!ndcore_block_backend_attach(&g_blk, 0, img, false))
    {
        printf("[floppycore] FATAL: could not attach %s\r\n", img);
        return;
    }

    g_sdev = ndcore_block_backend_dev(&g_blk);

    if (!nd_storage_queue_init(&g_squeue, &g_sdev))
    {
        printf("[floppycore] FATAL: nd_storage_queue_init failed\r\n");
        return;
    }

    /* The REAL C bus master (NDCoreShim.cpp) - it drives BREQ/BAPR/BDAP/BD on
     * the raw ND120_TOP ports against the real arbiter and real RAM.
     *
     * Until 20-JUL-2026 this was g_hal_dma, a set of loud-failure stubs, which
     * is what PROVED the `1560&` autoload path never touches DMA (see
     * NDDeviceCore/docs/floppy-1560-boot-trace.md). Now that the master
     * exists, the booted program's DMA request can actually be served.
     * ND120_NO_BUSMASTER=1 selects the old loud-failure stubs instead. That is
     * not dead code kept for sentiment: it re-proves, on demand, that the
     * autoload path reaches DMA exactly never. If that gate ever starts
     * printing "NO BUS MASTER", the core took the COMMAND path by mistake. */
    const bool no_master = (getenv("ND120_NO_BUSMASTER") != NULL);
    const nd_bus_hal *dma_hal = no_master ? &g_hal_dma : ndcore_shim_hal();

    printf("[floppycore] DMA HAL: %s\r\n",
           no_master ? "NONE (loud-failure stubs, ND120_NO_BUSMASTER=1)"
                     : "C bus master (NDCoreShim, raw ND120_TOP bus ports)");

    if (!nd_dma_engine_init(&g_dma, dma_hal, NULL))
    {
        printf("[floppycore] FATAL: nd_dma_engine_init failed\r\n");
        return;
    }

    if (!no_master) atexit(ndcore_shim_report);

    /* thumbwheel 0 -> base 01560, ident 021, interrupt level 11 */
    if (!nd_floppy_dma_init(&g_floppy, 0, &g_hal, NULL, &g_dma, &g_squeue))
    {
        printf("[floppycore] FATAL: nd_floppy_dma_init failed\r\n");
        return;
    }

    nd_device *dev = nd_floppy_dma_device(&g_floppy);

    printf("[floppycore] NDDeviceCore nd_floppy_dma registered: "
           "IOX %06o-%06o ident %03o level %u\r\n",
           dev->start_address, dev->end_address,
           dev->ident_code, (unsigned)dev->int_level);
    fflush(stdout);

    deviceManager.AddDevice(std::unique_ptr<NDDevice>(
        new NDDeviceCoreAdapter(dev, NULL, &g_squeue, &g_dma)));

    atexit(ndcore_floppy_atexit);
}

#else
static void addFloppyCore() { }   /* not built - nothing to register */
#endif /* ND120_DEVICECORE_FLOPPY */

/* ======================================================================= **
** TAPE-400 PAPERTAPE READER (ND120_DEVICECORE_TAPE)                      **
**                                                                        **
** Registers the PORTABLE nd_tape400 core at IOX 0400-0403, ident 02,      **
** level 12 - the address the CPU's `400$` BPUN loader talks to.           **
**                                                                        **
** `400$` uses the SAME microcode character-loader path as `1560&`         **
** (ETLO1): write control +3 = 004005 (DVACT) -> poll status +2 bit 3      **
** (RFT) -> read data +0. So this core must serve the same handshake; the  **
** only difference is that a papertape is a pure byte stream with no       **
** media geometry at all. See                                               **
** NDDeviceCore/docs/floppy-autoload-microcode-contract.md - the contract  **
** is the loader's, not the device's, so it applies to both.               **
**                                                                        **
** NO DMA anywhere: TAPE-400 is a character device, so the HAL's dma_*     **
** members are genuinely NULL here (unlike the floppy, which owns a DMA    **
** engine for its command path).                                           **
**                                                                        **
** Image: ND120_TAPECORE_IMG, default BOOT.BPUN (Ronny, 20-JUL-2026).      **
** NB BOOT.BPUN is NOT 8.3 - the extension is 4 chars - but nothing here   **
** requires 8.3, and NDModulE's FatFs has FF_USE_LFN=3 / FF_MAX_LFN=255,   **
** so the same name works on the Pico's SD card.                            **
** ======================================================================= */
#ifdef ND120_DEVICECORE_TAPE

/* Same three-layer rule as the floppy: no Verilog IO device may share the
 * bus with a C core under test. See the block above addFloppyCore(). */
#ifdef ND120_VERILOG_DEVICES
#error "ND120_DEVICECORE_TAPE with ND120_VERILOG_DEVICES: the Verilog ND_TAPE_400 \
would also drive IOX 0400-0403 and race our C core every cycle. Build the C-device \
gate with VERILOG_TAPE=0."
#endif

static NDCoreTapeBackend g_tape_backend;
static nd_storage        g_tape_storage;
static nd_tape400        g_tape400;

static void ndcore_tape_atexit()
{
    printf("[tapecore] tape: %lu bytes served, %lu EOF, %lu rewinds\r\n",
           g_tape_backend.bytes, g_tape_backend.eofs, g_tape_backend.rewinds);
    fflush(stdout);
    ndcore_tape_backend_close(&g_tape_backend);
}

static void addTapeCore()
{
    const char *img = getenv("ND120_TAPECORE_IMG");
    if (img == NULL || img[0] == '\0')
        img = "BOOT.BPUN";     /* Ronny's choice; LFN is enabled on the card */

    ndcore_tape_backend_init(&g_tape_backend);

    if (!ndcore_tape_backend_mount(&g_tape_backend, img))
    {
        printf("[tapecore] FATAL: no papertape to read - `400$` would hang the\r\n"
               "[tapecore]        CPU forever (the loader has no timeout)\r\n");
        return;
    }

    g_tape_storage = ndcore_tape_backend_storage(&g_tape_backend);

    /* thumbwheel 0 -> IOX 0400-0403, ident 02, interrupt level 12 */
    if (!nd_tape400_init(&g_tape400, 0, &g_hal, NULL, &g_tape_storage))
    {
        printf("[tapecore] FATAL: nd_tape400_init failed\r\n");
        return;
    }

    nd_device *dev = nd_tape400_device(&g_tape400);

    printf("[tapecore] NDDeviceCore nd_tape400 registered: "
           "IOX %06o-%06o ident %03o level %u\r\n",
           dev->start_address, dev->end_address,
           dev->ident_code, (unsigned)dev->int_level);
    fflush(stdout);

    /* No char/storage/DMA seam to pump: nd_tape400 pulls bytes synchronously
     * through the legacy streaming nd_storage struct. */
    deviceManager.AddDevice(std::unique_ptr<NDDevice>(
        new NDDeviceCoreAdapter(dev, NULL)));

    atexit(ndcore_tape_atexit);
}

#else
static void addTapeCore() { }   /* not built - nothing to register */
#endif /* ND120_DEVICECORE_TAPE */

/* ===================================================================== *
 * nd_demo_dma - the DMA PIPE-CLEANER at IOX 0500-0503 (ident 077, lvl 11)
 *
 * Deliberately the FIRST client of the C bus master: it has no disk
 * geometry, no BPUN stream and no boot path, so a DMA failure here is a DMA
 * failure and nothing else. Its write pattern (052525 ^ a ^ a<<7) is the
 * same shape as runSim's dmat_pattern, so a gate can predict exactly what
 * must land in ND RAM and verify it through the existing RAM backdoor.
 * ===================================================================== */
#ifdef ND120_DEVICECORE_DEMODMA
static nd_demo_dma g_demodma;

static void addDemoDmaCore()
{
    if (!nd_demo_dma_init(&g_demodma, ndcore_shim_hal(), NULL))
    {
        printf("[demodma] FATAL: nd_demo_dma_init failed (needs dma_* HAL)\r\n");
        return;
    }

    nd_device *dev = nd_demo_dma_device(&g_demodma);

    printf("[demodma] NDDeviceCore nd_demo_dma registered: "
           "IOX %06o-%06o ident %03o level %u\r\n",
           dev->start_address, dev->end_address,
           dev->ident_code, (unsigned)dev->int_level);
    fflush(stdout);

    deviceManager.AddDevice(std::unique_ptr<NDDevice>(
        new NDDeviceCoreAdapter(dev, NULL)));

    atexit(ndcore_shim_report);
}
#else
static void addDemoDmaCore() { }   /* not built - nothing to register */
#endif /* ND120_DEVICECORE_DEMODMA */

void addDevicesCore()
{
    ndcore_char_backend_init(&g_backend);
    g_chardev = ndcore_char_backend_dev(&g_backend);

    if (!nd_char_queue_init(&g_charq, &g_chardev))
    {
        printf("[democore] FATAL: nd_char_queue_init failed\r\n");
        return;
    }

    /* thumbwheel 0 -> base 0430 (octal), ident 03, interrupt level 10 */
    if (!nd_lineprinter_init(&g_lineprinter, 0, &g_hal, NULL, &g_charq))
    {
        printf("[democore] FATAL: nd_lineprinter_init failed\r\n");
        return;
    }

    nd_device *dev = nd_lineprinter_device(&g_lineprinter);

    printf("[democore] NDDeviceCore nd_lineprinter registered: "
           "IOX %06o-%06o ident %03o level %u\r\n",
           dev->start_address, dev->end_address,
           dev->ident_code, (unsigned)dev->int_level);
    fflush(stdout);

    deviceManager.AddDevice(std::unique_ptr<NDDevice>(
        new NDDeviceCoreAdapter(dev, &g_charq)));

    /* Report the captured paper + the gate verdict when the sim ends, so an
     * early/abnormal exit still produces a machine-checkable RESULT line. */
    atexit(ndcore_atexit_report);

    addDemoDmaCore();
    addFloppyCore();
    addTapeCore();
}

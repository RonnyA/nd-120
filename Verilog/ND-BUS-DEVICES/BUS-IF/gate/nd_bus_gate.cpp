/**************************************************************************
** ND-BUS SEAM GATE (Verilator) - the REAL RTL vs the portable C core     **
**                                                                        **
** Drives the CPU-side of ND_BUS_SLAVE.v (BAPR/BIOXE/BINACK/BD...) to      **
** issue real IOX cycles, and bridges the device-side ports (iox_addr/wr/  **
** wdata/rd/rdata, int_pending, ident_*) to a REAL NDDeviceCore device     **
** (the line printer) - the "one C++ adapter" from docs/rtl-gate-plan.md.  **
** Proves the shipped C core behaves correctly when driven through the     **
** authoritative Verilog seam, with NO ND-100 CPU and NO hardware.         **
**                                                                        **
** This is the Verilator twin of the Tang-20K nd-bus-test exerciser: the   **
** exerciser generates the same cycles from a UART menu on silicon; here a **
** scripted harness generates them in simulation so it runs in CI.         **
**                                                                        **
** Char devices gate FIRST (no DMA infra needed), per the gate plan.       **
**                                                                        **
** Ronny Hansen                                                           **
***************************************************************************/

#include "VND_BUS_SLAVE.h"
#include "verilated.h"

#include <cstdio>
#include <cstring>
#include <cstdint>

extern "C" {
#include "nd_lineprinter.h"   /* pulls nd_device.h + nd_char.h */
}

/* --- fake nd_char backend (tx-only, a couple ticks of latency) ---------- *
 * Identical shape to test_lineprinter.c's backend - the printer PUTs bytes,
 * we capture them on the "paper". */
#define BK_LATENCY 2
typedef struct { uint8_t tx[64]; int tx_len; bool pending; int latency; } fake_backend;

static bool bk_start(void *ctx, nd_char_request *req)
{
    fake_backend *b = (fake_backend *)ctx; (void)req;
    if (b->pending) return false;
    b->pending = true; b->latency = BK_LATENCY; return true;
}
static bool bk_poll(void *ctx, nd_char_request *req)
{
    fake_backend *b = (fake_backend *)ctx;
    if (!b->pending) return false;
    if (--b->latency > 0) return false;
    b->pending = false;
    if (req->op == ND_CHAR_PUT && b->tx_len < (int)sizeof(b->tx))
        b->tx[b->tx_len++] = req->value;
    req->have_byte = false;
    return true;
}
static bool bk_busy(void *ctx) { return ((fake_backend *)ctx)->pending; }

/* Verilator links against this legacy time hook when not using SystemC/timing. */
double sc_time_stamp(void) { return 0; }

/* --- globals ------------------------------------------------------------ */
static VND_BUS_SLAVE *dut;
static nd_lineprinter g_lp;
static nd_char_queue  g_q;
static fake_backend   g_bk;
static nd_char_dev    g_dev;

static int g_checks = 0, g_fail = 0;
#define CHECK(cond, msg) do { g_checks++; \
    if (!(cond)) { printf("  FAIL: %s\n", (msg)); g_fail++; } \
    else         { printf("  ok:   %s\n", (msg)); } } while (0)

/* interrupt_bits (bit10..13) -> int_pending[3:0] */
static uint8_t map_int(uint16_t ib)
{
    return (uint8_t)(((ib >> 10) & 1u) | (((ib >> 11) & 1u) << 1) |
                     (((ib >> 12) & 1u) << 2) | (((ib >> 13) & 1u) << 3));
}

/* THE ADAPTER: run while clk is low, bridging the device-side seam to the C
 * core. iox_wr / iox_rd / ident_strobe are 1-cycle strobes, so acting on their
 * level here fires the C-core call exactly once per transaction. */
static void adapter(void)
{
    nd_device *d = nd_lineprinter_device(&g_lp);

    if (dut->iox_wr && nd_device_claims(d, dut->iox_addr))
        d->vt->write(d, dut->iox_addr, dut->iox_wdata);

    if (dut->iox_rd)
        dut->iox_rdata = nd_device_claims(d, dut->iox_addr)
                       ? d->vt->read(d, dut->iox_addr) : 0;
    else
        dut->iox_rdata = 0;

    dut->int_pending = map_int(d->interrupt_bits);

    if (dut->ident_strobe) {
        uint16_t code = d->vt->ident(d, dut->ident_level);
        dut->ident_hit  = (code != 0);
        dut->ident_code = code;
    } else {
        dut->ident_hit  = 0;
        dut->ident_code = 0;
    }
}

/* Advance the C device + its char backend one step (per clock). */
static void device_pump(void)
{
    nd_device *d = nd_lineprinter_device(&g_lp);
    d->vt->tick(d);
    nd_char_queue_tick(&g_q);
}

/* One full clock: settle-at-low, bridge, posedge, then pump the C device. */
static void tick(void)
{
    dut->sysclk = 0; dut->eval();
    adapter();       dut->eval();
    dut->sysclk = 1; dut->eval();
    device_pump();
}

static void set_bd(uint32_t v) { dut->BD_23_0_n_OUT = (~v) & 0xFFFFFFu; }

static void bus_idle(void)
{
    dut->BAPR_n = 1; dut->BIOXE_n = 1; dut->BINACK_n = 1; dut->OUTIDENT_n = 1;
    dut->BD_23_0_n_OUT = 0xFFFFFFu;
}

static void settle(int n) { while (n-- > 0) { bus_idle(); tick(); } }

/* IOX WRITE cycle. addr is the full IOX address; ND convention: odd = write, so
 * a write register (e.g. 0431) has LSB=1, which the RTL decodes as ST_WRITE. */
static void iox_write_cycle(uint32_t addr, uint16_t data)
{
    set_bd(addr);
    dut->BAPR_n = 1; tick();     /* ensure prev_bapr = 1                 */
    dut->BAPR_n = 0; tick();     /* falling edge: capture addr, ST_WRITE */
    dut->BAPR_n = 1; tick();     /* address now latched                  */

    set_bd(data);
    dut->BIOXE_n = 1; tick();
    dut->BIOXE_n = 0; tick();    /* falling: iox_wr strobe, BDRY low     */
    tick();
    dut->BIOXE_n = 1; tick();    /* rising: release                      */
    settle(2);
}

/* IOX READ cycle. addr LSB=0 (even) -> ST_READ. Returns the value the RTL
 * drove back on BD_23_0_n_IN (de-inverted). */
static uint16_t iox_read_cycle(uint32_t addr)
{
    uint16_t rd;

    set_bd(addr);
    dut->BAPR_n = 1; tick();
    dut->BAPR_n = 0; tick();     /* capture addr, ST_READ                */
    dut->BAPR_n = 1; tick();

    dut->BIOXE_n = 1; tick();
    dut->BIOXE_n = 0; tick();    /* BIOXE fall: BINPUT_n low             */
    dut->BINACK_n = 1; tick();
    dut->BINACK_n = 0; tick();   /* BINACK fall: iox_rd next cycle       */
    tick();                      /* iox_rd high: adapter drives rdata,
                                    posedge captures BD_23_0_n_IN        */
    rd = (uint16_t)((~dut->BD_23_0_n_IN) & 0xFFFFu);

    dut->BINACK_n = 1;
    dut->BIOXE_n  = 1; tick();   /* BIOXE rise: release                  */
    settle(2);
    return rd;
}

/* Line-printer register offsets from its base (0430). */
enum { OFF_WRITE_DATA = 1, OFF_READ_STATUS = 2, OFF_WRITE_CONTROL = 3 };
#define ST_READY      (1u << 3)
#define ST_INT_EN     (1u << 0)
#define CT_INT_ENABLE (1u << 0)

int main(int argc, char **argv)
{
    Verilated::commandArgs(argc, argv);
    dut = new VND_BUS_SLAVE;

    /* Build the C line printer (thumbwheel 0 -> base 0430, ident 03, lvl 10). */
    memset(&g_bk, 0, sizeof(g_bk));
    g_dev.start = bk_start; g_dev.poll = bk_poll; g_dev.busy = bk_busy;
    g_dev.rx_ready = NULL; g_dev.reset = NULL; g_dev.ctx = &g_bk;
    nd_char_queue_init(&g_q, &g_dev);
    if (!nd_lineprinter_init(&g_lp, 0, NULL, NULL, &g_q)) {
        printf("  FAIL: lineprinter init\n");
        printf("TB_RESULT: FAIL\n");
        return 1;
    }
    uint32_t base = nd_lineprinter_device(&g_lp)->start_address;   /* 0430 */

    printf("=== ND-BUS SEAM GATE: line printer through ND_BUS_SLAVE.v ===\n");

    /* Reset the RTL. */
    bus_idle();
    dut->sys_rst_n = 0;
    dut->iox_rdata = 0; dut->int_pending = 0; dut->ident_hit = 0; dut->ident_code = 0;
    for (int i = 0; i < 5; i++) tick();
    dut->sys_rst_n = 1;
    settle(3);

    /* 1) CPU writes 'H' to the data register via a real IOX WRITE cycle. */
    iox_write_cycle(base + OFF_WRITE_DATA, 'H');
    settle(20);                                  /* let the print complete */
    CHECK(g_bk.tx_len == 1, "one byte reached the paper via the RTL");
    CHECK(g_bk.tx_len >= 1 && g_bk.tx[0] == 'H', "paper got 'H' through the seam");

    /* 2) CPU reads the status register via a real IOX READ cycle. */
    {
        uint16_t st = iox_read_cycle(base + OFF_READ_STATUS);
        CHECK((st & ST_READY) != 0, "status READY read back through the RTL");
    }

    /* 3) Enable the printer interrupt; the RTL must assert BINT10 (level 10). */
    iox_write_cycle(base + OFF_WRITE_CONTROL, CT_INT_ENABLE);
    settle(3);
    CHECK((iox_read_cycle(base + OFF_READ_STATUS) & ST_INT_EN) != 0,
          "interrupt-enable bit set (read back)");
    CHECK(dut->BINT10_n == 0, "BINT10 asserted by the RTL from the core's int");
    CHECK(dut->BINT11_n == 1 && dut->BINT12_n == 1 && dut->BINT13_n == 1,
          "only level 10 asserted");

    dut->final();
    delete dut;

    printf("%d checks, %d failures\n", g_checks, g_fail);
    printf("TB_RESULT: %s\n", (g_fail == 0) ? "PASS" : "FAIL");
    return (g_fail == 0) ? 0 : 1;
}

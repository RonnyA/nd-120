/**************************************************************************
** ND120 Latch vs Flip-Flop Signal Comparison Tool                      **
**                                                                       **
** Runs the simulation and logs key internal signals at every posedge    **
** OSC to stdout as CSV. Run twice (once with VERILATOR_SIM, once       **
** without) and diff the output to find where latch and FF behavior     **
** diverge.                                                              **
**                                                                       **
** Usage:                                                                **
**   make compare_latch   -> trace_latch.csv                             **
**   make compare_ff      -> trace_ff.csv                                **
**   diff trace_latch.csv trace_ff.csv                                   **
**                                                                       **
** Last reviewed: 28-MAR-2026                                            **
** Ronny Hansen                                                          **
***************************************************************************/

#include <cstdio>
#include <cstdint>
#include <cstring>
#include <cstdlib>

#include "VND120_TOP.h"
#include "VND120_TOP___024root.h"
#include "verilated.h"

#include "NDBus.h"
#include "NDDevices.h"

// BPUN load helpers (copied from test_nd120.cpp)
typedef unsigned short ushort;

static int gb(FILE *f)
{
    int w;
    if (f == NULL) return 00;
    w = getc(f) & 0377;
    return w;
}

static int gw(FILE *f)
{
    int c = gb(f);
    return (c << 8) | gb(f);
}

static ushort calc_parity(uint16_t val)
{
    ushort parity = 0;
    for (int i = 0; i < 8; i++) {
        parity ^= (val & 1);
        val >>= 1;
    }
    return parity == 0 ? 1 : 0;
}

void loadfile(char *fn, int off, uint8_t *low_array, uint8_t *low_array9,
              uint8_t *high_array, uint8_t *high_array9)
{
    int B, C, E, F, H, I;
    int w, i;
    unsigned short s;
    FILE *f;

    if ((f = fopen(fn, "r")) == 0) {
        fprintf(stderr, "Unable to open file %s\n", fn);
        return;
    }

    for (B = C = 0; (w = gb(f) & 0177) != '!';) {
        switch (w) {
        case '\n': continue;
        case '\r': B = C, C = 0; break;
        case '0': case '1': case '2': case '3':
        case '4': case '5': case '6': case '7':
            C = (C << 3) | (w - '0'); break;
        default: B = C = 0;
        }
    }

    fprintf(stderr, "Load address %06o\n", E = gw(f));
    fprintf(stderr, "Word count   %06o\n", F = gw(f));
    for (i = s = 0; i < F; i++) {
        int data16 = gw(f);
        low_array[E + i] = data16 & 0xFF;
        high_array[E + i] = (data16 >> 8) & 0xFF;
        low_array9[E + i] = calc_parity(low_array[E + i]);
        high_array9[E + i] = calc_parity(high_array[E + i]);
        s += data16;
    }
    H = gw(f);
    if (H != s) fprintf(stderr, "Bad checksum: %06o != %06o\n", H, s);
    I = gw(f);
    fprintf(stderr, "Words read   %06o\n", i);
    fclose(f);
}

int main(int argc, char **argv)
{
    Verilated::commandArgs(argc, argv);
    VND120_TOP *top = new VND120_TOP;

    // Load microcode into RAM
    auto &ram_low = top->rootp->ND120_TOP__DOT__CPU_BOARD__DOT__MEM__DOT__RAM__DOT__CHIP_15H__DOT__sdram;
    auto &ram_low_9 = top->rootp->ND120_TOP__DOT__CPU_BOARD__DOT__MEM__DOT__RAM__DOT__CHIP_15H__DOT__sdram_9;
    auto &ram_high = top->rootp->ND120_TOP__DOT__CPU_BOARD__DOT__MEM__DOT__RAM__DOT__CHIP_15J__DOT__sdram;
    auto &ram_high_9 = top->rootp->ND120_TOP__DOT__CPU_BOARD__DOT__MEM__DOT__RAM__DOT__CHIP_15J__DOT__sdram_9;

    char *fname = strdup("INSTRUCTION-B.BPUN");
    loadfile(fname, 0, &ram_low[0], &ram_low_9[0], &ram_high[0], &ram_high_9[0]);

    // Set defaults
    top->btn1 = false;
    top->uartRx = 1;
    top->BD_23_0_n_IN = 0xFFFFFF;
    top->BREQ_n = 1;
    top->BINT10_n = 1;
    top->BINT11_n = 1;
    top->BINT12_n = 1;
    top->BINT13_n = 1;
    top->BINT15_n = 1;
    top->POWSENSE_n = 1;
    top->SEMRQ_n_IN = 1;
    top->BINPUT_n_IN = 1;
    top->BDAP_n_IN = 1;
    top->BDRY_n_IN = 1;
    top->BAPR_n_IN = 1;
    top->DEBUGFLAG = 0;

    // Initial eval to let async resets and combinational logic settle
    top->sysclk = 0;
    top->eval();

    long maxTicks = 1000000;  // 1M ticks

    // CSV header
    printf("cycle,CSA,TERM_n,MCLK,MACLK,"
           "EMD,CBWRITE,CMWRITE,BACT,EBADR_n,"
           "DAP,BLOCK,RERR,"
           "BDRY,DISB,TST,BLOCKL,"
           "LED\n");

    for (long cnt = 0; cnt < maxTicks; cnt++)
    {
        if (cnt == 100)
            top->btn1 = true;  // Release reset

        // Rising edge: set clock high, evaluate
        top->sysclk = 1;
        top->eval();
        proccess_bif_signal(top);
        top->eval();

        // Sample signals at posedge OSC (after eval settles)
        {
            auto &r = *top->rootp;

            printf("%ld,%d,%d,%d,%d,"
                   "%d,%d,%d,%d,%d,"
                   "%d,%d,%d,"
                   "%d,%d,%d,%d,"
                   "%d\n",
                cnt,
                (int)top->CSA_12_0,
                (int)r.ND120_TOP__DOT__CPU_BOARD__DOT__s_term_n,
                (int)r.ND120_TOP__DOT__CPU_BOARD__DOT__s_maclk,
                0,  // MACLK placeholder (not separately accessible)

                // Group 1: BIF PALs
                (int)r.ND120_TOP__DOT__CPU_BOARD__DOT__BIF__DOT__DPATH__DOT__LDBCTL__DOT__PAL_44302_ULBC1__DOT__EMD,
                (int)r.ND120_TOP__DOT__CPU_BOARD__DOT__BIF__DOT__DPATH__DOT__LDBCTL__DOT__PAL_44303_ULBC2__DOT__CBWRITE,
                (int)r.ND120_TOP__DOT__CPU_BOARD__DOT__BIF__DOT__DPATH__DOT__LDBCTL__DOT__PAL_44303_ULBC2__DOT__CMWRITE,
                (int)r.ND120_TOP__DOT__CPU_BOARD__DOT__BIF__DOT__DPATH__DOT__LDBCTL__DOT__PAL_44304_ULBC3__DOT__BACT_reg,
                (int)r.ND120_TOP__DOT__CPU_BOARD__DOT__BIF__DOT__DPATH__DOT__LDBCTL__DOT__PAL_44304_ULBC3__DOT__EBADR_n_reg,

                (int)r.ND120_TOP__DOT__CPU_BOARD__DOT__BIF__DOT__BCTL__DOT__PAL_44401_UBTIM__DOT__DAP,
                (int)r.ND120_TOP__DOT__CPU_BOARD__DOT__BIF__DOT__BCTL__DOT__PAL_45001_UBPAR__DOT__BLOCK_reg,
                (int)r.ND120_TOP__DOT__CPU_BOARD__DOT__BIF__DOT__BCTL__DOT__PAL_45001_UBPAR__DOT__RERR_reg,

                // Group 2: Memory PALs
                (int)r.ND120_TOP__DOT__CPU_BOARD__DOT__MEM__DOT__LBDIF__DOT__PAL_44310_ULBDIF__DOT__BDRY,
                (int)r.ND120_TOP__DOT__CPU_BOARD__DOT__MEM__DOT__DATA__DOT__PAL_45008_UDATA__DOT__DISB_reg,
                (int)r.ND120_TOP__DOT__CPU_BOARD__DOT__MEM__DOT__DATA__DOT__PAL_45008_UDATA__DOT__TST_reg,
                (int)r.ND120_TOP__DOT__CPU_BOARD__DOT__MEM__DOT__ERROR__DOT__PAL_45009_UERROR__DOT__BLOCKL_reg,

                // Progress indicator
                (int)top->led
            );
        }

        // Falling edge: set clock low, evaluate
        top->sysclk = 0;
        top->eval();
    }

    top->final();
    delete top;
    return 0;
}

// ND120 sim - windowed full-signal FST capture (migrated out of runSim 29-JUL-2026)
//
// Captures EVERY signal in the verilated model to an FST file, but only inside
// a bounded window armed by a trigger, so a multi-hour run stays far below the
// 1GB artifact cap while preserving complete GTKWave observability around the
// event of interest. Proven use: PAGING test 3/11 root-causing (found the
// PAL_44306A EIPL and PAL_45001B / BIF_DPATH_9 PES-PEA bugs).
//
// Requirements:
//   - Verilate with --trace-fst instead of --trace (see the harness Makefile's
//     trace flag; verilated_fst_c.h must be available).
//   - Compile the harness with -DTRACE_FST_WINDOW.
//
// Usage in a harness main loop (two calls):
//   #include "fst_window.h"
//   ...
//   VND120_TOP *top = new VND120_TOP;          // after model creation:
//   fstw_init(top);                            // reads env, opens the file
//   ...
//   while (...) {                              // once per half-cycle, BEFORE
//       fstw_tick(trigger_value);              // (or after) eval - pass the
//       ...                                    // value the trigger compares
//   }                                          // against (e.g. the P register)
//
// Environment knobs (all optional):
//   ND120_FST_TRIG_P     octal trigger value; capture arms when the value
//                        passed to fstw_tick() equals it (default 077675)
//   ND120_FST_HALFCYCLES window length in half-cycles (default 200000)
//   ND120_FST_OUT        output path (default trace_window.fst)
//
// The capture prints [fst] START/DONE lines with the loop count so FST time
// correlates with any console probes. One window per run; after DONE the file
// is closed and further calls are no-ops.

#ifndef ND120_FST_WINDOW_H
#define ND120_FST_WINDOW_H

#ifdef TRACE_FST_WINDOW

#include <verilated_fst_c.h>
#include <cstdio>
#include <cstdlib>

static VerilatedFstC *g_fstw = nullptr;
static int g_fstw_state = 0;  // 0=idle 1=armed(dumping) 2=done
static long g_fstw_left = 200000;
static unsigned g_fstw_trig = 077675;
static unsigned long long g_fstw_time = 0;
static long g_fstw_calls = 0;

// Call once after the verilated model is constructed. TOP = model pointer.
template <typename TOP>
static void fstw_init(TOP *top)
{
    Verilated::traceEverOn(true);
    g_fstw = new VerilatedFstC;
    top->trace(g_fstw, 99);
    const char *e;
    if ((e = getenv("ND120_FST_TRIG_P")))     sscanf(e, "%o", &g_fstw_trig);
    if ((e = getenv("ND120_FST_HALFCYCLES"))) g_fstw_left = atol(e);
    g_fstw->open((e = getenv("ND120_FST_OUT")) ? e : "trace_window.fst");
    printf("[fst] windowed FST armed: trigger=%06o window=%ld half-cycles\n",
           g_fstw_trig, g_fstw_left);
}

// Call once per half-cycle with the current trigger-compare value.
static inline void fstw_tick(unsigned trig_value)
{
    if (!g_fstw || g_fstw_state == 2) { g_fstw_calls++; return; }
    if (g_fstw_state == 0 && trig_value == g_fstw_trig) {
        g_fstw_state = 1;
        printf("[fst] capture START call=%ld\n", g_fstw_calls);
    }
    if (g_fstw_state == 1) {
        g_fstw->dump(g_fstw_time);
        g_fstw_time += 5;
        if (--g_fstw_left <= 0) {
            g_fstw->close();
            g_fstw_state = 2;
            printf("[fst] capture DONE call=%ld (file closed)\n", g_fstw_calls);
        }
    }
    g_fstw_calls++;
}

#else  // !TRACE_FST_WINDOW - compile to nothing

template <typename TOP> static void fstw_init(TOP *) {}
static inline void fstw_tick(unsigned) {}

#endif  // TRACE_FST_WINDOW
#endif  // ND120_FST_WINDOW_H

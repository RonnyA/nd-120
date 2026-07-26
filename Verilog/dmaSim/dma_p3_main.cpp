/**************************************************************************
** dmaSim - P3 DMA-master gate (standalone Verilator harness)             **
**                                                                       **
** Verilates ND120_TOP and drives ONLY the DMA test-client ports         **
** (DMA_REQ/WR/ADDR/WDATA -> DMA_RDATA/ACK/ERR), so the Verilog           **
** ND_DMA_MASTER requests the bus from the REAL arbiter (PAL_44801A via   **
** BIF) and runs REAL memory cycles against the sim RAM - true cycle      **
** steal while the CPU is live. This is the full-RTL DMA gate, in its     **
** OWN harness + OWN obj_dir, touching neither sim/ nor runSim/.          **
**                                                                       **
** Experiment (ported from the proven runSim dma_test_tick):             **
**   after the CPU settles into its idle loop, DMA-WRITE N pattern words, **
**   verify them directly in the RAM arrays, then DMA-READ them back and  **
**   check every word. Fast back-to-back requests (harness gap 0) stress  **
**   the memory-side grant recovery the ND_DMA_MASTER MIN_GAP_TICKS note  **
**   describes ("every second read lost"). With the shipping master       **
**   (MIN_GAP_TICKS=32) every word must land.                            **
**                                                                       **
** Env knobs:                                                            **
**   ND120_DMA_TEST=<octal addr>:<count>   region + word count (def 400000:16)
**   ND120_DMA_SETTLE=<half-cycles>        boot/idle settle before the test
**   ND120_DMA_GAP=<half-cycles>           extra harness gap between requests
**   ND120_MAX_CNT=<half-cycles>           hard stop guard                **
**                                                                       **
** Verdict line: TB_RESULT: PASS / TB_RESULT: FAIL                       **
***************************************************************************/

#include <cstdio>
#include <cstdlib>
#include <cstring>
#include "VND120_TOP.h"
#include "VND120_TOP___024root.h"   // root-level RAM arrays (backdoor verify)

// --- pattern identical to runSim dma_test_tick, so results are comparable ---
static inline unsigned short dmat_pattern(unsigned a)
{
	return (unsigned short)(052525u ^ a ^ (a << 7));
}

// DMA test state: 0=settle 2=write 3=read 4=done
static int      g_state    = 0;
static unsigned g_addr0    = 010000;  // octal default region (same as test-dma-rtl)
static int      g_count    = 32;
static int      g_idx      = 0;
static int      g_fail     = 0;
static int      g_reqhold  = 0;
static int      g_pending  = 0;       // a request is in flight (guards stale ACK)
static int      g_gapleft  = 0;
static int      g_gap      = 0;       // extra harness gap (ND120_DMA_GAP)
static long     g_guard    = 0;
static long     g_settle   = 2500000; // half-cycles before the test starts

// One DMA transfer step, called once per half-cycle after eval()+clock toggle,
// exactly as runSim drives it. ram_lo/ram_hi are the Verilated RAM byte arrays.
template <typename RAM>
static void dma_tick(VND120_TOP *top, long cnt, RAM &ram_lo, RAM &ram_hi)
{
	if (g_state == 4)
		return;

	// per-tick trace of the first read transaction (ND120_DMA_TRACE=1)
	if (g_state == 3 && g_idx == 0 && getenv("ND120_DMA_TRACE"))
	{
		static int lines = 0;
		if (lines < 160)
		{
			printf("[trace] cnt=%ld req=%d busy=%d ack=%d err=%d rdata=%06o "
			       "bmem=%d grant=%d bdry=%d bd_out=%06o rh=%d\n",
			       cnt, (int)top->DMA_REQ, (int)top->DMA_BUSY, (int)top->DMA_ACK,
			       (int)top->DMA_ERR, (unsigned)top->DMA_RDATA, (int)top->BMEM_n,
			       (int)top->OUTGRANT_n, (int)top->BDRY_n_OUT,
			       (unsigned)(top->BD_23_0_n_OUT & 0xFFFFFF), g_reqhold);
			lines++;
		}
	}

	// settle: let the CPU load WCS + reach its idle loop so the bus is free
	if (g_state == 0)
	{
		if (cnt >= g_settle)
		{
			printf("[dmap3] starting: %d words at %06o (settle=%ld)\n",
			       g_count, g_addr0, g_settle);
			g_state = 2;
			g_idx = 0;
		}
		return;
	}

	// finish the one-clock request pulse first
	if (g_reqhold > 0)
	{
		if (--g_reqhold == 0)
			top->DMA_REQ = 0;
		return;
	}

	// Only a request WE issued (g_pending) completes here. dma_ack is high for
	// one sysclk cycle = two half-cycle samples, and it also lingers across the
	// write->read phase change; without this guard the trailing ACK of the last
	// write is misread as the first read's (stale rdata=0) result.
	if (top->DMA_ACK && g_pending)
	{
		g_pending = 0;
		if (top->DMA_ERR)
		{
			printf("[dmap3] transfer error at idx %d\n", g_idx);
			g_fail++;
		}
		if (g_state == 3)
		{
			unsigned short want = dmat_pattern(g_addr0 + g_idx);
			if (top->DMA_RDATA != want)
			{
				printf("[dmap3] readback mismatch @%06o got %06o want %06o\n",
				       g_addr0 + g_idx, top->DMA_RDATA, want);
				g_fail++;
			}
		}
		g_idx++;
		g_guard = 0;
		g_gapleft = g_gap;
		if (g_idx >= g_count)
		{
			if (g_state == 2)
			{
				// write pass done: verify the RAM arrays directly
				for (int k = 0; k < g_count; k++)
				{
					unsigned a = g_addr0 + k;
					unsigned short got =
					    (unsigned short)((ram_hi[a] << 8) | ram_lo[a]);
					if (got != dmat_pattern(a))
					{
						printf("[dmap3] RAM array mismatch @%06o got %06o want %06o\n",
						       a, got, dmat_pattern(a));
						g_fail++;
					}
				}
				printf("[dmap3] write pass done, RAM verified, reading back\n");
				g_state = 3;
				g_idx = 0;
			}
			else
			{
				printf("[dmap3] RESULT: %s\n", g_fail ? "FAIL" : "PASS");
				printf("TB_RESULT: %s\n", g_fail ? "FAIL" : "PASS");
				g_state = 4;
			}
			return;
		}
		// fall through to issue the next word
	}
	else if (top->DMA_BUSY)
	{
		// Bus trace of the FIRST read: does memory ever drive BD, does BDRY fire?
		if (g_state == 3 && g_idx == 0 && getenv("ND120_DMA_TRACE"))
		{
			static unsigned prev = 0xFFFFFFFFu;
			static int lines = 0;
			unsigned sig = ((unsigned)top->BDRY_n_OUT << 27) |
			               ((unsigned)top->BMEM_n << 26) |
			               ((unsigned)top->OUTGRANT_n << 25) |
			               (top->BD_23_0_n_OUT & 0xFFFFFF);
			if (sig != prev && lines < 200)
			{
				printf("[trace] cnt=%ld busy=%d bmem=%d grant=%d bdry=%d bd_out=%06o (~=%06o)\n",
				       cnt, (int)top->DMA_BUSY, (int)top->BMEM_n,
				       (int)top->OUTGRANT_n, (int)top->BDRY_n_OUT,
				       (unsigned)(top->BD_23_0_n_OUT & 0xFFFFFF),
				       (unsigned)(~top->BD_23_0_n_OUT & 0xFFFFFF));
				prev = sig;
				lines++;
			}
		}
		if (++g_guard > 8000000)
		{
			printf("[dmap3] HANG waiting for the bus\n");
			printf("TB_RESULT: FAIL\n");
			g_state = 4;
		}
		return;
	}

	// inter-word harness gap (ND120_DMA_GAP)
	if (g_gapleft > 0)
	{
		g_gapleft--;
		return;
	}

	// issue the next transfer
	top->DMA_WR = (g_state == 2);
	top->DMA_ADDR = g_addr0 + g_idx;
	top->DMA_WDATA = dmat_pattern(g_addr0 + g_idx);
	top->DMA_REQ = 1;
	g_reqhold = 2;
	g_pending = 1;
	g_guard = 1;
}

// ---- HAMMER mode (P3 teeth): write one known value, then read it back
// BACK-TO-BACK with DMA_REQ held high. With EARLY_REREQ=1 the master
// re-asserts BREQ overlapping BDRY; with MIN_GAP_TICKS=0 that races the
// memory grant/decode recovery -> "every second read lost" (stale/0 reads).
// With MIN_GAP_TICKS=32 the gap lets memory recover -> all reads correct.
static int      g_hstate = 0;   // 0=settle 1=write 2=hammer 3=done
static unsigned g_haddr  = 0;
static unsigned short g_hval = 0;
static int      g_hn     = 64;  // number of back-to-back reads to sample
static int      g_hcount = 0;   // reads completed
static int      g_hbad   = 0;   // reads that returned the wrong value
static int      g_hprev_ack = 0;
static int      g_hwritten  = 0;

static void hammer_tick(VND120_TOP *top, long cnt)
{
	if (g_hstate == 3)
		return;

	if (g_hstate == 0)   // settle: CPU reaches idle, bus free
	{
		if (cnt >= g_settle)
		{
			g_hval = dmat_pattern(g_haddr);
			printf("[hammer] starting: addr=%06o val=%06o reads=%d (settle=%ld)\n",
			       g_haddr, g_hval, g_hn, g_settle);
			g_hstate = 1;
		}
		return;
	}

	if (g_hstate == 1)   // single safe write of the known value
	{
		if (g_reqhold > 0) { if (--g_reqhold == 0) top->DMA_REQ = 0; return; }
		if (top->DMA_ACK && g_pending)
		{
			g_pending = 0;
			// start hammering: hold read request high on this address.
			// The write's ACK is STILL high this tick; seed prev_ack=1 so it
			// is not miscounted as the first read (the stale-ACK trap again).
			top->DMA_WR = 0;
			top->DMA_ADDR = g_haddr;
			top->DMA_REQ = 1;
			g_hprev_ack = 1;
			g_hstate = 2;
			return;
		}
		if (top->DMA_BUSY) return;
		if (!g_hwritten)
		{
			top->DMA_WR = 1;
			top->DMA_ADDR = g_haddr;
			top->DMA_WDATA = g_hval;
			top->DMA_REQ = 1;
			g_reqhold = 2;
			g_pending = 1;
			g_hwritten = 1;
		}
		return;
	}

	// g_hstate == 2: hammer. DMA_REQ stays high; count each completed read.
	int ack = top->DMA_ACK;
	if (ack && !g_hprev_ack)          // rising edge = one transfer done
	{
		g_hcount++;
		if (top->DMA_ERR || top->DMA_RDATA != g_hval)
			g_hbad++;
		if (g_hcount >= g_hn)
		{
			top->DMA_REQ = 0;
			printf("[hammer] addr=%06o reads=%d stale=%d\n",
			       g_haddr, g_hcount, g_hbad);
			if (g_hbad > 0)
			{
				printf("[hammer] BUG REPRODUCED: %d/%d back-to-back reads returned stale data\n",
				       g_hbad, g_hcount);
				printf("TB_RESULT: FAIL\n");
			}
			else
			{
				printf("[hammer] CLEAN: all %d back-to-back reads correct\n", g_hcount);
				printf("TB_RESULT: PASS\n");
			}
			g_hstate = 3;
		}
	}
	g_hprev_ack = ack;
}

int main(int argc, char **argv)
{
	Verilated::commandArgs(argc, argv);
	VND120_TOP *top = new VND120_TOP;

	// RAM backdoor (same hierarchical path runSim uses to verify)
	auto &ram_low  = top->rootp->ND120_TOP__DOT__CORE__DOT__CPU_BOARD__DOT__MEM__DOT__RAM__DOT__b0_lo;
	auto &ram_high = top->rootp->ND120_TOP__DOT__CORE__DOT__CPU_BOARD__DOT__MEM__DOT__RAM__DOT__b0_hi;

	bool hammer = false;
	if (const char *e = getenv("ND120_DMA_HAMMER"))
	{
		sscanf(e, "%o", &g_haddr);
		hammer = true;
		if (const char *n = getenv("ND120_DMA_HAMMER_N")) g_hn = atoi(n);
	}
	if (const char *e = getenv("ND120_DMA_TEST"))
		sscanf(e, "%o:%d", &g_addr0, &g_count);
	if (const char *e = getenv("ND120_DMA_SETTLE")) g_settle = atol(e);
	if (const char *e = getenv("ND120_DMA_GAP"))    g_gap    = atoi(e);
	long g_max_cnt = 40000000;
	if (const char *e = getenv("ND120_MAX_CNT")) g_max_cnt = atol(e);

	printf("[dmap3] armed: %d words at %06o, settle=%ld, gap=%d\n",
	       g_count, g_addr0, g_settle, g_gap);

	// reset + bus defaults (mirrors runSim main())
	top->btn1 = false;   // sys_rst_n = 0
	top->uartRx = 1;     // MARK
	top->BD_23_0_n_IN = 0xFFFFFF;
	top->BREQ_n = 1;
	top->BINT10_n = 1; top->BINT11_n = 1; top->BINT12_n = 1;
	top->BINT13_n = 1; top->BINT15_n = 1; top->POWSENSE_n = 1;
	top->SEMRQ_n_IN = 1; top->BINPUT_n_IN = 1; top->BDAP_n_IN = 1;
	top->BDRY_n_IN = 1; top->BAPR_n_IN = 1;
	top->DMA_REQ = 0; top->DMA_WR = 0; top->DMA_ADDR = 0; top->DMA_WDATA = 0;

	long cnt = 0;
	while (true)
	{
		cnt++;
		if (cnt > g_max_cnt)
		{
			printf("[dmap3] ND120_MAX_CNT reached before completion\n");
			printf("TB_RESULT: FAIL\n");
			break;
		}
		if (cnt == 100)
			top->btn1 = true;   // release reset

		top->eval();
		top->sysclk = !top->sysclk;

		if (hammer)
		{
			hammer_tick(top, cnt);
			if (g_hstate == 3)
				break;
		}
		else
		{
			dma_tick(top, cnt, ram_low, ram_high);
			if (g_state == 4)
				break;
		}
	}

	delete top;
	return g_fail ? 1 : 0;
}

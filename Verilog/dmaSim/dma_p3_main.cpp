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
#include <functional>
#include <string>
#include <map>
#include <vector>
#include <algorithm>
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
static int      g_hincr     = 0;   // ND120_DMA_HAMMER_INCR=1: +1 word per read
static int      g_hidx      = 0;   // reads completed in incr mode

static void hammer_tick(VND120_TOP *top, long cnt,
                        const std::function<void(unsigned, unsigned short)> &poke)
{
	if (g_hstate == 3)
		return;

	if (g_hstate == 0)   // settle: CPU reaches idle, bus free
	{
		if (cnt >= g_settle)
		{
			g_hval = dmat_pattern(g_haddr);
			if (g_hincr)
			{
				// pre-seed N distinct words directly in the RAM model, so a
				// stale-ADDRESS latch (previous word returned) is detectable
				for (int i = 0; i < g_hn; i++)
					poke(g_haddr + i, dmat_pattern(g_haddr + i));
				printf("[hammer] starting INCR: base=%06o n=%d (settle=%ld)\n",
				       g_haddr, g_hn, g_settle);
				top->DMA_WR = 0;
				top->DMA_ADDR = g_haddr;
				top->DMA_REQ = 1;
				g_hidx = 0;
				g_hprev_ack = 0;
				g_hstate = 2;
				return;
			}
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
		{
			unsigned short want = g_hincr ? dmat_pattern(g_haddr + g_hidx) : g_hval;
			if (top->DMA_ERR || top->DMA_RDATA != want)
			{
				g_hbad++;
				if (g_hbad <= 10)
					printf("[hammer] MISMATCH #%d @%06o got %06o want %06o err=%d\n",
					       g_hbad, g_haddr + g_hidx, (unsigned)top->DMA_RDATA,
					       want, (int)top->DMA_ERR);
			}
		}
		if (g_hincr)
		{
			g_hidx++;
			top->DMA_ADDR = g_haddr + g_hidx;   // next read's address
		}
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

// ---- OPCOM console typist + reader (ND120_OPCOM_SCRIPT=<file>) ----
// Types the file's characters into the sim console UART (7 data bits +
// parity slot + 2 stop bits, DELAY_FRAMES ticks per bit - the same framing
// runSim's injector uses) and prints everything the console transmits.
// Used to replay the silicon floppy-DMA test: deposits via OPCOM, then
// "2000!" starts the test program while the CPU polls -> the exact
// contention the fault needs.
static int OP_BIT = 32;                   // 16 UART clocks = 32 half-cycle loop ticks
                                          // (ND120_OPCOM_BIT overrides: set to 2x the
                                          //  RTL DELAY_FRAMES when building with
                                          //  -DND120_UART_DELAY_FRAMES for real-timing UART)
static std::string op_script;
static size_t op_pos = 0;
static int  op_txbit = -1, op_txticks = 0, op_txdata = 0;
static long op_pace = 0;                  // inter-char gap countdown
static long OP_PACE_TICKS = 4000;
static int  op_rxen = 0, op_rxbit = 0, op_rxdata = 0, op_rxticks = 0;
static int  op_rxhold = 0;               // half-ticks the line must stay HIGH before re-arming (back-to-back frame alignment)
static std::string op_line;

static int g_errfatal = 0;  // 1 = console printed ERRFATAL, dump pending
static int g_csa_rec = 0;   // 1 = recording microcode addresses
static std::vector<std::pair<unsigned, long>> g_csa_seq;  // (csa, repeat count)
// [csapair] ND120_CSA_PAIR=<octal>: count which CSA follows each visit to
// the given microaddress (the conditional-branch outcome distribution at
// that word - 24-AUG MACL+1 campaign).
static int g_cp_addr = -1;
static int g_cp_prev = -1;
static std::map<unsigned, long> g_cp_next;
static void csa_pair(VND120_TOP *top)
{
	if (g_cp_addr < 0 || top->sysclk != 0) return;
	unsigned csa = top->CSA_12_0;
	if ((int)csa == g_cp_prev) return;
	if (g_cp_prev == g_cp_addr) g_cp_next[csa]++;
	g_cp_prev = (int)csa;
}

static void csa_record(VND120_TOP *top)
{
	if (g_csa_rec != 1 || !(top->sysclk == 0)) return;
	unsigned csa = top->CSA_12_0;
	if (!g_csa_seq.empty() && g_csa_seq.back().first == csa) g_csa_seq.back().second++;
	else if (g_csa_seq.size() < 200000) g_csa_seq.push_back({csa, 1});
}
static void opcom_tick(VND120_TOP *top)
{
	// transmit into uartRx
	if (op_txbit >= 0)
	{
		if (op_txticks > 0) { op_txticks--; }
		else
		{
			if (op_txbit == 0) { top->uartRx = 0; }                    // start
			else if (op_txbit <= 7) { top->uartRx = (op_txdata >> (op_txbit - 1)) & 1; }
			else if (op_txbit == 8) { top->uartRx = 0; }               // parity slot
			else { top->uartRx = 1; }                                  // stop bits
			op_txticks = OP_BIT - 1;
			op_txbit++;
			if (op_txbit > 10) { op_txbit = -1; op_pace = OP_PACE_TICKS; }
		}
	}
	else if (op_pace > 0) { op_pace--; }
	else if (op_pos < op_script.size())
	{
		int ch = (unsigned char)op_script[op_pos++];
		if (ch == 1) { op_pace = 1000000; }   // \x01 = 1M-tick pause marker
		else { op_txdata = ch & 0x7F; op_txbit = 0; op_txticks = 0; }
	}

	// receive from uartTx
	if (op_rxhold > 0) { if (top->uartTx) op_rxhold--; else { /* still in stop/parity of the previous frame */ } }
	else if (!op_rxen && top->uartTx == 0) { op_rxen = 1; op_rxbit = 0; op_rxdata = 0; op_rxticks = OP_BIT / 2; }
	if (op_rxen)
	{
		if (op_rxticks > 0) { op_rxticks--; }
		else
		{
			if (op_rxbit >= 1 && op_rxbit <= 7 && top->uartTx) op_rxdata |= 1 << (op_rxbit - 1);
			op_rxticks = OP_BIT - 1;
			op_rxbit++;
			if (op_rxbit > 8)
			{
				op_rxen = 0;
				op_rxhold = OP_BIT / 2;   // require half a bit of MARK before hunting the next start bit
				char c = (char)(op_rxdata & 0x7F);
				if (c == '\r' || c == '\n') {
					if (!op_line.empty()) printf("[console] %s\n", op_line.c_str());
					if (op_line.find("0041 ") != std::string::npos) g_csa_rec = 1;
					if (g_csa_rec == 1 && op_line.find("update and check") != std::string::npos) g_csa_rec = 2;
					// SINTRAN crash: ERRFA (0o4356) saved X,T,A,D,L to
					// 0o4347-0o4353 BEFORE printing - dump them (main loop).
					if (op_line.find("ERRFATAL") != std::string::npos && g_errfatal == 0)
						g_errfatal = 1;
					op_line.clear();
				} else if (c >= 32) op_line += c;
			}
		}
	}
}

// ---- C floppy backend for the sim FDISK seam (copy of the vflp server in
// simDevices/NDBus.cpp, so this harness can serve FLOPPY1.IMG without the
// full runSim device stack). Image: env ND120_FLOPPY_IMG.
static FILE *vflp_file = 0;
static int vflp_file_tried = 0;
static int vflp_media_fmt = 0xF;
static int vflp_prev_req = 0;
static int vflp_state = 0;
static long vflp_pos = 0;
static int vflp_words = 0, vflp_idx = 0;
static int vflp_done_ticks = 0;

static unsigned short vflp_served[4096];
static int vflp_served_n = 0;
static long vflp_served_lsect = -1;   // lsect of the LAST sector accumulated
static long vflp_chk_delay = 0;       // compare countdown after the last DONE
static std::function<unsigned short(unsigned)> g_peek;

// compare the words we served for the PREVIOUS read against the memory the
// DMA should have written them to (FILSYS's disk buffer at 0o61100) - run
// when the next request arrives, so the DMA drain has long finished
static void flpchk_compare(void)
{
	if (vflp_served_n == 0 || !g_peek) return;
	int bad = 0, firstbad = -1;
	for (int i = 0; i < vflp_served_n; i++)
	{
		unsigned short got = g_peek(061100 + i);
		if (got != vflp_served[i]) { bad++; if (firstbad < 0) firstbad = i; }
	}
	printf("[flpchk] CB ending lsect %ld: %d words served, %d mismatch in mem@61100%s",
	       vflp_served_lsect, vflp_served_n, bad, bad ? " " : "\n");
	if (bad)
		printf("(first at +%o: mem %06o served %06o)\n", firstbad,
		       g_peek(061100 + firstbad), vflp_served[firstbad]);
	vflp_served_lsect = -1;
	vflp_served_n = 0;
}

static void floppy_server_tick(VND120_TOP *top)
{
	if (vflp_file == 0 && !vflp_file_tried)
	{
		vflp_file_tried = 1;
		const char *img = getenv("ND120_FLOPPY_IMG");
		if (img == 0) img = "FLOPPY.IMG";
		vflp_file = fopen(img, "r+");
		if (vflp_file == 0) vflp_file = fopen(img, "r");
		vflp_media_fmt = 0xF;
		if (vflp_file)
		{
			fseek(vflp_file, 0, SEEK_END);
			long sz = ftell(vflp_file);
			fseek(vflp_file, 0, SEEK_SET);
			if (sz == 315392) vflp_media_fmt = 0x0;
		}
	}
	top->FDISK_MEDIA_FMT = vflp_media_fmt;

	if (vflp_done_ticks > 0)
	{
		if (--vflp_done_ticks == 0) { top->FDISK_DONE = 0; top->FDISK_ERR = 0; }
	}

	if (top->FDISK_REQ && !vflp_prev_req)
	{
		int bps = (top->FDISK_FORMAT == 0) ? 512 :
		          (top->FDISK_FORMAT == 1) ? 256 :
		          (top->FDISK_FORMAT == 2) ? 128 : 1024;
		vflp_pos = (long)top->FDISK_LSECT * bps;
		vflp_words = top->FDISK_WORDCOUNT;
		vflp_idx = 0;
		// contiguous next sector of the same CB -> accumulate; anything
		// else -> compare what the previous CB left in memory, then reset
		if (!(vflp_served_n > 0 && (long)top->FDISK_LSECT == vflp_served_lsect + 1))
		{
			flpchk_compare();
			vflp_served_n = 0;
		}
		vflp_chk_delay = 0;
		printf("[flpsrv] %s lsect=%d fmt=%d wc=%d\n",
		       top->FDISK_WR ? "WRITE" : "READ", (int)top->FDISK_LSECT,
		       (int)top->FDISK_FORMAT, (int)top->FDISK_WORDCOUNT);
		if (vflp_file == 0 || fseek(vflp_file, vflp_pos, SEEK_SET) != 0)
		{
			top->FDISK_ERR = 1; top->FDISK_DONE = 1; vflp_done_ticks = 2;
		}
		else vflp_state = top->FDISK_WR ? 2 : 1;
		if (!top->FDISK_WR) vflp_served_lsect = top->FDISK_LSECT;
	}
	else if (vflp_state == 1)
	{
		int hi = getc(vflp_file), lo = getc(vflp_file);
		if (hi < 0 || lo < 0)
		{
			top->FDISK_ERR = 1; top->FDISK_DONE = 1; vflp_done_ticks = 2;
			top->FDBUF_WE = 0; vflp_state = 0;
		}
		else
		{
			top->FDBUF_ADDR = vflp_idx & 0x3FF;
			top->FDBUF_WDATA = ((hi & 0xFF) << 8) | (lo & 0xFF);
			top->FDBUF_WE = 1;
			if (vflp_served_n < 4096) vflp_served[vflp_served_n++] = top->FDBUF_WDATA;
			vflp_idx++;
			if (vflp_idx >= vflp_words) vflp_state = 4;
		}
	}
	else if (vflp_state == 4)
	{
		top->FDBUF_WE = 0; top->FDISK_DONE = 1; vflp_done_ticks = 2; vflp_state = 0;
		vflp_chk_delay = 60000;   // compare after the DMA drain, unless a
		                          // contiguous sector follows first
	}
	else if (vflp_state == 2)
	{
		top->FDBUF_WE = 0; top->FDBUF_ADDR = vflp_idx & 0x3FF; vflp_state = 3;
	}
	else if (vflp_state == 3)
	{
		unsigned short w = top->FDBUF_RDATA;
		putc((w >> 8) & 0xFF, vflp_file);
		putc(w & 0xFF, vflp_file);
		vflp_idx++;
		if (vflp_idx >= vflp_words)
		{
			fflush(vflp_file);
			top->FDISK_DONE = 1; vflp_done_ticks = 2; vflp_state = 0;
		}
		else vflp_state = 2;
	}
	if (vflp_chk_delay > 0 && --vflp_chk_delay == 0)
	{
		flpchk_compare();
		vflp_served_n = 0;
	}
	vflp_prev_req = top->FDISK_REQ;
}

// ---- BPUN memory poke (ND120_BPUN_POKE=<file>): parse the framed BPUN
// (ASCII preamble to '!', then big-endian 16-bit addr/count/words/checksum/
// action) and write the words straight into the RAM model at settle time.
static long bpun_poke(const char *path,
                      const std::function<void(unsigned, unsigned short)> &poke)
{
	FILE *f = fopen(path, "rb");
	if (!f) { printf("[bpun] cannot open %s\n", path); return -1; }
	int c;
	while ((c = fgetc(f)) != EOF && c != '!') {}
	if (c != '!') { printf("[bpun] no '!' in %s\n", path); fclose(f); return -1; }
	auto r16 = [&]() { int h = fgetc(f), l = fgetc(f); return (h < 0 || l < 0) ? -1L : (long)((h << 8) | l); };
	long addr = r16(), count = r16();
	if (addr < 0 || count <= 0) { printf("[bpun] bad header\n"); fclose(f); return -1; }
	long sum = 0;
	for (long i = 0; i < count; i++)
	{
		long w = r16();
		if (w < 0) { printf("[bpun] short file at word %ld\n", i); fclose(f); return -1; }
		poke((unsigned)(addr + i), (unsigned short)w);
		sum = (sum + w) & 0xFFFF;
	}
	long ck = r16();
	fclose(f);
	printf("[bpun] poked %ld words at %06lo (checksum %s)\n",
	       count, addr, ck == sum ? "ok" : "BAD");
	return addr;
}

int main(int argc, char **argv)
{
	Verilated::commandArgs(argc, argv);
	VND120_TOP *top = new VND120_TOP;

	// RAM backdoor (same hierarchical path runSim uses to verify)
#ifdef DMASIM_BLOCKRAM
#ifndef DMASIM_RAM_MASK
#define DMASIM_RAM_MASK 0x7FFF
#endif
	// MAIN_RAM_BLOCKRAM backend: one packed 16-bit array 'mem' instead of the
	// SIM model's byte arrays. Bank 0 = index addr[BANK_ADDR_BITS-1:0]; the
	// byte views below feed the SAME templated dma_tick unchanged. Build with
	//   make test-dma-p3 EXTRA_VDEFINES="-DMAIN_RAM_BLOCKRAM ..." \
	//        TIMING_CFLAGS="-std=gnu++20 -fcoroutines -DDMASIM_BLOCKRAM"
	auto &ram16 = top->rootp->ND120_TOP__DOT__CORE__DOT__CPU_BOARD__DOT__MEM__DOT__RAM__DOT__mem;
	struct ByteView {
		decltype(ram16) m;
		int sh;
		unsigned char operator[](unsigned a) const { return (m[a & DMASIM_RAM_MASK] >> sh) & 0xFF; }
	};
	ByteView ram_low{ram16, 0}, ram_high{ram16, 8};
	// backdoor word write for the INCR hammer pre-seed (packed 16-bit array)
	std::function<void(unsigned, unsigned short)> poke =
	    [&ram16](unsigned a, unsigned short v) { ram16[a & DMASIM_RAM_MASK] = v; };
#else
	auto &ram_low  = top->rootp->ND120_TOP__DOT__CORE__DOT__CPU_BOARD__DOT__MEM__DOT__RAM__DOT__b0_lo;
	auto &ram_high = top->rootp->ND120_TOP__DOT__CORE__DOT__CPU_BOARD__DOT__MEM__DOT__RAM__DOT__b0_hi;
	// backdoor word write for the INCR hammer pre-seed (byte-lane arrays)
	std::function<void(unsigned, unsigned short)> poke =
	    [&ram_low, &ram_high](unsigned a, unsigned short v) {
		ram_low[a]  = (unsigned char)(v & 0xFF);
		ram_high[a] = (unsigned char)(v >> 8);
	};
#endif

#ifdef DMASIM_BLOCKRAM
	g_peek = [&ram16](unsigned a) -> unsigned short { return ram16[a & DMASIM_RAM_MASK]; };
#else
	g_peek = [&ram_low, &ram_high](unsigned a) -> unsigned short {
		return (unsigned short)((ram_high[a] << 8) | ram_low[a]);
	};
#endif
	bool opcom = false;
	if (const char *cp = getenv("ND120_CSA_PAIR")) g_cp_addr = (int)strtol(cp, 0, 8);
	if (const char *e = getenv("ND120_OPCOM_SCRIPT"))
	{
		FILE *sf = fopen(e, "rb");
		if (!sf) { printf("cannot open script %s\n", e); return 1; }
		int c; while ((c = fgetc(sf)) != EOF) op_script += (char)c;
		fclose(sf);
		opcom = true;
		if (const char *pp = getenv("ND120_OPCOM_PACE")) OP_PACE_TICKS = atol(pp);
		if (const char *bb = getenv("ND120_OPCOM_BIT")) OP_BIT = atoi(bb);
		printf("[opcom] script %zu chars, pace %ld ticks, bit %d half-ticks\n",
		       op_script.size(), OP_PACE_TICKS, OP_BIT);
	}
	bool hammer = false;
	if (const char *e = getenv("ND120_DMA_HAMMER"))
	{
		sscanf(e, "%o", &g_haddr);
		hammer = true;
		if (const char *n = getenv("ND120_DMA_HAMMER_N")) g_hn = atoi(n);
		if (const char *n = getenv("ND120_DMA_HAMMER_INCR")) g_hincr = atoi(n);
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

		if (opcom)
		{
			static int poked = 0;
			if (cnt == g_settle && !poked)
			{
				poked = 1;
				if (const char *bp = getenv("ND120_BPUN_POKE"))
					bpun_poke(bp, poke);
			}
			// one server step per FULL sysclk cycle: the FDBUF write port
			// is posedge-clocked, so each served word must be stable for a
			// whole clock (per half-cycle serving skipped every 2nd word)
			if (top->sysclk == 0)
				floppy_server_tick(top);
#ifdef DMASIM_BLOCKRAM
			// where is the CPU: histogram of RAM read addresses in the
			// FINAL 1M ticks (prints the loop's working set at exit)
			{
				static std::map<unsigned, long> ram_hist;
				static int dumped = 0;
				if (cnt > g_max_cnt - 1000000 && top->sysclk == 0)
				{
					unsigned a = ((unsigned)top->rootp->ND120_TOP__DOT__CORE__DOT__CPU_BOARD__DOT__MEM__DOT__RAM__DOT__bidx << 18)
					           | (unsigned)top->rootp->ND120_TOP__DOT__CORE__DOT__CPU_BOARD__DOT__MEM__DOT__RAM__DOT__a;
					if (top->rootp->ND120_TOP__DOT__CORE__DOT__CPU_BOARD__DOT__MEM__DOT__RAM__DOT__read_active)
						ram_hist[a]++;
				}
				if (cnt == g_max_cnt - 1 && !dumped)
				{
					dumped = 1;
					std::vector<std::pair<long, unsigned>> v;
					for (auto &kv : ram_hist) v.push_back({kv.second, kv.first});
					std::sort(v.rbegin(), v.rend());
					printf("[ramhist] %zu distinct read addresses in final 1M ticks; top:\n", v.size());
					for (size_t i = 0; i < v.size() && i < 20; i++)
						printf("[ramhist]   %08o x%ld\n", v[i].second, v[i].first);
					if (g_peek)
					{
						printf("[ramhist] code at 176740..176777:");
						for (unsigned aa = 0176740; aa <= 0176777; aa++)
							printf(" %06o", g_peek(aa));
						printf("\n");
					}
				}
			}
#endif
			// per-read edge decision trace (ND120_EDGE_TRACE=1): at each
			// BDRY falling edge of a floppy-master READ, log the capture
			// age - measures the real release gap distribution
			{
				static int et_on = -1;
				static int et_prev_bdry = 1;
				static int et_lines = 0;
				if (et_on < 0) et_on = getenv("ND120_EDGE_TRACE") ? 1 : 0;
				if (et_on && et_lines < 5000)
				{
					int bdry = top->BDRY_n_OUT;
					auto st = top->rootp->ND120_TOP__DOT__CORE__DOT__gen_floppy__DOT__FLOPPY_DMA_MASTER__DOT__s_state;
					int wr = top->rootp->ND120_TOP__DOT__CORE__DOT__gen_floppy__DOT__FLOPPY_DMA_MASTER__DOT__s_wr;
					if (!bdry && et_prev_bdry && st == 3 && !wr)
					{
						printf("[edge] cnt=%ld addr=%06o cap=%d age=%d capv=%06o BDnow=%06x\n",
						       cnt,
						       (unsigned)top->rootp->ND120_TOP__DOT__CORE__DOT__gen_floppy__DOT__FLOPPY_DMA_MASTER__DOT__s_addr & 0xFFFFFF,
						       (int)top->rootp->ND120_TOP__DOT__CORE__DOT__gen_floppy__DOT__FLOPPY_DMA_MASTER__DOT__s_rd_captured,
						       (int)top->rootp->ND120_TOP__DOT__CORE__DOT__gen_floppy__DOT__FLOPPY_DMA_MASTER__DOT__s_rd_idle_cnt,
						       (unsigned)top->rootp->ND120_TOP__DOT__CORE__DOT__gen_floppy__DOT__FLOPPY_DMA_MASTER__DOT__s_rd_capture,
						       (unsigned)(top->rootp->ND120_TOP__DOT__CORE__DOT__s_fdmam_bd_n & 0xFFFFFF));
						et_lines++;
					}
					et_prev_bdry = bdry;
				}
			}
			// SC2661 console-UART register snapshot every 4M ticks
			{
				static long uart_next = 0;
				if (cnt >= uart_next)
				{
					if (uart_next)
						printf("[uart] cnt=%ld mode=%02x cmd=%02x status=%02x txhold=%02x insend=%d\n",
						       cnt,
						       (unsigned)top->rootp->ND120_TOP__DOT__CORE__DOT__CPU_BOARD__DOT__IO__DOT__UART__DOT__CHIP_32H__DOT__regModeRegister,
						       (unsigned)top->rootp->ND120_TOP__DOT__CORE__DOT__CPU_BOARD__DOT__IO__DOT__UART__DOT__CHIP_32H__DOT__regCommandRegister,
						       (unsigned)top->rootp->ND120_TOP__DOT__CORE__DOT__CPU_BOARD__DOT__IO__DOT__UART__DOT__CHIP_32H__DOT__regStatusRegister,
						       (unsigned)top->rootp->ND120_TOP__DOT__CORE__DOT__CPU_BOARD__DOT__IO__DOT__UART__DOT__CHIP_32H__DOT__regTransmitHoldingRegister,
						       (int)top->rootp->ND120_TOP__DOT__CORE__DOT__CPU_BOARD__DOT__IO__DOT__UART__DOT__CHIP_32H__DOT__regDataInSendRegister);
					uart_next = cnt + 4000000;
				}
			}
			// life signs: console TX edge counter, printed every 2M ticks
			{
				static int prev_tx = 1;
				static long tx_edges = 0;
				static long next_report = 0;
				if (top->uartTx != prev_tx) { tx_edges++; prev_tx = top->uartTx; }
				if (cnt >= next_report)
				{
					if (next_report) printf("[life] cnt=%ld uartTx edges so far=%ld\n", cnt, tx_edges);
					next_report = cnt + 2000000;
				}
			}
			if (cnt >= g_settle) opcom_tick(top);
			// SINTRAN ERRFATAL: the console watcher set g_errfatal=1. ERRFA
			// (0o4356) has ALREADY saved X,T,A,D,L to 0o4347-0o4353 (its first
			// instructions, before any printing), so dump the evidence now,
			// let the rest of the message flush, then stop.
			{
				static long errfatal_end = 0;
				if (g_errfatal == 1)
				{
					g_errfatal = 2;
					errfatal_end = cnt + 8000000;
					static const struct { unsigned a; const char *n; } cells[] = {
						{04347, "X (= hardware status when T=0/HDERR)"},
						{04350, "T (driver software status - the WHY)"},
						{04351, "A"}, {04352, "D"}, {04353, "L"},
						{042244, "SSTAT last IOX 504 status seen by WISTA"},
						{042273, "BADTR"}, {042274, "WANKN"},
						{042300, "SEEKF"}, {042305, "TRTZ"}, {042311, "BUSFL"},
						{042312, "SVLCA expected end address low"},
						{042313, "SVLWC expected word count"},
					};
					printf("[errfatal] ERRFA entry saves + WD datafield:\n");
					for (unsigned i = 0; i < sizeof(cells)/sizeof(cells[0]); i++)
						printf("[errfatal]   %06o = %06o  %s\n",
						       cells[i].a, g_peek ? g_peek(cells[i].a) : 0, cells[i].n);
					unsigned t = g_peek ? g_peek(04350) : 0xFFFF;
					const char *why =
					    t == 0    ? "HDERR hardware error (X = hardware status)" :
					    t == 1    ? "MORER bank number > 377" :
					    t == 4    ? "MEMER memory address register not as expected" :
					    t == 010  ? "LAOUR logical address outside device" :
					    t == 0100 ? "DILLC illegal code" :
					    t == 0200 ? "CNACT controller not active after activate" :
					                "UNKNOWN code";
					printf("[errfatal] T=%06o -> %s\n", t, why);
				}
				if (g_errfatal == 2 && cnt > errfatal_end)
				{
					printf("TB_RESULT: FAIL (SINTRAN ERRFATAL reproduced - see [errfatal] dump)\n");
					break;
				}
			}
			csa_record(top);
			csa_pair(top);
			// stop the CSA recording ~400k ticks after it started (enough for
			// the end-of-list handling and the prompt)
			{
				static long rec_start = -1;
				if (g_csa_rec == 1 && rec_start < 0) rec_start = cnt;
				if (g_csa_rec == 1 && rec_start >= 0 && cnt > rec_start + 400000) g_csa_rec = 2;
			}
			// trace the floppy DMA master's data window (ND120_FLP_TRACE=1)
			static int fl_lines = 0; static int fl_sawwr = 0;
			static int fl_on = -1;
			// [intp] level-11 interrupt handshake probe (ND120_INTP_TRACE=1):
			// log every change of the device int_pending bits and every IDENT
			// strobe with its level - the healthy LFN pattern to compare with
			// the silicon "pending=2 forever" capture (24-AUG).
			{
				static int ip_on = -1;
				if (ip_on < 0) ip_on = getenv("ND120_INTP_TRACE") ? 1 : 0;
				if (ip_on && top->sysclk == 0)
				{
					static int prev_ip = -1, prev_strobe = -1;
					int ip = (int)top->rootp->ND120_TOP__DOT__CORE__DOT__s_dev_int_pending;
					int st = (int)top->rootp->ND120_TOP__DOT__CORE__DOT__s_dev_ident_strobe;
					int lv = (int)top->rootp->ND120_TOP__DOT__CORE__DOT__s_dev_ident_level;
					if (ip != prev_ip)
					{ printf("[intp] cnt=%ld int_pending=%d\n", cnt, ip); prev_ip = ip; }
					if (st != prev_strobe)
					{ if (st) printf("[intp] cnt=%ld IDENT strobe level=%d\n", cnt, lv); prev_strobe = st; }
				}
			}
			if (fl_on < 0) fl_on = getenv("ND120_FLP_TRACE") ? 1 : 0;
			if (fl_on && fl_lines < 3000)
			{
				auto st = top->rootp->ND120_TOP__DOT__CORE__DOT__gen_floppy__DOT__FLOPPY_DMA_MASTER__DOT__s_state;
				if (!fl_sawwr && (st == 3 || st == 4) &&
				    top->rootp->ND120_TOP__DOT__CORE__DOT__gen_floppy__DOT__FLOPPY_DMA_MASTER__DOT__s_wr)
					fl_sawwr = 1;   // begin tracing at the first WRITE
				if (fl_sawwr && (st == 3 || st == 4))
				{
					printf("[flp] cnt=%ld st=%d wr=%d mBD=%06x mBDAP=%d bBDRY=%d addr=%06o wdata=%06o\n",
					       cnt, (int)st,
					       (int)top->rootp->ND120_TOP__DOT__CORE__DOT__gen_floppy__DOT__FLOPPY_DMA_MASTER__DOT__s_wr,
					       (unsigned)(top->rootp->ND120_TOP__DOT__CORE__DOT__s_fdmam_bd_n & 0xFFFFFF),
					       (int)top->rootp->ND120_TOP__DOT__CORE__DOT__s_fdmam_bdap_n,
					       (int)top->BDRY_n_OUT,
					       (unsigned)top->rootp->ND120_TOP__DOT__CORE__DOT__gen_floppy__DOT__FLOPPY_DMA_MASTER__DOT__s_addr & 0xFFFFFF,
					       (unsigned)top->rootp->ND120_TOP__DOT__CORE__DOT__gen_floppy__DOT__FLOPPY_DMA_MASTER__DOT__s_wdata);
					fl_lines++;
				}
			}
		}
		else if (hammer)
		{
			hammer_tick(top, cnt, poke);
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

	// ---- WCS dump (ND120_WCS_DUMP=<file>): after the runtime WCS load,
	// reassemble the 64-bit microwords from the 32 IDT6168A nibble chips and
	// write 8192 lines of 16 hex digits - byte-comparable with the preload
	// image Code/Microcode/wcs/wcs_image.hex (SKIP_WCS_LOAD path). The
	// Nexys build boots from the PRELOAD; the rig loads at RUNTIME - any
	// line that differs is microcode that exists ONLY on the board.
	if (!g_cp_next.empty())
	{
		printf("[csapair] next-CSA distribution after 0%o:\n", (unsigned)g_cp_addr);
		for (auto &kv : g_cp_next) printf("  0%04o x %ld\n", kv.first, kv.second);
	}

	if (const char *wf = getenv("ND120_WCS_DUMP"))
	{
		FILE *f = fopen(wf, "w");
		if (f)
		{
#define WCSC(n) top->rootp->ND120_TOP__DOT__CORE__DOT__CPU_BOARD__DOT__CPU__DOT__CS__DOT__WCS__DOT__CHIP_##n##__DOT__idt_memory_array
			for (int half = 0; half < 2; half++)
			{
				for (int lua = 0; lua < 4096; lua++)
				{
					unsigned long long w = 0;
#define NIB(j, arr) w |= ((unsigned long long)((arr)[lua] & 0xF)) << (60 - 4*(j))
					if (half == 0) {
						NIB(0,WCSC(16C)); NIB(1,WCSC(17C)); NIB(2,WCSC(18C)); NIB(3,WCSC(19C));
						NIB(4,WCSC(20C)); NIB(5,WCSC(21C)); NIB(6,WCSC(22C)); NIB(7,WCSC(23C));
						NIB(8,WCSC(24C)); NIB(9,WCSC(25C)); NIB(10,WCSC(26C)); NIB(11,WCSC(27C));
						NIB(12,WCSC(28C)); NIB(13,WCSC(29C)); NIB(14,WCSC(30C)); NIB(15,WCSC(31C));
					} else {
						NIB(0,WCSC(16D)); NIB(1,WCSC(17D)); NIB(2,WCSC(18D)); NIB(3,WCSC(19D));
						NIB(4,WCSC(20D)); NIB(5,WCSC(21D)); NIB(6,WCSC(22D)); NIB(7,WCSC(23D));
						NIB(8,WCSC(24D)); NIB(9,WCSC(25D)); NIB(10,WCSC(26D)); NIB(11,WCSC(27D));
						NIB(12,WCSC(28D)); NIB(13,WCSC(29D)); NIB(14,WCSC(30D)); NIB(15,WCSC(31D));
					}
#undef NIB
					fprintf(f, "%016llx\n", w);
				}
			}
#undef WCSC
			fclose(f);
			printf("[wcs] dumped 8192 microwords to %s\n", wf);
		}
	}

	if (!g_csa_seq.empty())
	{
		printf("[csa] %zu transitions recorded after the 0041 line; sequence (addr x repeat):\n", g_csa_seq.size());
		FILE *cf = fopen(getenv("ND120_CSA_OUT") ? getenv("ND120_CSA_OUT") : "csa_seq.txt", "w");
		for (auto &p : g_csa_seq) fprintf(cf, "%04o %ld\n", p.first, p.second);
		fclose(cf);
	}
	// dump the floppy controller's fetched command block (root peek)
	{
		auto &cb = top->rootp->ND120_TOP__DOT__CORE__DOT__gen_floppy__DOT__FLOPPY_1560__DOT__s_cb;
		printf("[floppy] fetched CB:");
		for (int i = 0; i < 8; i++) printf(" %06o", (unsigned)cb[i]);
		printf("\n[floppy] s_lsect %06o s_disk_addr %06o\n",
		       (unsigned)top->rootp->ND120_TOP__DOT__CORE__DOT__gen_floppy__DOT__FLOPPY_1560__DOT__s_lsect,
		       (unsigned)top->rootp->ND120_TOP__DOT__CORE__DOT__gen_floppy__DOT__FLOPPY_1560__DOT__s_disk_addr);
	}
	delete top;
	return g_fail ? 1 : 0;
}

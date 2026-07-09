/**************************************************************************
** ND120 SIMULATOR                                                       **
**                                                                       **
** Steps the Verilator TOP module                                        **
** Handles console I/O                                                   **
** Connects to Bus Interface devices                                     **
**                                                                       **
** Can load INITIAL BPUN directly into memory                            **
**                                                                       **
** Last reviewed: 22-MAR-2024                                            **
** Ronny Hansen                                                          **
***************************************************************************/

// Run SIMULATOR
// Runs the FPGA CPU in the console and lets you do console input and output via keyboard

// #define DO_TRACE
#include <iostream>
#include <vector>
#include <random>
#include <ctime>
#include <string>

#include <unistd.h>
#include <termios.h>
#include <fcntl.h>

#include "VND120_TOP.h"
#include "VND120_TOP___024root.h" // Root-level details for updating RAM directly
#include "verilated.h"

#ifdef DO_TRACE
#include <verilated_vcd_c.h>
#endif

#include "NDBus.h"
#include "NDDevices.h"

// Save the original terminal settings
struct termios orig_termios;

// BPUN load file logic
void loadfile(char *fn, int off, uint8_t *low_array, uint8_t *low_array9, uint8_t *high_array, uint8_t *high_array9);

// Function to restore terminal settings
void restore_terminal()
{
	tcsetattr(STDIN_FILENO, TCSANOW, &orig_termios);
}
// Function to set terminal to non-blocking mode
void set_nonblocking_terminal()
{
	struct termios new_termios;

	// Get the current terminal settings
	tcgetattr(STDIN_FILENO, &orig_termios);
	// Register a cleanup function to restore the settings on exit
	atexit(restore_terminal);

	new_termios = orig_termios;

	// Disable canonical mode and echo
	new_termios.c_lflag &= ~(ICANON | ECHO);

	// Apply the new terminal settings
	tcsetattr(STDIN_FILENO, TCSANOW, &new_termios);

	// Set the file descriptor to non-blocking mode
	int flags = fcntl(STDIN_FILENO, F_GETFL, 0);
	fcntl(STDIN_FILENO, F_SETFL, flags | O_NONBLOCK);
}

// Array of descriptions corresponding to each LED flag
const char *LED_DESCRIPTION[6] = {
	"CPU Red LED",				   // CPU_RED (1 << 0)
	"CPU Green LED",			   // CPU_GREEN (1 << 1)
	"Parity Error LED (LED4 Red)", // LED4_RED_PARITY_ERROR (1 << 2)
	"CPU Grant Indicator LED",	   // LED_CPU_GRANT_INDICATOR (1 << 3)
	"Bus Grant Indicator LED",	   // LED_BUS_GRANT_INDICATOR (1 << 4)
	"MMU LED1"					   // MMU_LED1 (1 << 5)
};

// Led contains the bits with current state, changed contains bits for which led changed state
void DumpLedInfo(uint8_t led, uint8_t changed)
{
	bool first = true;
	for (int i = 0; i < 6; ++i)
	{ // There are 6 LED signals
		int flag = 1 << i;

		if (changed & flag)
		{							// Check if this LED's state has changed
			bool isOn = led & flag; // Determine if it's now ON or OFF
			std::cout << (first ? "" : ", ") << LED_DESCRIPTION[i]
					  << " changed from " << (isOn ? "OFF to ON" : "ON to OFF");
			first = false;
		}
	}
	if (!first)
	{
		std::cout << std::endl; // Print a newline if any changes were printed
	}
}

#define MAX_SIM_TIME 20
vluint64_t sim_time = 0;
vluint64_t time_step = 5;

int DELAY_FRAMES = 16;					   // 16 frames
int HALF_DELAY_WAIT = (DELAY_FRAMES >> 1); // Equivalent to DELAY_FRAMES / 2

// --- FF-vs-latch divergence instrumentation (build with EXTRA_CFLAGS) ---
// -DSCRIPT_INPUT : after the boot '#' prompt, auto-inject a scripted command
// -DTRACE_CSA    : log CSA_12_0 changes (post-boot) to csa_trace.csv
#if defined(TRACE_CSA) || defined(SCRIPT_INPUT)
static int g_boot_done_cnt = 0;    // cnt when first '#' output (0 = not yet)
#endif
#ifdef TRACE_CSA
static FILE *g_csa_fp = nullptr;
static unsigned g_last_csa = 0xFFFFu;
#endif
#ifdef SCRIPT_INPUT
#ifdef SCRIPT_CMD_20
#define SCRIPT_CMD "20!\r"              // -DSCRIPT_CMD_20 avoids quoting through make/verilator
#endif
#ifdef SCRIPT_CMD_CRS
#define SCRIPT_CMD "\r\r\r\r\r\r\r\r"   // -DSCRIPT_CMD_CRS: 8 Enters; each re-echoes the '#' prompt via MOPC (console-output repro)
#endif
#ifdef SCRIPT_CMD_EXAM
#define SCRIPT_CMD "20/\r"              // -DSCRIPT_CMD_EXAM: memory examine; prints a multi-char octal value (output-burst repro)
#endif
#ifdef SCRIPT_CMD_GOLDEN
// -DSCRIPT_CMD_GOLDEN: the clock-enable refactor validation sequence
// (docs/plan-fix-unconstrained-clocks.md gate 3): examine 22, deposit
// 054321, re-examine (readback must show 054321), then run from 0 and 20.
#define SCRIPT_CMD "22/054321\r22/\r0!\r20!\r"
#endif
#ifndef SCRIPT_CMD
#define SCRIPT_CMD "0!\r"               // override with -DSCRIPT_CMD='"20!\r"'
#endif
static const char *g_script = SCRIPT_CMD;  // command to run once OPCOM is up
static int g_script_idx = 0;
static int g_next_inject_cnt = 0;          // gate: don't send next char until this cnt
#endif

int txData = 0;
int txDataBit = 0;
int txEnabled = 0;
int txTicks = 0;
int txOnes = 0;

int rxData = 0;
int rxDataBit = 0;
int rxEnabled = 0;
int rxTicks = 0;
int rxOnes = 0;
// 7N2

int main(int argc, char **argv)
{

	set_nonblocking_terminal();

	Verilated::commandArgs(argc, argv);
	VND120_TOP *top = new VND120_TOP;

	addDevices();

	uint8_t led = 0;
	uint8_t new_led = 0;

	// Load data
	// Access MEM->RAM fields via rootp
	auto &ram_low = top->rootp->ND120_TOP__DOT__CPU_BOARD__DOT__MEM__DOT__RAM__DOT__b0_lo;
	auto &ram_low_9 = top->rootp->ND120_TOP__DOT__CPU_BOARD__DOT__MEM__DOT__RAM__DOT__b0_lo_p;

	auto &ram_high = top->rootp->ND120_TOP__DOT__CPU_BOARD__DOT__MEM__DOT__RAM__DOT__b0_hi;
	auto &ram_high_9 = top->rootp->ND120_TOP__DOT__CPU_BOARD__DOT__MEM__DOT__RAM__DOT__b0_hi_p;

	// Use provided filename if exists, otherwise default to "INSTRUCTION-B.BPUN"
	// char *default_filename = strdup("INSTRUCTION-B.BPUN"); // strdup creates a modifiable copy
	char *default_filename = strdup("DEBUG.BPUN"); // strdup creates a modifiable copy
	char *filename = (argc > 1) ? argv[1] : default_filename;
	
	loadfile(filename, 0, &ram_low[0], &ram_low_9[0], &ram_high[0], &ram_high_9[0]);

	// LED bits
	//!   0=CPU RED
	//!   1=CPU GREEN
	//!   2=LED4_RED_PARITY_ERROR
	//!   3=LED_CPU_GRANT_INDICATOR
	//!   4=LED_BUS_GRANT_INDICATOR
	//!   5=LED1 from MMU

	top->btn1 = false; // sys_rst_n = 0
	top->uartRx = 1;   // MARK

	// Default values for BUS INTERFACE (BIF) input
	top->BD_23_0_n_IN = 0xFFFFFF; // Default to pulled-high
	top->BREQ_n = 1;
	top->BINT10_n = 1;
	top->BINT11_n = 1;
	top->BINT12_n = 1;
	top->BINT13_n = 1;
	top->BINT15_n = 1;
	top->POWSENSE_n = 1;

	// Bus signaling defaults (off)
	top->SEMRQ_n_IN = 1;
	top->BINPUT_n_IN = 1;
	top->BDAP_n_IN = 1;
	// top->BPERR_n = 1; // BUS PARITY ERROR (disabled  TOP module)
	top->BDRY_n_IN = 1;
	top->BAPR_n_IN = 1;

	int cnt = 0;
#ifdef TRACE_CSA
	g_csa_fp = fopen("csa_trace.csv", "w");
#endif
#ifdef TRACE_MIC
	// Deep half-clock trace of the MIC address pipeline in a cnt window.
	// Build with e.g. -DTRACE_MIC -DTRACE_MIC_START=12345 -DTRACE_MIC_END=12999
#ifndef TRACE_MIC_START
#define TRACE_MIC_START 0
#endif
#ifndef TRACE_MIC_END
#define TRACE_MIC_END 0x7FFFFFFF
#endif
	FILE *g_mic_fp = fopen("mic_trace.csv", "w");
	fprintf(g_mic_fp, "cnt,sysclk,csa,csbits,regREP,regIW,muxsel,term,cc\n");
#endif
	while (true)
	{
		cnt++;

		if (cnt == 100)
		{
			top->btn1 = true; // sys_rst_n = 1 // disable reset
		}

		top->eval();
		top->sysclk = !top->sysclk;

		proccess_bif_signal(top);

#ifdef TRACE_MIC
		if (g_mic_fp && cnt >= TRACE_MIC_START && cnt <= TRACE_MIC_END)
		{
			fprintf(g_mic_fp, "%d,%d,%o,%016llx,%o,%o,%d,%d,%d%d%d%d\n",
				cnt,
				(int)top->sysclk,
				(unsigned)top->CSA_12_0,
				(unsigned long long)top->rootp->ND120_TOP__DOT__s_csbits,
				(unsigned)top->rootp->ND120_TOP__DOT__CPU_BOARD__DOT__CPU__DOT__PROC__DOT__CGA__DOT__DELILAH__DOT__MIC__DOT__MIC_MASEL__DOT__regREP,
				(unsigned)top->rootp->ND120_TOP__DOT__CPU_BOARD__DOT__CPU__DOT__PROC__DOT__CGA__DOT__DELILAH__DOT__MIC__DOT__MIC_MASEL__DOT__regIW,
				(int)top->rootp->ND120_TOP__DOT__CPU_BOARD__DOT__CPU__DOT__PROC__DOT__CGA__DOT__DELILAH__DOT__MIC__DOT__MIC_MASEL__DOT__s_mux_selector,
				(int)top->rootp->ND120_TOP__DOT__CPU_BOARD__DOT__CYC__DOT__PAL_44601_UCYCFSM__DOT__TERM_reg,
				(int)top->rootp->ND120_TOP__DOT__CPU_BOARD__DOT__CYC__DOT__PAL_44601_UCYCFSM__DOT__CC3_reg,
				(int)top->rootp->ND120_TOP__DOT__CPU_BOARD__DOT__CYC__DOT__PAL_44601_UCYCFSM__DOT__CC2_reg,
				(int)top->rootp->ND120_TOP__DOT__CPU_BOARD__DOT__CYC__DOT__PAL_44601_UCYCFSM__DOT__CC1_reg,
				(int)top->rootp->ND120_TOP__DOT__CPU_BOARD__DOT__CYC__DOT__PAL_44601_UCYCFSM__DOT__CC0_reg);
		}
		if (g_mic_fp && cnt > TRACE_MIC_END)
		{
			fclose(g_mic_fp);
			g_mic_fp = nullptr;
			printf("\n[instrumented] TRACE_MIC window done, stopping\n");
			break;
		}
#endif

#if defined(TRACE_CSA) || defined(SCRIPT_INPUT)
		if (g_boot_done_cnt != 0)
		{
#ifdef TRACE_CSA
			if (g_csa_fp && top->CSA_12_0 != g_last_csa)
			{
				fprintf(g_csa_fp, "%d,%o\n", cnt, (unsigned)top->CSA_12_0);
				g_last_csa = top->CSA_12_0;
			}
#endif
			if (cnt > g_boot_done_cnt + 200000 + 40000000)
			{
#ifdef TRACE_CSA
				if (g_csa_fp) { fclose(g_csa_fp); g_csa_fp = nullptr; }
#endif
				printf("\n[instrumented] cycle budget reached, stopping\n");
				break;
			}
		}
#endif

		new_led = top->led ^ 0x3F; // bits are negated, active low
		// if (new_led != led)
		if (false)
		{
			uint8_t changed = new_led ^ led; // identify changed leds

			changed &= ~(1 << 4 | 1 << 3); // dont log cpu & bus grant

			// printf("LED changed to 0x%2X\r\n", new_led);
			led = new_led;
			DumpLedInfo(led, changed);
		}

		/*************************** TRANSMIT UART DATA *************************************/

		if (!txEnabled)
		{
			char ch;
			ssize_t n = 0;
#ifdef SCRIPT_INPUT
			// After boot ('#' seen) + settle, feed the scripted command instead of stdin
			if (g_boot_done_cnt != 0 && cnt > g_boot_done_cnt + 1000000 && cnt > g_next_inject_cnt && g_script[g_script_idx] != '\0')
			{
				ch = g_script[g_script_idx++];
				n = 1;
				g_next_inject_cnt = cnt + 300000;  // inter-char gap so OPCOM reads each (avoid RX overrun)
			}
			else
#endif
			// Try to read a character from stdin
			n = read(STDIN_FILENO, &ch, 1);

			if (n > 0)
			{
				// printf("You pressed: %x\n", ch);

				txData = (int)ch;
				txEnabled = true;
				txDataBit = 0;
				txTicks = 0;
				txOnes = 0;
			}
		}

		if (txEnabled)
		{
			if (txTicks > 0)
			{
				txTicks--;
			}
			else
			{
				switch (txDataBit)
				{
				case 0:
					txTicks = DELAY_FRAMES - 1; // Start bit
					top->uartRx = 0;
					txOnes = 0;
					if (txData == 0x0a)
						txData = 0x0d; // LF, not CR
					// printf("TX[%02X] %c\r\n", txData, txData);
					break;
				case 1:
				case 2:
				case 3:
				case 4:
				case 5:
				case 6:
				case 7:
					if ((txData & 0x01) != 0)
					{
						top->uartRx = 1;
						txOnes++;
					}
					else
					{
						top->uartRx = 0;
					}
					txData >>= 1;
					txTicks = DELAY_FRAMES - 1;
					break;
				case 8: // Parity
					top->uartRx = 0;
					// Calculate even parity: set top->uartRx to 1 if txOnes is odd, 0 if even
					// top->uartRx = (txOnes % 2) ? 0 : 1; // Even parity calculation
					txTicks = DELAY_FRAMES - 1;
					break;
				case 9:				 // stop bits
				case 10:			 // stop bits
					top->uartRx = 1; // MARK!
					txTicks = DELAY_FRAMES - 1;
					break;
				case 11:
					txData = 0;
					txEnabled = false;
					break;
				}

				// printf("TX[%d] %d\r\n", txDataBit, top->uartRx);

				txDataBit++;
			}
		}

		/*************************** RECEIEVE UART DATA *************************************/

		// Receive data ?
		if ((top->uartTx == 0) && (!rxEnabled))
		{
			rxEnabled = true;
			rxDataBit = 0;
			rxData = 0;
			rxOnes = 0;
			rxTicks = HALF_DELAY_WAIT;
		}

		if (rxEnabled)
		{
			if (rxTicks > 0)
			{
				rxTicks--;
			}
			else
			{
				// printf("RX[%d] %d\r\n", rxDataBit, top->uartTx);

				switch (rxDataBit)
				{
				case 0:
					rxTicks = DELAY_FRAMES;
					if (top->uartTx == 1)
					{
						rxEnabled = false;
					}
					break;
				case 1:
				case 2:
				case 3:
				case 4:
				case 5:
				case 6:
				case 7:
					if (top->uartTx != 0)
					{
						rxOnes++; // for parity check
						rxData |= (1 << (rxDataBit - 1));
					}
					rxTicks = DELAY_FRAMES - 1;
					break;
				case 8: // Parity
					rxTicks = DELAY_FRAMES - 1;
					break;
				case 9:	 // stop bits
				case 10: // stop bits
					rxTicks = DELAY_FRAMES - 1;
					break;
				case 11:
					// printf("Received 0x%02X '%c'\r\n", rxData, rxData);
					printf("%c", rxData);
					fflush(stdout);
#if defined(TRACE_CSA) || defined(SCRIPT_INPUT)
					if (rxData == '#' && g_boot_done_cnt == 0) g_boot_done_cnt = cnt;
#endif

					rxData = 0;
					rxEnabled = false;
					break;
				}
				rxDataBit++;
			}
		}

		// sim_time += time_step; // Increment simulation time

		top->eval();
		top->sysclk = !top->sysclk;

		// sim_time += time_step; // Increment simulation time
	}

#ifdef DO_TRACE

	// Add a few clock cycles
	m_trace->dump(sim_time);
	sim_time += time_step; // Increment simulation time
	m_trace->dump(sim_time);
	sim_time += time_step; // Increment simulation time

	m_trace->close();
#endif

	delete top;
	return 0;
}

/****************************** BPUN **********************/

static int mlp;

static int
gb(FILE *f)
{
	int w;

	if (f == NULL)
		return 00;

	w = getc(f) & 0377;
	return w;
}

static int
gw(FILE *f)
{
	int c = gb(f);
	return (c << 8) | gb(f);
}

// Return 1 if 8 bit parity is EVEN
ushort calc_parity(uint16_t val)
{
	ushort parity = 0;

	for (int i = 0; i < 8; i++)
	{
		parity ^= (val & 1);
		val >>= 1;
	}
	return parity == 0 ? 1 : 0; // Even parity returns 1, odd returns 0
}

/*
 * Bootable (BPUN) tape format.
 * Disks can use it as well with a max of 64 words data.  In this case
 * the bytes are stored in the LSB of the words from beginning of disk.
 * 1kw block should be read at address 0 in memory.
 *
 * A bootable tape consists of nine segments, named A-I.
 *
 * A - Any chars not including '!'
 * B - (optional) octal number terminated by CR (LF ignored).
 * C - (optional) octal number terminated by '!'.
 * D - A '!' delimeter
 * E - Block start address (in memory), two byte, MSB first.
 * F - Word count in G section, two byte, MSB first.
 * G - Words as counted in F section.
 * H - Checksum of G section, one word.
 * I - Action code.  If non-zero, start at address in B, otherwise nothing.
 */

void loadfile(char *fn, int off, uint8_t *low_array, uint8_t *low_array9, uint8_t *high_array, uint8_t *high_array9)
{
	int B, C, E, F, H, I;
	int w, i, rv;
	unsigned short s;
	FILE *f;

	if ((f = fopen(fn, "r")) == 0)
	{
		printf("Unable to open file %s\r\n", fn);
		return;
	}

#if 0
	rv = SCPE_OK;
	if (sim_switches & SWMASK('D')) {	/* read file from disk */
		mlp = 0;
		for (i = 0; i < 1024; i++) {
			/* images have MSB first */
			s = (getc(f) & 0377) << 8;
			s |= getc(f) & 0377;
			pwrmem(i, s, PM_CPU);
		}
		f = NULL;
	}
#endif

	/* read B/C section */
	for (B = C = 0; (w = gb(f) & 0177) != '!';)
	{
		switch (w)
		{
		case '\n':
			continue;
		case '\r':
			B = C, C = 0;
			break;
		case '0':
		case '1':
		case '2':
		case '3':
		case '4':
		case '5':
		case '6':
		case '7':
			C = (C << 3) | (w - '0');
			break;
		default:
			B = C = 0;
		}
	}

	printf("B address    %06o\n", B);
	printf("C address    %06o\n", C);
	//	regP = B;
	printf("Load address %06o\n", E = gw(f));
	printf("Word count   %06o\n", F = gw(f));
	for (i = s = 0; i < F; i++)
	{
		int data16 = gw(f);
		low_array[E + i] = data16 & 0xFF;
		high_array[E + i] = (data16 >> 8) & 0xFF;

		low_array9[E + i] = calc_parity(low_array[E + i]);
		high_array9[E + i] = calc_parity(high_array[E + i]);

		s += data16;
	}
	printf("Checksum     %06o\n", H = gw(f));
	if (H != s)
		printf("Bad checksum: %06o != %06o\n", H, s);
	printf("Execute	     %06o\n", I = gw(f));
	printf("Words read   %06o\n", i);
	//	ald = 0300;	/* from tape reader */
	//	return rv;
	fclose(f);
}

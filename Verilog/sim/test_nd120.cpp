/**************************************************************************
** ND120 SIMULATOR & DEBUGGER MODULE                                     **
**                                                                       **
** Steps the Verilator TOP module                                        **
**                                                                       **
** GTKWave helper program                                                **
** Simulates the CPU partially by execiting pre-defined commands,        **
** generating GTKWave signal file                                        **
**                                                                       **
** Used for debugging the Verilog code                                   **
**                                                                       **
** Can load INITIAL BPUN directly into memory                            **
**                                                                       **
** Last reviewed: 22-MAR-2024                                            **
** Ronny Hansen                                                          **
***************************************************************************/


#define DO_TRACE
#include <iostream>
#include <vector>
#include <random>
#include <ctime>
#include <string>

#include "VND120_TOP.h"
#include "VND120_TOP___024root.h" // Root-level details for updating RAM directly
#include "verilated.h"

#ifdef DO_TRACE
#include <verilated_vcd_c.h>
#endif

#include "NDBus.h"
#include "NDDevices.h"

// BPUN load file logic
void loadfile(char *fn, int off, uint8_t *low_array, uint8_t *low_array9, uint8_t *high_array, uint8_t *high_array9);

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

int main(int argc, char **argv)
{
	Verilated::commandArgs(argc, argv);
	VND120_TOP *top = new VND120_TOP;

	// Create ND Bus devices
	addDevices();

#ifdef DO_TRACE
	VerilatedVcdC *m_trace = new VerilatedVcdC;
	Verilated::traceEverOn(true);
	top->trace(m_trace, 1); // 1 is the trace depth
	m_trace->open("waveform.vcd");
#endif

	// Load data
	// Access MEM->RAM fields via rootp
	auto &ram_low = top->rootp->ND120_TOP__DOT__CPU_BOARD__DOT__MEM__DOT__RAM__DOT__CHIP_15H__DOT__sdram;
	auto &ram_low_9 = top->rootp->ND120_TOP__DOT__CPU_BOARD__DOT__MEM__DOT__RAM__DOT__CHIP_15H__DOT__sdram_9;

	auto &ram_high = top->rootp->ND120_TOP__DOT__CPU_BOARD__DOT__MEM__DOT__RAM__DOT__CHIP_15J__DOT__sdram;
	auto &ram_high_9 = top->rootp->ND120_TOP__DOT__CPU_BOARD__DOT__MEM__DOT__RAM__DOT__CHIP_15J__DOT__sdram_9;
	char *fname = strdup("INSTRUCTION-B.BPUN"); // strdup creates a modifiable copy
	loadfile(fname, 0, &ram_low[0], &ram_low_9[0], &ram_high[0], &ram_high_9[0]);

	uint8_t led = 0;
	uint8_t new_led = 0;

	// LED bits
	//!   0=CPU RED
	//!   1=CPU GREEN
	//!   2=LED4_RED_PARITY_ERROR
	//!   3=LED_CPU_GRANT_INDICATOR
	//!   4=LED_BUS_GRANT_INDICATOR
	//!   5=LED1 from MMU

	top->btn1 = false; // sys_rst_n = 0
	top->uartRx = 1;   // MARK!

	int txOffset = 0;

	int hashReceived = 0;
	int readyReceived = 0;

	// long startTrace = 2390000; // STAR
	// long maxTicks = startTrace + 500000;

	//long startTrace = 755472; // OPCOM READY after selftest
							  
	long startTrace = 2207832; // READY AFTER BOOT from 0!
	// long startTrace = 4777683;
	// long startTrace = 0;
	//long startTrace = 10000000; // 10 mill

	// long maxTicks = 2000000;

	
	// long maxTicks = startTrace + 200000; // 200K (good for boot)
	long maxTicks = startTrace + 1000000; // 1M
	// long maxTicks = startTrace + 2000000; // 2M
	// long maxTicks = startTrace + 5500000; // 5.5M

	

	// Boot commands
	const char *cmdBOOT = "0!\0"; // Start program in RAM at address 0
	const char *cmdLOAD = "&\0";  // Load prgraom via ALD setting
	const char *cmdIOR = "IO/";	  // DO IOX
	const char *cmdEXAMINE = "77777/76543\r";

	// INSTRUCTION COMMANDS
	const char *cmdHELP = "HELP,,,\r";
	const char *cmdBYTE = "BYTE\r";
	const char *cmdPRIV = "PRIV\r";

	const char *cmdP = 0;

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
	//top->BPERR_n = 1; // BUS PARITY ERROR (disabled  TOP module)
	top->BDRY_n_IN = 1;
	top->BAPR_n_IN = 1;

	for (long cnt = 0; cnt < maxTicks; cnt++)
	{
		if (cnt == 100)
		{
			top->btn1 = true; // sys_rst_n = 1 // disable reset
		}

		top->eval();
		top->sysclk = !top->sysclk;

		proccess_bif_signal(top);

#if _do_the_led_
		new_led = top->led ^ 0x3F; // bits are negated, active low
		if (new_led != led)
		{
			uint8_t changed = new_led ^ led; // identify changed leds

			changed &= ~(1 << 4 | 1 << 3 | 1 << 5); // dont log cpu & bus grant and MMU

			// printf("LED changed to 0x%2X\r\n", new_led);
			led = new_led;
			DumpLedInfo(led, changed);
		}
#endif

		/*************************** TRANSMIT UART DATA *************************************/

		if (!txEnabled)
		{
			char ch;
			// Try to read a character from stdin
			// ssize_t n = read(STDIN_FILENO, &ch, 1);
			int n = -1;
			if (n > 0)
			{
				printf("You pressed: %x\n", ch);

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
					// printf("TX[%x] %c\r\n", txData, txData);
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
					// Calculate even parity: set top->uartRx to 1 if txOnes is odd, 0 if even
					top->uartTx = 0;
					// top->uartRx = (txOnes % 2) ? 1 : 0; // Even parity calculation
					txTicks = DELAY_FRAMES - 1;
					break;
				case 9:	 // stop bits
				case 10: // stop bits
					txTicks = DELAY_FRAMES - 1;
					top->uartRx = 1; // MARK!
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
					rxTicks = DELAY_FRAMES;
					break;
				case 8: // Parity
					rxTicks = DELAY_FRAMES;
					break;
				case 9:	 // stop bits
				case 10: // stop bits
					rxTicks = DELAY_FRAMES;
					break;
				case 11:
					// if (rxData != 0)
					{
						printf("%c", (char)rxData);

						txData = 0;

						// if (rxData == (int)'*')
						//	printf("STAR at %ld\r\n",cnt);

						if (rxData == (int)'#') // #
						{
							if (hashReceived == 0)
								txOffset = 1;

							hashReceived++;
						}
						else if (rxData == (int)'>')
						{
							printf("Ready at %ld\r\n", cnt);

							if (readyReceived == 0)
								txOffset = 200; // START SENDING COMMAND

							readyReceived++;
						}
						else if (rxData == (int)' ') // space
						{
							if (hashReceived == 1)
								txOffset = 100; // Send data AFTER first HASH, and AFTER first space
							else
								txOffset = 1;
						}
						else
						{
							if (txOffset > 0)
								txOffset++;
						}

						// printf("[%d] Received 0x%02X '%c'\r\n", txOffset, rxData, (char)rxData);
						fflush(stdout);

						// Send COMMAND to OPCOM after first # ahas been received
						if (txOffset == 1)
						{
							printf("OPCOM command: %s at %ld\r\n", cmdBOOT, cnt);
							cmdP = cmdBOOT;
						}

						// Send DATA after # and SPACE
						if (txOffset == 100)
						{
							// printf("Setting DATA: %s", dbgCommand);
							cmdP = 0;
						}

						// Send COMMAND to CONFIGURE after ">"
						if (txOffset == 200)
						{
							printf("Setting command: %s", cmdPRIV);
							cmdP = cmdPRIV;
						}

						if (cmdP != 0)
						{
							if (*cmdP == '\0')
							{
								cmdP = 0;
							}
							else
							{
								// Print the current character
								txData = (char)*cmdP;

								// Move to the next character
								cmdP++;

								// printf("%d-%c\r\n",rxCnt, (char)txData);
							}
						}

						if (txData > 0)
						{
							// Send DATA!
							txEnabled = true;
							txDataBit = 0;
							txTicks = 0;
							txOnes = 0;
						}
					}
					rxData = 0;
					rxEnabled = false;

					break;
				}
				rxDataBit++;
			}
		}

#ifdef DO_TRACE
		if (cnt > startTrace)
		{
			m_trace->dump(sim_time);
			sim_time += time_step; // Increment simulation time
		}
#endif

		top->eval();
		top->sysclk = !top->sysclk;

#ifdef DO_TRACE
		if (cnt > startTrace)
		{
			m_trace->dump(sim_time);
			sim_time += time_step; // Increment simulation time
		}
#endif
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

 void loadfile(char *fn, int off, uint8_t *low_array,uint8_t *low_array9, uint8_t *high_array, uint8_t *high_array9)
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

		low_array9[E+i] = calc_parity(low_array[E+i]);
		high_array9[E+i] = calc_parity(high_array[E+i]);

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

#define DO_TRACE
#include <iostream>
#include <vector>
#include <random>
#include <ctime>
#include <string>

#include "VND120_TOP.h"
#include "verilated.h"

#ifdef DO_TRACE
#include <verilated_vcd_c.h>
#endif

// DECODE_DGA testcases
struct TestCase
{
	bool sysclk; // System Clock
	bool btn1;	 // Button 1, mapped to S1 (not labeled) on the board
	bool btn2;	 // Button 2, mapped to S2 (not labeled) on the board

	uint8_t led; // 6-bit output for controlling LEDs
	bool uartRx; // UART Receive pin
	bool uartT;	 // UART Transmit pin

	std::string description; // Description of the test case
};

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

#ifdef DO_TRACE
	VerilatedVcdC *m_trace = new VerilatedVcdC;
	Verilated::traceEverOn(true);
	top->trace(m_trace, 1); // 1 is the trace depth
	m_trace->open("waveform.vcd");
#endif

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

	int rxCnt = 0;

	int hashReceived = 0;

	for (long cnt = 0; cnt < 1800000; cnt++)
	{
		if (cnt == 100)
		{
			top->btn1 = true; // sys_rst_n = 1 // disable reset
		}

		top->eval();
		top->sysclk = !top->sysclk;

		new_led = top->led ^ 0x3F; // bits are negated, active low
		if (new_led != led)
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
					printf("Received 0x%02X '%c'\r\n", rxData, (char)rxData);

					if (rxData == 35) // #
					{
						if (hashReceived == 0)
							rxCnt = 1;

						hashReceived++;
					}
					else if (rxData == 0x20) // space
					{
						if (hashReceived == 1)
							rxCnt = 100;
						else
							rxCnt = 1;
					}

					else
						rxCnt++;

					if (true)
					{
						txData = 0;
#if 0 // IO						
						switch (rxCnt)
						{
						case 1:
							txData = (char)'I'; // IO Read
							break;
						case 2:
							txData = (char)'O';
							break;
						case 3:
							txData = (char)'/';
							break;
						}
#endif						

#if true
						switch (rxCnt)
						{
						case 1:
							txData = (char)'7'; // examine/write memory at #77777 (0x7FFF)
							break;
						case 2:
							txData = (char)'7';
							break;
						case 3:
							txData = (char)'7';
							break;
						case 4:
							txData = (char)'7';
							break;
						case 5:
							txData = (char)'7';
							break;
						case 6:
							txData = (char)'/';
							break;

						case 100:
							txData = (char)'7';
							break;
						case 101:
							txData = (char)'6';
							break;
						case 102:
							txData = (char)'5';
							break;
						case 103:
							txData = (char)'4';
							break;
						case 104:
							txData = (char)'3';
							break;
						case 105:
							txData = (char)0x0D; // LF
							break;
						default:
							break;
						}

#endif
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
		m_trace->dump(sim_time);
		sim_time += time_step; // Increment simulation time
#endif

		top->eval();
		top->sysclk = !top->sysclk;

#ifdef DO_TRACE
		m_trace->dump(sim_time);
		sim_time += time_step; // Increment simulation time
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

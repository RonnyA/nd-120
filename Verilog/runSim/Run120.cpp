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
#include "verilated.h"

#ifdef DO_TRACE
#include <verilated_vcd_c.h>
#endif

// Save the original terminal settings
struct termios orig_termios;

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

int txData = 0;
int txDataBit = 0;
int txEnabled = 0;
int txTicks =0;
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
	top->uartRx = 1; // MARK
	int cnt = 0;

	while (true)
	{
		cnt++;

		if (cnt == 100)
		{
			top->btn1 = true; // sys_rst_n = 1 // disable reset
		}

		top->eval();
		top->sysclk = !top->sysclk;

		new_led = top->led ^ 0x3F; // bits are negated, active low
		//if (new_led != led)
		if (false)
		{
			uint8_t changed = new_led ^ led; // identify changed leds

			changed &= ~(1 << 4 | 1 << 3); // dont log cpu & bus grant

			//printf("LED changed to 0x%2X\r\n", new_led);
			led = new_led;
			DumpLedInfo(led, changed);
		}


		/*************************** TRANSMIT UART DATA *************************************/

		if (!txEnabled)
		{
			char ch;
			// Try to read a character from stdin
			ssize_t n = read(STDIN_FILENO, &ch, 1);

			if (n > 0)
			{
				//printf("You pressed: %x\n", ch);				

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
					txTicks = DELAY_FRAMES-1; // Start bit
					top->uartRx = 0;
					txOnes = 0;
					if (txData==0x0a) txData=0x0d; //LF, not CR
					//printf("TX[%02X] %c\r\n", txData, txData);
					break;
				case 1:
				case 2:
				case 3:
				case 4:
				case 5:
				case 6:
				case 7:
					if ((txData & 0x01) !=0)
					{
						top->uartRx = 1;
						txOnes++;
					}
					else
					{
						top->uartRx = 0;
					}
					txData >>=1;
					txTicks = DELAY_FRAMES-1;
					break;
				case 8: // Parity
					top->uartRx = 0;
					// Calculate even parity: set top->uartRx to 1 if txOnes is odd, 0 if even
            		//top->uartRx = (txOnes % 2) ? 0 : 1; // Even parity calculation
					txTicks = DELAY_FRAMES-1;
					break;
				case 9: // stop bits
				case 10: // stop bits
					top->uartRx = 1; // MARK!
					txTicks = DELAY_FRAMES-1;					
					break;
				case 11:									   
					txData = 0;
					txEnabled = false;
					break;
				}

				//printf("TX[%d] %d\r\n", txDataBit, top->uartRx);

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
				//printf("RX[%d] %d\r\n", rxDataBit, top->uartTx);

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
						rxOnes ++; // for parity check
						rxData |= (1 << (rxDataBit - 1));
					}
					rxTicks = DELAY_FRAMES-1;
					break;
				case 8: // Parity
					rxTicks = DELAY_FRAMES-1;
					break;
				case 9: // stop bits
				case 10: // stop bits
					rxTicks = DELAY_FRAMES-1;
					break;
				case 11:
					//printf("Received 0x%02X '%c'\r\n", rxData, rxData);
					printf("%c",rxData);
					fflush(stdout);

					rxData = 0;
					rxEnabled = false;
					break;
				}
				rxDataBit++;
			}

		}

		//sim_time += time_step; // Increment simulation time

		top->eval();
		top->sysclk = !top->sysclk;

		//sim_time += time_step; // Increment simulation time
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

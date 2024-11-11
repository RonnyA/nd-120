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
const char* LED_DESCRIPTION[6] =  {
    "CPU Red LED",                    // CPU_RED (1 << 0)
    "CPU Green LED",                  // CPU_GREEN (1 << 1)
    "Parity Error LED (LED4 Red)",    // LED4_RED_PARITY_ERROR (1 << 2)
    "CPU Grant Indicator LED",        // LED_CPU_GRANT_INDICATOR (1 << 3)
    "Bus Grant Indicator LED",        // LED_BUS_GRANT_INDICATOR (1 << 4)
    "MMU LED1"                        // MMU_LED1 (1 << 5)
};

// Led contains the bits with current state, changed contains bits for which led changed state
void DumpLedInfo(uint8_t led, uint8_t changed)
{
    bool first = true;
    for (int i = 0; i < 6; ++i) { // There are 6 LED signals
        int flag = 1 << i;
        
        if (changed & flag) { // Check if this LED's state has changed
            bool isOn = led & flag; // Determine if it's now ON or OFF
            std::cout << (first ? "" : ", ") << LED_DESCRIPTION[i] 
                      << " changed from " << (isOn ? "OFF to ON" : "ON to OFF");
            first = false;
        }
    }
    if (!first) {
        std::cout << std::endl; // Print a newline if any changes were printed
    }
}

#define MAX_SIM_TIME 20
vluint64_t sim_time = 0;
vluint64_t time_step = 5;




int main(int argc, char **argv)
{
	// TODO: Create real testcases, and replacew the for loop's below with a for-each loop
	//
	// Create a collection of test cases
	std::vector<TestCase> testCases = {
		// ---------------------------------------------------------- INPUTS------------------------------------------------------------------------------------------------------------------------------    ---------------------------------------------- EXPECTED OUTPUTS ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
		//
		{"Test 1"},
		{"Test 2"},
		{"Test 3"},
		{"Test 4"},
	};

	Verilated::commandArgs(argc, argv);
	VND120_TOP *top = new VND120_TOP;

#ifdef DO_TRACE
	VerilatedVcdC *m_trace = new VerilatedVcdC;
	Verilated::traceEverOn(true);
	top->trace(m_trace, 1); // 1 is the trace depth
	m_trace->open("waveform.vcd");
#endif

	int errCnt = 0;
	int testCnt = 0;
	// Iterate through each test case
	// for (const auto& test : testCases) {
	//     cnt++;

	const auto &test = testCases[0];
	uint8_t led = 0;

  // LED bits
  //!   0=CPU RED
  //!   1=CPU GREEN
  //!   2=LED4_RED_PARITY_ERROR
  //!   3=LED_CPU_GRANT_INDICATOR
  //!   4=LED_BUS_GRANT_INDICATOR
  //!   5=LED1 from MMU

	top->btn1 = false; // sys_rst_n = 0

	for (long cnt = 0; cnt < 1000000; cnt++)
	{
		if (cnt == 100)
		{
			top->btn1 = true; // sys_rst_n = 1 // disable reset
		}

		top->sysclk = !top->sysclk;
		top->eval();		
		if (top->led != led)
		{
			uint8_t changed = top->led ^ led; // identify changed leds
			printf("LED changed to %2X\r\n",top->led);
			led = top->led;
			DumpLedInfo(led, changed);

		}

#ifdef DO_TRACE
		m_trace->dump(sim_time);
		sim_time += time_step; // Increment simulation time
#endif

	}

	if (errCnt == 0)
	{
		printf("Passed \r\n");
	}
	else
	{
		printf("FAILED!! \r\n");
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

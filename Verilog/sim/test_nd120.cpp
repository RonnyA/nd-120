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

	for (int cnt = 0; cnt < 1000; cnt++)
	{
		top->sysclk = !top->sysclk;
		top->eval();
		if (top->led != led)
		{
			printf("LED changed to %2X\r\n",top->led);
			led = top->led;
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

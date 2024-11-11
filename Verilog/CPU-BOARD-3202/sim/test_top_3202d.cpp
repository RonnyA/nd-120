#define DO_TRACE
#include <iostream>
#include <vector>
#include <random>
#include <ctime>
#include <string>

#include "VND3202D.h"
#include "verilated.h"

#ifdef DO_TRACE
#include <verilated_vcd_c.h>
#endif

// DECODE_DGA testcases
struct TestCase
{

	// Clocks
	// bool       CLOCK_1;
	// bool       CLOCK_2;

	/*----------------  INPUTS ----------------------*/

	bool BINT10_n;
	bool BINT11_n;
	bool BINT12_n;
	bool BINT13_n;
	bool BINT15_n;
	bool BREQ_n;
	bool CONSOLE_n;
	bool CONTINUE_n;
	bool EAUTO_n;
	bool LOAD_n;
	bool LOCK_n;
	uint8_t OC1_0;
	bool OSCCL_n;
	bool RXD;
	bool STOP_n;
	bool SW1_CONSOLE;
	bool SWMCL_n;
	bool XTR;

	/*----------------  EXPECTED OUTPUT ----------------------*/
	uint8_t DP_5_1_n;
	bool RUN_n;
	uint8_t TEST_4_0;
	bool TP1_INTRQ_n;
	bool TXD;

	uint64_t CSBITS;

	/*--------------------------------------------*/

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
	VND3202D *top = new VND3202D;

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
	for (int cnt = 0; cnt < 32; cnt++)
	{
		for (int csidbs = 0; csidbs < 32; csidbs++)
		{

			for (int csmis = 0; csmis < 4; csmis++)
			{
				printf("Running test %d\r\n", ++testCnt);
				// printf("Running %s\r\n", test.description.c_str());

				// Set up your module inputs based on the test case
				// Assignments
				// top->XBRN = test.XBRN;
				// top->XCLO = test.XCLO;

				top->BINT10_n = true;
				top->BINT11_n = true;
				top->BINT12_n = true;
				top->BINT13_n = true;
				top->BINT15_n = true;
				top->BREQ_n = true;
				top->CONSOLE_n = true;
				top->CONTINUE_n = true;
				top->EAUTO_n = true;
				top->LOAD_n = true;
				top->LOCK_n = true;
				
				top->OC_1_0  = 0b11;


				top->OSCCL_n = true;
				top->RXD = false;
				top->STOP_n = true;
				top->SW1_CONSOLE = false;
				top->SWMCL_n = true;
				top->XTR = false;

				top->CLOCK_1 = 0; // Master clock (39.3216 MHZ)
				top->CLOCK_2 = 0; // Master clock (35 MHZ)
				top->eval();

#ifdef DO_TRACE
				m_trace->dump(sim_time);
				sim_time += time_step; // Increment simulation time
#endif
				top->CLOCK_1 = 1; // Master clock
				top->CLOCK_2 = 1; // Master clock
				top->eval();

#ifdef DO_TRACE
				m_trace->dump(sim_time);
				sim_time += time_step; // Increment simulation time
#endif

#ifdef ___later___
				// Check the output against the expected values
				if (top->XA_7_0 != test.expected_XA_7_0)
				{
					printf("[%s] XA_7_0: 0x%02x does not match expected 0x%02x\n", test.description.c_str(), top->XA_7_0, test.expected_XA_7_0);
					errCnt++;
				}

				if (top->XA_7_0_C != test.expected_XA_7_0_C)
				{
					printf("[%s] XA_7_0_C: 0x%02x does not match expected 0x%02x\n", test.description.c_str(), top->XA_7_0_C, test.expected_XA_7_0_C);
					errCnt++;
				}

				if (top->XC10 != test.expected_XC10)
				{
					printf("[%s] XC10 output does not match expected value\n", test.description.c_str());
					errCnt++;
				}

				if (top->XCLN != test.expected_XCLN)
				{
					printf("[%s] XCLN output does not match expected value\n", test.description.c_str());
					errCnt++;
				}

				if (top->XCRN != test.expected_XCRN)
				{
					printf("[%s] XCRN output does not match expected value\n", test.description.c_str());
					errCnt++;
				}

				if (top->XCSN != test.expected_XCSN)
				{
					printf("[%s] XCSN output does not match expected value\n", test.description.c_str());
					errCnt++;
				}

				if (top->XDON != test.expected_XDON)
				{
					printf("[%s] XDON output does not match expected value\n", test.description.c_str());
					errCnt++;
				}

				if (top->XDTN != test.expected_XDTN)
				{
					printf("[%s] XDTN output does not match expected value\n", test.description.c_str());
					errCnt++;
				}

				if (top->XDVN != test.expected_XDVN)
				{
					printf("[%s] XDVN output does not match expected value\n", test.description.c_str());
					errCnt++;
				}

				if (top->XECR != test.expected_XECR)
				{
					printf("[%s] XECR output does not match expected value\n", test.description.c_str());
					errCnt++;
				}

				if (top->XEMN != test.expected_XEMN)
				{
					printf("[%s] XEMN output does not match expected value\n", test.description.c_str());
					errCnt++;
				}

				if (top->XEPN != test.expected_XEPN)
				{
					printf("[%s] XEPN output does not match expected value\n", test.description.c_str());
					errCnt++;
				}

				if (top->XESN != test.expected_XESN)
				{
					printf("[%s] XESN output does not match expected value\n", test.description.c_str());
					errCnt++;
				}

				if (top->XEUN != test.expected_XEUN)
				{
					printf("[%s] XEUN output does not match expected value\n", test.description.c_str());
					errCnt++;
				}

				if (top->XFEC != test.expected_XFEC)
				{
					printf("[%s] XFEC output does not match expected value\n", test.description.c_str());
					errCnt++;
				}

				if (top->XFMI != test.expected_XFMI)
				{
					printf("[%s] XFMI output does not match expected value\n", test.description.c_str());
					errCnt++;
				}

				if (top->XFON != test.expected_XFON)
				{
					printf("[%s] XFON output does not match expected value\n", test.description.c_str());
					errCnt++;
				}

				if (top->XFUN != test.expected_XFUN)
				{
					printf("[%s] XFUN output does not match expected value\n", test.description.c_str());
					errCnt++;
				}

				if (top->XION != test.expected_XION)
				{
					printf("[%s] XION output does not match expected value\n", test.description.c_str());
					errCnt++;
				}

				if (top->XI_3_0_C != test.expected_XI_3_0_C)
				{
					printf("[%s] XI_3_0_C: 0x%02x does not match expected 0x%02x\n", test.description.c_str(), top->XI_3_0_C, test.expected_XI_3_0_C);
					errCnt++;
				}

				if (top->XI_3_0_O != test.expected_XI_3_0_O)
				{
					printf("[%s] XI_3_0_O: 0x%02x does not match expected 0x%02x\n", test.description.c_str(), top->XI_3_0_O, test.expected_XI_3_0_O);
					errCnt++;
				}

				if (top->XLHN != test.expected_XLHN)
				{
					printf("[%s] XLHN output does not match expected value\n", test.description.c_str());
					errCnt++;
				}

				if (top->XMCL != test.expected_XMCL)
				{
					printf("[%s] XMCL output does not match expected value\n", test.description.c_str());
					errCnt++;
				}

				if (top->XMRN != test.expected_XMRN)
				{
					printf("[%s] XMRN output does not match expected value\n", test.description.c_str());
					errCnt++;
				}

				if (top->XOCN != test.expected_XOCN)
				{
					printf("[%s] XOCN output does not match expected value\n", test.description.c_str());
					errCnt++;
				}

				if (top->XPAN != test.expected_XPAN)
				{
					printf("[%s] XPAN output does not match expected value\n", test.description.c_str());
					errCnt++;
				}

				if (top->XPEN != test.expected_XPEN)
				{
					printf("[%s] XPEN output does not match expected value\n", test.description.c_str());
					errCnt++;
				}

				if (top->XPFN != test.expected_XPFN)
				{
					printf("[%s] XPFN output does not match expected value\n", test.description.c_str());
					errCnt++;
				}

				if (top->XPIN != test.expected_XPIN)
				{
					printf("[%s] XPIN output does not match expected value\n", test.description.c_str());
					errCnt++;
				}

				if (top->XPNN != test.expected_XPNN)
				{
					printf("[%s] XPNN output does not match expected value\n", test.description.c_str());
					errCnt++;
				}

				if (top->XPSC != test.expected_XPSC)
				{
					printf("[%s] XPSC output does not match expected value\n", test.description.c_str());
					errCnt++;
				}

				if (top->XPSN != test.expected_XPSN)
				{
					printf("[%s] XPSN output does not match expected value\n", test.description.c_str());
					errCnt++;
				}

				if (top->XRFN != test.expected_XRFN)
				{
					printf("[%s] XRFN output does not match expected value\n", test.description.c_str());
					errCnt++;
				}

				if (top->XRIN != test.expected_XRIN)
				{
					printf("[%s] XRIN output does not match expected value\n", test.description.c_str());
					errCnt++;
				}

				if (top->XRQN != test.expected_XRQN)
				{
					printf("[%s] XRQN output does not match expected value\n", test.description.c_str());
					errCnt++;
				}

				if (top->XRTN != test.expected_XRTN)
				{
					printf("[%s] XRTN output does not match expected value\n", test.description.c_str());
					errCnt++;
				}

				if (top->XRUN != test.expected_XRUN)
				{
					printf("[%s] XRUN output does not match expected value\n", test.description.c_str());
					errCnt++;
				}

				if (top->XRWN != test.expected_XRWN)
				{
					printf("[%s] XRWN output does not match expected value\n", test.description.c_str());
					errCnt++;
				}

				if (top->XSCN != test.expected_XSCN)
				{
					printf("[%s] XSCN output does not match expected value\n", test.description.c_str());
					errCnt++;
				}

				if (top->XSHN != test.expected_XSHN)
				{
					printf("[%s] XSHN output does not match expected value\n", test.description.c_str());
					errCnt++;
				}

				if (top->XSSN != test.expected_XSSN)
				{
					printf("[%s] XSSN output does not match expected value\n", test.description.c_str());
					errCnt++;
				}

				if (top->XSTP != test.expected_XSTP)
				{
					printf("[%s] XSTP output does not match expected value\n", test.description.c_str());
					errCnt++;
				}

				if (top->XSWN != test.expected_XSWN)
				{
					printf("[%s] XSWN output does not match expected value\n", test.description.c_str());
					errCnt++;
				}

				if (top->XTE0 != test.expected_XTE0)
				{
					printf("[%s] XTE0 output does not match expected value\n", test.description.c_str());
					errCnt++;
				}

				if (top->XTOT != test.expected_XTOT)
				{
					printf("[%s] XTOT output does not match expected value\n", test.description.c_str());
					errCnt++;
				}

				if (top->XTRN != test.expected_XTRN)
				{
					printf("[%s] XTRN output does not match expected value\n", test.description.c_str());
					errCnt++;
				}

				if (top->XVAL != test.expected_XVAL)
				{
					printf("[%s] XVAL output does not match expected value\n", test.description.c_str());
					errCnt++;
				}

				if (top->XWHN != test.expected_XWHN)
				{
					printf("[%s] XWHN output does not match expected value\n", test.description.c_str());
					errCnt++;
				}

				if (top->XWRI != test.expected_XWRI)
				{
					printf("[%s] XWRI output does not match expected value\n", test.description.c_str());
					errCnt++;
				}
#endif
			}
		}
		// if (errCnt>0) break; // exit for loop
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

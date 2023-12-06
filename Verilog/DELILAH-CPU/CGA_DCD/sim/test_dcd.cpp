#define DO_TRACE
#include <iostream>
#include <vector>
#include <random>
#include <ctime>
#include <string>

#include "VCGA_DCD.h"
#include "verilated.h"

#ifdef DO_TRACE
#include <verilated_vcd_c.h>
#endif

// DCD testcases 
struct TestCase {

	uint8_t CSCOMM_4_0;
	uint8_t CSMIS_1_0;
	bool ILCSN;
	bool F15;
	bool ZF;
	bool CRY;
	bool SGR;
	bool WPN;
	bool PONI;
	bool VEX;
	bool BRKN;
	bool FIDBO5;
	bool MRN;
	bool LSHADOW;
	bool INTRQN;
	uint8_t CSIDBS_4_0;

	/*----------------  EXPECTED OUTOUT ----------------------*/

	bool expected_INDN;
	bool expected_XFETCHN;
	bool expected_CBRKN;
	bool expected_DSSTOPN;
	bool expected_LDLCN;
	bool expected_LDPILN;
	bool expected_LDIRV;
	bool expected_CSMREQ;
	bool expected_LDDBRN;
	bool expected_FETCHN;
	bool expected_WRITEN;
	bool expected_CLFFN;
	bool expected_EPIC;
	bool expected_LWAN;
	bool expected_LDGPRN;
	bool expected_WRTRF;
	bool expected_CFETCH;
	bool expected_VACCN;
	bool expected_CLIRQN;
	bool expected_EPGSN;
	bool expected_EPCRN;
	bool expected_EPICVN;
	bool expected_EPICSN;
	bool expected_ERFN;

	/*--------------------------------------------*/

	std::string description; // Description of the test case
};


#define MAX_SIM_TIME 20
vluint64_t sim_time = 0;
vluint64_t time_step = 5;


int main(int argc, char** argv)
{
	// TODO: Create real testcases, and replacew the for loop's below with a for-each loop
	// 
	// Create a collection of test cases
	std::vector<TestCase> testCases = {
		// CSCOMM_4_0  CSMIS_1_0  ILCSN  F15     ZF      CRY     SGR     WPN     PONI    VEX     BRKN    FIDBO5  MRN   LSHADOW  INTRQN   CSIDBS_4_0    expected_INDN    expected_XFETCHN  expected_CBRKN   expected_DSSTOPN  expected_LDLCN  expected_LDPILN  expected_LDIRV  expected_CSMREQ  expected_LDDBRN   expected_FETCHN   expected_WRITEN  expected_CLFFN  expected_EPIC  expected_LWAN   expected_LDGPRN   expected_WRTRF   expected_CFETCH  expected_VACCN   expected_CLIRQN  expected_EPGSN    expected_EPCRN   expected_EPICVN  expected_EPICSN   expected_ERFN   Description
		{0,            0,         true,  false,  false,  false,  false,  true,   false,  false,  true,   false,  true, false,   true,    0,            true,            true,             true,            true,             true,           true,            true,           true,            true,             true,             true,            true,           true,          true,           true,             true,            true,            true,            true,            true,             true,            true,            true,             true,           "Test 1"},
		{0,            0,         true,  false,  false,  false,  false,  true,   false,  false,  true,   false,  true, false,   true,    0,            true,            true,             true,            true,             true,           true,            true,           true,            true,             true,             true,            true,           true,          true,           true,             true,            true,            true,            true,            true,             true,            true,            true,             true,           "Test 2"},
		{0,            0,         true,  false,  false,  false,  false,  true,   false,  false,  true,   false,  true, false,   true,    0,            true,            true,             true,            true,             true,           true,            true,           true,            true,             true,             true,            true,           true,          true,           true,             true,            true,            true,            true,            true,             true,            true,            true,             true,           "Test 3"},
		{0,            0,         true,  false,  false,  false,  false,  true,   false,  false,  true,   false,  true, false,   true,    0,            true,            true,             true,            true,             true,           true,            true,           true,            true,             true,             true,            true,           true,          true,           true,             true,            true,            true,            true,            true,             true,            true,            true,             true,           "Test 4"}
	};






	Verilated::commandArgs(argc, argv);
	VCGA_DCD* top = new VCGA_DCD;

#ifdef DO_TRACE
	VerilatedVcdC* m_trace = new VerilatedVcdC;
	Verilated::traceEverOn(true);
	top->trace(m_trace, 1); // 1 is the trace depth
	m_trace->open("waveform.vcd");
#endif



	int errCnt = 0;
	int testCnt = 0;
	// Iterate through each test case
//for (const auto& test : testCases) {    
//    cnt++;


	const auto& test = testCases[0];
	for (int cnt = 0; cnt < 32; cnt++)
	{
		for (int csidbs = 0; csidbs < 32; csidbs++)
		{

			for (int csmis = 0; csmis < 4; csmis++)
			{
				printf("Running test %d\r\n", ++testCnt);
				//printf("Running %s\r\n", test.description.c_str());
				

				// Set up your module inputs based on the test case
				top->CSCOMM_4_0 = test.CSCOMM_4_0;
				top->CSMIS_1_0 = test.CSMIS_1_0;
				top->ILCSN = test.ILCSN;
				top->F15 = test.F15;
				top->ZF = test.ZF;
				top->CRY = test.CRY;
				top->SGR = test.SGR;
				top->WPN = test.WPN;
				top->PONI = test.PONI;
				top->VEX = test.VEX;
				top->BRKN = test.BRKN;
				top->FIDBO5 = test.FIDBO5;
				top->MRN = test.MRN;
				top->LSHADOW = test.LSHADOW;
				top->INTRQN = test.INTRQN;
				top->CSIDBS_4_0 = test.CSIDBS_4_0;


				// Set input SELECTION

				top->MCLK = 0;
				top->CSCOMM_4_0 = cnt;     // 0-31, loop test
				top->CSIDBS_4_0 = csidbs;  // 0-31, loop test
				top->CSMIS_1_0 = csmis;    // 0-3, loop test
				top->eval();

#ifdef DO_TRACE        
				m_trace->dump(sim_time);
				sim_time += time_step; // Increment simulation time
#endif


				top->MCLK = 1;
				top->eval();

#ifdef DO_TRACE        
				m_trace->dump(sim_time);
				sim_time += time_step; // Increment simulation time
#endif

#ifdef ___later___
				// Check the output against the expected values
				if (top->expected_INDN != test.expected_INDN) {
					printf("[%s] INDN output does not match expected value\n", test.description.c_str());
					errCnt++;
				}

				if (top->expected_XFETCHN != test.expected_XFETCHN) {
					printf("[%s] XFETCHN output does not match expected value\n", test.description.c_str());
					errCnt++;
				}

				if (top->expected_CBRKN != test.expected_CBRKN) {
					printf("[%s] CBRKN output does not match expected value\n", test.description.c_str());
					errCnt++;
				}

				if (top->expected_DSSTOPN != test.expected_DSSTOPN) {
					printf("[%s] DSSTOPN output does not match expected value\n", test.description.c_str());
					errCnt++;
				}

				if (top->expected_LDLCN != test.expected_LDLCN) {
					printf("[%s] LDLCN output does not match expected value\n", test.description.c_str());
					errCnt++;
				}

				if (top->expected_LDPILN != test.expected_LDPILN) {
					printf("[%s] LDPILN output does not match expected value\n", test.description.c_str());
					errCnt++;
				}

				if (top->expected_LDIRV != test.expected_LDIRV) {
					printf("[%s] LDIRV output does not match expected value\n", test.description.c_str());
					errCnt++;
				}

				if (top->expected_CSMREQ != test.expected_CSMREQ) {
					printf("[%s] CSMREQ output does not match expected value\n", test.description.c_str());
					errCnt++;
				}

				if (top->expected_LDDBRN != test.expected_LDDBRN) {
					printf("[%s] LDDBRN output does not match expected value\n", test.description.c_str());
					errCnt++;
				}

				if (top->expected_FETCHN != test.expected_FETCHN) {
					printf("[%s] FETCHN output does not match expected value\n", test.description.c_str());
					errCnt++;
				}

				if (top->expected_WRITEN != test.expected_WRITEN) {
					printf("[%s] WRITEN output does not match expected value\n", test.description.c_str());
					errCnt++;
				}

				if (top->expected_CLFFN != test.expected_CLFFN) {
					printf("[%s] CLFFN output does not match expected value\n", test.description.c_str());
					errCnt++;
				}

				if (top->expected_EPIC != test.expected_EPIC) {
					printf("[%s] EPIC output does not match expected value\n", test.description.c_str());
					errCnt++;
				}

				if (top->expected_LWAN != test.expected_LWAN) {
					printf("[%s] LWAN output does not match expected value\n", test.description.c_str());
					errCnt++;
				}

				if (top->expected_LDGPRN != test.expected_LDGPRN) {
					printf("[%s] LDGPRN output does not match expected value\n", test.description.c_str());
					errCnt++;
				}

				if (top->expected_WRTRF != test.expected_WRTRF) {
					printf("[%s] WRTRF output does not match expected value\n", test.description.c_str());
					errCnt++;
				}

				if (top->expected_CFETCH != test.expected_CFETCH) {
					printf("[%s] CFETCH output does not match expected value\n", test.description.c_str());
					errCnt++;
				}

				if (top->expected_VACCN != test.expected_VACCN) {
					printf("[%s] VACCN output does not match expected value\n", test.description.c_str());
					errCnt++;
				}

				if (top->expected_CLIRQN != test.expected_CLIRQN) {
					printf("[%s] CLIRQN output does not match expected value\n", test.description.c_str());
					errCnt++;
				}

				if (top->expected_EPGSN != test.expected_EPGSN) {
					printf("[%s] EPGSN output does not match expected value\n", test.description.c_str());
					errCnt++;
				}

				if (top->expected_EPCRN != test.expected_EPCRN) {
					printf("[%s] EPCRN output does not match expected value\n", test.description.c_str());
					errCnt++;
				}

				if (top->expected_EPICVN != test.expected_EPICVN) {
					printf("[%s] EPICVN output does not match expected value\n", test.description.c_str());
					errCnt++;
				}

				if (top->expected_EPICSN != test.expected_EPICSN) {
					printf("[%s] EPICSN output does not match expected value\n", test.description.c_str());
					errCnt++;
				}

				if (top->expected_ERFN != test.expected_ERFN) {
					printf("[%s] ERFN output does not match expected value\n", test.description.c_str());
					errCnt++;
				}

#endif
			}
		}
		//if (errCnt>0) break; // exit for loop
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




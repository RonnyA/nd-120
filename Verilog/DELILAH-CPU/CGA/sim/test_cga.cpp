#define DO_TRACE
#include <iostream>
#include <vector>
#include <random>
#include <ctime>
#include <string>

#include "VCGA.h"
#include "verilated.h"

#ifdef DO_TRACE
#include <verilated_vcd_c.h>
#endif

// CGA testcases 
struct TestCase {
	// bool XTCLK;
	// bool XALUCLK;
	// bool XMCLK;

	bool     BDEST;
	    
	bool     XBINT10N;
	bool     XBINT11N;
	bool     XBINT12N;
	bool     XBINT13N;
	bool     XBINT15N;
	bool     XCSBIT20;
	bool     XCSECOND;
	bool     XCSLOOP;
	bool     XCSRBSEL0;
	bool     XCSRBSEL1;
	bool     XCSSCOND;
	bool     XCSVECT;
	bool     XCSXRF3;
	bool     XEDON;
	bool     XEMPIDN;
	bool     XETRAPN;
	bool     XEWCAN;
	bool     XFTRAPN;
	bool     XILCSN;
	bool     XIOXERRN;
	bool     XMAPN;	
	bool     XMORN;
	bool     XMRN;
	bool     XPANN;
	bool     XPARERRN;
	bool     XPOWFAILN;
	bool     XPTSTN;
	bool     XSPARE;
	bool     XSTP;	
	bool     XVTRAPN;

	uint16_t XCD_15_0;

	uint16_t XCSALUI_8_0;
	uint8_t  XCSALUM_1_0;
	uint16_t XCSBIT_15_0;
	uint8_t  XCSCINSEL_1_0;
	uint8_t  XCSIDBS_4_0;
	uint8_t  XCSMIS_1_0;
	uint8_t  XCSRASEL_1_0;
	uint8_t  XCSRB_3_0;	
	uint8_t  XCSSST_1_0;
	uint8_t  XCSTS_6_3;		
	uint8_t  XCSCOMM_4_0;

	uint8_t  XPT_9_15;
	uint8_t  XTSEL_2_0; // Test selector
	uint16_t XFIDB_15_0_IN; // On the real chip those pins are shared with XFIDB_15_0_OUT

	/*----------------  EXPECTED OUTOUT ----------------------*/

	uint16_t    expected_XFIDB_15_0_OUT; // On the real chip those pins are shared with XFIDB_15_0_IN

	bool        expected_XACONDN;
	bool        expected_XBRKN;
	bool        expected_XDOUBLE;
	bool        expected_XECCR;
	bool        expected_XERFN;
	bool        expected_XINTRQN;
	bool        expected_XIONI;
	bool        expected_XLSHADOW;
	bool        expected_XPONI;
	bool        expected_XTRAPN;
	bool        expected_XWCSN;
	bool        expected_XWRTRF;

	uint8_t     expected_XLAA_3_0;
	uint16_t    expected_XLA_23_10;
	uint8_t     expected_XLBA_3_0;
	uint16_t    expected_XMA_12_0;
	uint16_t    expected_XMCA_9_0;
	uint8_t     expected_XPCR_1_0;
	uint8_t     expected_XPIL_3_0;
	uint8_t     expected_XRF_1_0;
	uint8_t     expected_XTEST_4_0;

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
 	  // BDEST  XBINT10N  XBINT11N  XBINT12N  XBINT13N  XBINT15N  XCSBIT20  XCSECOND  XCSLOOP  XCSRBSEL0  XCSRBSEL1  XCSSCOND  XCSVECT  XCSXRF3  XEDON  XEMPIDN  XETRAPN  XEWCAN  XFTRAPN  XILCSN  XIOXERRN  XMAPN  XMORN  XMRN  XPANN  XPARERRN  XPOWFAILN  XPTSTN  XSPARE  XSTP  XVTRAPN  XCD_15_0  XCSALUI_8_0  XCSALUM_1_0  XCSBIT_15_0  XCSCINSEL_1_0  XCSIDBS_4_0  XCSMIS_1_0  XCSRASEL_1_0  XCSRB_3_0  XCSSST_1_0  XCSTS_6_3  XCSCOMM_4_0  XPT_9_15  XTSEL_2_0  XFIDB_15_0_IN  expected_XFIDB_15_0_OUT  expected_XACONDN  expected_XBRKN  expected_XDOUBLE  expected_XECCR  expected_XERFN  expected_XINTRQN  expected_XIONI  expected_XLSHADOW  expected_XPONI  expected_XTRAPN  expected_XWCSN  expected_XWRTRF  expected_XLAA_3_0  expected_XLA_23_10  expected_XLBA_3_0  expected_XMA_12_0  expected_XMCA_9_0  expected_XPCR_1_0  expected_XPIL_3_0  expected_XRF_1_0  expected_XTEST_4_0  Description
		{false, true,     true,     true,     true,     true,     false,    false,    false,   false,     false,     false,    false,   false,   false, false,   true,    false,  true,    true,   true,      false, false, false, true, false,    true,       false,   false,  false, true,    0,        0,           0,           0,           0,               0,            0,          0,            0,         0,           0,         0,            0,        0,         0,              0,                     true,            true,        true,           true,         true,         true,            true,         true,            true,        true,          true,         true,           0,               0,                0,             0,              0,             0,               0,               0,              0,             "Test 1"},
		{false, true,     true,     true,     true,     true,     false,    false,    false,   false,     false,     false,    false,   false,   false, false,   true,    false,  true,    true,   true,      false, false, false, true, false,    true,       false,   false,  false, true,    0,        0,           0,           0,           0,               0,            0,          0,            0,         0,           0,         0,            0,        0,         0,              0,                     true,            true,        true,           true,         true,         true,            true,         true,            true,        true,          true,         true,           0,               0,                0,             0,              0,             0,               0,               0,              0,             "Test 2"},
		{false, true,     true,     true,     true,     true,     false,    false,    false,   false,     false,     false,    false,   false,   false, false,   true,    false,  true,    true,   true,      false, false, false, true, false,    true,       false,   false,  false, true,    0,        0,           0,           0,           0,               0,            0,          0,            0,         0,           0,         0,            0,        0,         0,              0,                     true,            true,        true,           true,         true,         true,            true,         true,            true,        true,          true,         true,           0,               0,                0,             0,              0,             0,               0,               0,              0,             "Test 3"},
		{false, true,     true,     true,     true,     true,     false,    false,    false,   false,     false,     false,    false,   false,   false, false,   true,    false,  true,    true,   true,      false, false, false, true, false,    true,       false,   false,  false, true,    0,        0,           0,           0,           0,               0,            0,          0,            0,         0,           0,         0,            0,        0,         0,              0,                     true,            true,        true,           true,         true,         true,            true,         true,            true,        true,          true,         true,           0,               0,                0,             0,              0,             0,               0,               0,              0,             "Test 4"},
    };



	Verilated::commandArgs(argc, argv);
	VCGA* top = new VCGA;

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
				
				top->BDEST = test.BDEST;
				top->XBINT10N = test.XBINT10N;
				top->XBINT11N = test.XBINT11N;
				top->XBINT12N = test.XBINT12N;
				top->XBINT13N = test.XBINT13N;
				top->XBINT15N = test.XBINT15N;
				top->XCSBIT20 = test.XCSBIT20;
				top->XCSECOND = test.XCSECOND;
				top->XCSLOOP = test.XCSLOOP;
				top->XCSRBSEL0 = test.XCSRBSEL0;
				top->XCSRBSEL1 = test.XCSRBSEL1;
				top->XCSSCOND = test.XCSSCOND;
				top->XCSVECT = test.XCSVECT;
				top->XCSXRF3 = test.XCSXRF3;
				top->XEDON = test.XEDON;
				top->XEMPIDN = test.XEMPIDN;
				top->XETRAPN = test.XETRAPN;
				top->XEWCAN = test.XEWCAN;
				top->XFTRAPN = test.XFTRAPN;
				top->XILCSN = test.XILCSN;
				top->XIOXERRN = test.XIOXERRN;
				top->XMAPN = test.XMAPN;
				top->XMORN = test.XMORN;
				top->XMRN = test.XMRN;
				top->XPANN = test.XPANN;
				top->XPARERRN = test.XPARERRN;
				top->XPOWFAILN = test.XPOWFAILN;
				top->XPTSTN = test.XPTSTN;
				top->XSPARE = test.XSPARE;
				top->XSTP = test.XSTP;
				top->XVTRAPN = test.XVTRAPN;
				top->XCD_15_0 = test.XCD_15_0;
				top->XCSALUI_8_0 = test.XCSALUI_8_0;
				top->XCSALUM_1_0 = test.XCSALUM_1_0;
				top->XCSBIT_15_0 = test.XCSBIT_15_0;
				top->XCSCINSEL_1_0 = test.XCSCINSEL_1_0;
				top->XCSIDBS_4_0 = test.XCSIDBS_4_0;
				top->XCSMIS_1_0 = test.XCSMIS_1_0;
				top->XCSRASEL_1_0 = test.XCSRASEL_1_0;
				top->XCSRB_3_0 = test.XCSRB_3_0;
				top->XCSSST_1_0 = test.XCSSST_1_0;
				top->XCSTS_6_3 = test.XCSTS_6_3;
				top->XCSCOMM_4_0 = test.XCSCOMM_4_0;
				top->XPT_9_15 = test.XPT_9_15;
				top->XTSEL_2_0 = test.XTSEL_2_0;
				top->XFIDB_15_0_IN = test.XFIDB_15_0_IN;

				// Random fun
				top->XCD_15_0 = cnt;	
				top->XCSBIT_15_0 = cnt;
				top->XCSALUI_8_0 =  cnt & 0x1FF;
				top->XFIDB_15_0_IN = csidbs;
				top->XCSIDBS_4_0 = csidbs;

				top->XMAPN = cnt & 0x1;
				// Tick the 3 clocks! :-O

				top->XTCLK = 0;  // Trap clock
				top->XALUCLK = 0; // ALU clock
				top->XMCLK = 0; // Master clock
				top->eval();

#ifdef DO_TRACE        
				m_trace->dump(sim_time);
				sim_time += time_step; // Increment simulation time
#endif
				top->XTCLK = 1;  // Trap clock
				top->XALUCLK = 1; // ALU clock
				top->XMCLK = 1; // Master clock
				top->eval();

#ifdef DO_TRACE        
				m_trace->dump(sim_time);
				sim_time += time_step; // Increment simulation time
#endif

#ifdef ___later___
		// Check the output against the expected values
		if (top->expected_XFIDB_15_0_OUT != test.expected_XFIDB_15_0_OUT) {
			printf("[%s] XFIDB_15_0_OUT: 0x%04x does not match expected 0x%04x\n", test.description.c_str(), top->expected_XFIDB_15_0_OUT, test.expected_XFIDB_15_0_OUT);
			errCnt++;
		}

		if (top->expected_XACONDN != test.expected_XACONDN) {
			printf("[%s] XACONDN output does not match expected value\n", test.description.c_str());
			errCnt++;
		}

		if (top->expected_XBRKN != test.expected_XBRKN) {
			printf("[%s] XBRKN output does not match expected value\n", test.description.c_str());
			errCnt++;
		}

		if (top->expected_XDOUBLE != test.expected_XDOUBLE) {
			printf("[%s] XDOUBLE output does not match expected value\n", test.description.c_str());
			errCnt++;
		}

		if (top->expected_XECCR != test.expected_XECCR) {
			printf("[%s] XECCR output does not match expected value\n", test.description.c_str());
			errCnt++;
		}

		if (top->expected_XERFN != test.expected_XERFN) {
			printf("[%s] XERFN output does not match expected value\n", test.description.c_str());
			errCnt++;
		}

		if (top->expected_XINTRQN != test.expected_XINTRQN) {
			printf("[%s] XINTRQN output does not match expected value\n", test.description.c_str());
			errCnt++;
		}

		if (top->expected_XIONI != test.expected_XIONI) {
			printf("[%s] XIONI output does not match expected value\n", test.description.c_str());
			errCnt++;
		}

		if (top->expected_XLSHADOW != test.expected_XLSHADOW) {
			printf("[%s] XLSHADOW output does not match expected value\n", test.description.c_str());
			errCnt++;
		}

		if (top->expected_XPONI != test.expected_XPONI) {
			printf("[%s] XPONI output does not match expected value\n", test.description.c_str());
			errCnt++;
		}

		if (top->expected_XTRAPN != test.expected_XTRAPN) {
			printf("[%s] XTRAPN output does not match expected value\n", test.description.c_str());
			errCnt++;
		}

		if (top->expected_XWCSN != test.expected_XWCSN) {
			printf("[%s] XWCSN output does not match expected value\n", test.description.c_str());
			errCnt++;
		}

		if (top->expected_XWRTRF != test.expected_XWRTRF) {
			printf("[%s] XWRTRF output does not match expected value\n", test.description.c_str());
			errCnt++;
		}

		if (top->expected_XLAA_3_0 != test.expected_XLAA_3_0) {
			printf("[%s] XLAA_3_0 output: 0x%02x does not match expected 0x%02x\n", test.description.c_str(), top->expected_XLAA_3_0, test.expected_XLAA_3_0);
			errCnt++;
		}

		if (top->expected_XLA_23_10 != test.expected_XLA_23_10) {
			printf("[%s] XLA_23_10 output: 0x%04x does not match expected 0x%04x\n", test.description.c_str(), top->expected_XLA_23_10, test.expected_XLA_23_10);
			errCnt++;
		}

		if (top->expected_XLBA_3_0 != test.expected_XLBA_3_0) {
			printf("[%s] XLBA_3_0 output: 0x%02x does not match expected 0x%02x\n", test.description.c_str(), top->expected_XLBA_3_0, test.expected_XLBA_3_0);
			errCnt++;
		}

		if (top->expected_XMA_12_0 != test.expected_XMA_12_0) {
			printf("[%s] XMA_12_0 output: 0x%03x does not match expected 0x%03x\n", test.description.c_str(), top->expected_XMA_12_0, test.expected_XMA_12_0);
			errCnt++;
		}

		if (top->expected_XMCA_9_0 != test.expected_XMCA_9_0) {
			printf("[%s] XMCA_9_0 output: 0x%03x does not match expected 0x%03x\n", test.description.c_str(), top->expected_XMCA_9_0, test.expected_XMCA_9_0);
			errCnt++;
		}

		if (top->expected_XPCR_1_0 != test.expected_XPCR_1_0) {
			printf("[%s] XPCR_1_0 output: 0x%02x does not match expected 0x%02x\n", test.description.c_str(), top->expected_XPCR_1_0, test.expected_XPCR_1_0);
			errCnt++;
		}

		if (top->expected_XPIL_3_0 != test.expected_XPIL_3_0) {
			printf("[%s] XPIL_3_0 output: 0x%02x does not match expected 0x%02x\n", test.description.c_str(), top->expected_XPIL_3_0, test.expected_XPIL_3_0);
			errCnt++;
		}

		if (top->expected_XRF_1_0 != test.expected_XRF_1_0) {
			printf("[%s] XRF_1_0 output: 0x%02x does not match expected 0x%02x\n", test.description.c_str(), top->expected_XRF_1_0, test.expected_XRF_1_0);
			errCnt++;
		}

		if (top->expected_XTEST_4_0 != test.expected_XTEST_4_0) {
			printf("[%s] XTEST_4_0 output: 0x%02x does not match expected 0x%02x\n", test.description.c_str(), top->expected_XTEST_4_0, test.expected_XTEST_4_0);
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




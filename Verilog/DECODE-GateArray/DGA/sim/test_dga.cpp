#define DO_TRACE
#include <iostream>
#include <vector>
#include <random>
#include <ctime>
#include <string>

#include "VDECODE_DGA.h"
#include "verilated.h"

#ifdef DO_TRACE
#include <verilated_vcd_c.h>
#endif

// DECODE_DGA testcases 
struct TestCase {

	// Clocks
	//bool       XCLK;

	/*----------------  INPUTS ----------------------*/
   bool       XBRN;
   bool       XCLO;
   bool       XCON;
   uint8_t    XCO_4_0;
   bool       XDAN;
   bool       XDBN;
   bool       XEFN;
   bool       XEON;
   bool       XHIN;
   uint8_t    XIB_7_4;
   uint8_t    XID_4_0;
   uint8_t    XI_3_0_I;
   bool       XLCN;
   bool       XLON;
   bool       XLSH;
   uint8_t    XMI_1_0;
   bool       XPDI;
   bool       XPOW;
   bool       XPWC;
   bool       XRMN;
   bool       XRTO;
   bool       XS5N;
   uint8_t    XST_4_3;
   bool       XTES;
   bool       XTON;
   bool       XUCK;

	/*----------------  EXPECTED OUTOUT ----------------------*/

   uint8_t  expected_XA_7_0;
   uint8_t  expected_XA_7_0_C;
   bool     expected_XC10;
   bool     expected_XCLN;
   bool     expected_XCRN;
   bool     expected_XCSN;
   bool     expected_XDON;
   bool     expected_XDTN;
   bool     expected_XDVN;
   bool     expected_XECR;
   bool     expected_XEMN;
   bool     expected_XEPN;
   bool     expected_XESN;
   bool     expected_XEUN;
   bool     expected_XFEC;
   bool     expected_XFMI;
   bool     expected_XFON;
   bool     expected_XFUN;
   bool     expected_XION;
   uint8_t  expected_XI_3_0_C;
   uint8_t  expected_XI_3_0_O;
   bool     expected_XLHN;
   bool     expected_XMCL;
   bool     expected_XMRN;
   bool     expected_XOCN;
   bool     expected_XPAN;
   bool     expected_XPEN;
   bool     expected_XPFN;
   bool     expected_XPIN;
   bool     expected_XPNN;
   bool     expected_XPSC;
   bool     expected_XPSN;
   bool     expected_XRFN;
   bool     expected_XRIN;
   bool     expected_XRQN;
   bool     expected_XRTN;
   bool     expected_XRUN;
   bool     expected_XRWN;
   bool     expected_XSCN;
   bool     expected_XSHN;
   bool     expected_XSSN;
   bool     expected_XSTP;
   bool     expected_XSWN;
   bool     expected_XTE0;
   bool     expected_XTOT;
   bool     expected_XTRN;
   bool     expected_XVAL;
   bool     expected_XWHN;
   bool     expected_XWRI;

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
  // ---------------------------------------------------------- INPUTS------------------------------------------------------------------------------------------------------------------------------    ---------------------------------------------- EXPECTED OUTPUTS ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
  // XBRN   XCLO   XCON   XCO_4_0  XDAN   XDBN   XEFN   XEON  XHIN   XIB_7_4  XID_4_0  XI_3_0_I  XLCN   XLON   XLSH   XMI_1_0  XPDI   XPOW   XPWC   XRMN  XRTO   XS5N   XST_4_3  XTES    XTON  XUCK     expected_XA_7_0  expected_XA_7_0_C  expected_XC10  expected_XCLN  expected_XCRN  expected_XCSN  expected_XDON  expected_XDTN  expected_XDVN  expected_XECR  expected_XEMN  expected_XEPN  expected_XESN  expected_XEUN  expected_XFEC  expected_XFMI  expected_XFON  expected_XFUN  expected_XION  expected_XI_3_0_C  expected_XI_3_0_O  expected_XLHN  expected_XMCL  expected_XMRN  expected_XOCN  expected_XPAN  expected_XPEN  expected_XPFN  expected_XPIN  expected_XPNN  expected_XPSC  expected_XPSN  expected_XRFN  expected_XRIN  expected_XRQN  expected_XRTN  expected_XRUN  expected_XRWN  expected_XSCN  expected_XSHN  expected_XSSN  expected_XSTP  expected_XSWN  expected_XTE0  expected_XTOT  expected_XTRN  expected_XVAL  expected_XWHN  expected_XWRI  Description
    {true,  false, false, 0,       true,  true,  true,  true, false, 0,       0,       0,        true,  true,  false, 0,       false, false, false, true, false, true,  0,       false,  true, false,   0,               0,                 true,          true,          true,          true,          true,          true,          true,          true,          true,          true,          true,          true,          true,          true,          true,          true,          true,          0,                 0,                 true,          true,          true,          true,          true,          true,          true,          true,          true,          true,          true,          true,          true,          true,          true,          true,          true,          true,          true,          true,          true,          true,          true,          true,          true,          true,          true,          true,          "Test 1"},
	{true,  false, false, 0,       true,  true,  true,  true, false, 0,       0,       0,        true,  true,  false, 0,       false, false, false, true, false, true,  0,       false,  true, false,   0,               0,                 true,          true,          true,          true,          true,          true,          true,          true,          true,          true,          true,          true,          true,          true,          true,          true,          true,          0,                 0,                 true,          true,          true,          true,          true,          true,          true,          true,          true,          true,          true,          true,          true,          true,          true,          true,          true,          true,          true,          true,          true,          true,          true,          true,          true,          true,          true,          true,          "Test 1"},
	{true,  false, false, 0,       true,  true,  true,  true, false, 0,       0,       0,        true,  true,  false, 0,       false, false, false, true, false, true,  0,       false,  true, false,   0,               0,                 true,          true,          true,          true,          true,          true,          true,          true,          true,          true,          true,          true,          true,          true,          true,          true,          true,          0,                 0,                 true,          true,          true,          true,          true,          true,          true,          true,          true,          true,          true,          true,          true,          true,          true,          true,          true,          true,          true,          true,          true,          true,          true,          true,          true,          true,          true,          true,          "Test 1"},
	{true,  false, false, 0,       true,  true,  true,  true, false, 0,       0,       0,        true,  true,  false, 0,       false, false, false, true, false, true,  0,       false,  true, false,   0,               0,                 true,          true,          true,          true,          true,          true,          true,          true,          true,          true,          true,          true,          true,          true,          true,          true,          true,          0,                 0,                 true,          true,          true,          true,          true,          true,          true,          true,          true,          true,          true,          true,          true,          true,          true,          true,          true,          true,          true,          true,          true,          true,          true,          true,          true,          true,          true,          true,          "Test 1"}
};




	Verilated::commandArgs(argc, argv);
	VDECODE_DGA* top = new VDECODE_DGA;

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
				// Assignments
				top->XBRN = test.XBRN;
				top->XCLO = test.XCLO;
				top->XCON = test.XCON;
				top->XCO_4_0 = test.XCO_4_0;
				top->XDAN = test.XDAN;
				top->XDBN = test.XDBN;
				top->XEFN = test.XEFN;
				top->XEON = test.XEON;
				top->XHIN = test.XHIN;
				top->XIB_7_4 = test.XIB_7_4;
				top->XID_4_0 = test.XID_4_0;
				top->XI_3_0_I = test.XI_3_0_I;
				top->XLCN = test.XLCN;
				top->XLON = test.XLON;
				top->XLSH = test.XLSH;
				top->XMI_1_0 = test.XMI_1_0;
				top->XPDI = test.XPDI;
				top->XPOW = test.XPOW;
				top->XPWC = test.XPWC;
				top->XRMN = test.XRMN;
				top->XRTO = test.XRTO;
				top->XS5N = test.XS5N;
				top->XST_4_3 = test.XST_4_3;
				top->XTES = test.XTES;
				top->XTON = test.XTON;
				top->XUCK = test.XUCK;

				// Trigger som response (fixe later with real tests)
				top->XCO_4_0 = csidbs;
				top->XMI_1_0 = csmis;

				top->XCLK = 0; // Master clock
				top->eval();

#ifdef DO_TRACE        
				m_trace->dump(sim_time);
				sim_time += time_step; // Increment simulation time
#endif
				top->XCLK = 1; // Master clock
				top->eval();

#ifdef DO_TRACE        
				m_trace->dump(sim_time);
				sim_time += time_step; // Increment simulation time
#endif

#ifdef ___later___
		// Check the output against the expected values
		if (top->XA_7_0 != test.expected_XA_7_0) {
			printf("[%s] XA_7_0: 0x%02x does not match expected 0x%02x\n", test.description.c_str(), top->XA_7_0, test.expected_XA_7_0);
			errCnt++;
		}

		if (top->XA_7_0_C != test.expected_XA_7_0_C) {
			printf("[%s] XA_7_0_C: 0x%02x does not match expected 0x%02x\n", test.description.c_str(), top->XA_7_0_C, test.expected_XA_7_0_C);
			errCnt++;
		}

		if (top->XC10 != test.expected_XC10) {
			printf("[%s] XC10 output does not match expected value\n", test.description.c_str());
			errCnt++;
		}

		if (top->XCLN != test.expected_XCLN) {
			printf("[%s] XCLN output does not match expected value\n", test.description.c_str());
			errCnt++;
		}

		if (top->XCRN != test.expected_XCRN) {
			printf("[%s] XCRN output does not match expected value\n", test.description.c_str());
			errCnt++;
		}

		if (top->XCSN != test.expected_XCSN) {
			printf("[%s] XCSN output does not match expected value\n", test.description.c_str());
			errCnt++;
		}

		if (top->XDON != test.expected_XDON) {
			printf("[%s] XDON output does not match expected value\n", test.description.c_str());
			errCnt++;
		}

		if (top->XDTN != test.expected_XDTN) {
			printf("[%s] XDTN output does not match expected value\n", test.description.c_str());
			errCnt++;
		}

		if (top->XDVN != test.expected_XDVN) {
			printf("[%s] XDVN output does not match expected value\n", test.description.c_str());
			errCnt++;
		}

		if (top->XECR != test.expected_XECR) {
			printf("[%s] XECR output does not match expected value\n", test.description.c_str());
			errCnt++;
		}

		if (top->XEMN != test.expected_XEMN) {
			printf("[%s] XEMN output does not match expected value\n", test.description.c_str());
			errCnt++;
		}

		if (top->XEPN != test.expected_XEPN) {
			printf("[%s] XEPN output does not match expected value\n", test.description.c_str());
			errCnt++;
		}

		if (top->XESN != test.expected_XESN) {
			printf("[%s] XESN output does not match expected value\n", test.description.c_str());
			errCnt++;
		}

		if (top->XEUN != test.expected_XEUN) {
			printf("[%s] XEUN output does not match expected value\n", test.description.c_str());
			errCnt++;
		}

		if (top->XFEC != test.expected_XFEC) {
			printf("[%s] XFEC output does not match expected value\n", test.description.c_str());
			errCnt++;
		}

		if (top->XFMI != test.expected_XFMI) {
			printf("[%s] XFMI output does not match expected value\n", test.description.c_str());
			errCnt++;
		}

		if (top->XFON != test.expected_XFON) {
			printf("[%s] XFON output does not match expected value\n", test.description.c_str());
			errCnt++;
		}

		if (top->XFUN != test.expected_XFUN) {
			printf("[%s] XFUN output does not match expected value\n", test.description.c_str());
			errCnt++;
		}

		if (top->XION != test.expected_XION) {
			printf("[%s] XION output does not match expected value\n", test.description.c_str());
			errCnt++;
		}

		if (top->XI_3_0_C != test.expected_XI_3_0_C) {
			printf("[%s] XI_3_0_C: 0x%02x does not match expected 0x%02x\n", test.description.c_str(), top->XI_3_0_C, test.expected_XI_3_0_C);
			errCnt++;
		}

		if (top->XI_3_0_O != test.expected_XI_3_0_O) {
			printf("[%s] XI_3_0_O: 0x%02x does not match expected 0x%02x\n", test.description.c_str(), top->XI_3_0_O, test.expected_XI_3_0_O);
			errCnt++;
		}

		if (top->XLHN != test.expected_XLHN) {
			printf("[%s] XLHN output does not match expected value\n", test.description.c_str());
			errCnt++;
		}

		if (top->XMCL != test.expected_XMCL) {
			printf("[%s] XMCL output does not match expected value\n", test.description.c_str());
			errCnt++;
		}

		if (top->XMRN != test.expected_XMRN) {
			printf("[%s] XMRN output does not match expected value\n", test.description.c_str());
			errCnt++;
		}

		if (top->XOCN != test.expected_XOCN) {
			printf("[%s] XOCN output does not match expected value\n", test.description.c_str());
			errCnt++;
		}

		if (top->XPAN != test.expected_XPAN) {
			printf("[%s] XPAN output does not match expected value\n", test.description.c_str());
			errCnt++;
		}

		if (top->XPEN != test.expected_XPEN) {
			printf("[%s] XPEN output does not match expected value\n", test.description.c_str());
			errCnt++;
		}

		if (top->XPFN != test.expected_XPFN) {
			printf("[%s] XPFN output does not match expected value\n", test.description.c_str());
			errCnt++;
		}

		if (top->XPIN != test.expected_XPIN) {
			printf("[%s] XPIN output does not match expected value\n", test.description.c_str());
			errCnt++;
		}

		if (top->XPNN != test.expected_XPNN) {
			printf("[%s] XPNN output does not match expected value\n", test.description.c_str());
			errCnt++;
		}

		if (top->XPSC != test.expected_XPSC) {
			printf("[%s] XPSC output does not match expected value\n", test.description.c_str());
			errCnt++;
		}

		if (top->XPSN != test.expected_XPSN) {
			printf("[%s] XPSN output does not match expected value\n", test.description.c_str());
			errCnt++;
		}

		if (top->XRFN != test.expected_XRFN) {
			printf("[%s] XRFN output does not match expected value\n", test.description.c_str());
			errCnt++;
		}

		if (top->XRIN != test.expected_XRIN) {
			printf("[%s] XRIN output does not match expected value\n", test.description.c_str());
			errCnt++;
		}

		if (top->XRQN != test.expected_XRQN) {
			printf("[%s] XRQN output does not match expected value\n", test.description.c_str());
			errCnt++;
		}

		if (top->XRTN != test.expected_XRTN) {
			printf("[%s] XRTN output does not match expected value\n", test.description.c_str());
			errCnt++;
		}

		if (top->XRUN != test.expected_XRUN) {
			printf("[%s] XRUN output does not match expected value\n", test.description.c_str());
			errCnt++;
		}

		if (top->XRWN != test.expected_XRWN) {
			printf("[%s] XRWN output does not match expected value\n", test.description.c_str());
			errCnt++;
		}

		if (top->XSCN != test.expected_XSCN) {
			printf("[%s] XSCN output does not match expected value\n", test.description.c_str());
			errCnt++;
		}

		if (top->XSHN != test.expected_XSHN) {
			printf("[%s] XSHN output does not match expected value\n", test.description.c_str());
			errCnt++;
		}

		if (top->XSSN != test.expected_XSSN) {
			printf("[%s] XSSN output does not match expected value\n", test.description.c_str());
			errCnt++;
		}

		if (top->XSTP != test.expected_XSTP) {
			printf("[%s] XSTP output does not match expected value\n", test.description.c_str());
			errCnt++;
		}

		if (top->XSWN != test.expected_XSWN) {
			printf("[%s] XSWN output does not match expected value\n", test.description.c_str());
			errCnt++;
		}

		if (top->XTE0 != test.expected_XTE0) {
			printf("[%s] XTE0 output does not match expected value\n", test.description.c_str());
			errCnt++;
		}

		if (top->XTOT != test.expected_XTOT) {
			printf("[%s] XTOT output does not match expected value\n", test.description.c_str());
			errCnt++;
		}

		if (top->XTRN != test.expected_XTRN) {
			printf("[%s] XTRN output does not match expected value\n", test.description.c_str());
			errCnt++;
		}

		if (top->XVAL != test.expected_XVAL) {
			printf("[%s] XVAL output does not match expected value\n", test.description.c_str());
			errCnt++;
		}

		if (top->XWHN != test.expected_XWHN) {
			printf("[%s] XWHN output does not match expected value\n", test.description.c_str());
			errCnt++;
		}

		if (top->XWRI != test.expected_XWRI) {
			printf("[%s] XWRI output does not match expected value\n", test.description.c_str());
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




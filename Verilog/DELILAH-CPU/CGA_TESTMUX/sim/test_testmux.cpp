#define DO_TRACE
#include <iostream>
#include <vector>
#include <random>
#include <ctime>
#include <string>

#include "VCGA_TESTMUX.h"
#include "verilated.h"

#ifdef DO_TRACE
#include <verilated_vcd_c.h>
#endif

// TESTMUX testcases 
struct TestCase {

    uint8_t TSEL_2_0; // Select between the 8 input signals
    bool PTSTN; // Must be set to 1 to enable selection from TSEL (else 0 in the selection bits on the MUX81) Also impacts TM0-D0 (Output TM0, Signal 0: Locked to 0 when PTSTN is 1, follows PTREEOUT when PTSTN is 0)  
    
    uint8_t SC_6_3;   // Connects to signal 6 on TM0-TM4 (see below)
    uint8_t TVEC_3_0; // Connects to signal 7 on TM0-TM4 (see below)
    


    // TM0
    bool PTREEOUT;
    bool VACCN;
    bool MI;
    bool OVF;
    bool UPN;
    bool LCZN;
    //bool tm0_signal_6 = BOUND to SC_3
    //bool tm0_signal_7 = BOUND to TVEC_0;
    
    // TM1
    bool CSMREQ;
    bool INDN;
    bool PTM;
    bool ZF;
    bool COND;
    bool DZD;
    //bool tm1_signal_6 = BOUND to SC_4
    //bool tm1_signal_7 = BOUND to TVEC_1;

    // TM2
    bool LDIRV;
    bool CBRKN;
    bool WPN;
    bool F15;
    bool PN;
    bool OOD;
    //bool tm2_signal_6 = BOUND to SC_5
    //bool tm2_signal_7 = BOUND to TVEC_2;

    
    // TM3
    bool VEX;
    bool WRITEN;
    bool XFETCHN;
    bool SGR;
    bool TN;
    bool CFETCH;
    //bool tm3_signal_6 = BOUND to SC_4
    //bool tm3_signal_7 = BOUND to TVEC_3;

    // TM4
    //bool tm4_signal_0 = BOUND to 1
    bool DSTOPN;
    //bool tm4_signal_2 = BOUND to 1
    bool CRY;
    //bool tm4_signal_4 = BOUND to 1
    bool RESTR;
    bool DEEP;
    //bool tm4_signal_7 = BOUND to 0 (GND)



    /*----------------  EXPECTED OUTOUT ----------------------*/
    
    uint8_t expected_TEST_4_0; // Test the output of the MUX81

    /*--------------------------------------------*/

    std::string description; // Description of the test case
};


#define MAX_SIM_TIME 20
vluint64_t sim_time = 0;
vluint64_t time_step = 5;


int main(int argc, char **argv) 
{


    // Create a collection of test cases
    
    std::vector<TestCase> testCases = {

    /** INPUT SELECTION **  ************************** INPUT SIGNALS ************************************************************************************************************************************************/
    // TSEL_2_0     PTSTN   SC_6_3  TVEC_3_0  PTREEOUT  VACCN   MI       OVF  UPN  LCZN  CSMREQ  INDN  PTM  ZF  COND  DZD  LDIRV  CBRKN  WPN  F15  PN  OOD  VEX  WRITEN  XFETCHN  SGR  TN  CFETCH  DSTOPN  CRY  RESTR  DEEP  expected_TEST_4_0  Description

    // Test selector 0 with PTSTN false and then true
    {0,             false,  0,      0,          false,  false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, 0b10000, "Test 1"},
    {0,             true,   0,      0,          false,  false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, 0b10001, "Test 2"},

    // Loop through all the selections with 0 on the input signals
    {1,             true,   0,      0,          false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, 0b00000, "Test L0-1"},
    {2,             true,   0,      0,          false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, 0b10000, "Test L0-2"},
    {3,             true,   0,      0,          false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, 0b00000, "Test L0-3"},
	{4,             true,   0,      0,          false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, 0b10000, "Test L0-4"},
	{5,             true,   0,      0,          false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, 0b00000, "Test L0-5"},
	{6,             true,   0,      0,          false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, 0b00000, "Test L0-6"},
	{7,             true,   0,      0,          false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, 0b00000, "Test L0-7"},


    // Loop through all the selections with 1 on the TM0 input "PTREEOUT"
    {0,             true,   0,      0,          true, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, 0b10001, "Test L1-0"},
    {1,             true,   0,      0,          true, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, 0b00000, "Test L1-1"},
    {2,             true,   0,      0,          true, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, 0b10000, "Test L1-2"},
    {3,             true,   0,      0,          true, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, 0b00000, "Test L1-3"},
	{4,             true,   0,      0,          true, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, 0b10000, "Test L1-4"},
	{5,             true,   0,      0,          true, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, 0b00000, "Test L1-5"},
	{6,             true,   0,      0,          true, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, 0b00000, "Test L1-6"},
	{7,             true,   0,      0,          true, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, 0b00000, "Test L1-7"},

    // Loop through all the selections with 1 on the TM0 input "VACCN"
    {0,             true,   0,      0,          false,  true, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, 0b10001, "Test L2-0"},
    {1,             true,   0,      0,          false,  true, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, 0b00001, "Test L2-1"},
    {2,             true,   0,      0,          false,  true, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, 0b10000, "Test L2-2"},
    {3,             true,   0,      0,          false,  true, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, 0b00000, "Test L2-3"},
	{4,             true,   0,      0,          false,  true, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, 0b10000, "Test L2-4"},
	{5,             true,   0,      0,          false,  true, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, 0b00000, "Test L2-5"},
	{6,             true,   0,      0,          false,  true, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, 0b00000, "Test L2-6"},
	{7,             true,   0,      0,          false,  true, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, 0b00000, "Test L2-7"},



};


    Verilated::commandArgs(argc, argv);
    VCGA_TESTMUX* top = new VCGA_TESTMUX;

#ifdef DO_TRACE
    VerilatedVcdC *m_trace = new VerilatedVcdC;    
    Verilated::traceEverOn(true);
    top->trace(m_trace, 1); // 1 is the trace depth
    m_trace->open("waveform.vcd");
#endif
    


    int errCnt = 0;

        // Iterate through each test case
    for (const auto& test : testCases) {
        std::cout << "Running " << test.description << std::endl;

/*
        // Set up your module inputs based on the test case
        top->RB_15_0 = test.RB_15_0;
        top->NLCA_15_0 = test.NLCA_15_0;

        top->LAA_3_0 = test.LAA_3_0;
        top->LBA_3_0 = test.LBA_3_0;

        top->BDEST = test.BDEST;
        top->XFETCHN = test.XFETCHN;
*/
        // Set input SELECTION

        top->TSEL_2_0 = test.TSEL_2_0;
        top->TVEC_3_0 = test.TVEC_3_0;
        top->SC_6_3 = test.SC_6_3;
        top->PTSTN = test.PTSTN;

        top->eval();

#ifdef DO_TRACE        
        m_trace->dump(sim_time);
        sim_time += time_step; // Increment simulation time
#endif

        // Set the input SIGNALS
        top->TSEL_2_0 = test.TSEL_2_0;
        top->PTSTN = test.PTSTN;
        top->SC_6_3 = test.SC_6_3;
        top->TVEC_3_0 = test.TVEC_3_0;

        // TM0
        top->PTREEOUT = test.PTREEOUT;
        top->VACCN = test.VACCN;
        top->MI = test.MI;
        top->OVF = test.OVF;
        top->UPN = test.UPN;
        top->LCZN = test.LCZN;

        // TM1
        top->CSMREQ = test.CSMREQ;
        top->INDN = test.INDN;
        top->PTM = test.PTM;
        top->ZF = test.ZF;
        top->COND = test.COND;
        top->DZD = test.DZD;

        // TM2
        top->LDIRV = test.LDIRV;
        top->CBRKN = test.CBRKN;
        top->WPN = test.WPN;
        top->F15 = test.F15;
        top->PN = test.PN;
        top->OOD = test.OOD;

        // TM3
        top->VEX = test.VEX;
        top->WRITEN = test.WRITEN;
        top->XFETCHN = test.XFETCHN;
        top->SGR = test.SGR;
        top->TN = test.TN;
        top->CFETCH = test.CFETCH;

        // TM4
        top->DSTOPN = test.DSTOPN;
        top->CRY = test.CRY;
        top->RESTR = test.RESTR;
        top->DEEP = test.DEEP;

        // Expected Output
        


        top->eval();

#ifdef DO_TRACE        
        m_trace->dump(sim_time);
        sim_time += time_step; // Increment simulation time
#endif

        // Check the output against the expected values
        if (top->TEST_4_0 != test.expected_TEST_4_0)
        {
            printf("[%s] A output [A_15]: 0x%04x does not match expected 0x%04x\n", test.description.c_str(), top->TEST_4_0, test.expected_TEST_4_0);
            errCnt++;
        }

        //if (errCnt>0) break; // exit for loop
    }


    if (errCnt ==0)
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




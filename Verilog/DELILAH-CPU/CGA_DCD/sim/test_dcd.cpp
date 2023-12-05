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
    bool MCLK;
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


int main(int argc, char **argv) 
{

// Create a collection of test cases

std::vector<TestCase> testCases = {
    // CSCOMM_4_0  CSMIS_1_0  MCLK  ILCSN  F15  ZF  CRY  SGR  WPN  PONI  VEX  BRKN  FIDBO5  MRN  LSHADOW  INTRQN  CSIDBS_4_0  expected_INDN  expected_XFETCHN  ...  expected_ERFN  Description
#ifdef _feil_    
    {0, 0, false, false, false, false, false, false, false, false, false, false, false, false, false, false, 0, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, "Test 1"},
    {0, 0, false, false, false, false, false, false, false, false, false, false, false, false, false, false, 0, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, "Test 2"},
    {0, 0, false, false, false, false, false, false, false, false, false, false, false, false, false, false, 0, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, "Test 3"},
    {0, 0, false, false, false, false, false, false, false, false, false, false, false, false, false, false, 0, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, "Test 4"},
    {0, 0, false, false, false, false, false, false, false, false, false, false, false, false, false, false, 0, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, "Test 5"},
    // Add more test cases as needed
#endif    
};


    

    Verilated::commandArgs(argc, argv);
    VCGA_DCD* top = new VCGA_DCD;

#ifdef DO_TRACE
    VerilatedVcdC *m_trace = new VerilatedVcdC;    
    Verilated::traceEverOn(true);
    top->trace(m_trace, 1); // 1 is the trace depth
    m_trace->open("waveform.vcd");
#endif
    


    int errCnt = 0;
    int cnt = 0;
        // Iterate through each test case
    //for (const auto& test : testCases) {    
    //    cnt++;

    for(int cnt=0;cnt<32;cnt++)
    {
            for(int csidbs=0;csidbs<32;csidbs++)
        {

            for(int csmis=0;csmis<4;csmis++)
        {

        //std::cout << "Running " << test.description << std::endl;


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

        top->MCLK = 0;
        top->CSCOMM_4_0 = cnt;
        top->CSIDBS_4_0 = csidbs;
        top->CSMIS_1_0 = csmis;
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
        if (top->TEST_4_0 != test.expected_TEST_4_0)
        {
            printf("[%s] A output [A_15]: 0x%04x does not match expected 0x%04x\n", test.description.c_str(), top->TEST_4_0, test.expected_TEST_4_0);
            errCnt++;
        }
#endif
        }
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




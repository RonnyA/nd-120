#define DO_TRACE
#include <iostream>
#include <vector>
#include <random>
#include <ctime>
#include <string>

#include "VCGA_IDBCTL.h"
#include "verilated.h"

#ifdef DO_TRACE
#include <verilated_vcd_c.h>
#endif

// IDBCTL testcases 
struct TestCase {
    //bool MCLK;
    uint16_t LA_21_10;
    uint16_t PCR_15_0;
    uint16_t XFIDBI_15_0;
    uint16_t PICMASK_15_0;
    uint8_t PICV_2_0;
    uint8_t PICS_2_0;
    
    bool VACCN;    
    bool PVIOL;
    bool EPGSN;
    bool EPCRN;
    bool EPICSN;
    bool EPICVN;
    bool EPICMASKN;
    bool PD;
    bool HIGSN;
    bool LOGSN;

    /*----------------  EXPECTED OUTOUT ----------------------*/

    uint16_t expected_FIDBI_15_0; // FIDB Input to next stage
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
  // LA_21_10   PCR_15_0   XFIDBI_15_0  PICMASK_15_0  PICV_2_0  PICS_2_0  VACCN  PVIOL  EPGSN  EPCRN  EPICSN  EPICVN  EPICMASKN  PD     HIGSN  LOGSN  expected_FIDBI_15_0  Description
    {0,         0,         0,           0,            0,        0,        false, false, true,  true,  true,   true,   true,      false, true,  true,  0,                   "Test 1"},
    {0,         0,         0,           0,            0,        0,        false, false, true,  true,  true,   true,   true,      false, true,  true,  0,                   "Test 2"},
    {0,         0,         0,           0,            0,        0,        false, false, true,  true,  true,   true,   true,      false, true,  true,  0,                   "Test 3"},
    {0,         0,         0,           0,            0,        0,        false, false, true,  true,  true,   true,   true,      false, true,  true,  0,                   "Test 4"}
};




    

    Verilated::commandArgs(argc, argv);
    VCGA_IDBCTL* top = new VCGA_IDBCTL;

#ifdef DO_TRACE
    VerilatedVcdC *m_trace = new VerilatedVcdC;    
    Verilated::traceEverOn(true);
    top->trace(m_trace, 1); // 1 is the trace depth
    m_trace->open("waveform.vcd");
#endif
    


    int errCnt = 0;
        // Iterate through each test case
    for (const auto& test : testCases) 
    {    
        printf("Running %s\r\n", test.description.c_str());
        
        // Set up your module inputs based on the test case
        top->LA_21_10 = test.LA_21_10;
        top->PCR_15_0 = test.PCR_15_0;
        top->XFIDBI_15_0 = test.XFIDBI_15_0;
        top->PICMASK_15_0 = test.PICMASK_15_0;
        top->PICV_2_0 = test.PICV_2_0;
        top->PICS_2_0 = test.PICS_2_0;
        top->VACCN = test.VACCN;
        top->PVIOL = test.PVIOL;
        top->EPGSN = test.EPGSN;
        top->EPCRN = test.EPCRN;
        top->EPICSN = test.EPICSN;
        top->EPICVN = test.EPICVN;
        top->EPICMASKN = test.EPICMASKN;
        top->PD = test.PD;
        top->HIGSN = test.HIGSN;
        top->LOGSN = test.LOGSN;



        // Tick MCLK
        top->MCLK = 0;
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
        if (top->expected_FIDBI_15_0 != test.expected_FIDBI_15_0)
        {
            printf("[%s] A output [A_15]: 0x%04x does not match expected 0x%04x\n", test.description.c_str(), top->expected_FIDBI_15_0, test.expected_FIDBI_15_0);
            errCnt++;
        }
#endif
        
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




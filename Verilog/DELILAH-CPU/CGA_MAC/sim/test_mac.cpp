#define DO_TRACE
#include <iostream>
#include <vector>
#include <random>
#include <ctime>
#include <string>

#include "VCGA_MAC.h"
#include "verilated.h"

#ifdef DO_TRACE
#include <verilated_vcd_c.h>
#endif

// MAC testcases
struct TestCase {
    bool PTM;         // 
    uint16_t FIDBO_15_0; // FIDBO output from previous stage
    bool PONI;          // Memory Protection ON, PONI=1
    uint8_t CSMIS_1_0;  // CSMIS[1:0] = 0b00
    uint8_t CSCOM_4_0;  // CSCOM[4:0] = 0b00000 COMMANDS
    bool WR3;
    bool WR7;
    bool ILCSN; // Instruction Load Control Signal ?
    bool DOUBLE;
    bool CSMREQ;

    
    uint16_t CD_15_0; // 
    uint16_t RB_15_0; // 
    uint16_t XR_15_0; // X-Register. Register #7 ?
    uint16_t BR_15_0; // B Register. Register #3 ?
    uint16_t PR_15_0; // P Register. Register #2 ?


    /*--------------------------------------------*/
    bool expected_VEX;
    uint16_t expected_PCR_15_7_2_0;
    uint16_t expected_LA_23_10;
    bool expected_SHADOW;
    bool expected_ECCR;
    uint16_t expected_MCA_9_0;
    uint16_t expected_NLCA_15_0;

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
        // PTM  FIDBO  PONI  CSMIS CSCOM WR3  WR7  ILCSN DOUBLE CSMREQ CD    RB    XR    BR    PR    VEX   PCR   LA    SHADOW ECCR  MCA   NLCA  Description
        {false, 0,    false, 0,    0,    false,false,false,false,false,0,    0,    0,    0,    0,    false,0,    0,    false, false,0,    0,    "Test 1"},
        {false, 0,    false, 0,    0,    false,false,false,false,false,0,    0,    0,    0,    0,    false,0,    0,    false, false,0,    0,    "Test 2"},
        {false, 0,    false, 0,    0,    false,false,false,false,false,0,    0,    0,    0,    0,    false,0,    0,    false, false,0,    0,    "Test 3"},
        {false, 0,    false, 0,    0,    false,false,false,false,false,0,    0,    0,    0,    0,    false,0,    0,    false, false,0,    0,    "Test 4"},
        {false, 0,    false, 0,    0,    false,false,false,false,false,0,    0,    0,    0,    0,    false,0,    0,    false, false,0,    0,    "Test 5"}
        // Add more test cases here
    };
    


    Verilated::commandArgs(argc, argv);
    VCGA_MAC* top = new VCGA_MAC;

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
        // Toggle the clock and run the simulation
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

/*
        // Check the output against the expected values
        if (top->A_15_0 != test.expected_A_15_0 )
        {
            printf("[%s] A output [A_15]: 0x%04x does not match expected 0x%04x\n", test.description.c_str(),  top->A_15_0, test.expected_A_15_0);
            errCnt++;
        }

        if (top->B_15_0 != test.expected_B_15_0 )
        {
            printf("[%s] B output [B_15]: 0x%04x does not match expected 0x%04x\n", test.description.c_str(),  top->B_15_0, test.expected_B_15_0);
            errCnt++;
        }
*/
        if (errCnt>0) break; // exit for loop
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




#define DO_TRACE
#include <iostream>
#include <vector>
#include <random>
#include <ctime>
#include <string>

#include "VCGA_WRF.h"
#include "verilated.h"

#ifdef DO_TRACE
#include <verilated_vcd_c.h>
#endif

// WRF testcases
struct TestCase {
    uint16_t RB_15_0; // The value to be written to Register selected by LAA and LBA
    uint16_t NLCA_15_0; // NLCA_15_0 goes directly to P regster (Register #2). Is used as input to the P register IF "BDEST=0"

    uint8_t LAA_3_0;  // Select which register (0-15) which goes to A output 
    uint8_t LBA_3_0;  // Select which register (0-15) which goes to B output 
    bool BDEST;       // 1=Writes RB_15_0 to selected B register, 0=READ MODE (Can only write to B selector , never A selector)
    bool XFETCHN;     // ONLY FOR P REGISTER (#2): 0=FETCH FROM RB, 1=FETCH FROM NLCA
    
    uint16_t expected_A_15_0; // Expexted output on A output
    uint16_t expected_B_15_0; // Expexted output on B output    

    uint16_t expected_PR_15_0; // P Registeer. Register #2    
    uint16_t expected_RB_15_0; // B register. Register #3    
    uint16_t expected_XR_15_0; // X-Register. Register #7
    std::string description; // Description of the test case
};


#define MAX_SIM_TIME 20
vluint64_t sim_time = 0;
vluint64_t time_step = 5;


int main(int argc, char **argv) 
{

    // Create a collection of test cases
    std::vector<TestCase> testCases = {
    //   RB      NLCA    LAA   LBA  BDEST XFETCHN =>  A src  B src   P reg   R reg  X reg          
        {0x0000, 0x1234, 0x00, 0x01, 0,    1,        0x0000, 0x0000, 0x0000, 0x0000,0x0000, "1. No output expected"}, 
        {0x1234, 0x0000, 0x00, 0x01, 1,    0,        0x0000, 0x1234, 0x0000, 0x0000,0x0000, "2. Write 0x1234 into register 1, output B=0x1234"},
        {0xDEAD, 0xBEAF, 0x01, 0x02, 0,    1,        0x1234, 0x0000, 0x0000, 0x0000,0x0000, "3. Read Register #1 and Register #2 (P)"},
        {0xDEAD, 0xBEAF, 0x02, 0x02, 1,    1,        0xDEAD, 0xDEAD, 0xDEAD, 0x0000,0x0000, "4. Write 0xDEAD into register2 (P), output B=0xDEAD and P=0xDEAD"},
        // Add more test cases here
    };



    Verilated::commandArgs(argc, argv);
    VCGA_WRF* top = new VCGA_WRF;

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

        // Set up your module inputs based on the test case
        top->RB_15_0 = test.RB_15_0;
        top->NLCA_15_0 = test.NLCA_15_0;

        top->LAA_3_0 = test.LAA_3_0;
        top->LBA_3_0 = test.LBA_3_0;

        top->BDEST = test.BDEST;
        top->XFETCHN = test.XFETCHN;

        // Toggle the clock and run the simulation
        top->ALUCLK = 0;
        top->eval();

#ifdef DO_TRACE        
        m_trace->dump(sim_time);
        sim_time += time_step; // Increment simulation time
#endif

        top->ALUCLK = 1;
        top->eval();

#ifdef DO_TRACE        
        m_trace->dump(sim_time);
        sim_time += time_step; // Increment simulation time
#endif

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




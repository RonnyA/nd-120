#define DO_TRACE
#include <iostream>
#include <vector>
#include <random>
#include <ctime>
#include <string>

#include "VPAL_44601B.h"
#include "verilated.h"

#ifdef DO_TRACE
#include <verilated_vcd_c.h>
#endif

// PAL testcases
struct TestCase {
    

    // Inputs

    //bool CK;       // Clock signal
    //bool OE_n;     // OUTPUT ENABLE (active-low) for Q0-Q5

    bool DLY1_n;       // I0 - DLY1_n
    bool DLY0_n;       // I1 - DLY0_n
    bool CSDELAY0;     // I2 - CSDELAY0 
    bool WAIT1;        // I3 - WAIT1 
    bool WAIT2;        // I4 - WAIT2 
    bool CGNTCACT_n;   // I5 - CGNTCACT_n
    bool HIT;          // I6 - HIT
    bool BRK_n;        // I7 - BRK_n                       

    bool SLOW_n;       // B0_n - SLOW_n 
    bool SHORT_n;      // B1_n - SHORT_n 
     
    // Outputs 

    bool CX_n;        // Q0_n - CX_n
    bool TERM_n;      // Q1_n - TERM_n
    bool CC0_n;       // Q2_n - BANK0
    bool CC1_n;       // Q3_n - MWRITE_n
    bool CC2_n;       // Q4_n - MWRITE_n
    bool CC3_n;       // Q5_n - MWRITE_n

    std::string description; // Description of the test case
};


#define MAX_SIM_TIME 20
vluint64_t sim_time = 0;
vluint64_t time_step = 5;


int main(int argc, char **argv) 
{

    // Create a collection of test cases
    std::vector<TestCase> testCases = {
    };



    Verilated::commandArgs(argc, argv);
    VPAL_44601B* top = new VPAL_44601B;

#ifdef DO_TRACE
    VerilatedVcdC *m_trace = new VerilatedVcdC;    
    Verilated::traceEverOn(true);
    top->trace(m_trace, 1); // 1 is the trace depth
    m_trace->open("waveform.vcd");
#endif
    


    int errCnt = 0;

    top->OE_n  = false;        
    top->CK = 0;

    top->CGNTCACT_n = true;
    top->BRK_n = true;
    top->CGNTCACT_n = true;

    // Iterate through each test case
    //for (const auto& test : testCases) {
    for (int i=0;i<64;i++)
    {

        //std::cout << "Running " << test.description << std::endl;
        top->CK = !top->CK;

        // Assignments for input fields        
        top->SHORT_n = (i & 1<<3) ==0;
        top->CSDELAY0 = (i & 1<<2) !=0;
        top->DLY1_n = (i & 1<<1) ==0;
        top->DLY0_n = (i & 1<<0) ==0;


        if (i==10)
            top->BRK_n = false;

        if (i==16)
            top->CSDELAY0 = true;

        top->eval();

#ifdef DO_TRACE        
        m_trace->dump(sim_time);
        sim_time += time_step; // Increment simulation time
#endif        


        // /OE (Output enable)
        //top->OE_n  = true;
        top->CK = !top->CK;
        top->eval();
        

#ifdef DO_TRACE        
        m_trace->dump(sim_time);
        sim_time += time_step; // Increment simulation time
#endif


#if __later__
// Conditional checks for output fields
if (top->EMD_n != test.EMD_n) {
    printf("[%s] EMD_n output does not match expected value\n", test.description.c_str());
    errCnt++;
}

if (top->DSTB_n != test.DSTB_n) {
    printf("[%s] DSTB_n output does not match expected value\n", test.description.c_str());
    errCnt++;
}

if (top->BGNTCACT_n != test.BGNTCACT_n) {
    printf("[%s] BGNTCACT_n output does not match expected value\n", test.description.c_str());
    errCnt++;
}

if (top->CGNTCACT_n != test.CGNTCACT_n) {
    printf("[%s] CGNTCACT_n output does not match expected value\n", test.description.c_str());
    errCnt++;
}




        // if (errCnt>0) break; // exit for loop
#endif        
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




#define DO_TRACE
#include <iostream>
#include <vector>
#include <random>
#include <ctime>
#include <string>

#include "VCPU_MMU_HIT_27.h"
#include "verilated.h"

#ifdef DO_TRACE
#include <verilated_vcd_c.h>
#endif

// PAL testcases
struct TestCase {
    

    // Inputs
    uint16_t PPN_23_10;
    uint16_t CPN_23_10;    
    bool LSHADOW;
    bool CON_n;
    bool FMISS;

    // Outputs
    
    bool HIT0_n;
    bool HIT1_n;

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
    VCPU_MMU_HIT_27* top = new VCPU_MMU_HIT_27;

    
// Set default values

   top->PPN_23_10 = 0;
   top->CPN_23_10 = 0;
   top->LSHADOW = false;
   top->CON_n = true; // disable output of HIT0_n
   top->FMISS = true; // disable output of HIT1_n

#ifdef DO_TRACE
    VerilatedVcdC *m_trace = new VerilatedVcdC;    
    Verilated::traceEverOn(true);
    top->trace(m_trace, 1); // 1 is the trace depth
    m_trace->open("waveform.vcd");
#endif
    


    int errCnt = 0;

   // Default Assignments for input fields


    // Iterate through each test case
    //for (const auto& test : testCases) {
    //    std::cout << "Running " << test.description << std::endl;

    //top->STOC_n = false;
    for (int i=0; i<10; i++)
    {                          

        if (i==1)
            top->CPN_23_10=0xF0; // Set CPN_23_10

        if (i==2)
        {
            top->CON_n = false; // enable output of HIT0_n
            top->FMISS = false; // enable output of HIT1_n
        }


        if (i==4)
            top->PPN_23_10=0xF0; // Set CPN_23_10


        if (i==6)
            top->LSHADOW = true; // Set LSHADOW to true


        if (i==8)
            top->CON_n = true; // disable output of HIT0_n

        if (i==9)
            top->FMISS = true; // disable output of HIT1_n


        top->eval();

#ifdef DO_TRACE        
        m_trace->dump(sim_time);
        sim_time += time_step; // Increment simulation time
#endif


        // Fix clock!!
      


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



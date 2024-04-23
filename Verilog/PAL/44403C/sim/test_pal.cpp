// 44401B,5D,BTIM

#define DO_TRACE
#include <iostream>
#include <vector>
#include <random>
#include <ctime>
#include <string>

#include "VPAL_44403C.h"
#include "verilated.h"

#ifdef DO_TRACE
#include <verilated_vcd_c.h>
#endif

// PAL testcases
struct TestCase {
    
    // Inputs
    bool  CLK, CSDELAY0, CSDLY, CSECOND, CSLOOP, ACOND_n, MR_n, LUA12, MAP_n, OE_n;
    
    //  Outputs    
    bool SLCOND_n, DMAP_n, DMA12_n, MDLY_n, LCS_n, DLY0_n;

    std::string description; // Description of the test case
};


// note:
//   OSC is CK to flip-flop
//   OE_n is OUTPUT enable to Q0-Q3 pins on PAL.

#define MAX_SIM_TIME 20
vluint64_t sim_time = 0;
vluint64_t time_step = 5;


int main(int argc, char **argv) 
{

    // Create a collection of test cases
    std::vector<TestCase> testCases = {
    };

    Verilated::commandArgs(argc, argv);
    VPAL_44403C* top = new VPAL_44403C;

#ifdef DO_TRACE
    VerilatedVcdC *m_trace = new VerilatedVcdC;    
    Verilated::traceEverOn(true);
    top->trace(m_trace, 1); // 1 is the trace depth
    m_trace->open("waveform.vcd");
#endif
    


    int errCnt = 0;

    top->MR_n = true;
    top->OE_n  = false;
    //top->DMA12_n = true; // output
    top->LUA12 = false;

    // Iterate through each test case
    //for (const auto& test : testCases) {
    for (int i=0;i<32;i++)
    {


        //std::cout << "Running " << test.description << std::endl;

               
        // Assignments for input fields        
        top->CLK = 1;

        
        if (i==3)
            top->MR_n = false;

        if (i==5)
            top->MR_n = true;

        if (i==7)
        {
            
            top->LUA12 = true;
        }

        if (i==9)
        {
            
            top->LUA12 = false;
        }


        top->eval();

        //top->CACT_n = false;
        //top->CACT25_n = true;

/*
        top->CC0_n = (i & 1<<0) == 0;
        top->CC1_n = (i & 1<<1) == 0;
        top->CC2_n= (i & 1<<2) == 0;
        top->CC3_n = (i & 1<3) == 0;
*/

#ifdef DO_TRACE        
        m_trace->dump(sim_time);
        sim_time += time_step; // Increment simulation time
#endif        

        // /OE (Output enable)
        //top->OE_n  = true;



        top->CLK = 0;        

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




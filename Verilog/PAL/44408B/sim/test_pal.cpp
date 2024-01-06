#define DO_TRACE
#include <iostream>
#include <vector>
#include <random>
#include <ctime>
#include <string>

#include "VPAL_44408B.h"
#include "verilated.h"

#ifdef DO_TRACE
#include <verilated_vcd_c.h>
#endif

// PAL testcases
struct TestCase {
    
    // Test field
    bool TEST;

    // Inputs
    bool Q0_n, Q2_n, CC2_n, BDRY25_n, BDRY50_n, CGNT_n, CGNT50_n, CACT_n, TERM_n, BGNT_n, RT_n, IORQ_n;
    
    
    //  Outputs

    bool EMD_n, DSTB_n, BGNTCACT_n, CGNTCACT_n;
    

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
    VPAL_44408B* top = new VPAL_44408B;

#ifdef DO_TRACE
    VerilatedVcdC *m_trace = new VerilatedVcdC;    
    Verilated::traceEverOn(true);
    top->trace(m_trace, 1); // 1 is the trace depth
    m_trace->open("waveform.vcd");
#endif
    


    int errCnt = 0;

    top->CLK = 0;

    // Iterate through each test case
    //for (const auto& test : testCases) {
    for (int i=0;i<32;i++)
    {
        for (int j=0;j<4;j++)
        {
            for (int clk=0;clk<2;clk++)
            {

        //std::cout << "Running " << test.description << std::endl;

        // /OE (Output enable)
        top->OE_n  = false;        
        // Assignments for input fields
        
        top->LCS_n = !top->CLK;
        //top->LCS_n =(j & 1<<0) !=0;       

        top->C4 = (i & 1<<4) !=0;
        top->C3 = (i & 1<<3) !=0;
        top->C2 = (i & 1<<2) !=0;
        top->C1 = (i & 1<<1) !=0;
        top->C0 = (i & 1<<0) !=0;

        top-> M1 = (j & 1<<1) !=0;
        top-> M0 = (j & 1<<0) !=0;    

        top->eval();

#ifdef DO_TRACE        
        m_trace->dump(sim_time);
        sim_time += time_step; // Increment simulation time
#endif        


        // /OE (Output enable)
        //top->OE_n  = true;
        top->CLK = !top->CLK;
        top->eval();
        

#ifdef DO_TRACE        
        m_trace->dump(sim_time);
        sim_time += time_step; // Increment simulation time
#endif
            }
        }


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




#define DO_TRACE
#include <iostream>
#include <vector>
#include <random>
#include <ctime>
#include <string>

#include "VPAL_44407A.h"
#include "verilated.h"

#ifdef DO_TRACE
#include <verilated_vcd_c.h>
#endif

// PAL testcases
struct TestCase {
    

    // Inputs

    //bool CK;       // Clock signal
    //bool OE_n;     // OUTPUT ENABLE (active-low) for Q0-Q3

    bool IDBS0;      // I0 - CSIDBS0
    bool IDBS1;      // I1 - CSIDBS1
    bool IDBS2;      // I2 - CSIDBS2 
    bool IDBS3;      // I3 - CSIDBS3
    bool IDBS4;      // I4 - CSIDBS4 
    bool WRTRF;      // I5 - WRTRF
    bool LCS_n;      // I6 - LCS_n
                     // I7 - (not connected)
                    
  
    //  Outputs

    bool ERF_n;       // B0_n - ERF_n
                      // B1_n - (not connected)

    bool RRF_n;       // Q0_n - RRF_n
                      // Q2_n - (not connected)
                      // Q3_n - (not connected)
                      // Q4_n - (not connected)

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
    VPAL_44407A* top = new VPAL_44407A;

#ifdef DO_TRACE
    VerilatedVcdC *m_trace = new VerilatedVcdC;    
    Verilated::traceEverOn(true);
    top->trace(m_trace, 1); // 1 is the trace depth
    m_trace->open("waveform.vcd");
#endif
    


    int errCnt = 0;

    top->CK = 0;

    top->LCS_n = true;
    top->OE_n  = false;        

    // Iterate through each test case
    //for (const auto& test : testCases) {
    for (int i=0;i<64;i++)
    {

        //std::cout << "Running " << test.description << std::endl;
        top->CK = !top->CK;

        // Assignments for input fields
        top->IDBS4 = (i & 1<<4) !=0;
        top->IDBS3 = (i & 1<<3) !=0;
        top->IDBS2 = (i & 1<<2) !=0;
        top->IDBS1 = (i & 1<<1) !=0;
        top->IDBS0 = (i & 1<<0) !=0;

        if ((i==9)|(i==32+9))
            top->WRTRF = true;

        if (i==32)
        {
            top->WRTRF = false;
            top->LCS_n = false;
        }

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




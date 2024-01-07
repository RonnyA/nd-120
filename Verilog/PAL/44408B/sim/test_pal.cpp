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
    

    // Inputs

    //bool CK;       // Clock signal
    //bool OE_n;     // OUTPUT ENABLE (active-low) for Q0-Q3

    bool C4;       // I0 - CSCOMM4
    bool C3;       // I1 - CSCOMM3
    bool C2;       // I2 - CSCOMM2 
    bool C1;       // I3 - CSCOMM1 
    bool C0;       // I4 - CSCOMM0 
    bool M1;       // I5 - CSMIS1
    bool M0;       // I6 - CSMIS0  
                   // I7 - (not connected)
    bool LCS_n;    
                   // B0_n - (not connected)
    bool IDB2;     // B1_n - IDB2


    //  Outputs

    // These signals may have wrong Q pin description, as this is taken from the description of the PAL 444608 (VXFIX) which is a PAL16R6
    // (Missing information on how 44408 was connected..)

                    // Q0_n - (not connected)
    bool LDEXM_n;   // Q1_n 
    bool VEX;       // Q2_n
    bool OPCLCS;    // Q3_n
    bool RWCS_n ;   // Q4_n     

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

    top->CK = 0;

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
        
        top->LCS_n = !top->CK;
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
        top->CK = !top->CK;
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




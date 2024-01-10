#define DO_TRACE
#include <iostream>
#include <vector>
#include <random>
#include <ctime>
#include <string>

#include "VPAL_44904B.h"
#include "verilated.h"

#ifdef DO_TRACE
#include <verilated_vcd_c.h>
#endif

// PAL testcases
struct TestCase {
    

    // Inputs

    //bool CK;       // Clock signal
    //bool OE_n;     // OUTPUT ENABLE (active-low) for Q0-Q5


    bool MSIZE0_n;       // I0 - MSIZE0_n
    bool MSIZE1_n;       // I1 - MSIZE1_n
    bool MOFF_n;          // I2 - MOFF_n
    //bool i3,            // I3 - (n.c.)
    //bool i4,            // I4 - (n.c.)
    //bool i5,            // I5 - (n.c.)
    //bool i6,            // I6 - (n.c.)
    //bool i7,            // I7 - (n.c.)
    
    bool ABIT;            // Q0_n - ABIT
    bool BBIT;            // Q1_n - BBIT
    bool CBIT;            // Q2_n - CBIT
    bool DBIT;            // Q3_n - DBIT
    //output Q4_n,        // Q4_n - (n.c.)
    bool ELOW_n;          // Q5_n - ELOWSG_n
    bool EMID_n;          // Q6_n - EMIDSEG_n
    bool EHI_n;           // Q7_n - EHISEG_n

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
    VPAL_44904B* top = new VPAL_44904B;

#ifdef DO_TRACE
    VerilatedVcdC *m_trace = new VerilatedVcdC;    
    Verilated::traceEverOn(true);
    top->trace(m_trace, 1); // 1 is the trace depth
    m_trace->open("waveform.vcd");
#endif
    


    int errCnt = 0;

    top->OE_n  = false;        
    top->CK = 0;

    top->MOFF_n = true;

/*
              // Set all inputs to 0
            top->RGNT_n =
            top->BDAP50_n =
            top->MR_n  =
            top->BGNT25_n =
            top->CGNT25_n = 
            top->BDRY50_n = true;

*/
  

    // Iterate through each test case
    //for (const auto& test : testCases) {
    for (int i=0;i<64;i++)
    {

        //std::cout << "Running " << test.description << std::endl;
        top->CK = !top->CK;

        top->MSIZE1_n = (i & 1<<1) ==0;
        top->MSIZE0_n = (i & 1<<0) ==0;

        // MOFF *
        if (i==32)
        {
            top->MOFF_n = false;      
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




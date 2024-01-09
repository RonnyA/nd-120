#define DO_TRACE
#include <iostream>
#include <vector>
#include <random>
#include <ctime>
#include <string>

#include "VPAL_44803A.h"
#include "verilated.h"

#ifdef DO_TRACE
#include <verilated_vcd_c.h>
#endif

// PAL testcases
struct TestCase {
    

    // Inputs

    //bool CK;       // Clock signal
    //bool OE_n;     // OUTPUT ENABLE (active-low) for Q0-Q5


    bool LOEN_n;       // I0 - LOEN_n
    bool RLRQ_n;       // I1 - RLRQ_n
    bool MR_n;         // I2 - MR_n 
    bool CLRQ_n;       // I3 - CLRQ_n 
    bool BLRQ50_n;     // I4 - BLRQ50_n 
    bool SSEMA_n;      // I5 - BDRY25_n
    bool SEMRQ50_n;    // I6 - SEMRQ50_n
//  bool n.c ;         // I7 - n.c.


    // outputs

    bool RGNT_n;      // Q0_n - RGNT_n
    bool CGNT_n;      // Q1_n - CGNT_n
    bool BGNT_n;      // Q2_n - BGNT_n
    bool LOEN25_n;    // Q3_n - LOEN25_n (n.c.)
    bool LDR_n;       // Q4_n - LDR_n (n.c.)
    bool CSEM_n;      // Q5_n - CSEM_n (n.c.)
    bool BSEM_n;      // Q6_n - BSEM_n (n.c.)
    bool BCGNT25;      // Q7_n - BCGNT25

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
    VPAL_44803A* top = new VPAL_44803A;

#ifdef DO_TRACE
    VerilatedVcdC *m_trace = new VerilatedVcdC;    
    Verilated::traceEverOn(true);
    top->trace(m_trace, 1); // 1 is the trace depth
    m_trace->open("waveform.vcd");
#endif
    


    int errCnt = 0;

    top->OE_n  = false;        
    top->CK = 0;


    // Set all inputs to 0
    top->LOEN_n =
    top->RLRQ_n =
    top->MR_n =
    top->CLRQ_n = 
    top->BLRQ50_n = 
    top->SSEMA_n = 
    top->SEMRQ50_n = true;


    // Iterate through each test case
    //for (const auto& test : testCases) {
    for (int i=0;i<64;i++)
    {

        //std::cout << "Running " << test.description << std::endl;
        top->CK = !top->CK;

        // Assignments for input fields        
        /*
        top->SHORT_n = (i & 1<<3) ==0;
        top->CSDELAY0 = (i & 1<<2) !=0;
        top->DLY1_n = (i & 1<<1) ==0;
        top->DLY0_n = (i & 1<<0) ==0;
        */

        // REF
        if (i==3)
        {
            top->MR_n = false;
        }

        if (i==4)
        {
            top->LOEN_n = false;
        }

        if (i==5)
        {
            top->MR_n = true;
        }


        // IO
        if (i==7)
        {
            top->RLRQ_n = false;
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




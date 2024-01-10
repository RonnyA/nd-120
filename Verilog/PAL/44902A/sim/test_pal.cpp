#define DO_TRACE
#include <iostream>
#include <vector>
#include <random>
#include <ctime>
#include <string>

#include "VPAL_44902A.h"
#include "verilated.h"

#ifdef DO_TRACE
#include <verilated_vcd_c.h>
#endif

// PAL testcases
struct TestCase {
    

    // Inputs

    //bool CK;       // Clock signal
    //bool OE_n;     // OUTPUT ENABLE (active-low) for Q0-Q5

    bool RGNT_n;       // I0 - RGNT_n
    //bool CGNT_n;       // I1 - CGNT_n (NOT USED!!)
    //bool BGNT_n;       // I2 - BGNT_n (NOT USED!!)
    bool BDAP50_n;     // I3 - BDAP50_n 
    bool MR_n;         // I4 - MR_n 
    bool BGNT25_n;     // I5 - BGNT25_n
    bool CGNT25_n;     // I6 - CGNT25_n
    bool BDRY50_n;     // I7 - BDRY50_n

    // Outputs

    bool QA_n;        // Q0_n - QA_n (n.c.)
    bool QB_n;        // Q1_n - QB_n (n.c.)
    bool QC_n;        // Q2_n - QC_n (n.c.)
    bool QD_n;        // Q3_n - QD_n
    bool RAS;         // Q4_n - RAS
    bool CAS;         // Q5_n - CAS
    bool LOEN_n;      // Q6_n - LOEN_n
    bool HIEN_n;      // Q7_n - HIEN_n

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
    VPAL_44902A* top = new VPAL_44902A;

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
            top->RGNT_n =
            top->BDAP50_n =
            top->MR_n  =
            top->BGNT25_n =
            top->CGNT25_n = 
            top->BDRY50_n = true;


  

    // Iterate through each test case
    //for (const auto& test : testCases) {
    for (int i=0;i<64;i++)
    {

        //std::cout << "Running " << test.description << std::endl;
        top->CK = !top->CK;

        // Assignments for input fields        
        /*
        top->QD_n = (i & 1<<3) ==0;
        top->QC_n = (i & 1<<2) ==0;
        top->QB_n = (i & 1<<1) ==0;
        top->QA_n = (i & 1<<0) ==0;
        */

        // MR

        if (i==12)
        {
            // Set some interresting input signals
            top->RGNT_n = false;
            top->BDAP50_n = true;
            top->MR_n  = false;
            top->BGNT25_n = false;
            top->CGNT25_n = false;
            top->BDRY50_n = true;
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




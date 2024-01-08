#define DO_TRACE
#include <iostream>
#include <vector>
#include <random>
#include <ctime>
#include <string>

#include "VPAL_44801A.h"
#include "verilated.h"

#ifdef DO_TRACE
#include <verilated_vcd_c.h>
#endif

// PAL testcases
struct TestCase {
    

    // Inputs

    //bool CK;       // Clock signal
    //bool OE_n;     // OUTPUT ENABLE (active-low) for Q0-Q5

    bool CRQ_n;        // I0 - CRQ_n
    bool IORQ_n;       // I1 - IORQ_n
    bool MR_n;         // I2 - MR_n 
    bool BRQ50_n;      // I3 - BRQ50_n 
    bool REFRQ50_n;    // I4 - REFRQ50_n 
    bool BDRY25_n;     // I5 - BDRY25_n
    bool SEMRQ50_n;    // I6 - SEMRQ50_n
    bool MOFF_n;       // I7 - MOFF_n                       

    // Outputs

    bool SEM_n;       // Q0_n - SEM_n
    bool ACT_n;       // Q1_n - ACT_n (n.c.)
    bool DOREF_n;     // Q2_n - DOREF_n (n.c.)
    bool MEM_n;       // Q3_n - MEM_n (n.c.)
    bool REF_n;       // Q4_n - REF_n
    bool IOD_n;       // Q5_n - IOD_n
    bool GNT_n;       // Q6_n - GNT_n 
    bool CACT_n;      // Q7_n - CACT_n

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
    VPAL_44801A* top = new VPAL_44801A;

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
    top->CRQ_n = 
    top->IORQ_n =
    top->MR_n =
    top->BRQ50_n =
    top->REFRQ50_n =
    top->BDRY25_n =
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
            top->REFRQ50_n = false;
        }

        if (i==4)
        {
            top->MR_n = false;
        }

        if (i==5)
        {
            top->MR_n = true;
        }


        // IO
        if (i==7)
        {
            top->IORQ_n = false;
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




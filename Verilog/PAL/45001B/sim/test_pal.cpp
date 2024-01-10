#define DO_TRACE
#include <iostream>
#include <vector>
#include <random>
#include <ctime>
#include <string>

#include "VPAL_45001B.h"
#include "verilated.h"

#ifdef DO_TRACE
#include <verilated_vcd_c.h>
#endif

// PAL testcases
struct TestCase {
    

    // Inputs

    bool BDRY50_n;           // I0 - BDRY50_n
    bool BDRY75_n;           // I1 - BDRY75_n
    bool BLOCK25_n;          // I2 - BLOCK25_n
    bool BPERR50_n;          // I3 - BPERR50_n
    bool DBAPR_n;            // I4 - DBAPR_n
    bool MOR25_n;            // I5 - MOR25_n
    bool LPERR_n;            // I6 - LPERR_n
    bool MR_n;               // I7 - MR_n
    bool EPES_n;             // I8 - EPES_n
    bool EPEA_n;             // I9 - EPEA_n

    bool TEST;              // B4_n - PD3
    bool LERR_n;            // B5_n  


    // Outputs
    bool SPEA;              // Y0_n (OUT Only)
    bool SPES;              // Y1_n (OUT ONLY)
    
    bool BLOCK_n;           // B0_n - BLOCK_n
    bool PARERR_n;          // B1_n - PARERR_n
    bool RERR_n;            // B2_n
    //inout B3_n,             // B3_n - (n.c.)

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
    VPAL_45001B* top = new VPAL_45001B;

#ifdef DO_TRACE
    VerilatedVcdC *m_trace = new VerilatedVcdC;    
    Verilated::traceEverOn(true);
    top->trace(m_trace, 1); // 1 is the trace depth
    m_trace->open("waveform.vcd");
#endif
    


    int errCnt = 0;


    top->BDRY50_n=
    top->BDRY75_n=
    top->BLOCK25_n=
    top->BPERR50_n=
    top->DBAPR_n=
    top->MOR25_n=
    top->LPERR_n=
    top->MR_n=
    top->EPES_n=
    top->EPEA_n=true;    
    top->LERR_n=true;
    top->TEST=false;


    // Iterate through each test case
    //for (const auto& test : testCases) {
    for (int i=0;i<32;i++)
    {

        //std::cout << "Running " << test.description << std::endl;

        // Set inputs (?)
        if ((i & 0x02) == 2) top->MR_n = 1;
            else top->MR_n = 0;

        if (i==1)
            top->BLOCK25_n =false;
            
        if (i==1)
            top->DBAPR_n =false;

        if (i==2)
            top->EPEA_n =false;

        if (i==4)
            top->BDRY50_n =false;

        if (i==7)
            top->BDRY75_n =false;
        if (i==7)
            top->BPERR50_n =false;


        if (i==9)
            top->LERR_n =false;

        if (i==11)
            top->LPERR_n =false;

        if (i==13)
            top->MOR25_n =false;

        top->eval();

#ifdef DO_TRACE        
        m_trace->dump(sim_time);
        sim_time += time_step; // Increment simulation time
#endif        

        

        // Set inputs (?)

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




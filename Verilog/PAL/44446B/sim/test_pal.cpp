#define DO_TRACE
#include <iostream>
#include <vector>
#include <random>
#include <ctime>
#include <string>

#include "VPAL_44446B.h"
#include "verilated.h"

#ifdef DO_TRACE
#include <verilated_vcd_c.h>
#endif

// PAL testcases
struct TestCase {
    

    // Inputs

    //bool CK;        // Clock signal (connected to DBAPR)
    //bool OE_n;      // OUTPUT ENABLE (active-low) for Q0-Q3 (connected to BGNT_n)

    bool DBAPR;        // I0 - DBAPR
    bool MOFF_n;       // I1 - MOFF_n
    bool BINPUT_n;     // I2 - IBINPUT_n 
    bool BMEM_n;       // I3 - BMEM_n
    bool BD20_n;       // I4 - BD20_n 
    bool BD21_n;       // I5 - BD21_n
    bool BD22_n;       // I6 - BD22_n
    bool BD23_n;       // I7 - BD23_n                       


    // Outputs 

    bool AOK;         // B0_n - AOK
    bool DDBAPR_n;    // B1_n - DDBAPR_n 
    bool MSIZE1_n;    // B2_n - MSIZE1_n (not connected?)
//  input  BD19_n;    // B3_n - BD19_n (not in use)

    bool BANK2;       // Q0_n - BANK2
    bool BANK1;       // Q1_n - BANK1
    bool BANK0;       // Q2_n - BANK0
    bool MWRITE_n;    // Q3_n - MWRITE_n



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
    VPAL_44446B* top = new VPAL_44446B;

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
    // Iterate through each test case
    //for (const auto& test : testCases) {
    for (int i=0;i<64;i++)
    {

        //std::cout << "Running " << test.description << std::endl;
        top->CK = !top->CK;
        top->DBAPR = top->CK;

        // Assignments for input fields        
        top->BD23_n = (i & 1<<3) ==0;
        top->BD22_n = (i & 1<<2) ==0;
        top->BD21_n = (i & 1<<1) ==0;
        top->BD20_n = (i & 1<<0) ==0;

        if (i==32)
            top->MOFF_n = false;


        top->eval();

#ifdef DO_TRACE        
        m_trace->dump(sim_time);
        sim_time += time_step; // Increment simulation time
#endif        


        // /OE (Output enable)
        //top->OE_n  = true;
        top->CK = !top->CK;
        top->DBAPR = top->CK;
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




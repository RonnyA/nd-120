// PAL16L8
// CJTC 02SEP86
// 44304E,1C,LBC3 - LOCAL DATA BUS CONTROL PAL


#define DO_TRACE
#include <iostream>
#include <vector>
#include <random>
#include <ctime>
#include <string>

#include "VPAL_44304E.h"
#include "verilated.h"

#ifdef DO_TRACE
#include <verilated_vcd_c.h>
#endif

// PAL testcases
struct TestCase {
    
    // Inputs
    bool CGNT_n, BGNT_n, BGNT50_n, MWRITE_n, BDAP50_n, EBUS_n, IBAPR_n, GNT_n, TEST;

    //  Outputs
    bool EBD_n,  CLKBD, SAPR, FAPR, EBADR_b1, BACT_n, DBAPR;

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
    VPAL_44304E* top = new VPAL_44304E;

#ifdef DO_TRACE
    VerilatedVcdC *m_trace = new VerilatedVcdC;    
    Verilated::traceEverOn(true);
    top->trace(m_trace, 1); // 1 is the trace depth
    m_trace->open("waveform.vcd");
#endif
    


    int errCnt = 0;


    top->GNT_n = true;
    top->BGNT_n = true;
    top->BGNT50_n = true;
    top->MWRITE_n = true;
    top->BDAP50_n = true;
    top->EBUS_n = true;
    top->IBAPR_n = true;
    top->GNT_n = true;
    top->TEST = false;

    // Iterate through each test case
    //for (const auto& test : testCases) {
     //   std::cout << "Running " << test.description << std::endl;
     for (int i=0; i<32; i++) {

        // Assignments for input fields
#if _later_        
        top->TEST = test.TEST;
     
#endif
        if (i==2)
            top->GNT_n = false;

        if (i==3)
            top->BGNT50_n = false;

        if (i==4)
            top->BGNT_n = false;

        if (i==5)
            top->MWRITE_n = false;

        if (i==6)
            top->MWRITE_n = true;

        if (i==9)
            top->BDAP50_n = false;


        if (i==10)
        {
            top->GNT_n = true;
            top->BGNT_n = true;
        }
        
        if (i==9)
            top->IBAPR_n = false;


        top->eval();

#ifdef DO_TRACE        
        m_trace->dump(sim_time);
        sim_time += time_step; // Increment simulation time
#endif


#if __later__
// Conditional checks for output fields
if (top->WBD_n != test.WBD_n) {
    printf("[%s] WBD_n output does not match expected value\n", test.description.c_str());
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




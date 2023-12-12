#define DO_TRACE
#include <iostream>
#include <vector>
#include <random>
#include <ctime>
#include <string>

#include "VPAL_44302B.h"
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
        // TEST   Q0_n   Q2_n   CC2_n   BDRY25_n  BDRY50_n  CGNT_n   CGNT50_n  CACT_n   TERM_n   BGNT_n  RT_n    IORQ_n   EMD_n   DSTB_n   BGNTCACT_n   CGNTCACT_n  Description
        {  true,  true,  true,  true,   true,     true,     true,    true,     true,    true,    true,   true,   true,    true,   true,    true,        true,       "Test 1"},
        {  false, true,  true,  true,   true,     true,     false,   true,     true,    true,    true,   true,   true,    true,   true,    true,        true,       "Test 2"}, // cgnt = 0
        {  false, true,  true,  true,   true,     true,     true,    true,     false,   true,    true,   true,   true,    true,   true,    true,        true,       "Test 3"}, // cact = 0
        {  false, true,  true,  true,   true,     true,     true,    true,     true,    true,    false,  true,   true,    true,   true,    true,        true,       "Test 4"}, // bgnt = 0
        {  false, true,  true,  true,   true,     true,     true,    true,     true,    true,    true,   true,   true,    true,   true,    true,        true,       "Test 5"},
    };





    Verilated::commandArgs(argc, argv);
    VPAL_44302B* top = new VPAL_44302B;

#ifdef DO_TRACE
    VerilatedVcdC *m_trace = new VerilatedVcdC;    
    Verilated::traceEverOn(true);
    top->trace(m_trace, 1); // 1 is the trace depth
    m_trace->open("waveform.vcd");
#endif
    


    int errCnt = 0;

    // Iterate through each test case
    for (const auto& test : testCases) {
        std::cout << "Running " << test.description << std::endl;


        // TEST field is most important
        top->TEST = test.TEST;

        // Assignments for input fields
        top->Q0_n = test.Q0_n;
        top->Q2_n = test.Q2_n;
        top->CC2_n = test.CC2_n;
        top->BDRY25_n = test.BDRY25_n;
        top->BDRY50_n = test.BDRY50_n;
        top->CGNT_n = test.CGNT_n;
        top->CGNT50_n = test.CGNT50_n;
        top->CACT_n = test.CACT_n;
        top->TERM_n = test.TERM_n;
        top->BGNT_n = test.BGNT_n;
        top->RT_n = test.RT_n;
        top->IORQ_n = test.IORQ_n;
        
        
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




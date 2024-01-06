#define DO_TRACE
#include <iostream>
#include <vector>
#include <random>
#include <ctime>
#include <string>

#include "VPAL_44303B.h"
#include "verilated.h"

#ifdef DO_TRACE
#include <verilated_vcd_c.h>
#endif

// PAL testcases
struct TestCase {
    
    // Inputs

    bool TEST;


    bool CACT_n;
    bool CGNT_n;
    bool EADR_n;           // Address from CPU to Bus
    bool BINPUT50_n;
    bool MIS0;
    bool IOD_n;
    bool WRITE;    
    bool BACT_n;
    
    //  Outputs

    bool WBD_n;       // Write Bus Direction
    bool CBWRITE_n;   // CPU Write cycle to Bus
    bool WLBD_n;      // Write Local Bus Direction
    bool CMWRITE_n;    // CPU Write to Local Memory


    std::string description; // Description of the test case
};


#define MAX_SIM_TIME 20
vluint64_t sim_time = 0;
vluint64_t time_step = 5;


int main(int argc, char **argv) 
{

    // Create a collection of test cases
 std::vector<TestCase> testCases = {
    // TEST   CACT_n   CGNT_n   EADR_n   BINPUT50_n  MIS0   IOD_n   WRITE  BACT_n  WBD_n  CBWRITE_n  WLBD_n  CMWRITE_n  Description
    {  true,  true,    true,    true,    true,       false, true,  false,  true,   true,  true,      true,   true,      "Test 1"},
    {  false, true,    true,    false,   true,       false, true,  false,  true,   true,  true,      true,   true,      "Test 2"}, // EADR_n = 0
    {  false, false,   true,    true,    true,       false, true,  false,  true,   true,  true,      true,   true,      "Test 3"}, // CACT_n = 0
    {  false, true,    true,    true,    true,       false, true,  false,  true,   true,  true,      true,   true,      "Test 4"},
    {  false, true,    true,    true,    true,       false, true,  false,  true,   true,  true,      true,   true,      "Test 5"},
    {  false, true,    true,    true,    true,       false, true,  false,  true,   true,  true,      true,   true,      "Test 6"},

};




    Verilated::commandArgs(argc, argv);
    VPAL_44303B* top = new VPAL_44303B;

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

        // Assignments for input fields
        top->TEST = test.TEST;
        top->CACT_n = test.CACT_n;
        top->CGNT_n = test.CGNT_n;
        top->EADR_n = test.EADR_n;
        top->BINPUT50_n = test.BINPUT50_n;
        top->MIS0 = test.MIS0;
        top->IOD_n = test.IOD_n;
        top->WRITE = test.WRITE;
        top->BACT_n = test.BACT_n;

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

if (top->CBWRITE_n != test.CBWRITE_n) {
    printf("[%s] CBWRITE_n output does not match expected value\n", test.description.c_str());
    errCnt++;
}

if (top->WLBD_n != test.WLBD_n) {
    printf("[%s] WLBD_n output does not match expected value\n", test.description.c_str());
    errCnt++;
}

if (top->CMWRITE_n != test.CMWRITE_n) {
    printf("[%s] CMWRITE_n output does not match expected value\n", test.description.c_str());
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




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

    bool TEST;


    bool CACT_n;
    bool CGNT_n;
    bool EADR_n;           // Address from CPU to Bus
    bool BINPUT50_n;
    bool MISO;
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

    // Iterate through each test case
    for (const auto& test : testCases) {
        std::cout << "Running " << test.description << std::endl;

        // Assignments for input fields
#if _later_        
        top->TEST = test.TEST;
     
#endif

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




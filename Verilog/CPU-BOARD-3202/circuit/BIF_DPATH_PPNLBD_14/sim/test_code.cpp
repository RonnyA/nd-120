#define DO_TRACE
#include <iostream>
#include <vector>
#include <random>
#include <ctime>
#include <string>

#include "VBIF_DPATH_PPNLBD_14.h"
#include "verilated.h"

#ifdef DO_TRACE
#include <verilated_vcd_c.h>
#endif

// PAL testcases
struct TestCase
{

    // Input signals

    uint16_t PPN_23_10;
    uint16_t CA_9_0;
    bool EADR_n; // Output enable to LBD
    bool ECREQ; // Clock input for 74_374 chips

    // Output signals
    uint32_t LBD_23_0_OUT;
    std::string description; // Description of the test case
};

#define MAX_SIM_TIME 20
vluint64_t sim_time = 0;
vluint64_t time_step = 5;

int main(int argc, char **argv)
{

    // Create a collection of test cases
    std::vector<TestCase> testCases = {};

    Verilated::commandArgs(argc, argv);
    VBIF_DPATH_PPNLBD_14 *top = new VBIF_DPATH_PPNLBD_14;

    // Set default values

    top->PPN_23_10 = 0;
    top->CA_9_0 = 0;
    top->EADR_n = true;
    top->ECREQ = false;

#ifdef DO_TRACE
    VerilatedVcdC *m_trace = new VerilatedVcdC;
    Verilated::traceEverOn(true);
    top->trace(m_trace, 1); // 1 is the trace depth
    m_trace->open("waveform.vcd");
#endif

    int errCnt = 0;

    // Default Assignments for input fields

    // Iterate through each test case
    // for (const auto& test : testCases) {
    //    std::cout << "Running " << test.description << std::endl;

    ushort ppn = 0x3F00;

    // top->STOC_n = false;
    for (int i = 0; i < 30; i++)
    {        
        top->CA_9_0  = i;
        top->PPN_23_10 = ppn+i;
   

        if (i == 3)
        {
            top->EADR_n = false; // enable output
        }


        if (i == 8)
        {
            top->EADR_n = true; // enable output
        }
        
        top->ECREQ = !top->ECREQ;
        top->eval();
#ifdef DO_TRACE
        
        m_trace->dump(sim_time);
        sim_time += time_step; // Increment simulation time

        top->ECREQ = !top->ECREQ;
        top->eval();
        
        m_trace->dump(sim_time);
        sim_time += time_step; // Increment simulation time
#endif

#if __later__
        // Conditional checks for output fields
        if (top->EMD_n != test.EMD_n)
        {
            printf("[%s] EMD_n output does not match expected value\n", test.description.c_str());
            errCnt++;
        }

        if (top->DSTB_n != test.DSTB_n)
        {
            printf("[%s] DSTB_n output does not match expected value\n", test.description.c_str());
            errCnt++;
        }

        if (top->BGNTCACT_n != test.BGNTCACT_n)
        {
            printf("[%s] BGNTCACT_n output does not match expected value\n", test.description.c_str());
            errCnt++;
        }

        if (top->CGNTCACT_n != test.CGNTCACT_n)
        {
            printf("[%s] CGNTCACT_n output does not match expected value\n", test.description.c_str());
            errCnt++;
        }

        // if (errCnt>0) break; // exit for loop
#endif
    }

    if (errCnt == 0)
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

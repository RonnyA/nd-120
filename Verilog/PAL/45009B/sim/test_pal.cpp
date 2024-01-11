#define DO_TRACE
#include <iostream>
#include <vector>
#include <random>
#include <ctime>
#include <string>

#include "VPAL_45009B.h"
#include "verilated.h"

#ifdef DO_TRACE
#include <verilated_vcd_c.h>
#endif

// PAL testcases
struct TestCase {
    

    // Inputs
    bool RDATA;
    bool BLOCKL25_n;
    bool BCGNT50;
    bool PS_n;
    bool RERR_n;
    bool PA_n;
    bool TEST;
    bool LERR_n;
    bool MR_n;


    // Outputs    
    bool SPESL;
    bool SPEAL;
    bool EPESL_n;
    bool EPEAL_n;
    bool BLOCKL_n;

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
    VPAL_45009B* top = new VPAL_45009B;

#ifdef DO_TRACE
    VerilatedVcdC *m_trace = new VerilatedVcdC;    
    Verilated::traceEverOn(true);
    top->trace(m_trace, 1); // 1 is the trace depth
    m_trace->open("waveform.vcd");
#endif
    


    int errCnt = 0;

    // Initialize inputs to zero
    top->RDATA = 
    top->BCGNT50 =     
    top->TEST = false;

    top->BLOCKL25_n =
    top->PS_n = 
    top->RERR_n =
    top->PA_n =     
    top->LERR_n = 
    top->MR_n = true;


    // Iterate through each test case
    //for (const auto& test : testCases) {
    for (int i=0;i<32;i++)
    {

        //std::cout << "Running " << test.description << std::endl;

        // Set inputs (?)
        if ((i & 1<<2) !=0 ) top->MR_n = 1;
            else top->MR_n = 0;

        if (i==1)
            top->RERR_n = false;            
        

        if (i==2)
            top->PS_n = false;
        

        if (i==7)
            top->PA_n = false;


        if (i==6)
        {
            top->RDATA = true;
            top->LERR_n = false;
        }


        if (i==10)
            top->RERR_n = true;

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




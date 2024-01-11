#define DO_TRACE
#include <iostream>
#include <vector>
#include <random>
#include <ctime>
#include <string>

#include "VPAL_44511A.h"
#include "verilated.h"

#ifdef DO_TRACE
#include <verilated_vcd_c.h>
#endif

// PAL testcases
struct TestCase {
    

    // Inputs

    //bool CK;       // Clock signal
    //bool OE_n;     // OUTPUT ENABLE (active-low) for Q0-Q3

    bool PIL0;
    bool PIL1;
    bool PIL2;
    bool PIL3;
    bool CLK;
    bool MREQ_n;
    bool WCA_n;

    // Outputs

    bool CUP;
    bool CWR_n;
    bool LEV0;

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
    VPAL_44511A* top = new VPAL_44511A;

#ifdef DO_TRACE
    VerilatedVcdC *m_trace = new VerilatedVcdC;    
    Verilated::traceEverOn(true);
    top->trace(m_trace, 1); // 1 is the trace depth
    m_trace->open("waveform.vcd");
#endif
    


    int errCnt = 0;

    top->CK = 0;
    top->CLK = top->CK;
    // /OE (Output enable)
    top->OE_n  = false;        

    // initial values
    top->PIL0 =
    top->PIL1 =
    top->PIL2 = 
    top->PIL3 = 
    top->CLK = false;

    top->MREQ_n = true;
    top->WCA_n = true;


    // Iterate through each test case
    //for (const auto& test : testCases) {
    for (int i=0;i<32;i++)
    {

        //std::cout << "Running " << test.description << std::endl;

        // Assignments for input fields
        
        
        //top->LCS_n =(j & 1<<0) !=0;       

        top->PIL3 = (i & 1<<3) !=0;
        top->PIL2 = (i & 1<<2) !=0;
        top->PIL1 = (i & 1<<1) !=0;
        top->PIL0 = (i & 1<<0) !=0;


        if (i==4)
            top->MREQ_n = !top->MREQ_n;

        if (i==5)
            top->WCA_n = !top->WCA_n;



        if (i==7)
            top->MREQ_n = !top->MREQ_n;


        top->eval();

#ifdef DO_TRACE        
        m_trace->dump(sim_time);
        sim_time += time_step; // Increment simulation time
#endif        


        // /OE (Output enable)
        //top->OE_n  = true;
        top->CK = !top->CK;
        top->CLK = top->CK;        
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




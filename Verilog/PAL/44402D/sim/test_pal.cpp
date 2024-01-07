// PAL_44404C,14D,CYIN1

#define DO_TRACE
#include <iostream>
#include <vector>
#include <random>
#include <ctime>
#include <string>

#include "VPAL_44402D.h"
#include "verilated.h"

#ifdef DO_TRACE
#include <verilated_vcd_c.h>
#endif

// PAL testcases
struct TestCase {
    
    //bool CLK,          // Clock signal
    //bool OE_n,         // OUTPUT ENABLE (active-low) for Q0-Q3    

    // Inputs
    bool DT_n;          // I0
    bool RT_n;          // I1
    bool LSHADOW;       // I2
    bool FMISS;         // I3
    bool CYD;           // I4
    bool HIT0_n;        // I5
    bool HIT1_n;        // I6
    bool EWC_n;         // I7
                   
    bool OUBI;          // B2_n (Signal input from CHIP 21F)
    bool OUBD;          // B3_n (Signal input from CHIP 21F)

    // Output 
    bool USED_n;        // B0_n
    bool WCA_n;         // B1_n 
    
    bool NUBI_n;        // Q0_n
    bool NUBD_n;        // Q1_n (new output for 44404D)
                        // Q2_n (not connected, no signal)
    bool IHIT_n;        // Q3_n (on pcb, not connected signal?)    

    std::string description; // Description of the test case
};


// note:
//   OSC is CK to flip-flop
//   OE_n is OUTPUT enable to Q0-Q3 pins on PAL.

#define MAX_SIM_TIME 20
vluint64_t sim_time = 0;
vluint64_t time_step = 5;


int main(int argc, char **argv) 
{

    // Create a collection of test cases
    std::vector<TestCase> testCases = {
    };

    Verilated::commandArgs(argc, argv);
    VPAL_44402D* top = new VPAL_44402D;

#ifdef DO_TRACE
    VerilatedVcdC *m_trace = new VerilatedVcdC;    
    Verilated::traceEverOn(true);
    top->trace(m_trace, 1); // 1 is the trace depth
    m_trace->open("waveform.vcd");
#endif
    int errCnt = 0;

    top->OE_n  = false;
    top->CLK = 0;

    top->DT_n = true;
    top->RT_n = true;
    top->HIT0_n = true;
    top->HIT1_n = true;
    top->EWC_n = true;
    

    // Iterate through each test case
    //for (const auto& test : testCases) {
    for (int i=0;i<32;i++)
    {


        //std::cout << "Running " << test.description << std::endl;

               
        // Assignments for input fields        
        top->CLK = !top->CLK;        

 
        if (i==2)
            top->WCA_n = false;

        if (i==2)
            top->DT_n    = false;


        if (i==3)
            top->HIT0_n = false;

        if (i==4)
            top->HIT1_n = false;

        if (i==5)
        {
            top->OUBI = true;
            top->OUBD = true;
        }

        if (i==6)
            top->RT_n = false;


        if (i==7)
            top->DT_n= false;


        top->eval();


#ifdef DO_TRACE        
        m_trace->dump(sim_time);
        sim_time += time_step; // Increment simulation time
#endif        

        if ((i & 1<<1) != 0)
            top->LSHADOW = !top->LSHADOW;

        top->CLK = !top->CLK;        

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




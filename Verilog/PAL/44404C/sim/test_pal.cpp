// PAL_44404C,14D,CYIN1

#define DO_TRACE
#include <iostream>
#include <vector>
#include <random>
#include <ctime>
#include <string>

#include "VPAL_44404C.h"
#include "verilated.h"

#ifdef DO_TRACE
#include <verilated_vcd_c.h>
#endif

// PAL testcases
struct TestCase {
    
    // Inputs
    bool CSDELAY1;     // I0
    bool CSALUM1;      // I1
    bool CSALUM0;      // I2
    bool CSALUI8;      // I3
    bool CSALUI7;      // I4
    bool LBA3;         // I5
    bool LBA1;         // I6
    bool LBA0;         // I7
    bool RRF_n;        // B0_n
    bool LSHADOW;      // B1_n      ; new input for 44404D
    bool SLCOND_n;     // B2_n
        

    //  Outputs    
    bool DLY1_n;      // B3_n     
    bool NOWRIT_n;    // Q0_n (flip-flop)
    bool DLSHADOW;    // Q1_n (flip-flop)  ; new output for 44404D

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
    VPAL_44404C* top = new VPAL_44404C;

#ifdef DO_TRACE
    VerilatedVcdC *m_trace = new VerilatedVcdC;    
    Verilated::traceEverOn(true);
    top->trace(m_trace, 1); // 1 is the trace depth
    m_trace->open("waveform.vcd");
#endif
    


    int errCnt = 0;


    top->OE_n  = false;
    top->CLK = 0;
    top->NOWRIT_n = true;
    top->RRF_n = true;  // disable RRF
    top->SLCOND_n = true; // disable SLCOND 

    // Iterate through each test case
    //for (const auto& test : testCases) {
    for (int i=0;i<32;i++)
    {


        //std::cout << "Running " << test.description << std::endl;

               
        // Assignments for input fields        
        top->CLK = !top->CLK;        

        top->LBA3 =  (i & 1<<3) != 0;
        top->LBA1 =  (i & 1<<1) != 0;
        top->LBA0 =  (i & 1<<0) != 0;



        if (i==3)
            top->CSALUI7 = true;

        if (i==4)
            top->CSALUI8 = true;

        if (i==5)
            top->CSALUM0 = true;

        if (i==6)
            top->CSALUM1 = true;


        if (i==7)
            top->CSDELAY1= true;


        if (i==9)
        {
            top->RRF_n = false;  // enable RRF
            top->SLCOND_n = false; // enable SLCOND 
        }

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




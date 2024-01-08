#define DO_TRACE
#include <iostream>
#include <vector>
#include <random>
#include <ctime>
#include <string>

#include "VPAL_44445B.h"
#include "verilated.h"

#ifdef DO_TRACE
#include <verilated_vcd_c.h>
#endif

// PAL testcases
struct TestCase {
    

    // Inputs

    //bool CK;       // Clock signal
    //bool OE_n;     // OUTPUT ENABLE (active-low) for Q0-Q3


    bool WRITE;        // I0 - WRITE
    bool IORQ_n;       // I1 - IORQ_n
    bool MOFF_n;       // I2 - MOFF_n 
    bool PPN19;        // I3 - PPN19
    bool PPN20;        // I4 - PPN20 
    bool PPN21;        // I5 - PPN21
    bool PPN22;        // I6 - PPN22
    bool PPN23;        // I7 - PPN23                       
    bool ECREQ;        // B3_n - ECREQ

    // Outputs 

    bool MSIZE0_n;     // B0_n - MSIZE0_n (not connected?)
    bool CLRQ_n;       // B1_n - CLRQ_n 
    bool CRQ_n;        // B2_n - CRQ_n


    bool BANK2;        // Q0_n - BANK2
    bool BANK1;        // Q1_n - BANK1
    bool BANK0;        // Q2_n - BANK0
    bool MWRITE_n;     // Q3_n - MWRITE_n

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
    VPAL_44445B* top = new VPAL_44445B;

#ifdef DO_TRACE
    VerilatedVcdC *m_trace = new VerilatedVcdC;    
    Verilated::traceEverOn(true);
    top->trace(m_trace, 1); // 1 is the trace depth
    m_trace->open("waveform.vcd");
#endif
    


    int errCnt = 0;

    top->OE_n  = false;        
    top->CK = 0;

    top->ECREQ = true;
    top->MOFF_n = true;
    top->IORQ_n = true;
    

    // Iterate through each test case
    //for (const auto& test : testCases) {
    for (int i=0;i<64;i++)
    {

        //std::cout << "Running " << test.description << std::endl;
        top->CK = !top->CK;

        // Assignments for input fields        
        top->PPN23 = (i & 1<<3) !=0;
        top->PPN22 = (i & 1<<2) !=0;
        top->PPN21 = (i & 1<<1) !=0;
        top->PPN20 = (i & 1<<0) !=0;


        if (i==2)
            top->WRITE = true;


        if (i==2)
            top->IORQ_n = false;

        if (i==3)
            top->IORQ_n = true;


        if (i==32)
        {
            top->ECREQ = false;
            //top->MOFF_n = true;
            //top->IORQ_n = true;        
        }

        top->eval();

#ifdef DO_TRACE        
        m_trace->dump(sim_time);
        sim_time += time_step; // Increment simulation time
#endif        


        // /OE (Output enable)
        //top->OE_n  = true;
        top->CK = !top->CK;
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




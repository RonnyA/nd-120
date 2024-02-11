#define DO_TRACE
#include <iostream>
#include <vector>
#include <random>
#include <ctime>
#include <string>

#include "VCPU_MMU_PTIDB_30.h"
#include "verilated.h"

#ifdef DO_TRACE
#include <verilated_vcd_c.h>
#endif

// PAL testcases
struct TestCase {
    
    // InOut
    uint16_t IDB_15_0;     // Bidirectional IDB data bus (A)
    uint16_t PT_15_0;       // Bidirectional PT data bus  (B)

    // Inputs
    bool WRITE;               // Direction: 0=Read,1=Write  (DIR)
    bool EPTI_n;              // Enable PTI (EPTI_n)    

    // Outputs
    
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
    VCPU_MMU_PTIDB_30* top = new VCPU_MMU_PTIDB_30;

    
// Set default values

   top->IDB_15_0 = 0x2222;
   top->PT_15_0 = 0x1111;
   top->EPTI_n = true; // disable output 
   top->WRITE = true; //write to PT

#ifdef DO_TRACE
    VerilatedVcdC *m_trace = new VerilatedVcdC;    
    Verilated::traceEverOn(true);
    top->trace(m_trace, 1); // 1 is the trace depth
    m_trace->open("waveform.vcd");
#endif
    


    int errCnt = 0;
    top->eval();

    // Iterate through each test case
    //for (const auto& test : testCases) {
    //    std::cout << "Running " << test.description << std::endl;

    for (int i=0xFA00; i<0xFAFF; i++)
    {                          
        
        if (i%3==0)
        {
            top->WRITE = !top->WRITE; // toggle DIR
        }

        top->IDB_15_0 = 0xFFF1;
        top->PT_15_0 = 0xFFF0;

        if (top->WRITE) 
        {
            // Write IDB to PT
            top->IDB_15_0 = i;                       
        }
        else
        {
            // Read PT to  IDB 
            top->PT_15_0 = i;            
        }


        if (i%10==0)
        {
           top->EPTI_n  = !top->EPTI_n ; // toggle EPTI_n // Enable PTI
            
        }

        top->eval();
        

#ifdef DO_TRACE        
        m_trace->dump(sim_time);
        sim_time += time_step; // Increment simulation time
#endif


        // Fix clock!!
      


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




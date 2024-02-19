#define DO_TRACE
#include <iostream>
#include <vector>
#include <random>
#include <ctime>
#include <string>

#include "VCPU_MMU_CSR_26.h"
#include "verilated.h"

#ifdef DO_TRACE
#include <verilated_vcd_c.h>
#endif

// PAL testcases
struct TestCase {

    // Inputs
    bool STP;
    bool EMPID_n;
    bool EDO_n;
    bool LCS_n;
    bool PD2; // OE1_1G_n
    
    bool CUP;
    bool CON;   
    bool ECSR_n; // OE2_2G_n
    
    // Outputs
    bool       BSTP;
    bool       BEMPID_n;
    bool       BEDO_n; 
    bool       BLCS_n;
    
    uint8_t    IDB_3_0;
    
    std::string description; // Description of the test case
};


#define MAX_SIM_TIME 20
vluint64_t sim_time = 0;
vluint64_t time_step = 10;

int main(int argc, char **argv) 
{

    // Create a collection of test cases
    std::vector<TestCase> testCases = {
    };

    Verilated::commandArgs(argc, argv);
    VCPU_MMU_CSR_26* top = new VCPU_MMU_CSR_26;

    
// Set default values

   top->PD2 = true;    // disable output
   top->ECSR_n = true; // disable output

   top->STP =true;
   top->EMPID_n = true;
   top->EDO_n = true;
   top->LCS_n = true;

   top->CUP = true;
   top->CON = true;

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

    for (int i=0; i<10; i++)
    {                          
        
        if (i==1)
            top->PD2=false; // Enable OE1_1G_n


        if (i==2)
            top->ECSR_n=false; // Enable OE2_2G_n


        // ---

        if (i==3)
            top->STP=false;

        if (i==4)
            top->STP=false;

        if (i==5)
            top->EDO_n=false;

        if (i==6)
            top->LCS_n=false;

        // ---

        if (i==7)
            top->CUP=false;

        if (i==8)
            top->CON=false;


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




#define DO_TRACE
#include <iostream>
#include <vector>
#include <random>
#include <ctime>
#include <string>

#include "VCPU_CS_16.h"
#include "verilated.h"

#ifdef DO_TRACE
#include <verilated_vcd_c.h>
#endif

// PAL testcases
struct TestCase {
    
   /*******************************************************************************
   ** The inputs are defined here                                                **
   *******************************************************************************/
   
   uint16_t    IDB_15_0;
   uint8_t     CC_3_1_n;
   uint16_t    CSA_12_0;
   uint16_t    CSCA_9_0;
   uint8_t     RF_1_0;
   bool        BLCS_n;
   bool        BRK_n;
   bool        CLK;
   bool        FETCH;
   bool        FORM_n;
   bool        LCS_n;
   bool        MACLK;
   bool        PD1;
   bool        RWCS_n;
   bool        TERM_n;
   bool        WCA_n;
   bool        WCS_n;
   
   
   /*******************************************************************************
   ** The outputs are defined here                                               **
   *******************************************************************************/

   uint64_t  CSBITS;
   bool      EWCA_n;
   uint16_t  IDB_15_0_OUT;
   uint16_t  LUA_12_0;

   
    
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
    VCPU_CS_16* top = new VCPU_CS_16;
    
    // Set default values     
    top->BLCS_n = true;
    top->BRK_n = true;
    top->CLK = false;
    top->FETCH = false;
    top->FORM_n = true;
    top->LCS_n = true;
    top->MACLK = true;
    top->PD1 = false; // PD1 must be low to have normal functionality
    top->RWCS_n = true;
    top->TERM_n = true;
    top->WCA_n = true;
    top->WCS_n = true;


    top->FETCH = true;  

#ifdef DO_TRACE
    VerilatedVcdC *m_trace = new VerilatedVcdC;    
    Verilated::traceEverOn(true);
    top->trace(m_trace, 2); // 1 is the trace depth
    m_trace->open("waveform.vcd");
#endif
    


    int errCnt = 0;

    // Set defaults
    top->sys_rst_n = true; // Assert disabled
    top->sysclk = 0;
    top->eval();

    
#ifdef DO_TRACE        
        m_trace->dump(sim_time);
        sim_time += time_step; // Increment simulation time
#endif

    

    // Iterate through each test case
    //for (const auto& test : testCases) {
    //    std::cout << "Running " << test.description << std::endl;

    int rf = 0;
    int cnt=0;

    // Only first 10 microcodes for test
    for (int j=0;j<10;j++)
    {
        top->WCS_n = false;
        top->BLCS_n = false;
        top->LCS_n = false;
        
        top->CSA_12_0 = j;
        top->CSCA_9_0 = j;                

        // Load microcode from PROM to RAM
        for (int part = 0;part <4; part++)
        {
            for (int ck =0;ck<1;ck++)
            {
                
                
                top->RF_1_0 = part;

                top->sysclk=!top->sysclk;
                top->eval();
            
                    
        

#ifdef DO_TRACE        
        m_trace->dump(sim_time);
        sim_time += time_step; // Increment simulation time
#endif

                top->sysclk=!top->sysclk;
                top->CLK = !top->CLK;
                top->MACLK = top->CLK;
                top->eval();
#ifdef DO_TRACE        
        m_trace->dump(sim_time);
        sim_time += time_step; // Increment simulation time
#endif

            }
        }

    }

    top->WCS_n =true;
    top->BLCS_n = true; // Dont send PROM data out on IDB anymore
    top->LCS_n = true;


    for (int j=0; j<10; j++)
    {
        top->CSA_12_0 = j;
        top->CSCA_9_0 = j;

        for (int ck =0;ck<1;ck++)
        {
            top->MACLK = top->CLK;

    

            top->eval();

            top->CLK = !top->CLK ;        

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




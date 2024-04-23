#define DO_TRACE
#include <iostream>
#include <vector>
#include <random>
#include <ctime>
#include <string>

#include "VBIF_BCTL_SYNC_8.h"
#include "verilated.h"

#ifdef DO_TRACE
#include <verilated_vcd_c.h>
#endif

// PAL testcases
struct TestCase {
    
   /*******************************************************************************
   ** The inputs are defined here                                                **
   *******************************************************************************/
   

  // Inputs signals
   bool BLOCK_n;
   bool CACT_n;
   bool CLEAR_n;
   bool IBDAP_n;
   bool IBDRY_n;
   bool IBINPUT_n;
   bool IBPERR_n;
   bool IBREQ_n;
   bool ISEMRQ_n;
   bool OSC;
   bool PD1;
   bool PD3;
   bool REFRQ_n;

   // Output signals
   bool BDAP50_n;
   bool BDRY25_n;
   bool BDRY50_n;
   bool BDRY75_n;
   bool BINPUT50_n;
   bool BINPUT75_n;
   bool BLOCK25_n;
   bool BPERR50_n;
   bool BREQ50_n;
   bool CACT25_n;
   bool MR_n;
   bool REFRQ50_n;
   bool SEMRQ50_n;

    
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
    VBIF_BCTL_SYNC_8* top = new VBIF_BCTL_SYNC_8;
    
    // Set default values     
  

#ifdef DO_TRACE
    VerilatedVcdC *m_trace = new VerilatedVcdC;    
    Verilated::traceEverOn(true);
    top->trace(m_trace, 2); // 1 is the trace depth
    m_trace->open("waveform.vcd");
#endif
    


    int errCnt = 0;

    // Set defaults
    top->OSC =false;
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
            top->eval();
            
                    
        

#ifdef DO_TRACE        
        m_trace->dump(sim_time);
        sim_time += time_step; // Increment simulation time
#endif

            top->OSC =!top->OSC ;
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




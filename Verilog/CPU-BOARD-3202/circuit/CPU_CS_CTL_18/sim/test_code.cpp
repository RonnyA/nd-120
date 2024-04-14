#define DO_TRACE
#include <iostream>
#include <vector>
#include <random>
#include <ctime>
#include <string>

#include "VCPU_CS_CTL_18.h"
#include "verilated.h"

#ifdef DO_TRACE
#include <verilated_vcd_c.h>
#endif

// PAL testcases
struct TestCase {
    
   /*******************************************************************************
   ** The inputs are defined here                                                **
   *******************************************************************************/
   uint8_t CC_3_1_n;
   uint8_t RF_1_0;
   bool    BRK_n;
   bool    FETCH;
   bool    FORM_n;
   bool    LCS_n;
   bool    LUA12;
   bool    RWCS_n;
   bool    TERM_n;
   bool    WCA_n;
   bool    WCS_n;

   /*******************************************************************************
   ** The outputs are defined here                                               **
   *******************************************************************************/
   bool    ECSL_n;
   bool    ELOW_n;
   bool    EUPP_n;
   bool    EWCA_n;
   uint8_t EW_3_0_n;
   uint8_t WU_3_0_n;
   uint8_t WW_3_0_n;  
    
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
    VCPU_CS_CTL_18* top = new VCPU_CS_CTL_18;
    
    // Set default values     

    top->BRK_n =    
    top->FORM_n =
    top->LCS_n =
    top->RWCS_n =
    top->TERM_n=
    top->WCA_n =
    top->WCS_n = true;

    top->FETCH =
    top->LUA12 = 0;

#ifdef DO_TRACE
    VerilatedVcdC *m_trace = new VerilatedVcdC;    
    Verilated::traceEverOn(true);
    top->trace(m_trace, 2); // 1 is the trace depth
    m_trace->open("waveform.vcd");
#endif
    


    int errCnt = 0;

    bool testflip = false;
    top->eval();

    // Iterate through each test case
    //for (const auto& test : testCases) {
    //    std::cout << "Running " << test.description << std::endl;

    int rf = 0;
    int cnt=0;

    for (int j=0; j<512; j++)
    {
        
        if (j%10==1)
            cnt++;
        top->CC_3_1_n = ~cnt;
        
        if (j%16==1)
            rf++;
        if (rf>3) rf=0;
        top->RF_1_0 = rf;


        if (j%5==1)
            top->LCS_n = !top->LCS_n;

        if (j%8==1)
        {
            // WRITE PULSE TO MICROINSTRUCTION CACHE
            top->WCA_n =!top->WCA_n;
            top->FETCH = !top->FETCH;
            top->TERM_n = top->FETCH;
        }

        if (j==15)
            top->LUA12 = !top->LUA12;


          if (j%20==1)
          {
            top->RWCS_n = !top->RWCS_n;
            top->WCS_n = !top->WCS_n;
            top->LCS_n = !top->LCS_n;
          }


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




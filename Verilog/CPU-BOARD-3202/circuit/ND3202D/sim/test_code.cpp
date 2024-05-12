#define DO_TRACE
#include <iostream>
#include <vector>
#include <random>
#include <ctime>
#include <string>

#include "VND3202D.h"
#include "verilated.h"

#ifdef DO_TRACE
#include <verilated_vcd_c.h>
#endif

// PAL testcases
struct TestCase {
    
   /*******************************************************************************
   ** The inputs are defined here                                                **
   *******************************************************************************/
   bool sys_rst_n;
   bool sysclk;

   bool OC0;
   bool OC1;
   bool OSCCL_n;
   bool BINT10_n;
   bool BINT11_n;
   bool BINT12_n;
   bool BINT13_n;
   bool BINT15_n;
   bool BREQ_n;
   bool CLOCK_1;
   bool CLOCK_2;
   bool CONSOLE_n;
   bool CONTINUE_n;
   bool EAUTO_n;
   bool LOAD_n;
   bool LOCK_n;
   bool RXD;
   bool STOP_n;
   bool SW1_CONSOLE;
   bool SWMCL_n;
   bool XTR;
   uint8_t SEL_TESTMUX;      // Selects testmux signals to output on TEST_4_0
   uint8_t BAUD_RATE_SWITCH; // Switch on the PCB to select baudrate

   bool POWSENSE_n; // Power sense signal from the PSU
   
   /*******************************************************************************
   ** The outputs are defined here                                               **
   *******************************************************************************/

   uint64_t CSBITS;
   uint8_t  DP_5_1_n;
   bool     RUN_n;
   uint8_t  TEST_4_0;
   bool     TP1_INTRQ_n;
   bool     TXD;
 
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
    VND3202D* top = new VND3202D;
    

#ifdef DO_TRACE
    VerilatedVcdC *m_trace = new VerilatedVcdC;    
    Verilated::traceEverOn(true);
    top->trace(m_trace, 2); // 1 is the trace depth
    m_trace->open("waveform.vcd");
#endif
    


    int errCnt = 0;

    top->sys_rst_n = 0; // Assert

    top->CONSOLE_n = 
    top->CONTINUE_n =
    top->EAUTO_n =
    top->LOAD_n =
    top->LOCK_n =
    top->STOP_n =   
    top->SWMCL_n = 
    top->BINT10_n =
    top->BINT11_n =
    top->BINT12_n =
    top->BINT13_n = 
    top->BINT15_n =    
    top->BREQ_n = true; //disabled

    // Set defaults    
    top->OSCCL_n = 1;
    top->OC_1_0 = 0b11; // Choose clock input = XTAL1
    
    

    // Iterate through each test case
    //for (const auto& test : testCases) {
    //    std::cout << "Running " << test.description << std::endl;



    // Set defaults (clock and reset)
    top->CLOCK_2 = top->CLOCK_1=0;
    top->sys_rst_n = false; // Assert RESET signal
    top->sysclk = 0;
  
    //top->POWSENSE_n = true; // Power sense signal from the PSU

        top->eval();
#ifdef DO_TRACE        
        m_trace->dump(sim_time);
        sim_time += time_step; // Increment simulation time
#endif


    for (int ck =0;ck<2048;ck++)
    {

        if (ck==3)
            top->sys_rst_n=true;  // run 3 clock cycles with reset asserted


        //if (ck==10)
        //    top->POWSENSE_n = !top->POWSENSE_n; // Toggle POWSENSE signal

        top->sysclk = !top->sysclk; // Toggle clock
        top->CLOCK_1 = !top->CLOCK_1;
        top->CLOCK_2 = top->CLOCK_1;
        
        top->eval();
#ifdef DO_TRACE        
        m_trace->dump(sim_time);
        sim_time += time_step; // Increment simulation time
#endif

        top->CLOCK_1 = !top->CLOCK_1;
        top->CLOCK_2 = top->CLOCK_1;
        top->sysclk = !top->sysclk; // Toggle clock

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
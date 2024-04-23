#define DO_TRACE
#include <iostream>
#include <vector>
#include <random>
#include <ctime>
#include <string>

#include "VCPU_MMU_24.h"
#include "verilated.h"

#ifdef DO_TRACE
#include <verilated_vcd_c.h>
#endif

// PAL testcases
struct TestCase {

   bool sysclk; // System clock in FPGA
   bool sys_rst_n; // System reset in FPGA


   /*******************************************************************************
   ** The inputs are defined here                                                **
   *******************************************************************************/   


   bool         BRK_n;
   uint16_t     CA_10_0;
   bool         CC2_n;
   bool         CCLR_n;
   bool         CUP;
   bool         CWR;
   bool         CYD;
   bool         DOUBLE;
   bool         DT_n;
   bool         DVACC_n;
   bool         ECSR_n;
   bool         EDO_n;
   bool         EMCL_n;
   bool         EMPID_n;
   bool         EORF_n;
   bool         ESTOF_n;
   bool         FMISS;
   uint16_t     LA_20_10;
   bool         LCS_n;
   bool         LSHADOW;
   bool         PD2;
   bool         RT_n;
   bool         STP;
   bool         SW1_CONSOLE;
   bool         UCLK;
   bool         WCHIM_n;
   bool         WRITE;

   /*******************************************************************************
   ** The INOUT are defined here                                                **
   *******************************************************************************/
 
   uint16_t  IDB_15_0_IN;
   uint16_t  IDB_15_0_OUT;
   
   uint16_t  CD_15_0_IN;
   uint16_t  CD_15_0_OUT;

   uint16_t  PPN_25_10_IN;
   uint16_t  PPN_25_10_OUT;

  /*******************************************************************************
   ** The outputs are defined here                                               **
   *******************************************************************************/


   uint16_t  PT_15_0_OUT;

   bool        BEDO_n;
   bool        BEMPID_n;
   bool        BLCS_n;
   bool        BSTP;   
   bool        HIT;   
   bool        LAPA_n;   
   bool        WCA_n;
   bool        LED1; // Cache enabled ?

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
    VCPU_MMU_24* top = new VCPU_MMU_24;
    
    // Set default values     
   
   

#ifdef DO_TRACE
    VerilatedVcdC *m_trace = new VerilatedVcdC;    
    Verilated::traceEverOn(true);
    top->trace(m_trace, 2); // 1 is the trace depth
    m_trace->open("waveform.vcd");
#endif
    


    int errCnt = 0;

    // Set defaults

    

    // Iterate through each test case
    //for (const auto& test : testCases) {
    //    std::cout << "Running " << test.description << std::endl;


    top->sysclk = 0;

    for (int ck =0;ck<512;ck++)
    {
        


#ifdef DO_TRACE        
        m_trace->dump(sim_time);
        sim_time += time_step; // Increment simulation time
#endif


        top->eval();
        top->sysclk = !top->sysclk ;        


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




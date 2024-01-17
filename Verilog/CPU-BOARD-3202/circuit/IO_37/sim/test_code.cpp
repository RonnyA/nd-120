#define DO_TRACE
#include <iostream>
#include <vector>
#include <random>
#include <ctime>
#include <string>

#include "VIO_37.h"
#include "verilated.h"

#ifdef DO_TRACE
#include <verilated_vcd_c.h>
#endif

// PAL testcases
struct TestCase {

    // Inputs
   bool       BDRY50_n;
   bool       BRK_n;
   bool       CLK;
   uint8_t    CSCOMM_4_0;
   uint8_t    CSIDBS_4_0;
   uint8_t    CSMIS_1_0;
   bool       CX_n;
   bool       DAP_n;
   bool       EAUTO_n;
   bool       EORF_n;
   bool       HIT;
   bool       I1P;
   bool       ICONTIN_n;
   bool       ILOAD_n;
   uint8_t    INR_7_0;
   bool       IONI;
   bool       ISTOP_n;
   bool       LCS_n;
   bool       LEV0;
   bool       LOCK_n;
   bool       LSHADOW;
   uint8_t    OC_1_0;
   bool       OPCLCS;
   bool       OSCCL_n;
   uint8_t    PCR_1_0;
   bool       PONI;
   bool       POWSENSE_n;
   bool       REF_n;
   bool       RXD;
   bool       SEL5MS_n;
   bool       SWMCL_n;
   bool       UCLK;
   bool       XTAL1;
   bool       XTAL2;
   bool       XTR;
  
   
    // Outputs
   uint16_t CD_15_0;
    

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
    VIO_37* top = new VIO_37;

    
// Set default values


   top->CX_n = false; // CPU Fast version

   top->BDRY50_n = 
   top->BRK_n =    
   top->DAP_n =
   top->EAUTO_n =
   top->EORF_n =
   top->ICONTIN_n =
   top->ILOAD_n =
   top->IONI =
   top->ISTOP_n =
   top->LCS_n =
   top->LOCK_n =
   top->OSCCL_n =
   top->POWSENSE_n =
   top->REF_n =
   top->SEL5MS_n =
   top->SWMCL_n = true;
   
      
   top->LEV0 = true; // Level 0

   top->HIT  =
   top->I1P =
   top->LSHADOW =
   top->OPCLCS =
   top->PONI =
   top->RXD =
   top->XTR = false;

/*
    uint8_t    PCR_1_0;
    uint8_t    INR_7_0;
*/


   top->OC_1_0 = 0b10; // Select XTAL2 as clock input to OSC

   top->CLK = 
   top->UCLK = 
   top->XTAL1=
   top->XTAL2= 0;

#ifdef DO_TRACE
    VerilatedVcdC *m_trace = new VerilatedVcdC;    
    Verilated::traceEverOn(true);
    top->trace(m_trace, 1); // 1 is the trace depth
    m_trace->open("waveform.vcd");
#endif
    


    int errCnt = 0;

   // Default Assignments for input fields


    // Iterate through each test case
    //for (const auto& test : testCases) {
    //    std::cout << "Running " << test.description << std::endl;

    //top->STOC_n = false;
    for (int i=0; i<10; i++)
    {
        for (int cscomm=0; cscomm<32; cscomm++)
        {
            for (int csmis=0; csmis<=3; csmis++)
            {

                top->INR_7_0 = i;

                top->CSCOMM_4_0 = cscomm;
                top->CSMIS_1_0 = csmis;
                


        top->eval();


#ifdef DO_TRACE        
        m_trace->dump(sim_time);
        sim_time += time_step; // Increment simulation time
#endif


        // Fix clock!!

        top->CLK = !top->CLK;
        top->UCLK = 
        top->XTAL1=
        top->XTAL2= top->CLK;



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




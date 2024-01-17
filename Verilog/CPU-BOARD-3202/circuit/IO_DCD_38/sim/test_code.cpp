#define DO_TRACE
#include <iostream>
#include <vector>
#include <random>
#include <ctime>
#include <string>

#include "VIO_DCD_38.h"
#include "verilated.h"

#ifdef DO_TRACE
#include <verilated_vcd_c.h>
#endif

// PAL testcases
struct TestCase {
    

    // Inputs
   bool        BDRY50_n;
   bool        BRK_n;
   bool        CLK;
   uint8_t     CSCOMM_4_0;
   uint8_t     CSIDBS_4_0;
   uint8_t     CSMIS_1_0;
   bool        DAP_n;
   bool        EORF_n;
   bool        HIT;
   bool        ICONTIN_n;
   uint8_t     IDB_3_0_io;
   uint8_t     IDB_7_4;
   bool        ILOAD_n;
   bool        ISTOP_n;
   bool        LCS_n;
   bool        LSHADOW;
   uint8_t     OC_1_0;
   bool        OPCLCS;
   bool        OSCCL_n;
   bool        PONI;
   bool        POWSENSE_n;
   bool        REF_n;
   bool        RMM_n;
   bool        SEL5MS_n;
   uint8_t     STAT_4_3;
   bool        SWMCL_n;
   bool        UCLK;
   bool        XTAL1;  // 38.3216 MHz
   bool        XTAL2;  // 35 MHZ
    
    uint16_t IDB_15_0;             
    bool STOC_n;      
   
    // Outputs
   uint16_t CD_15_0;
    

    std::string description; // Description of the test case
};


#define MAX_SIM_TIME 20
vluint64_t sim_time = 0;
vluint64_t time_step = 5;



/*
   uint8_t     CSCOMM_4_0;
   uint8_t     CSIDBS_4_0;
   uint8_t     CSMIS_1_0;
   uint8_t     IDB_3_0_io;
   uint8_t     IDB_7_4;
   uint8_t     OC_1_0;
   uint8_t     STAT_4_3;
*/



int main(int argc, char **argv) 
{

    // Create a collection of test cases
    std::vector<TestCase> testCases = {
    };





    Verilated::commandArgs(argc, argv);
    VIO_DCD_38* top = new VIO_DCD_38;

    
// Set default values

   top->BDRY50_n =
   top->BRK_n =
   top->DAP_n =
   top->EORF_n =
   top->ICONTIN_n =
   top->ILOAD_n =
   top->ISTOP_n =
   top->LCS_n =
   top->OSCCL_n =
   top->POWSENSE_n =
   top->REF_n =
   top->RMM_n =
   top->SEL5MS_n =
   top->SWMCL_n = true;

   top->HIT =
   top->LSHADOW =
   top->OPCLCS =
   top->PONI = false;


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

                uint16_t idb;

                top->IDB_7_4 = (idb >> 4) & 0xF;
                top->IDB_3_0_io = (idb & 0xF);

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




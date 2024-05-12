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
   bool sysclk;      // System clock in FPGA
   bool sys_rst_n;   // System reset in FPGA

   uint8_t CSCOMM_4_0;
   uint8_t CSIDBS_4_0;
   uint8_t CSMIS_1_0;
   uint8_t OC_1_0;
   uint8_t STAT_4_3;

   
   bool BDRY50_n;
   bool BRK_n;
   bool CLK;
   bool DAP_n;
   bool EORF_n;
   bool HIT;
   bool ICONTIN_n;
   bool ILOAD_n;
   bool ISTOP_n;
   bool LCS_n;
   bool LSHADOW;
   bool OPCLCS;
   bool OSCCL_n;
   bool PONI;
   bool POWSENSE_n;
   bool REF_n;
   bool RMM_n;
   bool SEL5MS_n;
   bool SWMCL_n;
   bool UCLK;
   bool XTAL1;  // 38.3216 MHz
   bool XTAL2;  // 35 MHZ




   // In and outs
   uint8_t IDB_7_0_IN;
   uint8_t IDB_7_0_OUT; 
   
    // Outputs   
   uint8_t PA_7_0; // From FIFO direct to 68705 PanCal processor

   bool  CA10;
   bool  CCLR_n;
   bool  CEUART_n;
   bool  CLEAR_n;
   bool  DT_n;
   bool  DVACC_n;
   bool  ECREQ;
   bool  ECSR_n;
   bool  EDO_n;
   bool  EIOR_n;
   bool  EMPID_n;
   bool  EMP_n;
   bool  EPANS_n;
   bool  ESTOF_n;
   bool  FETCH;
   bool  FMISS;
   bool  FORM_n;
   bool  FUL_n;
   bool  IORQ_n;
   bool  LHIT;
   bool  MCL;
   bool  MREQ_n;
   bool  OSC;
   bool  PANOSC;
   bool  PAN_n;   
   bool  PA_n;
   bool  POWFAIL_n;
   bool  PPOSC;
   bool  PS_n;
   bool  REFRQ_n;
   bool  RINR_n;
   bool  RT_n;
   bool  RUART_n;
   bool  RWCS_n;  // (NOT CONNECTED IN SHEET 39) - find signal from one of the PAL's ??
   bool  SHORT_n;
   bool  SIOC_n;
   bool  SLOW_n;
   bool  SSEMA_n;
   bool  STOC_n;
   bool  STP;
   bool  TOUT;
   bool  TRAALD_n;
   bool  VAL;
   bool  WCHIM_n;
   bool  WRITE;
   bool  EPAN_n; // Signal on the DGA chip (not connected in sheet 39). Maybe replaced by a PAL signal ?      

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

                uint16_t idb = 0xBA;

                top->IDB_7_0_IN = idb;                

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




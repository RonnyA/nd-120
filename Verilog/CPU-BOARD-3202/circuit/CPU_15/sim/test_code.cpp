#define DO_TRACE
#include <iostream>
#include <vector>
#include <random>
#include <ctime>
#include <string>

#include "VCPU_15.h"
#include "verilated.h"

#ifdef DO_TRACE
#include <verilated_vcd_c.h>
#endif

// PAL testcases
struct TestCase {
   /*******************************************************************************
   ** The inputs are defined here                                                **
   *******************************************************************************/   
   bool   CLK;
   bool   ALUCLK;
   bool   MACLK;
   bool   MCLK;

   uint8_t   CC_3_1_n;

   bool   CA10;
   bool   CCLR_n;
   
   bool   CYD;
   bool   DT_n;
   bool   DVACC_n;
   bool   ECSR_n;
   bool   EDO_n;
   bool   EMCL_n;
   bool   EMPID_n;
   bool   EORF_n;
   bool   ESTOF_n;
   bool   ETRAP_n;
   bool   FETCH;
   bool   FMISS;
   bool   FORM_n;
   bool   IBINT10_n;
   bool   IBINT11_n;
   bool   IBINT12_n;
   bool   IBINT13_n;
   bool   IBINT15_n;
   bool   IOXERR_n;
   bool   LCS_n;
   bool   MAP_n;
   bool   MOR_n;
   bool   MR_n;
   bool   PAN_n;
   bool   PARERR_n;
   bool   PD1;
   bool   PD2;
   bool   POWFAIL_n;
   bool   RT_n;
   bool   RWCS_n;
   bool   STOC_n;
   bool   STP;
   bool   SW1_CONSOLE;
   bool   TERM_n;
   bool   UCLK;
   bool   WCHIM_n;
   bool   WRFSTB;
   bool   WRITE;
   

   /*******************************************************************************
   ** The INOUT are defined here                                                **
   *******************************************************************************/
 
    uint16_t  CD_15_0;
    uint16_t  IDB_15_0;

    uint16_t  CD_15_0_OUT;
    uint16_t  IDB_15_0_OUT

   /*******************************************************************************
   ** The outputs are defined here                                               **
   *******************************************************************************/
    uint16_t  CA_9_0;
    uint8_t   LBA_3_0;
    uint16_t  LUA_12_0;
           
    uint8_t   PCR_1_0;
    uint8_t   PIL_3_0;    
    uint16_t  PPN_23_10;
    uint8_t   TEST_4_0;
    uint64_t  TOPCSB;

    bool LSHADOW;
    bool OPCLCS;
    bool PONI;           
    bool TRAP;
    bool VEX;
    bool TP1_INTRQ_n;
    
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
    VCPU_15* top = new VCPU_15;
    
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



    for (int ck =0;ck<512;ck++)
    {
        top->ALUCLK = top->MCLK = top->MACLK = top->CLK;


#ifdef DO_TRACE        
        m_trace->dump(sim_time);
        sim_time += time_step; // Increment simulation time
#endif


        top->eval();
        top->CLK = !top->CLK ;        


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




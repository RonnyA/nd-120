#define DO_TRACE
#include <iostream>
#include <vector>
#include <random>
#include <ctime>
#include <string>

#include "VCPU_PROC_CGA_33.h"
#include "verilated.h"

#ifdef DO_TRACE
#include <verilated_vcd_c.h>
#endif

// PAL testcases
struct TestCase {
    

    // Inputs
    //input        ALUCLK;
    //input        MCLK;
    //input        UCLK;

    uint64_t  CSBITS;
    uint16_t  CD_15_0; 
    uint8_t  PT_15_9;  

    bool  BEDO_n;
    bool  BEMPID_n;
    bool  BSTP;
    
    
    bool  ETRAP_n;
    bool  EWCA_n;
    bool  IBINT10_n;
    bool  IBINT11_n;
    bool  IBINT12_n;
    bool  IBINT13_n;
    bool  IBINT15_n;
    bool  IOXERR_n;
    bool  LCS_n;
    bool  MAP_n;
    bool  MOR_n;
    bool  MR_n;
    bool  PAN_n;
    bool  PARERR_n;
    bool  POWFAIL_n;
    
    // Outputs
    bool ACOND_n;
    bool CGABRK_n;
    uint16_t CSA_12_0;  
    uint16_t CSCA_9_0;  
    bool DOUBLE;
    bool ECCR;
    uint16_t FIDB_15_0_io; 
    bool INTRQ_n_tp1;
    bool IONI;
    uint8_t LAA_3_0;   
    uint16_t LA_23_10;  
    uint8_t LBA_3_0;   
    bool LSHADOW;
    uint8_t PCR_1_0;   
    uint8_t PIL_3_0;   
    bool PONI;
    uint8_t RF_1_0;    
    uint8_t TEST_4_0;  
    bool TRAP_n;
    bool WCS_n;
    bool WRTRF;

    std::string description; // Description of the test case
};


#define MAX_SIM_TIME 20
vluint64_t sim_time = 0;
vluint64_t time_step = 5;


int main(int argc, char **argv) 
{

    // Create a collection of test cases
    std::vector<TestCase> testCases = {
        // TEST   Q0_n   Q2_n   CC2_n   BDRY25_n  BDRY50_n  CGNT_n   CGNT50_n  CACT_n   TERM_n   BGNT_n  RT_n    IORQ_n   EMD_n   DSTB_n   BGNTCACT_n   CGNTCACT_n  Description
    };





    Verilated::commandArgs(argc, argv);
    VCPU_PROC_CGA_33* top = new VCPU_PROC_CGA_33;

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

    top->ALUCLK = top->UCLK = top->MCLK = 0; // Toggle clocks

    for (int i=0; i<4096; i++)
    {
        top->MCLK = !top->MCLK; // Toggle OSC
        top->ALUCLK = top->UCLK = top->MCLK;

        /*
        top->CSALUI8 = (i & 1<<8)  != 0;
        top->CSALUI7 = (i & 1<<7)  != 0;
        top->CSALUM1 = (i & 1<<4)  != 0;
        top->CSALUM0 = (i & 1<<3)  != 0;        
        */


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




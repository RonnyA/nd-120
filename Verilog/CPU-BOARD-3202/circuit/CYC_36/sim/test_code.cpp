#define DO_TRACE
#include <iostream>
#include <vector>
#include <random>
#include <ctime>
#include <string>

#include "VCYC_36.h"
#include "verilated.h"

#ifdef DO_TRACE
#include <verilated_vcd_c.h>
#endif

// PAL testcases
struct TestCase {
    

    // Inputs

    // bool OSC;
    
    bool ACOND_n;              
    bool BRK_n;
    bool CGNTCACT_n;
    bool CSALUI7;
    bool CSALUI8;
    bool CSALUM0;
    bool CSALUM1;
    uint8_t CSDELAY_1_0;
    
    bool CSDLY;
    bool CSECOND;
    bool CSLOOP;
    bool FORM_n;
    bool HIT;
    bool IORQ_n;
    bool LBA0;
    bool LBA1;
    bool LBA3;               
    bool LSHADOW;
    bool LUA12;
    bool MREQ_n;
    bool MR_n;    
    bool PD1;
    bool PD4;
    bool RRF_n;
    bool RT_n;
    bool RWCS_n;
    bool SHORT_n;
    bool SLOW_n;               
    bool TRAP_n;               
    bool VEX;
    
    // Outputs
    bool ALUCLK;               
    bool CLK;               
    bool MACLK;
    bool MCLK;
    bool UCLK;
    bool WRFSTB;
    bool CYD;
    uint8_t  CC_3_1_n; // 3 bit
    bool TERM_n;
    bool MAP_n;
    bool CX_n;
    bool EORF_n;
    bool ETRAP_n;
    bool LCS_n;              
    
    

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
        {  true,  true,  true,  true,   true,     true,     true,    true,     true,    true,    true,   true,   true,    true,   true,    true,        true,       "Test 1"},
        {  false, true,  true,  true,   true,     true,     false,   true,     true,    true,    true,   true,   true,    true,   true,    true,        true,       "Test 2"}, // cgnt = 0
        {  false, true,  true,  true,   true,     true,     true,    true,     false,   true,    true,   true,   true,    true,   true,    true,        true,       "Test 3"}, // cact = 0
        {  false, true,  true,  true,   true,     true,     true,    true,     true,    true,    false,  true,   true,    true,   true,    true,        true,       "Test 4"}, // bgnt = 0
        {  false, true,  true,  true,   true,     true,     true,    true,     true,    true,    true,   true,   true,    true,   true,    true,        true,       "Test 5"},
    };





    Verilated::commandArgs(argc, argv);
    VCYC_36* top = new VCYC_36;

#ifdef DO_TRACE
    VerilatedVcdC *m_trace = new VerilatedVcdC;    
    Verilated::traceEverOn(true);
    top->trace(m_trace, 1); // 1 is the trace depth
    m_trace->open("waveform.vcd");
#endif
    




    int errCnt = 0;

   // Default Assignments for input fields
    top->PD1 = top->PD4 = 0; // Enable PD1 and PD4 (output enable)

    top->ACOND_n =             
    top->BRK_n =
    top->CGNTCACT_n = true;

    top->CSDELAY_1_0 = 0;


    top->CSALUI7 = 
    top->CSALUI8 = 
    top->CSALUM0 = 
    top->CSALUM1 = 
    top->CSDLY = 
    top->CSECOND = 
    top->CSLOOP = false;

    top->FORM_n = true;

    top->HIT = false;

    top->IORQ_n = true;

    top->LBA0 = 
    top->LBA1 =
    top->LBA3 =          
    top->LSHADOW =
    top->LUA12 = false;

    top->MREQ_n = 
    top->MR_n = true;

    top->OSC = 
    top->PD1 =
    top->PD4 = false;
    top->RRF_n =
    top->RT_n = 
    top->RWCS_n =
    top->SHORT_n =
    top->SLOW_n =               
    top->TRAP_n = true;             
    top->VEX = false;

    // Iterate through each test case
    //for (const auto& test : testCases) {
    //    std::cout << "Running " << test.description << std::endl;

    // Master Reset

    top->MR_n = false;

    bool clk_has_been_high =false;

    for (int i=0; i<4096; i++)
    {
        top->OSC = !top->OSC; // Toggle OSC

        top->CSALUI8 = (i & 1<<8)  != 0;
        top->CSALUI7 = (i & 1<<7)  != 0;
        top->CSALUM1 = (i & 1<<4)  != 0;
        top->CSALUM0 = (i & 1<<3)  != 0;        


        
        

        if (i==4)
            top->MREQ_n = false;

        if (i > 40)
        {

            top->CSDELAY_1_0 = (i & 1<<4)  != 0;                    
        }

        if (i==50)
            top->MREQ_n = !top->MREQ_n;

        if (i==70)
            top->IORQ_n = false;

        if (i==150)
            top->IORQ_n = true;

        top->eval();


        if (top->CLK) clk_has_been_high= true;
        if ((!top->CLK) && (clk_has_been_high))
            top->MR_n =true; // keep "master reset" until CLK is toggled

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




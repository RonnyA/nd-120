#define DO_TRACE
#include <iostream>
#include <vector>
#include <random>
#include <ctime>
#include <string>

#include "VCGA_TRAP.h"
#include "verilated.h"

#ifdef DO_TRACE
#include <verilated_vcd_c.h>
#endif

// INTR testcases 
struct TestCase {
    //bool TCLK;
   uint8_t PCR_1_0;   
   uint8_t PT_15_9;

   bool CBRKN;
   bool DSTOPN;
   bool ETRAPN;
   bool FETCHN;
   bool FTRAPN;
   bool INDN;
   bool INTRQN;
   bool PANN;
   bool PONI;   
   bool VACCN;
   bool VTRAPN;
   bool WRITEN;

    /*----------------  EXPECTED OUTOUT ----------------------*/

   bool expected_BRKN;
   bool expected_PVIOL;
   bool expected_RESTR;
   bool expected_TRAPN;
   uint8_t expected_TVEC_3_0;

    /*--------------------------------------------*/
    std::string description; // Description of the test case
};


#define MAX_SIM_TIME 20
vluint64_t sim_time = 0;
vluint64_t time_step = 5;


int main(int argc, char **argv) 
{

  // Create a collection of test cases
std::vector<TestCase> testCases = {
    // PCR_1_0  PT_15_9  CBRKN  DSTOPN  ETRAPN  FETCHN  FTRAPN  INDN  INTRQN  PANN  PONI  VACCN  VTRAPN  WRITEN  expected_BRKN  expected_PVIOL  expected_RESTR  expected_TRAPN  expected_TVEC_3_0  Description
    {0,        0,       true,   true,   true,   true,   true,   true, true,   true, true, true,  true,   true,   true,           true,            true,            true,            0,                 "Test 1"},
    {0,        0,       true,   true,   true,   true,   true,   true, false,  true, true, true,  true,   true,   true,           true,            true,            true,            0,                 "Test 2"}, // INTRQN
    {0,        0,       true,   true,   true,   false,  true,   true, true,   true, true, true,  true,   true,   true,           true,            true,            true,            0,                 "Test 3"}, //FATCHN
    {0,        0,       false,  true,   true,   true,   true,   true, true,   true, true, true,  true,   true,   true,           true,            true,            true,            0,                 "Test 4"}, //CBRKN
};


    

    Verilated::commandArgs(argc, argv);
    VCGA_TRAP* top = new VCGA_TRAP;

#ifdef DO_TRACE
    VerilatedVcdC *m_trace = new VerilatedVcdC;    
    Verilated::traceEverOn(true);
    top->trace(m_trace, 1); // 1 is the trace depth
    m_trace->open("waveform.vcd");
#endif
    


    int errCnt = 0;
        // Iterate through each test case
    for (const auto& test : testCases) 
    {    
        printf("Running %s\r\n", test.description.c_str());
        
        // Set up your module inputs based on the test case
       
        // Assignments
        top->PCR_1_0 = test.PCR_1_0;
        top->PT_15_9 = test.PT_15_9;
        top->CBRKN = test.CBRKN;
        top->DSTOPN = test.DSTOPN;
        top->ETRAPN = test.ETRAPN;
        top->FETCHN = test.FETCHN;
        top->FTRAPN = test.FTRAPN;
        top->INDN = test.INDN;
        top->INTRQN = test.INTRQN;
        top->PANN = test.PANN;
        top->PONI = test.PONI;
        top->VACCN = test.VACCN;
        top->VTRAPN = test.VTRAPN;
        top->WRITEN = test.WRITEN;

        // Tick TCLK (Trap Clock ??)
        top->TCLK = 0;
        top->eval();

#ifdef DO_TRACE        
        m_trace->dump(sim_time);
        sim_time += time_step; // Increment simulation time
#endif


        top->TCLK = 1;
        top->eval();

#ifdef DO_TRACE        
        m_trace->dump(sim_time);
        sim_time += time_step; // Increment simulation time
#endif

#ifdef ___later___
        // Check the output against the expected values
        // Conditional checks for expected values
    // Conditional checks for expected values
        if (top->expected_BRKN != test.expected_BRKN) {
            printf("[%s] BRKN output does not match expected value\n", test.description.c_str());
            errCnt++;
        }

        if (top->expected_PVIOL != test.expected_PVIOL) {
            printf("[%s] PVIOL output does not match expected value\n", test.description.c_str());
            errCnt++;
        }

        if (top->expected_RESTR != test.expected_RESTR) {
            printf("[%s] RESTR output does not match expected value\n", test.description.c_str());
            errCnt++;
        }

        if (top->expected_TRAPN != test.expected_TRAPN) {
            printf("[%s] TRAPN output does not match expected value\n", test.description.c_str());
            errCnt++;
        }

        if (top->expected_TVEC_3_0 != test.expected_TVEC_3_0) {
            printf("[%s] TVEC_3_0 output: 0x%02x does not match expected 0x%02x\n", test.description.c_str(), top->expected_TVEC_3_0, test.expected_TVEC_3_0);
            errCnt++;
        }

      
#endif
        
        //if (errCnt>0) break; // exit for loop
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




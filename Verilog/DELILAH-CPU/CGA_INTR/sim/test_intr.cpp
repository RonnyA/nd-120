#define DO_TRACE
#include <iostream>
#include <vector>
#include <random>
#include <ctime>
#include <string>

#include "VCGA_INTR.h"
#include "verilated.h"

#ifdef DO_TRACE
#include <verilated_vcd_c.h>
#endif

// INTR testcases 
struct TestCase {

    //bool MCLK;
    bool PANN;

    bool EMPIDN;
    bool BINT15N;
    bool POWFAILN;
    bool NORN;
    bool PARERRN;
    bool IOXERRN;
    bool Z;
    bool BINT13N;
    bool BINT12N;
    bool BINT11N;
    bool BINT10N;
    
    uint16_t FIDBO_15_0;
    uint8_t LAA_3_0;
    bool EPIC;
    bool CLIRQN;



    /*----------------  EXPECTED OUTOUT ----------------------*/
    bool expected_PD;
    bool expected_EPICMASKN;
    bool expected_HIGSN;
    bool expected_INTRQN;
    bool expected_IRQ;
    bool expected_LOGSN;
    
    
    uint16_t expected_PICMASK_15_0;
    uint8_t expected_PICS_2_0;
    uint8_t expected_PICV_2_0;
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
      // PANN   EMPIDN  BINT15N  POWFAILN  NORN   PARERRN  IOXERRN  Z      BINT13N  BINT12N  BINT11N  BINT10N  FIDBO_15_0  LAA_3_0  EPIC     CLIRQN  expected_PD  expected_EPICMASKN  expected_HIGSN  expected_INTRQN  expected_IRQ  expected_LOGSN  expected_PICMASK_15_0  expected_PICS_2_0  expected_PICV_2_0  Description
        {false, true,   true,    true,     true,  true,    true,    true,  true,    true,    true,    true,    0,          0,       false,   false,  false,       true,               true,           true,            false,        true,           0,                     0,                 0,                 "Test 1"}, // INIT, clearirq
        {false, true,   true,    true,     true,  true,    true,    true,  false,   true,    true,    true,    0,          0,       false,   true,   false,       true,               true,           true,            false,        true,           0,                     0,                 0,                 "Test 2"}, // INT13
        {false, true,   true,    true,     true,  true,    true,    true,  true,    true,    true,    true,    0,          0,       false,   false,  false,       true,               true,           true,            false,        true,           0,                     0,                 0,                 "Test 3"}, // CLRIRQN
        {false, true,   true,    true,     true,  true,    true,    false, true,    true,    true,    true,    0,          0,       false,   true,   false,       true,               true,           true,            false,        true,           0,                     0,                 0,                 "Test 4"} // Z interrupt
    };


    

    Verilated::commandArgs(argc, argv);
    VCGA_INTR* top = new VCGA_INTR;

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
        top->PANN = test.PANN;
        top->EMPIDN = test.EMPIDN;
        top->BINT15N = test.BINT15N;
        top->POWFAILN = test.POWFAILN;
        top->NORN = test.NORN;
        top->PARERRN = test.PARERRN;
        top->IOXERRN = test.IOXERRN;
        top->Z = test.Z;
        top->BINT13N = test.BINT13N;
        top->BINT12N = test.BINT12N;
        top->BINT11N = test.BINT11N;
        top->BINT10N = test.BINT10N;
        top->FIDBO_15_0 = test.FIDBO_15_0;
        top->LAA_3_0 = test.LAA_3_0;
        top->EPIC = test.EPIC;
        top->CLIRQN = test.CLIRQN;


        // Tick MCLK
        top->MCLK = 0;
        top->eval();

#ifdef DO_TRACE        
        m_trace->dump(sim_time);
        sim_time += time_step; // Increment simulation time
#endif


        top->MCLK = 1;
        top->eval();

#ifdef DO_TRACE        
        m_trace->dump(sim_time);
        sim_time += time_step; // Increment simulation time
#endif

#ifdef ___later___
        // Check the output against the expected values
        // Conditional checks for expected values
        if (top->expected_PD != test.expected_PD) {
            printf("[%s] PD output does not match expected value\n", test.description.c_str());
            errCnt++;
        }

        if (top->expected_EPICMASKN != test.expected_EPICMASKN) {
            printf("[%s] EPICMASKN output does not match expected value\n", test.description.c_str());
            errCnt++;
        }

        if (top->expected_HIGSN != test.expected_HIGSN) {
            printf("[%s] HIGSN output does not match expected value\n", test.description.c_str());
            errCnt++;
        }

        if (top->expected_INTRQN != test.expected_INTRQN) {
            printf("[%s] INTRQN output does not match expected value\n", test.description.c_str());
            errCnt++;
        }

        if (top->expected_IRQ != test.expected_IRQ) {
            printf("[%s] IRQ output does not match expected value\n", test.description.c_str());
            errCnt++;
        }

        if (top->expected_LOGSN != test.expected_LOGSN) {
            printf("[%s] LOGSN output does not match expected value\n", test.description.c_str());
            errCnt++;
        }

        if (top->expected_PICMASK_15_0 != test.expected_PICMASK_15_0) {
            printf("[%s] PICMASK_15_0 output: 0x%04x does not match expected 0x%04x\n", test.description.c_str(), top->expected_PICMASK_15_0, test.expected_PICMASK_15_0);
            errCnt++;
        }

        if (top->expected_PICS_2_0 != test.expected_PICS_2_0) {
            printf("[%s] PICS_2_0 output: 0x%02x does not match expected 0x%02x\n", test.description.c_str(), top->expected_PICS_2_0, test.expected_PICS_2_0);
            errCnt++;
        }

        if (top->expected_PICV_2_0 != test.expected_PICV_2_0) {
            printf("[%s] PICV_2_0 output: 0x%02x does not match expected 0x%02x\n", test.description.c_str(), top->expected_PICV_2_0, test.expected_PICV_2_0);
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




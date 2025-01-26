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
struct TestCase
{

    // Inputs
    bool BINT10N;        //! Bus Interrupt 10, active low
    bool BINT11N;        //! Bus Interrupt 11, active low
    bool BINT12N;        //! Bus Interrupt 12, active low
    bool BINT13N;        //! Bus Interrupt 13, active low
    bool BINT15N;        //! Bus Interrupt 15, active low
    bool CLIRQN;         //! Clear Interrupt Request, active low
    bool EMPIDN;         //! EMP Interrupt Disable, active low
    bool EPIC;           //! Enable PIC (Programmable Interrupt Controller) signal
    uint16_t FIDBO_15_0; //! FIDB , 16-bit
    bool IOXERRN;        //! IO Exception Error, active low
    uint8_t LAA_3_0;     //! Latched Address A, 4-bit
    bool MCLK;           //! Master Clock
    bool MORN;           //! MOR signal, active low (Memory Error)
    bool PANN;           //! PAN signal, active low (Panel Interrupt)
    bool PARERRN;        //! Parity Error, active low
    bool POWFAILN;       //! Power Failure, active low
    bool Z;              //! Error flag from ALU

    // Outputs
    bool EPICMASKN;        //! EPIC Mask, active low
    bool HIGSN;            //! High Speed signal, active low
    bool INTRQN;           //! Interrupt Request, active low
    bool IRQ;              //! Interrupt Request
    bool LOGSN;            //! Logical Segment Number, active low
    bool PD;               //! Power Down signal
    uint16_t PICMASK_15_0; //! PIC Mask, 16-bit
    uint8_t PICS_2_0;      //! PIC Select, 3-bit
    uint8_t PICV_2_0;      //! PIC Vector, 3-bit

    /*----------------  EXPECTED OUTOUT ----------------------*/
    /*
    bool expected_PD;
    bool expected_EPICMASKN;
    bool expected_HIGSN;
    bool expected_INTRQN;
    bool expected_IRQ;
    bool expected_LOGSN;


    uint16_t expected_PICMASK_15_0;
    uint8_t expected_PICS_2_0;
    uint8_t expected_PICV_2_0;
    */
    /*--------------------------------------------*/

    std::string description; // Description of the test case
};

#define MAX_SIM_TIME 20
vluint64_t sim_time = 0;
vluint64_t time_step = 5;

int main(int argc, char **argv)
{

    // Create a collection of test cases
    /*
      std::vector<TestCase> testCases = {
        // PANN   EMPIDN  BINT15N  POWFAILN  NORN   PARERRN  IOXERRN  Z      BINT13N  BINT12N  BINT11N  BINT10N  FIDBO_15_0  LAA_3_0  EPIC     CLIRQN  expected_PD  expected_EPICMASKN  expected_HIGSN  expected_INTRQN  expected_IRQ  expected_LOGSN  expected_PICMASK_15_0  expected_PICS_2_0  expected_PICV_2_0  Description
          {false, true,   true,    true,     true,  true,    true,    true,  true,    true,    true,    true,    0,          0,       false,   false,  false,       true,               true,           true,            false,        true,           0,                     0,                 0,                 "Test 1"}, // INIT, clearirq
          {false, true,   true,    true,     true,  true,    true,    true,  false,   true,    true,    true,    0,          0,       false,   true,   false,       true,               true,           true,            false,        true,           0,                     0,                 0,                 "Test 2"}, // INT13
          {false, true,   true,    true,     true,  true,    true,    true,  true,    true,    true,    true,    0,          0,       false,   false,  false,       true,               true,           true,            false,        true,           0,                     0,                 0,                 "Test 3"}, // CLRIRQN
          {false, true,   true,    true,     true,  true,    true,    false, true,    true,    true,    true,    0,          0,       false,   true,   false,       true,               true,           true,            false,        true,           0,                     0,                 0,                 "Test 4"} // Z interrupt

      };

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

          ++tick and log + check output
      }

  */

    Verilated::commandArgs(argc, argv);
    VCGA_INTR *top = new VCGA_INTR;

    // Set default values for input

    top->BINT10N = 1;
    top->BINT11N = 1;
    top->BINT12N = 1;
    top->BINT13N = 1;
    top->BINT15N = 1;
    top->CLIRQN = 1;
    top->EMPIDN = 1;

    top->EPIC = 0;
    top->FIDBO_15_0 = 0;
    top->IOXERRN = 1;
    top->LAA_3_0 = 0;

    top->MORN = 1;
    top->PANN = 1;
    top->PARERRN = 1;
    top->POWFAILN = 1;
    top->Z = 0;

    top->MCLK = 0;
#ifdef DO_TRACE
    VerilatedVcdC *m_trace = new VerilatedVcdC;
    Verilated::traceEverOn(true);
    top->trace(m_trace, 1); // 1 is the trace depth
    m_trace->open("waveform.vcd");
#endif

    int errCnt = 0;
    // Iterate through each test case
    for (int i = 0; i < 100; i++)
    {
        // Set up your module inputs based on the test case

        switch (i)
        {

        // Clear CHIP
        case 2:
            top->EPIC = 1;
            top->LAA_3_0 = 0; // MCLR clear regs and enable ints
            break;
        case 3:
            top->EPIC = 0;
            break;

        // Enable interrupt 15
        case 6:
            top->BINT15N = 0;
            break;

        case 7:
            top->BINT15N = 1;
            break;

        // Enable interrupt 13
        
        case 10:
            top->BINT13N = 0;
            break;

        case 11:
            top->BINT13N = 1;
            break;

        // RDVECT
        case 20:
            top->EPIC = 1;
            top->LAA_3_0 = 5; // 5=RDVECT (Read vector)
            break;
        case 21:
            top->EPIC = 0;
            top->LAA_3_0 = 0;
            break;

        // RDSTAT
        case 30:
            top->EPIC = 1;
            top->LAA_3_0 = 6; // 6=RDSTAT (read status register)
            break;
        case 31:
            top->EPIC = 0;
            top->LAA_3_0 = 0;
            break;


        //*************MORN**************************

       // Clear CHIP
        case 40:
            top->EPIC = 1;
            top->LAA_3_0 = 0; // MCLR clear regs and enable ints
            break;
        case 41:
            top->EPIC = 0;
            break;


          // Enable interrupt 15
        case 43:
            top->MORN = 0;
            break;

        case 44:
            top->MORN = 1;
            break;

        // RDVECT
        case 46:
            top->EPIC = 1;
            top->LAA_3_0 = 5; // 5=RDVECT (Read vector)
            break;
        case 47:
            top->EPIC = 0;
            top->LAA_3_0 = 0; 
            break;

        
        case 48:
            top->MORN = 0;
            break;

        case 49:
            top->MORN = 1;
            break;

        // RDVECT
        case 52:
            top->EPIC = 1;
            top->LAA_3_0 = 5; // 5=RDVECT (Read vector)
            break;
        case 53:
            top->EPIC = 0;
            top->LAA_3_0 = 0;
            break;
        }

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
        if (top->expected_PD != test.expected_PD)
        {
            printf("[%s] PD output does not match expected value\n", test.description.c_str());
            errCnt++;
        }

        if (top->expected_EPICMASKN != test.expected_EPICMASKN)
        {
            printf("[%s] EPICMASKN output does not match expected value\n", test.description.c_str());
            errCnt++;
        }

        if (top->expected_HIGSN != test.expected_HIGSN)
        {
            printf("[%s] HIGSN output does not match expected value\n", test.description.c_str());
            errCnt++;
        }

        if (top->expected_INTRQN != test.expected_INTRQN)
        {
            printf("[%s] INTRQN output does not match expected value\n", test.description.c_str());
            errCnt++;
        }

        if (top->expected_IRQ != test.expected_IRQ)
        {
            printf("[%s] IRQ output does not match expected value\n", test.description.c_str());
            errCnt++;
        }

        if (top->expected_LOGSN != test.expected_LOGSN)
        {
            printf("[%s] LOGSN output does not match expected value\n", test.description.c_str());
            errCnt++;
        }

        if (top->expected_PICMASK_15_0 != test.expected_PICMASK_15_0)
        {
            printf("[%s] PICMASK_15_0 output: 0x%04x does not match expected 0x%04x\n", test.description.c_str(), top->expected_PICMASK_15_0, test.expected_PICMASK_15_0);
            errCnt++;
        }

        if (top->expected_PICS_2_0 != test.expected_PICS_2_0)
        {
            printf("[%s] PICS_2_0 output: 0x%02x does not match expected 0x%02x\n", test.description.c_str(), top->expected_PICS_2_0, test.expected_PICS_2_0);
            errCnt++;
        }

        if (top->expected_PICV_2_0 != test.expected_PICV_2_0)
        {
            printf("[%s] PICV_2_0 output: 0x%02x does not match expected 0x%02x\n", test.description.c_str(), top->expected_PICV_2_0, test.expected_PICV_2_0);
            errCnt++;
        }
#endif

        // if (errCnt>0) break; // exit for loop
    }

    if (errCnt == 0)
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

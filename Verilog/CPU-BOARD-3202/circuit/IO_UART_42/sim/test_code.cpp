#define DO_TRACE
#include <iostream>
#include <vector>
#include <random>
#include <ctime>
#include <string>

#include "VIO_UART_42.h"
#include "verilated.h"

#ifdef DO_TRACE
#include <verilated_vcd_c.h>
#endif

// PAL testcases
struct TestCase {

   // Input signals
   bool        CEUART_n;
   bool        CLK;
   bool        CONSOLE_n;
   bool        EAUTO_n;
   bool        EIOR_n;
   
   bool        LCS_n;
   bool        LOCK_n;
   uint8_t     MIS_1_0; // 2bit
   bool        PPOSC;
   bool        RUART_n;

   bool        XTR;

// Baud rate settings
   uint8_t     BAUD_RATE_SWITCH; // input (5 bits)


   // RS232 RX/TX signals
   bool        RXD;  // input
   bool        TXD;          

   // Current loop signals
   bool        I1P;  // input
   bool        O1P;   // output
   bool        O2P;   // output

   
   // Output and Input signals
   uint16_t    IDB_15_0_IN; // input
   uint16_t    IDB_15_0_OUT; // output

   // Output signals
   bool        DA_n;
   bool        TBMT_n;

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
    VIO_UART_42* top = new VIO_UART_42;

    
// Set default values


    top->MIS_1_0 = 0;
    
    top->CEUART_n =    
    top->CONSOLE_n =
    top->EAUTO_n =
    top->EIOR_n = 
    top->LCS_n =
    top->LOCK_n =   
    top->PPOSC =
    top->RUART_n =
    top->XTR = true;

    top->BAUD_RATE_SWITCH = 0b1010; // input (4 bits)

    top->CLK =0;
    top->PPOSC = 0;
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
    for (int i=0; i<30; i++)
    {               
        if (i==2)
        {
            top->EIOR_n = false; // read IO port
        }

        if (i==5)
        {
            top->EIOR_n =true; // disable read IO port
        }

        // Write to UART command
        if (i==6)
        {
            top->MIS_1_0 = 0b11; // write to UART command register
            top->IDB_7_0_IN = 0xA5;
            top->CEUART_n = false; // enable UART
            top->RUART_n = true; // write UART
        }


        if (i==7)
        {
            top->MIS_1_0 = 0b11; // write to UART command register
            top->IDB_7_0_IN = 0xFF;
            top->CEUART_n = false; // enable UART
            top->RUART_n = false; // read UART
        }

        if (i==8)
        {
            top->MIS_1_0 = 0b11; // write to UART command register
            top->IDB_7_0_IN = 0;
            top->CEUART_n = true; // disable UART
            top->RUART_n = false; // read UART
        }
        


        if (i==10)
        {
            top->CEUART_n = false; // enable UART
            top->RUART_n = false; // read UART
        }

        if (i==15)
        {
            top->CEUART_n = false; // disable UART
        }

        if (i==17)
        {
            top->CONSOLE_n = false; // enable console
        }


        if (i==20)
        {  
            // test what happens when both chips are enabled
            top->EIOR_n = false; // read IO port
            top->CEUART_n = false; // read UART
        }

        top->eval();
#ifdef DO_TRACE        
        m_trace->dump(sim_time);
        sim_time += time_step; // Increment simulation time
#endif


        // Tick clock
        top->CLK = !top->CLK;
        top->PPOSC = !top->PPOSC;

        top->eval();
#ifdef DO_TRACE        
        m_trace->dump(sim_time);
        sim_time += time_step; // Increment simulation time
#endif
        // Tick clock
        top->CLK = !top->CLK;
        top->PPOSC = !top->PPOSC;


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




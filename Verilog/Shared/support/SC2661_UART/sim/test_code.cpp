#define DO_TRACE
#include <iostream>
#include <vector>
#include <random>
#include <ctime>
#include <string>

#include "VSC2661_UART.h"
#include "verilated.h"

#ifdef DO_TRACE
#include <verilated_vcd_c.h>
#endif

// PAL testcases
struct TestCase {
    
   /*******************************************************************************
   ** The inputs are defined here                                                **
   *******************************************************************************/
   bool A0;
   bool A1;
   bool BRCLK;
   bool CE_n;
   bool CTS_n;
   bool DCD_n;
   bool DSR_n;
   bool READ_n;
   bool RESET;
   bool RXC_n;
   bool RXD;
   bool TXC_n;
   

   /*******************************************************************************
   ** The inout are defined here                                                **
   *******************************************************************************/

   uint8_t    D_7_0;
   
   /*******************************************************************************
   ** The outputs are defined here                                               **
   *******************************************************************************/

   bool       DTR_n;   
   bool       RTS_n;
   bool       RXDRDY_n;
   bool       TXD;
   bool       TXDRDY_n;
   bool       TXEMT_n;

 
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
    VSC2661_UART* top = new VSC2661_UART;
    

#ifdef DO_TRACE
    VerilatedVcdC *m_trace = new VerilatedVcdC;    
    Verilated::traceEverOn(true);
    top->trace(m_trace, 2); // 1 is the trace depth
    m_trace->open("waveform.vcd");
#endif
    


    int errCnt = 0;

    top->A0 =
    top->A1 =
    top->BRCLK = // Baud rate clock
    top->RESET = 0;

    
    top->CE_n =
    top->CTS_n =
    top->DCD_n =
    top->DSR_n =
    top->READ_n =    
    top->RXC_n =
    top->RXD = 
    top->TXC_n = true;
   
    

    // Iterate through each test case
    //for (const auto& test : testCases) {
    //    std::cout << "Running " << test.description << std::endl;



    for (int ck =0;ck<512;ck++)
    {
                


#ifdef DO_TRACE        
        m_trace->dump(sim_time);
        sim_time += time_step; // Increment simulation time
#endif


        top->eval();
        
        top->BRCLK = !top->BRCLK;


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




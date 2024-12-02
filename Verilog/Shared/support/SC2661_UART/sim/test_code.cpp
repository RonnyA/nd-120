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

   uint8_t    D;
   uint8_t    D_OUT;
   
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

    top->ADDRESS =    
    top->BRCLK = // Baud rate clock
    top->RESET = 0;

    top->sys_rst_n = 1; //no FPGA system reset signal just yet...
    
    top->CE_n =
    top->CTS_n =
    top->DCD_n =
    top->DSR_n =    
    top->RXC_n =
    top->RXD = 
    top->TXC_n = true;
   
    top->READ_n = false; // default to read

    // Iterate through each test case
    //for (const auto& test : testCases) {
    //    std::cout << "Running " << test.description << std::endl;

    uint8_t transmitChars = 5;

    uint8_t clearChipAccess =0; // number of cycles until clear chip access
    int transmitAt = 10;
    int readtAt = 10000;

    uint8_t txData = 0xA0;

    for (int ck =0;ck<1000;ck++)
    {

        // loop data back to receiver
        //top->RXD  = top->TXD;

        // Reset chip
        if (ck==0)
        {
            top->RESET = 1;
        }
        if (ck==3)
        {
            top->RESET = 0;
        }



        if (clearChipAccess>0)
        {
            clearChipAccess--;
            if (clearChipAccess == 0)
            {
                clearChipAccess = false;
                top->CE_n = 1; // not enabled
                top->READ_n = 0; //Read
                top->ADDRESS = 0;       
                top->D = 0;        
            }
        }

        // Enable Read received data
        if ((top->RXDRDY_n==0) && (ck>5))
        {
            top->CE_n = 0;
            top->READ_n = 0; //Read
            top->ADDRESS = 0;      
            readtAt = ck +1; // Read the data output from the chip one cycle later
        }        

        // Read received data from UART.
        if (ck==readtAt)
        {
            uint8_t  data = top->D_OUT;
            printf("Received data %x  (ck=%d)\r\n",data,ck);
            if (transmitChars>0)
            {
                transmitChars--;
                transmitAt = ck +10;                
            } else  
                break; // exit for loop

            clearChipAccess = 1;
        }


    
        if (ck==6)
        {
            top->ADDRESS = 3; //Command Register
            top->READ_n = 1; //write
            //top->D = 0b00111111; // Normal operation
            top->D = 0b10111111; // Local loopback (The transmitter output is connected to the receiver input.)
            //top->D = 0b11111111; // Remote loopback

            top->CE_n = 0;
            clearChipAccess = 1;
        }


        // trigger transmit transmit
        if (ck==transmitAt)
        {
            top->ADDRESS = 0;
            top->READ_n = 1; //write
            top->D = txData;
            txData++;
            top->CE_n = 0;
            clearChipAccess = 1;            
        }


        if (ck==1000)
        {
            top->ADDRESS = 0;
            top->READ_n = 1; //write
            top->D = 0x8F;
            top->CE_n = 0;
            clearChipAccess = 1;
        }

        
        top->BRCLK = !top->BRCLK;
        top->sysclk = top->BRCLK;
        top->eval();                
        
#ifdef DO_TRACE        
        m_trace->dump(sim_time);
        sim_time += time_step; // Increment simulation time
#endif


        top->BRCLK = !top->BRCLK;
        top->sysclk = top->BRCLK;
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




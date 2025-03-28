#define DO_TRACE
#include <iostream>
#include <vector>
#include <random>
#include <ctime>
#include <string>

#include "VCPU_CS_TCV_20.h"
#include "verilated.h"

#ifdef DO_TRACE
#include <verilated_vcd_c.h>
#endif

// PAL testcases
struct TestCase {
    
   /*******************************************************************************
   ** The inputs are defined here                                                **
   *******************************************************************************/
    uint64_t    CSBITS;
    uint16_t    IDB_15_0_IN;
    bool        ECSL_n;
    bool        WCS_n;
    uint8_t     EW_3_0_n; // output enable signals        

   /*******************************************************************************
   ** The outputs are defined here                                               **
   *******************************************************************************/
   
   uint16_t IDB_15_0_OUT;
   uint64_t CSBITS_OUT;  
    
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
    VCPU_CS_TCV_20* top = new VCPU_CS_TCV_20;
    
    // Set default values     
    top->ECSL_n =false;
    top->WCS_n = false;
    top->EW_3_0_n = 0xF;

#ifdef DO_TRACE
    VerilatedVcdC *m_trace = new VerilatedVcdC;    
    Verilated::traceEverOn(true);
    top->trace(m_trace, 2); // 1 is the trace depth
    m_trace->open("waveform.vcd");
#endif
    


    int errCnt = 0;

    bool testflip = false;
    top->eval();

    // Iterate through each test case
    //for (const auto& test : testCases) {
    //    std::cout << "Running " << test.description << std::endl;

    int rf = 0;
    int cnt=0;

    for (int j=1; j<512; j++)
    {
        for (int e=0;e<4;e++)        
        {
            // Cycle e=0 => Write to internal 64 bit from IDB
            // Cycle e=1 => Read from internal 64 bit to CSBITS
            // Cycle e=2 => Disconnected
            top->ECSL_n = (e==1); // read out on idb
            top->WCS_n  = (e!=0); // read out on idb
            

            
            for (int b=0;b<4;b++)    
            {
                top->CSBITS = 0;                    
                top->CSBITS |= 0x1111; 
                top->CSBITS |= 0x2222L<<16L;
                top->CSBITS |= 0x3333L<<32L;
                top->CSBITS |= 0x4444L<<48L;

                top->IDB_15_0_IN = (j*0xA1D0)+b;


                if (e==0)  // WRITE
                {
                    top->ECSL_n = true; // Disable output
                    top->WCS_n = false; // Enable write

                    top->EW_3_0_n = 0xF & ~(1<<b);
                    //top->CSBITS = 0xFACECAFEDEADBEEF;

                }
                else if (e==1) // READ TO CSBITS
                {
                    top->ECSL_n = false; // Enable output
                    top->WCS_n = false; // Disable write
                    top->EW_3_0_n = 0xFF;
                }
                else if (e==2) //READ TO IDB
                {
                    top->EW_3_0_n = 0xF & ~(1<<b);                    
                    top->WCS_n = true; // Disable write                    
                } 
                else if (e==3) // DISCONNECT
                {
                    top->ECSL_n = true; // Disable output
                    top->EW_3_0_n = 0xF & ~(1<<b);
                }

                

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




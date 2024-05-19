#define DO_TRACE
#include <iostream>
#include <vector>
#include <random>
#include <ctime>
#include <string>

#include "VIO_REG_41.h"
#include "verilated.h"

#ifdef DO_TRACE
#include <verilated_vcd_c.h>
#endif

// PAL testcases
struct TestCase {

   // Input signals
   uint8_t    INR_7_0;

   bool       CLEAR_n;
   bool       CX_n;
   bool       DA_n;   
   bool       RINR_n;
   bool       SIOC_n;
   bool       TBMT_n;
   bool       TRAALD_n;

   // Output and Input signals
   uint8_t    IDB_7_0_IN; // input
   uint16_t   IDB_15_0_OUT; // output

   // Output signals
   bool       BINT10_n;
   bool       BINT12_n;
   bool       BINT13_n;
   bool       CONSOLE_n;
   bool       EMCL_n;
   uint8_t    IOLED; // 2 bits=> 0=RED;1=GREEN   

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
    VIO_REG_41* top = new VIO_REG_41;

    
// Set default values


   top->IDB_7_0_IN = 0;
   top->INR_7_0 = 0;

   top->CLEAR_n =
   top->CX_n  =
   top->DA_n = 
   top->RINR_n =
   top->SIOC_n =
   top->TBMT_n =
   top->TRAALD_n = true;



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
               top->IDB_7_0_IN = 0xFF;
               top->INR_7_0 = 0xA7;
        }

        if (i==3)
        {
            
            top->SIOC_n = false;  // latch chip 28A
        }       

        if (i==4)
        {
            
            top->SIOC_n = true;
        }       


        if (i==10)
        {            
            top->RINR_n = false; // read INR port
        }


        if (i==12)
        {
            top->RINR_n = true;
        }

        if (i==15)
        {            
            top->TRAALD_n = false; // read ALD port
        }


        if (i==17)
        {
            top->TRAALD_n = true;
        }


        if (i==18)
        {
            top->TRAALD_n = false; // read ALD port
            top->RINR_n = false; // read INR port
        }

        if (i==19)
        {
            top->TRAALD_n = true;
            top->RINR_n = true;
        }


        if (i==20)
        {
            top->CLEAR_n = false; // clear all registers in Chip 28A
        }

        if (i==21)
        {
            top->CLEAR_n = true; // stop clear 
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




#define DO_TRACE
#include <iostream>
#include <vector>
#include <random>
#include <ctime>
#include <string>

#include "VCPU_MMU_PPNX_28.h"
#include "verilated.h"

#ifdef DO_TRACE
#include <verilated_vcd_c.h>
#endif

// PAL testcases
struct TestCase {
    
    // Inputs
   bool EIPL_n;
   bool EIPUR_n;
   bool EIPU_n;
   bool ESTOF_n;

   //inout

   uint16_t IDB_15_0;
   uint16_t PPN_25_10;

   // Outputs
   
   bool      WCINH_n;
    
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
    VCPU_MMU_PPNX_28* top = new VCPU_MMU_PPNX_28;
    
// Set default values
   top->IDB_15_0 = 0x0;
   top->PPN_25_10 = 0x0;

   top->EIPL_n = true;
   top->EIPUR_n = true;
   top->EIPU_n = true;
   top->ESTOF_n = true;

   
#ifdef DO_TRACE
    VerilatedVcdC *m_trace = new VerilatedVcdC;    
    Verilated::traceEverOn(true);
    top->trace(m_trace, 2); // 1 is the trace depth
    m_trace->open("waveform.vcd");
#endif
    


    int errCnt = 0;
    top->eval();

    // Iterate through each test case
    //for (const auto& test : testCases) {
    //    std::cout << "Running " << test.description << std::endl;

    for (int j=0; j<2; j++)
    {
        top->ESTOF_n = (j==0); // DIR!
        //top->EIPUR_n = false;
        
        top->EIPU_n = false;
        top->EIPL_n = false;

        for (int i=0x0; i<=0xF; i++)
        {                          
            
            if (top->ESTOF_n == 1)  // PPN->IDB
            {
                top->PPN_25_10 = 0xE010+i;
                top->IDB_15_0 =  0xC121+i;
            }
            else  // IDB->PPN   
            {
                top->IDB_15_0 = 0xA110 +i;
                top->PPN_25_10 = 0xB051 +i;
                
            }

            if (i==0x5)   
                top->EIPUR_n = false; // enable - clear high 7 bits

            if (i==0x8)   
                top->EIPUR_n = true; // disble - clear high 7 bits


            if (i==0x7)
            {
                top->EIPU_n = true;
            }

            if (i==0xB)
            {
                top->EIPL_n = true;
            }

            if (i==0xC)
            {
                top->EIPL_n = false;
            }

            if (i==0xE)
            {
                top->EIPU_n = false;
            }


        top->eval();
        

#ifdef DO_TRACE        
        m_trace->dump(sim_time);
        sim_time += time_step; // Increment simulation time
#endif
        }



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




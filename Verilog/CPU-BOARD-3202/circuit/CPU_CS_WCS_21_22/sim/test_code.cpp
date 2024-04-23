#define DO_TRACE
#include <iostream>
#include <vector>
#include <random>
#include <ctime>
#include <string>

#include "VCPU_CS_WCS_21_22.h"
#include "verilated.h"

#ifdef DO_TRACE
#include <verilated_vcd_c.h>
#endif

// PAL testcases
struct TestCase {
    
   /*******************************************************************************
   ** The inputs are defined here                                                **
   *******************************************************************************/

    uint16_t    UUA_11_0;
    bool        EUPP_n; // Enable UUA RAM chips
    bool        WU0_n; // Enable write for UUA bits 15-0
    bool        WU1_n; // Enable write for UUA bits 31-16
    bool        WU2_n; // Enable write for UUA bits 47-632
    bool        WU3_n; // Enable write for UUA bits 63-48
    
    uint16_t    LUA_11_0;
    bool        ELOW_n; // Enable LUA RAM chips
    bool        WW0_n; // Enable write for LUA bits 15-0
    bool        WW1_n; // Enable write for LUA bits 31-16
    bool        WW2_n; // Enable write for LUA bits 47-32
    bool        WW3_n; // Enable write for LUA bits 63-48

            

   /*******************************************************************************
   ** The IN and outputs are defined here                                        **
   *******************************************************************************/

    uint64_t CSBITS_63_0; // IN and OUT 

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
    VCPU_CS_WCS_21_22* top = new VCPU_CS_WCS_21_22;
    
    // Set default values     
   

#ifdef DO_TRACE
    VerilatedVcdC *m_trace = new VerilatedVcdC;    
    Verilated::traceEverOn(true);
    top->trace(m_trace, 2); // 1 is the trace depth
    m_trace->open("waveform.vcd");
#endif

    int errCnt = 0;

    
    top->WU0_n = top->WU1_n = top->WU2_n = top->WU3_n = 1; // DISABLE UUA WRITE
    top->WW0_n = top->WW1_n = top->WW2_n = top->WW3_n = 1; // DISABLE LUA WRITE

    // Iterate through each test case
    //for (const auto& test : testCases) {
    //    std::cout << "Running " << test.description << std::endl;

    // Test code writes 32 addressed to LUA and UUA. Output values while both are selected will be from LUA
    // Then reads the contents of UUA, 32 addresses

    bool write_phase;
    
    top->sys_rst_n = true; // Assert disabled
    top->sysclk = 0;
    top->eval();

    
#ifdef DO_TRACE        
        m_trace->dump(sim_time);
        sim_time += time_step; // Increment simulation time
#endif

    for (int x=0;x<3;x++)
    {
        write_phase = (x==0);

        if (write_phase) // Write phase
        {
            top->EUPP_n = false; // ENABLE UUA RAM
            top->ELOW_n = false;  // ENABLE LUA RAM
        }
        else
        {
            top->EUPP_n = false; // ENABLE UUA RAM
            top->ELOW_n = true;  // DISABLE  LUA RAM
        }


        for(int i=0;i<32;i++)
        {
            top->WU0_n = top->WU1_n = top->WU2_n = top->WU3_n = 1; // DISABLE UUA WRITE
            top->WW0_n = top->WW1_n = top->WW2_n = top->WW3_n = 1; // DISABLE LUA WRITE
            
            top->UUA_11_0 = i;
            top->LUA_11_0 = i;

            for (int j=0; j<3; j++)
            {                

                top->CSBITS_63_0 =0;
                
                for (int part = 0; part<4; part++)
                {
                    top->WW0_n = top->WW1_n = top->WW2_n = top->WW3_n = 1; // DISABLE LUA WRITE
                    top->WU0_n = top->WU1_n = top->WU2_n = top->WU3_n = 1; // DISABLE UUA WRITE

                    if (write_phase)
                    {
                        top->CSBITS_63_0 = (uint64_t)0xCAFEABBADEADBEAF & 0xFFFFFFFFFFFFFF00; 
                        top->CSBITS_63_0 |=i;

                        if (part == 0) top->WW0_n = 0;
                        if (part == 1) top->WW1_n = 0;
                        if (part == 2) top->WW2_n = 0;
                        if (part == 3) top->WW3_n = 0;                    

                        if (part == 0) top->WU0_n = 0;
                        if (part == 1) top->WU1_n = 0;
                        if (part == 2) top->WU2_n = 0;
                        if (part == 3) top->WU3_n = 0;                    

                    }

                    top->sysclk  = !top->sysclk;
                

        

            

        top->eval();
        

#ifdef DO_TRACE        
        m_trace->dump(sim_time);
        sim_time += time_step; // Increment simulation time
#endif

        top->sysclk  = !top->sysclk;
        top->eval();

#ifdef DO_TRACE        
        m_trace->dump(sim_time);
        sim_time += time_step; // Increment simulation time
#endif



            }
        }
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




#define DO_TRACE
#include <iostream>
#include <vector>
#include <random>
#include <ctime>
#include <string>

#include "VCPU_PROC_CMDDEC_34.h"
#include "verilated.h"

#ifdef DO_TRACE
#include <verilated_vcd_c.h>
#endif

// PAL testcases
struct TestCase {
  // Inputs

   //bool     CLK,

   bool     CGABRK_n;
   uint8_t  CSCOMM_4_0;
   uint8_t  CSIDBS_4_0;
   uint8_t  CSMIS_1_0;
   bool     IDB2;
   bool     LCS_n;
   bool     MREQ_n;
   bool     PD1;
   uint8_t  PIL_3_0;
   bool     WCA_n;
   bool     WRTRF;
   
   // outputs
   bool     BRK_n;
   bool     CUP;
   bool     CWR;
   bool     ERF_n;
   bool     LEV0;
   bool     OPCLCS;
   bool     RRF_n;
// bool     RT_n; // This signal is not in the PAL 44408B, but in the PAL 444608 (VXFIX). Use  RT_n signal from DGA until we find out what the 44608A does with this signal.
   bool     RWCS_n;
   bool     LDEXM_n; // This wire is not in the PAL 44408B, but in the PAL 444608 (VXFIX). Not sure what to do with this signal at the moment.. but brings it out here just in case..
   bool     VEX;

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
    VCPU_PROC_CMDDEC_34* top = new VCPU_PROC_CMDDEC_34;

#ifdef DO_TRACE
    VerilatedVcdC *m_trace = new VerilatedVcdC;    
    Verilated::traceEverOn(true);
    top->trace(m_trace, 1); // 1 is the trace depth
    m_trace->open("waveform.vcd");
#endif
    


    int errCnt = 0;

    // Default Assignments for input fields   
    top->WRTRF = 
    top->PD1 = 
    top->IDB2 = false; 

    top->CGABRK_n =   
    top->LCS_n = 
    top->MREQ_n =    
    top->WCA_n = true;

    top->CSIDBS_4_0 = 0b01010;

    // Iterate through each test case
    //for (const auto& test : testCases) {
    //    std::cout << "Running " << test.description << std::endl;

    int pil = 0;
    int idbs = 0;
    for (int i=0; i<4096; i++)
    {
        for (int mis=0; mis<2;mis++)
        {


            top->CLK = !top->CLK; // Toggle OSC

            top->CSCOMM_4_0 = i & 0x1F;
            top->CSMIS_1_0 = mis;

            if (i>50)
            {

                if (i %10 == 0)
                {
                    idbs++;
                    idbs &= 0x1F;
                }

                if (idbs == 10)
                     top->WRTRF =  ! top->WRTRF;
                     
                top->LCS_n = true;
                top->CSIDBS_4_0 = idbs;
            }

            //if (i%5 == 0) 
            {
                top->PIL_3_0 = pil;
                pil++;
                pil &= 0xF;

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




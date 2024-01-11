#define DO_TRACE
#include <iostream>
#include <vector>
#include <random>
#include <ctime>
#include <string>

#include "VPAL_45008B.h"
#include "verilated.h"

#ifdef DO_TRACE
#include <verilated_vcd_c.h>
#endif

// PAL testcases
struct TestCase {
    

    // Inputs

    bool MWRITE_n;           // I0 - MWRITE_n
    bool SWDIS_n;            // I1 - SWDIS_n
    bool LBD0;               // I2 - LBD0
    bool LBD1;               // I3 - LBD1
    bool LBD3;               // I4 - LBD3
    bool LBD4;               // I5 - LBD4
    bool BIOXL_n;            // I6 - BIOXL_n
    bool ECCR;               // I7 - ECCR
    bool BCGNT50R_n;         // I8 - BCGNT50R_n
    //bool HIEN_n;             // I9 - EPEA_n (not used)

    bool QD_n;              // B4_n - PD3
    bool MR_n;              // B5_n - MR_n


    // Outputs

    bool DIS_n;             // Y0_n (OUT Only)
    bool OER_n;             // Y1_n (OUT ONLY)
    
    bool OET_n;             // B0_n - OET_n
    bool CLRERR_n;          // B1_n - CLRERR_n
    bool DISB_n;            // B2_n - DISB_n (n.c.)
    bool TST_n;             // B3_n - TST_n (n.c)

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
    VPAL_45008B* top = new VPAL_45008B;

#ifdef DO_TRACE
    VerilatedVcdC *m_trace = new VerilatedVcdC;    
    Verilated::traceEverOn(true);
    top->trace(m_trace, 1); // 1 is the trace depth
    m_trace->open("waveform.vcd");
#endif
    


    int errCnt = 0;

    // Initialize inputs to zero
    top->MWRITE_n=
    top->SWDIS_n=true;

    top->LBD0=
    top->LBD1=
    top->LBD3=
    top->LBD4= false;

    top->BIOXL_n=true;
    top->ECCR = false;
    top->BCGNT50R_n=
    //top->HIEN_n=
    top->QD_n=
    top->MR_n=true;

    // Iterate through each test case
    //for (const auto& test : testCases) {
    for (int i=0;i<32;i++)
    {

        //std::cout << "Running " << test.description << std::endl;

        // Set inputs (?)
        if ((i & 0x02) == 2) top->MR_n = 1;
            else top->MR_n = 0;

        if (i==1)
            top->MWRITE_n = false;            
        

        if (i==5)
        {
            top->LBD3 = true;
            top->LBD1 = true;
            top->BIOXL_n = false;
            top->ECCR = true;
        }

        if (i==7)
        {
            top->LBD3 = false;
            top->LBD1 = false;
            top->ECCR = false;
        }

        if (i==9)
            top->BIOXL_n = true;

        if (i==11)
            top->SWDIS_n = false;

        top->eval();

#ifdef DO_TRACE        
        m_trace->dump(sim_time);
        sim_time += time_step; // Increment simulation time
#endif        

        

        // Set inputs (?)

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




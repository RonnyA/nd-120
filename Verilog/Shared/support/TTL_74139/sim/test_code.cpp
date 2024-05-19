#define DO_TRACE
#include <iostream>
#include <vector>
#include <random>
#include <ctime>
#include <string>

#include "VTTL_74139.h"
#include "verilated.h"

#ifdef DO_TRACE
#include <verilated_vcd_c.h>
#endif

// PAL testcases
struct TestCase {
    
   /*******************************************************************************
   ** The inputs are defined here                                                **
   *******************************************************************************/

    // Decoder 1 inputs
    bool A1;       // Decoder 1 inputs - A
    bool B1;       // Decoder 1 inputs - B
    bool G1_n;     // Decoder 1 enable, active low

    // Decoder 1 outputs
    bool Y1_0_n;    // Decoder 1 outputs; active low
    bool Y1_1_n;
    bool Y1_2_n;
    bool Y1_3_n;

    // Decoder 2 inputs
    bool A2;         // Decoder 2 inputs - A
    bool B2;         // Decoder 2 inputs - B    
    bool G2_n;       // Decoder 2 enable; active low

    // Decoder 2 outputs
    bool Y2_0_n;    // Decoder 2 outputs; active low
    bool Y2_1_n;
    bool Y2_2_n;
    bool Y2_3_n;
   
 
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
    VTTL_74139* top = new VTTL_74139;
    

#ifdef DO_TRACE
    VerilatedVcdC *m_trace = new VerilatedVcdC;    
    Verilated::traceEverOn(true);
    top->trace(m_trace, 2); // 1 is the trace depth
    m_trace->open("waveform.vcd");
#endif
    


    int errCnt = 0;
    top->A1 = 0;
    top->B1 = 0;
    top->G1_n = 1;

    top->A2 = 0;
    top->B2 = 0;
    top->G2_n = 1;


    // Iterate through each test case
    //for (const auto& test : testCases) {
    //    std::cout << "Running " << test.description << std::endl;

    uint8_t transmitChars = 5;

    uint8_t clearChipAccess =0; // number of cycles until clear chip access
    int transmitAt = 10;
    int readtAt = 10000;

    uint8_t txData = 0xA0;

    for (int ck =0;ck<12;ck++)
    {

        switch(ck)
        {
            case 1:
                top->A1 = 0;
                top->B1 = 0;
                top->G1_n = 0;
                break;
            case 2:
                top->A1 = 1;
                top->B1 = 0;
                top->G1_n = 0;
                break;
            case 3:
                top->A1 = 0;
                top->B1 = 1;
                top->G1_n = 0;
                break;
            case 4:
                top->A1 = 1;
                top->B1 = 1;
                top->G1_n = 0;
                break;
            case 5:
                top->G1_n = 1;
                break;


            case 6:
                top->A2 = 0;
                top->B2 = 0;
                top->G2_n = 0;
                break;
            case 7:
                top->A2 = 1;
                top->B2 = 0;
                top->G2_n = 0;
                break;
            case 8:
                top->A2 = 0;
                top->B2 = 1;
                top->G2_n = 0;
                break;
            case 9:
                top->A2 = 1;
                top->B2 = 1;
                top->G2_n = 0;
                break;
            case 10:
                top->G2_n = 1;
                break;
            default:
            break;
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




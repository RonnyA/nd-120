#define DO_TRACE
#include <iostream>
#include <vector>
#include <random>
#include <ctime>
#include <string>

#include "VCGA_ALU.h"
#include "verilated.h"

#ifdef DO_TRACE
#include <verilated_vcd_c.h>
#endif


/// <summary>
/// ALU Source, bit 0-1-2 in the ALU i0-8 input
/// </summary>
enum ALUSource {
    A_Q = 0,  // Am2901 AQ  000
    A_B = 1,  // Am2901 AB  001
    O_Q = 2,  // Am2901 ZQ  010
    O_B = 3,  // Am2901 ZB  011
    O_A = 4,  // Am2901 ZA  100
    D_A = 5,  // Am2901 DA  101
    D_Q = 6,  // Am2901 DQ  110
    D_O = 7   // Am2901 DZ  111
};


/// <summary>
/// ALU Function, bit 3-4-5 in the ALU i0-8 input
/// </summary>
enum ALUFunc {
    ALUF_ADD = 0 << 3,   // ADD (R plus S)
    ALUF_SUBR = 1 << 3,  // SUBR (S Minus R)  // CSCINSEL must be set to 1 to force CARRY IN
    ALUF_SUBS = 2 << 3,  // SUBS (R Minus S)  // CSCINSEL must be set to 1 to force CARRY IN
    ALUF_OR = 3 << 3,    // OR (R or S)
    ALUF_AND = 4 << 3,   // AND (R and S)
    ALUF_NOTRS = 5 << 3, // NOTRS (/R AND /S)
    ALUF_EXOR = 6 << 3,  // EXOR (R EX-OR S)
    ALUF_EXNOR = 7 << 3  // EXNOR (R EX-NOR S)
};

/// <summary>
///  ALU Destination, bit 6-7-8 in the ALU i0-8 input
/// </summary>
enum ALUDestination {
    ALUD_Q = 0 << 6,    // Am2901.QREG (Q:=F, Y:=F)
    ALUD_NONE = 1 << 6, // Am2901.NOP (Y:=F)
    ALUD_B_YA = 2 << 6, // Am2901.RAMA (Y:A)
    ALUD_B = 3 << 6,    // Am2901.RAMF (Y:F)
    ALUD_SRD = 4 << 6,  // Am2901.RAMQD (Y:F, F,Q/2 -> B,Q)
    ALUD_SRB = 5 << 6,  // Am2901.RAMD (Y:F, F/2 -> B)
    ALUD_SLD = 6 << 6,  // Am2901.RAMQU (Y:F, 2F,Q->B,Q)
    ALUD_SLB = 7 << 6   // Am2901.RAMU (Y:F, 2F->B)
};


/// <summary>
/// ALU Mode used in field "CSALUM_1_0"
/// </summary>
enum ALUMode {
    ALUM_uSHIFT = 0,   // Micro controlled mode
    ALUM_FMU = 1,      // Multiply Mode (FMU)
    ALUM_FDV = 2,      // Divide Mode (FDV)
    ALUM_IR_SHIFT = 3  // Shift Instruction (IR SHIFT)
};


enum IDBSource {
    IDBS_ALU = 0,       // ALU result or register pointed to by the A—operand (dependent on bits 60—63 in microcode).
    IDBS_BMG = 1,       // Bit—mask generator. A 1 bit among zeros is enabled onto IDB. The position of the 1 bit is controlled by the A operand.
    IDBS_GPR = 2,       // General purpose register. The general purpose register is enabled onto IDB.
    IDBS_DBR = 3,       // DB/cache read register. The system bus data read register is enabled onto IDB. This must be used with the WAIT for data ready timing specification.
    IDBS_ARG = 4,       // Microcode argument register. The 16 lower bits of the microinstruction is enabled onto IDB.
    IDBS_REG = 5,       // Register file, selected by A & B operands. The register file address selected by the A and B operands is enabled onto IDB.
    IDBS_STS = 6,       // Macro status register. The 16 bit STS register is enabled onto IDB.
    // 7 not used
    IDBS_BARG = 8,      // B—operand as argument on bits 0—3. Values 0-17 B. The B operand is regarded as an argument and enabled onto IDB.
    IDBS_SWAP = 9,      // Byte swap register (previous IDB contents are byte-swapped). A byte swap circuit is enabled onto IDB.
    IDBS_PEA = 10,      // Parity Error address. The inverse of the PEA register is enabled onto IDB.
    IDBS_PES = 11,      // Parity Error status & Address. The inverse of the PES register is enabled onto IDB.
    IDBS_AARG = 12,     // A—operand as argument on bits 3—6 (with bits 0-2=0) giving a range of values 0-170. The A operand is regarded as an argument shifted 3 bits left, and enabled onto IDB.
    IDBS_PICS = 13,     // Internal status of the PIC. A read status command must be issued to the PIC.
    IDBS_IOR = 14,      // I/O register from UART etc. The register containing UART data and status is enabled onto IDB.
    IDBS_none = 15,     // Nothing enabled onto the IDB by IDBS field. IDB is disabled.
    IDBS_MIPANS = 16,   // Panel status register (EPANS).
    IDBS_MAPANS = 17,   // Panel status register (EPANS), and also panel status read bit (12) is reset.
    IDBS_GPR_SEXT = 18, // General purpose register, sign extended.
    IDBS_PGS = 19,      // Paging status extended.
    IDBS_CSR = 20,      // Cache status register.
    IDBS_PCR = 21,      // Paging control register.
    IDBS_ALD = 22,      // Automatic load descriptor and print-status.
    IDBS_PANEL = 23,    // Panel interrupt vector.
    IDBS_RCS = 24,      // Read control store (see also command decode 36,1 - RWCS).
    IDBS_PICVC = 25,    // PIC interrupt vector (see also command decode 11 - EPIC).
    IDBS_spare1 = 26,   // Spare.
    IDBS_spare2 = 27,   // Spare.
    IDBS_JMPA = 28,     // In ND-110, LA (10-15), CA (0-9) update P in ALU jump. In ND-120, space.
    IDBS_RINR = 29,     // Read installation number.
    IDBS_PICMASK = 30,  // In ND110, spare. In ND120, read PIC mask register.
    IDBS_UART = 31,     // In ND-110, spare. In ND-120, read UART (see also command decode 5,x - UART).
};


// Helper to 
const uint16_t ALU_ADD_AB = A_B | ALUF_ADD | ALUD_B;

// ALU testcases
struct TestCase {
    uint16_t A_15_0; // The value for A (coming from WRF normally)
    uint16_t B_15_0; // The value for B (coming from WRF normally)
    uint16_t CD_15_0; // The value for D (Data bus value)
    
    uint16_t EA_15_0;  // Output from ?? Bitmap generator ?
    uint16_t FIDBI_15_0; // Internal Bus - INPUT
    
    // Control signals
    uint16_t CSBIT_15_0;  // direct Input to register ARG (normally microcode bits 15_0)
    uint8_t CSIDBS_4_0;   // Selects input for internal data bus. See enum "IDBSource"
    uint8_t CSSST_1_0;    // Control signal to STS register bit 4-7. 00 = Read signal from STS. 01
    uint8_t CSCINSEL_1_0; // Selects input for "CarryInput" when ALUM = 3 (ALUM_IR_SHIFT). 0=0, 1=1, 2=STS6, 3=GPR0 (bits 46-47 in microcode)
    
    // ALU Control signals
    uint16_t CSALUI_8_0; // ALU control signals, 9 bits. Identical to Am 2901 control bits. Combined enum "ALUSource | ALUFunc | ALUDestination"
    uint8_t CSALUM_1_0;  // ALU Mode, 2 bits. See enum "ALUMode"

    uint8_t LAA_3_0;  // Select which register (0-15) which goes to A output - But here is combined to EAARG register (bit 4-6) 
    uint8_t LBA_3_0;  // Select which register (0-15) which goes to B output - But here is combined to EAARG register (bit 0-2)

    bool LDPILN;      // Load PIL (negated)
    bool LDDBRN;      // Load DBR (negated) - "Data bus register" (for IO)
    bool LDGPRN;      // Load GPR (negated) - "General Purpose register" (has shift logic also)
    bool XFETCHN;     // ONLY FOR P REGISTER (#2): 0=FETCH FROM RB, 1=FETCH FROM NLCA
    bool LDIRV;       // Load IRV (clock pulse) Load bit 9 and 10 from CD to replace CSMIS0 and CSMIS1 signals when ALUM = 3 (ALUM_IR_SHIFT)
    bool UPN;   // 0=Count Down 1=Count up  (loop counter,LC)
    bool LCZN;  //0=Loop counter at Zero


    /*---------- OUTPUT SIGNALS --------------*/

    uint16_t expected_RB_15_0; // Output sum from ALU
    uint16_t expected_FIDBO_15_0; // Internal Databus OUT
    

    // Flags
    bool expected_CRY;
    bool expected_ZF;
    bool expected_SGR;
    bool expected_OVF;
    bool expected_F11; // Bit 11 in F
    bool expected_F15; // Bit 15 in F. 0=Positive number, 1=negative number
    bool expected_BDEST;
    
    // STS flags
    bool expected_MI;
    bool expected_PTM;
    bool expected_Z;
    bool expected_DOUBLE;
    bool expected_PONI; // 1=Paging ON. 0=Paging off
    bool expected_IONI; // 1=Interrupt ON. 0=Interrupt OFF
    uint8_t expected_PIL; // Interrupt level (0-15)

    std::string description; // Description of the test case
};


#define MAX_SIM_TIME 20
vluint64_t sim_time = 0;
vluint64_t time_step = 5;


int main(int argc, char **argv) 
{

    // Create a collection of test cases
    std::vector<TestCase> testCases = {    

        // A_15_0, B_15_0,  CD_15_0,  EA_15_0, FIDBI_15_0, CSBIT_15_0, CSIDBS_4_0, CSSST_1_0, CSCINSEL_1_0,  _____CSALUI_8_0______          CSALUM_1_0,    LAA_3_0, LBA_3_0, LDPILN, LDDBRN, LDGPRN, XFETCHN,  LDIRV,  UPN,   LCZN, expected_RB_15_0, expected_FIDBO_15_0, expected_CRY, expected_ZF, expected_SGR, expected_OVF, expected_F11, expected_F15, expected_BDEST, expected_MI, expected_PTM, expected_Z, expected_DOUBLE, expected_PONI, expected_IONI, expected_PIL, description
        
        // ADD

        {      1,       2,   0xDEAD,   0xBEAF,     0xF00D,     0xB117,   IDBS_ALU,          0,           0,  A_B | ALUF_ADD | ALUD_B,       ALUM_uSHIFT,         1,        6,   true,   true,   true,   true,   true,  true,  true,                0,                  0,         true,        true,        true,        true,        true,        true,           true,       true,        true,       true,           true,           true,           true,            0, "Add 1+2" },
        {   0x10,    0x12,   0xDEAD,   0xBEAF,     0xF00D,     0xB117,   IDBS_ALU,          0,           0,  A_B | ALUF_ADD | ALUD_B,       ALUM_uSHIFT,         1,        6,   true,   true,   true,   true,   true,  true,  true,                0,                  0,         true,        true,        true,        true,        true,        true,           true,       true,        true,       true,           true,           true,           true,            0, "Add 0x10 + 0x12" },
        {  0x1AA,    0xAB,   0xDEAD,   0xBEAF,     0xF00D,     0xB117,   IDBS_ALU,          0,           0,  A_B | ALUF_ADD | ALUD_Q,       ALUM_uSHIFT,         1,        6,   true,   true,   true,   true,   true,  true,  true,                0,                  0,         true,        true,        true,        true,        true,        true,           true,       true,        true,       true,           true,           true,           true,            0, "Add 0x1AA+ 0xAB" },

        // Empty
        {     0,        0,         0,       0,          0,          0,          0,          0,           0,                        0,                  0,        0,        0,   true,   true,   true,   true,   true,  true,  true,                0,                  0,         true,        true,        true,        true,        true,        true,           true,       true,        true,       true,           true,           true,           true,            0, "EMPTY"},



        // SUBTRACT
        {      1,       2,   0xDEAD,   0xBEAF,     0xF00D,     0xB117,   IDBS_ALU,          0,           1,  A_B | ALUF_SUBS | ALUD_B_YA,   ALUM_uSHIFT,         1,        6,   true,   true,   true,   true,   true,  true,  true,                0,                  0,         true,        true,        true,        true,        true,        true,           true,       true,        true,       true,           true,           true,           true,            0, "SUB 1+2" },
        {   0x10,    0x12,   0xDEAD,   0xBEAF,     0xF00D,     0xB117,   IDBS_ALU,          0,           1,  A_B | ALUF_SUBS | ALUD_B_YA,   ALUM_uSHIFT,         1,        6,   true,   true,   true,   true,   true,  true,  true,                0,                  0,         true,        true,        true,        true,        true,        true,           true,       true,        true,       true,           true,           true,           true,            0, "SUB 0x10 + 0x12" },
        {  0x1AA,    0xAB,   0xDEAD,   0xBEAF,     0xF00D,     0xB117,   IDBS_ALU,          0,           1,  A_B | ALUF_SUBS | ALUD_Q,      ALUM_uSHIFT,         1,        6,   true,   true,   true,   true,   true,  true,  true,                0,                  0,         true,        true,        true,        true,        true,        true,           true,       true,        true,       true,           true,           true,           true,            0, "SUB 0x1AA+ 0xAB" },

        // Empty
        {     0,        0,         0,       0,          0,          0,          0,          0,           0,                        0,                  0,        0,        0,   true,   true,   true,   true,   true,  true,  true,                0,                  0,         true,        true,        true,        true,        true,        true,           true,       true,        true,       true,           true,           true,           true,            0, "EMPTY"},

#ifdef _xxx_
        {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, true, true, true, true, true, true, true, 0, 0, true, true, true, true, true, true, true, true, true, true, true, true, true, true, 0, "1"},
        {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, true, true, true, true, true, true, true, 0, 0, true, true, true, true, true, true, true, true, true, true, true, true, true, true, 0, "2"},
        {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, true, true, true, true, true, true, true, 0, 0, true, true, true, true, true, true, true, true, true, true, true, true, true, true, 0, "3"}
#endif
    };



    Verilated::commandArgs(argc, argv);
    VCGA_ALU* top = new VCGA_ALU;

#ifdef DO_TRACE
    VerilatedVcdC *m_trace = new VerilatedVcdC;    
    Verilated::traceEverOn(true);
    top->trace(m_trace, 1); // 1 is the trace depth
    m_trace->open("waveform.vcd");
#endif
    


    int errCnt = 0;

        // Iterate through each test case
    for (const auto& test : testCases) {
        std::cout << "Running " << test.description << std::endl;


        // Set up your module inputs based on the test case

        top->A_15_0 = test.A_15_0;
        top->B_15_0 = test.B_15_0;
        top->CD_15_0 = test.CD_15_0;
        top->EA_15_0 = test.EA_15_0;
        top->FIDBI_15_0 = test.FIDBI_15_0;
        top->CSBIT_15_0 = test.CSBIT_15_0;
        top->CSIDBS_4_0 = test.CSIDBS_4_0;
        top->CSSST_1_0 = test.CSSST_1_0;
        top->CSCINSEL_1_0 = test.CSCINSEL_1_0;
        top->CSALUI_8_0 = test.CSALUI_8_0;
        top->CSALUM_1_0 = test.CSALUM_1_0;
        top->LAA_3_0 = test.LAA_3_0;
        top->LBA_3_0 = test.LBA_3_0;
        top->LDPILN = test.LDPILN;
        top->LDDBRN = test.LDDBRN;
        top->LDGPRN = test.LDGPRN;
        top->XFETCHN = test.XFETCHN;
        top->LDIRV = test.LDIRV;
        top->UPN = test.UPN;
        top->LCZN = test.LCZN;


        // Toggle the clock and run the simulation
        top->ALUCLK = 0;
        top->eval();

#ifdef DO_TRACE        
        m_trace->dump(sim_time);
        sim_time += time_step; // Increment simulation time
#endif

        top->ALUCLK = 1;
        top->eval();

#ifdef DO_TRACE        
        m_trace->dump(sim_time);
        sim_time += time_step; // Increment simulation time
#endif

/*
        // Check the output against the expected values
        if (top->A_15_0 != test.expected_A_15_0 )
        {
            printf("[%s] A output [A_15]: 0x%04x does not match expected 0x%04x\n", test.description.c_str(),  top->A_15_0, test.expected_A_15_0);
            errCnt++;
        }

        if (top->B_15_0 != test.expected_B_15_0 )
        {
            printf("[%s] B output [B_15]: 0x%04x does not match expected 0x%04x\n", test.description.c_str(),  top->B_15_0, test.expected_B_15_0);
            errCnt++;
        }
*/
        if (errCnt>0) break; // exit for loop
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




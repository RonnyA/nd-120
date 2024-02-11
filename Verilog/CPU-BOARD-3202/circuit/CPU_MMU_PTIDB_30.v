/**************************************************************************
** ND120 CPU, MM&M                                                       **
** CPU/MMU/PTIDB                                                         **
** PT TO IDB                                                             **
** SHEET 30 of 50                                                        **
**                                                                       ** 
** Last reviewed: 11-FEB-2024                                            **
** Ronny Hansen                                                          **
***************************************************************************/

// verilator lint_off ASSIGNDLY

module CPU_MMU_PTIDB_30( 
                        inout tri [15:0] IDB_15_0,      // Bidirectional IDB data bus (A)
                        inout tri [15:0] PT_15_0,       // Bidirectional PT data bus  (B)
                        input WRITE,                    // Direction: 0=Read from B,1=Write to B  (DIR)
                        input EPTI_n                    // Enable PTI(negated)        (OE_n)                                    
                        );

// This code replaces the original Logisim generated code with a simpler and more efficient implementation
// It replaces two 74PCT245 chips (8-bit transceiver with 3-state outputs) with one 16 bit identical implementation.

wire OE_n;
wire DIR;

reg [15:0] A_reg;
reg [15:0] B_reg;

// Control OE and DIR directly with inputs for clarity
assign OE_n = EPTI_n;
assign DIR = WRITE;

// Separate logic for read and write operations
always @(*) begin
   A_reg = #(10) IDB_15_0;
   B_reg = #(10) PT_15_0;
end

// Drive logic for IDB_15_0 and PT_15_0
assign IDB_15_0 = (!OE_n && !DIR) ? B_reg : 16'bz;
assign PT_15_0 = (!OE_n && DIR) ? A_reg : 16'bz;


// Below is the original code from the Logisim generated file

/******************************************************************************
 ** Logisim-evolution goes FPGA automatic generated Verilog code             **
 ** https://github.com/logisim-evolution/                                    **
 **                                                                          **
 ** Component : CPU_MMU_PTIDB_30                                             **
 **                                                                          **
 *****************************************************************************/

`ifdef _OLD_CODE_

   /*******************************************************************************
   ** The wires are defined here                                                 **
   *******************************************************************************/
   wire [15:0] s_logisimBus21;
   wire [15:0] s_logisimBus31;
   wire        s_logisimNet10;
   wire        s_logisimNet11;
   wire        s_logisimNet12;
   wire        s_logisimNet13;
   wire        s_logisimNet14;
   wire        s_logisimNet16;
   wire        s_logisimNet17;
   wire        s_logisimNet18;
   wire        s_logisimNet19;
   wire        s_logisimNet2;
   wire        s_logisimNet20;
   wire        s_logisimNet23;
   wire        s_logisimNet24;
   wire        s_logisimNet25;
   wire        s_logisimNet26;
   wire        s_logisimNet27;
   wire        s_logisimNet28;
   wire        s_logisimNet29;
   wire        s_logisimNet3;
   wire        s_logisimNet30;
   wire        s_logisimNet32;
   wire        s_logisimNet33;
   wire        s_logisimNet34;
   wire        s_logisimNet35;
   wire        s_logisimNet36;
   wire        s_logisimNet37;
   wire        s_logisimNet38;
   wire        s_logisimNet39;
   wire        s_logisimNet4;
   wire        s_logisimNet5;
   wire        s_logisimNet6;
   wire        s_logisimNet7;
   wire        s_logisimNet8;
   wire        s_logisimNet9;

   /*******************************************************************************
   ** The module functionality is described here                                 **
   *******************************************************************************/

   /*******************************************************************************
   ** Here all input connections are defined                                     **
   *******************************************************************************/
   assign s_logisimBus31[15:0] = IDB_15_0;
   assign s_logisimNet11       = EPTI_n;
   assign s_logisimNet2        = WRITE;

   /*******************************************************************************
   ** Here all output connections are defined                                    **
   *******************************************************************************/
   assign PT_15_0 = s_logisimBus21[15:0];

   /*******************************************************************************
   ** Here all sub-circuits are defined                                          **
   *******************************************************************************/

   TTL_74245   CHIP_17B (.A1(s_logisimBus31[0]),
                         .A2(s_logisimBus31[1]),
                         .A3(s_logisimBus31[2]),
                         .A4(s_logisimBus31[3]),
                         .A5(s_logisimBus31[4]),
                         .A6(s_logisimBus31[5]),
                         .A7(s_logisimBus31[6]),
                         .A8(s_logisimBus31[7]),
                         .B1(s_logisimBus21[0]),
                         .B2(s_logisimBus21[1]),
                         .B3(s_logisimBus21[2]),
                         .B4(s_logisimBus21[3]),
                         .B5(s_logisimBus21[4]),
                         .B6(s_logisimBus21[5]),
                         .B7(s_logisimBus21[6]),
                         .B8(s_logisimBus21[7]),
                         .DIR(s_logisimNet2),
                         .G_n(s_logisimNet11));

   TTL_74245   CHIP_18B (.A1(s_logisimBus31[8]),
                         .A2(s_logisimBus31[9]),
                         .A3(s_logisimBus31[10]),
                         .A4(s_logisimBus31[11]),
                         .A5(s_logisimBus31[12]),
                         .A6(s_logisimBus31[13]),
                         .A7(s_logisimBus31[14]),
                         .A8(s_logisimBus31[15]),
                         .B1(s_logisimBus21[8]),
                         .B2(s_logisimBus21[9]),
                         .B3(s_logisimBus21[10]),
                         .B4(s_logisimBus21[11]),
                         .B5(s_logisimBus21[12]),
                         .B6(s_logisimBus21[13]),
                         .B7(s_logisimBus21[14]),
                         .B8(s_logisimBus21[15]),
                         .DIR(s_logisimNet2),
                         .G_n(s_logisimNet11));

`endif

endmodule

/******************************************************************************
 ** Logisim-evolution goes FPGA automatic generated Verilog code             **
 ** https://github.com/logisim-evolution/                                    **
 **                                                                          **
 ** Component : SIP1M9                                                       **
 **                                                                          **
 *****************************************************************************/

module SIP1M9( AA_9_0,
               CAS9_n,
               CAS_n,
               D9,
               DQ_8_1_io,
               PRD_n,
               Q9,
               RAS_n,
               W_n );

   /*******************************************************************************
   ** The inputs are defined here                                                **
   *******************************************************************************/
   input [9:0] AA_9_0;
   input       CAS9_n;
   input       CAS_n;
   input       RAS_n;
   input       W_n;

   /*******************************************************************************
   ** The outputs are defined here                                               **
   *******************************************************************************/
   output       D9;
   output [7:0] DQ_8_1_io;
   output       PRD_n;
   output       Q9;

   /*******************************************************************************
   ** The wires are defined here                                                 **
   *******************************************************************************/
   wire [9:0] s_logisimBus3;
   wire [7:0] s_logisimBus6;
   wire       s_logisimNet0;
   wire       s_logisimNet1;
   wire       s_logisimNet2;
   wire       s_logisimNet4;
   wire       s_logisimNet5;
   wire       s_logisimNet7;

   /*******************************************************************************
   ** The module functionality is described here                                 **
   *******************************************************************************/

   /*******************************************************************************
   ** Here all input connections are defined                                     **
   *******************************************************************************/
   assign s_logisimBus3[9:0] = AA_9_0;
   assign s_logisimNet2      = CAS_n;
   assign s_logisimNet4      = RAS_n;
   assign s_logisimNet5      = CAS9_n;
   assign s_logisimNet7      = W_n;

   /*******************************************************************************
   ** Here all output connections are defined                                    **
   *******************************************************************************/
   assign D9        = s_logisimNet1;
   assign DQ_8_1_io = s_logisimBus6[7:0];
   assign PRD_n     = s_logisimNet0;
   assign Q9        = s_logisimNet1;

   /*******************************************************************************
   ** Here all in-lined components are defined                                   **
   *******************************************************************************/

   // Ground
   assign  s_logisimNet1  =  1'b0;


   // Power
   assign  s_logisimNet0  =  1'b1;


endmodule

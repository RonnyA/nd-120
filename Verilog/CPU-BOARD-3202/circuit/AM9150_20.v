/******************************************************************************
 ** Logisim-evolution goes FPGA automatic generated Verilog code             **
 ** https://github.com/logisim-evolution/                                    **
 **                                                                          **
 ** Component : AM9150_20                                                    **
 **                                                                          **
 *****************************************************************************/

module AM9150_20( A_9_0,
                  D_4_1,
                  G_n,
                  Q_4_1,
                  R_n,
                  S_n,
                  W_n );

   /*******************************************************************************
   ** The inputs are defined here                                                **
   *******************************************************************************/
   input [9:0] A_9_0;
   input [3:0] D_4_1;
   input       G_n;
   input       R_n;
   input       S_n;
   input       W_n;

   /*******************************************************************************
   ** The outputs are defined here                                               **
   *******************************************************************************/
   output [3:0] Q_4_1;

   /*******************************************************************************
   ** The wires are defined here                                                 **
   *******************************************************************************/
   wire [3:0] s_logisimBus1;
   wire [3:0] s_logisimBus3;
   wire [9:0] s_logisimBus4;
   wire       s_logisimNet0;
   wire       s_logisimNet2;

   /*******************************************************************************
   ** The module functionality is described here                                 **
   *******************************************************************************/

   /*******************************************************************************
   ** Here all input connections are defined                                     **
   *******************************************************************************/
   assign s_logisimBus3[3:0] = D_4_1;
   assign s_logisimBus4[9:0] = A_9_0;
   assign s_logisimNet2      = G_n;

   /*******************************************************************************
   ** Here all output connections are defined                                    **
   *******************************************************************************/
   assign Q_4_1 = s_logisimBus1[3:0];

   /*******************************************************************************
   ** Here all in-lined components are defined                                   **
   *******************************************************************************/

   // NOT Gate
   assign s_logisimNet0 = ~s_logisimNet2;

   // Controlled Buffer
   assign s_logisimBus1 = (s_logisimNet0) ? s_logisimBus3 : 4'bZ;

endmodule
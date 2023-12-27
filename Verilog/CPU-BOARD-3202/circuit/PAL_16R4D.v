/******************************************************************************
 ** Logisim-evolution goes FPGA automatic generated Verilog code             **
 ** https://github.com/logisim-evolution/                                    **
 **                                                                          **
 ** Component : PAL_16R4D                                                    **
 **                                                                          **
 *****************************************************************************/

module PAL_16R4D( B0_n,
                  B1_n,
                  B2_n,
                  B3_n,
                  CK,
                  I0,
                  I1,
                  I2,
                  I3,
                  I4,
                  I5,
                  I6,
                  I7,
                  OE_n,
                  Q0_n,
                  Q1_n,
                  Q2_n,
                  Q3_n );

   /*******************************************************************************
   ** The inputs are defined here                                                **
   *******************************************************************************/
   input CK;
   input I0;
   input I1;
   input I2;
   input I3;
   input I4;
   input I5;
   input I6;
   input I7;
   input OE_n;

   /*******************************************************************************
   ** The outputs are defined here                                               **
   *******************************************************************************/
   output B0_n;
   output B1_n;
   output B2_n;
   output B3_n;
   output Q0_n;
   output Q1_n;
   output Q2_n;
   output Q3_n;

   /*******************************************************************************
   ** The wires are defined here                                                 **
   *******************************************************************************/
   wire s_logisimNet0;
   wire s_logisimNet1;
   wire s_logisimNet10;
   wire s_logisimNet11;
   wire s_logisimNet12;
   wire s_logisimNet13;
   wire s_logisimNet14;
   wire s_logisimNet15;
   wire s_logisimNet16;
   wire s_logisimNet17;
   wire s_logisimNet18;
   wire s_logisimNet2;
   wire s_logisimNet3;
   wire s_logisimNet4;
   wire s_logisimNet5;
   wire s_logisimNet6;
   wire s_logisimNet7;
   wire s_logisimNet8;
   wire s_logisimNet9;

   /*******************************************************************************
   ** The module functionality is described here                                 **
   *******************************************************************************/

   /*******************************************************************************
   ** Here all input connections are defined                                     **
   *******************************************************************************/
   assign s_logisimNet1  = I3;
   assign s_logisimNet10 = CK;
   assign s_logisimNet2  = I0;
   assign s_logisimNet3  = I1;
   assign s_logisimNet4  = I2;
   assign s_logisimNet5  = I4;
   assign s_logisimNet6  = I5;
   assign s_logisimNet7  = I6;
   assign s_logisimNet8  = I7;
   assign s_logisimNet9  = OE_n;

   /*******************************************************************************
   ** Here all output connections are defined                                    **
   *******************************************************************************/
   assign B0_n = s_logisimNet15;
   assign B1_n = s_logisimNet16;
   assign B2_n = s_logisimNet17;
   assign B3_n = s_logisimNet18;
   assign Q0_n = s_logisimNet11;
   assign Q1_n = s_logisimNet12;
   assign Q2_n = s_logisimNet13;
   assign Q3_n = s_logisimNet14;

   /*******************************************************************************
   ** Here all in-lined components are defined                                   **
   *******************************************************************************/

   // Power
   assign  s_logisimNet0  =  1'b1;


   // NOT Gate


   // Controlled Buffer
   assign s_logisimNet11 = (s_logisimNet0) ? s_logisimNet2 : 1'bZ;

   // Controlled Buffer
   assign s_logisimNet12 = (s_logisimNet0) ? s_logisimNet3 : 1'bZ;

   // Controlled Buffer
   assign s_logisimNet13 = (s_logisimNet0) ? s_logisimNet4 : 1'bZ;

   // Controlled Buffer
   assign s_logisimNet14 = (s_logisimNet0) ? s_logisimNet1 : 1'bZ;

   // Controlled Buffer
   assign s_logisimNet15 = (s_logisimNet0) ? s_logisimNet5 : 1'bZ;

   // Controlled Buffer
   assign s_logisimNet16 = (s_logisimNet0) ? s_logisimNet6 : 1'bZ;

   // Controlled Buffer
   assign s_logisimNet17 = (s_logisimNet0) ? s_logisimNet7 : 1'bZ;

   // Controlled Buffer
   assign s_logisimNet18 = (s_logisimNet0) ? s_logisimNet8 : 1'bZ;

endmodule

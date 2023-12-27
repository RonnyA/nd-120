/******************************************************************************
 ** Logisim-evolution goes FPGA automatic generated Verilog code             **
 ** https://github.com/logisim-evolution/                                    **
 **                                                                          **
 ** Component : TTL_74244                                                    **
 **                                                                          **
 *****************************************************************************/

module TTL_74244( I0_1A1,
                  I1_1A2,
                  I2_1A3,
                  I3_1A4,
                  I4_2A1,
                  I5_2A2,
                  I6_2A3,
                  I7_2A4,
                  O0_1Y1,
                  O1_1Y2,
                  O2_1Y3,
                  O3_1Y4,
                  O4_2Y1,
                  O5_2Y2,
                  O6_2Y3,
                  O7_2Y4,
                  OE1_1G_n,
                  OE2_2G_n );

   /*******************************************************************************
   ** The inputs are defined here                                                **
   *******************************************************************************/
   input I0_1A1;
   input I1_1A2;
   input I2_1A3;
   input I3_1A4;
   input I4_2A1;
   input I5_2A2;
   input I6_2A3;
   input I7_2A4;
   input OE1_1G_n;
   input OE2_2G_n;

   /*******************************************************************************
   ** The outputs are defined here                                               **
   *******************************************************************************/
   output O0_1Y1;
   output O1_1Y2;
   output O2_1Y3;
   output O3_1Y4;
   output O4_2Y1;
   output O5_2Y2;
   output O6_2Y3;
   output O7_2Y4;

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
   wire s_logisimNet19;
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
   assign s_logisimNet10 = OE1_1G_n;
   assign s_logisimNet11 = OE2_2G_n;
   assign s_logisimNet2  = I0_1A1;
   assign s_logisimNet3  = I1_1A2;
   assign s_logisimNet4  = I2_1A3;
   assign s_logisimNet5  = I3_1A4;
   assign s_logisimNet6  = I4_2A1;
   assign s_logisimNet7  = I5_2A2;
   assign s_logisimNet8  = I6_2A3;
   assign s_logisimNet9  = I7_2A4;

   /*******************************************************************************
   ** Here all output connections are defined                                    **
   *******************************************************************************/
   assign O0_1Y1 = s_logisimNet13;
   assign O1_1Y2 = s_logisimNet12;
   assign O2_1Y3 = s_logisimNet14;
   assign O3_1Y4 = s_logisimNet15;
   assign O4_2Y1 = s_logisimNet16;
   assign O5_2Y2 = s_logisimNet17;
   assign O6_2Y3 = s_logisimNet18;
   assign O7_2Y4 = s_logisimNet19;

   /*******************************************************************************
   ** Here all in-lined components are defined                                   **
   *******************************************************************************/

   // NOT Gate
   assign s_logisimNet0 = ~s_logisimNet10;

   // NOT Gate
   assign s_logisimNet1 = ~s_logisimNet11;

   // Controlled Buffer
   assign s_logisimNet13 = (s_logisimNet0) ? s_logisimNet2 : 1'bZ;

   // Controlled Buffer
   assign s_logisimNet12 = (s_logisimNet0) ? s_logisimNet3 : 1'bZ;

   // Controlled Buffer
   assign s_logisimNet14 = (s_logisimNet0) ? s_logisimNet4 : 1'bZ;

   // Controlled Buffer
   assign s_logisimNet15 = (s_logisimNet0) ? s_logisimNet5 : 1'bZ;

   // Controlled Buffer
   assign s_logisimNet16 = (s_logisimNet1) ? s_logisimNet6 : 1'bZ;

   // Controlled Buffer
   assign s_logisimNet17 = (s_logisimNet1) ? s_logisimNet7 : 1'bZ;

   // Controlled Buffer
   assign s_logisimNet18 = (s_logisimNet1) ? s_logisimNet8 : 1'bZ;

   // Controlled Buffer
   assign s_logisimNet19 = (s_logisimNet1) ? s_logisimNet9 : 1'bZ;

endmodule

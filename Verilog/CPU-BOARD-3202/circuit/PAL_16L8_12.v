/******************************************************************************
 ** Logisim-evolution goes FPGA automatic generated Verilog code             **
 ** https://github.com/logisim-evolution/                                    **
 **                                                                          **
 ** Component : PAL_16L8_12                                                  **
 **                                                                          **
 *****************************************************************************/

module PAL_16L8_12( B0_n,
                    B1_n,
                    B2_n,
                    B3_n,
                    B4_n,
                    B5_n,
                    I0,
                    I1,
                    I2,
                    I3,
                    I4,
                    I5,
                    I6,
                    I7,
                    I8,
                    I9,
                    Y0_n,
                    Y1_n );

   /*******************************************************************************
   ** The inputs are defined here                                                **
   *******************************************************************************/
   input I0;
   input I1;
   input I2;
   input I3;
   input I4;
   input I5;
   input I6;
   input I7;
   input I8;
   input I9;

   /*******************************************************************************
   ** The outputs are defined here                                               **
   *******************************************************************************/
   output B0_n;
   output B1_n;
   output B2_n;
   output B3_n;
   output B4_n;
   output B5_n;
   output Y0_n;
   output Y1_n;

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
   wire s_logisimNet20;
   wire s_logisimNet21;
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
   assign s_logisimNet16 = I4;
   assign s_logisimNet17 = I5;
   assign s_logisimNet2  = I9;
   assign s_logisimNet3  = I8;
   assign s_logisimNet4  = I0;
   assign s_logisimNet5  = I1;
   assign s_logisimNet6  = I2;
   assign s_logisimNet7  = I3;
   assign s_logisimNet8  = I6;
   assign s_logisimNet9  = I7;

   /*******************************************************************************
   ** Here all output connections are defined                                    **
   *******************************************************************************/
   assign B0_n = s_logisimNet13;
   assign B1_n = s_logisimNet14;
   assign B2_n = s_logisimNet20;
   assign B3_n = s_logisimNet21;
   assign B4_n = s_logisimNet1;
   assign B5_n = s_logisimNet19;
   assign Y0_n = s_logisimNet11;
   assign Y1_n = s_logisimNet12;

   /*******************************************************************************
   ** Here all in-lined components are defined                                   **
   *******************************************************************************/

   // Power
   assign  s_logisimNet0  =  1'b1;


   // Power
   assign  s_logisimNet10  =  1'b1;


   // Controlled Buffer
   assign s_logisimNet11 = (s_logisimNet0) ? s_logisimNet4 : 1'bZ;

   // Controlled Buffer
   assign s_logisimNet12 = (s_logisimNet0) ? s_logisimNet5 : 1'bZ;

   // Controlled Buffer
   assign s_logisimNet13 = (s_logisimNet0) ? s_logisimNet6 : 1'bZ;

   // Controlled Buffer
   assign s_logisimNet14 = (s_logisimNet0) ? s_logisimNet7 : 1'bZ;

   // Controlled Buffer
   assign s_logisimNet20 = (s_logisimNet0) ? s_logisimNet16 : 1'bZ;

   // Controlled Buffer
   assign s_logisimNet21 = (s_logisimNet0) ? s_logisimNet17 : 1'bZ;

   // Controlled Buffer
   assign s_logisimNet1 = (s_logisimNet10) ? s_logisimNet18 : 1'bZ;

   // Controlled Buffer
   assign s_logisimNet19 = (s_logisimNet10) ? s_logisimNet15 : 1'bZ;

   /*******************************************************************************
   ** Here all normal components are defined                                     **
   *******************************************************************************/
   AND_GATE #(.BubblesMask(2'b00))
      GATES_1 (.input1(s_logisimNet3),
               .input2(s_logisimNet2),
               .result(s_logisimNet15));

   AND_GATE #(.BubblesMask(2'b00))
      GATES_2 (.input1(s_logisimNet8),
               .input2(s_logisimNet9),
               .result(s_logisimNet18));


endmodule

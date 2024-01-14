/******************************************************************************
 ** Logisim-evolution goes FPGA automatic generated Verilog code             **
 ** https://github.com/logisim-evolution/                                    **
 **                                                                          **
 ** Component : AM29861A                                                     **
 **                                                                          **
 *****************************************************************************/

module AM29861A( OER_n,
                 OET_n,
                 R0,
                 R1,
                 R2,
                 R3,
                 R4,
                 R5,
                 R6,
                 R7,
                 R8,
                 R9,
                 T0,
                 T1,
                 T2,
                 T3,
                 T4,
                 T5,
                 T6,
                 T7,
                 T8,
                 T9 );

   /*******************************************************************************
   ** The inputs are defined here                                                **
   *******************************************************************************/
   input OER_n;
   input OET_n;
   input R0;
   input R1;
   input R2;
   input R3;
   input R4;
   input R5;
   input R6;
   input R7;
   input R8;
   input R9;

   /*******************************************************************************
   ** The outputs are defined here                                               **
   *******************************************************************************/
   output T0;
   output T1;
   output T2;
   output T3;
   output T4;
   output T5;
   output T6;
   output T7;
   output T8;
   output T9;

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
   wire s_logisimNet22;
   wire s_logisimNet23;
   wire s_logisimNet24;
   wire s_logisimNet25;
   wire s_logisimNet26;
   wire s_logisimNet27;
   wire s_logisimNet28;
   wire s_logisimNet29;
   wire s_logisimNet3;
   wire s_logisimNet30;
   wire s_logisimNet31;
   wire s_logisimNet32;
   wire s_logisimNet33;
   wire s_logisimNet34;
   wire s_logisimNet35;
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
   assign s_logisimNet12 = R0;
   assign s_logisimNet13 = R1;
   assign s_logisimNet14 = R2;
   assign s_logisimNet15 = R3;
   assign s_logisimNet16 = R4;
   assign s_logisimNet17 = R5;
   assign s_logisimNet18 = R6;
   assign s_logisimNet19 = R7;
   assign s_logisimNet20 = R8;
   assign s_logisimNet21 = R9;
   assign s_logisimNet22 = OER_n;
   assign s_logisimNet24 = OET_n;

   /*******************************************************************************
   ** Here all output connections are defined                                    **
   *******************************************************************************/
   assign T0 = s_logisimNet2;
   assign T1 = s_logisimNet3;
   assign T2 = s_logisimNet4;
   assign T3 = s_logisimNet1;
   assign T4 = s_logisimNet5;
   assign T5 = s_logisimNet6;
   assign T6 = s_logisimNet7;
   assign T7 = s_logisimNet8;
   assign T8 = s_logisimNet9;
   assign T9 = s_logisimNet10;

   /*******************************************************************************
   ** Here all in-lined components are defined                                   **
   *******************************************************************************/

   // NOT Gate
   assign s_logisimNet23 = ~s_logisimNet24;

   // NOT Gate
   assign s_logisimNet26 = ~s_logisimNet22;

   // Controlled Buffer
   assign s_logisimNet28 = (s_logisimNet11) ? s_logisimNet2 : 1'bZ;

   // Controlled Buffer
   assign s_logisimNet29 = (s_logisimNet11) ? s_logisimNet3 : 1'bZ;

   // Controlled Buffer
   assign s_logisimNet30 = (s_logisimNet11) ? s_logisimNet4 : 1'bZ;

   // Controlled Buffer
   assign s_logisimNet27 = (s_logisimNet11) ? s_logisimNet1 : 1'bZ;

   // Controlled Buffer
   assign s_logisimNet31 = (s_logisimNet11) ? s_logisimNet5 : 1'bZ;

   // Controlled Buffer
   assign s_logisimNet32 = (s_logisimNet11) ? s_logisimNet6 : 1'bZ;

   // Controlled Buffer
   assign s_logisimNet33 = (s_logisimNet11) ? s_logisimNet7 : 1'bZ;

   // Controlled Buffer
   assign s_logisimNet34 = (s_logisimNet11) ? s_logisimNet8 : 1'bZ;

   // Controlled Buffer
   assign s_logisimNet35 = (s_logisimNet11) ? s_logisimNet9 : 1'bZ;

   // Controlled Buffer
   assign s_logisimNet25 = (s_logisimNet11) ? s_logisimNet10 : 1'bZ;

   // Controlled Buffer
   assign s_logisimNet2 = (s_logisimNet0) ? s_logisimNet12 : 1'bZ;

   // Controlled Buffer
   assign s_logisimNet3 = (s_logisimNet0) ? s_logisimNet13 : 1'bZ;

   // Controlled Buffer
   assign s_logisimNet4 = (s_logisimNet0) ? s_logisimNet14 : 1'bZ;

   // Controlled Buffer
   assign s_logisimNet1 = (s_logisimNet0) ? s_logisimNet15 : 1'bZ;

   // Controlled Buffer
   assign s_logisimNet5 = (s_logisimNet0) ? s_logisimNet16 : 1'bZ;

   // Controlled Buffer
   assign s_logisimNet6 = (s_logisimNet0) ? s_logisimNet17 : 1'bZ;

   // Controlled Buffer
   assign s_logisimNet7 = (s_logisimNet0) ? s_logisimNet18 : 1'bZ;

   // Controlled Buffer
   assign s_logisimNet8 = (s_logisimNet0) ? s_logisimNet19 : 1'bZ;

   // Controlled Buffer
   assign s_logisimNet9 = (s_logisimNet0) ? s_logisimNet20 : 1'bZ;

   // Controlled Buffer
   assign s_logisimNet10 = (s_logisimNet0) ? s_logisimNet21 : 1'bZ;

   /*******************************************************************************
   ** Here all normal components are defined                                     **
   *******************************************************************************/
   AND_GATE #(.BubblesMask(2'b00))
      GATES_1 (.input1(s_logisimNet22),
               .input2(s_logisimNet23),
               .result(s_logisimNet0));

   AND_GATE #(.BubblesMask(2'b00))
      GATES_2 (.input1(s_logisimNet26),
               .input2(s_logisimNet24),
               .result(s_logisimNet11));


endmodule

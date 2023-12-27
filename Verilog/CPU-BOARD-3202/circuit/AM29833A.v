/******************************************************************************
 ** Logisim-evolution goes FPGA automatic generated Verilog code             **
 ** https://github.com/logisim-evolution/                                    **
 **                                                                          **
 ** Component : AM29833A                                                     **
 **                                                                          **
 *****************************************************************************/

module AM29833A( CK,
                 CLR_n,
                 ERR_n,
                 OER_n,
                 OET_n,
                 PAR_io,
                 R0,
                 R1,
                 R2,
                 R3,
                 R4,
                 R5,
                 R6,
                 R7,
                 T0,
                 T1,
                 T2,
                 T3,
                 T4,
                 T5,
                 T6,
                 T7 );

   /*******************************************************************************
   ** The inputs are defined here                                                **
   *******************************************************************************/
   input CK;
   input CLR_n;
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

   /*******************************************************************************
   ** The outputs are defined here                                               **
   *******************************************************************************/
   output ERR_n;
   output PAR_io;
   output T0;
   output T1;
   output T2;
   output T3;
   output T4;
   output T5;
   output T6;
   output T7;

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
   assign s_logisimNet10 = R6;
   assign s_logisimNet11 = R7;
   assign s_logisimNet14 = OER_n;
   assign s_logisimNet2  = OET_n;
   assign s_logisimNet31 = CLR_n;
   assign s_logisimNet33 = CK;
   assign s_logisimNet4  = R0;
   assign s_logisimNet5  = R1;
   assign s_logisimNet6  = R2;
   assign s_logisimNet7  = R3;
   assign s_logisimNet8  = R4;
   assign s_logisimNet9  = R5;

   /*******************************************************************************
   ** Here all output connections are defined                                    **
   *******************************************************************************/
   assign ERR_n  = s_logisimNet13;
   assign PAR_io = s_logisimNet32;
   assign T0     = s_logisimNet15;
   assign T1     = s_logisimNet16;
   assign T2     = s_logisimNet17;
   assign T3     = s_logisimNet18;
   assign T4     = s_logisimNet19;
   assign T5     = s_logisimNet20;
   assign T6     = s_logisimNet21;
   assign T7     = s_logisimNet30;

   /*******************************************************************************
   ** Here all in-lined components are defined                                   **
   *******************************************************************************/

   // NOT Gate
   assign s_logisimNet3 = ~s_logisimNet2;

   // NOT Gate
   assign s_logisimNet12 = ~s_logisimNet14;

   // Controlled Buffer
   assign s_logisimNet22 = (s_logisimNet1) ? s_logisimNet15 : 1'bZ;

   // Controlled Buffer
   assign s_logisimNet23 = (s_logisimNet1) ? s_logisimNet16 : 1'bZ;

   // Controlled Buffer
   assign s_logisimNet24 = (s_logisimNet1) ? s_logisimNet17 : 1'bZ;

   // Controlled Buffer
   assign s_logisimNet25 = (s_logisimNet1) ? s_logisimNet18 : 1'bZ;

   // Controlled Buffer
   assign s_logisimNet26 = (s_logisimNet1) ? s_logisimNet19 : 1'bZ;

   // Controlled Buffer
   assign s_logisimNet27 = (s_logisimNet1) ? s_logisimNet20 : 1'bZ;

   // Controlled Buffer
   assign s_logisimNet28 = (s_logisimNet1) ? s_logisimNet21 : 1'bZ;

   // Controlled Buffer
   assign s_logisimNet29 = (s_logisimNet1) ? s_logisimNet30 : 1'bZ;

   // Controlled Buffer
   assign s_logisimNet15 = (s_logisimNet0) ? s_logisimNet4 : 1'bZ;

   // Controlled Buffer
   assign s_logisimNet16 = (s_logisimNet0) ? s_logisimNet5 : 1'bZ;

   // Controlled Buffer
   assign s_logisimNet17 = (s_logisimNet0) ? s_logisimNet6 : 1'bZ;

   // Controlled Buffer
   assign s_logisimNet18 = (s_logisimNet0) ? s_logisimNet7 : 1'bZ;

   // Controlled Buffer
   assign s_logisimNet19 = (s_logisimNet0) ? s_logisimNet8 : 1'bZ;

   // Controlled Buffer
   assign s_logisimNet20 = (s_logisimNet0) ? s_logisimNet9 : 1'bZ;

   // Controlled Buffer
   assign s_logisimNet21 = (s_logisimNet0) ? s_logisimNet10 : 1'bZ;

   // Controlled Buffer
   assign s_logisimNet30 = (s_logisimNet0) ? s_logisimNet11 : 1'bZ;

   /*******************************************************************************
   ** Here all normal components are defined                                     **
   *******************************************************************************/
   AND_GATE #(.BubblesMask(2'b00))
      GATES_1 (.input1(s_logisimNet14),
               .input2(s_logisimNet3),
               .result(s_logisimNet0));

   AND_GATE #(.BubblesMask(2'b00))
      GATES_2 (.input1(s_logisimNet12),
               .input2(s_logisimNet2),
               .result(s_logisimNet1));


endmodule

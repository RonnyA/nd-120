/******************************************************************************
 ** Logisim-evolution goes FPGA automatic generated Verilog code             **
 ** https://github.com/logisim-evolution/                                    **
 **                                                                          **
 ** Component : TTL_74648                                                    **
 **                                                                          **
 *****************************************************************************/

module TTL_74648( A1,
                  A2,
                  A3,
                  A4,
                  A5,
                  A6,
                  A7,
                  A8,
                  B1_n,
                  B2_n,
                  B3_n,
                  B4_n,
                  B5_n,
                  B6_n,
                  B7_n,
                  B8_n,
                  CLKAB,
                  CLKBA,
                  DIR,
                  OE_n,
                  SAB,
                  SBA );

   /*******************************************************************************
   ** The inputs are defined here                                                **
   *******************************************************************************/
   input A1;
   input A2;
   input A3;
   input A4;
   input A5;
   input A6;
   input A7;
   input A8;
   input CLKAB;
   input CLKBA;
   input DIR;
   input OE_n;
   input SAB;
   input SBA;

   /*******************************************************************************
   ** The outputs are defined here                                               **
   *******************************************************************************/
   output B1_n;
   output B2_n;
   output B3_n;
   output B4_n;
   output B5_n;
   output B6_n;
   output B7_n;
   output B8_n;

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
   assign s_logisimNet0  = SAB;
   assign s_logisimNet10 = SBA;
   assign s_logisimNet13 = CLKBA;
   assign s_logisimNet14 = A1;
   assign s_logisimNet15 = DIR;
   assign s_logisimNet16 = OE_n;
   assign s_logisimNet9  = CLKAB;

   /*******************************************************************************
   ** Here all output connections are defined                                    **
   *******************************************************************************/
   assign B1_n = s_logisimNet6;
   assign B2_n = s_logisimNet25;
   assign B3_n = s_logisimNet26;
   assign B4_n = s_logisimNet27;
   assign B5_n = s_logisimNet28;
   assign B6_n = s_logisimNet29;
   assign B7_n = s_logisimNet30;
   assign B8_n = s_logisimNet24;

   /*******************************************************************************
   ** Here all in-lined components are defined                                   **
   *******************************************************************************/

   // NOT Gate
   assign s_logisimNet17 = ~s_logisimNet13;

   // Controlled Inverter
   assign s_logisimNet4 = (s_logisimNet2) ? ~s_logisimNet21 : 1'b0;

   // NOT Gate
   assign s_logisimNet11 = ~s_logisimNet9;

   // Controlled Inverter
   assign s_logisimNet23 = (s_logisimNet7) ? ~s_logisimNet20 : 1'b0;

   /*******************************************************************************
   ** Here all normal components are defined                                     **
   *******************************************************************************/
   AND_GATE #(.BubblesMask(2'b00))
      GATES_1 (.input1(s_logisimNet0),
               .input2(s_logisimNet18),
               .result(s_logisimNet3));

   AND_GATE #(.BubblesMask(2'b00))
      GATES_2 (.input1(s_logisimNet8),
               .input2(s_logisimNet14),
               .result(s_logisimNet22));

   OR_GATE #(.BubblesMask(2'b00))
      GATES_3 (.input1(s_logisimNet3),
               .input2(s_logisimNet22),
               .result(s_logisimNet21));

   OR_GATE #(.BubblesMask(2'b00))
      GATES_4 (.input1(s_logisimNet12),
               .input2(s_logisimNet19),
               .result(s_logisimNet20));

   AND_GATE #(.BubblesMask(2'b11))
      GATES_5 (.input1(s_logisimNet16),
               .input2(s_logisimNet15),
               .result(s_logisimNet7));

   AND_GATE #(.BubblesMask(2'b01))
      GATES_6 (.input1(s_logisimNet16),
               .input2(s_logisimNet15),
               .result(s_logisimNet2));

   AND_GATE #(.BubblesMask(2'b00))
      GATES_7 (.input1(s_logisimNet10),
               .input2(s_logisimNet1),
               .result(s_logisimNet12));

   AND_GATE #(.BubblesMask(2'b00))
      GATES_8 (.input1(s_logisimNet5),
               .input2(s_logisimNet6),
               .result(s_logisimNet19));

   NAND_GATE #(.BubblesMask(2'b00))
      GATES_9 (.input1(s_logisimNet10),
               .input2(s_logisimNet10),
               .result(s_logisimNet5));

   NAND_GATE #(.BubblesMask(2'b00))
      GATES_10 (.input1(s_logisimNet0),
                .input2(s_logisimNet0),
                .result(s_logisimNet8));

   D_FLIPFLOP #(.invertClockEnable(1))
      MEMORY_11 (.clock(s_logisimNet17),
                 .d(s_logisimNet6),
                 .preset(1'b0),
                 .q(),
                 .qBar(s_logisimNet1),
                 .reset(1'b0),
                 .tick(1'b1));

   D_FLIPFLOP #(.invertClockEnable(1))
      MEMORY_12 (.clock(s_logisimNet11),
                 .d(s_logisimNet14),
                 .preset(1'b0),
                 .q(),
                 .qBar(s_logisimNet18),
                 .reset(1'b0),
                 .tick(1'b1));


endmodule

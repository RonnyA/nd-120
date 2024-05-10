/******************************************************************************
 ** Logisim-evolution goes FPGA automatic generated Verilog code             **
 ** https://github.com/logisim-evolution/                                    **
 **                                                                          **
 ** Component : TTL_74646                                                    **
 **                                                                          **
 *****************************************************************************/

module TTL_74646( A1,
                  A2,
                  A3,
                  A4,
                  A5,
                  A6,
                  A7,
                  A8,
                  B1,
                  B2,
                  B3,
                  B4,
                  B5,
                  B6,
                  B7,
                  B8,
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
   output B1;
   output B2;
   output B3;
   output B4;
   output B5;
   output B6;
   output B7;
   output B8;

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
   assign s_logisimNet1  = SAB;
   assign s_logisimNet10 = CLKAB;
   assign s_logisimNet11 = SBA;
   assign s_logisimNet14 = CLKBA;
   assign s_logisimNet17 = DIR;
   assign s_logisimNet18 = OE_n;
   assign s_logisimNet7  = A1;

   /*******************************************************************************
   ** Here all output connections are defined                                    **
   *******************************************************************************/
   assign B1 = s_logisimNet6;
   assign B2 = s_logisimNet26;
   assign B3 = s_logisimNet27;
   assign B4 = s_logisimNet28;
   assign B5 = s_logisimNet29;
   assign B6 = s_logisimNet30;
   assign B7 = s_logisimNet31;
   assign B8 = s_logisimNet25;

   /*******************************************************************************
   ** Here all in-lined components are defined                                   **
   *******************************************************************************/

   // NOT Gate
   assign s_logisimNet19 = ~s_logisimNet14;

   // Controlled Inverter
   assign s_logisimNet16 = (s_logisimNet3) ? ~s_logisimNet23 : 1'b0;

   // NOT Gate
   assign s_logisimNet12 = ~s_logisimNet10;

   // Controlled Inverter
   assign s_logisimNet15 = (s_logisimNet8) ? ~s_logisimNet22 : 1'b0;

   // NOT Gate
   assign s_logisimNet0 = ~s_logisimNet7;

   // NOT Gate
   assign s_logisimNet32 = ~s_logisimNet6;

   /*******************************************************************************
   ** Here all normal components are defined                                     **
   *******************************************************************************/
   AND_GATE #(.BubblesMask(2'b00))
      GATES_1 (.input1(s_logisimNet1),
               .input2(s_logisimNet20),
               .result(s_logisimNet4));

   AND_GATE #(.BubblesMask(2'b00))
      GATES_2 (.input1(s_logisimNet9),
               .input2(s_logisimNet0),
               .result(s_logisimNet24));

   OR_GATE #(.BubblesMask(2'b00))
      GATES_3 (.input1(s_logisimNet4),
               .input2(s_logisimNet24),
               .result(s_logisimNet23));

   OR_GATE #(.BubblesMask(2'b00))
      GATES_4 (.input1(s_logisimNet13),
               .input2(s_logisimNet21),
               .result(s_logisimNet22));

   AND_GATE #(.BubblesMask(2'b11))
      GATES_5 (.input1(s_logisimNet18),
               .input2(s_logisimNet17),
               .result(s_logisimNet8));

   AND_GATE #(.BubblesMask(2'b01))
      GATES_6 (.input1(s_logisimNet18),
               .input2(s_logisimNet17),
               .result(s_logisimNet3));

   AND_GATE #(.BubblesMask(2'b00))
      GATES_7 (.input1(s_logisimNet11),
               .input2(s_logisimNet2),
               .result(s_logisimNet13));

   AND_GATE #(.BubblesMask(2'b00))
      GATES_8 (.input1(s_logisimNet5),
               .input2(s_logisimNet32),
               .result(s_logisimNet21));

   NAND_GATE #(.BubblesMask(2'b00))
      GATES_9 (.input1(s_logisimNet11),
               .input2(s_logisimNet11),
               .result(s_logisimNet5));

   NAND_GATE #(.BubblesMask(2'b00))
      GATES_10 (.input1(s_logisimNet1),
                .input2(s_logisimNet1),
                .result(s_logisimNet9));

   D_FLIPFLOP #(.invertClockEnable(1))
      MEMORY_11 (.clock(s_logisimNet19),
                 .d(s_logisimNet6),
                 .preset(1'b0),
                 .q(),
                 .qBar(s_logisimNet2),
                 .reset(1'b0),
                 .tick(1'b1));

   D_FLIPFLOP #(.invertClockEnable(1))
      MEMORY_12 (.clock(s_logisimNet12),
                 .d(s_logisimNet7),
                 .preset(1'b0),
                 .q(),
                 .qBar(s_logisimNet20),
                 .reset(1'b0),
                 .tick(1'b1));


endmodule

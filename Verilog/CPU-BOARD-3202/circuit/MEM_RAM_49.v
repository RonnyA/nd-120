/******************************************************************************
 ** Logisim-evolution goes FPGA automatic generated Verilog code             **
 ** https://github.com/logisim-evolution/                                    **
 **                                                                          **
 ** Component : MEM_RAM_49                                                   **
 **                                                                          **
 *****************************************************************************/

module MEM_RAM_49( AA_9_0,
                   BANK0,
                   BANK1,
                   BANK2,
                   CAS,
                   CORR_n,
                   DD_17_0_io,
                   MWRITE50_n,
                   RAS );

   /*******************************************************************************
   ** The inputs are defined here                                                **
   *******************************************************************************/
   input [9:0] AA_9_0;
   input       BANK0;
   input       BANK1;
   input       BANK2;
   input       CAS;
   input       MWRITE50_n;
   input       RAS;

   /*******************************************************************************
   ** The outputs are defined here                                               **
   *******************************************************************************/
   output        CORR_n;
   output [17:0] DD_17_0_io;

   /*******************************************************************************
   ** The wires are defined here                                                 **
   *******************************************************************************/
   wire [17:0] s_logisimBus35;
   wire [17:0] s_logisimBus43;
   wire [17:0] s_logisimBus6;
   wire [9:0]  s_logisimBus9;
   wire        s_logisimNet0;
   wire        s_logisimNet1;
   wire        s_logisimNet10;
   wire        s_logisimNet11;
   wire        s_logisimNet12;
   wire        s_logisimNet13;
   wire        s_logisimNet14;
   wire        s_logisimNet15;
   wire        s_logisimNet16;
   wire        s_logisimNet17;
   wire        s_logisimNet18;
   wire        s_logisimNet19;
   wire        s_logisimNet2;
   wire        s_logisimNet20;
   wire        s_logisimNet21;
   wire        s_logisimNet22;
   wire        s_logisimNet24;
   wire        s_logisimNet25;
   wire        s_logisimNet26;
   wire        s_logisimNet27;
   wire        s_logisimNet28;
   wire        s_logisimNet29;
   wire        s_logisimNet3;
   wire        s_logisimNet33;
   wire        s_logisimNet34;
   wire        s_logisimNet36;
   wire        s_logisimNet37;
   wire        s_logisimNet38;
   wire        s_logisimNet39;
   wire        s_logisimNet4;
   wire        s_logisimNet40;
   wire        s_logisimNet42;
   wire        s_logisimNet44;
   wire        s_logisimNet46;
   wire        s_logisimNet47;
   wire        s_logisimNet5;
   wire        s_logisimNet7;
   wire        s_logisimNet8;

   /*******************************************************************************
   ** The module functionality is described here                                 **
   *******************************************************************************/

   /*******************************************************************************
   ** Here all input connections are defined                                     **
   *******************************************************************************/
   assign s_logisimBus9[9:0] = AA_9_0;
   assign s_logisimNet0      = BANK2;
   assign s_logisimNet14     = BANK0;
   assign s_logisimNet19     = RAS;
   assign s_logisimNet2      = BANK1;
   assign s_logisimNet22     = CAS;
   assign s_logisimNet3      = MWRITE50_n;

   /*******************************************************************************
   ** Here all output connections are defined                                    **
   *******************************************************************************/
   assign CORR_n     = s_logisimNet13;
   assign DD_17_0_io = s_logisimBus35[17:0];

   /*******************************************************************************
   ** Here all in-lined components are defined                                   **
   *******************************************************************************/

   // NOT Gate
   assign s_logisimNet13 = ~s_logisimNet37;

   /*******************************************************************************
   ** Here all normal components are defined                                     **
   *******************************************************************************/
   NAND_GATE #(.BubblesMask(2'b00))
      GATES_1 (.input1(s_logisimNet19),
               .input2(s_logisimNet2),
               .result(s_logisimNet10));

   NAND_GATE #(.BubblesMask(2'b00))
      GATES_2 (.input1(s_logisimNet2),
               .input2(s_logisimNet22),
               .result(s_logisimNet24));

   OR_GATE #(.BubblesMask(2'b00))
      GATES_3 (.input1(s_logisimNet33),
               .input2(s_logisimNet46),
               .result(s_logisimBus43[8]));

   OR_GATE #(.BubblesMask(2'b00))
      GATES_4 (.input1(s_logisimNet20),
               .input2(s_logisimNet40),
               .result(s_logisimBus43[17]));

   NAND_GATE #(.BubblesMask(2'b00))
      GATES_5 (.input1(s_logisimNet19),
               .input2(s_logisimNet0),
               .result(s_logisimNet15));

   NAND_GATE #(.BubblesMask(2'b00))
      GATES_6 (.input1(s_logisimNet0),
               .input2(s_logisimNet22),
               .result(s_logisimNet4));

   OR_GATE #(.BubblesMask(2'b00))
      GATES_7 (.input1(s_logisimNet44),
               .input2(s_logisimNet29),
               .result(s_logisimBus35[8]));

   OR_GATE #(.BubblesMask(2'b00))
      GATES_8 (.input1(s_logisimNet38),
               .input2(s_logisimNet5),
               .result(s_logisimBus35[17]));

   OR_GATE_6_INPUTS #(.BubblesMask({2'b11, 4'hF}))
      GATES_9 (.input1(s_logisimNet28),
               .input2(s_logisimNet21),
               .input3(s_logisimNet17),
               .input4(s_logisimNet8),
               .input5(s_logisimNet26),
               .input6(s_logisimNet27),
               .result(s_logisimNet37));

   NAND_GATE #(.BubblesMask(2'b00))
      GATES_10 (.input1(s_logisimNet19),
                .input2(s_logisimNet14),
                .result(s_logisimNet18));

   NAND_GATE #(.BubblesMask(2'b00))
      GATES_11 (.input1(s_logisimNet14),
                .input2(s_logisimNet22),
                .result(s_logisimNet12));

   OR_GATE #(.BubblesMask(2'b00))
      GATES_12 (.input1(s_logisimNet42),
                .input2(s_logisimNet25),
                .result(s_logisimBus6[8]));

   OR_GATE #(.BubblesMask(2'b00))
      GATES_13 (.input1(s_logisimNet36),
                .input2(s_logisimNet47),
                .result(s_logisimBus6[17]));


   /*******************************************************************************
   ** Here all sub-circuits are defined                                          **
   *******************************************************************************/

   SIP1M9   CHIP_15K (.AA_9_0(s_logisimBus9[9:0]),
                      .CAS9_n(s_logisimNet24),
                      .CAS_n(s_logisimNet24),
                      .D9(s_logisimNet46),
                      .DQ_8_1_io(s_logisimBus43[7:0]),
                      .PRD_n(s_logisimNet21),
                      .Q9(s_logisimNet33),
                      .RAS_n(s_logisimNet10),
                      .W_n(s_logisimNet3));

   SIP1M9   CHIP_15L (.AA_9_0(s_logisimBus9[9:0]),
                      .CAS9_n(s_logisimNet24),
                      .CAS_n(s_logisimNet24),
                      .D9(s_logisimNet40),
                      .DQ_8_1_io(s_logisimBus43[16:9]),
                      .PRD_n(s_logisimNet26),
                      .Q9(s_logisimNet20),
                      .RAS_n(s_logisimNet10),
                      .W_n(s_logisimNet3));

   SIP1M9   CHIP_15M (.AA_9_0(s_logisimBus9[9:0]),
                      .CAS9_n(s_logisimNet4),
                      .CAS_n(s_logisimNet4),
                      .D9(s_logisimNet29),
                      .DQ_8_1_io(s_logisimBus35[7:0]),
                      .PRD_n(s_logisimNet28),
                      .Q9(s_logisimNet44),
                      .RAS_n(s_logisimNet15),
                      .W_n(s_logisimNet3));

   SIP1M9   CHIP_15N (.AA_9_0(s_logisimBus9[9:0]),
                      .CAS9_n(s_logisimNet4),
                      .CAS_n(s_logisimNet4),
                      .D9(s_logisimNet5),
                      .DQ_8_1_io(s_logisimBus35[16:9]),
                      .PRD_n(s_logisimNet27),
                      .Q9(s_logisimNet38),
                      .RAS_n(s_logisimNet15),
                      .W_n(s_logisimNet3));

   SIP1M9   CHIP_15H (.AA_9_0(s_logisimBus9[9:0]),
                      .CAS9_n(s_logisimNet12),
                      .CAS_n(s_logisimNet12),
                      .D9(s_logisimNet25),
                      .DQ_8_1_io(s_logisimBus6[7:0]),
                      .PRD_n(s_logisimNet17),
                      .Q9(s_logisimNet42),
                      .RAS_n(s_logisimNet18),
                      .W_n(s_logisimNet3));

   SIP1M9   CHIP_15J (.AA_9_0(s_logisimBus9[9:0]),
                      .CAS9_n(s_logisimNet12),
                      .CAS_n(s_logisimNet12),
                      .D9(s_logisimNet47),
                      .DQ_8_1_io(s_logisimBus6[16:9]),
                      .PRD_n(s_logisimNet8),
                      .Q9(s_logisimNet36),
                      .RAS_n(s_logisimNet18),
                      .W_n(s_logisimNet3));

endmodule

/******************************************************************************
 ** Logisim-evolution goes FPGA automatic generated Verilog code             **
 ** https://github.com/logisim-evolution/                                    **
 **                                                                          **
 ** Component : CGA_ALU_OUTMUX_SEL8                                          **
 **                                                                          **
 *****************************************************************************/

module CGA_ALU_OUTMUX_SEL8( D,
                            E_7_0,
                            SI_7_0 );

   /*******************************************************************************
   ** The inputs are defined here                                                **
   *******************************************************************************/
   input [7:0] E_7_0;
   input [7:0] SI_7_0;

   /*******************************************************************************
   ** The outputs are defined here                                               **
   *******************************************************************************/
   output D;

   /*******************************************************************************
   ** The wires are defined here                                                 **
   *******************************************************************************/
   wire [7:0] s_logisimBus0;
   wire [7:0] s_logisimBus1;
   wire       s_logisimNet10;
   wire       s_logisimNet11;
   wire       s_logisimNet12;
   wire       s_logisimNet13;
   wire       s_logisimNet14;
   wire       s_logisimNet15;
   wire       s_logisimNet16;
   wire       s_logisimNet17;
   wire       s_logisimNet18;
   wire       s_logisimNet19;
   wire       s_logisimNet2;
   wire       s_logisimNet20;
   wire       s_logisimNet21;
   wire       s_logisimNet22;
   wire       s_logisimNet23;
   wire       s_logisimNet24;
   wire       s_logisimNet25;
   wire       s_logisimNet26;
   wire       s_logisimNet3;
   wire       s_logisimNet4;
   wire       s_logisimNet5;
   wire       s_logisimNet6;
   wire       s_logisimNet7;
   wire       s_logisimNet8;
   wire       s_logisimNet9;

   /*******************************************************************************
   ** The module functionality is described here                                 **
   *******************************************************************************/

   /*******************************************************************************
   ** Here all input connections are defined                                     **
   *******************************************************************************/
   assign s_logisimBus0[7:0] = SI_7_0;
   assign s_logisimBus1[7:0] = E_7_0;

   /*******************************************************************************
   ** Here all output connections are defined                                    **
   *******************************************************************************/
   assign D = s_logisimNet4;

   /*******************************************************************************
   ** Here all normal components are defined                                     **
   *******************************************************************************/
   NAND_GATE #(.BubblesMask(2'b00))
      GATES_1 (.input1(s_logisimBus0[7]),
               .input2(s_logisimBus1[7]),
               .result(s_logisimNet2));

   NAND_GATE #(.BubblesMask(2'b00))
      GATES_2 (.input1(s_logisimBus0[6]),
               .input2(s_logisimBus1[6]),
               .result(s_logisimNet6));

   NAND_GATE #(.BubblesMask(2'b00))
      GATES_3 (.input1(s_logisimBus0[5]),
               .input2(s_logisimBus1[5]),
               .result(s_logisimNet26));

   NAND_GATE #(.BubblesMask(2'b00))
      GATES_4 (.input1(s_logisimBus0[4]),
               .input2(s_logisimBus1[4]),
               .result(s_logisimNet3));

   NAND_GATE #(.BubblesMask(2'b00))
      GATES_5 (.input1(s_logisimBus0[3]),
               .input2(s_logisimBus1[3]),
               .result(s_logisimNet7));

   NAND_GATE #(.BubblesMask(2'b00))
      GATES_6 (.input1(s_logisimBus0[2]),
               .input2(s_logisimBus1[2]),
               .result(s_logisimNet5));

   NAND_GATE #(.BubblesMask(2'b00))
      GATES_7 (.input1(s_logisimBus0[1]),
               .input2(s_logisimBus1[1]),
               .result(s_logisimNet9));

   NAND_GATE #(.BubblesMask(2'b00))
      GATES_8 (.input1(s_logisimBus0[0]),
               .input2(s_logisimBus1[0]),
               .result(s_logisimNet8));

   NAND_GATE_8_INPUTS #(.BubblesMask(8'h00))
      GATES_9 (.input1(s_logisimNet2),
               .input2(s_logisimNet6),
               .input3(s_logisimNet26),
               .input4(s_logisimNet3),
               .input5(s_logisimNet7),
               .input6(s_logisimNet5),
               .input7(s_logisimNet9),
               .input8(s_logisimNet8),
               .result(s_logisimNet4));


endmodule
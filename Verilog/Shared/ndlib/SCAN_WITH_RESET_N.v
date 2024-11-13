/******************************************************************************
 ** Logisim-evolution goes FPGA automatic generated Verilog code             **
 ** https://github.com/logisim-evolution/                                    **
 **                                                                          **
 ** Component : SCAN_WITH_RESET_N                                            **
 **                                                                          **
 *****************************************************************************/

module SCAN_WITH_RESET_N( CLK,
                          D,
                          Q,
                          QN,
                          R,
                          TE,
                          TI );

   /*******************************************************************************
   ** The inputs are defined here                                                **
   *******************************************************************************/
   input CLK;
   input D;
   input R;
   input TE;
   input TI;

   /*******************************************************************************
   ** The outputs are defined here                                               **
   *******************************************************************************/
   output Q;
   output QN;

   /*******************************************************************************
   ** The wires are defined here                                                 **
   *******************************************************************************/
   wire s_logisimNet0;
   wire s_logisimNet1;
   wire s_logisimNet10;
   wire s_logisimNet11;
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
   assign s_logisimNet0  = TE;
   assign s_logisimNet10 = TI;
   assign s_logisimNet4  = CLK;
   assign s_logisimNet8  = R;
   assign s_logisimNet9  = D;

   /*******************************************************************************
   ** Here all output connections are defined                                    **
   *******************************************************************************/
   assign Q  = s_logisimNet6;
   assign QN = s_logisimNet7;

   /*******************************************************************************
   ** Here all in-lined components are defined                                   **
   *******************************************************************************/

   // NOT Gate
   assign s_logisimNet11 = ~s_logisimNet0;

   // NOT Gate
   assign s_logisimNet2 = ~s_logisimNet8;

   /*******************************************************************************
   ** Here all normal components are defined                                     **
   *******************************************************************************/
   AND_GATE #(.BubblesMask(2'b00))
      GATES_1 (.input1(s_logisimNet9),
               .input2(s_logisimNet11),
               .result(s_logisimNet1));

   AND_GATE #(.BubblesMask(2'b00))
      GATES_2 (.input1(s_logisimNet0),
               .input2(s_logisimNet10),
               .result(s_logisimNet3));

   OR_GATE #(.BubblesMask(2'b00))
      GATES_3 (.input1(s_logisimNet1),
               .input2(s_logisimNet3),
               .result(s_logisimNet5));

   D_FLIPFLOP #(.InvertClockEnable(0))
      MEMORY_4 (.clock(s_logisimNet4),
                .d(s_logisimNet5),
                .preset(1'b0),
                .q(s_logisimNet6),
                .qBar(s_logisimNet7),
                .reset(s_logisimNet2),
                .tick(1'b1));


endmodule

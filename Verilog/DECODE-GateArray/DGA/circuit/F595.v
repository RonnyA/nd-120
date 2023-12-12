/******************************************************************************
 ** Logisim-evolution goes FPGA automatic generated Verilog code             **
 ** https://github.com/logisim-evolution/                                    **
 **                                                                          **
 ** Component : F595                                                         **
 **                                                                          **
 *****************************************************************************/

module F595( H01_S,
             H02_R,
             H03_G,
             N01_Q,
             N02_QB );

   /*******************************************************************************
   ** The inputs are defined here                                                **
   *******************************************************************************/
   input H01_S;
   input H02_R;
   input H03_G;

   /*******************************************************************************
   ** The outputs are defined here                                               **
   *******************************************************************************/
   output N01_Q;
   output N02_QB;

   /*******************************************************************************
   ** The wires are defined here                                                 **
   *******************************************************************************/
   wire s_logisimNet0;
   wire s_logisimNet1;
   wire s_logisimNet2;
   wire s_logisimNet3;
   wire s_logisimNet4;
   wire s_logisimNet5;
   wire s_logisimNet6;
   wire s_logisimNet7;
   wire s_logisimNet8;

   /*******************************************************************************
   ** The module functionality is described here                                 **
   *******************************************************************************/

   /*******************************************************************************
   ** Here all input connections are defined                                     **
   *******************************************************************************/
   assign s_logisimNet1 = H03_G;
   assign s_logisimNet3 = H01_S;
   assign s_logisimNet4 = H02_R;

   /*******************************************************************************
   ** Here all output connections are defined                                    **
   *******************************************************************************/
   assign N01_Q  = s_logisimNet8;
   assign N02_QB = s_logisimNet6;

   /*******************************************************************************
   ** Here all in-lined components are defined                                   **
   *******************************************************************************/

   // NOT Gate
   assign s_logisimNet8 = ~s_logisimNet2;

   // NOT Gate
   assign s_logisimNet6 = ~s_logisimNet5;

   /*******************************************************************************
   ** Here all normal components are defined                                     **
   *******************************************************************************/
   AND_GATE #(.BubblesMask(2'b00))
      GATES_1 (.input1(s_logisimNet3),
               .input2(s_logisimNet1),
               .result(s_logisimNet0));

   AND_GATE #(.BubblesMask(2'b00))
      GATES_2 (.input1(s_logisimNet1),
               .input2(s_logisimNet4),
               .result(s_logisimNet7));

   NOR_GATE #(.BubblesMask(2'b00))
      GATES_3 (.input1(s_logisimNet0),
               .input2(s_logisimNet5),
               .result(s_logisimNet2));

   NOR_GATE #(.BubblesMask(2'b00))
      GATES_4 (.input1(s_logisimNet2),
               .input2(s_logisimNet7),
               .result(s_logisimNet5));


endmodule

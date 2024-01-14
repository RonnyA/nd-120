/******************************************************************************
 ** Logisim-evolution goes FPGA automatic generated Verilog code             **
 ** https://github.com/logisim-evolution/                                    **
 **                                                                          **
 ** Component : F571                                                         **
 **                                                                          **
 *****************************************************************************/

module F571( A,
             D0,
             D1,
             ENB_N,
             Y );

   /*******************************************************************************
   ** The inputs are defined here                                                **
   *******************************************************************************/
   input A;
   input D0;
   input D1;
   input ENB_N;

   /*******************************************************************************
   ** The outputs are defined here                                               **
   *******************************************************************************/
   output Y;

   /*******************************************************************************
   ** The wires are defined here                                                 **
   *******************************************************************************/
   wire s_logisimNet0;
   wire s_logisimNet1;
   wire s_logisimNet2;
   wire s_logisimNet3;
   wire s_logisimNet4;
   wire s_logisimNet5;

   /*******************************************************************************
   ** The module functionality is described here                                 **
   *******************************************************************************/

   /*******************************************************************************
   ** Here all input connections are defined                                     **
   *******************************************************************************/
   assign s_logisimNet0 = ENB_N;
   assign s_logisimNet1 = A;
   assign s_logisimNet3 = D0;
   assign s_logisimNet4 = D1;

   /*******************************************************************************
   ** Here all output connections are defined                                    **
   *******************************************************************************/
   assign Y = s_logisimNet5;

   /*******************************************************************************
   ** Here all in-lined components are defined                                   **
   *******************************************************************************/

   // NOT Gate
   assign s_logisimNet2 = ~s_logisimNet0;

   /*******************************************************************************
   ** Here all normal components are defined                                     **
   *******************************************************************************/
   Multiplexer_2_w_enable   PLEXERS_1 (.enable(s_logisimNet2),
                              .muxIn_0(s_logisimNet3),
                              .muxIn_1(s_logisimNet4),
                              .muxOut(s_logisimNet5),
                              .sel(s_logisimNet1));


endmodule

/******************************************************************************
 ** Logisim-evolution goes FPGA automatic generated Verilog code             **
 ** https://github.com/logisim-evolution/                                    **
 **                                                                          **
 ** Component : MUX31LP                                                      **
 **                                                                          **
 *****************************************************************************/

module MUX31LP( input A,
                input B,
                input D0,
                input D1,
                input D2,
                output ZN );


   /*******************************************************************************
   ** The wires are defined here                                                 **
   *******************************************************************************/
   wire [1:0] s_logisimBus0;
   wire       s_logisimNet1;
   wire       s_logisimNet2;
   wire       s_logisimNet3;
   wire       s_logisimNet4;
   wire       s_logisimNet5;
   wire       s_logisimNet6;
   wire       s_logisimNet7;

   /*******************************************************************************
   ** The module functionality is described here                                 **
   *******************************************************************************/

   /*******************************************************************************
   ** Here all input connections are defined                                     **
   *******************************************************************************/
   assign s_logisimBus0[0] = A;
   assign s_logisimBus0[1] = B;
   assign s_logisimNet1    = D0;
   assign s_logisimNet2    = D2;
   assign s_logisimNet7    = D1;

   /*******************************************************************************
   ** Here all output connections are defined                                    **
   *******************************************************************************/
   assign ZN = s_logisimNet6;

   /*******************************************************************************
   ** Here all in-lined components are defined                                   **
   *******************************************************************************/

   // NOT Gate
   assign s_logisimNet6 = ~s_logisimNet5;

   /*******************************************************************************
   ** Here all normal components are defined                                     **
   *******************************************************************************/
   Multiplexer_4   PLEXERS_1 (
                              .muxIn_0(s_logisimNet1),
                              .muxIn_1(s_logisimNet7),
                              .muxIn_2(s_logisimNet2),
                              .muxIn_3(s_logisimNet2),
                              .muxOut(s_logisimNet5),
                              .sel(s_logisimBus0[1:0]));


endmodule

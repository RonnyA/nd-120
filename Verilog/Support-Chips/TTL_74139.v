/******************************************************************************
 ** Logisim-evolution goes FPGA automatic generated Verilog code             **
 ** https://github.com/logisim-evolution/                                    **
 **                                                                          **
 ** Component : TTL_74139                                                    **
 **                                                                          **
 *****************************************************************************/

module TTL_74139( A1,
                  A2,
                  B1,
                  B2,
                  G1_n,
                  G2_n,
                  Y1_0_n,
                  Y1_1_n,
                  Y1_2_n,
                  Y1_3_n,
                  Y2_0_n,
                  Y2_1_n,
                  Y2_2_n,
                  Y2_3_n );

   /*******************************************************************************
   ** The inputs are defined here                                                **
   *******************************************************************************/
   input A1;
   input A2;
   input B1;
   input B2;
   input G1_n;
   input G2_n;

   /*******************************************************************************
   ** The outputs are defined here                                               **
   *******************************************************************************/
   output Y1_0_n;
   output Y1_1_n;
   output Y1_2_n;
   output Y1_3_n;
   output Y2_0_n;
   output Y2_1_n;
   output Y2_2_n;
   output Y2_3_n;

   /*******************************************************************************
   ** The wires are defined here                                                 **
   *******************************************************************************/
   wire [1:0] s_logisimBus20;
   wire [1:0] s_logisimBus21;
   wire       s_logisimNet0;
   wire       s_logisimNet1;
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
   wire       s_logisimNet22;
   wire       s_logisimNet23;
   wire       s_logisimNet24;
   wire       s_logisimNet25;
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
   assign s_logisimBus20[0] = A1;
   assign s_logisimBus20[1] = B1;
   assign s_logisimBus21[0] = A2;
   assign s_logisimBus21[1] = B2;
   assign s_logisimNet8     = G1_n;
   assign s_logisimNet9     = G2_n;

   /*******************************************************************************
   ** Here all output connections are defined                                    **
   *******************************************************************************/
   assign Y1_0_n = s_logisimNet16;
   assign Y1_1_n = s_logisimNet15;
   assign Y1_2_n = s_logisimNet17;
   assign Y1_3_n = s_logisimNet0;
   assign Y2_0_n = s_logisimNet18;
   assign Y2_1_n = s_logisimNet14;
   assign Y2_2_n = s_logisimNet19;
   assign Y2_3_n = s_logisimNet1;

   /*******************************************************************************
   ** Here all in-lined components are defined                                   **
   *******************************************************************************/

   // NOT Gate
   assign s_logisimNet2 = ~s_logisimNet8;

   // NOT Gate
   assign s_logisimNet3 = ~s_logisimNet9;

   // NOT Gate
   assign s_logisimNet16 = ~s_logisimNet22;

   // NOT Gate
   assign s_logisimNet17 = ~s_logisimNet23;

   // NOT Gate
   assign s_logisimNet18 = ~s_logisimNet24;

   // NOT Gate
   assign s_logisimNet19 = ~s_logisimNet25;

   // NOT Gate
   assign s_logisimNet15 = ~s_logisimNet10;

   // NOT Gate
   assign s_logisimNet0 = ~s_logisimNet11;

   // NOT Gate
   assign s_logisimNet14 = ~s_logisimNet12;

   // NOT Gate
   assign s_logisimNet1 = ~s_logisimNet13;

   /*******************************************************************************
   ** Here all normal components are defined                                     **
   *******************************************************************************/
   Decoder_4   PLEXERS_1 (.decoderOut_0(s_logisimNet22),
                          .decoderOut_1(s_logisimNet10),
                          .decoderOut_2(s_logisimNet23),
                          .decoderOut_3(s_logisimNet11),
                          .enable(s_logisimNet2),
                          .sel(s_logisimBus20[1:0]));

   Decoder_4   PLEXERS_2 (.decoderOut_0(s_logisimNet24),
                          .decoderOut_1(s_logisimNet12),
                          .decoderOut_2(s_logisimNet25),
                          .decoderOut_3(s_logisimNet13),
                          .enable(s_logisimNet3),
                          .sel(s_logisimBus21[1:0]));


endmodule

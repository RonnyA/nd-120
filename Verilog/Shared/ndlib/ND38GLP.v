/**************************************************************************
** ND120                                                                 **
**                                                                       **
** Component : ND38GLP                                                   **
**                                                                       **
** Last reviewed: 10-NOV-2024                                            **
** Ronny Hansen                                                          **
***************************************************************************/



module ND38GLP (
    input A,
    input B,
    input C,
    input G,

    output Z0,
    output Z1,
    output Z2,
    output Z3,
    output Z4,
    output Z5,
    output Z6,
    output Z7
);

  /*******************************************************************************
   ** The wires are defined here                                                 **
   *******************************************************************************/
  wire [2:0] s_input_2_0;
  wire       s_g;
  wire       s_out0;
  wire       s_out1;
  wire       s_out2;
  wire       s_out3;
  wire       s_out4;
  wire       s_out5;
  wire       s_out6;
  wire       s_out7;

  /*******************************************************************************
   ** Here all input connections are defined                                     **
   *******************************************************************************/
  assign s_input_2_0[0] = A;
  assign s_input_2_0[1] = B;
  assign s_input_2_0[2] = C;
  assign s_g            = G;

  /*******************************************************************************
   ** Here all output connections are defined                                    **
   *******************************************************************************/
  assign Z0             = ~s_out0;
  assign Z1             = ~s_out1;
  assign Z2             = ~s_out2;
  assign Z3             = ~s_out3;
  assign Z4             = ~s_out4;
  assign Z5             = ~s_out5;
  assign Z6             = ~s_out6;
  assign Z7             = ~s_out7;


  /*******************************************************************************
   ** Here all normal components are defined                                     **
   *******************************************************************************/
  Decoder_8 PLEXERS_1 (
      .decoderOut_0(s_out0),
      .decoderOut_1(s_out1),
      .decoderOut_2(s_out2),
      .decoderOut_3(s_out3),
      .decoderOut_4(s_out4),
      .decoderOut_5(s_out5),
      .decoderOut_6(s_out6),
      .decoderOut_7(s_out7),
      .enable(s_g),
      .sel(s_input_2_0[2:0])
  );


endmodule

/**************************************************************************
** ND120 Shared                                                          **
**                                                                       **
** Component: MUX81                                                      **
**                                                                       **
** Last reviewed: 9-NOV-2024                                             **
** Ronny Hansen                                                          **
***************************************************************************/

module MUX81 (
    input A,
    input B,
    input C,
    input D0,
    input D1,
    input D2,
    input D3,
    input D4,
    input D5,
    input D6,
    input D7,

    output Z
);

  /*******************************************************************************
   ** The wires are defined here                                                 **
   *******************************************************************************/
  wire [2:0] s_selector;
  wire       s_d0;
  wire       s_d1;
  wire       s_d2;
  wire       s_d3;
  wire       s_d4;
  wire       s_d5;
  wire       s_d6;
  wire       s_d7;
  wire       s_mux_out;

  /*******************************************************************************
   ** The module functionality is described here                                 **
   *******************************************************************************/

  /*******************************************************************************
   ** Here all input connections are defined                                     **
   *******************************************************************************/
  assign s_selector[0] = A;
  assign s_selector[1] = B;
  assign s_selector[2] = C;
  assign s_d0    = D0;
  assign s_d1    = D1;
  assign s_d2    = D2;
  assign s_d3    = D3;
  assign s_d4    = D4;
  assign s_d5    = D5;
  assign s_d6    = D6;
  assign s_d7    = D7;

  /*******************************************************************************
   ** Here all output connections are defined                                    **
   *******************************************************************************/
  assign Z = s_mux_out;

  /*******************************************************************************
   ** Here all normal components are defined                                     **
   *******************************************************************************/
  Multiplexer_8 PLEXERS_1 (
      .muxIn_0(s_d0),
      .muxIn_1(s_d1),
      .muxIn_2(s_d2),
      .muxIn_3(s_d3),
      .muxIn_4(s_d4),
      .muxIn_5(s_d5),
      .muxIn_6(s_d6),
      .muxIn_7(s_d7),
      .muxOut(s_mux_out),
      .sel(s_selector[2:0])
  );


endmodule

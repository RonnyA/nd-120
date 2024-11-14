/**************************************************************************
** ND120 Shared                                                          **
**                                                                       **
** Component : RMUX_Gates                                                **
**                                                                       **
** Last reviewed: 11-NOV-2024                                            **
** Ronny Hansen                                                          **
***************************************************************************/


module RMUX_Gates (
    input A,
    input D,
    input RA,
    input RD,

    output RN
);

  /*******************************************************************************
   ** The wires are defined here                                                 **
   *******************************************************************************/
  wire s_gates1_out;
  wire s_gates2_out;
  wire s_rn_out;
  wire s_a;
  wire s_ra;
  wire s_d;
  wire s_rd;

  /*******************************************************************************
   ** The module functionality is described here                                 **
   *******************************************************************************/

  /*******************************************************************************
   ** Here all input connections are defined                                     **
   *******************************************************************************/
  assign s_a  = A;
  assign s_ra = RA;
  assign s_d  = D;
  assign s_rd = RD;

  /*******************************************************************************
   ** Here all output connections are defined                                    **
   *******************************************************************************/
  assign RN   = s_rn_out;

  /*******************************************************************************
   ** Here all normal components are defined                                     **
   *******************************************************************************/
  AND_GATE #(
      .BubblesMask(2'b00)
  ) GATES_1 (
      .input1(s_a),
      .input2(s_ra),
      .result(s_gates1_out)
  );

  AND_GATE #(
      .BubblesMask(2'b00)
  ) GATES_2 (
      .input1(s_d),
      .input2(s_rd),
      .result(s_gates2_out)
  );

  NOR_GATE #(
      .BubblesMask(2'b00)
  ) GATES_3 (
      .input1(s_gates1_out),
      .input2(s_gates2_out),
      .result(s_rn_out)
  );


endmodule

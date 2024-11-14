
/**************************************************************************
** ND120 Shared                                                          **
**                                                                       **
** Component : SCAN_WITH_RESET_N                                         **
**                                                                       **
** Last reviewed: 11-NOV-2024                                            **
** Ronny Hansen                                                          **
***************************************************************************/


module SCAN_WITH_RESET_N (
    input CLK,
    input D,
    input R,
    input TE,
    input TI,

    output Q,
    output QN
);

  /*******************************************************************************
   ** The wires are defined here                                                 **
   *******************************************************************************/
  wire s_clk;
  wire s_d;
  wire s_gates1_out;
  wire s_gates2_out;
  wire s_gates3_out;
  wire s_q_out;
  wire s_qn_out;
  wire s_r_n;
  wire s_r;
  wire s_te_n;
  wire s_te;
  wire s_ti;

  /*******************************************************************************
   ** Here all input connections are defined                                     **
   *******************************************************************************/
  assign s_clk = CLK;
  assign s_d = D;
  assign s_r = R;
  assign s_te = TE;
  assign s_ti = TI;

  /*******************************************************************************
   ** Here all output connections are defined                                    **
   *******************************************************************************/
  assign Q = s_q_out;
  assign QN = s_qn_out;

  /*******************************************************************************
   ** Here all in-lined components are defined                                   **
   *******************************************************************************/

  // NOT Gate
  assign s_te_n = ~s_te;
  assign s_r_n = ~s_r;

  /*******************************************************************************
   ** Here all normal components are defined                                     **
   *******************************************************************************/
  AND_GATE #(
      .BubblesMask(2'b00)
  ) GATES_1 (
      .input1(s_d),
      .input2(s_te_n),
      .result(s_gates1_out)
  );

  AND_GATE #(
      .BubblesMask(2'b00)
  ) GATES_2 (
      .input1(s_te),
      .input2(s_ti),
      .result(s_gates2_out)
  );

  OR_GATE #(
      .BubblesMask(2'b00)
  ) GATES_3 (
      .input1(s_gates1_out),
      .input2(s_gates2_out),
      .result(s_gates3_out)
  );

  D_FLIPFLOP #(
      .InvertClockEnable(0)
  ) MEMORY_4 (
      .clock(s_clk),
      .d(s_gates3_out),
      .preset(1'b0),
      .q(s_q_out),
      .qBar(s_qn_out),
      .reset(s_r_n),
      .tick(1'b1)
  );


endmodule

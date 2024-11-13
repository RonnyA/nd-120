/**************************************************************************
** ND120 Shared                                                          **
**                                                                       **
** SCAN WITH SET FLIP-FLOP                                               **
**                                                                       **
** Last reviewed: 9-NOV-2024                                             **
** Ronny Hansen                                                          **
***************************************************************************/

module SCAN_WITH_SET_N (
    input CLK,
    input D,
    input S,
    input TE,
    input TI,

    output Q,
    output QN
);

  /*******************************************************************************
   ** The wires are defined here                                                 **
   *******************************************************************************/
  wire s_te;
  wire s_and_d_ten;
  wire s_ti;
  wire s_te_n;
  wire s_and_te_ti;
  wire s_clk;
  wire s_d_input;
  wire s_s_n;
  wire s_q_out;
  wire s_q_n_out;
  wire s_s;
  wire s_d;

  /*******************************************************************************
   ** Here all input connections are defined                                     **
   *******************************************************************************/
  assign s_te = TE;
  assign s_ti = TI;
  assign s_clk = CLK;
  assign s_s = S;
  assign s_d = D;

  /*******************************************************************************
   ** Here all output connections are defined                                    **
   *******************************************************************************/
  assign Q = s_q_out;
  assign QN = s_q_n_out;

  /*******************************************************************************
   ** Here all in-lined components are defined                                   **
   *******************************************************************************/

  // NOT Gate
  assign s_te_n = ~s_te;
  assign s_s_n = ~s_s;

  /*******************************************************************************
   ** Here all normal components are defined                                     **
   *******************************************************************************/
  AND_GATE #(
      .BubblesMask(2'b00)
  ) GATES_1 (
      .input1(s_d),
      .input2(s_te_n),
      .result(s_and_d_ten)
  );

  AND_GATE #(
      .BubblesMask(2'b00)
  ) GATES_2 (
      .input1(s_te),
      .input2(s_ti),
      .result(s_and_te_ti)
  );

  OR_GATE #(
      .BubblesMask(2'b00)
  ) GATES_3 (
      .input1(s_and_d_ten),
      .input2(s_and_te_ti),
      .result(s_d_input)
  );

  D_FLIPFLOP #(
      .InvertClockEnable(0)
  ) MEMORY_4 (
      .clock(s_clk),
      .d(s_d_input),
      .preset(s_s_n),
      .q(s_q_out),
      .qBar(s_q_n_out),
      .reset(1'b0),
      .tick(1'b1)
  );


endmodule

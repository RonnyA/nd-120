/**************************************************************************
** ND120 Shared                                                          **
**                                                                       **
** SCAN FLIP-FLOP (Also known as FDIS in the DELILAH schematics)         **
**                                                                       **
** Positive edge triggered D flip-flop with scan                         **
** Its a D flip-flop with a 2-input multiplexer on the D input           **
**                                                                       **
** When TE (test enable) input is negated,                               **
** the circuit behaves like an ordinary D flip-flop.                     **
**                                                                       **
** When TE is asserted,                                                  **
** it takes its data from TI (test input) instead of from D.             **
**                                                                       **
** Last reviewed: 9-NOV-2024                                             **
** Ronny Hansen                                                          **
***************************************************************************/

module SCAN_FF (
    input CLK,  //! Clock (positive triggered)
    input D,    //! D input
    input TE,   //! Test enable
    input TI,   //! Test input

    output Q,  //! Q output
    output QN  //! Q_n output
);

  /*******************************************************************************
   ** The wires are defined here                                                 **
   *******************************************************************************/
  wire s_te;
  wire s_gates1_out;
  wire s_gates2_out;
  wire s_clk;
  wire s_gates3_out;
  wire s_q_out;
  wire s_qn_out;
  wire s_d;
  wire s_ti;
  wire s_te_n;

  /*******************************************************************************
   ** Here all input connections are defined                                     **
   *******************************************************************************/
  assign s_te = TE;
  assign s_clk = CLK;
  assign s_d = D;
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
      .reset(1'b0),
      .tick(1'b1)
  );


endmodule

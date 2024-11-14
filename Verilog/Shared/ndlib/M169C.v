/**************************************************************************
** ND120 Shared                                                          **
**                                                                       **
** M169C - 74LS169 - Synchronous 4-biy up/down binary counters           **
**                                                                       **
** https://www.ti.com/lit/ds/symlink/sn74als169b.pdf                     **
**                                                                       **
** Last reviewed: 9-NOV-2024                                             **
** Ronny Hansen                                                          **
***************************************************************************/

module M169C (
    input A,
    input B,
    input C,
    input CP,
    input D,
    input NL,
    input PN,
    input TN,
    input UP,

    output CON,
    output QA,
    output QB,
    output QC,
    output QD
);

  /*******************************************************************************
   ** The wires are defined here                                                 **
   *******************************************************************************/
  wire s_a;
  wire s_b;
  wire s_c;
  wire s_con_out;
  wire s_cp_n;
  wire s_cp;
  wire s_d;
  wire s_gates27_out;
  wire s_ff_out_qc;
  wire s_gates24_out;
  wire s_gates6_out;
  wire s_ff_out_qb;
  wire s_gates18_out;
  wire s_gates9_out;
  wire s_gates15_out;
  wire s_gates22_out;
  wire s_gates33_out;
  wire s_gates12_out;
  wire s_ff_out_qd;
  wire s_gates7_out;
  wire s_gates19_out;
  wire s_gates20_out;
  wire s_ff_out_qa;
  wire s_gates13_out;
  wire s_gates26_out;
  wire s_gates5_out;
  wire s_gates28_n_out;
  wire s_gates35_out;
  wire s_gates16_out;
  wire s_gates17_out;
  wire s_gates8_out;
  wire s_gates30_n_out;
  wire s_gates10_out;
  wire s_gates21_out;
  wire s_gates11_out;
  wire s_gates3_out;
  wire s_gates28_out;
  wire s_gates1_out;
  wire s_gates14_out;
  wire s_gates25_out;
  wire s_gates4_out;
  wire s_gates32_out;
  wire s_gates30_out;
  wire s_gates29_n_out;
  wire s_gates23_out;
  wire s_gates31_n_out;
  wire s_gates29_out;
  wire s_gates2_out;
  wire s_gates31_out;
  wire s_nl_n;
  wire s_nl;
  wire s_p_n;
  wire s_qa_n_out;
  wire s_qa_out;
  wire s_qb_n_out;
  wire s_qb_out;
  wire s_qc_n_out;
  wire s_qc_out;
  wire s_qd_n_out;
  wire s_qd_out;
  wire s_t_n;
  wire s_t;
  wire s_up_n;
  wire s_up;

  /*******************************************************************************
   ** The module functionality is described here                                 **
   *******************************************************************************/

  /*******************************************************************************
   ** Here all input connections are defined                                     **
   *******************************************************************************/
  assign s_a             = A;
  assign s_b             = B;
  assign s_c             = C;
  assign s_cp            = CP;
  assign s_d             = D;
  assign s_nl            = NL;
  assign s_p_n           = PN;
  assign s_t_n           = TN;
  assign s_up            = UP;

  /*******************************************************************************
   ** Here all output connections are defined                                    **
   *******************************************************************************/
  assign CON             = s_con_out;
  assign QA              = s_qa_out;
  assign QB              = s_qb_out;
  assign QC              = s_qc_out;
  assign QD              = s_qd_out;

  /*******************************************************************************
   ** Here all in-lined components are defined                                   **
   *******************************************************************************/

  // NOT Gate
  assign s_cp_n          = ~s_cp;
  assign s_gates28_n_out = ~s_gates28_out;
  assign s_gates29_n_out = ~s_gates29_out;
  assign s_gates30_n_out = ~s_gates30_out;
  assign s_gates31_n_out = ~s_gates31_out;
  assign s_qa_out        = ~s_qa_n_out;
  assign s_qb_out        = ~s_qb_n_out;
  assign s_qc_out        = ~s_qc_n_out;
  assign s_qd_out        = ~s_qd_n_out;
  assign s_up_n          = ~s_up;
  assign s_t             = ~s_t_n;
  assign s_nl_n          = ~s_nl;

  /*******************************************************************************
   ** Here all normal components are defined                                     **
   *******************************************************************************/
  AND_GATE #(
      .BubblesMask(2'b00)
  ) GATES_1 (
      .input1(s_ff_out_qa),
      .input2(s_nl),
      .result(s_gates1_out)
  );

  AND_GATE #(
      .BubblesMask(2'b00)
  ) GATES_2 (
      .input1(s_ff_out_qb),
      .input2(s_nl),
      .result(s_gates2_out)
  );

  AND_GATE #(
      .BubblesMask(2'b00)
  ) GATES_3 (
      .input1(s_gates35_out),
      .input2(s_gates8_out),
      .result(s_gates3_out)
  );

  AND_GATE #(
      .BubblesMask(2'b00)
  ) GATES_4 (
      .input1(s_ff_out_qc),
      .input2(s_nl),
      .result(s_gates4_out)
  );

  AND_GATE_3_INPUTS #(
      .BubblesMask(3'b000)
  ) GATES_5 (
      .input1(s_gates35_out),
      .input2(s_gates8_out),
      .input3(s_gates9_out),
      .result(s_gates5_out)
  );

  AND_GATE #(
      .BubblesMask(2'b00)
  ) GATES_6 (
      .input1(s_ff_out_qd),
      .input2(s_nl),
      .result(s_gates6_out)
  );

  AND_GATE_4_INPUTS #(
      .BubblesMask(4'h0)
  ) GATES_7 (
      .input1(s_gates35_out),
      .input2(s_gates8_out),
      .input3(s_gates9_out),
      .input4(s_gates10_out),
      .result(s_gates7_out)
  );

  NOR_GATE #(
      .BubblesMask(2'b00)
  ) GATES_8 (
      .input1(s_gates20_out),
      .input2(s_gates21_out),
      .result(s_gates8_out)
  );

  NOR_GATE #(
      .BubblesMask(2'b00)
  ) GATES_9 (
      .input1(s_gates22_out),
      .input2(s_gates23_out),
      .result(s_gates9_out)
  );

  NOR_GATE #(
      .BubblesMask(2'b00)
  ) GATES_10 (
      .input1(s_gates24_out),
      .input2(s_gates25_out),
      .result(s_gates10_out)
  );

  NOR_GATE #(
      .BubblesMask(2'b00)
  ) GATES_11 (
      .input1(s_gates26_out),
      .input2(s_gates27_out),
      .result(s_gates11_out)
  );

  XOR_GATE_ONEHOT #(
      .BubblesMask(2'b00)
  ) GATES_12 (
      .input1(s_gates1_out),
      .input2(s_gates35_out),
      .result(s_gates12_out)
  );

  AND_GATE #(
      .BubblesMask(2'b00)
  ) GATES_13 (
      .input1(s_nl_n),
      .input2(s_a),
      .result(s_gates13_out)
  );

  XOR_GATE_ONEHOT #(
      .BubblesMask(2'b00)
  ) GATES_14 (
      .input1(s_gates2_out),
      .input2(s_gates3_out),
      .result(s_gates14_out)
  );

  AND_GATE #(
      .BubblesMask(2'b00)
  ) GATES_15 (
      .input1(s_nl_n),
      .input2(s_b),
      .result(s_gates15_out)
  );

  XOR_GATE_ONEHOT #(
      .BubblesMask(2'b00)
  ) GATES_16 (
      .input1(s_gates4_out),
      .input2(s_gates5_out),
      .result(s_gates16_out)
  );

  AND_GATE #(
      .BubblesMask(2'b00)
  ) GATES_17 (
      .input1(s_nl_n),
      .input2(s_c),
      .result(s_gates17_out)
  );

  XOR_GATE_ONEHOT #(
      .BubblesMask(2'b00)
  ) GATES_18 (
      .input1(s_gates6_out),
      .input2(s_gates7_out),
      .result(s_gates18_out)
  );

  AND_GATE #(
      .BubblesMask(2'b00)
  ) GATES_19 (
      .input1(s_nl_n),
      .input2(s_d),
      .result(s_gates19_out)
  );

  AND_GATE #(
      .BubblesMask(2'b00)
  ) GATES_20 (
      .input1(s_up),
      .input2(s_qa_n_out),
      .result(s_gates20_out)
  );

  AND_GATE #(
      .BubblesMask(2'b00)
  ) GATES_21 (
      .input1(s_up_n),
      .input2(s_ff_out_qa),
      .result(s_gates21_out)
  );

  AND_GATE #(
      .BubblesMask(2'b00)
  ) GATES_22 (
      .input1(s_up),
      .input2(s_qb_n_out),
      .result(s_gates22_out)
  );

  AND_GATE #(
      .BubblesMask(2'b00)
  ) GATES_23 (
      .input1(s_up_n),
      .input2(s_ff_out_qb),
      .result(s_gates23_out)
  );

  AND_GATE #(
      .BubblesMask(2'b00)
  ) GATES_24 (
      .input1(s_up),
      .input2(s_qc_n_out),
      .result(s_gates24_out)
  );

  AND_GATE #(
      .BubblesMask(2'b00)
  ) GATES_25 (
      .input1(s_up_n),
      .input2(s_ff_out_qc),
      .result(s_gates25_out)
  );

  AND_GATE #(
      .BubblesMask(2'b00)
  ) GATES_26 (
      .input1(s_up),
      .input2(s_qd_n_out),
      .result(s_gates26_out)
  );

  AND_GATE #(
      .BubblesMask(2'b00)
  ) GATES_27 (
      .input1(s_up_n),
      .input2(s_ff_out_qd),
      .result(s_gates27_out)
  );

  NOR_GATE #(
      .BubblesMask(2'b00)
  ) GATES_28 (
      .input1(s_gates12_out),
      .input2(s_gates13_out),
      .result(s_gates28_out)
  );

  NOR_GATE #(
      .BubblesMask(2'b00)
  ) GATES_29 (
      .input1(s_gates14_out),
      .input2(s_gates15_out),
      .result(s_gates29_out)
  );

  NOR_GATE #(
      .BubblesMask(2'b00)
  ) GATES_30 (
      .input1(s_gates16_out),
      .input2(s_gates17_out),
      .result(s_gates30_out)
  );

  NOR_GATE #(
      .BubblesMask(2'b00)
  ) GATES_31 (
      .input1(s_gates18_out),
      .input2(s_gates19_out),
      .result(s_gates31_out)
  );

  AND_GATE_6_INPUTS #(
      .BubblesMask({2'b00, 4'h0})
  ) GATES_32 (
      .input1(s_gates11_out),
      .input2(s_gates10_out),
      .input3(s_gates9_out),
      .input4(s_t),
      .input5(s_up),
      .input6(1'b1),
      .result(s_gates32_out)
  );

  AND_GATE_6_INPUTS #(
      .BubblesMask({2'b00, 4'h0})
  ) GATES_33 (
      .input1(s_up_n),
      .input2(s_t),
      .input3(s_gates8_out),
      .input4(s_gates9_out),
      .input5(s_gates10_out),
      .input6(s_gates11_out),
      .result(s_gates33_out)
  );

  NOR_GATE #(
      .BubblesMask(2'b00)
  ) GATES_34 (
      .input1(s_gates32_out),
      .input2(s_gates33_out),
      .result(s_con_out)
  );

  AND_GATE_3_INPUTS #(
      .BubblesMask(3'b111)
  ) GATES_35 (
      .input1(s_p_n),
      .input2(s_t_n),
      .input3(s_nl_n),
      .result(s_gates35_out)
  );

  D_FLIPFLOP #(
      .InvertClockEnable(0)
  ) MEMORY_36 (
      .clock(s_cp),
      .d(s_gates28_n_out),
      .preset(1'b0),
      .q(s_ff_out_qa),
      .qBar(s_qa_n_out),
      .reset(1'b0),
      .tick(1'b1)
  );

  D_FLIPFLOP #(
      .InvertClockEnable(0)
  ) MEMORY_37 (
      .clock(s_cp),
      .d(s_gates29_n_out),
      .preset(1'b0),
      .q(s_ff_out_qb),
      .qBar(s_qb_n_out),
      .reset(1'b0),
      .tick(1'b1)
  );

  D_FLIPFLOP #(
      .InvertClockEnable(0)
  ) MEMORY_38 (
      .clock(s_cp),
      .d(s_gates30_n_out),
      .preset(1'b0),
      .q(s_ff_out_qc),
      .qBar(s_qc_n_out),
      .reset(1'b0),
      .tick(1'b1)
  );

  D_FLIPFLOP #(
      .InvertClockEnable(0)
  ) MEMORY_39 (
      .clock(s_cp),
      .d(s_gates31_n_out),
      .preset(1'b0),
      .q(s_ff_out_qd),
      .qBar(s_qd_n_out),
      .reset(1'b0),
      .tick(1'b1)
  );


endmodule

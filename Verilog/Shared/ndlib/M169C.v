/**************************************************************************
** ND120 Shared                                                          **
**                                                                       **
** M169C - 74LS169 - Synchronous 4-bit up/down binary counters           **
**                                                                       **
** https://www.ti.com/lit/ds/symlink/sn74als169b.pdf                     **
**                                                                       **
** Last reviewed: 20-DEC-2024                                            **
** Ronny Hansen                                                          **
***************************************************************************/

module M169C (
    input A,   //! Input A
    input B,   //! Input B
    input C,   //! Input C
    input D,   //! Input D
    input CP,  //! Clock Pulse
    input NL,  //! Load Next
    input PN,  //! Enable P
    input TN,  //! Enable T
    input UP,  //! Up/Down (1=Up, 0=Down)

    output CON,  //! Count is Zero
    output QA,   //! Output A
    output QB,   //! Output B
    output QC,   //! Output C
    output QD    //! Output D
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
  wire s_qd_nl;
  wire s_ff_out_qb;
  wire s_gates18_out;
  wire s_qb_zero;
  wire s_gates15_out;
  wire s_gates22_out;
  wire s_gates33_out;
  wire s_gates12_out;
  wire s_ff_out_qd;
  wire s_gates7_out;
  wire s_gates19_out;
  wire s_qan_up;
  wire s_ff_qa_q;
  wire s_gates13_out;
  wire s_gates26_out;
  wire s_gates5_out;
  wire s_gates28_n_out;
  wire s_gates35_out;
  wire s_gates16_out;
  wire s_gates17_out;
  wire s_qa_zero;
  wire s_gates30_n_out;
  wire s_qc_zero;
  wire s_qa_down;
  wire s_qd_zero;
  wire s_gates3_out;
  wire s_gates28_out;
  wire s_qa_nl;
  wire s_gates14_out;
  wire s_gates25_out;
  wire s_qc_nl;
  wire s_gates32_out;
  wire s_gates30_out;
  wire s_gates29_n_out;
  wire s_gates23_out;
  wire s_gates31_n_out;
  wire s_gates29_out;
  wire s_qb_nl;
  wire s_gates31_out;
  wire s_nl_n;
  wire s_nl;
  wire s_p_n;
  wire s_ff_qa_qn;
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
  assign s_qa_out        = ~s_ff_qa_qn;
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
  ) AND_QA_NL (
      .input1(s_ff_qa_q),
      .input2(s_nl),
      .result(s_qa_nl)
  );

  AND_GATE #(
      .BubblesMask(2'b00)
  ) AND_QB_NL (
      .input1(s_ff_out_qb),
      .input2(s_nl),
      .result(s_qb_nl)
  );

  AND_GATE #(
      .BubblesMask(2'b00)
  ) AND_QC_NL (
      .input1(s_ff_out_qc),
      .input2(s_nl),
      .result(s_qc_nl)
  );

  AND_GATE #(
      .BubblesMask(2'b00)
  ) AND_QD_NL (
      .input1(s_ff_out_qd),
      .input2(s_nl),
      .result(s_qd_nl)
  );


  AND_GATE #(
      .BubblesMask(2'b00)
  ) GATES_3 (
      .input1(s_gates35_out),
      .input2(s_qa_zero),
      .result(s_gates3_out)
  );


  AND_GATE_3_INPUTS #(
      .BubblesMask(3'b000)
  ) GATES_5 (
      .input1(s_gates35_out),
      .input2(s_qa_zero),
      .input3(s_qb_zero),
      .result(s_gates5_out)
  );



  AND_GATE_4_INPUTS #(
      .BubblesMask(4'h0)
  ) GATES_7 (
      .input1(s_gates35_out),
      .input2(s_qa_zero),
      .input3(s_qb_zero),
      .input4(s_qc_zero),
      .result(s_gates7_out)
  );

  NOR_GATE #(
      .BubblesMask(2'b00)
  ) GATES_8 (
      .input1(s_qan_up),
      .input2(s_qa_down),
      .result(s_qa_zero)   // QA is zero
  );

  NOR_GATE #(
      .BubblesMask(2'b00)
  ) GATES_9 (
      .input1(s_gates22_out),
      .input2(s_gates23_out),
      .result(s_qb_zero)
  );

  NOR_GATE #(
      .BubblesMask(2'b00)
  ) GATES_10 (
      .input1(s_gates24_out),
      .input2(s_gates25_out),
      .result(s_qc_zero)
  );

  NOR_GATE #(
      .BubblesMask(2'b00)
  ) GATES_11 (
      .input1(s_gates26_out),
      .input2(s_gates27_out),
      .result(s_qd_zero)
  );

  XOR_GATE_ONEHOT #(
      .BubblesMask(2'b00)
  ) GATES_12 (
      .input1(s_qa_nl),
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
      .input1(s_qb_nl),
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
      .input1(s_qc_nl),
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
      .input1(s_qd_nl),
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
  ) AND_QAN_UP (
      .input1(s_up),
      .input2(s_ff_qa_qn),
      .result(s_qan_up)
  );

  AND_GATE #(
      .BubblesMask(2'b00)
  ) AND_QA_UPN (  // AND_QA_UPN
      .input1(s_up_n),
      .input2(s_ff_qa_q),
      .result(s_qa_down)
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
      .input1(s_qd_zero),
      .input2(s_qc_zero),
      .input3(s_qb_zero),
      .input4(s_qa_zero),
      .input5(s_t),
      .input6(s_up),
      .result(s_gates32_out)
  );

  AND_GATE_6_INPUTS #(
      .BubblesMask({2'b00, 4'h0})
  ) GATES_33 (
      .input1(s_up_n),
      .input2(s_t),
      .input3(s_qa_zero),
      .input4(s_qb_zero),
      .input5(s_qc_zero),
      .input6(s_qd_zero),
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
      .q(s_ff_qa_q),
      .qBar(s_ff_qa_qn),
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

/**************************************************************************
** ND120 CGA (CPU Gate Array / DELILAH)                                  **
** /CGA/MAC/LASEL                                                        **
** LASEL                                                                 **
**                                                                       **
** Page 39                                                               **
** SHEET 1 of 1                                                          **
**                                                                       **
** Last reviewed: 14-DEC-2024                                            **
** Ronny Hansen                                                          **
***************************************************************************/

module CGA_MAC_LASEL (
    input        CSMREQ,
    input        DOUBLE,
    input        EXMN,
    input [15:0] ICA_15_8,
    input        MCLK,
    input [15:0] PCR_15_7_2_0,
    input        PEX,
    input        PONI,
    input        SEGZN,
    input        SELPTN,
    input        VEX,

    output A10,
    output A1617,
    output A1619,
    output A1819,
    output B1819,
    output B1821,
    output BB10,
    output C10,
    output D1617,
    output E1617,
    output F1617,
    output LSHADOW
);

  /*******************************************************************************
   ** The wires are defined here                                                 **
   *******************************************************************************/
  wire [15:0] s_ica_15_8;
  wire [15:0] s_pcr_15_7_2_0;
  wire        a_1617_out;
  wire        c_csmreq;
  wire        s_a10_out;
  wire        s_a1619_out;
  wire        s_a1819_out;
  wire        s_b1819_out;
  wire        s_b1821_out;
  wire        s_bb10_out;
  wire        s_c10_out;
  wire        s_d1617_out;
  wire        s_double_n;
  wire        s_double;
  wire        s_e1617_out;
  wire        s_exm_n;
  wire        s_exm;
  wire        s_f1617_out;
  wire        s_gates12_n_out;
  wire        s_gates12_out;
  wire        s_gates13_n_out;
  wire        s_gates13_out;
  wire        s_gates14_out;
  wire        s_gates15_out;
  wire        s_gates16_out;
  wire        s_gates17_out;
  wire        s_gates18_out;
  wire        s_gates19_out;
  wire        s_gates20_out;
  wire        s_gates21_out;
  wire        s_gates22_n_out;
  wire        s_shadow_n;
  wire        s_gates23_n_out;
  wire        s_gates23_out;
  wire        s_lshadow;
  wire        s_mclk;
  wire        s_pcr_15_7_2_0_n;
  wire        s_pex_n;
  wire        s_pex;
  wire        s_poni;
  wire        s_power;
  wire        s_segz_n;
  wire        s_selpt_n;
  wire        s_selpt;
  wire        s_vex;

  /*******************************************************************************
   ** Here all input connections are defined                                     **
   *******************************************************************************/
  assign c_csmreq             = CSMREQ;
  assign s_double             = DOUBLE;
  assign s_exm_n              = EXMN;
  assign s_ica_15_8[15:0]     = ICA_15_8;
  assign s_mclk               = MCLK;
  assign s_pcr_15_7_2_0[15:0] = PCR_15_7_2_0;
  assign s_pex                = PEX;
  assign s_poni               = PONI;
  assign s_segz_n             = SEGZN;
  assign s_selpt_n            = SELPTN;
  assign s_vex                = VEX;

  /*******************************************************************************
   ** Here all output connections are defined                                    **
   *******************************************************************************/
  assign A10                  = s_a10_out;
  assign A1617                = a_1617_out;
  assign A1619                = s_a1619_out;
  assign A1819                = s_a1819_out;
  assign B1819                = s_b1819_out;
  assign B1821                = s_b1821_out;
  assign BB10                 = s_bb10_out;
  assign C10                  = s_c10_out;
  assign D1617                = s_d1617_out;
  assign E1617                = s_e1617_out;
  assign F1617                = s_f1617_out;
  assign LSHADOW              = s_lshadow;

  /*******************************************************************************
   ** Here all in-lined components are defined                                   **
   *******************************************************************************/

  // Power
  assign s_power              = 1'b1;


  // NOT Gate
  assign s_double_n           = ~s_double;
  assign s_exm                = ~s_exm_n;
  assign s_gates12_n_out      = ~s_gates12_out;
  assign s_gates13_n_out      = ~s_gates13_out;
  assign s_gates22_n_out      = ~s_shadow_n;
  assign s_gates23_n_out      = ~s_gates23_out;
  assign s_pcr_15_7_2_0_n     = ~s_pcr_15_7_2_0[2];
  assign s_pex_n              = ~s_pex;
  assign s_selpt              = ~s_selpt_n;

  /*******************************************************************************
   ** Here all normal components are defined                                     **
   *******************************************************************************/
  AND_GATE #(
      .BubblesMask(2'b00)
  ) GATES_1 (
      .input1(s_gates22_n_out),
      .input2(s_gates13_n_out),
      .result(s_a1819_out)
  );

  AND_GATE #(
      .BubblesMask(2'b00)
  ) GATES_2 (
      .input1(s_shadow_n),
      .input2(s_exm),
      .result(s_b1821_out)
  );

  AND_GATE_4_INPUTS #(
      .BubblesMask(4'h0)
  ) GATES_3 (
      .input1(s_shadow_n),
      .input2(s_selpt_n),
      .input3(s_gates23_n_out),
      .input4(s_gates13_n_out),
      .result(s_b1819_out)
  );

  AND_GATE_4_INPUTS #(
      .BubblesMask(4'h0)
  ) GATES_4 (
      .input1(s_shadow_n),
      .input2(s_gates23_n_out),
      .input3(s_selpt),
      .input4(s_gates13_n_out),
      .result(s_a1619_out)
  );

  AND_GATE #(
      .BubblesMask(2'b00)
  ) GATES_5 (
      .input1(s_gates22_n_out),
      .input2(s_gates12_n_out),
      .result(s_a10_out)
  );

  AND_GATE #(
      .BubblesMask(2'b00)
  ) GATES_6 (
      .input1(s_gates22_n_out),
      .input2(s_gates12_out),
      .result(s_bb10_out)
  );

  AND_GATE #(
      .BubblesMask(2'b00)
  ) GATES_7 (
      .input1(s_shadow_n),
      .input2(s_power),
      .result(s_c10_out)
  );

  AND_GATE #(
      .BubblesMask(2'b00)
  ) GATES_8 (
      .input1(s_shadow_n),
      .input2(s_pex),
      .result(a_1617_out)
  );

  AND_GATE_4_INPUTS #(
      .BubblesMask(4'h0)
  ) GATES_9 (
      .input1(s_shadow_n),
      .input2(s_gates13_out),
      .input3(s_selpt),
      .input4(s_gates23_n_out),
      .result(s_d1617_out)
  );

  AND_GATE_3_INPUTS #(
      .BubblesMask(3'b000)
  ) GATES_10 (
      .input1(s_shadow_n),
      .input2(s_gates23_n_out),
      .input3(s_selpt_n),
      .result(s_e1617_out)
  );

  AND_GATE #(
      .BubblesMask(2'b00)
  ) GATES_11 (
      .input1(s_shadow_n),
      .input2(s_vex),
      .result(s_f1617_out)
  );

  NAND_GATE #(
      .BubblesMask(2'b00)
  ) GATES_12 (
      .input1(s_double_n),
      .input2(s_pcr_15_7_2_0_n),
      .result(s_gates12_out)
  );

  NAND_GATE #(
      .BubblesMask(2'b00)
  ) GATES_13 (
      .input1(s_pcr_15_7_2_0[2]),
      .input2(s_double),
      .result(s_gates13_out)
  );

  NAND_GATE #(
      .BubblesMask(2'b00)
  ) GATES_14 (
      .input1(s_ica_15_8[10]),
      .input2(s_ica_15_8[9]),
      .result(s_gates14_out)
  );

  NOR_GATE #(
      .BubblesMask(2'b00)
  ) GATES_15 (
      .input1(s_gates12_out),
      .input2(s_ica_15_8[8]),
      .result(s_gates15_out)
  );

  NAND_GATE_5_INPUTS #(
      .BubblesMask({1'b0, 4'h0})
  ) GATES_16 (
      .input1(s_ica_15_8[15]),
      .input2(s_ica_15_8[14]),
      .input3(s_ica_15_8[13]),
      .input4(s_ica_15_8[12]),
      .input5(s_ica_15_8[11]),
      .result(s_gates16_out)
  );

  NAND_GATE #(
      .BubblesMask(2'b00)
  ) GATES_17 (
      .input1(s_pcr_15_7_2_0[1]),
      .input2(s_pcr_15_7_2_0[0]),
      .result(s_gates17_out)
  );

  AND_GATE #(
      .BubblesMask(2'b11)
  ) GATES_18 (
      .input1(s_gates15_out),
      .input2(s_gates16_out),
      .result(s_gates18_out)
  );

  OR_GATE_3_INPUTS #(
      .BubblesMask(3'b111)
  ) GATES_19 (
      .input1(s_gates17_out),
      .input2(s_poni),
      .input3(s_pex_n),
      .result(s_gates19_out)
  );

  OR_GATE #(
      .BubblesMask(2'b11)
  ) GATES_20 (
      .input1(s_pex),
      .input2(s_segz_n),
      .result(s_gates20_out)
  );

  OR_GATE #(
      .BubblesMask(2'b11)
  ) GATES_21 (
      .input1(s_gates13_out),
      .input2(s_gates14_out),
      .result(s_gates21_out)
  );

  NAND_GATE_5_INPUTS #(
      .BubblesMask({1'b0, 4'h0})
  ) GATES_22 (
      .input1(s_gates21_out),
      .input2(s_gates18_out),
      .input3(c_csmreq),
      .input4(s_gates19_out),
      .input5(s_gates20_out),
      .result(s_shadow_n)
  );

  NAND_GATE_3_INPUTS #(
      .BubblesMask(3'b000)
  ) GATES_23 (
      .input1(s_exm_n),
      .input2(c_csmreq),
      .input3(s_poni),
      .result(s_gates23_out)
  );

  D_FLIPFLOP #(
      .InvertClockEnable(0)
  ) MEMORY_24 (
      .clock(s_mclk),
      .d(s_shadow_n),
      .preset(1'b0),
      .q(),
      .qBar(s_lshadow),
      .reset(1'b0),
      .tick(1'b1)
  );


endmodule

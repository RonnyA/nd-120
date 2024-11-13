/**************************************************************************
** ND120 CGA (CPU Gate Array / DELILAH)                                  **
** /CGA/MAC/LA1025                                                       **
** ADD                                                                   **
**                                                                       **
** Page 40                                                               **
** SHEET 1 of 1                                                          **
**                                                                       **
** Last reviewed: 10-NOV-2024                                            **
** Ronny Hansen                                                          **
***************************************************************************/

module CGA_MAC_LA1025 (
    input        A10,
    input        A1617,
    input        A1619,
    input        A1819,
    input        B1819,
    input        B1821,
    input        BB10,
    input        C10,
    input        D1617,
    input        E1617,
    input        F1617,
    input [15:0] ICA_15_0,
    input        MCLK,
    input [15:0] PCR_15_0,
    input [15:0] PCR_15_0_N,
    input [ 7:0] SEG_7_0,
    input [ 1:0] XPT_1_0,


    output        ECCRHIN,
    output [13:0] LA_23_10
);

  /*******************************************************************************
   ** The wires are defined here                                                 **
   *******************************************************************************/
  wire [15:0] s_ica_15_0;
  wire [13:0] s_la_23_10_out;
  wire [15:0] s_pcr_15_0;
  wire [ 1:0] s_xpt_1_0;
  wire [ 7:0] s_seg_7_0;
  wire [15:0] s_pcr_15_0_n;
  wire        s_a10;
  wire        s_a1617;
  wire        s_a1619;
  wire        s_a1819;
  wire        s_b1819;
  wire        s_b1821;
  wire        s_bb10;
  wire        s_c10_nand_ica10;
  wire        s_c10_nand_ica11;
  wire        s_c10_nand_ica12;
  wire        s_c10_nand_ica13;
  wire        s_c10_nand_ica14;
  wire        s_c10_nand_ica15;
  wire        s_c10;
  wire        s_d1617;
  wire        s_e1617;
  wire        s_eccrhi_n_out;
  wire        s_f1617_nand_xpt0;
  wire        s_f1617_nand_xpt1;
  wire        s_f1617;
  wire        s_ica_10_n;
  wire        s_ica_9_n;
  wire        s_ica0_1_z;
  wire        s_ica1_2_z;
  wire        s_ica2_3_z;
  wire        s_ica3_4_z;
  wire        s_ica4_5_z;
  wire        s_ica5_6_z;
  wire        s_ica6_7_z;
  wire        s_ica7_8_z;
  wire        s_ila10;
  wire        s_ila11;
  wire        s_ila12;
  wire        s_ila13;
  wire        s_ila14;
  wire        s_ila15;
  wire        s_ila16_b_z;
  wire        s_ila16_c_z;
  wire        s_ila16;
  wire        s_ila17_b_z;
  wire        s_ila17_c_z;
  wire        s_ila17;
  wire        s_ila18_a_z;
  wire        s_ila18_b_z;
  wire        s_ila18;
  wire        s_ila19_a_z;
  wire        s_ila19_b_z;
  wire        s_ila19;
  wire        s_ila20_n;
  wire        s_ila21_n;
  wire        s_ila22_n;
  wire        s_ila23_n;
  wire        s_la10_n;
  wire        s_la11_n;
  wire        s_la12_n;
  wire        s_la13_n;
  wire        s_la14_n;
  wire        s_mclk;

  /*******************************************************************************
   ** Here all input connections are defined                                     **
   *******************************************************************************/
  assign s_ica_15_0[15:0]   = ICA_15_0;
  assign s_pcr_15_0[15:0]   = PCR_15_0;
  assign s_xpt_1_0[1:0]     = XPT_1_0;
  assign s_seg_7_0[7:0]     = SEG_7_0;
  assign s_pcr_15_0_n[15:0] = PCR_15_0_N;
  assign s_a10              = A10;
  assign s_a1617            = A1617;
  assign s_a1619            = A1619;
  assign s_a1819            = A1819;
  assign s_b1819            = B1819;
  assign s_b1821            = B1821;
  assign s_bb10             = BB10;
  assign s_c10              = C10;
  assign s_d1617            = D1617;
  assign s_e1617            = E1617;
  assign s_f1617            = F1617;
  assign s_mclk             = MCLK;

  /*******************************************************************************
   ** Here all output connections are defined                                    **
   *******************************************************************************/
  assign ECCRHIN            = s_eccrhi_n_out;
  assign LA_23_10           = s_la_23_10_out[13:0];

  /*******************************************************************************
   ** Here all in-lined components are defined                                   **
   *******************************************************************************/

  // NOT Gate
  assign s_ica_9_n          = ~s_ica_15_0[9];
  assign s_ica_10_n         = ~s_ica_15_0[10];

  /*******************************************************************************
   ** Here all normal components are defined                                     **
   *******************************************************************************/
  NAND_GATE #(
      .BubblesMask(2'b00)
  ) GATES_1 (
      .input1(s_xpt_1_0[1]),
      .input2(s_f1617),
      .result(s_f1617_nand_xpt1)
  );

  NAND_GATE #(
      .BubblesMask(2'b00)
  ) GATES_2 (
      .input1(s_xpt_1_0[0]),
      .input2(s_f1617),
      .result(s_f1617_nand_xpt0)
  );

  NAND_GATE #(
      .BubblesMask(2'b00)
  ) GATES_7 (
      .input1(s_ica_15_0[15]),
      .input2(s_c10),
      .result(s_c10_nand_ica15)
  );

  NAND_GATE #(
      .BubblesMask(2'b00)
  ) GATES_8 (
      .input1(s_ica_15_0[14]),
      .input2(s_c10),
      .result(s_c10_nand_ica14)
  );

  NAND_GATE #(
      .BubblesMask(2'b00)
  ) GATES_9 (
      .input1(s_ica_15_0[13]),
      .input2(s_c10),
      .result(s_c10_nand_ica13)
  );

  NAND_GATE #(
      .BubblesMask(2'b00)
  ) GATES_10 (
      .input1(s_ica_15_0[12]),
      .input2(s_c10),
      .result(s_c10_nand_ica12)
  );

  NAND_GATE #(
      .BubblesMask(2'b00)
  ) GATES_3 (
      .input1(s_ica_15_0[11]),
      .input2(s_c10),
      .result(s_c10_nand_ica11)
  );


  NAND_GATE #(
      .BubblesMask(2'b00)
  ) GATES_4 (
      .input1(s_ica_15_0[10]),
      .input2(s_c10),
      .result(s_c10_nand_ica10)
  );

  /** ILA **/

  NAND_GATE #(
      .BubblesMask(2'b00)
  ) GATES_5 (
      .input1(s_seg_7_0[7]),
      .input2(s_a1617),
      .result(s_ila23_n)
  );

  NAND_GATE #(
      .BubblesMask(2'b00)
  ) GATES_6 (
      .input1(s_seg_7_0[6]),
      .input2(s_a1617),
      .result(s_ila22_n)
  );

  NAND_GATE #(
      .BubblesMask(2'b00)
  ) GATES_11 (
      .input1(s_seg_7_0[5]),
      .input2(s_b1821),
      .result(s_ila21_n)
  );

  NAND_GATE #(
      .BubblesMask(2'b00)
  ) GATES_12 (
      .input1(s_seg_7_0[4]),
      .input2(s_b1821),
      .result(s_ila20_n)
  );

  OR_GATE #(
      .BubblesMask(2'b11)
  ) GATES_13 (
      .input1(s_ica1_2_z),
      .input2(s_c10_nand_ica11),
      .result(s_ila11)
  );

  OR_GATE #(
      .BubblesMask(2'b11)
  ) GATES_14 (
      .input1(s_ica0_1_z),
      .input2(s_c10_nand_ica10),
      .result(s_ila10)
  );

  OR_GATE #(
      .BubblesMask(2'b11)
  ) GATES_15 (
      .input1(s_ila19_a_z),
      .input2(s_ila19_b_z),
      .result(s_ila19)
  );

  OR_GATE #(
      .BubblesMask(2'b11)
  ) GATES_16 (
      .input1(s_ila18_a_z),
      .input2(s_ila18_b_z),
      .result(s_ila18)
  );

  OR_GATE #(
      .BubblesMask(2'b11)
  ) GATES_17 (
      .input1(s_ica5_6_z),
      .input2(s_c10_nand_ica15),
      .result(s_ila15)
  );

  OR_GATE #(
      .BubblesMask(2'b11)
  ) GATES_18 (
      .input1(s_ica4_5_z),
      .input2(s_c10_nand_ica14),
      .result(s_ila14)
  );

  OR_GATE #(
      .BubblesMask(2'b11)
  ) GATES_19 (
      .input1(s_ica3_4_z),
      .input2(s_c10_nand_ica13),
      .result(s_ila13)
  );

  OR_GATE #(
      .BubblesMask(2'b11)
  ) GATES_20 (
      .input1(s_ica2_3_z),
      .input2(s_c10_nand_ica12),
      .result(s_ila12)
  );

  OR_GATE_4_INPUTS #(
      .BubblesMask(4'hF)
  ) GATES_21 (
      .input1(s_ica6_7_z),
      .input2(s_ila16_b_z),
      .input3(s_ila16_c_z),
      .input4(s_f1617_nand_xpt0),
      .result(s_ila16)
  );

  OR_GATE_4_INPUTS #(
      .BubblesMask(4'hF)
  ) GATES_22 (
      .input1(s_ica7_8_z),
      .input2(s_ila17_b_z),
      .input3(s_ila17_c_z),
      .input4(s_f1617_nand_xpt1),
      .result(s_ila17)
  );

  NAND_GATE_6_INPUTS #(
      .BubblesMask({2'b00, 4'h0})
  ) GATES_23 (
      .input1(s_la_23_10_out[5]),
      .input2(s_la10_n),
      .input3(s_la11_n),
      .input4(s_la12_n),
      .input5(s_la13_n),
      .input6(s_la14_n),
      .result(s_eccrhi_n_out)
  );


  /*******************************************************************************
   ** Here all sub-circuits are defined                                          **
   *******************************************************************************/


  /** ICA **/
  A02 ILA17A (
      .A(s_ica_15_0[7]),
      .B(s_a10),
      .C(s_ica_15_0[8]),
      .D(s_bb10),
      .Z(s_ica7_8_z)
  );

  A02 ILA16A (
      .A(s_ica_15_0[6]),
      .B(s_a10),
      .C(s_ica_15_0[7]),
      .D(s_bb10),
      .Z(s_ica6_7_z)
  );

  A02 ILA15A (
      .A(s_ica_15_0[5]),
      .B(s_a10),
      .C(s_ica_15_0[6]),
      .D(s_bb10),
      .Z(s_ica5_6_z)
  );

  A02 ILA14A (
      .A(s_ica_15_0[4]),
      .B(s_a10),
      .C(s_ica_15_0[5]),
      .D(s_bb10),
      .Z(s_ica4_5_z)
  );

  A02 ILA13A (
      .A(s_ica_15_0[3]),
      .B(s_a10),
      .C(s_ica_15_0[4]),
      .D(s_bb10),
      .Z(s_ica3_4_z)
  );

  A02 ILA12A (
      .A(s_ica_15_0[2]),
      .B(s_a10),
      .C(s_ica_15_0[3]),
      .D(s_bb10),
      .Z(s_ica2_3_z)
  );

  A02 ILA11A (
      .A(s_ica_15_0[1]),
      .B(s_a10),
      .C(s_ica_15_0[2]),
      .D(s_bb10),
      .Z(s_ica1_2_z)
  );

  A02 ILA10A (
      .A(s_ica_15_0[0]),
      .B(s_a10),
      .C(s_ica_15_0[1]),
      .D(s_bb10),
      .Z(s_ica0_1_z)
  );


  /** PCR **/
  A02 ILA17B (
      .A(s_pcr_15_0[12]),
      .B(s_a1619),
      .C(s_seg_7_0[1]),
      .D(s_a1617),
      .Z(s_ila17_b_z)
  );

  A02 ILA16B (
      .A(s_pcr_15_0[11]),
      .B(s_a1619),
      .C(s_seg_7_0[0]),
      .D(s_a1617),
      .Z(s_ila16_b_z)
  );

  A02 ILA17C (
      .A(s_pcr_15_0[10]),
      .B(s_d1617),
      .C(s_pcr_15_0[8]),
      .D(s_e1617),
      .Z(s_ila17_c_z)
  );

  A02 ILA16C (
      .A(s_pcr_15_0[9]),
      .B(s_d1617),
      .C(s_pcr_15_0[7]),
      .D(s_e1617),
      .Z(s_ila16_c_z)
  );


  /********/

  A02 ILA19A (
      .A(s_a1619),
      .B(s_pcr_15_0_n[14]),
      .C(s_seg_7_0[3]),
      .D(s_b1821),
      .Z(s_ila19_a_z)
  );

  A02 ILA19B (
      .A(s_ica_10_n),
      .B(s_a1819),
      .C(s_pcr_15_0_n[10]),
      .D(s_b1819),
      .Z(s_ila19_b_z)
  );


  A02 ILA18A (
      .A(s_a1619),
      .B(s_pcr_15_0_n[13]),
      .C(s_pcr_15_0_n[9]),
      .D(s_b1819),
      .Z(s_ila18_a_z)
  );

  A02 ILA18B (
      .A(s_seg_7_0[2]),
      .B(s_b1821),
      .C(s_ica_9_n),
      .D(s_a1819),
      .Z(s_ila18_b_z)
  );


  R81 R_LA_H (
      .CP(s_mclk),

      .A  (1'b0),
      .B  (1'b0),
      .C  (s_ila23_n),
      .D  (s_ila22_n),
      .E  (s_ila21_n),
      .F  (s_ila20_n),
      .G  (s_ila19),
      .H  (s_ila18),
      .QA (),
      .QAN(),
      .QB (),
      .QBN(),
      .QC (),
      .QCN(s_la_23_10_out[13]),
      .QD (),
      .QDN(s_la_23_10_out[12]),
      .QE (),
      .QEN(s_la_23_10_out[11]),
      .QF (),
      .QFN(s_la_23_10_out[10]),
      .QG (s_la_23_10_out[9]),
      .QGN(),
      .QH (s_la_23_10_out[8]),
      .QHN()
  );

  R81 R_LA_L (
      .CP(s_mclk),

      .A  (s_ila17),
      .B  (s_ila16),
      .C  (s_ila15),
      .D  (s_ila14),
      .E  (s_ila13),
      .F  (s_ila12),
      .G  (s_ila11),
      .H  (s_ila10),
      .QA (s_la_23_10_out[7]),
      .QAN(),
      .QB (s_la_23_10_out[6]),
      .QBN(),
      .QC (s_la_23_10_out[5]),
      .QCN(),
      .QD (s_la_23_10_out[4]),
      .QDN(s_la14_n),
      .QE (s_la_23_10_out[3]),
      .QEN(s_la13_n),
      .QF (s_la_23_10_out[2]),
      .QFN(s_la12_n),
      .QG (s_la_23_10_out[1]),
      .QGN(s_la11_n),
      .QH (s_la_23_10_out[0]),
      .QHN(s_la10_n)
  );

endmodule

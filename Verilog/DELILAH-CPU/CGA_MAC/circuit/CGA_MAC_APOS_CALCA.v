/**************************************************************************
** ND120 CGA (CPU Gate Array / DELILAH)                                  **
** /CGA/MAC/APOS/CALCA                                                   **
** CALCA                                                                 **
**                                                                       **
** Page 32                                                               **
** SHEET 1 of 1                                                          **
**                                                                       **
** Last reviewed: 10-NOV-2024                                            **
** Ronny Hansen                                                          **
***************************************************************************/

module CGA_MAC_APOS_CALCA (
    input        ECCRHIN,
    input [15:0] ICA_15_0,
    input        MCLK,

    output        ECCR,
    output [15:0] LCA_15_0,
    output [ 9:0] MCA_9_0
);

  /*******************************************************************************
   ** The wires are defined here                                                 **
   *******************************************************************************/
  wire [ 9:0] s_mca_9_0_out;
  wire [15:0] s_lca_15_0_out;
  wire [15:0] s_ica_15_0;
  wire [ 9:0] s_lca_15_0_n_out;
  wire        s_eccr_out;
  wire        s_eccrhi_n;
  wire        s_gates1_out;
  wire        s_gates2_out;
  wire        s_mca_10;
  wire        s_mca_11;
  wire        s_mca_12;
  wire        s_mca13;
  wire        s_mca14;
  wire        s_mca15;
  wire        s_mclk_n;
  wire        s_mclk;


  /*******************************************************************************
   ** Here all input connections are defined                                     **
   *******************************************************************************/
  assign s_ica_15_0[15:0] = ICA_15_0;
  assign s_mclk           = MCLK;
  assign s_eccrhi_n       = ECCRHIN;

  /*******************************************************************************
   ** Here all output connections are defined                                    **
   *******************************************************************************/
  assign ECCR             = s_eccr_out;
  assign LCA_15_0         = s_lca_15_0_out[15:0];
  assign MCA_9_0          = s_mca_9_0_out[9:0];

  /*******************************************************************************
   ** Here all in-lined components are defined                                   **
   *******************************************************************************/

  // NOT Gate
  assign s_mclk_n         = ~s_mclk;

  /*******************************************************************************
   ** Here all normal components are defined                                     **
   *******************************************************************************/
  NAND_GATE_5_INPUTS #(
      .BubblesMask({1'b0, 4'h0})
  ) GATES_1 (
      .input1(s_lca_15_0_out[0]),
      .input2(s_lca_15_0_n_out[1]),
      .input3(s_lca_15_0_out[2]),
      .input4(s_lca_15_0_out[3]),
      .input5(s_lca_15_0_n_out[4]),
      .result(s_gates1_out)
  );

  NAND_GATE_5_INPUTS #(
      .BubblesMask({1'b0, 4'h0})
  ) GATES_2 (
      .input1(s_lca_15_0_n_out[5]),
      .input2(s_lca_15_0_out[6]),
      .input3(s_lca_15_0_n_out[7]),
      .input4(s_lca_15_0_n_out[8]),
      .input5(s_lca_15_0_n_out[9]),
      .result(s_gates2_out)
  );

  AND_GATE_3_INPUTS #(
      .BubblesMask(3'b111)
  ) GATES_3 (
      .input1(s_eccrhi_n),
      .input2(s_gates1_out),
      .input3(s_gates2_out),
      .result(s_eccr_out)
  );


  /*******************************************************************************
   ** Here all sub-circuits are defined                                          **
   *******************************************************************************/

  R81 R_LO (
      .CP(s_mclk),
      .A (s_mca_9_0_out[0]),
      .B (s_mca_9_0_out[1]),
      .C (s_mca_9_0_out[2]),
      .D (s_mca_9_0_out[3]),
      .E (s_mca_9_0_out[4]),
      .F (s_mca_9_0_out[5]),
      .G (s_mca_9_0_out[6]),
      .H (s_mca_9_0_out[7]),

      .QA (s_lca_15_0_out[0]),
      .QAN(),

      .QB (s_lca_15_0_out[1]),
      .QBN(s_lca_15_0_n_out[1]),

      .QC (s_lca_15_0_out[2]),
      .QCN(),

      .QD (s_lca_15_0_out[3]),
      .QDN(),

      .QE (s_lca_15_0_out[4]),
      .QEN(s_lca_15_0_n_out[4]),

      .QF (s_lca_15_0_out[5]),
      .QFN(s_lca_15_0_n_out[5]),

      .QG (s_lca_15_0_out[6]),
      .QGN(),

      .QH (s_lca_15_0_out[7]),
      .QHN(s_lca_15_0_n_out[7])
  );

  R81 R_HI (
      .CP(s_mclk),
      .A (s_mca_9_0_out[8]),
      .B (s_mca_9_0_out[9]),
      .C (s_mca_10),
      .D (s_mca_11),
      .E (s_mca_12),
      .F (s_mca13),
      .G (s_mca14),
      .H (s_mca15),

      .QA (s_lca_15_0_out[8]),
      .QAN(s_lca_15_0_n_out[8]),

      .QB (s_lca_15_0_out[9]),
      .QBN(s_lca_15_0_n_out[9]),

      .QC (s_lca_15_0_out[10]),
      .QCN(),

      .QD (s_lca_15_0_out[11]),
      .QDN(),

      .QE (s_lca_15_0_out[12]),
      .QEN(),

      .QF (s_lca_15_0_out[13]),
      .QFN(),

      .QG (s_lca_15_0_out[14]),
      .QGN(),

      .QH (s_lca_15_0_out[15]),
      .QHN()
  );

  L8 L_LO (
      .L(s_mclk_n),

      .A(s_ica_15_0[0]),
      .B(s_ica_15_0[1]),
      .C(s_ica_15_0[2]),
      .D(s_ica_15_0[3]),
      .E(s_ica_15_0[4]),
      .F(s_ica_15_0[5]),
      .G(s_ica_15_0[6]),
      .H(s_ica_15_0[7]),

      .QA (s_mca_9_0_out[0]),
      .QAN(),
      .QB (s_mca_9_0_out[1]),
      .QBN(),
      .QC (s_mca_9_0_out[2]),
      .QCN(),
      .QD (s_mca_9_0_out[3]),
      .QDN(),
      .QE (s_mca_9_0_out[4]),
      .QEN(),
      .QF (s_mca_9_0_out[5]),
      .QFN(),
      .QG (s_mca_9_0_out[6]),
      .QGN(),
      .QH (s_mca_9_0_out[7]),
      .QHN()
  );

  L8 L_HI (
      .L(s_mclk_n),

      .A(s_ica_15_0[8]),
      .B(s_ica_15_0[9]),
      .C(s_ica_15_0[10]),
      .D(s_ica_15_0[11]),
      .E(s_ica_15_0[12]),
      .F(s_ica_15_0[13]),
      .G(s_ica_15_0[14]),
      .H(s_ica_15_0[15]),

      .QA (s_mca_9_0_out[8]),
      .QAN(),
      .QB (s_mca_9_0_out[9]),
      .QBN(),
      .QC (s_mca_10),
      .QCN(),
      .QD (s_mca_11),
      .QDN(),
      .QE (s_mca_12),
      .QEN(),
      .QF (s_mca13),
      .QFN(),
      .QG (s_mca14),
      .QGN(),
      .QH (s_mca15),
      .QHN()
  );

endmodule

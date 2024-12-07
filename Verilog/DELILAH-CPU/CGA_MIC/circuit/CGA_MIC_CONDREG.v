/**************************************************************************
** ND120 CGA (CPU Gate Array / DELILAH)                                  **
** /CGA/MIC/CONDREG                                                      **
** CONDITION REGISTER                                                    **
**                                                                       **
** Page 15                                                               **
** SHEET 1 of 1                                                          **
**                                                                       **
** Last reviewed: 10-NOV-2024                                            **
** Ronny Hansen                                                          **
***************************************************************************/

module CGA_MIC_CONDREG (
    input [11:0] CSBIT_11_0,
    input        CSSCOND,
    input        LCSN,
    input        MCLK,

    output       ACONDN,
    output [3:0] FS_6_3,
    output [3:0] LCC_3_0,
    output [3:0] TSEL_3_0
);

  /*******************************************************************************
   ** The wires are defined here                                                 **
   *******************************************************************************/
  wire [ 3:0] s_fc_6_3_out;
  wire [ 3:0] s_lcc_3_0_out;
  wire [11:0] s_csbit_11_0;
  wire [ 3:0] s_tsel_3_0_out;
  wire        s_acond_n_out;
  wire        s_csbit4_q;
  wire        s_csbit5_q;
  wire        s_csbit6_q;
  wire        s_csbit7_q;
  wire        s_csbit7_qn;
  wire        s_cscond_n;
  wire        s_csscond;
  wire        s_gates3_out;
  wire        s_gates4_out;
  wire        s_gates7_out;
  wire        s_lcs_n;
  wire        s_mclk;
  wire        s_tsel_3_0_n_out;

  /*******************************************************************************
   ** The module functionality is described here                                 **
   *******************************************************************************/

  /*******************************************************************************
   ** Here all input connections are defined                                     **
   *******************************************************************************/
  assign s_csbit_11_0[11:0] = CSBIT_11_0;
  assign s_csscond          = CSSCOND;
  assign s_lcs_n            = LCSN;
  assign s_mclk             = MCLK;

  /*******************************************************************************
   ** Here all output connections are defined                                    **
   *******************************************************************************/
  assign ACONDN             = s_acond_n_out;
  assign FS_6_3             = s_fc_6_3_out[3:0];
  assign LCC_3_0            = s_lcc_3_0_out[3:0];
  assign TSEL_3_0           = s_tsel_3_0_out[3:0];

  /*******************************************************************************
   ** Here all in-lined components are defined                                   **
   *******************************************************************************/

  // NOT Gate
  assign s_cscond_n         = ~s_csscond;

  // NOT Gate
  assign s_tsel_3_0_out[0]  = ~s_tsel_3_0_n_out;

  /*******************************************************************************
   ** Here all normal components are defined                                     **
   *******************************************************************************/
  NAND_GATE #(
      .BubblesMask(2'b00)
  ) GATES_1 (
      .input1(s_lcs_n),
      .input2(s_csbit7_qn),
      .result(s_tsel_3_0_out[3])
  );

  AND_GATE #(
      .BubblesMask(2'b00)
  ) GATES_2 (
      .input1(s_lcs_n),
      .input2(s_csbit6_q),
      .result(s_tsel_3_0_out[2])
  );

  XNOR_GATE_ONEHOT #(
      .BubblesMask(2'b00)
  ) GATES_3 (
      .input1(s_tsel_3_0_out[2]),
      .input2(s_tsel_3_0_out[1]),
      .result(s_gates3_out)
  );

  NAND_GATE #(
      .BubblesMask(2'b00)
  ) GATES_4 (
      .input1(s_gates3_out),
      .input2(s_gates7_out),
      .result(s_gates4_out)
  );

  NAND_GATE #(
      .BubblesMask(2'b00)
  ) GATES_5 (
      .input1(s_gates4_out),
      .input2(s_tsel_3_0_out[3]),
      .result(s_acond_n_out)
  );

  AND_GATE #(
      .BubblesMask(2'b00)
  ) GATES_6 (
      .input1(s_lcs_n),
      .input2(s_csbit5_q),
      .result(s_tsel_3_0_out[1])
  );

  NAND_GATE #(
      .BubblesMask(2'b00)
  ) GATES_7 (
      .input1(s_tsel_3_0_out[1]),
      .input2(s_tsel_3_0_n_out),
      .result(s_gates7_out)
  );

  NAND_GATE #(
      .BubblesMask(2'b00)
  ) GATES_8 (
      .input1(s_lcs_n),
      .input2(s_csbit4_q),
      .result(s_tsel_3_0_n_out)
  );


  /*******************************************************************************
   ** Here all sub-circuits are defined                                          **
   *******************************************************************************/
  SCAN_FF CSBIT11 (
      .CLK(s_mclk),
      .D  (s_csbit_11_0[11]),
      .Q  (s_lcc_3_0_out[3]),
      .QN (),
      .TE (s_cscond_n),
      .TI (s_lcc_3_0_out[3])
  );

  SCAN_FF CSBIT10 (
      .CLK(s_mclk),
      .D  (s_csbit_11_0[10]),
      .Q  (s_lcc_3_0_out[2]),
      .QN (),
      .TE (s_cscond_n),
      .TI (s_lcc_3_0_out[2])
  );

  SCAN_FF CSBIT9 (
      .CLK(s_mclk),
      .D  (s_csbit_11_0[9]),
      .Q  (s_lcc_3_0_out[1]),
      .QN (),
      .TE (s_cscond_n),
      .TI (s_lcc_3_0_out[1])
  );

  SCAN_FF CSBIT8 (
      .CLK(s_mclk),
      .D  (s_csbit_11_0[8]),
      .Q  (s_lcc_3_0_out[0]),
      .QN (),
      .TE (s_cscond_n),
      .TI (s_lcc_3_0_out[0])
  );

  SCAN_FF CSBIT7 (
      .CLK(s_mclk),
      .D  (s_csbit_11_0[7]),
      .Q  (s_csbit7_q),
      .QN (s_csbit7_qn),
      .TE (s_cscond_n),
      .TI (s_csbit7_q)
  );

  SCAN_FF CSBIT6 (
      .CLK(s_mclk),
      .D  (s_csbit_11_0[6]),
      .Q  (s_csbit6_q),
      .QN (),
      .TE (s_cscond_n),
      .TI (s_csbit6_q)
  );

  SCAN_FF CSBIT5 (
      .CLK(s_mclk),
      .D  (s_csbit_11_0[5]),
      .Q  (s_csbit5_q),
      .QN (),
      .TE (s_cscond_n),
      .TI (s_csbit5_q)
  );

  SCAN_FF CSBIT4 (
      .CLK(s_mclk),
      .D  (s_csbit_11_0[4]),
      .Q  (s_csbit4_q),
      .QN (),
      .TE (s_cscond_n),
      .TI (s_csbit4_q)
  );

  SCAN_FF CSBIT3 (
      .CLK(s_mclk),
      .D  (s_csbit_11_0[3]),
      .Q  (s_fc_6_3_out[3]),
      .QN (),
      .TE (s_cscond_n),
      .TI (s_fc_6_3_out[3])
  );

  SCAN_FF CSBIT2 (
      .CLK(s_mclk),
      .D  (s_csbit_11_0[2]),
      .Q  (s_fc_6_3_out[2]),
      .QN (),
      .TE (s_cscond_n),
      .TI (s_fc_6_3_out[2])
  );

  SCAN_FF CSBIT1 (
      .CLK(s_mclk),
      .D  (s_csbit_11_0[1]),
      .Q  (s_fc_6_3_out[1]),
      .QN (),
      .TE (s_cscond_n),
      .TI (s_fc_6_3_out[1])
  );

  SCAN_FF CSBIT0 (
      .CLK(s_mclk),
      .D  (s_csbit_11_0[0]),
      .Q  (s_fc_6_3_out[0]),
      .QN (),
      .TE (s_cscond_n),
      .TI (s_fc_6_3_out[0])
  );



endmodule

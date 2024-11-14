/**************************************************************************
** ND120 CGA (CPU Gate Array / DELILAH)                                  **
** /CGA/MIC/INCOUNT                                                      **
** INCOUNT                                                               **
**                                                                       **
** Page 23                                                               **
** SHEET 1 of 1                                                          **
**                                                                       **
** Last reviewed: 10-NOV-2024                                            **
** Ronny Hansen                                                          **
***************************************************************************/

module CGA_MIC_INCOUNT (
    input CD0,
    input CD1,
    input EC,
    input LWCAN,
    input MCLK,
    input MRN,

    output CSWAN0,
    output CSWAN1
);

  /*******************************************************************************
   ** The wires are defined here                                                 **
   *******************************************************************************/
  wire s_cd0;
  wire s_cd1;
  wire s_cswan0_out;
  wire s_cswan1_out;
  wire s_ec;
  wire s_ff6_qn_out;
  wire s_ff7_qn_out;
  wire s_gates1_out;
  wire s_gates2_out;
  wire s_gates3_out;
  wire s_lwca_n;
  wire s_mclk;
  wire s_mr_n;
  wire s_mr;
  wire s_plexers4_n_out;
  wire s_plexers4_out;
  wire s_plexers5_n_out;
  wire s_plexers5_out;

  /*******************************************************************************
   ** The module functionality is described here                                 **
   *******************************************************************************/

  /*******************************************************************************
   ** Here all input connections are defined                                     **
   *******************************************************************************/
  assign s_mclk           = MCLK;
  assign s_cd0            = CD0;
  assign s_mr_n           = MRN;
  assign s_cd1            = CD1;
  assign s_lwca_n         = LWCAN;
  assign s_ec             = EC;

  /*******************************************************************************
   ** Here all output connections are defined                                    **
   *******************************************************************************/
  assign CSWAN0           = s_cswan0_out;
  assign CSWAN1           = s_cswan1_out;

  /*******************************************************************************
   ** Here all in-lined components are defined                                   **
   *******************************************************************************/

  // NOT Gate
  assign s_plexers4_n_out = ~s_plexers4_out;
  assign s_plexers5_n_out = ~s_plexers5_out;
  assign s_mr             = ~s_mr_n;

  /*******************************************************************************
   ** Here all normal components are defined                                     **
   *******************************************************************************/
  XOR_GATE_ONEHOT #(
      .BubblesMask(2'b00)
  ) GATES_1 (
      .input1(s_ec),
      .input2(s_ff6_qn_out),
      .result(s_gates1_out)
  );

  NAND_GATE #(
      .BubblesMask(2'b00)
  ) GATES_2 (
      .input1(s_ff6_qn_out),
      .input2(s_ec),
      .result(s_gates2_out)
  );

  XNOR_GATE_ONEHOT #(
      .BubblesMask(2'b00)
  ) GATES_3 (
      .input1(s_gates2_out),
      .input2(s_ff7_qn_out),
      .result(s_gates3_out)
  );

  Multiplexer_2 PLEXERS_4 (
      .muxIn_0(s_cd0),
      .muxIn_1(s_gates1_out),
      .muxOut(s_plexers4_out),
      .sel(s_lwca_n)
  );

  Multiplexer_2 PLEXERS_5 (
      .muxIn_0(s_cd1),
      .muxIn_1(s_gates3_out),
      .muxOut(s_plexers5_out),
      .sel(s_lwca_n)
  );

  D_FLIPFLOP #(
      .InvertClockEnable(0)
  ) MEMORY_6 (
      .clock(s_mclk),
      .d(s_plexers4_n_out),
      .preset(s_mr),
      .q(s_cswan0_out),
      .qBar(s_ff6_qn_out),
      .reset(1'b0),
      .tick(1'b1)
  );

  D_FLIPFLOP #(
      .InvertClockEnable(0)
  ) MEMORY_7 (
      .clock(s_mclk),
      .d(s_plexers5_n_out),
      .preset(s_mr),
      .q(s_cswan1_out),
      .qBar(s_ff7_qn_out),
      .reset(1'b0),
      .tick(1'b1)
  );


endmodule

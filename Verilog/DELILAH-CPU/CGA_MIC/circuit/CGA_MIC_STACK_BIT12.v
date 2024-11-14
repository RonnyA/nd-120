/**************************************************************************
** ND120 CGA (CPU Gate Array / DELILAH)                                  **
** /CGA/MIC/STACK/BIT12                                                  **
** BIT12                                                                 **
**                                                                       **
** Page 18                                                               **
** SHEET 1 of 1                                                          **
**                                                                       **
** Last reviewed: 10-NOV-2024                                            **
** Ronny Hansen                                                          **
***************************************************************************/


module CGA_MIC_STACK_BIT12 (
    input LOAD,
    input MCLK,
    input S3,
    input S3N,
    input S4NS3N,
    input S4S3N,
    input SCLKN,
    input STIN,

    output DEEP,
    output STOUT
);

  /*******************************************************************************
   ** The wires are defined here                                                 **
   *******************************************************************************/
  wire s_gates4_out;
  wire s_gates7_out;
  wire s_s3_n;
  wire s_load;
  wire s_gates1_out;
  wire s_sti_n;
  wire s_gates9_out;
  wire s_mclk;
  wire s_sclk_n;
  wire s_sr44_qdn_out;
  wire s_s3;
  wire s_gates5_out;
  wire s_ff_sti_n_out;
  wire s_gates8_out;
  wire s_gates2_out;
  wire s_s4_s3_n;
  wire s_gates3_out;
  wire s_gates10_out;
  wire s_stout_out;
  wire s_deep_out;
  wire s_sr44_qbn_out;
  wire s_sr44_qcn_out;
  wire s_gates6_out;
  wire s_s4n_s3n;

  /*******************************************************************************
   ** The module functionality is described here                                 **
   *******************************************************************************/

  /*******************************************************************************
   ** Here all input connections are defined                                     **
   *******************************************************************************/
  assign s_load    = LOAD;
  assign s_mclk    = MCLK;
  assign s_s3      = S3;
  assign s_s3_n    = S3N;
  assign s_s4_s3_n = S4S3N;
  assign s_s4n_s3n = S4NS3N;
  assign s_sclk_n  = SCLKN;
  assign s_sti_n   = STIN;

  /*******************************************************************************
   ** Here all output connections are defined                                    **
   *******************************************************************************/
  assign DEEP      = s_deep_out;
  assign STOUT     = s_stout_out;

  /*******************************************************************************
   ** Here all normal components are defined                                     **
   *******************************************************************************/
  NAND_GATE #(
      .BubblesMask(2'b00)
  ) GATES_1 (
      .input1(s_ff_sti_n_out),
      .input2(s_s4_s3_n),
      .result(s_gates1_out)
  );

  NAND_GATE #(
      .BubblesMask(2'b00)
  ) GATES_2 (
      .input1(s_stout_out),
      .input2(s_s4n_s3n),
      .result(s_gates2_out)
  );

  OR_GATE #(
      .BubblesMask(2'b00)
  ) GATES_3 (
      .input1(s_sr44_qbn_out),
      .input2(s_s3_n),
      .result(s_gates3_out)
  );

  OR_GATE #(
      .BubblesMask(2'b00)
  ) GATES_4 (
      .input1(s_s3),
      .input2(s_sr44_qbn_out),
      .result(s_gates4_out)
  );

  OR_GATE #(
      .BubblesMask(2'b00)
  ) GATES_5 (
      .input1(s_s3_n),
      .input2(s_sr44_qcn_out),
      .result(s_gates5_out)
  );

  OR_GATE #(
      .BubblesMask(2'b00)
  ) GATES_6 (
      .input1(s_s3),
      .input2(s_sr44_qcn_out),
      .result(s_gates6_out)
  );

  OR_GATE #(
      .BubblesMask(2'b00)
  ) GATES_7 (
      .input1(s_s3_n),
      .input2(s_sr44_qdn_out),
      .result(s_gates7_out)
  );

  NAND_GATE_3_INPUTS #(
      .BubblesMask(3'b000)
  ) GATES_8 (
      .input1(s_gates3_out),
      .input2(s_gates1_out),
      .input3(s_gates2_out),
      .result(s_gates8_out)
  );

  NAND_GATE #(
      .BubblesMask(2'b00)
  ) GATES_9 (
      .input1(s_gates4_out),
      .input2(s_gates5_out),
      .result(s_gates9_out)
  );

  NAND_GATE #(
      .BubblesMask(2'b00)
  ) GATES_10 (
      .input1(s_gates6_out),
      .input2(s_gates7_out),
      .result(s_gates10_out)
  );

  D_FLIPFLOP #(
      .InvertClockEnable(0)
  ) MEMORY_11 (
      .clock(s_mclk),
      .d(s_sti_n),
      .preset(1'b0),
      .q(s_ff_sti_n_out),
      .qBar(),
      .reset(1'b0),
      .tick(1'b1)
  );


  /*******************************************************************************
   ** Here all sub-circuits are defined                                          **
   *******************************************************************************/

  SR44 SR44_2 (
      .CP(s_sclk_n),

      .A  (s_gates8_out),
      .B  (s_gates9_out),
      .C  (s_gates10_out),
      .D  (s_deep_out),
      .L  (s_load),
      .QA (s_stout_out),
      .QAN(),
      .QB (),
      .QBN(s_sr44_qbn_out),
      .QC (),
      .QCN(s_sr44_qcn_out),
      .QD (s_deep_out),
      .QDN(s_sr44_qdn_out),
      .SI (s_ff_sti_n_out)
  );

endmodule

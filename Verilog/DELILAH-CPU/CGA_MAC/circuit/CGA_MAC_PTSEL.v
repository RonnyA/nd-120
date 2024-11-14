/**************************************************************************
** ND120 CGA (CPU Gate Array / DELILAH)                                  **
 ** /CGA/MAC/PTSEL                                                       **
** PTSEL                                                                 **
**                                                                       **
** Page 34                                                               **
** SHEET 1 of 1                                                          **
**                                                                       **
** Last reviewed: 10-NOV-2024                                            **
** Ronny Hansen                                                          **
***************************************************************************/

module CGA_MAC_PTSEL (
    input MCLK,
    input PONI,
    input PTM,
    input SAPT,
    input SPTN,

    output SELPTN
);

  /*******************************************************************************
   ** The wires are defined here                                                 **
   *******************************************************************************/
  wire s_sapt;
  wire s_gates2_out;
  wire s_mclk;
  wire s_gates1_n_out;
  wire s_spt;
  wire s_gates3_out;
  wire s_gates4_out;
  wire s_ptm;
  wire s_poni;
  wire s_gates1_out;
  wire s_jkff_q_n_out;
  wire s_spt_n;
  wire s_gnd;

  /*******************************************************************************
   ** Here all input connections are defined                                     **
   *******************************************************************************/
  assign s_sapt = SAPT;
  assign s_mclk = MCLK;
  assign s_ptm = PTM;
  assign s_poni = PONI;
  assign s_spt_n = SPTN;

  /*******************************************************************************
   ** Here all output connections are defined                                    **
   *******************************************************************************/
  assign SELPTN = s_gates4_out;

  /*******************************************************************************
   ** Here all in-lined components are defined                                   **
   *******************************************************************************/

  // Ground
  assign s_gnd = 1'b0;

  // NOT Gate
  assign s_spt = ~s_spt_n;
  assign s_gates1_n_out = ~s_gates1_out;

  /*******************************************************************************
   ** Here all normal components are defined                                     **
   *******************************************************************************/
  NOR_GATE #(
      .BubblesMask(2'b11)
  ) GATES_1 (
      .input1(s_ptm),
      .input2(s_poni),
      .result(s_gates1_out)
  );

  OR_GATE #(
      .BubblesMask(2'b11)
  ) GATES_2 (
      .input1(s_spt_n),
      .input2(s_jkff_q_n_out),
      .result(s_gates2_out)
  );

  OR_GATE_3_INPUTS #(
      .BubblesMask(3'b111)
  ) GATES_3 (
      .input1(s_sapt),
      .input2(s_poni),
      .input3(s_ptm),
      .result(s_gates3_out)
  );

  NAND_GATE #(
      .BubblesMask(2'b00)
  ) GATES_4 (
      .input1(s_gates2_out),
      .input2(s_gates3_out),
      .result(s_gates4_out)
  );

  J_K_FLIPFLOP #(
      .InvertClockEnable(0)
  ) MEMORY_5 (
      .clock(s_mclk),
      .j(s_spt),
      .k(s_sapt),
      .preset(s_gates1_n_out),
      .q(),
      .qBar(s_jkff_q_n_out),
      .reset(s_gnd),
      .tick(1'b1)
  );


endmodule

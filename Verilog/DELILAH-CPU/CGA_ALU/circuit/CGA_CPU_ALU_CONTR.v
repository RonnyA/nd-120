/**************************************************************************
** ND120 CGA (CPU Gate Array / DELILAH)                                  **
** /CGA/ALU/CONTR                                                        **
** ALU CONTROLLER                                                        **
**                                                                       **
** Page 42                                                               **
** SHEET 1 of 1                                                          **
**                                                                       **
** Last reviewed: 10-NOV-2024                                            **
** Ronny Hansen                                                          **
***************************************************************************/

module CGA_CPU_ALU_CONTR (
    input       ALUCLK,
    input [1:0] CD_10_9,
    input       CRY,
    input [8:0] CSALUI_8_0,
    input [1:0] CSALUM_1_0,
    input [1:0] CSCINSEL_1_0,
    input [1:0] CSMIS_1_0,
    input [1:0] CSSST_1_0,
    input       DGPR0N,
    input       F0,
    input       F15,
    input       GPR0,
    input       LCZN,
    input       LDGPRN,
    input       LDIRV,
    input       Q0,
    input       Q15,
    input       STS6,
    input       STS7,
    input       UPN,
    input       XFETCHN,

    output       ALUD2N,
    output       ALUI4,
    output       ALUI7,
    output       ALUI8N,
    output       BDEST,
    output       CI,
    output [1:0] CSTS_1_0,
    output       FSEL,
    output [2:0] GPRC_2_0,
    output       GPRLI,
    output       LOG,
    output       MI,
    output       QLI,
    output [1:0] QSEL_1_0,
    output       RA,
    output       RD,
    output       RLI,
    output       RRI,
    output       RSN,
    output       SA,
    output       SB
);
  /*******************************************************************************
   ** The wires are defined here                                                 **
   *******************************************************************************/

  wire [1:0] s_cd_10_9;
  wire [1:0] s_csalum_1_0;
  wire [1:0] s_cscinsel_1_0;
  wire [1:0] s_csmis_1_0;
  wire [1:0] s_csst_1_0;
  wire [1:0] s_csts_1_0;
  wire [1:0] s_qsel_1_0_out;
  wire [8:0] s_csalui_8_0;
  wire       s_aluclk;
  wire       s_alud2_n_out;
  wire       s_alui1n;
  wire       s_alui3n;
  wire       s_alui4_n_out;
  wire       s_alui4_out;
  wire       s_alui6_n;
  wire       s_alui6;
  wire       s_alui7_n;
  wire       s_alui7_out;
  wire       s_alui8_n_out;
  wire       s_alui8;
  wire       s_bdest_n;
  wire       s_bdest_out;
  wire       s_ci_out;
  wire       s_cinsel0;
  wire       s_cinsel1;
  wire       s_cry;
  wire       s_csalui0_n;
  wire       s_csalui2_n;
  wire       s_csalui3_n;
  wire       s_csalui4_n;
  wire       s_csalum_0_n;
  wire       s_dgpr0_n;
  wire       s_f0;
  wire       s_f15;
  wire       s_fsel_n;
  wire       s_fsel;
  wire       s_gates1_out;
  wire       s_gates10_out;
  wire       s_gates11_out;
  wire       s_gates12_out;
  wire       s_gates13_out;
  wire       s_gates14_out;
  wire       s_gates15_out;
  wire       s_gates16_out;
  wire       s_gates17_out;
  wire       s_gates18_out;
  wire       s_gates2_out;
  wire       s_gates20_out;
  wire       s_gates21_out;
  wire       s_gates22_out;
  wire       s_gates23_out;
  wire       s_gates24_out;
  wire       s_gates28_out;
  wire       s_gates29_out;
  wire       s_gates3_out;
  wire       s_gates30_out;
  wire       s_gates31_out;
  wire       s_gates32_out;
  wire       s_gates33_out;
  wire       s_gates34_out;
  wire       s_gates35_out;
  wire       s_gates39_out;
  wire       s_gates4_out;
  wire       s_gates41_out;
  wire       s_gates42_out;
  wire       s_gates43_out;
  wire       s_gates44_out;
  wire       s_gates49_out;
  wire       s_gates5_out;
  wire       s_gates50_out;
  wire       s_gates52_out;
  wire       s_gates53_out;
  wire       s_gates54_out;
  wire       s_gates55_out;
  wire       s_gates56_out;
  wire       s_gates6_out;
  wire       s_gates7_out;
  wire       s_gates8_out;
  wire       s_gates9_out;
  wire       s_gnd;
  wire       s_gpr0;
  wire       s_gprli_out;
  wire       s_ialii7_n;
  wire       s_ialii8_n;
  wire       s_icsst1;
  wire       s_isel0_n;
  wire       s_isel1_n;
  wire       s_lcz_n;
  wire       s_ldgpr_n;
  wire       s_ldirv;
  wire       s_log_n_out;
  wire       s_log_out;
  wire       s_memory46_q;
  wire       s_memory47_q;
  wire       s_mi_out;
  wire       s_power;
  wire       s_q0;
  wire       s_q15;
  wire       s_qli_out;
  wire       s_qsel_0_n_out;
  wire       s_qsel_1_n_out;
  wire       s_ra_n_out;
  wire       s_ra_out;
  wire       s_rd_n_out;
  wire       s_rd_out;
  wire       s_rli_out;
  wire       s_rri_out;
  wire       s_rsn_n_out;
  wire       s_rsn_out;
  wire       s_sa_n_out;
  wire       s_sa_out;
  wire       s_sb_n_out;
  wire       s_sb_out;
  wire       s_ssel0;
  wire       s_ssel0n;
  wire       s_ssel1;
  wire       s_ssel1n;
  wire       s_sts6;
  wire       s_sts7;
  wire       s_up_n;
  wire       s_xfetch_n;

  /*******************************************************************************
   ** The module functionality is described here                                 **
   *******************************************************************************/

  /*******************************************************************************
   ** Here all input connections are defined                                     **
   *******************************************************************************/
  assign s_csst_1_0[1:0]     = CSSST_1_0;
  assign s_csalum_1_0[1:0]   = CSALUM_1_0;
  assign s_cd_10_9[1:0]      = CD_10_9;
  assign s_csmis_1_0[1:0]    = CSMIS_1_0;
  assign s_cscinsel_1_0[1:0] = CSCINSEL_1_0;
  assign s_csalui_8_0[8:0]   = CSALUI_8_0;
  assign s_lcz_n             = LCZN;
  assign s_sts6              = STS6;
  assign s_cry               = CRY;
  assign s_ldgpr_n           = LDGPRN;
  assign s_sts7              = STS7;
  assign s_f0                = F0;
  assign s_q0                = Q0;
  assign s_f15               = F15;
  assign s_q15               = Q15;
  assign s_xfetch_n          = XFETCHN;
  assign s_dgpr0_n           = DGPR0N;
  assign s_aluclk            = ALUCLK;
  assign s_up_n              = UPN;
  assign s_ldirv             = LDIRV;
  assign s_gpr0              = GPR0;

  /*******************************************************************************
   ** Here all output connections are defined                                    **
   *******************************************************************************/
  assign ALUD2N              = s_alud2_n_out;
  assign ALUI4               = s_alui4_out;
  assign ALUI7               = s_alui7_out;
  assign ALUI8N              = s_alui8_n_out;
  assign BDEST               = s_bdest_out;
  assign CI                  = s_ci_out;
  assign CSTS_1_0            = s_csts_1_0[1:0];
  assign FSEL                = s_fsel;
  assign GPRC_2_0            = {~s_gates44_out, ~s_gates43_out, ~s_gates42_out};
  assign GPRLI               = s_gprli_out;
  assign LOG                 = s_log_out;
  assign MI                  = s_mi_out;
  assign QLI                 = s_qli_out;
  assign QSEL_1_0            = s_qsel_1_0_out[1:0];
  assign RA                  = s_ra_out;
  assign RD                  = s_rd_out;
  assign RLI                 = s_rli_out;
  assign RRI                 = s_rri_out;
  assign RSN                 = s_rsn_out;
  assign SA                  = s_sa_out;
  assign SB                  = s_sb_out;

  /*******************************************************************************
   ** Here all in-lined components are defined                                   **
   *******************************************************************************/

  // Ground
  assign s_gnd               = 1'b0;
  assign s_power             = 1'b1;


  // NOT Gate
  assign s_csalui3_n         = ~s_csalui_8_0[3];
  assign s_csalui2_n         = ~s_csalui_8_0[2];
  assign s_csalui0_n         = ~s_csalui_8_0[0];
  assign s_csalui4_n         = ~s_csalui_8_0[4];
  assign s_qsel_1_0_out[1]   = ~s_qsel_1_n_out;
  assign s_qsel_1_0_out[0]   = ~s_qsel_0_n_out;
  assign s_rsn_out           = ~s_rsn_n_out;
  assign s_fsel              = ~s_fsel_n;
  assign s_log_out           = ~s_log_n_out;
  assign s_alui4_out         = ~s_alui4_n_out;
  assign s_sb_out            = ~s_sb_n_out;
  assign s_sa_out            = ~s_sa_n_out;
  assign s_ra_out            = ~s_ra_n_out;
  assign s_rd_out            = ~s_rd_n_out;
  assign s_csalum_0_n        = ~s_csalum_1_0[0];

  // NOT Gate
  assign s_alui7_out         = ~s_alui7_n;
  assign s_alui8             = ~s_alui8_n_out;
  assign s_bdest_out         = ~s_bdest_n;



  /*******************************************************************************
   ** Here all normal components are defined                                     **
   *******************************************************************************/
  AND_GATE #(
      .BubblesMask(2'b00)
  ) GATES_1 (
      .input1(s_csalum_1_0[1]),
      .input2(s_csalum_1_0[0]),
      .result(s_gates1_out)
  );

  NOR_GATE #(
      .BubblesMask(2'b00)
  ) GATES_2 (
      .input1(s_csalum_1_0[1]),
      .input2(s_csalum_0_n),
      .result(s_gates2_out)
  );

  NAND_GATE #(
      .BubblesMask(2'b00)
  ) GATES_3 (
      .input1(s_csalum_1_0[1]),
      .input2(s_csalum_0_n),
      .result(s_gates3_out)
  );

  NAND_GATE #(
      .BubblesMask(2'b00)
  ) GATES_4 (
      .input1(s_csalui_8_0[2]),
      .input2(s_csalui_8_0[0]),
      .result(s_gates4_out)
  );

  NAND_GATE #(
      .BubblesMask(2'b00)
  ) GATES_5 (
      .input1(s_csalui_8_0[2]),
      .input2(s_alui1n),
      .result(s_gates5_out)
  );

  NAND_GATE #(
      .BubblesMask(2'b00)
  ) GATES_6 (
      .input1(s_csalui2_n),
      .input2(s_csalui_8_0[0]),
      .result(s_gates6_out)
  );

  NAND_GATE #(
      .BubblesMask(2'b00)
  ) GATES_7 (
      .input1(s_alui1n),
      .input2(s_csalui2_n),
      .result(s_gates7_out)
  );

  NAND_GATE #(
      .BubblesMask(2'b00)
  ) GATES_8 (
      .input1(s_alui1n),
      .input2(s_csalui0_n),
      .result(s_gates8_out)
  );

  NAND_GATE #(
      .BubblesMask(2'b00)
  ) GATES_9 (
      .input1(s_alui7_out),
      .input2(s_f15),
      .result(s_gates9_out)
  );

  NAND_GATE_3_INPUTS #(
      .BubblesMask(3'b000)
  ) GATES_10 (
      .input1(s_alui7_n),
      .input2(s_alui6_n),
      .input3(s_q0),
      .result(s_gates10_out)
  );

  NAND_GATE_3_INPUTS #(
      .BubblesMask(3'b000)
  ) GATES_11 (
      .input1(s_alui7_n),
      .input2(s_alui6),
      .input3(s_f0),
      .result(s_gates11_out)
  );

  NOR_GATE_3_INPUTS #(
      .BubblesMask(3'b000)
  ) GATES_12 (
      .input1(s_gates56_out),
      .input2(s_csalui_8_0[5]),
      .input3(s_gnd),
      .result(s_gates12_out)
  );

  NAND_GATE #(
      .BubblesMask(2'b00)
  ) GATES_13 (
      .input1(s_gates4_out),
      .input2(s_gates5_out),
      .result(s_gates13_out)
  );

  NAND_GATE #(
      .BubblesMask(2'b00)
  ) GATES_14 (
      .input1(s_gates5_out),
      .input2(s_gates6_out),
      .result(s_gates14_out)
  );

  NAND_GATE #(
      .BubblesMask(2'b00)
  ) GATES_15 (
      .input1(s_gates8_out),
      .input2(s_csalui_8_0[2]),
      .result(s_gates15_out)
  );

  NAND_GATE #(
      .BubblesMask(2'b00)
  ) GATES_16 (
      .input1(1'b1),
      .input2(s_f0),
      .result(s_gates16_out)
  );

  NAND_GATE #(
      .BubblesMask(2'b00)
  ) GATES_17 (
      .input1(s_q0),
      .input2(s_alui6_n),
      .result(s_gates17_out)
  );

  NAND_GATE #(
      .BubblesMask(2'b00)
  ) GATES_18 (
      .input1(s_alui6_n),
      .input2(s_q15),
      .result(s_gates18_out)
  );

  NAND_GATE_3_INPUTS #(
      .BubblesMask(3'b000)
  ) GATES_19 (
      .input1(s_gates9_out),
      .input2(s_gates10_out),
      .input3(s_gates11_out),
      .result(s_mi_out)
  );

  NOR_GATE_3_INPUTS #(
      .BubblesMask(3'b000)
  ) GATES_20 (
      .input1(s_ssel1n),
      .input2(s_ssel0),
      .input3(s_alui6),
      .result(s_gates20_out)
  );

  NOR_GATE #(
      .BubblesMask(2'b00)
  ) GATES_21 (
      .input1(s_ssel0n),
      .input2(s_ssel1),
      .result(s_gates21_out)
  );

  NOR_GATE #(
      .BubblesMask(2'b00)
  ) GATES_22 (
      .input1(s_ssel0),
      .input2(s_ssel1),
      .result(s_gates22_out)
  );

  NAND_GATE #(
      .BubblesMask(2'b00)
  ) GATES_23 (
      .input1(s_gates16_out),
      .input2(s_gates17_out),
      .result(s_gates23_out)
  );

  NOR_GATE #(
      .BubblesMask(2'b00)
  ) GATES_24 (
      .input1(s_ssel1n),
      .input2(s_ssel0n),
      .result(s_gates24_out)
  );

  NAND_GATE_3_INPUTS #(
      .BubblesMask(3'b000)
  ) GATES_25 (
      .input1(s_alui6_n),
      .input2(s_alui7_out),
      .input3(s_alui8_n_out),
      .result(s_alud2_n_out)
  );

  NAND_GATE #(
      .BubblesMask(2'b00)
  ) GATES_26 (
      .input1(s_alui6_n),
      .input2(s_alui8),
      .result(s_qsel_1_n_out)
  );

  NAND_GATE #(
      .BubblesMask(2'b00)
  ) GATES_27 (
      .input1(s_alui6_n),
      .input2(s_alui7_n),
      .result(s_qsel_0_n_out)
  );

  NAND_GATE #(
      .BubblesMask(2'b00)
  ) GATES_28 (
      .input1(s_sts7),
      .input2(s_cry),
      .result(s_gates28_out)
  );

  NAND_GATE #(
      .BubblesMask(2'b00)
  ) GATES_29 (
      .input1(s_sts7),
      .input2(s_gpr0),
      .result(s_gates29_out)
  );

  NAND_GATE #(
      .BubblesMask(2'b00)
  ) GATES_30 (
      .input1(s_gpr0),
      .input2(s_cry),
      .result(s_gates30_out)
  );

  NAND_GATE #(
      .BubblesMask(2'b00)
  ) GATES_31 (
      .input1(s_cry),
      .input2(s_gates20_out),
      .result(s_gates31_out)
  );

  NAND_GATE #(
      .BubblesMask(2'b00)
  ) GATES_32 (
      .input1(s_gates23_out),
      .input2(s_gates21_out),
      .result(s_gates32_out)
  );

  NAND_GATE #(
      .BubblesMask(2'b00)
  ) GATES_33 (
      .input1(s_f15),
      .input2(s_gates22_out),
      .result(s_gates33_out)
  );

  NAND_GATE #(
      .BubblesMask(2'b00)
  ) GATES_34 (
      .input1(s_f15),
      .input2(s_gates21_out),
      .result(s_gates34_out)
  );

  NAND_GATE #(
      .BubblesMask(2'b00)
  ) GATES_35 (
      .input1(s_sts7),
      .input2(s_gates24_out),
      .result(s_gates35_out)
  );

  NAND_GATE #(
      .BubblesMask(2'b00)
  ) GATES_36 (
      .input1(s_gates35_out),
      .input2(s_gates34_out),
      .result(s_qli_out)
  );

  NAND_GATE_4_INPUTS #(
      .BubblesMask(4'h0)
  ) GATES_37 (
      .input1(s_gates35_out),
      .input2(s_gates31_out),
      .input3(s_gates32_out),
      .input4(s_gates33_out),
      .result(s_rri_out)
  );

  NAND_GATE_3_INPUTS #(
      .BubblesMask(3'b000)
  ) GATES_38 (
      .input1(s_gates28_out),
      .input2(s_gates29_out),
      .input3(s_gates30_out),
      .result(s_gprli_out)
  );

  NAND_GATE #(
      .BubblesMask(2'b00)
  ) GATES_39 (
      .input1(s_qli_out),
      .input2(s_alui6),
      .result(s_gates39_out)
  );

  NAND_GATE #(
      .BubblesMask(2'b00)
  ) GATES_40 (
      .input1(s_gates39_out),
      .input2(s_gates18_out),
      .result(s_rli_out)
  );

  NAND_GATE #(
      .BubblesMask(2'b00)
  ) GATES_41 (
      .input1(s_xfetch_n),
      .input2(s_alui7_n),
      .result(s_gates41_out)
  );

  NAND_GATE #(
      .BubblesMask(2'b00)
  ) GATES_42 (
      .input1(s_gates41_out),
      .input2(s_ldgpr_n),
      .result(s_gates42_out)
  );

  NAND_GATE #(
      .BubblesMask(2'b00)
  ) GATES_43 (
      .input1(s_ldgpr_n),
      .input2(s_xfetch_n),
      .result(s_gates43_out)
  );

  NAND_GATE #(
      .BubblesMask(2'b00)
  ) GATES_44 (
      .input1(~s_gates43_out),
      .input2(s_alui8_n_out),
      .result(s_gates44_out)
  );

  D_FLIPFLOP #(
      .InvertClockEnable(0)
  ) MEMORY_45 (
      .clock(s_aluclk),
      .d(s_csalui_8_0[6]),
      .preset(1'b0),
      .q(s_alui6),
      .qBar(s_alui6_n),
      .reset(1'b0),
      .tick(1'b1)
  );

  D_FLIPFLOP #(
      .InvertClockEnable(0)
  ) MEMORY_46 (
      .clock(s_ldirv),
      .d(s_cd_10_9[1]),
      .preset(1'b0),
      .q(s_memory46_q),
      .qBar(),
      .reset(1'b0),
      .tick(1'b1)
  );

  D_FLIPFLOP #(
      .InvertClockEnable(0)
  ) MEMORY_47 (
      .clock(s_ldirv),
      .d(s_cd_10_9[0]),
      .preset(1'b0),
      .q(s_memory47_q),
      .qBar(),
      .reset(1'b0),
      .tick(1'b1)
  );

  NAND_GATE #(
      .BubblesMask(2'b00)
  ) GATES_48 (
      .input1(s_icsst1),
      .input2(s_gates49_out),
      .result(s_csts_1_0[1])
  );

  NAND_GATE #(
      .BubblesMask(2'b00)
  ) GATES_49 (
      .input1(s_alui8),
      .input2(s_gates1_out),
      .result(s_gates49_out)
  );

  AND_GATE #(
      .BubblesMask(2'b00)
  ) GATES_50 (
      .input1(s_ialii7_n),
      .input2(s_ialii8_n),
      .result(s_gates50_out)
  );

  D_FLIPFLOP #(
      .InvertClockEnable(0)
  ) MEMORY_51 (
      .clock(s_aluclk),
      .d(s_gates50_out),
      .preset(1'b0),
      .q(s_bdest_n),
      .qBar(),
      .reset(1'b0),
      .tick(1'b1)
  );

  AND_GATE #(
      .BubblesMask(2'b00)
  ) GATES_52 (
      .input1(s_alui3n),
      .input2(s_csalui_8_0[5]),
      .result(s_gates52_out)
  );

  AND_GATE #(
      .BubblesMask(2'b00)
  ) GATES_53 (
      .input1(s_csalui4_n),
      .input2(s_alui3n),
      .result(s_gates53_out)
  );

  NOR_GATE #(
      .BubblesMask(2'b00)
  ) GATES_54 (
      .input1(s_gates53_out),
      .input2(s_gates52_out),
      .result(s_gates54_out)
  );

  NAND_GATE #(
      .BubblesMask(2'b00)
  ) GATES_55 (
      .input1(s_csalui_8_0[5]),
      .input2(s_csalui_8_0[4]),
      .result(s_gates55_out)
  );

  AND_GATE #(
      .BubblesMask(2'b00)
  ) GATES_56 (
      .input1(s_alui3n),
      .input2(s_csalui_8_0[4]),
      .result(s_gates56_out)
  );


  /*******************************************************************************
   ** Here all sub-circuits are defined                                          **
   *******************************************************************************/

  MUX21LP CSMIS1_MUX (
      .A (s_csmis_1_0[1]),
      .B (s_memory46_q),
      .S (s_gates1_out),
      .ZN(s_isel1_n)
  );

  MUX21LP CSMIS0_MUX (
      .A (s_csmis_1_0[0]),
      .B (s_memory47_q),
      .S (s_gates1_out),
      .ZN(s_isel0_n)
  );

  MUX21LP CSALUI7_MUX (
      .A (s_csalui_8_0[7]),
      .B (s_up_n),
      .S (s_gates1_out),
      .ZN(s_ialii7_n)
  );

  MUX21LP CSALUI8_MUX (
      .A (s_csalui_8_0[8]),
      .B (s_lcz_n),
      .S (s_gates1_out),
      .ZN(s_ialii8_n)
  );

  MUX21LP ALUI3_MUX (
      .A (s_dgpr0_n),
      .B (s_csalui3_n),
      .S (s_gates3_out),
      .ZN(s_alui3n)
  );

  MUX21LP ALUI1N_MUX (
      .A (s_csalui_8_0[1]),
      .B (s_dgpr0_n),
      .S (s_gates2_out),
      .ZN(s_alui1n)
  );

  R41P REG_RFLA4 (
      .CP (s_aluclk),
      .A  (s_gates54_out),
      .B  (s_gates55_out),
      .C  (s_gates12_out),
      .D  (s_csalui_8_0[4]),
      .QA (s_rsn_n_out),
      .QAN(),
      .QB (),
      .QBN(s_fsel_n),
      .QC (s_log_n_out),
      .QCN(),
      .QD (),
      .QDN(s_alui4_n_out)
  );

  R41P REG_BAAD (
      .CP (s_aluclk),
      .A  (s_gates13_out),
      .B  (s_gates14_out),
      .C  (s_gates7_out),
      .D  (s_gates15_out),
      .QA (),
      .QAN(s_sb_n_out),
      .QB (),
      .QBN(s_sa_n_out),
      .QC (s_ra_n_out),
      .QCN(),
      .QD (s_rd_n_out),
      .QDN()
  );

  R81 CONTR_REG (
      .CP(s_aluclk),
      .A (s_isel1_n),
      .B (s_isel0_n),
      .C (s_ialii7_n),
      .D (s_ialii8_n),
      .E (s_csst_1_0[0]),
      .F (s_csst_1_0[1]),
      .G (s_cscinsel_1_0[0]),
      .H (s_cscinsel_1_0[1]),

      .QA (s_ssel1n),
      .QAN(s_ssel1),
      .QB (s_ssel0n),
      .QBN(s_ssel0),
      .QC (s_alui7_n),
      .QCN(),
      .QD (s_alui8_n_out),
      .QDN(),
      .QE (s_csts_1_0[0]),
      .QEN(),
      .QF (),
      .QFN(s_icsst1),
      .QG (s_cinsel0),
      .QGN(),
      .QH (s_cinsel1),
      .QHN()
  );

  MUX41P CI_SEL_MUX (
      .A (s_cinsel0),
      .B (s_cinsel1),
      .D0(s_gnd),
      .D1(s_power),
      .D2(s_sts6),
      .D3(s_gpr0),
      .Z (s_ci_out)
  );

endmodule

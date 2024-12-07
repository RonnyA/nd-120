/**************************************************************************
** ND120 DGA (Decode Gate Array)                                         **
** DGA (Decode Gate Array)                                               **
**                                                                       **
** Decode Internal Databus Commands                                      **
**                                                                       **
** Page 16 DECODE - DECODE_DGA_COMM - Sheet 1 of 4                       **
** Page 17 DECODE - DECODE_DGA_COMM - Sheet 2 of 4                       **
** Page 18 DECODE - DECODE_DGA_COMM - Sheet 3 of 4                       **
** Page 19 DECODE - DECODE_DGA_COMM - Sheet 4 of 4                       **
**                                                                       **
** Last reviewed: 1-DEC-2024                                             **
** Ronny Hansen                                                          **
***************************************************************************/

module DECODE_DGA_COMM (
    input       BRKN,
    input       CLEAR,
    input       CLK1,
    input       CLK2,
    input       CLK3,
    input [4:0] CSCOMM_4_0,
    input [1:0] CSMIS_1_0,
    input       DAPN,
    input       EORFN,
    input       HITN,
    input       IDBI2,
    input       IDBI5,
    input       IDBI7,
    input       LCSN,
    input       LSHADOW,
    input       PONI,
    input       UCLK,

    output CA10,
    output CCLRN,
    output CEUARTN,
    output CLRTIN,
    output DTN,
    output DVACCN,
    output ECREQ,
    output EMCLN,
    output EMPIDN,
    output ESTOFN,
    output FETCH,
    output FMISS,
    output FORMN,
    output IORQN,
    output LDPANCN,
    output LHIT,
    output MREQ,
    output RESET,
    output RTN,
    output RWCSN,
    output SHORTN,
    output SIOCN,
    output SLOWN,
    output SSEMAN,
    output SSTOPN,
    output STARTN,
    output STOCN,
    output WCHIMN,
    output WRITE
);

  /*******************************************************************************
   ** The wires are defined here                                                 **
   *******************************************************************************/
  wire [1:0] s_csmis_1_0;
  wire [4:0] s_cscomm_4_0;

  wire       a_a237_nand_out;
  wire       s_208_y;
  wire       s_a140_q3;
  wire       s_a141_nand_out;
  wire       s_a142_nand_out;
  wire       s_a143_nand_out;
  wire       s_a144_nand_out;
  wire       s_a145_nand_out;
  wire       s_a147_nand_out;
  wire       s_a148_nand_out;
  wire       s_a149_nand_out;
  wire       s_a150_nand_out;
  wire       s_a152_nand_out;
  wire       s_a153_nand_out;
  wire       s_a155_nand_out;
  wire       s_a156_nand_out;
  wire       s_a158_nand_out;
  wire       s_a162_nand_out;
  wire       s_a166_nand_out;
  wire       s_a167_nand_out;
  wire       s_a171_nand_out;
  wire       s_a172_nand_out;
  wire       s_a177_nand_out;
  wire       s_a185_nand_out;
  wire       s_a189_nand_out;
  wire       s_isstop_n;
  wire       s_a192_nand_out;
  wire       s_a193_nand_out;
  wire       s_a196_nand_out;
  wire       s_a199_nand_out;
  wire       s_a201_y;
  wire       s_a204_q;
  wire       s_a206_nand_out;
  wire       s_a211_nand_out;
  wire       s_a212_nand_out;
  wire       s_a213_nand_out;
  wire       s_a214_q0;
  wire       s_a215_nand_out;
  wire       s_a216_nand_out;
  wire       s_a216_nand_out5;
  wire       s_a217_nand_out;
  wire       s_a218_nand_out;
  wire       s_a219_nand_out;
  wire       s_a220_nand_out;
  wire       s_a221_y;
  wire       s_a222_nand_out;
  wire       s_a223_nand_out;
  wire       s_a224_nand_out;
  wire       s_a226_q_n;
  wire       s_a226_q;
  wire       s_a228_nand_out;
  wire       s_a229_nand_out;
  wire       s_a233_nand_out;
  wire       s_a235_nand_out;
  wire       s_a236_y;
  wire       s_a238_nand_out;
  wire       s_a242_and_out;
  wire       s_a243_nand_out;
  wire       s_a245_nand_out;
  wire       s_brk_n;
  wire       s_ca10;
  wire       s_cclr_n;
  wire       s_ceuart_n;
  wire       s_clear_n;
  wire       s_clear;
  wire       s_clk1;
  wire       s_clk2;
  wire       s_clk3_n;
  wire       s_clk3;
  wire       s_clrti_n;
  wire       s_cscomm_0_n;
  wire       s_cscomm_1_n;
  wire       s_cscomm_2_n;
  wire       s_cscomm_3_n;
  wire       s_cscomm_4_n;
  wire       s_csmis_0_n;
  wire       s_csmis_1_n;
  wire       s_dap_n;
  wire       s_dap;
  wire       s_dt_n;
  wire       s_dvacc_n;
  wire       s_ecrq;
  wire       s_emcl_n;
  wire       s_empid_n;
  wire       s_erof_n;
  wire       s_erof;
  wire       s_estof_n;
  wire       s_fetch;
  wire       s_fmiss;
  wire       s_form_n;
  wire       s_gnd;
  wire       s_hit_n;
  wire       s_iclrti_n;
  wire       s_idbi2;
  wire       s_idbi5;
  wire       s_idbi7;
  wire       s_iempid_latched;
  wire       s_iempid_n;
  wire       s_ildpanc_n;
  wire       s_iorq_n;
  wire       s_iorq;
  wire       s_isioc_n;
  wire       s_islow_n;
  wire       s_istart_n;
  wire       s_iwchim_n;
  wire       s_lcs_n;
  wire       s_ldpanc_latched;
  wire       s_ldpanc_n;
  wire       s_lhit_n;
  wire       s_lhit;
  wire       s_lshadow_n;
  wire       s_lshadow;
  wire       s_mreq;
  wire       s_poni_n;
  wire       s_poni;
  wire       s_reset;
  wire       s_rt_n;
  wire       s_rwcs_n;
  wire       s_short_n;
  wire       s_sioc_n;
  wire       s_slow_n;
  wire       s_ssema_n;
  wire       s_ssema;
  wire       s_sstop_n;
  wire       s_start_n;
  wire       s_stoc_n;
  wire       s_uclk;
  wire       s_vcc;
  wire       s_wchim_n;
  wire       s_write;
  wire       s_zz1;

  /*******************************************************************************
   ** Here all input connections are defined                                     **
   *******************************************************************************/
  assign s_csmis_1_0[1:0]  = CSMIS_1_0;
  assign s_cscomm_4_0[4:0] = CSCOMM_4_0;
  assign s_erof_n          = EORFN;
  assign s_dap_n           = DAPN;
  assign s_clk1            = CLK1;
  assign s_lcs_n           = LCSN;
  assign s_brk_n           = BRKN;
  assign s_clk3            = CLK3;
  assign s_clk2            = CLK2;
  assign s_lshadow         = LSHADOW;
  assign s_poni            = PONI;
  assign s_uclk            = UCLK;
  assign s_idbi7           = IDBI7;
  assign s_clear           = CLEAR;
  assign s_idbi2           = IDBI2;
  assign s_hit_n           = HITN;
  assign s_idbi5           = IDBI5;

  /*******************************************************************************
   ** Here all output connections are defined                                    **
   *******************************************************************************/
  assign CA10              = s_ca10;
  assign CCLRN             = s_cclr_n;
  assign CEUARTN           = s_ceuart_n;
  assign CLRTIN            = s_clrti_n;
  assign DTN               = s_dt_n;
  assign DVACCN            = s_dvacc_n;
  assign ECREQ             = s_ecrq;
  assign EMCLN             = s_emcl_n;
  assign EMPIDN            = s_empid_n;
  assign ESTOFN            = s_estof_n;
  assign FETCH             = s_fetch;
  assign FMISS             = s_fmiss;
  assign FORMN             = s_form_n;
  assign IORQN             = s_iorq_n;
  assign LDPANCN           = s_ldpanc_n;
  assign LHIT              = s_lhit;
  assign MREQ              = s_mreq;
  assign RESET             = s_reset;
  assign RTN               = s_rt_n;
  assign RWCSN             = s_rwcs_n;
  assign SHORTN            = s_short_n;
  assign SIOCN             = s_sioc_n;
  assign SLOWN             = s_slow_n;
  assign SSEMAN            = s_ssema_n;
  assign SSTOPN            = s_sstop_n;
  assign STARTN            = s_start_n;
  assign STOCN             = s_stoc_n;
  assign WCHIMN            = s_wchim_n;
  assign WRITE             = s_write;

  /*******************************************************************************
   ** Here all in-lined components are defined                                   **
   *******************************************************************************/

  // Power and Ground
  assign s_vcc             = 1'b1;
  assign s_gnd             = 1'b0;


  // NOT Gate: A241
  assign s_lshadow_n       = ~s_lshadow;

  // NOT Gate: A240
  assign s_dap             = ~s_dap_n;

  // NOT Gate
  assign s_erof            = ~s_erof_n;

  // NOT Gate
  assign s_clear_n         = ~s_clear;


  // Negated CSCOMM
  assign s_cscomm_0_n      = ~s_cscomm_4_0[0];
  assign s_cscomm_1_n      = ~s_cscomm_4_0[1];
  assign s_cscomm_2_n      = ~s_cscomm_4_0[2];
  assign s_cscomm_3_n      = ~s_cscomm_4_0[3];
  assign s_cscomm_4_n      = ~s_cscomm_4_0[4];

  // Negated CSMIS
  assign s_csmis_0_n       = ~s_csmis_1_0[0];
  assign s_csmis_1_n       = ~s_csmis_1_0[1];

  // NOT Gate: A230
  assign s_poni_n          = ~s_poni;

  // NOT Gate: A197
  assign s_clk3_n          = ~s_clk3;

  /*******************************************************************************
   ** Here all normal components are defined                                     **
   *******************************************************************************/
  NAND_GATE #(
      .BubblesMask(2'b00)
  ) A206 (
      .input1(s_a192_nand_out),
      .input2(s_a193_nand_out),
      .result(s_a206_nand_out)
  );

  NAND_GATE_8_INPUTS #(
      .BubblesMask(8'h00)
  ) A212 (
      .input1(s_zz1),
      .input2(s_csmis_1_0[1]),
      .input3(s_cscomm_4_0[4]),
      .input4(s_cscomm_4_0[3]),
      .input5(s_cscomm_4_0[2]),
      .input6(s_cscomm_4_0[1]),
      .input7(s_cscomm_4_0[0]),
      .input8(s_lcs_n),
      .result(s_a212_nand_out)
  );

  NAND_GATE_8_INPUTS #(
      .BubblesMask(8'h00)
  ) A193 (
      .input1(s_csmis_1_n),
      .input2(s_csmis_1_0[0]),
      .input3(s_cscomm_4_0[4]),
      .input4(s_cscomm_3_n),
      .input5(s_cscomm_2_n),
      .input6(s_cscomm_1_n),
      .input7(s_cscomm_4_0[0]),
      .input8(s_lcs_n),
      .result(s_a193_nand_out)
  );

  NAND_GATE_4_INPUTS #(
      .BubblesMask(4'h0)
  ) A156 (
      .input1(s_cscomm_4_0[4]),
      .input2(s_cscomm_3_n),
      .input3(s_cscomm_4_0[2]),
      .input4(s_lcs_n),
      .result(s_a156_nand_out)
  );

  NAND_GATE_6_INPUTS #(
      .BubblesMask({2'b00, 4'h0})
  ) A149 (
      .input1(s_a156_nand_out),
      .input2(s_a142_nand_out),
      .input3(s_a145_nand_out),
      .input4(s_a152_nand_out),
      .input5(s_a150_nand_out),
      .input6(s_a155_nand_out),
      .result(s_a149_nand_out)
  );

  NAND_GATE_5_INPUTS #(
      .BubblesMask({1'b0, 4'h0})
  ) A150 (
      .input1(s_cscomm_4_0[4]),
      .input2(s_cscomm_3_n),
      .input3(s_cscomm_4_0[1]),
      .input4(s_cscomm_4_0[0]),
      .input5(s_lcs_n),
      .result(s_a150_nand_out)
  );

  NAND_GATE_8_INPUTS #(
      .BubblesMask(8'h00)
  ) A211 (
      .input1(s_csmis_1_n),
      .input2(s_csmis_1_0[0]),
      .input3(s_cscomm_4_0[4]),
      .input4(s_cscomm_4_0[3]),
      .input5(s_cscomm_4_0[2]),
      .input6(s_cscomm_4_0[1]),
      .input7(s_cscomm_0_n),
      .input8(s_lcs_n),
      .result(s_a211_nand_out)
  );

  NAND_GATE_6_INPUTS #(
      .BubblesMask({2'b00, 4'h0})
  ) A199 (
      .input1(s_cscomm_4_n),
      .input2(s_cscomm_3_n),
      .input3(s_cscomm_4_0[2]),
      .input4(s_cscomm_1_n),
      .input5(s_cscomm_4_0[0]),
      .input6(s_lcs_n),
      .result(s_a199_nand_out)
  );

  NAND_GATE_5_INPUTS #(
      .BubblesMask({1'b0, 4'h0})
  ) A155 (
      .input1(s_cscomm_4_0[4]),
      .input2(s_cscomm_4_0[3]),
      .input3(s_cscomm_2_n),
      .input4(s_cscomm_1_n),
      .input5(s_lcs_n),
      .result(s_a155_nand_out)
  );

  NAND_GATE_6_INPUTS #(
      .BubblesMask({2'b00, 4'h0})
  ) A191 (
      .input1(s_cscomm_4_n),
      .input2(s_cscomm_4_0[3]),
      .input3(s_cscomm_4_0[2]),
      .input4(s_cscomm_1_n),
      .input5(s_cscomm_0_n),
      .input6(s_lcs_n),
      .result(s_isstop_n)
  );

  NAND_GATE_5_INPUTS #(
      .BubblesMask({1'b0, 4'h0})
  ) A152 (
      .input1(s_cscomm_4_0[4]),
      .input2(s_cscomm_4_0[3]),
      .input3(s_cscomm_1_n),
      .input4(s_cscomm_0_n),
      .input5(s_lcs_n),
      .result(s_a152_nand_out)
  );

  NAND_GATE_5_INPUTS #(
      .BubblesMask({1'b0, 4'h0})
  ) A222 (
      .input1(s_csmis_1_0[0]),
      .input2(s_cscomm_4_n),
      .input3(s_cscomm_4_0[2]),
      .input4(s_cscomm_4_0[1]),
      .input5(s_lcs_n),
      .result(s_a222_nand_out)
  );

  NAND_GATE_3_INPUTS #(
      .BubblesMask(3'b000)
  ) A158 (
      .input1(s_a147_nand_out),
      .input2(s_a141_nand_out),
      .input3(s_a145_nand_out),
      .result(s_a158_nand_out)
  );

  NAND_GATE_6_INPUTS #(
      .BubblesMask({2'b00, 4'h0})
  ) A185 (
      .input1(s_cscomm_4_0[4]),
      .input2(s_cscomm_4_0[3]),
      .input3(s_cscomm_4_0[2]),
      .input4(s_cscomm_4_0[1]),
      .input5(s_cscomm_0_n),
      .input6(s_csmis_1_0[0]),
      .result(s_a185_nand_out)
  );

  AND_GATE_3_INPUTS #(
      .BubblesMask(3'b000)
  ) A242 (
      .input1(s_brk_n),
      .input2(s_lshadow_n),
      .input3(s_erof),
      .result(s_a242_and_out)
  );

  NAND_GATE_5_INPUTS #(
      .BubblesMask({1'b0, 4'h0})
  ) A147 (
      .input1(s_cscomm_4_0[4]),
      .input2(s_cscomm_4_0[3]),
      .input3(s_cscomm_2_n),
      .input4(s_cscomm_4_0[1]),
      .input5(s_lcs_n),
      .result(s_a147_nand_out)
  );

  NAND_GATE_5_INPUTS #(
      .BubblesMask({1'b0, 4'h0})
  ) A223 (
      .input1(s_csmis_1_0[0]),
      .input2(s_cscomm_3_n),
      .input3(s_cscomm_2_n),
      .input4(s_cscomm_1_n),
      .input5(s_lcs_n),
      .result(s_a223_nand_out)
  );

  NAND_GATE #(
      .BubblesMask(2'b00)
  ) A237 (
      .input1(s_write),
      .input2(s_uclk),
      .result(a_a237_nand_out)
  );

  NAND_GATE_5_INPUTS #(
      .BubblesMask({1'b0, 4'h0})
  ) A198 (
      .input1(s_cscomm_4_n),
      .input2(s_cscomm_3_n),
      .input3(s_cscomm_4_0[2]),
      .input4(s_cscomm_1_n),
      .input5(s_cscomm_4_0[0]),
      .result(s_a216_nand_out5)
  );

  NAND_GATE_3_INPUTS #(
      .BubblesMask(3'b000)
  ) A200 (
      .input1(s_a185_nand_out),
      .input2(s_a216_nand_out5),
      .input3(s_lcs_n),
      .result(s_islow_n)
  );

  NAND_GATE_4_INPUTS #(
      .BubblesMask(4'h0)
  ) A141 (
      .input1(s_cscomm_4_0[4]),
      .input2(s_cscomm_4_0[3]),
      .input3(s_cscomm_1_n),
      .input4(s_lcs_n),
      .result(s_a141_nand_out)
  );

  NAND_GATE_5_INPUTS #(
      .BubblesMask({1'b0, 4'h0})
  ) A228 (
      .input1(s_csmis_1_0[1]),
      .input2(s_cscomm_3_n),
      .input3(s_cscomm_2_n),
      .input4(s_cscomm_1_n),
      .input5(s_lcs_n),
      .result(s_a228_nand_out)
  );

  AND_GATE #(
      .BubblesMask(2'b00)
  ) A246 (
      .input1(s_lshadow),
      .input2(s_a140_q3),
      .result(s_estof_n)
  );

  NAND_GATE_3_INPUTS #(
      .BubblesMask(3'b000)
  ) A233 (
      .input1(s_a140_q3),
      .input2(s_hit_n),
      .input3(s_a242_and_out),
      .result(s_a233_nand_out)
  );

  NAND_GATE #(
      .BubblesMask(2'b00)
  ) A238 (
      .input1(s_write),
      .input2(s_a242_and_out),
      .result(s_a238_nand_out)
  );

  NAND_GATE #(
      .BubblesMask(2'b00)
  ) A235 (
      .input1(s_erof),
      .input2(s_iorq),
      .result(s_a235_nand_out)
  );

  NAND_GATE #(
      .BubblesMask(2'b00)
  ) A245 (
      .input1(s_a140_q3),
      .input2(s_lshadow_n),
      .result(s_a245_nand_out)
  );

  NAND_GATE #(
      .BubblesMask(2'b00)
  ) A243 (
      .input1(s_iorq),
      .input2(s_dap),
      .result(s_a243_nand_out)
  );

  NAND_GATE #(
      .BubblesMask(2'b00)
  ) A209 (
      .input1(s_erof),
      .input2(s_iempid_latched),
      .result(s_empid_n)
  );

  NAND_GATE_3_INPUTS #(
      .BubblesMask(3'b000)
  ) A162 (
      .input1(s_a156_nand_out),
      .input2(s_a150_nand_out),
      .input3(s_a142_nand_out),
      .result(s_a162_nand_out)
  );

  NAND_GATE_3_INPUTS #(
      .BubblesMask(3'b000)
  ) A239 (
      .input1(s_a233_nand_out),
      .input2(s_a238_nand_out),
      .input3(s_a235_nand_out),
      .result(s_ecrq)
  );

  NAND_GATE #(
      .BubblesMask(2'b00)
  ) A244 (
      .input1(s_a245_nand_out),
      .input2(s_a243_nand_out),
      .result(s_stoc_n)
  );

  NAND_GATE_6_INPUTS #(
      .BubblesMask({2'b00, 4'h0})
  ) A183 (
      .input1(s_cscomm_4_n),
      .input2(s_cscomm_4_0[3]),
      .input3(s_cscomm_2_n),
      .input4(s_cscomm_4_0[1]),
      .input5(s_cscomm_0_n),
      .input6(s_lcs_n),
      .result(s_iempid_n)
  );

  NAND_GATE_8_INPUTS #(
      .BubblesMask(8'h00)
  ) A145 (
      .input1(s_zz1),
      .input2(s_csmis_1_n),
      .input3(s_cscomm_4_0[4]),
      .input4(s_cscomm_3_n),
      .input5(s_cscomm_2_n),
      .input6(s_cscomm_4_0[1]),
      .input7(s_cscomm_0_n),
      .input8(s_lcs_n),
      .result(s_a145_nand_out)
  );

  NAND_GATE_8_INPUTS #(
      .BubblesMask(8'h00)
  ) A216 (
      .input1(s_zz1),
      .input2(s_a222_nand_out),
      .input3(s_a223_nand_out),
      .input4(s_a228_nand_out),
      .input5(s_a229_nand_out),
      .input6(s_a217_nand_out),
      .input7(s_a218_nand_out),
      .input8(s_a219_nand_out),
      .result(s_a216_nand_out)
  );

  NAND_GATE_5_INPUTS #(
      .BubblesMask({1'b0, 4'h0})
  ) A229 (
      .input1(s_cscomm_4_n),
      .input2(s_cscomm_4_0[2]),
      .input3(s_cscomm_1_n),
      .input4(s_cscomm_0_n),
      .input5(s_lcs_n),
      .result(s_a229_nand_out)
  );

  NAND_GATE_6_INPUTS #(
      .BubblesMask({2'b00, 4'h0})
  ) A182 (
      .input1(s_cscomm_4_n),
      .input2(s_cscomm_3_n),
      .input3(s_cscomm_4_0[2]),
      .input4(s_cscomm_4_0[1]),
      .input5(s_cscomm_4_0[0]),
      .input6(s_lcs_n),
      .result(s_isioc_n)
  );

  NAND_GATE #(
      .BubblesMask(2'b00)
  ) A167 (
      .input1(s_a147_nand_out),
      .input2(s_a144_nand_out),
      .result(s_a167_nand_out)
  );

  NAND_GATE_5_INPUTS #(
      .BubblesMask({1'b0, 4'h0})
  ) A217 (
      .input1(s_cscomm_3_n),
      .input2(s_cscomm_2_n),
      .input3(s_cscomm_1_n),
      .input4(s_cscomm_0_n),
      .input5(s_lcs_n),
      .result(s_a217_nand_out)
  );

  NAND_GATE_8_INPUTS #(
      .BubblesMask(8'h00)
  ) A142 (
      .input1(s_csmis_1_0[0]),
      .input2(s_csmis_1_0[1]),
      .input3(s_cscomm_4_0[4]),
      .input4(s_cscomm_3_n),
      .input5(s_cscomm_2_n),
      .input6(s_cscomm_4_0[1]),
      .input7(s_cscomm_0_n),
      .input8(s_lcs_n),
      .result(s_a142_nand_out)
  );

  NAND_GATE_6_INPUTS #(
      .BubblesMask({2'b00, 4'h0})
  ) A184 (
      .input1(s_cscomm_4_n),
      .input2(s_cscomm_4_0[3]),
      .input3(s_cscomm_4_0[2]),
      .input4(s_cscomm_1_n),
      .input5(s_cscomm_4_0[0]),
      .input6(s_lcs_n),
      .result(s_iclrti_n)
  );

  NAND_GATE_6_INPUTS #(
      .BubblesMask({2'b00, 4'h0})
  ) A148 (
      .input1(s_a145_nand_out),
      .input2(s_a142_nand_out),
      .input3(s_a156_nand_out),
      .input4(s_a150_nand_out),
      .input5(s_a141_nand_out),
      .input6(s_a147_nand_out),
      .result(s_a148_nand_out)
  );

  NAND_GATE_4_INPUTS #(
      .BubblesMask(4'h0)
  ) A218 (
      .input1(s_cscomm_4_n),
      .input2(s_cscomm_3_n),
      .input3(s_cscomm_2_n),
      .input4(s_lcs_n),
      .result(s_a218_nand_out)
  );

  NAND_GATE_8_INPUTS #(
      .BubblesMask(8'h00)
  ) A143 (
      .input1(s_zz1),
      .input2(s_csmis_1_0[1]),
      .input3(s_cscomm_4_0[4]),
      .input4(s_cscomm_3_n),
      .input5(s_cscomm_2_n),
      .input6(s_cscomm_4_0[1]),
      .input7(s_cscomm_0_n),
      .input8(s_lcs_n),
      .result(s_a143_nand_out)
  );

  NAND_GATE_8_INPUTS #(
      .BubblesMask(8'h00)
  ) A180 (
      .input1(s_csmis_0_n),
      .input2(s_csmis_1_n),
      .input3(s_cscomm_4_0[4]),
      .input4(s_cscomm_3_n),
      .input5(s_cscomm_2_n),
      .input6(s_cscomm_1_n),
      .input7(s_cscomm_4_0[0]),
      .input8(s_lcs_n),
      .result(s_iwchim_n)
  );

  NAND_GATE_4_INPUTS #(
      .BubblesMask(4'h0)
  ) A219 (
      .input1(s_cscomm_4_n),
      .input2(s_cscomm_4_0[3]),
      .input3(s_cscomm_4_0[2]),
      .input4(s_lcs_n),
      .result(s_a219_nand_out)
  );

  NAND_GATE_3_INPUTS #(
      .BubblesMask(3'b000)
  ) A166 (
      .input1(s_a143_nand_out),
      .input2(s_a156_nand_out),
      .input3(s_a150_nand_out),
      .result(s_a166_nand_out)
  );

  NAND_GATE_6_INPUTS #(
      .BubblesMask({2'b00, 4'h0})
  ) A144 (
      .input1(s_cscomm_4_0[4]),
      .input2(s_cscomm_4_0[3]),
      .input3(s_cscomm_4_0[2]),
      .input4(s_cscomm_1_n),
      .input5(s_cscomm_4_0[0]),
      .input6(s_lcs_n),
      .result(s_a144_nand_out)
  );

  NAND_GATE #(
      .BubblesMask(2'b00)
  ) A195 (
      .input1(s_erof),
      .input2(s_ldpanc_latched),
      .result(s_ldpanc_n)
  );

  NAND_GATE_8_INPUTS #(
      .BubblesMask(8'h00)
  ) A186 (
      .input1(s_csmis_0_n),
      .input2(s_csmis_1_0[1]),
      .input3(s_cscomm_4_n),
      .input4(s_cscomm_3_n),
      .input5(s_cscomm_4_0[2]),
      .input6(s_cscomm_4_0[1]),
      .input7(s_cscomm_0_n),
      .input8(s_lcs_n),
      .result(s_ildpanc_n)
  );

  NAND_GATE_8_INPUTS #(
      .BubblesMask(8'h00)
  ) A213 (
      .input1(s_csmis_1_0[1]),
      .input2(s_csmis_1_0[0]),
      .input3(s_cscomm_4_0[4]),
      .input4(s_cscomm_3_n),
      .input5(s_cscomm_2_n),
      .input6(s_cscomm_1_n),
      .input7(s_cscomm_4_0[0]),
      .input8(s_lcs_n),
      .result(s_a213_nand_out)
  );

  NAND_GATE_5_INPUTS #(
      .BubblesMask({1'b0, 4'h0})
  ) A153 (
      .input1(s_a142_nand_out),
      .input2(s_a150_nand_out),
      .input3(s_a144_nand_out),
      .input4(s_a156_nand_out),
      .input5(s_a147_nand_out),
      .result(s_a153_nand_out)
  );

  NAND_GATE_6_INPUTS #(
      .BubblesMask({2'b00, 4'h0})
  ) A190 (
      .input1(s_cscomm_4_n),
      .input2(s_cscomm_4_0[3]),
      .input3(s_cscomm_2_n),
      .input4(s_cscomm_4_0[1]),
      .input5(s_cscomm_4_0[0]),
      .input6(s_lcs_n),
      .result(s_istart_n)
  );

  NAND_GATE_3_INPUTS #(
      .BubblesMask(3'b000)
  ) A177 (
      .input1(s_lcs_n),
      .input2(s_mreq),
      .input3(s_fmiss),
      .result(s_a177_nand_out)
  );

  NAND_GATE_8_INPUTS #(
      .BubblesMask(8'h00)
  ) A215 (
      .input1(s_a226_q_n),
      .input2(s_csmis_1_0[1]),
      .input3(s_csmis_1_0[0]),
      .input4(s_cscomm_4_0[4]),
      .input5(s_cscomm_4_0[3]),
      .input6(s_cscomm_4_0[2]),
      .input7(s_cscomm_1_n),
      .input8(s_lcs_n),
      .result(s_a215_nand_out)
  );

  NAND_GATE_3_INPUTS #(
      .BubblesMask(3'b000)
  ) A220 (
      .input1(s_a212_nand_out),
      .input2(s_a215_nand_out),
      .input3(s_a224_nand_out),
      .result(s_a220_nand_out)
  );

  NAND_GATE #(
      .BubblesMask(2'b00)
  ) A171 (
      .input1(s_a177_nand_out),
      .input2(s_a172_nand_out),
      .result(s_a171_nand_out)
  );

  NAND_GATE #(
      .BubblesMask(2'b00)
  ) A172 (
      .input1(s_lcs_n),
      .input2(s_ssema),
      .result(s_a172_nand_out)
  );

  NAND_GATE #(
      .BubblesMask(2'b00)
  ) A224 (
      .input1(s_poni_n),
      .input2(s_lcs_n),
      .result(s_a224_nand_out)
  );

  NAND_GATE_8_INPUTS #(
      .BubblesMask(8'h00)
  ) A189 (
      .input1(s_csmis_0_n),
      .input2(s_csmis_1_0[1]),
      .input3(s_cscomm_4_0[4]),
      .input4(s_cscomm_3_n),
      .input5(s_cscomm_2_n),
      .input6(s_cscomm_1_n),
      .input7(s_cscomm_4_0[0]),
      .input8(s_lcs_n),
      .result(s_a189_nand_out)
  );

  NOR_GATE #(
      .BubblesMask(2'b00)
  ) A196 (
      .input1(s_a204_q),
      .input2(s_clk3_n),
      .result(s_a196_nand_out)
  );

  NAND_GATE_3_INPUTS #(
      .BubblesMask(3'b000)
  ) A192 (
      .input1(s_ssema),
      .input2(s_mreq),
      .input3(s_lcs_n),
      .result(s_a192_nand_out)
  );

  D_FLIPFLOP #(
      .InvertClockEnable(0)
  ) MEMORY_63 (
      .clock(s_clk1),
      .d(s_a153_nand_out),
      .preset(s_gnd),
      .q(s_ca10),
      .qBar(),
      .reset(!a_a237_nand_out),  // Reset signal is negated, as this flip-flop has RESET active high
      .tick(1'b1)
  );

  D_FLIPFLOP #(
      .InvertClockEnable(0)
  ) A226 (
      .clock(s_clk2),
      .d(s_a221_y),
      .preset(1'b0),
      .q(s_a226_q),
      .qBar(s_a226_q_n),
      .reset(1'b0),
      .tick(1'b1)
  );

  D_FLIPFLOP #(
      .InvertClockEnable(0)
  ) A232 (
      .clock(s_clk1),
      .d(s_a236_y),
      .preset(1'b0),
      .q(s_lhit_n),
      .qBar(s_lhit),
      .reset(1'b0),
      .tick(1'b1)
  );


  D_FLIPFLOP #(
      .InvertClockEnable(0)
  ) A227 (
      .clock(s_clk2),
      .d(s_a220_nand_out),
      .preset(1'b0),
      .q(),
      .qBar(s_dvacc_n),
      .reset(1'b0),
      .tick(1'b1)
  );

  D_FLIPFLOP #(
      .InvertClockEnable(0)
  ) MEMORY_68 (
      .clock(s_clk3),
      .d(s_a201_y),
      .preset(1'b0),
      .q(s_reset),
      .qBar(),
      .reset(s_clear),
      .tick(1'b1)
  );

  D_FLIPFLOP #(
      .InvertClockEnable(0)
  ) A204 (
      .clock(s_clk3_n),
      .d(s_a189_nand_out),
      .preset(1'b0),
      .q(s_a204_q),
      .qBar(),
      .reset(1'b0),
      .tick(1'b1)
  );


  /*******************************************************************************
   ** Here all sub-circuits are defined                                          **
   *******************************************************************************/

  F924 A181 (
      .C_H05  (s_clk3),
      .D0_H01 (s_vcc),
      .D1_H02 (s_isstop_n),
      .D2_H03 (s_a199_nand_out),
      .D3_H04 (s_a206_nand_out),
      .N01_Q0 (),
      .N02_Q1 (s_sstop_n),
      .N03_Q2 (s_ceuart_n),
      .N04_Q3 (s_ssema),
      .N05_Q0B(),
      .N06_Q1B(),
      .N07_Q2B(),
      .N08_Q3B(s_ssema_n)
  );

  F924 A214 (
      .C_H05  (s_clk2),
      .D0_H01 (s_a213_nand_out),
      .D1_H02 (s_a216_nand_out),
      .D2_H03 (s_a211_nand_out),
      .D3_H04 (s_a212_nand_out),
      .N01_Q0 (s_a214_q0),
      .N02_Q1 (),
      .N03_Q2 (s_rwcs_n),
      .N04_Q3 (s_iorq_n),
      .N05_Q0B(),
      .N06_Q1B(s_short_n),
      .N07_Q2B(),
      .N08_Q3B(s_iorq)
  );

  F924 A140 (
      .C_H05  (s_clk2),
      .D0_H01 (s_a162_nand_out),
      .D1_H02 (s_vcc),
      .D2_H03 (s_a158_nand_out),
      .D3_H04 (s_a149_nand_out),
      .N01_Q0 (s_fetch),
      .N02_Q1 (),
      .N03_Q2 (),
      .N04_Q3 (s_a140_q3),
      .N05_Q0B(),
      .N06_Q1B(),
      .N07_Q2B(s_dt_n),
      .N08_Q3B(s_rt_n)
  );

  F091 A178 (
      .N01(s_zz1),
      .N02()
  );

  F571 A221 (
      .A(s_a214_q0),
      .D0(s_idbi2),
      .D1(s_a226_q),
      .ENB_N(s_gnd),
      .Y(s_a221_y)
  );

  F571 A236 (
      .A(s_a140_q3),
      .D0(s_lhit_n),
      .D1(s_hit_n),
      .ENB_N(s_gnd),
      .Y(s_a236_y)
  );

  F924 A187 (
      .C_H05  (s_clk3),
      .D0_H01 (s_iclrti_n),
      .D1_H02 (s_isioc_n),
      .D2_H03 (s_iempid_n),
      .D3_H04 (s_islow_n),
      .N01_Q0 (s_clrti_n),
      .N02_Q1 (s_sioc_n),
      .N03_Q2 (),
      .N04_Q3 (s_slow_n),
      .N05_Q0B(),
      .N06_Q1B(),
      .N07_Q2B(s_iempid_latched),
      .N08_Q3B()
  );

  F924 A160 (
      .C_H05  (s_clk2),
      .D0_H01 (s_a171_nand_out),
      .D1_H02 (s_a166_nand_out),
      .D2_H03 (s_a148_nand_out),
      .D3_H04 (s_a167_nand_out),
      .N01_Q0 (s_fmiss),
      .N02_Q1 (),
      .N03_Q2 (),
      .N04_Q3 (s_write),
      .N05_Q0B(),
      .N06_Q1B(s_form_n),
      .N07_Q2B(s_mreq),
      .N08_Q3B()
  );

  F571 A208 (
      .A(s_sioc_n),
      .D0(s_idbi5),
      .D1(s_emcl_n),
      .ENB_N(s_gnd),
      .Y(s_208_y)
  );

  D_FLIPFLOP #(
      .InvertClockEnable(0)
  ) MEMORY_66 (
      .clock(s_clk3),
      .d(s_208_y),
      .preset(1'b0),
      .q(s_emcl_n),
      .qBar(),
      .reset(s_clear),
      .tick(1'b1)
  );

/* REFACTOR EMCL_n logic to avoid race condition */
/* refactor removed as original code worked...

  reg regEMCL_n;
  assign s_emcl_n = regEMCL_n;

  // Normally POSEDGE CLK3, but to avoid race we latch on the negative edge. EMCL_n is not time sensitve inside the opcode
  always@(negedge s_clk3, posedge s_clear)
  begin
    if (s_clear) begin
        regEMCL_n <= 0;
    end else begin
        if (s_sioc_n == 1'b0) begin
            regEMCL_n <= s_idbi5;
        end
    end
  end
*/

  F924 A188 (
      .C_H05  (s_clk3),
      .D0_H01 (s_vcc),
      .D1_H02 (s_istart_n),
      .D2_H03 (s_ildpanc_n),
      .D3_H04 (s_iwchim_n),
      .N01_Q0 (),
      .N02_Q1 (s_start_n),
      .N03_Q2 (),
      .N04_Q3 (s_wchim_n),
      .N05_Q0B(),
      .N06_Q1B(),
      .N07_Q2B(s_ldpanc_latched),
      .N08_Q3B()
  );

  F571 A201 (
      .D0(s_idbi7),
      .D1(s_reset),
      .A(s_sioc_n),
      .ENB_N(s_gnd),
      .Y(s_a201_y)
  );

  F595 A207 (
      .H01_S (s_a196_nand_out),
      .H02_R (s_clk3_n),
      .H03_G (s_zz1),
      .N01_Q (),
      .N02_QB(s_cclr_n)
  );

endmodule

/**************************************************************************
** ND120 CGA (CPU Gate Array / DELILAH)                                  **
** /CGA/INTR/CNTLR/VECGEN/STAT/SBIT                                      **
** S BIT                                                                 **
**                                                                       **
** Page 87                                                               **
** SHEET 1 of 1                                                          **
**                                                                       **
** Last reviewed: 10-NOV-2024                                            **
** Ronny Hansen                                                          **
***************************************************************************/

module CGA_INTR_CNTLR_VECGEN_STAT_SBIT (
    input CK,
    input DCDF,
    input DCDFN,
    input DCDG,
    input DCDGN,
    input GPE,
    input SIN,
    input VINN,

    output STS
);

  /*******************************************************************************
   ** The wires are defined here                                                 **
   *******************************************************************************/
  wire s_nand_sin_dcdg_dcdf_gpe;
  wire s_nand_vinn_gpe_dcdgn;
  wire s_vin_n;
  wire s_dcdg_n;
  wire s_nand_dcdg_dcdfn_sts;
  wire s_gpe;
  wire s_sts_out;
  wire s_dcdf_n;
  wire s_dcdg;
  wire s_ck;
  wire s_d;
  wire s_si_n;
  wire s_dcdf;

  /*******************************************************************************
   ** The module functionality is described here                                 **
   *******************************************************************************/

  /*******************************************************************************
   ** Here all input connections are defined                                     **
   *******************************************************************************/
  assign s_ck = CK;
  assign s_dcdf = DCDF;
  assign s_dcdf_n = DCDFN;
  assign s_dcdg = DCDG;
  assign s_dcdg_n = DCDGN;
  assign s_gpe = GPE;
  assign s_si_n = SIN;
  assign s_vin_n = VINN;

  /*******************************************************************************
   ** Here all output connections are defined                                    **
   *******************************************************************************/
  assign STS = s_sts_out;

  /*******************************************************************************
   ** Here all normal components are defined                                     **
   *******************************************************************************/
  NAND_GATE_4_INPUTS #(
      .BubblesMask(4'h0)
  ) GATES_1 (
      .input1(s_si_n),
      .input2(s_dcdg),
      .input3(s_dcdf),
      .input4(s_gpe),
      .result(s_nand_sin_dcdg_dcdf_gpe)
  );

  NAND_GATE_3_INPUTS #(
      .BubblesMask(3'b000)
  ) GATES_2 (
      .input1(s_dcdg),
      .input2(s_dcdf_n),
      .input3(s_sts_out),
      .result(s_nand_dcdg_dcdfn_sts)
  );

  NAND_GATE_3_INPUTS #(
      .BubblesMask(3'b000)
  ) GATES_3 (
      .input1(s_vin_n),
      .input2(s_gpe),
      .input3(s_dcdg_n),
      .result(s_nand_vinn_gpe_dcdgn)
  );

  OR_GATE_3_INPUTS #(
      .BubblesMask(3'b111)
  ) GATES_4 (
      .input1(s_nand_sin_dcdg_dcdf_gpe),
      .input2(s_nand_dcdg_dcdfn_sts),
      .input3(s_nand_vinn_gpe_dcdgn),
      .result(s_d)
  );

  D_FLIPFLOP #(
      .InvertClockEnable(0)
  ) MEMORY_5 (
      .clock(s_ck),
      .d(s_d),
      .preset(1'b0),
      .q(s_sts_out),
      .qBar(),
      .reset(1'b0),
      .tick(1'b1)
  );


endmodule

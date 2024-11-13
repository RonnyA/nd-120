/**************************************************************************
** ND120 CGA (CPU Gate Array / DELILAH)                                  **
** /CGA/INTR/CNTLR/VECGEN/STAT                                           **
** STAT                                                                  **
**                                                                       **
** Page 87                                                               **
** SHEET 1 of 1                                                          **
**                                                                       **
** Last reviewed: 10-NOV-2024                                            **
** Ronny Hansen                                                          **
***************************************************************************/


module CGA_INTR_CNTLR_VECGEN_STAT (
    input       FIDBO3,
    input       FIDBO4,
    input       G,
    input       HIF,
    input [2:0] HISIN_2_0,
    input [2:0] HIVEC_2_0,
    input       LOF,
    input [2:0] LOSIN_2_0,
    input [2:0] LOVEC_2_0,
    input       MCLK,

    output [2:0] HISTAT_2_0,
    output [2:0] LOSTAT_2_0

);

  /*******************************************************************************
   ** The wires are defined here                                                 **
   *******************************************************************************/
  wire [2:0] s_hivec_2_0;
  wire [2:0] s_hisin_2_0;
  wire [2:0] s_losin_2_0;
  wire [2:0] s_lovec_2_0;
  wire [2:0] s_histat_2_0_out;
  wire [2:0] s_lostat_2_0_out;
  wire       s_and_hivec1n_hivec0n;
  wire       s_and_lovec1n_lovec0n;
  wire       s_fidbo3_n;
  wire       s_fidbo3;
  wire       s_fidbo4_n;
  wire       s_fidbo4;
  wire       s_g_n;
  wire       s_g;
  wire       s_hif_n;
  wire       s_hif;
  wire       s_hivec0_n;
  wire       s_hivec1_n;
  wire       s_hivec2_n;
  wire       s_lof_n;
  wire       s_lof;
  wire       s_lovec0_n;
  wire       s_lovec1_n;
  wire       s_lovec2_n;
  wire       s_mclk;
  wire       s_xnor_hivec1_hivec0n;
  wire       s_xnor_hivec2n_hivec1nand0n;
  wire       s_xnor_lovec1_lovec0n;
  wire       s_xnor_lovec2n_lovec1nand0n;

  /*******************************************************************************
   ** The module functionality is described here                                 **
   *******************************************************************************/

  /*******************************************************************************
   ** Here all input connections are defined                                     **
   *******************************************************************************/
  assign s_fidbo3         = FIDBO3;
  assign s_fidbo4         = FIDBO4;
  assign s_g              = G;
  assign s_hif            = HIF;
  assign s_hisin_2_0[2:0] = HISIN_2_0;
  assign s_hivec_2_0[2:0] = HIVEC_2_0;
  assign s_lof            = LOF;
  assign s_losin_2_0[2:0] = LOSIN_2_0;
  assign s_lovec_2_0[2:0] = LOVEC_2_0;
  assign s_mclk           = MCLK;

  /*******************************************************************************
   ** Here all output connections are defined                                    **
   *******************************************************************************/
  assign HISTAT_2_0       = s_histat_2_0_out[2:0];
  assign LOSTAT_2_0       = s_lostat_2_0_out[2:0];

  /*******************************************************************************
   ** Here all in-lined components are defined                                   **
   *******************************************************************************/

  // NOT Gate
  assign s_fidbo3_n       = ~s_fidbo3;
  assign s_fidbo4_n       = ~s_fidbo4;
  assign s_g_n            = ~s_g;
  assign s_hif_n          = ~s_hif;
  assign s_hivec0_n       = ~s_hivec_2_0[0];
  assign s_hivec1_n       = ~s_hivec_2_0[1];
  assign s_hivec2_n       = ~s_hivec_2_0[2];
  assign s_lof_n          = ~s_lof;
  assign s_lovec0_n       = ~s_lovec_2_0[0];
  assign s_lovec1_n       = ~s_lovec_2_0[1];
  assign s_lovec2_n       = ~s_lovec_2_0[2];

  /*******************************************************************************
   ** Here all normal components are defined                                     **
   *******************************************************************************/
  XNOR_GATE_ONEHOT #(
      .BubblesMask(2'b00)
  ) GATES_1 (
      .input1(s_lovec_2_0[1]),
      .input2(s_lovec0_n),
      .result(s_xnor_lovec1_lovec0n)
  );

  XNOR_GATE_ONEHOT #(
      .BubblesMask(2'b00)
  ) GATES_2 (
      .input1(s_hivec_2_0[1]),
      .input2(s_hivec0_n),
      .result(s_xnor_hivec1_hivec0n)
  );

  AND_GATE #(
      .BubblesMask(2'b11)
  ) GATES_3 (
      .input1(s_lovec1_n),
      .input2(s_lovec0_n),
      .result(s_and_lovec1n_lovec0n)
  );

  AND_GATE #(
      .BubblesMask(2'b11)
  ) GATES_4 (
      .input1(s_hivec1_n),
      .input2(s_hivec0_n),
      .result(s_and_hivec1n_hivec0n)
  );

  XNOR_GATE_ONEHOT #(
      .BubblesMask(2'b00)
  ) GATES_5 (
      .input1(s_hivec2_n),
      .input2(s_and_hivec1n_hivec0n),
      .result(s_xnor_hivec2n_hivec1nand0n)
  );

  XNOR_GATE_ONEHOT #(
      .BubblesMask(2'b00)
  ) GATES_6 (
      .input1(s_lovec2_n),
      .input2(s_and_lovec1n_lovec0n),
      .result(s_xnor_lovec2n_lovec1nand0n)
  );


  /*******************************************************************************
   ** Here all sub-circuits are defined                                          **
   *******************************************************************************/

  CGA_INTR_CNTLR_VECGEN_STAT_SBIT SBIT1_LO (
      .CK(s_mclk),
      .DCDF(s_xnor_lovec1_lovec0n),
      .DCDFN(s_g),
      .DCDG(s_lof_n),
      .DCDGN(s_fidbo4_n),
      .GPE(s_lof),
      .SIN(s_losin_2_0[1]),
      .STS(s_lostat_2_0_out[1]),
      .VINN(s_g_n)
  );

  CGA_INTR_CNTLR_VECGEN_STAT_SBIT SBIT2_HI (
      .CK(s_mclk),
      .DCDF(s_xnor_hivec2n_hivec1nand0n),
      .DCDFN(s_g),
      .DCDG(s_hif_n),
      .DCDGN(s_fidbo3_n),
      .GPE(s_hif),
      .SIN(s_hisin_2_0[2]),
      .STS(s_histat_2_0_out[2]),
      .VINN(s_g_n)
  );

  CGA_INTR_CNTLR_VECGEN_STAT_SBIT SBIT0_LO (
      .CK(s_mclk),
      .DCDF(s_lovec0_n),
      .DCDFN(s_g),
      .DCDG(s_lof_n),
      .DCDGN(s_fidbo4_n),
      .GPE(s_lof),
      .SIN(s_losin_2_0[0]),
      .STS(s_lostat_2_0_out[0]),
      .VINN(s_g_n)
  );

  CGA_INTR_CNTLR_VECGEN_STAT_SBIT SBIT1_HI (
      .CK(s_mclk),
      .DCDF(s_xnor_hivec1_hivec0n),
      .DCDFN(s_g),
      .DCDG(s_hif_n),
      .DCDGN(s_fidbo3_n),
      .GPE(s_hif),
      .SIN(s_hisin_2_0[1]),
      .STS(s_histat_2_0_out[1]),
      .VINN(s_g_n)
  );

  CGA_INTR_CNTLR_VECGEN_STAT_SBIT SBIT0_HI (
      .CK(s_mclk),
      .DCDF(s_hivec0_n),
      .DCDFN(s_g),
      .DCDG(s_hif_n),
      .DCDGN(s_fidbo3_n),
      .GPE(s_hif),
      .SIN(s_hisin_2_0[0]),
      .STS(s_histat_2_0_out[0]),
      .VINN(s_g_n)
  );

  CGA_INTR_CNTLR_VECGEN_STAT_SBIT SBIT2_LO (
      .CK(s_mclk),
      .DCDF(s_xnor_lovec2n_lovec1nand0n),
      .DCDFN(s_g),
      .DCDG(s_lof_n),
      .DCDGN(s_fidbo4_n),
      .GPE(s_lof),
      .SIN(s_losin_2_0[2]),
      .STS(s_lostat_2_0_out[2]),
      .VINN(s_g_n)
  );

endmodule

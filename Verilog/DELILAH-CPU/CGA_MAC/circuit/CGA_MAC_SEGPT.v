/**************************************************************************
** ND120 CGA (CPU Gate Array / DELILAH)                                  **
** /CGA/MAC/SEGPT                                                        **
** SEGPT                                                                 **
**                                                                       **
** Page 35                                                               **
** SHEET 1 of 1                                                          **
**                                                                       **
** Last reviewed: 10-NOV-2024                                            **
** Ronny Hansen                                                          **
***************************************************************************/


module CGA_MAC_SEGPT (
    input        EXMN,
    input [15:0] FIDBO_15_0,
    input        LLDEXM,
    input        LLDPCR,
    input        LLDSEG,
    input        MCLK,


    output [15:0] PCR_14_13_10_9_N,
    output [15:0] PCR_15_7_2_0,
    output        PEX,
    output        SEGZN,
    output [ 7:0] SEG_7_0,
    output        VEX,
    output [ 1:0] XPT_1_0
);

  /*******************************************************************************
   ** The wires are defined here                                                 **
   *******************************************************************************/

  wire [ 1:0] x_xpt_1_0_out;
  wire [ 2:0] s_fidbo_2_0;
  wire [ 7:0] s_fidbo_7_0;
  wire [ 7:0] s_seg_7_0_out;
  wire [15:0] s_fidbo_15_0;
  wire [15:0] s_fidbo_15_7_2_0;
  wire [15:0] s_pcr_14_13_10_9_n_out;
  wire [15:0] s_pcr_15_7_2_0_out;

  wire        s_exm_n;
  wire        s_fidbo_0;
  wire        s_fidbo_1;
  wire        s_fidbo_2;
  wire        s_fidbo_3;
  wire        s_fidbo_4;
  wire        s_fidbo_5;
  wire        s_fidbo_6;
  wire        s_fidbo_7;
  wire        s_fidbo_8;
  wire        s_fidbo_9;
  wire        s_fidbo_10;
  wire        s_fidbo_11;
  wire        s_fidbo_12;
  wire        s_fidbo_13;
  wire        s_fidbo_14;
  wire        s_fidbo_15;
  wire        s_lldexm;
  wire        s_lldpcr;
  wire        s_lldseg;
  wire        s_mclk_n;
  wire        s_mclk;
  wire        s_pex_out;
  wire        s_segz_n_out;
  wire        s_vex_out;

  /*******************************************************************************
   ** Here all wiring is defined                                                 **
   *******************************************************************************/
  assign s_fidbo_2_0[0]       = s_fidbo_0;
  assign s_fidbo_2_0[1]       = s_fidbo_1;
  assign s_fidbo_2_0[2]       = s_fidbo_2;

  assign s_fidbo_15_7_2_0[0]  = s_fidbo_0;
  assign s_fidbo_15_7_2_0[1]  = s_fidbo_1;
  assign s_fidbo_15_7_2_0[2]  = s_fidbo_2;
  assign s_fidbo_15_7_2_0[7]  = s_fidbo_7;
  assign s_fidbo_15_7_2_0[8]  = s_fidbo_8;
  assign s_fidbo_15_7_2_0[9]  = s_fidbo_9;
  assign s_fidbo_15_7_2_0[10] = s_fidbo_10;
  assign s_fidbo_15_7_2_0[11] = s_fidbo_11;
  assign s_fidbo_15_7_2_0[12] = s_fidbo_12;
  assign s_fidbo_15_7_2_0[13] = s_fidbo_13;
  assign s_fidbo_15_7_2_0[14] = s_fidbo_14;
  assign s_fidbo_15_7_2_0[15] = s_fidbo_15;

  assign s_fidbo_7_0[0]       = s_fidbo_0;
  assign s_fidbo_7_0[1]       = s_fidbo_1;
  assign s_fidbo_7_0[2]       = s_fidbo_2;
  assign s_fidbo_7_0[3]       = s_fidbo_3;
  assign s_fidbo_7_0[4]       = s_fidbo_4;
  assign s_fidbo_7_0[5]       = s_fidbo_5;
  assign s_fidbo_7_0[6]       = s_fidbo_6;
  assign s_fidbo_7_0[7]       = s_fidbo_7;

  assign s_fidbo_0            = s_fidbo_15_0[0];
  assign s_fidbo_1            = s_fidbo_15_0[1];
  assign s_fidbo_2            = s_fidbo_15_0[2];
  assign s_fidbo_3            = s_fidbo_15_0[3];
  assign s_fidbo_4            = s_fidbo_15_0[4];
  assign s_fidbo_5            = s_fidbo_15_0[5];
  assign s_fidbo_6            = s_fidbo_15_0[6];
  assign s_fidbo_7            = s_fidbo_15_0[7];
  assign s_fidbo_8            = s_fidbo_15_0[8];
  assign s_fidbo_9            = s_fidbo_15_0[9];
  assign s_fidbo_10           = s_fidbo_15_0[10];
  assign s_fidbo_11           = s_fidbo_15_0[11];
  assign s_fidbo_12           = s_fidbo_15_0[12];
  assign s_fidbo_13           = s_fidbo_15_0[13];
  assign s_fidbo_14           = s_fidbo_15_0[14];
  assign s_fidbo_15           = s_fidbo_15_0[15];
  
  /*******************************************************************************
   ** Here all input connections are defined                                     **
   *******************************************************************************/
  assign s_fidbo_15_0[15:0]   = FIDBO_15_0;
  assign s_lldpcr             = LLDPCR;
  assign s_mclk               = MCLK;
  assign s_lldexm             = LLDEXM;
  assign s_exm_n              = EXMN;
  assign s_lldseg             = LLDSEG;

  /*******************************************************************************
   ** Here all output connections are defined                                    **
   *******************************************************************************/
  assign PCR_14_13_10_9_N     = s_pcr_14_13_10_9_n_out[15:0];
  assign PCR_15_7_2_0         = s_pcr_15_7_2_0_out[15:0];
  assign PEX                  = s_pex_out;
  assign SEGZN                = s_segz_n_out;
  assign SEG_7_0              = s_seg_7_0_out[7:0];
  assign VEX                  = s_vex_out;
  assign XPT_1_0              = x_xpt_1_0_out[1:0];

  /*******************************************************************************
   ** Here all in-lined components are defined                                   **
   *******************************************************************************/

  // NOT Gate
  assign s_mclk_n             = ~s_mclk;

  /*******************************************************************************
   ** Here all sub-circuits are defined                                          **
   *******************************************************************************/

  CGA_MAC_SEGPT_XPT XPT (
      .EXMN(s_exm_n),
      .FIDBO_2_0(s_fidbo_2_0[2:0]),
      .LLDEXM(s_lldexm),
      .MCLKN(s_mclk_n),
      .PEX(s_pex_out),
      .VEX(s_vex_out),
      .XPT_1_0(x_xpt_1_0_out[1:0])
  );

  CGA_MAC_SEGPT_SEG SEG (
      .FIDBO_7_0(s_fidbo_7_0[7:0]),
      .LLDSEG(s_lldseg),
      .MCLKN(s_mclk_n),
      .SEGZN(s_segz_n_out),
      .SEG_7_0(s_seg_7_0_out[7:0])
  );

  CGA_MAC_SEGPT_PCR PCR (
      .FIDBO_15_7_2_0(s_fidbo_15_7_2_0[15:0]),
      .LLDPCR(s_lldpcr),
      .MCLKN(s_mclk_n),
      .PCR_14_13_10_9_N(s_pcr_14_13_10_9_n_out[15:0]),
      .PCR_15_7_2_0(s_pcr_15_7_2_0_out[15:0])
  );

endmodule

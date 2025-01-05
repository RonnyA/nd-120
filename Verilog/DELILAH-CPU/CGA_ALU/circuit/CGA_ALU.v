/**************************************************************************
** ND120 CGA (CPU Gate Array / DELILAH)                                  **
** /CGA/ALU/OUTMUX                                                       **
** OUT MUX                                                               **
**                                                                       **
** Page 41                                                               **
** SHEET 1 of 1                                                          **
**                                                                       **
** Last reviewed: 1-DEC-2024                                             **
** Ronny Hansen                                                          **
***************************************************************************/


module CGA_ALU (
    input        ALUCLK,
    input [15:0] A_15_0,
    input [15:0] B_15_0,
    input [15:0] CD_15_0,
    input [ 8:0] CSALUI_8_0,
    input [ 1:0] CSALUM_1_0,
    input [15:0] CSBIT_15_0,
    input [ 1:0] CSCINSEL_1_0,
    input [ 4:0] CSIDBS_4_0,
    input [ 1:0] CSMIS_1_0,
    input [ 1:0] CSSST_1_0,
    input [15:0] EA_15_0,
    input [15:0] FIDBI_15_0,
    input [ 3:0] LAA_3_0,  //! A Operand. CSBITS [15:12]
    input [ 3:0] LBA_3_0,  //! B Operand. CSBITS [19:16]
    input        LCZN,
    input        LDDBRN,
    input        LDGPRN,
    input        LDIRV,
    input        LDPILN,
    input        UPN,
    input        XFETCHN,

    output        BDEST,
    output        CRY,
    output        DOUBLE,
    output        F11,
    output        F15,
    output [15:0] FIDBO_15_0_OUT,
    output        IONI,
    output        MI,
    output        OVF,
    output [ 3:0] PIL_3_0,
    output        PONI,
    output        PTM,
    output [15:0] RB_15_0,
    output        SGR,
    output        Z,
    output        ZF
);

  /*******************************************************************************
   ** The wires are defined here                                                 **
   *******************************************************************************/
  wire [ 1:0] s_cd_10_9;
  wire [ 1:0] s_csalum_1_0;
  wire [ 1:0] s_cscinsel_1_0;
  wire [ 1:0] s_csmis_1_0;
  wire [ 1:0] s_cssst_1_0;
  wire [ 1:0] s_csts_1_0;
  wire [ 1:0] s_qsel_1_0;
  wire [ 2:0] s_gprc_2_0;
  wire [ 3:0] s_laa_3_0;
  wire [ 3:0] s_lba_3_0;
  wire [ 3:0] s_pil_3_0_out;
  wire [ 4:0] s_csidbs4_0;
  wire [ 8:0] s_csalui_8_0;
  wire [15:0] s_a_15_0;
  wire [15:0] s_arg_15_0;
  wire [15:0] s_b_15_0;
  wire [15:0] s_cd_15_0;
  wire [15:0] s_csbit_15_0;
  wire [15:0] s_d_15_0;
  wire [15:0] s_dbr_15_0;
  wire [15:0] s_ea_15_0;
  wire [15:0] s_f_15_0;
  wire [15:0] s_fidbi_15_0;
  wire [15:0] s_fidbo_15_0_out;
  wire [15:0] s_g_15_0;
  wire [15:0] s_grp_15_0;
  wire [15:0] s_q_15_0;
  wire [15:0] s_rb_15_0_out;
  wire [15:0] s_rn_15_0;
  wire [15:0] s_s_15_0;
  wire [15:0] s_sts_15_0;
  wire [15:0] s_sw_15_0;
  wire        s_aarg0_n;
  wire        s_aarg0;
  wire        s_aluclk;
  wire        s_alud2_n;
  wire        s_alui4;
  wire        s_alui7;
  wire        s_alui8n;
  wire        s_bdest_out;
  wire        s_carry_in;
  wire        s_cry_out;
  wire        s_dgpr0_n;
  wire        s_fsel;
  wire        s_gprli;
  wire        s_lcz_n;
  wire        s_lddbr_n;
  wire        s_ldgpr_n;
  wire        s_ldirv;
  wire        s_ldpil_n;
  wire        s_log;
  wire        s_mi_out;
  wire        s_ovf_out;
  wire        s_qli;
  wire        s_ra;
  wire        s_rb;
  wire        s_rli;
  wire        s_rri;
  wire        s_rsn;
  wire        s_sa;
  wire        s_sb;
  wire        s_sel_idbs2;
  wire        s_sgr_out;
  wire        s_up_n;
  wire        s_xfetch_n;
  wire        s_zf_out;

  /*******************************************************************************
   ** Here all wiring is defined                                                 **
   *******************************************************************************/
  assign s_cd_10_9[1:0]         = s_cd_15_0[10:9];
  assign s_pil_3_0_out[3:0]     = s_sts_15_0[11:8];


  /*******************************************************************************
   ** Here all input connections are defined                                     **
   *******************************************************************************/
  assign s_lba_3_0[3:0]         = LBA_3_0;
  assign s_laa_3_0[3:0]         = LAA_3_0;


  assign s_cd_15_0[15:0]        = CD_15_0;
  assign s_cssst_1_0[1:0]       = CSSST_1_0;
  assign s_csalui_8_0[8:0]      = CSALUI_8_0;
  assign s_fidbi_15_0[15:0]     = FIDBI_15_0;
  assign s_csidbs4_0[4:0]       = CSIDBS_4_0;
  assign s_cscinsel_1_0[1:0]    = CSCINSEL_1_0;
  assign s_csalum_1_0[1:0]      = CSALUM_1_0;
  assign s_ea_15_0[15:0]        = EA_15_0;
  assign s_csmis_1_0[1:0]       = CSMIS_1_0;
  assign s_a_15_0[15:0]         = A_15_0;
  assign s_b_15_0[15:0]         = B_15_0;
  assign s_csbit_15_0[15:0]     = CSBIT_15_0;
  assign s_up_n                 = UPN;
  assign s_aluclk               = ALUCLK;
  assign s_xfetch_n             = XFETCHN;
  assign s_ldgpr_n              = LDGPRN;
  assign s_lddbr_n              = LDDBRN;
  assign s_ldpil_n              = LDPILN;
  assign s_ldirv                = LDIRV;
  assign s_lcz_n                = LCZN;

  /*******************************************************************************
   ** Here all output connections are defined                                    **
   *******************************************************************************/
  assign BDEST                  = s_bdest_out;
  assign CRY                    = s_cry_out;
  assign DOUBLE                 = s_sts_15_0[13];
  assign F11                    = s_f_15_0[11];
  assign F15                    = s_f_15_0[15];
  assign FIDBO_15_0_OUT         = s_fidbo_15_0_out[15:0];
  assign IONI                   = s_sts_15_0[15];
  assign MI                     = s_mi_out;
  assign OVF                    = s_ovf_out;
  assign PIL_3_0                = s_pil_3_0_out[3:0];
  assign PONI                   = s_sts_15_0[14];
  assign PTM                    = s_sts_15_0[0];
  assign RB_15_0                = s_rb_15_0_out[15:0];
  assign SGR                    = s_sgr_out;
  assign Z                      = s_sts_15_0[3];
  assign ZF                     = s_zf_out;

  /*******************************************************************************
   ** Here all in-lined components are defined                                   **
   *******************************************************************************/

  // NOT Gate
  assign s_fidbo_15_0_out[15:0] = ~s_g_15_0[15:0];

  assign s_aarg0                = ~s_aarg0_n;

  /*******************************************************************************
   ** Here all normal components are defined                                     **
   *******************************************************************************/
  D_FLIPFLOP #(
      .InvertClockEnable(0)
  ) MEMORY_1 (
      .clock(s_aluclk),
      .d(s_csidbs4_0[2]),
      .preset(1'b0),
      .q(s_sel_idbs2),
      .qBar(),
      .reset(1'b0),
      .tick(1'b1)
  );


  /*******************************************************************************
   ** Here all sub-circuits are defined                                          **
   *******************************************************************************/

  CGA_CPU_ALU_RALU ALU_RALU (
      .ALUI4(s_alui4),
      .CI(s_carry_in),
      .CRY(s_cry_out),
      .FSEL(s_fsel),
      .F_15_0(s_f_15_0[15:0]),
      .LOG(s_log),
      .OVF(s_ovf_out),
      .RN_15_0(s_rn_15_0[15:0]),
      .RSN(s_rsn),
      .SGR(s_sgr_out),
      .S_15_0(s_s_15_0[15:0]),
      .ZF(s_zf_out)
  );

  CGA_ALU_SHIFT ALU_SHIFT (
      .ALUI7(s_alui7),
      .ALUI8N(s_alui8n),
      .F_15_0(s_f_15_0[15:0]),
      .RB_15_0(s_rb_15_0_out[15:0]),
      .RLI(s_rli),
      .RRI(s_rri)
  );

  CGA_ALU_STS ALU_STS (
      .ALUCLK(s_aluclk),
      .CRY(s_cry_out),
      .CSTS_1_0(s_csts_1_0[1:0]),
      .FIDBO_15_0(s_fidbo_15_0_out[15:0]),
      .LDPILN(s_ldpil_n),
      .MI(s_mi_out),
      .OVF(s_ovf_out),
      .STS_15_0(s_sts_15_0[15:0])
  );

  CGA_ALU_GPR ALU_GPR (
      .ALUCLK(s_aluclk),
      .CD_15_0(s_cd_15_0[15:0]),
      .DGPR0N(s_dgpr0_n),
      .FIDBO_15_0(s_fidbo_15_0_out[15:0]),
      .GPRC_2_0(s_gprc_2_0[2:0]),
      .GPRLI(s_gprli),
      .GPR_15_0(s_grp_15_0[15:0])
  );

  CGA_ALU_DBR ALU_DBR (
      .ALUCLK  (s_aluclk),
      .CD_15_0 (s_cd_15_0[15:0]),
      .DBR_15_0(s_dbr_15_0[15:0]),
      .LDDBRN  (s_lddbr_n)
  );

  CGA_ALU_ARG ALU_ARG (
      .ALUCLK(s_aluclk),
      .ARG_15_0(s_arg_15_0[15:0]),
      .CSBIT_15_0(s_csbit_15_0[15:0])
  );

  CGA_ALU_SWAP ALU_SWAP (
      .ALUCLK(s_aluclk),
      .FIDBO_15_0(s_fidbo_15_0_out[15:0]),
      .SW_15_0(s_sw_15_0[15:0])
  );

  MUX21LP AARG0_MUX (
      .A (s_lba_3_0[3]),
      .B (s_laa_3_0[0]),
      .S (s_sel_idbs2),
      .ZN(s_aarg0_n)
  );

  CGA_ALU_OUTMUX ALU_OUTMUX (
       // Input
      .AARG0(s_aarg0),
      .ALUCLK(s_aluclk),
      .ALUD2N(s_alud2_n),
      .ARG_15_0(s_arg_15_0[15:0]),
      .A_15_0(s_a_15_0[15:0]),
      .CSIDBS_4_0(s_csidbs4_0[4:0]),
      .DBR_15_0(s_dbr_15_0[15:0]),
      .EA_15_0(s_ea_15_0[15:0]),
      .FIDBI_15_0(s_fidbi_15_0[15:0]),
      .F_15_0(s_f_15_0[15:0]),
      .GPR_15_0(s_grp_15_0[15:0]),
      .LAA_3_1(s_laa_3_0[3:1]),
      .LBA_2_0(s_lba_3_0[2:0]),
      .STS_15_0(s_sts_15_0[15:0]),
      .SW_15_0(s_sw_15_0[15:0]),

      //Output
      .G_15_0(s_g_15_0[15:0]),
      .D_15_0(s_d_15_0[15:0])
  );

  CGA_ALU_QREG ALU_QREG (
      .ALUCLK(s_aluclk),
      .F_15_0(s_f_15_0[15:0]),
      .QLI(s_qli),
      .QSEL_1_0(s_qsel_1_0[1:0]),
      .Q_15_0(s_q_15_0[15:0])
  );

  CGA_CPU_ALU_RMUX ALU_RMUX (
      .A_15_0(s_a_15_0[15:0]),
      .D_15_0(s_d_15_0[15:0]),
      .RA(s_ra),
      .RD(s_rb),
      .RN_15_0(s_rn_15_0[15:0])
  );

  CGA_ALU_SMUX ALU_SMUX (
      .A_15_0(s_a_15_0[15:0]),
      .B_15_0(s_b_15_0[15:0]),
      .Q_15_0(s_q_15_0[15:0]),
      .SA(s_sa),
      .SB(s_sb),
      .S_15_0(s_s_15_0[15:0])
  );

  CGA_CPU_ALU_CONTR ALU_CONTR (
      .ALUCLK(s_aluclk),
      .ALUD2N(s_alud2_n),
      .ALUI4(s_alui4),
      .ALUI7(s_alui7),
      .ALUI8N(s_alui8n),
      .BDEST(s_bdest_out),
      .CD_10_9(s_cd_10_9[1:0]),
      .CI(s_carry_in),
      .CRY(s_cry_out),
      .CSALUI_8_0(s_csalui_8_0[8:0]),
      .CSALUM_1_0(s_csalum_1_0[1:0]),
      .CSCINSEL_1_0(s_cscinsel_1_0[1:0]),
      .CSMIS_1_0(s_csmis_1_0[1:0]),
      .CSSST_1_0(s_cssst_1_0[1:0]),
      .CSTS_1_0(s_csts_1_0[1:0]),
      .DGPR0N(s_dgpr0_n),
      .F0(s_f_15_0[0]),
      .F15(s_f_15_0[15]),
      .FSEL(s_fsel),
      .GPR0(s_grp_15_0[0]),
      .GPRC_2_0(s_gprc_2_0[2:0]),
      .GPRLI(s_gprli),
      .LCZN(s_lcz_n),
      .LDGPRN(s_ldgpr_n),
      .LDIRV(s_ldirv),
      .LOG(s_log),
      .MI(s_mi_out),
      .Q0(s_q_15_0[0]),
      .Q15(s_q_15_0[15]),
      .QLI(s_qli),
      .QSEL_1_0(s_qsel_1_0[1:0]),
      .RA(s_ra),
      .RD(s_rb),
      .RLI(s_rli),
      .RRI(s_rri),
      .RSN(s_rsn),
      .SA(s_sa),
      .SB(s_sb),
      .STS6(s_sts_15_0[6]),
      .STS7(s_sts_15_0[7]),
      .UPN(s_up_n),
      .XFETCHN(s_xfetch_n)
  );

endmodule

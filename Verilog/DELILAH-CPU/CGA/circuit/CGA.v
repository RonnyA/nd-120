/**************************************************************************
** ND120 CGA (CPU Gate Array / DELILAH)                                  **
** /CGA                                                                  **
** CGA TOP LEVEL                                                         **
**                                                                       **
** Page 2-9                                                              **
** SHEET 1 of 8                                                          **
**                                                                       **
** Last reviewed: 1-DEC-2024                                             **
** Ronny Hansen                                                          **
***************************************************************************/

module CGA (
    input sysclk,    // System clock in FPGA
    input sys_rst_n, // System reset in FPGA

    // Input signals
    input        XALUCLK,
    input        XBINT10N,
    input        XBINT11N,
    input        XBINT12N,
    input        XBINT13N,
    input        XBINT15N,
    input [15:0] XCD_15_0,
    input [ 8:0] XCSALUI_8_0,
    input [ 1:0] XCSALUM_1_0,
    input        XCSBIT20,
    input [15:0] XCSBIT_15_0,
    input [ 1:0] XCSCINSEL_1_0,
    input [ 4:0] XCSCOMM_4_0,
    input        XCSECOND,
    input [ 4:0] XCSIDBS_4_0,
    input        XCSLOOP,
    input [ 1:0] XCSMIS_1_0,
    input [ 1:0] XCSRASEL_1_0,
    input [ 1:0] XCSRBSEL_1_0,
    input [ 3:0] XCSRB_3_0,
    input        XCSSCOND,
    input [ 1:0] XCSSST_1_0,
    input [ 3:0] XCSTS_6_3,
    input        XCSVECT,
    input        XCSXRF3,
    input        XEDON,
    input        XEMPIDN,
    input        XETRAPN,
    input        XEWCAN,
    input        XFTRAPN,
    input        XILCSN,
    input        XIOXERRN,
    input        XMAPN,
    input        XMCLK,
    input        XMORN,
    input        XMRN,
    input        XPANN,
    input        XPARERRN,
    input        XPOWFAILN,
    input        XPTSTN,
    input [ 6:0] XPT_9_15,
    input        XSPARE,
    input        XSTP,
    input        XTCLK,
    input [ 2:0] XTSEL_2_0,
    input        XVTRAPN,


    // Input and output signals connected to BUS Driver
    input  [15:0] XFIDB_15_0_IN,
    output [15:0] XFIDB_15_0_OUT,

    // Output signals
    output        XACONDN,
    output        XBRKN,
    output        XDOUBLE,
    output        XECCR,
    output        XERFN,
    output        XINTRQN,
    output        XIONI,
    output [ 3:0] XLAA_3_0,
    output [13:0] XLA_23_10,
    output [ 3:0] XLBA_3_0,
    output        XLSHADOW,
    output [12:0] XMA_12_0,
    output [ 9:0] XMCA_9_0,
    output [ 1:0] XPCR_1_0,
    output [ 3:0] XPIL_3_0,
    output        XPONI,
    output [ 1:0] XRF_1_0,
    output [ 4:0] XTEST_4_0,
    output        XTRAPN,
    output        XWCSN,
    output        XWRTRF
);



  /*******************************************************************************
   ** The wires are defined here                                                 **
   *******************************************************************************/
  wire [ 6:0] sx_pt_9_15;
  wire [ 1:0] s_cssst_1_0;
  wire [15:0] s_b_15_0;
  wire [ 6:0] s_pt_15_9;
  wire [ 1:0] sx_rf_1_0_out;
  wire [15:0] s_nlca_15_0;
  wire [ 3:0] s_tvec_3_0;
  wire [15:0] s_picmask_15_0;
  wire [ 3:0] sx_lba_3_0_out;
  wire [ 3:0] s_csrb_3_0;
  wire [ 2:0] s_picv_2_0;
  wire [ 8:0] s_csalui_8_0;
  wire [ 3:0] sx_pil_3_0_out;

  wire [ 3:0] sx_csts_6_3;
  wire [15:0] s_a_15_0;
  wire [15:0] sx_cd_15_0;
  wire [15:0] s_csbit_15_0;
  wire [ 1:0] s_csmis_1_0;
  wire [15:0] s_cd_15_0;
  wire [ 1:0] sx_pcr_1_0_out;
  wire [ 1:0] s_csrbsel_1_0;
  wire [ 4:0] sx_csidbs_4_0;
  wire [ 4:0] sx_cscomm_4_0;
  wire [ 3:0] s_csts_6_3;

  wire [15:0] s_xfidbi_15_0;
  wire [ 2:0] sx_tsel_2_0;
  wire [15:0] s_pcr_15_0;
  wire [ 3:0] sx_laa_3_0_out;
  wire [ 1:0] sx_csrasel_1_0;
  wire [ 1:0] s_csrasel_1_0;
  wire [ 4:0] s_csidbs_4_0;
  wire [15:0] sx_csbit_15_0;
  wire [ 9:0] sx_mca_9_0_out;
  wire [15:0] s_ea_15_0;
  wire [13:0] sx_la_23_10_out;
  wire [12:0] sx_ma_12_0_out;
  wire [ 1:0] s_csalum_1_0;
  wire [ 1:0] sx_csrbsel_1_0;
  wire [ 3:0] s_sc_6_3;
  wire [ 4:0] s_cscomm_4_0;
  wire [ 1:0] s_cscinsel_1_0;
  wire [ 1:0] sx_csinsel_1_0;
  wire [ 3:0] sx_csrb_3_0;
  wire [ 8:0] sx_csalui_8_0;
  wire [ 1:0] sx_csalum_1_0;
  wire [15:0] s_pr_15_0;
  wire [ 1:0] sx_csmis_1_0;
  wire [15:0] s_rb_15_0;
  wire [15:0] s_xr_15_0;
  wire [ 2:0] s_pics_2_0;

  wire [ 2:0] s_tsel_2_0;
  wire [15:0] s_br_15_0;
  wire [ 4:0] sx_test_4_0_out;
  wire [ 1:0] sx_cssst_1_0;
  wire        s_BDEST;
  wire        s_cbrk_n;
  wire        s_cfetch;
  wire        s_clff_n;
  wire        s_clirq_n;
  wire        s_cond;
  wire        s_cry;
  wire        s_csalui0;
  wire        s_csalui1;
  wire        s_csalui2;
  wire        s_csalui3;
  wire        s_csalui4;
  wire        s_csalui5;
  wire        s_csalui6;
  wire        s_csalui7;
  wire        s_csalui8;
  wire        s_csalum0;
  wire        s_csalum1;
  wire        s_csbit0;
  wire        s_csbit1;
  wire        s_csbit10;
  wire        s_csbit11;
  wire        s_csbit12;
  wire        s_csbit13;
  wire        s_csbit14;
  wire        s_csbit15;
  wire        s_csbit2;
  wire        s_csbit3;
  wire        s_csbit4;
  wire        s_csbit5;
  wire        s_csbit6;
  wire        s_csbit7;
  wire        s_csbit8;
  wire        s_csbit9;
  wire        s_cscinsel0;
  wire        s_cscinsel1;
  wire        s_cscomm0;
  wire        s_cscomm1;
  wire        s_cscomm2;
  wire        s_cscomm3;
  wire        s_cscomm4;
  wire        s_csidbs0;
  wire        s_csidbs1;
  wire        s_csidbs2;
  wire        s_csidbs3;
  wire        s_csidbs4;
  wire        s_csmi0;
  wire        s_csmi1;
  wire        s_csmreq;
  wire        s_csrasel0;
  wire        s_csrasel1;
  wire        s_csrb0;
  wire        s_csrb1;
  wire        s_csrb2;
  wire        s_csrb3;
  wire        s_csrbsel0;
  wire        s_csrbsel1;
  wire        s_cssst0;
  wire        s_cssst1;
  wire        s_csts3;
  wire        s_csts4;
  wire        s_csts5;
  wire        s_csts6;
  wire        s_deep;
  wire        s_dstop_n;
  wire        s_dzd;
  wire        s_epcr_n;
  wire        s_epgs_n;
  wire        s_epic;
  wire        s_epicmask_n;
  wire        s_epics_n;
  wire        s_epicv_n;
  wire        s_f11;
  wire        s_f15;
  wire        s_fetch_n;
  wire        s_higs_n;
  wire        s_ind_n;
  wire        s_irq;
  wire        s_lcz_n;
  wire        s_lddbr_n;
  wire        s_ldgpr_n;
  wire        s_ldirv;
  wire        s_ldlc_n;
  wire        s_ldpil_n;
  wire        s_logs_n;
  wire        s_lwca_n;
  wire        s_mi;
  wire        s_ood;
  wire        s_ovf;
  wire        s_pd;
  wire        s_pn;
  wire        s_power;
  wire        s_pt10;
  wire        s_pt11;
  wire        s_pt12;
  wire        s_pt13;
  wire        s_pt14;
  wire        s_pt15;
  wire        s_pt9;
  wire        s_ptm;
  wire        s_pviol;
  wire        s_restr;
  wire        s_sgr;
  wire        s_t_n;
  wire        s_tsel0;
  wire        s_tsel1;
  wire        s_tsel2;
  wire        s_up_n;
  wire        s_vacc_n;
  wire        s_vex;
  wire        s_wp_n;
  wire        s_wr3;
  wire        s_wr7;
  wire        s_write_n;
  wire        s_xfetch_n;
  wire        s_z;
  wire        s_zf;
  wire        sx_acond_n_out;
  wire        sx_aluclk;
  wire        sx_bint10_n;
  wire        sx_bint11_n;
  wire        sx_bint12_n;
  wire        sx_bint13_n;
  wire        sx_bint15_n;
  wire        sx_brk_n_out;
  wire        sx_csbit20;
  wire        sx_csecond;
  wire        sx_csloop;
  wire        sx_csscond;
  wire        sx_csvect;
  wire        sx_csxrf3;
  wire        sx_double_out;
  wire        sx_eccr_out;
  wire        sx_edo_n;
  wire        sx_empid_n;
  wire        sx_erf_n;
  wire        sx_etrap_n;
  wire        sx_ewca_n;
  wire        sx_ftrap_n;
  wire        sx_ilcs_n;
  wire        sx_intrq_n_out;
  wire        sx_ioni_out;
  wire        sx_ioxerr_n;
  wire        sx_lshadow_out;
  wire        sx_map_n;
  wire        sx_mclk;
  wire        sx_mor_n;
  wire        sx_mrn;
  wire        sx_pan_n;
  wire        sx_parerr_n;
  wire        sx_pcr0;
  wire        sx_pcr1;
  wire        sx_poni_out;
  wire        sx_powfail_n;
  wire        sx_ptst_n;
  wire        sx_spare;
  wire        sx_stp;
  wire        sx_tclk;
  wire        sx_trap_n_out;
  wire        sx_vtrap_n;
  wire        sx_wcs_n_out;
  wire        sx_wrtrf_out;

  /*******************************************************************************
   ** Here all wiring is defined                                                 **
   *******************************************************************************/
  assign s_cd_15_0[15:0]        = sx_cd_15_0[15:0];

  assign s_csalui_8_0[0]     = s_csalui0;
  assign s_csalui_8_0[1]     = s_csalui1;
  assign s_csalui_8_0[2]     = s_csalui2;
  assign s_csalui_8_0[3]     = s_csalui3;
  assign s_csalui_8_0[4]     = s_csalui4;
  assign s_csalui_8_0[5]     = s_csalui5;
  assign s_csalui_8_0[6]     = s_csalui6;
  assign s_csalui_8_0[7]     = s_csalui7;
  assign s_csalui_8_0[8]     = s_csalui8;

  assign s_csalui0           = sx_csalui_8_0[0];
  assign s_csalui1           = sx_csalui_8_0[1];
  assign s_csalui2           = sx_csalui_8_0[2];
  assign s_csalui3           = sx_csalui_8_0[3];
  assign s_csalui4           = sx_csalui_8_0[4];
  assign s_csalui5           = sx_csalui_8_0[5];
  assign s_csalui6           = sx_csalui_8_0[6];
  assign s_csalui7           = sx_csalui_8_0[7];
  assign s_csalui8           = sx_csalui_8_0[8];

  assign s_csalum_1_0[0]     = s_csalum0;
  assign s_csalum_1_0[1]     = s_csalum1;

  assign s_csalum0           = sx_csalum_1_0[0];
  assign s_csalum1           = sx_csalum_1_0[1];

  assign s_csbit_15_0[0]     = s_csbit0;
  assign s_csbit_15_0[1]     = s_csbit1;
  assign s_csbit_15_0[2]     = s_csbit2;
  assign s_csbit_15_0[3]     = s_csbit3;
  assign s_csbit_15_0[4]     = s_csbit4;
  assign s_csbit_15_0[5]     = s_csbit5;
  assign s_csbit_15_0[6]     = s_csbit6;
  assign s_csbit_15_0[7]     = s_csbit7;
  assign s_csbit_15_0[8]     = s_csbit8;
  assign s_csbit_15_0[9]     = s_csbit9;
  assign s_csbit_15_0[10]    = s_csbit10;
  assign s_csbit_15_0[11]    = s_csbit11;
  assign s_csbit_15_0[12]    = s_csbit12;
  assign s_csbit_15_0[13]    = s_csbit13;
  assign s_csbit_15_0[14]    = s_csbit14;
  assign s_csbit_15_0[15]    = s_csbit15;

  assign s_csbit0            = sx_csbit_15_0[0];
  assign s_csbit1            = sx_csbit_15_0[1];
  assign s_csbit2            = sx_csbit_15_0[2];
  assign s_csbit3            = sx_csbit_15_0[3];
  assign s_csbit4            = sx_csbit_15_0[4];
  assign s_csbit5            = sx_csbit_15_0[5];
  assign s_csbit6            = sx_csbit_15_0[6];
  assign s_csbit7            = sx_csbit_15_0[7];
  assign s_csbit8            = sx_csbit_15_0[8];
  assign s_csbit9            = sx_csbit_15_0[9];
  assign s_csbit10           = sx_csbit_15_0[10];
  assign s_csbit11           = sx_csbit_15_0[11];
  assign s_csbit12           = sx_csbit_15_0[12];
  assign s_csbit13           = sx_csbit_15_0[13];
  assign s_csbit14           = sx_csbit_15_0[14];
  assign s_csbit15           = sx_csbit_15_0[15];


  assign s_cscinsel_1_0[0]   = s_cscinsel0;
  assign s_cscinsel_1_0[1]   = s_cscinsel1;

  assign s_cscinsel0         = sx_csinsel_1_0[0];
  assign s_cscinsel1         = sx_csinsel_1_0[1];

  assign s_cscomm_4_0[0]     = s_cscomm0;
  assign s_cscomm_4_0[1]     = s_cscomm1;
  assign s_cscomm_4_0[2]     = s_cscomm2;
  assign s_cscomm_4_0[3]     = s_cscomm3;
  assign s_cscomm_4_0[4]     = s_cscomm4;

  assign s_cscomm0           = sx_cscomm_4_0[0];
  assign s_cscomm1           = sx_cscomm_4_0[1];
  assign s_cscomm2           = sx_cscomm_4_0[2];
  assign s_cscomm3           = sx_cscomm_4_0[3];
  assign s_cscomm4           = sx_cscomm_4_0[4];

  assign s_csidbs_4_0[0]     = s_csidbs0;
  assign s_csidbs_4_0[1]     = s_csidbs1;
  assign s_csidbs_4_0[2]     = s_csidbs2;
  assign s_csidbs_4_0[3]     = s_csidbs3;
  assign s_csidbs_4_0[4]     = s_csidbs4;

  assign s_csidbs0           = sx_csidbs_4_0[0];
  assign s_csidbs1           = sx_csidbs_4_0[1];
  assign s_csidbs2           = sx_csidbs_4_0[2];
  assign s_csidbs3           = sx_csidbs_4_0[3];
  assign s_csidbs4           = sx_csidbs_4_0[4];

  assign s_csmi0             = sx_csmis_1_0[0];
  assign s_csmi1             = sx_csmis_1_0[1];

  assign s_csmis_1_0[0]      = s_csmi0;
  assign s_csmis_1_0[1]      = s_csmi1;

  assign s_csrasel_1_0[0]    = s_csrasel0;
  assign s_csrasel_1_0[1]    = s_csrasel1;

  assign s_csrasel0          = sx_csrasel_1_0[0];
  assign s_csrasel1          = sx_csrasel_1_0[1];

  assign s_csrb_3_0[0]       = s_csrb0;
  assign s_csrb_3_0[1]       = s_csrb1;
  assign s_csrb_3_0[2]       = s_csrb2;
  assign s_csrb_3_0[3]       = s_csrb3;

  assign s_csrb0             = sx_csrb_3_0[0];
  assign s_csrb1             = sx_csrb_3_0[1];
  assign s_csrb2             = sx_csrb_3_0[2];
  assign s_csrb3             = sx_csrb_3_0[3];

  assign s_csrbsel_1_0[0]    = s_csrbsel0;
  assign s_csrbsel_1_0[1]    = s_csrbsel1;

  assign s_csrbsel0          = sx_csrbsel_1_0[0];
  assign s_csrbsel1          = sx_csrbsel_1_0[1];

  assign s_cssst_1_0[0]      = s_cssst0;
  assign s_cssst_1_0[1]      = s_cssst1;

  assign s_cssst0            = sx_cssst_1_0[0];
  assign s_cssst1            = sx_cssst_1_0[1];

  assign s_csts_6_3[0]       = s_csts3;
  assign s_csts_6_3[1]       = s_csts4;
  assign s_csts_6_3[2]       = s_csts5;
  assign s_csts_6_3[3]       = s_csts6;

  assign s_csts3             = sx_csts_6_3[0];
  assign s_csts4             = sx_csts_6_3[1];
  assign s_csts5             = sx_csts_6_3[2];
  assign s_csts6             = sx_csts_6_3[3];

  assign s_pt_15_9[0]        = s_pt9;
  assign s_pt_15_9[1]        = s_pt10;
  assign s_pt_15_9[2]        = s_pt11;
  assign s_pt_15_9[3]        = s_pt12;
  assign s_pt_15_9[4]        = s_pt13;
  assign s_pt_15_9[5]        = s_pt14;
  assign s_pt_15_9[6]        = s_pt15;

  assign s_pt9               = sx_pt_9_15[0];
  assign s_pt10              = sx_pt_9_15[1];
  assign s_pt11              = sx_pt_9_15[2];
  assign s_pt12              = sx_pt_9_15[3];
  assign s_pt13              = sx_pt_9_15[4];
  assign s_pt14              = sx_pt_9_15[5];
  assign s_pt15              = sx_pt_9_15[6];

  assign s_tsel_2_0[0]       = s_tsel0;
  assign s_tsel_2_0[1]       = s_tsel1;
  assign s_tsel_2_0[2]       = s_tsel2;

  assign s_tsel0             = sx_tsel_2_0[0];
  assign s_tsel1             = sx_tsel_2_0[1];
  assign s_tsel2             = sx_tsel_2_0[2];

  assign sx_pcr_1_0_out[0]   = sx_pcr0;
  assign sx_pcr_1_0_out[1]   = sx_pcr1;

  assign sx_pcr0             = s_pcr_15_0[0];
  assign sx_pcr1             = s_pcr_15_0[1];

  /*******************************************************************************
   ** Here all input connections are defined                                     **
   *******************************************************************************/
  assign sx_cd_15_0[15:0]    = XCD_15_0;
  assign sx_csalui_8_0[8:0]  = XCSALUI_8_0;
  assign sx_csalum_1_0[1:0]  = XCSALUM_1_0;
  assign sx_csbit_15_0[15:0] = XCSBIT_15_0;
  assign sx_cscomm_4_0[4:0]  = XCSCOMM_4_0;
  assign sx_csidbs_4_0[4:0]  = XCSIDBS_4_0;
  assign sx_csinsel_1_0[1:0] = XCSCINSEL_1_0;
  assign sx_csmis_1_0[1:0]   = XCSMIS_1_0;
  assign sx_csrasel_1_0[1:0] = XCSRASEL_1_0;
  assign sx_csrb_3_0[3:0]    = XCSRB_3_0;
  assign sx_csrbsel_1_0[1:0] = XCSRBSEL_1_0;
  assign sx_csts_6_3[3:0]    = XCSTS_6_3;
  assign sx_pt_9_15[6:0]     = XPT_9_15;
  assign sx_tsel_2_0[2:0]    = XTSEL_2_0;
  assign sx_cssst_1_0[1:0]   = XCSSST_1_0[1:0];

  assign sx_aluclk           = XALUCLK;
  assign sx_bint10_n         = XBINT10N;
  assign sx_bint11_n         = XBINT11N;
  assign sx_bint12_n         = XBINT12N;
  assign sx_bint13_n         = XBINT13N;
  assign sx_bint15_n         = XBINT15N;
  assign sx_csbit20          = XCSBIT20;
  assign sx_csecond          = XCSECOND;
  assign sx_csloop           = XCSLOOP;
  assign sx_csscond          = XCSSCOND;
  assign sx_csvect           = XCSVECT;
  assign sx_csxrf3           = XCSXRF3;
  assign sx_edo_n            = XEDON;
  assign sx_empid_n          = XEMPIDN;
  assign sx_etrap_n          = XETRAPN;
  assign sx_ewca_n           = XEWCAN;
  assign sx_ftrap_n          = XFTRAPN;
  assign sx_ilcs_n           = XILCSN;
  assign sx_ioxerr_n         = XIOXERRN;
  assign sx_map_n            = XMAPN;
  assign sx_mclk             = XMCLK;
  assign sx_mor_n            = XMORN;
  assign sx_mrn              = XMRN;
  assign sx_pan_n            = XPANN;
  assign sx_parerr_n         = XPARERRN;
  assign sx_powfail_n        = XPOWFAILN;
  assign sx_ptst_n           = XPTSTN;
  assign sx_spare            = XSPARE;
  assign sx_stp              = XSTP;
  assign sx_tclk             = XTCLK;
  assign sx_vtrap_n          = XVTRAPN;

  /*******************************************************************************
   ** Here all output connections are defined                                    **
   *******************************************************************************/
  assign XACONDN             = sx_acond_n_out;
  assign XBRKN               = sx_brk_n_out;
  assign XDOUBLE             = sx_double_out;
  assign XECCR               = sx_eccr_out;
  assign XERFN               = sx_erf_n;
  assign XINTRQN             = sx_intrq_n_out;
  assign XIONI               = sx_ioni_out;
  assign XLA_23_10           = sx_la_23_10_out[13:0];
  assign XLAA_3_0            = sx_laa_3_0_out[3:0];
  assign XLBA_3_0            = sx_lba_3_0_out[3:0];
  assign XLSHADOW            = sx_lshadow_out;
  assign XMA_12_0            = sx_ma_12_0_out[12:0];
  assign XMCA_9_0            = sx_mca_9_0_out[9:0];
  assign XPCR_1_0            = sx_pcr_1_0_out[1:0];
  assign XPIL_3_0            = sx_pil_3_0_out[3:0];
  assign XPONI               = sx_poni_out;
  assign XRF_1_0             = sx_rf_1_0_out[1:0];
  assign XTEST_4_0           = sx_test_4_0_out[4:0];
  assign XTRAPN              = sx_trap_n_out;
  assign XWCSN               = sx_wcs_n_out;
  assign XWRTRF              = sx_wrtrf_out;

  /*******************************************************************************
   ** Here all in-lined components are defined                                   **
   *******************************************************************************/

  // Power
  assign s_power             = 1'b1;

  // IDB bus mapping

  wire [15:0] s_FIDBO_15_0;
  wire [15:0] s_FIDBI_15_0;

  wire [15:0] s_alu_IDB_15_0_IN;
  wire [15:0] s_alu_IDB_15_0_OUT;

  wire [15:0] s_idbctl_IDB_15_0_IN;
  wire [15:0] s_idbctl_IDB_15_0_OUT;

  wire [15:0] s_int_IDB_15_0_IN;
  wire [15:0] s_mac_IDB_15_0_IN;

  wire s_dcd_fidbo5;

  // Assign FIDBO bus to DCD, INT and MAC
  assign s_dcd_fidbo5         = s_FIDBO_15_0[5];
  assign s_int_IDB_15_0_IN    = s_FIDBO_15_0;
  assign s_mac_IDB_15_0_IN    = s_FIDBO_15_0;

  // IDBCTL input comes from BusDriver signal s_xfidbi_15_0
  assign s_idbctl_IDB_15_0_IN = s_xfidbi_15_0;

  // FIDBI bus comes out of IDBCTL
  assign s_FIDBI_15_0         = s_idbctl_IDB_15_0_OUT;

  // ALU reads FIDBI from IDBCTL
  assign s_alu_IDB_15_0_IN    = s_FIDBI_15_0;

  // Input signal to Bus Driver is an OR of all output signals from ALU | IDBCTL
  assign s_FIDBO_15_0         = s_alu_IDB_15_0_OUT | s_idbctl_IDB_15_0_OUT;




  /*******************************************************************************
   ** Here all sub-circuits are defined                                          **
   *******************************************************************************/


  BusDriver16 BD_FIDBO (
      .EN(sx_edo_n),  // Enable = FALSE => A to IO, Enable=TRUE => IO to A
      .TN(sx_ptst_n),  // Test enable when LOW

      .A_15_0_IN(s_FIDBO_15_0),    // Data inputA (Connect to internal FIDBO data bus))
      .A_15_0_OUT(s_xfidbi_15_0),  // A output  (Connect to internal XFIDBI data bus)

      .IO_15_0_IN(XFIDB_15_0_IN),    // IN from XFIDB data bus (Connect to EXTERNAL _XFIDB_ data bus)
      .IO_15_0_OUT(XFIDB_15_0_OUT)   // Out to XFIDB data bus (Connect to EXTERNAL _XFIDB_ data bus)
  );


  CGA_ALU ALU (
      .ALUCLK(sx_aluclk),
      .A_15_0(s_a_15_0[15:0]),
      .BDEST(s_BDEST),
      .B_15_0(s_b_15_0[15:0]),
      .CD_15_0(s_cd_15_0[15:0]),
      .CRY(s_cry),
      .CSALUI_8_0(s_csalui_8_0[8:0]),
      .CSALUM_1_0(s_csalum_1_0[1:0]),
      .CSBIT_15_0(s_csbit_15_0[15:0]),
      .CSCINSEL_1_0(s_cscinsel_1_0[1:0]),
      .CSIDBS_4_0(s_csidbs_4_0[4:0]),
      .CSMIS_1_0(s_csmis_1_0[1:0]),
      .CSSST_1_0(s_cssst_1_0[1:0]),
      .DOUBLE(sx_double_out),
      .EA_15_0(s_ea_15_0[15:0]),
      .F11(s_f11),
      .F15(s_f15),
      .FIDBI_15_0(s_alu_IDB_15_0_IN),
      .FIDBO_15_0_OUT(s_alu_IDB_15_0_OUT),
      .IONI(sx_ioni_out),
      .LAA_3_0(sx_laa_3_0_out[3:0]),
      .LBA_3_0(sx_lba_3_0_out[3:0]),
      .LCZN(s_lcz_n),
      .LDDBRN(s_lddbr_n),
      .LDGPRN(s_ldgpr_n),
      .LDIRV(s_ldirv),
      .LDPILN(s_ldpil_n),
      .MI(s_mi),
      .OVF(s_ovf),
      .PIL_3_0(sx_pil_3_0_out[3:0]),
      .PONI(sx_poni_out),
      .PTM(s_ptm),
      .RB_15_0(s_rb_15_0[15:0]),
      .SGR(s_sgr),
      .UPN(s_up_n),
      .XFETCHN(s_xfetch_n),
      .Z(s_z),
      .ZF(s_zf)
  );

  CGA_TRAP TRAP (
      .BRKN(sx_brk_n_out),
      .CBRKN(s_cbrk_n),
      .DSTOPN(s_dstop_n),
      .ETRAPN(sx_etrap_n),
      .FETCHN(s_fetch_n),
      .FTRAPN(sx_ftrap_n),
      .INDN(s_ind_n),
      .INTRQN(sx_intrq_n_out),
      .PANN(sx_pan_n),
      .PCR_1_0(sx_pcr_1_0_out[1:0]),
      .PONI(sx_poni_out),
      .PT_15_9(s_pt_15_9[6:0]),
      .PVIOL(s_pviol),
      .RESTR(s_restr),
      .TCLK(sx_tclk),
      .TRAPN(sx_trap_n_out),
      .TVEC_3_0(s_tvec_3_0[3:0]),
      .VACCN(s_vacc_n),
      .VTRAPN(sx_vtrap_n),
      .WRITEN(s_write_n)
  );

  CGA_IDBCTL IDBCTL (
      .EPCRN(s_epcr_n),
      .EPGSN(s_epgs_n),
      .EPICMASKN(s_epicmask_n),
      .EPICSN(s_epics_n),
      .EPICVN(s_epicv_n),
      .FETCHN(s_fetch_n),
      .HIGSN(s_higs_n),
      .LA_21_10(sx_la_23_10_out[11:0]),
      .LOGSN(s_logs_n),
      .MCLK(sx_mclk),
      .PCR_15_0(s_pcr_15_0[15:0]),
      .PD(s_pd),
      .PICMASK_15_0(s_picmask_15_0[15:0]),
      .PICS_2_0(s_pics_2_0[2:0]),
      .PICV_2_0(s_picv_2_0[2:0]),
      .PVIOL(s_pviol),
      .VACCN(s_vacc_n),
      .XFIDBI_15_0(s_idbctl_IDB_15_0_IN[15:0]),
      .FIDBI_15_0_OUT(s_idbctl_IDB_15_0_OUT[15:0])
  );

  CGA_WRF WRF (
      .ALUCLK(sx_aluclk),
      .A_15_0(s_a_15_0[15:0]),
      .BDEST(s_BDEST),
      .BR_15_0(s_br_15_0[15:0]),
      .B_15_0(s_b_15_0[15:0]),
      .EA_15_0(s_ea_15_0[15:0]),
      .LAA_3_0(sx_laa_3_0_out[3:0]),
      .LBA_3_0(sx_lba_3_0_out[3:0]),
      .NLCA_15_0(s_nlca_15_0[15:0]),
      .PR_15_0(s_pr_15_0[15:0]),
      .RB_15_0(s_rb_15_0[15:0]),
      .WPN(s_wp_n),
      .WR3(s_wr3),
      .WR7(s_wr7),
      .XFETCHN(s_xfetch_n),
      .XR_15_0(s_xr_15_0[15:0])
  );

  CGA_DCD DCD (
      .BRKN(sx_brk_n_out),
      .CBRKN(s_cbrk_n),
      .CFETCH(s_cfetch),
      .CLFFN(s_clff_n),
      .CLIRQN(s_clirq_n),
      .CSCOMM_4_0(s_cscomm_4_0[4:0]),
      .CSIDBS_4_0(s_csidbs_4_0[4:0]),
      .CSMIS_1_0(s_csmis_1_0[1:0]),
      .CSMREQ(s_csmreq),
      .DSTOPN(s_dstop_n),
      .EPCRN(s_epcr_n),
      .EPGSN(s_epgs_n),
      .EPIC(s_epic),
      .EPICSN(s_epics_n),
      .EPICVN(s_epicv_n),
      .ERFN(sx_erf_n),
      .F15(s_f15),
      .FETCHN(s_fetch_n),
      .FIDBO5(s_dcd_fidbo5),
      .LCSN(sx_ilcs_n),
      .INDN(s_ind_n),
      .INTRQN(sx_intrq_n_out),
      .LDDBRN(s_lddbr_n),
      .LDGPRN(s_ldgpr_n),
      .LDIRV(s_ldirv),
      .LDLCN(s_ldlc_n),
      .LDPILN(s_ldpil_n),
      .LSHADOW(sx_lshadow_out),
      .LWCAN(s_lwca_n),
      .MCLK(sx_mclk),
      .MRN(sx_mrn),
      .PONI(sx_poni_out),
      .SGR(s_sgr),
      .VACCN(s_vacc_n),
      .VEX(s_vex),
      .WPN(s_wp_n),
      .WRITEN(s_write_n),
      .WRTRF(sx_wrtrf_out),
      .XFETCHN(s_xfetch_n),
      .CRY(s_cry),
      .ZF(s_zf)
  );

  CGA_INTR INTR (
      .BINT10N(sx_bint10_n),
      .BINT11N(sx_bint11_n),
      .BINT12N(sx_bint12_n),
      .BINT13N(sx_bint13_n),
      .BINT15N(sx_bint15_n),
      .CLIRQN(s_clirq_n),
      .EMPIDN(sx_empid_n),
      .EPIC(s_epic),
      .EPICMASKN(s_epicmask_n),
      .FIDBO_15_0(s_int_IDB_15_0_IN[15:0]),
      .HIGSN(s_higs_n),
      .INTRQN(sx_intrq_n_out),
      .IOXERRN(sx_ioxerr_n),
      .IRQ(s_irq),
      .LAA_3_0(sx_laa_3_0_out[3:0]),
      .LOGSN(s_logs_n),
      .MCLK(sx_mclk),
      .NORN(sx_mor_n),
      .PANN(sx_pan_n),
      .PARERRN(sx_parerr_n),
      .PD(s_pd),
      .PICMASK_15_0(s_picmask_15_0[15:0]),
      .PICS_2_0(s_pics_2_0[2:0]),
      .PICV_2_0(s_picv_2_0[2:0]),
      .POWFAILN(sx_powfail_n),
      .Z(s_z)
  );

  CGA_MAC MAC (
      .BR_15_0(s_br_15_0[15:0]),
      .CD_15_0(s_cd_15_0[15:0]),
      .CMIS_1_0(s_csmis_1_0[1:0]),
      .CSCOMM_4_0(s_cscomm_4_0[4:0]),
      .CSMREQ(s_csmreq),
      .DOUBLE(sx_double_out),
      .ECCR(sx_eccr_out),
      .FIDBO_15_0(s_mac_IDB_15_0_IN[15:0]),
      .ILCSN(sx_ilcs_n),
      .LA_23_10(sx_la_23_10_out[13:0]),
      .LSHADOW(sx_lshadow_out),
      .MCA_9_0(sx_mca_9_0_out[9:0]),
      .MCLK(sx_mclk),
      .NLCA_15_0(s_nlca_15_0[15:0]),
      .PCR_15_0(s_pcr_15_0[15:0]),
      .PONI(sx_poni_out),
      .PR_15_0(s_pr_15_0[15:0]),
      .PTM(s_ptm),
      .RB_15_0(s_rb_15_0[15:0]),
      .VEX(s_vex),
      .WR3(s_wr3),
      .WR7(s_wr7),
      .XR_15_0(s_xr_15_0[15:0])
  );

  CGA_MIC MIC (
      .sysclk(sysclk),  // System clock in FPGA
      .sys_rst_n(sys_rst_n),  // System reset in FPGA

      .ACONDN(sx_acond_n_out),
      .ALUCLK(sx_aluclk),
      .CD_15_0(s_cd_15_0[15:0]),
      .CFETCH(s_cfetch),
      .CLFFN(s_clff_n),
      .COND(s_cond),
      .CRY(s_cry),
      .CSALUI8(s_csalui8),
      .CSBIT20(sx_csbit20),
      .CSBIT_15_0(s_csbit_15_0[15:0]),
      .CSCOND(sx_csscond),
      .CSECOND(sx_csecond),
      .CSLOOP(sx_csloop),
      .CSMIS0(s_csmi0),
      .CSRASEL_1_0(s_csrasel_1_0[1:0]),
      .CSRBSEL_1_0(s_csrbsel_1_0[1:0]),
      .CSRB_3_0(s_csrb_3_0[3:0]),
      .CSTS_6_3(s_csts_6_3[3:0]),
      .CSVECT(sx_csvect),
      .CSXRF3(sx_csxrf3),
      .DEEP(s_deep),
      .DZD(s_dzd),
      .EWCAN(sx_ewca_n),
      .F11(s_f11),
      .F15(s_f15),
      .ILCSN(sx_ilcs_n),
      .IRQ(s_irq),
      .LAA_3_0(sx_laa_3_0_out[3:0]),
      .LBA_3_0(sx_lba_3_0_out[3:0]),
      .LCZN(s_lcz_n),
      .LDIRV(s_ldirv),
      .LDLCN(s_ldlc_n),
      .LWCAN(s_lwca_n),
      .MAPN(sx_map_n),
      .MA_12_0(sx_ma_12_0_out[12:0]),
      .MCLK(sx_mclk),
      .MI(s_mi),
      .MRN(sx_mrn),
      .OOD(s_ood),
      .OVF(s_ovf),
      .PIL_3_0(sx_pil_3_0_out[3:0]),
      .PN(s_pn),
      .RESTR(s_restr),
      .RF_1_0(sx_rf_1_0_out[1:0]),
      .SC_6_3(s_sc_6_3[3:0]),
      .SPARE(sx_spare),
      .STP(sx_stp),
      .TN(s_t_n),
      .TRAPN(sx_trap_n_out),
      .TVEC_3_0(s_tvec_3_0[3:0]),
      .UPN(s_up_n),
      .WCSN(sx_wcs_n_out),
      .ZF(s_zf)
  );

  CGA_TESTMUX TESTMUX (
      .CBRKN(s_cbrk_n),
      .CFETCH(s_cfetch),
      .COND(s_cond),
      .CRY(s_cry),
      .CSMREQ(s_csmreq),
      .DEEP(s_deep),
      .DSTOPN(s_dstop_n),
      .DZD(s_dzd),
      .F15(s_f15),
      .INDN(s_ind_n),
      .LCZN(s_lcz_n),
      .LDIRV(s_ldirv),
      .MI(s_mi),
      .OOD(s_ood),
      .OVF(s_ovf),
      .PN(s_pn),
      .PTM(s_ptm),
      .PTREEOUT(s_power),
      .PTSTN(sx_ptst_n),
      .RESTR(s_restr),
      .SC_6_3(s_sc_6_3[3:0]),
      .SGR(s_sgr),
      .TEST_4_0(sx_test_4_0_out[4:0]),
      .TN(s_t_n),
      .TSEL_2_0(s_tsel_2_0[2:0]),
      .TVEC_3_0(s_tvec_3_0[3:0]),
      .UPN(s_up_n),
      .VACCN(s_vacc_n),
      .VEX(s_vex),
      .WPN(s_wp_n),
      .WRITEN(s_write_n),
      .XFETCHN(s_xfetch_n),
      .ZF(s_zf)
  );

endmodule

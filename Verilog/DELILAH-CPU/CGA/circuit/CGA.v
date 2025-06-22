/**************************************************************************
** ND120 CGA (CPU Gate Array / DELILAH)                                  **
** /CGA                                                                  **
** CGA TOP LEVEL                                                         **
**                                                                       **
** Page 2-9                                                              **
** SHEET 1 of 8                                                          **
**                                                                       **
** Last reviewed: 9-FEB-2025                                             **
** Ronny Hansen                                                          **
***************************************************************************/

module CGA (
    // System input signals
    input sysclk,    // System clock in FPGA
    input sys_rst_n, // System reset in FPGA

    // Control and data inputs
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
    input        XEDON,       //! Enable IDB "data out" from CGA
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
    input [15:0] XFIDB_15_0_IN,


    // Control and data outputs
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
    output        XPONI,     //! Memory Protection ON, PONI=1
    output [ 1:0] XRF_1_0,
    output [ 4:0] XTEST_4_0,
    output        XTRAPN,
    output        XWCSN,
    output        XWRTRF,
    output [15:0] XFIDB_15_0_OUT
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
  assign s_cd_15_0[15:0]     = sx_cd_15_0[15:0];

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
      .TN(sx_ptst_n), // Test enable when LOW

      .A_15_0_IN (s_FIDBO_15_0),  // Data inputA (Connect to internal FIDBO data bus))
      .A_15_0_OUT(s_xfidbi_15_0), // A output  (Connect to internal XFIDBI data bus)

      .IO_15_0_IN(XFIDB_15_0_IN),  // IN from XFIDB data bus (Connect to EXTERNAL _XFIDB_ data bus)
      .IO_15_0_OUT(XFIDB_15_0_OUT)  // Out to XFIDB data bus (Connect to EXTERNAL _XFIDB_ data bus)
  );


  // This module represents the Arithmetic Logic Unit (ALU) of the CPU,
  // which performs various arithmetic and logical operations.
  // It takes input signals for clock, operands, and control signals,
  // and produces output signals indicating the results of the operations,
  // including flags for carry, overflow, and specific operation results.
  CGA_ALU ALU (
      // FPGA system clock
      .sysclk(sysclk),  // System clock in FPGA
      .sys_rst_n(sys_rst_n),  // System reset in FPGA

      // Input signals
      .ALUCLK(sx_aluclk),
      .A_15_0(s_a_15_0[15:0]),
      .B_15_0(s_b_15_0[15:0]),
      .CD_15_0(s_cd_15_0[15:0]),
      .CSALUI_8_0(s_csalui_8_0[8:0]),
      .CSALUM_1_0(s_csalum_1_0[1:0]),
      .CSBIT_15_0(s_csbit_15_0[15:0]),
      .CSCINSEL_1_0(s_cscinsel_1_0[1:0]),
      .CSIDBS_4_0(s_csidbs_4_0[4:0]),
      .CSMIS_1_0(s_csmis_1_0[1:0]),
      .CSSST_1_0(s_cssst_1_0[1:0]),
      .EA_15_0(s_ea_15_0[15:0]),
      .FIDBI_15_0(s_alu_IDB_15_0_IN),
      .LAA_3_0(sx_laa_3_0_out[3:0]),  //! A Operand. CSBITS [15:12]
      .LBA_3_0(sx_lba_3_0_out[3:0]),  //! B Operand. CSBITS [19:16]
      .LCZN(s_lcz_n),
      .LDDBRN(s_lddbr_n),
      .LDGPRN(s_ldgpr_n),
      .LDIRV(s_ldirv),
      .LDPILN(s_ldpil_n),
      .UPN(s_up_n),
      .XFETCHN(s_xfetch_n),

      // Output signals
      .BDEST(s_BDEST),
      .CRY(s_cry),
      .DOUBLE(sx_double_out),
      .F11(s_f11),
      .F15(s_f15),
      .FIDBO_15_0_OUT(s_alu_IDB_15_0_OUT),
      .IONI(sx_ioni_out),
      .MI(s_mi),
      .OVF(s_ovf),
      .PIL_3_0(sx_pil_3_0_out[3:0]),
      .PONI(sx_poni_out),
      .PTM(s_ptm),
      .RB_15_0(s_rb_15_0[15:0]),
      .SGR(s_sgr),
      .Z(s_z),
      .ZF(s_zf)
  );

  // This module handles trap conditions in the CPU, managing various input signals
  // related to interrupts and exceptions.
  // It processes these signals to generate appropriate output signals
  // that indicate the status of the trap conditions, including break signals,
  // violation indicators, and trap requests.
  CGA_TRAP TRAP (
      // Input signals
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
      .TCLK(sx_tclk),
      .VACCN(s_vacc_n),
      .VTRAPN(sx_vtrap_n),
      .WRITEN(s_write_n),

      // Output signals
      .BRKN(sx_brk_n_out),
      .PVIOL(s_pviol),
      .RESTR(s_restr),
      .TRAPN(sx_trap_n_out),
      .TVEC_3_0(s_tvec_3_0[3:0])
  );

  // This module, IDBCTL, manages the control logic for the IDB (Input Data Buffer) in the CPU Gate Array.
  // It processes various input signals related to control and status, including fetch signals,
  // mask signals, and violation indicators, and produces an output signal for the IDB.
  CGA_IDBCTL IDBCTL (
      // Input signals
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

      // Output signals
      .FIDBI_15_0_OUT(s_idbctl_IDB_15_0_OUT[15:0])
  );

  // The CGA_WRF module is responsible for managing the write functionality of the CPU's registers.
  // It takes in clock signals, destination flags, and data for register selection and writing.
  // Outputs from this module include enable signals for reading from source registers,
  // write enable signals for specific registers, and the data contents of selected registers.
  CGA_WRF WRF
  (
    // System Input signals
   .sysclk(sysclk),                          // System clock in FPGA
   .sys_rst_n(sys_rst_n),                    // System reset in FPGA

   // Input signals
    .ALUCLK(sx_aluclk),          // Clock signal for the ALU
    .BDEST(s_BDEST),             // Flag indicating if B is the destination for writing
    .LAA_3_0(sx_laa_3_0_out[3:0]), // Selector for source register A
    .LBA_3_0(sx_lba_3_0_out[3:0]), // Selector for destination register B
    .NLCA_15_0(s_nlca_15_0[15:0]), // Data input for register #2 (P register)
    .RB_15_0(s_rb_15_0[15:0]),     // Data input for destination register B
    .XFETCHN(s_xfetch_n),          // Fetch signal for the P register

    // Output signals
    .EA_15_0(s_ea_15_0[15:0]),    // Enable signal for reading from source register A
    .WPN(s_wp_n),                  // Write enable signal for register #2 (P register), negated
    .WR3(s_wr3),                   // Write enable signal for register #3 (B register)
    .WR7(s_wr7),                   // Write enable signal for register #7 (X register)

    .A_15_0(s_a_15_0[15:0]),       // Data output from source register A
    .B_15_0(s_b_15_0[15:0]),       // Data output from destination register B

    .PR_15_0(s_pr_15_0[15:0]),     // Direct data output from P register
    .BR_15_0(s_br_15_0[15:0]),     // Direct data output from B register
    .XR_15_0(s_xr_15_0[15:0])      // Direct data output from X register
  );

  // The CGA_DCD module is a decoder within the DELILAH CPU's gate array. It interprets control signals,
  // decodes instructions, and manages the execution flow. It receives various status and control inputs,
  // and based on these, it generates the necessary control outputs to drive other parts of the CPU.

  // Input signals
  CGA_DCD DCD (
      // Input signals
      .sysclk(sysclk),                          // System clock in FPGA
      .sys_rst_n(sys_rst_n),                    // System reset in FPGA

      .BRKN(sx_brk_n_out),
      .CRY(s_cry),
      .CSCOMM_4_0(s_cscomm_4_0[4:0]),
      .CSIDBS_4_0(s_csidbs_4_0[4:0]),
      .CSMIS_1_0(s_csmis_1_0[1:0]),
      .F15(s_f15),
      .FIDBO5(s_dcd_fidbo5),
      .INTRQN(sx_intrq_n_out),
      .LCSN(sx_ilcs_n),
      .LSHADOW(sx_lshadow_out),
      .MCLK(sx_mclk),
      .MRN(sx_mrn),
      .PONI(sx_poni_out),
      .SGR(s_sgr),
      .VEX(s_vex),
      .ZF(s_zf),

      // Output signals
      .CBRKN(s_cbrk_n),
      .CFETCH(s_cfetch),
      .CLFFN(s_clff_n),
      .CLIRQN(s_clirq_n),
      .CSMREQ(s_csmreq),
      .DSTOPN(s_dstop_n),
      .EPCRN(s_epcr_n),
      .EPGSN(s_epgs_n),
      .EPIC(s_epic),
      .EPICSN(s_epics_n),
      .EPICVN(s_epicv_n),
      .ERFN(sx_erf_n),
      .FETCHN(s_fetch_n),
      .INDN(s_ind_n),
      .LDDBRN(s_lddbr_n),
      .LDGPRN(s_ldgpr_n),
      .LDIRV(s_ldirv),
      .LDLCN(s_ldlc_n),
      .LDPILN(s_ldpil_n),
      .LWCAN(s_lwca_n),
      .VACCN(s_vacc_n),
      .WPN(s_wp_n),
      .WRITEN(s_write_n),
      .WRTRF(sx_wrtrf_out),
      .XFETCHN(s_xfetch_n)
  );
  // The CGA_INTR module is responsible for handling interrupt requests and related control signals within the DELILAH CPU. It processes various interrupt signals, manages interrupt masking, and provides status outputs that influence the CPU's response to different interrupt conditions.

  // Input signals to the CGA_INTR module
  CGA_INTR INTR (
      .BINT10N(sx_bint10_n),       // Bus Interrupt 10, active low
      .BINT11N(sx_bint11_n),       // Bus Interrupt 11, active low
      .BINT12N(sx_bint12_n),       // Bus Interrupt 12, active low
      .BINT13N(sx_bint13_n),       // Bus Interrupt 13, active low
      .BINT15N(sx_bint15_n),       // Bus Interrupt 15, active low
      .CLIRQN(s_clirq_n),          // Clear Interrupt Request, active low
      .EMPIDN(sx_empid_n),         // Interrupt Disable (EPIC.LDMPIE->set mask reg:inh all ints)
      .EPIC(s_epic),               // Enable PIC (Programmable Interrupt Controller) signal
      .FIDBO_15_0(s_int_IDB_15_0_IN[15:0]), // FIDB, 16-bit
      .IOXERRN(sx_ioxerr_n),       // IO Exception Error, active low
      .LAA_3_0(sx_laa_3_0_out[3:0]), // Latched Address A, 4-bit
      .MCLK(sx_mclk),              // Master Clock
      .MORN(sx_mor_n),             // MOR signal, active low (Memory Error)
      .PANN(sx_pan_n),             // PAN signal, active low (Panel Interrupt)
      .PARERRN(sx_parerr_n),       // Parity Error, active low
      .POWFAILN(sx_powfail_n),     // Power Failure, active low
      .Z(s_z),                     // Error flag from ALU

      // Output signals from the CGA_INTR module
      .EPICMASKN(s_epicmask_n),    // EPIC Mask, active low
      .HIGSN(s_higs_n),            // High Speed signal, active low
      .INTRQN(sx_intrq_n_out),     // Interrupt Request, active low
      .IRQ(s_irq),                 // Interrupt Request
      .LOGSN(s_logs_n),            // Logical Segment Number, active low
      .PD(s_pd),                   // Power Down signal
      .PICMASK_15_0(s_picmask_15_0[15:0]), // PIC Mask, 16-bit
      .PICS_2_0(s_pics_2_0[2:0]), // PIC Select, 3-bit
      .PICV_2_0(s_picv_2_0[2:0])  // PIC Vector, 3-bit
  );

  // The CGA_MAC module is a part of the DELILAH CPU's gate array,
  // which is responsible for arithmetic computations and control logic.
  // It takes various control signals, data paths,
  // and clock inputs to perform its operations and
  // outputs the results along with status signals.

  // Input signals to the CGA_MAC module
  CGA_MAC MAC
  (
      // System Input signals
    .sysclk(sysclk),                          // System clock in FPGA
    .sys_rst_n(sys_rst_n),                    // System reset in FPGA

    // Input signals to the CGA_MAC module
    .CSMREQ       (s_csmreq),                // Chip Select for MAC, active high
    .DOUBLE       (sx_double_out),           // Double Precision Control
    .ILCSN        (sx_ilcs_n),               // Instruction Load Control Signal, active low
    .MCLK         (sx_mclk),                 // Master Clock
    .PONI         (sx_poni_out),             // Memory Protection ON, PONI=1
    .PTM          (s_ptm),                   // Processor Test Mode
    .WR3          (s_wr3),                   // Write Control Signal 3
    .WR7          (s_wr7),                   // Write Control Signal 7
    .CMIS_1_0     (s_csmis_1_0[1:0]),       // Microcode: Misc (2 bits)
    .CSCOMM_4_0   (s_cscomm_4_0[4:0]),      // Microcode: Commands (5 bits)
    .RB_15_0      (s_rb_15_0[15:0]),        // Microcode Register B
    .CD_15_0      (s_cd_15_0[15:0]),        // Code/Data Selector
    .FIDBO_15_0   (s_mac_IDB_15_0_IN[15:0]),// FIDBO output from previous stage
    .PR_15_0      (s_pr_15_0[15:0]),        // ALU P Register
    .BR_15_0      (s_br_15_0[15:0]),        // ALU B Register
    .XR_15_0      (s_xr_15_0[15:0]),        // X Register

    // Output signals from the CGA_MAC module
    .ECCR         (sx_eccr_out),             // Error Correction Code Register
    .LA_23_10     (sx_la_23_10_out[13:0]),   // Latch Address bits 23 to 10
    .LSHADOW      (sx_lshadow_out),          // Latch SHADOW signal
    .MCA_9_0      (sx_mca_9_0_out[9:0]),     // Microcode Address bits 9 to 0
    .NLCA_15_0    (s_nlca_15_0[15:0]),       // Next Latch Address bits 15 to 0
    .PCR_15_0     (s_pcr_15_0[15:0]),        // Program Counter Register bits 15 to 0
    .VEX          (s_vex)                    // Violation Exception
  );


  // The CGA_MIC module is responsible for the microinstruction control within the DELILAH CPU's gate array.
  // It interprets various control and status signals to generate microinstructions that dictate the CPU's behavior.
  CGA_MIC MIC (
      // Input signals
      .sysclk(sysclk),                          // System clock in FPGA
      .sys_rst_n(sys_rst_n),                    // System reset in FPGA

      
      .ALUCLK(sx_aluclk),                       // ALU Clock
      .CD_15_0(s_cd_15_0[15:0]),               // Code/Data Selector
      .CFETCH(s_cfetch),                        // Control Fetch
      .CLFFN(s_clff_n),                         // Clear Flip-Flop, active low      
      .CRY(s_cry),                              // Carry
      .CSALUI8(s_csalui8),                      // Control Store ALU Immediate Bit 8
      .CSBIT20(sx_csbit20),                     // Control Store Bit 20
      .CSBIT_15_0(s_csbit_15_0[15:0]),         // Control Store Bits [15:0]
      .CSCOND(sx_csscond),                      // Control Store Conditional
      .CSECOND(sx_csecond),                     // Control Store Second
      .CSLOOP(sx_csloop),                       // Control Store Loop
      .CSMIS0(s_csmi0),                         // Control Store Misc Bit 0
      .CSRASEL_1_0(s_csrasel_1_0[1:0]),        // Control Store RA Select
      .CSRBSEL_1_0(s_csrbsel_1_0[1:0]),        // Control Store RB Select
      .CSRB_3_0(s_csrb_3_0[3:0]),              // Control Store RB Bits [3:0]
      .CSTS_6_3(s_csts_6_3[3:0]),              // Control Store TS Bits [6:3]
      .CSVECT(sx_csvect),                       // Control Store Vector
      .CSXRF3(sx_csxrf3),                       // Control Store XRF Bit 3
      .EWCAN(sx_ewca_n),                        // Early Write Cancel, active low
      .F11(s_f11),                              // Flag Bit 11
      .F15(s_f15),                              // Flag Bit 15
      .ILCSN(sx_ilcs_n),                        // Internal Load Control Store, active low
      .IRQ(s_irq),                              // Interrupt Request
      .LDIRV(s_ldirv),                          // Load direction vector
      .LDLCN(s_ldlc_n),                         // Load LCN
      .LWCAN(s_lwca_n),                         // Latch WCA
      .MAPN(sx_map_n),                          // Memory Address Present signal
      .MCLK(sx_mclk),                           // Master Clock
      .MI(s_mi),                                // STS M bit
      .MRN(sx_mrn),                             // Memory Read, active low
      .OVF(s_ovf),                              // Overflow
      .PIL_3_0(sx_pil_3_0_out[3:0]),            // Processor Interrupt Level Bits [3:0]
      .RESTR(s_restr),                          //
      .SPARE(sx_spare),                         // Spare
      .STP(sx_stp),                             // Stop
      .TRAPN(sx_trap_n_out),                    // Trap, active low
      .TVEC_3_0(s_tvec_3_0[3:0]),               // Trap Vector Bits [3:0]
      .ZF(s_zf),                                // Zero Flag

      // Output
      .ACONDN(sx_acond_n_out),                  // Abort Condition, active low
      .COND(s_cond),                            // Condition
      .DEEP(s_deep),                            // Deep
      .DZD(s_dzd),                              // Divide by Zero Detected
      .LAA_3_0(sx_laa_3_0_out[3:0]),            // Latched Address A Bits [3:0]
      .LBA_3_0(sx_lba_3_0_out[3:0]),            // Latched Address B Bits [3:0]
      .LCZN(s_lcz_n),                           // Loop Counter not Zero
      .MA_12_0(sx_ma_12_0_out[12:0]),           // Memory Address Bits [12:0] (for Control Store)
      .OOD(s_ood),                              //
      .PN(s_pn),                                //
      .RF_1_0(sx_rf_1_0_out[1:0]),              //
      .SC_6_3(s_sc_6_3[3:0]),                   // Special Condition Bits [6:3]
      .TN(s_t_n),                               // Test Negative
      .UPN(s_up_n),                             // Update Negative, active low
      .WCSN(sx_wcs_n_out)                       // Write Control Store, active low
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

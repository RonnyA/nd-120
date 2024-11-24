/**************************************************************************
** ND120 CGA (CPU Gate Array / DELILAH)                                  **
** /CGA/MIC                                                              **
** MIC                                                                   **
**                                                                       **
** Page 9-13                                                             **
** SHEET 1 of 4                                                          **
**                                                                       **
** Last reviewed: 10-NOV-2024                                            **
** Ronny Hansen                                                          **
***************************************************************************/

module CGA_MIC (
    input sysclk,    // System clock in FPGA
    input sys_rst_n, // System reset in FPGA

    input        ALUCLK,
    input [15:0] CD_15_0,
    input        CFETCH,
    input        CLFFN,
    input        CRY,
    input        CSALUI8,
    input        CSBIT20,
    input [15:0] CSBIT_15_0,
    input        CSCOND,
    input        CSECOND,
    input        CSLOOP,
    input        CSMIS0,
    input [ 1:0] CSRASEL_1_0,
    input [ 1:0] CSRBSEL_1_0,
    input [ 3:0] CSRB_3_0,
    input [ 3:0] CSTS_6_3,
    input        CSVECT,
    input        CSXRF3,
    input        EWCAN,
    input        F11,
    input        F15,
    input        ILCSN,
    input        IRQ,
    input        LCZ,
    input        LDIRV,
    input        LDLCN,
    input        LWCAN,
    input        MAPN,
    input        MCLK,
    input        MI,
    input        MRN,
    input        OVF,
    input [ 3:0] PIL_3_0,
    input        RESTR,
    input        SPARE,
    input        STP,
    input        TRAPN,
    input [ 3:0] TVEC_3_0,
    input        ZF,

    output        ACONDN,
    output        COND,
    output        DEEP,
    output        DZD,
    output [ 3:0] LAA_3_0,
    output [ 3:0] LBA_3_0,
    output        LCZN,
    output [12:0] MA_12_0,
    output        OOD,
    output        PN,
    output [ 1:0] RF_1_0,
    output [ 3:0] SC_6_3,
    output        TN,
    output        UPN,
    output        WCSN
);

  /*******************************************************************************
   ** The wires are defined here                                                 **
   *******************************************************************************/
  wire [ 1:0] s_csrasel_1_0;
  wire [ 1:0] s_csrbsel_1_0;
  wire [ 1:0] s_cswan_1_0;
  wire [ 1:0] s_rf_1_0_out;
  wire [ 3:0] s_csbit_15_12;
  wire [ 3:0] s_csbit_3_0;
  wire [ 3:0] s_csrb_3_0;
  wire [ 3:0] s_csts_6_3;
  wire [ 3:0] s_fs_6_3;
  wire [ 3:0] s_jmp_3_0;
  wire [ 3:0] s_laa_3_0_out;
  wire [ 3:0] s_lba_3_0_out;
  wire [ 3:0] s_lc_3_0;
  wire [ 3:0] s_lcc_3_0;
  wire [ 3:0] s_pil_3_0;
  wire [ 3:0] s_sc_6_3_out;
  wire [ 3:0] s_tsel_3_0;
  wire [ 3:0] s_tvec_3_0;
  wire [ 6:0] s_ir_6_0;
  wire [12:0] s_iw_12_0;
  wire [12:0] s_ma_12_0_out;
  wire [12:0] s_next_12_0;
  wire [12:0] s_ret_12_0;
  wire [12:0] s_w_12_0;
  wire [12:0] s_wca_12_0;
  wire [15:0] s_cd_15_0;
  wire [15:0] s_csbit_15_0;

  wire        s_acond_n_out;
  wire        s_aluclk;
  wire        s_carry_in;
  wire        s_cfetch;
  wire        s_clff_n;
  wire        s_clff;
  wire        s_cond_n;
  wire        s_cond;
  wire        s_cry;
  wire        s_csalui8;
  wire        s_csbit_0;
  wire        s_csbit_1;
  wire        s_csbit_10;
  wire        s_csbit_11;
  wire        s_csbit_12;
  wire        s_csbit_13;
  wire        s_csbit_14;
  wire        s_csbit_15;
  wire        s_csbit_2;
  wire        s_csbit_3;
  wire        s_csbit_4;
  wire        s_csbit_5;
  wire        s_csbit_6;
  wire        s_csbit_7;
  wire        s_csbit_8;
  wire        s_csbit_9;
  wire        s_csbit20;
  wire        s_cscond;
  wire        s_csecond_n;
  wire        s_csecond;
  wire        s_csloop_n;
  wire        s_csloop;
  wire        s_csmis0;
  wire        s_csrasel1_n;
  wire        s_csvect_n;
  wire        s_csvect;
  wire        s_csxrf3_n;
  wire        s_csxrf3;
  wire        s_deep_out;
  wire        s_dzd_out;
  wire        s_dzd_signal;
  wire        s_dzdff_q;
  wire        s_ewca_n;
  wire        s_f11;
  wire        s_f15;
  wire        s_fs6_efalse;
  wire        s_csts5_etrue;
  wire        s_fs5_efalse;
  wire        s_csts4_etrue;
  wire        s_fs4_efalse;
  wire        s_csts3_etrue;
  wire        s_fs3_efalse;
  wire        s_gates18_out;
  wire        s_gates19_out;
  wire        s_gates20_out;
  wire        s_csfs_4;
  wire        s_csfs_3;
  wire        s_gates25_out;
  wire        s_gates28_out;
  wire        s_gates29_out;
  wire        s_gates3_out;
  wire        s_gates4_out;
  wire        s_gates5_out;
  wire        s_efalse;
  wire        s_etrue;
  wire        s_csts6_etrue;
  wire        s_gnd;
  wire        s_ialui8_clocked_qn;
  wire        s_icd_4;
  wire        s_icd_5;
  wire        s_irq;
  wire        s_iwan0or1;
  wire        s_laa_0_n_out;
  wire        s_laa_1_n_out;
  wire        s_laa_2_n_out;
  wire        s_laa_3_n_out;
  wire        s_laa0_signal;
  wire        s_laa1_signal;
  wire        s_laa2_signal;
  wire        s_laa3_d2_input;
  wire        s_laa3_signal;
  wire        s_lba_0_n_out;
  wire        s_lba_1_n_out;
  wire        s_lba_2_n_out;
  wire        s_lba_3_n_out;
  wire        s_lba0_signal;
  wire        s_lba1_signal;
  wire        s_lba2_signal;
  wire        s_lba3_signal;
  wire        s_lc_hi_con;
  wire        s_lcc_eq_lc;
  wire        s_lcs_n;
  wire        s_lcs;
  wire        s_lcsn_nand_ewcan;
  wire        s_lcz_n_out;
  wire        s_lcz_out;
  wire        s_lcz;
  wire        s_ldirv;
  wire        s_ldlc_n;
  wire        s_loop;
  wire        s_lwca_n;
  wire        s_map_n;
  wire        s_mclk_n;
  wire        s_sclk_n;
  wire        s_clk_sc34;  // Clock signal for flip-flop carrying SC3 and SC4 signal
  wire        s_mclk;
  wire        s_mi;
  wire        s_mrn;
  wire        s_ood_out;
  wire        s_ood_signal;
  wire        s_oodff_q;
  wire        s_ovf;
  wire        s_p_n_out;
  wire        s_power;
  wire        s_restr;
  wire        s_rf0_in_a;
  wire        s_rf1_in_a;
  wire        s_sc_3_out;
  wire        s_sc_4_out;
  wire        s_sc_5_n_out;
  wire        s_sc_6_n_out;
  wire        s_spare;
  wire        s_stp;
  wire        s_t_n_out;
  wire        s_trap_n;
  wire        s_up_n_out;
  wire        s_up_out;
  wire        s_wcs_n_out;
  wire        s_zf;
  wire        s_zfff_q_out;

  /*******************************************************************************
   ** The module functionality is described here                                 **
   *******************************************************************************/

  /*******************************************************************************
   ** Here all wiring is defined                                                 **
   *******************************************************************************/

  assign s_csbit_3_0[0]     = s_csbit_0;
  assign s_csbit_3_0[1]     = s_csbit_1;
  assign s_csbit_3_0[2]     = s_csbit_2;
  assign s_csbit_3_0[3]     = s_csbit_3;
  assign s_csbit_15_12[0]   = s_csbit_12;
  assign s_csbit_15_12[1]   = s_csbit_13;
  assign s_csbit_15_12[2]   = s_csbit_14;
  assign s_csbit_15_12[3]   = s_csbit_15;

  assign s_csbit_0          = s_csbit_15_0[0];
  assign s_csbit_1          = s_csbit_15_0[1];
  assign s_csbit_2          = s_csbit_15_0[2];
  assign s_csbit_3          = s_csbit_15_0[3];
  assign s_csbit_4          = s_csbit_15_0[4];
  assign s_csbit_5          = s_csbit_15_0[5];
  assign s_csbit_6          = s_csbit_15_0[6];
  assign s_csbit_7          = s_csbit_15_0[7];
  assign s_csbit_8          = s_csbit_15_0[8];
  assign s_csbit_9          = s_csbit_15_0[9];
  assign s_csbit_10         = s_csbit_15_0[10];
  assign s_csbit_11         = s_csbit_15_0[11];
  assign s_csbit_12         = s_csbit_15_0[12];
  assign s_csbit_13         = s_csbit_15_0[13];
  assign s_csbit_14         = s_csbit_15_0[14];
  assign s_csbit_15         = s_csbit_15_0[15];

  /*******************************************************************************
   ** Here all input connections are defined                                     **
   *******************************************************************************/
  assign s_aluclk           = ALUCLK;
  assign s_cd_15_0[15:0]    = CD_15_0;
  assign s_cfetch           = CFETCH;
  assign s_clff_n           = CLFFN;
  assign s_cry              = CRY;
  assign s_csalui8          = CSALUI8;
  assign s_csbit_15_0[15:0] = CSBIT_15_0;
  assign s_csbit20          = CSBIT20;
  assign s_cscond           = CSCOND;
  assign s_csecond          = CSECOND;
  assign s_csloop           = CSLOOP;
  assign s_csmis0           = CSMIS0;
  assign s_csrasel_1_0[1:0] = CSRASEL_1_0;
  assign s_csrb_3_0[3:0]    = CSRB_3_0;
  assign s_csrbsel_1_0[1:0] = CSRBSEL_1_0;
  assign s_csts_6_3[3:0]    = CSTS_6_3;
  assign s_csvect           = CSVECT;
  assign s_csxrf3           = CSXRF3;
  assign s_ewca_n           = EWCAN;
  assign s_f11              = F11;
  assign s_f15              = F15;
  assign s_irq              = IRQ;

  // In the schematic it goes through 2 inverting buffers, here we go direct. Not sure if its to get a small delay?
  assign s_lcs_n            = ILCSN;

  assign s_lcz              = LCZ;
  assign s_ldirv            = LDIRV;
  assign s_ldlc_n           = LDLCN;
  assign s_lwca_n           = LWCAN;
  assign s_map_n            = MAPN;
  assign s_mclk             = MCLK;
  assign s_mi               = MI;
  assign s_mrn              = MRN;
  assign s_ovf              = OVF;
  assign s_pil_3_0[3:0]     = PIL_3_0;
  assign s_restr            = RESTR;
  assign s_spare            = SPARE;
  assign s_stp              = STP;
  assign s_trap_n           = TRAPN;
  assign s_tvec_3_0[3:0]    = TVEC_3_0;
  assign s_zf               = ZF;

  /*******************************************************************************
   ** Here all output connections are defined                                    **
   *******************************************************************************/
  assign ACONDN             = s_acond_n_out;
  assign COND               = s_cond;
  assign DEEP               = s_deep_out;
  assign DZD                = s_dzd_out;
  assign LAA_3_0            = s_laa_3_0_out[3:0];
  assign LBA_3_0            = s_lba_3_0_out[3:0];
  assign LCZN               = s_lcz_n_out;
  assign MA_12_0            = s_ma_12_0_out[12:0];
  assign OOD                = s_ood_out;
  assign PN                 = s_p_n_out;
  assign RF_1_0             = s_rf_1_0_out[1:0];
  assign SC_6_3             = s_sc_6_3_out[3:0];
  assign TN                 = s_t_n_out;
  assign UPN                = s_up_n_out;
  assign WCSN               = s_wcs_n_out;

  /*******************************************************************************
   ** Here all in-lined components are defined                                   **
   *******************************************************************************/

  // Power
  assign s_power            = 1'b1;

  // Ground
  assign s_gnd              = 1'b0;

  // NOT Gate
  assign s_clff             = ~s_clff_n;
  assign s_csecond_n        = ~s_csecond;
  assign s_csloop_n         = ~s_csloop;
  assign s_csrasel1_n       = ~s_csrasel_1_0[1];
  assign s_csvect_n         = ~s_csvect;
  assign s_csxrf3_n         = ~s_csxrf3;
  assign s_lcs              = ~s_lcs_n;

  assign s_laa_3_0_out[0]   = ~s_laa_0_n_out;
  assign s_laa_3_0_out[1]   = ~s_laa_1_n_out;
  assign s_laa_3_0_out[2]   = ~s_laa_2_n_out;
  assign s_laa_3_0_out[3]   = ~s_laa_3_n_out;

  assign s_lba_3_0_out[0]   = ~s_lba_0_n_out;
  assign s_lba_3_0_out[1]   = ~s_lba_1_n_out;
  assign s_lba_3_0_out[2]   = ~s_lba_2_n_out;
  assign s_lba_3_0_out[3]   = ~s_lba_3_n_out;

  assign s_lcz_out          = ~s_lcz_n_out;
  assign s_mclk_n           = ~s_mclk;  // MASEL  clock (negated MCLK)
  assign s_sclk_n           = ~s_mclk;  // STACK CLOCK (nedgated MCLK)
  assign s_clk_sc34         = ~s_mclk;  // Will be nagated at the chip level

  assign s_sc_6_3_out[0]    = s_sc_3_out;
  assign s_sc_6_3_out[1]    = s_sc_4_out;
  assign s_sc_6_3_out[2]    = ~s_sc_5_n_out;
  assign s_sc_6_3_out[3]    = ~s_sc_6_n_out;
  assign s_up_n_out         = ~s_up_out;



  /*******************************************************************************
   ** Here all normal components are defined                                     **
   *******************************************************************************/
  OR_GATE #(
      .BubblesMask(2'b00)
  ) GATES_1 (
      .input1(s_cswan_1_0[1]),
      .input2(s_cswan_1_0[0]),
      .result(s_iwan0or1)
  );

  NAND_GATE_3_INPUTS #(
      .BubblesMask(3'b000)
  ) GATES_2 (
      .input1(s_iwan0or1),
      .input2(s_lcs),
      .input3(s_power),
      .result(s_carry_in)
  );

  NOR_GATE_3_INPUTS #(
      .BubblesMask(3'b000)
  ) GATES_3 (
      .input1(s_icd_4),
      .input2(s_icd_5),
      .input3(s_clff),
      .result(s_gates3_out)
  );

  OR_GATE #(
      .BubblesMask(2'b00)
  ) GATES_4 (
      .input1(s_lc_hi_con),
      .input2(s_up_out),
      .result(s_gates4_out)
  );

  NAND_GATE_3_INPUTS #(
      .BubblesMask(3'b000)
  ) GATES_5 (
      .input1(s_lcs_n),
      .input2(s_csloop_n),
      .input3(s_csecond_n),
      .result(s_gates5_out)
  );

  AND_GATE_4_INPUTS #(
      .BubblesMask(4'h0)
  ) GATES_6 (
      .input1(s_cond_n),
      .input2(s_csloop_n),
      .input3(s_lcs_n),
      .input4(s_csecond),
      .result(s_efalse)
  );

  NAND_GATE_3_INPUTS #(
      .BubblesMask(3'b000)
  ) GATES_7 (
      .input1(s_gates4_out),
      .input2(s_loop),
      .input3(s_power),
      .result(s_p_n_out)
  );

  NAND_GATE #(
      .BubblesMask(2'b00)
  ) GATES_8 (
      .input1(s_cond_n),
      .input2(s_gates5_out),
      .result(s_etrue)
  );

  AND_GATE #(
      .BubblesMask(2'b00)
  ) GATES_9 (
      .input1(s_etrue),
      .input2(s_csts_6_3[3]),
      .result(s_csts6_etrue)
  );

  AND_GATE #(
      .BubblesMask(2'b00)
  ) GATES_10 (
      .input1(s_efalse),
      .input2(s_fs_6_3[3]),
      .result(s_fs6_efalse)
  );

  AND_GATE #(
      .BubblesMask(2'b00)
  ) GATES_11 (
      .input1(s_etrue),
      .input2(s_csts_6_3[2]),
      .result(s_csts5_etrue)
  );

  AND_GATE #(
      .BubblesMask(2'b00)
  ) GATES_12 (
      .input1(s_efalse),
      .input2(s_fs_6_3[2]),
      .result(s_fs5_efalse)
  );

  AND_GATE #(
      .BubblesMask(2'b00)
  ) GATES_13 (
      .input1(s_etrue),
      .input2(s_csts_6_3[1]),
      .result(s_csts4_etrue)
  );

  AND_GATE #(
      .BubblesMask(2'b00)
  ) GATES_14 (
      .input1(s_efalse),
      .input2(s_fs_6_3[1]),
      .result(s_fs4_efalse)
  );

  AND_GATE #(
      .BubblesMask(2'b00)
  ) GATES_15 (
      .input1(s_etrue),
      .input2(s_csts_6_3[0]),
      .result(s_csts3_etrue)
  );

  AND_GATE #(
      .BubblesMask(2'b00)
  ) GATES_16 (
      .input1(s_efalse),
      .input2(s_fs_6_3[0]),
      .result(s_fs3_efalse)
  );

  NAND_GATE #(
      .BubblesMask(2'b00)
  ) GATES_17 (
      .input1(s_gates3_out),
      .input2(s_lcc_eq_lc),
      .result(s_lcz_n_out)
  );

  NAND_GATE_3_INPUTS #(
      .BubblesMask(3'b000)
  ) GATES_18 (
      .input1(s_lcs_n),
      .input2(s_cond_n),
      .input3(s_csloop),
      .result(s_gates18_out)
  );

  NOR_GATE #(
      .BubblesMask(2'b00)
  ) GATES_19 (
      .input1(s_csts6_etrue),
      .input2(s_fs6_efalse),
      .result(s_gates19_out)
  );

  NOR_GATE #(
      .BubblesMask(2'b00)
  ) GATES_20 (
      .input1(s_csts5_etrue),
      .input2(s_fs5_efalse),
      .result(s_gates20_out)
  );

  NOR_GATE #(
      .BubblesMask(2'b00)
  ) GATES_21 (
      .input1(s_csts4_etrue),
      .input2(s_fs4_efalse),
      .result(s_csfs_4)
  );

  NOR_GATE #(
      .BubblesMask(2'b00)
  ) GATES_22 (
      .input1(s_csts3_etrue),
      .input2(s_fs3_efalse),
      .result(s_csfs_3)
  );

  NOR_GATE #(
      .BubblesMask(2'b11)
  ) GATES_23 (
      .input1(s_lcs_n),
      .input2(s_gates19_out),
      .result(s_sc_6_n_out)
  );

  NOR_GATE #(
      .BubblesMask(2'b11)
  ) GATES_24 (
      .input1(s_gates18_out),
      .input2(s_gates20_out),
      .result(s_sc_5_n_out)
  );

  AND_GATE #(
      .BubblesMask(2'b00)
  ) GATES_25 (
      .input1(s_zfff_q_out),
      .input2(s_zf),
      .result(s_gates25_out)
  );

  NOR_GATE_3_INPUTS #(
      .BubblesMask(3'b000)
  ) GATES_26 (
      .input1(s_gates25_out),
      .input2(s_dzd_out),
      .input3(s_gnd),
      .result(s_dzd_signal)
  );

  NOR_GATE #(
      .BubblesMask(2'b00)
  ) GATES_27 (
      .input1(s_ood_out),
      .input2(s_mi),
      .result(s_ood_signal)
  );

  NAND_GATE #(
      .BubblesMask(2'b00)
  ) GATES_28 (
      .input1(s_csrasel_1_0[0]),
      .input2(s_csxrf3),
      .result(s_gates28_out)
  );

  NAND_GATE #(
      .BubblesMask(2'b00)
  ) GATES_29 (
      .input1(s_csxrf3),
      .input2(s_csrasel1_n),
      .result(s_gates29_out)
  );

  AND_GATE #(
      .BubblesMask(2'b00)
  ) GATES_30 (
      .input1(s_csxrf3_n),
      .input2(s_ir_6_0[6]),
      .result(s_laa3_d2_input)
  );

  NAND_GATE #(
      .BubblesMask(2'b00)
  ) GATES_31 (
      .input1(s_lcs_n),
      .input2(s_ewca_n),
      .result(s_lcsn_nand_ewcan)
  );

  D_FLIPFLOP #(
      .InvertClockEnable(0)
  ) MEMORY_32 (
      .clock(s_mclk),
      .d(s_cond_n),
      .preset(1'b0),
      .q(),
      .qBar(s_cond),
      .reset(1'b0),
      .tick(1'b1)
  );

  D_FLIPFLOP #(
      .InvertClockEnable(0)
  ) MEMORY_33 (
      .clock(s_mclk),
      .d(s_csloop),
      .preset(1'b0),
      .q(s_loop),
      .qBar(),
      .reset(1'b0),
      .tick(1'b1)
  );

  D_FLIPFLOP #(
      .InvertClockEnable(1)
  ) MEMORY_34 (
      .clock(s_clk_sc34),
      .d(s_csfs_3),
      .preset(1'b0),
      .q(),
      .qBar(s_sc_3_out),
      .reset(1'b0),
      .tick(1'b1)
  );

  D_FLIPFLOP #(
      .InvertClockEnable(0)
  ) MEMORY_35 (
      .clock(s_mclk),
      .d(s_zf),
      .preset(1'b0),
      .q(s_zfff_q_out),
      .qBar(),
      .reset(s_clff),
      .tick(1'b1)
  );

  D_FLIPFLOP #(
      .InvertClockEnable(0)
  ) MEMORY_36 (
      .clock(s_mclk),
      .d(s_csalui8),
      .preset(1'b0),
      .q(),
      .qBar(s_ialui8_clocked_qn),
      .reset(1'b0),
      .tick(1'b1)
  );

  D_FLIPFLOP #(
      .InvertClockEnable(1)
  ) MEMORY_37 (
      .clock(s_clk_sc34),
      .d(s_csfs_4),
      .preset(1'b0),
      .q(),
      .qBar(s_sc_4_out),
      .reset(1'b0),
      .tick(1'b1)
  );

  D_FLIPFLOP #(
      .InvertClockEnable(0)
  ) MEMORY_38 (
      .clock(s_mclk),
      .d(s_gates29_out),
      .preset(1'b0),
      .q(s_rf1_in_a),
      .qBar(),
      .reset(1'b0),
      .tick(1'b1)
  );

  D_FLIPFLOP #(
      .InvertClockEnable(0)
  ) MEMORY_39 (
      .clock(s_mclk),
      .d(s_gates28_out),
      .preset(1'b0),
      .q(s_rf0_in_a),
      .qBar(),
      .reset(1'b0),
      .tick(1'b1)
  );


  /*******************************************************************************
   ** Here all sub-circuits are defined                                          **
   *******************************************************************************/

  CGA_MIC_INCOUNT MIC_INCOUNT (
      .CD0(s_cd_15_0[0]),
      .CD1(s_cd_15_0[1]),
      .CSWAN0(s_cswan_1_0[0]),
      .CSWAN1(s_cswan_1_0[1]),
      .EC(s_lcs),
      .LWCAN(s_lwca_n),
      .MCLK(s_mclk),
      .MRN(s_mrn)
  );

  M169C LC_HI (
      .CP(s_mclk),

      .A(s_cd_15_0[4]),
      .B(s_cd_15_0[5]),
      .C(s_cd_15_0[5]),
      .D(s_cd_15_0[5]),

      .CON(s_lc_hi_con),

      .NL(s_ldlc_n),
      .PN(s_p_n_out),

      .QA(s_icd_4),
      .QB(s_icd_5),
      .QC(),
      .QD(s_up_out),

      .TN(s_t_n_out),
      .UP(s_up_out)
  );

  M169C LC_LO (
      .CP(s_mclk),

      .A(s_cd_15_0[0]),
      .B(s_cd_15_0[1]),
      .C(s_cd_15_0[2]),
      .D(s_cd_15_0[3]),

      .CON(s_t_n_out),

      .NL(s_ldlc_n),
      .PN(s_p_n_out),

      .QA(s_lc_3_0[0]),
      .QB(s_lc_3_0[1]),
      .QC(s_lc_3_0[2]),
      .QD(s_lc_3_0[3]),

      .TN(s_gnd),
      .UP(s_up_out)
  );

  MUX21L M_RF1 (
      .A (s_rf1_in_a),
      .B (s_cswan_1_0[1]),
      .S (s_lcsn_nand_ewcan),
      .ZN(s_rf_1_0_out[1])
  );

  MUX21L M_RF0 (
      .A (s_rf0_in_a),
      .B (s_cswan_1_0[0]),
      .S (s_lcsn_nand_ewcan),
      .ZN(s_rf_1_0_out[0])
  );

  MUX34P ILC_MUX (
      .A  (s_csmis0),
      .B  (s_csvect_n),
      .D00(s_ir_6_0[0]),
      .D01(s_ir_6_0[1]),
      .D02(s_ir_6_0[2]),
      .D03(s_ir_6_0[3]),
      .D10(s_laa_3_0_out[0]),
      .D11(s_laa_3_0_out[1]),
      .D12(s_laa_3_0_out[2]),
      .D13(s_laa_3_0_out[3]),
      .D20(s_csbit_3_0[0]),
      .D21(s_csbit_3_0[1]),
      .D22(s_csbit_3_0[2]),
      .D23(s_csbit_3_0[3]),
      .Z0 (s_jmp_3_0[0]),
      .Z1 (s_jmp_3_0[1]),
      .Z2 (s_jmp_3_0[2]),
      .Z3 (s_jmp_3_0[3])
  );

  L8 IRLATCH (
      .A  (s_cd_15_0[0]),
      .B  (s_cd_15_0[1]),
      .C  (s_cd_15_0[2]),
      .D  (s_cd_15_0[3]),
      .E  (s_cd_15_0[4]),
      .F  (s_cd_15_0[5]),
      .G  (s_cd_15_0[6]),
      .H  (1'b0),
      .L  (s_ldirv),
      .QA (s_ir_6_0[0]),
      .QAN(),
      .QB (s_ir_6_0[1]),
      .QBN(),
      .QC (s_ir_6_0[2]),
      .QCN(),
      .QD (s_ir_6_0[3]),
      .QDN(),
      .QE (s_ir_6_0[4]),
      .QEN(),
      .QF (s_ir_6_0[5]),
      .QFN(),
      .QG (s_ir_6_0[6]),
      .QGN(),
      .QH (),
      .QHN()
  );

  CGA_MIC_CONDREG CONDREG (
      .ACONDN(s_acond_n_out),
      .CSBIT_11_0(s_csbit_15_0[11:0]),
      .CSSCOND(s_cscond),
      .FS_6_3(s_fs_6_3[3:0]),
      .LCC_3_0(s_lcc_3_0[3:0]),
      .LCSN(s_lcs_n),
      .MCLK(s_mclk),
      .TSEL_3_0(s_tsel_3_0[3:0])
  );

  MUX41P M_LAA_2 (
      .A (s_csrasel_1_0[0]),
      .B (s_csrasel_1_0[1]),
      .D0(s_csbit_15_12[1]),
      .D1(s_pil_3_0[1]),
      .D2(s_ir_6_0[5]),
      .D3(s_lc_3_0[2]),
      .Z (s_laa2_signal)
  );

  CMP4 LC_CMP (
      .A0 (s_lcc_3_0[0]),
      .A1 (s_lcc_3_0[1]),
      .A2 (s_lcc_3_0[2]),
      .A3 (s_lcc_3_0[3]),
      .AEB(s_lcc_eq_lc),
      .AGB(),
      .ALB(),
      .B0 (s_lc_3_0[0]),
      .B1 (s_lc_3_0[1]),
      .B2 (s_lc_3_0[2]),
      .B3 (s_lc_3_0[3])
  );

  CGA_MIC_IINC MIC_IINC (
      .CIN(s_carry_in),
      .IW_12_0(s_iw_12_0[12:0]),
      .NEXT_12_0(s_next_12_0[12:0])
  );

  MUX41P M_LAA_1 (
      .A (s_csrasel_1_0[0]),
      .B (s_csrasel_1_0[1]),
      .D0(s_csbit_15_12[2]),
      .D1(s_pil_3_0[2]),
      .D2(s_ir_6_0[4]),
      .D3(s_lc_3_0[1]),
      .Z (s_laa1_signal)
  );

  CGA_MIC_STACK MIC_STACK (
      // Input
      .MCLK (s_mclk),
      .SCLKN(s_sclk_n), //Stack Clock (Negated MCLK)

      .SC3      (s_sc_6_3_out[0]),   // SC[4:3] values - 00:HOLD, 01:POP, 10:LOAD, 11:PUSH
      .SC4      (s_sc_6_3_out[1]),   //
      .NEXT_12_0(s_next_12_0[12:0]),

      // Output
      .DEEP(s_deep_out),
      .RET_12_0(s_ret_12_0[12:0])
  );

  MUX41P M_LAA_0 (
      .A (s_csrasel_1_0[0]),
      .B (s_csrasel_1_0[1]),
      .D0(s_csbit_15_12[3]),
      .D1(s_pil_3_0[3]),
      .D2(s_ir_6_0[3]),
      .D3(s_lc_3_0[0]),
      .Z (s_laa0_signal)
  );

  R41P LAA_REG (
      .CP(s_mclk),

      .A(s_laa0_signal),
      .B(s_laa1_signal),
      .C(s_laa2_signal),
      .D(s_laa3_signal),

      .QA (),
      .QAN(s_laa_0_n_out),
      .QB (),
      .QBN(s_laa_1_n_out),
      .QC (),
      .QCN(s_laa_2_n_out),
      .QD (),
      .QDN(s_laa_3_n_out)
  );

  CGA_MIC_MASEL MIC_MASEL (
      .sysclk(sysclk),  // System clock in FPGA
      .sys_rst_n(sys_rst_n),  // System reset in FPGA
      .CSBIT20(s_csbit20),
      .CSBIT_11_0(s_csbit_15_0[11:0]),
      .IW_12_0(s_iw_12_0[12:0]),
      .JMP_3_0(s_jmp_3_0[3:0]),
      .MCLK(s_mclk),
      .MCLKN(s_mclk_n),
      .MRN(s_mrn),
      .NEXT_12_0(s_next_12_0[12:0]),
      .RET_12_0(s_ret_12_0[12:0]),
      .SC5(s_sc_6_3_out[2]),
      .SC6(s_sc_6_3_out[3]),
      .W_12_0(s_w_12_0[12:0])
  );

  SCAN_WITH_SET_N OOD_FF (
      .CLK(s_mclk),
      .D  (s_ood_signal),
      .Q  (s_oodff_q),
      .QN (s_ood_out),
      .S_n(s_clff_n),
      .TE (s_ialui8_clocked_qn),
      .TI (s_oodff_q)
  );

  SCAN_WITH_SET_N DZD_FF (
      .CLK(s_mclk),
      .D  (s_dzd_signal),
      .Q  (s_dzdff_q),
      .QN (s_dzd_out),
      .S_n(s_clff_n),
      .TE (s_ialui8_clocked_qn),
      .TI (s_dzdff_q)
  );

  MUX41P M_LBA_3 (
      .A (s_csrbsel_1_0[0]),
      .B (s_csrbsel_1_0[1]),
      .D0(s_csrb_3_0[3]),
      .D1(s_gnd),
      .D2(s_gnd),
      .D3(s_lc_3_0[3]),
      .Z (s_lba3_signal)
  );

  MUX41P M_LBA_2 (
      .A (s_csrbsel_1_0[0]),
      .B (s_csrbsel_1_0[1]),
      .D0(s_csrb_3_0[2]),
      .D1(s_ir_6_0[2]),
      .D2(s_ir_6_0[5]),
      .D3(s_lc_3_0[2]),
      .Z (s_lba2_signal)
  );

  CGA_MIC_WCAREG MIC_WCAREG (
      .CD_15_0(s_cd_15_0[15:0]),
      .LCSN(s_lcs_n),
      .LWCAN(s_lwca_n),
      .MCLK(s_mclk),
      .WCA_12_0(s_wca_12_0[12:0]),
      .WCSN(s_wcs_n_out)
  );

  MUX41P M_LBA_1 (
      .A (s_csrbsel_1_0[0]),
      .B (s_csrbsel_1_0[1]),
      .D0(s_csrb_3_0[1]),
      .D1(s_ir_6_0[1]),
      .D2(s_ir_6_0[4]),
      .D3(s_lc_3_0[1]),
      .Z (s_lba1_signal)
  );

  CGA_MIC_IPOS MIC_IPOS (
      .CD_15_0(s_cd_15_0[15:0]),
      .EWCAN(s_ewca_n),
      .MAPN(s_map_n),
      .MA_12_0(s_ma_12_0_out[12:0]),
      .TRAPN(s_trap_n),
      .TVEC_3_0(s_tvec_3_0[3:0]),
      .WCA_12_0(s_wca_12_0[12:0]),
      .W_12_0(s_w_12_0[12:0])
  );

  MUX41P M_LBA_0 (
      .A (s_csrbsel_1_0[0]),
      .B (s_csrbsel_1_0[1]),
      .D0(s_csrb_3_0[0]),
      .D1(s_ir_6_0[0]),
      .D2(s_ir_6_0[3]),
      .D3(s_lc_3_0[0]),
      .Z (s_lba0_signal)
  );

  R41P LBA_REG (
      .CP(s_mclk),

      .A(s_lba0_signal),
      .B(s_lba1_signal),
      .C(s_lba2_signal),
      .D(s_lba3_signal),

      .QA (),
      .QAN(s_lba_0_n_out),
      .QB (),
      .QBN(s_lba_1_n_out),
      .QC (),
      .QCN(s_lba_2_n_out),
      .QD (),
      .QDN(s_lba_3_n_out)
  );

  CGA_MIC_CSEL CSEL (
      .ALUCLK(s_aluclk),
      .CFETCH(s_cfetch),
      .COND(s_cond),
      .CONDN(s_cond_n),
      .CRY(s_cry),
      .DZD(s_dzd_out),
      .F11(s_f11),
      .F15(s_f15),
      .IRQ(s_irq),
      .LCZ(s_lcz),
      .OOD(s_ood_out),
      .OVF(s_ovf),
      .RESTR(s_restr),
      .SPARE(s_spare),
      .STP(s_stp),
      .TSEL_3_0(s_tsel_3_0[3:0]),
      .ZF(s_zf)
  );

  MUX41P M_LAA_3 (
      .A (s_csrasel_1_0[0]),
      .B (s_csrasel_1_0[1]),
      .D0(s_csbit_15_12[0]),
      .D1(s_pil_3_0[0]),
      .D2(s_laa3_d2_input),
      .D3(s_lc_3_0[3]),
      .Z (s_laa3_signal)
  );

endmodule

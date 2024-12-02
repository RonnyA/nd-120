/**************************************************************************
** ND120 CPU, MM&M                                                       **
** CGA/WRF/RBLOCK                                                        **
** WRF: Register File Block                                              **
** (PDF page 60)                                                         **
**                                                                       **
** Last reviewed: 09-NOV-2024                                            **
** Ronny Hansen                                                          **
***************************************************************************/


module CGA_WRF_RBLOCK (
    input        ALUCLK,   //! To clock the operation

    input [15:0] EA_15_0,  //! Enable A (source) for read. 16 bits to select register.
    input [15:0] EB_15_0,  //! Enable B (dest) for read. 16 bits to select register.

    input [15:0] RB_15_0,  //! Register B DATA (Destination) for WRITE. 16 bits to select register(s)
    input [15:0] WR_15_0,  //! Register B DATA (select) for WRITE. 16 bits to select register(s)

    input [15:0] NLCA_15_0, //! Input to P register (B=Reg2 which is P)
    input        XFETCHN,   //! Input to P register

    output [15:0] A_15_0,   //! DATA iutput 16 bit A, from register selected by EA_15_0
    output [15:0] B_15_0,   //! DATA output 16 bit B, from register selected by EB_15_0

    output [15:0] PR_15_0,  //! Direct output from P register (register #2)
    output [15:0] BR_15_0,  //! Direct output from B register (register #3)
    output [15:0] XR_15_0   //! Direct output from B register (register #7)
);

  /*******************************************************************************
   ** The wires are defined here                                                 **
   *******************************************************************************/
  wire [15:0] s_a_15_0_out;
  wire [15:0] s_b_15_0_out;
  wire [15:0] s_br_15_0_out;
  wire [15:0] s_ea_15_0;
  wire [15:0] s_eb_15_0;
  wire [15:0] s_ncla_15_0;
  wire [15:0] s_pr_15_0_out;
  wire [15:0] s_rb_15_0;

  wire [15:0] s_reg0_z_15_0;
  wire [15:0] s_reg1_d_15_0;
  wire [15:0] s_reg2_p_15_0;
  wire [15:0] s_reg3_b_15_0;
  wire [15:0] s_reg4_l_15_0;
  wire [15:0] s_reg5_a_15_0;
  wire [15:0] s_reg6_t_15_0;
  wire [15:0] s_reg7_x_15_0;
  wire [15:0] s_reg8_sts_15_0;
  wire [15:0] s_reg9_r1_15_0;
  wire [15:0] s_reg10_r2_15_0;
  wire [15:0] s_reg11_r3_15_0;
  wire [15:0] s_reg12_r4_15_0;
  wire [15:0] s_reg13_r5_15_0;
  wire [15:0] s_reg14_r6_15_0;
  wire [15:0] s_reg15_r7_15_0;

  wire [15:0] s_sel0_in_15_0;
  wire [15:0] s_sel1_in_15_0;
  wire [15:0] s_sel2_in_15_0;
  wire [15:0] s_sel3_in_15_0;
  wire [15:0] s_sel4_in_15_0;
  wire [15:0] s_sel5_in_15_0;
  wire [15:0] s_sel6_in_15_0;
  wire [15:0] s_sel7_in_15_0;
  wire [15:0] s_sel8_in_15_0;
  wire [15:0] s_sel9_in_15_0;
  wire [15:0] s_sel10_in_15_0;
  wire [15:0] s_sel11_in_15_0;
  wire [15:0] s_sel12_in_15_0;
  wire [15:0] s_sel13_in_15_0;
  wire [15:0] s_sel14_in_15_0;
  wire [15:0] s_sel15_in_15_0;

  wire [15:0] s_wr_15_0;
  wire [15:0] s_xr_15_0_out;

  wire        s_aluclk_n;
  wire        s_aluclk;
  wire        s_reg0_z_0;
  wire        s_reg0_z_1;
  wire        s_reg0_z_10;
  wire        s_reg0_z_11;
  wire        s_reg0_z_12;
  wire        s_reg0_z_13;
  wire        s_reg0_z_14;
  wire        s_reg0_z_15;
  wire        s_reg0_z_2;
  wire        s_reg0_z_3;
  wire        s_reg0_z_4;
  wire        s_reg0_z_5;
  wire        s_reg0_z_6;
  wire        s_reg0_z_7;
  wire        s_reg0_z_8;
  wire        s_reg0_z_9;
  wire        s_reg1_d_0;
  wire        s_reg1_d_1;
  wire        s_reg1_d_10;
  wire        s_reg1_d_11;
  wire        s_reg1_d_12;
  wire        s_reg1_d_13;
  wire        s_reg1_d_14;
  wire        s_reg1_d_15;
  wire        s_reg1_d_2;
  wire        s_reg1_d_3;
  wire        s_reg1_d_4;
  wire        s_reg1_d_5;
  wire        s_reg1_d_6;
  wire        s_reg1_d_7;
  wire        s_reg1_d_8;
  wire        s_reg1_d_9;
  wire        s_reg10_r2_0;
  wire        s_reg10_r2_1;
  wire        s_reg10_r2_10;
  wire        s_reg10_r2_11;
  wire        s_reg10_r2_12;
  wire        s_reg10_r2_13;
  wire        s_reg10_r2_14;
  wire        s_reg10_r2_15;
  wire        s_reg10_r2_2;
  wire        s_reg10_r2_3;
  wire        s_reg10_r2_4;
  wire        s_reg10_r2_5;
  wire        s_reg10_r2_6;
  wire        s_reg10_r2_7;
  wire        s_reg10_r2_8;
  wire        s_reg10_r2_9;
  wire        s_reg11_r3_0;
  wire        s_reg11_r3_1;
  wire        s_reg11_r3_10;
  wire        s_reg11_r3_11;
  wire        s_reg11_r3_12;
  wire        s_reg11_r3_13;
  wire        s_reg11_r3_14;
  wire        s_reg11_r3_15;
  wire        s_reg11_r3_2;
  wire        s_reg11_r3_3;
  wire        s_reg11_r3_4;
  wire        s_reg11_r3_5;
  wire        s_reg11_r3_6;
  wire        s_reg11_r3_7;
  wire        s_reg11_r3_8;
  wire        s_reg11_r3_9;
  wire        s_reg12_r4_0;
  wire        s_reg12_r4_1;
  wire        s_reg12_r4_10;
  wire        s_reg12_r4_11;
  wire        s_reg12_r4_12;
  wire        s_reg12_r4_13;
  wire        s_reg12_r4_14;
  wire        s_reg12_r4_15;
  wire        s_reg12_r4_2;
  wire        s_reg12_r4_3;
  wire        s_reg12_r4_4;
  wire        s_reg12_r4_5;
  wire        s_reg12_r4_6;
  wire        s_reg12_r4_7;
  wire        s_reg12_r4_8;
  wire        s_reg12_r4_9;
  wire        s_reg13_r5_0;
  wire        s_reg13_r5_1;
  wire        s_reg13_r5_10;
  wire        s_reg13_r5_11;
  wire        s_reg13_r5_12;
  wire        s_reg13_r5_13;
  wire        s_reg13_r5_14;
  wire        s_reg13_r5_15;
  wire        s_reg13_r5_2;
  wire        s_reg13_r5_3;
  wire        s_reg13_r5_4;
  wire        s_reg13_r5_5;
  wire        s_reg13_r5_6;
  wire        s_reg13_r5_7;
  wire        s_reg13_r5_8;
  wire        s_reg13_r5_9;
  wire        s_reg14_r6_0;
  wire        s_reg14_r6_1;
  wire        s_reg14_r6_10;
  wire        s_reg14_r6_11;
  wire        s_reg14_r6_12;
  wire        s_reg14_r6_13;
  wire        s_reg14_r6_14;
  wire        s_reg14_r6_15;
  wire        s_reg14_r6_2;
  wire        s_reg14_r6_3;
  wire        s_reg14_r6_4;
  wire        s_reg14_r6_5;
  wire        s_reg14_r6_6;
  wire        s_reg14_r6_7;
  wire        s_reg14_r6_8;
  wire        s_reg14_r6_9;
  wire        s_reg15_r7_0;
  wire        s_reg15_r7_1;
  wire        s_reg15_r7_10;
  wire        s_reg15_r7_11;
  wire        s_reg15_r7_12;
  wire        s_reg15_r7_13;
  wire        s_reg15_r7_14;
  wire        s_reg15_r7_15;
  wire        s_reg15_r7_2;
  wire        s_reg15_r7_3;
  wire        s_reg15_r7_4;
  wire        s_reg15_r7_5;
  wire        s_reg15_r7_6;
  wire        s_reg15_r7_7;
  wire        s_reg15_r7_8;
  wire        s_reg15_r7_9;
  wire        s_reg2_p_0;
  wire        s_reg2_p_1;
  wire        s_reg2_p_10;
  wire        s_reg2_p_11;
  wire        s_reg2_p_12;
  wire        s_reg2_p_13;
  wire        s_reg2_p_14;
  wire        s_reg2_p_15;
  wire        s_reg2_p_2;
  wire        s_reg2_p_3;
  wire        s_reg2_p_4;
  wire        s_reg2_p_5;
  wire        s_reg2_p_6;
  wire        s_reg2_p_7;
  wire        s_reg2_p_8;
  wire        s_reg2_p_9;
  wire        s_reg3_b_0;
  wire        s_reg3_b_1;
  wire        s_reg3_b_10;
  wire        s_reg3_b_11;
  wire        s_reg3_b_12;
  wire        s_reg3_b_13;
  wire        s_reg3_b_14;
  wire        s_reg3_b_15;
  wire        s_reg3_b_2;
  wire        s_reg3_b_3;
  wire        s_reg3_b_4;
  wire        s_reg3_b_5;
  wire        s_reg3_b_6;
  wire        s_reg3_b_7;
  wire        s_reg3_b_8;
  wire        s_reg3_b_9;
  wire        s_reg4_l_0;
  wire        s_reg4_l_1;
  wire        s_reg4_l_10;
  wire        s_reg4_l_11;
  wire        s_reg4_l_12;
  wire        s_reg4_l_13;
  wire        s_reg4_l_14;
  wire        s_reg4_l_15;
  wire        s_reg4_l_2;
  wire        s_reg4_l_3;
  wire        s_reg4_l_4;
  wire        s_reg4_l_5;
  wire        s_reg4_l_6;
  wire        s_reg4_l_7;
  wire        s_reg4_l_8;
  wire        s_reg4_l_9;
  wire        s_reg5_a_0;
  wire        s_reg5_a_1;
  wire        s_reg5_a_10;
  wire        s_reg5_a_11;
  wire        s_reg5_a_12;
  wire        s_reg5_a_13;
  wire        s_reg5_a_14;
  wire        s_reg5_a_15;
  wire        s_reg5_a_2;
  wire        s_reg5_a_3;
  wire        s_reg5_a_4;
  wire        s_reg5_a_5;
  wire        s_reg5_a_6;
  wire        s_reg5_a_7;
  wire        s_reg5_a_8;
  wire        s_reg5_a_9;
  wire        s_reg6_t_0;
  wire        s_reg6_t_1;
  wire        s_reg6_t_10;
  wire        s_reg6_t_11;
  wire        s_reg6_t_12;
  wire        s_reg6_t_13;
  wire        s_reg6_t_14;
  wire        s_reg6_t_15;
  wire        s_reg6_t_2;
  wire        s_reg6_t_3;
  wire        s_reg6_t_4;
  wire        s_reg6_t_5;
  wire        s_reg6_t_6;
  wire        s_reg6_t_7;
  wire        s_reg6_t_8;
  wire        s_reg6_t_9;
  wire        s_reg7_x_0;
  wire        s_reg7_x_1;
  wire        s_reg7_x_10;
  wire        s_reg7_x_11;
  wire        s_reg7_x_12;
  wire        s_reg7_x_13;
  wire        s_reg7_x_14;
  wire        s_reg7_x_15;
  wire        s_reg7_x_2;
  wire        s_reg7_x_3;
  wire        s_reg7_x_4;
  wire        s_reg7_x_5;
  wire        s_reg7_x_6;
  wire        s_reg7_x_7;
  wire        s_reg7_x_8;
  wire        s_reg7_x_9;
  wire        s_reg8_sts_0;
  wire        s_reg8_sts_1;
  wire        s_reg8_sts_10;
  wire        s_reg8_sts_11;
  wire        s_reg8_sts_12;
  wire        s_reg8_sts_13;
  wire        s_reg8_sts_14;
  wire        s_reg8_sts_15;
  wire        s_reg8_sts_2;
  wire        s_reg8_sts_3;
  wire        s_reg8_sts_4;
  wire        s_reg8_sts_5;
  wire        s_reg8_sts_6;
  wire        s_reg8_sts_7;
  wire        s_reg8_sts_8;
  wire        s_reg8_sts_9;
  wire        s_reg9_r1_0;
  wire        s_reg9_r1_1;
  wire        s_reg9_r1_10;
  wire        s_reg9_r1_11;
  wire        s_reg9_r1_12;
  wire        s_reg9_r1_13;
  wire        s_reg9_r1_14;
  wire        s_reg9_r1_15;
  wire        s_reg9_r1_2;
  wire        s_reg9_r1_3;
  wire        s_reg9_r1_4;
  wire        s_reg9_r1_5;
  wire        s_reg9_r1_6;
  wire        s_reg9_r1_7;
  wire        s_reg9_r1_8;
  wire        s_reg9_r1_9;
  wire        s_xfetch_n;
  
  /*******************************************************************************
   ** Here all wiring is defined                                                 **
   *******************************************************************************/
  assign s_sel0_in_15_0[0]   = s_reg0_z_0;
  assign s_sel0_in_15_0[1]   = s_reg1_d_0;
  assign s_sel0_in_15_0[2]   = s_reg2_p_0;
  assign s_sel0_in_15_0[3]   = s_reg3_b_0;
  assign s_sel0_in_15_0[4]   = s_reg4_l_0;
  assign s_sel0_in_15_0[5]   = s_reg5_a_0;
  assign s_sel0_in_15_0[6]   = s_reg6_t_0;
  assign s_sel0_in_15_0[7]   = s_reg7_x_0;
  assign s_sel0_in_15_0[8]   = s_reg8_sts_0;
  assign s_sel0_in_15_0[9]   = s_reg9_r1_0;
  assign s_sel0_in_15_0[10]  = s_reg10_r2_0;
  assign s_sel0_in_15_0[11]  = s_reg11_r3_0;
  assign s_sel0_in_15_0[12]  = s_reg12_r4_0;
  assign s_sel0_in_15_0[13]  = s_reg13_r5_0;
  assign s_sel0_in_15_0[14]  = s_reg14_r6_0;
  assign s_sel0_in_15_0[15]  = s_reg15_r7_0;

  assign s_sel1_in_15_0[0]   = s_reg0_z_1;
  assign s_sel1_in_15_0[1]   = s_reg1_d_1;
  assign s_sel1_in_15_0[2]   = s_reg2_p_1;
  assign s_sel1_in_15_0[3]   = s_reg3_b_1;
  assign s_sel1_in_15_0[4]   = s_reg4_l_1;
  assign s_sel1_in_15_0[5]   = s_reg5_a_1;
  assign s_sel1_in_15_0[6]   = s_reg6_t_1;
  assign s_sel1_in_15_0[7]   = s_reg7_x_1;
  assign s_sel1_in_15_0[8]   = s_reg8_sts_1;
  assign s_sel1_in_15_0[9]   = s_reg9_r1_1;
  assign s_sel1_in_15_0[10]  = s_reg10_r2_1;
  assign s_sel1_in_15_0[11]  = s_reg11_r3_1;
  assign s_sel1_in_15_0[12]  = s_reg12_r4_1;
  assign s_sel1_in_15_0[13]  = s_reg13_r5_1;
  assign s_sel1_in_15_0[14]  = s_reg14_r6_1;
  assign s_sel1_in_15_0[15]  = s_reg15_r7_1;

  assign s_sel2_in_15_0[0]   = s_reg0_z_2;
  assign s_sel2_in_15_0[1]   = s_reg1_d_2;
  assign s_sel2_in_15_0[2]   = s_reg2_p_2;
  assign s_sel2_in_15_0[3]   = s_reg3_b_2;
  assign s_sel2_in_15_0[4]   = s_reg4_l_2;
  assign s_sel2_in_15_0[5]   = s_reg5_a_2;
  assign s_sel2_in_15_0[6]   = s_reg6_t_2;
  assign s_sel2_in_15_0[7]   = s_reg7_x_2;
  assign s_sel2_in_15_0[8]   = s_reg8_sts_2;
  assign s_sel2_in_15_0[9]   = s_reg9_r1_2;
  assign s_sel2_in_15_0[10]  = s_reg10_r2_2;
  assign s_sel2_in_15_0[11]  = s_reg11_r3_2;
  assign s_sel2_in_15_0[12]  = s_reg12_r4_2;
  assign s_sel2_in_15_0[13]  = s_reg13_r5_2;
  assign s_sel2_in_15_0[14]  = s_reg14_r6_2;
  assign s_sel2_in_15_0[15]  = s_reg15_r7_2;

  assign s_sel3_in_15_0[0]   = s_reg0_z_3;
  assign s_sel3_in_15_0[1]   = s_reg1_d_3;
  assign s_sel3_in_15_0[2]   = s_reg2_p_3;
  assign s_sel3_in_15_0[3]   = s_reg3_b_3;
  assign s_sel3_in_15_0[4]   = s_reg4_l_3;
  assign s_sel3_in_15_0[5]   = s_reg5_a_3;
  assign s_sel3_in_15_0[6]   = s_reg6_t_3;
  assign s_sel3_in_15_0[7]   = s_reg7_x_3;
  assign s_sel3_in_15_0[8]   = s_reg8_sts_3;
  assign s_sel3_in_15_0[9]   = s_reg9_r1_3;
  assign s_sel3_in_15_0[10]  = s_reg10_r2_3;
  assign s_sel3_in_15_0[11]  = s_reg11_r3_3;
  assign s_sel3_in_15_0[12]  = s_reg12_r4_3;
  assign s_sel3_in_15_0[13]  = s_reg13_r5_3;
  assign s_sel3_in_15_0[14]  = s_reg14_r6_3;
  assign s_sel3_in_15_0[15]  = s_reg15_r7_3;

  assign s_sel4_in_15_0[0]   = s_reg0_z_4;
  assign s_sel4_in_15_0[1]   = s_reg1_d_4;
  assign s_sel4_in_15_0[2]   = s_reg2_p_4;
  assign s_sel4_in_15_0[3]   = s_reg3_b_4;
  assign s_sel4_in_15_0[4]   = s_reg4_l_4;
  assign s_sel4_in_15_0[5]   = s_reg5_a_4;
  assign s_sel4_in_15_0[6]   = s_reg6_t_4;
  assign s_sel4_in_15_0[7]   = s_reg7_x_4;
  assign s_sel4_in_15_0[8]   = s_reg8_sts_4;
  assign s_sel4_in_15_0[9]   = s_reg9_r1_4;
  assign s_sel4_in_15_0[10]  = s_reg10_r2_4;
  assign s_sel4_in_15_0[11]  = s_reg11_r3_4;
  assign s_sel4_in_15_0[12]  = s_reg12_r4_4;
  assign s_sel4_in_15_0[13]  = s_reg13_r5_4;
  assign s_sel4_in_15_0[14]  = s_reg14_r6_4;
  assign s_sel4_in_15_0[15]  = s_reg15_r7_4;

  assign s_sel5_in_15_0[0]   = s_reg0_z_5;
  assign s_sel5_in_15_0[1]   = s_reg1_d_5;
  assign s_sel5_in_15_0[2]   = s_reg2_p_5;
  assign s_sel5_in_15_0[3]   = s_reg3_b_5;
  assign s_sel5_in_15_0[4]   = s_reg4_l_5;
  assign s_sel5_in_15_0[5]   = s_reg5_a_5;
  assign s_sel5_in_15_0[6]   = s_reg6_t_5;
  assign s_sel5_in_15_0[7]   = s_reg7_x_5;
  assign s_sel5_in_15_0[8]   = s_reg8_sts_5;
  assign s_sel5_in_15_0[9]   = s_reg9_r1_5;
  assign s_sel5_in_15_0[10]  = s_reg10_r2_5;
  assign s_sel5_in_15_0[11]  = s_reg11_r3_5;
  assign s_sel5_in_15_0[12]  = s_reg12_r4_5;
  assign s_sel5_in_15_0[13]  = s_reg13_r5_5;
  assign s_sel5_in_15_0[14]  = s_reg14_r6_5;
  assign s_sel5_in_15_0[15]  = s_reg15_r7_5;

  assign s_sel6_in_15_0[0]   = s_reg0_z_6;
  assign s_sel6_in_15_0[1]   = s_reg1_d_6;
  assign s_sel6_in_15_0[2]   = s_reg2_p_6;
  assign s_sel6_in_15_0[3]   = s_reg3_b_6;
  assign s_sel6_in_15_0[4]   = s_reg4_l_6;
  assign s_sel6_in_15_0[5]   = s_reg5_a_6;
  assign s_sel6_in_15_0[6]   = s_reg6_t_6;
  assign s_sel6_in_15_0[7]   = s_reg7_x_6;
  assign s_sel6_in_15_0[8]   = s_reg8_sts_6;
  assign s_sel6_in_15_0[9]   = s_reg9_r1_6;
  assign s_sel6_in_15_0[10]  = s_reg10_r2_6;
  assign s_sel6_in_15_0[11]  = s_reg11_r3_6;
  assign s_sel6_in_15_0[12]  = s_reg12_r4_6;
  assign s_sel6_in_15_0[13]  = s_reg13_r5_6;
  assign s_sel6_in_15_0[14]  = s_reg14_r6_6;
  assign s_sel6_in_15_0[15]  = s_reg15_r7_6;
  

  assign s_sel7_in_15_0[0]   = s_reg0_z_7;
  assign s_sel7_in_15_0[1]   = s_reg1_d_7;
  assign s_sel7_in_15_0[2]   = s_reg2_p_7;
  assign s_sel7_in_15_0[3]   = s_reg3_b_7;
  assign s_sel7_in_15_0[4]   = s_reg4_l_7;
  assign s_sel7_in_15_0[5]   = s_reg5_a_7;
  assign s_sel7_in_15_0[6]   = s_reg6_t_7;
  assign s_sel7_in_15_0[7]   = s_reg7_x_7;
  assign s_sel7_in_15_0[8]   = s_reg8_sts_7;
  assign s_sel7_in_15_0[9]   = s_reg9_r1_7;
  assign s_sel7_in_15_0[10]  = s_reg10_r2_7;
  assign s_sel7_in_15_0[11]  = s_reg11_r3_7;
  assign s_sel7_in_15_0[12]  = s_reg12_r4_7;
  assign s_sel7_in_15_0[13]  = s_reg13_r5_7;
  assign s_sel7_in_15_0[14]  = s_reg14_r6_7;
  assign s_sel7_in_15_0[15]  = s_reg15_r7_7;

  assign s_sel8_in_15_0[0]   = s_reg0_z_8;
  assign s_sel8_in_15_0[1]   = s_reg1_d_8;
  assign s_sel8_in_15_0[2]   = s_reg2_p_8;
  assign s_sel8_in_15_0[3]   = s_reg3_b_8;
  assign s_sel8_in_15_0[4]   = s_reg4_l_8;
  assign s_sel8_in_15_0[5]   = s_reg5_a_8;
  assign s_sel8_in_15_0[6]   = s_reg6_t_8;
  assign s_sel8_in_15_0[7]   = s_reg7_x_8;
  assign s_sel8_in_15_0[8]   = s_reg8_sts_8;
  assign s_sel8_in_15_0[9]   = s_reg9_r1_8;
  assign s_sel8_in_15_0[10]  = s_reg10_r2_8;
  assign s_sel8_in_15_0[11]  = s_reg11_r3_8;
  assign s_sel8_in_15_0[12]  = s_reg12_r4_8;
  assign s_sel8_in_15_0[13]  = s_reg13_r5_8;
  assign s_sel8_in_15_0[14]  = s_reg14_r6_8;
  assign s_sel8_in_15_0[15]  = s_reg15_r7_8;

  assign s_sel9_in_15_0[0]   = s_reg0_z_9;
  assign s_sel9_in_15_0[1]   = s_reg1_d_9;
  assign s_sel9_in_15_0[2]   = s_reg2_p_9;
  assign s_sel9_in_15_0[3]   = s_reg3_b_9;
  assign s_sel9_in_15_0[4]   = s_reg4_l_9;
  assign s_sel9_in_15_0[5]   = s_reg5_a_9;
  assign s_sel9_in_15_0[6]   = s_reg6_t_9;
  assign s_sel9_in_15_0[7]   = s_reg7_x_9;
  assign s_sel9_in_15_0[8]   = s_reg8_sts_9;
  assign s_sel9_in_15_0[9]   = s_reg9_r1_9;
  assign s_sel9_in_15_0[10]  = s_reg10_r2_9;
  assign s_sel9_in_15_0[11]  = s_reg11_r3_9;
  assign s_sel9_in_15_0[12]  = s_reg12_r4_9;
  assign s_sel9_in_15_0[13]  = s_reg13_r5_9;
  assign s_sel9_in_15_0[14]  = s_reg14_r6_9;
  assign s_sel9_in_15_0[15]  = s_reg15_r7_9;

  assign s_sel10_in_15_0[0]  = s_reg0_z_10;
  assign s_sel10_in_15_0[1]  = s_reg1_d_10;
  assign s_sel10_in_15_0[2]  = s_reg2_p_10;
  assign s_sel10_in_15_0[3]  = s_reg3_b_10;
  assign s_sel10_in_15_0[4]  = s_reg4_l_10;
  assign s_sel10_in_15_0[5]  = s_reg5_a_10;
  assign s_sel10_in_15_0[6]  = s_reg6_t_10;
  assign s_sel10_in_15_0[7]  = s_reg7_x_10;
  assign s_sel10_in_15_0[8]  = s_reg8_sts_10;
  assign s_sel10_in_15_0[9]  = s_reg9_r1_10;
  assign s_sel10_in_15_0[10] = s_reg10_r2_10;
  assign s_sel10_in_15_0[11] = s_reg11_r3_10;
  assign s_sel10_in_15_0[12] = s_reg12_r4_10;
  assign s_sel10_in_15_0[13] = s_reg13_r5_10;
  assign s_sel10_in_15_0[14] = s_reg14_r6_10;
  assign s_sel10_in_15_0[15] = s_reg15_r7_10;

  assign s_sel11_in_15_0[0]  = s_reg0_z_11;
  assign s_sel11_in_15_0[1]  = s_reg1_d_11;
  assign s_sel11_in_15_0[2]  = s_reg2_p_11;
  assign s_sel11_in_15_0[3]  = s_reg3_b_11;
  assign s_sel11_in_15_0[4]  = s_reg4_l_11;
  assign s_sel11_in_15_0[5]  = s_reg5_a_11;
  assign s_sel11_in_15_0[6]  = s_reg6_t_11;
  assign s_sel11_in_15_0[7]  = s_reg7_x_11;
  assign s_sel11_in_15_0[8]  = s_reg8_sts_11;
  assign s_sel11_in_15_0[9]  = s_reg9_r1_11;
  assign s_sel11_in_15_0[10] = s_reg10_r2_11;
  assign s_sel11_in_15_0[11] = s_reg11_r3_11;
  assign s_sel11_in_15_0[12] = s_reg12_r4_11;
  assign s_sel11_in_15_0[13] = s_reg13_r5_11;
  assign s_sel11_in_15_0[14] = s_reg14_r6_11;
  assign s_sel11_in_15_0[15] = s_reg15_r7_11;

  assign s_sel12_in_15_0[0]  = s_reg0_z_12;
  assign s_sel12_in_15_0[1]  = s_reg1_d_12;
  assign s_sel12_in_15_0[2]  = s_reg2_p_12;
  assign s_sel12_in_15_0[3]  = s_reg3_b_12;
  assign s_sel12_in_15_0[4]  = s_reg4_l_12;
  assign s_sel12_in_15_0[5]  = s_reg5_a_12;
  assign s_sel12_in_15_0[6]  = s_reg6_t_12;
  assign s_sel12_in_15_0[7]  = s_reg7_x_12;
  assign s_sel12_in_15_0[8]  = s_reg8_sts_12;
  assign s_sel12_in_15_0[9]  = s_reg9_r1_12;
  assign s_sel12_in_15_0[10] = s_reg10_r2_12;
  assign s_sel12_in_15_0[11] = s_reg11_r3_12;
  assign s_sel12_in_15_0[12] = s_reg12_r4_12;
  assign s_sel12_in_15_0[13] = s_reg13_r5_12;
  assign s_sel12_in_15_0[14] = s_reg14_r6_12;
  assign s_sel12_in_15_0[15] = s_reg15_r7_12;

  assign s_sel13_in_15_0[0]  = s_reg0_z_13;
  assign s_sel13_in_15_0[1]  = s_reg1_d_13;
  assign s_sel13_in_15_0[2]  = s_reg2_p_13;
  assign s_sel13_in_15_0[3]  = s_reg3_b_13;
  assign s_sel13_in_15_0[4]  = s_reg4_l_13;
  assign s_sel13_in_15_0[5]  = s_reg5_a_13;
  assign s_sel13_in_15_0[6]  = s_reg6_t_13;
  assign s_sel13_in_15_0[7]  = s_reg7_x_13;
  assign s_sel13_in_15_0[8]  = s_reg8_sts_13;
  assign s_sel13_in_15_0[9]  = s_reg9_r1_13;
  assign s_sel13_in_15_0[10] = s_reg10_r2_13;
  assign s_sel13_in_15_0[11] = s_reg11_r3_13;
  assign s_sel13_in_15_0[12] = s_reg12_r4_13;
  assign s_sel13_in_15_0[13] = s_reg13_r5_13;
  assign s_sel13_in_15_0[14] = s_reg14_r6_13;
  assign s_sel13_in_15_0[15] = s_reg15_r7_13;

  assign s_sel14_in_15_0[0]  = s_reg0_z_14;
  assign s_sel14_in_15_0[1]  = s_reg1_d_14;
  assign s_sel14_in_15_0[2]  = s_reg2_p_14;
  assign s_sel14_in_15_0[3]  = s_reg3_b_14;
  assign s_sel14_in_15_0[4]  = s_reg4_l_14;
  assign s_sel14_in_15_0[5]  = s_reg5_a_14;
  assign s_sel14_in_15_0[6]  = s_reg6_t_14;
  assign s_sel14_in_15_0[7]  = s_reg7_x_14;
  assign s_sel14_in_15_0[8]  = s_reg8_sts_14;
  assign s_sel14_in_15_0[9]  = s_reg9_r1_14;
  assign s_sel14_in_15_0[10] = s_reg10_r2_14;
  assign s_sel14_in_15_0[11] = s_reg11_r3_14;
  assign s_sel14_in_15_0[12] = s_reg12_r4_14;
  assign s_sel14_in_15_0[13] = s_reg13_r5_14;
  assign s_sel14_in_15_0[14] = s_reg14_r6_14;
  assign s_sel14_in_15_0[15] = s_reg15_r7_14;

  assign s_sel15_in_15_0[0]  = s_reg0_z_15;
  assign s_sel15_in_15_0[1]  = s_reg1_d_15;
  assign s_sel15_in_15_0[2]  = s_reg2_p_15;
  assign s_sel15_in_15_0[3]  = s_reg3_b_15;
  assign s_sel15_in_15_0[4]  = s_reg4_l_15;
  assign s_sel15_in_15_0[5]  = s_reg5_a_15;
  assign s_sel15_in_15_0[6]  = s_reg6_t_15;
  assign s_sel15_in_15_0[7]  = s_reg7_x_15;
  assign s_sel15_in_15_0[8]  = s_reg8_sts_15;
  assign s_sel15_in_15_0[9]  = s_reg9_r1_15;
  assign s_sel15_in_15_0[10] = s_reg10_r2_15;
  assign s_sel15_in_15_0[11] = s_reg11_r3_15;
  assign s_sel15_in_15_0[12] = s_reg12_r4_15;
  assign s_sel15_in_15_0[13] = s_reg13_r5_15;
  assign s_sel15_in_15_0[14] = s_reg14_r6_15;
  assign s_sel15_in_15_0[15] = s_reg15_r7_15;

/* Map to wires.. TODO: connect sel_ inputs direct instead*/

  assign s_reg0_z_0          = s_reg0_z_15_0[0];
  assign s_reg0_z_1          = s_reg0_z_15_0[1];
  assign s_reg0_z_2          = s_reg0_z_15_0[2];
  assign s_reg0_z_3          = s_reg0_z_15_0[3];
  assign s_reg0_z_4          = s_reg0_z_15_0[4];
  assign s_reg0_z_5          = s_reg0_z_15_0[5];
  assign s_reg0_z_6          = s_reg0_z_15_0[6];
  assign s_reg0_z_7          = s_reg0_z_15_0[7];
  assign s_reg0_z_8          = s_reg0_z_15_0[8];
  assign s_reg0_z_9          = s_reg0_z_15_0[9];
  assign s_reg0_z_10         = s_reg0_z_15_0[10];
  assign s_reg0_z_11         = s_reg0_z_15_0[11];
  assign s_reg0_z_12         = s_reg0_z_15_0[12];
  assign s_reg0_z_13         = s_reg0_z_15_0[13];
  assign s_reg0_z_14         = s_reg0_z_15_0[14];
  assign s_reg0_z_15         = s_reg0_z_15_0[15];

  assign s_reg1_d_0          = s_reg1_d_15_0[0];
  assign s_reg1_d_1          = s_reg1_d_15_0[1];
  assign s_reg1_d_2          = s_reg1_d_15_0[2];
  assign s_reg1_d_3          = s_reg1_d_15_0[3];
  assign s_reg1_d_4          = s_reg1_d_15_0[4];
  assign s_reg1_d_5          = s_reg1_d_15_0[5];
  assign s_reg1_d_6          = s_reg1_d_15_0[6];
  assign s_reg1_d_7          = s_reg1_d_15_0[7];
  assign s_reg1_d_8          = s_reg1_d_15_0[8];
  assign s_reg1_d_9          = s_reg1_d_15_0[9];
  assign s_reg1_d_10         = s_reg1_d_15_0[10];
  assign s_reg1_d_11         = s_reg1_d_15_0[11];
  assign s_reg1_d_12         = s_reg1_d_15_0[12];
  assign s_reg1_d_13         = s_reg1_d_15_0[13];
  assign s_reg1_d_14         = s_reg1_d_15_0[14];
  assign s_reg1_d_15         = s_reg1_d_15_0[15];

  assign s_reg2_p_0          = s_reg2_p_15_0[0];
  assign s_reg2_p_1          = s_reg2_p_15_0[1];
  assign s_reg2_p_2          = s_reg2_p_15_0[2];
  assign s_reg2_p_3          = s_reg2_p_15_0[3];
  assign s_reg2_p_4          = s_reg2_p_15_0[4];
  assign s_reg2_p_5          = s_reg2_p_15_0[5];
  assign s_reg2_p_6          = s_reg2_p_15_0[6];
  assign s_reg2_p_7          = s_reg2_p_15_0[7];
  assign s_reg2_p_8          = s_reg2_p_15_0[8];
  assign s_reg2_p_9          = s_reg2_p_15_0[9];
  assign s_reg2_p_10         = s_reg2_p_15_0[10];
  assign s_reg2_p_11         = s_reg2_p_15_0[11];
  assign s_reg2_p_12         = s_reg2_p_15_0[12];
  assign s_reg2_p_13         = s_reg2_p_15_0[13];
  assign s_reg2_p_14         = s_reg2_p_15_0[14];
  assign s_reg2_p_15         = s_reg2_p_15_0[15];

  assign s_reg3_b_0          = s_reg3_b_15_0[0];
  assign s_reg3_b_1          = s_reg3_b_15_0[1];
  assign s_reg3_b_2          = s_reg3_b_15_0[2];
  assign s_reg3_b_3          = s_reg3_b_15_0[3];
  assign s_reg3_b_4          = s_reg3_b_15_0[4];
  assign s_reg3_b_5          = s_reg3_b_15_0[5];
  assign s_reg3_b_6          = s_reg3_b_15_0[6];
  assign s_reg3_b_7          = s_reg3_b_15_0[7];
  assign s_reg3_b_8          = s_reg3_b_15_0[8];
  assign s_reg3_b_9          = s_reg3_b_15_0[9];
  assign s_reg3_b_10         = s_reg3_b_15_0[10];
  assign s_reg3_b_11         = s_reg3_b_15_0[11];
  assign s_reg3_b_12         = s_reg3_b_15_0[12];
  assign s_reg3_b_13         = s_reg3_b_15_0[13];
  assign s_reg3_b_14         = s_reg3_b_15_0[14];
  assign s_reg3_b_15         = s_reg3_b_15_0[15];

  assign s_reg4_l_0          = s_reg4_l_15_0[0];
  assign s_reg4_l_1          = s_reg4_l_15_0[1];
  assign s_reg4_l_2          = s_reg4_l_15_0[2];
  assign s_reg4_l_3          = s_reg4_l_15_0[3];
  assign s_reg4_l_4          = s_reg4_l_15_0[4];
  assign s_reg4_l_5          = s_reg4_l_15_0[5];
  assign s_reg4_l_6          = s_reg4_l_15_0[6];
  assign s_reg4_l_7          = s_reg4_l_15_0[7];
  assign s_reg4_l_8          = s_reg4_l_15_0[8];
  assign s_reg4_l_9          = s_reg4_l_15_0[9];
  assign s_reg5_a_0          = s_reg5_a_15_0[0];
  assign s_reg4_l_10         = s_reg4_l_15_0[10];
  assign s_reg4_l_11         = s_reg4_l_15_0[11];
  assign s_reg4_l_12         = s_reg4_l_15_0[12];
  assign s_reg4_l_13         = s_reg4_l_15_0[13];
  assign s_reg4_l_14         = s_reg4_l_15_0[14];
  assign s_reg4_l_15         = s_reg4_l_15_0[15];

  assign s_reg5_a_1          = s_reg5_a_15_0[1];
  assign s_reg5_a_2          = s_reg5_a_15_0[2];
  assign s_reg5_a_3          = s_reg5_a_15_0[3];
  assign s_reg5_a_4          = s_reg5_a_15_0[4];
  assign s_reg5_a_5          = s_reg5_a_15_0[5];
  assign s_reg5_a_6          = s_reg5_a_15_0[6];
  assign s_reg5_a_7          = s_reg5_a_15_0[7];
  assign s_reg5_a_8          = s_reg5_a_15_0[8];
  assign s_reg5_a_9          = s_reg5_a_15_0[9];
  assign s_reg5_a_10         = s_reg5_a_15_0[10];
  assign s_reg5_a_11         = s_reg5_a_15_0[11];
  assign s_reg5_a_12         = s_reg5_a_15_0[12];
  assign s_reg5_a_13         = s_reg5_a_15_0[13];
  assign s_reg5_a_14         = s_reg5_a_15_0[14];
  assign s_reg5_a_15         = s_reg5_a_15_0[15];

  assign s_reg6_t_0          = s_reg6_t_15_0[0];
  assign s_reg6_t_1          = s_reg6_t_15_0[1];
  assign s_reg6_t_2          = s_reg6_t_15_0[2];
  assign s_reg6_t_3          = s_reg6_t_15_0[3];
  assign s_reg6_t_4          = s_reg6_t_15_0[4];
  assign s_reg6_t_5          = s_reg6_t_15_0[5];
  assign s_reg6_t_6          = s_reg6_t_15_0[6];
  assign s_reg6_t_7          = s_reg6_t_15_0[7];
  assign s_reg6_t_8          = s_reg6_t_15_0[8];
  assign s_reg6_t_9          = s_reg6_t_15_0[9];
  assign s_reg6_t_10         = s_reg6_t_15_0[10];
  assign s_reg6_t_11         = s_reg6_t_15_0[11];
  assign s_reg6_t_12         = s_reg6_t_15_0[12];
  assign s_reg6_t_13         = s_reg6_t_15_0[13];
  assign s_reg6_t_14         = s_reg6_t_15_0[14];
  assign s_reg6_t_15         = s_reg6_t_15_0[15];

  assign s_reg7_x_0          = s_reg7_x_15_0[0];
  assign s_reg7_x_1          = s_reg7_x_15_0[1];
  assign s_reg7_x_2          = s_reg7_x_15_0[2];
  assign s_reg7_x_3          = s_reg7_x_15_0[3];
  assign s_reg7_x_4          = s_reg7_x_15_0[4];
  assign s_reg7_x_5          = s_reg7_x_15_0[5];
  assign s_reg7_x_6          = s_reg7_x_15_0[6];
  assign s_reg7_x_7          = s_reg7_x_15_0[7];
  assign s_reg7_x_8          = s_reg7_x_15_0[8];
  assign s_reg7_x_9          = s_reg7_x_15_0[9];
  assign s_reg7_x_11         = s_reg7_x_15_0[11];
  assign s_reg7_x_10         = s_reg7_x_15_0[10];
  assign s_reg7_x_12         = s_reg7_x_15_0[12];
  assign s_reg7_x_13         = s_reg7_x_15_0[13];
  assign s_reg7_x_14         = s_reg7_x_15_0[14];
  assign s_reg7_x_15         = s_reg7_x_15_0[15];

  assign s_reg8_sts_0        = s_reg8_sts_15_0[0];
  assign s_reg8_sts_1        = s_reg8_sts_15_0[1];
  assign s_reg8_sts_2        = s_reg8_sts_15_0[2];
  assign s_reg8_sts_3        = s_reg8_sts_15_0[3];
  assign s_reg8_sts_4        = s_reg8_sts_15_0[4];
  assign s_reg8_sts_5        = s_reg8_sts_15_0[5];
  assign s_reg8_sts_6        = s_reg8_sts_15_0[6];
  assign s_reg8_sts_7        = s_reg8_sts_15_0[7];
  assign s_reg8_sts_8        = s_reg8_sts_15_0[8];
  assign s_reg8_sts_9        = s_reg8_sts_15_0[9];
  assign s_reg8_sts_10       = s_reg8_sts_15_0[10];
  assign s_reg8_sts_11       = s_reg8_sts_15_0[11];
  assign s_reg8_sts_12       = s_reg8_sts_15_0[12];
  assign s_reg8_sts_13       = s_reg8_sts_15_0[13];
  assign s_reg8_sts_14       = s_reg8_sts_15_0[14];
  assign s_reg8_sts_15       = s_reg8_sts_15_0[15];

  assign s_reg9_r1_0         = s_reg9_r1_15_0[0];
  assign s_reg9_r1_1         = s_reg9_r1_15_0[1];
  assign s_reg9_r1_2         = s_reg9_r1_15_0[2];
  assign s_reg9_r1_3         = s_reg9_r1_15_0[3];
  assign s_reg9_r1_4         = s_reg9_r1_15_0[4];
  assign s_reg9_r1_5         = s_reg9_r1_15_0[5];
  assign s_reg9_r1_6         = s_reg9_r1_15_0[6];
  assign s_reg9_r1_7         = s_reg9_r1_15_0[7];
  assign s_reg9_r1_8         = s_reg9_r1_15_0[8];
  assign s_reg9_r1_9         = s_reg9_r1_15_0[9];
  assign s_reg9_r1_10        = s_reg9_r1_15_0[10];
  assign s_reg9_r1_11        = s_reg9_r1_15_0[11];
  assign s_reg9_r1_12        = s_reg9_r1_15_0[12];
  assign s_reg9_r1_13        = s_reg9_r1_15_0[13];
  assign s_reg9_r1_14        = s_reg9_r1_15_0[14];
  assign s_reg9_r1_15        = s_reg9_r1_15_0[15];

  assign s_reg10_r2_0        = s_reg10_r2_15_0[0];
  assign s_reg10_r2_1        = s_reg10_r2_15_0[1];
  assign s_reg10_r2_2        = s_reg10_r2_15_0[2];
  assign s_reg10_r2_3        = s_reg10_r2_15_0[3];
  assign s_reg10_r2_4        = s_reg10_r2_15_0[4];
  assign s_reg10_r2_5        = s_reg10_r2_15_0[5];
  assign s_reg10_r2_6        = s_reg10_r2_15_0[6];
  assign s_reg10_r2_7        = s_reg10_r2_15_0[7];
  assign s_reg10_r2_8        = s_reg10_r2_15_0[8];
  assign s_reg10_r2_9        = s_reg10_r2_15_0[9];
  assign s_reg10_r2_10       = s_reg10_r2_15_0[10];
  assign s_reg10_r2_11       = s_reg10_r2_15_0[11];
  assign s_reg10_r2_12       = s_reg10_r2_15_0[12];
  assign s_reg10_r2_13       = s_reg10_r2_15_0[13];
  assign s_reg10_r2_14       = s_reg10_r2_15_0[14];
  assign s_reg10_r2_15       = s_reg10_r2_15_0[15];

  assign s_reg11_r3_0        = s_reg11_r3_15_0[0];
  assign s_reg11_r3_1        = s_reg11_r3_15_0[1];
  assign s_reg11_r3_2        = s_reg11_r3_15_0[2];
  assign s_reg11_r3_3        = s_reg11_r3_15_0[3];
  assign s_reg11_r3_4        = s_reg11_r3_15_0[4];
  assign s_reg11_r3_5        = s_reg11_r3_15_0[5];
  assign s_reg11_r3_6        = s_reg11_r3_15_0[6];
  assign s_reg11_r3_7        = s_reg11_r3_15_0[7];
  assign s_reg11_r3_8        = s_reg11_r3_15_0[8];
  assign s_reg11_r3_9        = s_reg11_r3_15_0[9];
  assign s_reg11_r3_10       = s_reg11_r3_15_0[10];
  assign s_reg11_r3_11       = s_reg11_r3_15_0[11];
  assign s_reg11_r3_12       = s_reg11_r3_15_0[12];
  assign s_reg11_r3_13       = s_reg11_r3_15_0[13];
  assign s_reg11_r3_14       = s_reg11_r3_15_0[14];
  assign s_reg11_r3_15       = s_reg11_r3_15_0[15];

  assign s_reg12_r4_0        = s_reg12_r4_15_0[0];
  assign s_reg12_r4_1        = s_reg12_r4_15_0[1];
  assign s_reg12_r4_2        = s_reg12_r4_15_0[2];
  assign s_reg12_r4_3        = s_reg12_r4_15_0[3];
  assign s_reg12_r4_4        = s_reg12_r4_15_0[4];
  assign s_reg12_r4_5        = s_reg12_r4_15_0[5];
  assign s_reg12_r4_6        = s_reg12_r4_15_0[6];
  assign s_reg12_r4_7        = s_reg12_r4_15_0[7];
  assign s_reg12_r4_8        = s_reg12_r4_15_0[8];
  assign s_reg12_r4_9        = s_reg12_r4_15_0[9];
  assign s_reg12_r4_10       = s_reg12_r4_15_0[10];
  assign s_reg12_r4_11       = s_reg12_r4_15_0[11];
  assign s_reg12_r4_12       = s_reg12_r4_15_0[12];
  assign s_reg12_r4_13       = s_reg12_r4_15_0[13];
  assign s_reg12_r4_14       = s_reg12_r4_15_0[14];
  assign s_reg12_r4_15       = s_reg12_r4_15_0[15];


  assign s_reg13_r5_0        = s_reg13_r5_15_0[0];
  assign s_reg13_r5_1        = s_reg13_r5_15_0[1];
  assign s_reg13_r5_10       = s_reg13_r5_15_0[10];
  assign s_reg13_r5_11       = s_reg13_r5_15_0[11];
  assign s_reg13_r5_12       = s_reg13_r5_15_0[12];
  assign s_reg13_r5_13       = s_reg13_r5_15_0[13];
  assign s_reg13_r5_14       = s_reg13_r5_15_0[14];
  assign s_reg13_r5_15       = s_reg13_r5_15_0[15];
  assign s_reg13_r5_2        = s_reg13_r5_15_0[2];
  assign s_reg13_r5_3        = s_reg13_r5_15_0[3];
  assign s_reg13_r5_4        = s_reg13_r5_15_0[4];
  assign s_reg13_r5_5        = s_reg13_r5_15_0[5];
  assign s_reg13_r5_6        = s_reg13_r5_15_0[6];
  assign s_reg13_r5_7        = s_reg13_r5_15_0[7];
  assign s_reg13_r5_8        = s_reg13_r5_15_0[8];
  assign s_reg13_r5_9        = s_reg13_r5_15_0[9];
  
  assign s_reg14_r6_0        = s_reg14_r6_15_0[0];
  assign s_reg14_r6_1        = s_reg14_r6_15_0[1];
  assign s_reg14_r6_10       = s_reg14_r6_15_0[10];
  assign s_reg14_r6_11       = s_reg14_r6_15_0[11];
  assign s_reg14_r6_12       = s_reg14_r6_15_0[12];
  assign s_reg14_r6_13       = s_reg14_r6_15_0[13];
  assign s_reg14_r6_14       = s_reg14_r6_15_0[14];
  assign s_reg14_r6_15       = s_reg14_r6_15_0[15];
  assign s_reg14_r6_2        = s_reg14_r6_15_0[2];
  assign s_reg14_r6_3        = s_reg14_r6_15_0[3];
  assign s_reg14_r6_4        = s_reg14_r6_15_0[4];
  assign s_reg14_r6_5        = s_reg14_r6_15_0[5];
  assign s_reg14_r6_6        = s_reg14_r6_15_0[6];
  assign s_reg14_r6_7        = s_reg14_r6_15_0[7];
  assign s_reg14_r6_8        = s_reg14_r6_15_0[8];
  assign s_reg14_r6_9        = s_reg14_r6_15_0[9];

  assign s_reg15_r7_0        = s_reg15_r7_15_0[0];
  assign s_reg15_r7_1        = s_reg15_r7_15_0[1];
  assign s_reg15_r7_10       = s_reg15_r7_15_0[10];
  assign s_reg15_r7_11       = s_reg15_r7_15_0[11];
  assign s_reg15_r7_12       = s_reg15_r7_15_0[12];
  assign s_reg15_r7_13       = s_reg15_r7_15_0[13];
  assign s_reg15_r7_14       = s_reg15_r7_15_0[14];
  assign s_reg15_r7_15       = s_reg15_r7_15_0[15];
  assign s_reg15_r7_2        = s_reg15_r7_15_0[2];
  assign s_reg15_r7_3        = s_reg15_r7_15_0[3];
  assign s_reg15_r7_4        = s_reg15_r7_15_0[4];
  assign s_reg15_r7_5        = s_reg15_r7_15_0[5];
  assign s_reg15_r7_6        = s_reg15_r7_15_0[6];
  assign s_reg15_r7_7        = s_reg15_r7_15_0[7];
  assign s_reg15_r7_8        = s_reg15_r7_15_0[8];
  assign s_reg15_r7_9        = s_reg15_r7_15_0[9];


  /*******************************************************************************
   ** Here all input connections are defined                                     **
   *******************************************************************************/
  assign s_rb_15_0[15:0]     = RB_15_0;
  assign s_ncla_15_0[15:0]   = NLCA_15_0;
  assign s_wr_15_0[15:0]     = WR_15_0;
  assign s_eb_15_0[15:0]     = EB_15_0;
  assign s_ea_15_0[15:0]     = EA_15_0;
  assign s_xfetch_n          = XFETCHN;
  assign s_aluclk_n          = ~ALUCLK;
  assign s_aluclk            = ALUCLK;

  /*******************************************************************************
   ** Here all output connections are defined                                    **
   *******************************************************************************/
  assign A_15_0              = s_a_15_0_out[15:0];
  assign BR_15_0             = s_br_15_0_out[15:0];
  assign B_15_0              = s_b_15_0_out[15:0];
  assign PR_15_0             = s_pr_15_0_out[15:0];
  assign XR_15_0             = s_xr_15_0_out[15:0];

  /*******************************************************************************
   ** Here all sub-circuits are defined                                          **
   *******************************************************************************/

  // Register 0 (Z)
  CGA_WRF_RBLOCK_DR16 Z_REG_0 (
      .ALUCLK(s_aluclk),
      .RB_15_0(s_rb_15_0[15:0]),
      .REG_15_0(s_reg0_z_15_0[15:0]),
      .WR(s_wr_15_0[0])
  );

  // Regster 1 (D)
  CGA_WRF_RBLOCK_DR16 D_REG_1 (
      .ALUCLK(s_aluclk),
      .RB_15_0(s_rb_15_0[15:0]),
      .REG_15_0(s_reg1_d_15_0[15:0]),
      .WR(s_wr_15_0[1])
  );

  // Register 2 (P)
  CGA_WRF_RBLOCK_PREG P_REG_2 (
      .ALUCLK(s_aluclk),
      .ALUCLKN(s_aluclk_n),
      .NLCA_15_0(s_ncla_15_0[15:0]),
      .PR_15_0(s_pr_15_0_out[15:0]),
      .P_15_0(s_reg2_p_15_0[15:0]),
      .RB_15_0(s_rb_15_0[15:0]),
      .WR2(s_wr_15_0[2]),
      .XFETCHN(s_xfetch_n)
  );

  // Register 3 (B)
  CGA_WRF_RBLOCK_LR16 B_REG_3 (
      .ALUCLK(s_aluclk),
      .LR_15_0(s_br_15_0_out[15:0]),
      .RB_15_0(s_rb_15_0[15:0]),
      .R_15_0(s_reg3_b_15_0[15:0]),
      .WR(s_wr_15_0[3])
  );

  // Register 4 (L)
  CGA_WRF_RBLOCK_DR16 L_REG_4 (
      .ALUCLK(s_aluclk),
      .RB_15_0(s_rb_15_0[15:0]),
      .REG_15_0(s_reg4_l_15_0[15:0]),
      .WR(s_wr_15_0[4])
  );

  // Register 5 (A)
  CGA_WRF_RBLOCK_DR16 A_REG_5 (
      .ALUCLK(s_aluclk),
      .RB_15_0(s_rb_15_0[15:0]),
      .REG_15_0(s_reg5_a_15_0[15:0]),
      .WR(s_wr_15_0[5])
  );

  // Register 6 (T)
  CGA_WRF_RBLOCK_DR16 T_REG_6 (
      .ALUCLK(s_aluclk),
      .RB_15_0(s_rb_15_0[15:0]),
      .REG_15_0(s_reg6_t_15_0[15:0]),
      .WR(s_wr_15_0[6])
  );

  // Register 7 (X)
  CGA_WRF_RBLOCK_LR16 X_REG_7 (
      .ALUCLK(s_aluclk),
      .LR_15_0(s_xr_15_0_out[15:0]),
      .RB_15_0(s_rb_15_0[15:0]),
      .R_15_0(s_reg7_x_15_0[15:0]),
      .WR(s_wr_15_0[7])
  );

  // Register 8 (STS)
  CGA_WRF_RBLOCK_DR16 STS_REG_8 (
      .ALUCLK(s_aluclk),
      .RB_15_0(s_rb_15_0[15:0]),
      .REG_15_0(s_reg8_sts_15_0[15:0]),
      .WR(s_wr_15_0[8])
  );

  // Register 9 (R1) (internal registers)
  CGA_WRF_RBLOCK_DR16 R1_REG_9 (
      .ALUCLK(s_aluclk),
      .RB_15_0(s_rb_15_0[15:0]),
      .REG_15_0(s_reg9_r1_15_0[15:0]),
      .WR(s_wr_15_0[9])
  );

  // Register 10 (R2)
  CGA_WRF_RBLOCK_DR16 R2_REG_10 (
      .ALUCLK(s_aluclk),
      .RB_15_0(s_rb_15_0[15:0]),
      .REG_15_0(s_reg10_r2_15_0[15:0]),
      .WR(s_wr_15_0[10])
  );

  // Register 11 (R3)
  CGA_WRF_RBLOCK_DR16 R3_REG_11 (
      .ALUCLK(s_aluclk),
      .RB_15_0(s_rb_15_0[15:0]),
      .REG_15_0(s_reg11_r3_15_0[15:0]),
      .WR(s_wr_15_0[11])
  );

  // Register 12 (R4)
  CGA_WRF_RBLOCK_DR16 R4_REG_12 (
      .ALUCLK(s_aluclk),
      .RB_15_0(s_rb_15_0[15:0]),
      .REG_15_0(s_reg12_r4_15_0[15:0]),
      .WR(s_wr_15_0[12])
  );

  // Register 13 (R5)
  CGA_WRF_RBLOCK_DR16 R5_REG_13 (
      .ALUCLK(s_aluclk),
      .RB_15_0(s_rb_15_0[15:0]),
      .REG_15_0(s_reg13_r5_15_0[15:0]),
      .WR(s_wr_15_0[13])
  );

  // Register 14 (R6)
  CGA_WRF_RBLOCK_DR16 R6_REG_14 (
      .ALUCLK(s_aluclk),
      .RB_15_0(s_rb_15_0[15:0]),
      .REG_15_0(s_reg14_r6_15_0[15:0]),
      .WR(s_wr_15_0[14])
  );

  // Register 15 (R7)
  CGA_WRF_RBLOCK_DR16 R7_REG_15 (
      .ALUCLK(s_aluclk),
      .RB_15_0(s_rb_15_0[15:0]),
      .REG_15_0(s_reg15_r7_15_0[15:0]),
      .WR(s_wr_15_0[15])
  );

  // Selector 0
  CGA_WRF_RBLOCK_SEL16 SEL_0 (
      .EA_15_0(s_ea_15_0[15:0]),
      .EB_15_0(s_eb_15_0[15:0]),
      .SI_15_0(s_sel0_in_15_0[15:0]),
      .PA(s_a_15_0_out[0]),
      .PB(s_b_15_0_out[0])
  );

  CGA_WRF_RBLOCK_SEL16 SEL_1 (
      .EA_15_0(s_ea_15_0[15:0]),
      .EB_15_0(s_eb_15_0[15:0]),
      .PA(s_a_15_0_out[1]),
      .PB(s_b_15_0_out[1]),
      .SI_15_0(s_sel1_in_15_0[15:0])
  );

  CGA_WRF_RBLOCK_SEL16 SEL_2 (
      .EA_15_0(s_ea_15_0[15:0]),
      .EB_15_0(s_eb_15_0[15:0]),
      .PA(s_a_15_0_out[2]),
      .PB(s_b_15_0_out[2]),
      .SI_15_0(s_sel2_in_15_0[15:0])
  );

  CGA_WRF_RBLOCK_SEL16 SEL_3 (
      .EA_15_0(s_ea_15_0[15:0]),
      .EB_15_0(s_eb_15_0[15:0]),
      .PA(s_a_15_0_out[3]),
      .PB(s_b_15_0_out[3]),
      .SI_15_0(s_sel3_in_15_0[15:0])
  );

  CGA_WRF_RBLOCK_SEL16 SEL_4 (
      .EA_15_0(s_ea_15_0[15:0]),
      .EB_15_0(s_eb_15_0[15:0]),
      .PA(s_a_15_0_out[4]),
      .PB(s_b_15_0_out[4]),
      .SI_15_0(s_sel4_in_15_0[15:0])
  );

  CGA_WRF_RBLOCK_SEL16 SEL_5 (
      .EA_15_0(s_ea_15_0[15:0]),
      .EB_15_0(s_eb_15_0[15:0]),
      .PA(s_a_15_0_out[5]),
      .PB(s_b_15_0_out[5]),
      .SI_15_0(s_sel5_in_15_0[15:0])
  );

  CGA_WRF_RBLOCK_SEL16 SEL_6 (
      .EA_15_0(s_ea_15_0[15:0]),
      .EB_15_0(s_eb_15_0[15:0]),
      .PA(s_a_15_0_out[6]),
      .PB(s_b_15_0_out[6]),
      .SI_15_0(s_sel6_in_15_0[15:0])
  );

  CGA_WRF_RBLOCK_SEL16 SEL_7 (
      .EA_15_0(s_ea_15_0[15:0]),
      .EB_15_0(s_eb_15_0[15:0]),
      .PA(s_a_15_0_out[7]),
      .PB(s_b_15_0_out[7]),
      .SI_15_0(s_sel7_in_15_0[15:0])
  );

  CGA_WRF_RBLOCK_SEL16 SEL_8 (
      .EA_15_0(s_ea_15_0[15:0]),
      .EB_15_0(s_eb_15_0[15:0]),
      .PA(s_a_15_0_out[8]),
      .PB(s_b_15_0_out[8]),
      .SI_15_0(s_sel8_in_15_0[15:0])
  );

  CGA_WRF_RBLOCK_SEL16 SEL_9 (
      .EA_15_0(s_ea_15_0[15:0]),
      .EB_15_0(s_eb_15_0[15:0]),
      .PA(s_a_15_0_out[9]),
      .PB(s_b_15_0_out[9]),
      .SI_15_0(s_sel9_in_15_0[15:0])
  );

  CGA_WRF_RBLOCK_SEL16 SEL_10 (
      .EA_15_0(s_ea_15_0[15:0]),
      .EB_15_0(s_eb_15_0[15:0]),
      .PA(s_a_15_0_out[10]),
      .PB(s_b_15_0_out[10]),
      .SI_15_0(s_sel10_in_15_0[15:0])
  );

  CGA_WRF_RBLOCK_SEL16 SEL_11 (
      .EA_15_0(s_ea_15_0[15:0]),
      .EB_15_0(s_eb_15_0[15:0]),
      .PA(s_a_15_0_out[11]),
      .PB(s_b_15_0_out[11]),
      .SI_15_0(s_sel11_in_15_0[15:0])
  );

  CGA_WRF_RBLOCK_SEL16 SEL_12 (
      .EA_15_0(s_ea_15_0[15:0]),
      .EB_15_0(s_eb_15_0[15:0]),
      .PA(s_a_15_0_out[12]),
      .PB(s_b_15_0_out[12]),
      .SI_15_0(s_sel12_in_15_0[15:0])
  );

  CGA_WRF_RBLOCK_SEL16 SEL_13 (
      .EA_15_0(s_ea_15_0[15:0]),
      .EB_15_0(s_eb_15_0[15:0]),
      .PA(s_a_15_0_out[13]),
      .PB(s_b_15_0_out[13]),
      .SI_15_0(s_sel13_in_15_0[15:0])
  );

  CGA_WRF_RBLOCK_SEL16 SEL_14 (
      .EA_15_0(s_ea_15_0[15:0]),
      .EB_15_0(s_eb_15_0[15:0]),
      .PA(s_a_15_0_out[14]),
      .PB(s_b_15_0_out[14]),
      .SI_15_0(s_sel14_in_15_0[15:0])
  );

  CGA_WRF_RBLOCK_SEL16 SEL_15 (
      .EA_15_0(s_ea_15_0[15:0]),
      .EB_15_0(s_eb_15_0[15:0]),
      .PA(s_a_15_0_out[15]),
      .PB(s_b_15_0_out[15]),
      .SI_15_0(s_sel15_in_15_0[15:0])
  );

endmodule

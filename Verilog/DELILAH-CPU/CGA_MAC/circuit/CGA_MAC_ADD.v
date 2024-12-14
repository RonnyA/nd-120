/**************************************************************************
** ND120 CGA (CPU Gate Array / DELILAH)                                  **
** /CGA/MAC/ADD                                                          **
** ADD                                                                   **
**                                                                       **
** Page 29                                                               **
** SHEET 1 of 1                                                          **
**                                                                       **
** Last reviewed: 14-DEC-2024                                            **
** Ronny Hansen                                                          **
***************************************************************************/

module CGA_MAC_ADD (
    input [15:0] BR_15_0,   //! B register from ALU
    input [15:0] RB_15_0,   //! Microcode Register B
    input [15:0] XR_15_0,   //! X register from ALU
    input [15:0] LCA_15_0,  //! ALU Load Control Address

    input        PB,        //! Select ALU register B
    input        PRB,       //! Select Microcode register B
    input        PX,        //! Select ALU register X
    input        PLCA,      //! Select ALU Load Control Address


    // Special: Add CD if PLCA is low
    input [15:0] CD_15_0,   //! CPU data added to the selected register
    input        CDS,       //! If false all 16 bits of CD is added. If false, only the low 8 bits are added.

    output [15:0] ADD_15_0  //! MAC Addition result
);

  /*******************************************************************************
   ** The wires are defined here                                                 **
   *******************************************************************************/
  wire [ 7:0] s_cd_7_0;
  wire [15:0] s_xr_15_0;
  wire [15:0] s_rb_15_0;
  wire [ 7:0] s_cde_15_8;
  wire [15:0] s_cd_15_0;
  wire [15:0] s_lca_15_0;
  wire [15:0] s_add_15_0_out;
  wire [15:0] s_br_15_0;
  wire [15:0] s_prp_15_0;

  wire        s_cd_2;
  wire        s_cds_n;
  wire        s_cds;
  wire        s_cde_enable;
  wire        s_cdsn_nand_cd8;
  wire        s_cdsn_nand_cd9;
  wire        s_cdsn_nand_cd10;
  wire        s_cdsn_nand_cd11;
  wire        s_cdsn_nand_cd12;
  wire        s_cdsn_nand_cd13;
  wire        s_cdsn_nand_cd14;
  wire        s_cdsn_nand_cd15;

  wire        s_pb;
  wire        s_plca;
  wire        s_prb;
  wire        s_prp0_a_n;
  wire        s_prp0_b_n;
  wire        s_prp1_a_n;
  wire        s_prp1_b_n;
  wire        s_prp10_a_n;
  wire        s_prp10_b_n;
  wire        s_prp11_a_n;
  wire        s_prp11_b_n;
  wire        s_prp12_a_n;
  wire        s_prp12_b_n;
  wire        s_prp13_a_n;
  wire        s_prp13_b_n;
  wire        s_prp14_a_n;
  wire        s_prp14_b_n;
  wire        s_prp15_a_n;
  wire        s_prp15_b_n;
  wire        s_prp2_a_n;
  wire        s_prp2_b_n;
  wire        s_prp3_a_n;
  wire        s_prp3_b_n;
  wire        s_prp4_a_n;
  wire        s_prp4_b_n;
  wire        s_prp5_a_n;
  wire        s_prp5_b_n;
  wire        s_prp6_a_n;
  wire        s_prp6_b_n;
  wire        s_prp7_a_n;
  wire        s_prp7_b_n;
  wire        s_prp8_a_n;
  wire        s_prp8_b_n;
  wire        s_prp9_a_n;
  wire        s_prp9_b_n;
  wire        s_px;

  /*******************************************************************************
   ** Here all input connections are defined                                     **
   *******************************************************************************/
  assign s_xr_15_0[15:0]  = XR_15_0;
  assign s_rb_15_0[15:0]  = RB_15_0;
  assign s_cd_15_0[15:0]  = CD_15_0;
  assign s_lca_15_0[15:0] = LCA_15_0;
  assign s_br_15_0[15:0]  = BR_15_0;
  assign s_pb             = PB;
  assign s_plca           = PLCA;
  assign s_prb            = PRB;
  assign s_cds            = CDS;
  assign s_px             = PX;

  /*******************************************************************************
   ** Here all output connections are defined                                    **
   *******************************************************************************/
  assign ADD_15_0         = s_add_15_0_out[15:0];

  /*******************************************************************************
   ** Here all in-lined components are defined                                   **
   *******************************************************************************/

  // NOT Gate
  assign s_cds_n          = ~s_cds;

  /*******************************************************************************
   ** Here all normal components are defined                                     **
   *******************************************************************************/

  /** PRP OR 0-15*/

  OR_GATE #(
      .BubblesMask(2'b11)
  ) GATES_1 (
      .input1(s_prp0_a_n),
      .input2(s_prp0_b_n),
      .result(s_prp_15_0[0])
  );

  OR_GATE #(
      .BubblesMask(2'b11)
  ) GATES_2 (
      .input1(s_prp1_a_n),
      .input2(s_prp1_b_n),
      .result(s_prp_15_0[1])
  );

  OR_GATE #(
      .BubblesMask(2'b11)
  ) GATES_3 (
      .input1(s_prp2_a_n),
      .input2(s_prp2_b_n),
      .result(s_prp_15_0[2])
  );

  OR_GATE #(
      .BubblesMask(2'b11)
  ) GATES_4 (
      .input1(s_prp3_a_n),
      .input2(s_prp3_b_n),
      .result(s_prp_15_0[3])
  );

  OR_GATE #(
      .BubblesMask(2'b11)
  ) GATES_5 (
      .input1(s_prp4_a_n),
      .input2(s_prp4_b_n),
      .result(s_prp_15_0[4])
  );

  OR_GATE #(
      .BubblesMask(2'b11)
  ) GATES_6 (
      .input1(s_prp5_a_n),
      .input2(s_prp5_b_n),
      .result(s_prp_15_0[5])
  );

  OR_GATE #(
      .BubblesMask(2'b11)
  ) GATES_7 (
      .input1(s_prp6_a_n),
      .input2(s_prp6_b_n),
      .result(s_prp_15_0[6])
  );

  OR_GATE #(
      .BubblesMask(2'b11)
  ) GATES_8 (
      .input1(s_prp7_a_n),
      .input2(s_prp7_b_n),
      .result(s_prp_15_0[7])
  );

  OR_GATE #(
      .BubblesMask(2'b11)
  ) GATES_9 (
      .input1(s_prp8_a_n),
      .input2(s_prp8_b_n),
      .result(s_prp_15_0[8])
  );

  OR_GATE #(
      .BubblesMask(2'b11)
  ) GATES_10 (
      .input1(s_prp9_a_n),
      .input2(s_prp9_b_n),
      .result(s_prp_15_0[9])
  );

  OR_GATE #(
      .BubblesMask(2'b11)
  ) GATES_11 (
      .input1(s_prp10_a_n),
      .input2(s_prp10_b_n),
      .result(s_prp_15_0[10])
  );

  OR_GATE #(
      .BubblesMask(2'b11)
  ) GATES_12 (
      .input1(s_prp11_a_n),
      .input2(s_prp11_b_n),
      .result(s_prp_15_0[11])
  );

  OR_GATE #(
      .BubblesMask(2'b11)
  ) GATES_13 (
      .input1(s_prp12_a_n),
      .input2(s_prp12_b_n),
      .result(s_prp_15_0[12])
  );

  OR_GATE #(
      .BubblesMask(2'b11)
  ) GATES_14 (
      .input1(s_prp13_a_n),
      .input2(s_prp13_b_n),
      .result(s_prp_15_0[13])
  );

  OR_GATE #(
      .BubblesMask(2'b11)
  ) GATES_15 (
      .input1(s_prp14_a_n),
      .input2(s_prp14_b_n),
      .result(s_prp_15_0[14])
  );

  OR_GATE #(
      .BubblesMask(2'b11)
  ) GATES_16 (
      .input1(s_prp15_a_n),
      .input2(s_prp15_b_n),
      .result(s_prp_15_0[15])
  );

  /** CDS and CD7 selector*/

  NAND_GATE #(
      .BubblesMask(2'b00)
  ) GATES_17 (
      .input1(s_cd_15_0[7]),
      .input2(s_cds),
      .result(s_cde_enable)
  );


  /** CD 8-15  AND selector **/
  NAND_GATE #(
      .BubblesMask(2'b00)
  ) GATES_18 (
      .input1(s_cds_n),
      .input2(s_cd_15_0[8]),
      .result(s_cdsn_nand_cd8)
  );

  NAND_GATE #(
      .BubblesMask(2'b00)
  ) GATES_19 (
      .input1(s_cds_n),
      .input2(s_cd_15_0[9]),
      .result(s_cdsn_nand_cd9)
  );

  NAND_GATE #(
      .BubblesMask(2'b00)
  ) GATES_20 (
      .input1(s_cds_n),
      .input2(s_cd_15_0[10]),
      .result(s_cdsn_nand_cd10)
  );

  NAND_GATE #(
      .BubblesMask(2'b00)
  ) GATES_21 (
      .input1(s_cds_n),
      .input2(s_cd_15_0[11]),
      .result(s_cdsn_nand_cd11)
  );

  NAND_GATE #(
      .BubblesMask(2'b00)
  ) GATES_22 (
      .input1(s_cds_n),
      .input2(s_cd_15_0[12]),
      .result(s_cdsn_nand_cd12)
  );

  NAND_GATE #(
      .BubblesMask(2'b00)
  ) GATES_23 (
      .input1(s_cds_n),
      .input2(s_cd_15_0[13]),
      .result(s_cdsn_nand_cd13)
  );

  NAND_GATE #(
      .BubblesMask(2'b00)
  ) GATES_24 (
      .input1(s_cds_n),
      .input2(s_cd_15_0[14]),
      .result(s_cdsn_nand_cd14)
  );

  NAND_GATE #(
      .BubblesMask(2'b00)
  ) GATES_25 (
      .input1(s_cds_n),
      .input2(s_cd_15_0[15]),
      .result(s_cdsn_nand_cd15)
  );


  NAND_GATE #(
      .BubblesMask(2'b00)
  ) GATES_27 (
      .input1(s_cdsn_nand_cd8),
      .input2(s_cde_enable),
      .result(s_cde_15_8[0])
  );

  NAND_GATE #(
      .BubblesMask(2'b00)
  ) GATES_28 (
      .input1(s_cdsn_nand_cd9),
      .input2(s_cde_enable),
      .result(s_cde_15_8[1])
  );

  NAND_GATE #(
      .BubblesMask(2'b00)
  ) GATES_29 (
      .input1(s_cdsn_nand_cd10),
      .input2(s_cde_enable),
      .result(s_cde_15_8[2])
  );

  NAND_GATE #(
      .BubblesMask(2'b00)
  ) GATES_30 (
      .input1(s_cdsn_nand_cd11),
      .input2(s_cde_enable),
      .result(s_cde_15_8[3])
  );

  NAND_GATE #(
      .BubblesMask(2'b00)
  ) GATES_31 (
      .input1(s_cdsn_nand_cd12),
      .input2(s_cde_enable),
      .result(s_cde_15_8[4])
  );

  NAND_GATE #(
      .BubblesMask(2'b00)
  ) GATES_32 (
      .input1(s_cdsn_nand_cd13),
      .input2(s_cde_enable),
      .result(s_cde_15_8[5])
  );

  NAND_GATE #(
      .BubblesMask(2'b00)
  ) GATES_33 (
      .input1(s_cdsn_nand_cd14),
      .input2(s_cde_enable),
      .result(s_cde_15_8[6])
  );

  NAND_GATE #(
      .BubblesMask(2'b00)
  ) GATES_34 (
      .input1(s_cdsn_nand_cd15),
      .input2(s_cde_enable),
      .result(s_cde_15_8[7])
  );


  /*******************************************************************************
   ** Here all sub-circuits are defined                                          **
   *******************************************************************************/

  // PRP 15 input
  A02 A02_31 (
      .A(s_rb_15_0[15]),
      .B(s_prb),
      .C(s_br_15_0[15]),
      .D(s_pb),
      .Z(s_prp15_a_n)
  );

  A02 A02_32 (
      .A(s_xr_15_0[15]),
      .B(s_px),
      .C(s_lca_15_0[15]),
      .D(s_plca),
      .Z(s_prp15_b_n)
  );

  // PRP 14 input
  A02 A02_29 (
      .A(s_rb_15_0[14]),
      .B(s_prb),
      .C(s_br_15_0[14]),
      .D(s_pb),
      .Z(s_prp14_a_n)
  );

  A02 A02_30 (
      .A(s_xr_15_0[14]),
      .B(s_px),
      .C(s_lca_15_0[14]),
      .D(s_plca),
      .Z(s_prp14_b_n)
  );

  // PRP 13 input
  A02 A02_27 (
      .A(s_rb_15_0[13]),
      .B(s_prb),
      .C(s_br_15_0[13]),
      .D(s_pb),
      .Z(s_prp13_a_n)
  );

  A02 A02_28 (
      .A(s_xr_15_0[13]),
      .B(s_px),
      .C(s_lca_15_0[13]),
      .D(s_plca),
      .Z(s_prp13_b_n)
  );

  // PRP 12 input
  A02 A02_25 (
      .A(s_rb_15_0[12]),
      .B(s_prb),
      .C(s_br_15_0[12]),
      .D(s_pb),
      .Z(s_prp12_a_n)
  );
  A02 A02_26 (
      .A(s_xr_15_0[12]),
      .B(s_px),
      .C(s_lca_15_0[12]),
      .D(s_plca),
      .Z(s_prp12_b_n)
  );

  // PRP 11 input
  A02 A02_23 (
      .A(s_rb_15_0[11]),
      .B(s_prb),
      .C(s_br_15_0[11]),
      .D(s_pb),
      .Z(s_prp11_a_n)
  );

  A02 A02_24 (
      .A(s_xr_15_0[11]),
      .B(s_px),
      .C(s_lca_15_0[11]),
      .D(s_plca),
      .Z(s_prp11_b_n)
  );

  // PRP 10 input
  A02 A02_21 (
      .A(s_rb_15_0[10]),
      .B(s_prb),
      .C(s_br_15_0[10]),
      .D(s_pb),
      .Z(s_prp10_a_n)
  );

  A02 A02_22 (
      .A(s_xr_15_0[10]),
      .B(s_px),
      .C(s_lca_15_0[10]),
      .D(s_plca),
      .Z(s_prp10_b_n)
  );

  // PRP 9 input
  A02 A02_19 (
      .A(s_rb_15_0[9]),
      .B(s_prb),
      .C(s_br_15_0[9]),
      .D(s_pb),
      .Z(s_prp9_a_n)
  );

  A02 A02_20 (
      .A(s_xr_15_0[9]),
      .B(s_px),
      .C(s_lca_15_0[9]),
      .D(s_plca),
      .Z(s_prp9_b_n)
  );

  // PRP 8 input
  A02 A02_17 (
      .A(s_rb_15_0[8]),
      .B(s_prb),
      .C(s_br_15_0[8]),
      .D(s_pb),
      .Z(s_prp8_a_n)
  );

  A02 A02_18 (
      .A(s_xr_15_0[8]),
      .B(s_px),
      .C(s_lca_15_0[8]),
      .D(s_plca),
      .Z(s_prp8_b_n)
  );

  // PRP 7 input
  A02 A02_15 (
      .A(s_rb_15_0[7]),
      .B(s_prb),
      .C(s_br_15_0[7]),
      .D(s_pb),
      .Z(s_prp7_a_n)
  );

  A02 A02_16 (
      .A(s_xr_15_0[7]),
      .B(s_px),
      .C(s_lca_15_0[7]),
      .D(s_plca),
      .Z(s_prp7_b_n)
  );

  // PRP 6 input

  A02 A02_13 (
      .A(s_rb_15_0[6]),
      .B(s_prb),
      .C(s_br_15_0[6]),
      .D(s_pb),
      .Z(s_prp6_a_n)
  );

  A02 A02_14 (
      .A(s_xr_15_0[6]),
      .B(s_px),
      .C(s_lca_15_0[6]),
      .D(s_plca),
      .Z(s_prp6_b_n)
  );

  // PRP 5 input
  A02 A02_11 (
      .A(s_rb_15_0[5]),
      .B(s_prb),
      .C(s_br_15_0[5]),
      .D(s_pb),
      .Z(s_prp5_a_n)
  );

  A02 A02_12 (
      .A(s_xr_15_0[5]),
      .B(s_px),
      .C(s_lca_15_0[5]),
      .D(s_plca),
      .Z(s_prp5_b_n)
  );

  // PRP 4 input
  A02 A02_9 (
      .A(s_rb_15_0[4]),
      .B(s_prb),
      .C(s_br_15_0[4]),
      .D(s_pb),
      .Z(s_prp4_a_n)
  );

  A02 A02_10 (
      .A(s_xr_15_0[4]),
      .B(s_px),
      .C(s_lca_15_0[4]),
      .D(s_plca),
      .Z(s_prp4_b_n)
  );

  // PRP 3 input
  A02 A02_7 (
      .A(s_rb_15_0[3]),
      .B(s_prb),
      .C(s_br_15_0[3]),
      .D(s_pb),
      .Z(s_prp3_a_n)
  );

  A02 A02_8 (
      .A(s_xr_15_0[3]),
      .B(s_px),
      .C(s_lca_15_0[3]),
      .D(s_plca),
      .Z(s_prp3_b_n)
  );


  // PRP 2 input
  A02 A02_5 (
      .A(s_rb_15_0[2]),
      .B(s_prb),
      .C(s_br_15_0[2]),
      .D(s_pb),
      .Z(s_prp2_a_n)
  );

  A02 A02_6 (
      .A(s_xr_15_0[2]),
      .B(s_px),
      .C(s_lca_15_0[2]),
      .D(s_plca),
      .Z(s_prp2_b_n)
  );

  // PRP 1 input
  A02 A02_3 (
      .A(s_rb_15_0[1]),
      .B(s_prb),
      .C(s_br_15_0[1]),
      .D(s_pb),
      .Z(s_prp1_a_n)
  );

  A02 A02_4 (
      .A(s_xr_15_0[1]),
      .B(s_px),
      .C(s_lca_15_0[1]),
      .D(s_plca),
      .Z(s_prp1_b_n)
  );

  // PRP 0 input
  A02 A02_1 (
      .A(s_rb_15_0[0]),
      .B(s_prb),
      .C(s_br_15_0[0]),
      .D(s_pb),
      .Z(s_prp0_a_n)
  );

  A02 A02_2 (
      .A(s_xr_15_0[0]),
      .B(s_px),
      .C(s_lca_15_0[0]),
      .D(s_plca),
      .Z(s_prp0_b_n)
  );

  // Fastadd  
  CGA_MAC_FASTADD FASTADD (
      .ADD_15_0(s_add_15_0_out[15:0]),
      .CDE_15_8(s_cde_15_8[7:0]),
      .CD_7_0  (s_cd_7_0[7:0]),
      .PRP_15_0(s_prp_15_0[15:0])
  );

endmodule

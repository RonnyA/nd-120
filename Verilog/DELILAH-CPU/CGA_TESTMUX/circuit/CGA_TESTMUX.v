/**************************************************************************
** ND120 CGA (CPU Gate Array / DELILAH)                                  **
** /CGA/TESTMUX                                                          **
** TESTMUX                                                               **
**                                                                       **
** Page 105                                                              **
** SHEET 1 of 1                                                          **
**                                                                       **
** Last reviewed: 10-NOV-2024                                            **
** Ronny Hansen                                                          **
***************************************************************************/

module CGA_TESTMUX (
    input       CBRKN,
    input       CFETCH,
    input       COND,
    input       CRY,
    input       CSMREQ,
    input       DEEP,
    input       DSTOPN,
    input       DZD,
    input       F15,
    input       INDN,
    input       LCZN,
    input       LDIRV,
    input       MI,
    input       OOD,
    input       OVF,
    input       PN,
    input       PTM,
    input       PTREEOUT,
    input       PTSTN,
    input       RESTR,
    input [3:0] SC_6_3,
    input       SGR,
    input       TN,
    input [2:0] TSEL_2_0,
    input [3:0] TVEC_3_0,
    input       UPN,
    input       VACCN,
    input       VEX,
    input       WPN,
    input       WRITEN,
    input       XFETCHN,
    input       ZF,

    output [4:0] TEST_4_0
);

  /*******************************************************************************
   ** The wires are defined here                                                 **
   *******************************************************************************/
  wire [3:0] s_tvec_3_0;
  wire [2:0] s_tsel_2_0;
  wire [4:0] s_test_4_0_out;
  wire [3:0] s_sc_6_3;
  wire       s_cbrk_n;
  wire       s_cfetch;
  wire       s_cond;
  wire       s_cry;
  wire       s_csmreq;
  wire       s_deep;
  wire       s_dstop_n;
  wire       s_dzd;
  wire       s_f15;
  wire       s_gates1_out;
  wire       s_gates2_out;
  wire       s_gates3_out;
  wire       s_gates4_out;
  wire       s_gnd;
  wire       s_ind_n;
  wire       s_lcz_n;
  wire       s_ldirv;
  wire       s_mi;
  wire       s_ood;
  wire       s_ovf;
  wire       s_pn;
  wire       s_power;
  wire       s_ptm;
  wire       s_ptreeout;
  wire       s_ptst_n;
  wire       s_restr;
  wire       s_sgr;
  wire       s_tn;
  wire       s_up_n;
  wire       s_vacc_n;
  wire       s_vex;
  wire       s_wpn;
  wire       s_write_n;
  wire       s_xfetch_n;
  wire       s_zf;

  /*******************************************************************************
   ** The module functionality is described here                                 **
   *******************************************************************************/

  /*******************************************************************************
   ** Here all input connections are defined                                     **
   *******************************************************************************/
  assign s_tvec_3_0[3:0] = TVEC_3_0;
  assign s_tsel_2_0[2:0] = TSEL_2_0;
  assign s_sc_6_3[3:0]   = SC_6_3;
  assign s_write_n       = WRITEN;
  assign s_cond          = COND;
  assign s_sgr           = SGR;
  assign s_cfetch        = CFETCH;
  assign s_csmreq        = CSMREQ;
  assign s_ptm           = PTM;
  assign s_deep          = DEEP;
  assign s_ldirv         = LDIRV;
  assign s_lcz_n         = LCZN;
  assign s_wpn           = WPN;
  assign s_pn            = PN;
  assign s_vacc_n        = VACCN;
  assign s_ovf           = OVF;
  assign s_zf            = ZF;
  assign s_tn            = TN;
  assign s_ind_n         = INDN;
  assign s_vex           = VEX;
  assign s_dzd           = DZD;
  assign s_xfetch_n      = XFETCHN;
  assign s_dstop_n       = DSTOPN;
  assign s_cry           = CRY;
  assign s_restr         = RESTR;
  assign s_cbrk_n        = CBRKN;
  assign s_f15           = F15;
  assign s_ood           = OOD;
  assign s_mi            = MI;
  assign s_up_n          = UPN;
  assign s_ptreeout      = PTREEOUT;
  assign s_ptst_n        = PTSTN;

  /*******************************************************************************
   ** Here all output connections are defined                                    **
   *******************************************************************************/
  assign TEST_4_0        = s_test_4_0_out[4:0];

  /*******************************************************************************
   ** Here all in-lined components are defined                                   **
   *******************************************************************************/

  // Power
  assign s_power         = 1'b1;

  // Ground
  assign s_gnd           = 1'b0;


  /*******************************************************************************
   ** Here all normal components are defined                                     **
   *******************************************************************************/
  NAND_GATE #(
      .BubblesMask(2'b11)
  ) GATES_1 (
      .input1(s_ptst_n),
      .input2(s_ptreeout),
      .result(s_gates1_out)
  );

  AND_GATE #(
      .BubblesMask(2'b00)
  ) GATES_2 (
      .input1(s_tsel_2_0[0]),
      .input2(s_ptst_n),
      .result(s_gates2_out)
  );

  AND_GATE #(
      .BubblesMask(2'b00)
  ) GATES_3 (
      .input1(s_tsel_2_0[1]),
      .input2(s_ptst_n),
      .result(s_gates3_out)
  );

  AND_GATE #(
      .BubblesMask(2'b00)
  ) GATES_4 (
      .input1(s_tsel_2_0[2]),
      .input2(s_ptst_n),
      .result(s_gates4_out)
  );


  /*******************************************************************************
   ** Here all sub-circuits are defined                                          **
   *******************************************************************************/

  MUX81 TM2 (
      .A (s_gates2_out),
      .B (s_gates3_out),
      .C (s_gates4_out),
      .D0(s_ldirv),
      .D1(s_cbrk_n),
      .D2(s_wpn),
      .D3(s_f15),
      .D4(s_pn),
      .D5(s_ood),
      .D6(s_sc_6_3[2]),
      .D7(s_tvec_3_0[2]),
      .Z (s_test_4_0_out[2])
  );

  MUX81 TM3 (
      .A (s_gates2_out),
      .B (s_gates3_out),
      .C (s_gates4_out),
      .D0(s_vex),
      .D1(s_write_n),
      .D2(s_xfetch_n),
      .D3(s_sgr),
      .D4(s_tn),
      .D5(s_cfetch),
      .D6(s_sc_6_3[3]),
      .D7(s_tvec_3_0[3]),
      .Z (s_test_4_0_out[3])
  );

  MUX81 TM4 (
      .A (s_gates2_out),
      .B (s_gates3_out),
      .C (s_gates4_out),
      .D0(s_power),
      .D1(s_dstop_n),
      .D2(s_power),
      .D3(s_cry),
      .D4(s_power),
      .D5(s_restr),
      .D6(s_deep),
      .D7(s_gnd),
      .Z (s_test_4_0_out[4])
  );

  MUX81 TM0 (
      .A (s_gates2_out),
      .B (s_gates3_out),
      .C (s_gates4_out),
      .D0(s_gates1_out),
      .D1(s_vacc_n),
      .D2(s_mi),
      .D3(s_ovf),
      .D4(s_up_n),
      .D5(s_lcz_n),
      .D6(s_sc_6_3[0]),
      .D7(s_tvec_3_0[0]),
      .Z (s_test_4_0_out[0])
  );

  MUX81 TM1 (
      .A (s_gates2_out),
      .B (s_gates3_out),
      .C (s_gates4_out),
      .D0(s_csmreq),
      .D1(s_ind_n),
      .D2(s_ptm),
      .D3(s_zf),
      .D4(s_cond),
      .D5(s_dzd),
      .D6(s_sc_6_3[1]),
      .D7(s_tvec_3_0[1]),
      .Z (s_test_4_0_out[1])
  );

endmodule

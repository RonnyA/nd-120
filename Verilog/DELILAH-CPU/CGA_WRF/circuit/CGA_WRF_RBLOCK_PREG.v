/**************************************************************************
** ND120 CPU, MM&M                                                       **
** CGA/WRF/RBLOCK/PREG                                                   **
** WRF: Register File                                                    **
** (PDF page 62)                                                         **
**                                                                       **
** Last reviewed: 10-NOV-2024                                            **
** Ronny Hansen                                                          **
***************************************************************************/

module CGA_WRF_RBLOCK_PREG (
    input        ALUCLK,
    input        ALUCLKN,
    input [15:0] NLCA_15_0,
    input [15:0] RB_15_0,
    input        WR2,
    input        XFETCHN,

    output [15:0] PR_15_0,
    output [15:0] P_15_0
);

  wire        s_aluclk_n;
  wire        s_aluclk;
  wire        s_ip0_n;
  wire        s_ip1_n;
  wire        s_ip10_n;
  wire        s_ip11_n;
  wire        s_ip12_n;
  wire        s_ip13_n;
  wire        s_ip14_n;
  wire        s_ip15_n;
  wire        s_ip2_n;
  wire        s_ip3_n;
  wire        s_ip4_n;
  wire        s_ip5_n;
  wire        s_ip6_n;
  wire        s_ip7_n;
  wire        s_ip8_n;
  wire        s_ip9_n;
  wire        s_wr2;
  wire        s_xfetch_n;
  wire        s_xfetch;
  wire [15:0] s_ncla_15_0;
  wire [15:0] s_p_15_0_out;
  wire [15:0] s_pr_15_0_out;
  wire [15:0] s_rb_15_0;


  /*******************************************************************************
   ** Here all input connections are defined                                     **
   *******************************************************************************/
  assign s_rb_15_0[15:0]   = RB_15_0;
  assign s_ncla_15_0[15:0] = NLCA_15_0;
  assign s_wr2             = WR2;
  assign s_aluclk          = ALUCLK;
  assign s_aluclk_n        = ALUCLKN;
  assign s_xfetch_n        = XFETCHN;

  /*******************************************************************************
   ** Here all output connections are defined                                    **
   *******************************************************************************/
  assign PR_15_0           = s_pr_15_0_out[15:0];
  assign P_15_0            = s_p_15_0_out[15:0];

  /*******************************************************************************
   ** Here all in-lined components are defined                                   **
   *******************************************************************************/

  // NOT Gate
  assign s_xfetch          = ~s_xfetch_n;

  /*******************************************************************************
   ** Here all sub-circuits are defined                                          **
   *******************************************************************************/

  /* Bits 0-7, left side on the schematic diagram page 62 */

  MUX31LP R0 (
      .A (s_xfetch),
      .B (s_wr2),
      .D0(s_p_15_0_out[0]),
      .D1(s_ncla_15_0[0]),
      .D2(s_rb_15_0[0]),
      .ZN(s_ip0_n)
  );

  MUX31LP R1 (
      .A (s_xfetch),
      .B (s_wr2),
      .D0(s_p_15_0_out[1]),
      .D1(s_ncla_15_0[1]),
      .D2(s_rb_15_0[1]),
      .ZN(s_ip1_n)
  );

  MUX31LP R2 (
      .A (s_xfetch),
      .B (s_wr2),
      .D0(s_p_15_0_out[2]),
      .D1(s_ncla_15_0[2]),
      .D2(s_rb_15_0[2]),
      .ZN(s_ip2_n)
  );

  MUX31LP R3 (
      .A (s_xfetch),
      .B (s_wr2),
      .D0(s_p_15_0_out[3]),
      .D1(s_ncla_15_0[3]),
      .D2(s_rb_15_0[3]),
      .ZN(s_ip3_n)
  );

  MUX31LP R4 (
      .A (s_xfetch),
      .B (s_wr2),
      .D0(s_p_15_0_out[4]),
      .D1(s_ncla_15_0[4]),
      .D2(s_rb_15_0[4]),
      .ZN(s_ip4_n)
  );

  MUX31LP R5 (
      .A (s_xfetch),
      .B (s_wr2),
      .D0(s_p_15_0_out[5]),
      .D1(s_ncla_15_0[5]),
      .D2(s_rb_15_0[5]),
      .ZN(s_ip5_n)
  );

  MUX31LP R6 (
      .A (s_xfetch),
      .B (s_wr2),
      .D0(s_p_15_0_out[6]),
      .D1(s_ncla_15_0[6]),
      .D2(s_rb_15_0[6]),
      .ZN(s_ip6_n)
  );

  MUX31LP R7 (
      .A (s_xfetch),
      .B (s_wr2),
      .D0(s_p_15_0_out[7]),
      .D1(s_ncla_15_0[7]),
      .D2(s_rb_15_0[7]),
      .ZN(s_ip7_n)
  );

  // verilator lint_off UNUSED
  // verilator lint_off UNDRIVEN
  // verilator lint_off PINCONNECTEMPTY

  // Register P(7:0) (Clocked on s_aluclk)
  R81P R_P_0_7 (
      .A(s_ip0_n),
      .B(s_ip1_n),
      .C(s_ip2_n),
      .D(s_ip3_n),
      .E(s_ip4_n),
      .F(s_ip5_n),
      .G(s_ip6_n),
      .H(s_ip7_n),

      .CP(s_aluclk),

      .QA (),
      .QAN(s_p_15_0_out[0]),
      .QB (),
      .QBN(s_p_15_0_out[1]),
      .QC (),
      .QCN(s_p_15_0_out[2]),
      .QD (),
      .QDN(s_p_15_0_out[3]),
      .QE (),
      .QEN(s_p_15_0_out[4]),
      .QF (),
      .QFN(s_p_15_0_out[5]),
      .QG (),
      .QGN(s_p_15_0_out[6]),
      .QH (),
      .QHN(s_p_15_0_out[7])
  );

  // Latch P(7:0) (Latched on s_aluclk_n)
  L8 L_PR_7_0 (
      .A  (s_ip0_n),
      .B  (s_ip1_n),
      .C  (s_ip2_n),
      .D  (s_ip3_n),
      .E  (s_ip4_n),
      .F  (s_ip5_n),
      .G  (s_ip6_n),
      .H  (s_ip7_n),
      .L  (s_aluclk_n),
      .QA (),
      .QAN(s_pr_15_0_out[0]),
      .QB (),
      .QBN(s_pr_15_0_out[1]),
      .QC (),
      .QCN(s_pr_15_0_out[2]),
      .QD (),
      .QDN(s_pr_15_0_out[3]),
      .QE (),
      .QEN(s_pr_15_0_out[4]),
      .QF (),
      .QFN(s_pr_15_0_out[5]),
      .QG (),
      .QGN(s_pr_15_0_out[6]),
      .QH (),
      .QHN(s_pr_15_0_out[7])
  );

  /* Bits 8-15, right side on the schematic diagram page 62 */

  MUX31LP R8 (
      .A (s_xfetch),
      .B (s_wr2),
      .D0(s_p_15_0_out[8]),
      .D1(s_ncla_15_0[8]),
      .D2(s_rb_15_0[8]),
      .ZN(s_ip8_n)
  );

  MUX31LP R9 (
      .A (s_xfetch),
      .B (s_wr2),
      .D0(s_p_15_0_out[9]),
      .D1(s_ncla_15_0[9]),
      .D2(s_rb_15_0[9]),
      .ZN(s_ip9_n)
  );

  MUX31LP R10 (
      .A (s_xfetch),
      .B (s_wr2),
      .D0(s_p_15_0_out[10]),
      .D1(s_ncla_15_0[10]),
      .D2(s_rb_15_0[10]),
      .ZN(s_ip10_n)
  );

  MUX31LP R11 (
      .A (s_xfetch),
      .B (s_wr2),
      .D0(s_p_15_0_out[11]),
      .D1(s_ncla_15_0[11]),
      .D2(s_rb_15_0[11]),
      .ZN(s_ip11_n)
  );

  MUX31LP R12 (
      .A (s_xfetch),
      .B (s_wr2),
      .D0(s_p_15_0_out[12]),
      .D1(s_ncla_15_0[12]),
      .D2(s_rb_15_0[12]),
      .ZN(s_ip12_n)
  );

  MUX31LP R13 (
      .A (s_xfetch),
      .B (s_wr2),
      .D0(s_p_15_0_out[13]),
      .D1(s_ncla_15_0[13]),
      .D2(s_rb_15_0[13]),
      .ZN(s_ip13_n)
  );

  MUX31LP R14 (
      .A (s_xfetch),
      .B (s_wr2),
      .D0(s_p_15_0_out[14]),
      .D1(s_ncla_15_0[14]),
      .D2(s_rb_15_0[14]),
      .ZN(s_ip14_n)
  );

  MUX31LP R15 (
      .A (s_xfetch),
      .B (s_wr2),
      .D0(s_p_15_0_out[15]),
      .D1(s_ncla_15_0[15]),
      .D2(s_rb_15_0[15]),
      .ZN(s_ip15_n)
  );

  R81P R_P_8_15 (
      .A(s_ip8_n),
      .B(s_ip9_n),
      .C(s_ip10_n),
      .D(s_ip11_n),
      .E(s_ip12_n),
      .F(s_ip13_n),
      .G(s_ip14_n),
      .H(s_ip15_n),

      .CP(s_aluclk),

      .QA (),
      .QAN(s_p_15_0_out[8]),
      .QB (),
      .QBN(s_p_15_0_out[9]),
      .QC (),
      .QCN(s_p_15_0_out[10]),
      .QD (),
      .QDN(s_p_15_0_out[11]),
      .QE (),
      .QEN(s_p_15_0_out[12]),
      .QF (),
      .QFN(s_p_15_0_out[13]),
      .QG (),
      .QGN(s_p_15_0_out[14]),
      .QH (),
      .QHN(s_p_15_0_out[15])
  );

  L8 L_PR_8_15 (
      .A(s_ip8_n),
      .B(s_ip9_n),
      .C(s_ip10_n),
      .D(s_ip11_n),
      .E(s_ip12_n),
      .F(s_ip13_n),
      .G(s_ip14_n),
      .H(s_ip15_n),

      .L(s_aluclk_n),

      .QA (),
      .QAN(s_pr_15_0_out[8]),
      .QB (),
      .QBN(s_pr_15_0_out[9]),
      .QC (),
      .QCN(s_pr_15_0_out[10]),
      .QD (),
      .QDN(s_pr_15_0_out[11]),
      .QE (),
      .QEN(s_pr_15_0_out[12]),
      .QF (),
      .QFN(s_pr_15_0_out[13]),
      .QG (),
      .QGN(s_pr_15_0_out[14]),
      .QH (),
      .QHN(s_pr_15_0_out[15])
  );

endmodule

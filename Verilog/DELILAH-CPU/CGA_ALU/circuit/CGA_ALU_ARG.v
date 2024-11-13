
/**************************************************************************
** ND120 CGA (CPU Gate Array / DELILAH)                                  **
** /CGA/ALU/ARG                                                          **
** A REGISTER                                                            **
**                                                                       **
** Page 53                                                               **
** SHEET 1 of 1                                                          **
**                                                                       **
** Last reviewed: 10-NOV-2024                                            **
** Ronny Hansen                                                          **
***************************************************************************/

module CGA_ALU_ARG (
    input        ALUCLK,
    input [15:0] CSBIT_15_0,

    output [15:0] ARG_15_0
);

  /*******************************************************************************
   ** The wires are defined here                                                 **
   *******************************************************************************/
  wire [15:0] s_csbits_15_0;
  wire [15:0] s_arg_15_0_out;
  wire        s_aluclk;

  /*******************************************************************************
   ** Here all input connections are defined                                     **
   *******************************************************************************/
  assign s_csbits_15_0[15:0] = CSBIT_15_0;
  assign s_aluclk            = ALUCLK;

  /*******************************************************************************
   ** Here all output connections are defined                                    **
   *******************************************************************************/
  assign ARG_15_0            = s_arg_15_0_out[15:0];

  /*******************************************************************************
   ** Here all sub-circuits are defined                                          **
   *******************************************************************************/

  R81 ARG_HI_REG (
      .CP(s_aluclk),

      .A(s_csbits_15_0[15]),
      .B(s_csbits_15_0[14]),
      .C(s_csbits_15_0[13]),
      .D(s_csbits_15_0[12]),
      .E(s_csbits_15_0[11]),
      .F(s_csbits_15_0[10]),
      .G(s_csbits_15_0[9]),
      .H(s_csbits_15_0[8]),

      .QA (s_arg_15_0_out[15]),
      .QAN(),
      .QB (s_arg_15_0_out[14]),
      .QBN(),
      .QC (s_arg_15_0_out[13]),
      .QCN(),
      .QD (s_arg_15_0_out[12]),
      .QDN(),
      .QE (s_arg_15_0_out[11]),
      .QEN(),
      .QF (s_arg_15_0_out[10]),
      .QFN(),
      .QG (s_arg_15_0_out[9]),
      .QGN(),
      .QH (s_arg_15_0_out[8]),
      .QHN()
  );

  R81 ARG_LO_REG (
      .CP(s_aluclk),
      .A (s_csbits_15_0[7]),
      .B (s_csbits_15_0[6]),
      .C (s_csbits_15_0[5]),
      .D (s_csbits_15_0[4]),
      .E (s_csbits_15_0[3]),
      .F (s_csbits_15_0[2]),
      .G (s_csbits_15_0[1]),
      .H (s_csbits_15_0[0]),

      .QA (s_arg_15_0_out[7]),
      .QAN(),
      .QB (s_arg_15_0_out[6]),
      .QBN(),
      .QC (s_arg_15_0_out[5]),
      .QCN(),
      .QD (s_arg_15_0_out[4]),
      .QDN(),
      .QE (s_arg_15_0_out[3]),
      .QEN(),
      .QF (s_arg_15_0_out[2]),
      .QFN(),
      .QG (s_arg_15_0_out[1]),
      .QGN(),
      .QH (s_arg_15_0_out[0]),
      .QHN()
  );



endmodule

/**************************************************************************
** ND120 CGA (CPU Gate Array / DELILAH)                                  **
** /CGA/ALU/SWAP                                                         **
** SWAP REGISTER                                                         **
**                                                                       **
** Page 51                                                               **
** SHEET 1 of 1                                                          **
**                                                                       **
** Last reviewed: 10-NOV-2024                                            **
** Ronny Hansen                                                          **
***************************************************************************/


module CGA_ALU_SWAP (
    input        ALUCLK,
    input [15:0] FIDBO_15_0,

    output [15:0] SW_15_0
);

  /*******************************************************************************
   ** The wires are defined here                                                 **
   *******************************************************************************/
  wire [15:0] s_fidbo_15_0;
  wire [15:0] s_sw_15_0_out;
  wire        s_aluclk;
 
  /*******************************************************************************
   ** Here all input connections are defined                                     **
   *******************************************************************************/
  assign s_fidbo_15_0[15:0] = FIDBO_15_0;
  assign s_aluclk           = ALUCLK;

  /*******************************************************************************
   ** Here all output connections are defined                                    **
   *******************************************************************************/
  assign SW_15_0            = s_sw_15_0_out[15:0];

  /*******************************************************************************
   ** Here all sub-circuits are defined                                          **
   *******************************************************************************/

  R81 SWAP_LO_REG (
      .CP (s_aluclk),
      .A  (s_fidbo_15_0[15]),
      .B  (s_fidbo_15_0[14]),
      .C  (s_fidbo_15_0[13]),
      .D  (s_fidbo_15_0[12]),
      .E  (s_fidbo_15_0[11]),
      .F  (s_fidbo_15_0[10]),
      .G  (s_fidbo_15_0[9]),
      .H  (s_fidbo_15_0[8]),
      .QA (s_sw_15_0_out[7]),
      .QAN(),
      .QB (s_sw_15_0_out[6]),
      .QBN(),
      .QC (s_sw_15_0_out[5]),
      .QCN(),
      .QD (s_sw_15_0_out[4]),
      .QDN(),
      .QE (s_sw_15_0_out[3]),
      .QEN(),
      .QF (s_sw_15_0_out[2]),
      .QFN(),
      .QG (s_sw_15_0_out[1]),
      .QGN(),
      .QH (s_sw_15_0_out[0]),
      .QHN()
  );

  R81 SWAP_HI_REG (
      .CP (s_aluclk),
      .A  (s_fidbo_15_0[7]),
      .B  (s_fidbo_15_0[6]),
      .C  (s_fidbo_15_0[5]),
      .D  (s_fidbo_15_0[4]),
      .E  (s_fidbo_15_0[3]),
      .F  (s_fidbo_15_0[2]),
      .G  (s_fidbo_15_0[1]),
      .H  (s_fidbo_15_0[0]),
      .QA (s_sw_15_0_out[15]),
      .QAN(),
      .QB (s_sw_15_0_out[14]),
      .QBN(),
      .QC (s_sw_15_0_out[13]),
      .QCN(),
      .QD (s_sw_15_0_out[12]),
      .QDN(),
      .QE (s_sw_15_0_out[11]),
      .QEN(),
      .QF (s_sw_15_0_out[10]),
      .QFN(),
      .QG (s_sw_15_0_out[9]),
      .QGN(),
      .QH (s_sw_15_0_out[8]),
      .QHN()
  );

endmodule

/**************************************************************************
** ND120 CGA (CPU Gate Array / DELILAH)                                  **
** /CGA/INTR/CNTLR/VECGEN/VHR                                            **
** VHR                                                                   **
**                                                                       **
** Page 86                                                               **
** SHEET 1 of 1                                                          **
**                                                                       **
** Last reviewed: 10-NOV-2024                                            **
** Ronny Hansen                                                          **
***************************************************************************/

module CGA_INTR_CNTLR_VECGEN_VHR (
    input [2:0] HIVEC_2_0,
    input [2:0] LOVEC_2_0,
    input       MCLK,
    input       N,

    output [2:0] HX_2_0,
    output [2:0] HX_2_0_N,
    output [2:0] LX_2_0,
    output [2:0] LX_2_0_N
);

  /*******************************************************************************
   ** The wires are defined here                                                 **
   *******************************************************************************/
  wire [2:0] s_hivec_2_0;
  wire [2:0] s_hx_2_0_n_out;
  wire [2:0] s_hx_2_0_out;
  wire [2:0] s_lovec_2_0;
  wire [2:0] s_lx_2_0_n_out;
  wire [2:0] s_lx_2_0_out;
  wire       s_mclk;
  wire       s_n;

  /*******************************************************************************
   ** The module functionality is described here                                 **
   *******************************************************************************/

  /*******************************************************************************
   ** Here all input connections are defined                                     **
   *******************************************************************************/
  assign s_lovec_2_0[2:0] = LOVEC_2_0;
  assign s_hivec_2_0[2:0] = HIVEC_2_0;
  assign s_n              = N;
  assign s_mclk           = MCLK;

  /*******************************************************************************
   ** Here all output connections are defined                                    **
   *******************************************************************************/
  assign HX_2_0           = s_hx_2_0_out[2:0];
  assign HX_2_0_N         = s_hx_2_0_n_out[2:0];
  assign LX_2_0           = s_lx_2_0_out[2:0];
  assign LX_2_0_N         = s_lx_2_0_n_out[2:0];

  /*******************************************************************************
   ** Here all sub-circuits are defined                                          **
   *******************************************************************************/

  SCAN_FF HX1 (
      .CLK(s_mclk),
      .D  (s_hivec_2_0[1]),
      .Q  (s_hx_2_0_out[1]),
      .QN (s_hx_2_0_n_out[1]),
      .TE (s_n),
      .TI (s_hx_2_0_out[1])
  );

  SCAN_FF HX2 (
      .CLK(s_mclk),
      .D  (s_hivec_2_0[2]),
      .Q  (s_hx_2_0_out[2]),
      .QN (s_hx_2_0_n_out[2]),
      .TE (s_n),
      .TI (s_hx_2_0_out[2])
  );

  SCAN_FF LX1 (
      .CLK(s_mclk),
      .D  (s_lovec_2_0[1]),
      .Q  (s_lx_2_0_out[1]),
      .QN (s_lx_2_0_n_out[1]),
      .TE (s_n),
      .TI (s_lx_2_0_out[1])
  );

  SCAN_FF HX0 (
      .CLK(s_mclk),
      .D  (s_hivec_2_0[0]),
      .Q  (s_hx_2_0_out[0]),
      .QN (s_hx_2_0_n_out[0]),
      .TE (s_n),
      .TI (s_hx_2_0_out[0])
  );

  SCAN_FF LX2 (
      .CLK(s_mclk),
      .D  (s_lovec_2_0[2]),
      .Q  (s_lx_2_0_out[2]),
      .QN (s_lx_2_0_n_out[2]),
      .TE (s_n),
      .TI (s_lx_2_0_out[2])
  );

  SCAN_FF LX0 (
      .CLK(s_mclk),
      .D  (s_lovec_2_0[0]),
      .Q  (s_lx_2_0_out[0]),
      .QN (s_lx_2_0_n_out[0]),
      .TE (s_n),
      .TI (s_lx_2_0_out[0])
  );

endmodule

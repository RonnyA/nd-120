/**************************************************************************
** CPU GATE ARRAY - CGA - DELILAH                                        **
**                                                                       **
** CGA/IDBCTL/PGSREG - IDB Control Logic                                 **
**                                                                       **
** PDF page 98 of 108                                                    **
**                                                                       **
** Last reviewed: 9-NOV-2024                                             **
** Ronny Hansen                                                          **
***************************************************************************/



module CGA_IDBCTL_PGSREG (
    input FETCHN,
    input [11:0] LA_21_10,
    input MCLK,
    input PVIOL,
    input VACCN,

    output [11:0] PGS_11_0,
    output [ 1:0] PGS_15_14
);

  /*******************************************************************************
   ** The wires are defined here                                                 **
   *******************************************************************************/
  wire        s_fetch_n;
  wire        s_mclk;
  wire        s_pgs15_dq;
  wire        s_pviol;
  wire        s_vacc_n;
  wire        s_vacc;
  wire [ 1:0] s_pga_15_14_out;
  wire [11:0] s_la_21_10;
  wire [11:0] s_pgs_11_0_out;

  /*******************************************************************************
   ** Here all input connections are defined                                     **
   *******************************************************************************/
  assign s_la_21_10[11:0] = LA_21_10;
  assign s_mclk           = MCLK;
  assign s_fetch_n        = FETCHN;
  assign s_pviol          = PVIOL;
  assign s_vacc_n         = VACCN;

  /*******************************************************************************
   ** Here all output connections are defined                                    **
   *******************************************************************************/
  assign PGS_11_0         = s_pgs_11_0_out[11:0];
  assign PGS_15_14        = s_pga_15_14_out[1:0];

  /*******************************************************************************
   ** Here all in-lined components are defined                                   **
   *******************************************************************************/

  // NOT Gate
  assign s_vacc    = ~s_vacc_n;

  /*******************************************************************************
   ** Here all sub-circuits are defined                                          **
   *******************************************************************************/


  SCAN_FF PGS15 (
      .CLK(s_mclk),
      .D  (s_pgs15_dq),
      .Q  (s_pgs15_dq),
      .QN (s_pga_15_14_out[1]),
      .TE (s_vacc),
      .TI (s_fetch_n)
  );

  SCAN_FF PGS14 (
      .CLK(s_mclk),
      .D  (s_pga_15_14_out[0]),
      .Q  (s_pga_15_14_out[0]),
      .QN (),
      .TE (s_vacc),
      .TI (s_pviol)
  );

  SCAN_FF PGS11 (
      .CLK(s_mclk),
      .D  (s_pgs_11_0_out[11]),
      .Q  (s_pgs_11_0_out[11]),
      .QN (),
      .TE (s_vacc),
      .TI (s_la_21_10[11])
  );

  SCAN_FF PGS10 (
      .CLK(s_mclk),
      .D  (s_pgs_11_0_out[10]),
      .Q  (s_pgs_11_0_out[10]),
      .QN (),
      .TE (s_vacc),
      .TI (s_la_21_10[10])
  );

  SCAN_FF PGS9 (
      .CLK(s_mclk),
      .D  (s_pgs_11_0_out[9]),
      .Q  (s_pgs_11_0_out[9]),
      .QN (),
      .TE (s_vacc),
      .TI (s_la_21_10[9])
  );

  SCAN_FF PGS8 (
      .CLK(s_mclk),
      .D  (s_pgs_11_0_out[8]),
      .Q  (s_pgs_11_0_out[8]),
      .QN (),
      .TE (s_vacc),
      .TI (s_la_21_10[8])
  );

  SCAN_FF PGS7 (
      .CLK(s_mclk),
      .D  (s_pgs_11_0_out[7]),
      .Q  (s_pgs_11_0_out[7]),
      .QN (),
      .TE (s_vacc),
      .TI (s_la_21_10[7])
  );


  SCAN_FF PGS3 (
      .CLK(s_mclk),
      .D  (s_pgs_11_0_out[3]),
      .Q  (s_pgs_11_0_out[3]),
      .QN (),
      .TE (s_vacc),
      .TI (s_la_21_10[3])
  );

  SCAN_FF PGS2 (
      .CLK(s_mclk),
      .D  (s_pgs_11_0_out[2]),
      .Q  (s_pgs_11_0_out[2]),
      .QN (),
      .TE (s_vacc),
      .TI (s_la_21_10[2])
  );

  SCAN_FF PGS1 (
      .CLK(s_mclk),
      .D  (s_pgs_11_0_out[1]),
      .Q  (s_pgs_11_0_out[1]),
      .QN (),
      .TE (s_vacc),
      .TI (s_la_21_10[1])
  );

  SCAN_FF PGS0 (
      .CLK(s_mclk),
      .D  (s_pgs_11_0_out[0]),
      .Q  (s_pgs_11_0_out[0]),
      .QN (),
      .TE (s_vacc),
      .TI (s_la_21_10[0])
  );

  SCAN_FF PGS6 (
      .CLK(s_mclk),
      .D  (s_pgs_11_0_out[6]),
      .Q  (s_pgs_11_0_out[6]),
      .QN (),
      .TE (s_vacc),
      .TI (s_la_21_10[6])
  );

  SCAN_FF PGS5 (
      .CLK(s_mclk),
      .D  (s_pgs_11_0_out[5]),
      .Q  (s_pgs_11_0_out[5]),
      .QN (),
      .TE (s_vacc),
      .TI (s_la_21_10[5])
  );

  SCAN_FF PGS4 (
      .CLK(s_mclk),
      .D  (s_pgs_11_0_out[4]),
      .Q  (s_pgs_11_0_out[4]),
      .QN (),
      .TE (s_vacc),
      .TI (s_la_21_10[4])
  );

endmodule

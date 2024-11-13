/**************************************************************************
** ND120 CGA (CPU Gate Array / DELILAH)                                  **
** /CGA/MIC/WCAREG                                                       **
** WCAREG                                                                **
**                                                                       **
** Page 21                                                               **
** SHEET 1 of 1                                                          **
**                                                                       **
** Last reviewed: 10-NOV-2024                                            **
** Ronny Hansen                                                          **
***************************************************************************/

module CGA_MIC_WCAREG (
    input [15:0] CD_15_0,
    input        LCSN,
    input        LWCAN,
    input        MCLK,

    output [12:0] WCA_12_0,
    output        WCSN
);

  /*******************************************************************************
   ** The wires are defined here                                                 **
   *******************************************************************************/
  wire [15:0] s_cd_15_0;
  wire [12:0] s_wca_12_0_out;
  wire        s_lcs_n;
  wire        s_lwca_n;
  wire        s_lwca;
  wire        s_mclk;
  wire        s_wca13_n;
  wire        s_wcs_n_out;
  wire        s_wcsnff_out_q;

  /*******************************************************************************
   ** Here all input connections are defined                                     **
   *******************************************************************************/
  assign s_cd_15_0[15:0] = CD_15_0;
  assign s_mclk          = MCLK;
  assign s_lcs_n         = LCSN;
  assign s_lwca_n        = LWCAN;

  /*******************************************************************************
   ** Here all output connections are defined                                    **
   *******************************************************************************/
  assign WCA_12_0        = s_wca_12_0_out[12:0];
  assign WCSN            = s_wcs_n_out;

  /*******************************************************************************
   ** Here all in-lined components are defined                                   **
   *******************************************************************************/

  // NOT Gate
  assign s_lwca          = ~s_lwca_n;

  /*******************************************************************************
   ** Here all normal components are defined                                     **
   *******************************************************************************/
  NOR_GATE #(
      .BubblesMask(2'b11)
  ) GATES_1 (
      .input1(s_wca13_n),
      .input2(s_lcs_n),
      .result(s_wcs_n_out)
  );


  /*******************************************************************************
   ** Here all sub-circuits are defined                                          **
   *******************************************************************************/
  SCAN_FF WCAFF12 (
      .CLK(s_mclk),
      .D  (s_wca_12_0_out[12]),
      .Q  (s_wca_12_0_out[12]),
      .QN (),
      .TE (s_lwca),
      .TI (s_cd_15_0[14])
  );

  SCAN_FF WCAFF11 (
      .CLK(s_mclk),
      .D  (s_wca_12_0_out[11]),
      .Q  (s_wca_12_0_out[11]),
      .QN (),
      .TE (s_lwca),
      .TI (s_cd_15_0[13])
  );

  SCAN_FF WCAFF10 (
      .CLK(s_mclk),
      .D  (s_wca_12_0_out[10]),
      .Q  (s_wca_12_0_out[10]),
      .QN (),
      .TE (s_lwca),
      .TI (s_cd_15_0[12])
  );

  SCAN_FF WCAFF9 (
      .CLK(s_mclk),
      .D  (s_wca_12_0_out[9]),
      .Q  (s_wca_12_0_out[9]),
      .QN (),
      .TE (s_lwca),
      .TI (s_cd_15_0[11])
  );

  SCAN_FF WCAFF8 (
      .CLK(s_mclk),
      .D  (s_wca_12_0_out[8]),
      .Q  (s_wca_12_0_out[8]),
      .QN (),
      .TE (s_lwca),
      .TI (s_cd_15_0[10])
  );

  SCAN_FF WCAFF7 (
      .CLK(s_mclk),
      .D  (s_wca_12_0_out[7]),
      .Q  (s_wca_12_0_out[7]),
      .QN (),
      .TE (s_lwca),
      .TI (s_cd_15_0[9])
  );

  SCAN_FF WCAFF6 (
      .CLK(s_mclk),
      .D  (s_wca_12_0_out[6]),
      .Q  (s_wca_12_0_out[6]),
      .QN (),
      .TE (s_lwca),
      .TI (s_cd_15_0[8])
  );

  SCAN_FF WCAFF5 (
      .CLK(s_mclk),
      .D  (s_wca_12_0_out[5]),
      .Q  (s_wca_12_0_out[5]),
      .QN (),
      .TE (s_lwca),
      .TI (s_cd_15_0[7])
  );

  SCAN_FF WCAFF4 (
      .CLK(s_mclk),
      .D  (s_wca_12_0_out[4]),
      .Q  (s_wca_12_0_out[4]),
      .QN (),
      .TE (s_lwca),
      .TI (s_cd_15_0[6])
  );

  SCAN_FF WCAFF3 (
      .CLK(s_mclk),
      .D  (s_wca_12_0_out[3]),
      .Q  (s_wca_12_0_out[3]),
      .QN (),
      .TE (s_lwca),
      .TI (s_cd_15_0[5])
  );

  SCAN_FF WCAFF2 (
      .CLK(s_mclk),
      .D  (s_wca_12_0_out[2]),
      .Q  (s_wca_12_0_out[2]),
      .QN (),
      .TE (s_lwca),
      .TI (s_cd_15_0[4])
  );

  SCAN_FF WCAFF1 (
      .CLK(s_mclk),
      .D  (s_wca_12_0_out[1]),
      .Q  (s_wca_12_0_out[1]),
      .QN (),
      .TE (s_lwca),
      .TI (s_cd_15_0[3])
  );

  SCAN_FF WCAFF0 (
      .CLK(s_mclk),
      .D  (s_wca_12_0_out[0]),
      .Q  (s_wca_12_0_out[0]),
      .QN (),
      .TE (s_lwca),
      .TI (s_cd_15_0[2])
  );

  SCAN_FF WCSNFF (
      .CLK(s_mclk),
      .D  (s_wcsnff_out_q),
      .Q  (s_wcsnff_out_q),
      .QN (s_wca13_n),
      .TE (s_lwca),
      .TI (s_cd_15_0[15])
  );



endmodule

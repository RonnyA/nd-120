/**************************************************************************
** ND120 CPU, MM&M                                                       **
** BIF/DPATH/CDLBD                                                       **
** BIF CD TO LBD                                                         **
** SHEET 11 of 50                                                        **
**                                                                       **
** Last reviewed: 20-DEC-2024                                            **
** Ronny Hansen                                                          **
***************************************************************************/

module BIF_DPATH_CDLBD_11 (
    input DSTB_n,  //! Data Strobe
    input ECREQ,   //! Enable CPU Request
    input EMD_n,   //! Enable Memory
    input WLBD_n,  //! Write Local Bus Data

    input  [15:0] LBD_15_0_IN,  //! Local Bus Data Input (16 bits)
    output [15:0] LBD_15_0_OUT, //! Local Bus Data Output (16 bits)

    input  [15:0] CD_15_0_IN,  //! CPU Data Input (16 bits)
    output [15:0] CD_15_0_OUT  //! CPU Data Output (16 bits)
);


  // Seems like the signal CD15-0 is pulled high if the B port on the 74AS646 is in high state
  // Which happens when signal EMD_n is high


  /*******************************************************************************
   ** The wires are defined here                                                 **
   *******************************************************************************/
  wire [15:0] s_cd_15_0_in;
  wire [15:0] s_cd_15_0_out;

  wire [15:0] s_lbd_15_0_in;
  wire [15:0] s_lbd_15_0_out;

  wire        s_wlbd;
  wire        s_ecreq;
  wire        s_dstb_n;
  wire        s_emd_n;
  wire        s_sba;

  /*******************************************************************************
   ** Here all input connections are defined                                     **
   *******************************************************************************/
  assign s_lbd_15_0_in[15:0] = LBD_15_0_IN[15:0];
  assign s_cd_15_0_in[15:0] = CD_15_0_IN[15:0];
  assign s_wlbd = WLBD_n;
  assign s_ecreq = ECREQ;
  assign s_dstb_n = DSTB_n;
  assign s_emd_n = EMD_n;

  /*******************************************************************************
   ** Here all output connections are defined                                    **
   *******************************************************************************/

  // Set CD_15_0 to 0 if EMD_n is high (3state)
  assign CD_15_0_OUT[15:0] = EMD_n ? 16'b0 : s_cd_15_0_out[15:0];
  assign LBD_15_0_OUT[15:0] = s_lbd_15_0_out[15:0];


  // Signal SBA is connecte to Power
  assign s_sba = 1'b1;


  /*******************************************************************************
   ** Here all sub-circuits are defined                                          **
   *******************************************************************************/

  TTL_74646 CHIP_7B (
      .A_IN (s_lbd_15_0_in[15:8]),
      .A_OUT(s_lbd_15_0_out[15:8]),
      .B_IN (s_cd_15_0_in[15:8]),
      .B_OUT(s_cd_15_0_out[15:8]),

      .CLKAB(s_dstb_n),
      .CLKBA(s_ecreq),

      .SAB(s_dstb_n),
      .SBA(s_sba),

      .DIR (s_wlbd),
      .OE_n(s_emd_n)
  );

  TTL_74646 CHIP_6B (
      .A_IN (s_lbd_15_0_in[7:0]),
      .A_OUT(s_lbd_15_0_out[7:0]),
      .B_IN (s_cd_15_0_in[7:0]),
      .B_OUT(s_cd_15_0_out[7:0]),

      .CLKAB(s_dstb_n),
      .CLKBA(s_ecreq),

      .SAB(s_dstb_n),
      .SBA(s_sba),

      .DIR (s_wlbd),
      .OE_n(s_emd_n)
  );

endmodule


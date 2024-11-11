/**************************************************************************
** ND120 CPU, MM&M                                                       **
** MEM/LBDIF                                                             **
** LOCAL BD CONTROL                                                      **
** SHEET 48 of 50                                                        **
**                                                                       **
** Last reviewed: 21-APRIL-2024                                          **
** Ronny Hansen                                                          **
***************************************************************************/

module MEM_LBDIF_48 (
    input BCGNT25,   //! Input BCGNT25
    input BDAP50_n,  //! Input BDAP50_n
    input BGNT_n,    //! Input BGNT_n
    input BIOXE_n,   //! Input BIOXE_n
    input BLOCKL_n,  //! Input BLOCKL_n
    input BLRQ_n,    //! Input BLRQ_n
    input CGNT_n,    //! Input CGNT_n
    input ECCR,      //! Input ECCR
    input GNT_n,     //! Input GNT_n
    input HIEN_n,    //! Input HIEN_n
    input LOEN_n,    //! Input LOEN_n
    input MOR_n,     //! Input MOR_n - Memory Off
    input MR_n,      //! Input MR_n
    input MWRITE_n,  //! Input MWRITE_n
    input OSC,       //! Input OSC
    input PD4,       //! Input PD4
    input RAS,       //! Input RAS
    input REF_n,     //! Input REF_n

    output BCGNT50,     //! Output BCGNT50 (BCGNT delayed 50 ns)
    output BCGNT50R_n,  //! Output BCGNT50R_n
    output BDRY_n,      //! Output BDRY_n
    output BGNT25_n,    //! Output BGNT25_n (BGNT25_n, BGNT_n delayed 25 ns)
    output BGNT50_n,    //! Output BGNT50_n (BGNT50_n, BGNT_n delayed 25 ns)
    output BIOXL_n,     //! Output BIOXL_n
    output BLOCKL25_n,  //! Output BLOCKL25_n
    output BLRQ50_n,    //! Output BLRQ50_n
    output CGNT25_n,    //! Output CGNT25_n
    output CGNT50_n,    //! Output CGNT50_n
    output GNT50_n,     //! Output GNT50_n
    output MOR25_n,     //! Output MOR25_n
    output MWRITE50_n,  //! Output MWRITE50_n
    output RDATA,       //! Output RDATA
    output RDATA25      //! Output RDATA25
);

  /*******************************************************************************
   ** The wires are defined here                                                 **
   *******************************************************************************/
  wire s_13f_y0;
  wire s_14f_y1;
  wire s_14f_y3;
  wire s_14f_y4;
  wire s_14f_y5;
  wire s_14f_y8;
  wire s_bcgnt25;
  wire s_bcgnt50_out;
  wire s_bcgnt50r_n_out;
  wire s_bdap50_n;
  wire s_bdry_n_out;
  wire s_bgnt_n;
  wire s_bgnt50_n_out;
  wire s_bgnt50_n;
  wire s_bgnt75_n;
  wire s_bioxe_n;
  wire s_bioxl_n_out;
  wire s_blockl_n;
  wire s_blockl25_n_out;
  wire s_blrq_n;
  wire s_blrq50_n_out;
  wire s_cgnt_n;
  wire s_cgnt25_n_out;
  wire s_cgnt50_n_out;
  wire s_eccr;
  wire s_gnt_n;
  wire s_gnt50_n_out;
  wire s_hien_n;
  wire s_loen_n;
  wire s_mor_n;
  wire s_mor25_n_out;
  wire s_mr_n;
  wire s_mwrite_n;
  wire s_mwrite50_n;
  wire s_osc;
  wire s_pd4;
  wire s_ras;
  wire s_rdata_out;
  wire s_rdata25_out;
  wire s_ref_100_n;
  wire s_ref_n;

  wire [9:0] chip13_d;
  wire [9:0] chip13_y;

  wire [9:0] chip14_d;
  wire [9:0] chip14_y;

  /*******************************************************************************
   ** Here all input connections are defined                                     **
   *******************************************************************************/
  assign s_hien_n       = HIEN_n;
  assign s_pd4          = PD4;
  assign s_eccr         = ECCR;
  assign s_loen_n       = LOEN_n;
  assign s_blrq_n       = BLRQ_n;
  assign s_mwrite_n     = MWRITE_n;
  assign s_ref_n        = REF_n;
  assign s_mor_n        = MOR_n;
  assign s_bgnt_n       = BGNT_n;
  assign s_mr_n         = MR_n;
  assign s_bioxe_n      = BIOXE_n;
  assign s_bdap50_n     = BDAP50_n;
  assign s_bcgnt25      = BCGNT25;
  assign s_ras          = RAS;
  assign s_blockl_n     = BLOCKL_n;
  assign s_gnt_n        = GNT_n;
  assign s_osc          = OSC;
  assign s_cgnt_n       = CGNT_n;

  /*******************************************************************************
   ** Here all output connections are defined                                    **
   *******************************************************************************/
  assign BCGNT50        = s_bcgnt50_out;
  assign BCGNT50R_n     = s_bcgnt50r_n_out;
  assign BDRY_n         = s_bdry_n_out;
  assign BGNT25_n       = s_bgnt50_n_out;
  assign BGNT50_n       = s_bgnt50_n;
  assign BIOXL_n        = s_bioxl_n_out;
  assign BLOCKL25_n     = s_blockl25_n_out;
  assign BLRQ50_n       = s_blrq50_n_out;
  assign CGNT25_n       = s_cgnt25_n_out;
  assign CGNT50_n       = s_cgnt50_n_out;
  assign GNT50_n        = s_gnt50_n_out;
  assign MOR25_n        = s_mor25_n_out;
  assign MWRITE50_n     = s_mwrite50_n;
  assign RDATA          = s_rdata_out;
  assign RDATA25        = s_rdata25_out;

  /*******************************************************************************
   ** Here all sub-circuits are defined                                          **
   *******************************************************************************/

  /************ CHIP 13F ************/

  /*

      // Input
      .D0(s_blrq_n),
      .D1(s_13f_y0),
      .D2(s_rdata_out),
      .D3(1'b0), // n.c.
      .D4(s_cgnt_n),
      .D5(s_cgnt25_n_out),
      .D6(s_bgnt_n),
      .D7(s_bgnt50_n_out),
      .D8(s_bgnt50_n),
      .D9(s_bcgnt25),

      // Output
      .Y0(s_13f_y0),
      .Y1(s_blrq50_n_out),
      .Y2(s_rdata25_out),
      .Y3(),
      .Y4(s_cgnt25_n_out),
      .Y5(s_cgnt50_n_out),
      .Y6(s_bgnt50_n_out),
      .Y7(s_bgnt50_n),
      .Y8(s_bgnt75_n),
      .Y9(s_bcgnt50_out)

  */

  // D - 10 Input signals
  assign chip13_d[0]    = s_blrq_n;
  assign chip13_d[1]    = s_13f_y0;
  assign chip13_d[2]    = s_rdata_out;
  assign chip13_d[3]    = 1'b0;
  assign chip13_d[4]    = s_cgnt_n;
  assign chip13_d[5]    = s_cgnt25_n_out;  // y4 looped back
  assign chip13_d[6]    = s_bgnt_n;
  assign chip13_d[7]    = s_bgnt50_n_out;  // y6 looped back
  assign chip13_d[8]    = s_bgnt50_n;  // y7 looped back
  assign chip13_d[9]    = s_bcgnt25;

  // Y - 10 Output signals
  assign s_13f_y0       = chip13_y[0];
  assign s_blrq50_n_out = chip13_y[1];
  assign s_rdata25_out  = chip13_y[2];
  //assign nc  = chip13_y[3];
  assign s_cgnt25_n_out = chip13_y[4];
  assign s_cgnt50_n_out = chip13_y[5];
  assign s_bgnt50_n_out = chip13_y[6];
  assign s_bgnt50_n     = chip13_y[7];
  assign s_bgnt75_n     = chip13_y[8];
  assign s_bcgnt50_out  = chip13_y[9];

  AM29C821 CHIP_13F (
      .CK(s_osc),
      .OE_n(s_pd4),
      .D(chip13_d),
      .Y(chip13_y)
  );



  /************ CHIP 14F ************/
  /*
      .D0  (s_blockl_n),
      .D1  (s_mwrite_n),
      .D2  (s_14f_y1),
      .D3  (s_ref_n),
      .D4  (s_14f_y3),
      .D5  (s_14f_y4),
      .D6  (s_14f_y5),
      .D7  (s_mor_n),
      .D8  (s_gnt_n),
      .D9  (s_14f_y8),

      .Y0  (s_blockl25_n_out),
      .Y1  (s_14f_y1),
      .Y2  (s_mwrite50_n),
      .Y3  (s_14f_y3),
      .Y4  (s_14f_y4),
      .Y5  (s_14f_y5),
      .Y6  (s_ref_100_n),
      .Y7  (s_mor25_n_out),
      .Y8  (s_14f_y8),
      .Y9  (s_gnt50_n_out)
    */
  assign chip14_d[0]      = s_blockl_n;
  assign chip14_d[1]      = s_mwrite_n;
  assign chip14_d[2]      = s_14f_y1;
  assign chip14_d[3]      = s_ref_n;
  assign chip14_d[4]      = s_14f_y3;  // y3
  assign chip14_d[5]      = s_14f_y4;  // y4
  assign chip14_d[6]      = s_14f_y5;  // y5
  assign chip14_d[7]      = s_mor_n;
  assign chip14_d[8]      = s_gnt_n;
  assign chip14_d[9]      = s_14f_y8;  // y8


  assign s_blockl25_n_out = chip14_y[0];
  assign s_14f_y1         = chip14_y[1];
  assign s_mwrite50_n     = chip14_y[2];
  assign s_14f_y3         = chip14_y[3];
  assign s_14f_y4         = chip14_y[4];
  assign s_14f_y5         = chip14_y[5];
  assign s_ref_100_n      = chip14_y[6];
  assign s_mor25_n_out    = chip14_y[7];
  assign s_14f_y8         = chip14_y[8];
  assign s_gnt50_n_out    = chip14_y[9];

  AM29C821 CHIP_14F (
      .CK(s_osc),
      .OE_n(s_pd4),
      .D(chip14_d),
      .Y(chip14_y)
  );

  /************ PAL chip 3F ************/

  PAL_44310D PAL_44310_ULBDIF (

      // Inputs
      .HIEN_n  (s_hien_n),        // I0
      .BGNT_n  (s_bgnt_n),        // I1
      .CGNT_n  (s_cgnt_n),        // I2
      .LOEN_n  (s_loen_n),        // I3
      .CGNT50_n(s_cgnt50_n_out),  // I4
      .ECCR    (s_eccr),          // I5
      .BGNT50_n(s_bgnt50_n),      // I6
      .BGNT75_n(s_bgnt75_n),      // I7
      .BDAP50_n(s_bdap50_n),      // I8
      .MR_n    (s_mr_n),          // I9

      .BDRY_n    (s_bdry_n_out),   // B0 Output
      .BIOXL_n   (s_bioxl_n_out),  // B1 Output
      .RAS       (s_ras),          // B2
      .REF100_n  (s_ref_100_n),    // B3
      .BIOXE_n   (s_bioxe_n),      // B4
      .MWRITE50_n(s_mwrite50_n),   // B5


      .BCGNT50R_n(s_bcgnt50r_n_out),  // Y0 Output
      .RDATA     (s_rdata_out)        // Y1 Output
  );


endmodule

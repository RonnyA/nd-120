/**************************************************************************
** ND120 CPU, MM&M                                                       **
** MEM/DATA                                                              **
** DATA & PARITY TCV                                                     **
** SHEET 46 of 50                                                        **
**                                                                       **
** Last reviewed: 1-DEC-2024                                             **
** Ronny Hansen                                                          **
***************************************************************************/

module MEM_DATA_46 (
    // Input signals
    input BCGNT50R_n,  //! Bus CPU Grant on read from memory after the address
    input BIOXL_n,     //! Bus IOX Enable
    input ECCR,        //! Bus ECC Request
    input HIEN_n,      //! High address bits enable
    input MR_n,        //! Master reset
    input MWRITE_n,    //! Memory Write
    input PA_n,        //! Parity Error Address (PEA)
    input QD_n,        //! Parity Error Signal (PES)
    input RDATA,       //! Read Data

    // IN and OUT signals
    input  [15:0] LBD_15_0_IN,
    output [15:0] LBD_15_0_OUT,

    output [17:0] DD_17_0_IN,
    output [17:0] DD_17_0_OUT,

    // Output signals
    output HIERR,       //! High address bits error
    output LOERR,       //! Low address bits error
    output LERR_n,      //! Local error
    output LPERR_n,     //! Local parity error
    output LED4         //! LED4_RED_PARITY_ERROR
);



  /*******************************************************************************
   ** The wires are defined here                                                 **
   *******************************************************************************/
  wire [15:0] s_lbd_15_0_in;
  wire [15:0] s_lbd_15_0_out;
  wire [17:0] s_dd_17_0_in;
  wire [17:0] s_dd_17_0_out;
  wire        s_bcgnt50r_n;
  wire        s_bioxl_n;
  wire        s_clr_14_8j;
  wire        s_clr_15_8j;
  wire        s_clr_n;
  wire        s_clrerr_n;
  wire        s_dis_n;
  wire        s_eccr;
  wire        s_gnd;
  wire        s_hien_n;
  wire        s_hierr_n_out;
  wire        s_hierr_out;
  wire        s_led4;
  wire        s_lerr_n_out;
  wire        s_loerr_n_out;
  wire        s_loerr_out;
  wire        s_lperr_n_out;
  wire        s_mr_n;
  wire        s_mwrite_n;
  wire        s_nor_mrn_pan;
  wire        s_oer_n;
  wire        s_oet_n;
  wire        s_pa_n;
  wire        s_power;
  wire        s_qd_n;
  wire        s_rdata;

  /*******************************************************************************
   ** Here all input connections are defined                                     **
   *******************************************************************************/
  assign s_lbd_15_0_in[15:0] = LBD_15_0_IN;
  assign s_dd_17_0_in[17:0]  = DD_17_0_IN;
  assign s_rdata             = RDATA;
  assign s_bioxl_n           = BIOXL_n;
  assign s_bcgnt50r_n        = BCGNT50R_n;
  assign s_pa_n              = PA_n;
  assign s_qd_n              = QD_n;
  assign s_mr_n              = MR_n;
  assign s_eccr              = ECCR;
  assign s_hien_n            = HIEN_n;
  assign s_mwrite_n          = MWRITE_n;

  /*******************************************************************************
   ** Here all output connections are defined                                    **
   *******************************************************************************/
  assign DD_17_0_OUT         = s_dd_17_0_out[17:0];
  assign HIERR               = s_hierr_out;
  assign LERR_n              = s_lerr_n_out;
  assign LOERR               = s_loerr_out;
  assign LPERR_n             = s_lperr_n_out;
  assign LBD_15_0_OUT        = s_lbd_15_0_out[15:0];

  /*******************************************************************************
   ** Here all in-lined components are defined                                   **
   *******************************************************************************/

  // Ground
  assign s_gnd               = 1'b0;

  // Power
  assign s_power             = 1'b1;

  // NOT Gate
  assign s_clr_15_8j         = ~s_clr_n;
  assign s_clr_14_8j         = ~s_nor_mrn_pan;
  assign s_loerr_out         = ~s_loerr_n_out;
  assign s_hierr_out         = ~s_hierr_n_out;

  // LED: LED4_RED_PARITY_ERROR
  assign LED4                = s_led4;

  /*******************************************************************************
   ** Here all normal components are defined                                     **
   *******************************************************************************/
  NOR_GATE #(
      .BubblesMask(2'b11)
  ) GATES_1 (
      .input1(s_dis_n),
      .input2(s_mr_n),
      .result(s_clr_n)
  );

  NOR_GATE #(
      .BubblesMask(2'b11)
  ) GATES_2 (
      .input1(s_mr_n),
      .input2(s_pa_n),
      .result(s_nor_mrn_pan)
  );

  NOR_GATE #(
      .BubblesMask(2'b00)
  ) GATES_3 (
      .input1(s_loerr_out),
      .input2(s_hierr_out),
      .result(s_lerr_n_out)
  );

  J_K_FLIPFLOP #(
      .InvertClockEnable(1)
  ) MEMORY_4 (
      .clock(s_lerr_n_out),
      .j(s_power),
      .k(s_gnd),
      .preset(s_gnd),
      .q(),
      .qBar(s_led4),
      .reset(s_clr_15_8j),
      .tick(1'b1)
  );

  J_K_FLIPFLOP #(
      .InvertClockEnable(1)
  ) MEMORY_5 (
      .clock(s_lerr_n_out),
      .j(s_power),
      .k(s_gnd),
      .preset(s_gnd),
      .q(),
      .qBar(s_lperr_n_out),
      .reset(s_clr_14_8j),
      .tick(1'b1)
  );


  /*******************************************************************************
   ** Here all sub-circuits are defined                                          **
   *******************************************************************************/


  PAL_45008B PAL_45008_UDATA (
      .MWRITE_n(s_mwrite_n),  //! I0 - MWRITE_n
      .SWDIS_n   (s_gnd),       //! I1 - SWDIS_n (SW4 - Parity disable, normal position = down. HERE: Disabled!)
      .LBD0(s_lbd_15_0_in[0]),  //! I2 - LBD0
      .LBD1(s_lbd_15_0_in[1]),  //! I3 - LBD1
      .LBD3(s_lbd_15_0_in[3]),  //! I4 - LBD3
      .LBD4(s_lbd_15_0_in[4]),  //! I5 - LBD4
      .BIOXL_n(s_bioxl_n),  //! I6 - BIOXL_n
      .ECCR(s_eccr),  //! I7 - ECCR
      .BCGNT50R_n(s_bcgnt50r_n),  //! I8 - BCGNT50R_n
      //.HIEN_n(s_hien_n),  //! I9 - EPEA_n  (NOT USED!)

      .DIS_n(s_dis_n),  //! DIS_n Y0_n (OUT Only)
      .OER_n(s_oer_n),  //! OER_n Y1_n (OUT ONLY)

      .OET_n   (s_oet_n),     //! B0_n - OET_n
      .CLRERR_n(s_clrerr_n),  //! B1_n - CLRERR_n
      .DISB_n  (),            //! B2_n - DISB_n (n.c)
      .TST_n   (),            //! B3_n - TST_n (n.c.)
      .QD_n    (s_qd_n),      //! B4_n - QD_n
      .MR_n    (s_mr_n)       //! B5_n - MR_n
  );



  AM29833A CHIP_1H (
      .CLK(s_rdata),
      .CLR_n(s_clrerr_n),
      .ERR_n(s_loerr_n_out),  // output (pulled high) // TODO: Fix pull up when output is not enabled
      .OER_n(s_oer_n),
      .OET_n(s_oet_n),

      // PARITY IN
      .PAR(s_dd_17_0_in[8]),

      // PARITY OUT
      .PAR_OUT(s_dd_17_0_out[8]),

      // R IN
      .R(s_lbd_15_0_in[7:0]),

      // R out
      .R_OUT(s_lbd_15_0_out[7:0]),

      // T in
      .T(s_dd_17_0_in[7:0]),

      // T out + T[8] = PAR // TODO: Pull high when OET is disabled
      .T_OUT(s_dd_17_0_out[7:0])
  );

  AM29833A CHIP_2H (
      .CLK(s_rdata),
      .CLR_n(s_clrerr_n),
      .ERR_n  (s_hierr_n_out),        // output (pulled high) // TODO: Fix pull up when output is not enabled
      .OER_n(s_oer_n),
      .OET_n(s_oet_n),

      // PARITY in
      .PAR(s_dd_17_0_in[17]),

      // PARITY out
      .PAR_OUT(s_dd_17_0_out[17]),

      // R in
      .R(s_lbd_15_0_in[15:8]),

      // R out
      .R_OUT(s_lbd_15_0_out[15:8]),

      // T in
      .T(s_dd_17_0_in[16:9]),

      // T out + T[17] = PAR  // TODO: Pull high when OET is disabled
      .T_OUT(s_dd_17_0_out[16:9])

  );

endmodule

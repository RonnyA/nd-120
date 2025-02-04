/**************************************************************************
** CPU GATE ARRAY - CGA - DELILAH                                        **
**                                                                       **
** CGA/IDBCTL - IDB Control Logic                                        **
**                                                                       **
** PDF page 97 of 108                                                    **
**                                                                       **
** Last reviewed: 02-FEB-2025                                            **
** Ronny Hansen                                                          **
***************************************************************************/


module CGA_IDBCTL (
    // Input signal
    input        EPCRN,
    input        EPGSN,
    input        EPICMASKN,
    input        EPICSN,
    input        EPICVN,
    input        FETCHN,
    input        HIGSN,
    input [11:0] LA_21_10,
    input        LOGSN,
    input        MCLK,
    input [15:0] PCR_15_0,
    input        PD,
    input [15:0] PICMASK_15_0,
    input [ 2:0] PICS_2_0,
    input [ 2:0] PICV_2_0,
    input        PVIOL,
    input        VACCN,
    input [15:0] XFIDBI_15_0,

    // Output signal
    output [15:0] FIDBI_15_0_OUT
);



  /*******************************************************************************
   ** The wires are defined here                                                 **
   *******************************************************************************/
  wire        s_epcr_n;
  wire        s_epgs_n;
  wire        s_epicmask_n;
  wire        s_epics_n;
  wire        s_epicv_n;
  wire        s_fetch_n;
  wire        s_gnd;
  wire        s_higs_n;
  wire        s_logs_n;
  wire        s_mclk;
  wire        s_pdf;
  wire        s_pviol;
  wire        s_vacc_n;
  wire [ 1:0] s_pgs_15_14;
  wire [11:0] s_la_21_10;
  wire [11:0] s_pgs_11_0;
  wire [15:0] s_fidbi_15_0_out;
  wire [15:0] s_pcr_15_0;
  wire [15:0] s_picmask_15_0;
  wire [15:0] s_xfidbi_15_0;
  wire [ 2:0] s_pics_2_0;
  wire [ 2:0] s_picv_2_0;
  wire [ 5:0] s_epins;

  /*******************************************************************************
   ** The module functionality is described here                                 **
   *******************************************************************************/

  /*******************************************************************************
   ** Here all input connections are defined                                     **
   *******************************************************************************/
  assign s_epcr_n             = EPCRN;
  assign s_epgs_n             = EPGSN;
  assign s_epicmask_n         = EPICMASKN;
  assign s_epics_n            = EPICSN;
  assign s_epicv_n            = EPICVN;
  assign s_fetch_n            = FETCHN;
  assign s_higs_n             = HIGSN;
  assign s_la_21_10[11:0]     = LA_21_10;
  assign s_logs_n             = LOGSN;
  assign s_mclk               = MCLK;
  assign s_pcr_15_0[15:0]     = PCR_15_0;
  assign s_pdf                = PD;
  assign s_picmask_15_0[15:0] = PICMASK_15_0;
  assign s_pics_2_0[2:0]      = PICS_2_0;
  assign s_picv_2_0[2:0]      = PICV_2_0;
  assign s_pviol              = PVIOL;
  assign s_vacc_n             = VACCN;
  assign s_xfidbi_15_0[15:0]  = XFIDBI_15_0;

  /*******************************************************************************
   ** Here all output connections are defined                                    **
   *******************************************************************************/
  assign FIDBI_15_0_OUT       = s_fidbi_15_0_out[15:0];

  /*******************************************************************************
   ** Here all in-lined components are defined                                   **
   *******************************************************************************/

  // Ground
  assign s_gnd                = 1'b0;

  // Assign signals to EPINS
  assign s_epins[0]           = ~s_epgs_n;
  assign s_epins[1]           = ~s_epcr_n;
  assign s_epins[2]           = ~s_epics_n;
  assign s_epins[3]           = ~s_epicv_n;
  assign s_epins[4]           = ~s_epicmask_n;
  assign s_epins[5]           = (s_epicmask_n & s_epicv_n & s_epics_n & s_epcr_n & s_epgs_n);


  // Code to make LINTER not complaing about bits not read in PCR 6:3
  (* keep = "true", DONT_TOUCH = "true" *) wire [4:0] unused_PCR_bits;
  assign unused_PCR_bits[4:0] = s_pcr_15_0[6:3];

  /*******************************************************************************
   ** Here all sub-circuits are defined                                          **
   *******************************************************************************/
  CGA_IDBCTL_SEL6 IDB15 (
      .D(s_xfidbi_15_0[15]),
      .D0(s_fidbi_15_0_out[15]),
      .E_PINS(s_epins[5:0]),
      .M(s_picmask_15_0[15]),
      .PCR(s_pcr_15_0[15]),
      .PGS(s_pgs_15_14[1]),
      .S(s_gnd),
      .V(s_gnd)
  );

  CGA_IDBCTL_SEL6 IDB14 (
      .D(s_xfidbi_15_0[14]),
      .D0(s_fidbi_15_0_out[14]),
      .E_PINS(s_epins[5:0]),
      .M(s_picmask_15_0[14]),
      .PCR(s_pcr_15_0[14]),
      .PGS(s_pgs_15_14[0]),
      .S(s_gnd),
      .V(s_gnd)
  );

  CGA_IDBCTL_SEL6 IDB13 (
      .D(s_xfidbi_15_0[13]),
      .D0(s_fidbi_15_0_out[13]),
      .E_PINS(s_epins[5:0]),
      .M(s_picmask_15_0[13]),
      .PCR(s_pcr_15_0[13]),
      .PGS(s_gnd),
      .S(s_gnd),
      .V(s_gnd)
  );

  CGA_IDBCTL_SEL6 IDB12 (
      .D(s_xfidbi_15_0[12]),
      .D0(s_fidbi_15_0_out[12]),
      .E_PINS(s_epins[5:0]),
      .M(s_picmask_15_0[12]),
      .PCR(s_pcr_15_0[12]),
      .PGS(s_gnd),
      .S(s_gnd),
      .V(s_gnd)
  );

  CGA_IDBCTL_SEL6 IDB11 (
      .D(s_xfidbi_15_0[11]),
      .D0(s_fidbi_15_0_out[11]),
      .E_PINS(s_epins[5:0]),
      .M(s_picmask_15_0[11]),
      .PCR(s_pcr_15_0[11]),
      .PGS(s_pgs_11_0[11]),
      .S(s_gnd),
      .V(s_gnd)
  );

  CGA_IDBCTL_SEL6 IDB10 (
      .D(s_xfidbi_15_0[10]),
      .D0(s_fidbi_15_0_out[10]),
      .E_PINS(s_epins[5:0]),
      .M(s_picmask_15_0[10]),
      .PCR(s_pcr_15_0[10]),
      .PGS(s_pgs_11_0[10]),
      .S(1'b0),
      .V(1'b0)
  );

  CGA_IDBCTL_SEL6 IDB9 (
      .D(s_xfidbi_15_0[9]),
      .D0(s_fidbi_15_0_out[9]),
      .E_PINS(s_epins[5:0]),
      .M(s_picmask_15_0[9]),
      .PCR(s_pcr_15_0[9]),
      .PGS(s_pgs_11_0[9]),
      .S(s_gnd),
      .V(s_gnd)
  );

  CGA_IDBCTL_SEL6 IDB8 (
      .D(s_xfidbi_15_0[8]),
      .D0(s_fidbi_15_0_out[8]),
      .E_PINS(s_epins[5:0]),
      .M(s_picmask_15_0[8]),
      .PCR(s_pcr_15_0[8]),
      .PGS(s_pgs_11_0[8]),
      .S(s_gnd),
      .V(s_gnd)
  );

  CGA_IDBCTL_SEL6 IDB7 (
      .D(s_xfidbi_15_0[7]),
      .D0(s_fidbi_15_0_out[7]),
      .E_PINS(s_epins[5:0]),
      .M(s_picmask_15_0[7]),
      .PCR(s_pcr_15_0[7]),
      .PGS(s_pgs_11_0[7]),
      .S(s_gnd),
      .V(s_gnd)
  );

  CGA_IDBCTL_SEL6 IDB6 (
      .D(s_xfidbi_15_0[6]),
      .D0(s_fidbi_15_0_out[6]),
      .E_PINS(s_epins[5:0]),
      .M(s_picmask_15_0[6]),
      .PCR(s_gnd),
      .PGS(s_pgs_11_0[6]),
      .S(s_gnd),
      .V(s_gnd)
  );

  CGA_IDBCTL_SEL6 IDB5 (
      .D(s_xfidbi_15_0[5]),
      .D0(s_fidbi_15_0_out[5]),
      .E_PINS(s_epins[5:0]),
      .M(s_picmask_15_0[5]),
      .PCR(s_gnd),
      .PGS(s_pgs_11_0[5]),
      .S(s_gnd),
      .V(s_gnd)
  );

  CGA_IDBCTL_SEL6 IDB4 (
      .D(s_xfidbi_15_0[4]),
      .D0(s_fidbi_15_0_out[4]),
      .E_PINS(s_epins[5:0]),
      .M(s_picmask_15_0[4]),
      .PCR(s_gnd),
      .PGS(s_pgs_11_0[4]),
      .S(s_logs_n),
      .V(s_gnd)
  );

  CGA_IDBCTL_SEL6 IDB3 (
      .D(s_xfidbi_15_0[3]),
      .D0(s_fidbi_15_0_out[3]),
      .E_PINS(s_epins[5:0]),
      .M(s_picmask_15_0[3]),
      .PCR(s_gnd),
      .PGS(s_pgs_11_0[3]),
      .S(s_higs_n),
      .V(s_pdf)
  );

  CGA_IDBCTL_SEL6 IDB2 (
      .D(s_xfidbi_15_0[2]),
      .D0(s_fidbi_15_0_out[2]),
      .E_PINS(s_epins[5:0]),
      .M(s_picmask_15_0[2]),
      .PCR(s_pcr_15_0[2]),
      .PGS(s_pgs_11_0[2]),
      .S(s_pics_2_0[2]),
      .V(s_picv_2_0[2])
  );

  CGA_IDBCTL_SEL6 IDB1 (
      .D(s_xfidbi_15_0[1]),
      .D0(s_fidbi_15_0_out[1]),
      .E_PINS(s_epins[5:0]),
      .M(s_picmask_15_0[1]),
      .PCR(s_pcr_15_0[1]),
      .PGS(s_pgs_11_0[1]),
      .S(s_pics_2_0[1]),
      .V(s_picv_2_0[1])
  );

  CGA_IDBCTL_SEL6 IDB0 (
      .D(s_xfidbi_15_0[0]),
      .D0(s_fidbi_15_0_out[0]),
      .E_PINS(s_epins[5:0]),
      .M(s_picmask_15_0[0]),
      .PCR(s_pcr_15_0[0]),
      .PGS(s_pgs_11_0[0]),
      .S(s_pics_2_0[0]),
      .V(s_picv_2_0[0])
  );



  CGA_IDBCTL_PGSREG PGSREG (
      .FETCHN(s_fetch_n),
      .LA_21_10(s_la_21_10[11:0]),
      .MCLK(s_mclk),
      .PGS_11_0(s_pgs_11_0[11:0]),
      .PGS_15_14(s_pgs_15_14[1:0]),
      .PVIOL(s_pviol),
      .VACCN(s_vacc_n)
  );

endmodule

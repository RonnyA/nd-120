/**************************************************************************
** ND120 CGA (CPU Gate Array / DELILAH)                                  **
** /CGA/MIC/MASEL/REPEAT                                                 **
** REPEAT                                                                **
**                                                                       **
** Page n                                                                **
** SHEET 1 of n                                                          **
**                                                                       **
** Last reviewed: 10-NOV-2024                                            **
** Ronny Hansen                                                          **
***************************************************************************/

module CGA_MIC_MASEL_REPEAT (
    input MCLK,
    input MPN,
    input [12:0] REP_12_0,

    output [12:0] IW_12_0
);

  /*******************************************************************************
   ** The wires are defined here                                                 **
   *******************************************************************************/
  wire [12:0] s_iw_12_0_out;
  wire [12:0] s_rep_12_0;
  wire        s_mclk;
  wire        s_mp_n;
  wire        s_mp;

  /*******************************************************************************
   ** The module functionality is described here                                 **
   *******************************************************************************/

  /*******************************************************************************
   ** Here all input connections are defined                                     **
   *******************************************************************************/
  assign s_rep_12_0[12:0] = REP_12_0;
  assign s_mp_n           = MPN;
  assign s_mclk           = MCLK;

  /*******************************************************************************
   ** Here all output connections are defined                                    **
   *******************************************************************************/
  assign IW_12_0          = s_iw_12_0_out[12:0];

  /*******************************************************************************
   ** Here all in-lined components are defined                                   **
   *******************************************************************************/

  // NOT Gate
  assign s_mp             = ~s_mp_n;

  /*******************************************************************************
   ** Here all normal components are defined                                     **
   *******************************************************************************/
  D_FLIPFLOP #(
      .InvertClockEnable(0)
  ) IWFF12 (
      .clock(s_mclk),
      .d(s_rep_12_0[12]),
      .preset(1'b0),
      .q(s_iw_12_0_out[12]),
      .qBar(),
      .reset(s_mp),
      .tick(1'b1)
  );

  D_FLIPFLOP #(
      .InvertClockEnable(0)
  ) IWFF11 (
      .clock(s_mclk),
      .d(s_rep_12_0[11]),
      .preset(1'b0),
      .q(s_iw_12_0_out[11]),
      .qBar(),
      .reset(s_mp),
      .tick(1'b1)
  );

  D_FLIPFLOP #(
      .InvertClockEnable(0)
  ) IWFF10 (
      .clock(s_mclk),
      .d(s_rep_12_0[10]),
      .preset(1'b0),
      .q(s_iw_12_0_out[10]),
      .qBar(),
      .reset(s_mp),
      .tick(1'b1)
  );

  D_FLIPFLOP #(
      .InvertClockEnable(0)
  ) IWFF9 (
      .clock(s_mclk),
      .d(s_rep_12_0[9]),
      .preset(1'b0),
      .q(s_iw_12_0_out[9]),
      .qBar(),
      .reset(s_mp),
      .tick(1'b1)
  );

  D_FLIPFLOP #(
      .InvertClockEnable(0)
  ) IWFF8 (
      .clock(s_mclk),
      .d(s_rep_12_0[8]),
      .preset(1'b0),
      .q(s_iw_12_0_out[8]),
      .qBar(),
      .reset(s_mp),
      .tick(1'b1)
  );

  D_FLIPFLOP #(
      .InvertClockEnable(0)
  ) IWFF7 (
      .clock(s_mclk),
      .d(s_rep_12_0[7]),
      .preset(1'b0),
      .q(s_iw_12_0_out[7]),
      .qBar(),
      .reset(s_mp),
      .tick(1'b1)
  );

  D_FLIPFLOP #(
      .InvertClockEnable(0)
  ) IWFF6 (
      .clock(s_mclk),
      .d(s_rep_12_0[6]),
      .preset(1'b0),
      .q(s_iw_12_0_out[6]),
      .qBar(),
      .reset(s_mp),
      .tick(1'b1)
  );

  D_FLIPFLOP #(
      .InvertClockEnable(0)
  ) IWFF5 (
      .clock(s_mclk),
      .d(s_rep_12_0[5]),
      .preset(1'b0),
      .q(s_iw_12_0_out[5]),
      .qBar(),
      .reset(s_mp),
      .tick(1'b1)
  );

  D_FLIPFLOP #(
      .InvertClockEnable(0)
  ) IWFF4 (
      .clock(s_mclk),
      .d(s_rep_12_0[4]),
      .preset(1'b0),
      .q(s_iw_12_0_out[4]),
      .qBar(),
      .reset(s_mp),
      .tick(1'b1)
  );

  D_FLIPFLOP #(
      .InvertClockEnable(0)
  ) IWFF3 (
      .clock(s_mclk),
      .d(s_rep_12_0[3]),
      .preset(1'b0),
      .q(s_iw_12_0_out[3]),
      .qBar(),
      .reset(s_mp),
      .tick(1'b1)
  );

  D_FLIPFLOP #(
      .InvertClockEnable(0)
  ) IWFF2 (
      .clock(s_mclk),
      .d(s_rep_12_0[2]),
      .preset(1'b0),
      .q(s_iw_12_0_out[2]),
      .qBar(),
      .reset(s_mp),
      .tick(1'b1)
  );

  D_FLIPFLOP #(
      .InvertClockEnable(0)
  ) IWFF1 (
      .clock(s_mclk),
      .d(s_rep_12_0[1]),
      .preset(1'b0),
      .q(s_iw_12_0_out[1]),
      .qBar(),
      .reset(s_mp),
      .tick(1'b1)
  );

  D_FLIPFLOP #(
      .InvertClockEnable(0)
  ) IWFF0 (
      .clock(s_mclk),
      .d(s_rep_12_0[0]),
      .preset(1'b0),
      .q(s_iw_12_0_out[0]),
      .qBar(),
      .reset(s_mp),
      .tick(1'b1)
  );




endmodule

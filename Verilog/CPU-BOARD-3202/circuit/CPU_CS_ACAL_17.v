/**************************************************************************
** ND120 CPU, MM&M                                                       **
** CPU/CS/ACAL                                                           **
** MICRO ADDR CALC UNIT                                                  **
** SHEET 17 of 50                                                        **
**                                                                       **
** Last reviewed: 2-FEB-2025                                             **
** Ronny Hansen                                                          **
***************************************************************************/


module CPU_CS_ACAL_17 (
    input         CLK,
    input  [12:0] CSA_12_0,
    input  [ 9:0] CSCA_9_0,
    input         MACLK,
    input         PD1,
    output [12:0] LUA_12_0,
    output [11:0] UUA_11_0
);


  /*******************************************************************************
   ** The wires are defined here                                                 **
   *******************************************************************************/
  wire [ 9:0] s_uua_chip_31g_9_0;
  wire [ 9:0] s_uua_chip_32g_9_0;
  wire [ 9:0] s_csca_9_0;
  wire [ 7:0] s_q_chip30h_7_0;  // output from Q_7_0 on chip 30H
  wire [12:0] s_csa_12_0;
  wire [12:0] s_lua;
  wire [11:0] s_uua;
  wire [ 7:0] s_d_chip30h_7_0;
  wire        s_pd1;
  wire        s_lua12;
  wire        s_lua12_n;
  wire        s_clk;
  wire        s_maclk;


  /*******************************************************************************
   ** The module functionality is described here                                 **
   *******************************************************************************/

  /*******************************************************************************
   ** Here all wiring is defined                                                 **
   *******************************************************************************/

  /*** Outputs from Chip 30H  ***/
  assign s_lua[12]          = s_q_chip30h_7_0[0];
  assign s_lua[11]          = s_q_chip30h_7_0[1];
  assign s_lua[10]          = s_q_chip30h_7_0[2];

  //assign s_lua[9:0] =  (outputs from Chip 31F)

  // Not used signals
  // s_q_chip30h_7_0[3];
  // s_q_chip30h_7_0[4];
  // s_q_chip30h_7_0[7];

    // Code to make LINTER _not_ complain about bits not read in PCR bits 15 and 6:0
  (* keep = "true", DONT_TOUCH = "true" *) wire [2:0] unused_CHIP30h_bits;
  assign unused_CHIP30h_bits = { s_q_chip30h_7_0[7],s_q_chip30h_7_0[4],s_q_chip30h_7_0[3] };


  assign s_uua[11]          = s_q_chip30h_7_0[5];
  assign s_uua[10]          = s_q_chip30h_7_0[6];

  assign s_uua[9:0]         = s_lua12 ? s_uua_chip_32g_9_0[9:0] : s_uua_chip_31g_9_0[9:0];

  /*** Outputs from Chip 30H  ***/

  /* Input data for chip 30H */
  assign s_d_chip30h_7_0[0] = s_csa_12_0[12];
  assign s_d_chip30h_7_0[1] = s_csa_12_0[11];
  assign s_d_chip30h_7_0[2] = s_csa_12_0[10];
  assign s_d_chip30h_7_0[3] = 0;  // not used
  assign s_d_chip30h_7_0[4] = 0;  // not used
  assign s_d_chip30h_7_0[5] = s_csa_12_0[11] | s_lua12_n;
  assign s_d_chip30h_7_0[6] = s_csa_12_0[10] | s_lua12_n;
  assign s_d_chip30h_7_0[7] = 0;


  assign s_lua12            = s_lua[12];
  assign s_lua12_n          = ~s_lua12;  // negated



  /*******************************************************************************
   ** Here all input connections are defined                                     **
   *******************************************************************************/
  assign s_csca_9_0[9:0]    = CSCA_9_0;
  assign s_csa_12_0[12:0]   = CSA_12_0;
  assign s_pd1              = PD1;
  assign s_maclk            = MACLK;
  assign s_clk              = CLK;

  /*******************************************************************************
   ** Here all output connections are defined                                    **
   *******************************************************************************/
  assign LUA_12_0           = s_lua[12:0];
  assign UUA_11_0           = s_uua[11:0];

  /*******************************************************************************
   ** Here all sub-circuits are defined                                          **
   *******************************************************************************/



  TTL_74373 CHIP_30H (
      .C(s_maclk),
      .D(s_d_chip30h_7_0[7:0]),
      .OC_n(s_pd1),
      .Q(s_q_chip30h_7_0[7:0])
  );

  AM29841 CHIP_31F (
      .D(s_csa_12_0[9:0]),
      .LE(s_maclk),
      .OE_n(s_pd1),
      .Y(s_lua[9:0])
  );

  AM29841 CHIP_32G (
      .D(s_csa_12_0[9:0]),
      .LE(s_maclk),
      .OE_n(s_lua12_n),
      .Y(s_uua_chip_32g_9_0[9:0])
  );

  AM29841 CHIP_31G (
      .D(s_csca_9_0[9:0]),
      .LE(s_clk),
      .OE_n(s_lua12),
      .Y(s_uua_chip_31g_9_0[9:0])
  );

endmodule


/**************************************************************************
** ND120 CGA (CPU Gate Array / DELILAH)                                  **
** /CGA/ALU/DBR                                                          **
** DBR REGISTER (Data Bus Register)                                      **
**                                                                       **
** Page 53                                                               **
** SHEET 1 of 1                                                          **
**                                                                       **
** Last reviewed: 10-NOV-2024                                            **
** Ronny Hansen                                                          **
***************************************************************************/


module CGA_ALU_DBR (
    input        ALUCLK,
    input [15:0] CD_15_0,
    input        LDDBRN,

    output [15:0] DBR_15_0
);

  /*******************************************************************************
   ** The wires are defined here                                                 **
   *******************************************************************************/
  wire [15:0] s_dbr_15_0_out;
  wire [15:0] s_cd_15_0;
  wire        s_aluclk;
  wire        s_lddbr;
  wire        s_logisimNet10;
  wire        s_logisimNet11;
  wire        s_logisimNet12;
  wire        s_logisimNet13;
  wire        s_logisimNet14;
  wire        s_logisimNet15;
  wire        s_logisimNet16;
  wire        s_logisimNet17;
  wire        s_logisimNet18;
  wire        s_logisimNet19;
  wire        s_logisimNet2;
  wire        s_logisimNet21;
  wire        s_logisimNet22;
  wire        s_logisimNet23;
  wire        s_logisimNet24;
  wire        s_logisimNet25;
  wire        s_logisimNet26;
  wire        s_logisimNet27;
  wire        s_logisimNet28;
  wire        s_logisimNet29;
  wire        s_logisimNet3;
  wire        s_logisimNet30;
  wire        s_logisimNet31;
  wire        s_lddbr_n;
  wire        s_logisimNet33;
  wire        s_logisimNet34;
  wire        s_logisimNet35;
  wire        s_logisimNet4;
  wire        s_logisimNet5;
  wire        s_logisimNet6;
  wire        s_logisimNet7;
  wire        s_logisimNet8;
  wire        s_logisimNet9;

  /*******************************************************************************
   ** The module functionality is described here                                 **
   *******************************************************************************/

  /*******************************************************************************
   ** Here all input connections are defined                                     **
   *******************************************************************************/
  assign s_cd_15_0[15:0] = CD_15_0;
  assign s_aluclk        = ALUCLK;
  assign s_lddbr_n       = LDDBRN;

  /*******************************************************************************
   ** Here all output connections are defined                                    **
   *******************************************************************************/
  assign DBR_15_0        = s_dbr_15_0_out[15:0];

  /*******************************************************************************
   ** Here all in-lined components are defined                                   **
   *******************************************************************************/

  // NOT Gate
  assign s_lddbr         = ~s_lddbr_n;

  /*******************************************************************************
   ** Here all sub-circuits are defined                                          **
   *******************************************************************************/
   SCAN_FF DBRF15 (
      .CLK(s_aluclk),
      .D  (s_dbr_15_0_out[15]),
      .Q  (s_dbr_15_0_out[15]),
      .QN (),
      .TE (s_lddbr),
      .TI (s_cd_15_0[15])
  );

  SCAN_FF DBRF14 (
      .CLK(s_aluclk),
      .D  (s_dbr_15_0_out[14]),
      .Q  (s_dbr_15_0_out[14]),
      .QN (),
      .TE (s_lddbr),
      .TI (s_cd_15_0[14])
  );

  SCAN_FF DBRf13 (
      .CLK(s_aluclk),
      .D  (s_dbr_15_0_out[13]),
      .Q  (s_dbr_15_0_out[13]),
      .QN (),
      .TE (s_lddbr),
      .TI (s_cd_15_0[13])
  );

  SCAN_FF DBRF12 (
      .CLK(s_aluclk),
      .D  (s_dbr_15_0_out[12]),
      .Q  (s_dbr_15_0_out[12]),
      .QN (),
      .TE (s_lddbr),
      .TI (s_cd_15_0[12])
  );

  SCAN_FF DBRF11 (
      .CLK(s_aluclk),
      .D  (s_dbr_15_0_out[11]),
      .Q  (s_dbr_15_0_out[11]),
      .QN (),
      .TE (s_lddbr),
      .TI (s_cd_15_0[11])
  );

  SCAN_FF DBRF10 (
      .CLK(s_aluclk),
      .D  (s_dbr_15_0_out[10]),
      .Q  (s_dbr_15_0_out[10]),
      .QN (),
      .TE (s_lddbr),
      .TI (s_cd_15_0[10])
  );

  SCAN_FF DBRF9 (
      .CLK(s_aluclk),
      .D  (s_dbr_15_0_out[9]),
      .Q  (s_dbr_15_0_out[9]),
      .QN (),
      .TE (s_lddbr),
      .TI (s_cd_15_0[9])
  );

  SCAN_FF DBRF8 (
      .CLK(s_aluclk),
      .D  (s_dbr_15_0_out[8]),
      .Q  (s_dbr_15_0_out[8]),
      .QN (),
      .TE (s_lddbr),
      .TI (s_cd_15_0[8])
  );

  SCAN_FF DBRF7 (
      .CLK(s_aluclk),
      .D  (s_dbr_15_0_out[7]),
      .Q  (s_dbr_15_0_out[7]),
      .QN (),
      .TE (s_lddbr),
      .TI (s_cd_15_0[7])
  );

  SCAN_FF DBRF6 (
      .CLK(s_aluclk),
      .D  (s_dbr_15_0_out[6]),
      .Q  (s_dbr_15_0_out[6]),
      .QN (),
      .TE (s_lddbr),
      .TI (s_cd_15_0[6])
  );

  SCAN_FF DBRF5 (
      .CLK(s_aluclk),
      .D  (s_dbr_15_0_out[5]),
      .Q  (s_dbr_15_0_out[5]),
      .QN (),
      .TE (s_lddbr),
      .TI (s_cd_15_0[5])
  );

  SCAN_FF DBRF4 (
      .CLK(s_aluclk),
      .D  (s_dbr_15_0_out[4]),
      .Q  (s_dbr_15_0_out[4]),
      .QN (),
      .TE (s_lddbr),
      .TI (s_cd_15_0[4])
  );

  SCAN_FF DBRF3 (
      .CLK(s_aluclk),
      .D  (s_dbr_15_0_out[3]),
      .Q  (s_dbr_15_0_out[3]),
      .QN (),
      .TE (s_lddbr),
      .TI (s_cd_15_0[3])
  );

  SCAN_FF DBRF2 (
      .CLK(s_aluclk),
      .D  (s_dbr_15_0_out[2]),
      .Q  (s_dbr_15_0_out[2]),
      .QN (),
      .TE (s_lddbr),
      .TI (s_cd_15_0[2])
  );

  SCAN_FF DBRF1 (
      .CLK(s_aluclk),
      .D  (s_dbr_15_0_out[1]),
      .Q  (s_dbr_15_0_out[1]),
      .QN (),
      .TE (s_lddbr),
      .TI (s_cd_15_0[1])
  );

  SCAN_FF DBRF0 (
      .CLK(s_aluclk),
      .D  (s_dbr_15_0_out[0]),
      .Q  (s_dbr_15_0_out[0]),
      .QN (),
      .TE (s_lddbr),
      .TI (s_cd_15_0[0])
  );

 
endmodule

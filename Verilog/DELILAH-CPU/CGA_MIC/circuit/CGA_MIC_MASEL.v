/******************************************************************************
 ** Logisim-evolution goes FPGA automatic generated Verilog code             **
 ** https://github.com/logisim-evolution/                                    **
 **                                                                          **
 ** Component : CGA_MIC_MASEL                                                **
 **                                                                          **
 *****************************************************************************/

module CGA_MIC_MASEL( CSBIT20,
                      CSBIT_11_4,
                      IW_12_0,
                      JMP_3_0,
                      MCLK,
                      MCLKN,
                      MRN,
                      NEXT_12_0,
                      RET_12_0,
                      SC5,
                      SC6,
                      W_12_0 );

   /*******************************************************************************
   ** The inputs are defined here                                                **
   *******************************************************************************/
   input        CSBIT20;
   input [7:0]  CSBIT_11_4;
   input [3:0]  JMP_3_0;
   input        MCLK;
   input        MCLKN;
   input        MRN;
   input [12:0] NEXT_12_0;
   input [12:0] RET_12_0;
   input        SC5;
   input        SC6;

   /*******************************************************************************
   ** The outputs are defined here                                               **
   *******************************************************************************/
   output [12:0] IW_12_0;
   output [12:0] W_12_0;

   /*******************************************************************************
   ** The wires are defined here                                                 **
   *******************************************************************************/
   wire [1:0]  s_logisimBus0;
   wire [12:0] s_logisimBus13;
   wire [12:0] s_logisimBus14;
   wire [12:0] s_logisimBus79;
   wire [12:0] s_logisimBus82;
   wire [3:0]  s_logisimBus85;
   wire [12:0] s_logisimBus87;
   wire [7:0]  s_logisimBus89;
   wire        s_logisimNet1;
   wire        s_logisimNet10;
   wire        s_logisimNet11;
   wire        s_logisimNet12;
   wire        s_logisimNet15;
   wire        s_logisimNet16;
   wire        s_logisimNet17;
   wire        s_logisimNet18;
   wire        s_logisimNet19;
   wire        s_logisimNet2;
   wire        s_logisimNet20;
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
   wire        s_logisimNet32;
   wire        s_logisimNet33;
   wire        s_logisimNet34;
   wire        s_logisimNet35;
   wire        s_logisimNet36;
   wire        s_logisimNet37;
   wire        s_logisimNet38;
   wire        s_logisimNet39;
   wire        s_logisimNet4;
   wire        s_logisimNet40;
   wire        s_logisimNet41;
   wire        s_logisimNet42;
   wire        s_logisimNet43;
   wire        s_logisimNet44;
   wire        s_logisimNet45;
   wire        s_logisimNet46;
   wire        s_logisimNet47;
   wire        s_logisimNet48;
   wire        s_logisimNet49;
   wire        s_logisimNet5;
   wire        s_logisimNet50;
   wire        s_logisimNet51;
   wire        s_logisimNet52;
   wire        s_logisimNet53;
   wire        s_logisimNet54;
   wire        s_logisimNet55;
   wire        s_logisimNet56;
   wire        s_logisimNet57;
   wire        s_logisimNet58;
   wire        s_logisimNet59;
   wire        s_logisimNet6;
   wire        s_logisimNet60;
   wire        s_logisimNet61;
   wire        s_logisimNet62;
   wire        s_logisimNet63;
   wire        s_logisimNet64;
   wire        s_logisimNet65;
   wire        s_logisimNet66;
   wire        s_logisimNet67;
   wire        s_logisimNet68;
   wire        s_logisimNet69;
   wire        s_logisimNet7;
   wire        s_logisimNet70;
   wire        s_logisimNet71;
   wire        s_logisimNet72;
   wire        s_logisimNet73;
   wire        s_logisimNet74;
   wire        s_logisimNet75;
   wire        s_logisimNet76;
   wire        s_logisimNet77;
   wire        s_logisimNet78;
   wire        s_logisimNet8;
   wire        s_logisimNet80;
   wire        s_logisimNet81;
   wire        s_logisimNet83;
   wire        s_logisimNet84;
   wire        s_logisimNet86;
   wire        s_logisimNet88;
   wire        s_logisimNet9;
   wire        s_logisimNet90;

   /*******************************************************************************
   ** The module functionality is described here                                 **
   *******************************************************************************/

   /*******************************************************************************
   ** Here all input connections are defined                                     **
   *******************************************************************************/
   assign s_logisimBus0[0]     = SC5;
   assign s_logisimBus0[1]     = SC6;
   assign s_logisimBus13[12:0] = RET_12_0;
   assign s_logisimBus14[12:0] = NEXT_12_0;
   assign s_logisimBus85[3:0]  = JMP_3_0;
   assign s_logisimBus89[7:0]  = CSBIT_11_4;
   assign s_logisimNet22       = MCLKN;
   assign s_logisimNet86       = MCLK;
   assign s_logisimNet88       = CSBIT20;
   assign s_logisimNet90       = MRN;

   /*******************************************************************************
   ** Here all output connections are defined                                    **
   *******************************************************************************/
   assign IW_12_0 = s_logisimBus82[12:0];
   assign W_12_0  = s_logisimBus79[12:0];

   /*******************************************************************************
   ** Here all normal components are defined                                     **
   *******************************************************************************/
   Multiplexer_4   PLEXERS_1 (
                              .muxIn_0(s_logisimBus89[7]),
                              .muxIn_1(s_logisimBus13[11]),
                              .muxIn_2(s_logisimBus14[11]),
                              .muxIn_3(s_logisimBus82[11]),
                              .muxOut(s_logisimBus87[11]),
                              .sel(s_logisimBus0[1:0]));

   Multiplexer_4   PLEXERS_2 (
                              .muxIn_0(s_logisimBus89[6]),
                              .muxIn_1(s_logisimBus13[10]),
                              .muxIn_2(s_logisimBus14[10]),
                              .muxIn_3(s_logisimBus82[10]),
                              .muxOut(s_logisimBus87[10]),
                              .sel(s_logisimBus0[1:0]));

   Multiplexer_4   PLEXERS_3 (
                              .muxIn_0(s_logisimBus89[5]),
                              .muxIn_1(s_logisimBus13[9]),
                              .muxIn_2(s_logisimBus14[9]),
                              .muxIn_3(s_logisimBus82[9]),
                              .muxOut(s_logisimBus87[9]),
                              .sel(s_logisimBus0[1:0]));

   Multiplexer_4   PLEXERS_4 (
                              .muxIn_0(s_logisimBus89[4]),
                              .muxIn_1(s_logisimBus13[8]),
                              .muxIn_2(s_logisimBus14[8]),
                              .muxIn_3(s_logisimBus82[8]),
                              .muxOut(s_logisimBus87[8]),
                              .sel(s_logisimBus0[1:0]));

   Multiplexer_4   PLEXERS_5 (
                              .muxIn_0(s_logisimBus89[3]),
                              .muxIn_1(s_logisimBus13[7]),
                              .muxIn_2(s_logisimBus14[7]),
                              .muxIn_3(s_logisimBus82[7]),
                              .muxOut(s_logisimBus87[7]),
                              .sel(s_logisimBus0[1:0]));

   Multiplexer_4   PLEXERS_6 (
                              .muxIn_0(s_logisimBus89[2]),
                              .muxIn_1(s_logisimBus13[6]),
                              .muxIn_2(s_logisimBus14[6]),
                              .muxIn_3(s_logisimBus82[6]),
                              .muxOut(s_logisimBus87[6]),
                              .sel(s_logisimBus0[1:0]));

   Multiplexer_4   PLEXERS_7 (
                              .muxIn_0(s_logisimBus89[1]),
                              .muxIn_1(s_logisimBus13[5]),
                              .muxIn_2(s_logisimBus14[5]),
                              .muxIn_3(s_logisimBus82[5]),
                              .muxOut(s_logisimBus87[5]),
                              .sel(s_logisimBus0[1:0]));

   Multiplexer_4   PLEXERS_8 (
                              .muxIn_0(s_logisimBus89[0]),
                              .muxIn_1(s_logisimBus13[4]),
                              .muxIn_2(s_logisimBus14[4]),
                              .muxIn_3(s_logisimBus82[4]),
                              .muxOut(s_logisimBus87[4]),
                              .sel(s_logisimBus0[1:0]));

   Multiplexer_4   PLEXERS_9 (
                              .muxIn_0(s_logisimBus85[3]),
                              .muxIn_1(s_logisimBus13[3]),
                              .muxIn_2(s_logisimBus14[3]),
                              .muxIn_3(s_logisimBus82[3]),
                              .muxOut(s_logisimBus87[3]),
                              .sel(s_logisimBus0[1:0]));

   Multiplexer_4   PLEXERS_10 (
                               .muxIn_0(s_logisimBus85[2]),
                               .muxIn_1(s_logisimBus13[2]),
                               .muxIn_2(s_logisimBus14[2]),
                               .muxIn_3(s_logisimBus82[2]),
                               .muxOut(s_logisimBus87[2]),
                               .sel(s_logisimBus0[1:0]));

   Multiplexer_4   PLEXERS_11 (
                               .muxIn_0(s_logisimBus85[1]),
                               .muxIn_1(s_logisimBus13[1]),
                               .muxIn_2(s_logisimBus14[1]),
                               .muxIn_3(s_logisimBus82[1]),
                               .muxOut(s_logisimBus87[1]),
                               .sel(s_logisimBus0[1:0]));

   Multiplexer_4   PLEXERS_12 (
                               .muxIn_0(s_logisimBus85[0]),
                               .muxIn_1(s_logisimBus13[0]),
                               .muxIn_2(s_logisimBus14[0]),
                               .muxIn_3(s_logisimBus82[0]),
                               .muxOut(s_logisimBus87[0]),
                               .sel(s_logisimBus0[1:0]));

   Multiplexer_4   PLEXERS_13 (
                               .muxIn_0(s_logisimNet88),
                               .muxIn_1(s_logisimBus13[12]),
                               .muxIn_2(s_logisimBus14[12]),
                               .muxIn_3(s_logisimBus82[12]),
                               .muxOut(s_logisimBus87[12]),
                               .sel(s_logisimBus0[1:0]));


   /*******************************************************************************
   ** Here all sub-circuits are defined                                          **
   *******************************************************************************/

   L8   WL_HI (.A(s_logisimBus87[4]),
               .B(s_logisimBus87[3]),
               .C(s_logisimBus87[2]),
               .D(s_logisimBus87[1]),
               .E(s_logisimBus87[0]),
               .F(1'b0),
               .G(1'b0),
               .H(1'b0),
               .L(s_logisimNet22),
               .QA(s_logisimBus79[12]),
               .QAN(),
               .QB(s_logisimBus79[11]),
               .QBN(),
               .QC(s_logisimBus79[10]),
               .QCN(),
               .QD(s_logisimBus79[9]),
               .QDN(),
               .QE(s_logisimBus79[8]),
               .QEN(),
               .QF(s_logisimBus79[7]),
               .QFN(),
               .QG(s_logisimBus79[6]),
               .QGN(),
               .QH(s_logisimBus79[5]),
               .QHN());

   L8   WL_LO (.A(s_logisimBus87[12]),
               .B(s_logisimBus87[11]),
               .C(s_logisimBus87[10]),
               .D(s_logisimBus87[9]),
               .E(s_logisimBus87[8]),
               .F(s_logisimBus87[7]),
               .G(s_logisimBus87[6]),
               .H(s_logisimBus87[5]),
               .L(s_logisimNet22),
               .QA(s_logisimBus79[4]),
               .QAN(),
               .QB(s_logisimBus79[3]),
               .QBN(),
               .QC(s_logisimBus79[2]),
               .QCN(),
               .QD(s_logisimBus79[1]),
               .QDN(),
               .QE(s_logisimBus79[0]),
               .QEN(),
               .QF(),
               .QFN(),
               .QG(),
               .QGN(),
               .QH(),
               .QHN());

   CGA_MIC_MASEL_REPEAT   MASEL_REPEAT (.IW_12_0(s_logisimBus82[12:0]),
                                        .MCLK(s_logisimNet86),
                                        .MPN(s_logisimNet90),
                                        .REP_12_0(s_logisimBus87[12:0]));

endmodule

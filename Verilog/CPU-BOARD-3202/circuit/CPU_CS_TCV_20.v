/******************************************************************************
 ** Logisim-evolution goes FPGA automatic generated Verilog code             **
 ** https://github.com/logisim-evolution/                                    **
 **                                                                          **
 ** Component : CPU_CS_TCV_20                                                **
 **                                                                          **
 *****************************************************************************/

module CPU_CS_TCV_20( CSBITS_io,
                      ECSL_n,
                      EW_3_0_n,
                      IDB_15_0_io,
                      WCS_n );

   /*******************************************************************************
   ** The inputs are defined here                                                **
   *******************************************************************************/
   input [63:0] CSBITS_io;
   input        ECSL_n;
   input [3:0]  EW_3_0_n;
   input        WCS_n;

   /*******************************************************************************
   ** The outputs are defined here                                               **
   *******************************************************************************/
   output [15:0] IDB_15_0_io;

   /*******************************************************************************
   ** The wires are defined here                                                 **
   *******************************************************************************/
   wire [7:0]  s_logisimBus26;
   wire [63:0] s_logisimBus4;
   wire [7:0]  s_logisimBus45;
   wire [15:0] s_logisimBus46;
   wire [7:0]  s_logisimBus49;
   wire [7:0]  s_logisimBus50;
   wire [7:0]  s_logisimBus52;
   wire [7:0]  s_logisimBus67;
   wire [7:0]  s_logisimBus70;
   wire [3:0]  s_logisimBus71;
   wire [7:0]  s_logisimBus94;
   wire        s_logisimNet10;
   wire        s_logisimNet100;
   wire        s_logisimNet101;
   wire        s_logisimNet102;
   wire        s_logisimNet103;
   wire        s_logisimNet104;
   wire        s_logisimNet105;
   wire        s_logisimNet106;
   wire        s_logisimNet107;
   wire        s_logisimNet108;
   wire        s_logisimNet109;
   wire        s_logisimNet11;
   wire        s_logisimNet110;
   wire        s_logisimNet111;
   wire        s_logisimNet112;
   wire        s_logisimNet113;
   wire        s_logisimNet114;
   wire        s_logisimNet115;
   wire        s_logisimNet116;
   wire        s_logisimNet117;
   wire        s_logisimNet118;
   wire        s_logisimNet119;
   wire        s_logisimNet12;
   wire        s_logisimNet120;
   wire        s_logisimNet121;
   wire        s_logisimNet122;
   wire        s_logisimNet123;
   wire        s_logisimNet124;
   wire        s_logisimNet125;
   wire        s_logisimNet126;
   wire        s_logisimNet127;
   wire        s_logisimNet128;
   wire        s_logisimNet129;
   wire        s_logisimNet13;
   wire        s_logisimNet130;
   wire        s_logisimNet131;
   wire        s_logisimNet132;
   wire        s_logisimNet133;
   wire        s_logisimNet134;
   wire        s_logisimNet135;
   wire        s_logisimNet136;
   wire        s_logisimNet137;
   wire        s_logisimNet138;
   wire        s_logisimNet139;
   wire        s_logisimNet14;
   wire        s_logisimNet140;
   wire        s_logisimNet141;
   wire        s_logisimNet142;
   wire        s_logisimNet143;
   wire        s_logisimNet144;
   wire        s_logisimNet145;
   wire        s_logisimNet146;
   wire        s_logisimNet147;
   wire        s_logisimNet148;
   wire        s_logisimNet149;
   wire        s_logisimNet15;
   wire        s_logisimNet150;
   wire        s_logisimNet151;
   wire        s_logisimNet152;
   wire        s_logisimNet153;
   wire        s_logisimNet154;
   wire        s_logisimNet155;
   wire        s_logisimNet156;
   wire        s_logisimNet157;
   wire        s_logisimNet158;
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
   wire        s_logisimNet40;
   wire        s_logisimNet41;
   wire        s_logisimNet42;
   wire        s_logisimNet43;
   wire        s_logisimNet44;
   wire        s_logisimNet51;
   wire        s_logisimNet53;
   wire        s_logisimNet54;
   wire        s_logisimNet55;
   wire        s_logisimNet56;
   wire        s_logisimNet57;
   wire        s_logisimNet58;
   wire        s_logisimNet59;
   wire        s_logisimNet60;
   wire        s_logisimNet61;
   wire        s_logisimNet62;
   wire        s_logisimNet63;
   wire        s_logisimNet64;
   wire        s_logisimNet65;
   wire        s_logisimNet66;
   wire        s_logisimNet68;
   wire        s_logisimNet75;
   wire        s_logisimNet76;
   wire        s_logisimNet77;
   wire        s_logisimNet78;
   wire        s_logisimNet79;
   wire        s_logisimNet80;
   wire        s_logisimNet81;
   wire        s_logisimNet82;
   wire        s_logisimNet83;
   wire        s_logisimNet84;
   wire        s_logisimNet85;
   wire        s_logisimNet86;
   wire        s_logisimNet87;
   wire        s_logisimNet88;
   wire        s_logisimNet89;
   wire        s_logisimNet9;
   wire        s_logisimNet90;
   wire        s_logisimNet91;
   wire        s_logisimNet92;
   wire        s_logisimNet93;
   wire        s_logisimNet95;
   wire        s_logisimNet96;
   wire        s_logisimNet97;
   wire        s_logisimNet98;
   wire        s_logisimNet99;

   /*******************************************************************************
   ** The module functionality is described here                                 **
   *******************************************************************************/

   /*******************************************************************************
   ** Here all input connections are defined                                     **
   *******************************************************************************/
   assign s_logisimBus4[63:0] = CSBITS_io;
   assign s_logisimBus71[3:0] = EW_3_0_n;
   assign s_logisimNet2       = WCS_n;
   assign s_logisimNet3       = ECSL_n;

   /*******************************************************************************
   ** Here all output connections are defined                                    **
   *******************************************************************************/
   assign IDB_15_0_io = s_logisimBus46[15:0];

   /*******************************************************************************
   ** Here all sub-circuits are defined                                          **
   *******************************************************************************/

   TTL_74245   CHIP_27B (.A1(s_logisimBus4[23]),
                         .A2(s_logisimBus4[22]),
                         .A3(s_logisimBus4[21]),
                         .A4(s_logisimBus4[20]),
                         .A5(s_logisimBus4[19]),
                         .A6(s_logisimBus4[18]),
                         .A7(s_logisimBus4[17]),
                         .A8(s_logisimBus4[16]),
                         .B1(s_logisimBus52[7]),
                         .B2(s_logisimBus52[6]),
                         .B3(s_logisimBus52[5]),
                         .B4(s_logisimBus52[4]),
                         .B5(s_logisimBus52[3]),
                         .B6(s_logisimBus52[2]),
                         .B7(s_logisimBus52[1]),
                         .B8(s_logisimBus52[0]),
                         .DIR(s_logisimNet2),
                         .G_n(s_logisimBus71[1]));

   TTL_74245   CHIP_29B (.A1(s_logisimBus4[7]),
                         .A2(s_logisimBus4[6]),
                         .A3(s_logisimBus4[5]),
                         .A4(s_logisimBus4[4]),
                         .A5(s_logisimBus4[3]),
                         .A6(s_logisimBus4[2]),
                         .A7(s_logisimBus4[1]),
                         .A8(s_logisimBus4[0]),
                         .B1(s_logisimBus26[7]),
                         .B2(s_logisimBus26[6]),
                         .B3(s_logisimBus26[5]),
                         .B4(s_logisimBus26[4]),
                         .B5(s_logisimBus26[3]),
                         .B6(s_logisimBus26[2]),
                         .B7(s_logisimBus26[1]),
                         .B8(s_logisimBus26[0]),
                         .DIR(s_logisimNet2),
                         .G_n(s_logisimBus71[0]));

   TTL_74245   CHIP_19D (.A1(s_logisimBus4[55]),
                         .A2(s_logisimBus4[54]),
                         .A3(s_logisimBus4[53]),
                         .A4(s_logisimBus4[52]),
                         .A5(s_logisimBus4[51]),
                         .A6(s_logisimBus4[50]),
                         .A7(s_logisimBus4[49]),
                         .A8(s_logisimBus4[48]),
                         .B1(s_logisimBus46[7]),
                         .B2(s_logisimBus46[6]),
                         .B3(s_logisimBus46[5]),
                         .B4(s_logisimBus46[4]),
                         .B5(s_logisimBus46[3]),
                         .B6(s_logisimBus46[2]),
                         .B7(s_logisimBus46[1]),
                         .B8(s_logisimBus46[0]),
                         .DIR(s_logisimNet2),
                         .G_n(s_logisimBus71[3]));

   TTL_74245   CHIP_21B (.A1(s_logisimBus4[39]),
                         .A2(s_logisimBus4[38]),
                         .A3(s_logisimBus4[37]),
                         .A4(s_logisimBus4[36]),
                         .A5(s_logisimBus4[35]),
                         .A6(s_logisimBus4[34]),
                         .A7(s_logisimBus4[33]),
                         .A8(s_logisimBus4[32]),
                         .B1(s_logisimBus70[7]),
                         .B2(s_logisimBus70[6]),
                         .B3(s_logisimBus70[5]),
                         .B4(s_logisimBus70[4]),
                         .B5(s_logisimBus70[3]),
                         .B6(s_logisimBus70[2]),
                         .B7(s_logisimBus70[1]),
                         .B8(s_logisimBus70[0]),
                         .DIR(s_logisimNet2),
                         .G_n(s_logisimBus71[2]));

   TTL_74373   CHIP_9C (.C(s_logisimNet3),
                        .D_7_0(s_logisimBus46[15:8]),
                        .OE_n(s_logisimNet3),
                        .Q_7_0(s_logisimBus45[7:0]));

   TTL_74373   CHIP_8C (.C(s_logisimNet3),
                        .D_7_0(s_logisimBus46[7:0]),
                        .OE_n(s_logisimNet3),
                        .Q_7_0(s_logisimBus67[7:0]));

   TTL_74245   CHIP_24B (.A1(s_logisimBus4[31]),
                         .A2(s_logisimBus4[30]),
                         .A3(s_logisimBus4[29]),
                         .A4(s_logisimBus4[28]),
                         .A5(s_logisimBus4[27]),
                         .A6(s_logisimBus4[26]),
                         .A7(s_logisimBus4[25]),
                         .A8(s_logisimBus4[24]),
                         .B1(s_logisimBus50[7]),
                         .B2(s_logisimBus50[6]),
                         .B3(s_logisimBus50[5]),
                         .B4(s_logisimBus50[4]),
                         .B5(s_logisimBus50[3]),
                         .B6(s_logisimBus50[2]),
                         .B7(s_logisimBus50[1]),
                         .B8(s_logisimBus50[0]),
                         .DIR(s_logisimNet2),
                         .G_n(s_logisimBus71[1]));

   TTL_74245   CHIP_28B (.A1(s_logisimBus4[15]),
                         .A2(s_logisimBus4[14]),
                         .A3(s_logisimBus4[13]),
                         .A4(s_logisimBus4[12]),
                         .A5(s_logisimBus4[11]),
                         .A6(s_logisimBus4[10]),
                         .A7(s_logisimBus4[9]),
                         .A8(s_logisimBus4[8]),
                         .B1(s_logisimBus94[7]),
                         .B2(s_logisimBus94[6]),
                         .B3(s_logisimBus94[5]),
                         .B4(s_logisimBus94[4]),
                         .B5(s_logisimBus94[3]),
                         .B6(s_logisimBus94[2]),
                         .B7(s_logisimBus94[1]),
                         .B8(s_logisimBus94[0]),
                         .DIR(s_logisimNet2),
                         .G_n(s_logisimBus71[0]));

   TTL_74245   CHIP_16B (.A1(s_logisimBus4[63]),
                         .A2(s_logisimBus4[62]),
                         .A3(s_logisimBus4[61]),
                         .A4(s_logisimBus4[60]),
                         .A5(s_logisimBus4[59]),
                         .A6(s_logisimBus4[58]),
                         .A7(s_logisimBus4[57]),
                         .A8(s_logisimBus4[56]),
                         .B1(s_logisimBus46[15]),
                         .B2(s_logisimBus46[14]),
                         .B3(s_logisimBus46[13]),
                         .B4(s_logisimBus46[12]),
                         .B5(s_logisimBus46[11]),
                         .B6(s_logisimBus46[10]),
                         .B7(s_logisimBus46[9]),
                         .B8(s_logisimBus46[8]),
                         .DIR(s_logisimNet2),
                         .G_n(s_logisimBus71[3]));

   TTL_74245   CHIP_20B (.A1(s_logisimBus4[47]),
                         .A2(s_logisimBus4[46]),
                         .A3(s_logisimBus4[45]),
                         .A4(s_logisimBus4[44]),
                         .A5(s_logisimBus4[43]),
                         .A6(s_logisimBus4[42]),
                         .A7(s_logisimBus4[41]),
                         .A8(s_logisimBus4[40]),
                         .B1(s_logisimBus49[7]),
                         .B2(s_logisimBus49[6]),
                         .B3(s_logisimBus49[5]),
                         .B4(s_logisimBus49[4]),
                         .B5(s_logisimBus49[3]),
                         .B6(s_logisimBus49[2]),
                         .B7(s_logisimBus49[1]),
                         .B8(s_logisimBus49[0]),
                         .DIR(s_logisimNet2),
                         .G_n(s_logisimBus71[2]));

endmodule

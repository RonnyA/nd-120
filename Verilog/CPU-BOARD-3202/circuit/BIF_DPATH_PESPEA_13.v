/******************************************************************************
 ** Logisim-evolution goes FPGA automatic generated Verilog code             **
 ** https://github.com/logisim-evolution/                                    **
 **                                                                          **
 ** Component : BIF_DPATH_PESPEA_13                                          **
 **                                                                          **
 *****************************************************************************/

module BIF_DPATH_PESPEA_13( BD_23_0_n,
                            EPEA_n,
                            EPES_n,
                            FETCH,
                            GNT_n,
                            IDB_15_0,
                            SPEA,
                            SPES );

   /*******************************************************************************
   ** The inputs are defined here                                                **
   *******************************************************************************/
   input [23:0] BD_23_0_n;
   input        EPEA_n;
   input        EPES_n;
   input        FETCH;
   input        GNT_n;
   input        SPEA;
   input        SPES;

   /*******************************************************************************
   ** The outputs are defined here                                               **
   *******************************************************************************/
   output [15:0] IDB_15_0;

   /*******************************************************************************
   ** The wires are defined here                                                 **
   *******************************************************************************/
   wire [15:0] s_logisimBus18;
   wire [23:0] s_logisimBus2;
   wire [15:0] s_logisimBus22;
   wire        s_logisimNet10;
   wire        s_logisimNet11;
   wire        s_logisimNet12;
   wire        s_logisimNet14;
   wire        s_logisimNet15;
   wire        s_logisimNet16;
   wire        s_logisimNet17;
   wire        s_logisimNet19;
   wire        s_logisimNet20;
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
   wire        s_logisimNet75;
   wire        s_logisimNet76;
   wire        s_logisimNet77;
   wire        s_logisimNet78;
   wire        s_logisimNet8;
   wire        s_logisimNet9;

   /*******************************************************************************
   ** The module functionality is described here                                 **
   *******************************************************************************/

   /*******************************************************************************
   ** Here all input connections are defined                                     **
   *******************************************************************************/
   assign s_logisimBus2[23:0] = BD_23_0_n;
   assign s_logisimNet11      = EPEA_n;
   assign s_logisimNet12      = EPES_n;
   assign s_logisimNet19      = SPEA;
   assign s_logisimNet20      = SPES;
   assign s_logisimNet60      = GNT_n;
   assign s_logisimNet61      = FETCH;

   /*******************************************************************************
   ** Here all output connections are defined                                    **
   *******************************************************************************/
   assign IDB_15_0 = s_logisimBus18[15:0];

   /*******************************************************************************
   ** Here all in-lined components are defined                                   **
   *******************************************************************************/

   // Controlled Buffer

   // NOT Gate
   assign s_logisimNet40 = ~s_logisimNet61;

   /*******************************************************************************
   ** Here all sub-circuits are defined                                          **
   *******************************************************************************/

   TTL_74534   CHIP_9A (.CK(s_logisimNet19),
                        .D1(s_logisimBus2[15]),
                        .D2(s_logisimBus2[14]),
                        .D3(s_logisimBus2[13]),
                        .D4(s_logisimBus2[12]),
                        .D5(s_logisimBus2[11]),
                        .D6(s_logisimBus2[10]),
                        .D7(s_logisimBus2[9]),
                        .D8(s_logisimBus2[8]),
                        .OE_n(s_logisimNet11),
                        .Q1_n(s_logisimBus18[15]),
                        .Q2_n(s_logisimBus18[14]),
                        .Q3_n(s_logisimBus18[13]),
                        .Q4_n(s_logisimBus18[12]),
                        .Q5_n(s_logisimBus18[11]),
                        .Q6_n(s_logisimBus18[10]),
                        .Q7_n(s_logisimBus18[9]),
                        .Q8_n(s_logisimBus18[8]));

   TTL_74534   CHIP_8A (.CK(s_logisimNet19),
                        .D1(s_logisimBus2[7]),
                        .D2(s_logisimBus2[6]),
                        .D3(s_logisimBus2[5]),
                        .D4(s_logisimBus2[4]),
                        .D5(s_logisimBus2[3]),
                        .D6(s_logisimBus2[2]),
                        .D7(s_logisimBus2[1]),
                        .D8(s_logisimBus2[0]),
                        .OE_n(s_logisimNet11),
                        .Q1_n(s_logisimBus18[7]),
                        .Q2_n(s_logisimBus18[6]),
                        .Q3_n(s_logisimBus18[5]),
                        .Q4_n(s_logisimBus18[4]),
                        .Q5_n(s_logisimBus18[3]),
                        .Q6_n(s_logisimBus18[2]),
                        .Q7_n(s_logisimBus18[1]),
                        .Q8_n(s_logisimBus18[0]));

   TTL_74534   CHIP_12A (.CK(s_logisimNet20),
                         .D1(s_logisimNet40),
                         .D2(s_logisimNet60),
                         .D3(s_logisimBus2[21]),
                         .D4(s_logisimBus2[20]),
                         .D5(s_logisimBus2[19]),
                         .D6(s_logisimBus2[18]),
                         .D7(s_logisimBus2[17]),
                         .D8(s_logisimBus2[16]),
                         .OE_n(s_logisimNet12),
                         .Q1_n(s_logisimBus22[15]),
                         .Q2_n(s_logisimBus22[14]),
                         .Q3_n(s_logisimBus22[13]),
                         .Q4_n(s_logisimBus22[12]),
                         .Q5_n(s_logisimBus22[11]),
                         .Q6_n(s_logisimBus22[10]),
                         .Q7_n(s_logisimBus22[9]),
                         .Q8_n(s_logisimBus22[8]));

   TTL_74534   CHIP_10A (.CK(s_logisimNet19),
                         .D1(s_logisimBus2[23]),
                         .D2(s_logisimBus2[22]),
                         .D3(s_logisimBus2[21]),
                         .D4(s_logisimBus2[20]),
                         .D5(s_logisimBus2[19]),
                         .D6(s_logisimBus2[18]),
                         .D7(s_logisimBus2[17]),
                         .D8(s_logisimBus2[16]),
                         .OE_n(s_logisimNet12),
                         .Q1_n(s_logisimBus22[7]),
                         .Q2_n(s_logisimBus22[6]),
                         .Q3_n(s_logisimBus22[5]),
                         .Q4_n(s_logisimBus22[4]),
                         .Q5_n(s_logisimBus22[3]),
                         .Q6_n(s_logisimBus22[2]),
                         .Q7_n(s_logisimBus22[1]),
                         .Q8_n(s_logisimBus22[0]));

endmodule

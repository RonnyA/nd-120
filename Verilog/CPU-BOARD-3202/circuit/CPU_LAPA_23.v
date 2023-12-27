/******************************************************************************
 ** Logisim-evolution goes FPGA automatic generated Verilog code             **
 ** https://github.com/logisim-evolution/                                    **
 **                                                                          **
 ** Component : CPU_LAPA_23                                                  **
 **                                                                          **
 *****************************************************************************/

module CPU_LAPA_23( LAPA_n,
                    LA_23_10,
                    PPN_23_10 );

   /*******************************************************************************
   ** The inputs are defined here                                                **
   *******************************************************************************/
   input        LAPA_n;
   input [13:0] LA_23_10;

   /*******************************************************************************
   ** The outputs are defined here                                               **
   *******************************************************************************/
   output [13:0] PPN_23_10;

   /*******************************************************************************
   ** The wires are defined here                                                 **
   *******************************************************************************/
   wire [13:0] s_logisimBus14;
   wire [13:0] s_logisimBus20;
   wire        s_logisimNet0;
   wire        s_logisimNet1;
   wire        s_logisimNet10;
   wire        s_logisimNet11;
   wire        s_logisimNet12;
   wire        s_logisimNet13;
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
   assign s_logisimBus20[13:0] = LA_23_10;
   assign s_logisimNet11       = LAPA_n;

   /*******************************************************************************
   ** Here all output connections are defined                                    **
   *******************************************************************************/
   assign PPN_23_10 = s_logisimBus14[13:0];

   /*******************************************************************************
   ** Here all sub-circuits are defined                                          **
   *******************************************************************************/

   TTL_74244   CHIP_5G (.I0_1A1(1'b0),
                        .I1_1A2(1'b0),
                        .I2_1A3(s_logisimBus20[0]),
                        .I3_1A4(s_logisimBus20[1]),
                        .I4_2A1(s_logisimBus20[2]),
                        .I5_2A2(s_logisimBus20[3]),
                        .I6_2A3(s_logisimBus20[4]),
                        .I7_2A4(s_logisimBus20[5]),
                        .O0_1Y1(),
                        .O1_1Y2(),
                        .O2_1Y3(s_logisimBus14[0]),
                        .O3_1Y4(s_logisimBus14[1]),
                        .O4_2Y1(s_logisimBus14[2]),
                        .O5_2Y2(s_logisimBus14[3]),
                        .O6_2Y3(s_logisimBus14[4]),
                        .O7_2Y4(s_logisimBus14[5]),
                        .OE1_1G_n(s_logisimNet11),
                        .OE2_2G_n(s_logisimNet11));

   TTL_74244   CHIP_23H (.I0_1A1(s_logisimBus20[6]),
                         .I1_1A2(s_logisimBus20[7]),
                         .I2_1A3(s_logisimBus20[8]),
                         .I3_1A4(s_logisimBus20[9]),
                         .I4_2A1(s_logisimBus20[10]),
                         .I5_2A2(s_logisimBus20[11]),
                         .I6_2A3(s_logisimBus20[12]),
                         .I7_2A4(s_logisimBus20[13]),
                         .O0_1Y1(s_logisimBus14[6]),
                         .O1_1Y2(s_logisimBus14[7]),
                         .O2_1Y3(s_logisimBus14[8]),
                         .O3_1Y4(s_logisimBus14[9]),
                         .O4_2Y1(s_logisimBus14[10]),
                         .O5_2Y2(s_logisimBus14[11]),
                         .O6_2Y3(s_logisimBus14[12]),
                         .O7_2Y4(s_logisimBus14[13]),
                         .OE1_1G_n(s_logisimNet11),
                         .OE2_2G_n(s_logisimNet11));

endmodule

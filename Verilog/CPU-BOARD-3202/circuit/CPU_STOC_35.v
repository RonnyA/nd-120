/******************************************************************************
 ** Logisim-evolution goes FPGA automatic generated Verilog code             **
 ** https://github.com/logisim-evolution/                                    **
 **                                                                          **
 ** Component : CPU_STOC_35                                                  **
 **                                                                          **
 *****************************************************************************/

module CPU_STOC_35( CD_15_0,
                    IDB_15_0,
                    STOC_n );

   /*******************************************************************************
   ** The inputs are defined here                                                **
   *******************************************************************************/
   input [15:0] IDB_15_0;
   input        STOC_n;

   /*******************************************************************************
   ** The outputs are defined here                                               **
   *******************************************************************************/
   output [15:0] CD_15_0;

   /*******************************************************************************
   ** The wires are defined here                                                 **
   *******************************************************************************/
   wire [15:0] s_logisimBus0;
   wire [15:0] s_logisimBus15;
   wire        s_logisimNet10;
   wire        s_logisimNet11;
   wire        s_logisimNet12;
   wire        s_logisimNet13;
   wire        s_logisimNet16;
   wire        s_logisimNet17;
   wire        s_logisimNet18;
   wire        s_logisimNet19;
   wire        s_logisimNet20;
   wire        s_logisimNet21;
   wire        s_logisimNet22;
   wire        s_logisimNet26;
   wire        s_logisimNet27;
   wire        s_logisimNet28;
   wire        s_logisimNet29;
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
   assign s_logisimBus15[15:0] = IDB_15_0;
   assign s_logisimNet5        = STOC_n;

   /*******************************************************************************
   ** Here all output connections are defined                                    **
   *******************************************************************************/
   assign CD_15_0 = s_logisimBus0[15:0];

   /*******************************************************************************
   ** Here all sub-circuits are defined                                          **
   *******************************************************************************/

   TTL_74244   CHIP_14B (.I0_1A1(s_logisimBus15[15]),
                         .I1_1A2(s_logisimBus15[14]),
                         .I2_1A3(s_logisimBus15[13]),
                         .I3_1A4(s_logisimBus15[12]),
                         .I4_2A1(s_logisimBus15[11]),
                         .I5_2A2(s_logisimBus15[10]),
                         .I6_2A3(s_logisimBus15[9]),
                         .I7_2A4(s_logisimBus15[8]),
                         .O0_1Y1(s_logisimBus0[15]),
                         .O1_1Y2(s_logisimBus0[14]),
                         .O2_1Y3(s_logisimBus0[13]),
                         .O3_1Y4(s_logisimBus0[12]),
                         .O4_2Y1(s_logisimBus0[11]),
                         .O5_2Y2(s_logisimBus0[10]),
                         .O6_2Y3(s_logisimBus0[9]),
                         .O7_2Y4(s_logisimBus0[8]),
                         .OE1_1G_n(s_logisimNet5),
                         .OE2_2G_n(s_logisimNet5));

   TTL_74244   CHIP_15D (.I0_1A1(s_logisimBus15[7]),
                         .I1_1A2(s_logisimBus15[6]),
                         .I2_1A3(s_logisimBus15[5]),
                         .I3_1A4(s_logisimBus15[4]),
                         .I4_2A1(s_logisimBus15[3]),
                         .I5_2A2(s_logisimBus15[2]),
                         .I6_2A3(s_logisimBus15[1]),
                         .I7_2A4(s_logisimBus15[0]),
                         .O0_1Y1(s_logisimBus0[7]),
                         .O1_1Y2(s_logisimBus0[6]),
                         .O2_1Y3(s_logisimBus0[5]),
                         .O3_1Y4(s_logisimBus0[4]),
                         .O4_2Y1(s_logisimBus0[3]),
                         .O5_2Y2(s_logisimBus0[2]),
                         .O6_2Y3(s_logisimBus0[1]),
                         .O7_2Y4(s_logisimBus0[0]),
                         .OE1_1G_n(s_logisimNet5),
                         .OE2_2G_n(s_logisimNet5));

endmodule

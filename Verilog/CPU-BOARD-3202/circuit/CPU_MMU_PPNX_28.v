/******************************************************************************
 ** Logisim-evolution goes FPGA automatic generated Verilog code             **
 ** https://github.com/logisim-evolution/                                    **
 **                                                                          **
 ** Component : CPU_MMU_PPNX_28                                              **
 **                                                                          **
 *****************************************************************************/

module CPU_MMU_PPNX_28( EIPL_n,
                        EIPUR_n,
                        EIPU_n,
                        ESTOF_n,
                        IDB_15_0_io,
                        PPN_25_10_io );

   /*******************************************************************************
   ** The inputs are defined here                                                **
   *******************************************************************************/
   input EIPL_n;
   input EIPUR_n;
   input EIPU_n;
   input ESTOF_n;

   /*******************************************************************************
   ** The outputs are defined here                                               **
   *******************************************************************************/
   output [15:0] IDB_15_0_io;
   output [15:0] PPN_25_10_io;

   /*******************************************************************************
   ** The wires are defined here                                                 **
   *******************************************************************************/
   wire [15:0] s_logisimBus17;
   wire [15:0] s_logisimBus50;
   wire        s_logisimNet0;
   wire        s_logisimNet1;
   wire        s_logisimNet10;
   wire        s_logisimNet11;
   wire        s_logisimNet12;
   wire        s_logisimNet13;
   wire        s_logisimNet14;
   wire        s_logisimNet15;
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
   wire        s_logisimNet6;
   wire        s_logisimNet8;
   wire        s_logisimNet9;

   /*******************************************************************************
   ** The module functionality is described here                                 **
   *******************************************************************************/

   /*******************************************************************************
   ** Here all input connections are defined                                     **
   *******************************************************************************/
   assign s_logisimNet18 = ESTOF_n;
   assign s_logisimNet19 = EIPL_n;
   assign s_logisimNet20 = EIPU_n;
   assign s_logisimNet40 = EIPUR_n;

   /*******************************************************************************
   ** Here all output connections are defined                                    **
   *******************************************************************************/
   assign IDB_15_0_io  = s_logisimBus50[15:0];
   assign PPN_25_10_io = s_logisimBus17[15:0];

   /*******************************************************************************
   ** Here all in-lined components are defined                                   **
   *******************************************************************************/

   // Ground
   assign  s_logisimNet37  =  1'b0;


   /*******************************************************************************
   ** Here all sub-circuits are defined                                          **
   *******************************************************************************/

   TTL_74245   CHIP_10B (.A1(s_logisimBus17[15]),
                         .A2(s_logisimBus17[14]),
                         .A3(s_logisimBus17[13]),
                         .A4(s_logisimBus17[12]),
                         .A5(s_logisimBus17[11]),
                         .A6(s_logisimBus17[10]),
                         .A7(s_logisimBus17[9]),
                         .A8(s_logisimBus17[8]),
                         .B1(s_logisimBus50[15]),
                         .B2(s_logisimBus50[14]),
                         .B3(s_logisimBus50[13]),
                         .B4(s_logisimBus50[12]),
                         .B5(s_logisimBus50[11]),
                         .B6(s_logisimBus50[10]),
                         .B7(s_logisimBus50[9]),
                         .B8(s_logisimBus50[8]),
                         .DIR(s_logisimNet18),
                         .G_n(s_logisimNet20));

   TTL_74245   CHIP_9B (.A1(s_logisimBus17[7]),
                        .A2(s_logisimBus17[6]),
                        .A3(s_logisimBus17[5]),
                        .A4(s_logisimBus17[4]),
                        .A5(s_logisimBus17[3]),
                        .A6(s_logisimBus17[2]),
                        .A7(s_logisimBus17[1]),
                        .A8(s_logisimBus17[0]),
                        .B1(s_logisimBus50[7]),
                        .B2(s_logisimBus50[6]),
                        .B3(s_logisimBus50[5]),
                        .B4(s_logisimBus50[4]),
                        .B5(s_logisimBus50[3]),
                        .B6(s_logisimBus50[2]),
                        .B7(s_logisimBus50[1]),
                        .B8(s_logisimBus50[0]),
                        .DIR(s_logisimNet18),
                        .G_n(s_logisimNet19));

   TTL_74244   CHIP_8B (.I0_1A1(s_logisimNet37),
                        .I1_1A2(s_logisimNet37),
                        .I2_1A3(s_logisimNet37),
                        .I3_1A4(s_logisimNet37),
                        .I4_2A1(s_logisimNet37),
                        .I5_2A2(s_logisimNet37),
                        .I6_2A3(s_logisimNet37),
                        .I7_2A4(s_logisimBus50[8]),
                        .O0_1Y1(s_logisimBus17[15]),
                        .O1_1Y2(s_logisimBus17[14]),
                        .O2_1Y3(s_logisimBus17[13]),
                        .O3_1Y4(s_logisimBus17[12]),
                        .O4_2Y1(s_logisimBus17[11]),
                        .O5_2Y2(s_logisimBus17[10]),
                        .O6_2Y3(s_logisimBus17[9]),
                        .O7_2Y4(s_logisimBus17[8]),
                        .OE1_1G_n(s_logisimNet40),
                        .OE2_2G_n(s_logisimNet40));

endmodule

/******************************************************************************
 ** Logisim-evolution goes FPGA automatic generated Verilog code             **
 ** https://github.com/logisim-evolution/                                    **
 **                                                                          **
 ** Component : CPU_CS_ACAL_17                                               **
 **                                                                          **
 *****************************************************************************/

module CPU_CS_ACAL_17( CLK,
                       CSA_12_0,
                       CSCA_9_0,
                       LUA_12_0,
                       MACLK,
                       PD1,
                       UUA_11_0 );

   /*******************************************************************************
   ** The inputs are defined here                                                **
   *******************************************************************************/
   input        CLK;
   input [12:0] CSA_12_0;
   input [9:0]  CSCA_9_0;
   input        MACLK;
   input        PD1;

   /*******************************************************************************
   ** The outputs are defined here                                               **
   *******************************************************************************/
   output [12:0] LUA_12_0;
   output [11:0] UUA_11_0;

   /*******************************************************************************
   ** The wires are defined here                                                 **
   *******************************************************************************/
   wire [9:0]  s_logisimBus32;
   wire [9:0]  s_logisimBus34;
   wire [7:0]  s_logisimBus47;
   wire [12:0] s_logisimBus48;
   wire [12:0] s_logisimBus66;
   wire [11:0] s_logisimBus82;
   wire [7:0]  s_logisimBus83;
   wire        s_logisimNet0;
   wire        s_logisimNet1;
   wire        s_logisimNet10;
   wire        s_logisimNet11;
   wire        s_logisimNet12;
   wire        s_logisimNet13;
   wire        s_logisimNet14;
   wire        s_logisimNet15;
   wire        s_logisimNet16;
   wire        s_logisimNet17;
   wire        s_logisimNet18;
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
   wire        s_logisimNet33;
   wire        s_logisimNet35;
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
   wire        s_logisimNet49;
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
   wire        s_logisimNet79;
   wire        s_logisimNet8;
   wire        s_logisimNet80;
   wire        s_logisimNet81;
   wire        s_logisimNet9;

   /*******************************************************************************
   ** The module functionality is described here                                 **
   *******************************************************************************/

   /*******************************************************************************
   ** Here all wiring is defined                                                 **
   *******************************************************************************/
   assign s_logisimBus66[10] = s_logisimNet3;
   assign s_logisimBus66[11] = s_logisimNet1;
   assign s_logisimBus66[12] = s_logisimNet33;
   assign s_logisimBus82[10] = s_logisimNet18;
   assign s_logisimBus82[11] = s_logisimNet6;
   assign s_logisimBus83[0]  = s_logisimNet20;
   assign s_logisimBus83[1]  = s_logisimNet4;
   assign s_logisimBus83[2]  = s_logisimNet21;
   assign s_logisimNet1      = s_logisimBus47[1];
   assign s_logisimNet18     = s_logisimBus47[6];
   assign s_logisimNet20     = s_logisimBus48[12];
   assign s_logisimNet21     = s_logisimBus48[10];
   assign s_logisimNet3      = s_logisimBus47[2];
   assign s_logisimNet33     = s_logisimBus47[0];
   assign s_logisimNet4      = s_logisimBus48[11];
   assign s_logisimNet6      = s_logisimBus47[5];

   /*******************************************************************************
   ** Here all input connections are defined                                     **
   *******************************************************************************/
   assign s_logisimBus34[9:0]  = CSCA_9_0;
   assign s_logisimBus48[12:0] = CSA_12_0;
   assign s_logisimNet0        = PD1;
   assign s_logisimNet2        = MACLK;
   assign s_logisimNet49       = CLK;

   /*******************************************************************************
   ** Here all output connections are defined                                    **
   *******************************************************************************/
   assign LUA_12_0 = s_logisimBus66[12:0];
   assign UUA_11_0 = s_logisimBus82[11:0];

   /*******************************************************************************
   ** Here all normal components are defined                                     **
   *******************************************************************************/
   NAND_GATE #(.BubblesMask(2'b00))
      GATES_1 (.input1(s_logisimNet33),
               .input2(s_logisimNet33),
               .result(s_logisimNet35));

   OR_GATE #(.BubblesMask(2'b00))
      GATES_2 (.input1(s_logisimNet4),
               .input2(s_logisimNet35),
               .result(s_logisimBus83[5]));

   OR_GATE #(.BubblesMask(2'b00))
      GATES_3 (.input1(s_logisimNet21),
               .input2(s_logisimNet35),
               .result(s_logisimBus83[6]));


   /*******************************************************************************
   ** Here all sub-circuits are defined                                          **
   *******************************************************************************/

   AM29841   CHIP_32G (.D0(s_logisimBus48[9]),
                       .D1(s_logisimBus48[8]),
                       .D2(s_logisimBus48[7]),
                       .D3(s_logisimBus48[6]),
                       .D4(s_logisimBus48[5]),
                       .D5(s_logisimBus48[4]),
                       .D6(s_logisimBus48[3]),
                       .D7(s_logisimBus48[2]),
                       .D8(s_logisimBus48[1]),
                       .D9(s_logisimBus48[0]),
                       .LE(s_logisimNet2),
                       .OE_n(s_logisimNet35),
                       .Y0(s_logisimBus82[9]),
                       .Y1(s_logisimBus82[8]),
                       .Y2(s_logisimBus82[7]),
                       .Y3(s_logisimBus82[6]),
                       .Y4(s_logisimBus82[5]),
                       .Y5(s_logisimBus82[4]),
                       .Y6(s_logisimBus82[3]),
                       .Y7(s_logisimBus82[2]),
                       .Y8(s_logisimBus82[1]),
                       .Y9(s_logisimBus82[0]));

   AM29841   CHIP_31G (.D0(s_logisimBus34[9]),
                       .D1(s_logisimBus34[8]),
                       .D2(s_logisimBus34[7]),
                       .D3(s_logisimBus34[6]),
                       .D4(s_logisimBus34[5]),
                       .D5(s_logisimBus34[4]),
                       .D6(s_logisimBus34[3]),
                       .D7(s_logisimBus34[2]),
                       .D8(s_logisimBus34[1]),
                       .D9(s_logisimBus34[0]),
                       .LE(s_logisimNet49),
                       .OE_n(s_logisimNet33),
                       .Y0(s_logisimBus32[9]),
                       .Y1(s_logisimBus32[8]),
                       .Y2(s_logisimBus32[7]),
                       .Y3(s_logisimBus32[6]),
                       .Y4(s_logisimBus32[5]),
                       .Y5(s_logisimBus32[4]),
                       .Y6(s_logisimBus32[3]),
                       .Y7(s_logisimBus32[2]),
                       .Y8(s_logisimBus32[1]),
                       .Y9(s_logisimBus32[0]));

   TTL_74373   CHIP_30H (.C(s_logisimNet2),
                         .D_7_0(s_logisimBus83[7:0]),
                         .OE_n(s_logisimNet0),
                         .Q_7_0(s_logisimBus47[7:0]));

   AM29841   CHIP_31F (.D0(s_logisimBus48[9]),
                       .D1(s_logisimBus48[8]),
                       .D2(s_logisimBus48[7]),
                       .D3(s_logisimBus48[6]),
                       .D4(s_logisimBus48[5]),
                       .D5(s_logisimBus48[4]),
                       .D6(s_logisimBus48[3]),
                       .D7(s_logisimBus48[2]),
                       .D8(s_logisimBus48[1]),
                       .D9(s_logisimBus48[0]),
                       .LE(s_logisimNet2),
                       .OE_n(s_logisimNet0),
                       .Y0(s_logisimBus66[9]),
                       .Y1(s_logisimBus66[8]),
                       .Y2(s_logisimBus66[7]),
                       .Y3(s_logisimBus66[6]),
                       .Y4(s_logisimBus66[5]),
                       .Y5(s_logisimBus66[4]),
                       .Y6(s_logisimBus66[3]),
                       .Y7(s_logisimBus66[2]),
                       .Y8(s_logisimBus66[1]),
                       .Y9(s_logisimBus66[0]));

endmodule

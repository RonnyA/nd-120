/******************************************************************************
 ** Logisim-evolution goes FPGA automatic generated Verilog code             **
 ** https://github.com/logisim-evolution/                                    **
 **                                                                          **
 ** Component : IO_REG_41                                                    **
 **                                                                          **
 *****************************************************************************/

module IO_REG_41( BINT10_n,
                  BINT12_n,
                  BINT13_n,
                  CLEAR_n,
                  CONSOLE_n,
                  CX_n,
                  DA_n,
                  EMCL_n,
                  IDB_15_0,
                  IDB_7_0_io,
                  INR_7_0,
                  RINR_n,
                  SIOC_n,
                  TBMT_n,
                  TRAALD_n,
                  logisimOutputBubbles );

   /*******************************************************************************
   ** The inputs are defined here                                                **
   *******************************************************************************/
   input       CLEAR_n;
   input       CX_n;
   input       DA_n;
   input [7:0] INR_7_0;
   input       RINR_n;
   input       SIOC_n;
   input       TBMT_n;
   input       TRAALD_n;

   /*******************************************************************************
   ** The outputs are defined here                                               **
   *******************************************************************************/
   output        BINT10_n;
   output        BINT12_n;
   output        BINT13_n;
   output        CONSOLE_n;
   output        EMCL_n;
   output [15:0] IDB_15_0;
   output [7:0]  IDB_7_0_io;
   output [1:0]  logisimOutputBubbles;

   /*******************************************************************************
   ** The wires are defined here                                                 **
   *******************************************************************************/
   wire [4:0]  s_logisimBus12;
   wire [7:0]  s_logisimBus47;
   wire [7:0]  s_logisimBus59;
   wire [3:0]  s_logisimBus62;
   wire [15:0] s_logisimBus77;
   wire        s_logisimNet0;
   wire        s_logisimNet1;
   wire        s_logisimNet10;
   wire        s_logisimNet11;
   wire        s_logisimNet13;
   wire        s_logisimNet14;
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
   wire        s_logisimNet4;
   wire        s_logisimNet40;
   wire        s_logisimNet41;
   wire        s_logisimNet42;
   wire        s_logisimNet43;
   wire        s_logisimNet44;
   wire        s_logisimNet45;
   wire        s_logisimNet46;
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
   wire        s_logisimNet6;
   wire        s_logisimNet60;
   wire        s_logisimNet61;
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
   wire        s_logisimNet78;
   wire        s_logisimNet79;
   wire        s_logisimNet8;
   wire        s_logisimNet80;
   wire        s_logisimNet81;
   wire        s_logisimNet82;
   wire        s_logisimNet83;

   /*******************************************************************************
   ** The module functionality is described here                                 **
   *******************************************************************************/

   /*******************************************************************************
   ** Here all input connections are defined                                     **
   *******************************************************************************/
   assign s_logisimBus59[7:0] = INR_7_0;
   assign s_logisimNet16      = RINR_n;
   assign s_logisimNet34      = SIOC_n;
   assign s_logisimNet40      = CX_n;
   assign s_logisimNet43      = TBMT_n;
   assign s_logisimNet44      = CLEAR_n;
   assign s_logisimNet61      = DA_n;
   assign s_logisimNet8       = TRAALD_n;

   /*******************************************************************************
   ** Here all output connections are defined                                    **
   *******************************************************************************/
   assign BINT10_n   = s_logisimNet19;
   assign BINT12_n   = s_logisimNet63;
   assign BINT13_n   = s_logisimNet50;
   assign CONSOLE_n  = s_logisimNet76;
   assign EMCL_n     = s_logisimNet35;
   assign IDB_15_0   = s_logisimBus77[15:0];
   assign IDB_7_0_io = s_logisimBus77[7:0];

   /*******************************************************************************
   ** Here all in-lined components are defined                                   **
   *******************************************************************************/

   // Ground
   assign  s_logisimNet13  =  1'b0;


   // Power
   assign  s_logisimNet11  =  1'b1;


   // Power
   assign  s_logisimNet38  =  1'b1;


   // Constant
   assign  s_logisimBus12[4:0]  =  {1'b0, 4'h0};


   // Power
   assign  s_logisimNet48  =  1'b1;


   // Constant
   assign  s_logisimBus62[3:0]  =  4'hF;


   // Power
   assign  s_logisimNet3  =  1'b1;


   // Power
   assign  s_logisimNet60  =  1'b1;


   // NOT Gate
   assign s_logisimNet0 = ~s_logisimNet61;

   // NOT Gate
   assign s_logisimNet22 = ~s_logisimNet2;

   // LED: RED
   assign logisimOutputBubbles[0] = s_logisimNet35;

   // LED: GREEN
   assign logisimOutputBubbles[1] = s_logisimNet18;

   /*******************************************************************************
   ** Here all normal components are defined                                     **
   *******************************************************************************/
   AND_GATE #(.BubblesMask(2'b00))
      GATES_1 (.input1(s_logisimNet2),
               .input2(s_logisimNet21),
               .result(s_logisimNet20));

   NAND_GATE #(.BubblesMask(2'b00))
      GATES_2 (.input1(s_logisimNet10),
               .input2(s_logisimNet41),
               .result(s_logisimNet50));

   NAND_GATE #(.BubblesMask(2'b00))
      GATES_3 (.input1(s_logisimNet1),
               .input2(s_logisimNet43),
               .result(s_logisimNet19));

   NAND_GATE #(.BubblesMask(2'b00))
      GATES_4 (.input1(s_logisimNet20),
               .input2(s_logisimNet0),
               .result(s_logisimNet63));

   NAND_GATE #(.BubblesMask(2'b00))
      GATES_5 (.input1(s_logisimNet22),
               .input2(s_logisimNet22),
               .result(s_logisimNet76));


   /*******************************************************************************
   ** Here all sub-circuits are defined                                          **
   *******************************************************************************/

   TTL_74273   CHIP_28A_IOC (.CK(s_logisimNet34),
                             .CL_n(s_logisimNet44),
                             .D1(s_logisimBus77[7]),
                             .D2(s_logisimBus77[6]),
                             .D3(s_logisimBus77[5]),
                             .D4(s_logisimBus77[4]),
                             .D5(s_logisimBus77[3]),
                             .D6(s_logisimBus77[2]),
                             .D7(s_logisimBus77[1]),
                             .D8(s_logisimBus77[0]),
                             .Q1(s_logisimNet49),
                             .Q2(s_logisimNet2),
                             .Q3(s_logisimNet35),
                             .Q4(s_logisimNet18),
                             .Q5(s_logisimNet10),
                             .Q6(s_logisimNet1),
                             .Q7(s_logisimNet21),
                             .Q8(s_logisimNet41));

   TTL_74244   CHIP_24A_INR (.I0_1A1(s_logisimBus59[7]),
                             .I1_1A2(s_logisimBus59[6]),
                             .I2_1A3(s_logisimBus59[5]),
                             .I3_1A4(s_logisimBus59[4]),
                             .I4_2A1(s_logisimBus59[3]),
                             .I5_2A2(s_logisimBus59[2]),
                             .I6_2A3(s_logisimBus59[1]),
                             .I7_2A4(s_logisimBus59[0]),
                             .O0_1Y1(s_logisimBus47[7]),
                             .O1_1Y2(s_logisimBus47[6]),
                             .O2_1Y3(s_logisimBus47[5]),
                             .O3_1Y4(s_logisimBus47[4]),
                             .O4_2Y1(s_logisimBus47[3]),
                             .O5_2Y2(s_logisimBus47[2]),
                             .O6_2Y3(s_logisimBus47[1]),
                             .O7_2Y4(s_logisimBus47[0]),
                             .OE1_1G_n(s_logisimNet16),
                             .OE2_2G_n(s_logisimNet16));

   TTL_74244   CHIP_27A_STRAP (.I0_1A1(s_logisimNet48),
                               .I1_1A2(s_logisimNet3),
                               .I2_1A3(s_logisimNet60),
                               .I3_1A4(s_logisimBus12[0]),
                               .I4_2A1(s_logisimBus12[1]),
                               .I5_2A2(s_logisimBus12[2]),
                               .I6_2A3(s_logisimBus12[3]),
                               .I7_2A4(s_logisimBus12[4]),
                               .O0_1Y1(s_logisimBus77[15]),
                               .O1_1Y2(s_logisimBus77[14]),
                               .O2_1Y3(s_logisimBus77[13]),
                               .O3_1Y4(s_logisimBus77[12]),
                               .O4_2Y1(s_logisimBus77[11]),
                               .O5_2Y2(s_logisimBus77[10]),
                               .O6_2Y3(s_logisimBus77[9]),
                               .O7_2Y4(s_logisimBus77[8]),
                               .OE1_1G_n(s_logisimNet8),
                               .OE2_2G_n(s_logisimNet8));

   TTL_74244   CHIP_25A_ALD (.I0_1A1(s_logisimNet40),
                             .I1_1A2(s_logisimNet13),
                             .I2_1A3(s_logisimNet11),
                             .I3_1A4(s_logisimNet38),
                             .I4_2A1(s_logisimBus62[3]),
                             .I5_2A2(s_logisimBus62[2]),
                             .I6_2A3(s_logisimBus62[1]),
                             .I7_2A4(s_logisimBus62[0]),
                             .O0_1Y1(s_logisimBus77[7]),
                             .O1_1Y2(s_logisimBus77[6]),
                             .O2_1Y3(s_logisimBus77[5]),
                             .O3_1Y4(s_logisimBus77[4]),
                             .O4_2Y1(s_logisimBus77[3]),
                             .O5_2Y2(s_logisimBus77[2]),
                             .O6_2Y3(s_logisimBus77[1]),
                             .O7_2Y4(s_logisimBus77[0]),
                             .OE1_1G_n(s_logisimNet8),
                             .OE2_2G_n(s_logisimNet8));

endmodule

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
   wire [4:0]  s_logisimBus11;
   wire [7:0]  s_logisimBus48;
   wire [7:0]  s_logisimBus59;
   wire [2:0]  s_logisimBus60;
   wire [3:0]  s_logisimBus62;
   wire [15:0] s_logisimBus78;
   wire        s_logisimNet0;
   wire        s_logisimNet1;
   wire        s_logisimNet10;
   wire        s_logisimNet12;
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
   wire        s_logisimNet39;
   wire        s_logisimNet4;
   wire        s_logisimNet41;
   wire        s_logisimNet42;
   wire        s_logisimNet43;
   wire        s_logisimNet44;
   wire        s_logisimNet45;
   wire        s_logisimNet46;
   wire        s_logisimNet47;
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
   wire        s_logisimNet77;
   wire        s_logisimNet79;
   wire        s_logisimNet80;
   wire        s_logisimNet81;
   wire        s_logisimNet82;
   wire        s_logisimNet83;
   wire        s_logisimNet84;
   wire        s_logisimNet9;

   /*******************************************************************************
   ** The module functionality is described here                                 **
   *******************************************************************************/

   /*******************************************************************************
   ** Here all input connections are defined                                     **
   *******************************************************************************/
   assign s_logisimBus59[7:0] = INR_7_0;
   assign s_logisimNet14      = RINR_n;
   assign s_logisimNet33      = SIOC_n;
   assign s_logisimNet41      = CX_n;
   assign s_logisimNet44      = TBMT_n;
   assign s_logisimNet45      = CLEAR_n;
   assign s_logisimNet61      = DA_n;
   assign s_logisimNet7       = TRAALD_n;

   /*******************************************************************************
   ** Here all output connections are defined                                    **
   *******************************************************************************/
   assign BINT10_n   = s_logisimNet17;
   assign BINT12_n   = s_logisimNet63;
   assign BINT13_n   = s_logisimNet50;
   assign CONSOLE_n  = s_logisimNet77;
   assign EMCL_n     = s_logisimNet34;
   assign IDB_15_0   = s_logisimBus78[15:0];
   assign IDB_7_0_io = s_logisimBus78[7:0];

   /*******************************************************************************
   ** Here all in-lined components are defined                                   **
   *******************************************************************************/

   // Ground
   assign  s_logisimNet12  =  1'b0;


   // Power
   assign  s_logisimNet10  =  1'b1;


   // Power
   assign  s_logisimNet39  =  1'b1;


   // Constant
   assign  s_logisimBus60[2:0]  =  3'b101;


   // Constant
   assign  s_logisimBus11[4:0]  =  {1'b0, 4'h0};


   // Constant
   assign  s_logisimBus62[3:0]  =  4'hF;


   // Power

   // NOT Gate
   assign s_logisimNet0 = ~s_logisimNet61;

   // NOT Gate
   assign s_logisimNet20 = ~s_logisimNet2;

   // LED: RED
   assign logisimOutputBubbles[0] = s_logisimNet34;

   // LED: GREEN
   assign logisimOutputBubbles[1] = s_logisimNet16;

   /*******************************************************************************
   ** Here all normal components are defined                                     **
   *******************************************************************************/
   AND_GATE #(.BubblesMask(2'b00))
      GATES_1 (.input1(s_logisimNet2),
               .input2(s_logisimNet19),
               .result(s_logisimNet18));

   NAND_GATE #(.BubblesMask(2'b00))
      GATES_2 (.input1(s_logisimNet9),
               .input2(s_logisimNet42),
               .result(s_logisimNet50));

   NAND_GATE #(.BubblesMask(2'b00))
      GATES_3 (.input1(s_logisimNet1),
               .input2(s_logisimNet44),
               .result(s_logisimNet17));

   NAND_GATE #(.BubblesMask(2'b00))
      GATES_4 (.input1(s_logisimNet18),
               .input2(s_logisimNet0),
               .result(s_logisimNet63));

   NAND_GATE #(.BubblesMask(2'b00))
      GATES_5 (.input1(s_logisimNet20),
               .input2(s_logisimNet20),
               .result(s_logisimNet77));


   /*******************************************************************************
   ** Here all sub-circuits are defined                                          **
   *******************************************************************************/

   TTL_74273   CHIP_28A_IOC (.CK(s_logisimNet33),
                             .CL_n(s_logisimNet45),
                             .D1(s_logisimBus78[7]),
                             .D2(s_logisimBus78[6]),
                             .D3(s_logisimBus78[5]),
                             .D4(s_logisimBus78[4]),
                             .D5(s_logisimBus78[3]),
                             .D6(s_logisimBus78[2]),
                             .D7(s_logisimBus78[1]),
                             .D8(s_logisimBus78[0]),
                             .Q1(s_logisimNet49),
                             .Q2(s_logisimNet2),
                             .Q3(s_logisimNet34),
                             .Q4(s_logisimNet16),
                             .Q5(s_logisimNet9),
                             .Q6(s_logisimNet1),
                             .Q7(s_logisimNet19),
                             .Q8(s_logisimNet42));

   TTL_74244   CHIP_24A_INR (.I0_1A1(s_logisimBus59[7]),
                             .I1_1A2(s_logisimBus59[6]),
                             .I2_1A3(s_logisimBus59[5]),
                             .I3_1A4(s_logisimBus59[4]),
                             .I4_2A1(s_logisimBus59[3]),
                             .I5_2A2(s_logisimBus59[2]),
                             .I6_2A3(s_logisimBus59[1]),
                             .I7_2A4(s_logisimBus59[0]),
                             .O0_1Y1(s_logisimBus48[7]),
                             .O1_1Y2(s_logisimBus48[6]),
                             .O2_1Y3(s_logisimBus48[5]),
                             .O3_1Y4(s_logisimBus48[4]),
                             .O4_2Y1(s_logisimBus48[3]),
                             .O5_2Y2(s_logisimBus48[2]),
                             .O6_2Y3(s_logisimBus48[1]),
                             .O7_2Y4(s_logisimBus48[0]),
                             .OE1_1G_n(s_logisimNet14),
                             .OE2_2G_n(s_logisimNet14));

   TTL_74244   CHIP_27A_STRAP (.I0_1A1(s_logisimBus60[2]),
                               .I1_1A2(s_logisimBus60[1]),
                               .I2_1A3(s_logisimBus60[0]),
                               .I3_1A4(s_logisimBus11[0]),
                               .I4_2A1(s_logisimBus11[1]),
                               .I5_2A2(s_logisimBus11[2]),
                               .I6_2A3(s_logisimBus11[3]),
                               .I7_2A4(s_logisimBus11[4]),
                               .O0_1Y1(s_logisimBus78[15]),
                               .O1_1Y2(s_logisimBus78[14]),
                               .O2_1Y3(s_logisimBus78[13]),
                               .O3_1Y4(s_logisimBus78[12]),
                               .O4_2Y1(s_logisimBus78[11]),
                               .O5_2Y2(s_logisimBus78[10]),
                               .O6_2Y3(s_logisimBus78[9]),
                               .O7_2Y4(s_logisimBus78[8]),
                               .OE1_1G_n(s_logisimNet7),
                               .OE2_2G_n(s_logisimNet7));

   TTL_74244   CHIP_25A_ALD (.I0_1A1(s_logisimNet41),
                             .I1_1A2(s_logisimNet12),
                             .I2_1A3(s_logisimNet10),
                             .I3_1A4(s_logisimNet39),
                             .I4_2A1(s_logisimBus62[3]),
                             .I5_2A2(s_logisimBus62[2]),
                             .I6_2A3(s_logisimBus62[1]),
                             .I7_2A4(s_logisimBus62[0]),
                             .O0_1Y1(s_logisimBus78[7]),
                             .O1_1Y2(s_logisimBus78[6]),
                             .O2_1Y3(s_logisimBus78[5]),
                             .O3_1Y4(s_logisimBus78[4]),
                             .O4_2Y1(s_logisimBus78[3]),
                             .O5_2Y2(s_logisimBus78[2]),
                             .O6_2Y3(s_logisimBus78[1]),
                             .O7_2Y4(s_logisimBus78[0]),
                             .OE1_1G_n(s_logisimNet7),
                             .OE2_2G_n(s_logisimNet7));

endmodule

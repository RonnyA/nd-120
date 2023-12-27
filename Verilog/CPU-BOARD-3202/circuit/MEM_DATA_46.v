/******************************************************************************
 ** Logisim-evolution goes FPGA automatic generated Verilog code             **
 ** https://github.com/logisim-evolution/                                    **
 **                                                                          **
 ** Component : MEM_DATA_46                                                  **
 **                                                                          **
 *****************************************************************************/

module MEM_DATA_46( BCGNT50R_n,
                    BIOXL_n,
                    DD_17_0_io,
                    ECCR,
                    HIEN_n,
                    HIERR,
                    LBD_15_0_io,
                    LERR_n,
                    LOERR,
                    LPERR_n,
                    MR_n,
                    MWRITE_n,
                    PA_n,
                    QD_n,
                    RDATA,
                    logisimOutputBubbles );

   /*******************************************************************************
   ** The inputs are defined here                                                **
   *******************************************************************************/
   input        BCGNT50R_n;
   input        BIOXL_n;
   input        ECCR;
   input        HIEN_n;
   input [15:0] LBD_15_0_io;
   input        MR_n;
   input        MWRITE_n;
   input        PA_n;
   input        QD_n;
   input        RDATA;

   /*******************************************************************************
   ** The outputs are defined here                                               **
   *******************************************************************************/
   output [17:0] DD_17_0_io;
   output        HIERR;
   output        LERR_n;
   output        LOERR;
   output        LPERR_n;
   output [0:0]  logisimOutputBubbles;

   /*******************************************************************************
   ** The wires are defined here                                                 **
   *******************************************************************************/
   wire [15:0] s_logisimBus15;
   wire [17:0] s_logisimBus66;
   wire        s_logisimNet0;
   wire        s_logisimNet1;
   wire        s_logisimNet10;
   wire        s_logisimNet11;
   wire        s_logisimNet12;
   wire        s_logisimNet13;
   wire        s_logisimNet14;
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
   wire        s_logisimNet67;
   wire        s_logisimNet68;
   wire        s_logisimNet69;
   wire        s_logisimNet70;
   wire        s_logisimNet71;
   wire        s_logisimNet72;
   wire        s_logisimNet73;
   wire        s_logisimNet9;

   /*******************************************************************************
   ** The module functionality is described here                                 **
   *******************************************************************************/

   /*******************************************************************************
   ** Here all input connections are defined                                     **
   *******************************************************************************/
   assign s_logisimBus15[15:0] = LBD_15_0_io;
   assign s_logisimNet0        = RDATA;
   assign s_logisimNet36       = BIOXL_n;
   assign s_logisimNet37       = BCGNT50R_n;
   assign s_logisimNet38       = PA_n;
   assign s_logisimNet47       = QD_n;
   assign s_logisimNet5        = MR_n;
   assign s_logisimNet67       = ECCR;
   assign s_logisimNet68       = HIEN_n;
   assign s_logisimNet73       = MWRITE_n;

   /*******************************************************************************
   ** Here all output connections are defined                                    **
   *******************************************************************************/
   assign DD_17_0_io = s_logisimBus66[17:0];
   assign HIERR      = s_logisimNet4;
   assign LERR_n     = s_logisimNet1;
   assign LOERR      = s_logisimNet35;
   assign LPERR_n    = s_logisimNet45;

   /*******************************************************************************
   ** Here all in-lined components are defined                                   **
   *******************************************************************************/

   // Ground
   assign  s_logisimNet18  =  1'b0;


   // Ground
   assign  s_logisimNet46  =  1'b0;


   // Power
   assign  s_logisimNet6  =  1'b1;


   // Constant
   assign  s_logisimNet50  =  1'b1;


   // NOT Gate
   assign s_logisimNet16 = ~s_logisimNet65;

   // NOT Gate
   assign s_logisimNet21 = ~s_logisimNet51;

   // NOT Gate
   assign s_logisimNet58 = ~s_logisimNet6;

   // NOT Gate
   assign s_logisimNet49 = ~s_logisimNet6;

   // NOT Gate
   assign s_logisimNet35 = ~s_logisimNet2;

   // NOT Gate
   assign s_logisimNet4 = ~s_logisimNet34;

   // LED: LED4_RED_PARITY_ERROR
   assign logisimOutputBubbles[0] = s_logisimNet48;

   /*******************************************************************************
   ** Here all normal components are defined                                     **
   *******************************************************************************/
   NOR_GATE #(.BubblesMask(2'b11))
      GATES_1 (.input1(s_logisimNet3),
               .input2(s_logisimNet5),
               .result(s_logisimNet65));

   NOR_GATE #(.BubblesMask(2'b11))
      GATES_2 (.input1(s_logisimNet5),
               .input2(s_logisimNet38),
               .result(s_logisimNet51));

   NOR_GATE #(.BubblesMask(2'b00))
      GATES_3 (.input1(s_logisimNet35),
               .input2(s_logisimNet4),
               .result(s_logisimNet1));

   J_K_FLIPFLOP #(.invertClockEnable(1))
      MEMORY_4 (.clock(s_logisimNet1),
                .j(s_logisimNet6),
                .k(s_logisimNet18),
                .preset(s_logisimNet58),
                .q(),
                .qBar(s_logisimNet48),
                .reset(s_logisimNet16),
                .tick(1'b1));

   J_K_FLIPFLOP #(.invertClockEnable(1))
      MEMORY_5 (.clock(s_logisimNet1),
                .j(s_logisimNet6),
                .k(s_logisimNet46),
                .preset(s_logisimNet49),
                .q(),
                .qBar(s_logisimNet45),
                .reset(s_logisimNet21),
                .tick(1'b1));


   /*******************************************************************************
   ** Here all sub-circuits are defined                                          **
   *******************************************************************************/

   PAL_16L8_12   PAL_45008_UDATA (.B0_n(s_logisimNet29),
                                  .B1_n(s_logisimNet30),
                                  .B2_n(s_logisimNet57),
                                  .B3_n(s_logisimNet13),
                                  .B4_n(s_logisimNet44),
                                  .B5_n(s_logisimNet17),
                                  .I0(s_logisimNet73),
                                  .I1(s_logisimNet50),
                                  .I2(s_logisimBus15[0]),
                                  .I3(s_logisimBus15[1]),
                                  .I4(s_logisimBus15[3]),
                                  .I5(s_logisimBus15[4]),
                                  .I6(s_logisimNet36),
                                  .I7(s_logisimNet67),
                                  .I8(s_logisimNet37),
                                  .I9(s_logisimNet68),
                                  .Y0_n(s_logisimNet3),
                                  .Y1_n(s_logisimNet20));

   AM29833A   CHIP_1H (.CK(s_logisimNet0),
                       .CLR_n(s_logisimNet30),
                       .ERR_n(s_logisimNet2),
                       .OER_n(s_logisimNet20),
                       .OET_n(s_logisimNet29),
                       .PAR_io(s_logisimBus66[8]),
                       .R0(s_logisimBus15[0]),
                       .R1(s_logisimBus15[1]),
                       .R2(s_logisimBus15[2]),
                       .R3(s_logisimBus15[3]),
                       .R4(s_logisimBus15[4]),
                       .R5(s_logisimBus15[5]),
                       .R6(s_logisimBus15[6]),
                       .R7(s_logisimBus15[7]),
                       .T0(s_logisimBus66[0]),
                       .T1(s_logisimBus66[1]),
                       .T2(s_logisimBus66[2]),
                       .T3(s_logisimBus66[3]),
                       .T4(s_logisimBus66[4]),
                       .T5(s_logisimBus66[5]),
                       .T6(s_logisimBus66[6]),
                       .T7(s_logisimBus66[7]));

   AM29833A   CHIP_2H (.CK(s_logisimNet0),
                       .CLR_n(s_logisimNet30),
                       .ERR_n(s_logisimNet34),
                       .OER_n(s_logisimNet20),
                       .OET_n(s_logisimNet29),
                       .PAR_io(s_logisimBus66[17]),
                       .R0(s_logisimBus15[8]),
                       .R1(s_logisimBus15[9]),
                       .R2(s_logisimBus15[10]),
                       .R3(s_logisimBus15[11]),
                       .R4(s_logisimBus15[12]),
                       .R5(s_logisimBus15[13]),
                       .R6(s_logisimBus15[14]),
                       .R7(s_logisimBus15[15]),
                       .T0(s_logisimBus66[9]),
                       .T1(s_logisimBus66[10]),
                       .T2(s_logisimBus66[11]),
                       .T3(s_logisimBus66[12]),
                       .T4(s_logisimBus66[13]),
                       .T5(s_logisimBus66[14]),
                       .T6(s_logisimBus66[15]),
                       .T7(s_logisimBus66[16]));

endmodule

/******************************************************************************
 ** Logisim-evolution goes FPGA automatic generated Verilog code             **
 ** https://github.com/logisim-evolution/                                    **
 **                                                                          **
 ** Component : CYC_36                                                       **
 **                                                                          **
 *****************************************************************************/

module CYC_36( ACOND_n,
               ALUCLK,
               BRK_n,
               CC_3_1_n,
               CGNTCACT_n,
               CLK,
               CSALUI7,
               CSALUI8,
               CSALUM0,
               CSALUM1,
               CSDELAY0,
               CSDELAY1,
               CSDLY,
               CSECOND,
               CSLOOP,
               CX_n,
               CYD,
               EORF_n,
               ETRAP_n,
               FORM_n,
               HIT,
               IORQ_n,
               LBA0,
               LBA1,
               LBA3,
               LCS_n,
               LSHADOW,
               LUA12,
               MACLK,
               MAP_n,
               MCLK,
               MREQ_n,
               MR_n,
               OSC,
               PD1,
               PD4,
               RRF_n,
               RT_n,
               RWCS_n,
               SHORT_n,
               SLOW_n,
               TERM_n,
               TRAP_n,
               UCLK,
               VEX,
               WRFSTB );

   /*******************************************************************************
   ** The inputs are defined here                                                **
   *******************************************************************************/
   input ACOND_n;
   input BRK_n;
   input CGNTCACT_n;
   input CSALUI7;
   input CSALUI8;
   input CSALUM0;
   input CSALUM1;
   input CSDELAY0;
   input CSDELAY1;
   input CSDLY;
   input CSECOND;
   input CSLOOP;
   input FORM_n;
   input HIT;
   input IORQ_n;
   input LBA0;
   input LBA1;
   input LBA3;
   input LSHADOW;
   input LUA12;
   input MREQ_n;
   input MR_n;
   input OSC;
   input PD1;
   input PD4;
   input RRF_n;
   input RT_n;
   input RWCS_n;
   input SHORT_n;
   input SLOW_n;
   input TRAP_n;
   input VEX;

   /*******************************************************************************
   ** The outputs are defined here                                               **
   *******************************************************************************/
   output       ALUCLK;
   output [2:0] CC_3_1_n;
   output       CLK;
   output       CX_n;
   output       CYD;
   output       EORF_n;
   output       ETRAP_n;
   output       LCS_n;
   output       MACLK;
   output       MAP_n;
   output       MCLK;
   output       TERM_n;
   output       UCLK;
   output       WRFSTB;

   /*******************************************************************************
   ** The wires are defined here                                                 **
   *******************************************************************************/
   wire [2:0] s_logisimBus33;
   wire       s_logisimNet0;
   wire       s_logisimNet1;
   wire       s_logisimNet10;
   wire       s_logisimNet11;
   wire       s_logisimNet12;
   wire       s_logisimNet13;
   wire       s_logisimNet14;
   wire       s_logisimNet15;
   wire       s_logisimNet16;
   wire       s_logisimNet17;
   wire       s_logisimNet18;
   wire       s_logisimNet19;
   wire       s_logisimNet2;
   wire       s_logisimNet20;
   wire       s_logisimNet21;
   wire       s_logisimNet22;
   wire       s_logisimNet23;
   wire       s_logisimNet24;
   wire       s_logisimNet25;
   wire       s_logisimNet26;
   wire       s_logisimNet27;
   wire       s_logisimNet28;
   wire       s_logisimNet29;
   wire       s_logisimNet3;
   wire       s_logisimNet30;
   wire       s_logisimNet31;
   wire       s_logisimNet32;
   wire       s_logisimNet34;
   wire       s_logisimNet35;
   wire       s_logisimNet36;
   wire       s_logisimNet37;
   wire       s_logisimNet38;
   wire       s_logisimNet39;
   wire       s_logisimNet4;
   wire       s_logisimNet40;
   wire       s_logisimNet41;
   wire       s_logisimNet42;
   wire       s_logisimNet43;
   wire       s_logisimNet44;
   wire       s_logisimNet45;
   wire       s_logisimNet46;
   wire       s_logisimNet47;
   wire       s_logisimNet48;
   wire       s_logisimNet49;
   wire       s_logisimNet5;
   wire       s_logisimNet50;
   wire       s_logisimNet51;
   wire       s_logisimNet52;
   wire       s_logisimNet53;
   wire       s_logisimNet54;
   wire       s_logisimNet55;
   wire       s_logisimNet56;
   wire       s_logisimNet57;
   wire       s_logisimNet58;
   wire       s_logisimNet59;
   wire       s_logisimNet6;
   wire       s_logisimNet60;
   wire       s_logisimNet61;
   wire       s_logisimNet62;
   wire       s_logisimNet63;
   wire       s_logisimNet64;
   wire       s_logisimNet65;
   wire       s_logisimNet66;
   wire       s_logisimNet67;
   wire       s_logisimNet68;
   wire       s_logisimNet69;
   wire       s_logisimNet7;
   wire       s_logisimNet70;
   wire       s_logisimNet71;
   wire       s_logisimNet72;
   wire       s_logisimNet8;
   wire       s_logisimNet9;

   /*******************************************************************************
   ** The module functionality is described here                                 **
   *******************************************************************************/

   /*******************************************************************************
   ** Here all input connections are defined                                     **
   *******************************************************************************/
   assign s_logisimNet1  = PD4;
   assign s_logisimNet10 = LUA12;
   assign s_logisimNet11 = CSALUM1;
   assign s_logisimNet12 = CSALUI8;
   assign s_logisimNet13 = LBA3;
   assign s_logisimNet14 = LBA0;
   assign s_logisimNet17 = MR_n;
   assign s_logisimNet18 = CSDELAY0;
   assign s_logisimNet25 = FORM_n;
   assign s_logisimNet26 = RWCS_n;
   assign s_logisimNet27 = VEX;
   assign s_logisimNet38 = IORQ_n;
   assign s_logisimNet39 = RT_n;
   assign s_logisimNet40 = PD1;
   assign s_logisimNet43 = HIT;
   assign s_logisimNet46 = MREQ_n;
   assign s_logisimNet52 = CSDLY;
   assign s_logisimNet53 = CSLOOP;
   assign s_logisimNet54 = CSDELAY1;
   assign s_logisimNet55 = CSALUM0;
   assign s_logisimNet56 = CSALUI7;
   assign s_logisimNet57 = LBA1;
   assign s_logisimNet59 = TRAP_n;
   assign s_logisimNet6  = BRK_n;
   assign s_logisimNet60 = SLOW_n;
   assign s_logisimNet62 = LSHADOW;
   assign s_logisimNet64 = OSC;
   assign s_logisimNet65 = CGNTCACT_n;
   assign s_logisimNet68 = SHORT_n;
   assign s_logisimNet72 = RRF_n;
   assign s_logisimNet8  = CSECOND;
   assign s_logisimNet9  = ACOND_n;

   /*******************************************************************************
   ** Here all output connections are defined                                    **
   *******************************************************************************/
   assign ALUCLK   = s_logisimNet2;
   assign CC_3_1_n = s_logisimBus33[2:0];
   assign CLK      = s_logisimNet23;
   assign CX_n     = s_logisimNet19;
   assign CYD      = s_logisimNet47;
   assign EORF_n   = s_logisimNet70;
   assign ETRAP_n  = s_logisimNet71;
   assign LCS_n    = s_logisimNet29;
   assign MACLK    = s_logisimNet45;
   assign MAP_n    = s_logisimNet34;
   assign MCLK     = s_logisimNet66;
   assign TERM_n   = s_logisimNet5;
   assign UCLK     = s_logisimNet22;
   assign WRFSTB   = s_logisimNet69;

   /*******************************************************************************
   ** Here all in-lined components are defined                                   **
   *******************************************************************************/

   // Power
   assign  s_logisimNet31  =  1'b1;


   // NOT Gate
   assign s_logisimNet42 = ~s_logisimNet29;

   /*******************************************************************************
   ** Here all normal components are defined                                     **
   *******************************************************************************/
   AND_GATE #(.BubblesMask(2'b00))
      GATES_1 (.input1(s_logisimNet17),
               .input2(s_logisimNet63),
               .result(s_logisimNet36));

   NAND_GATE #(.BubblesMask(2'b00))
      GATES_2 (.input1(s_logisimNet31),
               .input2(s_logisimNet5),
               .result(s_logisimNet23));

   NAND_GATE #(.BubblesMask(2'b00))
      GATES_3 (.input1(s_logisimNet5),
               .input2(s_logisimNet30),
               .result(s_logisimNet66));

   NAND_GATE #(.BubblesMask(2'b00))
      GATES_4 (.input1(s_logisimNet5),
               .input2(s_logisimNet20),
               .result(s_logisimNet45));

   AND_GATE #(.BubblesMask(2'b00))
      GATES_5 (.input1(s_logisimNet5),
               .input2(s_logisimNet44),
               .result(s_logisimNet22));

   NOR_GATE #(.BubblesMask(2'b00))
      GATES_6 (.input1(s_logisimNet5),
               .input2(s_logisimNet42),
               .result(s_logisimNet2));

   OR_GATE #(.BubblesMask(2'b00))
      GATES_7 (.input1(s_logisimNet62),
               .input2(s_logisimNet39),
               .result(s_logisimNet67));

   OR_GATE #(.BubblesMask(2'b00))
      GATES_8 (.input1(s_logisimNet46),
               .input2(s_logisimNet62),
               .result(s_logisimNet48));

   NAND_GATE #(.BubblesMask(2'b00))
      GATES_9 (.input1(s_logisimNet48),
               .input2(s_logisimNet38),
               .result(s_logisimNet63));

   NAND_GATE #(.BubblesMask(2'b00))
      GATES_10 (.input1(s_logisimNet38),
                .input2(s_logisimNet67),
                .result(s_logisimNet49));


   /*******************************************************************************
   ** Here all sub-circuits are defined                                          **
   *******************************************************************************/

   PAL_16R6D   PAL_44601_UCYCFSM (.B0_n(s_logisimNet61),
                                  .B1_n(s_logisimNet51),
                                  .CK(s_logisimNet64),
                                  .I0(s_logisimNet16),
                                  .I1(s_logisimNet50),
                                  .I2(s_logisimNet18),
                                  .I3(s_logisimNet36),
                                  .I4(s_logisimNet49),
                                  .I5(s_logisimNet65),
                                  .I6(s_logisimNet43),
                                  .I7(s_logisimNet6),
                                  .OE_n(s_logisimNet1),
                                  .Q0_n(s_logisimNet19),
                                  .Q1_n(s_logisimNet5),
                                  .Q2_n(s_logisimNet7),
                                  .Q3_n(s_logisimBus33[0]),
                                  .Q4_n(s_logisimBus33[1]),
                                  .Q5_n(s_logisimBus33[2]));

   PAL_16L8_12   PAL_44307_UCYCLK (.B0_n(s_logisimNet69),
                                   .B1_n(s_logisimNet47),
                                   .B2_n(s_logisimNet70),
                                   .B3_n(s_logisimNet44),
                                   .B4_n(s_logisimNet71),
                                   .B5_n(s_logisimNet34),
                                   .I0(s_logisimNet5),
                                   .I1(s_logisimNet7),
                                   .I2(s_logisimBus33[0]),
                                   .I3(s_logisimBus33[1]),
                                   .I4(s_logisimBus33[2]),
                                   .I5(s_logisimNet25),
                                   .I6(s_logisimNet6),
                                   .I7(s_logisimNet26),
                                   .I8(s_logisimNet59),
                                   .I9(s_logisimNet27),
                                   .Y0_n(s_logisimNet30),
                                   .Y1_n(s_logisimNet20));

   PAL_16R4D   PAL_44403_UCYIN0 (.B0_n(s_logisimNet50),
                                 .B1_n(),
                                 .B2_n(s_logisimNet21),
                                 .B3_n(),
                                 .CK(s_logisimNet23),
                                 .I0(s_logisimNet18),
                                 .I1(s_logisimNet52),
                                 .I2(s_logisimNet8),
                                 .I3(s_logisimNet53),
                                 .I4(s_logisimNet9),
                                 .I5(s_logisimNet17),
                                 .I6(s_logisimNet10),
                                 .I7(s_logisimNet34),
                                 .OE_n(s_logisimNet40),
                                 .Q0_n(s_logisimNet29),
                                 .Q1_n(s_logisimNet3),
                                 .Q2_n(s_logisimNet35),
                                 .Q3_n(s_logisimNet4));

   PAL_16R4D   PAL_44404_UCYIN1 (.B0_n(s_logisimNet37),
                                 .B1_n(s_logisimNet32),
                                 .B2_n(s_logisimNet41),
                                 .B3_n(s_logisimNet16),
                                 .CK(s_logisimNet23),
                                 .I0(s_logisimNet54),
                                 .I1(s_logisimNet11),
                                 .I2(s_logisimNet55),
                                 .I3(s_logisimNet12),
                                 .I4(s_logisimNet56),
                                 .I5(s_logisimNet13),
                                 .I6(s_logisimNet57),
                                 .I7(s_logisimNet14),
                                 .OE_n(s_logisimNet40),
                                 .Q0_n(s_logisimNet58),
                                 .Q1_n(s_logisimNet15),
                                 .Q2_n(),
                                 .Q3_n());

endmodule

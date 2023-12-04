/******************************************************************************
 ** Logisim-evolution goes FPGA automatic generated Verilog code             **
 ** https://github.com/logisim-evolution/                                    **
 **                                                                          **
 ** Component : CGA_CPU_ALU_CONTR                                            **
 **                                                                          **
 *****************************************************************************/

module CGA_CPU_ALU_CONTR( ALUCLK,
                          ALUD2N,
                          ALUI4,
                          ALUI7,
                          ALUI8N,
                          BDEST,
                          CD_10_9,
                          CI,
                          CRY,
                          CSALUI_8_0,
                          CSALUM_1_0,
                          CSCINSEL_1_0,
                          CSMIS_1_0,
                          CSSST_1_0,
                          CSTS_1_0,
                          DGPR0N,
                          F0,
                          F15,
                          FSEL,
                          GPR0,
                          GPRC_2_0,
                          GPRLI,
                          LCZN,
                          LDGPRN,
                          LDIRV,
                          LOG,
                          MI,
                          Q0,
                          Q15,
                          QLI,
                          QSEL_1_0,
                          RA,
                          RD,
                          RLI,
                          RRI,
                          RSN,
                          SA,
                          SB,
                          STS6,
                          STS7,
                          UPN,
                          XFETCHN );

   /*******************************************************************************
   ** The inputs are defined here                                                **
   *******************************************************************************/
   input       ALUCLK;
   input [1:0] CD_10_9;
   input       CRY;
   input [8:0] CSALUI_8_0;
   input [1:0] CSALUM_1_0;
   input [1:0] CSCINSEL_1_0;
   input [1:0] CSMIS_1_0;
   input [1:0] CSSST_1_0;
   input       DGPR0N;
   input       F0;
   input       F15;
   input       GPR0;
   input       LCZN;
   input       LDGPRN;
   input       LDIRV;
   input       Q0;
   input       Q15;
   input       STS6;
   input       STS7;
   input       UPN;
   input       XFETCHN;

   /*******************************************************************************
   ** The outputs are defined here                                               **
   *******************************************************************************/
   output       ALUD2N;
   output       ALUI4;
   output       ALUI7;
   output       ALUI8N;
   output       BDEST;
   output       CI;
   output [1:0] CSTS_1_0;
   output       FSEL;
   output [2:0] GPRC_2_0;
   output       GPRLI;
   output       LOG;
   output       MI;
   output       QLI;
   output [1:0] QSEL_1_0;
   output       RA;
   output       RD;
   output       RLI;
   output       RRI;
   output       RSN;
   output       SA;
   output       SB;

   /*******************************************************************************
   ** The wires are defined here                                                 **
   *******************************************************************************/
   wire [2:0] s_logisimBus119;
   wire [1:0] s_logisimBus121;
   wire [1:0] s_logisimBus124;
   wire [1:0] s_logisimBus136;
   wire [1:0] s_logisimBus16;
   wire [1:0] s_logisimBus39;
   wire [1:0] s_logisimBus85;
   wire [1:0] s_logisimBus89;
   wire [8:0] s_logisimBus91;
   wire       s_logisimNet0;
   wire       s_logisimNet1;
   wire       s_logisimNet10;
   wire       s_logisimNet100;
   wire       s_logisimNet101;
   wire       s_logisimNet102;
   wire       s_logisimNet103;
   wire       s_logisimNet104;
   wire       s_logisimNet105;
   wire       s_logisimNet106;
   wire       s_logisimNet107;
   wire       s_logisimNet108;
   wire       s_logisimNet109;
   wire       s_logisimNet11;
   wire       s_logisimNet110;
   wire       s_logisimNet111;
   wire       s_logisimNet112;
   wire       s_logisimNet113;
   wire       s_logisimNet114;
   wire       s_logisimNet115;
   wire       s_logisimNet116;
   wire       s_logisimNet117;
   wire       s_logisimNet118;
   wire       s_logisimNet12;
   wire       s_logisimNet120;
   wire       s_logisimNet122;
   wire       s_logisimNet123;
   wire       s_logisimNet125;
   wire       s_logisimNet126;
   wire       s_logisimNet127;
   wire       s_logisimNet128;
   wire       s_logisimNet129;
   wire       s_logisimNet13;
   wire       s_logisimNet130;
   wire       s_logisimNet131;
   wire       s_logisimNet132;
   wire       s_logisimNet133;
   wire       s_logisimNet134;
   wire       s_logisimNet135;
   wire       s_logisimNet137;
   wire       s_logisimNet138;
   wire       s_logisimNet139;
   wire       s_logisimNet14;
   wire       s_logisimNet140;
   wire       s_logisimNet141;
   wire       s_logisimNet142;
   wire       s_logisimNet143;
   wire       s_logisimNet144;
   wire       s_logisimNet145;
   wire       s_logisimNet146;
   wire       s_logisimNet147;
   wire       s_logisimNet148;
   wire       s_logisimNet149;
   wire       s_logisimNet15;
   wire       s_logisimNet150;
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
   wire       s_logisimNet33;
   wire       s_logisimNet34;
   wire       s_logisimNet35;
   wire       s_logisimNet36;
   wire       s_logisimNet37;
   wire       s_logisimNet38;
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
   wire       s_logisimNet73;
   wire       s_logisimNet74;
   wire       s_logisimNet75;
   wire       s_logisimNet76;
   wire       s_logisimNet77;
   wire       s_logisimNet78;
   wire       s_logisimNet79;
   wire       s_logisimNet8;
   wire       s_logisimNet80;
   wire       s_logisimNet81;
   wire       s_logisimNet82;
   wire       s_logisimNet83;
   wire       s_logisimNet84;
   wire       s_logisimNet86;
   wire       s_logisimNet87;
   wire       s_logisimNet88;
   wire       s_logisimNet9;
   wire       s_logisimNet90;
   wire       s_logisimNet92;
   wire       s_logisimNet93;
   wire       s_logisimNet94;
   wire       s_logisimNet95;
   wire       s_logisimNet96;
   wire       s_logisimNet97;
   wire       s_logisimNet98;
   wire       s_logisimNet99;

   /*******************************************************************************
   ** The module functionality is described here                                 **
   *******************************************************************************/

   /*******************************************************************************
   ** Here all input connections are defined                                     **
   *******************************************************************************/
   assign s_logisimBus124[1:0] = CSCINSEL_1_0;
   assign s_logisimBus136[1:0] = CSALUM_1_0;
   assign s_logisimBus16[1:0]  = CD_10_9;
   assign s_logisimBus39[1:0]  = CSMIS_1_0;
   assign s_logisimBus89[1:0]  = CSSST_1_0;
   assign s_logisimBus91[8:0]  = CSALUI_8_0;
   assign s_logisimNet104      = LCZN;
   assign s_logisimNet11       = LDGPRN;
   assign s_logisimNet147      = CRY;
   assign s_logisimNet30       = STS7;
   assign s_logisimNet31       = F0;
   assign s_logisimNet37       = Q0;
   assign s_logisimNet38       = F15;
   assign s_logisimNet40       = Q15;
   assign s_logisimNet46       = XFETCHN;
   assign s_logisimNet57       = STS6;
   assign s_logisimNet59       = DGPR0N;
   assign s_logisimNet8        = UPN;
   assign s_logisimNet82       = ALUCLK;
   assign s_logisimNet96       = LDIRV;
   assign s_logisimNet97       = GPR0;

   /*******************************************************************************
   ** Here all output connections are defined                                    **
   *******************************************************************************/
   assign ALUD2N   = s_logisimNet106;
   assign ALUI4    = s_logisimNet34;
   assign ALUI7    = s_logisimNet141;
   assign ALUI8N   = s_logisimNet108;
   assign BDEST    = s_logisimNet49;
   assign CI       = s_logisimNet116;
   assign CSTS_1_0 = s_logisimBus121[1:0];
   assign FSEL     = s_logisimNet118;
   assign GPRC_2_0 = s_logisimBus119[2:0];
   assign GPRLI    = s_logisimNet3;
   assign LOG      = s_logisimNet76;
   assign MI       = s_logisimNet84;
   assign QLI      = s_logisimNet75;
   assign QSEL_1_0 = s_logisimBus85[1:0];
   assign RA       = s_logisimNet149;
   assign RD       = s_logisimNet44;
   assign RLI      = s_logisimNet72;
   assign RRI      = s_logisimNet67;
   assign RSN      = s_logisimNet134;
   assign SA       = s_logisimNet71;
   assign SB       = s_logisimNet17;

   /*******************************************************************************
   ** Here all in-lined components are defined                                   **
   *******************************************************************************/

   // Ground
   assign  s_logisimNet109  =  1'b0;


   // Ground
   assign  s_logisimNet12  =  1'b0;


   // Power
   assign  s_logisimNet78  =  1'b1;


   // NOT Gate
   assign s_logisimNet6 = ~s_logisimBus91[3];

   // NOT Gate
   assign s_logisimNet74 = ~s_logisimBus91[2];

   // NOT Gate
   assign s_logisimNet146 = ~s_logisimBus91[0];

   // NOT Gate
   assign s_logisimNet77 = ~s_logisimBus91[4];

   // NOT Gate
   assign s_logisimBus85[1] = ~s_logisimNet66;

   // NOT Gate
   assign s_logisimBus85[0] = ~s_logisimNet32;

   // NOT Gate
   assign s_logisimNet49 = ~s_logisimNet35;

   // NOT Gate
   assign s_logisimNet134 = ~s_logisimNet142;

   // NOT Gate
   assign s_logisimNet118 = ~s_logisimNet133;

   // NOT Gate
   assign s_logisimNet76 = ~s_logisimNet80;

   // NOT Gate
   assign s_logisimNet34 = ~s_logisimNet61;

   // NOT Gate
   assign s_logisimNet17 = ~s_logisimNet42;

   // NOT Gate
   assign s_logisimNet71 = ~s_logisimNet92;

   // NOT Gate
   assign s_logisimNet149 = ~s_logisimNet13;

   // NOT Gate
   assign s_logisimNet44 = ~s_logisimNet68;

   // NOT Gate
   assign s_logisimNet141 = ~s_logisimNet103;

   // NOT Gate
   assign s_logisimNet126 = ~s_logisimNet132;

   // NOT Gate
   assign s_logisimNet143 = ~s_logisimNet141;

   // NOT Gate
   assign s_logisimNet108 = ~s_logisimNet126;

   // NOT Gate
   assign s_logisimBus119[0] = ~s_logisimNet64;

   // NOT Gate
   assign s_logisimBus119[1] = ~s_logisimNet28;

   // NOT Gate
   assign s_logisimBus119[2] = ~s_logisimNet144;

   // NOT Gate
   assign s_logisimNet45 = ~s_logisimBus136[0];

   /*******************************************************************************
   ** Here all normal components are defined                                     **
   *******************************************************************************/
   AND_GATE #(.BubblesMask(2'b00))
      GATES_1 (.input1(s_logisimBus136[1]),
               .input2(s_logisimBus136[0]),
               .result(s_logisimNet26));

   NOR_GATE #(.BubblesMask(2'b00))
      GATES_2 (.input1(s_logisimBus136[1]),
               .input2(s_logisimNet45),
               .result(s_logisimNet73));

   NAND_GATE #(.BubblesMask(2'b00))
      GATES_3 (.input1(s_logisimBus136[1]),
               .input2(s_logisimNet45),
               .result(s_logisimNet54));

   AND_GATE #(.BubblesMask(2'b00))
      GATES_4 (.input1(s_logisimNet77),
               .input2(s_logisimNet140),
               .result(s_logisimNet88));

   AND_GATE #(.BubblesMask(2'b00))
      GATES_5 (.input1(s_logisimNet140),
               .input2(s_logisimBus91[5]),
               .result(s_logisimNet93));

   NAND_GATE #(.BubblesMask(2'b00))
      GATES_6 (.input1(s_logisimBus91[2]),
               .input2(s_logisimBus91[0]),
               .result(s_logisimNet14));

   NAND_GATE #(.BubblesMask(2'b00))
      GATES_7 (.input1(s_logisimBus91[2]),
               .input2(s_logisimNet86),
               .result(s_logisimNet9));

   NAND_GATE #(.BubblesMask(2'b00))
      GATES_8 (.input1(s_logisimNet74),
               .input2(s_logisimBus91[0]),
               .result(s_logisimNet130));

   NAND_GATE #(.BubblesMask(2'b00))
      GATES_9 (.input1(s_logisimNet86),
               .input2(s_logisimNet74),
               .result(s_logisimNet7));

   NAND_GATE #(.BubblesMask(2'b00))
      GATES_10 (.input1(s_logisimNet86),
                .input2(s_logisimNet146),
                .result(s_logisimNet2));

   AND_GATE #(.BubblesMask(2'b00))
      GATES_11 (.input1(s_logisimNet140),
                .input2(s_logisimBus91[4]),
                .result(s_logisimNet87));

   NAND_GATE #(.BubblesMask(2'b00))
      GATES_12 (.input1(s_logisimNet141),
                .input2(s_logisimNet38),
                .result(s_logisimNet120));

   NAND_GATE_3_INPUTS #(.BubblesMask(3'b000))
      GATES_13 (.input1(s_logisimNet143),
                .input2(s_logisimNet98),
                .input3(s_logisimNet37),
                .result(s_logisimNet90));

   NAND_GATE_3_INPUTS #(.BubblesMask(3'b000))
      GATES_14 (.input1(s_logisimNet143),
                .input2(s_logisimNet150),
                .input3(s_logisimNet31),
                .result(s_logisimNet50));

   NAND_GATE #(.BubblesMask(2'b00))
      GATES_15 (.input1(s_logisimBus91[5]),
                .input2(s_logisimBus91[4]),
                .result(s_logisimNet43));

   NOR_GATE_3_INPUTS #(.BubblesMask(3'b000))
      GATES_16 (.input1(s_logisimNet87),
                .input2(s_logisimBus91[5]),
                .input3(s_logisimNet109),
                .result(s_logisimNet95));

   NOR_GATE #(.BubblesMask(2'b00))
      GATES_17 (.input1(s_logisimNet88),
                .input2(s_logisimNet93),
                .result(s_logisimNet79));

   NAND_GATE #(.BubblesMask(2'b00))
      GATES_18 (.input1(s_logisimNet14),
                .input2(s_logisimNet9),
                .result(s_logisimNet111));

   NAND_GATE #(.BubblesMask(2'b00))
      GATES_19 (.input1(s_logisimNet9),
                .input2(s_logisimNet130),
                .result(s_logisimNet52));

   NAND_GATE #(.BubblesMask(2'b00))
      GATES_20 (.input1(s_logisimNet2),
                .input2(s_logisimBus91[2]),
                .result(s_logisimNet20));

   NAND_GATE #(.BubblesMask(2'b00))
      GATES_21 (.input1(1'b1),
                .input2(s_logisimNet31),
                .result(s_logisimNet0));

   NAND_GATE #(.BubblesMask(2'b00))
      GATES_22 (.input1(s_logisimNet37),
                .input2(s_logisimNet98),
                .result(s_logisimNet15));

   NAND_GATE #(.BubblesMask(2'b00))
      GATES_23 (.input1(s_logisimNet98),
                .input2(s_logisimNet40),
                .result(s_logisimNet56));

   NAND_GATE_3_INPUTS #(.BubblesMask(3'b000))
      GATES_24 (.input1(s_logisimNet120),
                .input2(s_logisimNet90),
                .input3(s_logisimNet50),
                .result(s_logisimNet84));

   AND_GATE #(.BubblesMask(2'b00))
      GATES_25 (.input1(s_logisimNet29),
                .input2(s_logisimNet48),
                .result(s_logisimNet110));

   NOR_GATE_3_INPUTS #(.BubblesMask(3'b000))
      GATES_26 (.input1(s_logisimNet60),
                .input2(s_logisimNet112),
                .input3(s_logisimNet150),
                .result(s_logisimNet138));

   NOR_GATE #(.BubblesMask(2'b00))
      GATES_27 (.input1(s_logisimNet55),
                .input2(s_logisimNet129),
                .result(s_logisimNet19));

   NOR_GATE #(.BubblesMask(2'b00))
      GATES_28 (.input1(s_logisimNet112),
                .input2(s_logisimNet129),
                .result(s_logisimNet53));

   NAND_GATE #(.BubblesMask(2'b00))
      GATES_29 (.input1(s_logisimNet0),
                .input2(s_logisimNet15),
                .result(s_logisimNet101));

   NOR_GATE #(.BubblesMask(2'b00))
      GATES_30 (.input1(s_logisimNet60),
                .input2(s_logisimNet55),
                .result(s_logisimNet122));

   NAND_GATE_3_INPUTS #(.BubblesMask(3'b000))
      GATES_31 (.input1(s_logisimNet98),
                .input2(s_logisimNet141),
                .input3(s_logisimNet108),
                .result(s_logisimNet106));

   NAND_GATE #(.BubblesMask(2'b00))
      GATES_32 (.input1(s_logisimNet98),
                .input2(s_logisimNet126),
                .result(s_logisimNet66));

   NAND_GATE #(.BubblesMask(2'b00))
      GATES_33 (.input1(s_logisimNet98),
                .input2(s_logisimNet143),
                .result(s_logisimNet32));

   NAND_GATE #(.BubblesMask(2'b00))
      GATES_34 (.input1(s_logisimNet30),
                .input2(s_logisimNet147),
                .result(s_logisimNet36));

   NAND_GATE #(.BubblesMask(2'b00))
      GATES_35 (.input1(s_logisimNet30),
                .input2(s_logisimNet97),
                .result(s_logisimNet100));

   NAND_GATE #(.BubblesMask(2'b00))
      GATES_36 (.input1(s_logisimNet97),
                .input2(s_logisimNet147),
                .result(s_logisimNet41));

   NAND_GATE #(.BubblesMask(2'b00))
      GATES_37 (.input1(s_logisimNet147),
                .input2(s_logisimNet138),
                .result(s_logisimNet65));

   NAND_GATE #(.BubblesMask(2'b00))
      GATES_38 (.input1(s_logisimNet101),
                .input2(s_logisimNet19),
                .result(s_logisimNet18));

   NAND_GATE #(.BubblesMask(2'b00))
      GATES_39 (.input1(s_logisimNet38),
                .input2(s_logisimNet53),
                .result(s_logisimNet102));

   NAND_GATE #(.BubblesMask(2'b00))
      GATES_40 (.input1(s_logisimNet38),
                .input2(s_logisimNet19),
                .result(s_logisimNet148));

   NAND_GATE #(.BubblesMask(2'b00))
      GATES_41 (.input1(s_logisimNet30),
                .input2(s_logisimNet122),
                .result(s_logisimNet21));

   NAND_GATE #(.BubblesMask(2'b00))
      GATES_42 (.input1(s_logisimNet21),
                .input2(s_logisimNet148),
                .result(s_logisimNet75));

   NAND_GATE_4_INPUTS #(.BubblesMask(4'h0))
      GATES_43 (.input1(s_logisimNet21),
                .input2(s_logisimNet65),
                .input3(s_logisimNet18),
                .input4(s_logisimNet102),
                .result(s_logisimNet67));

   NAND_GATE_3_INPUTS #(.BubblesMask(3'b000))
      GATES_44 (.input1(s_logisimNet36),
                .input2(s_logisimNet100),
                .input3(s_logisimNet41),
                .result(s_logisimNet3));

   NAND_GATE #(.BubblesMask(2'b00))
      GATES_45 (.input1(s_logisimNet75),
                .input2(s_logisimNet150),
                .result(s_logisimNet127));

   NAND_GATE #(.BubblesMask(2'b00))
      GATES_46 (.input1(s_logisimNet127),
                .input2(s_logisimNet56),
                .result(s_logisimNet72));

   NAND_GATE #(.BubblesMask(2'b00))
      GATES_47 (.input1(s_logisimNet126),
                .input2(s_logisimNet26),
                .result(s_logisimNet22));

   NAND_GATE #(.BubblesMask(2'b00))
      GATES_48 (.input1(s_logisimNet94),
                .input2(s_logisimNet22),
                .result(s_logisimBus121[1]));

   NAND_GATE #(.BubblesMask(2'b00))
      GATES_49 (.input1(s_logisimNet46),
                .input2(s_logisimNet143),
                .result(s_logisimNet81));

   NAND_GATE #(.BubblesMask(2'b00))
      GATES_50 (.input1(s_logisimNet81),
                .input2(s_logisimNet11),
                .result(s_logisimNet64));

   NAND_GATE #(.BubblesMask(2'b00))
      GATES_51 (.input1(s_logisimNet11),
                .input2(s_logisimNet46),
                .result(s_logisimNet28));

   NAND_GATE #(.BubblesMask(2'b00))
      GATES_52 (.input1(~s_logisimNet28),
                .input2(s_logisimNet108),
                .result(s_logisimNet144));

   D_FLIPFLOP #(.invertClockEnable(0))
      MEMORY_53 (.clock(s_logisimNet82),
                 .d(s_logisimBus91[6]),
                 .preset(1'b0),
                 .q(s_logisimNet150),
                 .qBar(s_logisimNet98),
                 .reset(1'b0),
                 .tick(1'b1));

   D_FLIPFLOP #(.invertClockEnable(0))
      MEMORY_54 (.clock(s_logisimNet82),
                 .d(s_logisimNet110),
                 .preset(1'b0),
                 .q(s_logisimNet35),
                 .qBar(),
                 .reset(1'b0),
                 .tick(1'b1));

   D_FLIPFLOP #(.invertClockEnable(0))
      MEMORY_55 (.clock(s_logisimNet96),
                 .d(s_logisimBus16[1]),
                 .preset(1'b0),
                 .q(s_logisimNet5),
                 .qBar(),
                 .reset(1'b0),
                 .tick(1'b1));

   D_FLIPFLOP #(.invertClockEnable(0))
      MEMORY_56 (.clock(s_logisimNet96),
                 .d(s_logisimBus16[0]),
                 .preset(1'b0),
                 .q(s_logisimNet33),
                 .qBar(),
                 .reset(1'b0),
                 .tick(1'b1));


   /*******************************************************************************
   ** Here all sub-circuits are defined                                          **
   *******************************************************************************/

   MUX21LP   CSMIS1_MUX (.A(s_logisimBus39[1]),
                         .B(s_logisimNet5),
                         .S(s_logisimNet26),
                         .ZN(s_logisimNet69));

   MUX21LP   CSMIS0_MUX (.A(s_logisimBus39[0]),
                         .B(s_logisimNet33),
                         .S(s_logisimNet26),
                         .ZN(s_logisimNet23));

   MUX21LP   CSALUI7_MUX (.A(s_logisimBus91[7]),
                          .B(s_logisimNet8),
                          .S(s_logisimNet26),
                          .ZN(s_logisimNet29));

   MUX21LP   CSALUI8_MUX (.A(s_logisimBus91[8]),
                          .B(s_logisimNet104),
                          .S(s_logisimNet26),
                          .ZN(s_logisimNet48));

   MUX21LP   ALUI3_MUX (.A(s_logisimNet59),
                        .B(s_logisimNet6),
                        .S(s_logisimNet54),
                        .ZN(s_logisimNet140));

   MUX21LP   ALUI1N_MUX (.A(s_logisimBus91[1]),
                         .B(s_logisimNet59),
                         .S(s_logisimNet73),
                         .ZN(s_logisimNet86));

   R41P   REG_RFLA4 (.A(s_logisimNet79),
                     .B(s_logisimNet43),
                     .C(s_logisimNet95),
                     .CP(s_logisimNet82),
                     .D(s_logisimBus91[4]),
                     .QA(s_logisimNet142),
                     .QAN(),
                     .QB(),
                     .QBN(s_logisimNet133),
                     .QC(s_logisimNet80),
                     .QCN(),
                     .QD(),
                     .QDN(s_logisimNet61));

   R41P   REG_BAAD (.A(s_logisimNet111),
                    .B(s_logisimNet52),
                    .C(s_logisimNet7),
                    .CP(s_logisimNet82),
                    .D(s_logisimNet20),
                    .QA(),
                    .QAN(s_logisimNet42),
                    .QB(),
                    .QBN(s_logisimNet92),
                    .QC(s_logisimNet13),
                    .QCN(),
                    .QD(s_logisimNet68),
                    .QDN());

   R81   CONTR_REG (.A(s_logisimNet69),
                    .B(s_logisimNet23),
                    .C(s_logisimNet29),
                    .CP(s_logisimNet82),
                    .D(s_logisimNet48),
                    .E(s_logisimBus89[0]),
                    .F(s_logisimBus89[1]),
                    .G(s_logisimBus124[0]),
                    .H(s_logisimBus124[1]),
                    .QA(s_logisimNet60),
                    .QAN(s_logisimNet129),
                    .QB(s_logisimNet55),
                    .QBN(s_logisimNet112),
                    .QC(s_logisimNet103),
                    .QCN(),
                    .QD(s_logisimNet132),
                    .QDN(),
                    .QE(s_logisimBus121[0]),
                    .QEN(),
                    .QF(),
                    .QFN(s_logisimNet94),
                    .QG(s_logisimNet105),
                    .QGN(),
                    .QH(s_logisimNet63),
                    .QHN());

   MUX41P   CI_SEL_MUX (.A(s_logisimNet105),
                        .B(s_logisimNet63),
                        .D0(s_logisimNet12),
                        .D1(s_logisimNet78),
                        .D2(s_logisimNet57),
                        .D3(s_logisimNet97),
                        .Z(s_logisimNet116));

endmodule

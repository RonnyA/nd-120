/******************************************************************************
 ** Logisim-evolution goes FPGA automatic generated Verilog code             **
 ** https://github.com/logisim-evolution/                                    **
 **                                                                          **
 ** Component : DECODE_DGA_PFIFC                                             **
 **                                                                          **
 *****************************************************************************/

module DECODE_DGA_PFIFC( CLEAR,
                         EMPN,
                         FULN,
                         LDPANCN,
                         RMMN,
                         WEL_12_0,
                         WEU_12_0 );

   /*******************************************************************************
   ** The inputs are defined here                                                **
   *******************************************************************************/
   input CLEAR;
   input LDPANCN;
   input RMMN;

   /*******************************************************************************
   ** The outputs are defined here                                               **
   *******************************************************************************/
   output        EMPN;
   output        FULN;
   output [12:0] WEL_12_0;
   output [12:0] WEU_12_0;

   /*******************************************************************************
   ** The wires are defined here                                                 **
   *******************************************************************************/
   wire [12:0] s_logisimBus44;
   wire [12:0] s_logisimBus72;
   wire        s_logisimNet0;
   wire        s_logisimNet1;
   wire        s_logisimNet10;
   wire        s_logisimNet100;
   wire        s_logisimNet101;
   wire        s_logisimNet102;
   wire        s_logisimNet103;
   wire        s_logisimNet104;
   wire        s_logisimNet105;
   wire        s_logisimNet106;
   wire        s_logisimNet107;
   wire        s_logisimNet11;
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
   wire        s_logisimNet40;
   wire        s_logisimNet41;
   wire        s_logisimNet42;
   wire        s_logisimNet43;
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
   wire        s_logisimNet82;
   wire        s_logisimNet83;
   wire        s_logisimNet84;
   wire        s_logisimNet85;
   wire        s_logisimNet86;
   wire        s_logisimNet87;
   wire        s_logisimNet88;
   wire        s_logisimNet89;
   wire        s_logisimNet9;
   wire        s_logisimNet90;
   wire        s_logisimNet91;
   wire        s_logisimNet92;
   wire        s_logisimNet93;
   wire        s_logisimNet94;
   wire        s_logisimNet95;
   wire        s_logisimNet96;
   wire        s_logisimNet97;
   wire        s_logisimNet98;
   wire        s_logisimNet99;

   /*******************************************************************************
   ** The module functionality is described here                                 **
   *******************************************************************************/

   /*******************************************************************************
   ** Here all wiring is defined                                                 **
   *******************************************************************************/
   assign s_logisimBus44[0]  = s_logisimNet86;
   assign s_logisimBus44[10] = s_logisimNet106;
   assign s_logisimBus44[11] = s_logisimNet70;
   assign s_logisimBus44[12] = s_logisimNet88;
   assign s_logisimBus44[1]  = s_logisimNet101;
   assign s_logisimBus44[2]  = s_logisimNet104;
   assign s_logisimBus44[3]  = s_logisimNet69;
   assign s_logisimBus44[4]  = s_logisimNet85;
   assign s_logisimBus44[5]  = s_logisimNet102;
   assign s_logisimBus44[6]  = s_logisimNet105;
   assign s_logisimBus44[7]  = s_logisimNet68;
   assign s_logisimBus44[8]  = s_logisimNet87;
   assign s_logisimBus44[9]  = s_logisimNet103;
   assign s_logisimBus72[0]  = s_logisimNet86;
   assign s_logisimBus72[10] = s_logisimNet106;
   assign s_logisimBus72[11] = s_logisimNet70;
   assign s_logisimBus72[12] = s_logisimNet88;
   assign s_logisimBus72[1]  = s_logisimNet101;
   assign s_logisimBus72[2]  = s_logisimNet104;
   assign s_logisimBus72[3]  = s_logisimNet69;
   assign s_logisimBus72[4]  = s_logisimNet85;
   assign s_logisimBus72[5]  = s_logisimNet102;
   assign s_logisimBus72[6]  = s_logisimNet105;
   assign s_logisimBus72[7]  = s_logisimNet68;
   assign s_logisimBus72[8]  = s_logisimNet87;
   assign s_logisimBus72[9]  = s_logisimNet103;

   /*******************************************************************************
   ** Here all input connections are defined                                     **
   *******************************************************************************/
   assign s_logisimNet4  = LDPANCN;
   assign s_logisimNet45 = RMMN;
   assign s_logisimNet79 = CLEAR;

   /*******************************************************************************
   ** Here all output connections are defined                                    **
   *******************************************************************************/
   assign EMPN     = s_logisimNet30;
   assign FULN     = s_logisimNet91;
   assign WEL_12_0 = s_logisimBus72[12:0];
   assign WEU_12_0 = s_logisimBus44[12:0];

   /*******************************************************************************
   ** Here all in-lined components are defined                                   **
   *******************************************************************************/

   // NOT Gate
   assign s_logisimNet86 = ~s_logisimNet4;

   // NOT Gate
   assign s_logisimNet104 = ~s_logisimNet21;

   // NOT Gate
   assign s_logisimNet69 = ~s_logisimNet98;

   // NOT Gate
   assign s_logisimNet85 = ~s_logisimNet89;

   // NOT Gate
   assign s_logisimNet102 = ~s_logisimNet31;

   // NOT Gate
   assign s_logisimNet105 = ~s_logisimNet107;

   // NOT Gate
   assign s_logisimNet68 = ~s_logisimNet93;

   // NOT Gate
   assign s_logisimNet87 = ~s_logisimNet80;

   // NOT Gate
   assign s_logisimNet103 = ~s_logisimNet64;

   // NOT Gate
   assign s_logisimNet106 = ~s_logisimNet42;

   // NOT Gate
   assign s_logisimNet70 = ~s_logisimNet5;

   // NOT Gate
   assign s_logisimNet88 = ~s_logisimNet96;

   // NOT Gate
   assign s_logisimNet101 = ~s_logisimNet50;

   // NOT Gate
   assign s_logisimNet36 = ~s_logisimNet104;

   // NOT Gate
   assign s_logisimNet0 = ~s_logisimNet69;

   // NOT Gate
   assign s_logisimNet3 = ~s_logisimNet85;

   // NOT Gate
   assign s_logisimNet15 = ~s_logisimNet102;

   // NOT Gate
   assign s_logisimNet14 = ~s_logisimNet105;

   // NOT Gate
   assign s_logisimNet11 = ~s_logisimNet68;

   // NOT Gate
   assign s_logisimNet33 = ~s_logisimNet87;

   // NOT Gate
   assign s_logisimNet1 = ~s_logisimNet103;

   // NOT Gate
   assign s_logisimNet6 = ~s_logisimNet106;

   // NOT Gate
   assign s_logisimNet27 = ~s_logisimNet70;

   // NOT Gate
   assign s_logisimNet22 = ~s_logisimNet88;

   // NOT Gate
   assign s_logisimNet7 = ~s_logisimNet101;

   // NOT Gate
   assign s_logisimNet16 = ~s_logisimNet79;

   /*******************************************************************************
   ** Here all normal components are defined                                     **
   *******************************************************************************/
   NAND_GATE_4_INPUTS #(.BubblesMask(4'h0))
      A292 (.input1(s_logisimNet7),
            .input2(s_logisimNet76),
            .input3(s_logisimNet81),
            .input4(s_logisimNet0),
            .result(s_logisimNet21));

   NAND_GATE_4_INPUTS #(.BubblesMask(4'h0))
      GATES_2 (.input1(s_logisimNet36),
               .input2(s_logisimNet23),
               .input3(s_logisimNet66),
               .input4(s_logisimNet3),
               .result(s_logisimNet98));

   NAND_GATE_4_INPUTS #(.BubblesMask(4'h0))
      GATES_3 (.input1(s_logisimNet0),
               .input2(s_logisimNet53),
               .input3(s_logisimNet47),
               .input4(s_logisimNet15),
               .result(s_logisimNet89));

   NAND_GATE_4_INPUTS #(.BubblesMask(4'h0))
      GATES_4 (.input1(s_logisimNet3),
               .input2(s_logisimNet8),
               .input3(s_logisimNet84),
               .input4(s_logisimNet14),
               .result(s_logisimNet31));

   NAND_GATE_4_INPUTS #(.BubblesMask(4'h0))
      GATES_5 (.input1(s_logisimNet15),
               .input2(s_logisimNet12),
               .input3(s_logisimNet74),
               .input4(s_logisimNet11),
               .result(s_logisimNet107));

   NAND_GATE_4_INPUTS #(.BubblesMask(4'h0))
      GATES_6 (.input1(s_logisimNet14),
               .input2(s_logisimNet62),
               .input3(s_logisimNet55),
               .input4(s_logisimNet33),
               .result(s_logisimNet93));

   NAND_GATE_4_INPUTS #(.BubblesMask(4'h0))
      GATES_7 (.input1(s_logisimNet11),
               .input2(s_logisimNet63),
               .input3(s_logisimNet25),
               .input4(s_logisimNet1),
               .result(s_logisimNet80));

   NAND_GATE_4_INPUTS #(.BubblesMask(4'h0))
      GATES_8 (.input1(s_logisimNet33),
               .input2(s_logisimNet58),
               .input3(s_logisimNet99),
               .input4(s_logisimNet6),
               .result(s_logisimNet64));

   NAND_GATE_4_INPUTS #(.BubblesMask(4'h0))
      GATES_9 (.input1(s_logisimNet1),
               .input2(s_logisimNet40),
               .input3(s_logisimNet90),
               .input4(s_logisimNet27),
               .result(s_logisimNet42));

   NAND_GATE_4_INPUTS #(.BubblesMask(4'h0))
      GATES_10 (.input1(s_logisimNet6),
                .input2(s_logisimNet52),
                .input3(s_logisimNet78),
                .input4(s_logisimNet22),
                .result(s_logisimNet5));

   NAND_GATE_4_INPUTS #(.BubblesMask(4'h0))
      GATES_11 (.input1(s_logisimNet27),
                .input2(s_logisimNet32),
                .input3(s_logisimNet61),
                .input4(s_logisimNet45),
                .result(s_logisimNet96));

   NAND_GATE_4_INPUTS #(.BubblesMask(4'h0))
      A300 (.input1(s_logisimNet4),
            .input2(s_logisimNet28),
            .input3(s_logisimNet94),
            .input4(s_logisimNet36),
            .result(s_logisimNet50));

   AND_GATE_3_INPUTS #(.BubblesMask(3'b000))
      GATES_13 (.input1(s_logisimNet46),
                .input2(s_logisimNet46),
                .input3(s_logisimNet16),
                .result(s_logisimNet29));

   AND_GATE_3_INPUTS #(.BubblesMask(3'b000))
      GATES_14 (.input1(s_logisimNet13),
                .input2(s_logisimNet13),
                .input3(s_logisimNet16),
                .result(s_logisimNet100));

   AND_GATE_3_INPUTS #(.BubblesMask(3'b000))
      GATES_15 (.input1(s_logisimNet34),
                .input2(s_logisimNet34),
                .input3(s_logisimNet16),
                .result(s_logisimNet92));

   AND_GATE_3_INPUTS #(.BubblesMask(3'b000))
      GATES_16 (.input1(s_logisimNet54),
                .input2(s_logisimNet54),
                .input3(s_logisimNet16),
                .result(s_logisimNet41));

   AND_GATE_3_INPUTS #(.BubblesMask(3'b000))
      GATES_17 (.input1(s_logisimNet24),
                .input2(s_logisimNet24),
                .input3(s_logisimNet16),
                .result(s_logisimNet2));

   AND_GATE_3_INPUTS #(.BubblesMask(3'b000))
      GATES_18 (.input1(s_logisimNet43),
                .input2(s_logisimNet43),
                .input3(s_logisimNet16),
                .result(s_logisimNet95));

   AND_GATE_3_INPUTS #(.BubblesMask(3'b000))
      GATES_19 (.input1(s_logisimNet9),
                .input2(s_logisimNet9),
                .input3(s_logisimNet16),
                .result(s_logisimNet83));

   AND_GATE_3_INPUTS #(.BubblesMask(3'b000))
      GATES_20 (.input1(s_logisimNet77),
                .input2(s_logisimNet77),
                .input3(s_logisimNet16),
                .result(s_logisimNet71));

   AND_GATE_3_INPUTS #(.BubblesMask(3'b000))
      GATES_21 (.input1(s_logisimNet59),
                .input2(s_logisimNet59),
                .input3(s_logisimNet16),
                .result(s_logisimNet49));

   AND_GATE_3_INPUTS #(.BubblesMask(3'b000))
      GATES_22 (.input1(s_logisimNet37),
                .input2(s_logisimNet37),
                .input3(s_logisimNet16),
                .result(s_logisimNet20));

   AND_GATE_3_INPUTS #(.BubblesMask(3'b000))
      GATES_23 (.input1(s_logisimNet51),
                .input2(s_logisimNet51),
                .input3(s_logisimNet16),
                .result(s_logisimNet97));

   AND_GATE_3_INPUTS #(.BubblesMask(3'b000))
      GATES_24 (.input1(s_logisimNet86),
                .input2(s_logisimNet86),
                .input3(s_logisimNet16),
                .result(s_logisimNet82));

   AND_GATE_3_INPUTS #(.BubblesMask(3'b000))
      GATES_25 (.input1(s_logisimNet65),
                .input2(s_logisimNet65),
                .input3(s_logisimNet16),
                .result(s_logisimNet57));

   NAND_GATE #(.BubblesMask(2'b00))
      GATES_26 (.input1(s_logisimNet16),
                .input2(s_logisimNet0),
                .result(s_logisimNet60));

   NAND_GATE #(.BubblesMask(2'b00))
      GATES_27 (.input1(s_logisimNet16),
                .input2(s_logisimNet3),
                .result(s_logisimNet38));

   NAND_GATE #(.BubblesMask(2'b00))
      GATES_28 (.input1(s_logisimNet16),
                .input2(s_logisimNet15),
                .result(s_logisimNet39));

   NAND_GATE #(.BubblesMask(2'b00))
      GATES_29 (.input1(s_logisimNet16),
                .input2(s_logisimNet14),
                .result(s_logisimNet67));

   NAND_GATE #(.BubblesMask(2'b00))
      GATES_30 (.input1(s_logisimNet16),
                .input2(s_logisimNet11),
                .result(s_logisimNet48));

   NAND_GATE #(.BubblesMask(2'b00))
      GATES_31 (.input1(s_logisimNet16),
                .input2(s_logisimNet33),
                .result(s_logisimNet17));

   NAND_GATE #(.BubblesMask(2'b00))
      GATES_32 (.input1(s_logisimNet16),
                .input2(s_logisimNet1),
                .result(s_logisimNet19));

   NAND_GATE #(.BubblesMask(2'b00))
      GATES_33 (.input1(s_logisimNet16),
                .input2(s_logisimNet6),
                .result(s_logisimNet35));

   NAND_GATE #(.BubblesMask(2'b00))
      GATES_34 (.input1(s_logisimNet16),
                .input2(s_logisimNet27),
                .result(s_logisimNet75));

   NAND_GATE #(.BubblesMask(2'b00))
      GATES_35 (.input1(s_logisimNet16),
                .input2(s_logisimNet22),
                .result(s_logisimNet56));

   NAND_GATE #(.BubblesMask(2'b00))
      GATES_36 (.input1(s_logisimNet16),
                .input2(s_logisimNet45),
                .result(s_logisimNet26));

   NAND_GATE #(.BubblesMask(2'b00))
      GATES_37 (.input1(s_logisimNet16),
                .input2(s_logisimNet7),
                .result(s_logisimNet18));

   NAND_GATE #(.BubblesMask(2'b00))
      GATES_38 (.input1(s_logisimNet16),
                .input2(s_logisimNet36),
                .result(s_logisimNet10));


   /*******************************************************************************
   ** Here all sub-circuits are defined                                          **
   *******************************************************************************/

   F595   A321 (.H01_S(s_logisimNet29),
                .H02_R(s_logisimNet60),
                .H03_G(s_logisimNet73),
                .N01_Q(s_logisimNet23),
                .N02_QB(s_logisimNet81));

   F595   A316 (.H01_S(s_logisimNet100),
                .H02_R(s_logisimNet38),
                .H03_G(s_logisimNet73),
                .N01_Q(s_logisimNet53),
                .N02_QB(s_logisimNet66));

   F595   A308 (.H01_S(s_logisimNet92),
                .H02_R(s_logisimNet39),
                .H03_G(s_logisimNet73),
                .N01_Q(s_logisimNet8),
                .N02_QB(s_logisimNet47));

   F595   A322 (.H01_S(s_logisimNet41),
                .H02_R(s_logisimNet67),
                .H03_G(s_logisimNet73),
                .N01_Q(s_logisimNet12),
                .N02_QB(s_logisimNet84));

   F595   A302 (.H01_S(s_logisimNet2),
                .H02_R(s_logisimNet48),
                .H03_G(s_logisimNet73),
                .N01_Q(s_logisimNet62),
                .N02_QB(s_logisimNet74));

   F595   A304 (.H01_S(s_logisimNet95),
                .H02_R(s_logisimNet17),
                .H03_G(s_logisimNet73),
                .N01_Q(s_logisimNet63),
                .N02_QB(s_logisimNet55));

   F595   A301 (.H01_S(s_logisimNet83),
                .H02_R(s_logisimNet19),
                .H03_G(s_logisimNet73),
                .N01_Q(s_logisimNet58),
                .N02_QB(s_logisimNet25));

   F595   A315 (.H01_S(s_logisimNet71),
                .H02_R(s_logisimNet35),
                .H03_G(s_logisimNet73),
                .N01_Q(s_logisimNet40),
                .N02_QB(s_logisimNet99));

   F595   A339 (.H01_S(s_logisimNet49),
                .H02_R(s_logisimNet75),
                .H03_G(s_logisimNet73),
                .N01_Q(s_logisimNet52),
                .N02_QB(s_logisimNet90));

   F595   A334 (.H01_S(s_logisimNet20),
                .H02_R(s_logisimNet56),
                .H03_G(s_logisimNet73),
                .N01_Q(s_logisimNet32),
                .N02_QB(s_logisimNet78));

   F595   A343 (.H01_S(s_logisimNet97),
                .H02_R(s_logisimNet26),
                .H03_G(s_logisimNet73),
                .N01_Q(s_logisimNet30),
                .N02_QB(s_logisimNet61));

   F595   A305 (.H01_S(s_logisimNet82),
                .H02_R(s_logisimNet18),
                .H03_G(s_logisimNet73),
                .N01_Q(s_logisimNet28),
                .N02_QB(s_logisimNet91));

   F595   A314 (.H01_S(s_logisimNet57),
                .H02_R(s_logisimNet10),
                .H03_G(s_logisimNet73),
                .N01_Q(s_logisimNet76),
                .N02_QB(s_logisimNet94));

   F091   A351 (.N01(s_logisimNet73),
                .N02());

   DECODE_DGA_PFIFC_DELAY   A323 (.PIN_IN(s_logisimNet104),
                                  .PIN_OUT(s_logisimNet46));

   DECODE_DGA_PFIFC_DELAY   A312 (.PIN_IN(s_logisimNet69),
                                  .PIN_OUT(s_logisimNet13));

   DECODE_DGA_PFIFC_DELAY   A331 (.PIN_IN(s_logisimNet85),
                                  .PIN_OUT(s_logisimNet34));

   DECODE_DGA_PFIFC_DELAY   A347 (.PIN_IN(s_logisimNet102),
                                  .PIN_OUT(s_logisimNet54));

   DECODE_DGA_PFIFC_DELAY   A296 (.PIN_IN(s_logisimNet105),
                                  .PIN_OUT(s_logisimNet24));

   DECODE_DGA_PFIFC_DELAY   A310 (.PIN_IN(s_logisimNet68),
                                  .PIN_OUT(s_logisimNet43));

   DECODE_DGA_PFIFC_DELAY   A362 (.PIN_IN(s_logisimNet87),
                                  .PIN_OUT(s_logisimNet9));

   DECODE_DGA_PFIFC_DELAY   A363 (.PIN_IN(s_logisimNet103),
                                  .PIN_OUT(s_logisimNet77));

   DECODE_DGA_PFIFC_DELAY   A364 (.PIN_IN(s_logisimNet106),
                                  .PIN_OUT(s_logisimNet59));

   DECODE_DGA_PFIFC_DELAY   A365 (.PIN_IN(s_logisimNet70),
                                  .PIN_OUT(s_logisimNet37));

   DECODE_DGA_PFIFC_DELAY   A366 (.PIN_IN(s_logisimNet88),
                                  .PIN_OUT(s_logisimNet51));

   DECODE_DGA_PFIFC_DELAY   A309 (.PIN_IN(s_logisimNet101),
                                  .PIN_OUT(s_logisimNet65));

endmodule

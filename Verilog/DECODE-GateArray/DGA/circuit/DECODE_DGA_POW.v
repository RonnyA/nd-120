/******************************************************************************
 ** Logisim-evolution goes FPGA automatic generated Verilog code             **
 ** https://github.com/logisim-evolution/                                    **
 **                                                                          **
 ** Component : DECODE_DGA_POW                                               **
 **                                                                          **
 *****************************************************************************/

module DECODE_DGA_POW( BDRY50N,
                       CLEAR,
                       CLOSC,
                       CLRTIN,
                       CONTINUEN,
                       EMCLN,
                       IDB0,
                       IDB1,
                       IDB2,
                       LOADN,
                       MCL,
                       PANN,
                       PANOSC,
                       POWFAILN,
                       POWSENSE,
                       PRQN,
                       PWCL,
                       REFN,
                       REFRQN,
                       RESET,
                       RTOSC,
                       SEL5MSN,
                       SSTOPN,
                       STARTN,
                       STOPN,
                       STPN,
                       TESTO,
                       TESTE,
                       TOUT );

   /*******************************************************************************
   ** The inputs are defined here                                                **
   *******************************************************************************/
   input BDRY50N;
   input CLOSC;
   input CLRTIN;
   input CONTINUEN;
   input EMCLN;
   input LOADN;
   input POWSENSE;
   input PRQN;
   input PWCL;
   input REFN;
   input RESET;
   input RTOSC;
   input SEL5MSN;
   input SSTOPN;
   input STARTN;
   input STOPN;
   input TESTE;

   /*******************************************************************************
   ** The outputs are defined here                                               **
   *******************************************************************************/
   output CLEAR;
   output IDB0;
   output IDB1;
   output IDB2;
   output MCL;
   output PANN;
   output PANOSC;
   output POWFAILN;
   output REFRQN;
   output STPN;
   output TESTO;
   output TOUT;

   /*******************************************************************************
   ** The wires are defined here                                                 **
   *******************************************************************************/
   wire s_logisimNet0;
   wire s_logisimNet1;
   wire s_logisimNet10;
   wire s_logisimNet11;
   wire s_logisimNet12;
   wire s_logisimNet13;
   wire s_logisimNet14;
   wire s_logisimNet15;
   wire s_logisimNet16;
   wire s_logisimNet17;
   wire s_logisimNet18;
   wire s_logisimNet19;
   wire s_logisimNet2;
   wire s_logisimNet20;
   wire s_logisimNet21;
   wire s_logisimNet22;
   wire s_logisimNet23;
   wire s_logisimNet24;
   wire s_logisimNet25;
   wire s_logisimNet26;
   wire s_logisimNet27;
   wire s_logisimNet28;
   wire s_logisimNet29;
   wire s_logisimNet3;
   wire s_logisimNet30;
   wire s_logisimNet31;
   wire s_logisimNet32;
   wire s_logisimNet33;
   wire s_logisimNet34;
   wire s_logisimNet35;
   wire s_logisimNet36;
   wire s_logisimNet37;
   wire s_logisimNet38;
   wire s_logisimNet39;
   wire s_logisimNet4;
   wire s_logisimNet40;
   wire s_logisimNet41;
   wire s_logisimNet42;
   wire s_logisimNet43;
   wire s_logisimNet44;
   wire s_logisimNet45;
   wire s_logisimNet46;
   wire s_logisimNet47;
   wire s_logisimNet48;
   wire s_logisimNet49;
   wire s_logisimNet5;
   wire s_logisimNet50;
   wire s_logisimNet51;
   wire s_logisimNet52;
   wire s_logisimNet53;
   wire s_logisimNet54;
   wire s_logisimNet55;
   wire s_logisimNet56;
   wire s_logisimNet57;
   wire s_logisimNet58;
   wire s_logisimNet59;
   wire s_logisimNet6;
   wire s_logisimNet60;
   wire s_logisimNet61;
   wire s_logisimNet62;
   wire s_logisimNet63;
   wire s_logisimNet64;
   wire s_logisimNet65;
   wire s_logisimNet66;
   wire s_logisimNet67;
   wire s_logisimNet68;
   wire s_logisimNet69;
   wire s_logisimNet7;
   wire s_logisimNet70;
   wire s_logisimNet71;
   wire s_logisimNet72;
   wire s_logisimNet73;
   wire s_logisimNet74;
   wire s_logisimNet75;
   wire s_logisimNet76;
   wire s_logisimNet77;
   wire s_logisimNet78;
   wire s_logisimNet79;
   wire s_logisimNet8;
   wire s_logisimNet80;
   wire s_logisimNet81;
   wire s_logisimNet82;
   wire s_logisimNet83;
   wire s_logisimNet84;
   wire s_logisimNet85;
   wire s_logisimNet86;
   wire s_logisimNet87;
   wire s_logisimNet88;
   wire s_logisimNet89;
   wire s_logisimNet9;
   wire s_logisimNet90;
   wire s_logisimNet91;
   wire s_logisimNet92;
   wire s_logisimNet93;
   wire s_logisimNet94;
   wire s_logisimNet95;
   wire s_logisimNet96;
   wire s_logisimNet97;
   wire s_logisimNet98;
   wire s_logisimNet99;

   /*******************************************************************************
   ** The module functionality is described here                                 **
   *******************************************************************************/

   /*******************************************************************************
   ** Here all input connections are defined                                     **
   *******************************************************************************/
   assign s_logisimNet13 = POWSENSE;
   assign s_logisimNet21 = REFN;
   assign s_logisimNet22 = RTOSC;
   assign s_logisimNet23 = CLOSC;
   assign s_logisimNet29 = EMCLN;
   assign s_logisimNet33 = BDRY50N;
   assign s_logisimNet37 = SEL5MSN;
   assign s_logisimNet50 = PRQN;
   assign s_logisimNet60 = CONTINUEN;
   assign s_logisimNet61 = LOADN;
   assign s_logisimNet73 = PWCL;
   assign s_logisimNet74 = TESTE;
   assign s_logisimNet79 = SSTOPN;
   assign s_logisimNet84 = RESET;
   assign s_logisimNet85 = STOPN;
   assign s_logisimNet86 = STARTN;
   assign s_logisimNet9  = CLRTIN;

   /*******************************************************************************
   ** Here all output connections are defined                                    **
   *******************************************************************************/
   assign CLEAR    = s_logisimNet66;
   assign IDB0     = s_logisimNet83;
   assign IDB1     = s_logisimNet25;
   assign IDB2     = s_logisimNet87;
   assign MCL      = s_logisimNet31;
   assign PANN     = s_logisimNet88;
   assign PANOSC   = s_logisimNet0;
   assign POWFAILN = s_logisimNet18;
   assign REFRQN   = s_logisimNet43;
   assign STPN     = s_logisimNet58;   
   assign TESTO    = s_logisimNet48;
   assign TOUT     = s_logisimNet99;

   /*******************************************************************************
   ** Here all in-lined components are defined                                   **
   *******************************************************************************/

   // Ground
   assign  s_logisimNet19  =  1'b0;


   // Power
   assign  s_logisimNet17  =  1'b1;


   // Ground
   assign  s_logisimNet12  =  1'b0;


   // Ground
   assign  s_logisimNet49  =  1'b0;


   // Ground
   assign  s_logisimNet2  =  1'b0;


   // Ground
   assign  s_logisimNet38  =  1'b0;


   // Ground
   assign  s_logisimNet3  =  1'b0;


   // Ground
   assign  s_logisimNet15  =  1'b0;


   // Power
   assign  s_logisimNet6  =  1'b1;


   // NOT Gate
   assign s_logisimNet66 = ~s_logisimNet30;

   // NOT Gate
   assign s_logisimNet5 = ~s_logisimNet86;

   // NOT Gate
   assign s_logisimNet42 = ~s_logisimNet9;

   // NOT Gate
   assign s_logisimNet44 = ~s_logisimNet95;

   // NOT Gate
   assign s_logisimNet80 = ~s_logisimNet9;

   // NOT Gate
   assign s_logisimNet82 = ~s_logisimNet95;

   // NOT Gate
   assign s_logisimNet76 = ~s_logisimNet31;

   // NOT Gate
   assign s_logisimNet71 = ~s_logisimNet68;

   // NOT Gate
   assign s_logisimNet55 = ~s_logisimNet97;

   // NOT Gate
   assign s_logisimNet41 = ~s_logisimNet73;

   // NOT Gate
   assign s_logisimNet18 = ~s_logisimNet97;

   // NOT Gate
   assign s_logisimNet92 = ~s_logisimNet60;

   // NOT Gate: A504
   assign s_logisimNet90 = ~s_logisimNet61;

   // NOT Gate
   assign s_logisimNet78 = ~s_logisimNet27;

   // NOT Gate
   assign s_logisimNet16 = ~s_logisimNet1;

   // NOT Gate
   assign s_logisimNet64 = ~s_logisimNet50;

   // NOT Gate
   assign s_logisimNet46 = ~s_logisimNet53;

   /*******************************************************************************
   ** Here all normal components are defined                                     **
   *******************************************************************************/
   NAND_GATE_3_INPUTS #(.BubblesMask(3'b000))
      A597 (.input1(s_logisimNet27),
            .input2(s_logisimNet72),
            .input3(s_logisimNet64),
            .result(s_logisimNet59));

   NAND_GATE_3_INPUTS #(.BubblesMask(3'b000))
      A609 (.input1(s_logisimNet27),
            .input2(s_logisimNet72),
            .input3(s_logisimNet16),
            .result(s_logisimNet65));

   NAND_GATE #(.BubblesMask(2'b00))
      A598 (.input1(s_logisimNet98),
            .input2(s_logisimNet78),
            .result(s_logisimNet52));

   NAND_GATE_4_INPUTS #(.BubblesMask(4'h0))
      A599 (.input1(s_logisimNet46),
            .input2(s_logisimNet50),
            .input3(s_logisimNet72),
            .input4(s_logisimNet98),
            .result(s_logisimNet67));

   NAND_GATE_3_INPUTS #(.BubblesMask(3'b000))
      A590 (.input1(s_logisimNet16),
            .input2(s_logisimNet72),
            .input3(s_logisimNet98),
            .result(s_logisimNet11));

   NAND_GATE_3_INPUTS #(.BubblesMask(3'b000))
      A580 (.input1(s_logisimNet79),
            .input2(s_logisimNet30),
            .input3(s_logisimNet85),
            .result(s_logisimNet34));

   NAND_GATE_4_INPUTS #(.BubblesMask(4'h0))
      A606 (.input1(s_logisimNet72),
            .input2(s_logisimNet27),
            .input3(s_logisimNet98),
            .input4(s_logisimNet76),
            .result(s_logisimNet87));

   NAND_GATE_8_INPUTS #(.BubblesMask(8'h00))
      A592 (.input1(s_logisimNet76),
            .input2(s_logisimNet98),
            .input3(s_logisimNet27),
            .input4(s_logisimNet72),
            .input5(s_logisimNet1),
            .input6(s_logisimNet50),
            .input7(s_logisimNet53),
            .input8(s_logisimNet58),
            .result(s_logisimNet91));

   NAND_GATE_4_INPUTS #(.BubblesMask(4'h0))
      A603 (.input1(s_logisimNet59),
            .input2(s_logisimNet98),
            .input3(s_logisimNet76),
            .input4(s_logisimNet65),
            .result(s_logisimNet25));

   NAND_GATE_4_INPUTS #(.BubblesMask(4'h0))
      A604 (.input1(s_logisimNet76),
            .input2(s_logisimNet52),
            .input3(s_logisimNet67),
            .input4(s_logisimNet11),
            .result(s_logisimNet83));

   NAND_GATE #(.BubblesMask(2'b00))
      A595 (.input1(s_logisimNet79),
            .input2(s_logisimNet91),
            .result(s_logisimNet88));

   NAND_GATE #(.BubblesMask(2'b00))
      A573 (.input1(s_logisimNet29),
            .input2(s_logisimNet30),
            .result(s_logisimNet31));

   NOR_GATE #(.BubblesMask(2'b00))
      A611 (.input1(s_logisimNet13),
            .input2(s_logisimNet73),
            .result(s_logisimNet68));

   NOR_GATE #(.BubblesMask(2'b00))
      A636 (.input1(1'b0),
            .input2(1'b0),
            .result(s_logisimNet99));

   NOR_GATE #(.BubblesMask(2'b00))
      A635 (.input1(s_logisimNet23),
            .input2(s_logisimNet84),
            .result(s_logisimNet20));

   NAND_GATE #(.BubblesMask(2'b00))
      A578 (.input1(s_logisimNet58),
            .input2(s_logisimNet41),
            .result(s_logisimNet54));

   NAND_GATE_3_INPUTS #(.BubblesMask(3'b000))
      A579 (.input1(s_logisimNet76),
            .input2(s_logisimNet9),
            .input3(s_logisimNet40),
            .result(s_logisimNet36));

   J_K_FLIPFLOP #(.invertClockEnable(0))
      A616 (.clock(s_logisimNet39),
            .j(s_logisimNet28),
            .k(s_logisimNet6),
            .preset(s_logisimNet2),
            .q(s_logisimNet35),
            .qBar(),
            .reset(s_logisimNet8),
            .tick(1'b1));

   J_K_FLIPFLOP #(.invertClockEnable(0))
      A618 (.clock(s_logisimNet39),
            .j(s_logisimNet35),
            .k(s_logisimNet6),
            .preset(s_logisimNet2),
            .q(s_logisimNet32),
            .qBar(s_logisimNet28),
            .reset(s_logisimNet8),
            .tick(1'b1));

   J_K_FLIPFLOP #(.invertClockEnable(0))
      A617 (.clock(s_logisimNet39),
            .j(s_logisimNet32),
            .k(s_logisimNet32),
            .preset(s_logisimNet2),
            .q(),
            .qBar(s_logisimNet24),
            .reset(s_logisimNet8),
            .tick(1'b1));

   D_FLIPFLOP #(.invertClockEnable(0))
      A572 (.clock(s_logisimNet30),
            .d(s_logisimNet75),
            .preset(s_logisimNet42),
            .q(),
            .qBar(s_logisimNet4),
            .reset(s_logisimNet44),
            .tick(1'b1));

   D_FLIPFLOP #(.invertClockEnable(0))
      A577 (.clock(s_logisimNet62),
            .d(s_logisimNet19),
            .preset(s_logisimNet80),
            .q(s_logisimNet53),
            .qBar(),
            .reset(s_logisimNet82),
            .tick(1'b1));

   D_FLIPFLOP #(.invertClockEnable(0))
      A600 (.clock(s_logisimNet70),
            .d(s_logisimNet49),
            .preset(s_logisimNet71),
            .q(s_logisimNet97),
            .qBar(),
            .reset(s_logisimNet55),
            .tick(1'b1));


   /*******************************************************************************
   ** Here all sub-circuits are defined                                          **
   *******************************************************************************/

   F714   A623 (.H01_T(s_logisimNet22),
                .H02_R(s_logisimNet8),
                .H03_S(s_logisimNet3),
                .N01_Q(),
                .N02_QB(s_logisimNet69));

   F714   A633 (.H01_T(s_logisimNet22),
                .H02_R(s_logisimNet23),
                .H03_S(s_logisimNet15),
                .N01_Q(),
                .N02_QB(s_logisimNet10));

   F091   A613B (.N01(s_logisimNet95),
                 .N02());

   F714   A596 (.H01_T(s_logisimNet26),
                .H02_R(s_logisimNet13),
                .H03_S(s_logisimNet12),
                .N01_Q(),
                .N02_QB(s_logisimNet63));

   F714   A632 (.H01_T(s_logisimNet69),
                .H02_R(s_logisimNet8),
                .H03_S(s_logisimNet3),
                .N01_Q(),
                .N02_QB(s_logisimNet93));

   F714   A629 (.H01_T(s_logisimNet10),
                .H02_R(s_logisimNet23),
                .H03_S(s_logisimNet15),
                .N01_Q(),
                .N02_QB(s_logisimNet0));

   F714   A602 (.H01_T(s_logisimNet63),
                .H02_R(s_logisimNet13),
                .H03_S(s_logisimNet12),
                .N01_Q(),
                .N02_QB(s_logisimNet94));

   F714   A634 (.H01_T(s_logisimNet93),
                .H02_R(s_logisimNet8),
                .H03_S(s_logisimNet3),
                .N01_Q(),
                .N02_QB(s_logisimNet47));

   F595   A570 (.H01_S(s_logisimNet58),
                .H02_R(s_logisimNet73),
                .H03_G(s_logisimNet95),
                .N01_Q(),
                .N02_QB(s_logisimNet75));

   F595   A571 (.H01_S(s_logisimNet34),
                .H02_R(s_logisimNet5),
                .H03_G(s_logisimNet95),
                .N01_Q(s_logisimNet40),
                .N02_QB(s_logisimNet58));

   F714   A593 (.H01_T(s_logisimNet94),
                .H02_R(s_logisimNet13),
                .H03_S(s_logisimNet12),
                .N01_Q(),
                .N02_QB(s_logisimNet56));

   F714   A621 (.H01_T(s_logisimNet47),
                .H02_R(s_logisimNet8),
                .H03_S(s_logisimNet3),
                .N01_Q(),
                .N02_QB(s_logisimNet81));

   F091   A637 (.N01(),
                .N02(s_logisimNet96));

   F714   A594 (.H01_T(s_logisimNet56),
                .H02_R(s_logisimNet13),
                .H03_S(s_logisimNet12),
                .N01_Q(),
                .N02_QB(s_logisimNet51));

   F714   A622 (.H01_T(s_logisimNet81),
                .H02_R(s_logisimNet8),
                .H03_S(s_logisimNet3),
                .N01_Q(),
                .N02_QB(s_logisimNet7));

   F617   A630 (.H01_D(s_logisimNet96),
                .H02_C(s_logisimNet10),
                .H03_RB(s_logisimNet17),
                .H04_SB(s_logisimNet21),
                .N01_Q(s_logisimNet43),
                .N02_QB());

   F714   A619 (.H01_T(s_logisimNet7),
                .H02_R(s_logisimNet8),
                .H03_S(s_logisimNet3),
                .N01_Q(),
                .N02_QB(s_logisimNet48));

   F714   A591 (.H01_T(s_logisimNet51),
                .H02_R(s_logisimNet13),
                .H03_S(s_logisimNet12),
                .N01_Q(),
                .N02_QB(s_logisimNet89));

   F714   A627 (.H01_T(s_logisimNet24),
                .H02_R(s_logisimNet8),
                .H03_S(s_logisimNet2),
                .N01_Q(),
                .N02_QB(s_logisimNet14));

   F714   A605 (.H01_T(s_logisimNet89),
                .H02_R(s_logisimNet13),
                .H03_S(s_logisimNet12),
                .N01_Q(),
                .N02_QB(s_logisimNet70));

   F617   A631 (.H01_D(s_logisimNet43),
                .H02_C(s_logisimNet10),
                .H03_RB(s_logisimNet17),
                .H04_SB(s_logisimNet33),
                .N01_Q(s_logisimNet57),
                .N02_QB());

   F571   A620 (.A(s_logisimNet74),
                .D0(s_logisimNet48),
                .D1(s_logisimNet22),
                .ENB_N(s_logisimNet3),
                .Y(s_logisimNet77));

   F714   A626 (.H01_T(s_logisimNet14),
                .H02_R(s_logisimNet8),
                .H03_S(s_logisimNet2),
                .N01_Q(),
                .N02_QB(s_logisimNet45));

   F714   A624 (.H01_T(s_logisimNet77),
                .H02_R(s_logisimNet8),
                .H03_S(s_logisimNet3),
                .N01_Q(),
                .N02_QB(s_logisimNet39));

   F571   A625 (.A(s_logisimNet37),
                .D0(s_logisimNet24),
                .D1(s_logisimNet45),
                .ENB_N(s_logisimNet38),
                .Y(s_logisimNet62));

   F091   A613 (.N01(s_logisimNet1),
                .N02());

   F103   A628 (.F_IN(s_logisimNet20),
                .F_OUT(s_logisimNet8));

   F571   A601 (.A(s_logisimNet74),
                .D0(s_logisimNet62),
                .D1(s_logisimNet22),
                .ENB_N(s_logisimNet12),
                .Y(s_logisimNet26));

   F595   A576 (.H01_S(s_logisimNet90),
                .H02_R(s_logisimNet36),
                .H03_G(s_logisimNet95),
                .N01_Q(),
                .N02_QB(s_logisimNet72));

   F595   A574 (.H01_S(s_logisimNet4),
                .H02_R(s_logisimNet36),
                .H03_G(s_logisimNet95),
                .N01_Q(),
                .N02_QB(s_logisimNet98));

   F595   A569 (.H01_S(s_logisimNet54),
                .H02_R(s_logisimNet18),
                .H03_G(s_logisimNet95),
                .N01_Q(),
                .N02_QB(s_logisimNet30));

   F595   A575 (.H01_S(s_logisimNet92),
                .H02_R(s_logisimNet36),
                .H03_G(s_logisimNet95),
                .N01_Q(),
                .N02_QB(s_logisimNet27));

endmodule

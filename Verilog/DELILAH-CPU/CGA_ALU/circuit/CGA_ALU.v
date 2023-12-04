/******************************************************************************
 ** Logisim-evolution goes FPGA automatic generated Verilog code             **
 ** https://github.com/logisim-evolution/                                    **
 **                                                                          **
 ** Component : CGA_ALU                                                      **
 **                                                                          **
 *****************************************************************************/

module CGA_ALU( ALUCLK,
                A_15_0,
                BDEST,
                B_15_0,
                CD_15_0,
                CRY,
                CSALUI_8_0,
                CSALUM_1_0,
                CSBIT_15_0,
                CSCINSEL_1_0,
                CSIDBS_4_0,
                CSMIS_1_0,
                CSSST_1_0,
                DOUBLE,
                EA_15_0,
                F11,
                F15,
                FIDBI_15_0,
                FIDBO_15_0,
                IONI,
                LAA_3_0,
                LBA_3_0,
                LCZN,
                LDDBRN,
                LDGPRN,
                LDIRV,
                LDPILN,
                MI,
                OVF,
                PIL,
                PONI,
                PTM,
                RB_15_0,
                SGR,
                UPN,
                XFETCHN,
                Z,
                ZF );

   /*******************************************************************************
   ** The inputs are defined here                                                **
   *******************************************************************************/
   input        ALUCLK;
   input [15:0] A_15_0;
   input [15:0] B_15_0;
   input [15:0] CD_15_0;
   input [8:0]  CSALUI_8_0;
   input [1:0]  CSALUM_1_0;
   input [15:0] CSBIT_15_0;
   input [1:0]  CSCINSEL_1_0;
   input [4:0]  CSIDBS_4_0;
   input [1:0]  CSMIS_1_0;
   input [1:0]  CSSST_1_0;
   input [15:0] EA_15_0;
   input [15:0] FIDBI_15_0;
   input [3:0]  LAA_3_0;
   input [3:0]  LBA_3_0;
   input        LCZN;
   input        LDDBRN;
   input        LDGPRN;
   input        LDIRV;
   input        LDPILN;
   input        UPN;
   input        XFETCHN;

   /*******************************************************************************
   ** The outputs are defined here                                               **
   *******************************************************************************/
   output        BDEST;
   output        CRY;
   output        DOUBLE;
   output        F11;
   output        F15;
   output [15:0] FIDBO_15_0;
   output        IONI;
   output        MI;
   output        OVF;
   output [3:0]  PIL;
   output        PONI;
   output        PTM;
   output [15:0] RB_15_0;
   output        SGR;
   output        Z;
   output        ZF;

   /*******************************************************************************
   ** The wires are defined here                                                 **
   *******************************************************************************/
   wire [3:0]  s_logisimBus105;
   wire [3:0]  s_logisimBus106;
   wire [15:0] s_logisimBus107;
   wire [15:0] s_logisimBus108;
   wire [15:0] s_logisimBus113;
   wire [15:0] s_logisimBus119;
   wire [15:0] s_logisimBus123;
   wire [15:0] s_logisimBus128;
   wire [1:0]  s_logisimBus129;
   wire [8:0]  s_logisimBus130;
   wire [2:0]  s_logisimBus15;
   wire [15:0] s_logisimBus16;
   wire [1:0]  s_logisimBus17;
   wire [1:0]  s_logisimBus21;
   wire [4:0]  s_logisimBus22;
   wire [1:0]  s_logisimBus23;
   wire [1:0]  s_logisimBus24;
   wire [2:0]  s_logisimBus25;
   wire [15:0] s_logisimBus32;
   wire [15:0] s_logisimBus33;
   wire [15:0] s_logisimBus37;
   wire [15:0] s_logisimBus50;
   wire [15:0] s_logisimBus51;
   wire [1:0]  s_logisimBus54;
   wire [15:0] s_logisimBus57;
   wire [15:0] s_logisimBus65;
   wire [15:0] s_logisimBus66;
   wire [15:0] s_logisimBus7;
   wire [3:0]  s_logisimBus8;
   wire [1:0]  s_logisimBus81;
   wire [2:0]  s_logisimBus82;
   wire [15:0] s_logisimBus83;
   wire [15:0] s_logisimBus88;
   wire [15:0] s_logisimBus90;
   wire [1:0]  s_logisimBus99;
   wire        s_logisimNet0;
   wire        s_logisimNet1;
   wire        s_logisimNet10;
   wire        s_logisimNet100;
   wire        s_logisimNet101;
   wire        s_logisimNet102;
   wire        s_logisimNet103;
   wire        s_logisimNet104;
   wire        s_logisimNet109;
   wire        s_logisimNet11;
   wire        s_logisimNet110;
   wire        s_logisimNet111;
   wire        s_logisimNet112;
   wire        s_logisimNet114;
   wire        s_logisimNet115;
   wire        s_logisimNet116;
   wire        s_logisimNet117;
   wire        s_logisimNet118;
   wire        s_logisimNet12;
   wire        s_logisimNet120;
   wire        s_logisimNet121;
   wire        s_logisimNet122;
   wire        s_logisimNet124;
   wire        s_logisimNet125;
   wire        s_logisimNet126;
   wire        s_logisimNet127;
   wire        s_logisimNet13;
   wire        s_logisimNet14;
   wire        s_logisimNet18;
   wire        s_logisimNet19;
   wire        s_logisimNet2;
   wire        s_logisimNet20;
   wire        s_logisimNet26;
   wire        s_logisimNet27;
   wire        s_logisimNet28;
   wire        s_logisimNet29;
   wire        s_logisimNet3;
   wire        s_logisimNet30;
   wire        s_logisimNet31;
   wire        s_logisimNet34;
   wire        s_logisimNet35;
   wire        s_logisimNet36;
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
   wire        s_logisimNet52;
   wire        s_logisimNet53;
   wire        s_logisimNet55;
   wire        s_logisimNet56;
   wire        s_logisimNet58;
   wire        s_logisimNet59;
   wire        s_logisimNet6;
   wire        s_logisimNet60;
   wire        s_logisimNet61;
   wire        s_logisimNet62;
   wire        s_logisimNet63;
   wire        s_logisimNet64;
   wire        s_logisimNet67;
   wire        s_logisimNet68;
   wire        s_logisimNet69;
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
   wire        s_logisimNet80;
   wire        s_logisimNet84;
   wire        s_logisimNet85;
   wire        s_logisimNet86;
   wire        s_logisimNet87;
   wire        s_logisimNet89;
   wire        s_logisimNet9;
   wire        s_logisimNet91;
   wire        s_logisimNet92;
   wire        s_logisimNet93;
   wire        s_logisimNet94;
   wire        s_logisimNet95;
   wire        s_logisimNet96;
   wire        s_logisimNet97;
   wire        s_logisimNet98;

   /*******************************************************************************
   ** The module functionality is described here                                 **
   *******************************************************************************/

   /*******************************************************************************
   ** Here all wiring is defined                                                 **
   *******************************************************************************/
   assign s_logisimBus17[0] = s_logisimNet68;
   assign s_logisimBus17[1] = s_logisimNet103;
   assign s_logisimBus25[0] = s_logisimNet20;
   assign s_logisimBus25[1] = s_logisimNet46;
   assign s_logisimBus25[2] = s_logisimNet86;
   assign s_logisimBus82[0] = s_logisimNet120;
   assign s_logisimBus82[1] = s_logisimNet19;
   assign s_logisimBus82[2] = s_logisimNet45;
   assign s_logisimBus8[0]  = s_logisimNet28;
   assign s_logisimBus8[1]  = s_logisimNet12;
   assign s_logisimBus8[2]  = s_logisimNet3;
   assign s_logisimBus8[3]  = s_logisimNet114;
   assign s_logisimNet103   = s_logisimBus123[10];
   assign s_logisimNet114   = s_logisimBus51[11];
   assign s_logisimNet12    = s_logisimBus51[9];
   assign s_logisimNet120   = s_logisimBus105[0];
   assign s_logisimNet19    = s_logisimBus105[1];
   assign s_logisimNet20    = s_logisimBus106[1];
   assign s_logisimNet28    = s_logisimBus51[8];
   assign s_logisimNet3     = s_logisimBus51[10];
   assign s_logisimNet45    = s_logisimBus105[2];
   assign s_logisimNet46    = s_logisimBus106[2];
   assign s_logisimNet68    = s_logisimBus123[9];
   assign s_logisimNet86    = s_logisimBus106[3];

   /*******************************************************************************
   ** Here all input connections are defined                                     **
   *******************************************************************************/
   assign s_logisimBus105[3:0]  = LBA_3_0;
   assign s_logisimBus106[3:0]  = LAA_3_0;
   assign s_logisimBus123[15:0] = CD_15_0;
   assign s_logisimBus129[1:0]  = CSSST_1_0;
   assign s_logisimBus130[8:0]  = CSALUI_8_0;
   assign s_logisimBus16[15:0]  = FIDBI_15_0;
   assign s_logisimBus22[4:0]   = CSIDBS_4_0;
   assign s_logisimBus23[1:0]   = CSCINSEL_1_0;
   assign s_logisimBus24[1:0]   = CSALUM_1_0;
   assign s_logisimBus37[15:0]  = EA_15_0;
   assign s_logisimBus50[15:0]  = B_15_0;
   assign s_logisimBus54[1:0]   = CSMIS_1_0;
   assign s_logisimBus57[15:0]  = A_15_0;
   assign s_logisimBus83[15:0]  = CSBIT_15_0;
   assign s_logisimNet118       = UPN;
   assign s_logisimNet122       = ALUCLK;
   assign s_logisimNet18        = XFETCHN;
   assign s_logisimNet44        = LDGPRN;
   assign s_logisimNet67        = LDDBRN;
   assign s_logisimNet72        = LDPILN;
   assign s_logisimNet84        = LDIRV;
   assign s_logisimNet85        = LCZN;

   /*******************************************************************************
   ** Here all output connections are defined                                    **
   *******************************************************************************/
   assign BDEST      = s_logisimNet101;
   assign CRY        = s_logisimNet42;
   assign DOUBLE     = s_logisimBus51[13];
   assign F11        = s_logisimBus107[11];
   assign F15        = s_logisimBus107[15];
   assign FIDBO_15_0 = s_logisimBus119[15:0];
   assign IONI       = s_logisimBus51[15];
   assign MI         = s_logisimNet71;
   assign OVF        = s_logisimNet9;
   assign PIL        = s_logisimBus8[3:0];
   assign PONI       = s_logisimBus51[14];
   assign PTM        = s_logisimBus51[0];
   assign RB_15_0    = s_logisimBus88[15:0];
   assign SGR        = s_logisimNet69;
   assign Z          = s_logisimBus51[3];
   assign ZF         = s_logisimNet104;

   /*******************************************************************************
   ** Here all in-lined components are defined                                   **
   *******************************************************************************/

   // NOT Gate
   assign s_logisimBus119[15] = ~s_logisimBus32[15];

   // NOT Gate
   assign s_logisimBus119[14] = ~s_logisimBus32[14];

   // NOT Gate
   assign s_logisimBus119[13] = ~s_logisimBus32[13];

   // NOT Gate
   assign s_logisimBus119[12] = ~s_logisimBus32[12];

   // NOT Gate
   assign s_logisimBus119[11] = ~s_logisimBus32[11];

   // NOT Gate
   assign s_logisimBus119[10] = ~s_logisimBus32[10];

   // NOT Gate
   assign s_logisimBus119[9] = ~s_logisimBus32[9];

   // NOT Gate
   assign s_logisimBus119[8] = ~s_logisimBus32[8];

   // NOT Gate
   assign s_logisimBus119[7] = ~s_logisimBus32[7];

   // NOT Gate
   assign s_logisimBus119[6] = ~s_logisimBus32[6];

   // NOT Gate
   assign s_logisimBus119[5] = ~s_logisimBus32[5];

   // NOT Gate
   assign s_logisimBus119[4] = ~s_logisimBus32[4];

   // NOT Gate
   assign s_logisimBus119[3] = ~s_logisimBus32[3];

   // NOT Gate
   assign s_logisimBus119[2] = ~s_logisimBus32[2];

   // NOT Gate
   assign s_logisimBus119[1] = ~s_logisimBus32[1];

   // NOT Gate
   assign s_logisimBus119[0] = ~s_logisimBus32[0];

   // NOT Gate
   assign s_logisimNet64 = ~s_logisimNet6;

   /*******************************************************************************
   ** Here all normal components are defined                                     **
   *******************************************************************************/
   D_FLIPFLOP #(.invertClockEnable(0))
      MEMORY_1 (.clock(s_logisimNet122),
                .d(s_logisimBus22[2]),
                .preset(1'b0),
                .q(s_logisimNet31),
                .qBar(),
                .reset(1'b0),
                .tick(1'b1));


   /*******************************************************************************
   ** Here all sub-circuits are defined                                          **
   *******************************************************************************/

   MUX21LP   AARG0_MUX (.A(s_logisimBus105[3]),
                        .B(s_logisimBus106[0]),
                        .S(s_logisimNet31),
                        .Z(s_logisimNet6));

   CGA_ALU_SMUX   ALU_SMUX (.A_15_0(s_logisimBus57[15:0]),
                            .B_15_0(s_logisimBus50[15:0]),
                            .Q_15_0(s_logisimBus66[15:0]),
                            .SA(s_logisimNet87),
                            .SB(s_logisimNet34),
                            .S_15_0(s_logisimBus33[15:0]));

   CGA_CPU_ALU_RMUX   ALU_RMUX (.A_15_0(s_logisimBus57[15:0]),
                                .D_15_0(s_logisimBus7[15:0]),
                                .RA(s_logisimNet100),
                                .RD(s_logisimNet48),
                                .RN_15_0(s_logisimBus108[15:0]));

   CGA_CPU_ALU_RALU   ALU_RALU (.ALUI4(s_logisimNet73),
                                .CI(s_logisimNet98),
                                .CRY(s_logisimNet42),
                                .FSEL(s_logisimNet49),
                                .F_15_0(s_logisimBus107[15:0]),
                                .LOG(s_logisimNet125),
                                .OVF(s_logisimNet9),
                                .RN_15_0(s_logisimBus108[15:0]),
                                .RSN(s_logisimNet55),
                                .SGR(s_logisimNet69),
                                .S_15_0(s_logisimBus33[15:0]),
                                .ZF(s_logisimNet104));

   CGA_ALU_SHIFT   ALU_SHIFT (.ALUI7(s_logisimNet121),
                              .ALUI8N(s_logisimNet110),
                              .F_15_0(s_logisimBus107[15:0]),
                              .RB_15_0(s_logisimBus88[15:0]),
                              .RLI(s_logisimNet117),
                              .RRI(s_logisimNet74));

   CGA_ALU_STS   ALU_STS (.ALUCLK(s_logisimNet122),
                          .CRY(s_logisimNet42),
                          .CSTS_1_0(s_logisimBus81[1:0]),
                          .FIDBO_15_0(s_logisimBus123[15:0]),
                          .LDPILN(s_logisimNet72),
                          .MI(s_logisimNet71),
                          .OVF(s_logisimNet9),
                          .STS_15_0(s_logisimBus51[15:0]));

   CGA_ALU_GPR   ALU_GPR (.ALUCLK(s_logisimNet122),
                          .CD_15_0(s_logisimBus123[15:0]),
                          .DGPR0N(s_logisimNet124),
                          .FIDBO_15_0(s_logisimBus119[15:0]),
                          .GPRC_2_0(s_logisimBus15[2:0]),
                          .GPRLI(s_logisimNet96),
                          .GPR_15_0(s_logisimBus113[15:0]));

   CGA_ALU_DBR   ALU_DBR (.ALUCLK(s_logisimNet122),
                          .CD_15_0(s_logisimBus123[15:0]),
                          .DBR_15_0(s_logisimBus128[15:0]),
                          .LDDBRN(s_logisimNet67));

   CGA_ALU_ARG   ALU_ARG (.ALUCLK(s_logisimNet122),
                          .ARG_15_0(s_logisimBus65[15:0]),
                          .CSBIT_15_0(s_logisimBus83[15:0]));

   CGA_ALU_SWAP   ALU_SWAP (.ALUCLK(s_logisimNet122),
                            .FIDBO_15_0(s_logisimBus119[15:0]),
                            .SW_15_0(s_logisimBus90[15:0]));

   CGA_ALU_OUTMUX   ALU_OUTMUX (.AARG0(s_logisimNet64),
                                .ALUCLK(s_logisimNet122),
                                .ALUD2N(s_logisimNet102),
                                .ARG_15_0(s_logisimBus65[15:0]),
                                .A_15_0(s_logisimBus57[15:0]),
                                .CSIDBS_4_0(s_logisimBus22[4:0]),
                                .DBR_15_0(s_logisimBus128[15:0]),
                                .D_15_0(s_logisimBus7[15:0]),
                                .EA_15_0(s_logisimBus37[15:0]),
                                .FIDBI_15_0(s_logisimBus16[15:0]),
                                .F_15_0(s_logisimBus107[15:0]),
                                .GPR_15_0(s_logisimBus113[15:0]),
                                .G_15_0(s_logisimBus32[15:0]),
                                .LAA_3_1(s_logisimBus25[2:0]),
                                .LBA_2_0(s_logisimBus82[2:0]),
                                .STS_15_0(s_logisimBus51[15:0]),
                                .SW_15_0(s_logisimBus90[15:0]));

   CGA_ALU_QREG   ALU_QREG (.ALUCLK(s_logisimNet122),
                            .F_15_0(s_logisimBus107[15:0]),
                            .QLI(s_logisimNet126),
                            .QSEL_1_0(s_logisimBus99[1:0]),
                            .Q_15_0(s_logisimBus66[15:0]));

   CGA_CPU_ALU_CONTR   ALU_CONTR (.ALUCLK(s_logisimNet122),
                                  .ALUD2N(s_logisimNet102),
                                  .ALUI4(s_logisimNet73),
                                  .ALUI7(s_logisimNet121),
                                  .ALUI8N(s_logisimNet110),
                                  .BDEST(s_logisimNet101),
                                  .CD_10_9(s_logisimBus21[1:0]),
                                  .CI(s_logisimNet98),
                                  .CRY(s_logisimNet42),
                                  .CSALUI_8_0(s_logisimBus130[8:0]),
                                  .CSALUM_1_0(s_logisimBus24[1:0]),
                                  .CSCINSEL_1_0(s_logisimBus23[1:0]),
                                  .CSMIS_1_0(s_logisimBus54[1:0]),
                                  .CSSST_1_0(s_logisimBus129[1:0]),
                                  .CSTS_1_0(s_logisimBus81[1:0]),
                                  .DGPR0N(s_logisimNet124),
                                  .F0(s_logisimBus107[0]),
                                  .F15(s_logisimBus107[15]),
                                  .FSEL(s_logisimNet49),
                                  .GPR0(s_logisimBus113[0]),
                                  .GPRC_2_0(s_logisimBus15[2:0]),
                                  .GPRLI(s_logisimNet96),
                                  .LCZN(s_logisimNet85),
                                  .LDGPRN(s_logisimNet44),
                                  .LDIRV(s_logisimNet84),
                                  .LOG(s_logisimNet125),
                                  .MI(s_logisimNet71),
                                  .Q0(s_logisimBus66[0]),
                                  .Q15(s_logisimBus66[15]),
                                  .QLI(s_logisimNet126),
                                  .QSEL_1_0(s_logisimBus99[1:0]),
                                  .RA(s_logisimNet100),
                                  .RD(s_logisimNet48),
                                  .RLI(s_logisimNet117),
                                  .RRI(s_logisimNet74),
                                  .RSN(s_logisimNet55),
                                  .SA(s_logisimNet87),
                                  .SB(s_logisimNet34),
                                  .STS6(s_logisimBus51[6]),
                                  .STS7(s_logisimBus51[7]),
                                  .UPN(s_logisimNet118),
                                  .XFETCHN(s_logisimNet18));

endmodule

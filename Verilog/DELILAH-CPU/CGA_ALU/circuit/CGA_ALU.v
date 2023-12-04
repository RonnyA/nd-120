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
   wire [1:0]  s_logisimBus100;
   wire [3:0]  s_logisimBus106;
   wire [3:0]  s_logisimBus107;
   wire [15:0] s_logisimBus108;
   wire [15:0] s_logisimBus113;
   wire [15:0] s_logisimBus119;
   wire [15:0] s_logisimBus123;
   wire [15:0] s_logisimBus128;
   wire [1:0]  s_logisimBus129;
   wire [8:0]  s_logisimBus130;
   wire [2:0]  s_logisimBus16;
   wire [15:0] s_logisimBus17;
   wire [15:0] s_logisimBus18;
   wire [1:0]  s_logisimBus19;
   wire [1:0]  s_logisimBus23;
   wire [4:0]  s_logisimBus24;
   wire [1:0]  s_logisimBus25;
   wire [1:0]  s_logisimBus26;
   wire [2:0]  s_logisimBus27;
   wire [15:0] s_logisimBus35;
   wire [15:0] s_logisimBus38;
   wire [15:0] s_logisimBus51;
   wire [1:0]  s_logisimBus54;
   wire [15:0] s_logisimBus57;
   wire [15:0] s_logisimBus6;
   wire [15:0] s_logisimBus65;
   wire [15:0] s_logisimBus7;
   wire [15:0] s_logisimBus70;
   wire [1:0]  s_logisimBus81;
   wire [2:0]  s_logisimBus83;
   wire [15:0] s_logisimBus84;
   wire [15:0] s_logisimBus88;
   wire [15:0] s_logisimBus89;
   wire [3:0]  s_logisimBus9;
   wire [15:0] s_logisimBus91;
   wire        s_logisimNet0;
   wire        s_logisimNet1;
   wire        s_logisimNet10;
   wire        s_logisimNet101;
   wire        s_logisimNet102;
   wire        s_logisimNet103;
   wire        s_logisimNet104;
   wire        s_logisimNet105;
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
   wire        s_logisimNet15;
   wire        s_logisimNet2;
   wire        s_logisimNet20;
   wire        s_logisimNet21;
   wire        s_logisimNet22;
   wire        s_logisimNet28;
   wire        s_logisimNet29;
   wire        s_logisimNet3;
   wire        s_logisimNet30;
   wire        s_logisimNet31;
   wire        s_logisimNet32;
   wire        s_logisimNet33;
   wire        s_logisimNet34;
   wire        s_logisimNet36;
   wire        s_logisimNet37;
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
   wire        s_logisimNet52;
   wire        s_logisimNet53;
   wire        s_logisimNet55;
   wire        s_logisimNet56;
   wire        s_logisimNet58;
   wire        s_logisimNet59;
   wire        s_logisimNet60;
   wire        s_logisimNet61;
   wire        s_logisimNet62;
   wire        s_logisimNet63;
   wire        s_logisimNet64;
   wire        s_logisimNet66;
   wire        s_logisimNet67;
   wire        s_logisimNet68;
   wire        s_logisimNet69;
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
   wire        s_logisimNet82;
   wire        s_logisimNet85;
   wire        s_logisimNet86;
   wire        s_logisimNet87;
   wire        s_logisimNet90;
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
   assign s_logisimBus19[0] = s_logisimNet67;
   assign s_logisimBus19[1] = s_logisimNet104;
   assign s_logisimBus27[0] = s_logisimNet22;
   assign s_logisimBus27[1] = s_logisimNet47;
   assign s_logisimBus27[2] = s_logisimNet87;
   assign s_logisimBus83[0] = s_logisimNet120;
   assign s_logisimBus83[1] = s_logisimNet21;
   assign s_logisimBus83[2] = s_logisimNet46;
   assign s_logisimBus9[0]  = s_logisimNet31;
   assign s_logisimBus9[1]  = s_logisimNet13;
   assign s_logisimBus9[2]  = s_logisimNet3;
   assign s_logisimBus9[3]  = s_logisimNet114;
   assign s_logisimNet104   = s_logisimBus123[10];
   assign s_logisimNet114   = s_logisimBus51[11];
   assign s_logisimNet120   = s_logisimBus106[0];
   assign s_logisimNet13    = s_logisimBus51[9];
   assign s_logisimNet21    = s_logisimBus106[1];
   assign s_logisimNet22    = s_logisimBus107[1];
   assign s_logisimNet3     = s_logisimBus51[10];
   assign s_logisimNet31    = s_logisimBus51[8];
   assign s_logisimNet46    = s_logisimBus106[2];
   assign s_logisimNet47    = s_logisimBus107[2];
   assign s_logisimNet67    = s_logisimBus123[9];
   assign s_logisimNet87    = s_logisimBus107[3];

   /*******************************************************************************
   ** Here all input connections are defined                                     **
   *******************************************************************************/
   assign s_logisimBus106[3:0]  = LBA_3_0;
   assign s_logisimBus107[3:0]  = LAA_3_0;
   assign s_logisimBus123[15:0] = CD_15_0;
   assign s_logisimBus129[1:0]  = CSSST_1_0;
   assign s_logisimBus130[8:0]  = CSALUI_8_0;
   assign s_logisimBus18[15:0]  = FIDBI_15_0;
   assign s_logisimBus24[4:0]   = CSIDBS_4_0;
   assign s_logisimBus25[1:0]   = CSCINSEL_1_0;
   assign s_logisimBus26[1:0]   = CSALUM_1_0;
   assign s_logisimBus38[15:0]  = EA_15_0;
   assign s_logisimBus54[1:0]   = CSMIS_1_0;
   assign s_logisimBus57[15:0]  = A_15_0;
   assign s_logisimBus70[15:0]  = B_15_0;
   assign s_logisimBus84[15:0]  = CSBIT_15_0;
   assign s_logisimNet118       = UPN;
   assign s_logisimNet122       = ALUCLK;
   assign s_logisimNet20        = XFETCHN;
   assign s_logisimNet45        = LDGPRN;
   assign s_logisimNet66        = LDDBRN;
   assign s_logisimNet72        = LDPILN;
   assign s_logisimNet85        = LDIRV;
   assign s_logisimNet86        = LCZN;

   /*******************************************************************************
   ** Here all output connections are defined                                    **
   *******************************************************************************/
   assign BDEST      = s_logisimNet102;
   assign CRY        = s_logisimNet43;
   assign DOUBLE     = s_logisimBus51[13];
   assign F11        = s_logisimBus108[11];
   assign F15        = s_logisimBus108[15];
   assign FIDBO_15_0 = s_logisimBus119[15:0];
   assign IONI       = s_logisimBus51[15];
   assign MI         = s_logisimNet71;
   assign OVF        = s_logisimNet10;
   assign PIL        = s_logisimBus9[3:0];
   assign PONI       = s_logisimBus51[14];
   assign PTM        = s_logisimBus51[0];
   assign RB_15_0    = s_logisimBus89[15:0];
   assign SGR        = s_logisimNet68;
   assign Z          = s_logisimBus51[3];
   assign ZF         = s_logisimNet105;

   /*******************************************************************************
   ** Here all in-lined components are defined                                   **
   *******************************************************************************/

   // NOT Gate
   assign s_logisimBus119[15] = ~s_logisimBus35[15];

   // NOT Gate
   assign s_logisimBus119[14] = ~s_logisimBus35[14];

   // NOT Gate
   assign s_logisimBus119[13] = ~s_logisimBus35[13];

   // NOT Gate
   assign s_logisimBus119[12] = ~s_logisimBus35[12];

   // NOT Gate
   assign s_logisimBus119[11] = ~s_logisimBus35[11];

   // NOT Gate
   assign s_logisimBus119[10] = ~s_logisimBus35[10];

   // NOT Gate
   assign s_logisimBus119[9] = ~s_logisimBus35[9];

   // NOT Gate
   assign s_logisimBus119[8] = ~s_logisimBus35[8];

   // NOT Gate
   assign s_logisimBus119[7] = ~s_logisimBus35[7];

   // NOT Gate
   assign s_logisimBus119[6] = ~s_logisimBus35[6];

   // NOT Gate
   assign s_logisimBus119[5] = ~s_logisimBus35[5];

   // NOT Gate
   assign s_logisimBus119[4] = ~s_logisimBus35[4];

   // NOT Gate
   assign s_logisimBus119[3] = ~s_logisimBus35[3];

   // NOT Gate
   assign s_logisimBus119[2] = ~s_logisimBus35[2];

   // NOT Gate
   assign s_logisimBus119[1] = ~s_logisimBus35[1];

   // NOT Gate
   assign s_logisimBus119[0] = ~s_logisimBus35[0];

   // NOT Gate
   assign s_logisimNet64 = ~s_logisimNet8;

   /*******************************************************************************
   ** Here all normal components are defined                                     **
   *******************************************************************************/
   D_FLIPFLOP #(.invertClockEnable(0))
      MEMORY_1 (.clock(s_logisimNet122),
                .d(s_logisimBus24[2]),
                .preset(1'b0),
                .q(s_logisimNet34),
                .qBar(),
                .reset(1'b0),
                .tick(1'b1));


   /*******************************************************************************
   ** Here all sub-circuits are defined                                          **
   *******************************************************************************/

   MUX21LP   AARG0_MUX (.A(s_logisimBus106[3]),
                        .B(s_logisimBus107[0]),
                        .S(s_logisimNet34),
                        .ZN(s_logisimNet8));

   CGA_CPU_ALU_RALU   ALU_RALU (.ALUI4(s_logisimNet73),
                                .CI(s_logisimNet99),
                                .CRY(s_logisimNet43),
                                .FSEL(s_logisimNet50),
                                .F_15_0(s_logisimBus108[15:0]),
                                .LOG(s_logisimNet125),
                                .OVF(s_logisimNet10),
                                .RN_15_0(s_logisimBus6[15:0]),
                                .RSN(s_logisimNet55),
                                .SGR(s_logisimNet68),
                                .S_15_0(s_logisimBus7[15:0]),
                                .ZF(s_logisimNet105));

   CGA_ALU_SHIFT   ALU_SHIFT (.ALUI7(s_logisimNet121),
                              .ALUI8N(s_logisimNet110),
                              .F_15_0(s_logisimBus108[15:0]),
                              .RB_15_0(s_logisimBus89[15:0]),
                              .RLI(s_logisimNet117),
                              .RRI(s_logisimNet74));

   CGA_ALU_STS   ALU_STS (.ALUCLK(s_logisimNet122),
                          .CRY(s_logisimNet43),
                          .CSTS_1_0(s_logisimBus81[1:0]),
                          .FIDBO_15_0(s_logisimBus119[15:0]),
                          .LDPILN(s_logisimNet72),
                          .MI(s_logisimNet71),
                          .OVF(s_logisimNet10),
                          .STS_15_0(s_logisimBus51[15:0]));

   CGA_ALU_GPR   ALU_GPR (.ALUCLK(s_logisimNet122),
                          .CD_15_0(s_logisimBus123[15:0]),
                          .DGPR0N(s_logisimNet124),
                          .FIDBO_15_0(s_logisimBus119[15:0]),
                          .GPRC_2_0(s_logisimBus16[2:0]),
                          .GPRLI(s_logisimNet97),
                          .GPR_15_0(s_logisimBus113[15:0]));

   CGA_ALU_DBR   ALU_DBR (.ALUCLK(s_logisimNet122),
                          .CD_15_0(s_logisimBus123[15:0]),
                          .DBR_15_0(s_logisimBus128[15:0]),
                          .LDDBRN(s_logisimNet66));

   CGA_ALU_ARG   ALU_ARG (.ALUCLK(s_logisimNet122),
                          .ARG_15_0(s_logisimBus65[15:0]),
                          .CSBIT_15_0(s_logisimBus84[15:0]));

   CGA_ALU_SWAP   ALU_SWAP (.ALUCLK(s_logisimNet122),
                            .FIDBO_15_0(s_logisimBus119[15:0]),
                            .SW_15_0(s_logisimBus91[15:0]));

   CGA_ALU_OUTMUX   ALU_OUTMUX (.AARG0(s_logisimNet64),
                                .ALUCLK(s_logisimNet122),
                                .ALUD2N(s_logisimNet103),
                                .ARG_15_0(s_logisimBus65[15:0]),
                                .A_15_0(s_logisimBus57[15:0]),
                                .CSIDBS_4_0(s_logisimBus24[4:0]),
                                .DBR_15_0(s_logisimBus128[15:0]),
                                .D_15_0(s_logisimBus17[15:0]),
                                .EA_15_0(s_logisimBus38[15:0]),
                                .FIDBI_15_0(s_logisimBus18[15:0]),
                                .F_15_0(s_logisimBus108[15:0]),
                                .GPR_15_0(s_logisimBus113[15:0]),
                                .G_15_0(s_logisimBus35[15:0]),
                                .LAA_3_1(s_logisimBus27[2:0]),
                                .LBA_2_0(s_logisimBus83[2:0]),
                                .STS_15_0(s_logisimBus51[15:0]),
                                .SW_15_0(s_logisimBus91[15:0]));

   CGA_ALU_QREG   ALU_QREG (.ALUCLK(s_logisimNet122),
                            .F_15_0(s_logisimBus108[15:0]),
                            .QLI(s_logisimNet126),
                            .QSEL_1_0(s_logisimBus100[1:0]),
                            .Q_15_0(s_logisimBus88[15:0]));

   CGA_CPU_ALU_RMUX   ALU_RMUX (.A_15_0(s_logisimBus57[15:0]),
                                .D_15_0(s_logisimBus17[15:0]),
                                .RA(s_logisimNet101),
                                .RD(s_logisimNet49),
                                .RN_15_0(s_logisimBus6[15:0]));

   CGA_ALU_SMUX   ALU_SMUX (.A_15_0(s_logisimBus57[15:0]),
                            .B_15_0(s_logisimBus70[15:0]),
                            .Q_15_0(s_logisimBus88[15:0]),
                            .SA(s_logisimNet28),
                            .SB(s_logisimNet82),
                            .S_15_0(s_logisimBus7[15:0]));

   CGA_CPU_ALU_CONTR   ALU_CONTR (.ALUCLK(s_logisimNet122),
                                  .ALUD2N(s_logisimNet103),
                                  .ALUI4(s_logisimNet73),
                                  .ALUI7(s_logisimNet121),
                                  .ALUI8N(s_logisimNet110),
                                  .BDEST(s_logisimNet102),
                                  .CD_10_9(s_logisimBus23[1:0]),
                                  .CI(s_logisimNet99),
                                  .CRY(s_logisimNet43),
                                  .CSALUI_8_0(s_logisimBus130[8:0]),
                                  .CSALUM_1_0(s_logisimBus26[1:0]),
                                  .CSCINSEL_1_0(s_logisimBus25[1:0]),
                                  .CSMIS_1_0(s_logisimBus54[1:0]),
                                  .CSSST_1_0(s_logisimBus129[1:0]),
                                  .CSTS_1_0(s_logisimBus81[1:0]),
                                  .DGPR0N(s_logisimNet124),
                                  .F0(s_logisimBus108[0]),
                                  .F15(s_logisimBus108[15]),
                                  .FSEL(s_logisimNet50),
                                  .GPR0(s_logisimBus113[0]),
                                  .GPRC_2_0(s_logisimBus16[2:0]),
                                  .GPRLI(s_logisimNet97),
                                  .LCZN(s_logisimNet86),
                                  .LDGPRN(s_logisimNet45),
                                  .LDIRV(s_logisimNet85),
                                  .LOG(s_logisimNet125),
                                  .MI(s_logisimNet71),
                                  .Q0(s_logisimBus88[0]),
                                  .Q15(s_logisimBus88[15]),
                                  .QLI(s_logisimNet126),
                                  .QSEL_1_0(s_logisimBus100[1:0]),
                                  .RA(s_logisimNet101),
                                  .RD(s_logisimNet49),
                                  .RLI(s_logisimNet117),
                                  .RRI(s_logisimNet74),
                                  .RSN(s_logisimNet55),
                                  .SA(s_logisimNet28),
                                  .SB(s_logisimNet82),
                                  .STS6(s_logisimBus51[6]),
                                  .STS7(s_logisimBus51[7]),
                                  .UPN(s_logisimNet118),
                                  .XFETCHN(s_logisimNet20));

endmodule

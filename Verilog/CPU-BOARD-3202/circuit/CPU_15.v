/******************************************************************************
 ** Logisim-evolution goes FPGA automatic generated Verilog code             **
 ** https://github.com/logisim-evolution/                                    **
 **                                                                          **
 ** Component : CPU_15                                                       **
 **                                                                          **
 *****************************************************************************/

module CPU_15( ALUCLK,
               CA10,
               CA_9_0,
               CCLR_n,
               CC_3_1_n,
               CD_15_0_io,
               CLK,
               CYD,
               DT_n,
               DVACC_n,
               ECSR_n,
               EDO_n,
               EMCL_n,
               EMPID_n,
               EORF_n,
               ESTOF_n,
               ETRAP_n,
               FETCH,
               FMISS,
               FORM_n,
               IBINT10_n,
               IBINT11_n,
               IBINT12_n,
               IBINT13_n,
               IBINT15_n,
               IDB_15_0_io,
               IOXERR_n,
               LBA_3_0,
               LCS_n,
               LSHADOW,
               LUA_12_0,
               MACLK,
               MAP_n,
               MCLK,
               MOR_n,
               MR_n,
               OPCLCS,
               PAN_n,
               PARERR_n,
               PCR_1_0,
               PD1,
               PD2,
               PIL_3_0,
               PONI,
               POWFAIL_n,
               PPN_23_10,
               RT_n,
               RWCS_n,
               STOC_n,
               STP,
               SW1_CONSOLE,
               TERM_n,
               TEST_4_0,
               TOPCSB,
               TP1_INTRQ_n,
               TRAP,
               UCLK,
               VEX,
               WCHIM_n,
               WRFSTB,
               WRITE,
               logisimOutputBubbles );

   /*******************************************************************************
   ** The inputs are defined here                                                **
   *******************************************************************************/
   input       ALUCLK;
   input       CA10;
   input       CCLR_n;
   input [2:0] CC_3_1_n;
   input       CLK;
   input       CYD;
   input       DT_n;
   input       DVACC_n;
   input       ECSR_n;
   input       EDO_n;
   input       EMCL_n;
   input       EMPID_n;
   input       EORF_n;
   input       ESTOF_n;
   input       ETRAP_n;
   input       FETCH;
   input       FMISS;
   input       FORM_n;
   input       IBINT10_n;
   input       IBINT11_n;
   input       IBINT12_n;
   input       IBINT13_n;
   input       IBINT15_n;
   input       IOXERR_n;
   input       LCS_n;
   input       MACLK;
   input       MAP_n;
   input       MCLK;
   input       MOR_n;
   input       MR_n;
   input       PAN_n;
   input       PARERR_n;
   input       PD1;
   input       PD2;
   input       POWFAIL_n;
   input       RT_n;
   input       RWCS_n;
   input       STOC_n;
   input       STP;
   input       SW1_CONSOLE;
   input       TERM_n;
   input       UCLK;
   input       WCHIM_n;
   input       WRFSTB;
   input       WRITE;

   /*******************************************************************************
   ** The outputs are defined here                                               **
   *******************************************************************************/
   output [9:0]  CA_9_0;
   output [15:0] CD_15_0_io;
   output [15:0] IDB_15_0_io;
   output [3:0]  LBA_3_0;
   output        LSHADOW;
   output [12:0] LUA_12_0;
   output        OPCLCS;
   output [1:0]  PCR_1_0;
   output [3:0]  PIL_3_0;
   output        PONI;
   output [13:0] PPN_23_10;
   output [4:0]  TEST_4_0;
   output [63:0] TOPCSB;
   output        TP1_INTRQ_n;
   output        TRAP;
   output        VEX;
   output [0:0]  logisimOutputBubbles;

   /*******************************************************************************
   ** The wires are defined here                                                 **
   *******************************************************************************/
   wire [13:0] s_logisimBus1;
   wire [15:0] s_logisimBus12;
   wire [3:0]  s_logisimBus16;
   wire [63:0] s_logisimBus17;
   wire [13:0] s_logisimBus18;
   wire [4:0]  s_logisimBus19;
   wire [9:0]  s_logisimBus22;
   wire [15:0] s_logisimBus23;
   wire [2:0]  s_logisimBus29;
   wire [2:0]  s_logisimBus30;
   wire [1:0]  s_logisimBus34;
   wire [13:0] s_logisimBus46;
   wire [15:0] s_logisimBus52;
   wire [12:0] s_logisimBus56;
   wire [10:0] s_logisimBus69;
   wire [15:0] s_logisimBus7;
   wire [15:0] s_logisimBus70;
   wire [1:0]  s_logisimBus73;
   wire [3:0]  s_logisimBus75;
   wire [15:0] s_logisimBus84;
   wire [12:0] s_logisimBus89;
   wire [15:0] s_logisimBus9;
   wire        s_logisimNet0;
   wire        s_logisimNet10;
   wire        s_logisimNet11;
   wire        s_logisimNet13;
   wire        s_logisimNet14;
   wire        s_logisimNet15;
   wire        s_logisimNet2;
   wire        s_logisimNet20;
   wire        s_logisimNet21;
   wire        s_logisimNet24;
   wire        s_logisimNet25;
   wire        s_logisimNet26;
   wire        s_logisimNet27;
   wire        s_logisimNet28;
   wire        s_logisimNet3;
   wire        s_logisimNet31;
   wire        s_logisimNet32;
   wire        s_logisimNet33;
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
   wire        s_logisimNet47;
   wire        s_logisimNet48;
   wire        s_logisimNet49;
   wire        s_logisimNet5;
   wire        s_logisimNet50;
   wire        s_logisimNet51;
   wire        s_logisimNet53;
   wire        s_logisimNet54;
   wire        s_logisimNet55;
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
   wire        s_logisimNet71;
   wire        s_logisimNet72;
   wire        s_logisimNet74;
   wire        s_logisimNet76;
   wire        s_logisimNet77;
   wire        s_logisimNet78;
   wire        s_logisimNet79;
   wire        s_logisimNet8;
   wire        s_logisimNet80;
   wire        s_logisimNet81;
   wire        s_logisimNet82;
   wire        s_logisimNet83;
   wire        s_logisimNet85;
   wire        s_logisimNet86;
   wire        s_logisimNet87;
   wire        s_logisimNet88;
   wire        s_logisimNet90;
   wire        s_logisimNet91;
   wire        s_logisimNet92;
   wire        s_logisimNet93;
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
   assign s_logisimBus30[0] = s_logisimNet36;
   assign s_logisimBus30[1] = s_logisimNet93;
   assign s_logisimBus30[2] = s_logisimNet67;
   assign s_logisimNet36    = s_logisimBus29[0];
   assign s_logisimNet67    = s_logisimBus29[2];
   assign s_logisimNet93    = s_logisimBus29[1];

   /*******************************************************************************
   ** Here all input connections are defined                                     **
   *******************************************************************************/
   assign s_logisimBus29[2:0] = CC_3_1_n;
   assign s_logisimBus69[10]  = CA10;
   assign s_logisimNet13      = RT_n;
   assign s_logisimNet15      = EORF_n;
   assign s_logisimNet20      = EMCL_n;
   assign s_logisimNet24      = PAN_n;
   assign s_logisimNet25      = ALUCLK;
   assign s_logisimNet26      = IBINT13_n;
   assign s_logisimNet3       = MOR_n;
   assign s_logisimNet31      = MACLK;
   assign s_logisimNet38      = LCS_n;
   assign s_logisimNet4       = IBINT15_n;
   assign s_logisimNet40      = PD2;
   assign s_logisimNet41      = POWFAIL_n;
   assign s_logisimNet42      = ETRAP_n;
   assign s_logisimNet43      = WRFSTB;
   assign s_logisimNet44      = MAP_n;
   assign s_logisimNet45      = TERM_n;
   assign s_logisimNet48      = WCHIM_n;
   assign s_logisimNet5       = IBINT10_n;
   assign s_logisimNet50      = IBINT12_n;
   assign s_logisimNet51      = STOC_n;
   assign s_logisimNet53      = CYD;
   assign s_logisimNet57      = SW1_CONSOLE;
   assign s_logisimNet58      = EMPID_n;
   assign s_logisimNet59      = EDO_n;
   assign s_logisimNet60      = RWCS_n;
   assign s_logisimNet61      = STP;
   assign s_logisimNet62      = WRITE;
   assign s_logisimNet63      = IOXERR_n;
   assign s_logisimNet64      = PARERR_n;
   assign s_logisimNet65      = ECSR_n;
   assign s_logisimNet68      = FORM_n;
   assign s_logisimNet71      = CLK;
   assign s_logisimNet72      = UCLK;
   assign s_logisimNet76      = IBINT11_n;
   assign s_logisimNet8       = PD1;
   assign s_logisimNet80      = ESTOF_n;
   assign s_logisimNet86      = CCLR_n;
   assign s_logisimNet90      = DT_n;
   assign s_logisimNet91      = FMISS;
   assign s_logisimNet92      = FETCH;
   assign s_logisimNet96      = DVACC_n;
   assign s_logisimNet97      = MR_n;
   assign s_logisimNet98      = MCLK;

   /*******************************************************************************
   ** Here all output connections are defined                                    **
   *******************************************************************************/
   assign CA_9_0      = s_logisimBus69[9:0];
   assign CD_15_0_io  = s_logisimBus12[15:0];
   assign IDB_15_0_io = s_logisimBus23[15:0];
   assign LBA_3_0     = s_logisimBus16[3:0];
   assign LSHADOW     = s_logisimNet82;
   assign LUA_12_0    = s_logisimBus89[12:0];
   assign OPCLCS      = s_logisimNet32;
   assign PCR_1_0     = s_logisimBus73[1:0];
   assign PIL_3_0     = s_logisimBus75[3:0];
   assign PONI        = s_logisimNet83;
   assign PPN_23_10   = s_logisimBus18[13:0];
   assign TEST_4_0    = s_logisimBus19[4:0];
   assign TOPCSB      = s_logisimBus17[63:0];
   assign TP1_INTRQ_n = s_logisimNet54;
   assign TRAP        = s_logisimNet33;
   assign VEX         = s_logisimNet95;

   /*******************************************************************************
   ** Here all sub-circuits are defined                                          **
   *******************************************************************************/

   CPU_PROC_32   PROC (.ACOND_n(s_logisimNet28),
                       .ALUCLK(s_logisimNet25),
                       .BEDO_n(s_logisimNet77),
                       .BEMPID_n(s_logisimNet55),
                       .BRK_n(s_logisimNet11),
                       .BSTP(s_logisimNet87),
                       .CA_9_0(s_logisimBus69[9:0]),
                       .CD_15_0(s_logisimBus84[15:0]),
                       .CLK(s_logisimNet71),
                       .CSA_12_0(s_logisimBus56[12:0]),
                       .CSBITS(s_logisimBus17[63:0]),
                       .CSCA_9_0(s_logisimBus22[9:0]),
                       .CUP(s_logisimNet27),
                       .CWR(s_logisimNet6),
                       .DOUBLE(s_logisimNet85),
                       .ECCR(s_logisimNet78),
                       .ESTOF_n(s_logisimNet80),
                       .ETRAP_n(s_logisimNet42),
                       .EWCA_n(s_logisimNet14),
                       .IBINT10_n(s_logisimNet5),
                       .IBINT11_n(s_logisimNet76),
                       .IBINT12_n(s_logisimNet50),
                       .IBINT13_n(s_logisimNet26),
                       .IBINT15_n(s_logisimNet4),
                       .IDB_15_0_io(s_logisimBus23[15:0]),
                       .IONI(s_logisimNet74),
                       .IOXERR_n(s_logisimNet63),
                       .LA_23_10(s_logisimBus1[13:0]),
                       .LBA_3_0(s_logisimBus16[3:0]),
                       .LCS_n(s_logisimNet38),
                       .LEV0(s_logisimNet49),
                       .LSHADOW(s_logisimNet82),
                       .MAP_n(s_logisimNet44),
                       .MCLK(s_logisimNet98),
                       .MOR_n(s_logisimNet3),
                       .MREQ_n(s_logisimNet47),
                       .MR_n(s_logisimNet97),
                       .OPCLCS(s_logisimNet32),
                       .PAN_n(s_logisimNet24),
                       .PARERR_n(s_logisimNet64),
                       .PCR_1_0(s_logisimBus73[1:0]),
                       .PD1(s_logisimNet8),
                       .PIL_3_0(s_logisimBus75[3:0]),
                       .PONI(s_logisimNet83),
                       .POWFAIL_n(s_logisimNet41),
                       .PT_15_9(s_logisimBus52[15:9]),
                       .RF_1_0(s_logisimBus34[1:0]),
                       .RRF_n(s_logisimNet37),
                       .RT_n(s_logisimNet0),
                       .RWCS_n(s_logisimNet35),
                       .TERM_n(s_logisimNet45),
                       .TEST_4_0(s_logisimBus19[4:0]),
                       .TP1_INTRQ_n(s_logisimNet54),
                       .TRAP(s_logisimNet33),
                       .UCLK(s_logisimNet72),
                       .VEX(s_logisimNet95),
                       .WCA_n(s_logisimNet88),
                       .WCS_n(s_logisimNet2),
                       .WRFSTB(s_logisimNet43));

   CPU_CS_16   CS (.BLCS_n(s_logisimNet10),
                   .BRK_n(s_logisimNet11),
                   .CC_3_1_n(s_logisimBus30[2:0]),
                   .CLK(s_logisimNet71),
                   .CSA_12_0(s_logisimBus56[12:0]),
                   .CSBITS_io(s_logisimBus17[63:0]),
                   .CSCA_9_0(s_logisimBus22[9:0]),
                   .EWCA_n(s_logisimNet14),
                   .FETCH(s_logisimNet92),
                   .FORM_n(s_logisimNet68),
                   .IDB_15_0_io(s_logisimBus9[15:0]),
                   .LCS_n(s_logisimNet38),
                   .LUA_12_0(s_logisimBus89[12:0]),
                   .MACLK(s_logisimNet31),
                   .PD1(s_logisimNet8),
                   .RF_1_0(s_logisimBus34[1:0]),
                   .RWCS_n(s_logisimNet35),
                   .TERM_n(s_logisimNet45),
                   .WCA_n(s_logisimNet88),
                   .WCS_n(s_logisimNet2));

   CPU_MMU_24   MMU (.BEDO_n(s_logisimNet77),
                     .BEMPID_n(s_logisimNet55),
                     .BLCS_n(s_logisimNet10),
                     .BRK_n(s_logisimNet11),
                     .BSTP(s_logisimNet87),
                     .CA_10_0(s_logisimBus69[10:0]),
                     .CC2_n(s_logisimNet67),
                     .CCLR_n(s_logisimNet86),
                     .CD_15_0_io(s_logisimBus84[15:0]),
                     .CUP(s_logisimNet27),
                     .CWR(s_logisimNet6),
                     .CYD(s_logisimNet53),
                     .DOUBLE(s_logisimNet85),
                     .DT_n(s_logisimNet90),
                     .DVACC_n(s_logisimNet96),
                     .ECSR_n(s_logisimNet65),
                     .EDO_n(s_logisimNet59),
                     .EMCL_n(s_logisimNet20),
                     .EMPID_n(s_logisimNet58),
                     .EORF_n(s_logisimNet15),
                     .ESTOF_n(s_logisimNet80),
                     .FMISS(s_logisimNet91),
                     .HIT(s_logisimNet81),
                     .IDB_15_0_io(s_logisimBus7[15:0]),
                     .LAPA_n(s_logisimNet21),
                     .LA_20_10(s_logisimBus1[10:0]),
                     .LCS_n(s_logisimNet38),
                     .LSHADOW(s_logisimNet82),
                     .PD2(s_logisimNet40),
                     .PPN_23_10_io(s_logisimBus18[13:0]),
                     .PPN_25_10_io(s_logisimBus70[15:0]),
                     .PT_15_0(s_logisimBus52[15:0]),
                     .RT_n(s_logisimNet0),
                     .STP(s_logisimNet61),
                     .SW1_CONSOLE(s_logisimNet57),
                     .UCLK(s_logisimNet72),
                     .WCA_n(s_logisimNet88),
                     .WCHIM_n(s_logisimNet48),
                     .WRITE(s_logisimNet62),
                     .logisimOutputBubbles(logisimOutputBubbles[0 : 0]));

   CPU_STOC_35   CPU_STOC (.CD_15_0(s_logisimBus12[15:0]),
                           .IDB_15_0(s_logisimBus23[15:0]),
                           .STOC_n(s_logisimNet51));

   CPU_LAPA_23   LAPA (.LAPA_n(s_logisimNet21),
                       .LA_23_10(s_logisimBus1[13:0]),
                       .PPN_23_10(s_logisimBus46[13:0]));

endmodule

/**************************************************************************
** ND120 CPU, MM&M                                                       **
** CPU/PROC/CGA                                                          **
** CPU GATE ARRAY                                                        **
** SHEET 33 of 50                                                        **
**                                                                       ** 
** Last reviewed: 14-JAN-2024                                            **
** Ronny Hansen                                                          **
***************************************************************************/
/* verilator lint_off UNUSED */

module CPU_PROC_CGA_33( 
   input        ALUCLK,
   input        BEDO_n,
   input        BEMPID_n,
   input        BSTP,
   input [15:0] CD_15_0,
   input [63:0] CSBITS,
   input        ETRAP_n,
   input        EWCA_n,
   input        IBINT10_n,
   input        IBINT11_n,
   input        IBINT12_n,
   input        IBINT13_n,
   input        IBINT15_n,
   input        IOXERR_n,
   input        LCS_n,
   input        MAP_n,
   input        MCLK,
   input        MOR_n,
   input        MR_n,
   input        PAN_n,
   input        PARERR_n,
   input        POWFAIL_n,
   input [6:0]  PT_15_9,
   input        UCLK,

   // Outputs

   output        ACOND_n,
   output        CGABRK_n,
   output [12:0] CSA_12_0,
   output [9:0]  CSCA_9_0,
   output        DOUBLE,
   output        ECCR,
   output [15:0] FIDB_15_0_io,
   output        INTRQ_n_tp1,
   output        IONI,
   output [3:0]  LAA_3_0,
   output [13:0] LA_23_10,
   output [3:0]  LBA_3_0,
   output        LSHADOW,
   output [1:0]  PCR_1_0,
   output [3:0]  PIL_3_0,
   output        PONI,
   output [1:0]  RF_1_0,
   output [4:0]  TEST_4_0,
   output        TRAP_n,
   output        WCS_n,
   output        WRTRF
);

   /*******************************************************************************
   ** The wires are defined here                                                 **
   *******************************************************************************/
   wire [9:0]  s_logisimBus0;
   wire [3:0]  s_logisimBus10;
   wire [1:0]  s_logisimBus102;
   wire [3:0]  s_logisimBus103;
   wire [4:0]  s_logisimBus105;
   wire [1:0]  s_logisimBus106;
   wire [1:0]  s_logisimBus107;
   wire [1:0]  s_logisimBus108;
   wire [4:0]  s_logisimBus114;
   wire [1:0]  s_logisimBus121;
   wire [3:0]  s_logisimBus26;
   wire [15:0] s_logisimBus27;
   wire [3:0]  s_logisimBus35;
   wire [15:0] s_logisimBus37;
   wire [1:0]  s_logisimBus38;
   wire [12:0] s_logisimBus39;
   wire [15:0] s_logisimBus4;
   wire [1:0]  s_logisimBus40;
   wire [3:0]  s_logisimBus43;
   wire [6:0]  s_logisimBus44;
   wire [1:0]  s_logisimBus45;
   wire [3:0]  s_logisimBus53;
   wire [15:0] s_logisimBus61;
   wire [1:0]  s_logisimBus62;
   wire [63:0] s_logisimBus63;
   wire [4:0]  s_logisimBus67;
   wire [1:0]  s_logisimBus68;
   wire [4:0]  s_logisimBus69;
   wire [1:0]  s_logisimBus70;
   wire [8:0]  s_logisimBus71;
   wire [1:0]  s_logisimBus78;
   wire [1:0]  s_logisimBus79;
   wire [1:0]  s_logisimBus87;
   wire [4:0]  s_logisimBus88;
   wire [3:0]  s_logisimBus90;
   wire [1:0]  s_logisimBus93;
   wire [13:0] s_logisimBus94;
   wire [1:0]  s_logisimBus95;
   wire [8:0]  s_logisimBus96;
   wire        s_logisimNet1;
   wire        s_logisimNet100;
   wire        s_logisimNet101;
   wire        s_logisimNet104;
   wire        s_logisimNet109;
   wire        s_logisimNet11;
   wire        s_logisimNet110;
   wire        s_logisimNet111;
   wire        s_logisimNet112;
   wire        s_logisimNet113;
   wire        s_logisimNet115;
   wire        s_logisimNet116;
   wire        s_logisimNet117;
   wire        s_logisimNet118;
   wire        s_logisimNet119;
   wire        s_logisimNet12;
   wire        s_logisimNet120;
   wire        s_logisimNet122;
   wire        s_logisimNet123;
   wire        s_logisimNet124;
   wire        s_logisimNet125;
   wire        s_logisimNet126;
   wire        s_logisimNet127;
   wire        s_logisimNet128;
   wire        s_logisimNet129;
   wire        s_logisimNet13;
   wire        s_logisimNet130;
   wire        s_logisimNet131;
   wire        s_logisimNet132;
   wire        s_logisimNet133;
   wire        s_logisimNet134;
   wire        s_logisimNet135;
   wire        s_logisimNet136;
   wire        s_logisimNet137;
   wire        s_logisimNet138;
   wire        s_logisimNet139;
   wire        s_logisimNet14;
   wire        s_logisimNet140;
   wire        s_logisimNet141;
   wire        s_logisimNet142;
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
   wire        s_logisimNet28;
   wire        s_logisimNet29;
   wire        s_logisimNet3;
   wire        s_logisimNet30;
   wire        s_logisimNet31;
   wire        s_logisimNet32;
   wire        s_logisimNet33;
   wire        s_logisimNet34;
   wire        s_logisimNet36;
   wire        s_logisimNet41;
   wire        s_logisimNet42;
   wire        s_logisimNet46;
   wire        s_logisimNet47;
   wire        s_logisimNet48;
   wire        s_logisimNet49;
   wire        s_logisimNet5;
   wire        s_logisimNet50;
   wire        s_logisimNet51;
   wire        s_logisimNet52;
   wire        s_logisimNet54;
   wire        s_logisimNet55;
   wire        s_logisimNet56;
   wire        s_logisimNet57;
   wire        s_logisimNet58;
   wire        s_logisimNet59;
   wire        s_logisimNet6;
   wire        s_logisimNet60;
   wire        s_logisimNet64;
   wire        s_logisimNet65;
   wire        s_logisimNet66;
   wire        s_logisimNet7;
   wire        s_logisimNet72;
   wire        s_logisimNet73;
   wire        s_logisimNet74;
   wire        s_logisimNet75;
   wire        s_logisimNet76;
   wire        s_logisimNet77;
   wire        s_logisimNet8;
   wire        s_logisimNet80;
   wire        s_logisimNet81;
   wire        s_logisimNet82;
   wire        s_logisimNet83;
   wire        s_logisimNet84;
   wire        s_logisimNet85;
   wire        s_logisimNet86;
   wire        s_logisimNet89;
   wire        s_logisimNet9;
   wire        s_logisimNet91;
   wire        s_logisimNet92;
   wire        s_logisimNet97;
   wire        s_logisimNet98;
   wire        s_logisimNet99;

   /*******************************************************************************
   ** The module functionality is described here                                 **
   *******************************************************************************/

   /*******************************************************************************
   ** Here all wiring is defined                                                 **
   *******************************************************************************/
   assign s_logisimBus108[0] = s_logisimNet12;
   assign s_logisimBus108[1] = s_logisimNet73;
   assign s_logisimBus114[0] = s_logisimNet20;
   assign s_logisimBus114[1] = s_logisimNet81;
   assign s_logisimBus114[2] = s_logisimNet19;
   assign s_logisimBus114[3] = s_logisimNet80;
   assign s_logisimBus114[4] = s_logisimNet18;
   assign s_logisimBus43[0]  = s_logisimNet15;
   assign s_logisimBus43[1]  = s_logisimNet76;
   assign s_logisimBus43[2]  = s_logisimNet14;
   assign s_logisimBus43[3]  = s_logisimNet75;
   assign s_logisimBus45[0]  = s_logisimNet8;
   assign s_logisimBus45[1]  = s_logisimNet64;
   assign s_logisimBus61[0]  = s_logisimNet142;
   assign s_logisimBus61[10] = s_logisimNet132;
   assign s_logisimBus61[11] = s_logisimNet131;
   assign s_logisimBus61[12] = s_logisimNet130;
   assign s_logisimBus61[13] = s_logisimNet129;
   assign s_logisimBus61[14] = s_logisimNet128;
   assign s_logisimBus61[15] = s_logisimNet127;
   assign s_logisimBus61[1]  = s_logisimNet141;
   assign s_logisimBus61[2]  = s_logisimNet140;
   assign s_logisimBus61[3]  = s_logisimNet139;
   assign s_logisimBus61[4]  = s_logisimNet138;
   assign s_logisimBus61[5]  = s_logisimNet137;
   assign s_logisimBus61[6]  = s_logisimNet136;
   assign s_logisimBus61[7]  = s_logisimNet135;
   assign s_logisimBus61[8]  = s_logisimNet134;
   assign s_logisimBus61[9]  = s_logisimNet133;
   assign s_logisimBus62[0]  = s_logisimNet82;
   assign s_logisimBus62[1]  = s_logisimNet21;
   assign s_logisimBus78[0]  = s_logisimNet77;
   assign s_logisimBus78[1]  = s_logisimNet16;
   assign s_logisimBus79[0]  = s_logisimNet28;
   assign s_logisimBus79[1]  = s_logisimNet89;
   assign s_logisimBus88[0]  = s_logisimNet126;
   assign s_logisimBus88[1]  = s_logisimNet125;
   assign s_logisimBus88[2]  = s_logisimNet124;
   assign s_logisimBus88[3]  = s_logisimNet123;
   assign s_logisimBus88[4]  = s_logisimNet122;
   assign s_logisimBus90[0]  = s_logisimNet47;
   assign s_logisimBus90[1]  = s_logisimNet110;
   assign s_logisimBus90[2]  = s_logisimNet46;
   assign s_logisimBus90[3]  = s_logisimNet109;
   assign s_logisimBus93[0]  = s_logisimNet24;
   assign s_logisimBus93[1]  = s_logisimNet83;
   assign s_logisimBus95[0]  = s_logisimNet13;
   assign s_logisimBus95[1]  = s_logisimNet74;
   assign s_logisimBus96[0]  = s_logisimNet52;
   assign s_logisimBus96[1]  = s_logisimNet118;
   assign s_logisimBus96[2]  = s_logisimNet51;
   assign s_logisimBus96[3]  = s_logisimNet117;
   assign s_logisimBus96[4]  = s_logisimNet50;
   assign s_logisimBus96[5]  = s_logisimNet116;
   assign s_logisimBus96[6]  = s_logisimNet49;
   assign s_logisimBus96[7]  = s_logisimNet115;
   assign s_logisimBus96[8]  = s_logisimNet48;
   assign s_logisimNet109    = s_logisimBus63[31];
   assign s_logisimNet110    = s_logisimBus63[29];
   assign s_logisimNet115    = s_logisimBus63[62];
   assign s_logisimNet116    = s_logisimBus63[60];
   assign s_logisimNet117    = s_logisimBus63[58];
   assign s_logisimNet118    = s_logisimBus63[56];
   assign s_logisimNet12     = s_logisimBus63[46];
   assign s_logisimNet122    = s_logisimBus63[36];
   assign s_logisimNet123    = s_logisimBus63[35];
   assign s_logisimNet124    = s_logisimBus63[34];
   assign s_logisimNet125    = s_logisimBus63[33];
   assign s_logisimNet126    = s_logisimBus63[32];
   assign s_logisimNet127    = s_logisimBus63[15];
   assign s_logisimNet128    = s_logisimBus63[14];
   assign s_logisimNet129    = s_logisimBus63[13];
   assign s_logisimNet13     = s_logisimBus63[42];
   assign s_logisimNet130    = s_logisimBus63[12];
   assign s_logisimNet131    = s_logisimBus63[11];
   assign s_logisimNet132    = s_logisimBus63[10];
   assign s_logisimNet133    = s_logisimBus63[9];
   assign s_logisimNet134    = s_logisimBus63[8];
   assign s_logisimNet135    = s_logisimBus63[7];
   assign s_logisimNet136    = s_logisimBus63[6];
   assign s_logisimNet137    = s_logisimBus63[5];
   assign s_logisimNet138    = s_logisimBus63[4];
   assign s_logisimNet139    = s_logisimBus63[3];
   assign s_logisimNet14     = s_logisimBus63[18];
   assign s_logisimNet140    = s_logisimBus63[2];
   assign s_logisimNet141    = s_logisimBus63[1];
   assign s_logisimNet142    = s_logisimBus63[0];
   assign s_logisimNet15     = s_logisimBus63[16];
   assign s_logisimNet16     = s_logisimBus63[54];
   assign s_logisimNet18     = s_logisimBus63[41];
   assign s_logisimNet19     = s_logisimBus63[39];
   assign s_logisimNet20     = s_logisimBus63[37];
   assign s_logisimNet21     = s_logisimBus63[27];
   assign s_logisimNet24     = s_logisimBus63[44];
   assign s_logisimNet28     = s_logisimBus63[48];
   assign s_logisimNet46     = s_logisimBus63[30];
   assign s_logisimNet47     = s_logisimBus63[28];
   assign s_logisimNet48     = s_logisimBus63[63];
   assign s_logisimNet49     = s_logisimBus63[61];
   assign s_logisimNet50     = s_logisimBus63[59];
   assign s_logisimNet51     = s_logisimBus63[57];
   assign s_logisimNet52     = s_logisimBus63[55];
   assign s_logisimNet64     = s_logisimBus63[52];
   assign s_logisimNet73     = s_logisimBus63[47];
   assign s_logisimNet74     = s_logisimBus63[43];
   assign s_logisimNet75     = s_logisimBus63[19];
   assign s_logisimNet76     = s_logisimBus63[17];
   assign s_logisimNet77     = s_logisimBus63[53];
   assign s_logisimNet8      = s_logisimBus63[51];
   assign s_logisimNet80     = s_logisimBus63[40];
   assign s_logisimNet81     = s_logisimBus63[38];
   assign s_logisimNet82     = s_logisimBus63[26];
   assign s_logisimNet83     = s_logisimBus63[45];
   assign s_logisimNet89     = s_logisimBus63[49];

   /*******************************************************************************
   ** Here all input connections are defined                                     **
   *******************************************************************************/
   assign s_logisimBus44[6:0]  = PT_15_9;
   assign s_logisimBus4[15:0]  = CD_15_0;
   assign s_logisimBus63[63:0] = CSBITS;
   assign s_logisimNet101      = PARERR_n;
   assign s_logisimNet120      = IOXERR_n;
   assign s_logisimNet25       = MCLK;
   assign s_logisimNet29       = ETRAP_n;
   assign s_logisimNet3        = ALUCLK;
   assign s_logisimNet30       = BSTP;
   assign s_logisimNet31       = BEDO_n;
   assign s_logisimNet32       = MR_n;
   assign s_logisimNet33       = IBINT13_n;
   assign s_logisimNet34       = IBINT11_n;
   assign s_logisimNet42       = UCLK;
   assign s_logisimNet5        = BEMPID_n;
   assign s_logisimNet56       = MAP_n;
   assign s_logisimNet57       = EWCA_n;
   assign s_logisimNet59       = POWFAIL_n;
   assign s_logisimNet6        = LCS_n;
   assign s_logisimNet84       = IBINT15_n;
   assign s_logisimNet85       = IBINT12_n;
   assign s_logisimNet86       = IBINT10_n;
   assign s_logisimNet91       = MOR_n;
   assign s_logisimNet97       = PAN_n;

   /*******************************************************************************
   ** Here all output connections are defined                                    **
   *******************************************************************************/
   assign ACOND_n      = s_logisimNet17;
   assign CGABRK_n     = s_logisimNet17;
   assign CSA_12_0     = s_logisimBus39[12:0];
   assign CSCA_9_0     = s_logisimBus0[9:0];
   assign DOUBLE       = s_logisimNet17;
   assign ECCR         = s_logisimNet17;
   assign FIDB_15_0_io = s_logisimBus27[15:0];
   assign INTRQ_n_tp1  = s_logisimNet17;
   assign IONI         = s_logisimNet17;
   assign LAA_3_0      = s_logisimBus26[3:0];
   assign LA_23_10     = s_logisimBus94[13:0];
   assign LBA_3_0      = s_logisimBus53[3:0];
   assign LSHADOW      = s_logisimNet17;
   assign PCR_1_0      = s_logisimBus121[1:0];
   assign PIL_3_0      = s_logisimBus35[3:0];
   assign PONI         = s_logisimNet17;
   assign RF_1_0       = s_logisimBus87[1:0];
   assign TEST_4_0     = s_logisimBus69[4:0];
   assign TRAP_n       = s_logisimNet17;
   assign WCS_n        = s_logisimNet17;
   assign WRTRF        = s_logisimNet17;

   /*******************************************************************************
   ** Here all in-lined components are defined                                   **
   *******************************************************************************/

   // Constant
   assign  s_logisimBus27[15:0]  =  16'hAAAA;


   // Constant
   assign  s_logisimBus0[9:0]  =  {2'b10, 8'hAF};


   // Constant
   assign  s_logisimBus94[13:0]  =  {2'b11, 12'hEAF};


   // Constant
   assign  s_logisimBus69[4:0]  =  {1'b1, 4'hF};


   // Constant
   assign  s_logisimBus39[12:0]  =  {1'b0, 12'h1BC};


   // Constant
   assign  s_logisimNet17  =  1'b1;


   // Constant
   assign  s_logisimBus35[3:0]  =  4'h0;


   // Constant
   assign  s_logisimBus121[1:0]  =  2'b01;


   // Constant
   assign  s_logisimBus87[1:0]  =  2'b01;


   // Constant
   assign  s_logisimBus53[3:0]  =  4'h3;


   // Constant
   assign  s_logisimBus26[3:0]  =  4'h4;


   // Ground
   assign  s_logisimNet72  =  1'b0;


   // Buffer
   assign s_logisimNet41 = s_logisimBus63[21];

   // Buffer
   assign s_logisimNet66 = s_logisimBus63[25];

   // Buffer
   assign s_logisimNet36 = s_logisimBus63[22];

   // Buffer
   assign s_logisimNet9 = s_logisimBus63[20];

   // Buffer
   assign s_logisimNet11 = s_logisimBus63[50];

   // Buffer
   assign s_logisimBus103 = s_logisimBus90;

   // Buffer
   assign s_logisimNet65 = s_logisimBus63[24];

   // Buffer
   assign s_logisimNet104 = s_logisimBus63[23];

   // Buffer
   assign s_logisimBus10 = s_logisimBus43;

   // Buffer
   assign s_logisimBus37 = s_logisimBus61;

   // Buffer
   assign s_logisimBus70 = s_logisimBus95;

   // Buffer
   assign s_logisimBus71 = s_logisimBus96;

   // Buffer
   assign s_logisimBus67 = s_logisimBus114;

   // Buffer
   assign s_logisimBus102 = s_logisimBus78;

   // Buffer
   assign s_logisimBus68 = s_logisimBus93;

   // Buffer
   assign s_logisimBus105 = s_logisimBus88;

   // Buffer
   assign s_logisimBus38 = s_logisimBus62;

   // Buffer
   assign s_logisimBus106 = s_logisimBus45;

   // Buffer
   assign s_logisimBus40 = s_logisimBus79;

   // Buffer
   assign s_logisimBus107 = s_logisimBus108;

   // Buffer
   assign s_logisimNet58 = s_logisimNet97;

   // Buffer
   assign s_logisimNet54 = s_logisimNet91;

   // Buffer
   assign s_logisimNet1 = s_logisimNet120;

   // Buffer
   assign s_logisimNet55 = s_logisimNet101;

   // Buffer
   assign s_logisimNet2 = s_logisimNet59;

   /*******************************************************************************
   ** Here all sub-circuits are defined                                          **
   *******************************************************************************/

/*
   TTL_74374   CHIP_34G (.CK(s_logisimNet3),
                         .D1(1'b0),
                         .D2(1'b0),
                         .D3(1'b0),
                         .D4(s_logisimNet84),
                         .D5(s_logisimNet33),
                         .D6(s_logisimNet85),
                         .D7(s_logisimNet34),
                         .D8(s_logisimNet86),
                         .OE_n(s_logisimNet72),
                         .Q1(),
                         .Q2(),
                         .Q3(),
                         .Q4(s_logisimNet111),
                         .Q5(s_logisimNet22),
                         .Q6(s_logisimNet112),
                         .Q7(s_logisimNet23),
                         .Q8(s_logisimNet113));
*/
TTL_74374 CHIP_34G (
    .CK(s_logisimNet3),
    .D({s_logisimNet86, s_logisimNet34, s_logisimNet85, s_logisimNet33, s_logisimNet84, 3'b000}), // 8-bit D input, lower 3 bits unused
    .OE_n(s_logisimNet72),
    .Q({s_logisimNet113, s_logisimNet23, s_logisimNet112, s_logisimNet22, s_logisimNet111, 3'bzzz}) // 8-bit Q output, lower 3 bits ignored
);


CGA DELILAH (
   .BDEST(s_logisimNet41)
);




endmodule

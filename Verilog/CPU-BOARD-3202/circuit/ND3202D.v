/**************************************************************************
** ND120 CPU, MM&M                                                       **
** CPU                                                                   **
** CPU TOP LEVEL                                                         **
** SHEET 16 of 50                                                        **
**                                                                       ** 
** Last reviewed: 15-APRIL-2024                                          **
** Ronny Hansen                                                          **               
***************************************************************************/

//TODO: Missing MEM, BIF, IO and BUS Connectors A-B-C

module ND3202D (   
   input sysclk, // System clock in FPGA
   input sys_rst_n, // System reset in FPGA
   /*******************************************************************************
   ** The inputs are defined here                                                **
   *******************************************************************************/
   input BINT10_n,
   input BINT11_n,
   input BINT12_n,
   input BINT13_n,
   input BINT15_n,
   input BREQ_n,
   input CLOCK_1,
   input CLOCK_2,
   input CONSOLE_n,
   input CONTINUE_n,
   input EAUTO_n,
   input LOAD_n,
   input LOCK_n,
   input OC_1_0, // TO IO OC_1_0
   input OSCCL_n,
   input RXD,
   input STOP_n,
   input SW1_CONSOLE,
   input SWMCL_n,
   input XTR,


   /*******************************************************************************
   ** The outputs are defined here                                               **
   *******************************************************************************/
   output [63:0] CSBITS,
   output [4:0]  DP_5_1_n,
   output        RUN_n,
   output [4:0]  TEST_4_0,
   output        TP1_INTRQ_n,
   output        TXD,
   output [4:0]  LED // 0=CPU RED,1=CPU GREEN, 2=LED4_RED_PARITY_ERROR, 3=LED_CPU_GRANT_INDICATOR, 4=LED_BUS_GRANT_INDICATOR
);


   /*******************************************************************************
   ** The wires are defined here                                                 **
   *******************************************************************************/
   wire [15:0] s_idb_15_0_cpu_out;
   wire [15:0] s_cd_15_0_cpu_out;
   wire s_LDEXM_n;
   
   wire [3:0]  s_logisimBus115;
   wire [15:0] s_IDB_15_0_in;
   wire [9:0]  s_logisimBus118;
   wire [4:0]  s_logisimBus127;
   wire [4:0]  s_logisimBus133;
   wire [1:0]  s_logisimBus139;
   wire [12:0] s_logisimBus14;
   wire [1:0]  s_logisimBus146;
   wire [15:0] s_logisimBus160;
   wire [7:0]  s_logisimBus170;
   wire [15:0] s_logisimBus173;
   wire [4:0]  s_logisimBus174;
   wire [8:0]  s_logisimBus185;
   wire [1:0]  s_logisimBus209;
   wire [7:0]  s_logisimBus21;
   wire [7:0]  s_logisimBus210;
   wire [1:0]  s_logisimBus223;
   wire [3:0]  s_logisimBus23;
   wire [3:0]  s_logisimBus246;
   wire [63:0] s_logisimBus247;
   wire [23:0] s_logisimBus28;
   wire [15:0] s_logisimBus32;
   wire [15:0] s_logisimBus38;
   wire [2:0]  s_logisimBus4;
   wire [1:0]  s_oc_1_0;
   wire [1:0]  s_logisimBus50;
   wire [7:0]  s_logisimBus54;
   wire [1:0]  s_logisimBus62;
   wire [1:0]  s_logisimBus63;
   wire [4:0]  s_logisimBus66;
   wire [13:0] s_logisimBus67;
   wire [1:0]  s_logisimBus68;
   wire [23:0] s_logisimBus73;
   wire [3:0]  s_logisimBus75;
   wire [15:0] s_logisimBus81;
   wire [4:0]  s_logisimBus83;
   wire [15:0] s_logisimBus90;
   wire [4:0]  s_logisimBus95;
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
   wire        s_logisimNet108;
   wire        s_logisimNet109;
   wire        s_logisimNet11;
   wire        s_logisimNet110;
   wire        s_logisimNet111;
   wire        s_logisimNet112;
   wire        s_logisimNet113;
   wire        s_logisimNet114;
   wire        s_logisimNet116;
   wire        s_logisimNet119;
   wire        s_logisimNet12;
   wire        s_logisimNet120;
   wire        s_logisimNet121;
   wire        s_logisimNet122;
   wire        s_logisimNet123;
   wire        s_logisimNet124;
   wire        s_logisimNet125;
   wire        s_logisimNet126;
   wire        s_logisimNet128;
   wire        s_logisimNet129;
   wire        s_logisimNet13;
   wire        s_logisimNet130;
   wire        s_logisimNet131;
   wire        s_logisimNet132;
   wire        s_logisimNet134;
   wire        s_logisimNet135;
   wire        s_logisimNet136;
   wire        s_logisimNet137;
   wire        s_logisimNet138;
   wire        s_logisimNet140;
   wire        s_logisimNet141;
   wire        s_logisimNet142;
   wire        s_logisimNet143;
   wire        s_logisimNet144;
   wire        s_logisimNet145;
   wire        s_logisimNet147;
   wire        s_logisimNet148;
   wire        s_logisimNet149;
   wire        s_logisimNet15;
   wire        s_logisimNet150;
   wire        s_logisimNet151;
   wire        s_logisimNet152;
   wire        s_logisimNet153;
   wire        s_logisimNet154;
   wire        s_logisimNet155;
   wire        s_logisimNet156;
   wire        s_logisimNet157;
   wire        s_logisimNet158;
   wire        s_logisimNet159;
   wire        s_logisimNet16;
   wire        s_logisimNet161;
   wire        s_logisimNet162;
   wire        s_logisimNet163;
   wire        s_logisimNet164;
   wire        s_logisimNet165;
   wire        s_logisimNet166;
   wire        s_logisimNet167;
   wire        s_logisimNet168;
   wire        s_logisimNet169;
   wire        s_logisimNet17;
   wire        s_logisimNet171;
   wire        s_logisimNet172;
   wire        s_logisimNet175;
   wire        s_logisimNet176;
   wire        s_logisimNet177;
   wire        s_logisimNet178;
   wire        s_logisimNet179;
   wire        s_logisimNet18;
   wire        s_logisimNet180;
   wire        s_logisimNet181;
   wire        s_logisimNet182;
   wire        s_logisimNet183;
   wire        s_logisimNet184;
   wire        s_logisimNet186;
   wire        s_logisimNet187;
   wire        s_logisimNet188;
   wire        s_logisimNet189;
   wire        s_logisimNet19;
   wire        s_logisimNet190;
   wire        s_logisimNet191;
   wire        s_logisimNet192;
   wire        s_logisimNet193;
   wire        s_logisimNet194;
   wire        s_logisimNet195;
   wire        s_logisimNet196;
   wire        s_logisimNet197;
   wire        s_logisimNet198;
   wire        s_logisimNet199;
   wire        s_logisimNet2;
   wire        s_logisimNet20;
   wire        s_logisimNet200;
   wire        s_logisimNet201;
   wire        s_logisimNet202;
   wire        s_logisimNet203;
   wire        s_logisimNet204;
   wire        s_logisimNet205;
   wire        s_logisimNet206;
   wire        s_logisimNet207;
   wire        s_logisimNet208;
   wire        s_logisimNet211;
   wire        s_logisimNet212;
   wire        s_logisimNet213;
   wire        s_logisimNet214;
   wire        s_logisimNet215;
   wire        s_logisimNet216;
   wire        s_logisimNet217;
   wire        s_logisimNet218;
   wire        s_logisimNet219;
   wire        s_logisimNet22;
   wire        s_logisimNet220;
   wire        s_logisimNet221;
   wire        s_logisimNet222;
   wire        s_logisimNet224;
   wire        s_logisimNet225;
   wire        s_logisimNet226;
   wire        s_logisimNet227;
   wire        s_logisimNet228;
   wire        s_logisimNet229;
   wire        s_logisimNet230;
   wire        s_logisimNet231;
   wire        s_logisimNet232;
   wire        s_logisimNet233;
   wire        s_logisimNet234;
   wire        s_logisimNet235;
   wire        s_logisimNet236;
   wire        s_logisimNet237;
   wire        s_logisimNet238;
   wire        s_logisimNet239;
   wire        s_logisimNet24;
   wire        s_logisimNet240;
   wire        s_logisimNet241;
   wire        s_logisimNet242;
   wire        s_logisimNet243;
   wire        s_logisimNet244;
   wire        s_logisimNet245;
   wire        s_logisimNet248;
   wire        s_logisimNet249;
   wire        s_logisimNet25;
   wire        s_logisimNet250;
   wire        s_logisimNet251;
   wire        s_logisimNet252;
   wire        s_logisimNet253;
   wire        s_logisimNet254;
   wire        s_logisimNet255;
   wire        s_logisimNet256;
   wire        s_logisimNet257;
   wire        s_logisimNet258;
   wire        s_logisimNet259;
   wire        s_logisimNet26;
   wire        s_logisimNet260;
   wire        s_logisimNet261;
   wire        s_logisimNet262;
   wire        s_logisimNet263;
   wire        s_logisimNet264;
   wire        s_logisimNet265;
   wire        s_logisimNet266;
   wire        s_logisimNet267;
   wire        s_logisimNet268;
   wire        s_logisimNet269;
   wire        s_logisimNet27;
   wire        s_logisimNet270;
   wire        s_logisimNet271;
   wire        s_logisimNet272;
   wire        s_logisimNet273;
   wire        s_logisimNet29;
   wire        s_logisimNet30;
   wire        s_logisimNet31;
   wire        s_logisimNet33;
   wire        s_logisimNet34;
   wire        s_logisimNet35;
   wire        s_logisimNet36;
   wire        s_logisimNet37;
   wire        s_logisimNet39;
   wire        s_logisimNet40;
   wire        s_logisimNet41;
   wire        s_logisimNet42;
   wire        s_logisimNet43;
   wire        s_logisimNet44;
   wire        s_logisimNet45;
   wire        s_logisimNet46;
   wire        s_logisimNet48;
   wire        s_logisimNet49;
   wire        s_logisimNet5;
   wire        s_logisimNet51;
   wire        s_logisimNet52;
   wire        s_logisimNet53;
   wire        s_logisimNet55;
   wire        s_logisimNet56;
   wire        s_logisimNet57;
   wire        s_logisimNet58;
   wire        s_logisimNet59;
   wire        s_logisimNet6;
   wire        s_logisimNet60;
   wire        s_logisimNet61;
   wire        s_logisimNet64;
   wire        s_logisimNet65;
   wire        s_logisimNet69;
   wire        s_logisimNet7;
   wire        s_logisimNet70;
   wire        s_logisimNet71;
   wire        s_logisimNet72;
   wire        s_logisimNet74;
   wire        s_logisimNet76;
   wire        s_logisimNet77;
   wire        s_logisimNet78;
   wire        s_logisimNet79;
   wire        s_logisimNet8;
   wire        s_logisimNet80;
   wire        s_logisimNet82;
   wire        s_logisimNet84;
   wire        s_logisimNet85;
   wire        s_logisimNet86;
   wire        s_logisimNet87;
   wire        s_logisimNet88;
   wire        s_logisimNet89;
   wire        s_logisimNet9;
   wire        s_logisimNet91;
   wire        s_logisimNet92;
   wire        s_logisimNet93;
   wire        s_logisimNet94;
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
   assign s_logisimBus115[0] = s_logisimNet87;
   assign s_logisimBus115[1] = s_logisimNet202;
   assign s_logisimBus115[2] = s_logisimNet35;
   assign s_logisimBus115[3] = s_logisimNet116;
   assign s_logisimBus133[0] = s_logisimNet257;
   assign s_logisimBus133[1] = s_logisimNet256;
   assign s_logisimBus133[2] = s_logisimNet255;
   assign s_logisimBus133[3] = s_logisimNet254;
   assign s_logisimBus133[4] = s_logisimNet253;
   assign s_logisimBus139[0] = s_logisimNet85;
   assign s_logisimBus139[1] = s_logisimNet201;
   assign s_logisimBus146[0] = s_logisimNet34;
   assign s_logisimBus146[1] = s_logisimNet114;
   assign s_logisimBus185[0] = s_logisimNet52;
   assign s_logisimBus185[1] = s_logisimNet144;
   assign s_logisimBus185[2] = s_logisimNet9;
   assign s_logisimBus185[3] = s_logisimNet79;
   assign s_logisimBus185[4] = s_logisimNet186;
   assign s_logisimBus185[5] = s_logisimNet30;
   assign s_logisimBus185[6] = s_logisimNet102;
   assign s_logisimBus185[7] = s_logisimNet237;
   assign s_logisimBus185[8] = s_logisimNet51;
   assign s_logisimBus223[0] = s_logisimNet89;
   assign s_logisimBus223[1] = s_logisimNet65;
   assign s_logisimBus23[0]  = s_logisimNet8;
   assign s_logisimBus23[1]  = s_logisimNet78;
   assign s_logisimBus23[2]  = s_logisimNet188;
   assign s_logisimBus23[3]  = s_logisimNet31;
   assign s_logisimBus50[0]  = s_logisimNet157;
   assign s_logisimBus50[1]  = s_logisimNet15;
   assign s_logisimBus62[0]  = s_logisimNet212;
   assign s_logisimBus62[1]  = s_logisimNet42;
   assign s_logisimBus63[0]  = s_logisimNet2;
   assign s_logisimBus63[1]  = s_logisimNet71;
   assign s_logisimBus68[0]  = s_logisimNet1;
   assign s_logisimBus68[1]  = s_logisimNet124;
   assign s_logisimBus81[0]  = s_logisimNet273;
   assign s_logisimBus81[10] = s_logisimNet263;
   assign s_logisimBus81[11] = s_logisimNet262;
   assign s_logisimBus81[12] = s_logisimNet261;
   assign s_logisimBus81[13] = s_logisimNet260;
   assign s_logisimBus81[14] = s_logisimNet259;
   assign s_logisimBus81[15] = s_logisimNet258;
   assign s_logisimBus81[1]  = s_logisimNet272;
   assign s_logisimBus81[2]  = s_logisimNet271;
   assign s_logisimBus81[3]  = s_logisimNet270;
   assign s_logisimBus81[4]  = s_logisimNet269;
   assign s_logisimBus81[5]  = s_logisimNet268;
   assign s_logisimBus81[6]  = s_logisimNet267;
   assign s_logisimBus81[7]  = s_logisimNet266;
   assign s_logisimBus81[8]  = s_logisimNet265;
   assign s_logisimBus81[9]  = s_logisimNet264;
   assign s_logisimBus95[0]  = s_logisimNet161;
   assign s_logisimBus95[1]  = s_logisimNet18;
   assign s_logisimBus95[2]  = s_logisimNet92;
   assign s_logisimBus95[3]  = s_logisimNet208;
   assign s_logisimBus95[4]  = s_logisimNet41;
   assign s_logisimNet1      = s_logisimBus247[44];
   assign s_logisimNet102    = s_logisimBus247[61];
   assign s_logisimNet114    = s_logisimBus247[43];
   assign s_logisimNet116    = s_logisimBus247[19];
   assign s_logisimNet124    = s_logisimBus247[45];
   assign s_logisimNet144    = s_logisimBus247[56];
   assign s_logisimNet15     = s_logisimBus247[52];
   assign s_logisimNet157    = s_logisimBus247[51];
   assign s_logisimNet161    = s_logisimBus247[37];
   assign s_logisimNet18     = s_logisimBus247[38];
   assign s_logisimNet186    = s_logisimBus247[59];
   assign s_logisimNet188    = s_logisimBus247[30];
   assign s_logisimNet2      = s_logisimBus247[48];
   assign s_logisimNet201    = s_logisimBus247[47];
   assign s_logisimNet202    = s_logisimBus247[17];
   assign s_logisimNet208    = s_logisimBus247[40];
   assign s_logisimNet212    = s_logisimBus247[53];
   assign s_logisimNet237    = s_logisimBus247[62];
   assign s_logisimNet253    = s_logisimBus247[36];
   assign s_logisimNet254    = s_logisimBus247[35];
   assign s_logisimNet255    = s_logisimBus247[34];
   assign s_logisimNet256    = s_logisimBus247[33];
   assign s_logisimNet257    = s_logisimBus247[32];
   assign s_logisimNet258    = s_logisimBus247[15];
   assign s_logisimNet259    = s_logisimBus247[14];
   assign s_logisimNet260    = s_logisimBus247[13];
   assign s_logisimNet261    = s_logisimBus247[12];
   assign s_logisimNet262    = s_logisimBus247[11];
   assign s_logisimNet263    = s_logisimBus247[10];
   assign s_logisimNet264    = s_logisimBus247[9];
   assign s_logisimNet265    = s_logisimBus247[8];
   assign s_logisimNet266    = s_logisimBus247[7];
   assign s_logisimNet267    = s_logisimBus247[6];
   assign s_logisimNet268    = s_logisimBus247[5];
   assign s_logisimNet269    = s_logisimBus247[4];
   assign s_logisimNet270    = s_logisimBus247[3];
   assign s_logisimNet271    = s_logisimBus247[2];
   assign s_logisimNet272    = s_logisimBus247[1];
   assign s_logisimNet273    = s_logisimBus247[0];
   assign s_logisimNet30     = s_logisimBus247[60];
   assign s_logisimNet31     = s_logisimBus247[31];
   assign s_logisimNet34     = s_logisimBus247[42];
   assign s_logisimNet35     = s_logisimBus247[18];
   assign s_logisimNet41     = s_logisimBus247[41];
   assign s_logisimNet42     = s_logisimBus247[54];
   assign s_logisimNet51     = s_logisimBus247[63];
   assign s_logisimNet52     = s_logisimBus247[55];
   assign s_logisimNet65     = s_logisimBus247[27];
   assign s_logisimNet71     = s_logisimBus247[49];
   assign s_logisimNet78     = s_logisimBus247[29];
   assign s_logisimNet79     = s_logisimBus247[58];
   assign s_logisimNet8      = s_logisimBus247[28];
   assign s_logisimNet85     = s_logisimBus247[46];
   assign s_logisimNet87     = s_logisimBus247[16];
   assign s_logisimNet89     = s_logisimBus247[26];
   assign s_logisimNet9      = s_logisimBus247[57];
   assign s_logisimNet92     = s_logisimBus247[39];

   /*******************************************************************************
   ** Here all input connections are defined                                     **
   *******************************************************************************/
   
   assign s_oc_1_0          = OC_1_0;
   assign s_logisimNet0     = BINT13_n;
   assign s_logisimNet101   = BINT12_n;
   assign s_logisimNet126   = SWMCL_n;
   assign s_logisimNet137   = CONSOLE_n;
   assign s_logisimNet145   = BINT10_n;
   assign s_logisimNet167   = XTR;
   assign s_logisimNet180   = LOCK_n;
   assign s_logisimNet20    = BINT11_n;
   assign s_logisimNet217   = CONTINUE_n;
   assign s_logisimNet224   = CLOCK_1;
   assign s_logisimNet231   = EAUTO_n;
   assign s_logisimNet233   = OSCCL_n;
   assign s_logisimNet25    = CLOCK_2;
   assign s_logisimNet43    = BREQ_n;
   assign s_logisimNet48    = SW1_CONSOLE;
   assign s_logisimNet5     = BINT15_n;
   assign s_logisimNet59    = STOP_n;
   assign s_logisimNet64    = RXD;
   assign s_logisimNet88    = LOAD_n;

   /*******************************************************************************
   ** Here all output connections are defined                                    **
   *******************************************************************************/
   assign CSBITS      = s_logisimBus247[63:0];
   assign DP_5_1_n    = s_logisimBus83[4:0];
   assign RUN_n       = s_logisimNet177;
   assign TEST_4_0    = s_logisimBus127[4:0];
   assign TP1_INTRQ_n = s_logisimNet57;
   assign TXD         = s_logisimNet104;

   /*******************************************************************************
   ** Here all in-lined components are defined                                   **
   *******************************************************************************/

      
   // Buffer
   assign s_logisimNet177 = s_logisimNet169;

   // NOT Gate
   assign s_logisimNet60 = 0'b1;

   // NOT Gate
   assign s_logisimNet98 = 0'b1;

   // NOT Gate
   assign s_logisimNet252 = 0'b1;

   // NOT Gate
   assign s_logisimNet216 = 0'b1;

   /*******************************************************************************
   ** Here all sub-circuits are defined                                          **
   *******************************************************************************/

   CYC_36   CYC (
                 .sysclk(sysclk), // System clock in FPGA
                 .sys_rst_n(sys_rst_n), // System reset in FPGA
                 .ACOND_n(s_logisimNet12),
                 .ALUCLK(s_logisimNet243),
                 .BRK_n(s_logisimNet164),
                 .CC_3_1_n(s_logisimBus4[2:0]),
                 .CGNTCACT_n(s_logisimNet108),
                 .CLK(s_logisimNet218),
                 .CSALUI7(s_logisimBus185[7]),
                 .CSALUI8(s_logisimBus185[8]),
                 .CSALUM0(s_logisimBus68[0]),
                 .CSALUM1(s_logisimBus68[1]),
                 .CSDELAY0(s_logisimNet89),
                 .CSDELAY1(s_logisimNet65),
                 .CSDLY(s_logisimBus247[21]),
                 .CSECOND(s_logisimBus247[23]),
                 .CSLOOP(s_logisimBus247[22]),
                 .CX_n(s_logisimNet128),
                 .CYD(s_logisimNet27),
                 .EORF_n(s_logisimNet179),
                 .ETRAP_n(s_logisimNet236),
                 .FORM_n(s_logisimNet58),
                 .HIT(s_logisimNet227),
                 .IORQ_n(s_logisimNet240),
                 .LBA0(s_logisimBus75[0]),
                 .LBA1(s_logisimBus75[1]),
                 .LBA3(s_logisimBus75[3]),
                 .LCS_n(s_logisimNet123),
                 .LSHADOW(s_logisimNet125),
                 .LUA12(s_logisimNet100),
                 .MACLK(s_logisimNet129),
                 .MAP_n(s_logisimNet69),
                 .MCLK(s_logisimNet178),
                 .MREQ_n(s_logisimNet194),
                 .MR_n(s_logisimNet130),
                 .OSC(s_logisimNet168),
                 .PD1(s_logisimNet60),
                 .PD4(s_logisimNet216),
                 .RRF_n(s_logisimNet187),
                 .RT_n(s_logisimNet172),
                 .RWCS_n(s_logisimNet142),
                 .SHORT_n(s_logisimNet106),
                 .SLOW_n(s_logisimNet121),
                 .TERM_n(s_logisimNet84),
                 .TRAP_n(s_logisimNet107),
                 .UCLK(s_logisimNet219),
                 .VEX(s_logisimNet138),
                 .WRFSTB(s_logisimNet143));

   CPU_15   CPU (
                 .sysclk(sysclk), // System clock in FPGA
                 .sys_rst_n(sys_rst_n), // System reset in FPGA
                 .ALUCLK(s_logisimNet243),
                 .CA10(s_logisimNet203),
                 .CA_9_0(s_logisimBus118[9:0]),
                 .CCLR_n(s_logisimNet235),
                 .CC_3_1_n(s_logisimBus4[2:0]),
                 .CD_15_0_IN(s_logisimBus38[15:0]),
                 .CD_15_0_OUT(s_cd_15_0_cpu_out),
                 .CLK(s_logisimNet218),
                 .CYD(s_logisimNet27),
                 .DT_n(s_logisimNet230),
                 .DVACC_n(s_logisimNet97),
                 .ECSR_n(s_logisimNet244),
                 .EDO_n(s_logisimNet190),
                 .EMCL_n(s_logisimNet103),
                 .EMPID_n(s_logisimNet204),
                 .EORF_n(s_logisimNet179),
                 .ESTOF_n(s_logisimNet189),
                 .ETRAP_n(s_logisimNet236),
                 .FETCH(s_logisimNet152),
                 .FMISS(s_logisimNet61),
                 .FORM_n(s_logisimNet58),
                 .IBINT10_n(s_logisimNet111),
                 .IBINT11_n(s_logisimNet155),
                 .IBINT12_n(s_logisimNet136),
                 .IBINT13_n(s_logisimNet86),
                 .IBINT15_n(s_logisimNet74),
                 .IDB_15_0_IN(s_IDB_15_0_in[15:0]),
                 .IDB_15_0_OUT(s_idb_15_0_cpu_out),
                 .IOXERR_n(s_logisimNet176),
                 .LBA_3_0(s_logisimBus75[3:0]),
                 .LCS_n(s_logisimNet123),
                 .LSHADOW(s_logisimNet125),
                 .LUA_12_0(s_logisimBus14[12:0]),
                 .MACLK(s_logisimNet129),
                 .MAP_n(s_logisimNet69),
                 .MCLK(s_logisimNet178),
                 .MOR_n(s_logisimNet109),
                 .MR_n(s_logisimNet130),
                 .OPCLCS(s_logisimNet165),
                 .PAN_n(s_logisimNet119),
                 .PARERR_n(s_logisimNet249),
                 .PCR_1_0(s_logisimBus209[1:0]),
                 .PD1(s_logisimNet60),
                 .PD2(s_logisimNet98),
                 .PIL_3_0(s_logisimBus246[3:0]),
                 .PONI(s_logisimNet17),
                 .POWFAIL_n(s_logisimNet191),
                 .PPN_23_10(s_logisimBus67[13:0]),
                 .RT_n(s_logisimNet172),
                 .RWCS_n(s_logisimNet142),
                 .STOC_n(s_logisimNet205),
                 .STP(s_logisimNet169),
                 .SW1_CONSOLE(s_logisimNet48),
                 .TERM_n(s_logisimNet84),
                 .TEST_4_0(s_logisimBus127[4:0]),
                 .TOPCSB(s_logisimBus247[63:0]),
                 .TP1_INTRQ_n(s_logisimNet57),
                 .TRAP(s_logisimNet36),
                 .UCLK(s_logisimNet219),
                 .VEX(s_logisimNet138),
                 .WCHIM_n(s_logisimNet53),
                 .WRFSTB(s_logisimNet143),
                 .WRITE(s_logisimNet242),
                 .LDEXM_n(s_LDEXM_n)
                 );


   
   // Input signals on C-PLUG goes via 5C


   wire s_BPERR_n;  
   assign s_BPERR_n = 1'b1;



   TTL_74244   CHIP_5C (
               // Input 

               //   1A4 = BPERR_n    1A3 = BINPUT_n   1A2= SEMRQ_n    1A1 = BINT10_n
                .A1({s_BPERR_n, s_logisimNet163,s_logisimNet37, s_logisimNet145}), // Mapping 4 separate signals to 1A4-1A1
                .G1_n(s_logisimNet60),

                // 2A4 = BAPR_n       2A3= BDRY_n     2A2 = BDAP_n     2A1= n.c.
                .A2({s_logisimNet132, s_logisimNet33, s_logisimNet251, 1'b0}),   // Mapping 4 separate signals to 2A4-2A1
                .G2_n(s_logisimNet60),


               // Output
               .Y1({s_logisimNet181, s_logisimNet199, s_logisimNet232, s_logisimNet111}), // Mapping 4 separate signals to 1Y4-1Y1
               .Y2({s_logisimNet153, s_logisimNet56, s_logisimNet113, 1'bz}) // Mapping 4 separate signals to 1Y4-1Y1
   );

   IO_37   IO (
               .sysclk(sysclk), // System clock in FPGA
               .sys_rst_n(sys_rst_n), // System reset in FPGA
               
               .BDRY50_n(s_logisimNet250),
               .BINT10_n(s_logisimNet206),
               .BINT12_n(s_logisimNet193),
               .BINT13_n(s_logisimNet122),
               .BRK_n(s_logisimNet164),
               .CA10(s_logisimNet203),
               .CCLR_n(s_logisimNet235),
               .CLEAR_n(s_logisimNet183),
               .CLK(s_logisimNet218),
               .CONSOLE_n(s_logisimNet11),
               .CSCOMM_4_0(s_logisimBus133[4:0]),
               .CSIDBS_4_0(s_logisimBus95[4:0]),
               .CSMIS_1_0(s_logisimBus146[1:0]),
               .CX_n(s_logisimNet128),
               .DAP_n(s_logisimNet159),
               .DP_5_1_n(s_logisimBus83[4:0]),
               .DT_n(s_logisimNet230),
               .DVACC_n(s_logisimNet97),
               .EAUTO_n(s_logisimNet231),
               .ECREQ(s_logisimNet175),
               .ECSR_n(s_logisimNet244),
               .EDO_n(s_logisimNet190),
               .EMCL_n(s_logisimNet103),
               .EMPID_n(s_logisimNet204),
               .EORF_n(s_logisimNet179),
               .ESTOF_n(s_logisimNet189),
               .FETCH(s_logisimNet152),
               .FMISS(s_logisimNet61),
               .FORM_n(s_logisimNet58),
               .HIT(s_logisimNet227),
               .I1P(s_logisimNet166),
               .ICONTIN_n(s_logisimNet211),
               .IDB_15_8(s_logisimBus54[7:0]),
               .IDB_7_0_io(s_logisimBus170[7:0]),
               .ILOAD_n(s_logisimNet228),
               .INR_7_0(s_logisimBus210[7:0]),
               .IONI(s_logisimNet44),
               .IORQ_n(s_logisimNet105),
               .ISTOP_n(s_logisimNet19),
               .LCS_n(s_logisimNet123),
               .LEV0(s_logisimNet93),
               .LOCK_n(s_logisimNet180),
               .LSHADOW(s_logisimNet125),
               .MCL(s_logisimNet120),
               .MREQ_n(s_logisimNet194),
               .OC_1_0(s_oc_1_0[1:0]),
               .OPCLCS(s_logisimNet165),
               .OSC(s_logisimNet168),
               .OSCCL_n(s_logisimNet233),
               .PAN_n(s_logisimNet119),
               .PA_n(s_logisimNet226),
               .PCR_1_0(s_logisimBus209[1:0]),
               .PONI(s_logisimNet17),
               .POWFAIL_n(s_logisimNet191),
               .POWSENSE_n(s_logisimNet45),
               .PS_n(s_logisimNet156),
               .REFRQ_n(s_logisimNet16),
               .REF_n(s_logisimNet220),
               .RT_n(s_logisimNet172),
               .RWCS_n(s_logisimNet142),
               .RXD(s_logisimNet64),
               .SEL5MS_n(s_logisimNet94),
               .SHORT_n(s_logisimNet106),
               .SLOW_n(s_logisimNet121),
               .SSEMA_n(s_logisimNet192),
               .STOC_n(s_logisimNet205),
               .STP(s_logisimNet169),
               .SWMCL_n(s_logisimNet126),
               .TOUT(s_logisimNet195),
               .TXD(s_logisimNet104),
               .UCLK(s_logisimNet219),
               .WCHIM_n(s_logisimNet53),
               .WRITE(s_logisimNet242),
               .XTAL1(s_logisimNet224),
               .XTAL2(s_logisimNet25),
               .XTR(s_logisimNet167),
               .IOLED(LED[1:0])
               );

      // C-PLUG SIGNALS goes via 5C and 33C
      TTL_74244   CHIP_33C (
               // Input

                //   1A4=STOP_n      1A3=CONTINUE_n   1A2=BREQ_n      1A1=LOAD_n
                .A1({s_logisimNet59, s_logisimNet217,s_logisimNet43, s_logisimNet88}), // Mapping 4 separate signals to 1A4-1A1
                .G1_n(s_logisimNet60),
                //   2A4=BINT11_n    2A3=BINT12_n    2A2=BINT13_n    2A1=BINT15_n
                .A2({s_logisimNet20, s_logisimNet101, s_logisimNet0, s_logisimNet5}),   // Mapping 4 separate signals to 2A4-2A1
                .G2_n(s_logisimNet60),


               // Output
               .Y1({s_logisimNet19, s_logisimNet211, s_logisimNet207, s_logisimNet228}), // Mapping 4 separate signals to 1Y4-1Y1
               .Y2({s_logisimNet155, s_logisimNet136, s_logisimNet86, s_logisimNet74}) // Mapping 4 separate signals to 1Y4-1Y1
      );


/* TODO:

   MEM_43   MEM (
                 .sysclk(sysclk),          // System clock in FPGA
                 .sys_rst_n(sys_rst_n),    // System reset in FPGA

                 .BDAP50_n(s_logisimNet162),
                 .BDRY50_n(s_logisimNet250),
                 .BDRY_n(s_logisimNet33),
                 .BD_23_19_n(s_logisimBus174[4:0]),
                 .BGNT50_n(s_logisimNet239),
                 .BGNT_n(s_logisimNet200),
                 .BIOXE_n(s_logisimNet158),
                 .BMEM_n(s_logisimNet91),
                 .CGNT50_n(s_logisimNet55),
                 .CGNT_n(s_logisimNet148),
                 .CRQ_n(s_logisimNet150),
                 .DBAPR(s_logisimNet238),
                 .ECCR(s_logisimNet245),
                 .ECREQ(s_logisimNet175),
                 .FETCH(s_logisimNet152),
                 .GNT50_n(s_logisimNet154),
                 .GNT_n(s_logisimNet221),
                 .IBINPUT_n(s_logisimNet163),
                 .IDB_15_0_IN(s_logisimBus32[15:0]),
                 .IDB_15_0_OUT(xxx),
                 .IORQ_n(s_logisimNet240),
                 .LBD_15_0_io(s_logisimBus173[15:0]),
                 .LBD_23_16(s_logisimBus21[7:0]),
                 .LERR_n(s_logisimNet197),
                 .LPERR_n(s_logisimNet149),
                 .MOFF_n(s_logisimNet112),
                 .MOR25_n(s_logisimNet110),
                 .MOR_n(s_logisimNet109),
                 .MR_n(s_logisimNet130),
                 .MWRITE_n(s_logisimNet196),
                 .OSC(s_logisimNet168),
                 .PA_n(s_logisimNet226),
                 .PD1(s_logisimNet60),
                 .PD3(s_logisimNet252),
                 .PD4(s_logisimNet216),
                 .PPN_23_19(s_logisimBus66[4:0]),
                 .PS_n(s_logisimNet156),
                 .REFRQ_n(s_logisimNet213),
                 .REF_n(s_logisimNet220),
                 .RERR_n(s_logisimNet147),
                 .SEMRQ50_n(s_logisimNet135),
                 .SSEMA_n(s_logisimNet192),
                 .WRITE(s_logisimNet242),                 
                 .LED4(LED[2]),       // LED4_RED_PARITY_ERROR
                 .LED_CPU_GI(LED[3]), // LED_CPU_GRANT_INDICATOR
                 .LED_BUS_GI(LED[4])  // LED_BUS_GRANT_INDICATOR                 
                 );



   BIF_5   BIF(
                .sysclk(sysclk), // System clock in FPGA
                .sys_rst_n(sys_rst_n), // System reset in FPGA

                .BAPR_n(s_logisimNet132),
                .BDAP50_n(s_logisimNet162),
                .BDAP_n(s_logisimNet251),
                .BDRY50_n(s_logisimNet250),
                .BDRY_n(s_logisimNet222),
                .BD_23_0_n_io(s_logisimBus73[23:0]),
                .BERROR_n(s_logisimNet40),
                .BGNT50_n(s_logisimNet239),
                .BGNT_n(s_logisimNet200),
                .BINACK_n(s_logisimNet70),
                .BINPUT_n(s_logisimNet163),
                .BIOXE_n(s_logisimNet158),
                .BMEM_n(s_logisimNet91),
                .BREF_n(s_logisimNet131),
                .CA_9_0(s_logisimBus118[9:0]),
                .CC2_n(s_logisimNet82),
                .CD_15_0_IN(s_logisimBus90[15:0]),
                .CD_15_0_OUT(xxxx),
                .CGNCACT_n(s_logisimNet248),
                .CGNT50_n(s_logisimNet55),
                .CGNT_n(s_logisimNet148),
                .CLEAR_n(s_logisimNet183),
                .CRQ_n(s_logisimNet150),
                .DAP_n(s_logisimNet159),
                .DBAPR(s_logisimNet238),
                .EBUS_n(s_logisimNet13),
                .ECRQ(s_logisimNet22),
                .FETCH(s_logisimNet152),
                .GNT50_n(s_logisimNet154),
                .GNT_n(s_logisimNet221),
                .IBAPR_n(s_logisimNet153),
                .IBDAP_n(s_logisimNet113),
                .IBDRY_n(s_logisimNet56),
                .IBINPUT_n(s_logisimNet199),
                .IBPERR_n(s_logisimNet181),
                .IBREQ_n(s_logisimNet207),
                .IDB_15_0_IN(s_logisimBus160[15:0]),
                .IDB_15_0_OUT(xxx),
                .IORQ_n(s_logisimNet240),
                .IOXERR_n(s_logisimNet176),
                .ISEMRQ_n(s_logisimNet232),
                .LBD_23_0_io(s_logisimBus28[23:0]),
                .LERR_n(s_logisimNet197),
                .LPRERR_n(s_logisimNet29),
                .MIS0(s_logisimNet215),
                .MOFF_n(s_logisimNet112),
                .MOR25_n(s_logisimNet110),
                .MOR_n(s_logisimNet109),
                .MR_n(s_logisimNet130),
                .MWRITE_n(s_logisimNet196),
                .OSC(s_logisimNet168),
                .OUTGRANT_n(s_logisimNet39),
                .OUTIDENT_n(s_logisimNet24),
                .PARERR_n(s_logisimNet249),
                .PA_n(s_logisimNet226),
                .PD1(s_logisimNet60),
                .PD3(s_logisimNet252),
                .PPN_23_10(s_logisimBus67[13:0]),
                .PS_n(s_logisimNet156),
                .REFRQ_n(s_logisimNet213),
                .REF_n(s_logisimNet220),
                .RERR_n(s_logisimNet147),
                .RT_n(s_logisimNet172),
                .SEMRQ50_n(s_logisimNet135),
                .SEMRQ_n(s_logisimNet37),
                .SSEMA_n(s_logisimNet192),
                .TERM_n(s_logisimNet84),
                .TOUT(s_logisimNet195),
                .WRITE(s_logisimNet242));

*/

endmodule

/******************************************************************************
 ** Logisim-evolution goes FPGA automatic generated Verilog code             **
 ** https://github.com/logisim-evolution/                                    **
 **                                                                          **
 ** Component : CGA                                                          **
 **                                                                          **
 *****************************************************************************/

module CGA( BDEST,
            XACONDN,
            XALUCLK,
            XBINT10N,
            XBINT11N,
            XBINT12N,
            XBINT13N,
            XBINT15N,
            XBRKN,
            XCD_15_0,
            XCSALUI_8_0,
            XCSALUM_1_0,
            XCSBIT20,
            XCSBIT_15_0,
            XCSCINSEL_1_0,
            XCSCOMM_4_0,
            XCSECOND,
            XCSIDBS_4_0,
            XCSLOOP,
            XCSMIS_1_0,
            XCSRASEL_1_0,
            XCSRBSEL_1_0,
            XCSRB_3_0,
            XCSSCOND,
            XCSSST_1_0,
            XCSTS_6_3,
            XCSVECT,
            XCSXRF3,
            XDOUBLE,
            XECCR,
            XEDON,
            XEMPIDN,
            XERFN,
            XETRAPN,
            XEWCAN,
            XFIDB_15_0_IN,
            XFIDB_15_0_OUT,
            XFTRAPN,
            XILCSN,
            XINTRQN,
            XIONI,
            XIOXERRN,
            XLAA_3_0,
            XLA_23_10,
            XLBA_3_0,
            XLSHADOW,
            XMAPN,
            XMA_12_0,
            XMCA_9_0,
            XMCLK,
            XMORN,
            XMRN,
            XPANN,
            XPARERRN,
            XPCR_1_0,
            XPIL_3_0,
            XPONI,
            XPOWFAILN,
            XPTSTN,
            XPT_9_15,
            XRF_1_0,
            XSPARE,
            XSTP,
            XTCLK,
            XTEST_4_0,
            XTRAPN,
            XTSEL_2_0,
            XVTRAPN,
            XWCSN,
            XWRTRF );

   /*******************************************************************************
   ** The inputs are defined here                                                **
   *******************************************************************************/
   input        BDEST;
   input        XALUCLK;
   input        XBINT10N;
   input        XBINT11N;
   input        XBINT12N;
   input        XBINT13N;
   input        XBINT15N;
   input [15:0] XCD_15_0;
   input [8:0]  XCSALUI_8_0;
   input [1:0]  XCSALUM_1_0;
   input        XCSBIT20;
   input [15:0] XCSBIT_15_0;
   input [1:0]  XCSCINSEL_1_0;
   input [4:0]  XCSCOMM_4_0;
   input        XCSECOND;
   input [4:0]  XCSIDBS_4_0;
   input        XCSLOOP;
   input [1:0]  XCSMIS_1_0;
   input [1:0]  XCSRASEL_1_0;
   input [1:0]  XCSRBSEL_1_0;
   input [3:0]  XCSRB_3_0;
   input        XCSSCOND;
   input [1:0]  XCSSST_1_0;
   input [3:0]  XCSTS_6_3;
   input        XCSVECT;
   input        XCSXRF3;
   input        XEDON;
   input        XEMPIDN;
   input        XETRAPN;
   input        XEWCAN;
   input [15:0] XFIDB_15_0_IN;
   input        XFTRAPN;
   input        XILCSN;
   input        XIOXERRN;
   input        XMAPN;
   input        XMCLK;
   input        XMORN;
   input        XMRN;
   input        XPANN;
   input        XPARERRN;
   input        XPOWFAILN;
   input        XPTSTN;
   input [6:0]  XPT_9_15;
   input        XSPARE;
   input        XSTP;
   input        XTCLK;
   input [2:0]  XTSEL_2_0;
   input        XVTRAPN;

   /*******************************************************************************
   ** The outputs are defined here                                               **
   *******************************************************************************/
   output        XACONDN;
   output        XBRKN;
   output        XDOUBLE;
   output        XECCR;
   output        XERFN;
   output [15:0] XFIDB_15_0_OUT;
   output        XINTRQN;
   output        XIONI;
   output [3:0]  XLAA_3_0;
   output [13:0] XLA_23_10;
   output [3:0]  XLBA_3_0;
   output        XLSHADOW;
   output [12:0] XMA_12_0;
   output [9:0]  XMCA_9_0;
   output [1:0]  XPCR_1_0;
   output [3:0]  XPIL_3_0;
   output        XPONI;
   output [1:0]  XRF_1_0;
   output [4:0]  XTEST_4_0;
   output        XTRAPN;
   output        XWCSN;
   output        XWRTRF;

   /*******************************************************************************
   ** The wires are defined here                                                 **
   *******************************************************************************/
   wire [1:0]  s_logisimBus102;
   wire [6:0]  s_logisimBus103;
   wire [1:0]  s_logisimBus104;
   wire [15:0] s_logisimBus115;
   wire [6:0]  s_logisimBus121;
   wire [1:0]  s_logisimBus128;
   wire [15:0] s_logisimBus130;
   wire [3:0]  s_logisimBus132;
   wire [15:0] s_logisimBus135;
   wire [3:0]  s_logisimBus137;
   wire [3:0]  s_logisimBus139;
   wire [15:0] s_logisimBus143;
   wire [2:0]  s_logisimBus146;
   wire [8:0]  s_logisimBus148;
   wire [15:0] s_logisimBus15;
   wire [3:0]  s_logisimBus153;
   wire [3:0]  s_logisimBus156;
   wire [15:0] s_logisimBus16;
   wire [15:0] s_logisimBus163;
   wire [15:0] s_logisimBus165;
   wire [1:0]  s_logisimBus168;
   wire [15:0] s_logisimBus169;
   wire [6:0]  s_logisimBus17;
   wire [15:0] s_logisimBus171;
   wire [1:0]  s_logisimBus173;
   wire [15:0] s_logisimBus180;
   wire [1:0]  s_logisimBus185;
   wire [4:0]  s_logisimBus190;
   wire [4:0]  s_logisimBus191;
   wire [3:0]  s_logisimBus194;
   wire [15:0] s_logisimBus195;
   wire [15:0] s_logisimBus197;
   wire [2:0]  s_logisimBus201;
   wire [3:0]  s_logisimBus204;
   wire [1:0]  s_logisimBus210;
   wire [1:0]  s_logisimBus212;
   wire [4:0]  s_logisimBus215;
   wire [15:0] s_logisimBus216;
   wire [9:0]  s_logisimBus218;
   wire [4:0]  s_logisimBus224;
   wire [13:0] s_logisimBus225;
   wire [12:0] s_logisimBus230;
   wire [1:0]  s_logisimBus231;
   wire [1:0]  s_logisimBus232;
   wire [11:0] s_logisimBus234;
   wire [3:0]  s_logisimBus236;
   wire [4:0]  s_logisimBus237;
   wire [1:0]  s_logisimBus238;
   wire [1:0]  s_logisimBus26;
   wire [3:0]  s_logisimBus32;
   wire [8:0]  s_logisimBus37;
   wire [1:0]  s_logisimBus49;
   wire [3:0]  s_logisimBus53;
   wire [15:0] s_logisimBus55;
   wire [1:0]  s_logisimBus60;
   wire [15:0] s_logisimBus65;
   wire [15:0] s_logisimBus67;
   wire [2:0]  s_logisimBus70;
   wire [15:0] s_logisimBus86;
   wire [15:0] s_logisimBus9;
   wire [2:0]  s_logisimBus91;
   wire [4:0]  s_logisimBus96;
   wire        s_logisimNet0;
   wire        s_logisimNet1;
   wire        s_logisimNet10;
   wire        s_logisimNet100;
   wire        s_logisimNet101;
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
   wire        s_logisimNet129;
   wire        s_logisimNet13;
   wire        s_logisimNet131;
   wire        s_logisimNet133;
   wire        s_logisimNet134;
   wire        s_logisimNet136;
   wire        s_logisimNet138;
   wire        s_logisimNet14;
   wire        s_logisimNet140;
   wire        s_logisimNet141;
   wire        s_logisimNet142;
   wire        s_logisimNet144;
   wire        s_logisimNet145;
   wire        s_logisimNet147;
   wire        s_logisimNet149;
   wire        s_logisimNet150;
   wire        s_logisimNet151;
   wire        s_logisimNet152;
   wire        s_logisimNet154;
   wire        s_logisimNet155;
   wire        s_logisimNet157;
   wire        s_logisimNet158;
   wire        s_logisimNet159;
   wire        s_logisimNet160;
   wire        s_logisimNet161;
   wire        s_logisimNet162;
   wire        s_logisimNet164;
   wire        s_logisimNet166;
   wire        s_logisimNet167;
   wire        s_logisimNet170;
   wire        s_logisimNet172;
   wire        s_logisimNet174;
   wire        s_logisimNet175;
   wire        s_logisimNet176;
   wire        s_logisimNet177;
   wire        s_logisimNet178;
   wire        s_logisimNet179;
   wire        s_logisimNet18;
   wire        s_logisimNet181;
   wire        s_logisimNet182;
   wire        s_logisimNet183;
   wire        s_logisimNet184;
   wire        s_logisimNet186;
   wire        s_logisimNet187;
   wire        s_logisimNet188;
   wire        s_logisimNet189;
   wire        s_logisimNet19;
   wire        s_logisimNet192;
   wire        s_logisimNet193;
   wire        s_logisimNet196;
   wire        s_logisimNet198;
   wire        s_logisimNet199;
   wire        s_logisimNet2;
   wire        s_logisimNet20;
   wire        s_logisimNet200;
   wire        s_logisimNet202;
   wire        s_logisimNet203;
   wire        s_logisimNet205;
   wire        s_logisimNet206;
   wire        s_logisimNet207;
   wire        s_logisimNet208;
   wire        s_logisimNet209;
   wire        s_logisimNet21;
   wire        s_logisimNet211;
   wire        s_logisimNet213;
   wire        s_logisimNet214;
   wire        s_logisimNet217;
   wire        s_logisimNet219;
   wire        s_logisimNet22;
   wire        s_logisimNet220;
   wire        s_logisimNet221;
   wire        s_logisimNet222;
   wire        s_logisimNet223;
   wire        s_logisimNet226;
   wire        s_logisimNet227;
   wire        s_logisimNet228;
   wire        s_logisimNet229;
   wire        s_logisimNet23;
   wire        s_logisimNet233;
   wire        s_logisimNet235;
   wire        s_logisimNet239;
   wire        s_logisimNet24;
   wire        s_logisimNet25;
   wire        s_logisimNet27;
   wire        s_logisimNet28;
   wire        s_logisimNet29;
   wire        s_logisimNet3;
   wire        s_logisimNet30;
   wire        s_logisimNet31;
   wire        s_logisimNet33;
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
   wire        s_logisimNet5;
   wire        s_logisimNet50;
   wire        s_logisimNet51;
   wire        s_logisimNet52;
   wire        s_logisimNet54;
   wire        s_logisimNet56;
   wire        s_logisimNet57;
   wire        s_logisimNet58;
   wire        s_logisimNet59;
   wire        s_logisimNet6;
   wire        s_logisimNet61;
   wire        s_logisimNet62;
   wire        s_logisimNet63;
   wire        s_logisimNet64;
   wire        s_logisimNet66;
   wire        s_logisimNet68;
   wire        s_logisimNet69;
   wire        s_logisimNet7;
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
   wire        s_logisimNet81;
   wire        s_logisimNet82;
   wire        s_logisimNet83;
   wire        s_logisimNet84;
   wire        s_logisimNet85;
   wire        s_logisimNet87;
   wire        s_logisimNet88;
   wire        s_logisimNet89;
   wire        s_logisimNet90;
   wire        s_logisimNet92;
   wire        s_logisimNet93;
   wire        s_logisimNet94;
   wire        s_logisimNet95;
   wire        s_logisimNet97;
   wire        s_logisimNet98;
   wire        s_logisimNet99;

   /*******************************************************************************
   ** The module functionality is described here                                 **
   *******************************************************************************/

   /*******************************************************************************
   ** Here all wiring is defined                                                 **
   *******************************************************************************/
   assign s_logisimBus104[0]  = s_logisimNet52;
   assign s_logisimBus104[1]  = s_logisimNet101;
   assign s_logisimBus121[0]  = s_logisimNet58;
   assign s_logisimBus121[1]  = s_logisimNet14;
   assign s_logisimBus121[2]  = s_logisimNet54;
   assign s_logisimBus121[3]  = s_logisimNet5;
   assign s_logisimBus121[4]  = s_logisimNet116;
   assign s_logisimBus121[5]  = s_logisimNet0;
   assign s_logisimBus121[6]  = s_logisimNet19;
   assign s_logisimBus139[0]  = s_logisimNet11;
   assign s_logisimBus139[1]  = s_logisimNet41;
   assign s_logisimBus139[2]  = s_logisimNet90;
   assign s_logisimBus139[3]  = s_logisimNet77;
   assign s_logisimBus148[0]  = s_logisimNet109;
   assign s_logisimBus148[1]  = s_logisimNet89;
   assign s_logisimBus148[2]  = s_logisimNet6;
   assign s_logisimBus148[3]  = s_logisimNet78;
   assign s_logisimBus148[4]  = s_logisimNet59;
   assign s_logisimBus148[5]  = s_logisimNet4;
   assign s_logisimBus148[6]  = s_logisimNet43;
   assign s_logisimBus148[7]  = s_logisimNet10;
   assign s_logisimBus148[8]  = s_logisimNet110;
   assign s_logisimBus171[0]  = s_logisimNet2;
   assign s_logisimBus171[10] = s_logisimNet88;
   assign s_logisimBus171[11] = s_logisimNet112;
   assign s_logisimBus171[12] = s_logisimNet51;
   assign s_logisimBus171[13] = s_logisimNet57;
   assign s_logisimBus171[14] = s_logisimNet80;
   assign s_logisimBus171[15] = s_logisimNet118;
   assign s_logisimBus171[1]  = s_logisimNet45;
   assign s_logisimBus171[2]  = s_logisimNet87;
   assign s_logisimBus171[3]  = s_logisimNet111;
   assign s_logisimBus171[4]  = s_logisimNet50;
   assign s_logisimBus171[5]  = s_logisimNet56;
   assign s_logisimBus171[6]  = s_logisimNet79;
   assign s_logisimBus171[7]  = s_logisimNet117;
   assign s_logisimBus171[8]  = s_logisimNet3;
   assign s_logisimBus171[9]  = s_logisimNet44;
   assign s_logisimBus173[0]  = s_logisimNet92;
   assign s_logisimBus173[1]  = s_logisimNet28;
   assign s_logisimBus180[0]  = s_logisimNet62;
   assign s_logisimBus180[10] = s_logisimNet127;
   assign s_logisimBus180[11] = s_logisimNet13;
   assign s_logisimBus180[12] = s_logisimNet72;
   assign s_logisimBus180[13] = s_logisimNet94;
   assign s_logisimBus180[14] = s_logisimNet27;
   assign s_logisimBus180[15] = s_logisimNet39;
   assign s_logisimBus180[1]  = s_logisimNet107;
   assign s_logisimBus180[2]  = s_logisimNet126;
   assign s_logisimBus180[3]  = s_logisimNet12;
   assign s_logisimBus180[4]  = s_logisimNet73;
   assign s_logisimBus180[5]  = s_logisimNet93;
   assign s_logisimBus180[6]  = s_logisimNet29;
   assign s_logisimBus180[7]  = s_logisimNet38;
   assign s_logisimBus180[8]  = s_logisimNet63;
   assign s_logisimBus180[9]  = s_logisimNet106;
   assign s_logisimBus185[0]  = s_logisimNet85;
   assign s_logisimBus185[1]  = s_logisimNet69;
   assign s_logisimBus194[0]  = s_logisimNet18;
   assign s_logisimBus194[1]  = s_logisimNet83;
   assign s_logisimBus194[2]  = s_logisimNet98;
   assign s_logisimBus194[3]  = s_logisimNet36;
   assign s_logisimBus212[0]  = s_logisimNet33;
   assign s_logisimBus212[1]  = s_logisimNet84;
   assign s_logisimBus215[0]  = s_logisimNet95;
   assign s_logisimBus215[1]  = s_logisimNet22;
   assign s_logisimBus215[2]  = s_logisimNet40;
   assign s_logisimBus215[3]  = s_logisimNet64;
   assign s_logisimBus215[4]  = s_logisimNet75;
   assign s_logisimBus231[0]  = s_logisimNet42;
   assign s_logisimBus231[1]  = s_logisimNet120;
   assign s_logisimBus237[0]  = s_logisimNet21;
   assign s_logisimBus237[1]  = s_logisimNet34;
   assign s_logisimBus237[2]  = s_logisimNet100;
   assign s_logisimBus237[3]  = s_logisimNet68;
   assign s_logisimBus237[4]  = s_logisimNet157;
   assign s_logisimBus238[0]  = s_logisimNet7;
   assign s_logisimBus238[1]  = s_logisimNet24;
   assign s_logisimBus91[0]   = s_logisimNet25;
   assign s_logisimBus91[1]   = s_logisimNet47;
   assign s_logisimBus91[2]   = s_logisimNet20;
   assign s_logisimNet0       = s_logisimBus103[5];
   assign s_logisimNet10      = s_logisimBus37[7];
   assign s_logisimNet100     = s_logisimBus191[2];
   assign s_logisimNet101     = s_logisimBus102[1];
   assign s_logisimNet106     = s_logisimBus169[9];
   assign s_logisimNet107     = s_logisimBus169[1];
   assign s_logisimNet109     = s_logisimBus37[0];
   assign s_logisimNet11      = s_logisimBus32[0];
   assign s_logisimNet110     = s_logisimBus37[8];
   assign s_logisimNet111     = s_logisimBus216[3];
   assign s_logisimNet112     = s_logisimBus216[11];
   assign s_logisimNet116     = s_logisimBus103[4];
   assign s_logisimNet117     = s_logisimBus216[7];
   assign s_logisimNet118     = s_logisimBus216[15];
   assign s_logisimNet12      = s_logisimBus169[3];
   assign s_logisimNet120     = s_logisimBus49[1];
   assign s_logisimNet126     = s_logisimBus169[2];
   assign s_logisimNet127     = s_logisimBus169[10];
   assign s_logisimNet13      = s_logisimBus169[11];
   assign s_logisimNet14      = s_logisimBus103[1];
   assign s_logisimNet157     = s_logisimBus191[4];
   assign s_logisimNet18      = s_logisimBus156[0];
   assign s_logisimNet19      = s_logisimBus103[6];
   assign s_logisimNet2       = s_logisimBus216[0];
   assign s_logisimNet20      = s_logisimBus201[2];
   assign s_logisimNet21      = s_logisimBus191[0];
   assign s_logisimNet22      = s_logisimBus190[1];
   assign s_logisimNet24      = s_logisimBus26[1];
   assign s_logisimNet25      = s_logisimBus201[0];
   assign s_logisimNet27      = s_logisimBus169[14];
   assign s_logisimNet28      = s_logisimBus60[1];
   assign s_logisimNet29      = s_logisimBus169[6];
   assign s_logisimNet3       = s_logisimBus216[8];
   assign s_logisimNet33      = s_logisimBus210[0];
   assign s_logisimNet34      = s_logisimBus191[1];
   assign s_logisimNet36      = s_logisimBus156[3];
   assign s_logisimNet38      = s_logisimBus169[7];
   assign s_logisimNet39      = s_logisimBus169[15];
   assign s_logisimNet4       = s_logisimBus37[5];
   assign s_logisimNet40      = s_logisimBus190[2];
   assign s_logisimNet41      = s_logisimBus32[1];
   assign s_logisimNet42      = s_logisimBus49[0];
   assign s_logisimNet43      = s_logisimBus37[6];
   assign s_logisimNet44      = s_logisimBus216[9];
   assign s_logisimNet45      = s_logisimBus216[1];
   assign s_logisimNet47      = s_logisimBus201[1];
   assign s_logisimNet5       = s_logisimBus103[3];
   assign s_logisimNet50      = s_logisimBus216[4];
   assign s_logisimNet51      = s_logisimBus216[12];
   assign s_logisimNet52      = s_logisimBus102[0];
   assign s_logisimNet54      = s_logisimBus103[2];
   assign s_logisimNet56      = s_logisimBus216[5];
   assign s_logisimNet57      = s_logisimBus216[13];
   assign s_logisimNet58      = s_logisimBus103[0];
   assign s_logisimNet59      = s_logisimBus37[4];
   assign s_logisimNet6       = s_logisimBus37[2];
   assign s_logisimNet62      = s_logisimBus169[0];
   assign s_logisimNet63      = s_logisimBus169[8];
   assign s_logisimNet64      = s_logisimBus190[3];
   assign s_logisimNet68      = s_logisimBus191[3];
   assign s_logisimNet69      = s_logisimBus232[1];
   assign s_logisimNet7       = s_logisimBus26[0];
   assign s_logisimNet72      = s_logisimBus169[12];
   assign s_logisimNet73      = s_logisimBus169[4];
   assign s_logisimNet75      = s_logisimBus190[4];
   assign s_logisimNet77      = s_logisimBus32[3];
   assign s_logisimNet78      = s_logisimBus37[3];
   assign s_logisimNet79      = s_logisimBus216[6];
   assign s_logisimNet80      = s_logisimBus216[14];
   assign s_logisimNet83      = s_logisimBus156[1];
   assign s_logisimNet84      = s_logisimBus210[1];
   assign s_logisimNet85      = s_logisimBus232[0];
   assign s_logisimNet87      = s_logisimBus216[2];
   assign s_logisimNet88      = s_logisimBus216[10];
   assign s_logisimNet89      = s_logisimBus37[1];
   assign s_logisimNet90      = s_logisimBus32[2];
   assign s_logisimNet92      = s_logisimBus60[0];
   assign s_logisimNet93      = s_logisimBus169[5];
   assign s_logisimNet94      = s_logisimBus169[13];
   assign s_logisimNet95      = s_logisimBus190[0];
   assign s_logisimNet98      = s_logisimBus156[2];

   /*******************************************************************************
   ** Here all input connections are defined                                     **
   *******************************************************************************/
   assign s_logisimBus102[1:0]  = XCSSST_1_0;
   assign s_logisimBus103[6:0]  = XPT_9_15;
   assign s_logisimBus156[3:0]  = XCSTS_6_3;
   assign s_logisimBus169[15:0] = XCD_15_0;
   assign s_logisimBus190[4:0]  = XCSIDBS_4_0;
   assign s_logisimBus191[4:0]  = XCSCOMM_4_0;
   assign s_logisimBus201[2:0]  = XTSEL_2_0;
   assign s_logisimBus210[1:0]  = XCSRASEL_1_0;
   assign s_logisimBus216[15:0] = XCSBIT_15_0;
   assign s_logisimBus232[1:0]  = XCSRBSEL_1_0;
   assign s_logisimBus26[1:0]   = XCSCINSEL_1_0;
   assign s_logisimBus32[3:0]   = XCSRB_3_0;
   assign s_logisimBus37[8:0]   = XCSALUI_8_0;
   assign s_logisimBus49[1:0]   = XCSALUM_1_0;
   assign s_logisimBus60[1:0]   = XCSMIS_1_0;
   assign s_logisimBus86[15:0]  = XFIDB_15_0_IN;
   assign s_logisimNet105       = XMRN;
   assign s_logisimNet113       = XSTP;
   assign s_logisimNet114       = XVTRAPN;
   assign s_logisimNet119       = XMORN;
   assign s_logisimNet122       = XPOWFAILN;
   assign s_logisimNet129       = XPTSTN;
   assign s_logisimNet133       = XMCLK;
   assign s_logisimNet134       = XIOXERRN;
   assign s_logisimNet140       = XCSSCOND;
   assign s_logisimNet141       = XFTRAPN;
   assign s_logisimNet142       = XSPARE;
   assign s_logisimNet147       = XPANN;
   assign s_logisimNet149       = BDEST;
   assign s_logisimNet152       = XCSBIT20;
   assign s_logisimNet161       = XILCSN;
   assign s_logisimNet164       = XBINT12N;
   assign s_logisimNet175       = XETRAPN;
   assign s_logisimNet176       = XBINT11N;
   assign s_logisimNet177       = XPARERRN;
   assign s_logisimNet183       = XTCLK;
   assign s_logisimNet193       = XCSXRF3;
   assign s_logisimNet198       = XALUCLK;
   assign s_logisimNet202       = XEMPIDN;
   assign s_logisimNet211       = XEDON;
   assign s_logisimNet220       = XEWCAN;
   assign s_logisimNet221       = XCSECOND;
   assign s_logisimNet222       = XCSVECT;
   assign s_logisimNet228       = XBINT13N;
   assign s_logisimNet229       = XMAPN;
   assign s_logisimNet48        = XCSLOOP;
   assign s_logisimNet71        = XBINT15N;
   assign s_logisimNet76        = XBINT10N;

   /*******************************************************************************
   ** Here all output connections are defined                                    **
   *******************************************************************************/
   assign XACONDN        = s_logisimNet208;
   assign XBRKN          = s_logisimNet138;
   assign XDOUBLE        = s_logisimNet131;
   assign XECCR          = s_logisimNet144;
   assign XERFN          = s_logisimNet178;
   assign XFIDB_15_0_OUT = s_logisimBus15[15:0];
   assign XINTRQN        = s_logisimNet170;
   assign XIONI          = s_logisimNet217;
   assign XLAA_3_0       = s_logisimBus204[3:0];
   assign XLA_23_10      = s_logisimBus225[13:0];
   assign XLBA_3_0       = s_logisimBus137[3:0];
   assign XLSHADOW       = s_logisimNet172;
   assign XMA_12_0       = s_logisimBus230[12:0];
   assign XMCA_9_0       = s_logisimBus218[9:0];
   assign XPCR_1_0       = s_logisimBus168[1:0];
   assign XPIL_3_0       = s_logisimBus153[3:0];
   assign XPONI          = s_logisimNet188;
   assign XRF_1_0        = s_logisimBus128[1:0];
   assign XTEST_4_0      = s_logisimBus96[4:0];
   assign XTRAPN         = s_logisimNet200;
   assign XWCSN          = s_logisimNet167;
   assign XWRTRF         = s_logisimNet226;

   /*******************************************************************************
   ** Here all in-lined components are defined                                   **
   *******************************************************************************/

   // Power
   assign  s_logisimNet99  =  1'b1;


   /*******************************************************************************
   ** Here all sub-circuits are defined                                          **
   *******************************************************************************/

   CGA_ALU   ALU (.ALUCLK(s_logisimNet198),
                  .A_15_0(s_logisimBus165[15:0]),
                  .BDEST(s_logisimNet219),
                  .B_15_0(s_logisimBus115[15:0]),
                  .CD_15_0(s_logisimBus180[15:0]),
                  .CRY(s_logisimNet159),
                  .CSALUI_8_0(s_logisimBus148[8:0]),
                  .CSALUM_1_0(s_logisimBus231[1:0]),
                  .CSBIT_15_0(s_logisimBus171[15:0]),
                  .CSCINSEL_1_0(s_logisimBus238[1:0]),
                  .CSIDBS_4_0(s_logisimBus215[4:0]),
                  .CSMIS_1_0(s_logisimBus173[1:0]),
                  .CSSST_1_0(s_logisimBus104[1:0]),
                  .DOUBLE(s_logisimNet131),
                  .EA_15_0(s_logisimBus16[15:0]),
                  .F11(s_logisimNet162),
                  .F15(s_logisimNet223),
                  .FIDBI_15_0(s_logisimBus195[15:0]),
                  .FIDBO_15_0(s_logisimBus163[15:0]),
                  .IONI(s_logisimNet217),
                  .LAA_3_0(s_logisimBus204[3:0]),
                  .LBA_3_0(s_logisimBus137[3:0]),
                  .LCZN(s_logisimNet214),
                  .LDDBRN(s_logisimNet187),
                  .LDGPRN(s_logisimNet154),
                  .LDIRV(s_logisimNet227),
                  .LDPILN(s_logisimNet186),
                  .MI(s_logisimNet206),
                  .OVF(s_logisimNet174),
                  .PIL(s_logisimBus53[3:0]),
                  .PONI(s_logisimNet188),
                  .PTM(s_logisimNet189),
                  .RB_15_0(s_logisimBus65[15:0]),
                  .SGR(s_logisimNet192),
                  .UPN(s_logisimNet207),
                  .XFETCHN(s_logisimNet209),
                  .Z(s_logisimNet196),
                  .ZF(s_logisimNet182));

   CGA_TRAP   TRAP (.BRKN(s_logisimNet138),
                    .CBRKN(s_logisimNet97),
                    .DSTOPN(s_logisimNet66),
                    .ETRAPN(s_logisimNet175),
                    .FETCHN(s_logisimNet125),
                    .FTRAPN(s_logisimNet141),
                    .INDN(s_logisimNet123),
                    .INTRQN(s_logisimNet170),
                    .PANN(s_logisimNet147),
                    .PCR_1_0(s_logisimBus168[1:0]),
                    .PONI(s_logisimNet188),
                    .PT_15_9(s_logisimBus17[6:0]),
                    .PVIOL(s_logisimNet74),
                    .RESTR(s_logisimNet213),
                    .TCLK(s_logisimNet183),
                    .TRAPN(s_logisimNet200),
                    .TVEC_3_0(s_logisimBus132[3:0]),
                    .VACCN(s_logisimNet150),
                    .VTRAPN(s_logisimNet114),
                    .WRITEN(s_logisimNet61));

   CGA_IDBCTL   IDBCTL (.EPCRN(s_logisimNet35),
                        .EPGSN(s_logisimNet23),
                        .EPICMASKN(s_logisimNet108),
                        .EPICSN(s_logisimNet1),
                        .EPICVN(s_logisimNet81),
                        .FETCHN(s_logisimNet125),
                        .FIDBI_15_0(s_logisimBus195[15:0]),
                        .HIGSN(s_logisimNet46),
                        .LA_21_10(s_logisimBus234[11:0]),
                        .LOGSN(s_logisimNet8),
                        .MCLK(s_logisimNet133),
                        .PCR_15_0(s_logisimBus143[15:0]),
                        .PD(s_logisimNet31),
                        .PICMASK_15_0(s_logisimBus135[15:0]),
                        .PICS_2_0(s_logisimBus70[2:0]),
                        .PICV_2_0(s_logisimBus146[2:0]),
                        .PVIOL(s_logisimNet74),
                        .VACCN(s_logisimNet150),
                        .XFIDBI_15_0(s_logisimBus197[15:0]));

   CGA_WRF   WRF (.ALUCLK(s_logisimNet198),
                  .A_15_0(s_logisimBus165[15:0]),
                  .BDEST(s_logisimNet149),
                  .BR_15_0(s_logisimBus9[15:0]),
                  .B_15_0(s_logisimBus115[15:0]),
                  .LAA_3_0(s_logisimBus204[3:0]),
                  .LBA_3_0(s_logisimBus137[3:0]),
                  .NLCA_15_0(s_logisimBus130[15:0]),
                  .PR_15_0(s_logisimBus55[15:0]),
                  .RB_15_0(s_logisimBus65[15:0]),
                  .WPN(s_logisimNet233),
                  .WR3(s_logisimNet155),
                  .WR7(s_logisimNet160),
                  .XFETCHN(s_logisimNet209),
                  .XR_15_0(s_logisimBus67[15:0]));

   CGA_DCD   DCD (.BRKN(s_logisimNet138),
                  .CBRKN(s_logisimNet97),
                  .CFETCH(s_logisimNet124),
                  .CLFFN(s_logisimNet239),
                  .CLIRQN(s_logisimNet30),
                  .CRY(s_logisimNet182),
                  .CSCOMM_4_0(s_logisimBus224[4:0]),
                  .CSIDBS_4_0(s_logisimBus215[4:0]),
                  .CSMIS_1_0(s_logisimBus173[1:0]),
                  .CSMREQ(s_logisimNet136),
                  .DSTOPN(s_logisimNet66),
                  .EPCRN(s_logisimNet35),
                  .EPGSN(s_logisimNet23),
                  .EPIC(s_logisimNet82),
                  .EPICSN(s_logisimNet1),
                  .EPICVN(s_logisimNet81),
                  .ERFN(s_logisimNet178),
                  .F15(s_logisimNet223),
                  .FETCHN(s_logisimNet125),
                  .FIDBO5(s_logisimBus163[5]),
                  .ILCSN(s_logisimNet161),
                  .INDN(s_logisimNet123),
                  .INTRQN(s_logisimNet170),
                  .LDDBRN(s_logisimNet187),
                  .LDGPRN(s_logisimNet154),
                  .LDIRV(s_logisimNet227),
                  .LDLCN(s_logisimNet145),
                  .LDPILN(s_logisimNet186),
                  .LSHADOW(s_logisimNet172),
                  .LWCAN(s_logisimNet203),
                  .MCLK(s_logisimNet133),
                  .MRN(s_logisimNet105),
                  .PONI(s_logisimNet188),
                  .SGR(s_logisimNet192),
                  .VACCN(s_logisimNet150),
                  .VEX(s_logisimNet199),
                  .WPN(s_logisimNet233),
                  .WRITEN(s_logisimNet61),
                  .WRTRF(s_logisimNet226),
                  .XFETCHN(s_logisimNet209),
                  .ZF(s_logisimNet159));

   BusDriver16   BD_FIDBO (.A_15_0(s_logisimBus163[15:0]),
                           .EN(s_logisimNet211),
                           .IN_15_0(s_logisimBus86[15:0]),
                           .OUT_15_0(s_logisimBus15[15:0]),
                           .TN(s_logisimNet129),
                           .ZI_15_0(s_logisimBus197[15:0]));

   CGA_INTR   INTR (.BINT10N(s_logisimNet76),
                    .BINT11N(s_logisimNet176),
                    .BINT12N(s_logisimNet164),
                    .BINT13N(s_logisimNet228),
                    .BINT15N(s_logisimNet71),
                    .CLIRQN(s_logisimNet30),
                    .EMPIDN(s_logisimNet202),
                    .EPIC(s_logisimNet82),
                    .EPICMASKN(s_logisimNet108),
                    .FIDBO_15_0(s_logisimBus163[15:0]),
                    .HIGSN(s_logisimNet46),
                    .INTRQN(s_logisimNet170),
                    .IOXERRN(s_logisimNet134),
                    .IRQ(s_logisimNet179),
                    .LAA_3_0(s_logisimBus204[3:0]),
                    .LOGSN(s_logisimNet8),
                    .MCLK(s_logisimNet133),
                    .NORN(s_logisimNet119),
                    .PANN(s_logisimNet147),
                    .PARERRN(s_logisimNet177),
                    .PD(s_logisimNet31),
                    .PICMASK_15_0(s_logisimBus135[15:0]),
                    .PICS_2_0(s_logisimBus70[2:0]),
                    .PICV_2_0(s_logisimBus146[2:0]),
                    .POWFAILN(s_logisimNet122),
                    .Z(s_logisimNet196));

   CGA_MAC   MAC (.BR_15_0(s_logisimBus9[15:0]),
                  .CD_15_0(s_logisimBus180[15:0]),
                  .CMIS_1_0(s_logisimBus173[1:0]),
                  .CSCOMM_4_0(s_logisimBus224[4:0]),
                  .CSMREQ(s_logisimNet136),
                  .DOUBLE(s_logisimNet131),
                  .ECCR(s_logisimNet144),
                  .FIDBO_15_0(s_logisimBus163[15:0]),
                  .ILCSN(s_logisimNet161),
                  .LA_23_10(s_logisimBus225[13:0]),
                  .LSHADOW(s_logisimNet172),
                  .MCA_9_0(s_logisimBus218[9:0]),
                  .MCLK(s_logisimNet133),
                  .NLCA_15_0(s_logisimBus130[15:0]),
                  .PCR_15_7_2_0(s_logisimBus143[15:0]),
                  .PONI(s_logisimNet188),
                  .PR_15_0(s_logisimBus55[15:0]),
                  .PTM(s_logisimNet189),
                  .RB_15_0(s_logisimBus65[15:0]),
                  .VEX(s_logisimNet199),
                  .WR3(s_logisimNet155),
                  .WR7(s_logisimNet160),
                  .XR_15_0(s_logisimBus67[15:0]));

   CGA_MIC   MIC (.ACONDN(s_logisimNet208),
                  .ALUCLK(s_logisimNet198),
                  .CD_15_0(s_logisimBus180[15:0]),
                  .CFETCH(s_logisimNet124),
                  .CLFFN(s_logisimNet239),
                  .COND(s_logisimNet181),
                  .CRY(s_logisimNet182),
                  .CSALUI8(s_logisimNet110),
                  .CSBIT20(s_logisimNet152),
                  .CSBIT_15_0(s_logisimBus171[15:0]),
                  .CSCOND(s_logisimNet140),
                  .CSECOND(s_logisimNet221),
                  .CSLOOP(s_logisimNet48),
                  .CSMIS0(s_logisimNet92),
                  .CSRASEL_1_0(s_logisimBus212[1:0]),
                  .CSRBSEL_1_0(s_logisimBus185[1:0]),
                  .CSRB_3_0(s_logisimBus139[3:0]),
                  .CSTS_6_3(s_logisimBus194[3:0]),
                  .CSVECT(s_logisimNet222),
                  .CSXRF3(s_logisimNet193),
                  .DEEP(s_logisimNet184),
                  .DZD(s_logisimNet205),
                  .EWCAN(s_logisimNet220),
                  .F11(s_logisimNet162),
                  .F15(s_logisimNet223),
                  .ILCSN(s_logisimNet161),
                  .IRQ(s_logisimNet179),
                  .LAA_3_0(s_logisimBus204[3:0]),
                  .LBA_3_0(s_logisimBus137[3:0]),
                  .LCZ(1'b0),
                  .LCZN(s_logisimNet214),
                  .LDIRV(s_logisimNet227),
                  .LDLCN(s_logisimNet145),
                  .LWCAN(s_logisimNet203),
                  .MAPN(s_logisimNet229),
                  .MA_12_0(s_logisimBus230[12:0]),
                  .MCLK(s_logisimNet133),
                  .MI(s_logisimNet206),
                  .MRN(s_logisimNet105),
                  .OOD(s_logisimNet151),
                  .OVF(s_logisimNet174),
                  .PIL_3_0(s_logisimBus153[3:0]),
                  .PN(s_logisimNet166),
                  .RESTR(s_logisimNet213),
                  .RF_1_0(s_logisimBus128[1:0]),
                  .SC_6_3(s_logisimBus236[3:0]),
                  .SPARE(s_logisimNet142),
                  .STP(s_logisimNet113),
                  .TN(s_logisimNet235),
                  .TRAPN(s_logisimNet200),
                  .TVEC_3_0(s_logisimBus132[3:0]),
                  .UPN(s_logisimNet207),
                  .WCSN(s_logisimNet167),
                  .ZF(s_logisimNet159));

   CGA_TESTMUX   TESTMUX (.CBRKN(s_logisimNet97),
                          .CFETCH(s_logisimNet124),
                          .COND(s_logisimNet181),
                          .CRY(s_logisimNet182),
                          .CSMREQ(s_logisimNet136),
                          .DEEP(s_logisimNet184),
                          .DSTOPN(s_logisimNet66),
                          .DZD(s_logisimNet205),
                          .F15(s_logisimNet223),
                          .INDN(s_logisimNet123),
                          .LCZN(s_logisimNet214),
                          .LDIRV(s_logisimNet227),
                          .MI(s_logisimNet206),
                          .OOD(s_logisimNet151),
                          .OVF(s_logisimNet174),
                          .PN(s_logisimNet166),
                          .PTM(s_logisimNet189),
                          .PTREEOUT(s_logisimNet99),
                          .PTSTN(s_logisimNet129),
                          .RESTR(s_logisimNet213),
                          .SC_6_3(s_logisimBus236[3:0]),
                          .SGR(s_logisimNet192),
                          .TEST_4_0(s_logisimBus96[4:0]),
                          .TN(s_logisimNet235),
                          .TSEL_2_0(s_logisimBus91[2:0]),
                          .TVEC_3_0(s_logisimBus132[3:0]),
                          .UPN(s_logisimNet207),
                          .VACCN(s_logisimNet150),
                          .VEX(s_logisimNet199),
                          .WPN(s_logisimNet233),
                          .WRITEN(s_logisimNet61),
                          .XFETCHN(s_logisimNet209),
                          .ZF(s_logisimNet159));

endmodule

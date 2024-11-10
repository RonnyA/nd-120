/**************************************************************************
** ND120 CPU, MM&M                                                       **
** CGA/WRF/RBLOCK                                                        **
** WRF: Register File Block                                              **
** (PDF page 60)                                                         **
**                                                                       **
** Last reviewed: 09-NOV-2024                                            **
** Ronny Hansen                                                          **
***************************************************************************/


module CGA_WRF_RBLOCK (
    input        ALUCLK,
    input [15:0] EA_15_0,
    input [15:0] EB_15_0,
    input [15:0] NLCA_15_0,
    input [15:0] RB_15_0,
    input [15:0] WR_15_0,
    input        XFETCHN,

    output [15:0] A_15_0,
    output [15:0] BR_15_0,
    output [15:0] B_15_0,
    output [15:0] PR_15_0,
    output [15:0] XR_15_0
);

  /*******************************************************************************
   ** The wires are defined here                                                 **
   *******************************************************************************/
  wire [15:0] s_rb_15_0;
  wire [15:0] s_reg3_b_15_0;
  wire [15:0] s_reg14_r6_15_0;
  wire [15:0] s_sel12_in_15_0;
  wire [15:0] s_reg6_t_15_0;
  wire [15:0] s_sel3_in_15_0;
  wire [15:0] s_sel8_in_15_0;
  wire [15:0] s_logisimBus118;
  wire [15:0] s_reg2_p_15_0;
  wire [15:0] s_b_15_0_out;
  wire [15:0] s_ncla_15_0;
  wire [15:0] s_sel4_in_15_0;
  wire [15:0] s_sel9_in_15_0;
  wire [15:0] s_sel0_in_15_0;
  wire [15:0] s_reg13_r5_15_0;
  wire [15:0] s_br_15_0_out;
  wire [15:0] s_sel1_in_15_0;
  wire [15:0] s_xr_15_0_out;
  wire [15:0] s_reg5_a_15_0;
  wire [15:0] s_sel11_in_15_0;
  wire [15:0] s_reg1_d_15_0;
  wire [15:0] s_sel7_in_15_0;
  wire [15:0] s_a_15_0_out;
  wire [15:0] s_sel2_in_15_0;
  wire [15:0] s_reg12_r4_15_0;
  wire [15:0] s_reg15_r7_15_0;
  wire [15:0] s_reg0_z_15_0;
  wire [15:0] s_wr_15_0;
  wire [15:0] s_pr_15_0_out;
  wire [15:0] s_eb_15_0;
  wire [15:0] s_ea_15_0;
  wire [15:0] s_sel10_in_15_0;
  wire [15:0] s_reg7_x_15_0;
  wire [15:0] s_sel14_in_15_0;
  wire [15:0] s_sel6_in_15_0;
  wire [15:0] s_reg9_r1_15_0;
  wire [15:0] s_sel15_in_15_0;
  wire [15:0] s_sel13_in_15_0;
  wire [15:0] s_reg10_r2_15_0;
  wire [15:0] s_sel5_in_15_0;
  wire [15:0] s_reg4_l_15_0;
  wire [15:0] s_reg8_sts_15_0;
  wire        s_reg2_p_7;
  wire        s_reg15_r7_3;
  wire        s_reg3_b_15;
  wire        s_logisimNet103;
  wire        s_logisimNet104;
  wire        s_logisimNet105;
  wire        s_xfetch_n;
  wire        s_logisimNet109;
  wire        s_logisimNet110;
  wire        s_logisimNet111;
  wire        s_logisimNet112;
  wire        s_logisimNet113;
  wire        s_logisimNet114;
  wire        s_logisimNet115;
  wire        s_logisimNet117;
  wire        s_logisimNet12;
  wire        s_logisimNet122;
  wire        s_logisimNet123;
  wire        s_logisimNet124;
  wire        s_logisimNet125;
  wire        s_logisimNet126;
  wire        s_logisimNet127;
  wire        s_logisimNet128;
  wire        s_aluclk_n;
  wire        s_logisimNet130;
  wire        s_logisimNet131;
  wire        s_logisimNet132;
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
  wire        s_logisimNet143;
  wire        s_logisimNet144;
  wire        s_logisimNet147;
  wire        s_logisimNet148;
  wire        s_logisimNet15;
  wire        s_logisimNet150;
  wire        s_logisimNet151;
  wire        s_logisimNet152;
  wire        s_logisimNet153;
  wire        s_logisimNet154;
  wire        s_logisimNet156;
  wire        s_logisimNet157;
  wire        s_logisimNet158;
  wire        s_logisimNet159;
  wire        s_logisimNet16;
  wire        s_logisimNet160;
  wire        s_logisimNet161;
  wire        s_logisimNet162;
  wire        s_logisimNet164;
  wire        s_logisimNet165;
  wire        s_logisimNet166;
  wire        s_logisimNet167;
  wire        s_logisimNet168;
  wire        s_logisimNet169;
  wire        s_logisimNet17;
  wire        s_logisimNet170;
  wire        s_logisimNet171;
  wire        s_logisimNet172;
  wire        s_logisimNet173;
  wire        s_logisimNet174;
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
  wire        s_logisimNet185;
  wire        s_logisimNet186;
  wire        s_logisimNet187;
  wire        s_logisimNet188;
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
  wire        s_aluclk;
  wire        s_logisimNet200;
  wire        s_logisimNet201;
  wire        s_logisimNet202;
  wire        s_logisimNet203;
  wire        s_logisimNet204;
  wire        s_logisimNet205;
  wire        s_logisimNet206;
  wire        s_logisimNet207;
  wire        s_logisimNet209;
  wire        s_logisimNet21;
  wire        s_logisimNet210;
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
  wire        s_logisimNet223;
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
  wire        s_logisimNet246;
  wire        s_logisimNet247;
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
  wire        s_logisimNet273;
  wire        s_logisimNet274;
  wire        s_logisimNet275;
  wire        s_logisimNet277;
  wire        s_logisimNet278;
  wire        s_logisimNet279;
  wire        s_logisimNet28;
  wire        s_logisimNet280;
  wire        s_logisimNet281;
  wire        s_logisimNet284;
  wire        s_logisimNet285;
  wire        s_logisimNet286;
  wire        s_logisimNet287;
  wire        s_logisimNet288;
  wire        s_logisimNet289;
  wire        s_logisimNet29;
  wire        s_logisimNet290;
  wire        s_logisimNet291;
  wire        s_logisimNet292;
  wire        s_logisimNet293;
  wire        s_logisimNet294;
  wire        s_logisimNet295;
  wire        s_logisimNet296;
  wire        s_logisimNet297;
  wire        s_logisimNet298;
  wire        s_logisimNet299;
  wire        s_logisimNet3;
  wire        s_logisimNet30;
  wire        s_logisimNet300;
  wire        s_logisimNet301;
  wire        s_logisimNet302;
  wire        s_logisimNet303;
  wire        s_logisimNet304;
  wire        s_logisimNet305;
  wire        s_logisimNet306;
  wire        s_logisimNet307;
  wire        s_logisimNet308;
  wire        s_logisimNet309;
  wire        s_logisimNet31;
  wire        s_logisimNet310;
  wire        s_logisimNet311;
  wire        s_logisimNet312;
  wire        s_logisimNet313;
  wire        s_logisimNet314;
  wire        s_logisimNet315;
  wire        s_logisimNet316;
  wire        s_logisimNet317;
  wire        s_logisimNet318;
  wire        s_logisimNet319;
  wire        s_logisimNet321;
  wire        s_logisimNet322;
  wire        s_logisimNet323;
  wire        s_logisimNet324;
  wire        s_logisimNet325;
  wire        s_logisimNet326;
  wire        s_logisimNet327;
  wire        s_logisimNet328;
  wire        s_logisimNet329;
  wire        s_logisimNet330;
  wire        s_logisimNet331;
  wire        s_logisimNet332;
  wire        s_logisimNet333;
  wire        s_logisimNet335;
  wire        s_logisimNet336;
  wire        s_logisimNet337;
  wire        s_logisimNet338;
  wire        s_logisimNet339;
  wire        s_logisimNet34;
  wire        s_logisimNet340;
  wire        s_logisimNet341;
  wire        s_logisimNet343;
  wire        s_logisimNet344;
  wire        s_logisimNet345;
  wire        s_logisimNet346;
  wire        s_logisimNet347;
  wire        s_logisimNet348;
  wire        s_logisimNet35;
  wire        s_logisimNet36;
  wire        s_logisimNet37;
  wire        s_logisimNet39;
  wire        s_logisimNet4;
  wire        s_logisimNet40;
  wire        s_logisimNet41;
  wire        s_logisimNet42;
  wire        s_logisimNet43;
  wire        s_logisimNet45;
  wire        s_logisimNet46;
  wire        s_logisimNet48;
  wire        s_logisimNet49;
  wire        s_logisimNet51;
  wire        s_logisimNet52;
  wire        s_logisimNet53;
  wire        s_logisimNet54;
  wire        s_logisimNet56;
  wire        s_logisimNet57;
  wire        s_logisimNet58;
  wire        s_logisimNet59;
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
  assign s_sel0_in_15_0[0]   = s_logisimNet192;
  assign s_sel0_in_15_0[1]   = s_logisimNet59;
  assign s_sel0_in_15_0[10]  = s_logisimNet230;
  assign s_sel0_in_15_0[11]  = s_logisimNet344;
  assign s_sel0_in_15_0[12]  = s_logisimNet64;
  assign s_sel0_in_15_0[13]  = s_logisimNet148;
  assign s_sel0_in_15_0[14]  = s_logisimNet306;
  assign s_sel0_in_15_0[15]  = s_logisimNet343;
  assign s_sel0_in_15_0[2]   = s_logisimNet307;
  assign s_sel0_in_15_0[3]   = s_logisimNet255;
  assign s_sel0_in_15_0[4]   = s_logisimNet284;
  assign s_sel0_in_15_0[5]   = s_logisimNet16;
  assign s_sel0_in_15_0[6]   = s_logisimNet330;
  assign s_sel0_in_15_0[7]   = s_logisimNet178;
  assign s_sel0_in_15_0[8]   = s_logisimNet287;
  assign s_sel0_in_15_0[9]   = s_logisimNet267;

  assign s_sel1_in_15_0[0]   = s_logisimNet301;
  assign s_sel1_in_15_0[1]   = s_logisimNet80;
  assign s_sel1_in_15_0[10]  = s_logisimNet4;
  assign s_sel1_in_15_0[11]  = s_logisimNet29;
  assign s_sel1_in_15_0[12]  = s_logisimNet126;
  assign s_sel1_in_15_0[13]  = s_logisimNet158;
  assign s_sel1_in_15_0[14]  = s_logisimNet229;
  assign s_sel1_in_15_0[15]  = s_logisimNet127;
  assign s_sel1_in_15_0[2]   = s_logisimNet122;
  assign s_sel1_in_15_0[3]   = s_logisimNet209;
  assign s_sel1_in_15_0[4]   = s_logisimNet302;
  assign s_sel1_in_15_0[5]   = s_logisimNet61;
  assign s_sel1_in_15_0[6]   = s_logisimNet43;
  assign s_sel1_in_15_0[7]   = s_logisimNet291;
  assign s_sel1_in_15_0[8]   = s_logisimNet176;
  assign s_sel1_in_15_0[9]   = s_logisimNet346;

  assign s_sel10_in_15_0[0]  = s_logisimNet251;
  assign s_sel10_in_15_0[1]  = s_logisimNet53;
  assign s_sel10_in_15_0[10] = s_logisimNet303;
  assign s_sel10_in_15_0[11] = s_logisimNet299;
  assign s_sel10_in_15_0[12] = s_logisimNet94;
  assign s_sel10_in_15_0[13] = s_logisimNet40;
  assign s_sel10_in_15_0[14] = s_logisimNet85;
  assign s_sel10_in_15_0[15] = s_logisimNet173;
  assign s_sel10_in_15_0[2]  = s_logisimNet22;
  assign s_sel10_in_15_0[3]  = s_logisimNet331;
  assign s_sel10_in_15_0[4]  = s_logisimNet345;
  assign s_sel10_in_15_0[5]  = s_logisimNet226;
  assign s_sel10_in_15_0[6]  = s_logisimNet317;
  assign s_sel10_in_15_0[7]  = s_logisimNet233;
  assign s_sel10_in_15_0[8]  = s_logisimNet48;
  assign s_sel10_in_15_0[9]  = s_logisimNet285;

  assign s_sel11_in_15_0[0]  = s_logisimNet188;
  assign s_sel11_in_15_0[1]  = s_logisimNet300;
  assign s_sel11_in_15_0[10] = s_logisimNet132;
  assign s_sel11_in_15_0[11] = s_logisimNet227;
  assign s_sel11_in_15_0[12] = s_logisimNet318;
  assign s_sel11_in_15_0[13] = s_logisimNet66;
  assign s_sel11_in_15_0[14] = s_logisimNet49;
  assign s_sel11_in_15_0[15] = s_logisimNet181;
  assign s_sel11_in_15_0[2]  = s_logisimNet35;
  assign s_sel11_in_15_0[3]  = s_logisimNet41;
  assign s_sel11_in_15_0[4]  = s_logisimNet86;
  assign s_sel11_in_15_0[5]  = s_logisimNet174;
  assign s_sel11_in_15_0[6]  = s_logisimNet244;
  assign s_sel11_in_15_0[7]  = s_logisimNet3;
  assign s_sel11_in_15_0[8]  = s_logisimNet28;
  assign s_sel11_in_15_0[9]  = s_logisimNet74;

  assign s_sel12_in_15_0[0]  = s_logisimNet93;
  assign s_sel12_in_15_0[1]  = s_logisimNet329;
  assign s_sel12_in_15_0[10] = s_logisimNet295;
  assign s_sel12_in_15_0[11] = s_logisimNet203;
  assign s_sel12_in_15_0[12] = s_logisimNet37;
  assign s_sel12_in_15_0[13] = s_logisimNet231;
  assign s_sel12_in_15_0[14] = s_logisimNet179;
  assign s_sel12_in_15_0[15] = s_logisimNet281;
  assign s_sel12_in_15_0[2]  = s_logisimNet180;
  assign s_sel12_in_15_0[3]  = s_logisimNet160;
  assign s_sel12_in_15_0[4]  = s_logisimNet224;
  assign s_sel12_in_15_0[5]  = s_logisimNet286;
  assign s_sel12_in_15_0[6]  = s_logisimNet196;
  assign s_sel12_in_15_0[7]  = s_logisimNet78;
  assign s_sel12_in_15_0[8]  = s_logisimNet161;
  assign s_sel12_in_15_0[9]  = s_logisimNet212;

  assign s_sel13_in_15_0[0]  = s_logisimNet175;
  assign s_sel13_in_15_0[1]  = s_logisimNet248;
  assign s_sel13_in_15_0[10] = s_logisimNet216;
  assign s_sel13_in_15_0[11] = s_logisimNet332;
  assign s_sel13_in_15_0[12] = s_logisimNet262;
  assign s_sel13_in_15_0[13] = s_logisimNet8;
  assign s_sel13_in_15_0[14] = s_logisimNet290;
  assign s_sel13_in_15_0[15] = s_logisimNet91;
  assign s_sel13_in_15_0[2]  = s_logisimNet338;
  assign s_sel13_in_15_0[3]  = s_logisimNet239;
  assign s_sel13_in_15_0[4]  = s_logisimNet257;
  assign s_sel13_in_15_0[5]  = s_logisimNet136;
  assign s_sel13_in_15_0[6]  = s_logisimNet312;
  assign s_sel13_in_15_0[7]  = s_logisimNet324;
  assign s_sel13_in_15_0[8]  = s_logisimNet269;
  assign s_sel13_in_15_0[9]  = s_logisimNet205;

  assign s_sel14_in_15_0[0]  = s_logisimNet263;
  assign s_sel14_in_15_0[1]  = s_logisimNet139;
  assign s_sel14_in_15_0[10] = s_logisimNet202;
  assign s_sel14_in_15_0[11] = s_logisimNet325;
  assign s_sel14_in_15_0[12] = s_logisimNet193;
  assign s_sel14_in_15_0[13] = s_logisimNet77;
  assign s_sel14_in_15_0[14] = s_logisimNet99;
  assign s_sel14_in_15_0[15] = s_logisimNet194;
  assign s_sel14_in_15_0[2]  = s_logisimNet46;
  assign s_sel14_in_15_0[3]  = s_logisimNet92;
  assign s_sel14_in_15_0[4]  = s_logisimNet144;
  assign s_sel14_in_15_0[5]  = s_logisimNet249;
  assign s_sel14_in_15_0[6]  = s_logisimNet339;
  assign s_sel14_in_15_0[7]  = s_logisimNet26;
  assign s_sel14_in_15_0[8]  = s_logisimNet58;
  assign s_sel14_in_15_0[9]  = s_logisimNet137;

  assign s_sel15_in_15_0[0]  = s_logisimNet275;
  assign s_sel15_in_15_0[1]  = s_logisimNet237;
  assign s_sel15_in_15_0[10] = s_logisimNet207;
  assign s_sel15_in_15_0[11] = s_logisimNet341;
  assign s_sel15_in_15_0[12] = s_logisimNet309;
  assign s_sel15_in_15_0[13] = s_logisimNet166;
  assign s_sel15_in_15_0[14] = s_logisimNet113;
  assign s_sel15_in_15_0[15] = s_logisimNet310;
  assign s_sel15_in_15_0[2]  = s_logisimNet114;
  assign s_sel15_in_15_0[3]  = s_reg3_b_15;
  assign s_sel15_in_15_0[4]  = s_logisimNet156;
  assign s_sel15_in_15_0[5]  = s_logisimNet266;
  assign s_sel15_in_15_0[6]  = s_logisimNet128;
  assign s_sel15_in_15_0[7]  = s_logisimNet34;
  assign s_sel15_in_15_0[8]  = s_logisimNet105;
  assign s_sel15_in_15_0[9]  = s_logisimNet147;

  assign s_sel2_in_15_0[0]   = s_logisimNet69;
  assign s_sel2_in_15_0[1]   = s_logisimNet253;
  assign s_sel2_in_15_0[10]  = s_logisimNet76;
  assign s_sel2_in_15_0[11]  = s_logisimNet150;
  assign s_sel2_in_15_0[12]  = s_logisimNet327;
  assign s_sel2_in_15_0[13]  = s_logisimNet278;
  assign s_sel2_in_15_0[14]  = s_logisimNet124;
  assign s_sel2_in_15_0[15]  = s_logisimNet328;
  assign s_sel2_in_15_0[2]   = s_logisimNet222;
  assign s_sel2_in_15_0[3]   = s_logisimNet96;
  assign s_sel2_in_15_0[4]   = s_logisimNet104;
  assign s_sel2_in_15_0[5]   = s_logisimNet214;
  assign s_sel2_in_15_0[6]   = s_logisimNet140;
  assign s_sel2_in_15_0[7]   = s_logisimNet211;
  assign s_sel2_in_15_0[8]   = s_logisimNet293;
  assign s_sel2_in_15_0[9]   = s_logisimNet65;

  assign s_sel3_in_15_0[0]   = s_logisimNet153;
  assign s_sel3_in_15_0[1]   = s_logisimNet265;
  assign s_sel3_in_15_0[10]  = s_logisimNet165;
  assign s_sel3_in_15_0[11]  = s_logisimNet256;
  assign s_sel3_in_15_0[12]  = s_logisimNet273;
  assign s_sel3_in_15_0[13]  = s_logisimNet289;
  assign s_sel3_in_15_0[14]  = s_logisimNet218;
  assign s_sel3_in_15_0[15]  = s_reg15_r7_3;
  assign s_sel3_in_15_0[2]   = s_logisimNet220;
  assign s_sel3_in_15_0[3]   = s_logisimNet184;
  assign s_sel3_in_15_0[4]   = s_logisimNet199;
  assign s_sel3_in_15_0[5]   = s_logisimNet347;
  assign s_sel3_in_15_0[6]   = s_logisimNet238;
  assign s_sel3_in_15_0[7]   = s_logisimNet340;
  assign s_sel3_in_15_0[8]   = s_logisimNet206;
  assign s_sel3_in_15_0[9]   = s_logisimNet152;

  assign s_sel4_in_15_0[0]   = s_logisimNet326;
  assign s_sel4_in_15_0[1]   = s_logisimNet277;
  assign s_sel4_in_15_0[10]  = s_logisimNet115;
  assign s_sel4_in_15_0[11]  = s_logisimNet210;
  assign s_sel4_in_15_0[12]  = s_logisimNet292;
  assign s_sel4_in_15_0[13]  = s_logisimNet45;
  assign s_sel4_in_15_0[14]  = s_logisimNet36;
  assign s_sel4_in_15_0[15]  = s_logisimNet138;
  assign s_sel4_in_15_0[2]   = s_logisimNet21;
  assign s_sel4_in_15_0[3]   = s_logisimNet31;
  assign s_sel4_in_15_0[4]   = s_logisimNet68;
  assign s_sel4_in_15_0[5]   = s_logisimNet159;
  assign s_sel4_in_15_0[6]   = s_logisimNet221;
  assign s_sel4_in_15_0[7]   = s_logisimNet305;
  assign s_sel4_in_15_0[8]   = s_logisimNet18;
  assign s_sel4_in_15_0[9]   = s_logisimNet62;

  assign s_sel5_in_15_0[0]   = s_logisimNet315;
  assign s_sel5_in_15_0[1]   = s_logisimNet182;
  assign s_sel5_in_15_0[10]  = s_logisimNet241;
  assign s_sel5_in_15_0[11]  = s_logisimNet97;
  assign s_sel5_in_15_0[12]  = s_logisimNet235;
  assign s_sel5_in_15_0[13]  = s_logisimNet112;
  assign s_sel5_in_15_0[14]  = s_logisimNet130;
  assign s_sel5_in_15_0[15]  = s_logisimNet236;
  assign s_sel5_in_15_0[2]   = s_logisimNet67;
  assign s_sel5_in_15_0[3]   = s_logisimNet117;
  assign s_sel5_in_15_0[4]   = s_logisimNet186;
  assign s_sel5_in_15_0[5]   = s_logisimNet297;
  assign s_sel5_in_15_0[6]   = s_logisimNet81;
  assign s_sel5_in_15_0[7]   = s_logisimNet39;
  assign s_sel5_in_15_0[8]   = s_logisimNet83;
  assign s_sel5_in_15_0[9]   = s_logisimNet171;

  assign s_sel6_in_15_0[0]   = s_logisimNet143;
  assign s_sel6_in_15_0[1]   = s_logisimNet245;
  assign s_sel6_in_15_0[10]  = s_logisimNet177;
  assign s_sel6_in_15_0[11]  = s_logisimNet268;
  assign s_sel6_in_15_0[12]  = s_logisimNet259;
  assign s_sel6_in_15_0[13]  = s_logisimNet304;
  assign s_sel6_in_15_0[14]  = s_logisimNet232;
  assign s_sel6_in_15_0[15]  = s_logisimNet88;
  assign s_sel6_in_15_0[2]   = s_logisimNet335;
  assign s_sel6_in_15_0[3]   = s_logisimNet197;
  assign s_sel6_in_15_0[4]   = s_logisimNet204;
  assign s_sel6_in_15_0[5]   = s_logisimNet134;
  assign s_sel6_in_15_0[6]   = s_logisimNet254;
  assign s_sel6_in_15_0[7]   = s_logisimNet321;
  assign s_sel6_in_15_0[8]   = s_logisimNet215;
  assign s_sel6_in_15_0[9]   = s_logisimNet162;

  assign s_sel7_in_15_0[0]   = s_logisimNet228;
  assign s_sel7_in_15_0[1]   = s_logisimNet322;
  assign s_sel7_in_15_0[10]  = s_logisimNet288;
  assign s_sel7_in_15_0[11]  = s_logisimNet246;
  assign s_sel7_in_15_0[12]  = s_logisimNet336;
  assign s_sel7_in_15_0[13]  = s_logisimNet25;
  assign s_sel7_in_15_0[14]  = s_logisimNet56;
  assign s_sel7_in_15_0[15]  = s_logisimNet135;
  assign s_sel7_in_15_0[2]   = s_reg2_p_7;
  assign s_sel7_in_15_0[3]   = s_logisimNet313;
  assign s_sel7_in_15_0[4]   = s_logisimNet333;
  assign s_sel7_in_15_0[5]   = s_logisimNet190;
  assign s_sel7_in_15_0[6]   = s_logisimNet260;
  assign s_sel7_in_15_0[7]   = s_logisimNet219;
  assign s_sel7_in_15_0[8]   = s_logisimNet348;
  assign s_sel7_in_15_0[9]   = s_logisimNet270;

  assign s_sel8_in_15_0[0]   = s_logisimNet27;
  assign s_sel8_in_15_0[1]   = s_logisimNet195;
  assign s_sel8_in_15_0[10]  = s_logisimNet316;
  assign s_sel8_in_15_0[11]  = s_logisimNet103;
  assign s_sel8_in_15_0[12]  = s_logisimNet252;
  assign s_sel8_in_15_0[13]  = s_logisimNet123;
  assign s_sel8_in_15_0[14]  = s_logisimNet187;
  assign s_sel8_in_15_0[15]  = s_logisimNet298;
  assign s_sel8_in_15_0[2]   = s_logisimNet84;
  assign s_sel8_in_15_0[3]   = s_logisimNet172;
  assign s_sel8_in_15_0[4]   = s_logisimNet242;
  assign s_sel8_in_15_0[5]   = s_logisimNet164;
  assign s_sel8_in_15_0[6]   = s_logisimNet95;
  assign s_sel8_in_15_0[7]   = s_logisimNet73;
  assign s_sel8_in_15_0[8]   = s_logisimNet131;
  assign s_sel8_in_15_0[9]   = s_logisimNet225;

  assign s_sel9_in_15_0[0]  = s_logisimNet75;
  assign s_sel9_in_15_0[1]  = s_logisimNet311;
  assign s_sel9_in_15_0[10] = s_logisimNet337;
  assign s_sel9_in_15_0[11] = s_logisimNet198;
  assign s_sel9_in_15_0[12] = s_logisimNet57;
  assign s_sel9_in_15_0[13] = s_logisimNet217;
  assign s_sel9_in_15_0[14] = s_logisimNet201;
  assign s_sel9_in_15_0[15] = s_logisimNet323;
  assign s_sel9_in_15_0[2]  = s_logisimNet167;
  assign s_sel9_in_15_0[3]  = s_logisimNet191;
  assign s_sel9_in_15_0[4]  = s_logisimNet261;
  assign s_sel9_in_15_0[5]  = s_logisimNet271;
  assign s_sel9_in_15_0[6]  = s_logisimNet183;
  assign s_sel9_in_15_0[7]  = s_logisimNet89;
  assign s_sel9_in_15_0[8]  = s_logisimNet151;
  assign s_sel9_in_15_0[9]  = s_logisimNet247;


  assign s_reg2_p_7          = s_reg2_p_15_0[7];
  assign s_reg15_r7_3        = s_reg15_r7_15_0[3];
  assign s_reg3_b_15         = s_reg3_b_15_0[15];
  assign s_logisimNet103     = s_logisimBus118[8];
  assign s_logisimNet104     = s_reg4_l_15_0[2];
  assign s_logisimNet105     = s_reg8_sts_15_0[15];
  assign s_logisimNet112     = s_reg13_r5_15_0[5];
  assign s_logisimNet113     = s_reg14_r6_15_0[15];
  assign s_logisimNet114     = s_reg2_p_15_0[15];
  assign s_logisimNet115     = s_reg10_r2_15_0[4];
  assign s_logisimNet117     = s_reg3_b_15_0[5];
  assign s_logisimNet122     = s_reg2_p_15_0[1];
  assign s_logisimNet123     = s_reg13_r5_15_0[8];
  assign s_logisimNet124     = s_reg14_r6_15_0[2];
  assign s_logisimNet126     = s_reg12_r4_15_0[1];
  assign s_logisimNet127     = s_reg15_r7_15_0[1];
  assign s_logisimNet128     = s_reg6_t_15_0[15];
  assign s_logisimNet130     = s_reg14_r6_15_0[5];
  assign s_logisimNet131     = s_reg8_sts_15_0[8];
  assign s_logisimNet132     = s_reg10_r2_15_0[11];
  assign s_logisimNet134     = s_reg5_a_15_0[6];
  assign s_logisimNet135     = s_reg15_r7_15_0[7];
  assign s_logisimNet136     = s_reg5_a_15_0[13];
  assign s_logisimNet137     = s_reg9_r1_15_0[14];
  assign s_logisimNet138     = s_reg15_r7_15_0[4];
  assign s_logisimNet139     = s_reg1_d_15_0[14];
  assign s_logisimNet140     = s_reg6_t_15_0[2];
  assign s_logisimNet143     = s_reg0_z_15_0[6];
  assign s_logisimNet144     = s_reg4_l_15_0[14];
  assign s_logisimNet147     = s_reg9_r1_15_0[15];
  assign s_logisimNet148     = s_reg13_r5_15_0[0];
  assign s_logisimNet150     = s_logisimBus118[2];
  assign s_logisimNet151     = s_reg8_sts_15_0[9];
  assign s_logisimNet152     = s_reg9_r1_15_0[3];
  assign s_logisimNet153     = s_reg0_z_15_0[3];
  assign s_logisimNet156     = s_reg4_l_15_0[15];
  assign s_logisimNet158     = s_reg13_r5_15_0[1];
  assign s_logisimNet159     = s_reg5_a_15_0[4];
  assign s_logisimNet16      = s_reg5_a_15_0[0];
  assign s_logisimNet160     = s_reg3_b_15_0[12];
  assign s_logisimNet161     = s_reg8_sts_15_0[12];
  assign s_logisimNet162     = s_reg9_r1_15_0[6];
  assign s_logisimNet164     = s_reg5_a_15_0[8];
  assign s_logisimNet165     = s_reg10_r2_15_0[3];
  assign s_logisimNet166     = s_reg13_r5_15_0[15];
  assign s_logisimNet167     = s_reg2_p_15_0[9];
  assign s_logisimNet171     = s_reg9_r1_15_0[5];
  assign s_logisimNet172     = s_reg3_b_15_0[8];
  assign s_logisimNet173     = s_reg15_r7_15_0[10];
  assign s_logisimNet174     = s_reg5_a_15_0[11];
  assign s_logisimNet175     = s_reg0_z_15_0[13];
  assign s_logisimNet176     = s_reg8_sts_15_0[1];
  assign s_logisimNet177     = s_reg10_r2_15_0[6];
  assign s_logisimNet178     = s_reg7_x_15_0[0];
  assign s_logisimNet179     = s_reg14_r6_15_0[12];
  assign s_logisimNet18      = s_reg8_sts_15_0[4];
  assign s_logisimNet180     = s_reg2_p_15_0[12];
  assign s_logisimNet181     = s_reg15_r7_15_0[11];
  assign s_logisimNet182     = s_reg1_d_15_0[5];
  assign s_logisimNet183     = s_reg6_t_15_0[9];
  assign s_logisimNet184     = s_reg3_b_15_0[3];
  assign s_logisimNet186     = s_reg4_l_15_0[5];
  assign s_logisimNet187     = s_reg14_r6_15_0[8];
  assign s_logisimNet188     = s_reg0_z_15_0[11];
  assign s_logisimNet190     = s_reg5_a_15_0[7];
  assign s_logisimNet191     = s_reg3_b_15_0[9];
  assign s_logisimNet192     = s_reg0_z_15_0[0];
  assign s_logisimNet193     = s_reg12_r4_15_0[14];
  assign s_logisimNet194     = s_reg15_r7_15_0[14];
  assign s_logisimNet195     = s_reg1_d_15_0[8];
  assign s_logisimNet196     = s_reg6_t_15_0[12];
  assign s_logisimNet197     = s_reg3_b_15_0[6];
  assign s_logisimNet198     = s_logisimBus118[9];
  assign s_logisimNet199     = s_reg4_l_15_0[3];
  assign s_logisimNet201     = s_reg14_r6_15_0[9];
  assign s_logisimNet202     = s_reg10_r2_15_0[14];
  assign s_logisimNet203     = s_logisimBus118[12];
  assign s_logisimNet204     = s_reg4_l_15_0[6];
  assign s_logisimNet205     = s_reg9_r1_15_0[13];
  assign s_logisimNet206     = s_reg8_sts_15_0[3];
  assign s_logisimNet207     = s_reg10_r2_15_0[15];
  assign s_logisimNet209     = s_reg3_b_15_0[1];
  assign s_logisimNet21      = s_reg2_p_15_0[4];
  assign s_logisimNet210     = s_logisimBus118[4];
  assign s_logisimNet211     = s_reg7_x_15_0[2];
  assign s_logisimNet212     = s_reg9_r1_15_0[12];
  assign s_logisimNet214     = s_reg5_a_15_0[2];
  assign s_logisimNet215     = s_reg8_sts_15_0[6];
  assign s_logisimNet216     = s_reg10_r2_15_0[13];
  assign s_logisimNet217     = s_reg13_r5_15_0[9];
  assign s_logisimNet218     = s_reg14_r6_15_0[3];
  assign s_logisimNet219     = s_reg7_x_15_0[7];
  assign s_logisimNet22      = s_reg2_p_15_0[10];
  assign s_logisimNet220     = s_reg2_p_15_0[3];
  assign s_logisimNet221     = s_reg6_t_15_0[4];
  assign s_logisimNet222     = s_reg2_p_15_0[2];
  assign s_logisimNet224     = s_reg4_l_15_0[12];
  assign s_logisimNet225     = s_reg9_r1_15_0[8];
  assign s_logisimNet226     = s_reg5_a_15_0[10];
  assign s_logisimNet227     = s_logisimBus118[11];
  assign s_logisimNet228     = s_reg0_z_15_0[7];
  assign s_logisimNet229     = s_reg14_r6_15_0[1];
  assign s_logisimNet230     = s_reg10_r2_15_0[0];
  assign s_logisimNet231     = s_reg13_r5_15_0[12];
  assign s_logisimNet232     = s_reg14_r6_15_0[6];
  assign s_logisimNet233     = s_reg7_x_15_0[10];
  assign s_logisimNet235     = s_reg12_r4_15_0[5];
  assign s_logisimNet236     = s_reg15_r7_15_0[5];
  assign s_logisimNet237     = s_reg1_d_15_0[15];
  assign s_logisimNet238     = s_reg6_t_15_0[3];
  assign s_logisimNet239     = s_reg3_b_15_0[13];
  assign s_logisimNet241     = s_reg10_r2_15_0[5];
  assign s_logisimNet242     = s_reg4_l_15_0[8];
  assign s_logisimNet244     = s_reg6_t_15_0[11];
  assign s_logisimNet245     = s_reg1_d_15_0[6];
  assign s_logisimNet246     = s_logisimBus118[7];
  assign s_logisimNet247     = s_reg9_r1_15_0[9];
  assign s_logisimNet248     = s_reg1_d_15_0[13];
  assign s_logisimNet249     = s_reg5_a_15_0[14];
  assign s_logisimNet25      = s_reg13_r5_15_0[7];
  assign s_logisimNet251     = s_reg0_z_15_0[10];
  assign s_logisimNet252     = s_reg12_r4_15_0[8];
  assign s_logisimNet253     = s_reg1_d_15_0[2];
  assign s_logisimNet254     = s_reg6_t_15_0[6];
  assign s_logisimNet255     = s_reg3_b_15_0[0];
  assign s_logisimNet256     = s_logisimBus118[3];
  assign s_logisimNet257     = s_reg4_l_15_0[13];
  assign s_logisimNet259     = s_reg12_r4_15_0[6];
  assign s_logisimNet26      = s_reg7_x_15_0[14];
  assign s_logisimNet260     = s_reg6_t_15_0[7];
  assign s_logisimNet261     = s_reg4_l_15_0[9];
  assign s_logisimNet262     = s_reg12_r4_15_0[13];
  assign s_logisimNet263     = s_reg0_z_15_0[14];
  assign s_logisimNet265     = s_reg1_d_15_0[3];
  assign s_logisimNet266     = s_reg5_a_15_0[15];
  assign s_logisimNet267     = s_reg9_r1_15_0[0];
  assign s_logisimNet268     = s_logisimBus118[6];
  assign s_logisimNet269     = s_reg8_sts_15_0[13];
  assign s_logisimNet27      = s_reg0_z_15_0[8];
  assign s_logisimNet270     = s_reg9_r1_15_0[7];
  assign s_logisimNet271     = s_reg5_a_15_0[9];
  assign s_logisimNet273     = s_reg12_r4_15_0[3];
  assign s_logisimNet275     = s_reg0_z_15_0[15];
  assign s_logisimNet277     = s_reg1_d_15_0[4];
  assign s_logisimNet278     = s_reg13_r5_15_0[2];
  assign s_logisimNet28      = s_reg8_sts_15_0[11];
  assign s_logisimNet281     = s_reg15_r7_15_0[12];
  assign s_logisimNet284     = s_reg4_l_15_0[0];
  assign s_logisimNet285     = s_reg9_r1_15_0[10];
  assign s_logisimNet286     = s_reg5_a_15_0[12];
  assign s_logisimNet287     = s_reg8_sts_15_0[0];
  assign s_logisimNet288     = s_reg10_r2_15_0[7];
  assign s_logisimNet289     = s_reg13_r5_15_0[3];
  assign s_logisimNet29      = s_logisimBus118[1];
  assign s_logisimNet290     = s_reg14_r6_15_0[13];
  assign s_logisimNet291     = s_reg7_x_15_0[1];
  assign s_logisimNet292     = s_reg12_r4_15_0[4];
  assign s_logisimNet293     = s_reg8_sts_15_0[2];
  assign s_logisimNet295     = s_reg10_r2_15_0[12];
  assign s_logisimNet297     = s_reg5_a_15_0[5];
  assign s_logisimNet298     = s_reg15_r7_15_0[8];
  assign s_logisimNet299     = s_logisimBus118[10];
  assign s_logisimNet3       = s_reg7_x_15_0[11];
  assign s_logisimNet300     = s_reg1_d_15_0[11];
  assign s_logisimNet301     = s_reg0_z_15_0[1];
  assign s_logisimNet302     = s_reg4_l_15_0[1];
  assign s_logisimNet303     = s_reg10_r2_15_0[10];
  assign s_logisimNet304     = s_reg13_r5_15_0[6];
  assign s_logisimNet305     = s_reg7_x_15_0[4];
  assign s_logisimNet306     = s_reg14_r6_15_0[0];
  assign s_logisimNet307     = s_reg2_p_15_0[0];
  assign s_logisimNet309     = s_reg12_r4_15_0[15];
  assign s_logisimNet31      = s_reg3_b_15_0[4];
  assign s_logisimNet310     = s_reg15_r7_15_0[15];
  assign s_logisimNet311     = s_reg1_d_15_0[9];
  assign s_logisimNet312     = s_reg6_t_15_0[13];
  assign s_logisimNet313     = s_reg3_b_15_0[7];
  assign s_logisimNet315     = s_reg0_z_15_0[5];
  assign s_logisimNet316     = s_reg10_r2_15_0[8];
  assign s_logisimNet317     = s_reg6_t_15_0[10];
  assign s_logisimNet318     = s_reg12_r4_15_0[11];
  assign s_logisimNet321     = s_reg7_x_15_0[6];
  assign s_logisimNet322     = s_reg1_d_15_0[7];
  assign s_logisimNet323     = s_reg15_r7_15_0[9];
  assign s_logisimNet324     = s_reg7_x_15_0[13];
  assign s_logisimNet325     = s_logisimBus118[14];
  assign s_logisimNet326     = s_reg0_z_15_0[4];
  assign s_logisimNet327     = s_reg12_r4_15_0[2];
  assign s_logisimNet328     = s_reg15_r7_15_0[2];
  assign s_logisimNet329     = s_reg1_d_15_0[12];
  assign s_logisimNet330     = s_reg6_t_15_0[0];
  assign s_logisimNet331     = s_reg3_b_15_0[10];
  assign s_logisimNet332     = s_logisimBus118[13];
  assign s_logisimNet333     = s_reg4_l_15_0[7];
  assign s_logisimNet335     = s_reg2_p_15_0[6];
  assign s_logisimNet336     = s_reg12_r4_15_0[7];
  assign s_logisimNet337     = s_reg10_r2_15_0[9];
  assign s_logisimNet338     = s_reg2_p_15_0[13];
  assign s_logisimNet339     = s_reg6_t_15_0[14];
  assign s_logisimNet34      = s_reg7_x_15_0[15];
  assign s_logisimNet340     = s_reg7_x_15_0[3];
  assign s_logisimNet341     = s_logisimBus118[15];
  assign s_logisimNet343     = s_reg15_r7_15_0[0];
  assign s_logisimNet344     = s_logisimBus118[0];
  assign s_logisimNet345     = s_reg4_l_15_0[10];
  assign s_logisimNet346     = s_reg9_r1_15_0[1];
  assign s_logisimNet347     = s_reg5_a_15_0[3];
  assign s_logisimNet348     = s_reg8_sts_15_0[7];
  assign s_logisimNet35      = s_reg2_p_15_0[11];
  assign s_logisimNet36      = s_reg14_r6_15_0[4];
  assign s_logisimNet37      = s_reg12_r4_15_0[12];
  assign s_logisimNet39      = s_reg7_x_15_0[5];
  assign s_logisimNet4       = s_reg10_r2_15_0[1];
  assign s_logisimNet40      = s_reg13_r5_15_0[10];
  assign s_logisimNet41      = s_reg3_b_15_0[11];
  assign s_logisimNet43      = s_reg6_t_15_0[1];
  assign s_logisimNet45      = s_reg13_r5_15_0[4];
  assign s_logisimNet46      = s_reg2_p_15_0[14];
  assign s_logisimNet48      = s_reg8_sts_15_0[10];
  assign s_logisimNet49      = s_reg14_r6_15_0[11];
  assign s_logisimNet53      = s_reg1_d_15_0[10];
  assign s_logisimNet56      = s_reg14_r6_15_0[7];
  assign s_logisimNet57      = s_reg12_r4_15_0[9];
  assign s_logisimNet58      = s_reg8_sts_15_0[14];
  assign s_logisimNet59      = s_reg1_d_15_0[0];
  assign s_logisimNet61      = s_reg5_a_15_0[1];
  assign s_logisimNet62      = s_reg9_r1_15_0[4];
  assign s_logisimNet64      = s_reg12_r4_15_0[0];
  assign s_logisimNet65      = s_reg9_r1_15_0[2];
  assign s_logisimNet66      = s_reg13_r5_15_0[11];
  assign s_logisimNet67      = s_reg2_p_15_0[5];
  assign s_logisimNet68      = s_reg4_l_15_0[4];
  assign s_logisimNet69      = s_reg0_z_15_0[2];
  assign s_logisimNet73      = s_reg7_x_15_0[8];
  assign s_logisimNet74      = s_reg9_r1_15_0[11];
  assign s_logisimNet75      = s_reg0_z_15_0[9];
  assign s_logisimNet76      = s_reg10_r2_15_0[2];
  assign s_logisimNet77      = s_reg13_r5_15_0[14];
  assign s_logisimNet78      = s_reg7_x_15_0[12];
  assign s_logisimNet8       = s_reg13_r5_15_0[13];
  assign s_logisimNet80      = s_reg1_d_15_0[1];
  assign s_logisimNet81      = s_reg6_t_15_0[5];
  assign s_logisimNet83      = s_reg8_sts_15_0[5];
  assign s_logisimNet84      = s_reg2_p_15_0[8];
  assign s_logisimNet85      = s_reg14_r6_15_0[10];
  assign s_logisimNet86      = s_reg4_l_15_0[11];
  assign s_logisimNet88      = s_reg15_r7_15_0[6];
  assign s_logisimNet89      = s_reg7_x_15_0[9];
  assign s_logisimNet91      = s_reg15_r7_15_0[13];
  assign s_logisimNet92      = s_reg3_b_15_0[14];
  assign s_logisimNet93      = s_reg0_z_15_0[12];
  assign s_logisimNet94      = s_reg12_r4_15_0[10];
  assign s_logisimNet95      = s_reg6_t_15_0[8];
  assign s_logisimNet96      = s_reg3_b_15_0[2];
  assign s_logisimNet97      = s_logisimBus118[5];
  assign s_logisimNet99      = s_reg14_r6_15_0[14];

  /*******************************************************************************
   ** Here all input connections are defined                                     **
   *******************************************************************************/
  assign s_rb_15_0[15:0]     = RB_15_0;
  assign s_ncla_15_0[15:0]   = NLCA_15_0;
  assign s_wr_15_0[15:0]     = WR_15_0;
  assign s_eb_15_0[15:0]     = EB_15_0;
  assign s_ea_15_0[15:0]     = EA_15_0;
  assign s_xfetch_n          = XFETCHN;
  assign s_aluclk_n          = ~ALUCLK;
  assign s_aluclk            = ALUCLK;

  /*******************************************************************************
   ** Here all output connections are defined                                    **
   *******************************************************************************/
  assign A_15_0              = s_a_15_0_out[15:0];
  assign BR_15_0             = s_br_15_0_out[15:0];
  assign B_15_0              = s_b_15_0_out[15:0];
  assign PR_15_0             = s_pr_15_0_out[15:0];
  assign XR_15_0             = s_xr_15_0_out[15:0];

  /*******************************************************************************
   ** Here all sub-circuits are defined                                          **
   *******************************************************************************/

  // Register 0 (Z)
  CGA_WRF_RBLOCK_DR16 Z_REG_0 (
      .ALUCLK(s_aluclk),
      .RB_15_0(s_rb_15_0[15:0]),
      .REG_15_0(s_reg0_z_15_0[15:0]),
      .WR(s_wr_15_0[0])
  );

  // Regster 1 (D)
  CGA_WRF_RBLOCK_DR16 D_REG_1 (
      .ALUCLK(s_aluclk),
      .RB_15_0(s_rb_15_0[15:0]),
      .REG_15_0(s_reg1_d_15_0[15:0]),
      .WR(s_wr_15_0[1])
  );

  // Register 2 (P)
  CGA_WRF_RBLOCK_PREG P_REG_2 (
      .ALUCLK(s_aluclk),
      .ALUCLKN(s_aluclk_n),
      .NLCA_15_0(s_ncla_15_0[15:0]),
      .PR_15_0(s_pr_15_0_out[15:0]),
      .P_15_0(s_reg2_p_15_0[15:0]),
      .RB_15_0(s_rb_15_0[15:0]),
      .WR2(s_wr_15_0[2]),
      .XFETCHN(s_xfetch_n)
  );

  // Register 3 (B)
  CGA_WRF_RBLOCK_LR16 B_REG_3 (
      .ALUCLK(s_aluclk),
      .LR_15_0(s_br_15_0_out[15:0]),
      .RB_15_0(s_rb_15_0[15:0]),
      .R_15_0(s_reg3_b_15_0[15:0]),
      .WR(s_wr_15_0[3])
  );

  // Register 4 (L)
  CGA_WRF_RBLOCK_DR16 L_REG_4 (
      .ALUCLK(s_aluclk),
      .RB_15_0(s_rb_15_0[15:0]),
      .REG_15_0(s_reg4_l_15_0[15:0]),
      .WR(s_wr_15_0[4])
  );

  // Register 5 (A)
  CGA_WRF_RBLOCK_DR16 A_REG_5 (
      .ALUCLK(s_aluclk),
      .RB_15_0(s_rb_15_0[15:0]),
      .REG_15_0(s_reg5_a_15_0[15:0]),
      .WR(s_wr_15_0[5])
  );

  // Register 6 (T)
  CGA_WRF_RBLOCK_DR16 T_REG_6 (
      .ALUCLK(s_aluclk),
      .RB_15_0(s_rb_15_0[15:0]),
      .REG_15_0(s_reg6_t_15_0[15:0]),
      .WR(s_wr_15_0[6])
  );

  // Register 7 (X)
  CGA_WRF_RBLOCK_LR16 X_REG_7 (
      .ALUCLK(s_aluclk),
      .LR_15_0(s_xr_15_0_out[15:0]),
      .RB_15_0(s_rb_15_0[15:0]),
      .R_15_0(s_reg7_x_15_0[15:0]),
      .WR(s_wr_15_0[7])
  );

  // Register 8 (STS)
  CGA_WRF_RBLOCK_DR16 STS_REG_8 (
      .ALUCLK(s_aluclk),
      .RB_15_0(s_rb_15_0[15:0]),
      .REG_15_0(s_reg8_sts_15_0[15:0]),
      .WR(s_wr_15_0[8])
  );

  // Register 9 (R1) (internal registers)
  CGA_WRF_RBLOCK_DR16 R1_REG_9 (
      .ALUCLK(s_aluclk),
      .RB_15_0(s_rb_15_0[15:0]),
      .REG_15_0(s_reg9_r1_15_0[15:0]),
      .WR(s_wr_15_0[9])
  );

  // Register 10 (R2)
  CGA_WRF_RBLOCK_DR16 R2_REG_10 (
      .ALUCLK(s_aluclk),
      .RB_15_0(s_rb_15_0[15:0]),
      .REG_15_0(s_reg10_r2_15_0[15:0]),
      .WR(s_wr_15_0[10])
  );

  // Register 11 (R3)
  CGA_WRF_RBLOCK_DR16 R3_REG_11 (
      .ALUCLK(s_aluclk),
      .RB_15_0(s_rb_15_0[15:0]),
      .REG_15_0(s_logisimBus118[15:0]),
      .WR(s_wr_15_0[11])
  );

  // Register 12 (R4)
  CGA_WRF_RBLOCK_DR16 R4_REG_12 (
      .ALUCLK(s_aluclk),
      .RB_15_0(s_rb_15_0[15:0]),
      .REG_15_0(s_reg12_r4_15_0[15:0]),
      .WR(s_wr_15_0[12])
  );

  // Register 13 (R5)
  CGA_WRF_RBLOCK_DR16 R5_REG_13 (
      .ALUCLK(s_aluclk),
      .RB_15_0(s_rb_15_0[15:0]),
      .REG_15_0(s_reg13_r5_15_0[15:0]),
      .WR(s_wr_15_0[13])
  );

  // Register 14 (R6)
  CGA_WRF_RBLOCK_DR16 R6_REG_14 (
      .ALUCLK(s_aluclk),
      .RB_15_0(s_rb_15_0[15:0]),
      .REG_15_0(s_reg14_r6_15_0[15:0]),
      .WR(s_wr_15_0[14])
  );

  // Register 15 (R7)
  CGA_WRF_RBLOCK_DR16 R7_REG_15 (
      .ALUCLK(s_aluclk),
      .RB_15_0(s_rb_15_0[15:0]),
      .REG_15_0(s_reg15_r7_15_0[15:0]),
      .WR(s_wr_15_0[15])
  );

  // Selector 0
  CGA_WRF_RBLOCK_SEL16 SEL_0 (
      .EA_15_0(s_ea_15_0[15:0]),
      .EB_15_0(s_eb_15_0[15:0]),
      .SI_15_0(s_sel0_in_15_0[15:0]),
      .PA(s_a_15_0_out[0]),
      .PB(s_b_15_0_out[0])
  );

  CGA_WRF_RBLOCK_SEL16 SEL_1 (
      .EA_15_0(s_ea_15_0[15:0]),
      .EB_15_0(s_eb_15_0[15:0]),
      .PA(s_a_15_0_out[1]),
      .PB(s_b_15_0_out[1]),
      .SI_15_0(s_sel1_in_15_0[15:0])
  );

  CGA_WRF_RBLOCK_SEL16 SEL_2 (
      .EA_15_0(s_ea_15_0[15:0]),
      .EB_15_0(s_eb_15_0[15:0]),
      .PA(s_a_15_0_out[2]),
      .PB(s_b_15_0_out[2]),
      .SI_15_0(s_sel2_in_15_0[15:0])
  );

  CGA_WRF_RBLOCK_SEL16 SEL_3 (
      .EA_15_0(s_ea_15_0[15:0]),
      .EB_15_0(s_eb_15_0[15:0]),
      .PA(s_a_15_0_out[3]),
      .PB(s_b_15_0_out[3]),
      .SI_15_0(s_sel3_in_15_0[15:0])
  );

  CGA_WRF_RBLOCK_SEL16 SEL_4 (
      .EA_15_0(s_ea_15_0[15:0]),
      .EB_15_0(s_eb_15_0[15:0]),
      .PA(s_a_15_0_out[4]),
      .PB(s_b_15_0_out[4]),
      .SI_15_0(s_sel4_in_15_0[15:0])
  );

  CGA_WRF_RBLOCK_SEL16 SEL_5 (
      .EA_15_0(s_ea_15_0[15:0]),
      .EB_15_0(s_eb_15_0[15:0]),
      .PA(s_a_15_0_out[5]),
      .PB(s_b_15_0_out[5]),
      .SI_15_0(s_sel5_in_15_0[15:0])
  );

  CGA_WRF_RBLOCK_SEL16 SEL_6 (
      .EA_15_0(s_ea_15_0[15:0]),
      .EB_15_0(s_eb_15_0[15:0]),
      .PA(s_a_15_0_out[6]),
      .PB(s_b_15_0_out[6]),
      .SI_15_0(s_sel6_in_15_0[15:0])
  );

  CGA_WRF_RBLOCK_SEL16 SEL_7 (
      .EA_15_0(s_ea_15_0[15:0]),
      .EB_15_0(s_eb_15_0[15:0]),
      .PA(s_a_15_0_out[7]),
      .PB(s_b_15_0_out[7]),
      .SI_15_0(s_sel7_in_15_0[15:0])
  );

  CGA_WRF_RBLOCK_SEL16 SEL_8 (
      .EA_15_0(s_ea_15_0[15:0]),
      .EB_15_0(s_eb_15_0[15:0]),
      .PA(s_a_15_0_out[8]),
      .PB(s_b_15_0_out[8]),
      .SI_15_0(s_sel8_in_15_0[15:0])
  );

  CGA_WRF_RBLOCK_SEL16 SEL_9 (
      .EA_15_0(s_ea_15_0[15:0]),
      .EB_15_0(s_eb_15_0[15:0]),
      .PA(s_a_15_0_out[9]),
      .PB(s_b_15_0_out[9]),
      .SI_15_0(s_sel9_in_15_0[15:0])
  );

  CGA_WRF_RBLOCK_SEL16 SEL_10 (
      .EA_15_0(s_ea_15_0[15:0]),
      .EB_15_0(s_eb_15_0[15:0]),
      .PA(s_a_15_0_out[10]),
      .PB(s_b_15_0_out[10]),
      .SI_15_0(s_sel10_in_15_0[15:0])
  );

  CGA_WRF_RBLOCK_SEL16 SEL_11 (
      .EA_15_0(s_ea_15_0[15:0]),
      .EB_15_0(s_eb_15_0[15:0]),
      .PA(s_a_15_0_out[11]),
      .PB(s_b_15_0_out[11]),
      .SI_15_0(s_sel11_in_15_0[15:0])
  );

  CGA_WRF_RBLOCK_SEL16 SEL_12 (
      .EA_15_0(s_ea_15_0[15:0]),
      .EB_15_0(s_eb_15_0[15:0]),
      .PA(s_a_15_0_out[12]),
      .PB(s_b_15_0_out[12]),
      .SI_15_0(s_sel12_in_15_0[15:0])
  );

  CGA_WRF_RBLOCK_SEL16 SEL_13 (
      .EA_15_0(s_ea_15_0[15:0]),
      .EB_15_0(s_eb_15_0[15:0]),
      .PA(s_a_15_0_out[13]),
      .PB(s_b_15_0_out[13]),
      .SI_15_0(s_sel13_in_15_0[15:0])
  );

  CGA_WRF_RBLOCK_SEL16 SEL_14 (
      .EA_15_0(s_ea_15_0[15:0]),
      .EB_15_0(s_eb_15_0[15:0]),
      .PA(s_a_15_0_out[14]),
      .PB(s_b_15_0_out[14]),
      .SI_15_0(s_sel14_in_15_0[15:0])
  );

  CGA_WRF_RBLOCK_SEL16 SEL_15 (
      .EA_15_0(s_ea_15_0[15:0]),
      .EB_15_0(s_eb_15_0[15:0]),
      .PA(s_a_15_0_out[15]),
      .PB(s_b_15_0_out[15]),
      .SI_15_0(s_sel15_in_15_0[15:0])
  );

endmodule

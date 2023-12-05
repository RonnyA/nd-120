/******************************************************************************
 ** Logisim-evolution goes FPGA automatic generated Verilog code             **
 ** https://github.com/logisim-evolution/                                    **
 **                                                                          **
 ** Component : CGA_MIC                                                      **
 **                                                                          **
 *****************************************************************************/

module CGA_MIC( ACONDN,
                ALUCLK,
                CD_15_0,
                CFETCH,
                CLFFN,
                COND,
                CRY,
                CSALUI8,
                CSBIT20,
                CSBIT_15_0,
                CSCOND,
                CSECOND,
                CSLOOP,
                CSMIS0,
                CSRASEL_1_0,
                CSRBSEL_1_0,
                CSRB_3_0,
                CSTS_6_3,
                CSVECT,
                CSXRF3,
                DEEP,
                DZD,
                EWCAN,
                F11,
                F15,
                ILCSN,
                IRQ,
                LAA_3_0,
                LBA_3_0,
                LCZ,
                LCZN,
                LDIRV,
                LDLCN,
                LWCAN,
                MAPN,
                MA_12_0,
                MCLK,
                MI,
                MRN,
                OOD,
                OVF,
                PIL_3_0,
                PN,
                RESTR,
                RF_1_0,
                SC_6_3,
                SPARE,
                STP,
                TN,
                TRAPN,
                TVEC_3_0,
                UPN,
                WCSN,
                ZF );

   /*******************************************************************************
   ** The inputs are defined here                                                **
   *******************************************************************************/
   input        ALUCLK;
   input [15:0] CD_15_0;
   input        CFETCH;
   input        CLFFN;
   input        CRY;
   input        CSALUI8;
   input        CSBIT20;
   input [15:0] CSBIT_15_0;
   input        CSCOND;
   input        CSECOND;
   input        CSLOOP;
   input        CSMIS0;
   input [1:0]  CSRASEL_1_0;
   input [1:0]  CSRBSEL_1_0;
   input [3:0]  CSRB_3_0;
   input [3:0]  CSTS_6_3;
   input        CSVECT;
   input        CSXRF3;
   input        EWCAN;
   input        F11;
   input        F15;
   input        ILCSN;
   input        IRQ;
   input        LCZ;
   input        LDIRV;
   input        LDLCN;
   input        LWCAN;
   input        MAPN;
   input        MCLK;
   input        MI;
   input        MRN;
   input        OVF;
   input [3:0]  PIL_3_0;
   input        RESTR;
   input        SPARE;
   input        STP;
   input        TRAPN;
   input [3:0]  TVEC_3_0;
   input        ZF;

   /*******************************************************************************
   ** The outputs are defined here                                               **
   *******************************************************************************/
   output        ACONDN;
   output        COND;
   output        DEEP;
   output        DZD;
   output [3:0]  LAA_3_0;
   output [3:0]  LBA_3_0;
   output        LCZN;
   output [12:0] MA_12_0;
   output        OOD;
   output        PN;
   output [1:0]  RF_1_0;
   output [3:0]  SC_6_3;
   output        TN;
   output        UPN;
   output        WCSN;

   /*******************************************************************************
   ** The wires are defined here                                                 **
   *******************************************************************************/
   wire [12:0] s_logisimBus121;
   wire [3:0]  s_logisimBus129;
   wire [1:0]  s_logisimBus141;
   wire [1:0]  s_logisimBus145;
   wire [15:0] s_logisimBus150;
   wire [1:0]  s_logisimBus155;
   wire [12:0] s_logisimBus161;
   wire [3:0]  s_logisimBus178;
   wire [6:0]  s_logisimBus196;
   wire [15:0] s_logisimBus20;
   wire [3:0]  s_logisimBus202;
   wire [3:0]  s_logisimBus205;
   wire [12:0] s_logisimBus21;
   wire [1:0]  s_logisimBus217;
   wire [3:0]  s_logisimBus223;
   wire [3:0]  s_logisimBus226;
   wire [3:0]  s_logisimBus232;
   wire [3:0]  s_logisimBus233;
   wire [3:0]  s_logisimBus237;
   wire [3:0]  s_logisimBus241;
   wire [3:0]  s_logisimBus252;
   wire [12:0] s_logisimBus32;
   wire [3:0]  s_logisimBus41;
   wire [12:0] s_logisimBus57;
   wire [3:0]  s_logisimBus6;
   wire [3:0]  s_logisimBus73;
   wire [12:0] s_logisimBus77;
   wire [11:0] s_logisimBus85;
   wire [7:0]  s_logisimBus98;
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
   wire        s_logisimNet142;
   wire        s_logisimNet143;
   wire        s_logisimNet144;
   wire        s_logisimNet146;
   wire        s_logisimNet147;
   wire        s_logisimNet148;
   wire        s_logisimNet149;
   wire        s_logisimNet15;
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
   wire        s_logisimNet162;
   wire        s_logisimNet163;
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
   wire        s_logisimNet189;
   wire        s_logisimNet19;
   wire        s_logisimNet190;
   wire        s_logisimNet191;
   wire        s_logisimNet192;
   wire        s_logisimNet193;
   wire        s_logisimNet194;
   wire        s_logisimNet195;
   wire        s_logisimNet197;
   wire        s_logisimNet198;
   wire        s_logisimNet199;
   wire        s_logisimNet2;
   wire        s_logisimNet200;
   wire        s_logisimNet201;
   wire        s_logisimNet203;
   wire        s_logisimNet204;
   wire        s_logisimNet206;
   wire        s_logisimNet207;
   wire        s_logisimNet208;
   wire        s_logisimNet209;
   wire        s_logisimNet210;
   wire        s_logisimNet211;
   wire        s_logisimNet212;
   wire        s_logisimNet213;
   wire        s_logisimNet214;
   wire        s_logisimNet215;
   wire        s_logisimNet216;
   wire        s_logisimNet218;
   wire        s_logisimNet219;
   wire        s_logisimNet22;
   wire        s_logisimNet220;
   wire        s_logisimNet221;
   wire        s_logisimNet222;
   wire        s_logisimNet224;
   wire        s_logisimNet225;
   wire        s_logisimNet227;
   wire        s_logisimNet228;
   wire        s_logisimNet229;
   wire        s_logisimNet23;
   wire        s_logisimNet230;
   wire        s_logisimNet231;
   wire        s_logisimNet234;
   wire        s_logisimNet235;
   wire        s_logisimNet236;
   wire        s_logisimNet238;
   wire        s_logisimNet239;
   wire        s_logisimNet24;
   wire        s_logisimNet240;
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
   wire        s_logisimNet253;
   wire        s_logisimNet254;
   wire        s_logisimNet255;
   wire        s_logisimNet26;
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
   wire        s_logisimNet37;
   wire        s_logisimNet38;
   wire        s_logisimNet39;
   wire        s_logisimNet4;
   wire        s_logisimNet40;
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
   wire        s_logisimNet51;
   wire        s_logisimNet52;
   wire        s_logisimNet53;
   wire        s_logisimNet54;
   wire        s_logisimNet55;
   wire        s_logisimNet56;
   wire        s_logisimNet58;
   wire        s_logisimNet59;
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
   wire        s_logisimNet72;
   wire        s_logisimNet74;
   wire        s_logisimNet75;
   wire        s_logisimNet76;
   wire        s_logisimNet78;
   wire        s_logisimNet79;
   wire        s_logisimNet8;
   wire        s_logisimNet80;
   wire        s_logisimNet81;
   wire        s_logisimNet82;
   wire        s_logisimNet83;
   wire        s_logisimNet84;
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
   wire        s_logisimNet99;

   /*******************************************************************************
   ** The module functionality is described here                                 **
   *******************************************************************************/

   /*******************************************************************************
   ** Here all wiring is defined                                                 **
   *******************************************************************************/
   assign s_logisimBus232[0] = s_logisimNet76;
   assign s_logisimBus232[1] = s_logisimNet181;
   assign s_logisimBus232[2] = s_logisimNet109;
   assign s_logisimBus232[3] = s_logisimNet142;
   assign s_logisimBus252[0] = s_logisimNet243;
   assign s_logisimBus252[1] = s_logisimNet82;
   assign s_logisimBus252[2] = s_logisimNet177;
   assign s_logisimBus252[3] = s_logisimNet229;
   assign s_logisimBus85[0]  = s_logisimNet76;
   assign s_logisimBus85[10] = s_logisimNet46;
   assign s_logisimBus85[11] = s_logisimNet158;
   assign s_logisimBus85[1]  = s_logisimNet181;
   assign s_logisimBus85[2]  = s_logisimNet109;
   assign s_logisimBus85[3]  = s_logisimNet142;
   assign s_logisimBus85[4]  = s_logisimNet108;
   assign s_logisimBus85[5]  = s_logisimNet189;
   assign s_logisimBus85[6]  = s_logisimNet240;
   assign s_logisimBus85[7]  = s_logisimNet79;
   assign s_logisimBus85[8]  = s_logisimNet175;
   assign s_logisimBus85[9]  = s_logisimNet227;
   assign s_logisimNet108    = s_logisimBus150[4];
   assign s_logisimNet109    = s_logisimBus150[2];
   assign s_logisimNet142    = s_logisimBus150[3];
   assign s_logisimNet158    = s_logisimBus150[11];
   assign s_logisimNet175    = s_logisimBus150[8];
   assign s_logisimNet177    = s_logisimBus150[14];
   assign s_logisimNet181    = s_logisimBus150[1];
   assign s_logisimNet189    = s_logisimBus150[5];
   assign s_logisimNet227    = s_logisimBus150[9];
   assign s_logisimNet229    = s_logisimBus150[15];
   assign s_logisimNet240    = s_logisimBus150[6];
   assign s_logisimNet243    = s_logisimBus150[12];
   assign s_logisimNet46     = s_logisimBus150[10];
   assign s_logisimNet76     = s_logisimBus150[0];
   assign s_logisimNet79     = s_logisimBus150[7];
   assign s_logisimNet82     = s_logisimBus150[13];

   /*******************************************************************************
   ** Here all input connections are defined                                     **
   *******************************************************************************/
   assign s_logisimBus129[3:0]  = CSTS_6_3;
   assign s_logisimBus141[1:0]  = CSRASEL_1_0;
   assign s_logisimBus145[1:0]  = CSRBSEL_1_0;
   assign s_logisimBus150[15:0] = CSBIT_15_0;
   assign s_logisimBus205[3:0]  = PIL_3_0;
   assign s_logisimBus20[15:0]  = CD_15_0;
   assign s_logisimBus226[3:0]  = CSRB_3_0;
   assign s_logisimBus237[3:0]  = TVEC_3_0;
   assign s_logisimNet102       = CSECOND;
   assign s_logisimNet115       = LCZ;
   assign s_logisimNet116       = EWCAN;
   assign s_logisimNet123       = ALUCLK;
   assign s_logisimNet127       = CSXRF3;
   assign s_logisimNet132       = CLFFN;
   assign s_logisimNet146       = F15;
   assign s_logisimNet157       = LDLCN;
   assign s_logisimNet164       = OVF;
   assign s_logisimNet170       = MAPN;
   assign s_logisimNet174       = MCLK;
   assign s_logisimNet185       = CSBIT20;
   assign s_logisimNet193       = CSMIS0;
   assign s_logisimNet207       = CSCOND;
   assign s_logisimNet220       = CRY;
   assign s_logisimNet231       = SPARE;
   assign s_logisimNet249       = RESTR;
   assign s_logisimNet254       = STP;
   assign s_logisimNet255       = ILCSN;
   assign s_logisimNet26        = ZF;
   assign s_logisimNet27        = F11;
   assign s_logisimNet44        = CSALUI8;
   assign s_logisimNet53        = MI;
   assign s_logisimNet56        = MRN;
   assign s_logisimNet69        = TRAPN;
   assign s_logisimNet70        = CSLOOP;
   assign s_logisimNet8         = LDIRV;
   assign s_logisimNet81        = LWCAN;
   assign s_logisimNet93        = CFETCH;
   assign s_logisimNet94        = CSVECT;

   /*******************************************************************************
   ** Here all output connections are defined                                    **
   *******************************************************************************/
   assign ACONDN  = s_logisimNet37;
   assign COND    = s_logisimNet118;
   assign DEEP    = s_logisimNet151;
   assign DZD     = s_logisimNet2;
   assign LAA_3_0 = s_logisimBus6[3:0];
   assign LBA_3_0 = s_logisimBus223[3:0];
   assign LCZN    = s_logisimNet43;
   assign MA_12_0 = s_logisimBus77[12:0];
   assign OOD     = s_logisimNet29;
   assign PN      = s_logisimNet101;
   assign RF_1_0  = s_logisimBus155[1:0];
   assign SC_6_3  = s_logisimBus73[3:0];
   assign TN      = s_logisimNet91;
   assign UPN     = s_logisimNet17;
   assign WCSN    = s_logisimNet222;

   /*******************************************************************************
   ** Here all in-lined components are defined                                   **
   *******************************************************************************/

   // Power
   assign  s_logisimNet190  =  1'b1;


   // Power
   assign  s_logisimNet68  =  1'b1;


   // Ground
   assign  s_logisimNet31  =  1'b0;


   // Ground
   assign  s_logisimNet13  =  1'b0;


   // Ground
   assign  s_logisimNet45  =  1'b0;


   // NOT Gate
   assign s_logisimNet48 = ~s_logisimNet70;

   // NOT Gate
   assign s_logisimNet17 = ~s_logisimNet59;

   // NOT Gate
   assign s_logisimNet149 = ~s_logisimNet102;

   // NOT Gate
   assign s_logisimNet34 = ~s_logisimNet17;

   // NOT Gate
   assign s_logisimNet16 = ~s_logisimNet174;

   // NOT Gate
   assign s_logisimNet140 = ~s_logisimNet174;

   // NOT Gate
   assign s_logisimNet225 = ~s_logisimNet43;

   // NOT Gate
   assign s_logisimBus73[3] = ~s_logisimNet197;

   // NOT Gate
   assign s_logisimBus73[2] = ~s_logisimNet244;

   // NOT Gate
   assign s_logisimBus73[1] = ~s_logisimNet60;

   // NOT Gate
   assign s_logisimNet156 = ~s_logisimNet132;

   // NOT Gate
   assign s_logisimBus6[0] = ~s_logisimNet163;

   // NOT Gate
   assign s_logisimBus6[1] = ~s_logisimNet25;

   // NOT Gate
   assign s_logisimBus6[2] = ~s_logisimNet213;

   // NOT Gate
   assign s_logisimBus6[3] = ~s_logisimNet131;

   // NOT Gate
   assign s_logisimBus223[0] = ~s_logisimNet198;

   // NOT Gate
   assign s_logisimBus223[1] = ~s_logisimNet111;

   // NOT Gate
   assign s_logisimBus223[2] = ~s_logisimNet245;

   // NOT Gate
   assign s_logisimBus223[3] = ~s_logisimNet179;

   // NOT Gate
   assign s_logisimNet28 = ~s_logisimNet132;

   // NOT Gate
   assign s_logisimNet38 = ~s_logisimNet201;

   // NOT Gate
   assign s_logisimNet224 = ~s_logisimBus141[1];

   // NOT Gate
   assign s_logisimNet248 = ~s_logisimNet127;

   // NOT Gate
   assign s_logisimNet126 = ~s_logisimNet94;

   // NOT Gate
   assign s_logisimNet61 = ~s_logisimNet255;

   // NOT Gate
   assign s_logisimNet201 = ~s_logisimNet61;

   /*******************************************************************************
   ** Here all normal components are defined                                     **
   *******************************************************************************/
   OR_GATE #(.BubblesMask(2'b00))
      GATES_1 (.input1(s_logisimBus217[1]),
               .input2(s_logisimBus217[0]),
               .result(s_logisimNet47));

   NAND_GATE_3_INPUTS #(.BubblesMask(3'b000))
      GATES_2 (.input1(s_logisimNet47),
               .input2(s_logisimNet38),
               .input3(s_logisimNet190),
               .result(s_logisimNet206));

   NOR_GATE_3_INPUTS #(.BubblesMask(3'b000))
      GATES_3 (.input1(s_logisimNet22),
               .input2(s_logisimNet203),
               .input3(s_logisimNet28),
               .result(s_logisimNet96));

   OR_GATE #(.BubblesMask(2'b00))
      GATES_4 (.input1(s_logisimNet55),
               .input2(s_logisimNet34),
               .result(s_logisimNet166));

   NAND_GATE_3_INPUTS #(.BubblesMask(3'b000))
      GATES_5 (.input1(s_logisimNet201),
               .input2(s_logisimNet48),
               .input3(s_logisimNet149),
               .result(s_logisimNet124));

   AND_GATE_4_INPUTS #(.BubblesMask(4'h0))
      GATES_6 (.input1(s_logisimNet23),
               .input2(s_logisimNet48),
               .input3(s_logisimNet201),
               .input4(s_logisimNet102),
               .result(s_logisimNet105));

   NAND_GATE_3_INPUTS #(.BubblesMask(3'b000))
      GATES_7 (.input1(s_logisimNet166),
               .input2(s_logisimNet173),
               .input3(s_logisimNet68),
               .result(s_logisimNet101));

   NAND_GATE #(.BubblesMask(2'b00))
      GATES_8 (.input1(s_logisimNet23),
               .input2(s_logisimNet124),
               .result(s_logisimNet15));

   AND_GATE #(.BubblesMask(2'b00))
      GATES_9 (.input1(s_logisimNet15),
               .input2(s_logisimBus129[3]),
               .result(s_logisimNet135));

   AND_GATE #(.BubblesMask(2'b00))
      GATES_10 (.input1(s_logisimNet105),
                .input2(s_logisimBus202[3]),
                .result(s_logisimNet253));

   AND_GATE #(.BubblesMask(2'b00))
      GATES_11 (.input1(s_logisimNet15),
                .input2(s_logisimBus129[2]),
                .result(s_logisimNet192));

   AND_GATE #(.BubblesMask(2'b00))
      GATES_12 (.input1(s_logisimNet105),
                .input2(s_logisimBus202[2]),
                .result(s_logisimNet100));

   AND_GATE #(.BubblesMask(2'b00))
      GATES_13 (.input1(s_logisimNet15),
                .input2(s_logisimBus129[1]),
                .result(s_logisimNet236));

   AND_GATE #(.BubblesMask(2'b00))
      GATES_14 (.input1(s_logisimNet105),
                .input2(s_logisimBus202[1]),
                .result(s_logisimNet168));

   AND_GATE #(.BubblesMask(2'b00))
      GATES_15 (.input1(s_logisimNet15),
                .input2(s_logisimBus129[0]),
                .result(s_logisimNet33));

   AND_GATE #(.BubblesMask(2'b00))
      GATES_16 (.input1(s_logisimNet105),
                .input2(s_logisimBus202[0]),
                .result(s_logisimNet215));

   NAND_GATE #(.BubblesMask(2'b00))
      GATES_17 (.input1(s_logisimNet96),
                .input2(s_logisimNet74),
                .result(s_logisimNet43));

   NAND_GATE_3_INPUTS #(.BubblesMask(3'b000))
      GATES_18 (.input1(s_logisimNet201),
                .input2(s_logisimNet23),
                .input3(s_logisimNet70),
                .result(s_logisimNet4));

   NOR_GATE #(.BubblesMask(2'b00))
      GATES_19 (.input1(s_logisimNet135),
                .input2(s_logisimNet253),
                .result(s_logisimNet103));

   NOR_GATE #(.BubblesMask(2'b00))
      GATES_20 (.input1(s_logisimNet192),
                .input2(s_logisimNet100),
                .result(s_logisimNet171));

   NOR_GATE #(.BubblesMask(2'b00))
      GATES_21 (.input1(s_logisimNet236),
                .input2(s_logisimNet168),
                .result(s_logisimNet130));

   NOR_GATE #(.BubblesMask(2'b00))
      GATES_22 (.input1(s_logisimNet33),
                .input2(s_logisimNet215),
                .result(s_logisimNet67));

   NOR_GATE #(.BubblesMask(2'b11))
      GATES_23 (.input1(s_logisimNet201),
                .input2(s_logisimNet103),
                .result(s_logisimNet197));

   NOR_GATE #(.BubblesMask(2'b11))
      GATES_24 (.input1(s_logisimNet4),
                .input2(s_logisimNet171),
                .result(s_logisimNet244));

   AND_GATE #(.BubblesMask(2'b00))
      GATES_25 (.input1(s_logisimNet51),
                .input2(s_logisimNet26),
                .result(s_logisimNet114));

   NOR_GATE_3_INPUTS #(.BubblesMask(3'b000))
      GATES_26 (.input1(s_logisimNet114),
                .input2(s_logisimNet2),
                .input3(s_logisimNet31),
                .result(s_logisimNet194));

   NOR_GATE #(.BubblesMask(2'b00))
      GATES_27 (.input1(s_logisimNet29),
                .input2(s_logisimNet53),
                .result(s_logisimNet159));

   NAND_GATE #(.BubblesMask(2'b00))
      GATES_28 (.input1(s_logisimBus141[0]),
                .input2(s_logisimNet127),
                .result(s_logisimNet218));

   NAND_GATE #(.BubblesMask(2'b00))
      GATES_29 (.input1(s_logisimNet127),
                .input2(s_logisimNet224),
                .result(s_logisimNet138));

   AND_GATE #(.BubblesMask(2'b00))
      GATES_30 (.input1(s_logisimNet248),
                .input2(s_logisimBus196[6]),
                .result(s_logisimNet235));

   NAND_GATE #(.BubblesMask(2'b00))
      GATES_31 (.input1(s_logisimNet201),
                .input2(s_logisimNet116),
                .result(s_logisimNet188));

   D_FLIPFLOP #(.invertClockEnable(0))
      MEMORY_32 (.clock(s_logisimNet174),
                 .d(s_logisimNet23),
                 .preset(1'b0),
                 .q(),
                 .qBar(s_logisimNet118),
                 .reset(1'b0),
                 .tick(1'b1));

   D_FLIPFLOP #(.invertClockEnable(0))
      MEMORY_33 (.clock(s_logisimNet174),
                 .d(s_logisimNet70),
                 .preset(1'b0),
                 .q(s_logisimNet173),
                 .qBar(),
                 .reset(1'b0),
                 .tick(1'b1));

   D_FLIPFLOP #(.invertClockEnable(1))
      MEMORY_34 (.clock(s_logisimNet174),
                 .d(s_logisimNet67),
                 .preset(1'b0),
                 .q(s_logisimNet60),
                 .qBar(),
                 .reset(1'b0),
                 .tick(1'b1));

   D_FLIPFLOP #(.invertClockEnable(0))
      MEMORY_35 (.clock(s_logisimNet174),
                 .d(s_logisimNet26),
                 .preset(1'b0),
                 .q(s_logisimNet51),
                 .qBar(),
                 .reset(s_logisimNet156),
                 .tick(1'b1));

   D_FLIPFLOP #(.invertClockEnable(0))
      MEMORY_36 (.clock(s_logisimNet174),
                 .d(s_logisimNet44),
                 .preset(1'b0),
                 .q(),
                 .qBar(s_logisimNet152),
                 .reset(1'b0),
                 .tick(1'b1));

   D_FLIPFLOP #(.invertClockEnable(1))
      MEMORY_37 (.clock(s_logisimNet174),
                 .d(s_logisimNet130),
                 .preset(1'b0),
                 .q(),
                 .qBar(s_logisimBus73[0]),
                 .reset(1'b0),
                 .tick(1'b1));

   D_FLIPFLOP #(.invertClockEnable(0))
      MEMORY_38 (.clock(s_logisimNet174),
                 .d(s_logisimNet138),
                 .preset(1'b0),
                 .q(s_logisimNet209),
                 .qBar(),
                 .reset(1'b0),
                 .tick(1'b1));

   D_FLIPFLOP #(.invertClockEnable(0))
      MEMORY_39 (.clock(s_logisimNet174),
                 .d(s_logisimNet218),
                 .preset(1'b0),
                 .q(s_logisimNet187),
                 .qBar(),
                 .reset(1'b0),
                 .tick(1'b1));


   /*******************************************************************************
   ** Here all sub-circuits are defined                                          **
   *******************************************************************************/

   M169C   LC_HI (.A(s_logisimBus20[4]),
                  .B(s_logisimBus20[5]),
                  .C(s_logisimBus20[5]),
                  .CON(s_logisimNet55),
                  .CP(s_logisimNet174),
                  .D(s_logisimBus20[5]),
                  .NL(s_logisimNet157),
                  .PN(s_logisimNet101),
                  .QA(s_logisimNet22),
                  .QB(s_logisimNet203),
                  .QC(s_logisimNet216),
                  .QD(s_logisimNet59),
                  .TN(s_logisimNet91),
                  .UP(s_logisimNet34));

   M169C   LC_LO (.A(s_logisimBus20[0]),
                  .B(s_logisimBus20[1]),
                  .C(s_logisimBus20[2]),
                  .CON(s_logisimNet91),
                  .CP(s_logisimNet174),
                  .D(s_logisimBus20[3]),
                  .NL(s_logisimNet157),
                  .PN(s_logisimNet101),
                  .QA(s_logisimBus241[0]),
                  .QB(s_logisimBus241[1]),
                  .QC(s_logisimBus241[2]),
                  .QD(s_logisimBus241[3]),
                  .TN(s_logisimNet45),
                  .UP(s_logisimNet34));

   MUX21L   M_RF1 (.A(s_logisimNet209),
                   .B(s_logisimBus217[1]),
                   .S(s_logisimNet188),
                   .ZN(s_logisimBus155[1]));

   MUX21L   M_RF0 (.A(s_logisimNet187),
                   .B(s_logisimBus217[0]),
                   .S(s_logisimNet188),
                   .ZN(s_logisimBus155[0]));

   MUX34P   ILC_MUX (.A(s_logisimNet193),
                     .B(s_logisimNet126),
                     .D00(s_logisimBus196[0]),
                     .D01(s_logisimBus196[1]),
                     .D02(s_logisimBus196[2]),
                     .D03(s_logisimBus196[3]),
                     .D10(s_logisimBus6[0]),
                     .D11(s_logisimBus6[1]),
                     .D12(s_logisimBus6[2]),
                     .D13(s_logisimBus6[3]),
                     .D20(s_logisimBus232[0]),
                     .D21(s_logisimBus232[1]),
                     .D22(s_logisimBus232[2]),
                     .D23(s_logisimBus232[3]),
                     .Z0(s_logisimBus233[0]),
                     .Z1(s_logisimBus233[1]),
                     .Z2(s_logisimBus233[2]),
                     .Z3(s_logisimBus233[3]));

   L8   IRLATCH (.A(s_logisimBus20[0]),
                 .B(s_logisimBus20[1]),
                 .C(s_logisimBus20[2]),
                 .D(s_logisimBus20[3]),
                 .E(s_logisimBus20[4]),
                 .F(s_logisimBus20[5]),
                 .G(s_logisimBus20[6]),
                 .H(1'b0),
                 .L(s_logisimNet8),
                 .QA(s_logisimBus196[0]),
                 .QAN(),
                 .QB(s_logisimBus196[1]),
                 .QBN(),
                 .QC(s_logisimBus196[2]),
                 .QCN(),
                 .QD(s_logisimBus196[3]),
                 .QDN(),
                 .QE(s_logisimBus196[4]),
                 .QEN(),
                 .QF(s_logisimBus196[5]),
                 .QFN(),
                 .QG(s_logisimBus196[6]),
                 .QGN(),
                 .QH(),
                 .QHN());

   MUX41P   M_LAA_2 (.A(s_logisimBus141[0]),
                     .B(s_logisimBus141[1]),
                     .D0(s_logisimBus252[1]),
                     .D1(s_logisimBus205[1]),
                     .D2(s_logisimBus196[5]),
                     .D3(s_logisimBus241[2]),
                     .Z(s_logisimNet71));

   CMP4   LC_CMP (.A0(s_logisimBus178[0]),
                  .A1(s_logisimBus178[1]),
                  .A2(s_logisimBus178[2]),
                  .A3(s_logisimBus178[3]),
                  .AEB(s_logisimNet74),
                  .AGB(),
                  .ALB(),
                  .B0(s_logisimBus241[0]),
                  .B1(s_logisimBus241[1]),
                  .B2(s_logisimBus241[2]),
                  .B3(s_logisimBus241[3]));

   MUX41P   M_LAA_1 (.A(s_logisimBus141[0]),
                     .B(s_logisimBus141[1]),
                     .D0(s_logisimBus252[2]),
                     .D1(s_logisimBus205[2]),
                     .D2(s_logisimBus196[4]),
                     .D3(s_logisimBus241[1]),
                     .Z(s_logisimNet40));

   MUX41P   M_LAA_0 (.A(s_logisimBus141[0]),
                     .B(s_logisimBus141[1]),
                     .D0(s_logisimBus252[3]),
                     .D1(s_logisimBus205[3]),
                     .D2(s_logisimBus196[3]),
                     .D3(s_logisimBus241[0]),
                     .Z(s_logisimNet65));

   R41P   LAA_REG (.A(s_logisimNet65),
                   .B(s_logisimNet40),
                   .C(s_logisimNet71),
                   .CP(s_logisimNet174),
                   .D(s_logisimNet191),
                   .QA(),
                   .QAN(s_logisimNet163),
                   .QB(),
                   .QBN(s_logisimNet25),
                   .QC(),
                   .QCN(s_logisimNet213),
                   .QD(),
                   .QDN(s_logisimNet131));

   SCAN_WITH_SET_N   OOD_FF (.CLK(s_logisimNet174),
                             .D(s_logisimNet159),
                             .Q(s_logisimNet99),
                             .QN(s_logisimNet29),
                             .S(s_logisimNet132),
                             .TE(s_logisimNet152),
                             .TI(s_logisimNet99));

   SCAN_WITH_SET_N   DZD_FF (.CLK(s_logisimNet174),
                             .D(s_logisimNet194),
                             .Q(s_logisimNet83),
                             .QN(s_logisimNet2),
                             .S(s_logisimNet132),
                             .TE(s_logisimNet152),
                             .TI(s_logisimNet83));

   MUX41P   M_LBA_3 (.A(s_logisimBus145[0]),
                     .B(s_logisimBus145[1]),
                     .D0(s_logisimBus226[3]),
                     .D1(s_logisimNet13),
                     .D2(s_logisimNet13),
                     .D3(s_logisimBus241[3]),
                     .Z(s_logisimNet3));

   MUX41P   M_LBA_2 (.A(s_logisimBus145[0]),
                     .B(s_logisimBus145[1]),
                     .D0(s_logisimBus226[2]),
                     .D1(s_logisimBus196[2]),
                     .D2(s_logisimBus196[5]),
                     .D3(s_logisimBus241[2]),
                     .Z(s_logisimNet63));

   MUX41P   M_LBA_1 (.A(s_logisimBus145[0]),
                     .B(s_logisimBus145[1]),
                     .D0(s_logisimBus226[1]),
                     .D1(s_logisimBus196[1]),
                     .D2(s_logisimBus196[4]),
                     .D3(s_logisimBus241[1]),
                     .Z(s_logisimNet0));

   MUX41P   M_LBA_0 (.A(s_logisimBus145[0]),
                     .B(s_logisimBus145[1]),
                     .D0(s_logisimBus226[0]),
                     .D1(s_logisimBus196[0]),
                     .D2(s_logisimBus196[3]),
                     .D3(s_logisimBus241[0]),
                     .Z(s_logisimNet24));

   R41P   LBA_REG (.A(s_logisimNet24),
                   .B(s_logisimNet0),
                   .C(s_logisimNet63),
                   .CP(s_logisimNet174),
                   .D(s_logisimNet3),
                   .QA(),
                   .QAN(s_logisimNet198),
                   .QB(),
                   .QBN(s_logisimNet111),
                   .QC(),
                   .QCN(s_logisimNet245),
                   .QD(),
                   .QDN(s_logisimNet179));

   MUX41P   M_LAA_3 (.A(s_logisimBus141[0]),
                     .B(s_logisimBus141[1]),
                     .D0(s_logisimBus252[0]),
                     .D1(s_logisimBus205[0]),
                     .D2(s_logisimNet235),
                     .D3(s_logisimBus241[3]),
                     .Z(s_logisimNet191));

   CGA_MIC_INCOUNT   MIC_INCOUNT (.CD0(s_logisimBus20[0]),
                                  .CD1(s_logisimBus20[1]),
                                  .CSWAN0(s_logisimBus217[0]),
                                  .CSWAN1(s_logisimBus217[1]),
                                  .EC(s_logisimNet38),
                                  .LWCAN(s_logisimNet81),
                                  .MCLK(s_logisimNet174),
                                  .MRN(s_logisimNet56));

   CGA_MIC_CONDREG   CONDREG (.ACONDN(s_logisimNet37),
                              .CSBIT_11_0(s_logisimBus85[11:0]),
                              .CSSCOND(s_logisimNet207),
                              .FS_6_3(s_logisimBus202[3:0]),
                              .LCC_3_0(s_logisimBus178[3:0]),
                              .LCSN(s_logisimNet201),
                              .MCLK(s_logisimNet174),
                              .TSEL_3_0(s_logisimBus41[3:0]));

   CGA_MIC_IINC   MIC_IINC (.CIN(s_logisimNet206),
                            .IW_12_0(s_logisimBus57[12:0]),
                            .NEXT_12_0(s_logisimBus121[12:0]));

   CGA_MIC_STACK   MIC_STACK (.DEEP(s_logisimNet151),
                              .MCLK(s_logisimNet174),
                              .NEXT_12_0(s_logisimBus121[12:0]),
                              .RET_12_0(s_logisimBus32[12:0]),
                              .SC3(1'b0),
                              .SC4(1'b0),
                              .SCLKN(s_logisimNet140));

   CGA_MIC_MASEL   MIC_MASEL (.CSBIT20(s_logisimNet185),
                              .CSBIT_11_4(s_logisimBus98[7:0]),
                              .IW_12_0(s_logisimBus57[12:0]),
                              .JMP_3_0(s_logisimBus233[3:0]),
                              .MCLK(s_logisimNet174),
                              .MCLKN(s_logisimNet16),
                              .MRN(s_logisimNet56),
                              .NEXT_12_0(s_logisimBus121[12:0]),
                              .RET_12_0(s_logisimBus32[12:0]),
                              .SC5(s_logisimBus73[2]),
                              .SC6(s_logisimBus73[3]),
                              .W_12_0(s_logisimBus161[12:0]));

   CGA_MIC_WCAREG   MIC_WCAREG (.CD_15_0(s_logisimBus20[15:0]),
                                .LCSN(s_logisimNet201),
                                .LWCAN(s_logisimNet81),
                                .MCLK(s_logisimNet174),
                                .WCA_12_0(s_logisimBus21[12:0]),
                                .WCSN(s_logisimNet222));

   CGA_MIC_IPOS   MIC_IPOS (.CD_15_0(s_logisimBus20[15:0]),
                            .EWCAN(s_logisimNet116),
                            .MAPN(s_logisimNet170),
                            .MA_12_0(s_logisimBus77[12:0]),
                            .TRAPN(s_logisimNet69),
                            .TVEC_3_0(s_logisimBus237[3:0]),
                            .WCA_12_0(s_logisimBus21[12:0]),
                            .W_12_0(s_logisimBus161[12:0]));

   CGA_MIC_CSEL   CSEL (.ALUCLK(s_logisimNet123),
                        .CFETCH(s_logisimNet93),
                        .COND(s_logisimNet118),
                        .CONDN(s_logisimNet23),
                        .CRY(s_logisimNet220),
                        .DZD(s_logisimNet2),
                        .F11(s_logisimNet27),
                        .F15(s_logisimNet146),
                        .IRQ(s_logisimNet120),
                        .LCZ(s_logisimNet115),
                        .OOD(s_logisimNet29),
                        .OVF(s_logisimNet164),
                        .RESTR(s_logisimNet249),
                        .SPARE(s_logisimNet231),
                        .STP(s_logisimNet254),
                        .TSEL_3_0(s_logisimBus41[3:0]),
                        .ZF(s_logisimNet26));

endmodule

/******************************************************************************
 ** Logisim-evolution goes FPGA automatic generated Verilog code             **
 ** https://github.com/logisim-evolution/                                    **
 **                                                                          **
 ** Component : DECODE_DGA                                                   **
 **                                                                          **
 *****************************************************************************/

module DECODE_DGA( XA_7_0,
                   XA_7_0_C,
                   XBDN,
                   XBRN,
                   XC10,
                   XCLK,
                   XCLN,
                   XCLO,
                   XCON,
                   XCO_4_0,
                   XCRN,
                   XCSN,
                   XDAN,
                   XDON,
                   XDTN,
                   XDVN,
                   XECR,
                   XEFN,
                   XEMN,
                   XEON,
                   XEPN,
                   XESN,
                   XEUN,
                   XFEC,
                   XFMI,
                   XFON,
                   XFUN,
                   XHIN,
                   XIB_7_4,
                   XID_4_0,
                   XION,
                   XI_3_0_C,
                   XI_3_0_I,  // TODO: Merge into inout _io
                   XI_3_0_O,
                   XLCN,
                   XLHN,
                   XLON,
                   XLSH,
                   XMCL,
                   XMI_1_0,
                   XMRN,
                   XOCN,
                   XPAN,
                   XPOI,
                   XPEN,
                   XPFN,
                   XPIN,
                   XPNN,
                   XPOW,
                   XPSC,
                   XPSN,
                   XPWC,
                   XRFN,
                   XRIN,
                   XRMN,
                   XRQN,
                   XRTN,
                   XRTO,
                   XRUN,
                   XRWN,
                   XS5N,
                   XSCN,
                   XSHN,
                   XSSN,
                   XSTP,
                   XST_4_3,
                   XSWN,
                   XTEO,
                   XTES,
                   XTON,
                   XTOT,
                   XTRN,
                   XUCK,
                   XVAL,
                   XWHN,
                   XWRI );

   /*******************************************************************************
   ** The inputs are defined here                                                **
   *******************************************************************************/
   input       XBDN;
   input       XBRN;
   input       XCLK;
   input       XCLO;
   input       XCON;
   input [4:0] XCO_4_0;
   input       XDAN;
   input       XEFN;
   input       XEON;
   input       XHIN;
   input [3:0] XIB_7_4;
   input [4:0] XID_4_0;
   input [3:0] XI_3_0_I;
   input       XLCN;
   input       XLON;
   input       XLSH;
   input [1:0] XMI_1_0;
   input       XPOI;
   input       XPOW;
   input       XPWC;
   input       XRMN;
   input       XRTO;
   input       XS5N;
   input [1:0] XST_4_3;
   input       XTES;
   input       XTON;
   input       XUCK;

   /*******************************************************************************
   ** The outputs are defined here                                               **
   *******************************************************************************/
   output [7:0] XA_7_0;
   output [7:0] XA_7_0_C;
   output       XC10;
   output       XCLN;
   output       XCRN;
   output       XCSN;
   output       XDON;
   output       XDTN;
   output       XDVN;
   output       XECR;
   output       XEMN;
   output       XEPN;
   output       XESN;
   output       XEUN;
   output       XFEC;
   output       XFMI;
   output       XFON;
   output       XFUN;
   output       XION;
   output [3:0] XI_3_0_C;
   output [3:0] XI_3_0_O;
   output       XLHN;
   output       XMCL;
   output       XMRN;
   output       XOCN;
   output       XPAN;
   output       XPEN;
   output       XPFN;
   output       XPIN;
   output       XPNN;
   output       XPSC;
   output       XPSN;
   output       XRFN;
   output       XRIN;
   output       XRQN;
   output       XRTN;
   output       XRUN;
   output       XRWN;
   output       XSCN;
   output       XSHN;
   output       XSSN;
   output       XSTP;
   output       XSWN;
   output       XTEO;
   output       XTOT;
   output       XTRN;
   output       XVAL;
   output       XWHN;
   output       XWRI;

   /*******************************************************************************
   ** The wires are defined here                                                 **
   *******************************************************************************/
   wire [4:0]  s_logisimBus11;
   wire [3:0]  s_logisimBus12;
   wire [1:0]  s_logisimBus20;
   wire [12:0] s_logisimBus24;
   wire [3:0]  s_logisimBus30;
   wire [1:0]  s_logisimBus32;
   wire [7:0]  s_logisimBus35;
   wire [3:0]  s_logisimBus42;
   wire [3:0]  s_logisimBus5;
   wire [12:0] s_logisimBus53;
   wire [7:0]  s_logisimBus56;
   wire [7:0]  s_logisimBus74;
   wire [4:0]  s_logisimBus78;
   wire [7:0]  s_logisimBus8;
   wire [7:0]  s_logisimBus83;
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
   wire        s_logisimNet110;
   wire        s_logisimNet111;
   wire        s_logisimNet112;
   wire        s_logisimNet13;
   wire        s_logisimNet14;
   wire        s_logisimNet15;
   wire        s_logisimNet16;
   wire        s_logisimNet17;
   wire        s_logisimNet18;
   wire        s_logisimNet19;
   wire        s_logisimNet2;
   wire        s_logisimNet21;
   wire        s_logisimNet22;
   wire        s_logisimNet23;
   wire        s_logisimNet25;
   wire        s_logisimNet26;
   wire        s_logisimNet27;
   wire        s_logisimNet28;
   wire        s_logisimNet29;
   wire        s_logisimNet3;
   wire        s_logisimNet31;
   wire        s_logisimNet33;
   wire        s_logisimNet34;
   wire        s_logisimNet36;
   wire        s_logisimNet37;
   wire        s_logisimNet38;
   wire        s_logisimNet39;
   wire        s_logisimNet4;
   wire        s_logisimNet40;
   wire        s_logisimNet41;
   wire        s_logisimNet43;
   wire        s_logisimNet44;
   wire        s_logisimNet45;
   wire        s_logisimNet46;
   wire        s_logisimNet47;
   wire        s_logisimNet48;
   wire        s_logisimNet49;
   wire        s_logisimNet50;
   wire        s_logisimNet51;
   wire        s_logisimNet52;
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
   wire        s_logisimNet66;
   wire        s_logisimNet67;
   wire        s_logisimNet68;
   wire        s_logisimNet69;
   wire        s_logisimNet7;
   wire        s_logisimNet70;
   wire        s_logisimNet71;
   wire        s_logisimNet72;
   wire        s_logisimNet73;
   wire        s_logisimNet75;
   wire        s_logisimNet76;
   wire        s_logisimNet77;
   wire        s_logisimNet79;
   wire        s_logisimNet80;
   wire        s_logisimNet81;
   wire        s_logisimNet82;
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
   assign s_logisimBus35[0] = s_logisimNet4;
   assign s_logisimBus35[1] = s_logisimNet4;
   assign s_logisimBus35[2] = s_logisimNet4;
   assign s_logisimBus35[3] = s_logisimNet4;
   assign s_logisimBus35[4] = s_logisimNet4;
   assign s_logisimBus35[5] = s_logisimNet4;
   assign s_logisimBus35[6] = s_logisimNet4;
   assign s_logisimBus35[7] = s_logisimNet4;
   assign s_logisimBus42[0] = s_logisimNet2;
   assign s_logisimBus42[1] = s_logisimNet2;
   assign s_logisimBus42[2] = s_logisimNet2;
   assign s_logisimBus42[3] = s_logisimNet2;
   assign s_logisimBus74[4] = s_logisimNet21;
   assign s_logisimBus74[5] = s_logisimNet55;
   assign s_logisimBus74[6] = s_logisimNet3;
   assign s_logisimBus74[7] = s_logisimNet51;
   assign s_logisimNet21    = s_logisimBus12[0];
   assign s_logisimNet3     = s_logisimBus12[2];
   assign s_logisimNet51    = s_logisimBus12[3];
   assign s_logisimNet55    = s_logisimBus12[1];

   /*******************************************************************************
   ** Here all input connections are defined                                     **
   *******************************************************************************/
   assign s_logisimBus11[4:0] = XID_4_0;
   assign s_logisimBus12[3:0] = XIB_7_4;
   assign s_logisimBus20[1:0] = XMI_1_0;
   assign s_logisimBus32[1:0] = XST_4_3;
   assign s_logisimBus5[3:0]  = XI_3_0_I;
   assign s_logisimBus78[4:0] = XCO_4_0;
   assign s_logisimNet105     = XPOI;
   assign s_logisimNet106     = XBRN;
   assign s_logisimNet22      = XLCN;
   assign s_logisimNet23      = XS5N;
   assign s_logisimNet27      = XLON;
   assign s_logisimNet28      = XTON;
   assign s_logisimNet52      = XBDN;
   assign s_logisimNet54      = XLSH;
   assign s_logisimNet59      = XCLK;
   assign s_logisimNet63      = XDAN;
   assign s_logisimNet64      = XHIN;
   assign s_logisimNet65      = XPWC;
   assign s_logisimNet7       = XUCK;
   assign s_logisimNet75      = XTES;
   assign s_logisimNet77      = XEON;
   assign s_logisimNet79      = XEFN;
   assign s_logisimNet80      = XPOW;
   assign s_logisimNet91      = XCLO;
   assign s_logisimNet93      = XCON;
   assign s_logisimNet94      = XRMN;
   assign s_logisimNet95      = XRTO;

   /*******************************************************************************
   ** Here all output connections are defined                                    **
   *******************************************************************************/
   assign XA_7_0   = s_logisimBus83[7:0];
   assign XA_7_0_C = s_logisimBus35[7:0];
   assign XC10     = s_logisimNet1;
   assign XCLN     = s_logisimNet97;
   assign XCRN     = s_logisimNet71;
   assign XCSN     = s_logisimNet67;
   assign XDON     = s_logisimNet61;
   assign XDTN     = s_logisimNet39;
   assign XDVN     = s_logisimNet9;
   assign XECR     = s_logisimNet38;
   assign XEMN     = s_logisimNet96;
   assign XEPN     = s_logisimNet89;
   assign XESN     = s_logisimNet70;
   assign XEUN     = s_logisimNet40;
   assign XFEC     = s_logisimNet29;
   assign XFMI     = s_logisimNet18;
   assign XFON     = s_logisimNet19;
   assign XFUN     = s_logisimNet31;
   assign XION     = s_logisimNet60;
   assign XI_3_0_C = s_logisimBus42[3:0];
   assign XI_3_0_O = s_logisimBus30[3:0];
   assign XLHN     = s_logisimNet45;
   assign XMCL     = s_logisimNet99;
   assign XMRN     = s_logisimNet87;
   assign XOCN     = s_logisimNet49;
   assign XPAN     = s_logisimNet13;
   assign XPEN     = s_logisimNet86;
   assign XPFN     = s_logisimNet81;
   assign XPIN     = s_logisimNet69;
   assign XPNN     = s_logisimNet41;
   assign XPSC     = s_logisimNet104;
   assign XPSN     = s_logisimNet16;
   assign XRFN     = s_logisimNet73;
   assign XRIN     = s_logisimNet58;
   assign XRQN     = s_logisimNet37;
   assign XRTN     = s_logisimNet44;
   assign XRUN     = s_logisimNet68;
   assign XRWN     = s_logisimNet57;
   assign XSCN     = s_logisimNet72;
   assign XSHN     = s_logisimNet17;
   assign XSSN     = s_logisimNet50;
   assign XSTP     = s_logisimNet26;
   assign XSWN     = s_logisimNet43;
   assign XTEO     = s_logisimNet101;
   assign XTOT     = s_logisimNet47;
   assign XTRN     = s_logisimNet62;
   assign XVAL     = s_logisimNet88;
   assign XWHN     = s_logisimNet0;
   assign XWRI     = s_logisimNet48;

   /*******************************************************************************
   ** Here all in-lined components are defined                                   **
   *******************************************************************************/

   // NOT Gate
   assign s_logisimNet2 = ~s_logisimNet89;

   // Controlled Buffer
   assign s_logisimBus30[3] = (s_logisimNet2) ? s_logisimBus74[3] : 1'bZ;

   // Controlled Buffer
   assign s_logisimBus30[2] = (s_logisimNet2) ? s_logisimBus74[2] : 1'bZ;

   // Controlled Buffer
   assign s_logisimBus30[1] = (s_logisimNet2) ? s_logisimBus74[1] : 1'bZ;

   // Controlled Buffer
   assign s_logisimBus30[0] = (s_logisimNet2) ? s_logisimBus74[0] : 1'bZ;

   // Buffer
   assign s_logisimNet92 = s_logisimNet94;

   // Buffer
   assign s_logisimBus8 = s_logisimBus56;

   // NOT Gate
   assign s_logisimNet4 = ~s_logisimNet92;

   // Controlled Buffer
   assign s_logisimBus83 = (s_logisimNet4) ? s_logisimBus8 : 8'bZ;

   /*******************************************************************************
   ** Here all normal components are defined                                     **
   *******************************************************************************/
   Multiplexer_2   PLEXERS_1 (
                              .muxIn_0(s_logisimBus5[3]),
                              .muxIn_1(s_logisimNet14),
                              .muxOut(s_logisimBus74[3]),
                              .sel(s_logisimNet2));

   Multiplexer_2   PLEXERS_2 (
                              .muxIn_0(s_logisimBus5[2]),
                              .muxIn_1(s_logisimNet100),
                              .muxOut(s_logisimBus74[2]),
                              .sel(s_logisimNet2));

   Multiplexer_2   PLEXERS_3 (
                              .muxIn_0(s_logisimBus5[1]),
                              .muxIn_1(s_logisimNet103),
                              .muxOut(s_logisimBus74[1]),
                              .sel(s_logisimNet2));

   Multiplexer_2   PLEXERS_4 (
                              .muxIn_0(s_logisimBus5[0]),
                              .muxIn_1(s_logisimNet85),
                              .muxOut(s_logisimBus74[0]),
                              .sel(s_logisimNet2));


   /*******************************************************************************
   ** Here all sub-circuits are defined                                          **
   *******************************************************************************/

   F091   A090 (.N01(),
                .N02(s_logisimNet14));

   DECODE_DGA_PFIFC   PFIFC (.CLEAR(s_logisimNet97),
                             .EMPN(s_logisimNet96),
                             .FULN(s_logisimNet31),
                             .LDPANCN(s_logisimNet76),
                             .RMMN(s_logisimNet94),
                             .WEL_12_0(s_logisimBus24[12:0]),
                             .WEU_12_0(s_logisimBus53[12:0]));

   DECODE_DGA_POW   POW (.BDRY50N(s_logisimNet52),
                         .CLEAR(s_logisimNet97),
                         .CLOSC(s_logisimNet91),
                         .CLRTIN(s_logisimNet10),
                         .CONTINUEN(s_logisimNet93),
                         .EMCLN(s_logisimNet90),
                         .IDB0(s_logisimNet85),
                         .IDB1(s_logisimNet103),
                         .IDB2(s_logisimNet100),
                         .LOADN(s_logisimNet27),
                         .MCL(s_logisimNet99),
                         .PANN(s_logisimNet41),
                         .PANOSC(s_logisimNet104),
                         .POWFAILN(s_logisimNet81),
                         .POWSENSE(s_logisimNet80),
                         .PRQN(s_logisimNet34),
                         .PWCL(s_logisimNet65),
                         .REFN(s_logisimNet79),
                         .REFRQN(s_logisimNet73),
                         .RESET(s_logisimNet36),
                         .RTOSC(s_logisimNet95),
                         .SEL5MSN(s_logisimNet23),
                         .SSTOPN(s_logisimNet25),
                         .STARTN(s_logisimNet33),
                         .STOPN(s_logisimNet28),
                         .STPN(s_logisimNet26),
                         .TESTO(s_logisimNet101),
                         .TESTE(s_logisimNet75),
                         .TOUT(s_logisimNet47));

   DECODE_DGA_PFIFD   PFIFD (.AD_7_0(s_logisimBus56[7:0]),
                             .IDBI_7_0(s_logisimBus74[7:0]),
                             .WEL_12_0(s_logisimBus24[12:0]),
                             .WEU_12_0(s_logisimBus53[12:0]));

   DECODE_DGA_IDBS   IDBS (.CLK0(s_logisimNet59),
                           .CLK1(s_logisimNet59),
                           .CSIDBS_4_0(s_logisimBus11[4:0]),
                           .ECSRN(s_logisimNet67),
                           .EDON(s_logisimNet61),
                           .EIORN(s_logisimNet60),
                           .EPANN(s_logisimNet89),
                           .EPANSN(s_logisimNet16),
                           .EPEAN(s_logisimNet13),
                           .EPESN(s_logisimNet86),
                           .LCSN(s_logisimNet22),
                           .PRQN(s_logisimNet34),
                           .RINRN(s_logisimNet58),
                           .RUARTN(s_logisimNet68),
                           .STAT3(s_logisimBus32[0]),
                           .STAT4(s_logisimBus32[1]),
                           .TRAALDN(s_logisimNet62),
                           .VAL(s_logisimNet88));

   DECODE_DGA_COMM   COMM (.BRKN(s_logisimNet106),
                           .CA10(s_logisimNet1),
                           .CCLRN(s_logisimNet71),
                           .CEUARTN(s_logisimNet40),
                           .CLEAR(s_logisimNet97),
                           .CLK1(s_logisimNet59),
                           .CLK2(s_logisimNet59),
                           .CLK3(s_logisimNet59),
                           .CLRTIN(s_logisimNet10),
                           .CSCOMM_4_0(s_logisimBus78[4:0]),
                           .CSMIS_1_0(s_logisimBus20[1:0]),
                           .DAPN(s_logisimNet63),
                           .DTN(s_logisimNet39),
                           .DVACCN(s_logisimNet9),
                           .ECREQ(s_logisimNet38),
                           .EMCLN(s_logisimNet90),
                           .EMPIDN(s_logisimNet69),
                           .EORFN(s_logisimNet77),
                           .ESTOFN(s_logisimNet70),
                           .FETCH(s_logisimNet29),
                           .FMISS(s_logisimNet18),
                           .FORMN(s_logisimNet19),
                           .HITN(s_logisimNet64),
                           .IDBI2(s_logisimBus74[2]),
                           .IDBI5(s_logisimNet55),
                           .IDBI7(s_logisimNet51),
                           .IORQN(s_logisimNet37),
                           .LCSN(s_logisimNet22),
                           .LDPANCN(s_logisimNet76),
                           .LHIT(s_logisimNet45),
                           .LSHADOW(s_logisimNet54),
                           .MREQ(s_logisimNet87),
                           .PONI(s_logisimNet105),
                           .RESET(s_logisimNet36),
                           .RTN(s_logisimNet44),
                           .RWCSN(s_logisimNet57),
                           .SHORTN(s_logisimNet17),
                           .SIOCN(s_logisimNet49),
                           .SLOWN(s_logisimNet43),
                           .SSEMAN(s_logisimNet50),
                           .SSTOPN(s_logisimNet25),
                           .STARTN(s_logisimNet33),
                           .STOCN(s_logisimNet72),
                           .UCLK(s_logisimNet7),
                           .WCHIMN(s_logisimNet0),
                           .WRITE(s_logisimNet48));

endmodule

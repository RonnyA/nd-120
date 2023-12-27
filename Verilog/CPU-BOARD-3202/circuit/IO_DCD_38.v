/******************************************************************************
 ** Logisim-evolution goes FPGA automatic generated Verilog code             **
 ** https://github.com/logisim-evolution/                                    **
 **                                                                          **
 ** Component : IO_DCD_38                                                    **
 **                                                                          **
 *****************************************************************************/

module IO_DCD_38( BDRY50_n,
                  BRK_n,
                  CA10,
                  CCLR_n,
                  CEUART_n,
                  CLEAR_n,
                  CLK,
                  CSCOMM_4_0,
                  CSIDBS_4_0,
                  CSMIS_1_0,
                  DAP_n,
                  DT_n,
                  DVACC_n,
                  ECREQ,
                  ECSR_n,
                  EDO_n,
                  EIOR_n,
                  EMPID_n,
                  EMP_n,
                  EORF_n,
                  EPANS_n,
                  ESTOF_n,
                  FETCH,
                  FMISS,
                  FORM_n,
                  FUL_n,
                  HIT,
                  ICONTIN_n,
                  IDB_3_0_io,
                  IDB_7_4,
                  ILOAD_n,
                  IORQ_n,
                  ISTOP_n,
                  LCS_n,
                  LHIT,
                  LSHADOW,
                  MCL,
                  MREQ_n,
                  OC_1_0,
                  OPCLCS,
                  OSC,
                  OSCCL_n,
                  PANOSC,
                  PAN_n,
                  PA_7_0,
                  PA_n,
                  PONI,
                  POWFAIL_n,
                  POWSENSE_n,
                  PPOSC,
                  PS_n,
                  REFRQ_n,
                  REF_n,
                  RINR_n,
                  RMM_n,
                  RT_n,
                  RUART_n,
                  RWCS_n,
                  SEL5MS_n,
                  SHORT_n,
                  SIOC_n,
                  SLOW_n,
                  SSEMA_n,
                  STAT_4_3,
                  STOC_n,
                  STP,
                  SWMCL_n,
                  TOUT,
                  TRAALD_n,
                  UCLK,
                  VAL,
                  WCHIM_n,
                  WRITE,
                  XTAL1,
                  XTAL2 );

   /*******************************************************************************
   ** The inputs are defined here                                                **
   *******************************************************************************/
   input       BDRY50_n;
   input       BRK_n;
   input       CLK;
   input [4:0] CSCOMM_4_0;
   input [4:0] CSIDBS_4_0;
   input [1:0] CSMIS_1_0;
   input       DAP_n;
   input       EORF_n;
   input       HIT;
   input       ICONTIN_n;
   input [3:0] IDB_3_0_io;
   input [3:0] IDB_7_4;
   input       ILOAD_n;
   input       ISTOP_n;
   input       LCS_n;
   input       LSHADOW;
   input [1:0] OC_1_0;
   input       OPCLCS;
   input       OSCCL_n;
   input       PONI;
   input       POWSENSE_n;
   input       REF_n;
   input       RMM_n;
   input       SEL5MS_n;
   input [1:0] STAT_4_3;
   input       SWMCL_n;
   input       UCLK;
   input       XTAL1;
   input       XTAL2;

   /*******************************************************************************
   ** The outputs are defined here                                               **
   *******************************************************************************/
   output       CA10;
   output       CCLR_n;
   output       CEUART_n;
   output       CLEAR_n;
   output       DT_n;
   output       DVACC_n;
   output       ECREQ;
   output       ECSR_n;
   output       EDO_n;
   output       EIOR_n;
   output       EMPID_n;
   output       EMP_n;
   output       EPANS_n;
   output       ESTOF_n;
   output       FETCH;
   output       FMISS;
   output       FORM_n;
   output       FUL_n;
   output       IORQ_n;
   output       LHIT;
   output       MCL;
   output       MREQ_n;
   output       OSC;
   output       PANOSC;
   output       PAN_n;
   output [7:0] PA_7_0;
   output       PA_n;
   output       POWFAIL_n;
   output       PPOSC;
   output       PS_n;
   output       REFRQ_n;
   output       RINR_n;
   output       RT_n;
   output       RUART_n;
   output       RWCS_n;
   output       SHORT_n;
   output       SIOC_n;
   output       SLOW_n;
   output       SSEMA_n;
   output       STOC_n;
   output       STP;
   output       TOUT;
   output       TRAALD_n;
   output       VAL;
   output       WCHIM_n;
   output       WRITE;

   /*******************************************************************************
   ** The wires are defined here                                                 **
   *******************************************************************************/
   wire [4:0] s_logisimBus18;
   wire [3:0] s_logisimBus29;
   wire [3:0] s_logisimBus30;
   wire [7:0] s_logisimBus52;
   wire [4:0] s_logisimBus56;
   wire [1:0] s_logisimBus57;
   wire [1:0] s_logisimBus64;
   wire [1:0] s_logisimBus73;
   wire       s_logisimNet0;
   wire       s_logisimNet1;
   wire       s_logisimNet10;
   wire       s_logisimNet11;
   wire       s_logisimNet12;
   wire       s_logisimNet13;
   wire       s_logisimNet14;
   wire       s_logisimNet15;
   wire       s_logisimNet16;
   wire       s_logisimNet17;
   wire       s_logisimNet19;
   wire       s_logisimNet2;
   wire       s_logisimNet20;
   wire       s_logisimNet21;
   wire       s_logisimNet22;
   wire       s_logisimNet23;
   wire       s_logisimNet24;
   wire       s_logisimNet25;
   wire       s_logisimNet26;
   wire       s_logisimNet27;
   wire       s_logisimNet28;
   wire       s_logisimNet3;
   wire       s_logisimNet31;
   wire       s_logisimNet32;
   wire       s_logisimNet33;
   wire       s_logisimNet34;
   wire       s_logisimNet35;
   wire       s_logisimNet36;
   wire       s_logisimNet37;
   wire       s_logisimNet38;
   wire       s_logisimNet39;
   wire       s_logisimNet4;
   wire       s_logisimNet40;
   wire       s_logisimNet41;
   wire       s_logisimNet42;
   wire       s_logisimNet43;
   wire       s_logisimNet44;
   wire       s_logisimNet45;
   wire       s_logisimNet46;
   wire       s_logisimNet47;
   wire       s_logisimNet48;
   wire       s_logisimNet49;
   wire       s_logisimNet5;
   wire       s_logisimNet50;
   wire       s_logisimNet51;
   wire       s_logisimNet53;
   wire       s_logisimNet54;
   wire       s_logisimNet55;
   wire       s_logisimNet58;
   wire       s_logisimNet59;
   wire       s_logisimNet6;
   wire       s_logisimNet60;
   wire       s_logisimNet61;
   wire       s_logisimNet62;
   wire       s_logisimNet63;
   wire       s_logisimNet65;
   wire       s_logisimNet66;
   wire       s_logisimNet67;
   wire       s_logisimNet68;
   wire       s_logisimNet69;
   wire       s_logisimNet7;
   wire       s_logisimNet70;
   wire       s_logisimNet71;
   wire       s_logisimNet72;
   wire       s_logisimNet74;
   wire       s_logisimNet75;
   wire       s_logisimNet76;
   wire       s_logisimNet77;
   wire       s_logisimNet78;
   wire       s_logisimNet79;
   wire       s_logisimNet8;
   wire       s_logisimNet80;
   wire       s_logisimNet81;
   wire       s_logisimNet82;
   wire       s_logisimNet83;
   wire       s_logisimNet84;
   wire       s_logisimNet85;
   wire       s_logisimNet86;
   wire       s_logisimNet87;
   wire       s_logisimNet9;

   /*******************************************************************************
   ** The module functionality is described here                                 **
   *******************************************************************************/

   /*******************************************************************************
   ** Here all input connections are defined                                     **
   *******************************************************************************/
   assign s_logisimBus18[4:0] = CSCOMM_4_0;
   assign s_logisimBus29[3:0] = IDB_7_4;
   assign s_logisimBus30[3:0] = IDB_3_0_io;
   assign s_logisimBus56[4:0] = CSIDBS_4_0;
   assign s_logisimBus57[1:0] = STAT_4_3;
   assign s_logisimBus64[1:0] = CSMIS_1_0;
   assign s_logisimBus73[1:0] = OC_1_0;
   assign s_logisimNet10      = BRK_n;
   assign s_logisimNet16      = ICONTIN_n;
   assign s_logisimNet17      = BDRY50_n;
   assign s_logisimNet33      = POWSENSE_n;
   assign s_logisimNet34      = LCS_n;
   assign s_logisimNet35      = REF_n;
   assign s_logisimNet39      = UCLK;
   assign s_logisimNet47      = SWMCL_n;
   assign s_logisimNet49      = XTAL1;
   assign s_logisimNet50      = XTAL2;
   assign s_logisimNet54      = OSCCL_n;
   assign s_logisimNet58      = HIT;
   assign s_logisimNet59      = PONI;
   assign s_logisimNet6       = OPCLCS;
   assign s_logisimNet60      = ISTOP_n;
   assign s_logisimNet62      = RMM_n;
   assign s_logisimNet63      = DAP_n;
   assign s_logisimNet74      = SEL5MS_n;
   assign s_logisimNet76      = EORF_n;
   assign s_logisimNet80      = CLK;
   assign s_logisimNet81      = LSHADOW;
   assign s_logisimNet9       = ILOAD_n;

   /*******************************************************************************
   ** Here all output connections are defined                                    **
   *******************************************************************************/
   assign CA10      = s_logisimNet11;
   assign CCLR_n    = s_logisimNet85;
   assign CEUART_n  = s_logisimNet65;
   assign CLEAR_n   = s_logisimNet0;
   assign DT_n      = s_logisimNet36;
   assign DVACC_n   = s_logisimNet42;
   assign ECREQ     = s_logisimNet41;
   assign ECSR_n    = s_logisimNet68;
   assign EDO_n     = s_logisimNet83;
   assign EIOR_n    = s_logisimNet82;
   assign EMPID_n   = s_logisimNet43;
   assign EMP_n     = s_logisimNet69;
   assign EPANS_n   = s_logisimNet5;
   assign ESTOF_n   = s_logisimNet24;
   assign FETCH     = s_logisimNet20;
   assign FMISS     = s_logisimNet84;
   assign FORM_n    = s_logisimNet44;
   assign FUL_n     = s_logisimNet4;
   assign IORQ_n    = s_logisimNet86;
   assign LHIT      = s_logisimNet87;
   assign MCL       = s_logisimNet75;
   assign MREQ_n    = s_logisimNet70;
   assign OSC       = s_logisimNet40;
   assign PANOSC    = s_logisimNet51;
   assign PAN_n     = s_logisimNet67;
   assign PA_7_0    = s_logisimBus52[7:0];
   assign PA_n      = s_logisimNet12;
   assign POWFAIL_n = s_logisimNet55;
   assign PPOSC     = s_logisimNet31;
   assign PS_n      = s_logisimNet78;
   assign REFRQ_n   = s_logisimNet1;
   assign RINR_n    = s_logisimNet38;
   assign RT_n      = s_logisimNet37;
   assign RUART_n   = s_logisimNet66;
   assign RWCS_n    = s_logisimNet45;
   assign SHORT_n   = s_logisimNet25;
   assign SIOC_n    = s_logisimNet13;
   assign SLOW_n    = s_logisimNet2;
   assign SSEMA_n   = s_logisimNet71;
   assign STOC_n    = s_logisimNet46;
   assign STP       = s_logisimNet79;
   assign TOUT      = s_logisimNet21;
   assign TRAALD_n  = s_logisimNet32;
   assign VAL       = s_logisimNet27;
   assign WCHIM_n   = s_logisimNet72;
   assign WRITE     = s_logisimNet22;

   /*******************************************************************************
   ** Here all in-lined components are defined                                   **
   *******************************************************************************/

   // Ground
   assign  s_logisimNet3  =  1'b0;


   // NOT Gate
   assign s_logisimNet26 = ~s_logisimNet33;

   // NOT Gate
   assign s_logisimNet28 = ~s_logisimBus73[0];

   /*******************************************************************************
   ** Here all normal components are defined                                     **
   *******************************************************************************/
   NAND_GATE #(.BubblesMask(2'b00))
      GATES_1 (.input1(s_logisimNet23),
               .input2(s_logisimNet48),
               .result(s_logisimNet40));

   NAND_GATE #(.BubblesMask(2'b00))
      GATES_2 (.input1(s_logisimNet3),
               .input2(s_logisimNet47),
               .result(s_logisimNet77));

   NAND_GATE_3_INPUTS #(.BubblesMask(3'b000))
      GATES_3 (.input1(s_logisimNet49),
               .input2(s_logisimBus73[1]),
               .input3(s_logisimBus73[0]),
               .result(s_logisimNet23));

   NAND_GATE #(.BubblesMask(2'b00))
      GATES_4 (.input1(s_logisimBus73[1]),
               .input2(s_logisimNet50),
               .result(s_logisimNet15));

   NAND_GATE #(.BubblesMask(2'b00))
      GATES_5 (.input1(s_logisimNet54),
               .input2(s_logisimNet3),
               .result(s_logisimNet14));

   NAND_GATE #(.BubblesMask(2'b00))
      GATES_6 (.input1(s_logisimNet28),
               .input2(s_logisimNet15),
               .result(s_logisimNet48));

   OR_GATE #(.BubblesMask(2'b00))
      GATES_7 (.input1(s_logisimNet77),
               .input2(s_logisimNet6),
               .result(s_logisimNet8));


   /*******************************************************************************
   ** Here all sub-circuits are defined                                          **
   *******************************************************************************/

   TTL_74393   CHIP_13C_1 (.A_n(s_logisimNet49),
                           .CLR(s_logisimNet14),
                           .QA(),
                           .QB(),
                           .QC(s_logisimNet31),
                           .QD(s_logisimNet53));

   TTL_74393   CHIP_13C_2 (.A_n(s_logisimNet53),
                           .CLR(s_logisimNet14),
                           .QA(),
                           .QB(),
                           .QC(),
                           .QD(s_logisimNet19));

endmodule

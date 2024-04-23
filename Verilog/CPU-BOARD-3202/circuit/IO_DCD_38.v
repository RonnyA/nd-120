/**************************************************************************
** ND120 CPU, MM&M                                                       **
** IO/DCD                                                                **
** IO DECODING                                                           **
** SHEET 38 of 50                                                        **
**                                                                       ** 
** Last reviewed: 21-APRIL-2024                                          **
** Ronny Hansen                                                          **               
***************************************************************************/

module IO_DCD_38( 
   input       BDRY50_n,
   input       BRK_n,
   input       CLK,
   input [4:0] CSCOMM_4_0,
   input [4:0] CSIDBS_4_0,
   input [1:0] CSMIS_1_0,
   input       DAP_n,
   input       EORF_n,
   input       HIT,
   input       ICONTIN_n,
   

   input       ILOAD_n,
   input       ISTOP_n,
   input       LCS_n,
   input       LSHADOW,
   input [1:0] OC_1_0,
   input       OPCLCS,
   input       OSCCL_n,
   input       PONI,
   input       POWSENSE_n,
   input       REF_n,
   input       RMM_n,
   input       SEL5MS_n,
   input [1:0] STAT_4_3,
   input       SWMCL_n,
   input       UCLK,
   input       XTAL1,
   input       XTAL2,

   input  [7:0] IDB_7_0_IN,
   output [3:0] IDB_3_0_OUT,


   output       CA10,
   output       CCLR_n,
   output       CEUART_n,
   output       CLEAR_n,
   output       DT_n,
   output       DVACC_n,
   output       ECREQ,
   output       ECSR_n,
   output       EDO_n,
   output       EIOR_n,
   output       EMPID_n,
   output       EMP_n,
   output       EPANS_n,
   output       ESTOF_n,
   output       FETCH,
   output       FMISS,
   output       FORM_n,
   output       FUL_n,
   output       IORQ_n,
   output       LHIT,
   output       MCL,
   output       MREQ_n,
   output       OSC,
   output       PANOSC,
   output       PAN_n,
   output [7:0] PA_7_0,
   output       PA_n,
   output       POWFAIL_n,
   output       PPOSC,
   output       PS_n,
   output       REFRQ_n,
   output       RINR_n,
   output       RT_n,
   output       RUART_n,
   output       RWCS_n,
   output       SHORT_n,
   output       SIOC_n,
   output       SLOW_n,
   output       SSEMA_n,
   output       STOC_n,
   output       STP,
   output       TOUT,
   output       TRAALD_n,
   output       VAL,
   output       WCHIM_n,
   output       WRITE,
   output       EPAN_n // Signal on the DGA chip (not connected in sheet 39). Maybe replaced by a PAL signal ?                  
);

   
   /*******************************************************************************
   ** The wires are defined here                                                 **
   *******************************************************************************/
   wire [4:0] s_logisimBus18;
   
   wire [7:0] s_IDB_7_0_in;
   wire [7:0] s_IDB_7_0_out;

   wire [7:0] s_pa_7_0;
   wire [4:0] s_logisimBus56;
   wire [1:0] s_logisimBus57;
   wire [1:0] s_logisimBus64;
   wire [1:0] s_oc_1_0;
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
   wire       s_XRTOSC;
   wire       s_logisimNet2;
   wire       s_logisimNet20;
   wire       s_logisimNet21;
   wire       s_logisimNet22;
   wire       s_and_to_osc;
   wire       s_logisimNet24;
   wire       s_logisimNet25;
   wire       s_powsense;
   wire       s_logisimNet27;
   wire       s_oc0;
   wire       s_oc0_n;
   wire       s_oc1;
   wire       s_high;
   wire       s_PPOSC;
   wire       s_logisimNet32;
   wire       s_powsense_n;
   wire       s_logisimNet34;
   wire       s_logisimNet35;
   wire       s_logisimNet36;
   wire       s_logisimNet37;
   wire       s_logisimNet38;
   wire       s_logisimNet39;
   wire       s_logisimNet4;
   wire       s_osc;
   wire       s_logisimNet41;
   wire       s_logisimNet42;
   wire       s_logisimNet43;
   wire       s_logisimNet44;
   wire       s_logisimNet45;
   wire       s_logisimNet46;
   wire       s_logisimNet47;
   wire       s_logisimNet48;
   wire       s_XTAL1;
   wire       s_logisimNet5;
   wire       s_XTAL2;
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
   wire       s_clk; // bus IOTIM B
   wire       s_lshadow;
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
   
   assign s_IDB_7_0_in[3:0] = IDB_7_0_IN;

   assign s_logisimBus56[4:0] = CSIDBS_4_0;
   assign s_logisimBus57[1:0] = STAT_4_3;
   assign s_logisimBus64[1:0] = CSMIS_1_0;
   assign s_oc_1_0[1:0]       = OC_1_0;
   assign s_logisimNet10      = BRK_n;
   assign s_logisimNet16      = ICONTIN_n;
   assign s_logisimNet17      = BDRY50_n;
   assign s_powsense_n        = POWSENSE_n;
   assign s_logisimNet34      = LCS_n;
   assign s_logisimNet35      = REF_n;
   assign s_logisimNet39      = UCLK;
   assign s_logisimNet47      = SWMCL_n;
   assign s_XTAL1             = XTAL1;
   assign s_XTAL2             = XTAL2;
   assign s_logisimNet54      = OSCCL_n;
   assign s_logisimNet58      = HIT;
   assign s_logisimNet59      = PONI;
   assign s_logisimNet6       = OPCLCS;
   assign s_logisimNet60      = ISTOP_n;
   assign s_logisimNet62      = RMM_n;
   assign s_logisimNet63      = DAP_n;
   assign s_logisimNet74      = SEL5MS_n;
   assign s_logisimNet76      = EORF_n;
   assign s_clk               = CLK;
   assign s_lshadow           = LSHADOW;
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
   assign OSC       = s_osc;
   assign PANOSC    = s_logisimNet51;
   assign PAN_n     = s_logisimNet67;
   assign PA_7_0    = s_pa_7_0[7:0];
   assign PA_n      = s_logisimNet12;
   assign POWFAIL_n = s_logisimNet55;
   assign PPOSC     = s_PPOSC;
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

   // HIGH (schematic is via a zener diode, not sure what this is about - estimated 500 uc delay - which may be used to reset CLOSC and PWCL signal)
   assign  s_high  =  1'b1;


   // NOT Gate
   assign s_powsense = ~s_powsense_n;

   // OC 0 and 1
   assign s_oc0   = s_oc_1_0[0];
   assign s_oc0_n = ~s_oc0;
   assign s_oc1   = s_oc_1_0[1];
   

   /*******************************************************************************
   ** Here all normal components are defined                                     **
   *******************************************************************************/

   assign s_osc          = ~(s_and_to_osc & s_logisimNet48);
   assign s_logisimNet77 = ~(s_high & s_logisimNet47);
   assign s_and_to_osc   = ~(s_XTAL1 & s_oc1 & s_oc0);
   assign s_logisimNet15 = ~(s_oc1 & s_XTAL2);
   assign s_logisimNet14 = ~(s_logisimNet54 & s_high);
   assign s_logisimNet48 = ~(s_oc0_n & s_logisimNet15);
   assign s_logisimNet8  = s_logisimNet77 | s_logisimNet6;


   /*******************************************************************************
   ** Here all sub-circuits are defined                                          **
   *******************************************************************************/

   TTL_74393   CHIP_13C_1 (.CLK_n(s_XTAL1),
                           .RESET(s_logisimNet14),
                           .QA(),
                           .QB(),
                           .QC(s_PPOSC),  // Signal PPOSC leaving DCD (4.9152 Mhz clock for UART)
                           .QD(s_logisimNet53));

   TTL_74393   CHIP_13C_2 (.CLK_n(s_logisimNet53),
                           .RESET(s_logisimNet14),
                           .QA(),
                           .QB(),
                           .QC(),
                           .QD(s_XRTOSC)  // Signal RTOSC going to DGA (153.6Khz)
                           );


   wire CLOSC;  // CLOSC
   assign CLOSC = s_logisimNet14;

   wire PWCL;
   assign PWCL = ~SWMCL_n | OPCLCS;


   wire TESTE;
   assign TESTE = 1'b1;  // <=== TEST ENABLE (?) Must be 1 for normal operation

   wire XTESTO;  
   


   DECODE_DGA  DGA(
            /** INPUT **/

            .XBDN(BDRY50_n),  
            .XBRN(BRK_n),
            .XCLK(CLK),
            .XCLO(CLOSC),  
            .XCON(ICONTIN_n),
            .XCO_4_0(CSCOMM_4_0),
            .XDAN(DAP_n),
            .XEFN(REF_n),
            .XEON(EORF_n),
            .XHIN(~HIT),  // XHIT_n (negated)
            .XID_4_0(CSIDBS_4_0),
            .XIDB_7_0_IN(IDB_7_0_IN),
            .XIDB_3_0_OUT(IDB_3_0_OUT),
            
            .XLCN(LCS_n),
            .XLON(ILOAD_n),
            .XLSH(LSHADOW),
            .XMI_1_0(CSMIS_1_0),
            .XPOI(PONI),   
            .XPOW(POWSENSE_n), 
            .XPWC(PWCL),
            .XRMN(RMM_n),
            .XRTO(s_XRTOSC),    // XRTOSC 
            .XS5N(SEL5MS_n),
            .XST_4_3(STAT_4_3),
            .XTES(TESTE),                     
            .XTON(ISTOP_n),
            .XUCK(UCLK),

            /** OUTPUT **/
            .XA_7_0(s_pa_7_0),            
            .XC10(CA10),
            .XCLN(CLEAR_n),
            .XCRN(CCLR_n),
            .XCSN(ECSR_n),
            .XDON(EDO_n),
            .XDTN(DT_n),
            .XDVN(DVACC_n),
            .XECR(ECREQ),
            .XEMN(EMP_n),
            .XEPN(EPAN_n),
            .XESN(ESTOF_n),
            .XEUN(CEUART_n),
            .XFEC(FETCH),
            .XFMI(FMISS),
            .XFON(FORM_n),
            .XFUN(FUL_n),
            .XION(EIOR_n),
            .XI_3_0_C(),
            .XI_3_0_O(),
            .XLHN(LHIT),  
            .XMCL(MCL),
            .XMRN(MREQ_n),
            .XOCN(SIOC_n),
            .XPAN(PA_n),
            .XPEN(PS_n),
            .XPFN(POWFAIL_n),
            .XPIN(EMPID_n),
            .XPNN(PAN_n),
            .XPSC(PANOSC),
            .XPSN(EPANS_n),
            .XRFN(REFRQ_n),
            .XRIN(RINR_n),
            .XRQN(IORQ_n),
            .XRTN(RT_n),
            .XRUN(RUART_n),
            .XRWN(RWCS_n), // (NOT CONNECTED IN SHEET 39)
            .XSCN(STOC_n),
            .XSHN(SHORT_n),
            .XSSN(SSEMA_n),
            .XSTP(STP),
            .XSWN(SLOW_n),
            .XTEO(XTESTO),  // TEST OUTPUT (NOT CONNECTED IN SHEET 39)
            .XTOT(TOUT),
            .XTRN(TRAALD_n),
            .XVAL(VAL),
            .XWHN(WCHIM_n),
            .XWRI(WRITE)                  

   );


 



endmodule

/**************************************************************************
** ND120 CPU, MM&M                                                       **
** BIF/BCTL                                                              **
** BIF CONTROL                                                           **   
** SHEET 6 of 50                                                         **
**                                                                       ** 
** Last reviewed: 13-MAY-2024                                            **
** Ronny Hansen                                                          **               
***************************************************************************/

module BIF_BCTL_6
(
   input CBWRITE_n,
   input CC2_n,
   input CGNT50_n,
   input CGNT_n,
   input CLEAR_n,
   input CRQ_n,
   input DBAPR,
   input GNT50_n,
   input IBDAP_n,
   input IBDRY_n,
   input IBINPUT_n,
   input IBPERR_n,
   input IBREQ_n,
   input IORQ_n,
   input ISEMRQ_n,
   input LERR_n,
   input LPERR_n,
   input MIS0,
   input MOFF_n,
   input MOR25_n,
   input OSC,
   input PA_n,
   input PD1,
   input PD3,
   input PS_n,
   input REFRQ_n,
   input SSEMA_n,
   input TERM_n,
   input TOUT,

   output       BAPR_n,
   output       BDAP50_n,
   output       BDAP_n,
   output       BDRY25_n,
   output       BDRY50_n,
   output       BDRY_n,
   output       BERROR_n,
   output       BINACK_n,
   output       BINPUT50_n,
   output       BINPUT_n,
   output       BIOXE_n,
   output       BMEM_n,
   output       BREF_n,
   output       CACT_n,
   output       DAP_n,
   output       EADR_n,
   output       EPEA_n,
   output       EPES_n,
   output       GNT_n,
   output       IOD_n,
   output       IOXERR_n,
   output       MOR_n,
   output       MR_n,
   output       OUTGRANT_n,
   output       OUTIDENT_n,
   output       PARERR_n,
   output [2:0] Q_2_0_n,
   output       REF_n,
   output       RERR_n,
   output       SEMRQ50_n,
   output       SEMRQ_n,
   output       SPEA,
   output       SPES
);   

 
   /*******************************************************************************
   ** The wires are defined here                                                 **
   *******************************************************************************/
   wire [2:0] s_logisimBus48;
   wire       s_logisimNet0;
   wire       s_logisimNet1;
   wire       s_logisimNet10;
   wire       s_logisimNet11;
   wire       s_logisimNet12;
   wire       s_logisimNet13;
   wire       s_pd1;
   wire       s_logisimNet15;
   wire       s_logisimNet16;
   wire       s_logisimNet17;
   wire       s_logisimNet18;
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
   wire       s_bdry50_n;
   wire       s_logisimNet29;
   wire       s_logisimNet3;
   wire       s_logisimNet30;
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
   wire       s_logisimNet49;
   wire       s_logisimNet5;
   wire       s_logisimNet50;
   wire       s_logisimNet51;
   wire       s_logisimNet52;
   wire       s_logisimNet53;
   wire       s_logisimNet54;
   wire       s_logisimNet55;
   wire       s_logisimNet56;
   wire       s_logisimNet57;
   wire       s_logisimNet58;
   wire       s_logisimNet59;
   wire       s_logisimNet6;
   wire       s_logisimNet60;
   wire       s_logisimNet61;
   wire       s_logisimNet62;
   wire       s_logisimNet63;
   wire       s_logisimNet64;
   wire       s_logisimNet65;
   wire       s_logisimNet66;
   wire       s_logisimNet67;
   wire       s_logisimNet68;
   wire       s_logisimNet69;
   wire       s_logisimNet7;
   wire       s_osc;
   wire       s_logisimNet71;
   wire       s_logisimNet72;
   wire       s_logisimNet73;
   wire       s_logisimNet74;
   wire       s_logisimNet75;
   wire       s_logisimNet76;
   wire       s_pd3;
   wire       s_logisimNet78;
   wire       s_logisimNet79;
   wire       s_logisimNet8;
   wire       s_logisimNet80;
   wire       s_logisimNet81;
   wire       s_logisimNet9;

   /*******************************************************************************
   ** The module functionality is described here                                 **
   *******************************************************************************/

   /*******************************************************************************
   ** Here all input connections are defined                                     **
   *******************************************************************************/
   assign s_logisimNet0  = TERM_n;
   assign s_logisimNet12 = MOFF_n;
   assign s_pd1          = PD1;
   assign s_logisimNet16 = IORQ_n;
   assign s_logisimNet25 = DBAPR;
   assign s_logisimNet26 = CLEAR_n;
   assign s_logisimNet27 = IBDAP_n;
   assign s_logisimNet29 = IBPERR_n;
   assign s_logisimNet32 = IBREQ_n;
   assign s_logisimNet39 = GNT50_n;
   assign s_logisimNet42 = IBDRY_n;
   assign s_logisimNet49 = CC2_n;
   assign s_logisimNet50 = CGNT_n;
   assign s_logisimNet51 = MOR25_n;
   assign s_logisimNet54 = REFRQ_n;
   assign s_logisimNet56 = CRQ_n;
   assign s_logisimNet58 = TOUT;
   assign s_logisimNet6  = IBINPUT_n;
   assign s_logisimNet63 = PS_n;
   assign s_logisimNet64 = CGNT50_n;
   assign s_logisimNet65 = LPERR_n;
   assign s_logisimNet66 = ISEMRQ_n;
   assign s_logisimNet67 = SSEMA_n;
   assign s_logisimNet69 = PA_n;
   assign s_osc          = OSC;
   assign s_logisimNet71 = LERR_n;
   assign s_logisimNet72 = MIS0;
   assign s_pd3          = PD3;
   assign s_logisimNet8  = CBWRITE_n;

   /*******************************************************************************
   ** Here all output connections are defined                                    **
   *******************************************************************************/
   assign BAPR_n     = s_logisimNet22;
   assign BDAP50_n   = s_logisimNet33;
   assign BDAP_n     = s_logisimNet21;
   assign BDRY25_n   = s_logisimNet11;
   assign BDRY50_n   = s_bdry50_n;
   assign BDRY_n     = s_logisimNet61;
   assign BERROR_n   = s_logisimNet44;
   assign BINACK_n   = s_logisimNet60;
   assign BINPUT50_n = s_logisimNet76;
   assign BINPUT_n   = s_logisimNet62;
   assign BIOXE_n    = s_logisimNet43;
   assign BMEM_n     = s_logisimNet45;
   assign BREF_n     = s_logisimNet75;
   assign CACT_n     = s_logisimNet35;
   assign DAP_n      = s_logisimNet13;
   assign EADR_n     = s_logisimNet34;
   assign EPEA_n     = s_logisimNet4;
   assign EPES_n     = s_logisimNet23;
   assign GNT_n      = s_logisimNet31;
   assign IOD_n      = s_logisimNet9;
   assign IOXERR_n   = s_logisimNet73;
   assign MOR_n      = s_logisimNet20;
   assign MR_n       = s_logisimNet37;
   assign OUTGRANT_n = s_logisimNet74;
   assign OUTIDENT_n = s_logisimNet19;
   assign PARERR_n   = s_logisimNet78;
   assign Q_2_0_n    = s_logisimBus48[2:0];
   assign REF_n      = s_logisimNet36;
   assign RERR_n     = s_logisimNet3;
   assign SEMRQ50_n  = s_logisimNet17;
   assign SEMRQ_n    = s_logisimNet46;
   assign SPEA       = s_logisimNet24;
   assign SPES       = s_logisimNet47;

   /*******************************************************************************
   ** Here all normal components are defined                                     **
   *******************************************************************************/
   NAND_GATE #(.BubblesMask(2'b11))
      GATES_1 (.input1(s_logisimNet63),
               .input2(s_logisimNet3),
               .result(s_logisimNet23));

   NAND_GATE #(.BubblesMask(2'b11))
      GATES_2 (.input1(s_logisimNet69),
               .input2(s_logisimNet3),
               .result(s_logisimNet4));


   /*******************************************************************************
   ** Here all sub-circuits are defined                                          **
   *******************************************************************************/

   PAL_44801A   PAL_44801_UBARB 
   (
      .CK(s_osc),                // Clock signal                         
      .OE_n(s_pd3),              // OUTPUT ENABLE (active-low) for Q0-Q5 

      .CRQ_n(s_logisimNet56),     // I0 - CRQ_n      
      .IORQ_n(s_logisimNet16),    // I1 - IORQ_n     
      .MR_n(s_logisimNet37),      // I2 - MR_n       
      .BRQ50_n(s_logisimNet5),    // I3 - BRQ50_n    
      .REFRQ50_n(s_logisimNet1),  // I4 - REFRQ50_n  
      .BDRY25_n(s_logisimNet2),   // I5 - BDRY25_n   
      .SEMRQ50_n(s_logisimNet17), // I6 - SEMRQ50_n  
      //.MOFF_n(s_logisimNet12),  // I7 - MOFF_n     

      .SEM_n(s_logisimNet18),     // Q0_n - SEM_n          
      .ACT_n(s_logisimNet41),     // Q1_n - ACT_n (n.c.)   
      .DOREF_n(s_logisimNet59),   // Q2_n - DOREF_n (n.c.) 
      .MEM_n(s_logisimNet10),     // Q3_n - MEM_n (n.c.)   
      .REF_n(s_logisimNet36),     // Q4_n - REF_n          
      .IOD_n(s_logisimNet9),      // Q5_n - IOD_n          
      .GNT_n(s_logisimNet31),     // Q6_n - GNT_n          
      .CACT_n(s_logisimNet35)     // Q7_n - CACT_n         
   );

   PAL_44401B   PAL_44401_UBTIM 
   (
      .CK(s_osc),
      .OE_n(s_pd1),
            
      .CC2_n(s_logisimNet49),      // I0 
      .CACT_n(s_logisimNet35),     // I1 
      .CACT25_n(s_logisimNet11),   // I2 
      .BDRY50_n(s_bdry50_n),       // I3 
      .CGNT_n(s_logisimNet50),     // I4 
      .CGNT50_n(s_logisimNet64),   // I5 
      .TERM_n(s_logisimNet0),      // I6 
      .IORQ_n(s_logisimNet16),     // I7 
                                   
      .Q0_n(s_logisimBus48[0]),    // Q0_n                            
      .Q1_n(s_logisimBus48[1]),    // Q1_n                            
      .Q2_n(s_logisimBus48[2]),    // Q2_n                            
      //.Q3_n(),                   // Q3_n (not connected, no signal) 
                                   
      .APR_n(s_logisimNet7),       // B0_n 
      .DAP_n(s_logisimNet13),      // B1_n 
      .EIOD_n(s_logisimNet38),     // B2_n 
      .EADR_n(s_logisimNet34)      // B3_n 
   );
      
   PAL_45001B   PAL_45001_UBPAR 
   (
      .BDRY50_n(s_bdry50_n),       // I0 - BDRY50_n  
      .BDRY75_n(s_logisimNet53),   // I1 - BDRY75_n  
      .BLOCK25_n(s_logisimNet52),  // I2 - BLOCK25_n 
      .BPERR50_n(s_logisimNet30),  // I3 - BPERR50_n 
      .DBAPR_n(s_logisimNet25),    // I4 - DBAPR_n   
      .MOR25_n(s_logisimNet51),    // I5 - MOR25_n   
      .LPERR_n(s_logisimNet65),    // I6 - LPERR_n   
      .MR_n(s_logisimNet37),       // I7 - MR_n      
      .EPES_n(s_logisimNet23),     // I8 - EPES_n    
      .EPEA_n(s_logisimNet4),      // I9 - EPEA_n    
                                   
      .SPEA(s_logisimNet24),       // Y0_n (OUT Only)      
      .SPES(s_logisimNet47),       // Y1_n (OUT ONLY)      
                                                           
      .BLOCK_n(s_logisimNet68),    // B0_n - BLOCK_n (out) 
      .PARERR_n(s_logisimNet78),   // B1_n - PARERR_n (out)
      .RERR_n(s_logisimNet3),      // B2_n                 
      //.B3_n(s_logisimNet57),     // B3_n - (n.c.)        
      .TEST(s_logisimNet55),       // B4_n - PD3           
      .LERR_n(s_logisimNet15)      // B5_n                 
   );

   BIF_BCTL_BDRV_7   BDRV (.APR_n(s_logisimNet7),
                           .BAPR_n(s_logisimNet22),
                           .BDAP_n(s_logisimNet21),
                           .BDRY25_n(s_logisimNet2),
                           .BDRY50_n(s_bdry50_n),
                           .BDRY_n(s_logisimNet61),
                           .BERROR_n(s_logisimNet44),
                           .BINACK_n(s_logisimNet60),
                           .BINPUT75_n(s_logisimNet40),
                           .BINPUT_n(s_logisimNet62),
                           .BIOXE_n(s_logisimNet43),
                           .BMEM_n(s_logisimNet45),
                           .BREF_n(s_logisimNet75),
                           .CACT_n(s_logisimNet35),
                           .CBWRITE_n(s_logisimNet8),
                           .DAP_n(s_logisimNet13),
                           .EIOD_n(s_logisimNet38),
                           .GNT50_n(s_logisimNet39),
                           .IBDRY_n(s_logisimNet42),
                           .IBREQ_n(s_logisimNet32),
                           .IOD_n(s_logisimNet9),
                           .IOXERR_n(s_logisimNet73),
                           .MEM_n(s_logisimNet10),
                           .MIS0(s_logisimNet72),
                           .MOR_n(s_logisimNet20),
                           .OUTGRANT_n(s_logisimNet74),
                           .OUTIDENT_n(s_logisimNet19),
                           .REF_n(s_logisimNet36),
                           .SEMRQ_n(s_logisimNet46),
                           .SEM_n(s_logisimNet18),
                           .SSEMA_n(s_logisimNet67),
                           .TOUT(s_logisimNet58));

   BIF_BCTL_SYNC_8   SYNC (.BDAP50_n(s_logisimNet33),
                           .BDRY25_n(s_logisimNet2),
                           .BDRY50_n(s_bdry50_n),
                           .BDRY75_n(s_logisimNet53),
                           .BINPUT50_n(s_logisimNet76),
                           .BINPUT75_n(s_logisimNet40),
                           .BLOCK25_n(s_logisimNet52),
                           .BLOCK_n(s_logisimNet68),
                           .BPERR50_n(s_logisimNet30),
                           .BREQ50_n(s_logisimNet5),
                           .CACT25_n(s_logisimNet11),
                           .CACT_n(s_logisimNet35),
                           .CLEAR_n(s_logisimNet26),
                           .IBDAP_n(s_logisimNet27),
                           .IBDRY_n(s_logisimNet42),
                           .IBINPUT_n(s_logisimNet6),
                           .IBPERR_n(s_logisimNet29),
                           .IBREQ_n(s_logisimNet32),
                           .ISEMRQ_n(s_logisimNet66),
                           .MR_n(s_logisimNet37),
                           .OSC(s_osc),
                           .PD1(s_pd1),
                           .PD3(s_pd3),
                           .REFRQ50_n(s_logisimNet1),
                           .REFRQ_n(s_logisimNet54),
                           .SEMRQ50_n(s_logisimNet17));

endmodule

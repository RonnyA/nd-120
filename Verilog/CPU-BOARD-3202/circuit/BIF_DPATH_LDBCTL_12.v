/******************************************************************************
 ** Logisim-evolution goes FPGA automatic generated Verilog code             **
 ** https://github.com/logisim-evolution/                                    **
 **                                                                          **
 ** Component : BIF_DPATH_LDBCTL_12                                          **
 **                                                                          **
 *****************************************************************************/

module BIF_DPATH_LDBCTL_12( BDAP50_n,
                            BDRY25_n,
                            BDRY50_n,
                            BGNT50_n,
                            BGNTCACT,
                            BGNT_n,
                            BINPUT50_n,
                            CACT_n,
                            CBWRITE_n,
                            CC2_n,
                            CGNT50_n,
                            CGNTCACT_n,
                            CGNT_n,
                            CLKBD,
                            DBAPR,
                            DSTB_n,
                            EADR_n,
                            EBADR,
                            EBD_n,
                            EBUS_n,
                            EMD_n,
                            GNT_n,
                            IBAPR_n,
                            IOD_n,
                            IORQ_n,
                            MIS0,
                            MWRITE_n,
                            PD1,
                            PD3,
                            Q0_n,
                            Q2_n,
                            RT_n,
                            TERM_n,
                            WBD_n,
                            WLBD_n,
                            WRITE );

   /*******************************************************************************
   ** The inputs are defined here                                                **
   *******************************************************************************/
   input BDAP50_n;
   input BDRY25_n;
   input BDRY50_n;
   input BGNT50_n;
   input BGNT_n;
   input BINPUT50_n;
   input CACT_n;
   input CC2_n;
   input CGNT50_n;
   input CGNT_n;
   input EADR_n;
   input EBUS_n;
   input GNT_n;
   input IBAPR_n;
   input IOD_n;
   input IORQ_n;
   input MIS0;
   input MWRITE_n;
   input PD1;
   input PD3;
   input Q0_n;
   input Q2_n;
   input RT_n;
   input TERM_n;
   input WRITE;

   /*******************************************************************************
   ** The outputs are defined here                                               **
   *******************************************************************************/
   output BGNTCACT;
   output CBWRITE_n;
   output CGNTCACT_n;
   output CLKBD;
   output DBAPR;
   output DSTB_n;
   output EBADR;
   output EBD_n;
   output EMD_n;
   output WBD_n;
   output WLBD_n;

   /*******************************************************************************
   ** The wires are defined here                                                 **
   *******************************************************************************/
   wire s_logisimNet0;
   wire s_logisimNet1;
   wire s_logisimNet10;
   wire s_logisimNet11;
   wire s_logisimNet12;
   wire s_logisimNet13;
   wire s_logisimNet14;
   wire s_logisimNet15;
   wire s_logisimNet16;
   wire s_logisimNet17;
   wire s_logisimNet18;
   wire s_logisimNet19;
   wire s_logisimNet2;
   wire s_logisimNet20;
   wire s_logisimNet21;
   wire s_logisimNet22;
   wire s_logisimNet23;
   wire s_logisimNet24;
   wire s_logisimNet25;
   wire s_logisimNet26;
   wire s_logisimNet27;
   wire s_logisimNet28;
   wire s_logisimNet29;
   wire s_logisimNet3;
   wire s_logisimNet30;
   wire s_logisimNet31;
   wire s_logisimNet32;
   wire s_logisimNet33;
   wire s_logisimNet34;
   wire s_logisimNet35;
   wire s_logisimNet36;
   wire s_logisimNet37;
   wire s_logisimNet38;
   wire s_logisimNet39;
   wire s_logisimNet4;
   wire s_logisimNet40;
   wire s_logisimNet41;
   wire s_logisimNet42;
   wire s_logisimNet5;
   wire s_logisimNet6;
   wire s_logisimNet7;
   wire s_logisimNet8;
   wire s_logisimNet9;

   /*******************************************************************************
   ** The module functionality is described here                                 **
   *******************************************************************************/

   /*******************************************************************************
   ** Here all input connections are defined                                     **
   *******************************************************************************/
   assign s_logisimNet0  = CACT_n;
   assign s_logisimNet12 = CGNT_n;
   assign s_logisimNet15 = BGNT_n;
   assign s_logisimNet17 = BGNT50_n;
   assign s_logisimNet18 = MWRITE_n;
   assign s_logisimNet19 = BDAP50_n;
   assign s_logisimNet2  = PD3;
   assign s_logisimNet20 = EBUS_n;
   assign s_logisimNet21 = IBAPR_n;
   assign s_logisimNet22 = GNT_n;
   assign s_logisimNet3  = Q0_n;
   assign s_logisimNet35 = EADR_n;
   assign s_logisimNet36 = BINPUT50_n;
   assign s_logisimNet37 = MIS0;
   assign s_logisimNet38 = IOD_n;
   assign s_logisimNet39 = WRITE;
   assign s_logisimNet4  = Q2_n;
   assign s_logisimNet40 = PD1;
   assign s_logisimNet41 = RT_n;
   assign s_logisimNet42 = IORQ_n;
   assign s_logisimNet5  = CC2_n;
   assign s_logisimNet6  = BDRY25_n;
   assign s_logisimNet7  = BDRY50_n;
   assign s_logisimNet8  = CGNT50_n;
   assign s_logisimNet9  = TERM_n;

   /*******************************************************************************
   ** Here all output connections are defined                                    **
   *******************************************************************************/
   assign BGNTCACT   = s_logisimNet23;
   assign CBWRITE_n  = s_logisimNet10;
   assign CGNTCACT_n = s_logisimNet24;
   assign CLKBD      = s_logisimNet32;
   assign DBAPR      = s_logisimNet30;
   assign DSTB_n     = s_logisimNet26;
   assign EBADR      = s_logisimNet31;
   assign EBD_n      = s_logisimNet33;
   assign EMD_n      = s_logisimNet25;
   assign WBD_n      = s_logisimNet13;
   assign WLBD_n     = s_logisimNet1;

   /*******************************************************************************
   ** Here all sub-circuits are defined                                          **
   *******************************************************************************/

   PAL_16L8_12   PAL_44303_ULBC2 (.B0_n(s_logisimNet10),
                                  .B1_n(s_logisimNet16),
                                  .B2_n(),
                                  .B3_n(),
                                  .B4_n(),
                                  .B5_n(),
                                  .I0(s_logisimNet0),
                                  .I1(s_logisimNet12),
                                  .I2(s_logisimNet35),
                                  .I3(s_logisimNet36),
                                  .I4(s_logisimNet37),
                                  .I5(s_logisimNet38),
                                  .I6(s_logisimNet39),
                                  .I7(s_logisimNet40),
                                  .I8(1'b0),
                                  .I9(s_logisimNet34),
                                  .Y0_n(s_logisimNet13),
                                  .Y1_n(s_logisimNet1));

   PAL_16L8_12   PAL_44302_ULBC1 (.B0_n(s_logisimNet25),
                                  .B1_n(s_logisimNet26),
                                  .B2_n(),
                                  .B3_n(s_logisimNet27),
                                  .B4_n(s_logisimNet14),
                                  .B5_n(s_logisimNet11),
                                  .I0(s_logisimNet3),
                                  .I1(s_logisimNet4),
                                  .I2(s_logisimNet5),
                                  .I3(s_logisimNet6),
                                  .I4(s_logisimNet7),
                                  .I5(s_logisimNet12),
                                  .I6(s_logisimNet8),
                                  .I7(s_logisimNet0),
                                  .I8(s_logisimNet9),
                                  .I9(s_logisimNet15),
                                  .Y0_n(s_logisimNet23),
                                  .Y1_n(s_logisimNet24));

   PAL_16L8_12   PAL_44304_ULBC3 (.B0_n(s_logisimNet34),
                                  .B1_n(s_logisimNet31),
                                  .B2_n(s_logisimNet28),
                                  .B3_n(s_logisimNet29),
                                  .B4_n(s_logisimNet32),
                                  .B5_n(s_logisimNet33),
                                  .I0(s_logisimNet12),
                                  .I1(s_logisimNet15),
                                  .I2(s_logisimNet17),
                                  .I3(s_logisimNet18),
                                  .I4(s_logisimNet19),
                                  .I5(s_logisimNet20),
                                  .I6(s_logisimNet21),
                                  .I7(s_logisimNet22),
                                  .I8(s_logisimNet2),
                                  .I9(1'b0),
                                  .Y0_n(s_logisimNet30),
                                  .Y1_n());

endmodule

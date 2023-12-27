/******************************************************************************
 ** Logisim-evolution goes FPGA automatic generated Verilog code             **
 ** https://github.com/logisim-evolution/                                    **
 **                                                                          **
 ** Component : BIF_BCTL_SYNC_8                                              **
 **                                                                          **
 *****************************************************************************/

module BIF_BCTL_SYNC_8( BDAP50_n,
                        BDRY25_n,
                        BDRY50_n,
                        BDRY75_n,
                        BINPUT50_n,
                        BINPUT75_n,
                        BLOCK25_n,
                        BLOCK_n,
                        BPERR50_n,
                        BREQ50_n,
                        CACT25_n,
                        CACT_n,
                        CLEAR_n,
                        IBDAP_n,
                        IBDRY_n,
                        IBINPUT_n,
                        IBPERR_n,
                        IBREQ_n,
                        ISEMRQ_n,
                        MR_n,
                        OSC,
                        PD1,
                        PD3,
                        REFRQ50_n,
                        REFRQ_n,
                        SEMRQ50_n );

   /*******************************************************************************
   ** The inputs are defined here                                                **
   *******************************************************************************/
   input BLOCK_n;
   input CACT_n;
   input CLEAR_n;
   input IBDAP_n;
   input IBDRY_n;
   input IBINPUT_n;
   input IBPERR_n;
   input IBREQ_n;
   input ISEMRQ_n;
   input OSC;
   input PD1;
   input PD3;
   input REFRQ_n;

   /*******************************************************************************
   ** The outputs are defined here                                               **
   *******************************************************************************/
   output BDAP50_n;
   output BDRY25_n;
   output BDRY50_n;
   output BDRY75_n;
   output BINPUT50_n;
   output BINPUT75_n;
   output BLOCK25_n;
   output BPERR50_n;
   output BREQ50_n;
   output CACT25_n;
   output MR_n;
   output REFRQ50_n;
   output SEMRQ50_n;

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
   wire s_logisimNet4;
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
   assign s_logisimNet17 = IBDAP_n;
   assign s_logisimNet18 = BLOCK_n;
   assign s_logisimNet19 = CACT_n;
   assign s_logisimNet2  = OSC;
   assign s_logisimNet20 = IBPERR_n;
   assign s_logisimNet21 = ISEMRQ_n;
   assign s_logisimNet22 = CLEAR_n;
   assign s_logisimNet23 = REFRQ_n;
   assign s_logisimNet24 = IBINPUT_n;
   assign s_logisimNet25 = IBDRY_n;
   assign s_logisimNet3  = PD1;
   assign s_logisimNet5  = PD3;
   assign s_logisimNet7  = IBREQ_n;

   /*******************************************************************************
   ** Here all output connections are defined                                    **
   *******************************************************************************/
   assign BDAP50_n   = s_logisimNet11;
   assign BDRY25_n   = s_logisimNet0;
   assign BDRY50_n   = s_logisimNet4;
   assign BDRY75_n   = s_logisimNet9;
   assign BINPUT50_n = s_logisimNet1;
   assign BINPUT75_n = s_logisimNet12;
   assign BLOCK25_n  = s_logisimNet16;
   assign BPERR50_n  = s_logisimNet8;
   assign BREQ50_n   = s_logisimNet10;
   assign CACT25_n   = s_logisimNet6;
   assign MR_n       = s_logisimNet15;
   assign REFRQ50_n  = s_logisimNet13;
   assign SEMRQ50_n  = s_logisimNet14;

   /*******************************************************************************
   ** Here all sub-circuits are defined                                          **
   *******************************************************************************/

   AM29C821   CHIP_4D (.CK(s_logisimNet2),
                       .D0(s_logisimNet26),
                       .D1(s_logisimNet27),
                       .D2(s_logisimNet28),
                       .D3(s_logisimNet29),
                       .D4(s_logisimNet30),
                       .D5(s_logisimNet0),
                       .D6(s_logisimNet4),
                       .D7(s_logisimNet31),
                       .D8(s_logisimNet32),
                       .D9(s_logisimNet1),
                       .OE_n(s_logisimNet3),
                       .Y0(s_logisimNet15),
                       .Y1(s_logisimNet13),
                       .Y2(s_logisimNet14),
                       .Y3(s_logisimNet1),
                       .Y4(s_logisimNet8),
                       .Y5(s_logisimNet4),
                       .Y6(s_logisimNet9),
                       .Y7(s_logisimNet10),
                       .Y8(s_logisimNet11),
                       .Y9(s_logisimNet12));

   AM29C821   CHIP_3D (.CK(s_logisimNet2),
                       .D0(s_logisimNet22),
                       .D1(s_logisimNet23),
                       .D2(s_logisimNet21),
                       .D3(s_logisimNet24),
                       .D4(s_logisimNet20),
                       .D5(s_logisimNet25),
                       .D6(s_logisimNet19),
                       .D7(s_logisimNet7),
                       .D8(s_logisimNet17),
                       .D9(s_logisimNet18),
                       .OE_n(s_logisimNet5),
                       .Y0(s_logisimNet26),
                       .Y1(s_logisimNet27),
                       .Y2(s_logisimNet28),
                       .Y3(s_logisimNet29),
                       .Y4(s_logisimNet30),
                       .Y5(s_logisimNet0),
                       .Y6(s_logisimNet6),
                       .Y7(s_logisimNet31),
                       .Y8(s_logisimNet32),
                       .Y9(s_logisimNet16));

endmodule

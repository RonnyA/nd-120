/******************************************************************************
 ** Logisim-evolution goes FPGA automatic generated Verilog code             **
 ** https://github.com/logisim-evolution/                                    **
 **                                                                          **
 ** Component : BIF_DPATH_PPNLBD_14                                          **
 **                                                                          **
 *****************************************************************************/

module BIF_DPATH_PPNLBD_14( CA_9_0,
                            EADR_n,
                            ECREQ,
                            LBD_23_0,
                            PPN_23_10 );

   /*******************************************************************************
   ** The inputs are defined here                                                **
   *******************************************************************************/
   input [9:0]  CA_9_0;
   input        EADR_n;
   input        ECREQ;
   input [13:0] PPN_23_10;

   /*******************************************************************************
   ** The outputs are defined here                                               **
   *******************************************************************************/
   output [23:0] LBD_23_0;

   /*******************************************************************************
   ** The wires are defined here                                                 **
   *******************************************************************************/
   wire [9:0]  s_ca_9_0;
   wire [23:0] s_lbd_23_0;
   wire [13:0] s_ppn_23_10;
   wire        s_logisimNet0;
   wire        s_logisimNet1;
   wire        s_logisimNet10;
   wire        s_logisimNet11;
   wire        s_logisimNet12;
   wire        s_logisimNet13;
   wire        s_logisimNet14;
   wire        s_logisimNet15;
   wire        s_logisimNet16;
   wire        s_logisimNet18;
   wire        s_logisimNet19;
   wire        s_eadr_n;
   wire        s_eadr_n0;
   wire        s_eadr_n1;
   wire        s_eadr_n2;
   wire        s_eadr_n3;
   wire        s_eadr_n4;
   wire        s_eadr_n5;
   wire        s_eadr_n6;
   wire        s_eadr_n7;
   wire        s_eadr_n8;
   wire        s_eadr_n9;
   wire        s_logisimNet3;
   wire        s_logisimNet30;
   wire        s_logisimNet31;
   wire        s_logisimNet32;
   wire        s_logisimNet33;
   wire        s_logisimNet34;
   wire        s_logisimNet35;
   wire        s_logisimNet36;
   wire        s_logisimNet38;
   wire        s_logisimNet39;
   wire        s_logisimNet4;
   wire        s_logisimNet41;
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
   wire        s_logisimNet8;
   wire        s_ecreq;

   /*******************************************************************************
   ** The module functionality is described here                                 **
   *******************************************************************************/

   /*******************************************************************************
   ** Here all input connections are defined                                     **
   *******************************************************************************/
   assign s_ca_9_0[9:0]     = CA_9_0;
   assign s_ppn_23_10[13:0] = PPN_23_10;
   assign s_eadr_n          = EADR_n;
   assign s_ecreq           = ECREQ;

   /*******************************************************************************
   ** Here all output connections are defined                                    **
   *******************************************************************************/
   assign LBD_23_0 = s_lbd_23_0[23:0];

   /*******************************************************************************
   ** Here all sub-circuits are defined                                          **
   *******************************************************************************/

   TTL_74374   CHIP_3B (.CK(s_ecreq),
                        .OE_n(s_eadr_n),
                        .D(s_ppn_23_10[13:6]),                        
                        .Q(s_lbd_23_0[23:16])                        
                        );

   TTL_74374   CHIP_4B (.CK(s_ecreq),
                        .D({s_ppn_23_10[5:0],s_ca_9_0[9:8]}),
                        .OE_n(s_eadr_n),
                        .Q(s_lbd_23_0[15:8])
                        );

   TTL_74374   CHIP_6C (.CK(s_ecreq),
                        .OE_n(s_eadr_n),
                        .D(s_ca_9_0[7:0]),                                                
                        .Q(s_lbd_23_0[7:0])                        
                        );

         

endmodule

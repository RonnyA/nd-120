/******************************************************************************
 ** Logisim-evolution goes FPGA automatic generated Verilog code             **
 ** https://github.com/logisim-evolution/                                    **
 **                                                                          **
 ** Component : BIF_DPATH_CDLBD_11                                           **
 **                                                                          **
 *****************************************************************************/

module BIF_DPATH_CDLBD_11( CD_15_0_io,
                           DSTB_n,
                           ECREQ,
                           EMD_n,
                           LBD_15_0_io,
                           WLBD_n );

   /*******************************************************************************
   ** The inputs are defined here                                                **
   *******************************************************************************/
   input        DSTB_n;
   input        ECREQ;
   input        EMD_n;
   input [15:0] LBD_15_0_io;
   input        WLBD_n;

   /*******************************************************************************
   ** The outputs are defined here                                               **
   *******************************************************************************/
   output [15:0] CD_15_0_io;

   /*******************************************************************************
   ** The wires are defined here                                                 **
   *******************************************************************************/
   wire [15:0] s_logisimBus18;
   wire [15:0] s_logisimBus6;
   wire        s_logisimNet0;
   wire        s_logisimNet10;
   wire        s_logisimNet11;
   wire        s_logisimNet12;
   wire        s_logisimNet13;
   wire        s_logisimNet14;
   wire        s_logisimNet15;
   wire        s_logisimNet16;
   wire        s_logisimNet19;
   wire        s_logisimNet2;
   wire        s_logisimNet20;
   wire        s_logisimNet21;
   wire        s_logisimNet22;
   wire        s_logisimNet23;
   wire        s_logisimNet24;
   wire        s_logisimNet25;
   wire        s_logisimNet26;
   wire        s_logisimNet27;
   wire        s_logisimNet28;
   wire        s_logisimNet29;
   wire        s_logisimNet30;
   wire        s_logisimNet31;
   wire        s_logisimNet32;
   wire        s_logisimNet33;
   wire        s_logisimNet34;
   wire        s_logisimNet35;
   wire        s_logisimNet36;
   wire        s_logisimNet37;
   wire        s_logisimNet38;
   wire        s_logisimNet39;
   wire        s_logisimNet4;
   wire        s_logisimNet40;
   wire        s_logisimNet41;
   wire        s_logisimNet42;
   wire        s_logisimNet7;
   wire        s_logisimNet8;
   wire        s_logisimNet9;

   /*******************************************************************************
   ** The module functionality is described here                                 **
   *******************************************************************************/

   /*******************************************************************************
   ** Here all input connections are defined                                     **
   *******************************************************************************/
   assign s_logisimBus6[15:0] = LBD_15_0_io;
   assign s_logisimNet0       = WLBD_n;
   assign s_logisimNet16      = ECREQ;
   assign s_logisimNet4       = DSTB_n;
   assign s_logisimNet7       = EMD_n;

   /*******************************************************************************
   ** Here all output connections are defined                                    **
   *******************************************************************************/
   assign CD_15_0_io = s_logisimBus18[15:0];

   /*******************************************************************************
   ** Here all in-lined components are defined                                   **
   *******************************************************************************/

   // Power
   assign  s_logisimNet2  =  1'b1;


   /*******************************************************************************
   ** Here all sub-circuits are defined                                          **
   *******************************************************************************/

   TTL_74646   CHIP_7B (.A1(s_logisimBus6[15]),
                        .A2(s_logisimBus6[14]),
                        .A3(s_logisimBus6[13]),
                        .A4(s_logisimBus6[12]),
                        .A5(s_logisimBus6[11]),
                        .A6(s_logisimBus6[10]),
                        .A7(s_logisimBus6[9]),
                        .A8(s_logisimBus6[8]),
                        .B1(s_logisimBus18[15]),
                        .B2(s_logisimBus18[14]),
                        .B3(s_logisimBus18[13]),
                        .B4(s_logisimBus18[12]),
                        .B5(s_logisimBus18[11]),
                        .B6(s_logisimBus18[10]),
                        .B7(s_logisimBus18[9]),
                        .B8(s_logisimBus18[8]),
                        .CLKAB(s_logisimNet4),
                        .CLKBA(s_logisimNet16),
                        .DIR(s_logisimNet0),
                        .OE_n(s_logisimNet7),
                        .SAB(s_logisimNet4),
                        .SBA(s_logisimNet2));

   TTL_74646   CHIP_6B (.A1(s_logisimBus6[7]),
                        .A2(s_logisimBus6[6]),
                        .A3(s_logisimBus6[5]),
                        .A4(s_logisimBus6[4]),
                        .A5(s_logisimBus6[3]),
                        .A6(s_logisimBus6[2]),
                        .A7(s_logisimBus6[1]),
                        .A8(s_logisimBus6[0]),
                        .B1(s_logisimBus18[7]),
                        .B2(s_logisimBus18[6]),
                        .B3(s_logisimBus18[5]),
                        .B4(s_logisimBus18[4]),
                        .B5(s_logisimBus18[3]),
                        .B6(s_logisimBus18[2]),
                        .B7(s_logisimBus18[1]),
                        .B8(s_logisimBus18[0]),
                        .CLKAB(s_logisimNet4),
                        .CLKBA(s_logisimNet16),
                        .DIR(s_logisimNet0),
                        .OE_n(s_logisimNet7),
                        .SAB(s_logisimNet4),
                        .SBA(s_logisimNet2));

endmodule

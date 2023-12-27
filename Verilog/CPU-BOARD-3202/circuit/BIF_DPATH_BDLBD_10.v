/******************************************************************************
 ** Logisim-evolution goes FPGA automatic generated Verilog code             **
 ** https://github.com/logisim-evolution/                                    **
 **                                                                          **
 ** Component : BIF_DPATH_BDLBD_10                                           **
 **                                                                          **
 *****************************************************************************/

module BIF_DPATH_BDLBD_10( BD_23_0_n_io,
                           BGNTCACT_n,
                           BGNT_n,
                           CLKBD,
                           EBADR,
                           EBD_n,
                           LBD_23_0_io,
                           WBD_n );

   /*******************************************************************************
   ** The inputs are defined here                                                **
   *******************************************************************************/
   input [23:0] BD_23_0_n_io;
   input        BGNTCACT_n;
   input        BGNT_n;
   input        CLKBD;
   input        EBADR;
   input        EBD_n;
   input        WBD_n;

   /*******************************************************************************
   ** The outputs are defined here                                               **
   *******************************************************************************/
   output [23:0] LBD_23_0_io;

   /*******************************************************************************
   ** The wires are defined here                                                 **
   *******************************************************************************/
   wire [23:0] s_logisimBus18;
   wire [23:0] s_logisimBus35;
   wire        s_logisimNet1;
   wire        s_logisimNet10;
   wire        s_logisimNet11;
   wire        s_logisimNet12;
   wire        s_logisimNet13;
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
   wire        s_logisimNet3;
   wire        s_logisimNet30;
   wire        s_logisimNet31;
   wire        s_logisimNet32;
   wire        s_logisimNet33;
   wire        s_logisimNet34;
   wire        s_logisimNet37;
   wire        s_logisimNet38;
   wire        s_logisimNet39;
   wire        s_logisimNet4;
   wire        s_logisimNet40;
   wire        s_logisimNet41;
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
   wire        s_logisimNet57;
   wire        s_logisimNet58;
   wire        s_logisimNet59;
   wire        s_logisimNet6;
   wire        s_logisimNet60;
   wire        s_logisimNet7;
   wire        s_logisimNet8;

   /*******************************************************************************
   ** The module functionality is described here                                 **
   *******************************************************************************/

   /*******************************************************************************
   ** Here all input connections are defined                                     **
   *******************************************************************************/
   assign s_logisimBus35[23:0] = BD_23_0_n_io;
   assign s_logisimNet1        = EBADR;
   assign s_logisimNet15       = EBD_n;
   assign s_logisimNet16       = WBD_n;
   assign s_logisimNet2        = CLKBD;
   assign s_logisimNet3        = BGNTCACT_n;
   assign s_logisimNet4        = BGNT_n;

   /*******************************************************************************
   ** Here all output connections are defined                                    **
   *******************************************************************************/
   assign LBD_23_0_io = s_logisimBus18[23:0];

   /*******************************************************************************
   ** Here all sub-circuits are defined                                          **
   *******************************************************************************/

   TTL_74648   CHIP_4A (.A1(s_logisimBus35[23]),
                        .A2(s_logisimBus35[22]),
                        .A3(s_logisimBus35[21]),
                        .A4(s_logisimBus35[20]),
                        .A5(s_logisimBus35[19]),
                        .A6(s_logisimBus35[18]),
                        .A7(s_logisimBus35[17]),
                        .A8(s_logisimBus35[16]),
                        .B1_n(s_logisimBus18[23]),
                        .B2_n(s_logisimBus18[22]),
                        .B3_n(s_logisimBus18[21]),
                        .B4_n(s_logisimBus18[20]),
                        .B5_n(s_logisimBus18[19]),
                        .B6_n(s_logisimBus18[18]),
                        .B7_n(s_logisimBus18[17]),
                        .B8_n(s_logisimBus18[16]),
                        .CLKAB(s_logisimNet2),
                        .CLKBA(s_logisimNet4),
                        .DIR(s_logisimNet16),
                        .OE_n(s_logisimNet15),
                        .SAB(s_logisimNet1),
                        .SBA(s_logisimNet3));

   TTL_74648   CHIP_5A (.A1(s_logisimBus35[15]),
                        .A2(s_logisimBus35[14]),
                        .A3(s_logisimBus35[13]),
                        .A4(s_logisimBus35[12]),
                        .A5(s_logisimBus35[11]),
                        .A6(s_logisimBus35[10]),
                        .A7(s_logisimBus35[9]),
                        .A8(s_logisimBus35[8]),
                        .B1_n(s_logisimBus18[15]),
                        .B2_n(s_logisimBus18[14]),
                        .B3_n(s_logisimBus18[13]),
                        .B4_n(s_logisimBus18[12]),
                        .B5_n(s_logisimBus18[11]),
                        .B6_n(s_logisimBus18[10]),
                        .B7_n(s_logisimBus18[9]),
                        .B8_n(s_logisimBus18[8]),
                        .CLKAB(s_logisimNet2),
                        .CLKBA(s_logisimNet4),
                        .DIR(s_logisimNet16),
                        .OE_n(s_logisimNet15),
                        .SAB(s_logisimNet1),
                        .SBA(s_logisimNet3));

   TTL_74648   CHIP_6A (.A1(s_logisimBus35[7]),
                        .A2(s_logisimBus35[6]),
                        .A3(s_logisimBus35[5]),
                        .A4(s_logisimBus35[4]),
                        .A5(s_logisimBus35[3]),
                        .A6(s_logisimBus35[2]),
                        .A7(s_logisimBus35[1]),
                        .A8(s_logisimBus35[0]),
                        .B1_n(s_logisimBus18[7]),
                        .B2_n(s_logisimBus18[6]),
                        .B3_n(s_logisimBus18[5]),
                        .B4_n(s_logisimBus18[4]),
                        .B5_n(s_logisimBus18[3]),
                        .B6_n(s_logisimBus18[2]),
                        .B7_n(s_logisimBus18[1]),
                        .B8_n(s_logisimBus18[0]),
                        .CLKAB(s_logisimNet2),
                        .CLKBA(s_logisimNet4),
                        .DIR(s_logisimNet16),
                        .OE_n(s_logisimNet15),
                        .SAB(s_logisimNet1),
                        .SBA(s_logisimNet3));

endmodule

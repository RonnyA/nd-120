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
   wire [9:0]  s_logisimBus17;
   wire [23:0] s_logisimBus40;
   wire [13:0] s_logisimBus42;
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
   wire        s_logisimNet9;

   /*******************************************************************************
   ** The module functionality is described here                                 **
   *******************************************************************************/

   /*******************************************************************************
   ** Here all input connections are defined                                     **
   *******************************************************************************/
   assign s_logisimBus17[9:0]  = CA_9_0;
   assign s_logisimBus42[13:0] = PPN_23_10;
   assign s_logisimNet2        = EADR_n;
   assign s_logisimNet9        = ECREQ;

   /*******************************************************************************
   ** Here all output connections are defined                                    **
   *******************************************************************************/
   assign LBD_23_0 = s_logisimBus40[23:0];

   /*******************************************************************************
   ** Here all sub-circuits are defined                                          **
   *******************************************************************************/

   TTL_74374   CHIP_3B (.CK(s_logisimNet9),
                        .D1(s_logisimBus42[13]),
                        .D2(s_logisimBus42[12]),
                        .D3(s_logisimBus42[11]),
                        .D4(s_logisimBus42[10]),
                        .D5(s_logisimBus42[9]),
                        .D6(s_logisimBus42[8]),
                        .D7(s_logisimBus42[7]),
                        .D8(s_logisimBus42[6]),
                        .OE_n(s_logisimNet2),
                        .Q1(s_logisimBus40[23]),
                        .Q2(s_logisimBus40[22]),
                        .Q3(s_logisimBus40[21]),
                        .Q4(s_logisimBus40[20]),
                        .Q5(s_logisimBus40[19]),
                        .Q6(s_logisimBus40[18]),
                        .Q7(s_logisimBus40[17]),
                        .Q8(s_logisimBus40[16]));

   TTL_74374   CHIP_4B (.CK(s_logisimNet9),
                        .D1(s_logisimBus42[5]),
                        .D2(s_logisimBus42[4]),
                        .D3(s_logisimBus42[3]),
                        .D4(s_logisimBus42[2]),
                        .D5(s_logisimBus42[1]),
                        .D6(s_logisimBus42[0]),
                        .D7(s_logisimBus17[9]),
                        .D8(s_logisimBus17[8]),
                        .OE_n(s_logisimNet2),
                        .Q1(s_logisimBus40[15]),
                        .Q2(s_logisimBus40[14]),
                        .Q3(s_logisimBus40[13]),
                        .Q4(s_logisimBus40[12]),
                        .Q5(s_logisimBus40[11]),
                        .Q6(s_logisimBus40[10]),
                        .Q7(s_logisimBus40[9]),
                        .Q8(s_logisimBus40[8]));

   TTL_74374   CHIP_6C (.CK(s_logisimNet9),
                        .D1(s_logisimBus17[7]),
                        .D2(s_logisimBus17[6]),
                        .D3(s_logisimBus17[5]),
                        .D4(s_logisimBus17[4]),
                        .D5(s_logisimBus17[3]),
                        .D6(s_logisimBus17[2]),
                        .D7(s_logisimBus17[1]),
                        .D8(s_logisimBus17[0]),
                        .OE_n(s_logisimNet2),
                        .Q1(s_logisimBus40[7]),
                        .Q2(s_logisimBus40[6]),
                        .Q3(s_logisimBus40[5]),
                        .Q4(s_logisimBus40[4]),
                        .Q5(s_logisimBus40[3]),
                        .Q6(s_logisimBus40[2]),
                        .Q7(s_logisimBus40[1]),
                        .Q8(s_logisimBus40[0]));

endmodule

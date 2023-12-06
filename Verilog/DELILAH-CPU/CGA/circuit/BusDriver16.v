/******************************************************************************
 ** Logisim-evolution goes FPGA automatic generated Verilog code             **
 ** https://github.com/logisim-evolution/                                    **
 **                                                                          **
 ** Component : BusDriver16                                                  **
 **                                                                          **
 *****************************************************************************/

module BusDriver16( A_15_0,
                    EN,
                    IN_15_0,
                    OUT_15_0,
                    TN,
                    ZI_15_0 );

   /*******************************************************************************
   ** The inputs are defined here                                                **
   *******************************************************************************/
   input [15:0] A_15_0;
   input        EN;
   input [15:0] IN_15_0;
   input        TN;

   /*******************************************************************************
   ** The outputs are defined here                                               **
   *******************************************************************************/
   output [15:0] OUT_15_0;
   output [15:0] ZI_15_0;

   /*******************************************************************************
   ** The wires are defined here                                                 **
   *******************************************************************************/
   wire [15:0] s_logisimBus17;
   wire [15:0] s_logisimBus28;
   wire [15:0] s_logisimBus3;
   wire [15:0] s_logisimBus61;
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
   wire        s_logisimNet62;
   wire        s_logisimNet63;
   wire        s_logisimNet64;
   wire        s_logisimNet65;
   wire        s_logisimNet66;
   wire        s_logisimNet67;
   wire        s_logisimNet68;
   wire        s_logisimNet69;
   wire        s_logisimNet7;
   wire        s_logisimNet8;
   wire        s_logisimNet9;

   /*******************************************************************************
   ** The module functionality is described here                                 **
   *******************************************************************************/

   /*******************************************************************************
   ** Here all input connections are defined                                     **
   *******************************************************************************/
   assign s_logisimBus17[15:0] = IN_15_0;
   assign s_logisimBus61[15:0] = A_15_0;
   assign s_logisimNet1        = TN;
   assign s_logisimNet45       = EN;

   /*******************************************************************************
   ** Here all output connections are defined                                    **
   *******************************************************************************/
   assign OUT_15_0 = s_logisimBus28[15:0];
   assign ZI_15_0  = s_logisimBus3[15:0];

   /*******************************************************************************
   ** Here all sub-circuits are defined                                          **
   *******************************************************************************/

   BD4TU   BD4 (.A(s_logisimBus61[4]),
                .BUF_IN(s_logisimBus17[4]),
                .BUF_OUT(s_logisimBus28[4]),
                .EN(s_logisimNet45),
                .TN(s_logisimNet1),
                .ZI(s_logisimBus3[4]));

   BD4TU   BD5 (.A(s_logisimBus61[5]),
                .BUF_IN(s_logisimBus17[5]),
                .BUF_OUT(s_logisimBus28[5]),
                .EN(s_logisimNet45),
                .TN(s_logisimNet1),
                .ZI(s_logisimBus3[5]));

   BD4TU   BD6 (.A(s_logisimBus61[6]),
                .BUF_IN(s_logisimBus17[6]),
                .BUF_OUT(s_logisimBus28[6]),
                .EN(s_logisimNet45),
                .TN(s_logisimNet1),
                .ZI(s_logisimBus3[6]));

   BD4TU   BD7 (.A(s_logisimBus61[7]),
                .BUF_IN(s_logisimBus17[7]),
                .BUF_OUT(s_logisimBus28[7]),
                .EN(s_logisimNet45),
                .TN(s_logisimNet1),
                .ZI(s_logisimBus3[7]));

   BD4TU   BD8 (.A(s_logisimBus61[8]),
                .BUF_IN(s_logisimBus17[8]),
                .BUF_OUT(s_logisimBus28[8]),
                .EN(s_logisimNet45),
                .TN(s_logisimNet1),
                .ZI(s_logisimBus3[8]));

   BD4TU   BD9 (.A(s_logisimBus61[9]),
                .BUF_IN(s_logisimBus17[9]),
                .BUF_OUT(s_logisimBus28[9]),
                .EN(s_logisimNet45),
                .TN(s_logisimNet1),
                .ZI(s_logisimBus3[9]));

   BD4TU   BD10 (.A(s_logisimBus61[10]),
                 .BUF_IN(s_logisimBus17[10]),
                 .BUF_OUT(s_logisimBus28[10]),
                 .EN(s_logisimNet45),
                 .TN(s_logisimNet1),
                 .ZI(s_logisimBus3[10]));

   BD4TU   BD11 (.A(s_logisimBus61[11]),
                 .BUF_IN(s_logisimBus17[11]),
                 .BUF_OUT(s_logisimBus28[11]),
                 .EN(s_logisimNet45),
                 .TN(s_logisimNet1),
                 .ZI(s_logisimBus3[11]));

   BD4TU   BD12 (.A(s_logisimBus61[12]),
                 .BUF_IN(s_logisimBus17[12]),
                 .BUF_OUT(s_logisimBus28[12]),
                 .EN(s_logisimNet45),
                 .TN(s_logisimNet1),
                 .ZI(s_logisimBus3[12]));

   BD4TU   BD13 (.A(s_logisimBus61[13]),
                 .BUF_IN(s_logisimBus17[13]),
                 .BUF_OUT(s_logisimBus28[13]),
                 .EN(s_logisimNet45),
                 .TN(s_logisimNet1),
                 .ZI(s_logisimBus3[13]));

   BD4TU   BD14 (.A(s_logisimBus61[14]),
                 .BUF_IN(s_logisimBus17[14]),
                 .BUF_OUT(s_logisimBus28[14]),
                 .EN(s_logisimNet45),
                 .TN(s_logisimNet1),
                 .ZI(s_logisimBus3[14]));

   BD4TU   BD15 (.A(s_logisimBus61[15]),
                 .BUF_IN(s_logisimBus17[15]),
                 .BUF_OUT(s_logisimBus28[15]),
                 .EN(s_logisimNet45),
                 .TN(s_logisimNet1),
                 .ZI(s_logisimBus3[15]));

   BD4TU   BD0 (.A(s_logisimBus61[0]),
                .BUF_IN(s_logisimBus17[0]),
                .BUF_OUT(s_logisimBus28[0]),
                .EN(s_logisimNet45),
                .TN(s_logisimNet1),
                .ZI(s_logisimBus3[0]));

   BD4TU   BD1 (.A(s_logisimBus61[1]),
                .BUF_IN(s_logisimBus17[1]),
                .BUF_OUT(s_logisimBus28[1]),
                .EN(s_logisimNet45),
                .TN(s_logisimNet1),
                .ZI(s_logisimBus3[1]));

   BD4TU   BD2 (.A(s_logisimBus61[2]),
                .BUF_IN(s_logisimBus17[2]),
                .BUF_OUT(s_logisimBus28[2]),
                .EN(s_logisimNet45),
                .TN(s_logisimNet1),
                .ZI(s_logisimBus3[2]));

   BD4TU   BD3 (.A(s_logisimBus61[3]),
                .BUF_IN(s_logisimBus17[3]),
                .BUF_OUT(s_logisimBus28[3]),
                .EN(s_logisimNet45),
                .TN(s_logisimNet1),
                .ZI(s_logisimBus3[3]));

endmodule

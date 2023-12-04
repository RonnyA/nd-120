/******************************************************************************
 ** Logisim-evolution goes FPGA automatic generated Verilog code             **
 ** https://github.com/logisim-evolution/                                    **
 **                                                                          **
 ** Component : CGA_ALU_RALU_MUX216L                                         **
 **                                                                          **
 *****************************************************************************/

module CGA_ALU_RALU_MUX216L( F_15_0,
                             O_15_0,
                             S,
                             T_15_0 );

   /*******************************************************************************
   ** The inputs are defined here                                                **
   *******************************************************************************/
   input [15:0] F_15_0;
   input        S;
   input [15:0] T_15_0;

   /*******************************************************************************
   ** The outputs are defined here                                               **
   *******************************************************************************/
   output [15:0] O_15_0;

   /*******************************************************************************
   ** The wires are defined here                                                 **
   *******************************************************************************/
   wire [15:0] s_logisimBus23;
   wire [15:0] s_logisimBus40;
   wire [15:0] s_logisimBus50;
   wire        s_logisimNet0;
   wire        s_logisimNet1;
   wire        s_logisimNet10;
   wire        s_logisimNet11;
   wire        s_logisimNet12;
   wire        s_logisimNet13;
   wire        s_logisimNet14;
   wire        s_logisimNet15;
   wire        s_logisimNet16;
   wire        s_logisimNet17;
   wire        s_logisimNet18;
   wire        s_logisimNet19;
   wire        s_logisimNet2;
   wire        s_logisimNet20;
   wire        s_logisimNet21;
   wire        s_logisimNet22;
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
   wire        s_logisimNet37;
   wire        s_logisimNet38;
   wire        s_logisimNet39;
   wire        s_logisimNet4;
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
   wire        s_logisimNet51;
   wire        s_logisimNet6;
   wire        s_logisimNet7;
   wire        s_logisimNet8;
   wire        s_logisimNet9;

   /*******************************************************************************
   ** The module functionality is described here                                 **
   *******************************************************************************/

   /*******************************************************************************
   ** Here all input connections are defined                                     **
   *******************************************************************************/
   assign s_logisimBus40[15:0] = T_15_0;
   assign s_logisimBus50[15:0] = F_15_0;
   assign s_logisimNet24       = S;

   /*******************************************************************************
   ** Here all output connections are defined                                    **
   *******************************************************************************/
   assign O_15_0 = s_logisimBus23[15:0];

   /*******************************************************************************
   ** Here all sub-circuits are defined                                          **
   *******************************************************************************/

   MUX21LP   MUXQ10 (.A(s_logisimBus50[10]),
                     .B(s_logisimBus40[10]),
                     .S(s_logisimNet24),
                     .ZN(s_logisimBus23[10]));

   MUX21LP   MUXQ9 (.A(s_logisimBus50[9]),
                    .B(s_logisimBus40[9]),
                    .S(s_logisimNet24),
                    .ZN(s_logisimBus23[9]));

   MUX21LP   MUXQ8 (.A(s_logisimBus50[8]),
                    .B(s_logisimBus40[8]),
                    .S(s_logisimNet24),
                    .ZN(s_logisimBus23[8]));

   MUX21LP   MUXQ7 (.A(s_logisimBus50[7]),
                    .B(s_logisimBus40[7]),
                    .S(s_logisimNet24),
                    .ZN(s_logisimBus23[7]));

   MUX21LP   MUXQ6 (.A(s_logisimBus50[6]),
                    .B(s_logisimBus40[6]),
                    .S(s_logisimNet24),
                    .ZN(s_logisimBus23[6]));

   MUX21LP   MUXQ5 (.A(s_logisimBus50[5]),
                    .B(s_logisimBus40[5]),
                    .S(s_logisimNet24),
                    .ZN(s_logisimBus23[5]));

   MUX21LP   MUXQ4 (.A(s_logisimBus50[4]),
                    .B(s_logisimBus40[4]),
                    .S(s_logisimNet24),
                    .ZN(s_logisimBus23[4]));

   MUX21LP   MUXQ3 (.A(s_logisimBus50[3]),
                    .B(s_logisimBus40[3]),
                    .S(s_logisimNet24),
                    .ZN(s_logisimBus23[3]));

   MUX21LP   MUXQ2 (.A(s_logisimBus50[2]),
                    .B(s_logisimBus40[2]),
                    .S(s_logisimNet24),
                    .ZN(s_logisimBus23[2]));

   MUX21LP   MUXQ1 (.A(s_logisimBus50[1]),
                    .B(s_logisimBus40[1]),
                    .S(s_logisimNet24),
                    .ZN(s_logisimBus23[1]));

   MUX21LP   MUXQ0 (.A(s_logisimBus50[0]),
                    .B(s_logisimBus40[0]),
                    .S(s_logisimNet24),
                    .ZN(s_logisimBus23[0]));

   MUX21LP   MUXQ15 (.A(s_logisimBus50[15]),
                     .B(s_logisimBus40[15]),
                     .S(s_logisimNet24),
                     .ZN(s_logisimBus23[15]));

   MUX21LP   MUXQ14 (.A(s_logisimBus50[14]),
                     .B(s_logisimBus40[14]),
                     .S(s_logisimNet24),
                     .ZN(s_logisimBus23[14]));

   MUX21LP   MUXQ13 (.A(s_logisimBus50[13]),
                     .B(s_logisimBus40[13]),
                     .S(s_logisimNet24),
                     .ZN(s_logisimBus23[13]));

   MUX21LP   MUXQ12 (.A(s_logisimBus50[12]),
                     .B(s_logisimBus40[12]),
                     .S(s_logisimNet24),
                     .ZN(s_logisimBus23[12]));

   MUX21LP   MUXQ11 (.A(s_logisimBus50[11]),
                     .B(s_logisimBus40[11]),
                     .S(s_logisimNet24),
                     .ZN(s_logisimBus23[11]));

endmodule

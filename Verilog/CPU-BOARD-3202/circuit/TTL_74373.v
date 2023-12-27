/******************************************************************************
 ** Logisim-evolution goes FPGA automatic generated Verilog code             **
 ** https://github.com/logisim-evolution/                                    **
 **                                                                          **
 ** Component : TTL_74373                                                    **
 **                                                                          **
 *****************************************************************************/

module TTL_74373( C,
                  D_7_0,
                  OE_n,
                  Q_7_0 );

   /*******************************************************************************
   ** The inputs are defined here                                                **
   *******************************************************************************/
   input       C;
   input [7:0] D_7_0;
   input       OE_n;

   /*******************************************************************************
   ** The outputs are defined here                                               **
   *******************************************************************************/
   output [7:0] Q_7_0;

   /*******************************************************************************
   ** The wires are defined here                                                 **
   *******************************************************************************/
   wire [7:0] s_logisimBus10;
   wire [7:0] s_logisimBus11;
   wire [7:0] s_logisimBus9;
   wire       s_logisimNet0;
   wire       s_logisimNet1;
   wire       s_logisimNet12;
   wire       s_logisimNet13;
   wire       s_logisimNet14;
   wire       s_logisimNet15;
   wire       s_logisimNet16;
   wire       s_logisimNet17;
   wire       s_logisimNet18;
   wire       s_logisimNet19;
   wire       s_logisimNet2;
   wire       s_logisimNet20;
   wire       s_logisimNet21;
   wire       s_logisimNet3;
   wire       s_logisimNet4;
   wire       s_logisimNet5;
   wire       s_logisimNet6;
   wire       s_logisimNet7;
   wire       s_logisimNet8;

   /*******************************************************************************
   ** The module functionality is described here                                 **
   *******************************************************************************/

   /*******************************************************************************
   ** Here all input connections are defined                                     **
   *******************************************************************************/
   assign s_logisimBus11[7:0] = D_7_0;
   assign s_logisimNet20      = OE_n;
   assign s_logisimNet21      = C;

   /*******************************************************************************
   ** Here all output connections are defined                                    **
   *******************************************************************************/
   assign Q_7_0 = s_logisimBus10[7:0];

   /*******************************************************************************
   ** Here all in-lined components are defined                                   **
   *******************************************************************************/

   // Controlled Buffer
   assign s_logisimBus10 = (s_logisimNet0) ? s_logisimBus9 : 8'bZ;

   // NOT Gate
   assign s_logisimNet0 = ~s_logisimNet20;

   /*******************************************************************************
   ** Here all sub-circuits are defined                                          **
   *******************************************************************************/

   L8   Latch (.A(s_logisimBus11[0]),
               .B(s_logisimBus11[1]),
               .C(s_logisimBus11[2]),
               .D(s_logisimBus11[3]),
               .E(s_logisimBus11[4]),
               .F(s_logisimBus11[5]),
               .G(s_logisimBus11[6]),
               .H(s_logisimBus11[7]),
               .L(s_logisimNet21),
               .QA(s_logisimBus9[0]),
               .QAN(),
               .QB(s_logisimBus9[1]),
               .QBN(),
               .QC(s_logisimBus9[2]),
               .QCN(),
               .QD(s_logisimBus9[3]),
               .QDN(),
               .QE(s_logisimBus9[4]),
               .QEN(),
               .QF(s_logisimBus9[5]),
               .QFN(),
               .QG(s_logisimBus9[6]),
               .QGN(),
               .QH(s_logisimBus9[7]),
               .QHN());

endmodule

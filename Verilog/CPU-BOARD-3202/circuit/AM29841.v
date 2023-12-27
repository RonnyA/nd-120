/******************************************************************************
 ** Logisim-evolution goes FPGA automatic generated Verilog code             **
 ** https://github.com/logisim-evolution/                                    **
 **                                                                          **
 ** Component : AM29841                                                      **
 **                                                                          **
 *****************************************************************************/

module AM29841( D0,
                D1,
                D2,
                D3,
                D4,
                D5,
                D6,
                D7,
                D8,
                D9,
                LE,
                OE_n,
                Y0,
                Y1,
                Y2,
                Y3,
                Y4,
                Y5,
                Y6,
                Y7,
                Y8,
                Y9 );

   /*******************************************************************************
   ** The inputs are defined here                                                **
   *******************************************************************************/
   input D0;
   input D1;
   input D2;
   input D3;
   input D4;
   input D5;
   input D6;
   input D7;
   input D8;
   input D9;
   input LE;
   input OE_n;

   /*******************************************************************************
   ** The outputs are defined here                                               **
   *******************************************************************************/
   output Y0;
   output Y1;
   output Y2;
   output Y3;
   output Y4;
   output Y5;
   output Y6;
   output Y7;
   output Y8;
   output Y9;

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
   assign s_logisimNet12 = OE_n;
   assign s_logisimNet13 = D5;
   assign s_logisimNet14 = D3;
   assign s_logisimNet15 = D9;
   assign s_logisimNet16 = D8;
   assign s_logisimNet17 = D0;
   assign s_logisimNet18 = D1;
   assign s_logisimNet19 = D2;
   assign s_logisimNet20 = D4;
   assign s_logisimNet21 = D6;
   assign s_logisimNet22 = D7;
   assign s_logisimNet3  = LE;

   /*******************************************************************************
   ** Here all output connections are defined                                    **
   *******************************************************************************/
   assign Y0 = s_logisimNet23;
   assign Y1 = s_logisimNet24;
   assign Y2 = s_logisimNet25;
   assign Y3 = s_logisimNet27;
   assign Y4 = s_logisimNet28;
   assign Y5 = s_logisimNet29;
   assign Y6 = s_logisimNet30;
   assign Y7 = s_logisimNet31;
   assign Y8 = s_logisimNet32;
   assign Y9 = s_logisimNet26;

   /*******************************************************************************
   ** Here all in-lined components are defined                                   **
   *******************************************************************************/

   // NOT Gate
   assign s_logisimNet0 = ~s_logisimNet12;

   // Controlled Buffer
   assign s_logisimNet26 = (s_logisimNet0) ? s_logisimNet4 : 1'bZ;

   // Controlled Buffer
   assign s_logisimNet23 = (s_logisimNet0) ? s_logisimNet9 : 1'bZ;

   // Controlled Buffer
   assign s_logisimNet24 = (s_logisimNet0) ? s_logisimNet10 : 1'bZ;

   // Controlled Buffer
   assign s_logisimNet25 = (s_logisimNet0) ? s_logisimNet2 : 1'bZ;

   // Controlled Buffer
   assign s_logisimNet27 = (s_logisimNet0) ? s_logisimNet11 : 1'bZ;

   // Controlled Buffer
   assign s_logisimNet28 = (s_logisimNet0) ? s_logisimNet1 : 1'bZ;

   // Controlled Buffer
   assign s_logisimNet29 = (s_logisimNet0) ? s_logisimNet6 : 1'bZ;

   // Controlled Buffer
   assign s_logisimNet30 = (s_logisimNet0) ? s_logisimNet7 : 1'bZ;

   // Controlled Buffer
   assign s_logisimNet31 = (s_logisimNet0) ? s_logisimNet5 : 1'bZ;

   // Controlled Buffer
   assign s_logisimNet32 = (s_logisimNet0) ? s_logisimNet8 : 1'bZ;

   /*******************************************************************************
   ** Here all sub-circuits are defined                                          **
   *******************************************************************************/

   LATCH   LATCH_10 (.D(s_logisimNet15),
                     .ENABLE(s_logisimNet3),
                     .Q(s_logisimNet4),
                     .QN());

   LATCH   LATCH_1 (.D(s_logisimNet17),
                    .ENABLE(s_logisimNet3),
                    .Q(s_logisimNet9),
                    .QN());

   LATCH   LATCH_2 (.D(s_logisimNet18),
                    .ENABLE(s_logisimNet3),
                    .Q(s_logisimNet10),
                    .QN());

   LATCH   LATCH_3 (.D(s_logisimNet19),
                    .ENABLE(s_logisimNet3),
                    .Q(s_logisimNet2),
                    .QN());

   LATCH   LATCH_4 (.D(s_logisimNet14),
                    .ENABLE(s_logisimNet3),
                    .Q(s_logisimNet11),
                    .QN());

   LATCH   LATCH_5 (.D(s_logisimNet20),
                    .ENABLE(s_logisimNet3),
                    .Q(s_logisimNet1),
                    .QN());

   LATCH   LATCH_6 (.D(s_logisimNet13),
                    .ENABLE(s_logisimNet3),
                    .Q(s_logisimNet6),
                    .QN());

   LATCH   LATCH_7 (.D(s_logisimNet21),
                    .ENABLE(s_logisimNet3),
                    .Q(s_logisimNet7),
                    .QN());

   LATCH   LATCH_8 (.D(s_logisimNet22),
                    .ENABLE(s_logisimNet3),
                    .Q(s_logisimNet5),
                    .QN());

   LATCH   LATCH_9 (.D(s_logisimNet16),
                    .ENABLE(s_logisimNet3),
                    .Q(s_logisimNet8),
                    .QN());

endmodule

/******************************************************************************
 ** Logisim-evolution goes FPGA automatic generated Verilog code             **
 ** https://github.com/logisim-evolution/                                    **
 **                                                                          **
 ** Component : TTL_74245                                                    **
 **                                                                          **
 *****************************************************************************/

module TTL_74245( A1,
                  A2,
                  A3,
                  A4,
                  A5,
                  A6,
                  A7,
                  A8,
                  B1,
                  B2,
                  B3,
                  B4,
                  B5,
                  B6,
                  B7,
                  B8,
                  DIR,
                  G_n );

   /*******************************************************************************
   ** The inputs are defined here                                                **
   *******************************************************************************/
   input A1;
   input A2;
   input A3;
   input A4;
   input A5;
   input A6;
   input A7;
   input A8;
   input DIR;
   input G_n;

   /*******************************************************************************
   ** The outputs are defined here                                               **
   *******************************************************************************/
   output B1;
   output B2;
   output B3;
   output B4;
   output B5;
   output B6;
   output B7;
   output B8;

   /*******************************************************************************
   ** The wires are defined here                                                 **
   *******************************************************************************/
   wire [7:0] s_logisimBus0;
   wire [7:0] s_logisimBus13;
   wire [7:0] s_logisimBus2;
   wire [7:0] s_logisimBus23;
   wire       s_logisimNet1;
   wire       s_logisimNet10;
   wire       s_logisimNet11;
   wire       s_logisimNet12;
   wire       s_logisimNet14;
   wire       s_logisimNet15;
   wire       s_logisimNet16;
   wire       s_logisimNet17;
   wire       s_logisimNet18;
   wire       s_logisimNet19;
   wire       s_logisimNet20;
   wire       s_logisimNet21;
   wire       s_logisimNet22;
   wire       s_logisimNet3;
   wire       s_logisimNet4;
   wire       s_logisimNet5;
   wire       s_logisimNet6;
   wire       s_logisimNet7;
   wire       s_logisimNet8;
   wire       s_logisimNet9;

   /*******************************************************************************
   ** The module functionality is described here                                 **
   *******************************************************************************/

   /*******************************************************************************
   ** Here all input connections are defined                                     **
   *******************************************************************************/
   assign s_logisimBus2[0] = A1;
   assign s_logisimBus2[1] = A2;
   assign s_logisimBus2[2] = A3;
   assign s_logisimBus2[3] = A4;
   assign s_logisimBus2[4] = A5;
   assign s_logisimBus2[5] = A6;
   assign s_logisimBus2[6] = A7;
   assign s_logisimBus2[7] = A8;
   assign s_logisimNet22   = G_n;
   assign s_logisimNet3    = DIR;

   /*******************************************************************************
   ** Here all output connections are defined                                    **
   *******************************************************************************/
   assign B1 = s_logisimBus23[0];
   assign B2 = s_logisimBus23[1];
   assign B3 = s_logisimBus23[2];
   assign B4 = s_logisimBus23[3];
   assign B5 = s_logisimBus23[4];
   assign B6 = s_logisimBus23[5];
   assign B7 = s_logisimBus23[6];
   assign B8 = s_logisimBus23[7];

   /*******************************************************************************
   ** Here all in-lined components are defined                                   **
   *******************************************************************************/

   // Controlled Buffer
   assign s_logisimBus0 = (s_logisimNet1) ? s_logisimBus13 : 8'bZ;

   // Controlled Buffer
   assign s_logisimBus23 = (s_logisimNet4) ? s_logisimBus13 : 8'bZ;

   // NOT Gate
   assign s_logisimNet4 = ~s_logisimNet22;

   // Controlled Buffer

   // Controlled Buffer
   assign s_logisimBus13 = (s_logisimNet3) ? s_logisimBus2 : 8'bZ;

   // NOT Gate
   assign s_logisimNet1 = ~s_logisimNet3;

endmodule

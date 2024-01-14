/******************************************************************************
 ** Logisim-evolution goes FPGA automatic generated Verilog code             **
 ** https://github.com/logisim-evolution/                                    **
 **                                                                          **
 ** Component : BD4TU                                                        **
 **                                                                          **
 *****************************************************************************/

module BD4TU( A,
              BUF_IN,
              BUF_OUT,
              EN,
              TN,
              ZI );

   /*******************************************************************************
   ** The inputs are defined here                                                **
   *******************************************************************************/
   input A;
   input BUF_IN;
   input EN;
   input TN;

   /*******************************************************************************
   ** The outputs are defined here                                               **
   *******************************************************************************/
   output BUF_OUT;
   output ZI;

   /*******************************************************************************
   ** The wires are defined here                                                 **
   *******************************************************************************/
   wire s_logisimNet0;
   wire s_logisimNet1;
   wire s_logisimNet2;
   wire s_logisimNet3;
   wire s_logisimNet4;
   wire s_logisimNet5;
   wire s_logisimNet6;

   /*******************************************************************************
   ** The module functionality is described here                                 **
   *******************************************************************************/

   /*******************************************************************************
   ** Here all input connections are defined                                     **
   *******************************************************************************/
   assign s_logisimNet1 = EN;
   assign s_logisimNet2 = A;
   assign s_logisimNet6 = BUF_IN;

   /*******************************************************************************
   ** Here all output connections are defined                                    **
   *******************************************************************************/
   assign BUF_OUT = s_logisimNet5;
   assign ZI      = s_logisimNet4;

   /*******************************************************************************
   ** Here all in-lined components are defined                                   **
   *******************************************************************************/

   // NOT Gate
   assign s_logisimNet3 = ~s_logisimNet1;

   // Controlled Buffer
   assign s_logisimNet0 = (s_logisimNet3) ? s_logisimNet2 : 1'bZ;

   // Controlled Buffer
   assign s_logisimNet5 = (s_logisimNet3) ? s_logisimNet0 : 1'bZ;

   // Controlled Buffer
   assign s_logisimNet4 = (s_logisimNet1) ? s_logisimNet6 : 1'bZ;

endmodule

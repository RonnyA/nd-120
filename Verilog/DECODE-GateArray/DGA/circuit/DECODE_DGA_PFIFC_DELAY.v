/******************************************************************************
 ** Logisim-evolution goes FPGA automatic generated Verilog code             **
 ** https://github.com/logisim-evolution/                                    **
 **                                                                          **
 ** Component : DECODE_DGA_PFIFC_DELAY                                       **
 **                                                                          **
 *****************************************************************************/

module DECODE_DGA_PFIFC_DELAY( PIN_IN,
                               PIN_OUT );

   /*******************************************************************************
   ** The inputs are defined here                                                **
   *******************************************************************************/
   input PIN_IN;

   /*******************************************************************************
   ** The outputs are defined here                                               **
   *******************************************************************************/
   output PIN_OUT;

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
   wire s_logisimNet7;

   /*******************************************************************************
   ** The module functionality is described here                                 **
   *******************************************************************************/

   /*******************************************************************************
   ** Here all input connections are defined                                     **
   *******************************************************************************/
   assign s_logisimNet6 = PIN_IN;

   /*******************************************************************************
   ** Here all output connections are defined                                    **
   *******************************************************************************/
   assign PIN_OUT = s_logisimNet1;

   /*******************************************************************************
   ** Here all in-lined components are defined                                   **
   *******************************************************************************/

   // Buffer
   assign s_logisimNet7 = s_logisimNet6;

   // Buffer
   assign s_logisimNet4 = s_logisimNet7;

   // Buffer
   assign s_logisimNet5 = s_logisimNet4;

   // Buffer
   assign s_logisimNet2 = s_logisimNet5;

   // Buffer
   assign s_logisimNet3 = s_logisimNet2;

   // Buffer
   assign s_logisimNet0 = s_logisimNet3;

   // Buffer
   assign s_logisimNet1 = s_logisimNet0;

endmodule

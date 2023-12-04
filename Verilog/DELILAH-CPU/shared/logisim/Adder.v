/******************************************************************************
 ** Logisim-evolution goes FPGA automatic generated Verilog code             **
 ** https://github.com/logisim-evolution/                                    **
 **                                                                          **
 ** Component : Adder                                                        **
 **                                                                          **
 *****************************************************************************/

module Adder( carryIn,
              carryOut,
              dataA,
              dataB,
              result );

   /*******************************************************************************
   ** Here all module parameters are defined with a dummy value                  **
   *******************************************************************************/
   parameter extendedBits = 1;
   parameter nrOfBits = 1;

   /*******************************************************************************
   ** The inputs are defined here                                                **
   *******************************************************************************/
   input                carryIn;
   input [nrOfBits-1:0] dataA;
   input [nrOfBits-1:0] dataB;

   /*******************************************************************************
   ** The outputs are defined here                                               **
   *******************************************************************************/
   output                carryOut;
   output [nrOfBits-1:0] result;

   /*******************************************************************************
   ** The wires are defined here                                                 **
   *******************************************************************************/
   wire [extendedBits-1:0] s_extendedDataA;
   wire [extendedBits-1:0] s_extendedDataB;
   wire [extendedBits-1:0] s_sumResult;

   /*******************************************************************************
   ** The module functionality is described here                                 **
   *******************************************************************************/
   assign   {carryOut, result} = dataA + dataB + carryIn;

endmodule

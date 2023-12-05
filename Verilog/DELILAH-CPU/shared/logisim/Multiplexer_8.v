/******************************************************************************
 ** Logisim-evolution goes FPGA automatic generated Verilog code             **
 ** https://github.com/logisim-evolution/                                    **
 **                                                                          **
 ** Component : Multiplexer_8                                                **
 **                                                                          **
 *****************************************************************************/

module Multiplexer_8( 
                      muxIn_0,
                      muxIn_1,
                      muxIn_2,
                      muxIn_3,
                      muxIn_4,
                      muxIn_5,
                      muxIn_6,
                      muxIn_7,
                      muxOut,
                      sel );

   /*******************************************************************************
   ** The inputs are defined here                                                **
   *******************************************************************************/
   input       muxIn_0;
   input       muxIn_1;
   input       muxIn_2;
   input       muxIn_3;
   input       muxIn_4;
   input       muxIn_5;
   input       muxIn_6;
   input       muxIn_7;
   input [2:0] sel;

   /*******************************************************************************
   ** The outputs are defined here                                               **
   *******************************************************************************/
   output reg muxOut;

   /*******************************************************************************
   ** The module functionality is described here                                 **
   *******************************************************************************/

     // Logic for the 8 to-1 multiplexer

   always @(*) begin
      case (sel)
         3'b000: muxOut = muxIn_0;
         3'b001: muxOut = muxIn_1;
         3'b010: muxOut = muxIn_2;
         3'b011: muxOut = muxIn_3;
         3'b100: muxOut = muxIn_4;
         3'b101: muxOut = muxIn_5;
         3'b110: muxOut = muxIn_6;
         default: muxOut = muxIn_7;
      endcase
   end

endmodule

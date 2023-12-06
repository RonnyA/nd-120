/******************************************************************************
 ** Logisim-evolution goes FPGA automatic generated Verilog code             **
 ** https://github.com/logisim-evolution/                                    **
 **                                                                          **
 ** Component : Multiplexer_bus_2                                            **
 **                                                                          **
 *****************************************************************************/

module Multiplexer_bus_2( 
                          muxIn_0,
                          muxIn_1,
                          muxOut,
                          sel );

   /*******************************************************************************
   ** Here all module parameters are defined with a dummy value                  **
   *******************************************************************************/
   parameter nrOfBits = 1;

   /*******************************************************************************
   ** The inputs are defined here                                                **
   *******************************************************************************/
      input [nrOfBits-1:0] muxIn_0;
   input [nrOfBits-1:0] muxIn_1;
   input                sel;

   /*******************************************************************************
   ** The outputs are defined here                                               **
   *******************************************************************************/
   output [nrOfBits-1:0] muxOut;

   /*******************************************************************************
   ** The module functionality is described here                                 **
   *******************************************************************************/
   reg [nrOfBits:0] s_selected_vector;
   assign muxOut = s_selected_vector;

   always @(*)
   begin      
      case (sel)
         1'b0:
            s_selected_vector = muxIn_0;
        default:
           s_selected_vector = muxIn_1;
      endcase
   end

endmodule

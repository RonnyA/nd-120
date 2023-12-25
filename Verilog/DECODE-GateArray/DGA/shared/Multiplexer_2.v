/******************************************************************************
 **                                                                          **
 ** Component : Multiplexer_2                                                **
 **                                                                          **
 ** Refactored 03.12.2023 Ronny Hansen                                       **
 *****************************************************************************/
/* */

module Multiplexer_2( input wire enable,
                      input wire muxIn_0,
                      input wire muxIn_1,                      
                      input wire sel,
                      output wire muxOut
                      );   
      assign muxOut = (enable == 1'b0) ? 1'b0 : (sel ? muxIn_1 : muxIn_0);
endmodule

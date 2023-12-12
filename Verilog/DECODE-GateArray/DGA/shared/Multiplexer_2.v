/******************************************************************************
 **                                                                          **
 ** Component : Multiplexer_2                                                **
 **                                                                          **
 ** Refactored 03.12.2023 Ronny Hansen                                       **
 *****************************************************************************/
/* */

module Multiplexer_2( input muxIn_0,
                      input muxIn_1,                      
                      input sel,
                      output reg muxOut,
                      input enable
                      );
   
   /*******************************************************************************
   ** The module functionality is described here                                 **
   *******************************************************************************/
    
     // Logic for the 4-to-1 multiplexer
    assign muxOut = (sel == 2'b00) ? muxIn_0 :
                     muxIn_1 ; // Default case for select == 1'b1


endmodule

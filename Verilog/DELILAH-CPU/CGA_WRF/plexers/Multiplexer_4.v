
/******************************************************************************
 **                                                                          **
 ** Component : Multiplexer_4                                                **
 **                                                                          **
 ** Refactored 03.12.2023 Ronny Hansen                                       **
 *****************************************************************************/
/* Refactored 03.12.2023 Ronny Hansen */

module Multiplexer_4(
    input wire muxIn_0,
    input wire muxIn_1,
    input wire muxIn_2,
    input wire muxIn_3,
    input wire [1:0] sel,
    output reg muxOut
);

     // Logic for the 4-to-1 multiplexer
    assign muxOut = (sel == 2'b00) ? muxIn_0 :
                            (sel == 2'b01) ? muxIn_1 :
                            (sel == 2'b10) ? muxIn_2  :
                            muxIn_3 ; // Default case for select == 2'b11


endmodule



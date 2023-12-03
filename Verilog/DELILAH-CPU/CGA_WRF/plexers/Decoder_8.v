/******************************************************************************
 **                                                                          **
 ** Component : Decoder_8                                                    **
 **                                                                          **
 *****************************************************************************/

module Decoder_8 (
    input enable,
    input [2:0] sel,
    output reg decoderOut_0,
    output reg decoderOut_1,
    output reg decoderOut_2,
    output reg decoderOut_3,
    output reg decoderOut_4,
    output reg decoderOut_5,
    output reg decoderOut_6,
    output reg decoderOut_7
);

   assign decoderOut_0  = (enable&(sel == 3'b000)) ? 1'b1 : 1'b0;
   assign decoderOut_1  = (enable&(sel == 3'b001)) ? 1'b1 : 1'b0;
   assign decoderOut_2  = (enable&(sel == 3'b010)) ? 1'b1 : 1'b0;
   assign decoderOut_3  = (enable&(sel == 3'b011)) ? 1'b1 : 1'b0;
   assign decoderOut_4  = (enable&(sel == 3'b100)) ? 1'b1 : 1'b0;
   assign decoderOut_5  = (enable&(sel == 3'b101)) ? 1'b1 : 1'b0;
   assign decoderOut_6  = (enable&(sel == 3'b110)) ? 1'b1 : 1'b0;
   assign decoderOut_7  = (enable&(sel == 3'b111)) ? 1'b1 : 1'b0;

endmodule

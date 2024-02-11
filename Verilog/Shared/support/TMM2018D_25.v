/******************************************************************************
 **  TMM2018D_25 | 16K bit Static RAM (Cache)                               **
 *****************************************************************************/

module TMM2018D_25(
   input [10:0] A0_A10,
   input        CS_n,
   input        OE_n,
   input        W_n,

   inout  [7:0] D0_D7
   );

 // Internal memory declaration
reg [7:0] memory [0:2047]; // 2^11 addresses, each 8-bit wide
reg [7:0] data_out; // Internal data register for output

// Control the direction of the data bus
assign D0_D7 = (!CS_n && !OE_n && W_n) ? data_out : 8'bz;

/* verilator lint_off LATCH */
always @(*) begin
   if (!CS_n) begin
      if (!W_n) begin // Active low write enable
         memory[A0_A10] = D0_D7;
      end else begin
         data_out = memory[A0_A10];
      end    
   end
end

endmodule

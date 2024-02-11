/******************************************************************************
 ** Component : IMS1403_25                                                   **
 ** 16K x 1 Static RAM                                                       **
 *****************************************************************************/

module IMS1403_25( 
   input [13:0] A0_A13,
   input        CE_n,
   input        D,
   input        W_n,
   output Q
);


  // Define the memory array

   /* verilator lint_off LITENDIAN */
   reg [0:16383] memory;

   /* verilator lint_on LITENDIAN */   
   /* verilator lint_off LATCH */
   always @* begin
      if (!CE_n && !W_n)  // Chip enabled and Write Enabled
         memory[A0_A13] = D;      
   end

   assign Q = CE_n ? 1'bz : W_n ? memory[A0_A13] : 1'bz; // Q is high impedance when W_n (write) is active   

endmodule

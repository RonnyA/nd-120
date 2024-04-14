/******************************************************************************
 **                                                                          **
 **  IDT6168A                                                                **
 **  16K (4Kx4) Static RAM                                                   **
 **                                                                          **
 *****************************************************************************/

module IDT6168A_20( 
   input [11:0] A_11_0,    // Address input
   input        CE_n,      // Chip enable (active low)
   input        WE_n,      // Write enable (active low)
   inout [3:0]  D_3_0      // Data input/output
);

   /*******************************************************************************
   ** The wires are defined here                                                 **
   *******************************************************************************/
   wire [11:0] s_address;
   wire [3:0]  s_databus; // 4 bit wide databus
   wire        s_ce_n;
   wire        s_we_n;

   /*******************************************************************************
   ** Here all input connections are defined                                     **
   *******************************************************************************/
   assign s_address = A_11_0;
   assign s_ce_n = CE_n;
   assign s_we_n = WE_n;

   /*******************************************************************************
   ** Memory array                                                               **
   *******************************************************************************/
   // Define a 4K x 4 bit memory array
   reg [3:0] memory_array[0:4095];

   /*******************************************************************************
   ** Reading and Writing Logic                                                  **
   *******************************************************************************/
   // Bidirectional data bus handling
   assign D_3_0 = (!s_ce_n && s_we_n) ? memory_array[s_address] : 4'bz;

   /*
    * In typical SRAM modules, write operations are enabled when the WE_n (Write Enable) signal is low (active low), 
    * and it's more appropriate to trigger the write operation with the signal's level rather than its edge. 
    * This is because SRAM is usually designed to accept data as long as WE_n is low and the chip enable (CE_n) is also low, 
    * enabling continuous write operations during the active period.
    */

   // Writing to the memory
      always_latch @* begin
      if (!s_ce_n && !s_we_n) begin
         memory_array[s_address] = D_3_0;
      end
   end

endmodule

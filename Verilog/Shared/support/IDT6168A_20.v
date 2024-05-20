/******************************************************************************
 **                                                                          **
 **  IDT6168A                                                                **
 **  16K (4Kx4) Static RAM  (using BLOCK RAM)                                **
 **                                                                          **
 *****************************************************************************/

module IDT6168A_20( 
   input wire   clk,       // Clock input (BLOCK RAM MUST HAVE CLOCK)
   input wire   reset_n,   // FPGA Reset input (active low) 

   input [11:0] A_11_0,    // Address input
   input        CE_n,      // Chip enable (active low)
   input        WE_n,      // Write enable (active low)
   input [3:0]  D_3_0_IN,  // Data input/output
   output [3:0] D_3_0_OUT  // Data input/output
);

   /*******************************************************************************
   ** The wires are defined here                                                 **
   *******************************************************************************/
   wire [11:0] s_address;   
   wire        s_ce_n;
   wire        s_we_n;

  /*******************************************************************************
   ** Signals                                                                   **
   *******************************************************************************/
   reg [3:0] data_out;     // Output data register
   wire [3:0] data_in;     // Input data from the bus

   assign s_ce_n = CE_n;
   assign s_we_n = WE_n;
   assign s_address = A_11_0;
   assign data_in = D_3_0_IN; // Connect input data

   // OUTPUT
   assign D_3_0_OUT = (!s_ce_n && s_we_n) ? data_out : 4'b0; // Tristate logic for bidirectional data bus in chip, in FPGA use 0000 for no output.

   
   /*******************************************************************************
   ** Memory array using block RAM                                               **
   *******************************************************************************/
   (* ram_style = "block" *) reg [3:0] memory_array[0:4095];



   /*
    * In typical SRAM modules, write operations are enabled when the WE_n (Write Enable) signal is low (active low), 
    * and it's more appropriate to trigger the write operation with the signal's level rather than its edge. 
    * This is because SRAM is usually designed to accept data as long as WE_n is low and the chip enable (CE_n) is also low, 
    * enabling continuous write operations during the active period.
    */

   /* verilator lint_off BLKSEQ */
   always @(posedge clk) begin
      if (reset_n == 1'b0) begin
         memory_array[s_address] <= 4'b0; // Reset memory array //TODO: Need to reset the whole array
      end else if (!s_ce_n) begin
         if (!s_we_n) begin
            memory_array[s_address] = data_in;  // Write operation
         end else begin
            data_out = memory_array[s_address]; // Read operation
         end
      end
   end


endmodule

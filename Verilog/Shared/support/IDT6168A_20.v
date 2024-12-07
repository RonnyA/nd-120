/**************************************************************************
** ND120 Shared                                                          **
**                                                                       **
**  IDT6168A                                                             **
**  16K (4Kx4) Static RAM  (using BLOCK RAM)                             **
**                                                                       **
** Last reviewed: 7-DEC-2024                                             **
** Ronny Hansen                                                          **
***************************************************************************/



module IDT6168A_20 (
    input wire clk,     // Clock input (BLOCK RAM MUST HAVE CLOCK)
    input wire reset_n, // Active-low reset

    input  wire [11:0] A_11_0,    // Address input
    input  wire        CE_n,      // Chip enable (active low)
    input  wire        WE_n,      // Write enable (active low)
    input  wire [ 3:0] D_3_0_IN,  // Data input for write
    output wire [ 3:0] D_3_0_OUT  // Data output for read
);

  // Memory array using block RAM, 4K x 4-bit
  (* ram_style = "block" *)reg [ 3:0] memory_array[0:4095];

  // Internal registers for address and data
  reg [ 3:0] data_in;
  reg [ 3:0] data_out;

     /*
    * In typical SRAM modules, write operations are enabled when the WE_n (Write Enable) signal is low (active low),
    * and it's more appropriate to trigger the write operation with the signal's level rather than its edge.
    * This is because SRAM is usually designed to accept data as long as WE_n is low and the chip enable (CE_n) is also low,
    * enabling continuous write operations during the active period.
    */
  always @(posedge clk) begin
    if (!reset_n) begin
      // Reset only data_out to prevent read conflicts during reset
      data_out <= 4'b0;
    end else if (!CE_n) begin
      data_in   <= D_3_0_IN;

      if (!WE_n) begin
        // Write operation
        memory_array[A_11_0] <= data_in;
      end else begin
        // Read operation
        data_out <= memory_array[A_11_0];
      end
    end
  end

  // Connect the output to data_out when reading
  assign D_3_0_OUT = (!CE_n && WE_n) ? data_out : 4'b0000;

endmodule

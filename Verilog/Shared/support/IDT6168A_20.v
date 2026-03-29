/**************************************************************************
** ND120 Shared                                                          **
**                                                                       **
**  IDT6168A                                                             **
**  16K (4Kx4) Static RAM  (using BLOCK RAM)                             **
**                                                                       **
** Last reviewed: 29-JAN-2025                                             **
** Ronny Hansen                                                          **
***************************************************************************/


/*

The IDT6168 is a 16,384-bit high-speed static RAM organized as 4K x 4.
It is fabricated using IDT’s high-performance, high-reliability CMOS technology.
This state-of-the-art technology, combined with innovative circuit design techniques,
provides a cost-effective approach forhigh-speed memory applications.Access times as fast 15ns are available.

The circuit also offers areduced power standby mode.
When CS goes HIGH, the circuit willautomatically go to, and remain in, a standby mode as long as CS remainsHIGH.

This capability provides significant system-level power and coolingsavings.
The low-power (LA) version also offers a battery backup dataretention  capability  where  the  circuit  typically
consumes only 1μW operating off a 2V battery. 

All inputs and outputs of the IDT6168 areTTL-compatible and operate from a single 5V supply.
The IDT6168 is packaged in either a space saving 20-pin, 300-milceramic or plastic DIP or a 20-pin LCC providing 
high board-level packing densities.

Military grade product is manufactured in compliance with the latest revision of MIL-STD-883, Class B,
making it ideally suited tomilitary temperature applications demanding the highest level of performance and reliability.


High-speed (equal access and cycle time)
  –   Military: 25/45ns (max.)
  –   Industrial: 25ns (max.)
  –   Commercial: 15/20/25ns (max.)

Documentation: https://www.alldatasheet.com/datasheet-pdf/view/65830/IDT/IDT6168.html


NOTE!! The access time is not immediate, meaning it takes 15-20 nanoseconds after the address has changed for the data to become valid on the output.

*/
module IDT6168A_20 (
    input wire clk,     // Clock input (BLOCK RAM MUST HAVE CLOCK)
    input wire reset_n, // Active-low reset

    input  wire [11:0] A_11_0,    // Address input
    input  wire        CE_n,      // Chip enable (active low)
    input  wire        WE_n,      // Write enable (active low)
    input  wire [ 3:0] D_3_0_IN,  // Data input for write
    output wire [ 3:0] D_3_0_OUT  // Data output for read
);

  // Memory array - 4K x 4-bit
  // Gowin: syn_ramstyle for block RAM inference
  // Xilinx: ram_style for block RAM inference
  (* syn_ramstyle = "block_ram", ram_style = "block" *)
  reg [3:0] idt_memory_array[0:4095];

  reg [3:0] data_out;
  reg regCE_n;

  // Simple read/write pattern for block RAM inference.
  // Block RAM cannot have reset on the memory array itself,
  // only on the output register.
  always @(negedge clk) begin
    regCE_n <= CE_n;

    if (!CE_n) begin
      if (!WE_n) begin
        // Write operation: data written directly (no pipeline register)
        idt_memory_array[A_11_0] <= D_3_0_IN;
      end

      // Read operation: always read (write-first behavior)
      data_out <= idt_memory_array[A_11_0];
    end
  end

  // Output gated by registered chip enable and write enable
  assign D_3_0_OUT = (!regCE_n && WE_n) ? data_out : 4'b0000;

endmodule

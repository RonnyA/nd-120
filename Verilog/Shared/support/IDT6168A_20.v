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

  // Memory array using block RAM, 4K x 4-bit
  (* ram_style = "block" *)reg [ 3:0] idt_memory_array[0:4095];

  // Internal registers for address and data
  reg [ 3:0] data_in;
  reg [ 3:0] data_out;
  reg regCE_n;
  wire s_CE_n;
  assign s_CE_n = regCE_n;

     /*
    * In typical SRAM modules, write operations are enabled when the WE_n (Write Enable) signal is low (active low),
    * and it's more appropriate to trigger the write operation with the signal's level rather than its edge.
    * This is because SRAM is usually designed to accept data as long as WE_n is low and the chip enable (CE_n) is also low,
    * enabling continuous write operations during the active period.

    * NOTE 1: Not using WE_n as a latching signal, but rely on clk signal
    *
    * NOTE 2: SRAM shouldupdate output ASAP when address changes and not wait for clock edge. But that doesnt work in the Verilator testbench, I assume race conditions..
    */
    always @(negedge clk)
    //always @(posedge clk)
    begin
      regCE_n <= CE_n;

      if (!reset_n)
      begin
        // Reset only data_out to prevent read conflicts during reset
        data_out <= 4'b0;
      end else if (!CE_n) begin
        data_in   <= D_3_0_IN;

        if (!WE_n) begin
          // Write operation
          idt_memory_array[A_11_0] <= data_in;
        end else begin
          // Read operation
          data_out <= idt_memory_array[A_11_0];
        end
      end
  end

  // Connect the output to data_out when reading
  //assign D_3_0_OUT = (!s_CE_n && WE_n) ? idt_memory_array[A_11_0] : 4'b0000;
  assign D_3_0_OUT = (!s_CE_n && WE_n) ? data_out : 4'b0000;

endmodule

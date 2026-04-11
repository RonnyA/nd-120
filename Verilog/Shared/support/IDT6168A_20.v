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

  // Memory array - 4K x 4-bit. Marked for block RAM inference on FPGA targets.
  // Both Vivado/Xilinx (ram_style) and Gowin (syn_ramstyle) recognise this.
  (* syn_ramstyle = "block_ram", ram_style = "block" *)
  reg [3:0] idt_memory_array[0:4095];

  // -----------------------------------------------------------------------
  // Unified sim/FPGA model: posedge-clk write-first synchronous RAM.
  //
  // Both branches now use the SAME timing semantics — no `ifdef VERILATOR_SIM`
  // divergence. Read latency is 1 sysclk: address change at posedge clk N
  // produces the corresponding data at posedge clk N+1.
  //
  // Why 1 sysclk and not zero/combinational:
  //
  //   With zero-delay reads, the WCS feedback loop (WCS→CSBITS→SC5/SC6→
  //   regREP→regW→CSA→LUA→WCS) collapses entirely within one MCLK=0 idle
  //   period. The TVEC dispatch chain (o000017→o000016→o002001) resolves
  //   in delta time without intermediate MCLK pulses, and o000016 LDLC is
  //   skipped (R81 in CGA_DCD captures the wrong CSCOMM).
  //
  //   The 1-sysclk read delay forces each TVEC chain step to take its own
  //   MCLK cycle, matching how the original ASIC's WCS RAM access time
  //   (15-20ns) was a significant fraction of the original cycle period.
  //
  // Why posedge-only (not negedge writes / negedge reads):
  //
  //   The previous model had VERILATOR_SIM doing reads on posedge but
  //   writes on negedge, while the FPGA branch did BOTH on negedge — the
  //   half-sysclk shift created a sim/FPGA divergence. Unifying both to
  //   posedge eliminates the divergence and gives the same timing model
  //   in iverilog, Verilator, and the FPGA block RAM.
  //
  // Block RAM inference: Vivado and Gowin both recognise the
  // "always @(posedge clk) begin if (we) mem[a] <= d; out <= mem[a]; end"
  // pattern as a write-first BRAM template.
  // -----------------------------------------------------------------------
  reg [3:0] data_out  = 4'h0;
  reg       regCE_n   = 1'b1;
  reg       regWE_n   = 1'b1;

  always @(posedge clk) begin
    regCE_n <= CE_n;
    regWE_n <= WE_n;
    if (!CE_n) begin
      if (!WE_n) begin
        // Write happens at posedge clk N. Read of the SAME address at the
        // same edge returns the just-written value (write-first behavior).
        idt_memory_array[A_11_0] <= D_3_0_IN;
        data_out                 <= D_3_0_IN;
      end else begin
        // Pure read: capture memory[A] into data_out for the next cycle.
        data_out                 <= idt_memory_array[A_11_0];
      end
    end
  end

  // Output: tri-state-equivalent. Drives data_out only when the registered
  // CE_n is asserted AND the registered WE_n is high (read mode).
  assign D_3_0_OUT = (!regCE_n && regWE_n) ? data_out : 4'b0000;


endmodule

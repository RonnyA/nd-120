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
  reg [3:0] idt_memory_array[0:4095];

`ifdef VERILATOR_SIM
  // Simulation mode: 1-cycle registered read to model IDT6168A's 15-20 ns access time.
  //
  // WHY NOT COMBINATORIAL:
  // With zero-delay reads the MASEL feedback loop (WCS→CSBITS→SC5/SC6→regREP→
  // regW→CSA→LUA→WCS) collapses entirely within one MCLK=0 idle period.
  // The TVEC dispatch chain (o000017→o000016→o002001) resolves in delta time
  // without any intermediate MCLK pulses. At the single MCLK posedge for o002001
  // R81 (COMM_MIS_REG in CGA_DCD) captures o002001's CSCOMM=o07 instead of
  // o000016's CSCOMM=o17, so LDLCN never fires and LC never loads from panel IDB.
  //
  // WHY 1-CYCLE DELAY FIXES IT:
  // The 1-cycle break in the feedback loop forces each TVEC chain step to take one
  // sysclk. Steps o000017, o000016, and o002001 each get their own MCLK pulse,
  // exactly as in real hardware. At posedge MCLK for o000016, R81 captures
  // CSCOMM=o17. At posedge MCLK for o002001, M169C sees LDLCN=0 and loads LC
  // from the panel IDB bus.  Sequential execution is unaffected: LUA has been
  // stable for multiple cycles before MCLK fires, so D_reg is always valid.

  // Writes: synchronous on negedge (matches LCS load timing)
  always @(negedge clk) begin
    if (!CE_n && !WE_n) begin
      idt_memory_array[A_11_0] <= D_3_0_IN;
    end
  end

  // Reads: 1-cycle registered — data appears one posedge after address + CE_n settle
  reg [3:0] D_reg;
  always @(posedge clk) begin
    D_reg <= (!CE_n && WE_n) ? idt_memory_array[A_11_0] : 4'b0000;
  end
  assign D_3_0_OUT = D_reg;

`else
  // FPGA mode: synchronous block RAM (Xilinx/Gowin block RAM inference).
  // Gowin: syn_ramstyle for block RAM inference
  // Xilinx: ram_style for block RAM inference
  (* syn_ramstyle = "block_ram", ram_style = "block" *)

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

`endif

endmodule

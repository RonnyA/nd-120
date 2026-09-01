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
module IDT6168A_20 #(
    // Optional preload image (one 4-bit hex nibble per line, 4096 lines).
    // Empty string = no preload (default). Used to pre-fill the WCS so the
    // runtime microcode load can be skipped - see docs/skip-wcs-load.md.
    parameter INIT_FILE = ""
) (
    input wire clk,     // Clock input (BLOCK RAM MUST HAVE CLOCK)
    input wire reset_n, // Active-low reset

    input  wire [11:0] A_11_0,    // Address input
    input  wire        CE_n,      // Chip enable (active low)
    input  wire        WE_n,      // Write enable (active low)
    input  wire [ 3:0] D_3_0_IN,  // Data input for write
    output wire [ 3:0] D_3_0_OUT  // Data output for read
);

`ifdef QUARTUS_ALTSYNCRAM
  // ---------------------------------------------------------------------
  // Quartus-only: explicit altsyncram primitive (31-AUG-2026, MiSTer
  // build 2). Quartus 17.0.2 refused to infer M10K for the plain-Verilog
  // write-first template below - it reported the read as ASYNCHRONOUS
  // despite the whole thing sitting in one posedge-clk block (tried two
  // different, behaviorally-equivalent codings; both refused the same
  // way), then tried to build all 16 x 4Kx4 chips out of discrete
  // registers - 262,144 flip-flops for this bank alone, more than the
  // whole device has. Sidestepping inference entirely with Quartus's own
  // RAM megafunction is the documented way around that. Vivado, Gowin and
  // iverilog never see this branch and keep the plain-Verilog array below,
  // unchanged, exactly as their own inference already accepted it.
  //
  // WRONG, AND CORRECTED 01-SEP-2026 - kept because the reasoning error is
  // worth seeing: this comment used to claim that outdata_reg_a="CLOCK0" plus
  // read_during_write_mode_port_a="NEW_DATA_NO_NBE_READ" "reproduce the same
  // write-first, 1-sysclk-latency semantics as the plain-Verilog model".
  //
  // The read-during-write half is right. The LATENCY half is not. altsyncram
  // ALREADY registers the address in synchronous mode, so "CLOCK0" added a
  // SECOND register and made the read take TWO sysclks against the plain
  // model's one. The claim was written from the parameter names rather than
  // from what the primitive does, and nothing tested it - only this board
  // compiles this branch, so no simulation could ever have caught it.
  wire [3:0] s_q_a;
  reg        regCE_n = 1'b1;
  reg        regWE_n = 1'b1;

  //! WCS PRELOAD under SKIP_WCS_LOAD (31-AUG-2026). The `initial
  //! $readmemh(INIT_FILE, ...)` in the plain-Verilog branch below is how
  //! Vivado and Gowin bake the microcode into the bitstream; altsyncram
  //! takes its contents from init_file instead, and that wants a MIF, not a
  //! $readmemh nibble list. fpga/mister/tools/wcs_hex_to_mif.py converts
  //! each wcs_*.hex to wcs_*.hex.mif, so the name is just INIT_FILE with
  //! ".mif" appended - derived here rather than adding a second per-chip
  //! parameter to CPU_CS_WCS_21_22.v's 32 instantiations.
  //!
  //! An EMPTY WCS is exactly the "CPU does nothing at all" symptom this
  //! board had on its first bring-up: no SKIP_WCS_LOAD meant the runtime
  //! PROM->WCS loader ran instead, a path neither proven board uses.
`ifdef SKIP_WCS_LOAD
  localparam INIT_MIF = {INIT_FILE, ".mif"};
`else
  localparam INIT_MIF = "UNUSED";
`endif

  altsyncram #(
      .operation_mode                  ("SINGLE_PORT"),
      .width_a                         (4),
      .widthad_a                       (12),
      .numwords_a                      (4096),
      //! UNREGISTERED, not "CLOCK0" (01-SEP-2026, Ronny: "data needs to come
      //! out from WCS ASAP as address changes").
      //!
      //! altsyncram ALWAYS registers the address in synchronous mode. Adding
      //! outdata_reg_a="CLOCK0" put a SECOND register on the output, making
      //! the WCS read take TWO clocks - while the plain-Verilog model below,
      //! which every other board and the simulator run, takes ONE:
      //!     always @(posedge clk) data_out <= idt_memory_array[A_11_0];
      //!
      //! So on this board alone every microinstruction arrived a clock late.
      //! Measured consequence: the microsequencer ran one step out of
      //! alignment with the cycle controller, and a nested microsubroutine
      //! return popped the wrong address (001015 instead of the 002027 MACL
      //! pushed), so MACL never resumed and the machine looped forever in the
      //! interrupt-register microcode. See docs/mister-microcode-loop.md.
      .outdata_reg_a                   ("UNREGISTERED"),
      .read_during_write_mode_port_a   ("NEW_DATA_NO_NBE_READ"),
      .ram_block_type                  ("M10K"),
      .lpm_type                        ("altsyncram"),
      .intended_device_family          ("Cyclone V"),
      .init_file                       (INIT_MIF)
  ) RAM_INST (
      .clock0    (clk),
      .clocken0  (!CE_n),
      .address_a (A_11_0),
      .data_a    (D_3_0_IN),
      .wren_a    (!WE_n),
      .rden_a    (1'b1),
      .aclr0     (1'b0),
      .q_a       (s_q_a)
  );

  always @(posedge clk) begin
    regCE_n <= CE_n;
    regWE_n <= WE_n;
  end

  // Output: tri-state-equivalent. Drives the RAM's registered output only
  // when the registered CE_n is asserted AND the registered WE_n is high
  // (read mode) - same mask as the plain-Verilog branch.
  assign D_3_0_OUT = (!regCE_n && regWE_n) ? s_q_a : 4'b0000;

`else

  // Memory array - 4K x 4-bit. Marked for block RAM inference on FPGA targets.
  // Vivado/Xilinx (ram_style) and Gowin (syn_ramstyle) recognise this; Quartus
  // does not take this path at all (see the QUARTUS_ALTSYNCRAM branch above).
  (* syn_ramstyle = "block_ram", ram_style = "block" *)
  reg [3:0] idt_memory_array[0:4095];

  // Optional block-RAM preload (bitstream INIT on FPGA; $readmemh in sim).
  // Only active under SKIP_WCS_LOAD; preserves BRAM inference (Xilinx + Gowin).
`ifdef SKIP_WCS_LOAD
  initial begin
    if (INIT_FILE != "") $readmemh(INIT_FILE, idt_memory_array);
  end
`endif

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

`endif

endmodule

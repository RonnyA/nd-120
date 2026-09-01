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

`elsif QUARTUS_RAM_INFER

  // ---------------------------------------------------------------------
  // Quartus arm, second attempt (01-SEP-2026): the SAME array and the SAME
  // 1-clock write-first behaviour as the reference below, only restructured
  // into a shape Quartus 17.0 will map onto M10K. PLAIN VERILOG on purpose.
  //
  // Why plain Verilog and not the megafunction above: nothing simulates an
  // altsyncram, so its 2-clock read went unnoticed until it cost a day on
  // the board. Both arms here are ordinary Verilog, so
  // Shared/support/sim/run_altsyncram_equiv.sh can compile and run BOTH and
  // prove them cycle-identical. An arm that can be tested is worth more
  // than an arm that is "obviously" right.
  //
  // What Quartus objects to in the reference arm (measured, build v46):
  //     Info (276007): ... uninferred due to asynchronous read logic
  // for all 32 WCS chips, then
  //     Error (276003): Cannot convert all sets of registers into RAM ...
  // because 32 x 4K x 4 bits of flip-flops does not fit any device.
  // Nothing reads the array outside the clocked block, so the read is not
  // actually asynchronous. What it cannot map is the OUTPUT REGISTER: in
  // the reference, data_out loads from the ARRAY on a read but from
  // D_3_0_IN on a write. A register fed from a non-memory source cannot be
  // the M10K's own output register, so the array read is left with nowhere
  // synchronous to land - and M10K has no asynchronous read port (the same
  // limit that forces the async cache RAMs onto MLAB).
  //
  // NOTE this is a reading of the evidence, not a rule quoted from Intel's
  // documentation. The build is the proof; if the 276007 messages persist,
  // this arm is wrong and QUARTUS_ALTSYNCRAM above is still the answer.
  //
  // The fix: give the array read a register of its own that does nothing
  // but hold array data, and rebuild the write-first bypass outside it from
  // ordinary flip-flops.
  //
  // ramstyle "no_rw_check": a read and a write can hit the same address in
  // the same cycle. The bypass mux already supplies the new data there, so
  // whatever the M10K hands back on that cycle is discarded. Saying so
  // stops Quartus building bypass hardware we do not need.
  (* ramstyle = "no_rw_check, M10K" *)
  reg [3:0] idt_memory_array[0:4095];

  // Same optional preload as the reference arm. Quartus honours an
  // `initial $readmemh` as M10K bitstream init - unlike the megafunction
  // above, which needed a separately generated .mif.
`ifdef SKIP_WCS_LOAD
  initial begin
    if (INIT_FILE != "") $readmemh(INIT_FILE, idt_memory_array);
  end
`endif

  reg [3:0] mem_q   = 4'h0;   // pure array read - THIS is the M10K output reg
  reg [3:0] byp_q   = 4'h0;   // write data, held one clock to match mem_q
  reg       byp_sel = 1'b0;   // the last enabled cycle was a write
  reg       regCE_n = 1'b1;
  reg       regWE_n = 1'b1;

  always @(posedge clk) begin
    regCE_n <= CE_n;
    regWE_n <= WE_n;
    if (!CE_n) begin
      // Read on EVERY enabled cycle, with nothing but the enable gating it.
      // On a write cycle the fetched value is thrown away by the mux below.
      mem_q <= idt_memory_array[A_11_0];

      if (!WE_n) idt_memory_array[A_11_0] <= D_3_0_IN;

      byp_q   <= D_3_0_IN;
      byp_sel <= ~WE_n;
    end
    // CE_n high: mem_q, byp_q and byp_sel all hold, so the output holds -
    // exactly as data_out holds in the reference arm.
  end

  // Write-first bypass, rebuilt outside the memory read register.
  wire [3:0] data_out = byp_sel ? byp_q : mem_q;

  // Same output mask as both other arms.
  assign D_3_0_OUT = (!regCE_n && regWE_n) ? data_out : 4'b0000;

`else

  // Memory array - 4K x 4-bit. Marked for block RAM inference on FPGA targets.
  // This is the REFERENCE arm: Vivado (ram_style), Gowin (syn_ramstyle) plus
  // plus Verilator and iverilog, all take it and all infer block RAM from
  // it. Quartus does not - it takes one of the two arms above instead.
  // (Keep "Verilator" off the START of a comment line: Verilator reads a
  // comment beginning with that word as a lint metacomment and dies with
  // "Unknown verilator comment", which broke every sim build 01-SEP-2026.)
  //
  // MEASURED 01-SEP-2026 (build v46), correcting an earlier guess of mine:
  // adding Quartus's own "ramstyle" spelling here does NOT make Quartus
  // infer the array. It still reports every instance as
  //   Info (276007): ... uninferred due to asynchronous read logic
  // and fails Analysis & Synthesis trying to build them from flip-flops.
  // The attribute spelling was never the reason inference failed; the
  // structure of the output register is (see the QUARTUS_RAM_INFER arm).
  // "ramstyle" is left in place because it is the correct spelling to state
  // for Quartus and costs nothing, not because it fixes anything.
  //
  // Quartus also warns Warning (10306) on syn_ramstyle="block_ram": it does
  // recognise Synplify's attribute NAME but not Gowin's VALUE for it. That
  // warning is harmless - Quartus never builds this arm.
  (* syn_ramstyle = "block_ram", ram_style = "block", ramstyle = "M10K" *)
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

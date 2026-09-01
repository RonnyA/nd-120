//============================================================================
//! iverilog-simulatable behavioral stand-in for Quartus's altsyncram
//! megafunction, covering ONLY the parameter combinations this repo
//! actually uses (SINGLE_PORT, CLOCK0, either NEW_DATA_NO_NBE_READ/
//! DONT_CARE with a registered output, or an UNREGISTERED/MLAB async read).
//!
//! WHY THIS EXISTS: Quartus 17.0.2 refused plain-Verilog RAM inference for
//! three arrays (IDT6168A_20.v, MEM_RAM_49_BLOCKRAM.v, CPU_PROC_32.v's
//! registerBlock), all fixed with explicit altsyncram instances - but that
//! primitive is Quartus-only and cannot be simulated in iverilog, so those
//! branches were only ever checked for "does it synthesize," never "does it
//! behave correctly." After a MiSTer build 2 board bring-up showed the CPU
//! not running (31-AUG-2026), this stub exists to equivalence-test each
//! altsyncram translation against its proven plain-Verilog sibling before
//! spending another ~13-minute Quartus round trip guessing blind.
//!
//! Modeled strictly from Intel's documented altsyncram behavior for these
//! settings - not a general-purpose model, do not extend it casually.
//============================================================================

`default_nettype none

module altsyncram #(
    parameter                operation_mode                = "SINGLE_PORT",
    parameter integer         width_a                        = 8,
    parameter integer         widthad_a                      = 8,
    parameter integer         numwords_a                     = 256,
    parameter                outdata_reg_a                  = "UNREGISTERED",
    parameter                read_during_write_mode_port_a  = "DONT_CARE",
    parameter                ram_block_type                 = "AUTO",
    parameter                lpm_type                        = "altsyncram",
    parameter                intended_device_family          = "Cyclone V",
    //! Accepted for port-compatibility with the real megafunction; this
    //! stub does NOT preload from it (the equivalence tests write before
    //! they read, so contents-at-reset are not what they compare).
    parameter                init_file                       = "UNUSED"
) (
    input  wire                     clock0,
    input  wire                     clocken0,
    input  wire [widthad_a-1:0]     address_a,
    input  wire [width_a-1:0]       data_a,
    input  wire                     wren_a,
    input  wire                     rden_a,
    input  wire                     aclr0,
    output reg  [width_a-1:0]       q_a
);

  /* verilator lint_off UNUSEDSIGNAL */
  wire s_unused = &{1'b0, operation_mode == operation_mode, ram_block_type == ram_block_type,
                    lpm_type == lpm_type, intended_device_family == intended_device_family,
                    aclr0, rden_a};
  /* verilator lint_on UNUSEDSIGNAL */

  reg [width_a-1:0] mem[0:numwords_a-1];

  generate
    // ---------------------------------------------------------------------
    // WRONG UNTIL 01-SEP-2026, AND IT HID A REAL BUG.
    //
    // This stub modelled "UNREGISTERED" as a pure combinational read (ZERO
    // clocks) and "CLOCK0" as one clock. The real primitive is one clock and
    // TWO, because altsyncram ALWAYS registers the address in synchronous
    // mode - `ram_block_type("M10K")` and an M10K physically cannot read
    // asynchronously (that is the very constraint that forces the async cache
    // RAMs onto MLAB). `outdata_reg_a` adds an OPTIONAL SECOND register.
    //
    // Because the stub was off by one in both settings, the IDT6168A
    // equivalence check passed with "CLOCK0" - and the WCS on MiSTer was
    // handing the microsequencer every microinstruction a clock late.
    //
    // Modelled faithfully below: an address register always, plus the output
    // register only for "CLOCK0".
    // ---------------------------------------------------------------------
    if (outdata_reg_a == "UNREGISTERED") begin : g_async
      // MLAB-style: write is synchronous, read is a pure combinational
      // function of the array (true async read). A continuous `assign`,
      // not `always @(*)`, on purpose - Icarus's `@(*)` sensitivity
      // inference for a memory-array-indexed read tracks the INDEX only,
      // not the array's CONTENT, so a write that lands on the currently
      // addressed word (address_a unchanged) would not re-trigger the
      // block and q_a would go stale/X. `assign` has full, correct
      // sensitivity for this (found 31-AUG-2026 diffing this stub against
      // the proven plain-Verilog registerBlock model - false divergence,
      // not a real hardware behavior difference).
      // ONE clock: the address is registered, the array read is combinational
      // out of that register. Write-first forwarding on the same address.
      reg [widthad_a-1:0] addr_q = {widthad_a{1'b0}};
      always @(posedge clock0) begin
        if (clocken0) begin
          if (wren_a) mem[address_a] <= data_a;
          addr_q <= address_a;
        end
      end
      // Write-first falls out for free: the write lands on the SAME edge that
      // captures addr_q, so a combinational read of mem[addr_q] afterwards
      // already sees the new data. No forwarding term needed.
      wire [width_a-1:0] mem_word = mem[addr_q];
      always @(*) q_a = mem_word;
    end else begin : g_sync
      // CLOCK0-registered output. read_during_write_mode_port_a is either
      // NEW_DATA_NO_NBE_READ (write-first: q_a shows the write data) or
      // DONT_CARE (undefined during a write) - both repo uses treat the
      // write-cycle q_a value as unobserved externally, so model both as
      // write-first, which is a superset-safe behavior for equivalence
      // checking (never LESS informative than DONT_CARE would allow).
      // TWO clocks: address register, then the OPTIONAL output register that
      // outdata_reg_a="CLOCK0" adds. The intermediate value is what the
      // UNREGISTERED setting would have produced.
      reg [width_a-1:0] q_stage1 = {width_a{1'b0}};
      always @(posedge clock0) begin
        if (clocken0) begin
          if (wren_a) begin
            mem[address_a] <= data_a;
            q_stage1       <= data_a;      // write-first
          end else if (rden_a) begin
            q_stage1 <= mem[address_a];
          end
          q_a <= q_stage1;                 // the SECOND register
        end
      end
    end
  endgenerate

endmodule

`default_nettype wire

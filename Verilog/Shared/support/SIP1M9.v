/******************************************************************************
** RAM CHIP 1 MBYTE (1024KB)                                                  **
**                                                                            **
** This ram has PARITY bit..                                                  **
** THM91020 - http://norsk-data.com/library/libother/extern/THM91020.pdf      **
** THM91070 - http://norsk-data.com/library/libother/extern/THM91070.pdf      **
**                                                                            **
** Last reviewed: 9-FEB-2025                                                  **
** Ronny Hansen                                                               **
********************************************************************************/

// TODO: Implement access to real RAM inside FPGA

module SIP1M9 (

    // Input signals
    input sysclk,    //! System clock in FPGA
    input sys_rst_n, //! System reset in FPGA

    input [9:0] ADDRESS,  //! Address input
    input       CAS9_n,   //! Column address strobe
    input       CAS_n,    //! Column address strobe
    input       RAS_n,    //! Row address strobe
    input       W_n,      //! Read/Write signal


    // Input signals
    input [7:0] D8,  //! DATA INPUT (8-bit)
    input       D9,  //! DATA INPUT (1-bit)

    // Output signals
    output [7:0] Q8,    //! DATA OUTPUT (8-bit)
    output       Q9,    //! DATA OUTPUT (1-bit)
    output       PRD_n  //! Parity Data Output

);

  wire parity_calculation;

  // Parameters are declared here
  parameter ramSize = 0; // 0 = Disabled, 1=64KB, 2=1MB, 3=4KB (for FPGA BRAM testing)


// Convert ramSize into a memory depth.
// Feel free to tweak default 1 if "disabled" should do something else.
  localparam integer MEM_DEPTH = (ramSize == 2) ? 1048575 :   // 1 MB (too large for FPGA BRAM)
                                 (ramSize == 1) ? 65535   :   // 64 KB (still too large for small FPGAs)
                                 (ramSize == 3) ? 4095    :   // 4 KB (fits in BRAM for testing)
                                                  1;          // Disabled = 1 word (or 0, if desired)

  reg  [7:0] reg_Q8;
  reg        reg_Q9;

  // NOTE: sdram/sdram_9 are declared at MODULE scope (not inside the generate) so
  // their Verilator hierarchical name stays `...CHIP_15H__DOT__sdram`, which the C++
  // sim harnesses (loadfile in test_nd120.cpp / Run120.cpp / latch_ff_compare.cpp)
  // reference to preload programs. ONLY declared for Verilator (ramSize=2 DRAM model);
  // on the FPGA (ramSize=3) it is unused, and as a block-RAM-styled array it was NOT
  // pruned in time and pushed BRAM usage over the xc7a35t's 100-block limit -> synth
  // OOM. Guarded out of the FPGA build. (ramSize=2 <=> VERILATOR_SIM in this design.)
`ifdef VERILATOR_SIM
  (* ram_style = "block" *) reg [7:0] sdram   [0:MEM_DEPTH-1];
  (* ram_style = "block" *) reg       sdram_9 [0:MEM_DEPTH-1];
`endif

generate
if (ramSize == 3) begin : g_fpga_bram
  // ======================================================================
  //  FPGA SYNCHRONOUS BRAM PATH (ramSize=3)
  // ----------------------------------------------------------------------
  //  The original DRAM model below (ramSize=2) is a ZERO-DELAY simulation
  //  model: it clocks on negedge RAS_n/CAS_n (routed control signals, not a
  //  clock), gates the read output combinationally by CAS_n, and indexes a
  //  20-bit `sip_address` into whatever depth is declared. On real BRAM that
  //  fails four ways (glitchy clock, read-0 race, address-changes-with-clock,
  //  and — because sip_address = {row,col} reorders the bits — consecutive
  //  addresses land 1024 apart and alias in a small array).
  //
  //  This path is a proper SYNCHRONOUS BRAM: everything on sysclk; RAS_n/CAS_n
  //  are treated as level enables (they are PAL outputs registered on OSC=sysclk
  //  in this design, so they are already sysclk-synchronous); the read output is
  //  registered and HELD stable (the controller's RDATA strobe samples it late in
  //  the cycle while CAS is still low); and the address is reconstructed to the
  //  LINEAR word address LBD[19:0] = {col, row} so it is contiguous, then the low
  //  FPGA_ADDR_BITS are used (no reorder-aliasing).
  // ======================================================================
  localparam integer FPGA_ADDR_BITS = 12;                 // 4 K words/chip (fits xc7a35t; tune up later)
  localparam integer FPGA_DEPTH     = (1 << FPGA_ADDR_BITS);

  (* ram_style = "block" *) reg [7:0] bram8 [0:FPGA_DEPTH-1];
  (* ram_style = "block" *) reg       bram9 [0:FPGA_DEPTH-1];

  reg  [9:0] row_addr;                                     // AA latched during the RAS/row phase
  // Linear word address = {col, row} = LBD[19:0]; use the low FPGA_ADDR_BITS.
  wire [19:0] lin_addr  = {ADDRESS[9:0], row_addr[9:0]};   // {col(now on AA during CAS), row}
  wire [FPGA_ADDR_BITS-1:0] a = lin_addr[FPGA_ADDR_BITS-1:0];

  always @(posedge sysclk) begin
    // Track the row address throughout the RAS window (before CAS asserts);
    // whatever is on AA when CAS falls no longer overwrites it.
    if (!RAS_n && CAS_n) row_addr <= ADDRESS[9:0];

    // Access while both strobes are active (bank-gated CAS_n already selects us).
    if (!RAS_n && !CAS_n) begin
      if (W_n) begin                                       // read (re-reads while CAS low; addr stable)
        reg_Q8 <= bram8[a];
        reg_Q9 <= bram9[a];
      end else begin                                       // write
        bram8[a] <= D8;
        bram9[a] <= D9;
      end
    end
  end

  // Registered, held read data; still bank-gated (0 when not selected / not a read)
  // so the three banks' outputs OR-combine correctly in MEM_RAM_49.
  assign Q8 = ((CAS_n == 0) && (W_n)) ? reg_Q8 : 8'b0;
  assign Q9 = ((CAS_n == 0) && (W_n)) ? reg_Q9 : 1'b0;

end else begin : g_sim_dram
  // ======================================================================
  //  ORIGINAL ZERO-DELAY DRAM MODEL (ramSize=2 Verilator, etc.) — unchanged
  //  (sdram/sdram_9 declared at module scope above)
  // ======================================================================
  reg [9:0] hi_address;

  wire [19:0] sip_address = (CAS_n == 0) ? {hi_address[9:0], ADDRESS[9:0]} : 20'b0;

  always @(negedge RAS_n) begin
    hi_address <= ADDRESS[9:0];
  end

  always @(negedge CAS_n) begin
    if (!RAS_n) begin
      if (W_n) begin  // read
        reg_Q8 <= sdram[sip_address];
        reg_Q9 <= sdram_9[sip_address];
      end else begin  // write
        sdram[sip_address]   <= D8;
        sdram_9[sip_address] <= D9;
      end
    end
  end

  // Data out is valid as long as CAS is active (and its read, not write)
  assign Q8 = ((CAS_n == 0) && (W_n)) ? reg_Q8 : 8'b00000000;
  assign Q9 = ((CAS_n == 0) && (W_n)) ? reg_Q9 : 0;
end
endgenerate


  // Even Parity Logic
    // ^ (in Verilig) is XOR giving 0=if even, 1=if odd.
  // Invert this so that the PAR signal is according to Am29833A documentation: PAR=L on ODD and PAR=H on EVEN
  assign parity_calculation =  (^{Q8, Q9});

  assign PRD_n = ((CAS_n == 0) && (W_n))  ? parity_calculation : 1;
  /*
  assign PRD_n = ~(
    Q8[0] ^
    Q8[1] ^
    Q8[2] ^
    Q8[3] ^
    Q8[4] ^
    Q8[5] ^
    Q8[6] ^
    Q8[7] ^
    Q9
  );
  */

endmodule

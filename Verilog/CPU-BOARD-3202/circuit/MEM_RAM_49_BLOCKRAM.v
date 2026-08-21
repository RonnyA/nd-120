/**************************************************************************
** ND120 CPU, MM&M                                                       **
** MEM/RAM - block-RAM backend (any FPGA)                                **
** Drop-in replacement for the sheet-49 RAM (MEM_RAM_49): one clean      **
** synchronous BRAM instead of six emulated SIP1M9 DRAM chips.           **
** Selected with `define MAIN_RAM_BLOCKRAM (see MEM_43.v).               **
**                                                                       **
** Implements the MEASURED DRAM protocol (docs/nd120-dram-memory.md      **
** section 4) with the hardware lessons of 8-JUL-2026 baked in:          **
**   - row captured at the RAS rising edge (not level)                   **
**   - write data captured BEFORE CAS (the D bus is driven early and     **
**     released around CAS-fall on silicon)                              **
**   - write executed ONCE, at the first RAS&CAS edge                    **
**   - registered read, held while CAS is active, bank-gated output      **
**                                                                       **
** Capacity: NUM_BANKS x 2^BANK_ADDR_BITS 18-bit words. Default 3 banks  **
** x 4K words = 24 KB (Basys3 xc7a35t BRAM budget). Boards with more     **
** BRAM raise BANK_ADDR_BITS. Linear word address = {col, row} like the  **
** proven SIP1M9 FPGA path; the low BANK_ADDR_BITS are used, so keep     **
** test addresses inside a bank to avoid aliasing.                       **
**                                                                       **
** Last reviewed: 8-JUL-2026                                             **
** Ronny Hansen                                                          **
***************************************************************************/

module MEM_RAM_49_BLOCKRAM #(
    parameter integer BANK_ADDR_BITS = 12,  // words per bank = 2**BANK_ADDR_BITS
    parameter integer NUM_BANKS = 3         // informational; storage is 4 bank slots
) (
    // Input signals (sheet-49 interface, same as MEM_RAM_49)
    input sysclk,
    input sys_rst_n,

    input [9:0] AA_9_0,
    input       BANK0,
    input       BANK1,
    input       BANK2,

    input CAS,
    input RAS,

    input MWRITE50_n,

    input  [17:0] DD_17_0_IN,
    output [17:0] DD_17_0_OUT,

    output CORR_n
);

  /* verilator lint_off UNUSEDSIGNAL */
  wire [31:0] unused_params = NUM_BANKS;
  /* verilator lint_on UNUSEDSIGNAL */

  // One 16-bit wide BRAM, 4 bank slots (bank 3 unused).
  // PARITY IS NEVER STORED (policy, Ronny 3-AUG-2026): the two parity bits
  // DD[8] and DD[17] are dropped on write and regenerated as ODD parity on
  // read, exactly as MEM_RAM_49_SDRAM and SIP1M9 do. 18 bits wide would have
  // cost extra block RAM to hold bits nothing reads back.
  (* ram_style = "block", syn_ramstyle = "block_ram" *)
  reg [15:0] mem[0:(4 << BANK_ADDR_BITS)-1];

  // {high byte, low byte} -> full 18-bit word with regenerated odd parity
  function [17:0] with_parity(input [15:0] d);
    with_parity = {~(^d[15:8]), d[15:8], ~(^d[7:0]), d[7:0]};
  endfunction

  reg [9:0] row_q;
  reg       ras_d;
  reg [17:0] dd_q;    // write data captured while RAS active, CAS not yet seen
  reg        win_d;   // access window (RAS & CAS & bank), one sysclk delayed

  // Raw registered array read. The parity regeneration must sit AFTER this
  // register: with_parity() between the array and the register put an XOR
  // function in the read path, which stopped Vivado inferring block RAM -
  // the whole 16K x 16 array fell back to 1024 RAM256X1S distributed-RAM
  // primitives (measured 21-AUG-2026, Synth 8-6849). Registered raw read =
  // BRAM-mappable; the parity bits are combinational on the FF output.
  reg [15:0] rd_raw;
  wire [17:0] rd_q = with_parity(rd_raw);

  // Linear word address {col, row}, low bits (same mapping as the proven
  // SIP1M9 FPGA path: contiguous CPU addresses stay contiguous)
  wire [19:0] lin = {AA_9_0, row_q};
  wire [BANK_ADDR_BITS-1:0] a = lin[BANK_ADDR_BITS-1:0];
  wire [1:0] bidx = BANK1 ? 2'd1 : (BANK2 ? 2'd2 : 2'd0);
  wire bsel = BANK0 | BANK1 | BANK2;
  wire win = RAS & CAS & bsel;

  always @(posedge sysclk) begin
    if (!sys_rst_n) begin
      ras_d <= 0;
      win_d <= 0;
    end else begin
      ras_d <= RAS;
      win_d <= win;

      // row: exactly once, at the RAS rising edge (AA carries the row there)
      if (RAS && !ras_d) row_q <= AA_9_0;

      // write data: capture every edge until CAS is seen high - the final
      // capture (the CAS-fall edge) holds the settled pre-CAS value
      if (RAS && !CAS) dd_q <= DD_17_0_IN;

      if (win) begin
        if (MWRITE50_n) begin
          // read: registered raw, re-reads while CAS; parity regenerated
          // combinationally AFTER the register (see rd_raw above)
          rd_raw <= mem[{bidx, a}];
        end else if (!win_d) begin
          // write: ONCE, first window edge; the two parity bits are dropped
          mem[{bidx, a}] <= {dd_q[16:9], dd_q[7:0]};
        end
      end
    end
  end

  // Output gating: same convention as the chips (0 when not selected/reading)
  wire read_active = CAS & MWRITE50_n & bsel;
  assign DD_17_0_OUT = read_active ? rd_q : 18'b0;

  // Parity check outputs, same formula as two SIP1M9 chips (low = DD[8:0],
  // high = DD[17:9]), AND-combined; 1 when inactive
  assign CORR_n = read_active ? ((^rd_q[8:0]) & (^rd_q[17:9])) : 1'b1;

endmodule

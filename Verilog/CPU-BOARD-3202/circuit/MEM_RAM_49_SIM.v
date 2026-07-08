/**************************************************************************
** ND120 CPU, MM&M                                                       **
** MEM/RAM - Verilator simulation backend                                **
** Drop-in replacement for the sheet-49 RAM (MEM_RAM_49): the original   **
** zero-delay DRAM model of the six SIP1M9 chips, ported to the shared   **
** sheet-49 interface. Selected automatically for VERILATOR_SIM builds   **
** (see MEM_43.v). Behavior is a faithful port of SIP1M9's ramSize=2     **
** model: row latched on the (bank-gated) RAS edge, memory clocked on    **
** the (bank-gated) CAS edge, output gated by CAS, {row,col} indexing.   **
**                                                                       **
** Capacity: 3 banks x 1M x 18 bits = 6 MB, same as before.              **
**                                                                       **
** NOTE for the C++ harnesses (test_nd120.cpp / Run120.cpp /             **
** latch_ff_compare.cpp): programs are preloaded by poking the BANK0     **
** arrays by hierarchical name:                                          **
**   ...MEM__DOT__RAM__DOT__b0_lo    [1M x 8]  data bits 7:0             **
**   ...MEM__DOT__RAM__DOT__b0_lo_p  [1M x 1]  parity bit 8              **
**   ...MEM__DOT__RAM__DOT__b0_hi    [1M x 8]  data bits 16:9            **
**   ...MEM__DOT__RAM__DOT__b0_hi_p  [1M x 1]  parity bit 17             **
** (same element widths as the old CHIP_15H/15J sdram/sdram_9 arrays).   **
**                                                                       **
** Last reviewed: 8-JUL-2026                                             **
** Ronny Hansen                                                          **
***************************************************************************/

module MEM_RAM_49_SIM (
    // Input signals (sheet-49 interface, same as MEM_RAM_49)
    /* verilator lint_off UNUSEDSIGNAL */
    input sysclk,     // unused: this is the zero-delay strobe-clocked model
    input sys_rst_n,  // unused
    /* verilator lint_on UNUSEDSIGNAL */

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

  localparam integer DEPTH = 1048576;  // 1M words per bank

  // Bank 0 arrays - names/widths are load-bearing for the C++ preload hooks
  reg [7:0] b0_lo  [0:DEPTH-1];
  reg       b0_lo_p[0:DEPTH-1];
  reg [7:0] b0_hi  [0:DEPTH-1];
  reg       b0_hi_p[0:DEPTH-1];

  reg [7:0] b1_lo  [0:DEPTH-1];
  reg       b1_lo_p[0:DEPTH-1];
  reg [7:0] b1_hi  [0:DEPTH-1];
  reg       b1_hi_p[0:DEPTH-1];

  reg [7:0] b2_lo  [0:DEPTH-1];
  reg       b2_lo_p[0:DEPTH-1];
  reg [7:0] b2_hi  [0:DEPTH-1];
  reg       b2_hi_p[0:DEPTH-1];

  // Bank-gated strobes: posedge (RAS & BANKx) is the same event as the old
  // negedge of the chips' s_ras_bX = ~(RAS & BANKx)
  wire ras_b0 = RAS & BANK0;
  wire cas_b0 = CAS & BANK0;
  wire ras_b1 = RAS & BANK1;
  wire cas_b1 = CAS & BANK1;
  wire ras_b2 = RAS & BANK2;
  wire cas_b2 = CAS & BANK2;

  reg [9:0] row0, row1, row2;
  reg [17:0] q0, q1, q2;

  always @(posedge ras_b0) row0 <= AA_9_0;
  always @(posedge ras_b1) row1 <= AA_9_0;
  always @(posedge ras_b2) row2 <= AA_9_0;

  // {row, col} indexing - identical to the old sip_address
  wire [19:0] idx0 = {row0, AA_9_0};
  wire [19:0] idx1 = {row1, AA_9_0};
  wire [19:0] idx2 = {row2, AA_9_0};

  always @(posedge cas_b0)
    if (ras_b0) begin
      if (MWRITE50_n) q0 <= {b0_hi_p[idx0], b0_hi[idx0], b0_lo_p[idx0], b0_lo[idx0]};
      else begin
        {b0_hi_p[idx0], b0_hi[idx0], b0_lo_p[idx0], b0_lo[idx0]} <= DD_17_0_IN;
      end
    end

  always @(posedge cas_b1)
    if (ras_b1) begin
      if (MWRITE50_n) q1 <= {b1_hi_p[idx1], b1_hi[idx1], b1_lo_p[idx1], b1_lo[idx1]};
      else begin
        {b1_hi_p[idx1], b1_hi[idx1], b1_lo_p[idx1], b1_lo[idx1]} <= DD_17_0_IN;
      end
    end

  always @(posedge cas_b2)
    if (ras_b2) begin
      if (MWRITE50_n) q2 <= {b2_hi_p[idx2], b2_hi[idx2], b2_lo_p[idx2], b2_lo[idx2]};
      else begin
        {b2_hi_p[idx2], b2_hi[idx2], b2_lo_p[idx2], b2_lo[idx2]} <= DD_17_0_IN;
      end
    end

  // Data out valid while the bank's CAS is active on a read; banks OR together
  wire [17:0] dd0 = (cas_b0 && MWRITE50_n) ? q0 : 18'b0;
  wire [17:0] dd1 = (cas_b1 && MWRITE50_n) ? q1 : 18'b0;
  wire [17:0] dd2 = (cas_b2 && MWRITE50_n) ? q2 : 18'b0;
  assign DD_17_0_OUT = dd0 | dd1 | dd2;

  // Parity outputs: per virtual chip, XOR of its 9 bits when reading, else 1;
  // AND-combined - identical to the six chips' PRD_n -> CORR_n
  wire prd_b0l = (cas_b0 && MWRITE50_n) ? (^q0[8:0]) : 1'b1;
  wire prd_b0h = (cas_b0 && MWRITE50_n) ? (^q0[17:9]) : 1'b1;
  wire prd_b1l = (cas_b1 && MWRITE50_n) ? (^q1[8:0]) : 1'b1;
  wire prd_b1h = (cas_b1 && MWRITE50_n) ? (^q1[17:9]) : 1'b1;
  wire prd_b2l = (cas_b2 && MWRITE50_n) ? (^q2[8:0]) : 1'b1;
  wire prd_b2h = (cas_b2 && MWRITE50_n) ? (^q2[17:9]) : 1'b1;
  assign CORR_n = prd_b0l & prd_b0h & prd_b1l & prd_b1h & prd_b2l & prd_b2h;

endmodule

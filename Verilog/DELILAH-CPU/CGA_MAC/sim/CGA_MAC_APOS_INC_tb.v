/**************************************************************************
** ND120 CGA (CPU Gate Array / DELILAH)                                  **
** CGA_MAC_APOS_INC testbench                                            **
**                                                                       **
** Exhaustive verification of the 16-bit incrementer (/CGA/MAC/APOS/INC, **
** page 33). The active RTL is `NLCA = LCA + 1`; the retired _OLD_WAY_   **
** gate netlist (16 FullAdders rippling +1 with two NAND group-carry     **
** lookaheads: GATES_1 = carry out of bits 7:0 into bit 8, GATES_2 =     **
** carry out of bits 12:8 into bit 13, BubblesMask 0 everywhere) was     **
** modeled literally in the independent Python generator                 **
** (gen_tier3_mac_golden.py, scratchpad only) and proven equal to        **
** (LCA+1) mod 2^16 for ALL 65536 inputs. That generator also emitted    **
** the sweep checksum constant and the directed corner constants below.  **
**                                                                       **
** Checks:                                                               **
**  1. Exhaustive sweep, all 65536 LCA values, NLCA vs an independent    **
**     bitwise ripple-increment model. 65536 checks.                     **
**  2. Running checksum of the actual NLCA sequence vs the Python        **
**     constant (chk = chk*33 + NLCA mod 2^32). 1 check.                 **
**  3. Directed carry-boundary corners with literal Python-emitted       **
**     expected constants. 8 checks.                                     **
**                                                                       **
** Pure combinational module: the active code instantiates NO library    **
** primitives (no FPGA_FF_MODE / USE_TRANSPARENT_LATCHES sensitivity),   **
** so a SINGLE build covers all modes.                                   **
**                                                                       **
** Self-checking: prints TB_RESULT: PASS / FAIL (never silent).          **
**                                                                       **
** 31-JUL-2026                                                           **
** Ronny Hansen                                                          **
***************************************************************************/
`timescale 1ns / 1ps

module CGA_MAC_APOS_INC_tb;

  reg  [15:0] LCA = 0;
  wire [15:0] NLCA;

  integer errors = 0;
  integer checks = 0;
  integer i;
  reg [31:0] chk;

  localparam integer EXPECTED_CHECKS = 65545;
  // Emitted by gen_tier3_mac_golden.py (chk = chk*33 + NLCA, LCA ascending)
  localparam [31:0] SWEEP_CHECKSUM = 32'hE04F8000;

  reg [15:0] cvec[0:7];
  reg [15:0] cexp[0:7];

  CGA_MAC_APOS_INC dut (
      .LCA_15_0 (LCA),
      .NLCA_15_0(NLCA)
  );

  task check_word(input [15:0] val, input [15:0] exp, input [127:0] name);
    begin
      checks = checks + 1;
      if (val !== exp) begin
        errors = errors + 1;
        $display("FAIL %0s: NLCA=%04x expected %04x (LCA=%04x)",
                 name, val, exp, LCA);
      end
    end
  endtask

  // Independent expected model: bitwise ripple increment (no '+' on the
  // full word), typed separately from the DUT's arithmetic assign.
  function [15:0] inc_ripple(input [15:0] v);
    integer b;
    reg carry;
    begin
      carry = 1'b1;
      for (b = 0; b < 16; b = b + 1) begin
        inc_ripple[b] = v[b] ^ carry;
        carry = v[b] & carry;
      end
    end
  endfunction

  initial begin
    $display("CGA_MAC_APOS_INC_tb: single build (pure comb, no primitives)");

    // ------------------------------------------------------------------
    // 1+2. Exhaustive sweep + running checksum: 65536 + 1 checks.
    // ------------------------------------------------------------------
    chk = 32'd0;
    for (i = 0; i < 65536; i = i + 1) begin
      LCA = i[15:0];
      #2;
      check_word(NLCA, inc_ripple(i[15:0]), "exhaustive sweep");
      chk = chk * 33 + {16'b0, NLCA};
    end
    checks = checks + 1;
    if (chk !== SWEEP_CHECKSUM) begin
      errors = errors + 1;
      $display("FAIL sweep checksum: got %08x expected %08x",
               chk, SWEEP_CHECKSUM);
    end

    // ------------------------------------------------------------------
    // 3. Directed carry-boundary corners (literal Python constants). 8.
    // ------------------------------------------------------------------
    cvec[0] = 16'h0000; cexp[0] = 16'h0001;
    cvec[1] = 16'h00FF; cexp[1] = 16'h0100;  // carry across GATES_1 group
    cvec[2] = 16'h0FFF; cexp[2] = 16'h1000;
    cvec[3] = 16'h1FFF; cexp[3] = 16'h2000;  // carry across GATES_2 group
    cvec[4] = 16'h7FFF; cexp[4] = 16'h8000;
    cvec[5] = 16'hFFFE; cexp[5] = 16'hFFFF;
    cvec[6] = 16'hFFFF; cexp[6] = 16'h0000;  // full wraparound
    cvec[7] = 16'hAAAA; cexp[7] = 16'hAAAB;
    for (i = 0; i < 8; i = i + 1) begin
      LCA = cvec[i];
      #2;
      check_word(NLCA, cexp[i], "corner");
    end

    // ------------------------------------------------------------------
    // Verdict. Expected: 65536 + 1 + 8 = 65545.
    // ------------------------------------------------------------------
    if (errors == 0 && checks == EXPECTED_CHECKS)
      $display("TB_RESULT: PASS (%0d checks)", checks);
    else
      $display("TB_RESULT: FAIL (%0d errors, %0d of %0d checks)",
               errors, checks, EXPECTED_CHECKS);
    $finish;
  end

endmodule

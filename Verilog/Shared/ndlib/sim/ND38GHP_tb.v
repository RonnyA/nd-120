/****************************************************************************
** ND38GHP - exhaustive functional testbench                              **
**                                                                         **
** WHAT THIS MODULE ACTUALLY IS                                            **
**   A 3-to-8 decoder wrapping Decoder_8. Select is built as               **
**   s_sel[0]=A, s_sel[1]=B, s_sel[2]=C, so sel = {C,B,A} with A the LOW   **
**   bit. GN is ACTIVE LOW: s_g = ~GN is Decoder_8's active-high enable.   **
**   Outputs are NOT inverted (Z_i = decoder output directly), so this     **
**   part is ACTIVE HIGH one-hot: when enabled, exactly the selected       **
**   output is 1 and the rest are 0.                                       **
**                                                                         **
**   DISABLED STATE (GN=1, so s_g=0): per Decoder_8's else branch, ALL     **
**   EIGHT outputs are 0. So ND38GHP disabled = ALL ZERO.                  **
**                                                                         **
** COVERAGE: EXHAUSTIVE. Inputs are A, B, C, GN = 4 bits, so 2^4 = 16      **
**   combinations. For every one, all 8 outputs are checked against the    **
**   reference model, plus a one-hot-or-all-zero invariant.                **
**                                                                         **
** VCD: 16 combinations, dumped in full.                                   **
**                                                                         **
** Run: cd Verilog/Shared/ndlib/sim && iverilog -g2012 -o ND38GHP_tb.vvp \
**          ND38GHP_tb.v -y .. -y ../../logisim && vvp ND38GHP_tb.vvp      **
**                                                                         **
** Last reviewed: 20-AUG-2026                                              **
** Ronny Hansen                                                            **
*****************************************************************************/
`timescale 1ns / 1ps
`default_nettype none

module ND38GHP_tb;

  reg A, B, C, GN;
  wire Z0, Z1, Z2, Z3, Z4, Z5, Z6, Z7;
  wire [7:0] Z = {Z7, Z6, Z5, Z4, Z3, Z2, Z1, Z0};

  integer errors = 0;
  integer checks = 0;
  integer combo;
  reg [7:0] expected;

  ND38GHP DUT (
      .A (A), .B(B), .C(C), .GN(GN),
      .Z0(Z0), .Z1(Z1), .Z2(Z2), .Z3(Z3),
      .Z4(Z4), .Z5(Z5), .Z6(Z6), .Z7(Z7)
  );

  // reference model: sel = {C,B,A}, A is the low bit; GN active low enable;
  // active high one-hot outputs; disabled = all zero
  function [7:0] ref_z;
    input a, b, c, gn;
    reg [2:0] sel;
    begin
      if (gn) begin
        ref_z = 8'b0;
      end else begin
        sel = {c, b, a};
        ref_z = (8'b1 << sel);
      end
    end
  endfunction

  initial begin
    $dumpfile("ND38GHP_tb.vcd");
    $dumpvars(0, ND38GHP_tb);

    GN=0; A=0; B=0; C=0; #10;  // sel=0 enabled
    A=1; B=0; C=0; #10;        // sel=1
    A=0; B=1; C=0; #10;        // sel=2
    A=1; B=1; C=1; #10;        // sel=7
    GN=1; #10;                 // disabled

    $display("=====================================================");
    $display(" ND38GHP exhaustive functional testbench");
    $display(" (all 16 input combinations; sel = {C,B,A}, A is the low bit)");
    $display("=====================================================");

    for (combo = 0; combo < 16; combo = combo + 1) begin
      {A, B, C, GN} = combo[3:0];
      #1;
      expected = ref_z(A, B, C, GN);
      checks   = checks + 8;
      if (Z !== expected) begin
        errors = errors + 1;
        $display("FAIL: A=%b B=%b C=%b GN=%b -> Z=%08b expected %08b", A, B, C, GN, Z, expected);
      end
      // one-hot (enabled) or all-zero (disabled) invariant
      checks = checks + 1;
      if (GN == 1'b0) begin
        if ($countones(Z) !== 1) begin
          errors = errors + 1;
          $display("FAIL ONEHOT: enabled Z=%08b has %0d ones, expected exactly 1", Z, $countones(Z));
        end
      end else begin
        if (Z !== 8'b0) begin
          errors = errors + 1;
          $display("FAIL DISABLED_NOT_ZERO: GN=1 Z=%08b expected all zero", Z);
        end
      end
    end

    // ---- named property checks -------------------------------------------

    // 1. Disabled state is ALL ZERO (active-high part, GN active low)
    GN = 1'b1; A = 1'b1; B = 1'b1; C = 1'b1; #1;
    checks = checks + 1;
    if (Z !== 8'b00000000) begin
      errors = errors + 1;
      $display("FAIL DISABLED_ALL_ZERO: Z=%08b expected 00000000 when GN=1", Z);
    end

    // 2. Select bit order: A is the low bit, C is the high bit
    GN = 1'b0; A = 1'b0; B = 1'b1; C = 1'b0; #1;  // {C,B,A}=010=2 -> Z2
    checks = checks + 1;
    if (Z !== 8'b00000100) begin
      errors = errors + 1;
      $display("FAIL SEL_ORDER: A=0,B=1,C=0 -> Z=%08b expected Z2 only (00000100)", Z);
    end

    $display("-----------------------------------------------------");
    $display(" checks run : %0d", checks);
    $display(" failures   : %0d", errors);
    if (errors == 0) $display("TB_RESULT: PASS");
    else             $display("TB_RESULT: FAIL");
    $display("=====================================================");
    $finish;
  end

endmodule

`default_nettype wire

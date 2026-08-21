/****************************************************************************
** MUX41P - exhaustive functional testbench                               **
**                                                                         **
** WHAT THIS MODULE ACTUALLY IS                                            **
**   A single 4-to-1 Multiplexer_4 with sel wired as `.sel({B, A})`, so    **
**   sel = {B,A} with A the LOW bit. No output inversion:                  **
**       Z = D[ {B,A} ]                                                    **
**                                                                         **
** COVERAGE: EXHAUSTIVE. Inputs are A, B, D0, D1, D2, D3 = 6 bits, so      **
**   2^6 = 64 combinations, every one checked against the reference model. **
**                                                                         **
** VCD: the whole run is a few dozen steps, so it is dumped in full.       **
**                                                                         **
** Run: cd Verilog/Shared/ndlib/sim && iverilog -g2012 -o MUX41P_tb.vvp \
**          MUX41P_tb.v -y .. -y ../../logisim && vvp MUX41P_tb.vvp        **
**                                                                         **
** Last reviewed: 20-AUG-2026                                              **
** Ronny Hansen                                                            **
*****************************************************************************/
`timescale 1ns / 1ps
`default_nettype none

module MUX41P_tb;

  reg A, B, D0, D1, D2, D3;
  wire Z;

  integer errors = 0;
  integer checks = 0;
  integer combo;
  reg expected;

  MUX41P DUT (
      .A (A), .B(B),
      .D0(D0), .D1(D1), .D2(D2), .D3(D3),
      .Z (Z)
  );

  // reference model: sel = {B,A}, A is the low bit
  function ref_z;
    input a, b, d0, d1, d2, d3;
    reg [1:0] sel;
    begin
      sel = {b, a};
      case (sel)
        2'd0: ref_z = d0;
        2'd1: ref_z = d1;
        2'd2: ref_z = d2;
        2'd3: ref_z = d3;
      endcase
    end
  endfunction

  initial begin
    $dumpfile("MUX41P_tb.vcd");
    $dumpvars(0, MUX41P_tb);

    D0 = 1'b1; D1 = 1'b0; D2 = 1'b1; D3 = 1'b0;
    A = 1'b0; B = 1'b0; #10;  // sel=0 -> D0
    A = 1'b1; B = 1'b0; #10;  // sel=1 -> D1
    A = 1'b0; B = 1'b1; #10;  // sel=2 -> D2
    A = 1'b1; B = 1'b1; #10;  // sel=3 -> D3

    $display("=====================================================");
    $display(" MUX41P exhaustive functional testbench");
    $display(" (all 64 input combinations; sel = {B,A}, A is the low bit)");
    $display("=====================================================");

    for (combo = 0; combo < 64; combo = combo + 1) begin
      {A, B, D0, D1, D2, D3} = combo[5:0];
      #1;
      expected = ref_z(A, B, D0, D1, D2, D3);
      checks   = checks + 1;
      if (Z !== expected) begin
        errors = errors + 1;
        $display("FAIL: A=%b B=%b D0=%b D1=%b D2=%b D3=%b -> Z=%b expected %b",
                  A, B, D0, D1, D2, D3, Z, expected);
      end
    end

    // ---- named property checks -------------------------------------------

    // 1. Select bit order: A is the low bit, B is the high bit
    D0 = 1'b0; D1 = 1'b1; D2 = 1'b0; D3 = 1'b0;
    A = 1'b1; B = 1'b0; #1;  // {B,A}={0,1}=1 -> D1
    checks = checks + 1;
    if (Z !== D1) begin
      errors = errors + 1;
      $display("FAIL SEL_ORDER_A_LOW: A=1,B=0 -> Z=%b expected D1=%b (A is low bit)", Z, D1);
    end

    // 2. sel=3 reaches D3 independently (no tie, unlike MUX31LP/MUX34P)
    D0 = 1'b0; D1 = 1'b0; D2 = 1'b0; D3 = 1'b1;
    A = 1'b1; B = 1'b1; #1;
    checks = checks + 1;
    if (Z !== 1'b1) begin
      errors = errors + 1;
      $display("FAIL SEL3_IS_D3: sel=3 Z=%b expected D3=1 (independent 4th input)", Z);
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

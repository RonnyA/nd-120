/****************************************************************************
** MUX81 - exhaustive functional testbench                                **
**                                                                         **
** WHAT THIS MODULE ACTUALLY IS                                            **
**   A single 8-to-1 Multiplexer_8. The select bus is built as             **
**   s_selector[0]=A, s_selector[1]=B, s_selector[2]=C, passed as          **
**   sel[2:0], so sel = {C,B,A} with A the LOW bit and C the HIGH bit.     **
**   No output inversion:                                                  **
**       Z = D[ {C,B,A} ]                                                  **
**                                                                         **
** COVERAGE: EXHAUSTIVE. Inputs are A, B, C, D0..D7 = 11 bits, so          **
**   2^11 = 2048 combinations, every one checked against the reference     **
**   model above.                                                          **
**                                                                         **
** VCD: a short documentation sequence is dumped first, then dumping is    **
**   turned off for the 2048-step sweep.                                   **
**                                                                         **
** Run: cd Verilog/Shared/ndlib/sim && iverilog -g2012 -o MUX81_tb.vvp \
**          MUX81_tb.v -y .. -y ../../logisim && vvp MUX81_tb.vvp          **
**                                                                         **
** Last reviewed: 20-AUG-2026                                              **
** Ronny Hansen                                                            **
*****************************************************************************/
`timescale 1ns / 1ps
`default_nettype none

module MUX81_tb;

  reg A, B, C;
  reg D0, D1, D2, D3, D4, D5, D6, D7;
  wire Z;

  integer errors = 0;
  integer checks = 0;
  integer combo;
  reg [7:0] data;
  reg expected;

  MUX81 DUT (
      .A (A), .B(B), .C(C),
      .D0(D0), .D1(D1), .D2(D2), .D3(D3),
      .D4(D4), .D5(D5), .D6(D6), .D7(D7),
      .Z (Z)
  );

  // reference model: sel = {C,B,A}, A is the low bit, C is the high bit
  function ref_z;
    input a, b, c;
    input [7:0] d;
    reg [2:0] sel;
    begin
      sel = {c, b, a};
      ref_z = d[sel];
    end
  endfunction

  initial begin
    $dumpfile("MUX81_tb.vcd");
    $dumpvars(0, MUX81_tb);

    {D7,D6,D5,D4,D3,D2,D1,D0} = 8'b10110010;
    A=0; B=0; C=0; #10;  // sel=0
    A=1; B=0; C=0; #10;  // sel=1
    A=0; B=1; C=0; #10;  // sel=2
    A=1; B=1; C=0; #10;  // sel=3
    A=0; B=0; C=1; #10;  // sel=4
    A=1; B=1; C=1; #10;  // sel=7

    $dumpoff;

    $display("=====================================================");
    $display(" MUX81 exhaustive functional testbench");
    $display(" (all 2048 input combinations; sel = {C,B,A}, A is the low bit)");
    $display("=====================================================");

    for (combo = 0; combo < 2048; combo = combo + 1) begin
      {A, B, C, D7, D6, D5, D4, D3, D2, D1, D0} = combo[10:0];
      #1;
      data = {D7,D6,D5,D4,D3,D2,D1,D0};
      expected = ref_z(A, B, C, data);
      checks = checks + 1;
      if (Z !== expected) begin
        errors = errors + 1;
        if (errors < 20)
          $display("FAIL: A=%b B=%b C=%b D=%08b -> Z=%b expected %b", A, B, C, data, Z, expected);
      end
    end

    // ---- named property checks -------------------------------------------

    // 1. Select bit order: A is the low bit, C is the high bit
    {D7,D6,D5,D4,D3,D2,D1,D0} = 8'b00000100;  // only D2 set
    A=0; B=1; C=0; #1;  // {C,B,A}={0,1,0}=2 -> D2
    checks = checks + 1;
    if (Z !== 1'b1) begin
      errors = errors + 1;
      $display("FAIL SEL_ORDER_A_LOW_C_HIGH: A=0,B=1,C=0 -> Z=%b expected 1 (D2, A low/C high)", Z);
    end

    // 2. Full-scale select: C set alone picks D4
    {D7,D6,D5,D4,D3,D2,D1,D0} = 8'b00010000;  // only D4 set
    A=0; B=0; C=1; #1;
    checks = checks + 1;
    if (Z !== 1'b1) begin
      errors = errors + 1;
      $display("FAIL SEL_C_PICKS_D4: A=0,B=0,C=1 -> Z=%b expected 1 (D4)", Z);
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

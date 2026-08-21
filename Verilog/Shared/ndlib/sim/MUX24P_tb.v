/****************************************************************************
** MUX24P - exhaustive functional testbench                               **
**                                                                         **
** WHAT THIS MODULE ACTUALLY IS                                            **
**   Four INDEPENDENT 2-to-1 multiplexers sharing one select line A, each  **
**   built from a Multiplexer_2 (muxIn_0=D0i, muxIn_1=D1i, sel=A). Unlike  **
**   MUX21L/MUX21LP the outputs are NOT inverted:                          **
**       Zi = A ? D1i : D0i   for i = 0..3                                 **
**                                                                         **
** COVERAGE: EXHAUSTIVE. Inputs are A, D00..D03, D10..D13 = 9 bits, so     **
**   2^9 = 512 combinations, every one checked against the reference       **
**   model above for all four outputs (2048 output comparisons total).    **
**                                                                         **
** VCD: a short documentation sequence is dumped first, then dumping is    **
**   turned off for the 512-step sweep.                                    **
**                                                                         **
** Run: cd Verilog/Shared/ndlib/sim && iverilog -g2012 -o MUX24P_tb.vvp \
**          MUX24P_tb.v -y .. -y ../../logisim && vvp MUX24P_tb.vvp        **
**                                                                         **
** Last reviewed: 20-AUG-2026                                              **
** Ronny Hansen                                                            **
*****************************************************************************/
`timescale 1ns / 1ps
`default_nettype none

module MUX24P_tb;

  reg A;
  reg D00, D01, D02, D03;
  reg D10, D11, D12, D13;
  wire Z0, Z1, Z2, Z3;

  integer errors = 0;
  integer checks = 0;
  integer combo;
  reg [3:0] eZ;

  MUX24P DUT (
      .A  (A),
      .D00(D00), .D01(D01), .D02(D02), .D03(D03),
      .D10(D10), .D11(D11), .D12(D12), .D13(D13),
      .Z0 (Z0), .Z1(Z1), .Z2(Z2), .Z3(Z3)
  );

  // reference model: Zi = A ? D1i : D0i, independently per slice
  function [3:0] ref_z;
    input a;
    input d00, d01, d02, d03;
    input d10, d11, d12, d13;
    begin
      ref_z[0] = a ? d10 : d00;
      ref_z[1] = a ? d11 : d01;
      ref_z[2] = a ? d12 : d02;
      ref_z[3] = a ? d13 : d03;
    end
  endfunction

  initial begin
    $dumpfile("MUX24P_tb.vcd");
    $dumpvars(0, MUX24P_tb);

    // ---- short documentation sequence: walk A with recognisable data ----
    A = 1'b0; {D03, D02, D01, D00} = 4'b0101; {D13, D12, D11, D10} = 4'b1010; #10;
    A = 1'b1; #10;
    A = 1'b0; {D03, D02, D01, D00} = 4'b1111; {D13, D12, D11, D10} = 4'b0000; #10;
    A = 1'b1; #10;
    A = 1'b0; {D03, D02, D01, D00} = 4'b0000; {D13, D12, D11, D10} = 4'b1111; #10;
    A = 1'b1; #10;

    $dumpoff;

    $display("=====================================================");
    $display(" MUX24P exhaustive functional testbench");
    $display(" (all 512 input combinations)");
    $display("=====================================================");

    for (combo = 0; combo < 512; combo = combo + 1) begin
      {A, D13, D12, D11, D10, D03, D02, D01, D00} = combo[8:0];
      #1;
      eZ = ref_z(A, D00, D01, D02, D03, D10, D11, D12, D13);
      checks = checks + 4;
      if (Z0 !== eZ[0]) begin
        errors = errors + 1;
        $display("FAIL Z0: A=%b D00=%b D10=%b -> Z0=%b expected %b", A, D00, D10, Z0, eZ[0]);
      end
      if (Z1 !== eZ[1]) begin
        errors = errors + 1;
        $display("FAIL Z1: A=%b D01=%b D11=%b -> Z1=%b expected %b", A, D01, D11, Z1, eZ[1]);
      end
      if (Z2 !== eZ[2]) begin
        errors = errors + 1;
        $display("FAIL Z2: A=%b D02=%b D12=%b -> Z2=%b expected %b", A, D02, D12, Z2, eZ[2]);
      end
      if (Z3 !== eZ[3]) begin
        errors = errors + 1;
        $display("FAIL Z3: A=%b D03=%b D13=%b -> Z3=%b expected %b", A, D03, D13, Z3, eZ[3]);
      end
    end

    // ---- named property checks -------------------------------------------

    // 1. Slices are independent: changing slice 1's data must not move slice 0's output
    A = 1'b0; D00 = 1'b1; D01 = 1'b0; D02 = 1'b0; D03 = 1'b0;
    D10 = 1'b0; D11 = 1'b0; D12 = 1'b0; D13 = 1'b0; #1;
    checks = checks + 1;
    if (Z0 !== 1'b1) begin
      errors = errors + 1;
      $display("FAIL SLICE_INDEP_BASELINE: Z0=%b expected 1 before slice-1 change", Z0);
    end
    D01 = 1'b1; #1;
    checks = checks + 1;
    if (Z0 !== 1'b1) begin
      errors = errors + 1;
      $display("FAIL SLICE_INDEP: Z0=%b changed when D01 changed, must stay 1", Z0);
    end

    // 2. A selects the D1x bank when set
    A = 1'b1; D10 = 1'b1; D11 = 1'b1; D12 = 1'b1; D13 = 1'b1;
    D00 = 1'b0; D01 = 1'b0; D02 = 1'b0; D03 = 1'b0; #1;
    checks = checks + 1;
    if ({Z3, Z2, Z1, Z0} !== 4'b1111) begin
      errors = errors + 1;
      $display("FAIL SEL_D1_BANK: Z=%b%b%b%b expected 1111", Z3, Z2, Z1, Z0);
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

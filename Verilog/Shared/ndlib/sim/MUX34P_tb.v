/****************************************************************************
** MUX34P - exhaustive functional testbench                               **
**                                                                         **
** WHAT THIS MODULE ACTUALLY IS                                            **
**   FOUR independent 4-to-1 Multiplexer_4 slices sharing one 2-bit        **
**   select bus, built as s_selector[0]=A, s_selector[1]=B, so             **
**   sel = {B,A} with A the LOW bit. Each slice i (i=0..3) ties            **
**   muxIn_3 to the SAME wire as muxIn_2 (both = D2i):                     **
**       sel=0 (B=0,A=0) -> Zi = D0i                                       **
**       sel=1 (B=0,A=1) -> Zi = D1i                                       **
**       sel=2 (B=1,A=0) -> Zi = D2i                                       **
**       sel=3 (B=1,A=1) -> Zi = D2i   (tied to the sel=2 input - design   **
**                                       intent, checked explicitly below) **
**   Unlike MUX31LP (same select-bit pattern, same tie), MUX34P does NOT   **
**   invert its outputs - Z0..Z3 come straight from the mux, no ZN/~.      **
**                                                                         **
** COVERAGE: EXHAUSTIVE. Inputs are A, B, D00..D03, D10..D13, D20..D23 =   **
**   14 bits, so 2^14 = 16384 combinations, every one checked against the  **
**   reference model above for all four outputs (65536 output             **
**   comparisons total).                                                   **
**                                                                         **
** VCD: a short documentation sequence is dumped first, then dumping is    **
**   turned off for the 16384-step sweep.                                  **
**                                                                         **
** Run: cd Verilog/Shared/ndlib/sim && iverilog -g2012 -o MUX34P_tb.vvp \
**          MUX34P_tb.v -y .. -y ../../logisim && vvp MUX34P_tb.vvp        **
**                                                                         **
** Last reviewed: 20-AUG-2026                                              **
** Ronny Hansen                                                            **
*****************************************************************************/
`timescale 1ns / 1ps
`default_nettype none

module MUX34P_tb;

  reg A, B;
  reg D00, D01, D02, D03;
  reg D10, D11, D12, D13;
  reg D20, D21, D22, D23;
  wire Z0, Z1, Z2, Z3;

  integer errors = 0;
  integer checks = 0;
  integer combo;
  reg [3:0] eZ;

  MUX34P DUT (
      .A  (A), .B(B),
      .D00(D00), .D01(D01), .D02(D02), .D03(D03),
      .D10(D10), .D11(D11), .D12(D12), .D13(D13),
      .D20(D20), .D21(D21), .D22(D22), .D23(D23),
      .Z0 (Z0), .Z1(Z1), .Z2(Z2), .Z3(Z3)
  );

  // reference model: sel = {B,A}, A is the low bit; sel==3 ties to sel==2 (D2i)
  function [3:0] ref_z;
    input a, b;
    input d00, d01, d02, d03;
    input d10, d11, d12, d13;
    input d20, d21, d22, d23;
    reg [1:0] sel;
    begin
      sel = {b, a};
      case (sel)
        2'd0: ref_z = {d03, d02, d01, d00};
        2'd1: ref_z = {d13, d12, d11, d10};
        2'd2: ref_z = {d23, d22, d21, d20};
        2'd3: ref_z = {d23, d22, d21, d20};
      endcase
    end
  endfunction

  initial begin
    $dumpfile("MUX34P_tb.vcd");
    $dumpvars(0, MUX34P_tb);

    // ---- short documentation sequence: walk {B,A} with recognisable data --
    {D03, D02, D01, D00} = 4'b0001;
    {D13, D12, D11, D10} = 4'b0010;
    {D23, D22, D21, D20} = 4'b0100;
    A = 1'b0; B = 1'b0; #10;  // sel=0 -> D0x
    A = 1'b1; B = 1'b0; #10;  // sel=1 -> D1x
    A = 1'b0; B = 1'b1; #10;  // sel=2 -> D2x
    A = 1'b1; B = 1'b1; #10;  // sel=3 -> D2x (tied)
    {D23, D22, D21, D20} = 4'b1011; #10;  // tie tracks D2x

    $dumpoff;

    $display("=====================================================");
    $display(" MUX34P exhaustive functional testbench");
    $display(" (all 16384 input combinations; sel = {B,A}, A is the low bit)");
    $display("=====================================================");

    for (combo = 0; combo < 16384; combo = combo + 1) begin
      {A, B, D23, D22, D21, D20, D13, D12, D11, D10, D03, D02, D01, D00} = combo[13:0];
      #1;
      eZ = ref_z(A, B, D00, D01, D02, D03, D10, D11, D12, D13, D20, D21, D22, D23);
      checks = checks + 4;
      if (Z0 !== eZ[0]) begin
        errors = errors + 1;
        if (errors < 20)
          $display("FAIL Z0: A=%b B=%b -> Z0=%b expected %b", A, B, Z0, eZ[0]);
      end
      if (Z1 !== eZ[1]) begin
        errors = errors + 1;
        if (errors < 20)
          $display("FAIL Z1: A=%b B=%b -> Z1=%b expected %b", A, B, Z1, eZ[1]);
      end
      if (Z2 !== eZ[2]) begin
        errors = errors + 1;
        if (errors < 20)
          $display("FAIL Z2: A=%b B=%b -> Z2=%b expected %b", A, B, Z2, eZ[2]);
      end
      if (Z3 !== eZ[3]) begin
        errors = errors + 1;
        if (errors < 20)
          $display("FAIL Z3: A=%b B=%b -> Z3=%b expected %b", A, B, Z3, eZ[3]);
      end
    end

    // ---- named property checks -------------------------------------------

    // 1. THE TIE: sel=3 must return the same as sel=2, per slice
    D00=0; D01=0; D02=0; D03=0;
    D10=0; D11=0; D12=0; D13=0;
    D20=1; D21=0; D22=1; D23=0;
    A = 1'b0; B = 1'b1; #1;  // sel=2
    checks = checks + 1;
    if ({Z3,Z2,Z1,Z0} !== {D23,D22,D21,D20}) begin
      errors = errors + 1;
      $display("FAIL SEL2_READS_D2X: Z=%b%b%b%b expected %b%b%b%b", Z3,Z2,Z1,Z0, D23,D22,D21,D20);
    end
    A = 1'b1; B = 1'b1; #1;  // sel=3
    checks = checks + 1;
    if ({Z3,Z2,Z1,Z0} !== {D23,D22,D21,D20}) begin
      errors = errors + 1;
      $display("FAIL SEL3_TIED_TO_SEL2: sel=3 Z=%b%b%b%b must equal sel=2 reading (%b%b%b%b)",
                Z3,Z2,Z1,Z0, D23,D22,D21,D20);
    end

    // 2. SLICE INDEPENDENCE: changing slice 1's data must not move slice 0's output
    A = 1'b0; B = 1'b0;  // sel=0 -> D0x
    D00 = 1'b1; D01 = 1'b0; D02 = 1'b0; D03 = 1'b0; #1;
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

    // 3. Select bit order: A is the low bit, B is the high bit
    D00=0; D01=0; D02=0; D03=0;
    D10=1; D11=1; D12=1; D13=1;
    A = 1'b1; B = 1'b0; #1;  // {B,A}={0,1}=1 -> D1x
    checks = checks + 1;
    if ({Z3,Z2,Z1,Z0} !== {D13,D12,D11,D10}) begin
      errors = errors + 1;
      $display("FAIL SEL_ORDER_A_LOW: A=1,B=0 -> Z=%b%b%b%b expected D1x=%b%b%b%b (A is low bit)",
                Z3,Z2,Z1,Z0, D13,D12,D11,D10);
    end

    // 4. No output inversion (unlike MUX31LP)
    D00=1; D01=1; D02=1; D03=1;
    A = 1'b0; B = 1'b0; #1;  // sel=0 -> D0x = 1111
    checks = checks + 1;
    if ({Z3,Z2,Z1,Z0} !== 4'b1111) begin
      errors = errors + 1;
      $display("FAIL NOT_INVERTED: Z=%b%b%b%b expected 1111 (D0x all 1, no inversion)", Z3,Z2,Z1,Z0);
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

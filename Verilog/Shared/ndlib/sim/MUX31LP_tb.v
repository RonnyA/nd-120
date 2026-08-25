/****************************************************************************
** MUX31LP - exhaustive functional testbench                              **
**                                                                         **
** WHAT THIS MODULE ACTUALLY IS                                            **
**   A 4-to-1 Multiplexer_4 with muxIn_3 tied to the SAME wire as muxIn_2  **
**   (both = D2), which is how a 4-input primitive becomes a 3-data-input  **
**   part. The select bus is built as s_select[0]=A, s_select[1]=B, so     **
**   sel = {B,A} with A the LOW bit (NOT the port order A,B read as a      **
**   number). Output is inverted:                                          **
**       sel=0 (B=0,A=0) -> ZN = ~D0                                       **
**       sel=1 (B=0,A=1) -> ZN = ~D1                                       **
**       sel=2 (B=1,A=0) -> ZN = ~D2                                       **
**       sel=3 (B=1,A=1) -> ZN = ~D2   (tied to the sel=2 input - design   **
**                                       intent, not a bug, and checked    **
**                                       explicitly below)                 **
**                                                                         **
** COVERAGE: EXHAUSTIVE. Inputs are A, B, D0, D1, D2 = 5 bits, so 2^5 = 32 **
**   combinations, every one checked against the reference model above.    **
**                                                                         **
** VCD: a short documentation sequence is dumped first, then dumping is    **
**   turned off for the 32-step sweep.                                     **
**                                                                         **
** Run: cd Verilog/Shared/ndlib/sim && iverilog -g2012 -o MUX31LP_tb.vvp \
**          MUX31LP_tb.v -y .. -y ../../logisim && vvp MUX31LP_tb.vvp      **
**                                                                         **
** Last reviewed: 20-AUG-2026                                              **
** Ronny Hansen                                                            **
*****************************************************************************/
`timescale 1ns / 1ps
`default_nettype none

module MUX31LP_tb;

  reg A, B, D0, D1, D2;
  wire ZN;

  integer errors = 0;
  integer checks = 0;
  integer combo;
  reg     expected;

  MUX31LP DUT (
      .A (A),
      .B (B),
      .D0(D0),
      .D1(D1),
      .D2(D2),
      .ZN(ZN)
  );

  // reference model: sel = {B,A}, A is the low bit; sel==3 ties to D2 (same as sel==2)
  function ref_zn;
    input a, b, d0, d1, d2;
    reg [1:0] sel;
    begin
      sel = {b, a};
      case (sel)
        2'd0: ref_zn = ~d0;
        2'd1: ref_zn = ~d1;
        2'd2: ref_zn = ~d2;
        2'd3: ref_zn = ~d2;
      endcase
    end
  endfunction

  initial begin
    $dumpfile("MUX31LP_tb.vcd");
    $dumpvars(0, MUX31LP_tb);

    // ---- short documentation sequence: walk {B,A} with recognisable data --
    D0 = 1'b0; D1 = 1'b1; D2 = 1'b0;
    A = 1'b0; B = 1'b0; #10;  // sel=0 -> D0
    A = 1'b1; B = 1'b0; #10;  // sel=1 -> D1
    A = 1'b0; B = 1'b1; #10;  // sel=2 -> D2
    A = 1'b1; B = 1'b1; #10;  // sel=3 -> D2 (tied)
    D2 = 1'b1; #10;           // show the tie tracking D2
    A = 1'b0; B = 1'b1; #10;  // sel=2 -> D2

    $dumpoff;

    $display("=====================================================");
    $display(" MUX31LP exhaustive functional testbench");
    $display(" (all 32 input combinations; sel = {B,A}, A is the low bit)");
    $display("=====================================================");

    for (combo = 0; combo < 32; combo = combo + 1) begin
      {A, B, D0, D1, D2} = combo[4:0];
      #1;
      expected = ref_zn(A, B, D0, D1, D2);
      checks   = checks + 1;
      if (ZN !== expected) begin
        errors = errors + 1;
        $display("FAIL: A=%b B=%b D0=%b D1=%b D2=%b -> ZN=%b expected %b",
                  A, B, D0, D1, D2, ZN, expected);
      end
    end

    // ---- named property checks -------------------------------------------

    // 1. THE TIE: sel=3 must return the same thing as sel=2 (both read D2)
    D0 = 1'b1; D1 = 1'b1; D2 = 1'b0;
    A = 1'b0; B = 1'b1; #1;  // sel=2
    checks = checks + 1;
    if (ZN !== ~D2) begin
      errors = errors + 1;
      $display("FAIL SEL2_READS_D2: ZN=%b expected %b", ZN, ~D2);
    end
    A = 1'b1; B = 1'b1; #1;  // sel=3
    checks = checks + 1;
    if (ZN !== ~D2) begin
      errors = errors + 1;
      $display("FAIL SEL3_TIED_TO_SEL2: sel=3 ZN=%b must equal sel=2 reading (%b)", ZN, ~D2);
    end
    D2 = 1'b1; #1;  // still sel=3, D2 flips - must track
    checks = checks + 1;
    if (ZN !== ~D2) begin
      errors = errors + 1;
      $display("FAIL SEL3_TRACKS_D2: sel=3 ZN=%b must track D2=%b", ZN, D2);
    end

    // 2. Select bit order: A is the low bit, B is the high bit
    D0 = 1'b0; D1 = 1'b1; D2 = 1'b0;
    A = 1'b1; B = 1'b0; #1;  // {B,A}={0,1}=1 -> D1
    checks = checks + 1;
    if (ZN !== ~D1) begin
      errors = errors + 1;
      $display("FAIL SEL_ORDER_A_LOW: A=1,B=0 -> ZN=%b expected NOT D1=%b (A is low bit)", ZN, ~D1);
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

/****************************************************************************
** RMUX_Gates - exhaustive functional testbench                           **
**                                                                         **
** WHAT THIS MODULE ACTUALLY IS                                            **
**   Two AND_GATE instances feeding one NOR_GATE, all three instantiated   **
**   with BubblesMask=2'b00. In AND_GATE/NOR_GATE, BubblesMask bit0/bit1   **
**   invert input1/input2 respectively when set; 2'b00 means NEITHER      **
**   input is inverted on any of the three gates - the mask parameter is  **
**   present but unused here, so the plain gate functions apply:          **
**       GATES_1: gates1 = A & RA                                          **
**       GATES_2: gates2 = D & RD                                          **
**       GATES_3: RN    = ~(gates1 | gates2)                               **
**   giving the overall boolean function                                   **
**       RN = NOT( (A AND RA) OR (D AND RD) )                              **
**                                                                         **
** COVERAGE: EXHAUSTIVE. Inputs are A, D, RA, RD = 4 bits, so 2^4 = 16     **
**   combinations, every one checked against the reference model above.    **
**                                                                         **
** VCD: 16 combinations, dumped in full.                                   **
**                                                                         **
** Run: cd Verilog/Shared/ndlib/sim && iverilog -g2012 -o RMUX_Gates_tb.vvp \
**          RMUX_Gates_tb.v -y .. -y ../../logisim && vvp RMUX_Gates_tb.vvp **
**                                                                         **
** Last reviewed: 20-AUG-2026                                              **
** Ronny Hansen                                                            **
*****************************************************************************/
`timescale 1ns / 1ps
`default_nettype none

module RMUX_Gates_tb;

  reg A, D, RA, RD;
  wire RN;

  integer errors = 0;
  integer checks = 0;
  integer combo;
  reg expected;

  RMUX_Gates DUT (
      .A (A), .D(D), .RA(RA), .RD(RD),
      .RN(RN)
  );

  // reference model: RN = NOT( (A AND RA) OR (D AND RD) )
  function ref_rn;
    input a, d, ra, rd;
    begin
      ref_rn = ~((a & ra) | (d & rd));
    end
  endfunction

  initial begin
    $dumpfile("RMUX_Gates_tb.vcd");
    $dumpvars(0, RMUX_Gates_tb);

    A=0; RA=0; D=0; RD=0; #10;  // both terms 0 -> RN=1
    A=1; RA=1; D=0; RD=0; #10;  // first term 1 -> RN=0
    A=0; RA=0; D=1; RD=1; #10;  // second term 1 -> RN=0
    A=1; RA=1; D=1; RD=1; #10;  // both terms 1 -> RN=0
    A=1; RA=0; D=1; RD=0; #10;  // RA/RD gating both off -> RN=1

    $display("=====================================================");
    $display(" RMUX_Gates exhaustive functional testbench");
    $display(" (all 16 input combinations)");
    $display("=====================================================");

    for (combo = 0; combo < 16; combo = combo + 1) begin
      {A, D, RA, RD} = combo[3:0];
      #1;
      expected = ref_rn(A, D, RA, RD);
      checks   = checks + 1;
      if (RN !== expected) begin
        errors = errors + 1;
        $display("FAIL: A=%b D=%b RA=%b RD=%b -> RN=%b expected %b", A, D, RA, RD, RN, expected);
      end
    end

    // ---- named property checks -------------------------------------------

    // 1. RA gates A: A alone (RA=0) must not pull RN low
    A = 1'b1; RA = 1'b0; D = 1'b0; RD = 1'b0; #1;
    checks = checks + 1;
    if (RN !== 1'b1) begin
      errors = errors + 1;
      $display("FAIL RA_GATES_A: A=1 RA=0 -> RN=%b expected 1 (A must be gated off)", RN);
    end

    // 2. RD gates D: D alone (RD=0) must not pull RN low
    A = 1'b0; RA = 1'b0; D = 1'b1; RD = 1'b0; #1;
    checks = checks + 1;
    if (RN !== 1'b1) begin
      errors = errors + 1;
      $display("FAIL RD_GATES_D: D=1 RD=0 -> RN=%b expected 1 (D must be gated off)", RN);
    end

    // 3. Either qualified term alone is enough to pull RN low (OR, not AND)
    A = 1'b1; RA = 1'b1; D = 1'b0; RD = 1'b0; #1;
    checks = checks + 1;
    if (RN !== 1'b0) begin
      errors = errors + 1;
      $display("FAIL A_TERM_ALONE_PULLS_LOW: A&RA=1 alone -> RN=%b expected 0", RN);
    end
    A = 1'b0; RA = 1'b0; D = 1'b1; RD = 1'b1; #1;
    checks = checks + 1;
    if (RN !== 1'b0) begin
      errors = errors + 1;
      $display("FAIL D_TERM_ALONE_PULLS_LOW: D&RD=1 alone -> RN=%b expected 0", RN);
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

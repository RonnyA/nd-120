/****************************************************************************
** TTL_74241 - exhaustive functional testbench                             **
**                                                                         **
** Quad/quad buffer with 3-state outputs. Read from                        **
** Verilog/Shared/support/TTL_74241.v: this RTL is ASYMMETRIC between      **
** its two halves -                                                        **
**   Y1[3:0] = G1_n ? 4'b0 : A1[3:0];   (Y1 enable is ACTIVE LOW)          **
**   Y2[3:0] = G2   ? A2[3:0] : 4'b0;   (Y2 enable is ACTIVE HIGH)         **
** This matches the real SN74ABT241A datasheet (1G is active low, 2G is    **
** active high) - no disagreement there. The one place this RTL departs    **
** from the datasheet is the disabled state: a real 74241 goes high-Z,     **
** this RTL drives 4'b0. That is the repo-wide FPGA convention (buses are  **
** OR-ed together, so a disabled driver must contribute zero, not z) and   **
** is checked explicitly below.                                            **
**                                                                         **
** COVERAGE: exhaustive over A1[3:0] x A2[3:0] x G1_n x G2 = 1024          **
** combinations, checked against a reference model built from the RTL.     **
**                                                                         **
** Also checked: disabled-state = 4'b0 for both halves, for both an all-1s **
** and an all-0s data pattern; and that the two halves are independent.    **
**                                                                         **
** Run: cd Verilog/Shared/support/sim && make test-74241                  **
**                                                                         **
** Last reviewed: 20-AUG-2026                                              **
** Ronny Hansen                                                            **
*****************************************************************************/
`timescale 1ns / 1ps
`default_nettype none

module TTL_74241_tb;

  reg  [3:0] A1, A2;
  reg        G1_n, G2;
  wire [3:0] Y1, Y2;

  integer errors = 0;
  integer checks = 0;

  TTL_74241 DUT (
      .A1(A1), .Y1(Y1), .G1_n(G1_n),
      .A2(A2), .Y2(Y2), .G2(G2)
  );

  function [3:0] ref_y1;
    input [3:0] a1;
    input g1_n;
    begin
      ref_y1 = g1_n ? 4'b0 : a1;
    end
  endfunction

  function [3:0] ref_y2;
    input [3:0] a2;
    input g2;
    begin
      ref_y2 = g2 ? a2 : 4'b0;
    end
  endfunction

  integer ia1, ia2, ig1, ig2;
  reg [3:0] ey1, ey2;

  initial begin
    $dumpfile("TTL_74241_tb.vcd");
    $dumpvars(0, TTL_74241_tb);

    $display("=====================================================");
    $display(" TTL_74241 exhaustive functional testbench");
    $display(" (all 1024 input combinations)");
    $display("=====================================================");

    // ---- short documentation sequence -------------------------------------
    A1 = 4'h0; A2 = 4'h0; G1_n = 1'b1; G2 = 1'b0; #10; // both halves disabled
    G1_n = 1'b0; A1 = 4'hA; #10;                       // Y1 half enabled, passes A
    A1 = 4'h5; #10;                                     // Y1 follows A1
    G1_n = 1'b1; #10;                                   // Y1 disabled -> 0
    G2 = 1'b1; A2 = 4'hC; #10;                          // Y2 half enabled, passes A
    A2 = 4'h3; #10;                                     // Y2 follows A2
    G2 = 1'b0; #10;                                     // Y2 disabled -> 0
    G1_n = 1'b0; A1 = 4'hF; G2 = 1'b1; A2 = 4'h0; #10;  // both enabled, different data
    G1_n = 1'b1; G2 = 1'b0; #10;                        // both disabled, end of sequence

    $dumpoff;

    // ---- exhaustive sweep --------------------------------------------------
    for (ig1 = 0; ig1 < 2; ig1 = ig1 + 1)
    for (ig2 = 0; ig2 < 2; ig2 = ig2 + 1)
    for (ia1 = 0; ia1 < 16; ia1 = ia1 + 1)
    for (ia2 = 0; ia2 < 16; ia2 = ia2 + 1) begin
      G1_n = ig1[0]; G2 = ig2[0];
      A1 = ia1[3:0]; A2 = ia2[3:0];
      #1;
      ey1 = ref_y1(A1, G1_n);
      ey2 = ref_y2(A2, G2);
      checks = checks + 2;
      if (Y1 !== ey1) begin
        errors = errors + 1;
        if (errors < 10)
          $display("FAIL Y1: A1=%h G1_n=%b -> Y1=%h expected %h", A1, G1_n, Y1, ey1);
      end
      if (Y2 !== ey2) begin
        errors = errors + 1;
        if (errors < 10)
          $display("FAIL Y2: A2=%h G2=%b -> Y2=%h expected %h", A2, G2, Y2, ey2);
      end
    end

    // ---- named property checks --------------------------------------------

    // Y1 disabled must read 0, for BOTH an all-ones and an all-zeros pattern
    G1_n = 1'b1; A1 = 4'hF; #1;
    checks = checks + 1;
    if (Y1 !== 4'b0) begin
      errors = errors + 1;
      $display("FAIL Y1_DISABLED_ONES: A1=FF Y1=%h, must be 0", Y1);
    end
    G1_n = 1'b1; A1 = 4'h0; #1;
    checks = checks + 1;
    if (Y1 !== 4'b0) begin
      errors = errors + 1;
      $display("FAIL Y1_DISABLED_ZEROS: A1=0 Y1=%h, must be 0", Y1);
    end

    // Y2 disabled (G2=0) must read 0, for BOTH data patterns
    G2 = 1'b0; A2 = 4'hF; #1;
    checks = checks + 1;
    if (Y2 !== 4'b0) begin
      errors = errors + 1;
      $display("FAIL Y2_DISABLED_ONES: A2=FF Y2=%h, must be 0", Y2);
    end
    G2 = 1'b0; A2 = 4'h0; #1;
    checks = checks + 1;
    if (Y2 !== 4'b0) begin
      errors = errors + 1;
      $display("FAIL Y2_DISABLED_ZEROS: A2=0 Y2=%h, must be 0", Y2);
    end

    // Independence: changing half 2's inputs must not move half 1's output
    G1_n = 1'b0; A1 = 4'h7; #1;
    ey1 = Y1;
    G2 = 1'b1; A2 = 4'h0; #1;
    G2 = 1'b0; A2 = 4'hF; #1;
    checks = checks + 1;
    if (Y1 !== ey1) begin
      errors = errors + 1;
      $display("FAIL INDEPENDENCE_1: Y1 moved (%h -> %h) when only half 2 changed", ey1, Y1);
    end
    // Mirror: changing half 1's inputs must not move half 2's output
    G2 = 1'b1; A2 = 4'h9; #1;
    ey2 = Y2;
    G1_n = 1'b1; A1 = 4'h0; #1;
    G1_n = 1'b0; A1 = 4'hF; #1;
    checks = checks + 1;
    if (Y2 !== ey2) begin
      errors = errors + 1;
      $display("FAIL INDEPENDENCE_2: Y2 moved (%h -> %h) when only half 1 changed", ey2, Y2);
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

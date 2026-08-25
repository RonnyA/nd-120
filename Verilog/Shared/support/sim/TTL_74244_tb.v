/****************************************************************************
** TTL_74244 - exhaustive functional testbench                             **
**                                                                         **
** Octal buffer/line driver with 3-state outputs, organized as two 4-bit   **
** halves, BOTH with active-low output enables. Read from                  **
** Verilog/Shared/support/TTL_74244.v:                                     **
**   Y1 = G1_n ? 4'b0 : A1;                                                 **
**   Y2 = G2_n ? 4'b0 : A2;                                                 **
** Matches the real 74LS244 enable polarity. The one departure from the    **
** real datasheet is the disabled state: real hardware goes high-Z, this   **
** RTL drives 4'b0 - the repo-wide FPGA convention (buses are OR-ed        **
** together, so a disabled driver must contribute zero, not z).            **
**                                                                         **
** COVERAGE: exhaustive over A1[3:0] x A2[3:0] x G1_n x G2_n = 1024         **
** combinations, checked against a reference model built from the RTL.     **
**                                                                         **
** Also checked: disabled-state = 4'b0 for both halves, for both an all-1s **
** and an all-0s data pattern; and that the two halves are independent.    **
**                                                                         **
** Run: cd Verilog/Shared/support/sim && make test-74244                  **
**                                                                         **
** Last reviewed: 20-AUG-2026                                              **
** Ronny Hansen                                                            **
*****************************************************************************/
`timescale 1ns / 1ps
`default_nettype none

module TTL_74244_tb;

  reg  [3:0] A1, A2;
  reg        G1_n, G2_n;
  wire [3:0] Y1, Y2;

  integer errors = 0;
  integer checks = 0;

  TTL_74244 DUT (
      .A1(A1), .G1_n(G1_n), .Y1(Y1),
      .A2(A2), .G2_n(G2_n), .Y2(Y2)
  );

  function [3:0] ref_y;
    input [3:0] a;
    input g_n;
    begin
      ref_y = g_n ? 4'b0 : a;
    end
  endfunction

  integer ia1, ia2, ig1, ig2;
  reg [3:0] ey1, ey2;

  initial begin
    $dumpfile("TTL_74244_tb.vcd");
    $dumpvars(0, TTL_74244_tb);

    $display("=====================================================");
    $display(" TTL_74244 exhaustive functional testbench");
    $display(" (all 1024 input combinations)");
    $display("=====================================================");

    // ---- short documentation sequence -------------------------------------
    A1 = 4'h0; A2 = 4'h0; G1_n = 1'b1; G2_n = 1'b1; #10; // both halves disabled
    G1_n = 1'b0; A1 = 4'hA; #10;                          // Y1 half enabled, passes A
    A1 = 4'h5; #10;                                        // Y1 follows A1
    G1_n = 1'b1; #10;                                      // Y1 disabled -> 0
    G2_n = 1'b0; A2 = 4'hC; #10;                           // Y2 half enabled, passes A
    A2 = 4'h3; #10;                                        // Y2 follows A2
    G2_n = 1'b1; #10;                                      // Y2 disabled -> 0
    G1_n = 1'b0; A1 = 4'hF; G2_n = 1'b0; A2 = 4'h0; #10;  // both enabled, different data
    G1_n = 1'b1; G2_n = 1'b1; #10;                         // both disabled, end of sequence

    $dumpoff;

    // ---- exhaustive sweep --------------------------------------------------
    for (ig1 = 0; ig1 < 2; ig1 = ig1 + 1)
    for (ig2 = 0; ig2 < 2; ig2 = ig2 + 1)
    for (ia1 = 0; ia1 < 16; ia1 = ia1 + 1)
    for (ia2 = 0; ia2 < 16; ia2 = ia2 + 1) begin
      G1_n = ig1[0]; G2_n = ig2[0];
      A1 = ia1[3:0]; A2 = ia2[3:0];
      #1;
      ey1 = ref_y(A1, G1_n);
      ey2 = ref_y(A2, G2_n);
      checks = checks + 2;
      if (Y1 !== ey1) begin
        errors = errors + 1;
        if (errors < 10)
          $display("FAIL Y1: A1=%h G1_n=%b -> Y1=%h expected %h", A1, G1_n, Y1, ey1);
      end
      if (Y2 !== ey2) begin
        errors = errors + 1;
        if (errors < 10)
          $display("FAIL Y2: A2=%h G2_n=%b -> Y2=%h expected %h", A2, G2_n, Y2, ey2);
      end
    end

    // ---- named property checks --------------------------------------------

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

    G2_n = 1'b1; A2 = 4'hF; #1;
    checks = checks + 1;
    if (Y2 !== 4'b0) begin
      errors = errors + 1;
      $display("FAIL Y2_DISABLED_ONES: A2=FF Y2=%h, must be 0", Y2);
    end
    G2_n = 1'b1; A2 = 4'h0; #1;
    checks = checks + 1;
    if (Y2 !== 4'b0) begin
      errors = errors + 1;
      $display("FAIL Y2_DISABLED_ZEROS: A2=0 Y2=%h, must be 0", Y2);
    end

    // Independence between halves
    G1_n = 1'b0; A1 = 4'h7; #1;
    ey1 = Y1;
    G2_n = 1'b0; A2 = 4'h0; #1;
    G2_n = 1'b1; A2 = 4'hF; #1;
    checks = checks + 1;
    if (Y1 !== ey1) begin
      errors = errors + 1;
      $display("FAIL INDEPENDENCE_1: Y1 moved (%h -> %h) when only half 2 changed", ey1, Y1);
    end
    G2_n = 1'b0; A2 = 4'h9; #1;
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

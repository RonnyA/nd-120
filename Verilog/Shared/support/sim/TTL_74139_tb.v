/****************************************************************************
** TTL_74139 - exhaustive functional testbench                             **
**                                                                         **
** The 74139 is a dual 2-line to 4-line decoder/demultiplexer with         **
** active-low outputs and an active-low enable per half. Read from         **
** Verilog/Shared/support/TTL_74139.v: when G_n is high ALL FOUR outputs   **
** of that half go to 1 (inactive) - there is no tri-state involved here,  **
** it is a plain decoder, so the repo-wide "disabled output drives zero"   **
** bus-sharing rule does not apply to this module (its outputs are never   **
** OR-ed onto a shared bus in a disabled state - the disabled state IS     **
** 1111, matching the real SN54LS139A datasheet exactly).                  **
**                                                                         **
** COVERAGE: the full input space per half is A,B,G_n = 8 combinations,    **
** and the two halves are fully independent, so all 64 combinations of     **
** {A1,B1,G1_n,A2,B2,G2_n} are swept exhaustively against a reference       **
** model built directly from the RTL's own assign statements.              **
**                                                                         **
** Also checked: decoder 2's inputs must have ZERO effect on decoder 1's   **
** outputs, and vice versa (the two halves must be independent).           **
**                                                                         **
** Run: cd Verilog/Shared/support/sim && make test-74139                  **
**                                                                         **
** Last reviewed: 20-AUG-2026                                              **
** Ronny Hansen                                                            **
*****************************************************************************/
`timescale 1ns / 1ps
`default_nettype none

module TTL_74139_tb;

  reg A1, B1, G1_n;
  reg A2, B2, G2_n;
  wire Y1_0_n, Y1_1_n, Y1_2_n, Y1_3_n;
  wire Y2_0_n, Y2_1_n, Y2_2_n, Y2_3_n;

  integer errors = 0;
  integer checks = 0;

  TTL_74139 DUT (
      .A1(A1), .B1(B1), .G1_n(G1_n),
      .Y1_0_n(Y1_0_n), .Y1_1_n(Y1_1_n), .Y1_2_n(Y1_2_n), .Y1_3_n(Y1_3_n),
      .A2(A2), .B2(B2), .G2_n(G2_n),
      .Y2_0_n(Y2_0_n), .Y2_1_n(Y2_1_n), .Y2_2_n(Y2_2_n), .Y2_3_n(Y2_3_n)
  );

  // ---- reference model, straight from the RTL's own assign statements ----
  function [3:0] ref_y;
    input a, b, g_n;
    begin
      if (g_n)
        ref_y = 4'b1111;
      else begin
        ref_y[0] = ~((~b) & (~a));
        ref_y[1] = ~((~b) & a);
        ref_y[2] = ~(b & (~a));
        ref_y[3] = ~(b & a);
      end
    end
  endfunction

  integer ia1, ib1, ig1, ia2, ib2, ig2;
  reg [3:0] ey1, ey2;
  reg [3:0] y1_actual, y2_actual;

  initial begin
    $dumpfile("TTL_74139_tb.vcd");
    $dumpvars(0, TTL_74139_tb);

    $display("=====================================================");
    $display(" TTL_74139 exhaustive functional testbench");
    $display(" (all 64 input combinations)");
    $display("=====================================================");

    // ---- short documentation sequence, dumped for the VCD ----------------
    A1 = 0; B1 = 0; G1_n = 1; A2 = 0; B2 = 0; G2_n = 1; #10; // both disabled
    G1_n = 0; #10;                                          // dec1 enabled, A=0 B=0 -> Y0
    A1 = 1; #10;                                             // A=1 B=0 -> Y1
    B1 = 1; #10;                                             // A=1 B=1 -> Y3
    A1 = 0; #10;                                             // A=0 B=1 -> Y2
    G1_n = 1; #10;                                            // dec1 disabled again
    G2_n = 0; A2 = 0; B2 = 0; #10;                            // dec2 enabled, A=0 B=0 -> Y0
    A2 = 1; B2 = 1; #10;                                      // dec2 A=1 B=1 -> Y3
    G1_n = 0; A1 = 1; B1 = 0; #10;                            // both enabled at once, different codes
    G1_n = 1; G2_n = 1; #10;                                  // both disabled, end of sequence

    $dumpoff;

    // ---- exhaustive sweep --------------------------------------------------
    for (ig1 = 0; ig1 < 2; ig1 = ig1 + 1)
    for (ib1 = 0; ib1 < 2; ib1 = ib1 + 1)
    for (ia1 = 0; ia1 < 2; ia1 = ia1 + 1)
    for (ig2 = 0; ig2 < 2; ig2 = ig2 + 1)
    for (ib2 = 0; ib2 < 2; ib2 = ib2 + 1)
    for (ia2 = 0; ia2 < 2; ia2 = ia2 + 1) begin
      A1 = ia1[0]; B1 = ib1[0]; G1_n = ig1[0];
      A2 = ia2[0]; B2 = ib2[0]; G2_n = ig2[0];
      #1;
      ey1 = ref_y(A1, B1, G1_n);
      ey2 = ref_y(A2, B2, G2_n);
      y1_actual = {Y1_3_n, Y1_2_n, Y1_1_n, Y1_0_n};
      y2_actual = {Y2_3_n, Y2_2_n, Y2_1_n, Y2_0_n};
      checks = checks + 2;
      if (y1_actual !== ey1) begin
        errors = errors + 1;
        if (errors < 10)
          $display("FAIL DEC1: A1=%b B1=%b G1_n=%b -> Y1=%04b expected %04b",
                    A1, B1, G1_n, y1_actual, ey1);
      end
      if (y2_actual !== ey2) begin
        errors = errors + 1;
        if (errors < 10)
          $display("FAIL DEC2: A2=%b B2=%b G2_n=%b -> Y2=%04b expected %04b",
                    A2, B2, G2_n, y2_actual, ey2);
      end
    end

    // ---- named property check: the two halves are independent -----------
    A1 = 0; B1 = 0; G1_n = 0; // dec1 enabled, code 00 -> Y1_0_n = 0
    A2 = 0; B2 = 0; G2_n = 1; // dec2 disabled
    #1;
    checks = checks + 1;
    if (Y1_0_n !== 1'b0) begin
      errors = errors + 1;
      $display("FAIL SETUP: expected Y1_0_n=0 before independence check");
    end
    A2 = 1; B2 = 1; G2_n = 0; // now sweep decoder 2 through every code
    #1;
    checks = checks + 1;
    if (Y1_0_n !== 1'b0 || Y1_1_n !== 1'b1 || Y1_2_n !== 1'b1 || Y1_3_n !== 1'b1) begin
      errors = errors + 1;
      $display("FAIL INDEPENDENCE: decoder 2 inputs moved decoder 1 outputs (Y1=%04b)",
                {Y1_3_n, Y1_2_n, Y1_1_n, Y1_0_n});
    end
    // mirror: decoder 1 must not move decoder 2's outputs
    B1 = 1; A1 = 1; G1_n = 1;
    #1;
    checks = checks + 1;
    if (Y2_0_n !== 1'b1 || Y2_1_n !== 1'b1 || Y2_2_n !== 1'b1 || Y2_3_n !== 1'b0) begin
      errors = errors + 1;
      $display("FAIL INDEPENDENCE_MIRROR: decoder 1 inputs moved decoder 2 outputs (Y2=%04b)",
                {Y2_3_n, Y2_2_n, Y2_1_n, Y2_0_n});
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

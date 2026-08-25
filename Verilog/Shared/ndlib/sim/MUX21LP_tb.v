/****************************************************************************
** MUX21LP - exhaustive functional testbench                              **
**                                                                         **
** WHAT THIS MODULE ACTUALLY IS                                            **
**   MUX21LP wraps a single Multiplexer_2 (muxIn_0=A, muxIn_1=B, sel=S)    **
**   and inverts the multiplexer's output:                                 **
**       ZN = ~( S ? B : A )                                               **
**                                                                         **
** SURPRISE FOUND: this is FUNCTIONALLY IDENTICAL to MUX21L.v next door.   **
**   MUX21L wires the same Multiplexer_2 with the same port mapping and    **
**   the same output inversion - only the local wire names differ         **
**   (s_a/s_b/s_s/s_z vs direct port references). Same reference model,   **
**   same DUT truth table, two module names. See MUX21L_tb.v for the      **
**   twin test; both testbenches pass against the identical model.        **
**                                                                         **
** COVERAGE: EXHAUSTIVE. All 2 x 2 x 2 = 8 input combinations (A, B, S),   **
**   every one checked against the reference model above.                 **
**                                                                         **
** VCD: the whole run is 8 steps, so it is dumped in full.                 **
**                                                                         **
** Run: cd Verilog/Shared/ndlib/sim && iverilog -g2012 -o MUX21LP_tb.vvp \
**          MUX21LP_tb.v -y .. -y ../../logisim && vvp MUX21LP_tb.vvp      **
**                                                                         **
** Last reviewed: 20-AUG-2026                                              **
** Ronny Hansen                                                            **
*****************************************************************************/
`timescale 1ns / 1ps
`default_nettype none

module MUX21LP_tb;

  reg  A, B, S;
  wire ZN;

  integer errors = 0;
  integer checks = 0;
  integer ia, ib, is_;
  reg     expected;

  MUX21LP DUT (
      .A (A),
      .B (B),
      .S (S),
      .ZN(ZN)
  );

  // reference model: ZN = NOT( S ? B : A )
  function ref_zn;
    input a, b, s;
    begin
      ref_zn = ~(s ? b : a);
    end
  endfunction

  initial begin
    $dumpfile("MUX21LP_tb.vcd");
    $dumpvars(0, MUX21LP_tb);

    // ---- short documentation sequence: walk S with recognisable data ----
    A = 1'b0; B = 1'b1; S = 1'b0; #10;
    A = 1'b0; B = 1'b1; S = 1'b1; #10;
    A = 1'b1; B = 1'b0; S = 1'b0; #10;
    A = 1'b1; B = 1'b0; S = 1'b1; #10;
    A = 1'b0; B = 1'b0; S = 1'b0; #10;
    A = 1'b1; B = 1'b1; S = 1'b1; #10;

    $dumpoff;

    $display("=====================================================");
    $display(" MUX21LP exhaustive functional testbench");
    $display(" (all 8 input combinations)");
    $display("=====================================================");

    for (ia = 0; ia < 2; ia = ia + 1) begin
      for (ib = 0; ib < 2; ib = ib + 1) begin
        for (is_ = 0; is_ < 2; is_ = is_ + 1) begin
          A = ia[0];
          B = ib[0];
          S = is_[0];
          #1;
          expected = ref_zn(A, B, S);
          checks   = checks + 1;
          if (ZN !== expected) begin
            errors = errors + 1;
            $display("FAIL: A=%b B=%b S=%b -> ZN=%b expected %b", A, B, S, ZN, expected);
          end
        end
      end
    end

    // ---- named property checks -------------------------------------------

    // 1. S selects B (negated) when set
    A = 1'b0; B = 1'b1; S = 1'b1; #1;
    checks = checks + 1;
    if (ZN !== 1'b0) begin
      errors = errors + 1;
      $display("FAIL SEL_B_WHEN_S1: ZN=%b expected 0 (NOT B=1)", ZN);
    end

    // 2. S selects A (negated) when clear
    A = 1'b1; B = 1'b0; S = 1'b0; #1;
    checks = checks + 1;
    if (ZN !== 1'b0) begin
      errors = errors + 1;
      $display("FAIL SEL_A_WHEN_S0: ZN=%b expected 0 (NOT A=1)", ZN);
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

/****************************************************************************
** Multiplexer_2 - exhaustive functional testbench                        **
**                                                                         **
** WHAT THIS MODULE ACTUALLY IS                                            **
**   A plain 2-to-1 multiplexer with a single 1-bit select:                **
**       muxOut = sel ? muxIn_1 : muxIn_0                                  **
**   No inversion, no enable. This is the primitive that MUX21L, MUX21LP,  **
**   MUX24P, and MUX34P's tied-input slices are all built from.            **
**                                                                         **
** COVERAGE: EXHAUSTIVE. Inputs are muxIn_0, muxIn_1, sel = 3 bits, so     **
**   2^3 = 8 combinations, every one checked against the reference model.  **
**                                                                         **
** VCD: 8 combinations, dumped in full.                                    **
**                                                                         **
** Run: cd Verilog/Shared/logisim/sim && iverilog -g2012 \
**          -o Multiplexer_2_tb.vvp Multiplexer_2_tb.v ../Multiplexer_2.v \
**          && vvp Multiplexer_2_tb.vvp                                    **
**                                                                         **
** Last reviewed: 20-AUG-2026                                              **
** Ronny Hansen                                                            **
*****************************************************************************/
`timescale 1ns / 1ps
`default_nettype none

module Multiplexer_2_tb;

  reg muxIn_0, muxIn_1, sel;
  wire muxOut;

  integer errors = 0;
  integer checks = 0;
  integer combo;
  reg expected;

  Multiplexer_2 DUT (
      .muxIn_0(muxIn_0),
      .muxIn_1(muxIn_1),
      .sel    (sel),
      .muxOut (muxOut)
  );

  // reference model: muxOut = sel ? muxIn_1 : muxIn_0
  function ref_out;
    input i0, i1, s;
    begin
      ref_out = s ? i1 : i0;
    end
  endfunction

  initial begin
    $dumpfile("Multiplexer_2_tb.vcd");
    $dumpvars(0, Multiplexer_2_tb);

    muxIn_0 = 1'b0; muxIn_1 = 1'b1; sel = 1'b0; #10;  // sel=0 -> in0
    sel = 1'b1; #10;                                  // sel=1 -> in1
    muxIn_0 = 1'b1; muxIn_1 = 1'b0; sel = 1'b0; #10;
    sel = 1'b1; #10;

    $display("=====================================================");
    $display(" Multiplexer_2 exhaustive functional testbench");
    $display(" (all 8 input combinations)");
    $display("=====================================================");

    for (combo = 0; combo < 8; combo = combo + 1) begin
      {muxIn_0, muxIn_1, sel} = combo[2:0];
      #1;
      expected = ref_out(muxIn_0, muxIn_1, sel);
      checks   = checks + 1;
      if (muxOut !== expected) begin
        errors = errors + 1;
        $display("FAIL: muxIn_0=%b muxIn_1=%b sel=%b -> muxOut=%b expected %b",
                  muxIn_0, muxIn_1, sel, muxOut, expected);
      end
    end

    // ---- named property checks -------------------------------------------

    // 1. sel=0 selects muxIn_0, muxIn_1 has no effect
    muxIn_0 = 1'b1; sel = 1'b0; muxIn_1 = 1'b0; #1;
    checks = checks + 1;
    if (muxOut !== 1'b1) begin
      errors = errors + 1;
      $display("FAIL SEL0_IS_IN0: muxOut=%b expected 1", muxOut);
    end
    muxIn_1 = 1'b1; #1;
    checks = checks + 1;
    if (muxOut !== 1'b1) begin
      errors = errors + 1;
      $display("FAIL SEL0_IGNORES_IN1: muxOut=%b changed when muxIn_1 changed, must stay 1", muxOut);
    end

    // 2. sel=1 selects muxIn_1, muxIn_0 has no effect
    sel = 1'b1; muxIn_1 = 1'b0; muxIn_0 = 1'b1; #1;
    checks = checks + 1;
    if (muxOut !== 1'b0) begin
      errors = errors + 1;
      $display("FAIL SEL1_IS_IN1: muxOut=%b expected 0", muxOut);
    end
    muxIn_0 = 1'b0; #1;
    checks = checks + 1;
    if (muxOut !== 1'b0) begin
      errors = errors + 1;
      $display("FAIL SEL1_IGNORES_IN0: muxOut=%b changed when muxIn_0 changed, must stay 0", muxOut);
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

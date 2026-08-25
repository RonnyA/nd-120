/****************************************************************************
** Multiplexer_2_w_enable - exhaustive functional testbench               **
**                                                                         **
** WHAT THIS MODULE ACTUALLY IS                                            **
**   A 2-to-1 multiplexer with an ACTIVE HIGH enable:                      **
**       muxOut = (enable == 0) ? 0 : (sel ? muxIn_1 : muxIn_0)            **
**   Disabled output is 0, not X and not the last-selected value.          **
**                                                                         **
** COVERAGE: EXHAUSTIVE. Inputs are enable, muxIn_0, muxIn_1, sel = 4      **
**   bits, so 2^4 = 16 combinations, every one checked against the         **
**   reference model above.                                                **
**                                                                         **
** VCD: 16 combinations, dumped in full.                                   **
**                                                                         **
** Run: cd Verilog/Shared/logisim/sim && iverilog -g2012 \
**          -o Multiplexer_2_w_enable_tb.vvp Multiplexer_2_w_enable_tb.v \
**          ../Multiplexer_2_w_enable.v && vvp Multiplexer_2_w_enable_tb.vvp **
**                                                                         **
** Last reviewed: 20-AUG-2026                                              **
** Ronny Hansen                                                            **
*****************************************************************************/
`timescale 1ns / 1ps
`default_nettype none

module Multiplexer_2_w_enable_tb;

  reg enable, muxIn_0, muxIn_1, sel;
  wire muxOut;

  integer errors = 0;
  integer checks = 0;
  integer combo;
  reg expected;

  Multiplexer_2_w_enable DUT (
      .enable (enable),
      .muxIn_0(muxIn_0),
      .muxIn_1(muxIn_1),
      .sel    (sel),
      .muxOut (muxOut)
  );

  // reference model: muxOut = enable ? (sel ? muxIn_1 : muxIn_0) : 0
  function ref_out;
    input en, i0, i1, s;
    begin
      ref_out = (en == 1'b0) ? 1'b0 : (s ? i1 : i0);
    end
  endfunction

  initial begin
    $dumpfile("Multiplexer_2_w_enable_tb.vcd");
    $dumpvars(0, Multiplexer_2_w_enable_tb);

    enable = 1'b1; muxIn_0 = 1'b0; muxIn_1 = 1'b1; sel = 1'b0; #10;  // en=1 sel=0 -> in0
    sel = 1'b1; #10;                                                // en=1 sel=1 -> in1
    enable = 1'b0; #10;                                             // disabled -> 0
    sel = 1'b0; #10;                                                // still disabled -> 0

    $display("=====================================================");
    $display(" Multiplexer_2_w_enable exhaustive functional testbench");
    $display(" (all 16 input combinations)");
    $display("=====================================================");

    for (combo = 0; combo < 16; combo = combo + 1) begin
      {enable, muxIn_0, muxIn_1, sel} = combo[3:0];
      #1;
      expected = ref_out(enable, muxIn_0, muxIn_1, sel);
      checks   = checks + 1;
      if (muxOut !== expected) begin
        errors = errors + 1;
        $display("FAIL: enable=%b muxIn_0=%b muxIn_1=%b sel=%b -> muxOut=%b expected %b",
                  enable, muxIn_0, muxIn_1, sel, muxOut, expected);
      end
    end

    // ---- named property checks -------------------------------------------

    // 1. Disabled output is 0 regardless of sel/data
    enable = 1'b0; muxIn_0 = 1'b1; muxIn_1 = 1'b1; sel = 1'b0; #1;
    checks = checks + 1;
    if (muxOut !== 1'b0) begin
      errors = errors + 1;
      $display("FAIL DISABLED_ZERO_SEL0: muxOut=%b expected 0 with all inputs 1", muxOut);
    end
    sel = 1'b1; #1;
    checks = checks + 1;
    if (muxOut !== 1'b0) begin
      errors = errors + 1;
      $display("FAIL DISABLED_ZERO_SEL1: muxOut=%b expected 0 with all inputs 1", muxOut);
    end

    // 2. Enabled behaves exactly like the plain 2:1 mux
    enable = 1'b1; muxIn_0 = 1'b0; muxIn_1 = 1'b1; sel = 1'b1; #1;
    checks = checks + 1;
    if (muxOut !== 1'b1) begin
      errors = errors + 1;
      $display("FAIL ENABLED_SEL1: muxOut=%b expected muxIn_1=1", muxOut);
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

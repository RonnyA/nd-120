/****************************************************************************
** Multiplexer_4 - exhaustive functional testbench                        **
**                                                                         **
** WHAT THIS MODULE ACTUALLY IS                                            **
**   A 4-to-1 multiplexer coded as an always@(*) case on a 2-bit sel:      **
**       sel=00 -> muxIn_0, 01 -> muxIn_1, 10 -> muxIn_2, 11 -> muxIn_3    **
**   The case has a `default: muxOut = 1'bx;` branch. With a 2-bit sel     **
**   every one of the 4 values is a real case label, so the default is    **
**   UNREACHABLE for any 2-valued (0/1) select - it only exists to keep    **
**   the case statement from inferring a latch on X/Z select bits. This    **
**   testbench does not drive X/Z into sel and does not exercise that      **
**   branch.                                                               **
**                                                                         **
** COVERAGE: EXHAUSTIVE over the reachable input space. Inputs are         **
**   muxIn_0..muxIn_3 (4 bits) and sel (2 bits) = 6 bits, so 2^6 = 64      **
**   combinations, every one checked against the reference model.          **
**                                                                         **
** VCD: a short documentation sequence is dumped first, then dumping is    **
**   turned off for the 64-step sweep.                                     **
**                                                                         **
** Run: cd Verilog/Shared/logisim/sim && iverilog -g2012 \
**          -o Multiplexer_4_tb.vvp Multiplexer_4_tb.v ../Multiplexer_4.v \
**          && vvp Multiplexer_4_tb.vvp                                    **
**                                                                         **
** Last reviewed: 20-AUG-2026                                              **
** Ronny Hansen                                                            **
*****************************************************************************/
`timescale 1ns / 1ps
`default_nettype none

module Multiplexer_4_tb;

  reg muxIn_0, muxIn_1, muxIn_2, muxIn_3;
  reg [1:0] sel;
  wire muxOut;

  integer errors = 0;
  integer checks = 0;
  integer combo;
  reg expected;

  Multiplexer_4 DUT (
      .muxIn_0(muxIn_0),
      .muxIn_1(muxIn_1),
      .muxIn_2(muxIn_2),
      .muxIn_3(muxIn_3),
      .sel    (sel),
      .muxOut (muxOut)
  );

  // reference model: standard binary-select 4:1 mux
  function ref_out;
    input i0, i1, i2, i3;
    input [1:0] s;
    begin
      case (s)
        2'b00: ref_out = i0;
        2'b01: ref_out = i1;
        2'b10: ref_out = i2;
        2'b11: ref_out = i3;
      endcase
    end
  endfunction

  initial begin
    $dumpfile("Multiplexer_4_tb.vcd");
    $dumpvars(0, Multiplexer_4_tb);

    // ---- short documentation sequence: walk sel through all 4 values ----
    muxIn_0 = 1'b1; muxIn_1 = 1'b0; muxIn_2 = 1'b1; muxIn_3 = 1'b0;
    sel = 2'b00; #10;
    sel = 2'b01; #10;
    sel = 2'b10; #10;
    sel = 2'b11; #10;

    $dumpoff;

    $display("=====================================================");
    $display(" Multiplexer_4 exhaustive functional testbench");
    $display(" (all 64 reachable input combinations, 2-bit sel)");
    $display("=====================================================");

    for (combo = 0; combo < 64; combo = combo + 1) begin
      {muxIn_0, muxIn_1, muxIn_2, muxIn_3, sel} = combo[5:0];
      #1;
      expected = ref_out(muxIn_0, muxIn_1, muxIn_2, muxIn_3, sel);
      checks   = checks + 1;
      if (muxOut !== expected) begin
        errors = errors + 1;
        $display("FAIL: muxIn=%b%b%b%b sel=%b -> muxOut=%b expected %b",
                  muxIn_0, muxIn_1, muxIn_2, muxIn_3, sel, muxOut, expected);
      end
    end

    // ---- named property checks -------------------------------------------

    // 1. Each sel value reads only its own input, others have no effect
    muxIn_0 = 1'b1; muxIn_1 = 1'b0; muxIn_2 = 1'b0; muxIn_3 = 1'b0;
    sel = 2'b00; #1;
    checks = checks + 1;
    if (muxOut !== 1'b1) begin
      errors = errors + 1;
      $display("FAIL SEL0_IS_IN0: muxOut=%b expected 1", muxOut);
    end
    muxIn_1 = 1'b1; muxIn_2 = 1'b1; muxIn_3 = 1'b1; #1;
    checks = checks + 1;
    if (muxOut !== 1'b1) begin
      errors = errors + 1;
      $display("FAIL SEL0_IGNORES_OTHERS: muxOut=%b changed, must stay 1 (from muxIn_0)", muxOut);
    end

    sel = 2'b11; muxIn_3 = 1'b0; #1;
    checks = checks + 1;
    if (muxOut !== 1'b0) begin
      errors = errors + 1;
      $display("FAIL SEL3_IS_IN3: muxOut=%b expected 0 (from muxIn_3)", muxOut);
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

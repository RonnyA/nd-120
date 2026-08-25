/****************************************************************************
** Multiplexer_8 - exhaustive functional testbench                        **
**                                                                         **
** WHAT THIS MODULE ACTUALLY IS                                            **
**   An 8-to-1 multiplexer coded as an always@(*) case on a 3-bit sel:     **
**       sel=000 -> muxIn_0 ... sel=111 -> muxIn_7                         **
**   The case has a `default: muxOut = 1'bx;` branch. With a 3-bit sel     **
**   every one of the 8 values is a real case label, so the default is    **
**   UNREACHABLE for any 3-valued (0/1) select. This testbench does not    **
**   drive X/Z into sel and does not exercise that branch.                 **
**                                                                         **
** COVERAGE: EXHAUSTIVE over the reachable input space. Inputs are         **
**   muxIn_0..muxIn_7 (8 bits) and sel (3 bits) = 11 bits, so              **
**   2^11 = 2048 combinations, every one checked against the reference     **
**   model.                                                                 **
**                                                                         **
** VCD: a short documentation sequence is dumped first, then dumping is    **
**   turned off for the 2048-step sweep.                                   **
**                                                                         **
** Run: cd Verilog/Shared/logisim/sim && iverilog -g2012 \
**          -o Multiplexer_8_tb.vvp Multiplexer_8_tb.v ../Multiplexer_8.v \
**          && vvp Multiplexer_8_tb.vvp                                    **
**                                                                         **
** Last reviewed: 20-AUG-2026                                              **
** Ronny Hansen                                                            **
*****************************************************************************/
`timescale 1ns / 1ps
`default_nettype none

module Multiplexer_8_tb;

  reg muxIn_0, muxIn_1, muxIn_2, muxIn_3, muxIn_4, muxIn_5, muxIn_6, muxIn_7;
  reg [2:0] sel;
  wire muxOut;

  integer errors = 0;
  integer checks = 0;
  integer combo;
  reg [7:0] data;
  reg expected;

  Multiplexer_8 DUT (
      .muxIn_0(muxIn_0),
      .muxIn_1(muxIn_1),
      .muxIn_2(muxIn_2),
      .muxIn_3(muxIn_3),
      .muxIn_4(muxIn_4),
      .muxIn_5(muxIn_5),
      .muxIn_6(muxIn_6),
      .muxIn_7(muxIn_7),
      .sel    (sel),
      .muxOut (muxOut)
  );

  // reference model: standard binary-select 8:1 mux
  function ref_out;
    input [7:0] d;
    input [2:0] s;
    begin
      ref_out = d[s];
    end
  endfunction

  initial begin
    $dumpfile("Multiplexer_8_tb.vcd");
    $dumpvars(0, Multiplexer_8_tb);

    // ---- short documentation sequence: walk sel through 0,1,2,4,7 -------
    {muxIn_7,muxIn_6,muxIn_5,muxIn_4,muxIn_3,muxIn_2,muxIn_1,muxIn_0} = 8'b10110010;
    sel = 3'd0; #10;
    sel = 3'd1; #10;
    sel = 3'd2; #10;
    sel = 3'd4; #10;
    sel = 3'd7; #10;

    $dumpoff;

    $display("=====================================================");
    $display(" Multiplexer_8 exhaustive functional testbench");
    $display(" (all 2048 reachable input combinations, 3-bit sel)");
    $display("=====================================================");

    for (combo = 0; combo < 2048; combo = combo + 1) begin
      {muxIn_0, muxIn_1, muxIn_2, muxIn_3, muxIn_4, muxIn_5, muxIn_6, muxIn_7, sel} = combo[10:0];
      #1;
      data = {muxIn_7,muxIn_6,muxIn_5,muxIn_4,muxIn_3,muxIn_2,muxIn_1,muxIn_0};
      expected = ref_out(data, sel);
      checks   = checks + 1;
      if (muxOut !== expected) begin
        errors = errors + 1;
        if (errors < 20)
          $display("FAIL: data=%08b sel=%b -> muxOut=%b expected %b", data, sel, muxOut, expected);
      end
    end

    // ---- named property checks -------------------------------------------

    // 1. Each sel value reads only its own input, others have no effect
    {muxIn_7,muxIn_6,muxIn_5,muxIn_4,muxIn_3,muxIn_2,muxIn_1,muxIn_0} = 8'b00000001;
    sel = 3'd0; #1;
    checks = checks + 1;
    if (muxOut !== 1'b1) begin
      errors = errors + 1;
      $display("FAIL SEL0_IS_IN0: muxOut=%b expected 1", muxOut);
    end
    {muxIn_7,muxIn_6,muxIn_5,muxIn_4,muxIn_3,muxIn_2,muxIn_1} = 7'b1111111; #1;
    checks = checks + 1;
    if (muxOut !== 1'b1) begin
      errors = errors + 1;
      $display("FAIL SEL0_IGNORES_OTHERS: muxOut=%b changed, must stay 1 (from muxIn_0)", muxOut);
    end

    // 2. High end of the select range
    {muxIn_7,muxIn_6,muxIn_5,muxIn_4,muxIn_3,muxIn_2,muxIn_1,muxIn_0} = 8'b10000000;
    sel = 3'd7; #1;
    checks = checks + 1;
    if (muxOut !== 1'b1) begin
      errors = errors + 1;
      $display("FAIL SEL7_IS_IN7: muxOut=%b expected 1 (from muxIn_7)", muxOut);
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

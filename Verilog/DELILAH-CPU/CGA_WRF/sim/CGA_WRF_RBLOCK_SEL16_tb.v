/**************************************************************************
** ND120 CPU, MM&M                                                       **
** CGA_WRF_RBLOCK_SEL16 testbench                                        **
**                                                                       **
** Verification of the register-select hit detectors (PDF page 61):     **
** eight A02 AND-OR-INVERT gates per side pair up SI[k] with EA[k]       **
** (resp. EB[k]), feeding a NAND8 (BubblesMask 0). The whole tree        **
** reduces to the independent model                                      **
**                                                                       **
**   PA = |(SI_15_0 & EA_15_0)     PB = |(SI_15_0 & EB_15_0)             **
**                                                                       **
** (any select line ANDed with its enable). Model cross-checked          **
** gate-vs-behavior in the generator script (scratchpad                  **
** gen_tier1_golden.py, 0 mismatches over per-pair exhaustive + 200k     **
** random vectors).                                                      **
**                                                                       **
** 48 inputs - full exhaustive is 2^48, so per the campaign convention:  **
**   1. 8 directed corner vectors                                        **
**   2. per-A02-slice exhaustive: for each of the 8 bit pairs, all 64    **
**      {SI,EA,EB} combinations in that pair (zero background)           **
**   3. 4096 fixed-seed LFSR full-width vectors                          **
** Each vector checks {PA,PB} as one unit.                               **
**                                                                       **
** Pure combinational (A02 + logisim NAND8, no FF/latch primitives): a   **
** single build mode covers it.                                          **
**                                                                       **
** Self-checking: prints TB_RESULT: PASS / FAIL (never silent).          **
**                                                                       **
** 31-JUL-2026                                                           **
** Ronny Hansen                                                          **
***************************************************************************/
`timescale 1ns / 1ps

module CGA_WRF_RBLOCK_SEL16_tb;

  reg [15:0] EA_15_0 = 0;
  reg [15:0] EB_15_0 = 0;
  reg [15:0] SI_15_0 = 0;

  wire PA, PB;

  integer errors = 0;
  integer checks = 0;
  integer i, sl, c;
  reg [31:0] lfsr;

  CGA_WRF_RBLOCK_SEL16 dut (
      .EA_15_0(EA_15_0),
      .EB_15_0(EB_15_0),
      .SI_15_0(SI_15_0),
      .PA(PA),
      .PB(PB)
  );

  task check(input [127:0] name);
    reg exp_pa, exp_pb;
    begin
      #2;
      exp_pa = |(SI_15_0 & EA_15_0);
      exp_pb = |(SI_15_0 & EB_15_0);
      checks = checks + 1;
      if ({PA, PB} !== {exp_pa, exp_pb}) begin
        errors = errors + 1;
        $display("FAIL %0s: {PA,PB}=%b%b expected %b%b (SI=%04h EA=%04h EB=%04h)",
                 name, PA, PB, exp_pa, exp_pb, SI_15_0, EA_15_0, EB_15_0);
      end
    end
  endtask

  function [31:0] lfsr_next(input [31:0] x);
    lfsr_next = {x[30:0], x[31] ^ x[21] ^ x[1] ^ x[0]};
  endfunction

  initial begin
    // 1. directed corners
    SI_15_0 = 16'h0000; EA_15_0 = 16'h0000; EB_15_0 = 16'h0000; check("all zero");
    SI_15_0 = 16'hFFFF; EA_15_0 = 16'hFFFF; EB_15_0 = 16'hFFFF; check("all ones");
    SI_15_0 = 16'hFFFF; EA_15_0 = 16'h0000; EB_15_0 = 16'h0000; check("SI only");
    SI_15_0 = 16'h0000; EA_15_0 = 16'hFFFF; EB_15_0 = 16'hFFFF; check("E only");
    SI_15_0 = 16'hAAAA; EA_15_0 = 16'h5555; EB_15_0 = 16'h5555; check("disjoint");
    SI_15_0 = 16'h8000; EA_15_0 = 16'h8000; EB_15_0 = 16'h0000; check("hit A only");
    SI_15_0 = 16'h0001; EA_15_0 = 16'h0000; EB_15_0 = 16'h0001; check("hit B only");
    SI_15_0 = 16'h0100; EA_15_0 = 16'h0100; EB_15_0 = 16'h0100; check("hit both");

    // 2. per-A02-slice exhaustive: slice sl covers bits 2*sl+1 .. 2*sl
    for (sl = 0; sl < 8; sl = sl + 1) begin
      for (c = 0; c < 64; c = c + 1) begin
        SI_15_0 = {14'b0, c[5:4]} << (2 * sl);
        EA_15_0 = {14'b0, c[3:2]} << (2 * sl);
        EB_15_0 = {14'b0, c[1:0]} << (2 * sl);
        check("slice");
      end
    end

    // 3. fixed-seed LFSR full-width vectors
    lfsr = 32'h5EED0001;
    for (i = 0; i < 4096; i = i + 1) begin
      lfsr = lfsr_next(lfsr); SI_15_0 = lfsr[15:0];
      lfsr = lfsr_next(lfsr); EA_15_0 = lfsr[15:0];
      lfsr = lfsr_next(lfsr); EB_15_0 = lfsr[15:0];
      check("lfsr");
    end

    // Verdict. Expected: 8 + 8*64 + 4096 = 4616 checks.
    if (errors == 0 && checks == 4616)
      $display("TB_RESULT: PASS (%0d checks)", checks);
    else
      $display("TB_RESULT: FAIL (%0d errors, %0d of 4616 checks)", errors, checks);
    $finish;
  end

endmodule

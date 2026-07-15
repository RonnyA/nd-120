/**************************************************************************************************
** ND120 CGA (CPU Gate Array / DELILAH) - unit test                                              **
** CGA_INTR_CNTLR_IRQ_MASK  (16-bit PICMASK register, schematic p.80)                              **
**                                                                                               **
** DUT contract: 16 independent MASKBIT cells sharing A(DCDA), B(DCDB), C and MCLK.               **
**   Parent supplies DCDCN = ~C. Per bit i, on the rising MCLK edge, with MSK=~q, MSKN=q:          **
**     OR3        = (MSK & A) | (DIN[i] & B) | (B & MSKN & ~C)                                     **
**     new q(MSKN)= ~(OR3 ^ ~C)                                                                    **
**   Outputs: PICMASK[i] = MSK = ~q,  PICMASK_N[i] = MSKN = q.                                     **
**   Named mode used for LOAD round-trip: A=0,B=1,C=1 -> PICMASK <= DIN.                           **
**                                                                                               **
** Regression focus: MASK LOAD round-trip -- write a pattern, read it back, EVERY bit stored       **
** exactly (this is the bit-swap class of bug). Plus complementary PICMASK / PICMASK_N, and no     **
** cross-bit leakage under all shared-decode combinations.                                         **
**                                                                                               **
** Self-checking against an INDEPENDENT per-bit shadow. "TB_RESULT: PASS/FAIL".                    **
** Teeth: -DTEETH_TEST corrupts one expected bit -> harness MUST FAIL.                            **
** MCLK_EN=0, FPGA_FF_MODE NOT defined (original posedge-MCLK path).                              **
**                                                                                               **
** Compile (from repo Verilog/):                                                                  **
**   iverilog -g2012 -o /tmp/tb_mask -y Shared/logisim -y Shared/support -y Shared/ndlib \        **
**     DELILAH-CPU/CGA_INTR/circuit/CGA_INTR_CNTLR_IRQ_MASK_MASKBIT.v \                            **
**     DELILAH-CPU/CGA_INTR/circuit/CGA_INTR_CNTLR_IRQ_MASK.v \                                    **
**     DELILAH-CPU/CGA_INTR/sim/CGA_INTR_CNTLR_IRQ_MASK_tb.v && vvp /tmp/tb_mask                   **
**                                                                                               **
** Last reviewed: 15-JUL-2026                                                                     **
***************************************************************************************************/
`timescale 1ns / 1ps

module CGA_INTR_CNTLR_IRQ_MASK_tb;

  reg         MCLK = 0;
  reg         A = 0, B = 0, C = 0;
  reg  [15:0] DIN  = 16'h0000;
  wire [15:0] PICMASK, PICMASK_N;

  CGA_INTR_CNTLR_IRQ_MASK dut (
      .sysclk        (1'b0),
      .MCLK_EN       (1'b0),
      .A             (A),
      .B             (B),
      .C             (C),
      .DIN_15_0      (DIN),
      .MCLK          (MCLK),
      .PICMASK_15_0  (PICMASK),
      .PICMASK_15_0_N(PICMASK_N)
  );

  integer errors = 0;
  integer checks = 0;
  reg [15:0] q = 16'h0000;      // independent shadow (q per bit = MSKN)
  reg [15:0] q_exp;
  integer b;

  function automatic reg next_q(input cur_q, input datain, input aa, input bb, input cc);
    reg msk, mskn, dcdcn, or3;
    begin
      mskn  = cur_q; msk = ~cur_q; dcdcn = ~cc;
      or3   = (msk & aa) | (datain & bb) | (bb & mskn & dcdcn);
      next_q = ~(or3 ^ dcdcn);
    end
  endfunction

  task edge_and_check(input ta, input tb_, input tc, input [15:0] tdin, input [127:0] what);
    begin
      A = ta; B = tb_; C = tc; DIN = tdin;
      #2;
      for (b = 0; b < 16; b = b + 1)
        q_exp[b] = next_q(q[b], tdin[b], ta, tb_, tc);
`ifdef TEETH_TEST
      q_exp[7] = ~q_exp[7];      // corrupt one bit -> must FAIL
`endif
      #1 MCLK = 1; #2;
      for (b = 0; b < 16; b = b + 1)
        q[b] = next_q(q[b], tdin[b], ta, tb_, tc);
      checks = checks + 1;
      // PICMASK = ~q, PICMASK_N = q ; both must match and be complementary
      if ((PICMASK_N !== q_exp) || (PICMASK !== ~q_exp)) begin
        errors = errors + 1;
        $display("FAIL %0s: PICMASK=%h PICMASK_N=%h exp(MSKN)=%h (A=%b B=%b C=%b DIN=%h)",
                 what, PICMASK, PICMASK_N, q_exp, ta, tb_, tc, tdin);
      end
      #1 MCLK = 0; #2;
    end
  endtask

  // convenience: LOAD a pattern (A=0,B=1,C=1) then verify readback bit-exact
  task load_and_verify(input [15:0] pat, input [127:0] what);
    begin
      edge_and_check(1'b0, 1'b1, 1'b1, pat, what);
      if (PICMASK !== pat) begin
        errors = errors + 1;
        $display("FAIL %0s: round-trip PICMASK=%h expected=%h", what, PICMASK, pat);
      end
      if (PICMASK_N !== ~pat) begin
        errors = errors + 1;
        $display("FAIL %0s: round-trip PICMASK_N=%h expected=%h", what, PICMASK_N, ~pat);
      end
    end
  endtask

  integer i;
  reg roundtrip_ok;

  initial begin
    $dumpfile("CGA_INTR_CNTLR_IRQ_MASK_tb.vcd");
    $dumpvars(0, CGA_INTR_CNTLR_IRQ_MASK_tb);

    // ---- LOAD round-trip: walking ones (bit-swap catcher) ----
    roundtrip_ok = 1'b1;
    for (i = 0; i < 16; i = i + 1) begin
      load_and_verify(16'h0001 << i, "walk-1 load");
      if (PICMASK !== (16'h0001 << i)) roundtrip_ok = 1'b0;
    end
    // walking zeros
    for (i = 0; i < 16; i = i + 1)
      load_and_verify(~(16'h0001 << i), "walk-0 load");
    // canonical patterns
    load_and_verify(16'hA5A5, "pat A5A5");
    load_and_verify(16'h5A5A, "pat 5A5A");
    load_and_verify(16'hFFFF, "pat FFFF");
    load_and_verify(16'h0000, "pat 0000");
    load_and_verify(16'hCAFE, "pat CAFE");
    load_and_verify(16'h8001, "pat 8001");

    // ---- exercise SET/OR, HOLD, CLEAR-all shared modes for cross-bit integrity ----
    load_and_verify(16'h0F0F, "seed 0F0F");
    edge_and_check(1'b1, 1'b1, 1'b1, 16'hF0F0, "OR-in F0F0 -> FFFF");
    if (PICMASK !== 16'hFFFF) begin errors=errors+1; $display("FAIL OR-in expected FFFF got %h",PICMASK); end
    edge_and_check(1'b1, 1'b0, 1'b1, 16'h1234, "HOLD (DIN ignored)");
    if (PICMASK !== 16'hFFFF) begin errors=errors+1; $display("FAIL HOLD expected FFFF got %h",PICMASK); end
    edge_and_check(1'b0, 1'b0, 1'b1, 16'hFFFF, "CLEAR-all");
    if (PICMASK !== 16'h0000) begin errors=errors+1; $display("FAIL CLEAR expected 0000 got %h",PICMASK); end

    // ---- randomized soak over all shared-decode combos + random DIN/current ----
    for (i = 0; i < 800; i = i + 1)
      edge_and_check($random&1, $random&1, $random&1, {$random}, "random");

    $display("LOAD round-trip bit-exact ok=%b", roundtrip_ok);
    if (!roundtrip_ok) errors = errors + 1;
    $display("checks=%0d errors=%0d", checks, errors);
    if (errors == 0) $display("TB_RESULT: PASS");
    else             $display("TB_RESULT: FAIL (%0d errors)", errors);
    $finish;
  end

endmodule

/**************************************************************************************************
** ND120 CGA (CPU Gate Array / DELILAH) - unit test                                              **
** CGA_INTR_CNTLR_IRQ_MREQ  (masked interrupt-request generation, schematic p.81)                  **
**                                                                                               **
** DUT contract (purely combinational, 16 independent NAND gates):                                **
**     MIREQ_N[i] = ~( LREQ[i] & PICMASK_N[i] )   for every bit i, independently.                  **
**   MIREQ_N is ACTIVE-LOW: it asserts (=0) only when the latched request LREQ[i]=1 AND the        **
**   corresponding mask-enable PICMASK_N[i]=1. There must be NO neighbour leakage between bits.    **
**                                                                                               **
** Regression focus: per-bit masking with the live internal-interrupt levels 14,13,12,11,10        **
** hammered explicitly (single-bit walk of both LREQ and PICMASK_N), plus a full exhaustive proof   **
** on one representative bit-pair and randomized 16-bit soak.                                       **
**                                                                                               **
** Self-checking against the INDEPENDENT boolean model. "TB_RESULT: PASS/FAIL".                    **
** Teeth: -DTEETH_TEST corrupts one expected bit -> harness MUST FAIL.                            **
**                                                                                               **
** Compile (from repo Verilog/):                                                                  **
**   iverilog -g2012 -o /tmp/tb_mreq -y Shared/logisim -y Shared/support -y Shared/ndlib \        **
**     DELILAH-CPU/CGA_INTR/circuit/CGA_INTR_CNTLR_IRQ_MREQ.v \                                    **
**     DELILAH-CPU/CGA_INTR/sim/CGA_INTR_CNTLR_IRQ_MREQ_tb.v && vvp /tmp/tb_mreq                   **
**                                                                                               **
** Last reviewed: 15-JUL-2026                                                                     **
***************************************************************************************************/
`timescale 1ns / 1ps

module CGA_INTR_CNTLR_IRQ_MREQ_tb;

  reg  [15:0] LREQ      = 16'h0000;
  reg  [15:0] PICMASK_N = 16'h0000;
  wire [15:0] MIREQ_N;

  CGA_INTR_CNTLR_IRQ_MREQ dut (
      .LREQ_15_0     (LREQ),
      .PICMASK_15_0_N(PICMASK_N),
      .MIREQ_15_0_N  (MIREQ_N)
  );

  integer errors = 0;
  integer checks = 0;
  reg [15:0] exp;
  integer b;

  task do_check(input [127:0] what);
    begin
      #2;
      for (b = 0; b < 16; b = b + 1)
        exp[b] = ~(LREQ[b] & PICMASK_N[b]);   // independent per-bit golden
`ifdef TEETH_TEST
      exp[10] = ~exp[10];   // corrupt IOX bit -> must FAIL
`endif
      checks = checks + 1;
      if (MIREQ_N !== exp) begin
        errors = errors + 1;
        $display("FAIL %0s: MIREQ_N=%h exp=%h (LREQ=%h PICMASK_N=%h)", what, MIREQ_N, exp, LREQ, PICMASK_N);
      end
    end
  endtask

  integer i, lvl;
  integer live_lvls [0:4];
  reg walk_ok;

  initial begin
    $dumpfile("CGA_INTR_CNTLR_IRQ_MREQ_tb.vcd");
    $dumpvars(0, CGA_INTR_CNTLR_IRQ_MREQ_tb);
    live_lvls[0]=14; live_lvls[1]=13; live_lvls[2]=12; live_lvls[3]=11; live_lvls[4]=10;

    // ---- live-level single-bit proof: request present, mask-enable walk ----
    walk_ok = 1'b1;
    for (i = 0; i < 5; i = i + 1) begin
      lvl = live_lvls[i];
      // request on this level only, mask-enable on this level only -> only this MIREQ_N asserts (0)
      LREQ = 16'h1 << lvl; PICMASK_N = 16'h1 << lvl;
      do_check("live: req+enable one level");
      if (MIREQ_N !== ~(16'h1 << lvl)) walk_ok = 1'b0;   // exactly that bit low
      // request present but this level MASKED OFF (PICMASK_N=0) -> no assertion anywhere
      LREQ = 16'h1 << lvl; PICMASK_N = 16'h0000;
      do_check("live: req but masked off");
      if (MIREQ_N !== 16'hFFFF) walk_ok = 1'b0;
      // mask enabled but NO request -> no assertion
      LREQ = 16'h0000; PICMASK_N = 16'h1 << lvl;
      do_check("live: enable but no req");
      if (MIREQ_N !== 16'hFFFF) walk_ok = 1'b0;
    end

    // ---- neighbour-leak: all requests + all enabled, then knock out ONE enable ----
    LREQ = 16'hFFFF; PICMASK_N = 16'hFFFF; do_check("all req all enabled");
    if (MIREQ_N !== 16'h0000) walk_ok = 1'b0;
    for (i = 0; i < 16; i = i + 1) begin
      LREQ = 16'hFFFF; PICMASK_N = ~(16'h1 << i);
      do_check("knock out one enable");
      if (MIREQ_N !== (16'h1 << i)) walk_ok = 1'b0;  // exactly that bit de-asserts (=1)
    end

    // ---- exhaustive on representative bit-pair (bits 12 MOR & 11 PAR) ----
    for (i = 0; i < 16; i = i + 1) begin
      LREQ      = 16'h0000; PICMASK_N = 16'h0000;
      LREQ[12]      = i[0]; LREQ[11]      = i[1];
      PICMASK_N[12] = i[2]; PICMASK_N[11] = i[3];
      do_check("exhaustive bits 12/11");
    end

    // ---- randomized 16-bit soak ----
    for (i = 0; i < 1000; i = i + 1) begin
      LREQ = {$random}; PICMASK_N = {$random};
      do_check("random");
    end

    $display("live-level + neighbour-leak walk ok=%b", walk_ok);
    if (!walk_ok) errors = errors + 1;
    $display("checks=%0d errors=%0d", checks, errors);
    if (errors == 0) $display("TB_RESULT: PASS");
    else             $display("TB_RESULT: FAIL (%0d errors)", errors);
    $finish;
  end

endmodule

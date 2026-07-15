/**************************************************************************************************
** ND120 CGA (CPU Gate Array / DELILAH) - integration test                                        **
** CGA_INTR_CNTLR_IRQ  (request register + PICMASK + masked-request, schematic p.79)               **
**                                                                                               **
** Wires together IRQ_REG (16 request latches), IRQ_MASK (PICMASK), IRQ_MREQ (masking NANDs).      **
** End-to-end contract, all bits independent, on each rising MCLK edge:                            **
**   request latch : if CLRQ[i] LREQ[i]=0; else if !IREQ_N[i] LREQ[i]=1; else hold                 **
**   mask cell     : PICMASK[i] = ~q[i], PICMASK_N[i] = q[i], q updated per the MASKBIT equation   **
**                   OR3 = (~q & A) | (DIN[i] & B) | (B & q & ~C); new q = ~(OR3 ^ ~C)             **
**   masked req    : MIREQ_N[i] = ~( LREQ[i] & PICMASK_N[i] )   (combinational, post-edge)         **
**   CPN driven as ~MCLK (as CGA_INTR_CNTLR wires s_mclk_n).                                       **
**                                                                                               **
** Regression focus: full chain -- a latched request only reaches MIREQ_N when the mask lets it,   **
** persistence across clocks, per-bit clear via CLRQ, and no cross-bit leakage; live internal      **
** levels 14/13/12/11/10 exercised explicitly.                                                     **
**                                                                                               **
** Self-checking against an INDEPENDENT shadow of all three stages. "TB_RESULT: PASS/FAIL".        **
** Teeth: -DTEETH_TEST corrupts an expected MIREQ_N bit -> harness MUST FAIL.                      **
** MCLK_EN=0, FPGA_FF_MODE NOT defined (original posedge-MCLK path).                              **
**                                                                                               **
** Compile (from repo Verilog/):                                                                  **
**   iverilog -g2012 -o /tmp/tb_irq -y Shared/logisim -y Shared/support -y Shared/ndlib \         **
**     DELILAH-CPU/CGA_INTR/circuit/CGA_INTR_CNTLR_IRQ_REG_RQBIT.v \                               **
**     DELILAH-CPU/CGA_INTR/circuit/CGA_INTR_CNTLR_IRQ_REG.v \                                     **
**     DELILAH-CPU/CGA_INTR/circuit/CGA_INTR_CNTLR_IRQ_MASK_MASKBIT.v \                            **
**     DELILAH-CPU/CGA_INTR/circuit/CGA_INTR_CNTLR_IRQ_MASK.v \                                    **
**     DELILAH-CPU/CGA_INTR/circuit/CGA_INTR_CNTLR_IRQ_MREQ.v \                                    **
**     DELILAH-CPU/CGA_INTR/circuit/CGA_INTR_CNTLR_IRQ.v \                                         **
**     DELILAH-CPU/CGA_INTR/sim/CGA_INTR_CNTLR_IRQ_tb.v && vvp /tmp/tb_irq                         **
**                                                                                               **
** Last reviewed: 15-JUL-2026                                                                     **
***************************************************************************************************/
`timescale 1ns / 1ps

module CGA_INTR_CNTLR_IRQ_tb;

  reg         MCLK  = 0;
  reg         A = 0, B = 0, C = 0;
  reg  [15:0] CLRQ  = 16'h0000;
  reg  [15:0] DIN   = 16'h0000;
  reg  [15:0] IREQ_N= 16'hFFFF;   // active-low: no requests
  wire        CPN   = ~MCLK;
  wire [15:0] MIREQ_N, PICMASK;

  CGA_INTR_CNTLR_IRQ dut (
      .sysclk     (1'b0),
      .MCLK_EN    (1'b0),
      .A          (A),
      .B          (B),
      .C          (C),
      .CLRQ_15_0  (CLRQ),
      .CPN        (CPN),
      .DIN_15_0   (DIN),
      .IREQ_15_0_N(IREQ_N),
      .MCLK       (MCLK),
      .MIREQ_15_0_N(MIREQ_N),
      .PICMASK_15_0(PICMASK)
  );

  integer errors = 0;
  integer checks = 0;
  reg [15:0] L  = 16'h0000;   // shadow: latched requests
  reg [15:0] q  = 16'h0000;   // shadow: mask q (=MSKN); PICMASK=~q
  reg [15:0] mireq_exp, picmask_exp;
  integer b;

  function automatic reg next_q(input cur_q, input datain, input aa, input bb, input cc);
    reg msk, mskn, dcdcn, or3;
    begin
      mskn=cur_q; msk=~cur_q; dcdcn=~cc;
      or3 = (msk & aa) | (datain & bb) | (bb & mskn & dcdcn);
      next_q = ~(or3 ^ dcdcn);
    end
  endfunction

  task edge_and_check(input ta, input tb_, input tc, input [15:0] tclrq, input [15:0] tdin,
                      input [15:0] tireqn, input [127:0] what);
    begin
      A=ta; B=tb_; C=tc; CLRQ=tclrq; DIN=tdin; IREQ_N=tireqn;
      #2;
      for (b = 0; b < 16; b = b + 1) begin
        reg nl, nq;
        // request latch next
        if (tclrq[b])        nl = 1'b0;
        else if (!tireqn[b]) nl = 1'b1;
        else                 nl = L[b];
        // mask next
        nq = next_q(q[b], tdin[b], ta, tb_, tc);
        picmask_exp[b] = ~nq;
        mireq_exp[b]   = ~(nl & nq);   // PICMASK_N = q(=nq)
      end
`ifdef TEETH_TEST
      mireq_exp[14] = ~mireq_exp[14];  // corrupt level-14 masked req -> must FAIL
`endif
      #1 MCLK = 1; #2;
      // commit true shadow
      for (b = 0; b < 16; b = b + 1) begin
        if (tclrq[b])        L[b] = 1'b0;
        else if (!tireqn[b]) L[b] = 1'b1;
        q[b] = next_q(q[b], tdin[b], ta, tb_, tc);
      end
      checks = checks + 1;
      if ((MIREQ_N !== mireq_exp) || (PICMASK !== picmask_exp)) begin
        errors = errors + 1;
        $display("FAIL %0s: MIREQ_N=%h exp=%h  PICMASK=%h exp=%h (A%b B%b C%b CLRQ=%h DIN=%h IREQn=%h)",
                 what, MIREQ_N, mireq_exp, PICMASK, picmask_exp, ta, tb_, tc, tclrq, tdin, tireqn);
      end
      #1 MCLK = 0; #2;
    end
  endtask

  // helper: load PICMASK = pat (A=0,B=1,C=1) with no request/clear activity
  task load_mask(input [15:0] pat);
    edge_and_check(1'b0,1'b1,1'b1, 16'h0000, pat, 16'hFFFF, "load-mask");
  endtask
  // helper: pure clock with only request lines driven (no mask op: A=1,B=0,C=1 = HOLD mask)
  task clk_req(input [15:0] tclrq, input [15:0] tireqn, input [127:0] what);
    edge_and_check(1'b1,1'b0,1'b1, tclrq, 16'h0000, tireqn, what);
  endtask

  integer i, lvl;
  integer live_lvls [0:4];
  reg chain_ok;

  initial begin
    $dumpfile("CGA_INTR_CNTLR_IRQ_tb.vcd");
    $dumpvars(0, CGA_INTR_CNTLR_IRQ_tb);
    live_lvls[0]=14; live_lvls[1]=13; live_lvls[2]=12; live_lvls[3]=11; live_lvls[4]=10;

    // master clear the request latches
    clk_req(16'hFFFF, 16'hFFFF, "master clear reqs");

    // ---- full-chain live-level test ----
    // PICMASK_N is the enable seen by MREQ; PICMASK_N[i]=q[i]. Load PICMASK so that the live
    // levels are ENABLED. PICMASK = ~q, so to get q(enable)=1 on a level we need PICMASK bit=0.
    chain_ok = 1'b1;
    for (i = 0; i < 5; i = i + 1) begin
      lvl = live_lvls[i];
      clk_req(16'hFFFF, 16'hFFFF, "clear reqs");        // L=0
      load_mask(~(16'h1 << lvl));                        // PICMASK: this level=0 -> q(enable)=1
      // assert request on this level
      clk_req(16'h0000, ~(16'h1 << lvl), "assert live req");
      if (MIREQ_N !== ~(16'h1 << lvl)) chain_ok = 1'b0;  // exactly this level asserts (=0)
      // remove request line -> PERSIST, still asserted
      clk_req(16'h0000, 16'hFFFF, "persist live req");
      if (MIREQ_N !== ~(16'h1 << lvl)) chain_ok = 1'b0;
      // clear the request -> de-asserts
      clk_req(16'h1 << lvl, 16'hFFFF, "clear live req");
      if (MIREQ_N !== 16'hFFFF) chain_ok = 1'b0;
    end

    // ---- masked-off request must NOT reach MIREQ_N ----
    clk_req(16'hFFFF, 16'hFFFF, "clear reqs");
    load_mask(16'hFFFF);                     // PICMASK all 1 -> q(enable) all 0 -> everything masked
    clk_req(16'h0000, 16'h0000, "all reqs, all masked");
    if (MIREQ_N !== 16'hFFFF) begin errors=errors+1; $display("FAIL masked-off leaked: %h",MIREQ_N); end
    // now enable everything, requests still latched -> all assert
    load_mask(16'h0000);                     // PICMASK all 0 -> q(enable) all 1
    if (MIREQ_N !== 16'h0000) begin errors=errors+1; $display("FAIL enable-all: %h",MIREQ_N); end

    // ---- randomized chain soak (all controls random) ----
    for (i = 0; i < 800; i = i + 1)
      edge_and_check($random&1,$random&1,$random&1, {$random}, {$random}, {$random}, "random");

    $display("full-chain live-level test ok=%b", chain_ok);
    if (!chain_ok) errors = errors + 1;
    $display("checks=%0d errors=%0d", checks, errors);
    if (errors == 0) $display("TB_RESULT: PASS");
    else             $display("TB_RESULT: FAIL (%0d errors)", errors);
    $finish;
  end

endmodule

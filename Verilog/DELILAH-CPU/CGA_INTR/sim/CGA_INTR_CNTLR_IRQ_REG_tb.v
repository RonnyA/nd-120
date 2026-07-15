/**************************************************************************************************
** ND120 CGA (CPU Gate Array / DELILAH) - unit test                                              **
** CGA_INTR_CNTLR_IRQ_REG  (16-bit interrupt-request register, schematic p.78)                    **
**                                                                                               **
** DUT contract: 16 independent RQBIT latches. For each bit i, on the rising MCLK edge:           **
**     if (CLRQ[i])        LREQ[i] <= 0     // clear dominates                                     **
**     else if (!IRQ_N[i]) LREQ[i] <= 1     // capture request (IRQ is ACTIVE-LOW)                 **
**     else                LREQ[i] <= LREQ[i]  // HOLD / persist                                   **
**   LREQ[i] is the latched request, ACTIVE-HIGH.  CPN driven as ~MCLK (as the parent wires it).  **
**                                                                                               **
** Regression focus:                                                                             **
**   - PERSISTENCE: a set request holds across clocks until its CLRQ bit fires.                   **
**   - NO NEIGHBOUR LEAKAGE: setting/clearing one bit must not disturb any other bit. Exercised    **
**     hard on the live internal-interrupt levels 14 (level-14), 13 (POW), 12 (MOR), 11 (PAR),     **
**     10 (IOX) via single-bit walk plus randomized multi-bit soak.                               **
**                                                                                               **
** Self-checking against an INDEPENDENT per-bit shadow L[15:0]. "TB_RESULT: PASS/FAIL".            **
** Teeth: -DTEETH_TEST corrupts one expected bit -> harness MUST FAIL.                            **
** MCLK_EN=0, FPGA_FF_MODE NOT defined (original posedge-MCLK path).                              **
**                                                                                               **
** Compile (from repo Verilog/):                                                                  **
**   iverilog -g2012 -o /tmp/tb_irqreg -y Shared/logisim -y Shared/support -y Shared/ndlib \      **
**     DELILAH-CPU/CGA_INTR/circuit/CGA_INTR_CNTLR_IRQ_REG_RQBIT.v \                               **
**     DELILAH-CPU/CGA_INTR/circuit/CGA_INTR_CNTLR_IRQ_REG.v \                                     **
**     DELILAH-CPU/CGA_INTR/sim/CGA_INTR_CNTLR_IRQ_REG_tb.v && vvp /tmp/tb_irqreg                  **
**                                                                                               **
** Last reviewed: 15-JUL-2026                                                                     **
***************************************************************************************************/
`timescale 1ns / 1ps

module CGA_INTR_CNTLR_IRQ_REG_tb;

  reg         MCLK      = 0;
  reg  [15:0] CLRQ      = 16'h0000;
  reg  [15:0] IRQ_N     = 16'hFFFF;  // active-low: all high = no requests
  wire        CPN       = ~MCLK;
  wire [15:0] LREQ;

  CGA_INTR_CNTLR_IRQ_REG dut (
      .sysclk    (1'b0),
      .MCLK_EN   (1'b0),
      .CLRQ_15_0 (CLRQ),
      .CPN       (CPN),
      .IRQ_15_0_N(IRQ_N),
      .MCLK      (MCLK),
      .LREQ_15_0 (LREQ)
  );

  integer errors = 0;
  integer checks = 0;
  reg [15:0] L = 16'h0000;   // independent shadow
  reg [15:0] lreq_exp;
  integer b;

  task edge_and_check(input [15:0] tclrq, input [15:0] tirqn, input [127:0] what);
    begin
      CLRQ = tclrq; IRQ_N = tirqn;
      #2;
      // independent golden next-state per bit
      for (b = 0; b < 16; b = b + 1) begin
        if (tclrq[b])        lreq_exp[b] = 1'b0;
        else if (!tirqn[b])  lreq_exp[b] = 1'b1;
        else                 lreq_exp[b] = L[b];
      end
`ifdef TEETH_TEST
      lreq_exp[12] = ~lreq_exp[12];   // corrupt the MOR bit -> must FAIL
`endif
      #1 MCLK = 1; #2;
      // commit TRUE shadow
      for (b = 0; b < 16; b = b + 1) begin
        if (tclrq[b])        L[b] = 1'b0;
        else if (!tirqn[b])  L[b] = 1'b1;
      end
      checks = checks + 1;
      if (LREQ !== lreq_exp) begin
        errors = errors + 1;
        $display("FAIL %0s: LREQ exp=%h got=%h (CLRQ=%h IRQ_N=%h)", what, lreq_exp, LREQ, tclrq, tirqn);
      end
      #1 MCLK = 0; #2;
    end
  endtask

  integer i, lvl;
  reg all_walk_ok;
  // live internal-interrupt source levels
  integer live_lvls [0:4];

  initial begin
    $dumpfile("CGA_INTR_CNTLR_IRQ_REG_tb.vcd");
    $dumpvars(0, CGA_INTR_CNTLR_IRQ_REG_tb);
    live_lvls[0]=14; live_lvls[1]=13; live_lvls[2]=12; live_lvls[3]=11; live_lvls[4]=10;

    // master clear all
    edge_and_check(16'hFFFF, 16'hFFFF, "master clear");

    // ---- single-bit request WALK: assert bit i only, prove ONLY bit i sets ----
    all_walk_ok = 1'b1;
    for (i = 0; i < 16; i = i + 1) begin
      edge_and_check(16'hFFFF, 16'hFFFF, "clear before walk");
      edge_and_check(16'h0000, ~(16'h0001 << i), "assert one bit");
      if (LREQ !== (16'h0001 << i)) all_walk_ok = 1'b0;
      // remove request, must PERSIST (still exactly that one bit)
      edge_and_check(16'h0000, 16'hFFFF, "persist one bit");
      if (LREQ !== (16'h0001 << i)) all_walk_ok = 1'b0;
      // clear just that bit
      edge_and_check(16'h0001 << i, 16'hFFFF, "clear one bit");
      if (LREQ !== 16'h0000) all_walk_ok = 1'b0;
    end

    // ---- live internal levels: set all 5, then clear ONE at a time, no leak ----
    edge_and_check(16'hFFFF, 16'hFFFF, "clear");
    edge_and_check(16'h0000, ~((16'h1<<14)|(16'h1<<13)|(16'h1<<12)|(16'h1<<11)|(16'h1<<10)),
                   "set live 14/13/12/11/10");
    for (i = 0; i < 5; i = i + 1) begin
      lvl = live_lvls[i];
      edge_and_check(16'h1 << lvl, 16'hFFFF, "clear one live level");
    end

    // ---- persistence: set bit 14, clock idle many times, must hold ----
    edge_and_check(16'hFFFF, 16'hFFFF, "clear");
    edge_and_check(16'h0000, ~(16'h1<<14), "set lvl14");
    for (i = 0; i < 10; i = i + 1)
      edge_and_check(16'h0000, 16'hFFFF, "hold lvl14");

    // ---- randomized multi-bit soak ----
    for (i = 0; i < 500; i = i + 1)
      edge_and_check({$random}, {$random}, "random");

    $display("single-bit walk (no neighbour leak) ok=%b", all_walk_ok);
    if (!all_walk_ok) errors = errors + 1;
    $display("checks=%0d errors=%0d", checks, errors);
    if (errors == 0) $display("TB_RESULT: PASS");
    else             $display("TB_RESULT: FAIL (%0d errors)", errors);
    $finish;
  end

endmodule

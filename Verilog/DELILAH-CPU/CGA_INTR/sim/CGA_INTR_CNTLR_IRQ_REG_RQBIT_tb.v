/**************************************************************************************************
** ND120 CGA (CPU Gate Array / DELILAH) - unit test                                              **
** CGA_INTR_CNTLR_IRQ_REG_RQBIT  (ONE interrupt-request latch bit, schematic p.78)                **
**                                                                                               **
** DUT contract (derived from the gate netlist, not assumed):                                    **
**   Internal transparent SR-latch  B = ~( (~PN | ~B) & ~(CPN & CLR) )                            **
**   D input to the FF               s_d = ~( (~PN | ~B) & ~CLR )                                 **
**   FF  q <= s_d on posedge CP (= MCLK);  INR = qBar = ~q.                                       **
**                                                                                               **
**   Reduced request-latch behaviour (proved by exhaustive comparison against the DUT below):    **
**     PN is the interrupt request, ACTIVE-LOW  (PN=0 => request asserted).                       **
**     CLR is the clear line,      ACTIVE-HIGH  (CLR=1 => force the latch clear, dominates).      **
**     INR is the latched request, ACTIVE-HIGH  (INR=1 => request pending).                       **
**   On each rising CP edge:                                                                      **
**     if (CLR)      L <= 0            // clear dominates                                          **
**     else if (!PN) L <= 1            // capture a request                                       **
**     else          L <= L            // HOLD (persistence: once set, stays set)                 **
**     INR = L                                                                                    **
**   CPN is driven as ~CP (exactly how CGA_INTR_CNTLR wires s_mclk_n).                            **
**                                                                                               **
** Regression focus: PERSISTENCE (a set request must HOLD across clocks until CLR), and that an   **
** idle bit is not disturbed by unrelated PN activity while cleared.                              **
**                                                                                               **
** Self-checking: golden INR from an INDEPENDENT behavioural shadow (L), checked over a directed  **
** persistence/clear script PLUS an exhaustive sweep of every (state,CLR,PN) transition from both **
** latch states. Prints "TB_RESULT: PASS/FAIL".                                                   **
** Teeth: compile with -DTEETH_TEST to flip the expected value -> the harness MUST report FAIL.   **
** MCLK_EN tied 0, FPGA_FF_MODE NOT defined -> D_FLIPFLOP_EN USE_ENABLE=0 (original posedge-CP).   **
**                                                                                               **
** Compile (from repo Verilog/):                                                                  **
**   iverilog -g2012 -o /tmp/tb_rqbit -y Shared/logisim -y Shared/support -y Shared/ndlib \       **
**     DELILAH-CPU/CGA_INTR/circuit/CGA_INTR_CNTLR_IRQ_REG_RQBIT.v \                               **
**     DELILAH-CPU/CGA_INTR/sim/CGA_INTR_CNTLR_IRQ_REG_RQBIT_tb.v && vvp /tmp/tb_rqbit             **
**                                                                                               **
** Last reviewed: 15-JUL-2026                                                                     **
***************************************************************************************************/
`timescale 1ns / 1ps

module CGA_INTR_CNTLR_IRQ_REG_RQBIT_tb;

  reg  CP  = 0;
  reg  CLR = 0;
  reg  PN  = 1;   // active-low request; 1 = no request
  wire CPN = ~CP; // exactly how CGA_INTR_CNTLR drives s_mclk_n
  wire INR;

  CGA_INTR_CNTLR_IRQ_REG_RQBIT dut (
      .sysclk (1'b0),
      .MCLK_EN(1'b0),
      .CLR    (CLR),
      .CP     (CP),
      .CPN    (CPN),
      .PN     (PN),
      .INR    (INR)
  );

  integer errors = 0;
  integer checks = 0;
  reg     L = 0;      // independent shadow of the latched request
  reg     inr_exp;

  // Drive inputs during CP low, pulse a rising edge, compare INR.
  task edge_and_check(input tclr, input tpn, input [127:0] what);
    begin
      CLR = tclr; PN = tpn;
      #2;                       // let the transparent latch settle at CP=0
      // independent golden next-state
      if (tclr)        inr_exp = 1'b0;
      else if (!tpn)   inr_exp = 1'b1;
      else             inr_exp = L;     // hold
`ifdef TEETH_TEST
      inr_exp = ~inr_exp;               // deliberately wrong -> harness must FAIL
`endif
      #1 CP = 1; #2;            // rising edge captures
      // commit the TRUE shadow (never perturbed)
      if (tclr)        L = 1'b0;
      else if (!tpn)   L = 1'b1;
      // else hold
      checks = checks + 1;
      if (INR !== inr_exp) begin
        errors = errors + 1;
        $display("FAIL %0s: INR exp=%b got=%b (CLR=%b PN=%b Lprev)", what, inr_exp, INR, tclr, tpn);
      end
      #1 CP = 0; #2;
    end
  endtask

  integer i;
  reg pass_set, pass_hold1, pass_hold2, pass_clr, pass_reqgone_clear;

  initial begin
    $dumpfile("CGA_INTR_CNTLR_IRQ_REG_RQBIT_tb.vcd");
    $dumpvars(0, CGA_INTR_CNTLR_IRQ_REG_RQBIT_tb);

    // ---- power-on clear to a defined state ----
    edge_and_check(1'b1, 1'b1, "init-clear");        // CLR -> INR=0

    // ---- directed persistence / clear script ----
    edge_and_check(1'b0, 1'b0, "assert request");    pass_set  = (INR===1'b1);
    edge_and_check(1'b0, 1'b1, "request removed");    pass_hold1= (INR===1'b1); // PERSIST
    edge_and_check(1'b0, 1'b1, "still no request");   pass_hold2= (INR===1'b1); // PERSIST
    edge_and_check(1'b0, 1'b1, "and again");                                    // PERSIST
    edge_and_check(1'b1, 1'b1, "clear it");           pass_clr  = (INR===1'b0);
    // once cleared, unrelated PN=1 idle must NOT set it
    edge_and_check(1'b0, 1'b1, "idle after clear");   pass_reqgone_clear = (INR===1'b0);
    edge_and_check(1'b0, 1'b1, "idle after clear 2"); pass_reqgone_clear = pass_reqgone_clear & (INR===1'b0);

    // clear+request simultaneously: clear must dominate
    edge_and_check(1'b1, 1'b0, "clr dominates req");
    // now set, then verify hold across MANY clocks
    edge_and_check(1'b0, 1'b0, "re-assert");
    for (i = 0; i < 8; i = i + 1)
      edge_and_check(1'b0, 1'b1, "long hold");

    // ---- exhaustive (state, CLR, PN) transition sweep from BOTH latch states ----
    // seed L=0
    edge_and_check(1'b1, 1'b1, "seed L=0");
    edge_and_check(1'b0, 1'b0, "from0 clr0 pn0");
    edge_and_check(1'b1, 1'b1, "seed L=0b");
    edge_and_check(1'b0, 1'b1, "from0 clr0 pn1");
    edge_and_check(1'b1, 1'b1, "seed L=0c");
    edge_and_check(1'b1, 1'b0, "from0 clr1 pn0");
    edge_and_check(1'b1, 1'b1, "from0 clr1 pn1 (=seed)");
    // seed L=1
    edge_and_check(1'b0, 1'b0, "seed L=1");
    edge_and_check(1'b0, 1'b0, "from1 clr0 pn0");
    edge_and_check(1'b0, 1'b0, "seed L=1b");
    edge_and_check(1'b0, 1'b1, "from1 clr0 pn1 (hold 1)");
    edge_and_check(1'b0, 1'b0, "seed L=1c");
    edge_and_check(1'b1, 1'b0, "from1 clr1 pn0");
    edge_and_check(1'b0, 1'b0, "seed L=1d");
    edge_and_check(1'b1, 1'b1, "from1 clr1 pn1");

    // ---- randomized soak ----
    for (i = 0; i < 400; i = i + 1)
      edge_and_check($random & 1, $random & 1, "random");

    $display("spotlights: set=%b hold1=%b hold2=%b clr=%b idle-stays-clear=%b",
             pass_set, pass_hold1, pass_hold2, pass_clr, pass_reqgone_clear);
    $display("checks=%0d errors=%0d", checks, errors);
    if (errors == 0) $display("TB_RESULT: PASS");
    else             $display("TB_RESULT: FAIL (%0d errors)", errors);
    $finish;
  end

endmodule

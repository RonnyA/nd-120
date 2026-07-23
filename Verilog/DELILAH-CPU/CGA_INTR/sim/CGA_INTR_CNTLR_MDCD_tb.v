/**************************************************************************************************
** ND120 CGA (CPU Gate Array / DELILAH) - unit test                                              **
** CGA_INTR_CNTLR_MDCD   (PIC command decoder, schematic p.n)                                     **
**                                                                                               **
** DUT contract (derived directly from the gate netlist in                                       **
**   DELILAH-CPU/CGA_INTR/circuit/CGA_INTR_CNTLR_MDCD.v):                                          **
**   Two ND38GLP 3->8 decoders turn LAA_3_0 into one-hot (active-low) command lines d0..d15.      **
**   dn[X] = 0 iff LAA==X.  sel[X] = (LAA==X).  epic gates almost every strobe.                   **
**                                                                                               **
**   Combinational strobes (independent golden, re-derived by hand from the gates):               **
**     g1 = sel0|sel8|sel10|sel12|sel14   g2 = sel10|sel11|sel14                                   **
**     g3 = sel8|sel10                     g4 = sel3|sel7                                          **
**     A         = ~(g1 & epic)                 (GATES_5 AND then NOT  -> active-low)              **
**     B         =  (g2 & epic)                 (GATES_8 NAND then NOT -> active-high)             **
**     C         = ~(g3 & epic)                                                                    **
**     EPICMASKN = ~(g4 & epic)   OEM = (g4 & epic)                                                **
**     OESN      = ~(sel6 & epic)                                                                  **
**     N         =  (sel5 & epic)   S = ~N                                                         **
**     HIF       = (sel5 & hipassall & epic) | (sel9 & epic)                                       **
**     LOF       = (sel9 & epic) | (sel5 & lopassall & epic)                                       **
**     G         = ~((sel0|sel5) & epic)   M = ~((sel0|sel5) & epic)                               **
**     L         =  (sel0|sel9) & epic                                                             **
**     J         =  (sel0|sel1|sel2|sel3) & epic                                                   **
**     D         = ~((sel0|sel13|sel15) & epic)                                                    **
**     E         = ~sel13                        (NOTE: independent of epic)                       **
**     H         =  (sel0|sel5|sel9) & epic                                                        **
**                                                                                               **
**   Pass-all latch (two MCLK-domain FFs, init 0), gt41 = ~((sel0|sel1|sel4|sel5)&epic):           **
**     m42.d = (m42q & gt41) | (lopassall & N)      m43.d = (m43q & gt41) | (hipassall & N)         **
**   Stateful strobes:                                                                             **
**     HIK = (sel4 & epic & m43q) | (sel0 & epic) | (sel1 & epic)                                  **
**     LOK = (sel1 & epic) | (sel0 & epic) | (sel4 & epic & m42q)                                  **
**                                                                                               **
** Self-checking: golden computed INDEPENDENTLY here. Part A exhaustively sweeps all               **
**   16 LAA x epic x hipassall x lopassall = 128 input combos (MCLK held low, FFs at init 0)       **
**   and checks all 19 outputs. Part B toggles MCLK to load/hold/clear the pass-all latch and      **
**   verifies HIK/LOK track the FF state. Prints "TB_RESULT: PASS/FAIL".                           **
**                                                                                               **
** -DTEETH_TEST perturbs the golden (g3 = sel8|sel9 instead of sel8|sel10) -> C mismatches at      **
**   LAA=10 with epic -> the tb must report FAIL, proving the checks actually compare.             **
**                                                                                               **
** Default build: MCLK_EN=0, FPGA_FF_MODE NOT defined (FFs clock on routed MCLK).                  **
** Compile (from repo Verilog/):                                                                  **
**   iverilog -g2012 -o /tmp/tb_mdcd -y Shared/logisim -y Shared/support -y Shared/ndlib \         **
**     DELILAH-CPU/CGA_INTR/circuit/CGA_INTR_CNTLR_MDCD.v \                                         **
**     DELILAH-CPU/CGA_INTR/sim/CGA_INTR_CNTLR_MDCD_tb.v && vvp /tmp/tb_mdcd                        **
**                                                                                               **
** Last reviewed: 15-JUL-2026                                                                     **
***************************************************************************************************/
`timescale 1ns / 1ps

module CGA_INTR_CNTLR_MDCD_tb;

  // DUT inputs
  reg        sysclk;
  reg        MCLK_EN;
  reg        EPIC;
  reg        HIPASSALL;
  reg  [3:0] LAA_3_0;
  reg        LOPASSALL;
  reg        MCLK;

  // DUT outputs
  wire A, B, C, D, E, EPICMASKN, G, H, HIF, HIK, J, L, LOF, LOK, M, N, OEM, OESN, S;

  CGA_INTR_CNTLR_MDCD dut (
      .sysclk   (sysclk),
      .MCLK_EN  (MCLK_EN),
      .EPIC     (EPIC),
      .HIPASSALL(HIPASSALL),
      .LAA_3_0  (LAA_3_0),
      .LOPASSALL(LOPASSALL),
      .MCLK     (MCLK),
      .A(A), .B(B), .C(C), .D(D), .E(E),
      .EPICMASKN(EPICMASKN), .G(G), .H(H), .HIF(HIF), .HIK(HIK),
      .J(J), .L(L), .LOF(LOF), .LOK(LOK), .M(M), .N(N),
      .OEM(OEM), .OESN(OESN), .S(S)
  );

  integer errors = 0;
  integer checks = 0;

  // ---- shadow pass-all latch state (init 0, matching D_FLIPFLOP initial) ----
  reg smem42q, smem43q;

  // ---- independent golden expectations ----
  reg e_A, e_B, e_C, e_D, e_E, e_EPICMASKN, e_G, e_H, e_HIF, e_HIK;
  reg e_J, e_L, e_LOF, e_LOK, e_M, e_N, e_OEM, e_OESN, e_S;

  // one-hot selects
  function sel(input [3:0] v, input integer x); sel = (v == x[3:0]); endfunction

  task compute_expected(input [3:0] v, input ep, input hpa, input lpa,
                        input m42q, input m43q);
    reg g1,g2,g3,g4,nn,gt41;
    begin
      g1 = sel(v,0)|sel(v,8)|sel(v,10)|sel(v,12)|sel(v,14);
      g2 = sel(v,10)|sel(v,11)|sel(v,14);
`ifdef TEETH_TEST
      g3 = sel(v,8)|sel(v,9);      // TEETH: wrong (should be sel8|sel10) -> C wrong at LAA=10
`else
      g3 = sel(v,8)|sel(v,10);
`endif
      g4 = sel(v,3)|sel(v,7);
      nn = sel(v,5) & ep;

      e_A         = ~(g1 & ep);
      e_B         =  (g2 & ep);
      e_C         = ~(g3 & ep);
      e_EPICMASKN = ~(g4 & ep);
      e_OEM       =  (g4 & ep);
      e_OESN      = ~(sel(v,6) & ep);
      e_N         =  nn;
      e_S         = ~nn;
      e_HIF       = (sel(v,5)&hpa&ep) | (sel(v,9)&ep);
      e_LOF       = (sel(v,9)&ep) | (sel(v,5)&lpa&ep);
      e_G         = ~((sel(v,0)|sel(v,5)) & ep);
      e_M         = ~((sel(v,0)|sel(v,5)) & ep);
      e_L         =  (sel(v,0)|sel(v,9)) & ep;
      e_J         =  (sel(v,0)|sel(v,1)|sel(v,2)|sel(v,3)) & ep;
      e_D         = ~((sel(v,0)|sel(v,13)|sel(v,15)) & ep);
      e_E         = ~sel(v,13);
      e_H         =  (sel(v,0)|sel(v,5)|sel(v,9)) & ep;

      // gates29/gates32 feed AND3 with BubblesMask 111: the Q-bar input is
      // re-inverted back to Q, so the sel4 term uses m43q/m42q (Q), not ~Q.
      e_HIK = (sel(v,4)&ep&m43q) | (sel(v,0)&ep) | (sel(v,1)&ep);
      e_LOK = (sel(v,1)&ep) | (sel(v,0)&ep) | (sel(v,4)&ep&m42q);

      gt41 = ~((sel(v,0)|sel(v,1)|sel(v,4)|sel(v,5)) & ep);
      // (gt41 / next-state used by the sequential model in Part B)
    end
  endtask

  // shadow next-state of the pass-all latch (call at each modeled MCLK posedge)
  function nextm(input m_q, input other, input [3:0] v, input ep, input pass);
    reg gt41, nn;
    begin
      nn   = sel(v,5) & ep;
      gt41 = ~((sel(v,0)|sel(v,1)|sel(v,4)|sel(v,5)) & ep);
      nextm = (m_q & gt41) | (pass & nn);
    end
  endfunction

  task check_all(input [127:0] tag);
    begin
      checks = checks + 1;
      if (A!==e_A||B!==e_B||C!==e_C||D!==e_D||E!==e_E||EPICMASKN!==e_EPICMASKN||
          G!==e_G||H!==e_H||HIF!==e_HIF||HIK!==e_HIK||J!==e_J||L!==e_L||
          LOF!==e_LOF||LOK!==e_LOK||M!==e_M||N!==e_N||OEM!==e_OEM||
          OESN!==e_OESN||S!==e_S) begin
        errors = errors + 1;
        $display("FAIL[%0s] LAA=%0d EPIC=%b HPA=%b LPA=%b m42q=%b m43q=%b",
                 tag, LAA_3_0, EPIC, HIPASSALL, LOPASSALL, smem42q, smem43q);
        if (A!==e_A) $display("   A   exp=%b got=%b", e_A, A);
        if (B!==e_B) $display("   B   exp=%b got=%b", e_B, B);
        if (C!==e_C) $display("   C   exp=%b got=%b", e_C, C);
        if (D!==e_D) $display("   D   exp=%b got=%b", e_D, D);
        if (E!==e_E) $display("   E   exp=%b got=%b", e_E, E);
        if (EPICMASKN!==e_EPICMASKN) $display("   EPICMASKN exp=%b got=%b", e_EPICMASKN, EPICMASKN);
        if (G!==e_G) $display("   G   exp=%b got=%b", e_G, G);
        if (H!==e_H) $display("   H   exp=%b got=%b", e_H, H);
        if (HIF!==e_HIF) $display("   HIF exp=%b got=%b", e_HIF, HIF);
        if (HIK!==e_HIK) $display("   HIK exp=%b got=%b", e_HIK, HIK);
        if (J!==e_J) $display("   J   exp=%b got=%b", e_J, J);
        if (L!==e_L) $display("   L   exp=%b got=%b", e_L, L);
        if (LOF!==e_LOF) $display("   LOF exp=%b got=%b", e_LOF, LOF);
        if (LOK!==e_LOK) $display("   LOK exp=%b got=%b", e_LOK, LOK);
        if (M!==e_M) $display("   M   exp=%b got=%b", e_M, M);
        if (N!==e_N) $display("   N   exp=%b got=%b", e_N, N);
        if (OEM!==e_OEM) $display("   OEM exp=%b got=%b", e_OEM, OEM);
        if (OESN!==e_OESN) $display("   OESN exp=%b got=%b", e_OESN, OESN);
        if (S!==e_S) $display("   S   exp=%b got=%b", e_S, S);
      end
    end
  endtask

  integer vi, ep, hp, lp;
  reg n42, n43;

  // free-running system clock (only relevant in FF mode; harmless in default mode)
  initial sysclk = 0;
  always #5 sysclk = ~sysclk;

  initial begin
    MCLK_EN = 1'b0;
    MCLK    = 1'b0;
    smem42q = 1'b0;
    smem43q = 1'b0;

    // -------- Part A: exhaustive combinational sweep (MCLK held low) --------
    for (ep = 0; ep < 2; ep = ep + 1)
      for (hp = 0; hp < 2; hp = hp + 1)
        for (lp = 0; lp < 2; lp = lp + 1)
          for (vi = 0; vi < 16; vi = vi + 1) begin
            EPIC = ep[0]; HIPASSALL = hp[0]; LOPASSALL = lp[0]; LAA_3_0 = vi[3:0];
            #2;
            compute_expected(vi[3:0], ep[0], hp[0], lp[0], smem42q, smem43q);
            check_all("A-comb");
          end

    // -------- Part B: pass-all latch (HIK/LOK statefulness) --------
    // helper sequence via inline tasks below
    // HIK/LOK sel4 term reads the pass-all latch Q: asserts when m*q=1.
    // 1) init state (m42q=m43q=0): at LAA=4,epic=1 both HIK and LOK are DEASSERTED
    apply(4'd4, 1'b1, 1'b0, 1'b0);
    // 2) LAA=5,epic,lpa=hpa=1 loads BOTH latches to 1 on the MCLK edge
    apply_clk(4'd5, 1'b1, 1'b1, 1'b1);
    // 3) now LAA=4,epic=1 -> both HIK and LOK ASSERT (m*q=1)
    apply(4'd4, 1'b1, 1'b0, 1'b0);
    // 4) LAA=7,epic=1 is a HOLD (gt41=1) -> latches stay 1
    apply_clk(4'd7, 1'b1, 1'b0, 1'b0);
    apply(4'd4, 1'b1, 1'b0, 1'b0);          // still asserted
    // 5) LAA=5,epic,lpa=1,hpa=0 -> m42<=1, m43<=0 (asymmetric load)
    apply_clk(4'd5, 1'b1, 1'b0, 1'b1);
    apply(4'd4, 1'b1, 1'b0, 1'b0);          // LOK asserts (m42q=1), HIK deasserts (m43q=0)
    // 6) LAA=0,epic=1 is a CLEAR (gt41=0, no set) -> both latches 0
    apply_clk(4'd0, 1'b1, 1'b0, 1'b0);
    apply(4'd4, 1'b1, 1'b0, 1'b0);          // both HIK and LOK deassert again
    // 7) epic=0 command is a HOLD regardless of LAA
    apply_clk(4'd5, 1'b0, 1'b1, 1'b1);      // epic=0 -> gt41=1, N=0 -> hold (stay 0)
    apply(4'd4, 1'b1, 1'b0, 1'b0);          // still deasserted

    $display("checks=%0d errors=%0d", checks, errors);
    if (errors == 0) $display("TB_RESULT: PASS");
    else             $display("TB_RESULT: FAIL (%0d errors)", errors);
    $finish;
  end

  // apply inputs WITHOUT clocking, then check (latch state unchanged)
  task apply(input [3:0] v, input ep, input hp, input lp);
    begin
      EPIC = ep; HIPASSALL = hp; LOPASSALL = lp; LAA_3_0 = v;
      #2;
      compute_expected(v, ep, hp, lp, smem42q, smem43q);
      check_all("B-hold");
    end
  endtask

  // apply inputs, pulse MCLK (posedge advances the latch), update shadow, then check
  task apply_clk(input [3:0] v, input ep, input hp, input lp);
    reg nn42, nn43;
    begin
      EPIC = ep; HIPASSALL = hp; LOPASSALL = lp; LAA_3_0 = v;
      #2;
      // compute next-state from CURRENT shadow BEFORE the edge
      nn42 = nextm(smem42q, smem43q, v, ep, lp);
      nn43 = nextm(smem43q, smem42q, v, ep, hp);
      MCLK = 1'b1; #2;      // rising edge captures
      smem42q = nn42;
      smem43q = nn43;
      MCLK = 1'b0; #2;
      compute_expected(v, ep, hp, lp, smem42q, smem43q);
      check_all("B-clk");
    end
  endtask

endmodule

/**************************************************************************************************
** ND120 CGA (CPU Gate Array / DELILAH) - unit test                                              **
** CGA_INTR_CNTLR_IRQ_MASK_MASKBIT  (ONE PICMASK register bit cell, schematic p.80)                **
**                                                                                               **
** DUT contract (derived from the gate netlist, NOT assumed):                                     **
**   Outputs are complementary: MSK = qBar, MSKN = q  (MSK = ~MSKN always).                        **
**   With DCDCN driven as ~C by the parent, the combinational D into the FF is:                    **
**     OR3   = (MSK & DCDA) | (DATAIN & DCDB) | (DCDB & MSKN & DCDCN)                              **
**     new q(=MSKN) = XNOR(OR3, DCDCN) = ~(OR3 ^ DCDCN)                                            **
**     new MSK      = ~new_q                                                                       **
**   captured on the rising CLOCK edge (= MCLK).                                                   **
**                                                                                               **
**   Named modes that fall out of that equation (DCDCN = ~C):                                      **
**     C=1,DCDA=0,DCDB=1 : new MSK = DATAIN         (LOAD  - the round-trip mode)                  **
**     C=1,DCDA=1,DCDB=0 : new MSK = MSK            (HOLD)                                          **
**     C=1,DCDA=1,DCDB=1 : new MSK = MSK | DATAIN   (SET / OR-in)                                  **
**     C=1,DCDA=0,DCDB=0 : new MSK = 0              (CLEAR-all)                                      **
**   (C=0 cases are exercised too, purely from the raw equation.)                                  **
**                                                                                               **
** Self-checking: independent shadow of new_q computed from the boolean equation above, swept      **
** EXHAUSTIVELY over all 2^5 = 32 input combinations (DCDA,DCDB,C,DATAIN x current state), from     **
** both initial states, plus named-mode spotlights incl. a LOAD round-trip. "TB_RESULT: PASS/FAIL".**
** Teeth: -DTEETH_TEST flips the expected value -> harness MUST FAIL.                              **
** MCLK_EN=0, FPGA_FF_MODE NOT defined (original posedge-CLOCK path).                              **
**                                                                                               **
** Compile (from repo Verilog/):                                                                  **
**   iverilog -g2012 -o /tmp/tb_maskbit -y Shared/logisim -y Shared/support -y Shared/ndlib \     **
**     DELILAH-CPU/CGA_INTR/circuit/CGA_INTR_CNTLR_IRQ_MASK_MASKBIT.v \                            **
**     DELILAH-CPU/CGA_INTR/sim/CGA_INTR_CNTLR_IRQ_MASK_MASKBIT_tb.v && vvp /tmp/tb_maskbit        **
**                                                                                               **
** Last reviewed: 15-JUL-2026                                                                     **
***************************************************************************************************/
`timescale 1ns / 1ps

module CGA_INTR_CNTLR_IRQ_MASK_MASKBIT_tb;

  reg  CLOCK  = 0;
  reg  DATAIN = 0;
  reg  DCDA   = 0;
  reg  DCDB   = 0;
  reg  C      = 0;          // parent supplies DCDCN = ~C
  wire DCDCN  = ~C;
  wire MSK, MSKN;

  CGA_INTR_CNTLR_IRQ_MASK_MASKBIT dut (
      .sysclk (1'b0),
      .MCLK_EN(1'b0),
      .CLOCK  (CLOCK),
      .DATAIN (DATAIN),
      .DCDA   (DCDA),
      .DCDB   (DCDB),
      .DCDCN  (DCDCN),
      .MSK    (MSK),
      .MSKN   (MSKN)
  );

  integer errors = 0;
  integer checks = 0;
  reg     q = 0;       // independent shadow of q (=MSKN). MSK = ~q.
  reg     q_exp;

  // pure boolean next-state, independent of the DUT gate instances
  function automatic reg next_q(input cur_q, input datain, input dcda, input dcdb, input c);
    reg msk, mskn, dcdcn, or3;
    begin
      mskn  = cur_q;
      msk   = ~cur_q;
      dcdcn = ~c;
      or3   = (msk & dcda) | (datain & dcdb) | (dcdb & mskn & dcdcn);
      next_q = ~(or3 ^ dcdcn);   // XNOR
    end
  endfunction

  task edge_and_check(input tda, input tdb, input tc, input tdin, input [127:0] what);
    begin
      DATAIN = tdin; DCDA = tda; DCDB = tdb; C = tc;
      #2;
      q_exp = next_q(q, tdin, tda, tdb, tc);
`ifdef TEETH_TEST
      q_exp = ~q_exp;             // deliberately wrong -> harness must FAIL
`endif
      #1 CLOCK = 1; #2;
      q = next_q(q, tdin, tda, tdb, tc);   // commit TRUE shadow
      checks = checks + 1;
      // MSKN must equal q_exp, and MSK must be its complement
      if ((MSKN !== q_exp) || (MSK !== ~q_exp)) begin
        errors = errors + 1;
        $display("FAIL %0s: MSK=%b MSKN=%b exp q(MSKN)=%b (DCDA=%b DCDB=%b C=%b DIN=%b)",
                 what, MSK, MSKN, q_exp, tda, tdb, tc, tdin);
      end
      #1 CLOCK = 0; #2;
    end
  endtask

  integer i, seed;
  reg pass_load1, pass_load0, pass_hold, pass_setor, pass_clrall;

  initial begin
    $dumpfile("CGA_INTR_CNTLR_IRQ_MASK_MASKBIT_tb.vcd");
    $dumpvars(0, CGA_INTR_CNTLR_IRQ_MASK_MASKBIT_tb);

    // ---- named-mode spotlights (C=1) ----
    // LOAD round-trip: DCDA=0,DCDB=1 -> MSK <- DATAIN
    edge_and_check(1'b0, 1'b1, 1'b1, 1'b1, "LOAD msk<=1"); pass_load1 = (MSK===1'b1);
    edge_and_check(1'b1, 1'b0, 1'b1, 1'b0, "HOLD (=1)");   pass_hold  = (MSK===1'b1);
    edge_and_check(1'b0, 1'b1, 1'b1, 1'b0, "LOAD msk<=0"); pass_load0 = (MSK===1'b0);
    edge_and_check(1'b1, 1'b1, 1'b1, 1'b1, "SET/OR-in 1"); pass_setor = (MSK===1'b1);
    edge_and_check(1'b0, 1'b0, 1'b1, 1'b0, "CLEAR-all");   pass_clrall= (MSK===1'b0);

    // ---- exhaustive sweep, from BOTH starting states ----
    // start from q=0 (MSK=1): force a load-1 first
    edge_and_check(1'b0, 1'b1, 1'b1, 1'b1, "seed MSK=1");   // MSK=1 => q=0
    for (i = 0; i < 16; i = i + 1) begin
      // reseed to q=0 each iter, then apply combo, so 'current state' side is q=0
      edge_and_check(1'b0, 1'b1, 1'b1, 1'b1, "reseed q0");
      edge_and_check(i[3], i[2], i[1], i[0], "exh from q0");
    end
    // start from q=1 (MSK=0): force a load-0 first
    for (i = 0; i < 16; i = i + 1) begin
      edge_and_check(1'b0, 1'b1, 1'b1, 1'b0, "reseed q1"); // MSK=0 => q=1
      edge_and_check(i[3], i[2], i[1], i[0], "exh from q1");
    end

    // ---- randomized soak ----
    for (i = 0; i < 300; i = i + 1) begin
      seed = $random;
      edge_and_check(seed[0], seed[1], seed[2], seed[3], "random");
    end

    $display("spotlights: load1=%b hold=%b load0=%b setor=%b clrall=%b",
             pass_load1, pass_hold, pass_load0, pass_setor, pass_clrall);
    $display("checks=%0d errors=%0d", checks, errors);
    if (errors == 0) $display("TB_RESULT: PASS");
    else             $display("TB_RESULT: FAIL (%0d errors)", errors);
    $finish;
  end

endmodule

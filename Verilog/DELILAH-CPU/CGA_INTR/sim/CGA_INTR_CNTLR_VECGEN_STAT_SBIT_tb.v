/**************************************************************************************************
** ND120 CGA (CPU Gate Array / DELILAH) - unit test                                              **
** CGA_INTR_CNTLR_VECGEN_STAT_SBIT  (ONE Am2914 status-register bit cell, schematic p.87)         **
**                                                                                               **
** DUT contract (confirmed cell equation, docs/RUN-level14-livelock-analysis.md):                **
**   D = (SIN & DCDG & DCDF & GPE) | (DCDG & DCDFN & STS) | (VINN & DCDF & DCDGN)                 **
**   STS <= D on the rising edge of CK (= MCLK).                                                  **
**   Named operations (the way STAT drives this cell):                                            **
**     idle   : DCDG=1, DCDF=0            -> hold  (D = STS)                                       **
**     LDSTAT : DCDG=1, DCDF=1, GPE=1     -> load  (D = SIN, the S-bus)                            **
**     RDVECT : DCDG=0, DCDGN=1, DCDF=1   -> fence (D = VINN, the "vector+1" bit)                  **
**     MCLR   : DCDG=0, DCDF=0            -> clear (D = 0)                                          **
**                                                                                               **
** Self-checking: golden D is computed INDEPENDENTLY from the boolean equation above and tracked  **
** as a shadow state model, EXHAUSTIVELY over all 128 input combinations (7 inputs), plus the     **
** four named-operation spotlight checks. Prints "TB_RESULT: PASS/FAIL".                          **
**                                                                                               **
** Teeth: compile with -DTEETH_TEST to flip the expected value -> the harness MUST report FAIL.   **
**                                                                                               **
** MCLK_EN tied 0, FPGA_FF_MODE NOT defined -> D_FLIPFLOP_EN USE_ENABLE=0 (original posedge-CK).   **
**                                                                                               **
** Compile (from repo Verilog/):                                                                  **
**   iverilog -g2012 -o /tmp/tb_sbit -y Shared/logisim -y Shared/support -y Shared/ndlib \        **
**     DELILAH-CPU/CGA_INTR/circuit/CGA_INTR_CNTLR_VECGEN_STAT_SBIT.v \                            **
**     DELILAH-CPU/CGA_INTR/sim/CGA_INTR_CNTLR_VECGEN_STAT_SBIT_tb.v && vvp /tmp/tb_sbit           **
**                                                                                               **
** Last reviewed: 15-JUL-2026                                                                     **
***************************************************************************************************/
`timescale 1ns / 1ps

module CGA_INTR_CNTLR_VECGEN_STAT_SBIT_tb;

  reg CK    = 0;
  reg DCDF  = 0;
  reg DCDFN = 0;
  reg DCDG  = 0;
  reg DCDGN = 0;
  reg GPE   = 0;
  reg SIN   = 0;
  reg VINN  = 0;
  wire STS;

  CGA_INTR_CNTLR_VECGEN_STAT_SBIT dut (
      .sysclk (1'b0),
      .MCLK_EN(1'b0),
      .CK     (CK),
      .DCDF   (DCDF),
      .DCDFN  (DCDFN),
      .DCDG   (DCDG),
      .DCDGN  (DCDGN),
      .GPE    (GPE),
      .SIN    (SIN),
      .VINN   (VINN),
      .STS    (STS)
  );

  integer errors = 0;
  integer checks = 0;
  reg     sts_model = 0;   // independent shadow of the FF state
  reg     d_exp;

  // Rising clock edge: capture D into STS (mirror the DUT FF), then compare.
  task edge_and_check(input [127:0] what);
    begin
      // compute the independent golden D from CURRENT model state + inputs
      d_exp = (SIN & DCDG & DCDF & GPE)
            | (DCDG & DCDFN & sts_model)
            | (VINN & DCDF & DCDGN);
`ifdef TEETH_TEST
      d_exp = ~d_exp;   // deliberately wrong -> harness must FAIL
`endif
      #1 CK = 1; #1;    // rising edge captures
      sts_model = (SIN & DCDG & DCDF & GPE)   // true golden (never perturbed)
                | (DCDG & DCDFN & sts_model)
                | (VINN & DCDF & DCDGN);
      checks = checks + 1;
      if (STS !== d_exp) begin
        errors = errors + 1;
        $display("FAIL %0s: STS exp=%b got=%b (DCDF=%b DCDFN=%b DCDG=%b DCDGN=%b GPE=%b SIN=%b VINN=%b)",
                 what, d_exp, STS, DCDF, DCDFN, DCDG, DCDGN, GPE, SIN, VINN);
      end
      #1 CK = 0; #1;
    end
  endtask

  integer i;
  reg pass_load0, pass_load1, pass_rdvect, pass_mclr, pass_hold;

  initial begin
    $dumpfile("CGA_INTR_CNTLR_VECGEN_STAT_SBIT_tb.vcd");
    $dumpvars(0, CGA_INTR_CNTLR_VECGEN_STAT_SBIT_tb);

    // ---- Named operation spotlights (the four Am2914 cell operations) ----
    // MCLR (clear): DCDG=0, DCDF=0
    DCDF=0; DCDFN=1; DCDG=0; DCDGN=1; GPE=1; SIN=1; VINN=1;
    edge_and_check("MCLR->clear");           pass_mclr = (STS === 1'b0);

    // LDSTAT load 1: DCDG=1, DCDF=1, GPE=1, SIN=1
    DCDF=1; DCDFN=0; DCDG=1; DCDGN=0; GPE=1; SIN=1; VINN=0;
    edge_and_check("LDSTAT load SIN=1");     pass_load1 = (STS === 1'b1);

    // idle/hold: DCDG=1, DCDF=0 -> must hold the 1 loaded above
    DCDF=0; DCDFN=1; DCDG=1; DCDGN=0; GPE=1; SIN=0; VINN=0;
    edge_and_check("idle->hold(1)");         pass_hold = (STS === 1'b1);

    // LDSTAT load 0
    DCDF=1; DCDFN=0; DCDG=1; DCDGN=0; GPE=1; SIN=0; VINN=1;
    edge_and_check("LDSTAT load SIN=0");     pass_load0 = (STS === 1'b0);

    // RDVECT fence: DCDG=0, DCDGN=1, DCDF=1, VINN=1 -> load the vector+1 bit
    DCDF=1; DCDFN=0; DCDG=0; DCDGN=1; GPE=0; SIN=0; VINN=1;
    edge_and_check("RDVECT->load VINN=1");   pass_rdvect = (STS === 1'b1);

    // ---- Exhaustive raw-boolean sweep over all 128 input combinations ----
    // (re-seed model to a known state first)
    DCDF=0; DCDFN=0; DCDG=0; DCDGN=0; GPE=0; SIN=0; VINN=0;
    edge_and_check("reseed");
    for (i = 0; i < 128; i = i + 1) begin
      {DCDF,DCDFN,DCDG,DCDGN,GPE,SIN,VINN} = i[6:0];
      edge_and_check("exhaustive");
    end

    $display("spotlights: MCLR=%b LDSTAT1=%b hold=%b LDSTAT0=%b RDVECT=%b",
             pass_mclr, pass_load1, pass_hold, pass_load0, pass_rdvect);
    $display("checks=%0d errors=%0d", checks, errors);
    if (errors == 0) $display("TB_RESULT: PASS");
    else             $display("TB_RESULT: FAIL (%0d errors)", errors);
    $finish;
  end

endmodule

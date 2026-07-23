/**************************************************************************************************
** ND120 CGA (CPU Gate Array / DELILAH) - unit test                                              **
** CGA_INTR_CNTLR_VECGEN_OSMUX  (output status mux -> PICS_2_0, schematic p.89)                    **
**                                                                                               **
** DUT contract: PICS_2_0 is the selected group's status, a 2:1 mux by the active-low selects:    **
**   selHI = (~HIGSN) & (~OESN)                                                                    **
**   selLO = (~LOGSN) & (~OESN)                                                                    **
**   PICS  = (selHI ? HISTAT : 0) | (selLO ? LOSTAT : 0)   (both deselected -> 0)                  **
** Must pass the selected group's status UNCHANGED for all 8 values.                               **
**                                                                                               **
** Self-checking: golden computed INDEPENDENTLY as the behavioural mux above, swept over all 8    **
** select combinations x all 8x8 (HISTAT,LOSTAT) pairs. Named passthrough spotlights confirm      **
** HI-select gives HISTAT and LO-select gives LOSTAT for every value 0..7.                         **
**                                                                                               **
** Teeth: compile with -DTEETH_TEST to perturb the expected value -> harness MUST report FAIL.     **
**                                                                                               **
** Compile (from repo Verilog/):                                                                  **
**   iverilog -g2012 -o /tmp/tb_osmux -y Shared/logisim -y Shared/support -y Shared/ndlib \       **
**     DELILAH-CPU/CGA_INTR/circuit/CGA_INTR_CNTLR_VECGEN_OSMUX.v \                                **
**     DELILAH-CPU/CGA_INTR/sim/CGA_INTR_CNTLR_VECGEN_OSMUX_tb.v && vvp /tmp/tb_osmux              **
**                                                                                               **
** Last reviewed: 15-JUL-2026                                                                     **
***************************************************************************************************/
`timescale 1ns / 1ps

module CGA_INTR_CNTLR_VECGEN_OSMUX_tb;

  reg        HIGSN = 1;
  reg  [2:0] HISTAT_2_0 = 0;
  reg        LOGSN = 1;
  reg  [2:0] LOSTAT_2_0 = 0;
  reg        OESN = 1;
  wire [2:0] PICS_2_0;

  CGA_INTR_CNTLR_VECGEN_OSMUX dut (
      .HIGSN     (HIGSN),
      .HISTAT_2_0(HISTAT_2_0),
      .LOGSN     (LOGSN),
      .LOSTAT_2_0(LOSTAT_2_0),
      .OESN      (OESN),
      .PICS_2_0  (PICS_2_0)
  );

  integer errors = 0;
  integer checks = 0;
  integer sel, hi, lo;
  reg       selHI, selLO;
  reg [2:0] exp;
  reg       pass_hi_pass, pass_lo_pass;

  task do_check(input [127:0] what);
    begin
      #1;
      selHI = (~HIGSN) & (~OESN);
      selLO = (~LOGSN) & (~OESN);
      exp   = (selHI ? HISTAT_2_0 : 3'b000) | (selLO ? LOSTAT_2_0 : 3'b000);
`ifdef TEETH_TEST
      exp   = exp ^ 3'b001;   // deliberately wrong -> harness must FAIL
`endif
      checks = checks + 1;
      if (PICS_2_0 !== exp) begin
        errors = errors + 1;
        $display("FAIL %0s sel(HIGSN,LOGSN,OESN)=%b%b%b HISTAT=%0d LOSTAT=%0d : PICS exp=%0d got=%0d",
                 what, HIGSN, LOGSN, OESN, HISTAT_2_0, LOSTAT_2_0, exp, PICS_2_0);
      end
    end
  endtask

  integer k;

  initial begin
    $dumpfile("CGA_INTR_CNTLR_VECGEN_OSMUX_tb.vcd");
    $dumpvars(0, CGA_INTR_CNTLR_VECGEN_OSMUX_tb);

    // ---- Named passthrough spotlights: HI-select must pass HISTAT unchanged ----
    pass_hi_pass = 1'b1;
    HIGSN=0; LOGSN=1; OESN=0;           // select HI group
    for (k = 0; k < 8; k = k + 1) begin
      HISTAT_2_0 = k[2:0]; LOSTAT_2_0 = (k+3)%8;   // LOSTAT distinct, must be ignored
      do_check("HI passthrough");
      if (PICS_2_0 !== k[2:0]) pass_hi_pass = 1'b0;
    end

    // ---- LO-select must pass LOSTAT unchanged ----
    pass_lo_pass = 1'b1;
    HIGSN=1; LOGSN=0; OESN=0;           // select LO group
    for (k = 0; k < 8; k = k + 1) begin
      LOSTAT_2_0 = k[2:0]; HISTAT_2_0 = (k+3)%8;   // HISTAT distinct, must be ignored
      do_check("LO passthrough");
      if (PICS_2_0 !== k[2:0]) pass_lo_pass = 1'b0;
    end

    // ---- Exhaustive over all selects x all status pairs ----
    for (sel = 0; sel < 8; sel = sel + 1) begin
      {HIGSN, LOGSN, OESN} = sel[2:0];
      for (hi = 0; hi < 8; hi = hi + 1)
        for (lo = 0; lo < 8; lo = lo + 1) begin
          HISTAT_2_0 = hi[2:0];
          LOSTAT_2_0 = lo[2:0];
          do_check("exhaustive");
        end
    end

    $display("spotlights: HI-passthrough=%b LO-passthrough=%b", pass_hi_pass, pass_lo_pass);
    $display("checks=%0d errors=%0d", checks, errors);
    if (errors == 0) $display("TB_RESULT: PASS");
    else             $display("TB_RESULT: FAIL (%0d errors)", errors);
    $finish;
  end

endmodule

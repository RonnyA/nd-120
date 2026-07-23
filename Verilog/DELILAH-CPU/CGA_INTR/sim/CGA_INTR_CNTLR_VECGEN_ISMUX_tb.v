/**************************************************************************************************
** ND120 CGA (CPU Gate Array / DELILAH) - unit test                                              **
** CGA_INTR_CNTLR_VECGEN_ISMUX  (input-select mux for the status register, schematic p.85)         **
**                                                                                               **
** DUT contract: selects each group's S-bus (SIN) source between the IDB-write value FIDBO_2_0    **
** and the group's own status feedback (HISTAT/LOSTAT):                                            **
**   selHI = (~HIGSN) & (~OESN)   ->  HISIN = selHI ? HISTAT : FIDBO                               **
**   selLO = (~LOGSN) & (~OESN)   ->  LOSIN = selLO ? LOSTAT : FIDBO                               **
** (HIGSN/LOGSN/OESN are active-low group/output selects.)                                         **
**                                                                                               **
** Self-checking: golden computed INDEPENDENTLY as the behavioural 2:1 mux above, swept over all  **
** 8 select combinations x all data patterns (FIDBO x HISTAT, LOSTAT derived distinct) so a wrong  **
** select polarity OR a wrong data source is caught. Prints "TB_RESULT: PASS/FAIL".               **
**                                                                                               **
** Teeth: compile with -DTEETH_TEST to perturb the expected value -> harness MUST report FAIL.     **
**                                                                                               **
** Compile (from repo Verilog/):                                                                  **
**   iverilog -g2012 -o /tmp/tb_ismux -y Shared/logisim -y Shared/support -y Shared/ndlib \       **
**     DELILAH-CPU/CGA_INTR/circuit/CGA_INTR_CNTLR_VECGEN_ISMUX.v \                                **
**     DELILAH-CPU/CGA_INTR/sim/CGA_INTR_CNTLR_VECGEN_ISMUX_tb.v && vvp /tmp/tb_ismux              **
**                                                                                               **
** Last reviewed: 15-JUL-2026                                                                     **
***************************************************************************************************/
`timescale 1ns / 1ps

module CGA_INTR_CNTLR_VECGEN_ISMUX_tb;

  reg  [2:0] FIDBO_2_0 = 0;
  reg        HIGSN = 1;
  reg  [2:0] HISTAT_2_0 = 0;
  reg        LOGSN = 1;
  reg  [2:0] LOSTAT_2_0 = 0;
  reg        OESN = 1;
  wire [2:0] HISIN_2_0;
  wire [2:0] LOSIN_2_0;

  CGA_INTR_CNTLR_VECGEN_ISMUX dut (
      .FIDBO_2_0 (FIDBO_2_0),
      .HIGSN     (HIGSN),
      .HISTAT_2_0(HISTAT_2_0),
      .LOGSN     (LOGSN),
      .LOSTAT_2_0(LOSTAT_2_0),
      .OESN      (OESN),
      .HISIN_2_0 (HISIN_2_0),
      .LOSIN_2_0 (LOSIN_2_0)
  );

  integer errors = 0;
  integer checks = 0;
  integer sel, fd, ht;
  reg       selHI, selLO;
  reg [2:0] exp_hi, exp_lo;

  initial begin
    $dumpfile("CGA_INTR_CNTLR_VECGEN_ISMUX_tb.vcd");
    $dumpvars(0, CGA_INTR_CNTLR_VECGEN_ISMUX_tb);

    for (sel = 0; sel < 8; sel = sel + 1) begin
      {HIGSN, LOGSN, OESN} = sel[2:0];
      for (fd = 0; fd < 8; fd = fd + 1) begin
        for (ht = 0; ht < 8; ht = ht + 1) begin
          FIDBO_2_0  = fd[2:0];
          HISTAT_2_0 = ht[2:0];
          LOSTAT_2_0 = (ht + 5) % 8;   // distinct from HISTAT so mis-source shows
          #1;
          // independent golden
          selHI  = (~HIGSN) & (~OESN);
          selLO  = (~LOGSN) & (~OESN);
          exp_hi = selHI ? HISTAT_2_0 : FIDBO_2_0;
          exp_lo = selLO ? LOSTAT_2_0 : FIDBO_2_0;
`ifdef TEETH_TEST
          exp_hi = exp_hi ^ 3'b001;   // deliberately wrong -> harness must FAIL
`endif
          checks = checks + 1;
          if (HISIN_2_0 !== exp_hi || LOSIN_2_0 !== exp_lo) begin
            errors = errors + 1;
            $display("FAIL sel(HIGSN,LOGSN,OESN)=%b FIDBO=%0d HISTAT=%0d LOSTAT=%0d : HISIN exp=%0d got=%0d  LOSIN exp=%0d got=%0d",
                     sel[2:0], FIDBO_2_0, HISTAT_2_0, LOSTAT_2_0,
                     exp_hi, HISIN_2_0, exp_lo, LOSIN_2_0);
          end
        end
      end
    end

    $display("checks=%0d errors=%0d", checks, errors);
    if (errors == 0) $display("TB_RESULT: PASS");
    else             $display("TB_RESULT: FAIL (%0d errors)", errors);
    $finish;
  end

endmodule

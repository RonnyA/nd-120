/**************************************************************************************************
** ND120 CGA (CPU Gate Array / DELILAH) - unit test                                              **
** CGA_INTR_CNTLR_VECGEN_CMP  (dual magnitude comparator, schematic p.88)                         **
**                                                                                               **
** DUT contract: two MAGCMP instances (VGES = V >= S):                                            **
**   HIVGES = (HIVEC_2_0 >= HISTAT_2_0)                                                           **
**   LOVGES = (LOVEC_2_0 >= LOSTAT_2_0)                                                           **
** These gate whether a detected interrupt vector out-ranks the current status fence.             **
**                                                                                               **
** Self-checking: golden (V >= S) computed INDEPENDENTLY. Exhaustive over ALL 64 HI pairs x ALL   **
** 64 LO pairs (4096 combos) - proves the two comparators are independent and each correct.       **
** Prints "TB_RESULT: PASS/FAIL".                                                                 **
**                                                                                               **
** Compile (from repo Verilog/):                                                                  **
**   iverilog -g2012 -o /tmp/tb_cmp \                                                             **
**     -y Shared/logisim -y Shared/support -y Shared/ndlib \                                      **
**     DELILAH-CPU/CGA_INTR/circuit/CGA_INTR_CNTLR_VECGEN_CMP.v \                                  **
**     DELILAH-CPU/CGA_INTR/circuit/CGA_INTR_CNTLR_VECGEN_CMP_MAGCMP.v \                           **
**     DELILAH-CPU/CGA_INTR/sim/CGA_INTR_CNTLR_VECGEN_CMP_tb.v && vvp /tmp/tb_cmp                  **
**                                                                                               **
** Last reviewed: 15-JUL-2026                                                                     **
***************************************************************************************************/
`timescale 1ns / 1ps

module CGA_INTR_CNTLR_VECGEN_CMP_tb;

  reg  [2:0] HISTAT_2_0, HIVEC_2_0, LOSTAT_2_0, LOVEC_2_0;
  wire       HIVGES, LOVGES;

  CGA_INTR_CNTLR_VECGEN_CMP dut (
      .HISTAT_2_0(HISTAT_2_0),
      .HIVEC_2_0 (HIVEC_2_0),
      .LOSTAT_2_0(LOSTAT_2_0),
      .LOVEC_2_0 (LOVEC_2_0),
      .HIVGES    (HIVGES),
      .LOVGES    (LOVGES)
  );

  integer hv, hs, lv, ls;
  integer errors = 0;
  integer checks = 0;
  reg     ehi, elo;

  initial begin
    // Exhaustive: all 64 HI pairs crossed with all 64 LO pairs.
    for (hv = 0; hv < 8; hv = hv + 1)
      for (hs = 0; hs < 8; hs = hs + 1)
        for (lv = 0; lv < 8; lv = lv + 1)
          for (ls = 0; ls < 8; ls = ls + 1) begin
            HIVEC_2_0 = hv[2:0]; HISTAT_2_0 = hs[2:0];
            LOVEC_2_0 = lv[2:0]; LOSTAT_2_0 = ls[2:0];
            #1;
            ehi = (hv >= hs) ? 1'b1 : 1'b0;   // independent golden
            elo = (lv >= ls) ? 1'b1 : 1'b0;
            checks = checks + 1;
            if (HIVGES !== ehi || LOVGES !== elo) begin
              errors = errors + 1;
              if (errors <= 20)
                $display("FAIL HV=%0d HS=%0d LV=%0d LS=%0d: HIVGES e=%b g=%b LOVGES e=%b g=%b",
                         hv, hs, lv, ls, ehi, HIVGES, elo, LOVGES);
            end
          end

    $display("checks=%0d errors=%0d", checks, errors);
    if (errors == 0) $display("TB_RESULT: PASS");
    else             $display("TB_RESULT: FAIL (%0d errors)", errors);
    $finish;
  end

endmodule

/**************************************************************************************************
** ND120 CGA (CPU Gate Array / DELILAH) - unit test                                              **
** CGA_INTR_CNTLR_VECGEN_CMP_MAGCMP  (3-bit magnitude comparator, schematic p.88)                 **
**                                                                                               **
** DUT contract: VGES = (V_2_0 >= S_2_0)   (unsigned 3-bit compare).                              **
**   Gates VGES into every interrupt dispatch, so correctness is CRITICAL.                        **
**   Ground truth (docs/RUN-level14-livelock-analysis.md): hand-verified V=6 vs S=5/6/7.          **
**                                                                                               **
** Self-checking: golden = (V >= S) computed INDEPENDENTLY in the tb, exhaustive over ALL 64      **
** (V,S) pairs, i.e. the full 8x8 >= truth table. Prints "TB_RESULT: PASS/FAIL".                  **
**                                                                                               **
** Compile (from repo Verilog/):                                                                  **
**   iverilog -g2012 -o /tmp/tb_magcmp \                                                          **
**     -y Shared/logisim -y Shared/support -y Shared/ndlib \                                      **
**     DELILAH-CPU/CGA_INTR/circuit/CGA_INTR_CNTLR_VECGEN_CMP_MAGCMP.v \                           **
**     DELILAH-CPU/CGA_INTR/sim/CGA_INTR_CNTLR_VECGEN_CMP_MAGCMP_tb.v && vvp /tmp/tb_magcmp        **
**                                                                                               **
** Last reviewed: 15-JUL-2026                                                                     **
***************************************************************************************************/
`timescale 1ns / 1ps

module CGA_INTR_CNTLR_VECGEN_CMP_MAGCMP_tb;

  reg  [2:0] V_2_0;
  reg  [2:0] S_2_0;
  wire       VGES;

  CGA_INTR_CNTLR_VECGEN_CMP_MAGCMP dut (
      .S_2_0(S_2_0),
      .V_2_0(V_2_0),
      .VGES (VGES)
  );

  integer v, s;
  integer errors = 0;
  integer checks = 0;
  reg     exp;
  reg     doc65, doc66, doc67;   // doc-cited spotlight cases V=6 vs S=5/6/7

  initial begin
    doc65 = 1'bx; doc66 = 1'bx; doc67 = 1'bx;
    for (v = 0; v < 8; v = v + 1) begin
      for (s = 0; s < 8; s = s + 1) begin
        V_2_0 = v[2:0];
        S_2_0 = s[2:0];
        #1;
        exp    = (v >= s) ? 1'b1 : 1'b0;   // independent golden
        checks = checks + 1;
        if (VGES !== exp) begin
          errors = errors + 1;
          $display("FAIL V=%0d S=%0d: VGES exp=%b got=%b", v, s, exp, VGES);
        end
        // record the doc-cited spotlight cases as measured from the DUT
        if (v == 6 && s == 5) doc65 = VGES;
        if (v == 6 && s == 6) doc66 = VGES;
        if (v == 6 && s == 7) doc67 = VGES;
      end
    end

    $display("doc cases (measured): V6>=S5=%b V6>=S6=%b V6>=S7=%b (expect 1 1 0)",
             doc65, doc66, doc67);
    $display("checks=%0d errors=%0d", checks, errors);
    if (errors == 0) $display("TB_RESULT: PASS");
    else             $display("TB_RESULT: FAIL (%0d errors)", errors);
    $finish;
  end

endmodule

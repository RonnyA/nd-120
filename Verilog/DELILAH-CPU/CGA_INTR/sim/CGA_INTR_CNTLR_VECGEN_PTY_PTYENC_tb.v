/**************************************************************************************************
** ND120 CGA (CPU Gate Array / DELILAH) - unit test                                              **
** CGA_INTR_CNTLR_VECGEN_PTY_PTYENC  (priority encoder, schematic p.83)                           **
**                                                                                               **
** DUT contract (active-LOW requests): RN[7:0], RN[i]==0 means "level i requesting".              **
**   DET   = 1 iff any request is active (any RN bit == 0)                                        **
**   V_2_0 = index of the HIGHEST-numbered active-low request bit (Am2914 priority: high wins)     **
**           when no request is active, V_2_0 = 0.                                                **
**                                                                                               **
** Self-checking: golden is computed INDEPENDENTLY here (scan bits 7..0, first low wins) - it     **
** does NOT reuse the DUT gate network. Exhaustive over ALL 256 RN patterns.                       **
** Prints "TB_RESULT: PASS" or "TB_RESULT: FAIL (<n> errors)".                                    **
**                                                                                               **
** Compile (from repo Verilog/):                                                                  **
**   iverilog -g2012 -o /tmp/tb_ptyenc \                                                          **
**     -y Shared/logisim -y Shared/support -y Shared/ndlib \                                      **
**     DELILAH-CPU/CGA_INTR/circuit/CGA_INTR_CNTLR_VECGEN_PTY_PTYENC.v \                           **
**     DELILAH-CPU/CGA_INTR/sim/CGA_INTR_CNTLR_VECGEN_PTY_PTYENC_tb.v && vvp /tmp/tb_ptyenc        **
**                                                                                               **
** Last reviewed: 15-JUL-2026                                                                     **
***************************************************************************************************/
`timescale 1ns / 1ps

module CGA_INTR_CNTLR_VECGEN_PTY_PTYENC_tb;

  reg  [7:0] RN;
  wire       DET;
  wire [2:0] V_2_0;

  CGA_INTR_CNTLR_VECGEN_PTY_PTYENC dut (
      .RN   (RN),
      .DET  (DET),
      .V_2_0(V_2_0)
  );

  // Independent golden priority-encode: highest active-low bit wins.
  // Returns {det, vec} packed as [3:0] = {det, v[2:0]}.
  function [3:0] golden;
    input [7:0] rn;
    integer i;
    reg        det;
    reg  [2:0] vec;
    begin
      det = 1'b0;
      vec = 3'b000;
      // scan from highest index down; first active-low (rn[i]==0) sets vec and det.
      for (i = 7; i >= 0; i = i - 1) begin
        if (rn[i] == 1'b0 && det == 1'b0) begin
          det = 1'b1;
          vec = i[2:0];
        end
      end
      golden = {det, vec};
    end
  endfunction

  integer    n;
  integer    errors = 0;
  reg  [3:0] g;
  reg        exp_det;
  reg  [2:0] exp_vec;

  initial begin
    for (n = 0; n < 256; n = n + 1) begin
      RN = n[7:0];
      #1;
      g       = golden(RN);
      exp_det = g[3];
      exp_vec = g[2:0];
      if (DET !== exp_det || V_2_0 !== exp_vec) begin
        errors = errors + 1;
        if (errors <= 20)
          $display("FAIL RN=%b (active=%b): DET exp=%b got=%b  V exp=%0d got=%0d",
                   RN, ~RN, exp_det, DET, exp_vec, V_2_0);
      end
    end

    $display("checks=256 errors=%0d", errors);
    if (errors == 0) $display("TB_RESULT: PASS");
    else             $display("TB_RESULT: FAIL (%0d errors)", errors);
    $finish;
  end

endmodule

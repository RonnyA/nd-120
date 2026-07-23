/**************************************************************************************************
** ND120 CGA (CPU Gate Array / DELILAH) - unit test                                              **
** CGA_INTR_CNTLR_IRGEL_VMUX  (vector mux -> PICV_2_0, schematic p.95)                            **
**                                                                                               **
** DUT contract (derived from the gate netlist, NOT assumed):                                    **
**   For each bit i in {0,1,2}:                                                                   **
**     GATES: hi_i = NAND(HIVEC[i], HVE)   lo_i = NAND(LOVEC[i], LVE)                             **
**            PICV[i] = OR(bubble hi_i, bubble lo_i) = (~hi_i)|(~lo_i)                            **
**                    = (HVE & HIVEC[i]) | (LVE & LOVEC[i])                                        **
**   So PICV = ({3{HVE}} & HIVEC) | ({3{LVE}} & LOVEC)  -- a bitwise OR of two gated vectors.     **
**   HVE-only  -> passes HIVEC.  LVE-only -> passes LOVEC.  both-off -> 0.  both-on -> bitwise OR. **
**                                                                                               **
** Self-checking: golden computed INDEPENDENTLY from the gate equation above, swept EXHAUSTIVELY  **
** over HIVEC(0..7) x LOVEC(0..7) x HVE x LVE = 256 cases, plus named spotlights.                 **
**                                                                                               **
** Teeth: compile with -DTEETH_TEST to perturb the expected value -> harness MUST report FAIL.    **
**                                                                                               **
** Compile (from repo Verilog/):                                                                  **
**   iverilog -g2012 -o /tmp/tb_vmux -y Shared/logisim -y Shared/support -y Shared/ndlib \        **
**     DELILAH-CPU/CGA_INTR/circuit/CGA_INTR_CNTLR_IRGEL_VMUX.v \                                  **
**     DELILAH-CPU/CGA_INTR/sim/CGA_INTR_CNTLR_IRGEL_VMUX_tb.v && vvp /tmp/tb_vmux                 **
**                                                                                               **
** Last reviewed: 15-JUL-2026                                                                     **
***************************************************************************************************/
`timescale 1ns / 1ps

module CGA_INTR_CNTLR_IRGEL_VMUX_tb;

  reg  [2:0] HIVEC_2_0 = 0;
  reg        HVE = 0;
  reg  [2:0] LOVEC_2_0 = 0;
  reg        LVE = 0;
  wire [2:0] PICV_2_0;

  CGA_INTR_CNTLR_IRGEL_VMUX dut (
      .HIVEC_2_0(HIVEC_2_0),
      .HVE      (HVE),
      .LOVEC_2_0(LOVEC_2_0),
      .LVE      (LVE),
      .PICV_2_0 (PICV_2_0)
  );

  integer errors = 0;
  integer checks = 0;
  integer hv, lv, hvec, lvec;
  reg [2:0] exp;
  reg spot_hi, spot_lo, spot_bothoff, spot_bothon;

  // Independent golden (NOT read from DUT wires): bitwise OR of the two gated vectors.
  function [2:0] golden(input [2:0] hivec, input hve, input [2:0] lovec, input lve);
    begin
      golden = ({3{hve}} & hivec) | ({3{lve}} & lovec);
    end
  endfunction

  task do_check(input [127:0] what);
    begin
      #1;
      exp = golden(HIVEC_2_0, HVE, LOVEC_2_0, LVE);
`ifdef TEETH_TEST
      exp = exp ^ 3'b001;   // deliberately wrong -> harness must FAIL
`endif
      checks = checks + 1;
      if (PICV_2_0 !== exp) begin
        errors = errors + 1;
        $display("FAIL %0s HVE=%b LVE=%b HIVEC=%0d LOVEC=%0d : PICV exp=%0d got=%0d",
                 what, HVE, LVE, HIVEC_2_0, LOVEC_2_0, exp, PICV_2_0);
      end
    end
  endtask

  integer k;

  initial begin
    $dumpfile("CGA_INTR_CNTLR_IRGEL_VMUX_tb.vcd");
    $dumpvars(0, CGA_INTR_CNTLR_IRGEL_VMUX_tb);

    // ---- Spotlight 1: HVE-only passes HIVEC unchanged for all 8 values ----
    spot_hi = 1'b1;
    HVE = 1; LVE = 0;
    for (k = 0; k < 8; k = k + 1) begin
      HIVEC_2_0 = k[2:0]; LOVEC_2_0 = (~k[2:0]);   // distinct LOVEC must be ignored
      do_check("HVE-only");
      if (PICV_2_0 !== k[2:0]) spot_hi = 1'b0;
    end

    // ---- Spotlight 2: LVE-only passes LOVEC unchanged for all 8 values ----
    spot_lo = 1'b1;
    HVE = 0; LVE = 1;
    for (k = 0; k < 8; k = k + 1) begin
      LOVEC_2_0 = k[2:0]; HIVEC_2_0 = (~k[2:0]);   // distinct HIVEC must be ignored
      do_check("LVE-only");
      if (PICV_2_0 !== k[2:0]) spot_lo = 1'b0;
    end

    // ---- Spotlight 3: both-off -> PICV must be 0 for all vectors ----
    spot_bothoff = 1'b1;
    HVE = 0; LVE = 0;
    for (k = 0; k < 8; k = k + 1) begin
      HIVEC_2_0 = k[2:0]; LOVEC_2_0 = (~k[2:0]);
      do_check("both-off");
      if (PICV_2_0 !== 3'b000) spot_bothoff = 1'b0;
    end

    // ---- Spotlight 4: both-on -> bitwise OR of the two vectors ----
    spot_bothon = 1'b1;
    HVE = 1; LVE = 1;
    for (k = 0; k < 8; k = k + 1) begin
      HIVEC_2_0 = k[2:0]; LOVEC_2_0 = (~k[2:0]);
      do_check("both-on");
      if (PICV_2_0 !== (k[2:0] | (~k[2:0]))) spot_bothon = 1'b0;  // == 3'b111
    end

    // ---- Exhaustive: HVE x LVE x HIVEC x LOVEC ----
    for (hv = 0; hv < 2; hv = hv + 1)
      for (lv = 0; lv < 2; lv = lv + 1)
        for (hvec = 0; hvec < 8; hvec = hvec + 1)
          for (lvec = 0; lvec < 8; lvec = lvec + 1) begin
            HVE = hv[0]; LVE = lv[0];
            HIVEC_2_0 = hvec[2:0]; LOVEC_2_0 = lvec[2:0];
            do_check("exhaustive");
          end

    $display("spotlights: HVE-only=%b LVE-only=%b both-off=%b both-on=%b",
             spot_hi, spot_lo, spot_bothoff, spot_bothon);
    $display("checks=%0d errors=%0d", checks, errors);
    if (errors == 0) $display("TB_RESULT: PASS");
    else             $display("TB_RESULT: FAIL (%0d errors)", errors);
    $finish;
  end

endmodule

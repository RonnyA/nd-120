/**************************************************************************************************
** ND120 CGA (CPU Gate Array / DELILAH) - unit test                                              **
** CGA_INTR_CNTLR_VECGEN_VHR  (vector-hold register, schematic p.86)                               **
**                                                                                               **
** DUT contract: six SCAN_FF cells latch HIVEC_2_0 / LOVEC_2_0 into HX_2_0 / LX_2_0 on the rising  **
** edge of MCLK. N is the SCAN_FF TE with TI tied to the cell's own Q (self-hold):                 **
**     N=0 : load   (HX <= HIVEC, LX <= LOVEC)                                                     **
**     N=1 : hold   (HX,LX unchanged)                                                              **
**   HX_2_0_N / LX_2_0_N are the bit-wise complements.                                             **
**                                                                                               **
** Self-checking: golden is an INDEPENDENT shadow register (load on N=0, hold on N=1). Verifies    **
** the vector loads faithfully for all 8 values AND is held unchanged across clocks while the      **
** input vector is churned. Also checks the _N complement outputs. Prints "TB_RESULT: PASS/FAIL". **
**                                                                                               **
** Teeth: compile with -DTEETH_TEST to perturb the expected value -> harness MUST report FAIL.     **
** MCLK_EN tied 0, FPGA_FF_MODE NOT defined -> original posedge-MCLK SCAN_FF behaviour.            **
**                                                                                               **
** Compile (from repo Verilog/):                                                                  **
**   iverilog -g2012 -o /tmp/tb_vhr -y Shared/logisim -y Shared/support -y Shared/ndlib \         **
**     DELILAH-CPU/CGA_INTR/circuit/CGA_INTR_CNTLR_VECGEN_VHR.v \                                  **
**     DELILAH-CPU/CGA_INTR/sim/CGA_INTR_CNTLR_VECGEN_VHR_tb.v && vvp /tmp/tb_vhr                  **
**                                                                                               **
** Last reviewed: 15-JUL-2026                                                                     **
***************************************************************************************************/
`timescale 1ns / 1ps

module CGA_INTR_CNTLR_VECGEN_VHR_tb;

  reg        MCLK = 0;
  reg        N    = 0;
  reg  [2:0] HIVEC_2_0 = 0;
  reg  [2:0] LOVEC_2_0 = 0;
  wire [2:0] HX_2_0, HX_2_0_N, LX_2_0, LX_2_0_N;

  CGA_INTR_CNTLR_VECGEN_VHR dut (
      .sysclk   (1'b0),
      .MCLK_EN  (1'b0),
      .HIVEC_2_0(HIVEC_2_0),
      .LOVEC_2_0(LOVEC_2_0),
      .MCLK     (MCLK),
      .N        (N),
      .HX_2_0   (HX_2_0),
      .HX_2_0_N (HX_2_0_N),
      .LX_2_0   (LX_2_0),
      .LX_2_0_N (LX_2_0_N)
  );

  integer errors = 0;
  integer checks = 0;
  reg [2:0] hx_model = 0;    // independent shadow (SCAN_FF power-up = 0)
  reg [2:0] lx_model = 0;

  task do_clk;               // one rising MCLK edge (inputs already set)
    begin
      #2 MCLK = 1; #2 MCLK = 0; #1;
    end
  endtask

  task edge_and_check(input [127:0] what);
    reg [2:0] ehx, elx;
    begin
      // update independent model on the (modelled) rising edge
      if (N == 1'b0) begin hx_model = HIVEC_2_0; lx_model = LOVEC_2_0; end
      // N==1 -> hold
      do_clk;
      ehx = hx_model; elx = lx_model;
`ifdef TEETH_TEST
      ehx = ehx ^ 3'b001;   // deliberately wrong -> harness must FAIL
`endif
      checks = checks + 1;
      if (HX_2_0 !== ehx || LX_2_0 !== elx) begin
        errors = errors + 1;
        $display("FAIL %0s: HX exp=%0d got=%0d  LX exp=%0d got=%0d (N=%b HIVEC=%0d LOVEC=%0d)",
                 what, ehx, HX_2_0, elx, LX_2_0, N, HIVEC_2_0, LOVEC_2_0);
      end
      // complement outputs must always mirror
      if (HX_2_0_N !== ~HX_2_0 || LX_2_0_N !== ~LX_2_0) begin
        errors = errors + 1;
        $display("FAIL %0s complement: HX=%b HX_N=%b LX=%b LX_N=%b",
                 what, HX_2_0, HX_2_0_N, LX_2_0, LX_2_0_N);
      end
    end
  endtask

  integer v;

  initial begin
    $dumpfile("CGA_INTR_CNTLR_VECGEN_VHR_tb.vcd");
    $dumpvars(0, CGA_INTR_CNTLR_VECGEN_VHR_tb);

    // ---- Load faithfulness: every value 0..7 loads exactly (N=0) ----
    for (v = 0; v < 8; v = v + 1) begin
      N = 0; HIVEC_2_0 = v[2:0]; LOVEC_2_0 = (v + 4) % 8;
      edge_and_check("load");
    end

    // ---- Hold across clocks: freeze, then churn the input vector ----
    N = 0; HIVEC_2_0 = 3'd6; LOVEC_2_0 = 3'd1; edge_and_check("seed for hold");
    N = 1;
    HIVEC_2_0 = 3'd0; LOVEC_2_0 = 3'd7; edge_and_check("hold clk1 (input churned)");
    HIVEC_2_0 = 3'd5; LOVEC_2_0 = 3'd2; edge_and_check("hold clk2 (input churned)");
    HIVEC_2_0 = 3'd3; LOVEC_2_0 = 3'd4; edge_and_check("hold clk3 (input churned)");

    // ---- Release hold: loads the current input again ----
    N = 0; HIVEC_2_0 = 3'd2; LOVEC_2_0 = 3'd5; edge_and_check("reload after hold");

    $display("checks=%0d errors=%0d", checks, errors);
    if (errors == 0) $display("TB_RESULT: PASS");
    else             $display("TB_RESULT: FAIL (%0d errors)", errors);
    $finish;
  end

endmodule

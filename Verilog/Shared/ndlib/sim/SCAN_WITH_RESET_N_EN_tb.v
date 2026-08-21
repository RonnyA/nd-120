/****************************************************************************
** SCAN_WITH_RESET_N_EN - self-checking functional testbench, both modes   **
**                                                                         **
**   USE_ENABLE=0 (default) wraps SCAN_WITH_RESET_N: posedge CLK,          **
**       d = TE ? TI : D, R_n DEAD, plus the one-delta input pipeline.     **
**   USE_ENABLE=1 : posedge sysclk, capture TE ? TI : D while EN is high.  **
**       R_n is explicitly lint-waived and unused. CLK unused.             **
**                                                                         **
** R_n IS DEAD IN BOTH MODES, and that is deliberate: mode 1 was written   **
** to replicate the ACTUAL behaviour of mode 0, where R_n never reaches    **
** anything because SCAN_WITH_RESET_N instantiates D_FLIPFLOP with the     **
** default ACTIVE_ASYNC=0 (whose synchronous branch ignores its reset      **
** pin) and passes R_n UNINVERTED to that pin. The wrapper's own header    **
** records the same finding. This tb asserts R_n has no effect in EITHER   **
** mode, so a future fix that gives R_n meaning cannot slip in silently -  **
** it must break these checks and be signed off.                           **
**                                                                         **
** THE ONE PLACE THE TWO MODES REALLY DIFFER is not the enable but the     **
** one-delta pipeline inside SCAN_WITH_RESET_N: data changing in the SAME  **
** simulation instant as the clock edge is captured as its OLD value in    **
** mode 0 and as its NEW value in mode 1. Asserted per mode.               **
**                                                                         **
** Also covered: ENABLE HELD LOW across many sysclk edges, NO clock edge   **
** of any kind, the TE mux both ways, the falling edge doing nothing, and  **
** data churning between edges.                                            **
**                                                                         **
** BUILD MODE: no `ifdef - latch mode and -DFPGA_FF_MODE are identical.    **
**                                                                         **
** Run: cd Verilog/Shared/ndlib/sim && make test-scanrsten                 **
**                                                                         **
** Last reviewed: 20-AUG-2026                                              **
** Ronny Hansen                                                            **
*****************************************************************************/
`timescale 1ns / 1ps
`default_nettype none

module SCAN_WITH_RESET_N_EN_tb;

  integer checks = 0;
  integer errors = 0;

`define CHK(NM, GOT, EXP) \
  begin \
    checks = checks + 1; \
    if ((GOT) !== (EXP)) begin \
      errors = errors + 1; \
      $display("FAIL t=%0t %0s : got=%b expected=%b", $time, NM, (GOT), (EXP)); \
    end \
  end

  reg sysclk = 1'b0;
  reg EN = 1'b1;
  reg CLK = 1'b0;
  reg D = 1'b0, TE = 1'b0, TI = 1'b0, R_n = 1'b1;

  wire q_m0, qn_m0;
  wire q_m1, qn_m1;

  SCAN_WITH_RESET_N_EN #(.USE_ENABLE(0)) U_M0 (
      .sysclk(sysclk), .EN(EN), .CLK(CLK), .D(D), .R_n(R_n),
      .TE(TE), .TI(TI), .Q(q_m0), .QN(qn_m0));

  SCAN_WITH_RESET_N_EN #(.USE_ENABLE(1)) U_M1 (
      .sysclk(sysclk), .EN(EN), .CLK(CLK), .D(D), .R_n(R_n),
      .TE(TE), .TI(TI), .Q(q_m1), .QN(qn_m1));

  task sys_tick; begin #5 sysclk = 1'b1; #5 sysclk = 1'b0; #1; end endtask
  task clk_rise; begin #5 CLK = 1'b1; #1; end endtask
  task clk_fall; begin #5 CLK = 1'b0; #1; end endtask
  task both;     begin #3; clk_rise; clk_fall; sys_tick; end endtask

  initial begin
    $dumpfile("SCAN_WITH_RESET_N_EN_tb.vcd");
    $dumpvars(0, SCAN_WITH_RESET_N_EN_tb);
  end

  initial begin
    #1;
    `CHK("power-up q_m0", q_m0, 1'b0)
    `CHK("power-up q_m1", q_m1, 1'b0)

    // ---- 1. NO EDGE OF ANY KIND ----
    D = 1'b1; #20;
    `CHK("no edge: q_m0 holds", q_m0, 1'b0)
    `CHK("no edge: q_m1 holds", q_m1, 1'b0)

    // ---- 2. each mode uses its own clock ----
    clk_rise;
    `CHK("posedge CLK: mode0 captures", q_m0, 1'b1)
    `CHK("posedge CLK: mode1 ignores the CLK pin", q_m1, 1'b0)
    clk_fall;
    sys_tick;
    `CHK("posedge sysclk with EN high: mode1 captures", q_m1, 1'b1)

    // ---- 3. R_n IS DEAD IN BOTH MODES ----
    R_n = 1'b0; #10;
    `CHK("R_n low, no edge: mode0 NOT cleared", q_m0, 1'b1)
    `CHK("R_n low, no edge: mode1 NOT cleared", q_m1, 1'b1)
    both;
    `CHK("R_n low across an edge: mode0 still loads D=1", q_m0, 1'b1)
    `CHK("R_n low across an edge: mode1 still loads D=1", q_m1, 1'b1)
    D = 1'b0; both;
    `CHK("R_n low: mode0 simply keeps loading D", q_m0, 1'b0)
    `CHK("R_n low: mode1 simply keeps loading D", q_m1, 1'b0)
    D = 1'b1; TE = 1'b1; TI = 1'b1; both;
    `CHK("R_n low on the scan path: mode0 loads TI", q_m0, 1'b1)
    `CHK("R_n low on the scan path: mode1 loads TI", q_m1, 1'b1)
    TE = 1'b0; R_n = 1'b1; #5;
    `CHK("releasing R_n changes nothing: mode0", q_m0, 1'b1)
    `CHK("releasing R_n changes nothing: mode1", q_m1, 1'b1)

    // ---- 4. ENABLE HELD LOW: mode1 frozen, mode0 unaffected ----
    EN = 1'b0; D = 1'b0;
    sys_tick; sys_tick; sys_tick;
    `CHK("mode1 EN held low: no capture", q_m1, 1'b1)
    #3; clk_rise; clk_fall;
    `CHK("mode0 does not care about EN", q_m0, 1'b0)
    EN = 1'b1; sys_tick;
    `CHK("mode1 captures once re-enabled", q_m1, 1'b0)

    // ---- 5. the TE mux both ways ----
    D = 1'b0; TE = 1'b1; TI = 1'b1; both;
    `CHK("mode0 TE=1 takes TI", q_m0, 1'b1)
    `CHK("mode1 TE=1 takes TI", q_m1, 1'b1)
    D = 1'b1; TI = 1'b0; both;
    `CHK("mode0 TE=1 ignores D", q_m0, 1'b0)
    `CHK("mode1 TE=1 ignores D", q_m1, 1'b0)
    TE = 1'b0; D = 1'b1; TI = 1'b0; both;
    `CHK("mode0 TE=0 takes D", q_m0, 1'b1)
    `CHK("mode1 TE=0 takes D", q_m1, 1'b1)

    // ---- 6. the falling CLK edge must do nothing (mode 0) ----
    D = 1'b1; #3; clk_rise;
    `CHK("mode0 rising CLK captures", q_m0, 1'b1)
    D = 1'b0; clk_fall;
    `CHK("mode0 falling CLK does not capture", q_m0, 1'b1)

    // ---- 7. data churning between edges ----
    D = 1'b0; #2; D = 1'b1; #2; D = 1'b0; #2;
    clk_rise; clk_fall; sys_tick;
    `CHK("mode0: final settled D=0 captured", q_m0, 1'b0)
    `CHK("mode1: final settled D=0 captured", q_m1, 1'b0)

    // ---- 8. THE MODE DIFFERENCE: a same-instant data change ----
    D = 1'b0; #3; clk_rise; clk_fall; sys_tick;
    `CHK("both settled at 0 (mode0)", q_m0, 1'b0)
    `CHK("both settled at 0 (mode1)", q_m1, 1'b0)
    D = 1'b1; CLK = 1'b1; sysclk = 1'b1;    // same instant
    #1;
    `CHK("mode0 one-delta pipeline: captures the OLD value 0", q_m0, 1'b0)
    `CHK("mode1 has no such stage: captures the NEW value 1",  q_m1, 1'b1)
    CLK = 1'b0; sysclk = 1'b0; #3;
    clk_rise; clk_fall;
    `CHK("mode0 catches up on the next edge", q_m0, 1'b1)

    `CHK("qBar_m0 complement", qn_m0, ~q_m0)
    `CHK("qBar_m1 complement", qn_m1, ~q_m1)

    $display("SCAN_WITH_RESET_N_EN_tb: checks=%0d failures=%0d", checks, errors);
    if (errors == 0) $display("TB_RESULT: PASS");
    else $display("TB_RESULT: FAIL");
    $finish;
  end

endmodule
`default_nettype wire

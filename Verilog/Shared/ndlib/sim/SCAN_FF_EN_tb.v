/****************************************************************************
** SCAN_FF_EN - self-checking functional testbench, both modes             **
**                                                                         **
**   USE_ENABLE=0 (default) wraps SCAN_FF: posedge CLK, d = TE ? TI : D,   **
**       and - see below - a one-delta input pipeline. sysclk/EN unused.   **
**   USE_ENABLE=1 lives in the sysclk domain: posedge sysclk, capture      **
**       TE ? TI : D only while EN is high. The CLK pin is unused.         **
**                                                                         **
** There is no reset and no preset on this cell in either mode, so the     **
** set-and-reset-together case does not exist here (see                    **
** SCAN_WITH_SET_N_EN_tb.v for the variant that has one). What IS tested   **
** instead is the pair of things an equivalence test cannot see: ENABLE    **
** HELD LOW across many sysclk edges, and NO clock edge of any kind.       **
**                                                                         **
** ANOMALY, mode 0 only: SCAN_FF.v routes the mux output through           **
**     reg delayedD;  always @(s_ff_d_input) delayedD <= s_ff_d_input;     **
** a NON-BLOCKING assignment in a combinational block, which is a          **
** one-delta pipeline stage. Data that changes in the SAME simulation      **
** instant as the CLK rise is therefore NOT captured - the previous value  **
** is. Mode 1 has no such stage and takes the new value. This is the one   **
** place where the two modes genuinely differ in behaviour rather than in  **
** which edge they use, so it is asserted separately per mode.             **
**                                                                         **
** BUILD MODE: no `ifdef - latch mode and -DFPGA_FF_MODE are identical.    **
**                                                                         **
** Run: cd Verilog/Shared/ndlib/sim && make test-scanffen                  **
**                                                                         **
** Last reviewed: 20-AUG-2026                                              **
** Ronny Hansen                                                            **
*****************************************************************************/
`timescale 1ns / 1ps
`default_nettype none

module SCAN_FF_EN_tb;

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
  reg D = 1'b0, TE = 1'b0, TI = 1'b0;

  wire q_m0, qn_m0;
  wire q_m1, qn_m1;

  SCAN_FF_EN #(.USE_ENABLE(0)) U_M0 (
      .sysclk(sysclk), .EN(EN), .CLK(CLK), .D(D), .TE(TE), .TI(TI),
      .Q(q_m0), .QN(qn_m0));

  SCAN_FF_EN #(.USE_ENABLE(1)) U_M1 (
      .sysclk(sysclk), .EN(EN), .CLK(CLK), .D(D), .TE(TE), .TI(TI),
      .Q(q_m1), .QN(qn_m1));

  task sys_tick; begin #5 sysclk = 1'b1; #5 sysclk = 1'b0; #1; end endtask
  task clk_rise; begin #5 CLK = 1'b1; #1; end endtask
  task clk_fall; begin #5 CLK = 1'b0; #1; end endtask
  // settle the data first, then clock both domains
  task both;     begin #3; clk_rise; clk_fall; sys_tick; end endtask

  initial begin
    $dumpfile("SCAN_FF_EN_tb.vcd");
    $dumpvars(0, SCAN_FF_EN_tb);
  end

  initial begin
    #1;
    `CHK("power-up q_m0", q_m0, 1'b0)
    `CHK("power-up q_m1", q_m1, 1'b0)

    // ---- 1. NO EDGE OF ANY KIND ----
    D = 1'b1; TE = 1'b0; EN = 1'b1; #20;
    `CHK("no edge: q_m0 holds", q_m0, 1'b0)
    `CHK("no edge: q_m1 holds", q_m1, 1'b0)

    // ---- 2. each mode uses its own clock ----
    clk_rise;
    `CHK("posedge CLK: mode0 captures", q_m0, 1'b1)
    `CHK("posedge CLK: mode1 ignores the CLK pin", q_m1, 1'b0)
    clk_fall;
    sys_tick;
    `CHK("posedge sysclk with EN high: mode1 captures", q_m1, 1'b1)

    // ---- 3. ENABLE HELD LOW: mode1 frozen, mode0 unaffected ----
    EN = 1'b0; D = 1'b0;
    sys_tick; sys_tick; sys_tick;
    `CHK("mode1 EN held low: no capture", q_m1, 1'b1)
    #3; clk_rise; clk_fall;
    `CHK("mode0 does not care about EN", q_m0, 1'b0)
    EN = 1'b1; sys_tick;
    `CHK("mode1 captures once re-enabled", q_m1, 1'b0)

    // ---- 4. the TE mux, both ways, in both modes ----
    D = 1'b0; TE = 1'b1; TI = 1'b1; both;
    `CHK("mode0 TE=1 takes TI=1 while D=0", q_m0, 1'b1)
    `CHK("mode1 TE=1 takes TI=1 while D=0", q_m1, 1'b1)
    D = 1'b1; TI = 1'b0; both;
    `CHK("mode0 TE=1 takes TI=0 while D=1", q_m0, 1'b0)
    `CHK("mode1 TE=1 takes TI=0 while D=1", q_m1, 1'b0)
    TE = 1'b0; D = 1'b1; TI = 1'b0; both;
    `CHK("mode0 TE=0 takes D=1 while TI=0", q_m0, 1'b1)
    `CHK("mode1 TE=0 takes D=1 while TI=0", q_m1, 1'b1)
    TE = 1'b0; D = 1'b0; TI = 1'b1; both;
    `CHK("mode0 TE=0 takes D=0 while TI=1", q_m0, 1'b0)
    `CHK("mode1 TE=0 takes D=0 while TI=1", q_m1, 1'b0)

    // ---- 5. the falling CLK edge must do nothing (mode 0) ----
    D = 1'b1; #3; clk_rise;
    `CHK("mode0 rising CLK captures", q_m0, 1'b1)
    D = 1'b0; clk_fall;
    `CHK("mode0 falling CLK does not capture", q_m0, 1'b1)

    // ---- 6. data churning between edges ----
    D = 1'b1; #2; D = 1'b0; #2; D = 1'b1; #2;
    clk_rise;
    `CHK("mode0: final settled D=1 captured", q_m0, 1'b1)
    clk_fall;
    sys_tick;
    `CHK("mode1: final settled D=1 captured", q_m1, 1'b1)

    // ---- 7. THE MODE DIFFERENCE: a same-instant data change ----
    D = 1'b1; #3; clk_rise; clk_fall; sys_tick;
    `CHK("both settled at 1", q_m0, 1'b1)
    `CHK("both settled at 1 (mode1)", q_m1, 1'b1)
    D = 1'b0; CLK = 1'b1; sysclk = 1'b1;   // all in the same instant
    #1;
    `CHK("mode0 one-delta pipeline: captures the OLD value 1", q_m0, 1'b1)
    `CHK("mode1 has no such stage: captures the NEW value 0",  q_m1, 1'b0)
    CLK = 1'b0; sysclk = 1'b0; #3;
    clk_rise; clk_fall;
    `CHK("mode0 catches up on the next edge", q_m0, 1'b0)

    `CHK("qBar_m0 complement", qn_m0, ~q_m0)
    `CHK("qBar_m1 complement", qn_m1, ~q_m1)

    $display("SCAN_FF_EN_tb: checks=%0d failures=%0d", checks, errors);
    if (errors == 0) $display("TB_RESULT: PASS");
    else $display("TB_RESULT: FAIL");
    $finish;
  end

endmodule
`default_nettype wire

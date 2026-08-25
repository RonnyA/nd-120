/****************************************************************************
** SCAN_WITH_SET_N_EN - self-checking functional testbench, both modes     **
**                                                                         **
**   USE_ENABLE=0 (default) wraps SCAN_WITH_SET_N: posedge CLK,            **
**       d = TE ? TI : D, ASYNC active-low set via S_n (the original       **
**       inverts S_n into D_FLIPFLOP's ACTIVE_ASYNC preset), plus the      **
**       one-delta input pipeline described below.                         **
**   USE_ENABLE=1 : posedge sysclk or posedge (~S_n);                      **
**       ~S_n -> Q = 1, else capture TE ? TI : D while EN is high.         **
**       The CLK pin is unused. S_n stays ASYNCHRONOUS and, while held     **
**       low, overrides the enabled capture.                               **
**                                                                         **
** THIS IS THE VARIANT WHOSE SET PIN ACTUALLY WORKS. Its sibling           **
** SCAN_WITH_RESET_N_EN has a dead R_n; the difference is that this file   **
** inverts S_n and turns ACTIVE_ASYNC on, and that one does neither.       **
**                                                                         **
** SET AND CAPTURE TOGETHER: there is no reset pin to conflict with, but   **
** the equivalent race - S_n asserted in the same instant as the capturing **
** clock edge - is tested in both modes, and the SET wins in both.         **
** Releasing S_n is a FALLING edge on the internal preset and therefore    **
** produces no event: Q does not move until the next capture. Tested.      **
**                                                                         **
** POWER-UP NOTE: mode 1 declares its flop `reg q_r = 1'b1` under `ifdef   **
** YOSYS and `reg q_r = 1'b0` otherwise, because a Gowin GW2A flop's       **
** power-up value must equal its async-set value. iverilog and Verilator   **
** take the 0 branch, so both modes power up at 0 here and this tb         **
** asserts 0. A yosys/Gowin build would legitimately differ - that is why  **
** the difference is written down rather than assumed away.                **
**                                                                         **
** MODE DIFFERENCE: the one-delta pipeline in SCAN_WITH_SET_N means a data **
** change in the SAME simulation instant as the clock edge is captured as  **
** its OLD value in mode 0 and its NEW value in mode 1. Asserted per mode. **
**                                                                         **
** Also covered: ENABLE HELD LOW, NO clock edge of any kind, the TE mux    **
** both ways, the falling edge doing nothing, data churning between edges. **
**                                                                         **
** BUILD MODE: no `ifdef affecting behaviour here for iverilog - latch     **
** mode and -DFPGA_FF_MODE are identical. Both are run.                    **
**                                                                         **
** Run: cd Verilog/Shared/ndlib/sim && make test-scanseten                 **
**                                                                         **
** Last reviewed: 20-AUG-2026                                              **
** Ronny Hansen                                                            **
*****************************************************************************/
`timescale 1ns / 1ps
`default_nettype none

module SCAN_WITH_SET_N_EN_tb;

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
  reg D = 1'b0, TE = 1'b0, TI = 1'b0, S_n = 1'b1;

  wire q_m0, qn_m0;
  wire q_m1, qn_m1;

  SCAN_WITH_SET_N_EN #(.USE_ENABLE(0)) U_M0 (
      .sysclk(sysclk), .EN(EN), .CLK(CLK), .D(D), .S_n(S_n),
      .TE(TE), .TI(TI), .Q(q_m0), .QN(qn_m0));

  SCAN_WITH_SET_N_EN #(.USE_ENABLE(1)) U_M1 (
      .sysclk(sysclk), .EN(EN), .CLK(CLK), .D(D), .S_n(S_n),
      .TE(TE), .TI(TI), .Q(q_m1), .QN(qn_m1));

  task sys_tick; begin #5 sysclk = 1'b1; #5 sysclk = 1'b0; #1; end endtask
  task clk_rise; begin #5 CLK = 1'b1; #1; end endtask
  task clk_fall; begin #5 CLK = 1'b0; #1; end endtask
  task both;     begin #3; clk_rise; clk_fall; sys_tick; end endtask

  initial begin
    $dumpfile("SCAN_WITH_SET_N_EN_tb.vcd");
    $dumpvars(0, SCAN_WITH_SET_N_EN_tb);
  end

  initial begin
    #1;
    `CHK("power-up q_m0 (S_n starts high)", q_m0, 1'b0)
    `CHK("power-up q_m1 (non-YOSYS init 0)", q_m1, 1'b0)

    // ---- 1. NO EDGE OF ANY KIND, S_n high ----
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

    // ---- 3. ASYNC SET works in BOTH modes, with no clock edge ----
    D = 1'b0; both;
    `CHK("cleared before the async-set test: mode0", q_m0, 1'b0)
    `CHK("cleared before the async-set test: mode1", q_m1, 1'b0)
    S_n = 1'b0; #10;
    `CHK("S_n low sets mode0 with NO clock edge", q_m0, 1'b1)
    `CHK("S_n low sets mode1 with NO clock edge", q_m1, 1'b1)

    // ---- 4. S_n held low beats the data on a capture, in both modes ----
    D = 1'b0; both;
    `CHK("S_n held low: mode0 still 1 with D=0", q_m0, 1'b1)
    `CHK("S_n held low: mode1 still 1 with D=0", q_m1, 1'b1)
    TE = 1'b1; TI = 1'b0; both;
    `CHK("S_n held low: the scan path cannot clear mode0", q_m0, 1'b1)
    `CHK("S_n held low: the scan path cannot clear mode1", q_m1, 1'b1)
    TE = 1'b0;

    // ---- 5. releasing S_n produces no event ----
    S_n = 1'b1; #10;
    `CHK("releasing S_n alone: mode0 unchanged", q_m0, 1'b1)
    `CHK("releasing S_n alone: mode1 unchanged", q_m1, 1'b1)
    D = 1'b0; both;
    `CHK("the next capture takes D=0: mode0", q_m0, 1'b0)
    `CHK("the next capture takes D=0: mode1", q_m1, 1'b0)

    // ---- 6. S_n asserted in the SAME instant as the capture: SET wins ----
    D = 1'b0; #3;
    S_n = 1'b0; CLK = 1'b1; sysclk = 1'b1;
    #1;
    `CHK("mode0: set and capture together -> SET WINS", q_m0, 1'b1)
    `CHK("mode1: set and capture together -> SET WINS", q_m1, 1'b1)
    CLK = 1'b0; sysclk = 1'b0; S_n = 1'b1; #3;

    // ---- 7. ENABLE HELD LOW: mode1 frozen, mode0 unaffected ----
    EN = 1'b0; D = 1'b0;
    sys_tick; sys_tick; sys_tick;
    `CHK("mode1 EN held low: no capture", q_m1, 1'b1)
    #3; clk_rise; clk_fall;
    `CHK("mode0 does not care about EN", q_m0, 1'b0)
    // the async set still works with EN low - it is outside the if(EN)
    S_n = 1'b0; #5;
    `CHK("mode1: async set works even with EN low", q_m1, 1'b1)
    S_n = 1'b1; EN = 1'b1; sys_tick;
    `CHK("mode1 captures D=0 once re-enabled", q_m1, 1'b0)

    // ---- 8. the TE mux both ways ----
    D = 1'b0; TE = 1'b1; TI = 1'b1; both;
    `CHK("mode0 TE=1 takes TI", q_m0, 1'b1)
    `CHK("mode1 TE=1 takes TI", q_m1, 1'b1)
    D = 1'b1; TI = 1'b0; both;
    `CHK("mode0 TE=1 ignores D", q_m0, 1'b0)
    `CHK("mode1 TE=1 ignores D", q_m1, 1'b0)
    TE = 1'b0; D = 1'b1; TI = 1'b0; both;
    `CHK("mode0 TE=0 takes D", q_m0, 1'b1)
    `CHK("mode1 TE=0 takes D", q_m1, 1'b1)

    // ---- 9. the falling CLK edge must do nothing (mode 0) ----
    D = 1'b1; #3; clk_rise;
    `CHK("mode0 rising CLK captures", q_m0, 1'b1)
    D = 1'b0; clk_fall;
    `CHK("mode0 falling CLK does not capture", q_m0, 1'b1)

    // ---- 10. THE MODE DIFFERENCE: a same-instant data change ----
    D = 1'b0; #3; clk_rise; clk_fall; sys_tick;
    `CHK("both settled at 0 (mode0)", q_m0, 1'b0)
    `CHK("both settled at 0 (mode1)", q_m1, 1'b0)
    D = 1'b1; CLK = 1'b1; sysclk = 1'b1;
    #1;
    `CHK("mode0 one-delta pipeline: captures the OLD value 0", q_m0, 1'b0)
    `CHK("mode1 has no such stage: captures the NEW value 1",  q_m1, 1'b1)
    CLK = 1'b0; sysclk = 1'b0; #3;
    clk_rise; clk_fall;
    `CHK("mode0 catches up on the next edge", q_m0, 1'b1)

    `CHK("qBar_m0 complement", qn_m0, ~q_m0)
    `CHK("qBar_m1 complement", qn_m1, ~q_m1)

    $display("SCAN_WITH_SET_N_EN_tb: checks=%0d failures=%0d", checks, errors);
    if (errors == 0) $display("TB_RESULT: PASS");
    else $display("TB_RESULT: FAIL");
    $finish;
  end

endmodule
`default_nettype wire

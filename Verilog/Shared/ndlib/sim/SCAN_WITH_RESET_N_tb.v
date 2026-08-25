/****************************************************************************
** SCAN_WITH_RESET_N - self-checking testbench, and a documented anomaly   **
**                                                                         **
** The cell is meant to be a scan flip-flop with a reset: D or TI selected **
** by TE, captured on the rising edge of CLK, with R_n clearing it.        **
**                                                                         **
** ANOMALY 1 - R_n DOES NOTHING. Measured, and traceable in the source:    **
**   SCAN_WITH_RESET_N.v instantiates                                      **
**       D_FLIPFLOP #(.InvertClockEnable(0)) MEMORY_4 (... .reset(s_r) ...)**
**   and leaves ACTIVE_ASYNC at its DEFAULT of 0. D_FLIPFLOP's gen_sync    **
**   branch is `always @(posedge s_clock) q <= d;` - it never reads its    **
**   preset or reset pins. So the reset input is wired to a pin that is    **
**   not connected to anything inside the flop.                            **
**   On top of that, R_n is passed through as `assign s_r = R_n;` and      **
**   then handed to .reset() WITHOUT inversion, so even if the async       **
**   branch were enabled the polarity would be active-HIGH on a pin named  **
**   *_n. (The sibling SCAN_WITH_SET_N.v does invert its S_n.)             **
**   SCAN_WITH_RESET_N_EN.v's own header states the same finding.          **
**   This tb asserts R_n has NO effect, in every combination, so that a    **
**   future fix breaks these checks loudly instead of silently changing    **
**   what the CPU does.                                                    **
**                                                                         **
** ANOMALY 2 - A ONE-DELTA INPUT PIPELINE. The mux output does not go      **
** straight to the flop; it goes through                                   **
**       reg delayedD;  always @(s_ff_d_input) delayedD <= s_ff_d_input;   **
**   A NON-BLOCKING assignment in a combinational block. The consequence   **
**   is measurable: if D (or TE/TI) changes in the SAME simulation instant **
**   as the CLK rising edge, the flop captures the PREVIOUS value, not the **
**   new one. Real hardware has no such stage. Tested explicitly below.    **
**                                                                         **
** Covered besides the two anomalies: power-up, the TE mux both ways, no   **
** clock edge at all, the falling edge doing nothing, data changing        **
** between edges, and R_n asserted at the same time as a capture.          **
**                                                                         **
** BUILD MODE: no `ifdef in this cell or the ones it uses - latch mode and **
** -DFPGA_FF_MODE must be bit-identical. Both are run.                     **
**                                                                         **
** Run: cd Verilog/Shared/ndlib/sim && make test-scanrst                   **
**                                                                         **
** Last reviewed: 20-AUG-2026                                              **
** Ronny Hansen                                                            **
*****************************************************************************/
`timescale 1ns / 1ps
`default_nettype none

module SCAN_WITH_RESET_N_tb;

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

  reg CLK = 1'b0;
  reg D = 1'b0;
  reg R_n = 1'b1;
  reg TE = 1'b0;
  reg TI = 1'b0;
  wire Q, QN;

  SCAN_WITH_RESET_N DUT (.CLK(CLK), .D(D), .R_n(R_n), .TE(TE), .TI(TI),
                         .Q(Q), .QN(QN));

  // The inputs are settled BEFORE the edge in this task, which is what a
  // real design does; the one-delta pipeline is exercised separately.
  task clk_rise; begin #5 CLK = 1'b1; #1; end endtask
  task clk_fall; begin #5 CLK = 1'b0; #1; end endtask
  task capture;  begin #3; clk_rise; clk_fall; end endtask

  initial begin
    $dumpfile("SCAN_WITH_RESET_N_tb.vcd");
    $dumpvars(0, SCAN_WITH_RESET_N_tb);
  end

  initial begin
    #1;
    `CHK("power-up Q", Q, 1'b0)
    `CHK("power-up QN", QN, 1'b1)

    // ---- 1. NO CLOCK EDGE AT ALL ----
    D = 1'b1; TE = 1'b0; #20;
    `CHK("no clock edge: Q holds", Q, 1'b0)

    // ---- 2. the D path (TE low) ----
    D = 1'b1; TE = 1'b0; capture;
    `CHK("TE=0 captures D=1", Q, 1'b1)
    `CHK("QN complement", QN, 1'b0)
    D = 1'b0; capture;
    `CHK("TE=0 captures D=0", Q, 1'b0)

    // ---- 3. the scan path (TE high): TI is taken and D is ignored ----
    D = 1'b0; TE = 1'b1; TI = 1'b1; capture;
    `CHK("TE=1 takes TI=1 while D=0", Q, 1'b1)
    D = 1'b1; TI = 1'b0; capture;
    `CHK("TE=1 takes TI=0 while D=1", Q, 1'b0)
    TE = 1'b0;

    // ---- 4. ANOMALY 1: R_n has NO EFFECT, in any combination ----
    D = 1'b1; TE = 1'b0; capture;
    `CHK("preloaded Q=1", Q, 1'b1)
    R_n = 1'b0; #10;
    `CHK("R_n low, no clock edge: Q NOT cleared", Q, 1'b1)
    capture;
    `CHK("R_n low across a clock edge: Q NOT cleared (still loads D=1)", Q, 1'b1)
    D = 1'b0; capture;
    `CHK("R_n low: the flop simply keeps loading D", Q, 1'b0)
    D = 1'b1; capture;
    `CHK("R_n low: D=1 loads normally", Q, 1'b1)
    R_n = 1'b1; #5;
    `CHK("releasing R_n changes nothing either", Q, 1'b1)
    // and the same with the scan path selected
    R_n = 1'b0; TE = 1'b1; TI = 1'b1; capture;
    `CHK("R_n low on the scan path: TI=1 still loads", Q, 1'b1)
    TI = 1'b0; capture;
    `CHK("R_n low on the scan path: TI=0 still loads", Q, 1'b0)
    R_n = 1'b1; TE = 1'b0;

    // ---- 5. the falling edge must do nothing ----
    D = 1'b1; #3; clk_rise;
    `CHK("rising edge captures", Q, 1'b1)
    D = 1'b0; clk_fall;
    `CHK("falling edge does not capture", Q, 1'b1)

    // ---- 6. data changing between edges: the last settled value wins ----
    D = 1'b1; #2; D = 1'b0; #2; D = 1'b1; #2;
    clk_rise;
    `CHK("mid-cycle D churn: final settled D=1 captured", Q, 1'b1)
    clk_fall;

    // ---- 7. ANOMALY 2: the one-delta pipeline. Changing D in the SAME
    //         simulation instant as the rising edge captures the OLD value.
    //         Settle to a known 1, then flip D to 0 at the same instant. ----
    D = 1'b1; #3; clk_rise; clk_fall;
    `CHK("settled at 1 before the delta test", Q, 1'b1)
    D = 1'b0; CLK = 1'b1;          // same instant, no # between them
    #1;
    `CHK("same-instant D change: the OLD value (1) is captured", Q, 1'b1)
    CLK = 1'b0; #3;
    clk_rise;
    `CHK("the next edge finally sees D=0", Q, 1'b0)
    clk_fall;

    `CHK("final QN complement", QN, ~Q)

    $display("SCAN_WITH_RESET_N_tb: checks=%0d failures=%0d", checks, errors);
    if (errors == 0) $display("TB_RESULT: PASS");
    else $display("TB_RESULT: FAIL");
    $finish;
  end

endmodule
`default_nettype wire

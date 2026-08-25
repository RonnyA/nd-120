/****************************************************************************
** SCAN_WITH_SET_N - self-checking functional testbench                    **
**                                                                         **
** Scan flip-flop with an ASYNCHRONOUS ACTIVE-LOW SET. Unlike its sibling  **
** SCAN_WITH_RESET_N - whose R_n pin is dead - this cell's set pin really  **
** works, and the two files differ in exactly the two ways that matter:    **
**                                                                         **
**   SCAN_WITH_SET_N.v     : assign s_s_n = ~s_s;   (S_n IS inverted)      **
**                           D_FLIPFLOP #(.ACTIVE_ASYNC(1), ...)           **
**                              .preset(s_s_n)  .reset(1'b0)               **
**   SCAN_WITH_RESET_N.v   : R_n passed through UNINVERTED, and            **
**                           ACTIVE_ASYNC left at its default of 0, so the **
**                           pin is not connected to anything inside.      **
**                                                                         **
** So here S_n = 0 asynchronously forces Q to 1 with no clock edge at all, **
** and while S_n is held low a clock edge still yields 1 whatever D is.    **
**                                                                         **
** THE ASYMMETRY TO WATCH: the async branch in D_FLIPFLOP is edge          **
** sensitive but level decoded -                                           **
**     always @(posedge clk or posedge preset or posedge reset)            **
**       q <= preset ? 1 : reset ? 0 : d;                                  **
** so RELEASING S_n (a falling edge on the internal preset) produces no    **
** event and Q does not move; only the next clock edge takes D again.      **
** Both halves are checked.                                                **
**                                                                         **
** There is no reset pin on this cell (.reset is tied to 1'b0 inside), so  **
** the set-and-reset-together case cannot be built here; the equivalent    **
** conflict - S_n asserted at the same instant as a capture - IS tested,   **
** and the set wins.                                                       **
**                                                                         **
** SHARED ANOMALY: like SCAN_FF and SCAN_WITH_RESET_N, the mux output      **
** passes through `always @(s_ff_d_input) delayedD <= s_ff_d_input;` - a   **
** non-blocking assignment in a combinational block, i.e. a one-delta      **
** pipeline stage that real hardware does not have. A D change in the      **
** SAME simulation instant as the clock rise captures the OLD value.       **
** Tested explicitly.                                                      **
**                                                                         **
** BUILD MODE: no `ifdef - latch mode and -DFPGA_FF_MODE are identical.    **
**                                                                         **
** Run: cd Verilog/Shared/ndlib/sim && make test-scanset                   **
**                                                                         **
** Last reviewed: 20-AUG-2026                                              **
** Ronny Hansen                                                            **
*****************************************************************************/
`timescale 1ns / 1ps
`default_nettype none

module SCAN_WITH_SET_N_tb;

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
  reg S_n = 1'b1;
  reg TE = 1'b0;
  reg TI = 1'b0;
  wire Q, QN;

  SCAN_WITH_SET_N DUT (.CLK(CLK), .D(D), .S_n(S_n), .TE(TE), .TI(TI),
                       .Q(Q), .QN(QN));

  task clk_rise; begin #5 CLK = 1'b1; #1; end endtask
  task clk_fall; begin #5 CLK = 1'b0; #1; end endtask
  task capture;  begin #3; clk_rise; clk_fall; end endtask

  initial begin
    $dumpfile("SCAN_WITH_SET_N_tb.vcd");
    $dumpvars(0, SCAN_WITH_SET_N_tb);
  end

  initial begin
    #1;
    `CHK("power-up Q (S_n starts high, so no set fires)", Q, 1'b0)
    `CHK("power-up QN", QN, 1'b1)

    // ---- 1. NO CLOCK EDGE, S_n high: nothing happens ----
    D = 1'b1; #20;
    `CHK("no clock edge: Q holds", Q, 1'b0)

    // ---- 2. the D path ----
    D = 1'b1; TE = 1'b0; capture;
    `CHK("TE=0 captures D=1", Q, 1'b1)
    D = 1'b0; capture;
    `CHK("TE=0 captures D=0", Q, 1'b0)

    // ---- 3. the scan path: TI is taken, D ignored ----
    D = 1'b0; TE = 1'b1; TI = 1'b1; capture;
    `CHK("TE=1 takes TI=1 while D=0", Q, 1'b1)
    D = 1'b1; TI = 1'b0; capture;
    `CHK("TE=1 takes TI=0 while D=1", Q, 1'b0)
    TE = 1'b0; D = 1'b0;

    // ---- 4. ASYNC SET with NO clock edge anywhere near it ----
    capture;                      // make sure Q is 0 first
    `CHK("Q cleared before the async-set test", Q, 1'b0)
    S_n = 1'b0; #10;
    `CHK("S_n low sets Q with NO clock edge", Q, 1'b1)
    `CHK("QN complement after the async set", QN, 1'b0)

    // ---- 5. S_n held low beats the data on a clock edge ----
    D = 1'b0; capture;
    `CHK("S_n held low: clock edge still yields 1 with D=0", Q, 1'b1)
    TE = 1'b1; TI = 1'b0; capture;
    `CHK("S_n held low: the scan path cannot clear it either", Q, 1'b1)
    TE = 1'b0;

    // ---- 6. RELEASING S_n produces no event - only the next edge moves Q --
    S_n = 1'b1; #10;
    `CHK("releasing S_n alone does not change Q", Q, 1'b1)
    D = 1'b0; capture;
    `CHK("the next clock edge finally takes D=0", Q, 1'b0)

    // ---- 7. S_n asserted at the same instant as a capture: the SET wins ----
    D = 1'b0; #3;
    S_n = 1'b0; CLK = 1'b1;       // same simulation instant
    #1;
    `CHK("S_n and the clock edge together: the SET wins", Q, 1'b1)
    CLK = 1'b0; S_n = 1'b1; #3;

    // ---- 8. the falling edge must do nothing ----
    D = 1'b0; #3; clk_rise;
    `CHK("rising edge captures D=0", Q, 1'b0)
    D = 1'b1; clk_fall;
    `CHK("falling edge does not capture", Q, 1'b0)

    // ---- 9. data changing between edges: last settled value wins ----
    D = 1'b0; #2; D = 1'b1; #2; D = 1'b0; #2;
    clk_rise;
    `CHK("mid-cycle D churn: final settled D=0 captured", Q, 1'b0)
    clk_fall;

    // ---- 10. the one-delta pipeline (shared with SCAN_FF) ----
    D = 1'b0; #3; clk_rise; clk_fall;
    `CHK("settled at 0 before the delta test", Q, 1'b0)
    D = 1'b1; CLK = 1'b1;         // same instant
    #1;
    `CHK("same-instant D change: the OLD value (0) is captured", Q, 1'b0)
    CLK = 1'b0; #3;
    clk_rise;
    `CHK("the next edge finally sees D=1", Q, 1'b1)
    clk_fall;

    `CHK("final QN complement", QN, ~Q)

    $display("SCAN_WITH_SET_N_tb: checks=%0d failures=%0d", checks, errors);
    if (errors == 0) $display("TB_RESULT: PASS");
    else $display("TB_RESULT: FAIL");
    $finish;
  end

endmodule
`default_nettype wire

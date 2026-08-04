/**************************************************************************
** F714 (NEC T flip-flop with async R, S) self-checking testbench         **
**                                                                        **
** Directed walk of the RTL truth table:                                  **
**   posedge T, R=S=0  -> Q inverts                                       **
**   negedge T         -> hold                                            **
**   posedge R         -> Q=0, QB=1 (highest priority in the RTL)         **
**   posedge S         -> Q=1, QB=0                                       **
**                                                                        **
** NOTE (documented divergence, pinned by check 5): the NEC data-sheet    **
** prohibition row R=S=1 gives Q=1, QB=1. The RTL prioritises RESET, so   **
** raising R and S together gives Q=0, QB=1. This tb asserts the RTL      **
** behavior and this comment records the difference from the cell sheet.  **
**                                                                        **
** Verdict: TB_RESULT: PASS (<n> checks) with a fixed expected count.     **
***************************************************************************/
`timescale 1ns / 1ps

module F714_tb;

  localparam integer CHECKS_EXPECTED = 18;

  reg H01_T = 0;
  reg H02_R = 0;
  reg H03_S = 0;

  wire N01_Q;
  wire N02_QB;

  integer errors = 0;
  integer checks = 0;

  F714 uut (
      .H01_T(H01_T),
      .H02_R(H02_R),
      .H03_S(H03_S),
      .N01_Q(N01_Q),
      .N02_QB(N02_QB)
  );

  task chk(input got, input exp, input [255:0] label);
    begin
      checks = checks + 1;
      if (got !== exp) begin
        $display("  FAIL: %0s  got=%b expected=%b", label, got, exp);
        errors = errors + 1;
      end
    end
  endtask

  initial begin
    // 1. Reset pulse: Q=0, QB=1
    #10 H02_R = 1;
    #10 H02_R = 0;
    chk(N01_Q, 1'b0, "after R pulse: Q=0");
    chk(N02_QB, 1'b1, "after R pulse: QB=1");

    // 2. Set pulse: Q=1, QB=0
    #10 H03_S = 1;
    #10 H03_S = 0;
    chk(N01_Q, 1'b1, "after S pulse: Q=1");
    chk(N02_QB, 1'b0, "after S pulse: QB=0");

    // 3a. Toggle: posedge T inverts (1 -> 0)
    #10 H01_T = 1;
    #10;
    chk(N01_Q, 1'b0, "posedge T toggles: Q=0");
    chk(N02_QB, 1'b1, "posedge T toggles: QB=1");

    // 3b. negedge T holds
    H01_T = 0;
    #10;
    chk(N01_Q, 1'b0, "negedge T holds: Q=0");
    chk(N02_QB, 1'b1, "negedge T holds: QB=1");

    // 4. Toggle again (0 -> 1)
    #10 H01_T = 1;
    #10 H01_T = 0;
    chk(N01_Q, 1'b1, "second toggle: Q=1");
    chk(N02_QB, 1'b0, "second toggle: QB=0");

    // 5. R and S raised together: RTL gives RESET priority (see header).
    #10;
    H02_R = 1;
    H03_S = 1;
    #10;
    chk(N01_Q, 1'b0, "R=S=1 (RTL reset priority): Q=0");
    chk(N02_QB, 1'b1, "R=S=1 (RTL reset priority): QB=1");
    H02_R = 0;
    H03_S = 0;

    // 6. Set again after the prohibition exit
    #10 H03_S = 1;
    #10 H03_S = 0;
    chk(N01_Q, 1'b1, "S after prohibition: Q=1");
    chk(N02_QB, 1'b0, "S after prohibition: QB=0");

    // 7. Two more toggles: 1 -> 0 -> 1
    #10 H01_T = 1;
    #10 H01_T = 0;
    chk(N01_Q, 1'b0, "third toggle: Q=0");
    chk(N02_QB, 1'b1, "third toggle: QB=1");
    #10 H01_T = 1;
    #10 H01_T = 0;
    chk(N01_Q, 1'b1, "fourth toggle: Q=1");
    chk(N02_QB, 1'b0, "fourth toggle: QB=0");

    #10;
    if (errors == 0 && checks == CHECKS_EXPECTED)
      $display("TB_RESULT: PASS (%0d checks)", checks);
    else
      $display("TB_RESULT: FAIL (%0d errors / %0d checks, expected %0d)",
               errors, checks, CHECKS_EXPECTED);
    $finish;
  end

  initial begin
    #10000;
    $display("TB_RESULT: FAIL (timeout)");
    $finish;
  end

endmodule

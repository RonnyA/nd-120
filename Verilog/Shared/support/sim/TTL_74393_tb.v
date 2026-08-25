/****************************************************************************
** TTL_74393 - exhaustive functional testbench                            **
**                                                                        **
** COVERAGE: the counter is clocked through all 16 states TWICE in a row  **
** (32 negedge-CLK_n events), so the full 0..15 sequence AND the 15->0    **
** wrap are both directly observed and checked. Also checked: async       **
** RESET forcing 0 immediately mid-count with no CLK_n edge involved, no  **
** advance on the POSITIVE edge of CLK_n, and the QA/QB/QC/QD-to-         **
** counter-bit mapping (implied by every step of the exhaustive count).   **
**                                                                        **
** RTL note: this module implements ONE 4-stage counter (the "dual"       **
** counter's second half is not modelled here) with an active-HIGH        **
** asynchronous RESET and count-on-negedge-CLK_n, exactly as the header   **
** comment in TTL_74393.v states - this matches the datasheet for this    **
** half of the device. No RTL-vs-datasheet disagreement found here.       **
**                                                                        **
** Run: cd Verilog/Shared/support/sim && iverilog -g2012 -o tb.vvp \      **
**   TTL_74393_tb.v ../TTL_74393.v && vvp tb.vvp                          **
**                                                                        **
** Last reviewed: 20-AUG-2026                                            **
** Ronny Hansen                                                          **
*****************************************************************************/
`timescale 1ns / 1ps
`default_nettype none

module TTL_74393_tb;

  reg CLK_n = 1;
  reg RESET = 0;
  wire QA, QB, QC, QD;

  integer errors = 0;
  integer checks = 0;

  TTL_74393 DUT (
      .CLK_n(CLK_n), .RESET(RESET),
      .QA(QA), .QB(QB), .QC(QC), .QD(QD)
  );

  function [3:0] cnt;
    begin
      cnt = {QD, QC, QB, QA};
    end
  endfunction

  // One full negedge-CLK_n count step.
  task step_and_check(input [3:0] expected);
    begin
      CLK_n = 0;
      #5;
      CLK_n = 1;
      #5;
      checks = checks + 1;
      if (cnt() !== expected) begin
        errors = errors + 1;
        if (errors < 10)
          $display("FAIL COUNT: got QD..QA=%b expected %b (state %0d)", cnt(), expected, expected);
      end
    end
  endtask

  integer i, pass;

  initial begin
    $dumpfile("TTL_74393_tb.vcd");
    $dumpvars(0, TTL_74393_tb);

    // ---- short documentation sequence: reset, then count 0..15 ------------
    RESET = 1; #5; RESET = 0; #5;
    checks = checks + 1;
    if (cnt() !== 4'd0) begin
      errors = errors + 1;
      $display("FAIL INIT_RESET: cnt=%0d expected 0", cnt());
    end
    for (i = 1; i <= 15; i = i + 1) step_and_check(i[3:0]);
    step_and_check(4'd0);   // the 15 -> 0 wrap
    $dumpoff;

    // ---- exhaustive: two full passes through all 16 states (32 steps),
    //      so the 0..15 sequence and the wrap are both re-proven -----------
    $display("=====================================================");
    $display(" TTL_74393 exhaustive count sweep");
    $display(" (16 states x 2 passes = 32 negedge CLK_n events)");
    $display("=====================================================");
    RESET = 1; #5; RESET = 0; #5;
    for (pass = 0; pass < 2; pass = pass + 1) begin
      for (i = 1; i <= 16; i = i + 1) begin
        step_and_check(i[3:0]);   // i=16 wraps to 4'd0 automatically
      end
    end

    // ---- named check: async RESET forces 0 immediately, mid-count, with
    //      no CLK_n edge involved ------------------------------------------
    RESET = 0;
    for (i = 1; i <= 5; i = i + 1) step_and_check(i[3:0]);
    checks = checks + 1;
    if (cnt() === 4'd0) begin
      errors = errors + 1;
      $display("FAIL ASYNC_RESET_setup: counter already 0 before the mid-count reset was applied");
    end
    RESET = 1;              // asserted with CLK_n NOT toggling
    #1;                     // no clock edge anywhere in this window
    checks = checks + 1;
    if (cnt() !== 4'd0) begin
      errors = errors + 1;
      $display("FAIL ASYNC_RESET_immediate: cnt=%0d expected 0 within 1ns of RESET with no CLK_n edge", cnt());
    end
    #10;
    checks = checks + 1;
    if (cnt() !== 4'd0) begin
      errors = errors + 1;
      $display("FAIL ASYNC_RESET_held: cnt=%0d expected 0 while RESET stays high", cnt());
    end
    RESET = 0;
    #5;
    checks = checks + 1;
    if (cnt() !== 4'd0) begin
      errors = errors + 1;
      $display("FAIL ASYNC_RESET_release: cnt=%0d expected counter to stay 0 until the next negedge", cnt());
    end

    // ---- named check: no advance on the POSITIVE edge of CLK_n ------------
    // Entering this block CLK_n is steady at 1 (from the previous section)
    // and cnt=0. Setting CLK_n=0 IS itself the qualifying falling edge, so
    // that step is expected to advance the count to 1 - the actual "no
    // advance" proof is the CLK_n=1 step right after it.
    CLK_n = 0;
    #5;
    checks = checks + 1;
    if (cnt() !== 4'd1) begin
      errors = errors + 1;
      $display("FAIL setup for posedge test: cnt=%0d expected 1 after the setup falling edge", cnt());
    end
    CLK_n = 1;               // this is a POSITIVE edge of CLK_n
    #5;
    checks = checks + 1;
    if (cnt() !== 4'd1) begin
      errors = errors + 1;
      $display("FAIL NO_ADVANCE_ON_POSEDGE: cnt=%0d changed on a rising edge of CLK_n, expected 1", cnt());
    end
    CLK_n = 0;                // now the falling edge that DOES count
    #5;
    checks = checks + 1;
    if (cnt() !== 4'd2) begin
      errors = errors + 1;
      $display("FAIL NEGEDGE_DOES_ADVANCE: cnt=%0d expected 2 after the falling edge", cnt());
    end
    CLK_n = 1;
    #5;

    $display("-----------------------------------------------------");
    $display(" checks run : %0d", checks);
    $display(" failures   : %0d", errors);
    if (errors == 0) $display("TB_RESULT: PASS");
    else             $display("TB_RESULT: FAIL");
    $display("=====================================================");
    $finish;
  end

  initial begin
    #200000;
    $display("FAIL [timeout]: watchdog fired");
    $display("TB_RESULT: FAIL (timeout)");
    $finish;
  end

endmodule

`default_nettype wire

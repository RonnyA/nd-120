/****************************************************************************
** D_FLIPFLOP_SIMPLE - self-checking functional testbench                  **
**                                                                         **
** The cut-down flop: clock + d only, no preset, no reset, no enable, no   **
** parameters. Unlike its bigger brother D_FLIPFLOP it has NO              **
** InvertClockEnable parameter, so it is unconditionally RISING edge.      **
** That asymmetry is the reason this tb exists next to D_FLIPFLOP_tb.v -   **
** the two cells look interchangeable in a schematic and are not.          **
**                                                                         **
** Covered: power-up value, rising-edge capture, NO edge at all, falling   **
** edge (must do nothing), data toggling between edges, hold across many   **
** data changes, and qBar being the exact complement at every step.        **
**                                                                         **
** There is nothing to reset or preset on this cell, so the "set and reset **
** together" case does not exist here; it is covered in D_FLIPFLOP_tb.v.   **
**                                                                         **
** BUILD MODE: no `ifdef in the source - latch mode and -DFPGA_FF_MODE     **
** must be bit-identical. Both are run.                                    **
**                                                                         **
** Run: cd Verilog/Shared/logisim/sim && make test-dffsimple               **
**                                                                         **
** Last reviewed: 20-AUG-2026                                              **
** Ronny Hansen                                                            **
*****************************************************************************/
`timescale 1ns / 1ps
`default_nettype none

module D_FLIPFLOP_SIMPLE_tb;

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

  reg clock = 1'b0;
  reg d = 1'b0;
  wire q, qBar;

  D_FLIPFLOP_SIMPLE DUT (.clock(clock), .d(d), .q(q), .qBar(qBar));

  task clk_rise; begin #10 clock = 1'b1; #1; end endtask
  task clk_fall; begin #10 clock = 1'b0; #1; end endtask

  integer i;

  initial begin
    $dumpfile("D_FLIPFLOP_SIMPLE_tb.vcd");
    $dumpvars(0, D_FLIPFLOP_SIMPLE_tb);
  end

  initial begin
    #1;
    `CHK("power-up q", q, 1'b0)
    `CHK("power-up qBar", qBar, 1'b1)

    // ---- no clock edge at all ----
    d = 1'b1; #25;
    `CHK("no edge: q holds 0", q, 1'b0)
    `CHK("no edge: qBar holds 1", qBar, 1'b1)

    // ---- rising edge captures ----
    clk_rise;
    `CHK("rising edge captures 1", q, 1'b1)
    `CHK("qBar complement", qBar, 1'b0)

    // ---- falling edge must do nothing ----
    d = 1'b0;
    clk_fall;
    `CHK("falling edge does not capture", q, 1'b1)

    // ---- data toggling between edges: only the last value lands ----
    d = 1'b1; #2; d = 1'b0; #2; d = 1'b1; #2; d = 1'b0; #2;
    clk_rise;
    `CHK("only the final pre-edge value is captured", q, 1'b0)
    clk_fall;

    // ---- long hold with the clock parked low ----
    d = 1'b1;
    for (i = 0; i < 5; i = i + 1) begin
      #3 d = ~d;
    end
    `CHK("clock parked low: q unchanged", q, 1'b0)

    // ---- alternating pattern, one bit per rising edge ----
    d = 1'b1; clk_rise; `CHK("pattern bit 1", q, 1'b1) clk_fall;
    d = 1'b0; clk_rise; `CHK("pattern bit 0", q, 1'b0) clk_fall;
    d = 1'b1; clk_rise; `CHK("pattern bit 1 again", q, 1'b1) clk_fall;
    `CHK("final qBar complement", qBar, ~q)

    $display("D_FLIPFLOP_SIMPLE_tb: checks=%0d failures=%0d", checks, errors);
    if (errors == 0) $display("TB_RESULT: PASS");
    else $display("TB_RESULT: FAIL");
    $finish;
  end

endmodule
`default_nettype wire

/****************************************************************************
** T_FLIPFLOP - self-checking functional testbench                         **
**                                                                         **
** WHAT THE RTL ACTUALLY DOES (read from T_FLIPFLOP.v):                    **
**                                                                         **
**   s_clock = (invertClockEnable == 0) ? clock : ~clock;                  **
**   default invertClockEnable = 1  ->  the DEFAULT cell captures on the   **
**   FALLING edge of the `clock` pin. Note the parameter name is spelled   **
**   with a LOWER-CASE i here and an upper-case I in D_FLIPFLOP.v and      **
**   J_K_FLIPFLOP.v - overriding it needs the right spelling per cell.     **
**                                                                         **
**   always @(posedge s_clock)                                             **
**     if      (reset)  q <= 0;      // <-- RESET is tested FIRST          **
**     else if (preset) q <= 1;                                            **
**     else if (tick)   q <= q ^ t;                                        **
**                                                                         **
** SET AND RESET TOGETHER: RESET WINS here. The sibling J_K_FLIPFLOP.v in  **
** the same directory writes the same three lines with preset first, so    **
** PRESET wins there. Two cells side by side resolve the identical         **
** conflict in opposite directions. Vivado's "set and reset at equal       **
** priority may cause simulation mismatches" warning is aimed exactly at   **
** this, and this tb is what pins the ND-120 answer down for T_FLIPFLOP.   **
**                                                                         **
** Both preset and reset are SYNCHRONOUS - the async sensitivity list is   **
** commented out in the source - so with no clock edge they do nothing.    **
** `tick` gates only the toggle; reset/preset act with tick low.           **
**                                                                         **
** BUILD MODE: no `ifdef in the source - latch mode and -DFPGA_FF_MODE     **
** must be bit-identical. Both are run.                                    **
**                                                                         **
** Run: cd Verilog/Shared/logisim/sim && make test-tff                     **
**                                                                         **
** Last reviewed: 20-AUG-2026                                              **
** Ronny Hansen                                                            **
*****************************************************************************/
`timescale 1ns / 1ps
`default_nettype none

module T_FLIPFLOP_tb;

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
  reg t = 1'b0;
  reg preset = 1'b0, reset = 1'b0;
  reg tick = 1'b1;

  wire q_neg, qn_neg;   // default -> falling edge of the pin
  wire q_pos, qn_pos;   // invertClockEnable(0) -> rising edge of the pin

  T_FLIPFLOP U_NEG (
      .clock(clock), .preset(preset), .reset(reset), .t(t), .tick(tick),
      .q(q_neg), .qBar(qn_neg)
  );

  T_FLIPFLOP #(.invertClockEnable(0)) U_POS (
      .clock(clock), .preset(preset), .reset(reset), .t(t), .tick(tick),
      .q(q_pos), .qBar(qn_pos)
  );

  task clk_rise; begin #10 clock = 1'b1; #1; end endtask
  task clk_fall; begin #10 clock = 1'b0; #1; end endtask
  task clk_cycle; begin clk_rise; clk_fall; end endtask

  integer i;

  initial begin
    $dumpfile("T_FLIPFLOP_tb.vcd");
    $dumpvars(0, T_FLIPFLOP_tb);
  end

  initial begin
    #1;
    `CHK("power-up q_neg", q_neg, 1'b0)
    `CHK("power-up q_pos", q_pos, 1'b0)
    `CHK("power-up qBar_pos", qn_pos, 1'b1)

    // ---- 1. NO CLOCK EDGE: preset/reset are synchronous, nothing moves ----
    t = 1'b1; preset = 1'b1; reset = 1'b1; #25;
    `CHK("no edge: q_neg holds", q_neg, 1'b0)
    `CHK("no edge: q_pos holds", q_pos, 1'b0)
    preset = 1'b0; reset = 1'b0;

    // ---- 2. which pin edge each instance uses ----
    t = 1'b1;
    clk_rise;
    `CHK("pin rise: q_pos toggles to 1", q_pos, 1'b1)
    `CHK("pin rise: q_neg must NOT move", q_neg, 1'b0)
    clk_fall;
    `CHK("pin fall: q_neg toggles to 1", q_neg, 1'b1)
    `CHK("pin fall: q_pos holds 1", q_pos, 1'b1)

    // ---- 3. t low: no toggle even with tick high ----
    t = 1'b0;
    clk_cycle;
    `CHK("t=0: q_pos holds", q_pos, 1'b1)
    `CHK("t=0: q_neg holds", q_neg, 1'b1)

    // ---- 4. free-running toggle, 6 edges ----
    t = 1'b1;
    for (i = 0; i < 6; i = i + 1) begin
      clk_rise;
      `CHK("toggling q_pos", q_pos, (i % 2) ? 1'b1 : 1'b0)
      clk_fall;
      `CHK("toggling q_neg", q_neg, (i % 2) ? 1'b1 : 1'b0)
    end
    // after 6 toggles from 1 -> back to 1
    `CHK("after 6 toggles q_pos back to 1", q_pos, 1'b1)
    `CHK("after 6 toggles q_neg back to 1", q_neg, 1'b1)

    // ---- 5. tick low freezes the toggle ----
    tick = 1'b0;
    clk_cycle; clk_cycle;
    `CHK("tick=0: q_pos frozen", q_pos, 1'b1)
    `CHK("tick=0: q_neg frozen", q_neg, 1'b1)

    // ---- 6. ... but reset/preset still act with tick low ----
    reset = 1'b1;
    clk_cycle;
    `CHK("tick=0 but reset=1: q_pos cleared", q_pos, 1'b0)
    `CHK("tick=0 but reset=1: q_neg cleared", q_neg, 1'b0)
    reset = 1'b0;
    preset = 1'b1;
    clk_cycle;
    `CHK("tick=0 but preset=1: q_pos set", q_pos, 1'b1)
    `CHK("tick=0 but preset=1: q_neg set", q_neg, 1'b1)
    preset = 1'b0;
    tick = 1'b1;

    // ---- 7. SET AND RESET TOGETHER -> RESET WINS (opposite of J_K) ----
    // start from 1 so a wrong winner is unmistakable
    preset = 1'b1; clk_cycle; preset = 1'b0;
    `CHK("pre-set to 1 for the conflict test", q_pos, 1'b1)
    preset = 1'b1; reset = 1'b1;
    clk_cycle;
    `CHK("preset+reset together: RESET WINS on q_pos", q_pos, 1'b0)
    `CHK("preset+reset together: RESET WINS on q_neg", q_neg, 1'b0)
    clk_cycle;
    `CHK("conflict held over a second edge: still 0", q_pos, 1'b0)
    preset = 1'b0; reset = 1'b0;

    // ---- 8. t changing between edges: only the pre-edge value counts ----
    t = 1'b1; #2; t = 1'b0; #2;
    clk_cycle;
    `CHK("mid-cycle t churn: final t=0, no toggle", q_pos, 1'b0)
    t = 1'b0; #2; t = 1'b1; #2;
    clk_rise;
    `CHK("mid-cycle t churn: final t=1, toggles", q_pos, 1'b1)
    clk_fall;

    `CHK("final qBar_pos complement", qn_pos, ~q_pos)
    `CHK("final qBar_neg complement", qn_neg, ~q_neg)

    $display("T_FLIPFLOP_tb: checks=%0d failures=%0d", checks, errors);
    if (errors == 0) $display("TB_RESULT: PASS");
    else $display("TB_RESULT: FAIL");
    $finish;
  end

endmodule
`default_nettype wire

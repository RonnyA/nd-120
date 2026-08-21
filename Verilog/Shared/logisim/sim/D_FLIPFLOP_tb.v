/****************************************************************************
** D_FLIPFLOP - self-checking functional testbench                         **
**                                                                         **
** D_FLIPFLOP is the primitive that almost every other sequential cell in  **
** Shared/ndlib is built out of (SCAN_FF, SCAN_WITH_SET_N, SR44, M169C,    **
** F924, ...). Two parameters change what it IS, and both defaults are     **
** surprising, so they are pinned down here:                               **
**                                                                         **
**   InvertClockEnable (default 1)                                         **
**       s_clock = ~clock, so the DEFAULT instance captures on the         **
**       FALLING edge of the `clock` pin. Only InvertClockEnable(0)        **
**       gives a rising-edge flop. Every ndlib user passes 0.              **
**                                                                         **
**   ACTIVE_ASYNC (default 0)                                              **
**       The gen_sync branch is `always @(posedge s_clock) q <= d;` and    **
**       it does NOT read preset or reset AT ALL. With the default         **
**       parameter the preset and reset PINS ARE DEAD. That is not a       **
**       cosmetic detail: SCAN_WITH_RESET_N wires R_n to .reset on a       **
**       default-parameter D_FLIPFLOP, which is why R_n has no effect      **
**       in that module (see SCAN_WITH_RESET_N_tb.v).                      **
**                                                                         **
**   `tick` is declared but never read in either branch.                   **
**                                                                         **
** SET-AND-RESET-TOGETHER: with ACTIVE_ASYNC=1 the block is                **
**   always @(posedge s_clock or posedge preset or posedge reset)          **
**     q <= preset ? 1 : reset ? 0 : d;                                    **
** so PRESET WINS when both are asserted in the same instant. Vivado       **
** warns that equal-priority set/reset "may cause simulation mismatches";  **
** this tb records what the RTL actually does. Note also that preset and   **
** reset are EDGE sensitive in the sensitivity list but LEVEL decoded in   **
** the body: a held-high preset keeps forcing 1 on every clock edge, but   **
** a preset that FALLS produces no event at all.                           **
**                                                                         **
** BUILD MODE: this module contains no `ifdef, so latch mode and           **
** -DFPGA_FF_MODE must give BIT-IDENTICAL results. Both are run.           **
**                                                                         **
** Run: cd Verilog/Shared/logisim/sim && make test-dff                     **
**                                                                         **
** Last reviewed: 20-AUG-2026                                              **
** Ronny Hansen                                                            **
*****************************************************************************/
`timescale 1ns / 1ps
`default_nettype none

module D_FLIPFLOP_tb;

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
  reg preset = 1'b0;
  reg reset = 1'b0;
  reg tick = 1'b0;

  // Default parameters: falling-edge capture, preset/reset pins DEAD.
  wire q_def, qn_def;
  D_FLIPFLOP U_DEF (
      .clock(clock), .d(d), .preset(preset), .reset(reset), .tick(tick),
      .q(q_def), .qBar(qn_def)
  );

  // Rising edge, still no async path (preset/reset pins DEAD).
  wire q_pos, qn_pos;
  D_FLIPFLOP #(.InvertClockEnable(0), .ACTIVE_ASYNC(0)) U_POS (
      .clock(clock), .d(d), .preset(preset), .reset(reset), .tick(tick),
      .q(q_pos), .qBar(qn_pos)
  );

  // Rising edge WITH async preset/reset.
  wire q_asy, qn_asy;
  D_FLIPFLOP #(.InvertClockEnable(0), .ACTIVE_ASYNC(1)) U_ASY (
      .clock(clock), .d(d), .preset(preset), .reset(reset), .tick(tick),
      .q(q_asy), .qBar(qn_asy)
  );

  task clk_rise; begin #10 clock = 1'b1; #1; end endtask
  task clk_fall; begin #10 clock = 1'b0; #1; end endtask

  // qBar must always be the exact complement of q, on every instance.
  task check_qbar;
    begin
      `CHK("U_DEF qBar complement", qn_def, ~q_def)
      `CHK("U_POS qBar complement", qn_pos, ~q_pos)
      `CHK("U_ASY qBar complement", qn_asy, ~q_asy)
    end
  endtask

  initial begin
    $dumpfile("D_FLIPFLOP_tb.vcd");
    $dumpvars(0, D_FLIPFLOP_tb);
  end

  initial begin
    #1;
    // ---- 1. power-up value ----
    `CHK("power-up q_def", q_def, 1'b0)
    `CHK("power-up q_pos", q_pos, 1'b0)
    `CHK("power-up q_asy", q_asy, 1'b0)
    check_qbar;

    // ---- 2. NO CLOCK EDGE AT ALL: data must not reach q ----
    d = 1'b1;
    #20;
    `CHK("no edge: q_def holds", q_def, 1'b0)
    `CHK("no edge: q_pos holds", q_pos, 1'b0)
    `CHK("no edge: q_asy holds", q_asy, 1'b0)

    // ---- 3. rising edge of the clock PIN ----
    clk_rise;
    `CHK("posedge pin: q_def (inverted clk) must NOT capture", q_def, 1'b0)
    `CHK("posedge pin: q_pos captures 1", q_pos, 1'b1)
    `CHK("posedge pin: q_asy captures 1", q_asy, 1'b1)
    check_qbar;

    // ---- 4. falling edge of the clock PIN ----
    clk_fall;
    `CHK("negedge pin: q_def captures 1", q_def, 1'b1)
    `CHK("negedge pin: q_pos holds 1", q_pos, 1'b1)
    `CHK("negedge pin: q_asy holds 1", q_asy, 1'b1)

    // ---- 5. data toggling BETWEEN edges: only the final value counts ----
    d = 1'b0; #3; d = 1'b1; #3; d = 1'b0; #3;
    clk_rise;
    `CHK("mid-cycle toggling: q_pos takes final d=0", q_pos, 1'b0)
    `CHK("mid-cycle toggling: q_asy takes final d=0", q_asy, 1'b0)
    `CHK("mid-cycle toggling: q_def unchanged on this edge", q_def, 1'b1)
    d = 1'b1; #3; d = 1'b0; #3;
    clk_fall;
    `CHK("mid-cycle toggling: q_def takes final d=0", q_def, 1'b0)

    // ---- 6. `tick` is not wired to anything: toggling it changes nothing ----
    d = 1'b1;
    tick = 1'b1; #5; tick = 1'b0; #5; tick = 1'b1; #5;
    `CHK("tick toggling does not clock q_def", q_def, 1'b0)
    `CHK("tick toggling does not clock q_pos", q_pos, 1'b0)
    `CHK("tick toggling does not clock q_asy", q_asy, 1'b0)

    // ---- 7. ASYNC RESET (no clock edge anywhere near it) ----
    clk_rise;                       // load 1 into the rising-edge flops
    clk_fall;                       // load 1 into the default flop
    `CHK("preload q_def=1", q_def, 1'b1)
    `CHK("preload q_pos=1", q_pos, 1'b1)
    `CHK("preload q_asy=1", q_asy, 1'b1)
    reset = 1'b1; #5;
    `CHK("async reset clears q_asy with no clock edge", q_asy, 1'b0)
    `CHK("reset pin is DEAD on q_def (ACTIVE_ASYNC=0)", q_def, 1'b1)
    `CHK("reset pin is DEAD on q_pos (ACTIVE_ASYNC=0)", q_pos, 1'b1)
    check_qbar;

    // reset held high across a clock edge keeps forcing 0 even though d=1
    `CHK("d is still 1 here", d, 1'b1)
    clk_rise;
    `CHK("reset held high beats d on the clock edge", q_asy, 1'b0)
    clk_fall;
    reset = 1'b0; #5;
    `CHK("releasing reset alone changes nothing", q_asy, 1'b0)

    // ---- 8. ASYNC PRESET ----
    preset = 1'b1; #5;
    `CHK("async preset sets q_asy with no clock edge", q_asy, 1'b1)
    `CHK("preset pin is DEAD on q_pos", q_pos, 1'b1)
    d = 1'b0;
    clk_rise;
    `CHK("preset held high beats d=0 on the clock edge", q_asy, 1'b1)
    clk_fall;
    preset = 1'b0; #5;
    `CHK("releasing preset alone changes nothing", q_asy, 1'b1)

    // ---- 9. PRESET AND RESET ASSERTED IN THE SAME INSTANT ----
    // Bring q_asy to 0 first so a wrong winner is visible.
    reset = 1'b1; #2; reset = 1'b0; #2;
    `CHK("q_asy pre-cleared", q_asy, 1'b0)
    preset = 1'b1; reset = 1'b1;    // same simulation instant
    #5;
    `CHK("simultaneous preset+reset: PRESET WINS", q_asy, 1'b1)
    check_qbar;
    // and with both still held, a clock edge must not let d through
    d = 1'b0;
    clk_rise;
    `CHK("both held: clock edge still yields 1", q_asy, 1'b1)
    clk_fall;
    // drop preset only. That is a FALLING edge on preset -> no event fires,
    // so q must not move even though reset is still high.
    preset = 1'b0; #5;
    `CHK("preset falling produces no event: q_asy stays 1", q_asy, 1'b1)
    // now a real clock edge with reset still high -> reset decodes -> 0
    clk_rise;
    `CHK("clock edge with reset still high clears to 0", q_asy, 1'b0)
    clk_fall;
    reset = 1'b0; #5;

    // ---- 10. back to normal data operation after all that ----
    d = 1'b1; clk_rise;
    `CHK("normal capture resumes", q_asy, 1'b1)
    check_qbar;

    $display("D_FLIPFLOP_tb: checks=%0d failures=%0d", checks, errors);
    if (errors == 0) $display("TB_RESULT: PASS");
    else $display("TB_RESULT: FAIL");
    $finish;
  end

endmodule
`default_nettype wire

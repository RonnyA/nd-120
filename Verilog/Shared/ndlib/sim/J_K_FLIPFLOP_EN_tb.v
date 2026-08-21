/****************************************************************************
** J_K_FLIPFLOP_EN - self-checking functional testbench, both modes        **
**                                                                         **
**   USE_ENABLE=0 (default)                                                **
**       wraps J_K_FLIPFLOP with InvertClockEnable passed straight         **
**       through, and the wrapper's OWN default for that parameter is 1.   **
**       So a default-instantiated J_K_FLIPFLOP_EN clocks on the FALLING   **
**       edge of the `clock` pin. sysclk and EN are unused.                **
**   USE_ENABLE=1                                                          **
**       posedge sysclk, everything gated by EN:                           **
**           if (EN) begin preset -> 1; else reset -> 0; else tick -> JK   **
**       The `clock` pin is unused. Crucially, preset and reset are        **
**       INSIDE the if(EN) - with EN low, even preset and reset do         **
**       nothing at all. That is a real behavioural difference from the    **
**       original, where preset/reset act on every clock edge, and it is   **
**       checked explicitly.                                               **
**                                                                         **
** In BOTH modes preset and reset are SYNCHRONOUS and PRESET WINS when     **
** both are asserted together (the same priority as the original). With    **
** no clock edge nothing moves in either mode.                             **
**                                                                         **
** The J-K function itself, (~q & j) | (q & ~k), is checked from both      **
** starting states for all four j/k combinations, in both modes.           **
**                                                                         **
** BUILD MODE: no `ifdef - latch mode and -DFPGA_FF_MODE are identical.    **
**                                                                         **
** Run: cd Verilog/Shared/ndlib/sim && make test-jkffen                    **
**                                                                         **
** Last reviewed: 20-AUG-2026                                              **
** Ronny Hansen                                                            **
*****************************************************************************/
`timescale 1ns / 1ps
`default_nettype none

module J_K_FLIPFLOP_EN_tb;

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
  reg clock = 1'b0;
  reg j = 1'b0, k = 1'b0;
  reg preset = 1'b0, reset = 1'b0;
  reg tick = 1'b1;

  wire q_m0d, qn_m0d;   // mode 0, DEFAULT InvertClockEnable(1) -> falling edge
  wire q_m0p, qn_m0p;   // mode 0, InvertClockEnable(0)         -> rising edge
  wire q_m1,  qn_m1;    // mode 1, sysclk + EN

  J_K_FLIPFLOP_EN U_M0D (
      .sysclk(sysclk), .EN(EN), .clock(clock), .j(j), .k(k),
      .preset(preset), .reset(reset), .tick(tick), .q(q_m0d), .qBar(qn_m0d));

  J_K_FLIPFLOP_EN #(.USE_ENABLE(0), .InvertClockEnable(0)) U_M0P (
      .sysclk(sysclk), .EN(EN), .clock(clock), .j(j), .k(k),
      .preset(preset), .reset(reset), .tick(tick), .q(q_m0p), .qBar(qn_m0p));

  J_K_FLIPFLOP_EN #(.USE_ENABLE(1)) U_M1 (
      .sysclk(sysclk), .EN(EN), .clock(clock), .j(j), .k(k),
      .preset(preset), .reset(reset), .tick(tick), .q(q_m1), .qBar(qn_m1));

  task sys_tick; begin #5 sysclk = 1'b1; #5 sysclk = 1'b0; #1; end endtask
  task clk_rise; begin #5 clock = 1'b1; #1; end endtask
  task clk_fall; begin #5 clock = 1'b0; #1; end endtask
  task clk_cycle; begin clk_rise; clk_fall; end endtask

  // drive both a pin cycle and an enabled sysclk edge
  task both_edges; begin clk_cycle; sys_tick; end endtask

  task force_all(input v);
    begin
      preset = v; reset = ~v; j = 1'b0; k = 1'b0; tick = 1'b1; EN = 1'b1;
      both_edges;
      preset = 1'b0; reset = 1'b0;
    end
  endtask

  reg exp;
  integer ji, ki;

  initial begin
    $dumpfile("J_K_FLIPFLOP_EN_tb.vcd");
    $dumpvars(0, J_K_FLIPFLOP_EN_tb);
  end

  initial begin
    #1;
    `CHK("power-up q_m0d", q_m0d, 1'b0)
    `CHK("power-up q_m0p", q_m0p, 1'b0)
    `CHK("power-up q_m1",  q_m1,  1'b0)

    // ---- 1. NO EDGE OF ANY KIND: preset/reset are synchronous ----
    j = 1'b1; k = 1'b1; preset = 1'b1; reset = 1'b1; #20;
    `CHK("no edge: q_m0d holds", q_m0d, 1'b0)
    `CHK("no edge: q_m0p holds", q_m0p, 1'b0)
    `CHK("no edge: q_m1 holds",  q_m1,  1'b0)
    preset = 1'b0; reset = 1'b0; j = 1'b0; k = 1'b0;

    // ---- 2. which edge each instance uses ----
    j = 1'b1; k = 1'b0;
    clk_rise;
    `CHK("pin rise: mode0 InvertClockEnable(0) sets", q_m0p, 1'b1)
    `CHK("pin rise: mode0 DEFAULT (inverted) does NOT", q_m0d, 1'b0)
    `CHK("pin rise: mode1 ignores the clock pin", q_m1, 1'b0)
    clk_fall;
    `CHK("pin fall: mode0 DEFAULT sets", q_m0d, 1'b1)
    `CHK("pin fall: mode1 still untouched", q_m1, 1'b0)
    sys_tick;
    `CHK("sysclk edge with EN high: mode1 sets", q_m1, 1'b1)

    // ---- 3. mode 1: ENABLE HELD LOW freezes everything, INCLUDING
    //         preset and reset (they live inside the if(EN)) ----
    EN = 1'b0;
    j = 1'b0; k = 1'b1;            // would clear
    sys_tick; sys_tick;
    `CHK("mode1 EN low: the JK update is frozen", q_m1, 1'b1)
    reset = 1'b1;
    sys_tick; sys_tick;
    `CHK("mode1 EN low: even RESET does nothing", q_m1, 1'b1)
    preset = 1'b0;
    sys_tick;
    `CHK("mode1 EN low: still 1", q_m1, 1'b1)
    EN = 1'b1;
    sys_tick;
    `CHK("mode1 EN back high: the pending reset now clears it", q_m1, 1'b0)
    reset = 1'b0;

    // ---- 4. tick low freezes only the JK update, in both modes ----
    force_all(1'b1);
    tick = 1'b0; j = 1'b0; k = 1'b1;
    both_edges;
    `CHK("tick=0: q_m0p frozen", q_m0p, 1'b1)
    `CHK("tick=0: q_m0d frozen", q_m0d, 1'b1)
    `CHK("tick=0: q_m1 frozen",  q_m1,  1'b1)
    reset = 1'b1;
    both_edges;
    `CHK("tick=0 but reset=1: q_m0p cleared", q_m0p, 1'b0)
    `CHK("tick=0 but reset=1: q_m1 cleared",  q_m1,  1'b0)
    reset = 1'b0; tick = 1'b1;

    // ---- 5. SET AND RESET TOGETHER -> PRESET WINS, in both modes ----
    force_all(1'b0);
    `CHK("pre-cleared q_m0p", q_m0p, 1'b0)
    `CHK("pre-cleared q_m1",  q_m1,  1'b0)
    preset = 1'b1; reset = 1'b1;
    both_edges;
    `CHK("mode0: preset+reset -> PRESET WINS", q_m0p, 1'b1)
    `CHK("mode0 default-edge: PRESET WINS",    q_m0d, 1'b1)
    `CHK("mode1: preset+reset -> PRESET WINS", q_m1,  1'b1)
    preset = 1'b0; reset = 1'b0;

    // ---- 6. the JK truth table from both starting states, both modes ----
    for (ji = 0; ji <= 1; ji = ji + 1) begin
      for (ki = 0; ki <= 1; ki = ki + 1) begin
        force_all(1'b0);
        j = ji[0]; k = ki[0];
        exp = (~1'b0 & j) | (1'b0 & ~k);
        both_edges;
        `CHK("mode0 JK from q=0", q_m0p, exp)
        `CHK("mode1 JK from q=0", q_m1,  exp)

        force_all(1'b1);
        j = ji[0]; k = ki[0];
        exp = (~1'b1 & j) | (1'b1 & ~k);
        both_edges;
        `CHK("mode0 JK from q=1", q_m0p, exp)
        `CHK("mode1 JK from q=1", q_m1,  exp)
      end
    end
    j = 1'b0; k = 1'b0;

    `CHK("qBar_m0p complement", qn_m0p, ~q_m0p)
    `CHK("qBar_m0d complement", qn_m0d, ~q_m0d)
    `CHK("qBar_m1 complement",  qn_m1,  ~q_m1)

    $display("J_K_FLIPFLOP_EN_tb: checks=%0d failures=%0d", checks, errors);
    if (errors == 0) $display("TB_RESULT: PASS");
    else $display("TB_RESULT: FAIL");
    $finish;
  end

endmodule
`default_nettype wire

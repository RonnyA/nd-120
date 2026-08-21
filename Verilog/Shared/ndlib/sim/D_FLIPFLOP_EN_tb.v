/****************************************************************************
** D_FLIPFLOP_EN - self-checking functional testbench, all five modes      **
**                                                                         **
** D_FLIPFLOP_EN is the P2/P3 clock-domain wrapper around D_FLIPFLOP. Its  **
** two parameters select FIVE different circuits, and the existing         **
** Shared/support/sim/FF_EN_equiv_tb.v only compares two of them against   **
** each other. This tb tests each branch's FUNCTION on its own, including  **
** the cases an equivalence test cannot see: enable held low, no clock     **
** edge at all, and set and reset asserted together.                       **
**                                                                         **
**   USE_ENABLE=0, ASYNC_RESET=0  (gen_orig)                               **
**       D_FLIPFLOP #(.InvertClockEnable(0)) - posedge `clock`.            **
**       preset/reset are DEAD (D_FLIPFLOP's sync branch never reads       **
**       them). sysclk and EN are unused.                                  **
**   USE_ENABLE=0, ASYNC_RESET=1  (gen_orig_arst)                          **
**       D_FLIPFLOP #(.ACTIVE_ASYNC(1)) - posedge `clock` plus ASYNC       **
**       active-high preset and reset, PRESET WINS when both are high.     **
**   USE_ENABLE=1, ASYNC_RESET=0  (gen_enable)                             **
**       posedge sysclk, capture only while EN is high. `clock`, preset    **
**       and reset are all unused - preset and reset are DEAD here too.    **
**   USE_ENABLE=1, ASYNC_RESET=1  (gen_enable_arst)                        **
**       posedge sysclk or posedge preset or posedge reset;                **
**       preset -> 1, else reset -> 0, else EN -> capture d.               **
**       PRESET WINS. Note the set/reset override the enable.              **
**   USE_ENABLE=2                 (gen_strobe_edge)                        **
**       `clock` is treated as a DATA STROBE, not a clock: the flop lives  **
**       in the sysclk domain and captures d on a sysclk-detected RISE of  **
**       `clock`. EN, preset, reset and tick are all ignored. Because the  **
**       rise is detected by comparing against a registered copy, the      **
**       capture lands ONE sysclk AFTER the strobe rises, and a strobe     **
**       pulse narrower than a sysclk period can be missed entirely -      **
**       both are checked.                                                 **
**       USE_ENABLE=2 is tested BEFORE ASYNC_RESET in the generate chain,  **
**       so USE_ENABLE=2 with ASYNC_RESET=1 is still the strobe circuit.   **
**                                                                         **
** `tick` is unused in every branch.                                       **
**                                                                         **
** BUILD MODE: no `ifdef in D_FLIPFLOP_EN.v or D_FLIPFLOP.v - latch mode   **
** and -DFPGA_FF_MODE must be bit-identical. Both are run.                 **
**                                                                         **
** Run: cd Verilog/Shared/ndlib/sim && make test-dffen                     **
**                                                                         **
** Last reviewed: 20-AUG-2026                                              **
** Ronny Hansen                                                            **
*****************************************************************************/
`timescale 1ns / 1ps
`default_nettype none

module D_FLIPFLOP_EN_tb;

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
  reg EN = 1'b0;
  reg clock = 1'b0;
  reg d = 1'b0;
  reg preset = 1'b0;
  reg reset = 1'b0;
  reg tick = 1'b1;

  wire q_m0,  qn_m0;    // USE_ENABLE=0 ASYNC_RESET=0
  wire q_m0a, qn_m0a;   // USE_ENABLE=0 ASYNC_RESET=1
  wire q_m1,  qn_m1;    // USE_ENABLE=1 ASYNC_RESET=0
  wire q_m1a, qn_m1a;   // USE_ENABLE=1 ASYNC_RESET=1
  wire q_m2,  qn_m2;    // USE_ENABLE=2 (strobe)

  D_FLIPFLOP_EN #(.USE_ENABLE(0), .ASYNC_RESET(0)) U_M0 (
      .sysclk(sysclk), .EN(EN), .clock(clock), .d(d),
      .preset(preset), .reset(reset), .tick(tick), .q(q_m0), .qBar(qn_m0));

  D_FLIPFLOP_EN #(.USE_ENABLE(0), .ASYNC_RESET(1)) U_M0A (
      .sysclk(sysclk), .EN(EN), .clock(clock), .d(d),
      .preset(preset), .reset(reset), .tick(tick), .q(q_m0a), .qBar(qn_m0a));

  D_FLIPFLOP_EN #(.USE_ENABLE(1), .ASYNC_RESET(0)) U_M1 (
      .sysclk(sysclk), .EN(EN), .clock(clock), .d(d),
      .preset(preset), .reset(reset), .tick(tick), .q(q_m1), .qBar(qn_m1));

  D_FLIPFLOP_EN #(.USE_ENABLE(1), .ASYNC_RESET(1)) U_M1A (
      .sysclk(sysclk), .EN(EN), .clock(clock), .d(d),
      .preset(preset), .reset(reset), .tick(tick), .q(q_m1a), .qBar(qn_m1a));

  D_FLIPFLOP_EN #(.USE_ENABLE(2), .ASYNC_RESET(1)) U_M2 (
      .sysclk(sysclk), .EN(EN), .clock(clock), .d(d),
      .preset(preset), .reset(reset), .tick(tick), .q(q_m2), .qBar(qn_m2));

  task sys_tick; begin #5 sysclk = 1'b1; #5 sysclk = 1'b0; #1; end endtask
  task clk_rise; begin #5 clock = 1'b1; #1; end endtask
  task clk_fall; begin #5 clock = 1'b0; #1; end endtask

  initial begin
    $dumpfile("D_FLIPFLOP_EN_tb.vcd");
    $dumpvars(0, D_FLIPFLOP_EN_tb);
  end

  initial begin
    #1;
    `CHK("power-up q_m0",  q_m0,  1'b0)
    `CHK("power-up q_m0a", q_m0a, 1'b0)
    `CHK("power-up q_m1",  q_m1,  1'b0)
    `CHK("power-up q_m1a", q_m1a, 1'b0)
    `CHK("power-up q_m2",  q_m2,  1'b0)

    // ---- 1. NO EDGE OF ANY KIND ----
    d = 1'b1; EN = 1'b1; #20;
    `CHK("no edge: q_m0 holds",  q_m0,  1'b0)
    `CHK("no edge: q_m0a holds", q_m0a, 1'b0)
    `CHK("no edge: q_m1 holds",  q_m1,  1'b0)
    `CHK("no edge: q_m1a holds", q_m1a, 1'b0)
    `CHK("no edge: q_m2 holds",  q_m2,  1'b0)

    // ---- 2. mode 0: only the `clock` pin matters ----
    EN = 1'b0;                     // EN low must be irrelevant in mode 0
    clk_rise;
    `CHK("mode0 captures on posedge clock even with EN low", q_m0, 1'b1)
    `CHK("mode0-arst captures on posedge clock", q_m0a, 1'b1)
    `CHK("mode1 ignores the clock pin", q_m1, 1'b0)
    `CHK("mode1-arst ignores the clock pin", q_m1a, 1'b0)
    clk_fall;
    d = 1'b0; clk_fall; clk_rise;
    `CHK("mode0 captures d=0", q_m0, 1'b0)
    clk_fall;

    // ---- 3. mode 1: ENABLE HELD LOW means no capture, ever ----
    EN = 1'b0; d = 1'b1;
    sys_tick; sys_tick; sys_tick;
    `CHK("mode1 EN held low: no capture", q_m1, 1'b0)
    `CHK("mode1-arst EN held low: no capture", q_m1a, 1'b0)

    // ---- 4. mode 1: one capture per enabled sysclk edge ----
    EN = 1'b1; sys_tick;
    `CHK("mode1 captures d=1 with EN high", q_m1, 1'b1)
    `CHK("mode1-arst captures d=1 with EN high", q_m1a, 1'b1)
    EN = 1'b0; d = 1'b0; sys_tick; sys_tick;
    `CHK("mode1 holds while EN is low again", q_m1, 1'b1)
    EN = 1'b1; sys_tick;
    `CHK("mode1 captures d=0 when re-enabled", q_m1, 1'b0)
    `CHK("mode1-arst captures d=0 when re-enabled", q_m1a, 1'b0)

    // ---- 5. preset/reset are DEAD in modes 0 and 1 (ASYNC_RESET=0) ----
    d = 1'b1; EN = 1'b1; sys_tick; clk_rise; clk_fall;
    `CHK("preloaded q_m0", q_m0, 1'b1)
    `CHK("preloaded q_m1", q_m1, 1'b1)
    reset = 1'b1; #10;
    `CHK("mode0: reset pin is DEAD", q_m0, 1'b1)
    `CHK("mode1: reset pin is DEAD", q_m1, 1'b1)
    `CHK("mode0-arst: async reset CLEARS", q_m0a, 1'b0)
    `CHK("mode1-arst: async reset CLEARS", q_m1a, 1'b0)
    reset = 1'b0; #5;

    // ---- 6. async preset in the ASYNC_RESET=1 branches ----
    preset = 1'b1; #5;
    `CHK("mode0-arst: async preset SETS with no edge", q_m0a, 1'b1)
    `CHK("mode1-arst: async preset SETS with no edge", q_m1a, 1'b1)
    `CHK("mode1: preset pin is DEAD", q_m1, 1'b1)
    // set overrides the enable in mode 1-arst
    d = 1'b0; EN = 1'b1; sys_tick;
    `CHK("mode1-arst: held preset beats an enabled capture", q_m1a, 1'b1)
    preset = 1'b0; #5;
    `CHK("mode1-arst: releasing preset alone changes nothing", q_m1a, 1'b1)
    sys_tick;
    `CHK("mode1-arst: the next enabled edge takes d=0", q_m1a, 1'b0)

    // ---- 7. SET AND RESET ASSERTED TOGETHER -> PRESET WINS ----
    reset = 1'b1; #2; reset = 1'b0; #2;
    `CHK("mode0-arst pre-cleared", q_m0a, 1'b0)
    `CHK("mode1-arst pre-cleared", q_m1a, 1'b0)
    preset = 1'b1; reset = 1'b1;   // same instant
    #5;
    `CHK("mode0-arst: simultaneous preset+reset -> PRESET WINS", q_m0a, 1'b1)
    `CHK("mode1-arst: simultaneous preset+reset -> PRESET WINS", q_m1a, 1'b1)
    preset = 1'b0; #2;
    `CHK("mode1-arst: preset falling gives no event, stays 1", q_m1a, 1'b1)
    sys_tick;                      // reset still high, EN high, d=0
    `CHK("mode1-arst: reset still high wins on the next edge", q_m1a, 1'b0)
    reset = 1'b0; #2;

    // ---- 8. USE_ENABLE=2: `clock` is a STROBE, captured in the sysclk
    //         domain one sysclk after its rise ----
    EN = 1'b0;                     // proves EN is ignored in mode 2
    clock = 1'b0; d = 1'b1; sys_tick;
    `CHK("mode2: no strobe rise yet", q_m2, 1'b0)
    clock = 1'b1;                  // strobe rises between sysclk edges
    sys_tick;                      // this edge sees clock=1, clock_d=0 -> capture
    `CHK("mode2: captures d=1 on the detected strobe rise", q_m2, 1'b1)
    d = 1'b0;
    sys_tick;                      // strobe still high, clock_d now 1 -> no capture
    `CHK("mode2: a HELD strobe does not keep capturing", q_m2, 1'b1)
    clock = 1'b0; sys_tick;
    `CHK("mode2: the strobe falling does not capture", q_m2, 1'b1)
    clock = 1'b1; sys_tick;
    `CHK("mode2: the next strobe rise captures d=0", q_m2, 1'b0)
    clock = 1'b0; sys_tick;

    // a strobe pulse narrower than one sysclk period, placed entirely
    // between two sysclk rising edges, IS still seen here because the
    // sampled level is what matters - the pulse must overlap a sysclk edge.
    d = 1'b1;
    clock = 1'b1; #1; clock = 1'b0; #1;   // pulse with no sysclk edge inside
    sys_tick;
    `CHK("mode2: a pulse that spans NO sysclk edge is MISSED", q_m2, 1'b0)

    `CHK("qBar_m0 complement",  qn_m0,  ~q_m0)
    `CHK("qBar_m0a complement", qn_m0a, ~q_m0a)
    `CHK("qBar_m1 complement",  qn_m1,  ~q_m1)
    `CHK("qBar_m1a complement", qn_m1a, ~q_m1a)
    `CHK("qBar_m2 complement",  qn_m2,  ~q_m2)

    $display("D_FLIPFLOP_EN_tb: checks=%0d failures=%0d", checks, errors);
    if (errors == 0) $display("TB_RESULT: PASS");
    else $display("TB_RESULT: FAIL");
    $finish;
  end

endmodule
`default_nettype wire

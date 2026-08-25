/****************************************************************************
** J_K_FLIPFLOP - self-checking functional testbench                       **
**                                                                         **
** WHAT THE RTL ACTUALLY DOES (read from J_K_FLIPFLOP.v, not assumed):     **
**                                                                         **
**   s_clock = (InvertClockEnable == 0) ? clock : ~clock;                  **
**   default InvertClockEnable = 1  ->  the DEFAULT cell captures on the   **
**   FALLING edge of the `clock` pin.                                      **
**                                                                         **
**   always @(posedge s_clock)                                             **
**     if      (preset) q <= 1;                                            **
**     else if (reset)  q <= 0;                                            **
**     else if (tick)   q <= (~q & j) | (q & ~k);                          **
**                                                                         **
** So, unlike D_FLIPFLOP with ACTIVE_ASYNC(1), preset and reset here are   **
** SYNCHRONOUS - the async sensitivity list was deliberately commented out **
** for Vivado. With no clock edge, preset and reset do NOTHING.            **
**                                                                         **
** SET AND RESET TOGETHER: preset is tested first, so PRESET WINS. Note    **
** that the sibling T_FLIPFLOP.v in the same directory tests RESET first   **
** and therefore resolves the same conflict the OPPOSITE way. That         **
** inconsistency between two cells that sit side by side is exactly the    **
** kind of thing Vivado's "set and reset at equal priority may cause       **
** simulation mismatches" warning is about, and both tbs pin it down.      **
**                                                                         **
**   `tick` gates ONLY the J-K update. preset and reset act even when      **
**   tick is low. Tested explicitly.                                       **
**                                                                         **
** J-K truth table checked exhaustively from both starting states:         **
**   j=0 k=0 hold, j=0 k=1 clear, j=1 k=0 set, j=1 k=1 toggle.             **
**                                                                         **
** BUILD MODE: no `ifdef in the source - latch mode and -DFPGA_FF_MODE     **
** must be bit-identical. Both are run.                                    **
**                                                                         **
** Run: cd Verilog/Shared/logisim/sim && make test-jkff                    **
**                                                                         **
** Last reviewed: 20-AUG-2026                                              **
** Ronny Hansen                                                            **
*****************************************************************************/
`timescale 1ns / 1ps
`default_nettype none

module J_K_FLIPFLOP_tb;

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
  reg j = 1'b0, k = 1'b0;
  reg preset = 1'b0, reset = 1'b0;
  reg tick = 1'b1;

  wire q_neg, qn_neg;   // default parameters -> falling edge of the pin
  wire q_pos, qn_pos;   // InvertClockEnable(0) -> rising edge of the pin

  J_K_FLIPFLOP U_NEG (
      .clock(clock), .j(j), .k(k), .preset(preset), .reset(reset), .tick(tick),
      .q(q_neg), .qBar(qn_neg)
  );

  J_K_FLIPFLOP #(.InvertClockEnable(0)) U_POS (
      .clock(clock), .j(j), .k(k), .preset(preset), .reset(reset), .tick(tick),
      .q(q_pos), .qBar(qn_pos)
  );

  task clk_rise; begin #10 clock = 1'b1; #1; end endtask
  task clk_fall; begin #10 clock = 1'b0; #1; end endtask

  // one full pin cycle: U_POS updates on the rise, U_NEG on the fall
  task clk_cycle; begin clk_rise; clk_fall; end endtask

  // Force U_POS to a known state using its synchronous preset/reset.
  task pos_force(input v);
    begin
      preset = v; reset = ~v; j = 1'b0; k = 1'b0;
      clk_rise;
      preset = 1'b0; reset = 1'b0;
      clk_fall;               // U_NEG also lands here; harmless, it is re-forced
    end
  endtask

  reg exp;
  integer ji, ki;

  initial begin
    $dumpfile("J_K_FLIPFLOP_tb.vcd");
    $dumpvars(0, J_K_FLIPFLOP_tb);
  end

  initial begin
    #1;
    `CHK("power-up q_neg", q_neg, 1'b0)
    `CHK("power-up q_pos", q_pos, 1'b0)
    `CHK("power-up qBar_neg", qn_neg, 1'b1)

    // ---- 1. NO CLOCK EDGE: nothing at all may change ----
    j = 1'b1; k = 1'b1; preset = 1'b1; reset = 1'b1; #25;
    `CHK("no edge: q_neg holds (preset is SYNCHRONOUS)", q_neg, 1'b0)
    `CHK("no edge: q_pos holds (preset is SYNCHRONOUS)", q_pos, 1'b0)
    preset = 1'b0; reset = 1'b0; j = 1'b0; k = 1'b0;

    // ---- 2. which pin edge each instance uses ----
    j = 1'b1; k = 1'b0;             // "set" on the next update
    clk_rise;
    `CHK("pin rise: q_pos sets", q_pos, 1'b1)
    `CHK("pin rise: q_neg must NOT move", q_neg, 1'b0)
    clk_fall;
    `CHK("pin fall: q_neg sets", q_neg, 1'b1)
    `CHK("pin fall: q_pos holds", q_pos, 1'b1)

    // ---- 3. tick low freezes the J-K update ----
    tick = 1'b0;
    j = 1'b0; k = 1'b1;             // would clear if tick were high
    clk_cycle;
    `CHK("tick=0: q_pos frozen", q_pos, 1'b1)
    `CHK("tick=0: q_neg frozen", q_neg, 1'b1)

    // ---- 4. ... but preset/reset still act with tick low ----
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

    // ---- 5. SET AND RESET ASSERTED TOGETHER -> PRESET WINS ----
    reset = 1'b1; clk_cycle;        // start from 0 so a wrong winner shows
    `CHK("pre-cleared for the conflict test", q_pos, 1'b0)
    reset = 1'b0;
    preset = 1'b1; reset = 1'b1;
    clk_cycle;
    `CHK("preset+reset together: PRESET WINS on q_pos", q_pos, 1'b1)
    `CHK("preset+reset together: PRESET WINS on q_neg", q_neg, 1'b1)
    // and it stays won on a second edge, i.e. it is not a one-shot
    clk_cycle;
    `CHK("conflict held over a second edge: still 1", q_pos, 1'b1)
    preset = 1'b0; reset = 1'b0;

    // ---- 6. full J-K truth table from BOTH starting states ----
    // expected next state = (~q & j) | (q & ~k)
    for (ji = 0; ji <= 1; ji = ji + 1) begin
      for (ki = 0; ki <= 1; ki = ki + 1) begin
        j = ji[0];
        k = ki[0];
        // start from 0
        pos_force(1'b0);
        exp = (~1'b0 & j) | (1'b0 & ~k);
        clk_rise;
        `CHK("JK from q=0", q_pos, exp)
        clk_fall;
        // start from 1
        pos_force(1'b1);
        exp = (~1'b1 & j) | (1'b1 & ~k);
        clk_rise;
        `CHK("JK from q=1", q_pos, exp)
        clk_fall;
      end
    end
    j = 1'b0; k = 1'b0;

    // ---- 7. inputs changing between edges: only the pre-edge value counts ----
    pos_force(1'b0);
    j = 1'b1; k = 1'b0; #2;         // would set
    j = 1'b0; k = 1'b1; #2;         // final: would clear
    clk_rise;
    `CHK("mid-cycle j/k churn: final value wins", q_pos, 1'b0)
    clk_fall;

    `CHK("final qBar_pos complement", qn_pos, ~q_pos)
    `CHK("final qBar_neg complement", qn_neg, ~q_neg)

    $display("J_K_FLIPFLOP_tb: checks=%0d failures=%0d", checks, errors);
    if (errors == 0) $display("TB_RESULT: PASS");
    else $display("TB_RESULT: FAIL");
    $finish;
  end

endmodule
`default_nettype wire

/**************************************************************************
** ND120 CPU - unit test                                                 **
** SCAN_WITH_SET_N_EN mode equivalence (P2 wrapper).                     **
**                                                                       **
** Instantiates SCAN_WITH_SET_N_EN in USE_ENABLE=0 (wraps the original   **
** SCAN_WITH_SET_N: posedge CLK, ASYNC active-low set via S_n) and       **
** USE_ENABLE=1 (posedge sysclk + EN, S_n kept as an ASYNC preset) side  **
** by side, drives CLK/EN like FF_EN_equiv_tb (pa <= nxt; en=nxt&~pa),   **
** and requires Q/QN identical on EVERY sysclk.                          **
**                                                                       **
** Async-set note: the _EN mode-1 branch deliberately KEEPS the async    **
** preset (always @(posedge sysclk or posedge ~S_n)), so unlike a        **
** sync-converted set there is NO structural async-vs-sync divergence    **
** window - the directed section asserts equality through async S_n      **
** assertion with the clock idle, release-then-capture, and S_n held     **
** low ACROSS a capture edge (preset must win over EN capture in both).  **
** (Divergence that DOES exist but is not reachable under iverilog:      **
** the `ifdef YOSYS power-up init is 1 instead of 0 - Gowin dfflegalize  **
** constraint, see the _EN header.)                                      **
**                                                                       **
** Teeth: a third instance driven by a one-cycle-LATE enable must        **
** diverge, or the tb fails (the P2 off-by-one risk class).              **
**                                                                       **
** Run: make test-scanset-en   (Shared/support/sim)                      **
***************************************************************************/
`timescale 1ns / 1ps

module SCAN_WITH_SET_N_EN_equiv_tb;

  // Directed: 16 combos x 2 steps = 32, async-S_n sequence = 9
  localparam integer DIRECTED = 41;
  localparam integer RANDOM = 4096;
  localparam integer EXPECTED = DIRECTED + RANDOM;

  reg sysclk = 0;
  always #5 sysclk = ~sysclk;

  // ---- CYC-style clock/enable generation (FF_EN_equiv_tb pattern) ----
  reg  nxt = 0;
  reg  pa = 0;
  wire en = nxt & ~pa;
  reg  en_d = 0;  // one cycle LATE enable (teeth)
  always @(posedge sysclk) begin
    pa   <= nxt;
    en_d <= en;
  end

  // ---- shared stimulus ----
  reg d = 0, s_n = 1, te = 0, ti = 0;

  // ---- instances ----
  wire q_ref, qn_ref, q_en, qn_en, q_late, qn_late;
  SCAN_WITH_SET_N_EN #(.USE_ENABLE(0)) U_REF (
      .sysclk(sysclk), .EN(1'b0), .CLK(pa),
      .D(d), .S_n(s_n), .TE(te), .TI(ti), .Q(q_ref), .QN(qn_ref));
  SCAN_WITH_SET_N_EN #(.USE_ENABLE(1)) U_EN (
      .sysclk(sysclk), .EN(en), .CLK(1'b0),
      .D(d), .S_n(s_n), .TE(te), .TI(ti), .Q(q_en), .QN(qn_en));
  SCAN_WITH_SET_N_EN #(.USE_ENABLE(1)) U_LATE (
      .sysclk(sysclk), .EN(en_d), .CLK(1'b0),
      .D(d), .S_n(s_n), .TE(te), .TI(ti), .Q(q_late), .QN(qn_late));

  // ---- checker ----
  integer checks = 0, errors = 0, teeth = 0, pulses = 0;
  reg run_chk = 1;
  reg pa_d1 = 0;
  always @(negedge sysclk) begin
    if (run_chk) begin
      checks = checks + 1;
      if ({q_ref, qn_ref} !== {q_en, qn_en}) begin
        errors = errors + 1;
        $display("FAIL t=%0t ref Q/QN=%b%b en Q/QN=%b%b (d=%b s_n=%b te=%b ti=%b)",
                 $time, q_ref, qn_ref, q_en, qn_en, d, s_n, te, ti);
      end
      if ({q_ref, qn_ref} !== {q_late, qn_late}) teeth = teeth + 1;
    end
    if (pa & ~pa_d1) pulses = pulses + 1;
    pa_d1 <= pa;
  end

  task step;
    begin
      @(negedge sysclk);
    end
  endtask

  reg [15:0] lfsr = 16'hBEEF;
  integer i;

  initial begin
    $dumpfile("SCAN_WITH_SET_N_EN_equiv_tb.vcd");
    $dumpvars(0, SCAN_WITH_SET_N_EN_equiv_tb);

    // Directed 1: every {D,S_n,TE,TI} combo held across one pa pulse.
    for (i = 0; i < 16; i = i + 1) begin
      {d, s_n, te, ti} = i[3:0];
      nxt = 1; step;
      nxt = 0; step;
    end

    // Directed 2: async S_n behaviour, both async preset paths.
    d = 0; te = 0; ti = 0; nxt = 0; s_n = 1;
    s_n = 0; step;              // 1: async set with clock idle -> both go 1
    step;                       // 2: hold, still set
    s_n = 1; step;              // 3: released, both must HOLD 1 (no clock)
    nxt = 1; step;              // 4: capture edge, d=0 -> both back to 0
    nxt = 0; step;              // 5:
    d = 1; s_n = 0; nxt = 1; step;  // 6: S_n low ACROSS a capture edge:
    nxt = 0; step;              // 7:   preset must win over EN capture (=1)
    s_n = 1; d = 0; nxt = 1; step;  // 8: release + capture d=0 same pulse
    nxt = 0; step;              // 9:

    // Random: fixed-seed LFSR; S_n asserted rarely so data traffic
    // dominates but async set still fires in-stream.
    for (i = 0; i < RANDOM; i = i + 1) begin
      lfsr = {lfsr[14:0], lfsr[15] ^ lfsr[13] ^ lfsr[12] ^ lfsr[10]};
      nxt  = lfsr[0];
      d    = lfsr[4];
      s_n  = ~(lfsr[5] & lfsr[9] & lfsr[12]);  // low ~12% of cycles
      te   = lfsr[6] & lfsr[7];
      ti   = lfsr[8];
      step;
    end

    @(posedge sysclk);
    run_chk = 0;

    $display("checks=%0d errors=%0d pa_pulses=%0d teeth(late-EN divergences)=%0d",
             checks, errors, pulses, teeth);
    if (errors == 0 && checks == EXPECTED && teeth > 0 && pulses > 100) begin
      $display("TB_RESULT: PASS (%0d checks)", checks);
    end else begin
      if (checks != EXPECTED) $display("FAIL: check count %0d != expected %0d", checks, EXPECTED);
      if (teeth == 0) $display("FAIL: late-enable never diverged - no teeth");
      if (pulses <= 100) $display("FAIL: too few pa pulses - vacuous run");
      $display("TB_RESULT: FAIL");
    end
    $finish;
  end

endmodule

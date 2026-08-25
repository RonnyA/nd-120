/**************************************************************************
** ND120 CPU - unit test                                                 **
** SCAN_WITH_RESET_N_EN mode equivalence (P2 wrapper).                   **
**                                                                       **
** Instantiates SCAN_WITH_RESET_N_EN in USE_ENABLE=0 (wraps the original **
** SCAN_WITH_RESET_N, posedge CLK) and USE_ENABLE=1 (posedge sysclk +    **
** EN) side by side, drives the CLK/EN pair exactly like FF_EN_equiv_tb  **
** (pa <= nxt registered level; en = nxt & ~pa aligned enable), and      **
** requires Q/QN identical on EVERY sysclk.                              **
**                                                                       **
** R_n note (verified against the sources, see the _EN header): the      **
** original wires MEMORY_4 as a plain sync D_FLIPFLOP (ACTIVE_ASYNC=0)   **
** whose gen_sync branch IGNORES preset/reset - so R_n has NO EFFECT in  **
** EITHER mode. The directed R_n-wiggle section below documents that:    **
** it drives R_n through both levels, async and across capture edges,    **
** and still requires exact equality (both sides ignore it).             **
**                                                                       **
** Teeth: a third instance driven by a one-cycle-LATE enable must        **
** diverge, or the tb fails (the P2 off-by-one risk class).              **
**                                                                       **
** Run: make test-scanrst-en   (Shared/support/sim)                      **
***************************************************************************/
`timescale 1ns / 1ps

module SCAN_WITH_RESET_N_EN_equiv_tb;

  // Directed: 16 input combos x (1 pulse = 2 steps) = 32, R_n wiggle = 8
  localparam integer DIRECTED = 40;
  localparam integer RANDOM = 4096;
  localparam integer EXPECTED = DIRECTED + RANDOM;

  reg sysclk = 0;
  always #5 sysclk = ~sysclk;

  // ---- CYC-style clock/enable generation (FF_EN_equiv_tb pattern) ----
  reg  nxt = 0;   // "next level"
  reg  pa = 0;    // phase-accurate clock level
  wire en = nxt & ~pa;
  reg  en_d = 0;  // one cycle LATE enable (teeth)
  always @(posedge sysclk) begin
    pa   <= nxt;
    en_d <= en;
  end

  // ---- shared stimulus ----
  reg d = 0, r_n = 1, te = 0, ti = 0;

  // ---- instances ----
  wire q_ref, qn_ref, q_en, qn_en, q_late, qn_late;
  SCAN_WITH_RESET_N_EN #(.USE_ENABLE(0)) U_REF (
      .sysclk(sysclk), .EN(1'b0), .CLK(pa),
      .D(d), .R_n(r_n), .TE(te), .TI(ti), .Q(q_ref), .QN(qn_ref));
  SCAN_WITH_RESET_N_EN #(.USE_ENABLE(1)) U_EN (
      .sysclk(sysclk), .EN(en), .CLK(1'b0),
      .D(d), .R_n(r_n), .TE(te), .TI(ti), .Q(q_en), .QN(qn_en));
  SCAN_WITH_RESET_N_EN #(.USE_ENABLE(1)) U_LATE (
      .sysclk(sysclk), .EN(en_d), .CLK(1'b0),
      .D(d), .R_n(r_n), .TE(te), .TI(ti), .Q(q_late), .QN(qn_late));

  // ---- checker ----
  integer checks = 0, errors = 0, teeth = 0, pulses = 0;
  reg run_chk = 1;
  reg pa_d1 = 0;
  always @(negedge sysclk) begin
    if (run_chk) begin
      checks = checks + 1;
      if ({q_ref, qn_ref} !== {q_en, qn_en}) begin
        errors = errors + 1;
        $display("FAIL t=%0t ref Q/QN=%b%b en Q/QN=%b%b (d=%b r_n=%b te=%b ti=%b)",
                 $time, q_ref, qn_ref, q_en, qn_en, d, r_n, te, ti);
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

  reg [15:0] lfsr = 16'hACE1;
  integer i;

  initial begin
    $dumpfile("SCAN_WITH_RESET_N_EN_equiv_tb.vcd");
    $dumpvars(0, SCAN_WITH_RESET_N_EN_equiv_tb);

    // Directed 1: every {D,R_n,TE,TI} combo held across one pa pulse.
    for (i = 0; i < 16; i = i + 1) begin
      {d, r_n, te, ti} = i[3:0];
      nxt = 1; step;
      nxt = 0; step;
    end

    // Directed 2: R_n wiggle - toggled every cycle, first with pa held
    // HIGH multi-cycle (data changing underneath is covered in the random
    // phase), then with pa idle. DOCUMENTS that R_n is a no-op in BOTH
    // modes: equality is still required on every cycle.
    d = 1; te = 0; ti = 0;
    for (i = 0; i < 8; i = i + 1) begin
      r_n = i[0];
      nxt = (i < 6);
      step;
    end
    nxt = 0;

    // Random: fixed-seed LFSR, irregular pa phases incl. multi-cycle-high
    // with data/scan/reset inputs changing underneath.
    for (i = 0; i < RANDOM; i = i + 1) begin
      lfsr = {lfsr[14:0], lfsr[15] ^ lfsr[13] ^ lfsr[12] ^ lfsr[10]};
      nxt  = lfsr[0];
      d    = lfsr[4];
      r_n  = lfsr[5];
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

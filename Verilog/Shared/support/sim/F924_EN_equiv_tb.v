/**************************************************************************
** ND120 CPU - unit test                                                 **
** F924_EN mode equivalence (P2 wrapper).                                **
**                                                                       **
** Instantiates F924_EN in USE_ENABLE=0 (wraps the original F924 NEC     **
** 4-bit D flip-flop, posedge C_H05; base module lives in                **
** DECODE-GateArray/DGA/circuit/F924.v) and USE_ENABLE=1 (structural     **
** copy with D_FLIPFLOP_EN flops, posedge sysclk + EN) side by side,     **
** drives C_H05/EN like FF_EN_equiv_tb (pa <= nxt; en = nxt & ~pa),      **
** and requires all 8 outputs (Q0..Q3 + inverted) identical on EVERY     **
** sysclk.                                                               **
**                                                                       **
** Directed coverage: every 4-bit data pattern captured once. Random     **
** phase changes data under multi-cycle-high pa phases.                  **
**                                                                       **
** Teeth: a third instance driven by a one-cycle-LATE enable must        **
** diverge, or the tb fails (the P2 off-by-one risk class).              **
**                                                                       **
** Run: make test-f924-en   (Shared/support/sim)                         **
***************************************************************************/
`timescale 1ns / 1ps

module F924_EN_equiv_tb;

  // Directed: 16 data patterns x (1 pulse = 2 steps) = 32
  localparam integer DIRECTED = 32;
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
  reg [3:0] data = 4'b0000;

  // ---- instances ----
  wire [7:0] o_ref, o_en, o_late;  // {Q0..Q3, Q0B..Q3B}
  F924_EN #(.USE_ENABLE(0)) U_REF (
      .sysclk(sysclk), .EN(1'b0), .C_H05(pa),
      .D0_H01(data[0]), .D1_H02(data[1]), .D2_H03(data[2]), .D3_H04(data[3]),
      .N01_Q0(o_ref[7]), .N02_Q1(o_ref[6]), .N03_Q2(o_ref[5]), .N04_Q3(o_ref[4]),
      .N05_Q0B(o_ref[3]), .N06_Q1B(o_ref[2]), .N07_Q2B(o_ref[1]), .N08_Q3B(o_ref[0]));
  F924_EN #(.USE_ENABLE(1)) U_EN (
      .sysclk(sysclk), .EN(en), .C_H05(1'b0),
      .D0_H01(data[0]), .D1_H02(data[1]), .D2_H03(data[2]), .D3_H04(data[3]),
      .N01_Q0(o_en[7]), .N02_Q1(o_en[6]), .N03_Q2(o_en[5]), .N04_Q3(o_en[4]),
      .N05_Q0B(o_en[3]), .N06_Q1B(o_en[2]), .N07_Q2B(o_en[1]), .N08_Q3B(o_en[0]));
  F924_EN #(.USE_ENABLE(1)) U_LATE (
      .sysclk(sysclk), .EN(en_d), .C_H05(1'b0),
      .D0_H01(data[0]), .D1_H02(data[1]), .D2_H03(data[2]), .D3_H04(data[3]),
      .N01_Q0(o_late[7]), .N02_Q1(o_late[6]), .N03_Q2(o_late[5]), .N04_Q3(o_late[4]),
      .N05_Q0B(o_late[3]), .N06_Q1B(o_late[2]), .N07_Q2B(o_late[1]), .N08_Q3B(o_late[0]));

  // ---- checker ----
  integer checks = 0, errors = 0, teeth = 0, pulses = 0;
  reg run_chk = 1;
  reg pa_d1 = 0;
  always @(negedge sysclk) begin
    if (run_chk) begin
      checks = checks + 1;
      if (o_ref !== o_en) begin
        errors = errors + 1;
        $display("FAIL t=%0t ref=%b en=%b (data=%b)", $time, o_ref, o_en, data);
      end
      if (o_ref !== o_late) teeth = teeth + 1;
    end
    if (pa & ~pa_d1) pulses = pulses + 1;
    pa_d1 <= pa;
  end

  task step;
    begin
      @(negedge sysclk);
    end
  endtask

  reg [15:0] lfsr = 16'hD1CE;
  integer i;

  initial begin
    $dumpfile("F924_EN_equiv_tb.vcd");
    $dumpvars(0, F924_EN_equiv_tb);

    // Directed: capture every 4-bit data pattern once.
    for (i = 0; i < 16; i = i + 1) begin
      data = i[3:0];
      nxt = 1; step;
      nxt = 0; step;
    end

    // Random: fixed-seed LFSR, irregular pa phases incl. multi-cycle-high
    // with data changing underneath.
    for (i = 0; i < RANDOM; i = i + 1) begin
      lfsr = {lfsr[14:0], lfsr[15] ^ lfsr[13] ^ lfsr[12] ^ lfsr[10]};
      nxt  = lfsr[0];
      data = lfsr[7:4];
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

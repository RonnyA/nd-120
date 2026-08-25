/**************************************************************************
** ND120 CPU - unit test                                                 **
** SR44_EN mode equivalence (P2 wrapper).                                **
**                                                                       **
** Instantiates SR44_EN in USE_ENABLE=0 (wraps the original SR44 4-bit   **
** load/shift register, posedge CP) and USE_ENABLE=1 (posedge sysclk +   **
** EN) side by side, drives CP/EN like FF_EN_equiv_tb (pa <= nxt;        **
** en = nxt & ~pa), and requires all 8 outputs (QA..QD + inverted)       **
** identical on EVERY sysclk.                                            **
**                                                                       **
** Directed coverage: L=1 parallel load of all 16 {A,B,C,D} patterns;    **
** L=0 serial shift of a known SI pattern through the whole chain        **
** (SI -> QA -> QB -> QC -> QD). Random phase mixes load/shift with     **
** data changing under multi-cycle-high pa phases.                       **
**                                                                       **
** Teeth: a third instance driven by a one-cycle-LATE enable must        **
** diverge, or the tb fails (the P2 off-by-one risk class).              **
**                                                                       **
** Run: make test-sr44-en   (Shared/support/sim)                         **
***************************************************************************/
`timescale 1ns / 1ps

module SR44_EN_equiv_tb;

  // Directed: 16 loads x 2 + clear load x 2 + 8 shift pulses x 2 = 50
  localparam integer DIRECTED = 50;
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
  reg a = 0, b = 0, c = 0, d = 0, l = 0, si = 0;

  // ---- instances ----
  wire [7:0] o_ref, o_en, o_late;  // {QA,QAN,QB,QBN,QC,QCN,QD,QDN}
  SR44_EN #(.USE_ENABLE(0)) U_REF (
      .sysclk(sysclk), .EN(1'b0), .CP(pa),
      .A(a), .B(b), .C(c), .D(d), .L(l), .SI(si),
      .QA(o_ref[7]), .QAN(o_ref[6]), .QB(o_ref[5]), .QBN(o_ref[4]),
      .QC(o_ref[3]), .QCN(o_ref[2]), .QD(o_ref[1]), .QDN(o_ref[0]));
  SR44_EN #(.USE_ENABLE(1)) U_EN (
      .sysclk(sysclk), .EN(en), .CP(1'b0),
      .A(a), .B(b), .C(c), .D(d), .L(l), .SI(si),
      .QA(o_en[7]), .QAN(o_en[6]), .QB(o_en[5]), .QBN(o_en[4]),
      .QC(o_en[3]), .QCN(o_en[2]), .QD(o_en[1]), .QDN(o_en[0]));
  SR44_EN #(.USE_ENABLE(1)) U_LATE (
      .sysclk(sysclk), .EN(en_d), .CP(1'b0),
      .A(a), .B(b), .C(c), .D(d), .L(l), .SI(si),
      .QA(o_late[7]), .QAN(o_late[6]), .QB(o_late[5]), .QBN(o_late[4]),
      .QC(o_late[3]), .QCN(o_late[2]), .QD(o_late[1]), .QDN(o_late[0]));

  // ---- checker ----
  integer checks = 0, errors = 0, teeth = 0, pulses = 0;
  reg run_chk = 1;
  reg pa_d1 = 0;
  always @(negedge sysclk) begin
    if (run_chk) begin
      checks = checks + 1;
      if (o_ref !== o_en) begin
        errors = errors + 1;
        $display("FAIL t=%0t ref=%b en=%b (abcd=%b%b%b%b l=%b si=%b)",
                 $time, o_ref, o_en, a, b, c, d, l, si);
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

  reg [15:0] lfsr = 16'hC0DE;
  reg [7:0] shifts;
  integer i;

  initial begin
    $dumpfile("SR44_EN_equiv_tb.vcd");
    $dumpvars(0, SR44_EN_equiv_tb);

    // Directed 1: parallel load of every {A,B,C,D} pattern (L=1).
    l = 1; si = 0;
    for (i = 0; i < 16; i = i + 1) begin
      {a, b, c, d} = i[3:0];
      nxt = 1; step;
      nxt = 0; step;
    end

    // Directed 2: clear via load 0, then shift a known pattern through
    // the full chain SI -> QA -> QB -> QC -> QD (L=0).
    {a, b, c, d} = 4'b0000; l = 1;
    nxt = 1; step; nxt = 0; step;
    l = 0;
    shifts = 8'b11010010;
    for (i = 0; i < 8; i = i + 1) begin
      si = shifts[i];
      nxt = 1; step;
      nxt = 0; step;
    end

    // Random: fixed-seed LFSR, load/shift mix, irregular pa phases.
    for (i = 0; i < RANDOM; i = i + 1) begin
      lfsr = {lfsr[14:0], lfsr[15] ^ lfsr[13] ^ lfsr[12] ^ lfsr[10]};
      nxt  = lfsr[0];
      {a, b, c, d} = lfsr[7:4];
      l    = lfsr[8] & lfsr[9];   // shift-dominant traffic
      si   = lfsr[11];
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

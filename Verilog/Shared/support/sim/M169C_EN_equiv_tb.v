/**************************************************************************
** ND120 CPU - unit test                                                 **
** M169C_EN mode equivalence (P2 wrapper).                               **
**                                                                       **
** Instantiates M169C_EN in USE_ENABLE=0 (wraps the original M169C,      **
** 74LS169 sync 4-bit up/down counter, posedge CP) and USE_ENABLE=1      **
** (structural copy with D_FLIPFLOP_EN flops, posedge sysclk + EN) side  **
** by side, drives CP/EN like FF_EN_equiv_tb (pa <= nxt; en = nxt&~pa),  **
** and requires QA..QD AND CON identical on EVERY sysclk.                **
**                                                                       **
** Control semantics (read from the M169C gate netlist):                 **
**   NL = 0 -> parallel load {A,B,C,D} (active-LOW load, 74169 PE_n)     **
**   NL = 1, PN = 0, TN = 0 -> count (UP=1 up, UP=0 down)                **
**   PN=1 or TN=1 -> hold; CON (terminal count) is combinational and     **
**   also depends on TN.                                                 **
**                                                                       **
** Directed coverage: loads (0,17,5,12 octal-ish patterns), 20 up        **
** counts (wrap + CON at 15), 20 down counts (wrap + CON at 0), all 4    **
** PN/TN enable combos held over pulses. Random phase mixes everything.  **
**                                                                       **
** Teeth: a third instance driven by a one-cycle-LATE enable must        **
** diverge, or the tb fails (the P2 off-by-one risk class).              **
**                                                                       **
** Run: make test-m169c-en   (Shared/support/sim)                        **
***************************************************************************/
`timescale 1ns / 1ps

module M169C_EN_equiv_tb;

  // Directed: 4 loads x 2 + 20 up x 2 + 20 down x 2 + load x 2
  //           + 4 enable-combos x 2 pulses x 2 = 106
  localparam integer DIRECTED = 106;
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
  reg a = 0, b = 0, c = 0, d = 0;
  reg nl = 1, pn = 0, tn = 0, up = 1;

  // ---- instances ----
  wire [4:0] o_ref, o_en, o_late;  // {CON,QA,QB,QC,QD}
  M169C_EN #(.USE_ENABLE(0)) U_REF (
      .sysclk(sysclk), .EN(1'b0), .CP(pa),
      .A(a), .B(b), .C(c), .D(d), .NL(nl), .PN(pn), .TN(tn), .UP(up),
      .CON(o_ref[4]), .QA(o_ref[3]), .QB(o_ref[2]), .QC(o_ref[1]), .QD(o_ref[0]));
  M169C_EN #(.USE_ENABLE(1)) U_EN (
      .sysclk(sysclk), .EN(en), .CP(1'b0),
      .A(a), .B(b), .C(c), .D(d), .NL(nl), .PN(pn), .TN(tn), .UP(up),
      .CON(o_en[4]), .QA(o_en[3]), .QB(o_en[2]), .QC(o_en[1]), .QD(o_en[0]));
  M169C_EN #(.USE_ENABLE(1)) U_LATE (
      .sysclk(sysclk), .EN(en_d), .CP(1'b0),
      .A(a), .B(b), .C(c), .D(d), .NL(nl), .PN(pn), .TN(tn), .UP(up),
      .CON(o_late[4]), .QA(o_late[3]), .QB(o_late[2]), .QC(o_late[1]), .QD(o_late[0]));

  // ---- checker ----
  integer checks = 0, errors = 0, teeth = 0, pulses = 0;
  reg run_chk = 1;
  reg pa_d1 = 0;
  always @(negedge sysclk) begin
    if (run_chk) begin
      checks = checks + 1;
      if (o_ref !== o_en) begin
        errors = errors + 1;
        $display("FAIL t=%0t ref{CON,QA..QD}=%b en=%b (abcd=%b%b%b%b nl=%b pn=%b tn=%b up=%b)",
                 $time, o_ref, o_en, a, b, c, d, nl, pn, tn, up);
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

  task pulse;
    begin
      nxt = 1; step;
      nxt = 0; step;
    end
  endtask

  reg [15:0] lfsr = 16'hF00D;
  integer i;

  initial begin
    $dumpfile("M169C_EN_equiv_tb.vcd");
    $dumpvars(0, M169C_EN_equiv_tb);

    // Directed 1: parallel loads (NL=0), four patterns.
    pn = 0; tn = 0; up = 1; nl = 0;
    {a, b, c, d} = 4'b0000; pulse;
    {a, b, c, d} = 4'b1111; pulse;
    {a, b, c, d} = 4'b1010; pulse;
    {a, b, c, d} = 4'b0110; pulse;

    // Directed 2: load 0, count UP 20 pulses (wrap through 15, CON hits).
    {a, b, c, d} = 4'b0000; nl = 0; pulse;
    nl = 1; up = 1;
    for (i = 0; i < 20; i = i + 1) pulse;

    // Directed 3: count DOWN 20 pulses (wrap through 0, CON hits).
    up = 0;
    for (i = 0; i < 20; i = i + 1) pulse;

    // Directed 4: all PN/TN enable combos, 2 pulses each (hold vs count,
    // and CON's TN dependence).
    up = 1;
    for (i = 0; i < 4; i = i + 1) begin
      {pn, tn} = i[1:0];
      pulse;
      pulse;
    end

    // Random: fixed-seed LFSR over all inputs, irregular pa phases.
    for (i = 0; i < RANDOM; i = i + 1) begin
      lfsr = {lfsr[14:0], lfsr[15] ^ lfsr[13] ^ lfsr[12] ^ lfsr[10]};
      nxt  = lfsr[0];
      {a, b, c, d} = lfsr[7:4];
      nl   = ~(lfsr[8] & lfsr[9]);   // load ~25% of the time
      pn   = lfsr[10] & lfsr[3];
      tn   = lfsr[11] & lfsr[2];
      up   = lfsr[12];
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

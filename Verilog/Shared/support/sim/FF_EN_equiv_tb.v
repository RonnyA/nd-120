/**************************************************************************
** ND120 CPU - unit test                                                 **
** SCAN_FF_EN / D_FLIPFLOP_EN / R81_EN mode equivalence (P2 wrappers).   **
**                                                                       **
** Drives CLK exactly like a CYC_36 phase-accurate clock (a sysclk-      **
** registered level: pa <= next) and EN as the aligned enable            **
** (next & ~pa, high in the cycle whose posedge is pa's rise).           **
** USE_ENABLE=0 (posedge pa, original chip) and USE_ENABLE=1 (posedge    **
** sysclk + if(EN)) must then match on EVERY sysclk - including multi-   **
** cycle-high pa phases with data changing underneath, and the SCAN_FF   **
** TE/TI path.                                                           **
**                                                                       **
** Teeth: a third instance driven by a one-cycle-LATE enable must        **
** diverge, or the tb fails (the P2 off-by-one risk class).              **
**                                                                       **
** Run: make test-ffen   (Shared/support/sim)                            **
***************************************************************************/
`timescale 1ns / 1ps

module FF_EN_equiv_tb;

  reg sysclk = 0;
  always #5 sysclk = ~sysclk;

  // ---- CYC-style clock/enable generation ----
  reg        nxt = 0;      // "next level" (combinational in CYC, reg here)
  reg        pa = 0;       // phase-accurate clock level
  wire       en = nxt & ~pa;
  reg        en_d = 0;     // one cycle LATE enable (teeth)
  always @(posedge sysclk) begin
    pa   <= nxt;
    en_d <= en;
  end

  // ---- shared stimulus ----
  reg [7:0] data = 8'h00;
  reg       te = 0, ti = 0;

  // ---- SCAN_FF pair (+ late teeth instance) ----
  wire q_scan_ref, q_scan_en, q_scan_late;
  SCAN_FF_EN #(.USE_ENABLE(0)) U_SCAN_REF (
      .sysclk(sysclk), .EN(1'b0), .CLK(pa),
      .D(data[0]), .TE(te), .TI(ti), .Q(q_scan_ref), .QN());
  SCAN_FF_EN #(.USE_ENABLE(1)) U_SCAN_EN (
      .sysclk(sysclk), .EN(en), .CLK(1'b0),
      .D(data[0]), .TE(te), .TI(ti), .Q(q_scan_en), .QN());
  SCAN_FF_EN #(.USE_ENABLE(1)) U_SCAN_LATE (
      .sysclk(sysclk), .EN(en_d), .CLK(1'b0),
      .D(data[0]), .TE(te), .TI(ti), .Q(q_scan_late), .QN());

  // ---- D_FLIPFLOP pair ----
  wire q_dff_ref, q_dff_en;
  D_FLIPFLOP_EN #(.USE_ENABLE(0)) U_DFF_REF (
      .sysclk(sysclk), .EN(1'b0), .clock(pa), .d(data[1]),
      .preset(1'b0), .reset(1'b0), .tick(1'b1), .q(q_dff_ref), .qBar());
  D_FLIPFLOP_EN #(.USE_ENABLE(1)) U_DFF_EN (
      .sysclk(sysclk), .EN(en), .clock(1'b0), .d(data[1]),
      .preset(1'b0), .reset(1'b0), .tick(1'b1), .q(q_dff_en), .qBar());

  // ---- R81 pair ----
  wire [7:0] q_r81_ref, q_r81_en;
  R81_EN #(.USE_ENABLE(0)) U_R81_REF (
      .sysclk(sysclk), .EN(1'b0), .CP(pa),
      .A(data[0]), .B(data[1]), .C(data[2]), .D(data[3]),
      .E(data[4]), .F(data[5]), .G(data[6]), .H(data[7]),
      .QA(q_r81_ref[0]), .QAN(), .QB(q_r81_ref[1]), .QBN(),
      .QC(q_r81_ref[2]), .QCN(), .QD(q_r81_ref[3]), .QDN(),
      .QE(q_r81_ref[4]), .QEN(), .QF(q_r81_ref[5]), .QFN(),
      .QG(q_r81_ref[6]), .QGN(), .QH(q_r81_ref[7]), .QHN());
  R81_EN #(.USE_ENABLE(1)) U_R81_EN (
      .sysclk(sysclk), .EN(en), .CP(1'b0),
      .A(data[0]), .B(data[1]), .C(data[2]), .D(data[3]),
      .E(data[4]), .F(data[5]), .G(data[6]), .H(data[7]),
      .QA(q_r81_en[0]), .QAN(), .QB(q_r81_en[1]), .QBN(),
      .QC(q_r81_en[2]), .QCN(), .QD(q_r81_en[3]), .QDN(),
      .QE(q_r81_en[4]), .QEN(), .QF(q_r81_en[5]), .QFN(),
      .QG(q_r81_en[6]), .QGN(), .QH(q_r81_en[7]), .QHN());

  integer checks = 0, errors = 0, teeth = 0, pulses = 0;
  reg pa_d1 = 0;
  reg [15:0] lfsr = 16'hACE1;

  always @(negedge sysclk) begin
    // compare only after the first pa pulse: the original chips have no
    // initializer (power-up X under 4-state sim), the EN mode inits to 0
    if (pulses > 0) begin
    checks = checks + 1;
    if (q_scan_ref !== q_scan_en) begin
      errors = errors + 1;
      $display("FAIL t=%0t SCAN_FF: ref=%b en=%b", $time, q_scan_ref, q_scan_en);
    end
    if (q_dff_ref !== q_dff_en) begin
      errors = errors + 1;
      $display("FAIL t=%0t D_FLIPFLOP: ref=%b en=%b", $time, q_dff_ref, q_dff_en);
    end
    if (q_r81_ref !== q_r81_en) begin
      errors = errors + 1;
      $display("FAIL t=%0t R81: ref=%h en=%h", $time, q_r81_ref, q_r81_en);
    end
    if (q_scan_ref !== q_scan_late) teeth = teeth + 1;
    end
    if (pa & ~pa_d1) pulses = pulses + 1;
    pa_d1 <= pa;

    // pseudo-random next-level, data, and scan-mode stimulus
    lfsr <= {lfsr[14:0], lfsr[15] ^ lfsr[13] ^ lfsr[12] ^ lfsr[10]};
    nxt  <= lfsr[0] & lfsr[3];       // irregular pa phases incl. multi-cycle
    data <= lfsr[11:4];
    te   <= lfsr[1] & lfsr[7];
    ti   <= lfsr[2];
  end

  initial begin
    $dumpfile("FF_EN_equiv_tb.vcd");
    $dumpvars(0, FF_EN_equiv_tb);
    #100000;  // 10000 cycles
    $display("checks=%0d errors=%0d pa_pulses=%0d teeth(late-EN divergences)=%0d",
             checks, errors, pulses, teeth);
    if (errors == 0 && teeth > 0 && pulses > 100) begin
      $display("TB_RESULT: PASS");
    end else begin
      if (teeth == 0)   $display("FAIL: late-enable never diverged - no teeth");
      if (pulses <= 100) $display("FAIL: too few pa pulses - vacuous run");
      $display("TB_RESULT: FAIL");
    end
    $finish;
  end

endmodule

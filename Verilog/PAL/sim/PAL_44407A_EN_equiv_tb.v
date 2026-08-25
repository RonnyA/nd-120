/**************************************************************************
** ND120 CPU - unit test                                                 **
** PAL_44407A (ERFFIX) vs PAL_44407A_EN(USE_ENABLE=1) equivalence.       **
**                                                                       **
** Reference = original PAL clocked by a sysclk-registered level pa      **
** (posedge CK). DUT = _EN variant on posedge sysclk + rise-aligned      **
** enable en = nxt & ~pa (the FF_EN_equiv_tb pattern). Both sample the   **
** same stimulus at the same sysclk posedges; every registered and       **
** combinational output is compared on every sysclk.                     **
**                                                                       **
** Alignment: the original PAL powers up X; RRF_reg has no feedback,     **
** so two all-zero-input CK pulses make both sides defined and equal.    **
**                                                                       **
** Stimulus: exhaustive directed sweep of all 2^8 combinations of the    **
** 7 data inputs + OE_n (one CK pulse each), then 8192 fixed-seed        **
** LFSR random cycles with irregular pa phases.                          **
**                                                                       **
** Run: make test-44407a-en   (PAL/sim)                                  **
***************************************************************************/
`timescale 1ns / 1ps

module PAL_44407A_EN_equiv_tb;

  // 2 checks/pulse * (256 sweep pulses) + 8192 random cycles
  localparam integer EXPECTED_CHECKS = 512 + 8192;

  reg sysclk = 0;
  always #5 sysclk = ~sysclk;

  // CYC-style clock/enable generation
  reg  nxt = 0;
  reg  pa = 0;
  wire en = nxt & ~pa;
  always @(posedge sysclk) pa <= nxt;

  // shared stimulus
  reg OE_n = 0;
  reg IDBS0 = 0, IDBS1 = 0, IDBS2 = 0, IDBS3 = 0, IDBS4 = 0;
  reg WRTRF = 0, LCS_n = 0;

  // reference: original PAL, clocked by pa
  wire ERF_n_r, RRF_n_r;
  PAL_44407A REF (
      .CK(pa),
      .OE_n(OE_n),
      .IDBS0(IDBS0),
      .IDBS1(IDBS1),
      .IDBS2(IDBS2),
      .IDBS3(IDBS3),
      .IDBS4(IDBS4),
      .WRTRF(WRTRF),
      .LCS_n(LCS_n),
      .ERF_n(ERF_n_r),
      .RRF_n(RRF_n_r)
  );

  // DUT: enable variant on sysclk
  wire ERF_n_e, RRF_n_e;
  PAL_44407A_EN #(
      .USE_ENABLE(1)
  ) DUT (
      .sysclk(sysclk),
      .EN(en),
      .CK(1'b0),
      .OE_n(OE_n),
      .IDBS0(IDBS0),
      .IDBS1(IDBS1),
      .IDBS2(IDBS2),
      .IDBS3(IDBS3),
      .IDBS4(IDBS4),
      .WRTRF(WRTRF),
      .LCS_n(LCS_n),
      .ERF_n(ERF_n_e),
      .RRF_n(RRF_n_e)
  );

  integer checks = 0, errors = 0, pulses = 0, i;
  reg compare_on = 0, rnd_on = 0;
  reg pa_d = 0;
  reg [15:0] lfsr = 16'hACE1;

  always @(negedge sysclk) begin
    if (compare_on) begin
      checks = checks + 1;
      if ({ERF_n_r, RRF_n_r} !== {ERF_n_e, RRF_n_e}) begin
        errors = errors + 1;
        if (errors <= 20)
          $display("FAIL t=%0t ERF/RRF ref=%b%b en=%b%b in={OE=%b IDBS=%b%b%b%b%b WRTRF=%b LCS_n=%b}",
                   $time, ERF_n_r, RRF_n_r, ERF_n_e, RRF_n_e,
                   OE_n, IDBS4, IDBS3, IDBS2, IDBS1, IDBS0, WRTRF, LCS_n);
      end
    end
    if (pa & ~pa_d) pulses = pulses + 1;
    pa_d <= pa;
    if (rnd_on) begin
      lfsr <= {lfsr[14:0], lfsr[15] ^ lfsr[13] ^ lfsr[12] ^ lfsr[10]};
      {OE_n, LCS_n, WRTRF, IDBS4, IDBS3, IDBS2, IDBS1, IDBS0} <= lfsr[7:0];
      nxt <= lfsr[11] & lfsr[9];  // irregular pa phases incl. multi-cycle
    end
  end

  task pulse;
    begin
      @(negedge sysclk) nxt = 1;
      @(negedge sysclk) nxt = 0;
    end
  endtask

  initial begin
    // alignment: flush the original PAL's power-up X (no feedback terms here)
    {OE_n, IDBS0, IDBS1, IDBS2, IDBS3, IDBS4, WRTRF, LCS_n} = 8'b0;
    pulse;
    pulse;
    @(posedge sysclk) compare_on = 1;

    // directed: exhaustive sweep of all input combinations, one pulse each
    for (i = 0; i < 256; i = i + 1) begin
      @(negedge sysclk);
      {OE_n, LCS_n, WRTRF, IDBS4, IDBS3, IDBS2, IDBS1, IDBS0} = i[7:0];
      nxt = 1;
      @(negedge sysclk) nxt = 0;
    end

    // random phase
    @(posedge sysclk) rnd_on = 1;
    repeat (8192) @(negedge sysclk);
    @(posedge sysclk) rnd_on = 0;

    $display("checks=%0d errors=%0d pa_pulses=%0d", checks, errors, pulses);
    if (errors == 0 && checks == EXPECTED_CHECKS && pulses > 300) begin
      $display("TB_RESULT: PASS (%0d checks)", checks);
    end else begin
      if (checks != EXPECTED_CHECKS)
        $display("FAIL: check count %0d != expected %0d", checks, EXPECTED_CHECKS);
      if (pulses <= 300) $display("FAIL: too few CK pulses - vacuous run");
      $display("TB_RESULT: FAIL");
    end
    $finish;
  end

endmodule

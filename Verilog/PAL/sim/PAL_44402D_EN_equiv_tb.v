/**************************************************************************
** ND120 CPU - unit test                                                 **
** PAL_44402D (UBITS) vs PAL_44402D_EN(USE_ENABLE=1) equivalence.        **
**                                                                       **
** Reference = original PAL clocked by a sysclk-registered level pa      **
** (posedge CLK). DUT = _EN variant on posedge sysclk + rise-aligned     **
** enable en = nxt & ~pa (the FF_EN_equiv_tb pattern). Both sample the   **
** same stimulus at the same sysclk posedges; every registered and       **
** combinational output is compared on every sysclk.                     **
**                                                                       **
** Alignment: the original PAL powers up X (no initializers); the _EN    **
** variant initializes to 0. 44402D has no register feedback in its      **
** registered equations, so two all-zero-input CLK pulses make both      **
** sides defined and equal before comparison starts.                     **
**                                                                       **
** Stimulus: exhaustive directed sweep of all 2^11 combinations of the   **
** 10 data inputs + OE_n (one CLK pulse each), then 8192 fixed-seed      **
** LFSR random cycles with irregular pa phases.                          **
**                                                                       **
** Run: make test-44402d-en   (PAL/sim)                                  **
***************************************************************************/
`timescale 1ns / 1ps

module PAL_44402D_EN_equiv_tb;

  // 2 checks/pulse * (2048 sweep pulses) + 8192 random cycles
  localparam integer EXPECTED_CHECKS = 4096 + 8192;

  reg sysclk = 0;
  always #5 sysclk = ~sysclk;

  // CYC-style clock/enable generation
  reg  nxt = 0;
  reg  pa = 0;
  wire en = nxt & ~pa;
  always @(posedge sysclk) pa <= nxt;

  // shared stimulus
  reg OE_n = 0;
  reg DT_n = 0, RT_n = 0, LSHADOW = 0, FMISS = 0, CYD = 0;
  reg HIT0_n = 0, HIT1_n = 0, EWC_n = 0, OUBI = 0, OUBD = 0;

  // reference: original PAL, clocked by pa
  wire USED_n_r, WCA_n_r, NUBI_n_r, NUBD_n_r, IHIT_n_r;
  PAL_44402D REF (
      .CLK(pa),
      .OE_n(OE_n),
      .DT_n(DT_n),
      .RT_n(RT_n),
      .LSHADOW(LSHADOW),
      .FMISS(FMISS),
      .CYD(CYD),
      .HIT0_n(HIT0_n),
      .HIT1_n(HIT1_n),
      .EWC_n(EWC_n),
      .USED_n(USED_n_r),
      .WCA_n(WCA_n_r),
      .OUBI(OUBI),
      .OUBD(OUBD),
      .NUBI_n(NUBI_n_r),
      .NUBD_n(NUBD_n_r),
      .IHIT_n(IHIT_n_r)
  );

  // DUT: enable variant on sysclk
  wire USED_n_e, WCA_n_e, NUBI_n_e, NUBD_n_e, IHIT_n_e;
  PAL_44402D_EN #(
      .USE_ENABLE(1)
  ) DUT (
      .sysclk(sysclk),
      .EN(en),
      .CLK(1'b0),
      .OE_n(OE_n),
      .DT_n(DT_n),
      .RT_n(RT_n),
      .LSHADOW(LSHADOW),
      .FMISS(FMISS),
      .CYD(CYD),
      .HIT0_n(HIT0_n),
      .HIT1_n(HIT1_n),
      .EWC_n(EWC_n),
      .USED_n(USED_n_e),
      .WCA_n(WCA_n_e),
      .OUBI(OUBI),
      .OUBD(OUBD),
      .NUBI_n(NUBI_n_e),
      .NUBD_n(NUBD_n_e),
      .IHIT_n(IHIT_n_e)
  );

  integer checks = 0, errors = 0, pulses = 0, i;
  reg compare_on = 0, rnd_on = 0;
  reg pa_d = 0;
  reg [15:0] lfsr = 16'hACE1;

  always @(negedge sysclk) begin
    if (compare_on) begin
      checks = checks + 1;
      if ({USED_n_r, WCA_n_r, NUBI_n_r, NUBD_n_r, IHIT_n_r} !==
          {USED_n_e, WCA_n_e, NUBI_n_e, NUBD_n_e, IHIT_n_e}) begin
        errors = errors + 1;
        if (errors <= 20)
          $display("FAIL t=%0t USED/WCA/NUBI/NUBD/IHIT ref=%b%b%b%b%b en=%b%b%b%b%b in={OE=%b DT_n=%b RT_n=%b LSH=%b FMISS=%b CYD=%b H0_n=%b H1_n=%b EWC_n=%b OUBI=%b OUBD=%b}",
                   $time, USED_n_r, WCA_n_r, NUBI_n_r, NUBD_n_r, IHIT_n_r,
                   USED_n_e, WCA_n_e, NUBI_n_e, NUBD_n_e, IHIT_n_e,
                   OE_n, DT_n, RT_n, LSHADOW, FMISS, CYD, HIT0_n, HIT1_n, EWC_n, OUBI, OUBD);
      end
    end
    if (pa & ~pa_d) pulses = pulses + 1;
    pa_d <= pa;
    if (rnd_on) begin
      lfsr <= {lfsr[14:0], lfsr[15] ^ lfsr[13] ^ lfsr[12] ^ lfsr[10]};
      {OE_n, OUBD, OUBI, EWC_n, HIT1_n, HIT0_n, CYD, FMISS, LSHADOW, RT_n, DT_n} <= lfsr[10:0];
      nxt <= lfsr[11] & lfsr[3];  // irregular pa phases incl. multi-cycle
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
    {OE_n, DT_n, RT_n, LSHADOW, FMISS, CYD, HIT0_n, HIT1_n, EWC_n, OUBI, OUBD} = 11'b0;
    pulse;
    pulse;
    @(posedge sysclk) compare_on = 1;

    // directed: exhaustive sweep of all input combinations, one pulse each
    for (i = 0; i < 2048; i = i + 1) begin
      @(negedge sysclk);
      {OE_n, OUBD, OUBI, EWC_n, HIT1_n, HIT0_n, CYD, FMISS, LSHADOW, RT_n, DT_n} = i[10:0];
      nxt = 1;
      @(negedge sysclk) nxt = 0;
    end

    // random phase
    @(posedge sysclk) rnd_on = 1;
    repeat (8192) @(negedge sysclk);
    @(posedge sysclk) rnd_on = 0;

    $display("checks=%0d errors=%0d pa_pulses=%0d", checks, errors, pulses);
    if (errors == 0 && checks == EXPECTED_CHECKS && pulses > 2100) begin
      $display("TB_RESULT: PASS (%0d checks)", checks);
    end else begin
      if (checks != EXPECTED_CHECKS)
        $display("FAIL: check count %0d != expected %0d", checks, EXPECTED_CHECKS);
      if (pulses <= 2100) $display("FAIL: too few CLK pulses - vacuous run");
      $display("TB_RESULT: FAIL");
    end
    $finish;
  end

endmodule

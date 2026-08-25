/**************************************************************************
** ND120 CPU - unit test                                                 **
** PAL_44404C (CYIN1) vs PAL_44404C_EN(USE_ENABLE=1) equivalence.        **
**                                                                       **
** Reference = original PAL clocked by a sysclk-registered level pa      **
** (posedge CLK). DUT = _EN variant on posedge sysclk + rise-aligned     **
** enable en = nxt & ~pa (the FF_EN_equiv_tb pattern). Both sample the   **
** same stimulus at the same sysclk posedges; every registered and       **
** combinational output is compared on every sysclk.                     **
**                                                                       **
** Alignment: the original PAL powers up X (no initializers); neither    **
** registered equation (NOWRIT, DLSHADOW) has feedback, so two           **
** all-zero-input CLK pulses make both sides defined and equal.          **
**                                                                       **
** Stimulus: exhaustive directed sweep of all 2^12 combinations of the   **
** 11 data inputs + OE_n (one CLK pulse each), then 8192 fixed-seed      **
** LFSR random cycles with irregular pa phases.                          **
**                                                                       **
** Run: make test-44404c-en   (PAL/sim)                                  **
***************************************************************************/
`timescale 1ns / 1ps

module PAL_44404C_EN_equiv_tb;

  // 2 checks/pulse * (4096 sweep pulses) + 8192 random cycles
  localparam integer EXPECTED_CHECKS = 8192 + 8192;

  reg sysclk = 0;
  always #5 sysclk = ~sysclk;

  // CYC-style clock/enable generation
  reg  nxt = 0;
  reg  pa = 0;
  wire en = nxt & ~pa;
  always @(posedge sysclk) pa <= nxt;

  // shared stimulus
  reg OE_n = 0;
  reg CSDELAY1 = 0, CSALUM1 = 0, CSALUM0 = 0, CSALUI8 = 0, CSALUI7 = 0;
  reg LBA3 = 0, LBA1 = 0, LBA0 = 0;
  reg RRF_n = 0, LSHADOW = 0, SLCOND_n = 0;

  // reference: original PAL, clocked by pa
  wire NOWRIT_n_r, DLSHADOW_r, DLY1_n_r;
  PAL_44404C REF (
      .CLK(pa),
      .OE_n(OE_n),
      .CSDELAY1(CSDELAY1),
      .CSALUM1(CSALUM1),
      .CSALUM0(CSALUM0),
      .CSALUI8(CSALUI8),
      .CSALUI7(CSALUI7),
      .LBA3(LBA3),
      .LBA1(LBA1),
      .LBA0(LBA0),
      .NOWRIT_n(NOWRIT_n_r),
      .DLSHADOW(DLSHADOW_r),
      .RRF_n(RRF_n),
      .LSHADOW(LSHADOW),
      .SLCOND_n(SLCOND_n),
      .DLY1_n(DLY1_n_r)
  );

  // DUT: enable variant on sysclk
  wire NOWRIT_n_e, DLSHADOW_e, DLY1_n_e;
  PAL_44404C_EN #(
      .USE_ENABLE(1)
  ) DUT (
      .sysclk(sysclk),
      .EN(en),
      .CLK(1'b0),
      .OE_n(OE_n),
      .CSDELAY1(CSDELAY1),
      .CSALUM1(CSALUM1),
      .CSALUM0(CSALUM0),
      .CSALUI8(CSALUI8),
      .CSALUI7(CSALUI7),
      .LBA3(LBA3),
      .LBA1(LBA1),
      .LBA0(LBA0),
      .NOWRIT_n(NOWRIT_n_e),
      .DLSHADOW(DLSHADOW_e),
      .RRF_n(RRF_n),
      .LSHADOW(LSHADOW),
      .SLCOND_n(SLCOND_n),
      .DLY1_n(DLY1_n_e)
  );

  integer checks = 0, errors = 0, pulses = 0, i;
  reg compare_on = 0, rnd_on = 0;
  reg pa_d = 0;
  reg [15:0] lfsr = 16'hACE1;

  always @(negedge sysclk) begin
    if (compare_on) begin
      checks = checks + 1;
      if ({NOWRIT_n_r, DLSHADOW_r, DLY1_n_r} !== {NOWRIT_n_e, DLSHADOW_e, DLY1_n_e}) begin
        errors = errors + 1;
        if (errors <= 20)
          $display("FAIL t=%0t NOWRIT/DLSHADOW/DLY1 ref=%b%b%b en=%b%b%b in={OE=%b CSDELAY1=%b CSALUM1=%b CSALUM0=%b CSALUI8=%b CSALUI7=%b LBA3=%b LBA1=%b LBA0=%b RRF_n=%b LSHADOW=%b SLCOND_n=%b}",
                   $time, NOWRIT_n_r, DLSHADOW_r, DLY1_n_r,
                   NOWRIT_n_e, DLSHADOW_e, DLY1_n_e,
                   OE_n, CSDELAY1, CSALUM1, CSALUM0, CSALUI8, CSALUI7,
                   LBA3, LBA1, LBA0, RRF_n, LSHADOW, SLCOND_n);
      end
    end
    if (pa & ~pa_d) pulses = pulses + 1;
    pa_d <= pa;
    if (rnd_on) begin
      lfsr <= {lfsr[14:0], lfsr[15] ^ lfsr[13] ^ lfsr[12] ^ lfsr[10]};
      {OE_n, SLCOND_n, LSHADOW, RRF_n, LBA0, LBA1, LBA3, CSALUI7, CSALUI8, CSALUM0, CSALUM1,
       CSDELAY1} <= lfsr[11:0];
      nxt <= lfsr[13] & lfsr[3];  // irregular pa phases incl. multi-cycle
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
    {OE_n, CSDELAY1, CSALUM1, CSALUM0, CSALUI8, CSALUI7, LBA3, LBA1, LBA0,
     RRF_n, LSHADOW, SLCOND_n} = 12'b0;
    pulse;
    pulse;
    @(posedge sysclk) compare_on = 1;

    // directed: exhaustive sweep of all input combinations, one pulse each
    for (i = 0; i < 4096; i = i + 1) begin
      @(negedge sysclk);
      {OE_n, SLCOND_n, LSHADOW, RRF_n, LBA0, LBA1, LBA3, CSALUI7, CSALUI8, CSALUM0, CSALUM1,
       CSDELAY1} = i[11:0];
      nxt = 1;
      @(negedge sysclk) nxt = 0;
    end

    // random phase
    @(posedge sysclk) rnd_on = 1;
    repeat (8192) @(negedge sysclk);
    @(posedge sysclk) rnd_on = 0;

    $display("checks=%0d errors=%0d pa_pulses=%0d", checks, errors, pulses);
    if (errors == 0 && checks == EXPECTED_CHECKS && pulses > 4200) begin
      $display("TB_RESULT: PASS (%0d checks)", checks);
    end else begin
      if (checks != EXPECTED_CHECKS)
        $display("FAIL: check count %0d != expected %0d", checks, EXPECTED_CHECKS);
      if (pulses <= 4200) $display("FAIL: too few CLK pulses - vacuous run");
      $display("TB_RESULT: FAIL");
    end
    $finish;
  end

endmodule

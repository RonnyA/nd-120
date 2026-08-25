/**************************************************************************
** ND120 CPU - unit test                                                 **
** PAL_44403C (CYIN0) vs PAL_44403C_EN(USE_ENABLE=1) equivalence.        **
**                                                                       **
** Reference = original PAL clocked by a sysclk-registered level pa      **
** (posedge CLK). DUT = _EN variant on posedge sysclk + rise-aligned     **
** enable en = nxt & ~pa (the FF_EN_equiv_tb pattern). Both sample the   **
** same stimulus at the same sysclk posedges; every registered and       **
** combinational output is compared on every sysclk.                     **
**                                                                       **
** Alignment: the original PAL powers up X. The LCS register has         **
** feedback, so the alignment pulses assert MR (MR_n=0), which forces    **
** LCS to a defined 1 on both sides; MDLY/DMA12/DMAP have no feedback.   **
**                                                                       **
** Stimulus: exhaustive directed sweep of all 2^9 combinations of the    **
** 8 data inputs + OE_n, swept TWICE (LCS/DMA12 state coverage - the     **
** second pass runs each combination from different register state),     **
** then 8192 fixed-seed LFSR random cycles with irregular pa phases.     **
**                                                                       **
** Run: make test-44403c-en   (PAL/sim)                                  **
***************************************************************************/
`timescale 1ns / 1ps

module PAL_44403C_EN_equiv_tb;

  // 2 checks/pulse * (2 * 512 sweep pulses) + 8192 random cycles
  localparam integer EXPECTED_CHECKS = 2048 + 8192;

  reg sysclk = 0;
  always #5 sysclk = ~sysclk;

  // CYC-style clock/enable generation
  reg  nxt = 0;
  reg  pa = 0;
  wire en = nxt & ~pa;
  always @(posedge sysclk) pa <= nxt;

  // shared stimulus
  reg OE_n = 0;
  reg CSDELAY0 = 0, CSDLY = 0, CSECOND = 0, CSLOOP = 0;
  reg ACOND_n = 0, MR_n = 0, LUA12 = 0, MAP_n = 0;

  // reference: original PAL, clocked by pa
  wire LCS_n_r, MDLY_n_r, DMA12_n_r, DMAP_n_r, DLY0_n_r, SLCOND_n_r;
  PAL_44403C REF (
      .CLK(pa),
      .OE_n(OE_n),
      .CSDELAY0(CSDELAY0),
      .CSDLY(CSDLY),
      .CSECOND(CSECOND),
      .CSLOOP(CSLOOP),
      .ACOND_n(ACOND_n),
      .MR_n(MR_n),
      .LUA12(LUA12),
      .MAP_n(MAP_n),
      .LCS_n(LCS_n_r),
      .MDLY_n(MDLY_n_r),
      .DMA12_n(DMA12_n_r),
      .DMAP_n(DMAP_n_r),
      .DLY0_n(DLY0_n_r),
      .SLCOND_n(SLCOND_n_r)
  );

  // DUT: enable variant on sysclk
  wire LCS_n_e, MDLY_n_e, DMA12_n_e, DMAP_n_e, DLY0_n_e, SLCOND_n_e;
  PAL_44403C_EN #(
      .USE_ENABLE(1)
  ) DUT (
      .sysclk(sysclk),
      .EN(en),
      .CLK(1'b0),
      .OE_n(OE_n),
      .CSDELAY0(CSDELAY0),
      .CSDLY(CSDLY),
      .CSECOND(CSECOND),
      .CSLOOP(CSLOOP),
      .ACOND_n(ACOND_n),
      .MR_n(MR_n),
      .LUA12(LUA12),
      .MAP_n(MAP_n),
      .LCS_n(LCS_n_e),
      .MDLY_n(MDLY_n_e),
      .DMA12_n(DMA12_n_e),
      .DMAP_n(DMAP_n_e),
      .DLY0_n(DLY0_n_e),
      .SLCOND_n(SLCOND_n_e)
  );

  integer checks = 0, errors = 0, pulses = 0, i, pass;
  reg compare_on = 0, rnd_on = 0;
  reg pa_d = 0;
  reg [15:0] lfsr = 16'hACE1;

  always @(negedge sysclk) begin
    if (compare_on) begin
      checks = checks + 1;
      if ({LCS_n_r, MDLY_n_r, DMA12_n_r, DMAP_n_r, DLY0_n_r, SLCOND_n_r} !==
          {LCS_n_e, MDLY_n_e, DMA12_n_e, DMAP_n_e, DLY0_n_e, SLCOND_n_e}) begin
        errors = errors + 1;
        if (errors <= 20)
          $display("FAIL t=%0t LCS/MDLY/DMA12/DMAP/DLY0/SLCOND ref=%b%b%b%b%b%b en=%b%b%b%b%b%b in={OE=%b CSDELAY0=%b CSDLY=%b CSECOND=%b CSLOOP=%b ACOND_n=%b MR_n=%b LUA12=%b MAP_n=%b}",
                   $time, LCS_n_r, MDLY_n_r, DMA12_n_r, DMAP_n_r, DLY0_n_r, SLCOND_n_r,
                   LCS_n_e, MDLY_n_e, DMA12_n_e, DMAP_n_e, DLY0_n_e, SLCOND_n_e,
                   OE_n, CSDELAY0, CSDLY, CSECOND, CSLOOP, ACOND_n, MR_n, LUA12, MAP_n);
      end
    end
    if (pa & ~pa_d) pulses = pulses + 1;
    pa_d <= pa;
    if (rnd_on) begin
      lfsr <= {lfsr[14:0], lfsr[15] ^ lfsr[13] ^ lfsr[12] ^ lfsr[10]};
      {OE_n, MAP_n, LUA12, MR_n, ACOND_n, CSLOOP, CSECOND, CSDLY, CSDELAY0} <= lfsr[8:0];
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
    // alignment: assert MR so the LCS feedback register resolves X -> 1
    {OE_n, CSDELAY0, CSDLY, CSECOND, CSLOOP, ACOND_n, MR_n, LUA12, MAP_n} = 9'b0;
    MR_n = 0;
    pulse;
    pulse;
    @(posedge sysclk) compare_on = 1;

    // directed: exhaustive sweep of all input combinations, twice
    // (second pass hits each combination from different LCS/DMA12 state)
    for (pass = 0; pass < 2; pass = pass + 1) begin
      for (i = 0; i < 512; i = i + 1) begin
        @(negedge sysclk);
        {OE_n, MAP_n, LUA12, MR_n, ACOND_n, CSLOOP, CSECOND, CSDLY, CSDELAY0} = i[8:0];
        nxt = 1;
        @(negedge sysclk) nxt = 0;
      end
    end

    // random phase
    @(posedge sysclk) rnd_on = 1;
    repeat (8192) @(negedge sysclk);
    @(posedge sysclk) rnd_on = 0;

    $display("checks=%0d errors=%0d pa_pulses=%0d", checks, errors, pulses);
    if (errors == 0 && checks == EXPECTED_CHECKS && pulses > 1100) begin
      $display("TB_RESULT: PASS (%0d checks)", checks);
    end else begin
      if (checks != EXPECTED_CHECKS)
        $display("FAIL: check count %0d != expected %0d", checks, EXPECTED_CHECKS);
      if (pulses <= 1100) $display("FAIL: too few CLK pulses - vacuous run");
      $display("TB_RESULT: FAIL");
    end
    $finish;
  end

endmodule

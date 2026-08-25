/**************************************************************************
** ND120 CPU - unit test                                                 **
** PAL_44408B (VEXFIX) vs PAL_44408B_EN(USE_ENABLE=1) equivalence.       **
**                                                                       **
** Reference = original PAL clocked by a sysclk-registered level pa      **
** (posedge CK). DUT = _EN variant on posedge sysclk + rise-aligned      **
** enable en = nxt & ~pa (the FF_EN_equiv_tb pattern). Both sample the   **
** same stimulus at the same sysclk posedges; every registered and       **
** combinational output is compared on every sysclk.                     **
**                                                                       **
** Alignment: the original PAL powers up X. VEX_n_int has feedback, so   **
** the alignment pulses assert LCS (LCS_n=0), which forces VEX_n_int to  **
** a defined 1 on both sides; the other registers have no feedback.      **
**                                                                       **
** Stimulus: exhaustive directed sweep of all 2^10 combinations of the   **
** 9 data inputs + OE_n, swept TWICE (VEX/LDEXM state coverage - the     **
** second pass runs each combination from different register state),     **
** then 8192 fixed-seed LFSR random cycles with irregular pa phases.     **
**                                                                       **
** Run: make test-44408b-en   (PAL/sim)                                  **
***************************************************************************/
`timescale 1ns / 1ps

module PAL_44408B_EN_equiv_tb;

  // 2 checks/pulse * (2 * 1024 sweep pulses) + 8192 random cycles
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
  reg C4 = 0, C3 = 0, C2 = 0, C1 = 0, C0 = 0, M1 = 0, M0 = 0;
  reg LCS_n = 0, IDB2 = 0;

  // reference: original PAL, clocked by pa
  wire LDEXM_n_r, VEX_r, OPCLCS_r, RWCS_n_r, RT_n_r;
  PAL_44408B REF (
      .CK(pa),
      .OE_n(OE_n),
      .C4(C4),
      .C3(C3),
      .C2(C2),
      .C1(C1),
      .C0(C0),
      .M1(M1),
      .M0(M0),
      .LCS_n(LCS_n),
      .IDB2(IDB2),
      .LDEXM_n(LDEXM_n_r),
      .VEX(VEX_r),
      .OPCLCS(OPCLCS_r),
      .RWCS_n(RWCS_n_r),
      .RT_n(RT_n_r)
  );

  // DUT: enable variant on sysclk
  wire LDEXM_n_e, VEX_e, OPCLCS_e, RWCS_n_e, RT_n_e;
  PAL_44408B_EN #(
      .USE_ENABLE(1)
  ) DUT (
      .sysclk(sysclk),
      .EN(en),
      .CK(1'b0),
      .OE_n(OE_n),
      .C4(C4),
      .C3(C3),
      .C2(C2),
      .C1(C1),
      .C0(C0),
      .M1(M1),
      .M0(M0),
      .LCS_n(LCS_n),
      .IDB2(IDB2),
      .LDEXM_n(LDEXM_n_e),
      .VEX(VEX_e),
      .OPCLCS(OPCLCS_e),
      .RWCS_n(RWCS_n_e),
      .RT_n(RT_n_e)
  );

  integer checks = 0, errors = 0, pulses = 0, i, pass;
  reg compare_on = 0, rnd_on = 0;
  reg pa_d = 0;
  reg [15:0] lfsr = 16'hACE1;

  always @(negedge sysclk) begin
    if (compare_on) begin
      checks = checks + 1;
      if ({LDEXM_n_r, VEX_r, OPCLCS_r, RWCS_n_r, RT_n_r} !==
          {LDEXM_n_e, VEX_e, OPCLCS_e, RWCS_n_e, RT_n_e}) begin
        errors = errors + 1;
        if (errors <= 20)
          $display("FAIL t=%0t LDEXM/VEX/OPCLCS/RWCS/RT ref=%b%b%b%b%b en=%b%b%b%b%b in={OE=%b C=%b%b%b%b%b M=%b%b LCS_n=%b IDB2=%b}",
                   $time, LDEXM_n_r, VEX_r, OPCLCS_r, RWCS_n_r, RT_n_r,
                   LDEXM_n_e, VEX_e, OPCLCS_e, RWCS_n_e, RT_n_e,
                   OE_n, C4, C3, C2, C1, C0, M1, M0, LCS_n, IDB2);
      end
    end
    if (pa & ~pa_d) pulses = pulses + 1;
    pa_d <= pa;
    if (rnd_on) begin
      lfsr <= {lfsr[14:0], lfsr[15] ^ lfsr[13] ^ lfsr[12] ^ lfsr[10]};
      {OE_n, IDB2, LCS_n, M0, M1, C0, C1, C2, C3, C4} <= lfsr[9:0];
      nxt <= lfsr[11] & lfsr[12];  // irregular pa phases incl. multi-cycle
    end
  end

  task pulse;
    begin
      @(negedge sysclk) nxt = 1;
      @(negedge sysclk) nxt = 0;
    end
  endtask

  initial begin
    // alignment: assert LCS so the VEX feedback register resolves X -> 1
    {OE_n, C4, C3, C2, C1, C0, M1, M0, LCS_n, IDB2} = 10'b0;
    LCS_n = 0;
    pulse;
    pulse;
    @(posedge sysclk) compare_on = 1;

    // directed: exhaustive sweep of all input combinations, twice
    // (second pass hits each combination from different VEX/LDEXM state)
    for (pass = 0; pass < 2; pass = pass + 1) begin
      for (i = 0; i < 1024; i = i + 1) begin
        @(negedge sysclk);
        {OE_n, IDB2, LCS_n, M0, M1, C0, C1, C2, C3, C4} = i[9:0];
        nxt = 1;
        @(negedge sysclk) nxt = 0;
      end
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
      if (pulses <= 2100) $display("FAIL: too few CK pulses - vacuous run");
      $display("TB_RESULT: FAIL");
    end
    $finish;
  end

endmodule

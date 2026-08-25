/**************************************************************************
** ND120 CPU - unit test                                                 **
** PAL_44511A (LEV0) vs PAL_44511A_EN(USE_ENABLE=1) equivalence.         **
**                                                                       **
** Reference = original PAL clocked by a sysclk-registered level pa      **
** (posedge CK). DUT = _EN variant on posedge sysclk + rise-aligned      **
** enable en = nxt & ~pa (the FF_EN_equiv_tb pattern). Both sample the   **
** same stimulus at the same sysclk posedges; every registered and       **
** combinational output is compared on every sysclk.                     **
**                                                                       **
** The PAL's CLK *data* input (pin I4; on the 3202 board it is the same  **
** net as the CK clock pin) is driven here from a dedicated stimulus     **
** reg so both instances sample the identical value at their capture     **
** edge - pin-level equivalence of the two modules, all CLK-pin values   **
** covered by the sweep.                                                 **
**                                                                       **
** Alignment: the original PAL powers up X, and both CWR_reg (hold       **
** branch) and CUP_n_reg (feedback) can keep X alive. The alignment      **
** pulses drive CLK=1, MREQ=1, WCA=1: pulse 1 sets CWR on both sides,    **
** pulse 2 then resolves CUP_n via the now-defined CWR_n feedback;       **
** pulse 3 is margin.                                                    **
**                                                                       **
** Stimulus: exhaustive directed sweep of all 2^8 combinations of the    **
** 7 data inputs + OE_n, swept TWICE (CWR/CUP state coverage), then      **
** 8192 fixed-seed LFSR random cycles with irregular pa phases.          **
**                                                                       **
** Run: make test-44511a-en   (PAL/sim)                                  **
***************************************************************************/
`timescale 1ns / 1ps

module PAL_44511A_EN_equiv_tb;

  // 2 checks/pulse * (2 * 256 sweep pulses) + 8192 random cycles
  localparam integer EXPECTED_CHECKS = 1024 + 8192;

  reg sysclk = 0;
  always #5 sysclk = ~sysclk;

  // CYC-style clock/enable generation
  reg  nxt = 0;
  reg  pa = 0;
  wire en = nxt & ~pa;
  always @(posedge sysclk) pa <= nxt;

  // shared stimulus
  reg OE_n = 0;
  reg PIL0 = 0, PIL1 = 0, PIL2 = 0, PIL3 = 0;
  reg clk_pin = 0;  // the PAL's CLK data input (I4)
  reg MREQ_n = 0, WCA_n = 0;

  // reference: original PAL, clocked by pa
  wire CUP_r, CWR_n_r, LEV0_r;
  PAL_44511A REF (
      .CK(pa),
      .OE_n(OE_n),
      .PIL0(PIL0),
      .PIL1(PIL1),
      .PIL2(PIL2),
      .PIL3(PIL3),
      .CLK(clk_pin),
      .MREQ_n(MREQ_n),
      .WCA_n(WCA_n),
      .CUP(CUP_r),
      .CWR_n(CWR_n_r),
      .LEV0(LEV0_r)
  );

  // DUT: enable variant on sysclk
  wire CUP_e, CWR_n_e, LEV0_e;
  PAL_44511A_EN #(
      .USE_ENABLE(1)
  ) DUT (
      .sysclk(sysclk),
      .EN(en),
      .CK(1'b0),
      .OE_n(OE_n),
      .PIL0(PIL0),
      .PIL1(PIL1),
      .PIL2(PIL2),
      .PIL3(PIL3),
      .CLK(clk_pin),
      .MREQ_n(MREQ_n),
      .WCA_n(WCA_n),
      .CUP(CUP_e),
      .CWR_n(CWR_n_e),
      .LEV0(LEV0_e)
  );

  integer checks = 0, errors = 0, pulses = 0, i, pass;
  reg compare_on = 0, rnd_on = 0;
  reg pa_d = 0;
  reg [15:0] lfsr = 16'hACE1;

  always @(negedge sysclk) begin
    if (compare_on) begin
      checks = checks + 1;
      if ({CUP_r, CWR_n_r, LEV0_r} !== {CUP_e, CWR_n_e, LEV0_e}) begin
        errors = errors + 1;
        if (errors <= 20)
          $display("FAIL t=%0t CUP/CWR/LEV0 ref=%b%b%b en=%b%b%b in={OE=%b PIL=%b%b%b%b CLKpin=%b MREQ_n=%b WCA_n=%b}",
                   $time, CUP_r, CWR_n_r, LEV0_r, CUP_e, CWR_n_e, LEV0_e,
                   OE_n, PIL3, PIL2, PIL1, PIL0, clk_pin, MREQ_n, WCA_n);
      end
    end
    if (pa & ~pa_d) pulses = pulses + 1;
    pa_d <= pa;
    if (rnd_on) begin
      lfsr <= {lfsr[14:0], lfsr[15] ^ lfsr[13] ^ lfsr[12] ^ lfsr[10]};
      {OE_n, WCA_n, MREQ_n, clk_pin, PIL3, PIL2, PIL1, PIL0} <= lfsr[7:0];
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
    // alignment: CLK=1, MREQ=1, WCA=1 - pulse 1 sets CWR (defined both
    // sides), pulse 2 resolves CUP_n through the defined CWR_n feedback
    {OE_n, PIL0, PIL1, PIL2, PIL3, clk_pin, MREQ_n, WCA_n} = 8'b0;
    clk_pin = 1;
    MREQ_n  = 0;
    WCA_n   = 0;
    pulse;
    pulse;
    pulse;
    @(posedge sysclk) compare_on = 1;

    // directed: exhaustive sweep of all input combinations, twice
    // (second pass hits each combination from different CWR/CUP state)
    for (pass = 0; pass < 2; pass = pass + 1) begin
      for (i = 0; i < 256; i = i + 1) begin
        @(negedge sysclk);
        {OE_n, WCA_n, MREQ_n, clk_pin, PIL3, PIL2, PIL1, PIL0} = i[7:0];
        nxt = 1;
        @(negedge sysclk) nxt = 0;
      end
    end

    // random phase
    @(posedge sysclk) rnd_on = 1;
    repeat (8192) @(negedge sysclk);
    @(posedge sysclk) rnd_on = 0;

    $display("checks=%0d errors=%0d pa_pulses=%0d", checks, errors, pulses);
    if (errors == 0 && checks == EXPECTED_CHECKS && pulses > 600) begin
      $display("TB_RESULT: PASS (%0d checks)", checks);
    end else begin
      if (checks != EXPECTED_CHECKS)
        $display("FAIL: check count %0d != expected %0d", checks, EXPECTED_CHECKS);
      if (pulses <= 600) $display("FAIL: too few CK pulses - vacuous run");
      $display("TB_RESULT: FAIL");
    end
    $finish;
  end

endmodule

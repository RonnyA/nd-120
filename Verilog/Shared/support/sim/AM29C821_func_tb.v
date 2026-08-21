/****************************************************************************
** AM29C821 - FUNCTIONAL testbench (absolute values, not mode-vs-mode)     **
**                                                                         **
** WHY THIS EXISTS ALONGSIDE AM29C821_equiv_tb.v                           **
**   The existing AM29C821_equiv_tb.v is an EQUIVALENCE test: it compares  **
**   USE_SYSCLK=0 against =2 (and counts where =1 diverges). It never      **
**   asserts an ABSOLUTE expected value, so a fault present in every mode  **
**   at once - a dropped OE_n mask, an inverted output, a register that    **
**   captures the wrong thing - passes it silently, because all three      **
**   copies would be wrong together. This testbench closes that hole: it   **
**   checks each mode against a reference model of what the part is        **
**   supposed to produce.                                                  **
**                                                                         **
** THE PART, as Verilog/Shared/support/AM29C821.v actually implements it:  **
**   10-bit register, three selectable capture behaviours -                **
**     USE_SYSCLK=0 (default): capture on posedge CK. Matches the real     **
**                             AM29C821 and is correct for a real clock.   **
**     USE_SYSCLK=1: LEVEL capture - re-captures D on EVERY posedge sysclk **
**                   while CK is high. This is NOT edge-triggered, and the **
**                   RTL comment records that it is what broke the memory  **
**                   write path when CK was a multi-cycle strobe. Tested   **
**                   here as the documented behaviour, not as "correct".   **
**     USE_SYSCLK=2: sysclk-sampled RISING-EDGE capture - one capture per  **
**                   detected CK rise, landing one sysclk AFTER the rise.  **
**   Output: Y = (OE_n == 0) ? register : 10'b0.                           **
**                                                                         **
** THE REPO RULE THIS GUARDS: inside the FPGA `z` does not work. A         **
** disabled output must drive ZERO, because these buses are OR-ed          **
** together. Checked explicitly with the register holding all-ones         **
** underneath, so a pass cannot be an accident of the stored value.        **
**                                                                         **
** COVERAGE: EXHAUSTIVE over the data space in the default mode - all      **
** 1024 values of D are captured and read back, and all 1024 are then      **
** re-read with OE_n high and required to be zero (2048 checks), plus the  **
** directed mode-1 / mode-2 / hold / named property checks below.          **
**                                                                         **
** Run: cd Verilog/Shared/support/sim && make test-am29c821-func           **
**                                                                         **
** Last reviewed: 20-AUG-2026                                              **
** Ronny Hansen                                                            **
*****************************************************************************/
`timescale 1ns / 1ps
`default_nettype none

module AM29C821_func_tb;

  reg        sysclk = 1'b0;
  reg        ck     = 1'b0;
  reg        oe_n   = 1'b0;
  reg  [9:0] d      = 10'b0;

  wire [9:0] y_ck;     // USE_SYSCLK=0 - posedge CK (the real part)
  wire [9:0] y_lvl;    // USE_SYSCLK=1 - level capture while CK high
  wire [9:0] y_edge;   // USE_SYSCLK=2 - sysclk-sampled CK rise

  integer errors = 0;
  integer checks = 0;

  AM29C821 #(.USE_SYSCLK(0)) U_CK   (.sysclk(sysclk), .CK(ck), .OE_n(oe_n), .D(d), .Y(y_ck));
  AM29C821 #(.USE_SYSCLK(1)) U_LVL  (.sysclk(sysclk), .CK(ck), .OE_n(oe_n), .D(d), .Y(y_lvl));
  AM29C821 #(.USE_SYSCLK(2)) U_EDGE (.sysclk(sysclk), .CK(ck), .OE_n(oe_n), .D(d), .Y(y_edge));

  always #5 sysclk = ~sysclk;

  // ---- reference model: the part's function, with the repo's
  // ---- zero-when-disabled convention instead of high-Z
  function [9:0] ref_y;
    input [9:0] stored;
    input       oe;
    begin
      ref_y = (oe == 1'b0) ? stored : 10'b0;
    end
  endfunction

  task chk(input [9:0] got, input [9:0] exp, input [400:0] label);
    begin
      checks = checks + 1;
      if (got !== exp) begin
        errors = errors + 1;
        if (errors < 12)
          $display("FAIL %0s: got %04o expected %04o (d=%04o ck=%b oe_n=%b)",
                   label, got, exp, d, ck, oe_n);
      end
    end
  endtask

  // One clean CK pulse for the posedge-CK part, wide enough that the
  // sysclk-sampling modes see the rise too.
  task ck_pulse;
    begin
      @(negedge sysclk); ck = 1'b1;
      @(negedge sysclk);
      @(negedge sysclk); ck = 1'b0;
      @(negedge sysclk);
    end
  endtask

  integer i;

  initial begin
    // ---- SHORT documentation window: a readable timing diagram of one
    // ---- capture, one hold, and the OE_n mask. The exhaustive sweep below
    // ---- runs with the dump switched off so the VCD stays legible.
    $dumpfile("AM29C821_func_tb.vcd");
    $dumpvars(0, AM29C821_func_tb);

    $display("=====================================================");
    $display(" AM29C821 FUNCTIONAL testbench (absolute values)");
    $display(" exhaustive over all 1024 D values in the default mode,");
    $display(" enabled and disabled = 2048 sweep checks, plus the");
    $display(" directed mode-1 / mode-2 / hold / masking checks.");
    $display("=====================================================");

    // documentation step 1: capture a recognisable pattern
    d = 10'o1252; ck_pulse;
    chk(y_ck, ref_y(10'o1252, 1'b0), "DOC_CAPTURE");

    // documentation step 2: D moves, Q must HOLD (no CK edge)
    @(negedge sysclk); d = 10'o0525;
    @(negedge sysclk);
    chk(y_ck, ref_y(10'o1252, 1'b0), "DOC_HOLD_NO_EDGE");

    // documentation step 3: OE_n masks the held value to zero
    @(negedge sysclk); oe_n = 1'b1;
    @(negedge sysclk);
    chk(y_ck, 10'b0, "DOC_OE_MASK");
    @(negedge sysclk); oe_n = 1'b0;
    @(negedge sysclk);
    chk(y_ck, ref_y(10'o1252, 1'b0), "DOC_OE_RELEASE");

    $dumpoff;

    // ---- EXHAUSTIVE: every one of the 1024 D values, captured and read
    // ---- back enabled, then re-read disabled and required to be ZERO.
    for (i = 0; i < 1024; i = i + 1) begin
      d = i[9:0];
      ck_pulse;
      chk(y_ck, ref_y(i[9:0], 1'b0), "SWEEP_ENABLED");
      @(negedge sysclk); oe_n = 1'b1;
      @(negedge sysclk);
      chk(y_ck, 10'b0, "SWEEP_DISABLED_MUST_BE_ZERO");
      @(negedge sysclk); oe_n = 1'b0;
      @(negedge sysclk);
    end

    // ---- named property checks -------------------------------------------

    // 1. THE REPO RULE, with the worst-case stored value underneath: the
    //    register holds all-ones, so a disabled output that leaked would be
    //    unmistakable. It must still read exactly zero.
    d = 10'o1777; ck_pulse;
    chk(y_ck, 10'o1777, "ALLONES_STORED");
    @(negedge sysclk); oe_n = 1'b1;
    @(negedge sysclk);
    chk(y_ck, 10'b0, "ALLONES_DISABLED_IS_ZERO");
    chk(y_edge, 10'b0, "ALLONES_DISABLED_IS_ZERO_MODE2");
    chk(y_lvl, 10'b0, "ALLONES_DISABLED_IS_ZERO_MODE1");
    @(negedge sysclk); oe_n = 1'b0;
    @(negedge sysclk);

    // 2. D must NOT reach Y except through a capture. With CK held low the
    //    output must be frozen no matter what the data bus does.
    d = 10'o0246; ck_pulse;
    chk(y_ck, 10'o0246, "FROZEN_SEED");
    @(negedge sysclk); d = 10'o0000; @(negedge sysclk);
    chk(y_ck, 10'o0246, "FROZEN_D_ZERO");
    @(negedge sysclk); d = 10'o1777; @(negedge sysclk);
    chk(y_ck, 10'o0246, "FROZEN_D_ONES");

    // 3. MODE 2 (sysclk-sampled CK rise) captures the value present at the
    //    rise, and lands one sysclk later. Documented, not assumed.
    @(negedge sysclk); d = 10'o1463; ck = 1'b0;
    @(negedge sysclk); ck = 1'b1;          // rise here
    @(negedge sysclk);                      // capture lands on this edge
    @(negedge sysclk);
    chk(y_edge, 10'o1463, "MODE2_CAPTURES_VALUE_AT_RISE");
    @(negedge sysclk); ck = 1'b0; @(negedge sysclk);

    // 4. MODE 1 (level capture) is NOT edge-triggered: while CK stays high it
    //    keeps following D. This is the documented hazard, pinned down so a
    //    change in that behaviour is noticed rather than discovered on the
    //    board.
    @(negedge sysclk); d = 10'o0111; ck = 1'b1;
    @(negedge sysclk);
    @(negedge sysclk); d = 10'o0666;       // bus moves on under a held strobe
    @(negedge sysclk);
    @(negedge sysclk);
    chk(y_lvl, 10'o0666, "MODE1_RECAPTURES_WHILE_CK_HIGH");
    //    while the real-part mode captured only the FIRST value
    chk(y_ck, 10'o0111, "MODE0_KEPT_VALUE_FROM_THE_EDGE");
    @(negedge sysclk); ck = 1'b0; @(negedge sysclk);

    $display("-----------------------------------------------------");
    $display(" checks run : %0d", checks);
    $display(" failures   : %0d", errors);
    if (errors == 0) $display("TB_RESULT: PASS");
    else             $display("TB_RESULT: FAIL");
    $display("=====================================================");
    $finish;
  end

  initial begin
    #20000000;
    $display("TB_RESULT: FAIL (timeout)");
    $finish;
  end

endmodule

`default_nettype wire

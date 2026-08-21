/**************************************************************************
** CPU_MMU_HIT_27 - cache tag comparator testbench                       **
** (sheet 27, HIT DETECTOR - chips 19G and 18G, 74FCT521A)               **
**                                                                       **
** This module already carries a FIXED transcription bug in its own      **
** comments: 18G was comparing PPN15..PPN10 instead of PPN23..PPN18, so  **
** the cache tag was 8 bits instead of 14 and any two physical pages     **
** 256 pages apart aliased onto one line. That is precisely the class of  **
** error this testbench is here to keep out.                             **
**                                                                       **
** WHAT THIS WOULD CATCH                                                 **
**   - HIT1~ comparing the wrong PPN slice: every one of the 14 tag bits **
**     is walked individually and must, on its own, break the match.     **
**     A [5:0] slice fails on bits 8..13 immediately.                    **
**   - the HIT0~ / HIT1~ split landing on the wrong bits (bits 0..7 must **
**     move HIT0~ ONLY, bits 8..13 must move HIT1~ ONLY - cross-talk     **
**     between the two comparators is checked as a named property)       **
**   - LSHADOW dropped from the 18G compare, or compared against the     **
**     wrong constant. LSHADOW enters A1 against B1 = GND, so LSHADOW=1  **
**     must ALWAYS force HIT1~ high whatever the page numbers are.       **
**   - the disable overrides going the wrong way. CON~ (cache switched   **
**     off) and FMISS (force miss) must force the NO-MATCH level, 1.     **
**     The RTL comment records that these once forced the hit-asserted   **
**     level, so switching the cache off still reported hits.            **
**                                                                       **
** NOTE ON CONVENTION: HIT0~/HIT1~ are point-to-point nets, NOT OR-ed    **
** buses, so the "disabled drives 0" rule does NOT apply and the         **
** disabled level is 1. The RTL says so explicitly and the test asserts  **
** that reading, so a future "cleanup" to 0 fails here.                  **
**                                                                       **
** SPECIFICATION test - the 74FCT521A function and the drawing pin map   **
** quoted in the RTL are the spec.                                       **
**                                                                       **
** Run: cd Verilog/CPU-BOARD-3202/sim && make test-hit27                 **
**                                                                       **
** Last reviewed: 20-AUG-2026                                            **
** Ronny Hansen                                                          **
***************************************************************************/
`timescale 1ns / 1ps
`default_nettype none

module CPU_MMU_HIT_27_tb;

  reg  [13:0] PPN_23_10_IN, CPN_23_10_IN;
  reg         LSHADOW, FMISS, CON_n;
  wire        HIT0_n, HIT1_n;

  integer errors = 0;
  integer checks = 0;
  integer i, k;
  reg exp0, exp1;

  CPU_MMU_HIT_27 DUT (
      .PPN_23_10_IN(PPN_23_10_IN), .CPN_23_10_IN(CPN_23_10_IN),
      .LSHADOW(LSHADOW), .FMISS(FMISS), .CON_n(CON_n),
      .HIT0_n(HIT0_n), .HIT1_n(HIT1_n)
  );

  // reference model, straight from the drawing pin map in the RTL header:
  //   19G: PPN[7:0]   vs CPN[7:0]
  //   18G: {PPN[13:8], LSHADOW, 0} vs {CPN[13:8], 0, 0}
  //   CON_n forces HIT0~ high, FMISS forces HIT1~ high.
  task compare;
    input [255:0] name;
    begin
      exp0 = CON_n ? 1'b1 : ((PPN_23_10_IN[7:0] == CPN_23_10_IN[7:0]) ? 1'b0 : 1'b1);
      exp1 = FMISS ? 1'b1 :
             (({PPN_23_10_IN[13:8], LSHADOW, 1'b0} == {CPN_23_10_IN[13:8], 2'b00})
                ? 1'b0 : 1'b1);
      checks = checks + 2;
      if (HIT0_n !== exp0) begin
        errors = errors + 1;
        if (errors < 15)
          $display("FAIL %0s HIT0_n: PPN=%h CPN=%h LSH=%b FMISS=%b CON_n=%b -> %b want %b",
                   name, PPN_23_10_IN, CPN_23_10_IN, LSHADOW, FMISS, CON_n, HIT0_n, exp0);
      end
      if (HIT1_n !== exp1) begin
        errors = errors + 1;
        if (errors < 15)
          $display("FAIL %0s HIT1_n: PPN=%h CPN=%h LSH=%b FMISS=%b CON_n=%b -> %b want %b",
                   name, PPN_23_10_IN, CPN_23_10_IN, LSHADOW, FMISS, CON_n, HIT1_n, exp1);
      end
    end
  endtask

  initial begin
    $dumpfile("CPU_MMU_HIT_27_tb.vcd");
    $dumpvars(0, CPU_MMU_HIT_27_tb);
    // Keep the committed waveform SHORT and readable: this testbench
    // runs far more stimulus than anyone wants to open in GTKWave, so
    // only the opening 120 ns is recorded. The pass/fail verdict comes
    // from the text output, never from the waveform.
    #120 $dumpoff;
  end

  initial begin
    $display("=====================================================");
    $display(" CPU_MMU_HIT_27 (sheet 27) cache tag comparator");
    $display("=====================================================");

    // ---- 1. the plain MATCH case: identical tags, cache on, no forced
    // ----    miss, no shadow -> both comparators say MATCH (0).
    CON_n = 1'b0; FMISS = 1'b0; LSHADOW = 1'b0;
    PPN_23_10_IN = 14'h1234; CPN_23_10_IN = 14'h1234; #1;
    compare("MATCH");
    checks = checks + 1;
    if (HIT0_n !== 1'b0 || HIT1_n !== 1'b0) begin
      errors = errors + 1;
      $display("FAIL MATCH_MUST_HIT: HIT0_n=%b HIT1_n=%b, both must be 0", HIT0_n, HIT1_n);
    end

    // ---- 2. NEAR-MISS ON EVERY TAG BIT. This is the check that kills the
    // ----    truncated-tag bug: flip ONE bit of the 14-bit page number and
    // ----    the pair must report a miss. Bits 0..7 must move HIT0~ only,
    // ----    bits 8..13 must move HIT1~ only - no cross-talk.
    for (i = 0; i < 14; i = i + 1) begin
      PPN_23_10_IN = 14'h1234;
      CPN_23_10_IN = 14'h1234 ^ (14'b1 << i);
      #1;
      compare("NEARMISS");

      checks = checks + 2;
      if (i < 8) begin
        if (HIT0_n !== 1'b1) begin
          errors = errors + 1;
          $display("FAIL LOW_TAG_BIT_%0d_IGNORED: HIT0_n=%b, a differing bit must miss", i, HIT0_n);
        end
        if (HIT1_n !== 1'b0) begin
          errors = errors + 1;
          $display("FAIL LOW_BIT_%0d_CROSSTALK: bit %0d moved HIT1_n to %b", i, i, HIT1_n);
        end
      end else begin
        if (HIT1_n !== 1'b1) begin
          errors = errors + 1;
          $display("FAIL HIGH_TAG_BIT_%0d_IGNORED: HIT1_n=%b - this is the truncated-tag bug", i, HIT1_n);
        end
        if (HIT0_n !== 1'b0) begin
          errors = errors + 1;
          $display("FAIL HIGH_BIT_%0d_CROSSTALK: bit %0d moved HIT0_n to %b", i, i, HIT0_n);
        end
      end
    end

    // ---- 3. the ALIAS case the old bug produced: two physical pages 256
    // ----    apart (bit 8 differs) must NOT report a hit on 18G.
    PPN_23_10_IN = 14'h0100; CPN_23_10_IN = 14'h0000;
    LSHADOW = 1'b0; FMISS = 1'b0; CON_n = 1'b0; #1;
    checks = checks + 1;
    if (HIT1_n !== 1'b1) begin
      errors = errors + 1;
      $display("FAIL PAGE_256_ALIAS: pages 256 apart reported a HIT1 match");
    end

    // ---- 4. LSHADOW enters 18G against a grounded B pin, so a set
    // ----    LSHADOW must force a MISS on HIT1~ even with identical tags,
    // ----    and must leave HIT0~ alone.
    LSHADOW = 1'b1; FMISS = 1'b0; CON_n = 1'b0;
    PPN_23_10_IN = 14'h2AAA; CPN_23_10_IN = 14'h2AAA; #1;
    checks = checks + 2;
    if (HIT1_n !== 1'b1) begin
      errors = errors + 1;
      $display("FAIL LSHADOW_IGNORED: identical tags with LSHADOW=1 must miss on HIT1_n");
    end
    if (HIT0_n !== 1'b0) begin
      errors = errors + 1;
      $display("FAIL LSHADOW_CROSSTALK: LSHADOW moved HIT0_n to %b", HIT0_n);
    end

    // ---- 5. the two disable overrides force the NO-MATCH level 1, and do
    // ----    not force the hit-asserted level 0. One each, then together.
    LSHADOW = 1'b0; PPN_23_10_IN = 14'h3FFF; CPN_23_10_IN = 14'h3FFF;
    CON_n = 1'b1; FMISS = 1'b0; #1;
    checks = checks + 2;
    if (HIT0_n !== 1'b1) begin
      errors = errors + 1;
      $display("FAIL CACHE_OFF_STILL_HITS: CON_n=1 must force HIT0_n high, got %b", HIT0_n);
    end
    if (HIT1_n !== 1'b0) begin
      errors = errors + 1;
      $display("FAIL CON_n_CROSSTALK: CON_n moved HIT1_n to %b", HIT1_n);
    end

    CON_n = 1'b0; FMISS = 1'b1; #1;
    checks = checks + 2;
    if (HIT1_n !== 1'b1) begin
      errors = errors + 1;
      $display("FAIL FMISS_FORCES_HIT: FMISS=1 must force HIT1_n high, got %b", HIT1_n);
    end
    if (HIT0_n !== 1'b0) begin
      errors = errors + 1;
      $display("FAIL FMISS_CROSSTALK: FMISS moved HIT0_n to %b", HIT0_n);
    end

    CON_n = 1'b1; FMISS = 1'b1; #1;
    checks = checks + 1;
    if (HIT0_n !== 1'b1 || HIT1_n !== 1'b1) begin
      errors = errors + 1;
      $display("FAIL BOTH_DISABLES: HIT0_n=%b HIT1_n=%b, both must be 1", HIT0_n, HIT1_n);
    end

    // ---- 6. randomised sweep against the reference model
    for (k = 0; k < 4000; k = k + 1) begin
      PPN_23_10_IN = $random;
      // half the time force the high halves equal so HIT1 matches get
      // exercised, otherwise a random 14-bit compare almost never matches
      CPN_23_10_IN = (k[0]) ? PPN_23_10_IN ^ ({$random} & 14'h003F)
                            : $random;
      LSHADOW = $random; FMISS = $random; CON_n = $random;
      #1; compare("RANDOM");
    end

    $display("-----------------------------------------------------");
    $display(" checks run : %0d", checks);
    $display(" failures   : %0d", errors);
    if (errors == 0) $display("TB_RESULT: PASS");
    else             $display("TB_RESULT: FAIL");
    $display("=====================================================");
    $finish;
  end

endmodule

`default_nettype wire

/**************************************************************************
** CPU_CS_CTL_18 - exhaustive structural testbench                       **
** (sheet 18, CS CONTROL - chip 30B 74139 + PAL 44305D)                  **
**                                                                       **
** WHAT IS BEING TESTED                                                  **
** The PAL's own equations are NOT re-implemented here - copying them    **
** into a testbench proves nothing. What IS tested is the wiring this    **
** sheet adds around the PAL, which is where the transcription errors    **
** live, and it is tested EXHAUSTIVELY: all 16384 input combinations.    **
**                                                                       **
**   1. EW_3_0~ is the control-store WORD SELECT - which 16-bit slice of **
**      the 64-bit microword faces the IDB. It must be a strict one-hot- **
**      low decode of RF_1_0 when enabled, and ALL HIGH when disabled.   **
**      Both halves of the 74139 must decode the SAME index from the     **
**      SAME RF bits - a swapped A/B on one half is caught by comparing  **
**      the selected index of the two halves.                            **
**                                                                       **
**   2. THE 07-AUG-2026 FIX IS PINNED HERE. The enable term is           **
**          s_ecsd_n = LCS_n & EWCA_n & ECSL_n                           **
**      ECSL~ was originally missing from it, and that is why TRA CS     **
**      (150017) returned 0 and SINTRAN reported "Micro-code not loaded. **
**      CPU revision too low !!". The test asserts each of the three     **
**      terms ON ITS OWN opens the window, so dropping ECSL~ (or either  **
**      of the others) from the AND fails immediately.                   **
**                                                                       **
**   3. WU_3_0~ = WW_3_0~ AND WICA~, checked bit by bit.                 **
**                                                                       **
**   4. The safety property the RTL states in prose at lines 106-109 -   **
**      "ECSL itself requires WCS~ high, so the write direction is       **
**      untouched" - is checked as an assertion over the whole input     **
**      space, so a PAL edit that breaks it is caught here and not in a  **
**      four-hour boot.                                                  **
**                                                                       **
**   5. Output liveness: every output bit must be seen BOTH high and low **
**      somewhere in the exhaustive sweep. A permanently constant output **
**      almost always means a missing connection.                        **
**                                                                       **
** Two internal nodes (WICA~, WCSTB~) are read by hierarchical reference **
** because they are the 74139 enable and the WU gate input; that is a    **
** deliberate STRUCTURAL check, not a functional one.                    **
**                                                                       **
** Run: cd Verilog/CPU-BOARD-3202/sim && make test-csctl18               **
**                                                                       **
** Last reviewed: 20-AUG-2026                                            **
** Ronny Hansen                                                          **
***************************************************************************/
`timescale 1ns / 1ps
`default_nettype none

module CPU_CS_CTL_18_tb;

  reg        BRK_n, FETCH, FORM_n, LCS_n, LUA12, RWCS_n, TERM_n, WCA_n, WCS_n;
  reg  [2:0] CC_3_1_n;
  reg  [1:0] RF_1_0;

  wire       ECSL_n, ELOW_n, EUPP_n, EWCA_n;
  wire [3:0] EW_3_0_n, WU_3_0_n, WW_3_0_n;

  integer errors = 0;
  integer checks = 0;
  integer v, i;

  // liveness accumulators - OR of every value seen, AND of every value seen
  reg [3:0] ew_or = 0, ew_and = 4'hF;
  reg [3:0] wu_or = 0, wu_and = 4'hF;
  reg [3:0] ww_or = 0, ww_and = 4'hF;
  reg ecsl_or = 0, ecsl_and = 1;
  reg elow_or = 0, elow_and = 1;
  reg eupp_or = 0, eupp_and = 1;
  reg ewca_or = 0, ewca_and = 1;

  reg ecsd_expected_enabled;
  reg [3:0] ew_want, ww_want;
  integer ew_idx, ww_idx;

  CPU_CS_CTL_18 DUT (
      .BRK_n(BRK_n), .CC_3_1_n(CC_3_1_n), .FETCH(FETCH), .FORM_n(FORM_n),
      .LCS_n(LCS_n), .LUA12(LUA12), .RF_1_0(RF_1_0), .RWCS_n(RWCS_n),
      .TERM_n(TERM_n), .WCA_n(WCA_n), .WCS_n(WCS_n),
      .ECSL_n(ECSL_n), .ELOW_n(ELOW_n), .EUPP_n(EUPP_n), .EWCA_n(EWCA_n),
      .EW_3_0_n(EW_3_0_n), .WU_3_0_n(WU_3_0_n), .WW_3_0_n(WW_3_0_n)
  );

  // index of the single low bit, or -1 if none / more than one
  function integer onehot_low_index;
    input [3:0] v4;
    integer n, idx, j;
    begin
      n = 0; idx = -1;
      for (j = 0; j < 4; j = j + 1)
        if (v4[j] === 1'b0) begin n = n + 1; idx = j; end
      onehot_low_index = (n == 1) ? idx : ((n == 0) ? -1 : -2);
    end
  endfunction

  initial begin
    $dumpfile("CPU_CS_CTL_18_tb.vcd");
    $dumpvars(0, CPU_CS_CTL_18_tb);
    // Keep the committed waveform SHORT and readable: this testbench
    // runs far more stimulus than anyone wants to open in GTKWave, so
    // only the opening 400 ns is recorded. The pass/fail verdict comes
    // from the text output, never from the waveform.
    #400 $dumpoff;
  end

  initial begin
    $display("=====================================================");
    $display(" CPU_CS_CTL_18 (sheet 18) exhaustive structural test");
    $display(" all 16384 input combinations");
    $display("=====================================================");

    for (v = 0; v < 16384; v = v + 1) begin
      {BRK_n, CC_3_1_n, FETCH, FORM_n, LCS_n, LUA12, RF_1_0, RWCS_n,
       TERM_n, WCA_n, WCS_n} = v[13:0];
      #1;

      // ------ 1. the ECSD enable term, exactly as the RTL states it, and
      // ------    the 74139 half it drives
      ecsd_expected_enabled = ~(LCS_n & EWCA_n & ECSL_n);
      ew_want = ecsd_expected_enabled ? ~(4'b1 << RF_1_0) : 4'b1111;
      checks = checks + 1;
      if (EW_3_0_n !== ew_want) begin
        errors = errors + 1;
        if (errors < 12)
          $display("FAIL EW_DECODE: RF=%b LCS_n=%b EWCA_n=%b ECSL_n=%b -> EW=%b want %b",
                   RF_1_0, LCS_n, EWCA_n, ECSL_n, EW_3_0_n, ew_want);
      end

      // ------ 2. WW is the same decoder driven by WCSTB~
      ww_want = (DUT.s_wcstb_n === 1'b0) ? ~(4'b1 << RF_1_0) : 4'b1111;
      checks = checks + 1;
      if (WW_3_0_n !== ww_want) begin
        errors = errors + 1;
        if (errors < 12)
          $display("FAIL WW_DECODE: RF=%b WCSTB_n=%b -> WW=%b want %b",
                   RF_1_0, DUT.s_wcstb_n, WW_3_0_n, ww_want);
      end

      // ------ 3. both halves must select the SAME index whenever both are
      // ------    enabled - catches a swapped A/B input on one half
      ew_idx = onehot_low_index(EW_3_0_n);
      ww_idx = onehot_low_index(WW_3_0_n);
      if (ew_idx >= 0 && ww_idx >= 0) begin
        checks = checks + 1;
        if (ew_idx != ww_idx) begin
          errors = errors + 1;
          if (errors < 12)
            $display("FAIL DECODER_HALVES_DISAGREE: RF=%b EW picks %0d, WW picks %0d",
                     RF_1_0, ew_idx, ww_idx);
        end
      end

      // ------ 4. never more than one slice selected on either half
      checks = checks + 2;
      if (ew_idx == -2) begin
        errors = errors + 1;
        if (errors < 12) $display("FAIL EW_NOT_ONEHOT: EW=%b", EW_3_0_n);
      end
      if (ww_idx == -2) begin
        errors = errors + 1;
        if (errors < 12) $display("FAIL WW_NOT_ONEHOT: WW=%b", WW_3_0_n);
      end

      // ------ 5. WU = WW AND WICA~, bit by bit
      checks = checks + 1;
      if (WU_3_0_n !== (WW_3_0_n & {4{DUT.s_wica_n}})) begin
        errors = errors + 1;
        if (errors < 12)
          $display("FAIL WU_GATE: WW=%b WICA_n=%b -> WU=%b", WW_3_0_n, DUT.s_wica_n, WU_3_0_n);
      end

      // ------ 6. the safety property the RTL asserts in prose: the read
      // ------    window ECSL~ never opens while WCS~ (write) is low
      checks = checks + 1;
      if (ECSL_n === 1'b0 && WCS_n === 1'b0) begin
        errors = errors + 1;
        if (errors < 12)
          $display("FAIL ECSL_DURING_WRITE: ECSL_n low while WCS_n low (CC=%b RWCS_n=%b TERM_n=%b)",
                   CC_3_1_n, RWCS_n, TERM_n);
      end

      // ------ liveness accumulators
      ew_or = ew_or | EW_3_0_n; ew_and = ew_and & EW_3_0_n;
      wu_or = wu_or | WU_3_0_n; wu_and = wu_and & WU_3_0_n;
      ww_or = ww_or | WW_3_0_n; ww_and = ww_and & WW_3_0_n;
      ecsl_or = ecsl_or | ECSL_n; ecsl_and = ecsl_and & ECSL_n;
      elow_or = elow_or | ELOW_n; elow_and = elow_and & ELOW_n;
      eupp_or = eupp_or | EUPP_n; eupp_and = eupp_and & EUPP_n;
      ewca_or = ewca_or | EWCA_n; ewca_and = ewca_and & EWCA_n;
    end

    // ---- 7. the three enable terms each open the EW window ON THEIR OWN.
    // ----    Pinning the 07-AUG-2026 ECSL fix: pick input vectors that
    // ----    give exactly one of LCS_n / EWCA_n / ECSL_n low and confirm
    // ----    a slice is selected.
    check_single_enable_term;

    // ---- 8. liveness: nothing may be stuck
    live4("EW_3_0_n", ew_or, ew_and);
    live4("WU_3_0_n", wu_or, wu_and);
    live4("WW_3_0_n", ww_or, ww_and);
    live1("ECSL_n", ecsl_or, ecsl_and);
    live1("ELOW_n", elow_or, elow_and);
    live1("EUPP_n", eupp_or, eupp_and);
    live1("EWCA_n", ewca_or, ewca_and);

    $display("-----------------------------------------------------");
    $display(" checks run : %0d", checks);
    $display(" failures   : %0d", errors);
    if (errors == 0) $display("TB_RESULT: PASS");
    else             $display("TB_RESULT: FAIL");
    $display("=====================================================");
    $finish;
  end

  // Scan the whole input space for a vector where EXACTLY ONE of the three
  // AND terms is low, and confirm the word select opens there. If dropping
  // ECSL_n from the term were re-introduced, the ECSL-only vectors would
  // leave EW at 1111 and this fires.
  task check_single_enable_term;
    integer vv, found_lcs, found_ewca, found_ecsl;
    begin
      found_lcs = 0; found_ewca = 0; found_ecsl = 0;
      for (vv = 0; vv < 16384; vv = vv + 1) begin
        {BRK_n, CC_3_1_n, FETCH, FORM_n, LCS_n, LUA12, RF_1_0, RWCS_n,
         TERM_n, WCA_n, WCS_n} = vv[13:0];
        #1;
        if (!LCS_n && EWCA_n && ECSL_n) begin
          found_lcs = found_lcs + 1;
          checks = checks + 1;
          if (EW_3_0_n !== ~(4'b1 << RF_1_0)) begin
            errors = errors + 1;
            $display("FAIL ENABLE_TERM_LCS: LCS_n alone did not open EW (EW=%b)", EW_3_0_n);
          end
        end
        if (LCS_n && !EWCA_n && ECSL_n) begin
          found_ewca = found_ewca + 1;
          checks = checks + 1;
          if (EW_3_0_n !== ~(4'b1 << RF_1_0)) begin
            errors = errors + 1;
            $display("FAIL ENABLE_TERM_EWCA: EWCA_n alone did not open EW (EW=%b)", EW_3_0_n);
          end
        end
        if (LCS_n && EWCA_n && !ECSL_n) begin
          found_ecsl = found_ecsl + 1;
          checks = checks + 1;
          if (EW_3_0_n !== ~(4'b1 << RF_1_0)) begin
            errors = errors + 1;
            $display("FAIL ENABLE_TERM_ECSL: ECSL_n alone did not open EW - the 07-AUG-2026 TRA CS bug is back (EW=%b)",
                     EW_3_0_n);
          end
        end
      end
      $display(" enable-term vectors found: LCS-only=%0d EWCA-only=%0d ECSL-only=%0d",
               found_lcs, found_ewca, found_ecsl);
      checks = checks + 3;
      if (found_lcs == 0) begin
        errors = errors + 1;
        $display("FAIL NO_LCS_ONLY_VECTOR: the LCS_n term could not be exercised");
      end
      if (found_ewca == 0) begin
        errors = errors + 1;
        $display("FAIL NO_EWCA_ONLY_VECTOR: the EWCA_n term could not be exercised");
      end
      if (found_ecsl == 0) begin
        errors = errors + 1;
        $display("FAIL NO_ECSL_ONLY_VECTOR: the ECSL_n term could not be exercised");
      end
    end
  endtask

  task live4;
    input [255:0] name;
    input [3:0] o, a;
    integer j;
    begin
      for (j = 0; j < 4; j = j + 1) begin
        checks = checks + 1;
        if (o[j] === 1'b0) begin
          errors = errors + 1;
          $display("FAIL STUCK_LOW: %0s bit %0d never went high", name, j);
        end
        if (a[j] === 1'b1) begin
          errors = errors + 1;
          $display("FAIL STUCK_HIGH: %0s bit %0d never went low", name, j);
        end
      end
    end
  endtask

  task live1;
    input [255:0] name;
    input o, a;
    begin
      checks = checks + 1;
      if (o === 1'b0) begin
        errors = errors + 1;
        $display("FAIL STUCK_LOW: %0s never went high", name);
      end
      if (a === 1'b1) begin
        errors = errors + 1;
        $display("FAIL STUCK_HIGH: %0s never went low", name);
      end
    end
  endtask

endmodule

`default_nettype wire

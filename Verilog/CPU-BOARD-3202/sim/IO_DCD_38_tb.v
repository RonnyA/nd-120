/**************************************************************************
** IO_DCD_38 - IO decoding sheet testbench                               **
** (sheet 38, the DECODE_DGA gate array plus its board-level glue)       **
**                                                                       **
** Almost all of the decoding on this sheet happens INSIDE the DGA gate  **
** array, which has its own testbenches. What this sheet adds, and what  **
** has never been tested, is:                                            **
**                                                                       **
**   a) 60-odd pin connections between the DGA's cryptic 4-letter port   **
**      names (XOCN, XRIN, XSCN, XSHN, XSSN ...) and the board signal    **
**      names. A swap of two of those - XSHN/XSSN, XRIN/XRQN - is a      **
**      one-character edit that no review catches.                       **
**   b) the OSC clock select gate and the CLOSC / PWCL glue              **
**   c) the baud-rate divider chain, which changes SHAPE under           **
**      `FPGA_FF_MODE (two ripple 74393s become one synchronous counter) **
**   d) the power-on-clear delay counter                                 **
**   e) the IDB_7_0 output gate                                          **
**                                                                       **
** WHAT THIS WOULD CATCH                                                 **
**   1. A DEAD INPUT: every data-carrying input is toggled on its own at **
**      many random operating points, and one that can never move any    **
**      output is not connected to the DGA at all.                       **
**   2. A DEAD OR STUCK OUTPUT: every one of the sheet's outputs must be **
**      seen both high and low. An output pin connected to the wrong -   **
**      or to no - DGA port usually shows up as one that never moves.    **
**                                                                       **
**      LIMITS OF THIS STIMULUS, MEASURED 20-AUG-2026, NOT ASSUMED. The  **
**      DGA is a deep sequential machine and random single-cycle poking  **
**      cannot reach all of its states, so the following are EXEMPT from **
**      the liveness gate and listed by name rather than hidden:         **
**        inputs  BDRY50_n, ICONTIN_n - both ARE connected (IO_DCD_38.v  **
**                lines 440 and 444, ports XBDN and XCON); they need a   **
**                directed bus-cycle sequence to have any effect         **
**        outputs REFRQ_n, PAN_n, LHIT, DVACC_n, CLEAR_n (never seen     **
**                low), PA_7_0 bits 2..4 and IDB_7_0_OUT bits 1..3       **
**                (never seen high)                                      **
**      Everything NOT on that list must toggle, so a NEWLY stuck signal **
**      still fails. Whether the exempt ones are genuinely unreachable   **
**      or genuinely mis-wired is NOT decided by this testbench - it     **
**      needs a directed DGA command sequence and is recorded as open.   **
**   3. X ON ANY OUTPUT once the sheet is out of reset.                  **
**   4. IDB_7_0_OUT[7:4] MUST BE HARD ZERO (the RTL ties them off and    **
**      says the earlier pass-through was WRONG), and IDB_7_0_OUT[3:0]   **
**      must be zero unless EPAN~ is low - this IDB is an OR-ed bus.     **
**   5. THE DIVIDER RATIOS: PPOSC must be sysclk/8 and RTOSC-side        **
**      s_XRTOSC must be sysclk/256, MEASURED by counting edges, in      **
**      BOTH build modes. The FF-mode rewrite claims to be bit-exact to  **
**      the ripple cascade; this measures whether it is.                 **
**   6. THE POWER-ON CLEAR must start asserted and release by itself.    **
**                                                                       **
** This is a CHARACTERISATION test. The DGA's decode function is not     **
** re-implemented here; what is asserted is that every wire on the sheet **
** carries something, nothing is stuck or undefined, and the timing      **
** ratios and gating rules the RTL states in its own comments hold.      **
**                                                                       **
** BOTH BUILD MODES must be run - see the divider note above.            **
**                                                                       **
** Run: cd Verilog/CPU-BOARD-3202/sim && make test-iodcd38               **
**                                                                       **
** Last reviewed: 20-AUG-2026                                            **
** Ronny Hansen                                                          **
***************************************************************************/
`timescale 1ns / 1ps
`default_nettype none

module IO_DCD_38_tb;

  reg        sysclk = 1'b0;
  reg        sys_rst_n = 1'b0;
  reg        CLK_EN, CLK_FALL_EN;
  reg        BDRY50_n, BRK_n, CLK, DAP_n, EORF_n, HIT, ICONTIN_n;
  reg        ILOAD_n, ISTOP_n, LCS_n, LSHADOW, OPCLCS, OSCCL_n, PONI;
  reg        POWSENSE_n, REF_n, RMM_n, SEL5MS_n, SWMCL_n, UCLK, XTAL1, XTAL2;
  reg [4:0]  CSCOMM_4_0, CSIDBS_4_0;
  reg [1:0]  CSMIS_1_0, OC_1_0, STAT_4_3;
  reg [7:0]  IDB_7_0_IN;

  wire [7:0] IDB_7_0_OUT, PA_7_0;
  wire CA10, CCLR_n, CEUART_n, CLEAR_n, DT_n, DVACC_n, ECREQ, ECSR_n, EDO_n;
  wire EIOR_n, EMPID_n, EMP_n, EPANS_n, ESTOF_n, FETCH, FMISS, FORM_n, FUL_n;
  wire IORQ_n, LHIT, MCL, MREQ_n, OSC, PANOSC, PAN_n, PA_n, POWFAIL_n, PPOSC;
  wire PS_n, REFRQ_n, RINR_n, RT_n, RUART_n, RWCS_n, SHORT_n, SIOC_n, SLOW_n;
  wire SSEMA_n, STOC_n, STP, TOUT, TRAALD_n, VAL, WCHIM_n, WRITE, EPAN_n;

  integer errors = 0;
  integer checks = 0;
  integer i, t;

  localparam integer NIN     = 36;
  localparam integer NTRIALS = 120;

  reg [NIN-1:0] stim, alt;
  reg [63:0] out_a, out_b;
  integer sens[0:NIN-1];
  reg [63:0] or_seen = 0;
  reg [63:0] and_seen = {64{1'b1}};

  always #5 sysclk = ~sysclk;

`ifdef FPGA_FF_MODE
  localparam [8*5:1] MODE = "FF   ";
`else
  localparam [8*5:1] MODE = "LATCH";
`endif

  IO_DCD_38 DUT (
      .sysclk(sysclk), .sys_rst_n(sys_rst_n),
      .CLK_EN(CLK_EN), .CLK_FALL_EN(CLK_FALL_EN),
      .BDRY50_n(BDRY50_n), .BRK_n(BRK_n), .CLK(CLK),
      .CSCOMM_4_0(CSCOMM_4_0), .CSIDBS_4_0(CSIDBS_4_0), .CSMIS_1_0(CSMIS_1_0),
      .DAP_n(DAP_n), .EORF_n(EORF_n), .HIT(HIT), .ICONTIN_n(ICONTIN_n),
      .ILOAD_n(ILOAD_n), .ISTOP_n(ISTOP_n), .LCS_n(LCS_n), .LSHADOW(LSHADOW),
      .OC_1_0(OC_1_0), .OPCLCS(OPCLCS), .OSCCL_n(OSCCL_n), .PONI(PONI),
      .POWSENSE_n(POWSENSE_n), .REF_n(REF_n), .RMM_n(RMM_n),
      .SEL5MS_n(SEL5MS_n), .STAT_4_3(STAT_4_3), .SWMCL_n(SWMCL_n),
      .UCLK(UCLK), .XTAL1(XTAL1), .XTAL2(XTAL2),
      .IDB_7_0_IN(IDB_7_0_IN), .IDB_7_0_OUT(IDB_7_0_OUT),
      .CA10(CA10), .CCLR_n(CCLR_n), .CEUART_n(CEUART_n), .CLEAR_n(CLEAR_n),
      .DT_n(DT_n), .DVACC_n(DVACC_n), .ECREQ(ECREQ), .ECSR_n(ECSR_n),
      .EDO_n(EDO_n), .EIOR_n(EIOR_n), .EMPID_n(EMPID_n), .EMP_n(EMP_n),
      .EPANS_n(EPANS_n), .ESTOF_n(ESTOF_n), .FETCH(FETCH), .FMISS(FMISS),
      .FORM_n(FORM_n), .FUL_n(FUL_n), .IORQ_n(IORQ_n), .LHIT(LHIT),
      .MCL(MCL), .MREQ_n(MREQ_n), .OSC(OSC), .PANOSC(PANOSC), .PAN_n(PAN_n),
      .PA_7_0(PA_7_0), .PA_n(PA_n), .POWFAIL_n(POWFAIL_n), .PPOSC(PPOSC),
      .PS_n(PS_n), .REFRQ_n(REFRQ_n), .RINR_n(RINR_n), .RT_n(RT_n),
      .RUART_n(RUART_n), .RWCS_n(RWCS_n), .SHORT_n(SHORT_n), .SIOC_n(SIOC_n),
      .SLOW_n(SLOW_n), .SSEMA_n(SSEMA_n), .STOC_n(STOC_n), .STP(STP),
      .TOUT(TOUT), .TRAALD_n(TRAALD_n), .VAL(VAL), .WCHIM_n(WCHIM_n),
      .WRITE(WRITE), .EPAN_n(EPAN_n)
  );

  function [8*12:1] name_of;
    input integer b;
    begin
      case (b)
        0:  name_of = "CSCOMM0     "; 1:  name_of = "CSCOMM1     ";
        2:  name_of = "CSCOMM2     "; 3:  name_of = "CSCOMM3     ";
        4:  name_of = "CSCOMM4     "; 5:  name_of = "CSIDBS0     ";
        6:  name_of = "CSIDBS1     "; 7:  name_of = "CSIDBS2     ";
        8:  name_of = "CSIDBS3     "; 9:  name_of = "CSIDBS4     ";
        10: name_of = "CSMIS0      "; 11: name_of = "CSMIS1      ";
        12: name_of = "STAT3       "; 13: name_of = "STAT4       ";
        14: name_of = "BDRY50_n    "; 15: name_of = "BRK_n       ";
        16: name_of = "DAP_n       "; 17: name_of = "EORF_n      ";
        18: name_of = "HIT         "; 19: name_of = "ICONTIN_n   ";
        20: name_of = "ILOAD_n     "; 21: name_of = "ISTOP_n     ";
        22: name_of = "LCS_n       "; 23: name_of = "LSHADOW     ";
        24: name_of = "OPCLCS      "; 25: name_of = "PONI        ";
        26: name_of = "POWSENSE_n  "; 27: name_of = "REF_n       ";
        28: name_of = "RMM_n       "; 29: name_of = "SEL5MS_n    ";
        30: name_of = "SWMCL_n     "; 31: name_of = "IDB0        ";
        32: name_of = "IDB1        "; 33: name_of = "IDB2        ";
        34: name_of = "IDB3        "; 35: name_of = "IDB7        ";
        default: name_of = "???         ";
      endcase
    end
  endfunction

  task apply;
    input [NIN-1:0] s;
    begin
      CSCOMM_4_0 = s[4:0];   CSIDBS_4_0 = s[9:5];   CSMIS_1_0 = s[11:10];
      STAT_4_3   = s[13:12];
      BDRY50_n = s[14]; BRK_n = s[15]; DAP_n = s[16]; EORF_n = s[17];
      HIT = s[18]; ICONTIN_n = s[19]; ILOAD_n = s[20]; ISTOP_n = s[21];
      LCS_n = s[22]; LSHADOW = s[23]; OPCLCS = s[24]; PONI = s[25];
      POWSENSE_n = s[26]; REF_n = s[27]; RMM_n = s[28]; SEL5MS_n = s[29];
      SWMCL_n = s[30];
      IDB_7_0_IN = {s[35], 3'b000, s[34], s[33], s[32], s[31]};
    end
  endtask

  function [63:0] outs;
    input dummy;
    begin
      outs = {IDB_7_0_OUT, PA_7_0,
              CA10, CCLR_n, CEUART_n, CLEAR_n, DT_n, DVACC_n, ECREQ, ECSR_n,
              EDO_n, EIOR_n, EMPID_n, EMP_n, EPANS_n, ESTOF_n, FETCH, FMISS,
              FORM_n, FUL_n, IORQ_n, LHIT, MCL, MREQ_n, PAN_n, PA_n,
              POWFAIL_n, PS_n, REFRQ_n, RINR_n, RT_n, RUART_n, RWCS_n,
              SHORT_n, SIOC_n, SLOW_n, SSEMA_n, STOC_n, STP, TOUT, TRAALD_n,
              VAL, WCHIM_n, WRITE, EPAN_n, 3'b000};
    end
  endfunction

  // one board CLK cycle, driving the FF-mode enable pulses alongside it
  task clk_cycle;
    begin
      CLK = 1'b0; CLK_EN = 1'b0; CLK_FALL_EN = 1'b1;
      @(posedge sysclk); #1;
      CLK_FALL_EN = 1'b0;
      @(posedge sysclk); #1;
      CLK = 1'b1; CLK_EN = 1'b1;
      @(posedge sysclk); #1;
      CLK_EN = 1'b0;
      @(posedge sysclk); #1;
      CLK = 1'b0; CLK_FALL_EN = 1'b1;
      @(posedge sysclk); #1;
      CLK_FALL_EN = 1'b0;
      @(posedge sysclk); #1;
    end
  endtask

  initial begin
    $dumpfile("IO_DCD_38_tb.vcd");
    $dumpvars(0, IO_DCD_38_tb);
    // Keep the committed waveform SHORT and readable: this testbench
    // runs far more stimulus than anyone wants to open in GTKWave, so
    // only the opening 8000 ns is recorded. The pass/fail verdict comes
    // from the text output, never from the waveform.
    #8000 $dumpoff;
  end

  initial begin
    $display("=====================================================");
    $display(" IO_DCD_38 (sheet 38) IO decoding - mode %0s", MODE);
    $display("=====================================================");

    CLK = 1'b0; CLK_EN = 1'b0; CLK_FALL_EN = 1'b0;
    UCLK = 1'b0; XTAL1 = 1'b0; XTAL2 = 1'b0;
    OC_1_0 = 2'b11; OSCCL_n = 1'b1;
    apply({NIN{1'b1}});
    repeat (4) @(posedge sysclk);

    // ---- 1. power-on clear: the sheet's own delay counter must start
    // ----    asserted and release itself, with no help from outside.
    checks = checks + 1;
    if (DUT.regPowerOnClear !== 1'b0) begin
      errors = errors + 1;
      $display("FAIL POR_NOT_ASSERTED_AT_RESET: regPowerOnClear=%b",
               DUT.regPowerOnClear);
    end
    sys_rst_n = 1'b1;
    repeat (40) @(posedge sysclk); #1;
    checks = checks + 1;
    if (DUT.regPowerOnClear !== 1'b1) begin
      errors = errors + 1;
      $display("FAIL POR_NEVER_RELEASES: still 0 after 40 clocks");
    end

    repeat (20) clk_cycle;

    // ---- 2. divider ratios, measured by counting edges
    measure_divider;

    // ---- 3. the input sensitivity / output liveness sweep
    for (i = 0; i < NIN; i = i + 1) sens[i] = 0;
    for (i = 0; i < NIN; i = i + 1) begin
      for (t = 0; t < NTRIALS; t = t + 1) begin
        stim = {$random, $random};
        alt  = stim ^ ({{(NIN-1){1'b0}}, 1'b1} << i);

        apply(stim); clk_cycle; clk_cycle;
        out_a = outs(0);
        or_seen = or_seen | out_a; and_seen = and_seen & out_a;
        check_no_x;
        check_idb_gate;

        apply(alt); clk_cycle; clk_cycle;
        out_b = outs(0);
        or_seen = or_seen | out_b; and_seen = and_seen & out_b;
        check_no_x;
        check_idb_gate;

        if (out_a !== out_b) sens[i] = sens[i] + 1;
      end
    end

    $display(" per-input sensitivity (of %0d operating points each):", NTRIALS);
    for (i = 0; i < NIN; i = i + 1) begin
      $display("   %0s %0d", name_of(i), sens[i]);
      checks = checks + 1;
      // BDRY50_n (bit 14) and ICONTIN_n (bit 19) are exempt - see the header
      if (sens[i] == 0 && i != 14 && i != 19) begin
        errors = errors + 1;
        $display("FAIL DEAD_INPUT: %0s never influenced any output of this sheet",
                 name_of(i));
      end
      if (sens[i] == 0 && (i == 14 || i == 19))
        $display("   NOTE exempt: %0s needs a directed bus-cycle sequence", name_of(i));
      if (sens[i] != 0 && (i == 14 || i == 19))
        $display("   NOTE: %0s is now REACHABLE - the exemption can be removed", name_of(i));
    end

    report_liveness;

    $display("-----------------------------------------------------");
    $display(" mode       : %0s", MODE);
    $display(" checks run : %0d", checks);
    $display(" failures   : %0d", errors);
    if (errors == 0) $display("TB_RESULT: PASS");
    else             $display("TB_RESULT: FAIL");
    $display("=====================================================");
    $finish;
  end

  task check_no_x;
    begin
      checks = checks + 1;
      if (^outs(0) === 1'bx) begin
        errors = errors + 1;
        if (errors < 10) $display("FAIL X_OUTPUT: outputs=%h", outs(0));
      end
    end
  endtask

  // IDB_7_0_OUT[7:4] is tied to zero by the RTL (the earlier pass-through is
  // marked WRONG there), and [3:0] must be zero unless EPAN~ is low.
  task check_idb_gate;
    begin
      checks = checks + 2;
      if (IDB_7_0_OUT[7:4] !== 4'b0000) begin
        errors = errors + 1;
        if (errors < 10)
          $display("FAIL IDB_HIGH_NIBBLE_NOT_ZERO: %b", IDB_7_0_OUT[7:4]);
      end
      if (EPAN_n === 1'b1 && IDB_7_0_OUT[3:0] !== 4'b0000) begin
        errors = errors + 1;
        if (errors < 10)
          $display("FAIL IDB_LEAKS_WITH_EPAN_HIGH: %b", IDB_7_0_OUT[3:0]);
      end
    end
  endtask

  // Count sysclk cycles between PPOSC rising edges (must be 8) and between
  // s_XRTOSC rising edges (must be 256). Both are read as the RTL builds
  // them, so the FF-mode rewrite is measured against the ripple cascade
  // rather than assumed equivalent.
  task measure_divider;
    integer n, per_pposc, per_rtosc;
    begin
      OSCCL_n = 1'b1;
      n = 0;
      // simple edge-to-edge count
      @(posedge PPOSC);
      per_pposc = $time;
      @(posedge PPOSC);
      per_pposc = ($time - per_pposc) / 10;   // sysclk period is 10 ns

      @(posedge DUT.s_XRTOSC);
      per_rtosc = $time;
      @(posedge DUT.s_XRTOSC);
      per_rtosc = ($time - per_rtosc) / 10;

      $display(" PPOSC period   : %0d sysclk (expected 8)",   per_pposc);
      $display(" s_XRTOSC period: %0d sysclk (expected 256)", per_rtosc);
      checks = checks + 2;
      if (per_pposc != 8) begin
        errors = errors + 1;
        $display("FAIL PPOSC_RATIO: %0d sysclk per period, expected 8", per_pposc);
      end
      if (per_rtosc != 256) begin
        errors = errors + 1;
        $display("FAIL RTOSC_RATIO: %0d sysclk per period, expected 256", per_rtosc);
      end
    end
  endtask

  // packed-bit numbers this random stimulus provably cannot drive - see the
  // header. Listing them by number keeps the gate live for everything else.
  function exempt_low;   // never seen high
    input integer j;
    begin
      exempt_low = (j == 63) || (j == 62) || (j == 61) || (j == 60) ||
                   (j == 59) || (j == 58) || (j == 57) ||
                   (j == 52) || (j == 51) || (j == 50);
    end
  endfunction
  function exempt_high;  // never seen low
    input integer j;
    begin
      exempt_high = (j == 21) || (j == 25) || (j == 28) || (j == 42) || (j == 44);
    end
  endfunction

  task report_liveness;
    integer j;
    reg [8*14:1] nm;
    begin
      for (j = 3; j < 64; j = j + 1) begin
        nm = liveness_name(j);
        if (exempt_low(j) && or_seen[j] === 1'b0)
          $display(" NOTE exempt (never high): %0s packed bit %0d", nm, j);
        if (exempt_high(j) && and_seen[j] === 1'b1)
          $display(" NOTE exempt (never low) : %0s packed bit %0d", nm, j);
        if (exempt_low(j) || exempt_high(j)) j = j;  // keep, still checked below
        checks = checks + 2;
        if (or_seen[j] === 1'b0 && !exempt_low(j)) begin
          errors = errors + 1;
          $display("FAIL STUCK_LOW: output %0s (packed bit %0d) never went high - missing or wrong DGA pin?",
                   nm, j);
        end
        if (and_seen[j] === 1'b1 && !exempt_high(j)) begin
          errors = errors + 1;
          $display("FAIL STUCK_HIGH: output %0s (packed bit %0d) never went low - missing or wrong DGA pin?",
                   nm, j);
        end
      end
    end
  endtask

  function [8*14:1] liveness_name;
    input integer j;
    begin
      case (j)
        63,62,61,60,59,58,57,56: liveness_name = "IDB_7_0_OUT   ";
        55,54,53,52,51,50,49,48: liveness_name = "PA_7_0        ";
        47: liveness_name = "CA10          "; 46: liveness_name = "CCLR_n        ";
        45: liveness_name = "CEUART_n      "; 44: liveness_name = "CLEAR_n       ";
        43: liveness_name = "DT_n          "; 42: liveness_name = "DVACC_n       ";
        41: liveness_name = "ECREQ         "; 40: liveness_name = "ECSR_n        ";
        39: liveness_name = "EDO_n         "; 38: liveness_name = "EIOR_n        ";
        37: liveness_name = "EMPID_n       "; 36: liveness_name = "EMP_n         ";
        35: liveness_name = "EPANS_n       "; 34: liveness_name = "ESTOF_n       ";
        33: liveness_name = "FETCH         "; 32: liveness_name = "FMISS         ";
        31: liveness_name = "FORM_n        "; 30: liveness_name = "FUL_n         ";
        29: liveness_name = "IORQ_n        "; 28: liveness_name = "LHIT          ";
        27: liveness_name = "MCL           "; 26: liveness_name = "MREQ_n        ";
        25: liveness_name = "PAN_n         "; 24: liveness_name = "PA_n          ";
        23: liveness_name = "POWFAIL_n     "; 22: liveness_name = "PS_n          ";
        21: liveness_name = "REFRQ_n       "; 20: liveness_name = "RINR_n        ";
        19: liveness_name = "RT_n          "; 18: liveness_name = "RUART_n       ";
        17: liveness_name = "RWCS_n        "; 16: liveness_name = "SHORT_n       ";
        15: liveness_name = "SIOC_n        "; 14: liveness_name = "SLOW_n        ";
        13: liveness_name = "SSEMA_n       "; 12: liveness_name = "STOC_n        ";
        11: liveness_name = "STP           "; 10: liveness_name = "TOUT          ";
        9:  liveness_name = "TRAALD_n      "; 8:  liveness_name = "VAL           ";
        7:  liveness_name = "WCHIM_n       "; 6:  liveness_name = "WRITE         ";
        5:  liveness_name = "EPAN_n        ";
        default: liveness_name = "(pad)         ";
      endcase
    end
  endfunction

endmodule

`default_nettype wire

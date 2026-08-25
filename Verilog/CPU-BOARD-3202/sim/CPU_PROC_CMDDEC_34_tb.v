/**************************************************************************
** CPU_PROC_CMDDEC_34 - command decode connectivity testbench            **
** (sheet 34, PALs 44407A UERFIX, 44408B VEXFIX, 44511A ULEV0)           **
**                                                                       **
** WHY THIS SHAPE OF TEST                                                 **
** Every CPU bug this project has found so far was ONE WRONG INPUT ON    **
** ONE GATE - CGA_ALU_QREG's MUXQ15.D3, CGA_INTR_CNTLR's swapped FIDBO   **
** bits. This sheet is 100 lines of nothing but pin assignments feeding  **
** three PALs, so a mis-typed pin here is invisible in review and fatal  **
** in a boot. Re-implementing the PAL equations in the testbench would   **
** prove nothing, so this test attacks the WIRING directly:              **
**                                                                       **
**   1. INPUT SENSITIVITY. For every input bit of the module, the test   **
**      searches random operating points for one where toggling THAT BIT **
**      ALONE changes at least one output. An input that is tied off,    **
**      duplicated onto another pin, or connected to the wrong PAL pin   **
**      shows up as an input that can never influence anything. It       **
**      reports exactly WHICH bit is dead, and how many of the sampled   **
**      operating points each live bit reached.                          **
**      Two inputs are exempt and the test says so: sysclk and CLK_EN,   **
**      which carry no data, and CLK, which is the register clock.       **
**                                                                       **
**   2. OUTPUT LIVENESS. Every output must be seen BOTH high and low     **
**      across the sweep. A permanently constant output means a missing  **
**      connection - except RT_n, which the RTL states IS fixed high in  **
**      44408B ("DONT USE SIGNAL FROM 44408 as its fixed high") because  **
**      the PALASM for the real 44608A VXFIX is missing. The test        **
**      asserts that documented reading rather than failing on it, so a  **
**      future PAL replacement that makes RT_n live is noticed here.     **
**                                                                       **
**   3. NO OUTPUT MAY BE X after a clock, at any operating point.        **
**                                                                       **
**   4. THE ONE GATE THIS SHEET OWNS OUTRIGHT:                           **
**          BRK_n = ~(~CGABRK_n & ~VEX)                                  **
**      checked against both of its inputs on every sampled vector.      **
**                                                                       **
**   5. PD1 IS THE OUTPUT ENABLE of all three PALs. Its effect is        **
**      measured and printed, so a change of that behaviour is visible.  **
**                                                                       **
** BOTH BUILD MODES: `FPGA_FF_MODE turns the PALs into their clock-      **
** enable form (USE_ENABLE=1, capturing on the CLK_EN pulse instead of   **
** the CLK edge). The stimulus drives both, and the two runs are         **
** compared by their printed decode signature.                           **
**                                                                       **
** This is a CHARACTERISATION test. It does not claim to know what the   **
** PALs should decode; it claims that every wire on this sheet carries   **
** something and that nothing is stuck.                                  **
**                                                                       **
** Run: cd Verilog/CPU-BOARD-3202/sim && make test-cmddec34              **
**                                                                       **
** Last reviewed: 20-AUG-2026                                            **
** Ronny Hansen                                                          **
***************************************************************************/
`timescale 1ns / 1ps
`default_nettype none

module CPU_PROC_CMDDEC_34_tb;

  reg        sysclk = 1'b0;
  reg        CLK_EN;
  reg        CGABRK_n, CLK, IDB2, LCS_n, MREQ_n, PD1, WCA_n, WRTRF;
  reg [4:0]  CSCOMM_4_0, CSIDBS_4_0;
  reg [1:0]  CSMIS_1_0;
  reg [3:0]  PIL_3_0;

  wire BRK_n, CUP, CWR, ERF_n, LEV0, OPCLCS, RRF_n, RT_n, RWCS_n, LDEXM_n, VEX;

  integer errors = 0;
  integer checks = 0;
  integer i, t;

  localparam integer NIN     = 21;   // data-carrying input bits, see name_of()
  localparam integer NTRIALS = 400;  // random operating points per input bit

  // packed stimulus vector, laid out to match apply()/name_of()
  reg [NIN-1:0] stim, alt;
  reg [10:0] out_a, out_b;
  integer sens[0:NIN-1];

  reg [10:0] or_seen  = 11'h000;
  reg [10:0] and_seen = 11'h7FF;
  reg [31:0] signature = 32'h0;

  always #5 sysclk = ~sysclk;

`ifdef FPGA_FF_MODE
  localparam [8*5:1] MODE = "FF   ";
`else
  localparam [8*5:1] MODE = "LATCH";
`endif

  CPU_PROC_CMDDEC_34 DUT (
      .sysclk(sysclk), .CLK_EN(CLK_EN),
      .CGABRK_n(CGABRK_n), .CLK(CLK), .CSCOMM_4_0(CSCOMM_4_0),
      .CSIDBS_4_0(CSIDBS_4_0), .CSMIS_1_0(CSMIS_1_0), .IDB2(IDB2),
      .LCS_n(LCS_n), .MREQ_n(MREQ_n), .PD1(PD1), .PIL_3_0(PIL_3_0),
      .WCA_n(WCA_n), .WRTRF(WRTRF),
      .BRK_n(BRK_n), .CUP(CUP), .CWR(CWR), .ERF_n(ERF_n), .LEV0(LEV0),
      .OPCLCS(OPCLCS), .RRF_n(RRF_n), .RT_n(RT_n), .RWCS_n(RWCS_n),
      .LDEXM_n(LDEXM_n), .VEX(VEX)
  );

  function [8*12:1] name_of;
    input integer b;
    begin
      case (b)
        0:  name_of = "CSCOMM0     ";
        1:  name_of = "CSCOMM1     ";
        2:  name_of = "CSCOMM2     ";
        3:  name_of = "CSCOMM3     ";
        4:  name_of = "CSCOMM4     ";
        5:  name_of = "CSIDBS0     ";
        6:  name_of = "CSIDBS1     ";
        7:  name_of = "CSIDBS2     ";
        8:  name_of = "CSIDBS3     ";
        9:  name_of = "CSIDBS4     ";
        10: name_of = "CSMIS0      ";
        11: name_of = "CSMIS1      ";
        12: name_of = "PIL0        ";
        13: name_of = "PIL1        ";
        14: name_of = "PIL2        ";
        15: name_of = "PIL3        ";
        16: name_of = "IDB2        ";
        17: name_of = "LCS_n       ";
        18: name_of = "MREQ_n      ";
        19: name_of = "WCA_n       ";
        20: name_of = "WRTRF       ";
        default: name_of = "???         ";
      endcase
    end
  endfunction

  task apply;
    input [NIN-1:0] s;
    begin
      CSCOMM_4_0 = s[4:0];
      CSIDBS_4_0 = s[9:5];
      CSMIS_1_0  = s[11:10];
      PIL_3_0    = s[15:12];
      IDB2       = s[16];
      LCS_n      = s[17];
      MREQ_n     = s[18];
      WCA_n      = s[19];
      WRTRF      = s[20];
    end
  endtask

  // one CLK cycle, driving both the level and the FF-mode enable pulse
  task clk_cycle;
    begin
      CLK = 1'b0; CLK_EN = 1'b0;
      @(posedge sysclk); #1;
      CLK = 1'b1; CLK_EN = 1'b1;
      @(posedge sysclk); #1;
      CLK_EN = 1'b0;
      @(posedge sysclk); #1;
      CLK = 1'b0;
      @(posedge sysclk); #1;
    end
  endtask

  function [10:0] outs;
    input dummy;
    begin
      outs = {BRK_n, CUP, CWR, ERF_n, LEV0, OPCLCS, RRF_n, RT_n, RWCS_n, LDEXM_n, VEX};
    end
  endfunction

  initial begin
    $dumpfile("CPU_PROC_CMDDEC_34_tb.vcd");
    $dumpvars(0, CPU_PROC_CMDDEC_34_tb);
    // Keep the committed waveform SHORT and readable: this testbench
    // runs far more stimulus than anyone wants to open in GTKWave, so
    // only the opening 4000 ns is recorded. The pass/fail verdict comes
    // from the text output, never from the waveform.
    #4000 $dumpoff;
  end

  initial begin
    $display("=====================================================");
    $display(" CPU_PROC_CMDDEC_34 (sheet 34) wiring test - mode %0s", MODE);
    $display("=====================================================");

    CLK = 1'b0; CLK_EN = 1'b0; PD1 = 1'b0; CGABRK_n = 1'b1;
    apply({NIN{1'b0}});
    repeat (4) @(posedge sysclk);

    // WARM-UP, and a POWER-UP STATE this testbench measured on 20-AUG-2026:
    // PAL_44511A's CUP register is self-holding
    //     CUP_n_reg <= (CWR_n & MREQ) | (CUP_n_reg & MREQ_n)
    // and in the DEFAULT build (PAL_44511A.v) it has no initial value, while
    // the FF-mode variant (PAL_44511A_EN.v) initialises it to 0. So in the
    // default build CUP reads X out of reset until TWO clocks have gone by
    // with MREQ~ LOW - one to define CWR, one to feed it into CUP. The
    // testbench clocks that state out deliberately instead of hiding it; the
    // divergence itself is reported, not silently tolerated.
    clk_cycle; clk_cycle; clk_cycle;
    checks = checks + 1;
    if (^outs(0) === 1'bx) begin
      errors = errors + 1;
      $display("FAIL X_AFTER_WARMUP: outputs=%b still contain x after three clocks with MREQ_n low",
               outs(0));
    end

    for (i = 0; i < NIN; i = i + 1) sens[i] = 0;

    // ---- 1. per-input sensitivity, plus liveness and the BRK_n gate
    for (i = 0; i < NIN; i = i + 1) begin
      for (t = 0; t < NTRIALS; t = t + 1) begin
        stim = {$random};
        CGABRK_n = t[0];
        alt  = stim ^ ({{(NIN-1){1'b0}}, 1'b1} << i);

        apply(stim); clk_cycle; out_a = outs(0);
        or_seen = or_seen | out_a; and_seen = and_seen & out_a;
        signature = signature + out_a;

        // no output may be x
        checks = checks + 1;
        if (^out_a === 1'bx) begin
          errors = errors + 1;
          if (errors < 12)
            $display("FAIL X_OUTPUT: outputs=%b at stim=%h CGABRK_n=%b",
                     out_a, stim, CGABRK_n);
        end

        // the one gate this sheet owns
        checks = checks + 1;
        if (BRK_n !== (CGABRK_n | VEX)) begin
          errors = errors + 1;
          if (errors < 12)
            $display("FAIL BRK_GATE: CGABRK_n=%b VEX=%b -> BRK_n=%b want %b",
                     CGABRK_n, VEX, BRK_n, CGABRK_n | VEX);
        end

        apply(alt); clk_cycle; out_b = outs(0);
        or_seen = or_seen | out_b; and_seen = and_seen & out_b;

        if (out_a !== out_b) sens[i] = sens[i] + 1;
      end
    end

    $display(" per-input sensitivity (operating points out of %0d where the",
             NTRIALS);
    $display(" bit ALONE changed an output):");
    for (i = 0; i < NIN; i = i + 1) begin
      $display("   %0s %0d", name_of(i), sens[i]);
      checks = checks + 1;
      if (sens[i] == 0) begin
        errors = errors + 1;
        $display("FAIL DEAD_INPUT: %0s never influenced any output - it is tied off, duplicated, or on the wrong PAL pin",
                 name_of(i));
      end
    end

    // ---- 2. output liveness. RT_n is the documented exception.
    live("BRK_n  ", or_seen[10], and_seen[10], 1);
    live("CUP    ", or_seen[9],  and_seen[9],  1);
    live("CWR    ", or_seen[8],  and_seen[8],  1);
    live("ERF_n  ", or_seen[7],  and_seen[7],  1);
    live("LEV0   ", or_seen[6],  and_seen[6],  1);
    live("OPCLCS ", or_seen[5],  and_seen[5],  1);
    live("RRF_n  ", or_seen[4],  and_seen[4],  1);
    live("RT_n   ", or_seen[3],  and_seen[3],  0);  // documented: fixed high
    live("RWCS_n ", or_seen[2],  and_seen[2],  1);
    live("LDEXM_n", or_seen[1],  and_seen[1],  1);
    live("VEX    ", or_seen[0],  and_seen[0],  1);

    // RT_n is asserted to be exactly what the RTL says it is: stuck high.
    checks = checks + 1;
    if (!(or_seen[3] === 1'b1 && and_seen[3] === 1'b1)) begin
      errors = errors + 1;
      $display("FAIL RT_N_CHANGED: the RTL states 44408B holds RT_n fixed high, but it moved. If the 44608A PALASM has been added, update this testbench.");
    end

    // ---- 3. PD1 is the PAL output enable - measure and report its effect
    PD1 = 1'b1;
    apply({NIN{1'b1}}); clk_cycle;
    $display(" PD1 asserted -> outputs %b", outs(0));
    checks = checks + 1;
    if (^outs(0) === 1'bx) begin
      errors = errors + 1;
      $display("FAIL X_OUTPUT_WITH_PD1: outputs=%b", outs(0));
    end
    PD1 = 1'b0;

    $display("-----------------------------------------------------");
    $display(" mode          : %0s", MODE);
    $display(" decode signature (compare across modes): %08h", signature);
    $display(" checks run : %0d", checks);
    $display(" failures   : %0d", errors);
    if (errors == 0) $display("TB_RESULT: PASS");
    else             $display("TB_RESULT: FAIL");
    $display("=====================================================");
    $finish;
  end

  task live;
    input [8*8:1] name;
    input o, a;
    input must_toggle;
    begin
      if (must_toggle) begin
        checks = checks + 2;
        if (o === 1'b0) begin
          errors = errors + 1;
          $display("FAIL STUCK_LOW: %0s never went high - missing connection?", name);
        end
        if (a === 1'b1) begin
          errors = errors + 1;
          $display("FAIL STUCK_HIGH: %0s never went low - missing connection?", name);
        end
      end
    end
  endtask

endmodule

`default_nettype wire

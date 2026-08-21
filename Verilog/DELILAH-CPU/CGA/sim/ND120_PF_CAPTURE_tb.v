/*****************************************************************************
** ND120_PF_CAPTURE - does it freeze the RIGHT cycle, and does it LOCK?     **
**                                                                          **
** WHY THIS BENCH IS NOT OPTIONAL                                           **
**   The capture block exists to settle an argument about a page fault on    **
**   silicon. If it froze the wrong cycle it would not fail loudly - it      **
**   would produce a plausible word and send the investigation somewhere     **
**   wrong, with the authority of "measured on hardware". So the block is    **
**   worthless until this bench proves it lands on the intended edge.        **
**                                                                          **
** THE HAZARD BEING TESTED                                                  **
**   TVEC_3_0 is REGISTERED on TCLK. The inputs that caused a page fault     **
**   have already changed by the time TVEC shows it. A naive capture would   **
**   sample the inputs when it SEES the fault and record the following       **
**   cycle's data. This bench deliberately changes the inputs immediately    **
**   after the faulting edge, so a wrong-cycle capture cannot pass.          **
**                                                                          **
** WHAT IS CHECKED                                                          **
**   1  RIGHT CYCLE   - the frozen word is the input set at the faulting     **
**                      edge, NOT the set present when TVEC was observed     **
**   2  LOCK          - a second, different page fault must NOT overwrite it **
**   3  NEGATIVE      - no page fault -> nothing captured, captured stays 0  **
**   4  CLEAR         - clear releases the lock and a new fault is captured  **
**   5  FIRST EDGE    - a fault before any capturing edge must not freeze    **
**                      an undefined snapshot                                **
**   6  STROBE HONESTY- ptram_strobes_valid reports whether the two RAM bits **
**                      mean anything, so an unrouted 0 cannot be misread    **
**                      as "the RAM was not driving"                         **
**                                                                          **
** Runs in BOTH build modes; the capturing edge differs but the answers must **
** not. Run: cd Verilog/DELILAH-CPU/CGA/sim && make iv-ND120_PF_CAPTURE      **
**                                                                          **
** 21-AUG-2026                                                              **
** Ronny Hansen                                                             **
*****************************************************************************/
`timescale 1ns / 1ps
`default_nettype none

module ND120_PF_CAPTURE_tb;

  localparam integer CNTW = 24;
  localparam [3:0] PF_VEC = 4'd1;
  localparam [3:0] NO_VEC = 4'd0;

  reg sysclk = 1'b0;
  always #1 sysclk = ~sysclk;  // 2 ns period

  reg        clear = 1'b0;   // check 11 tests POWER-UP state, so no clear yet
  reg        tclk = 1'b0;
  reg        tclk_en = 1'b0;
  reg  [6:0] pt = 7'b1110000;      // granting PTE by default
  reg        vacc = 1'b0;
  reg [13:0] la = 14'h0000;
  reg  [3:0] tvec = NO_VEC;
  reg        pviol = 1'b0;
  reg        restr = 1'b0;
  reg        cs_n = 1'b1;
  reg        oe_n = 1'b1;
  reg        epgs = 1'b0;

  wire        captured;
  wire  [6:0] c_pt;
  wire        c_vacc;
  wire [13:0] c_la;
  wire  [3:0] c_tvec;
  wire        c_pviol, c_restr, c_cs_n, c_oe_n;
  wire [CNTW-1:0] c_cycle;
  wire        strobes_valid;
  wire [15:0] readout;
  wire  [6:0] c_pt_prev, c_pt_next;
  wire  [7:0] n_faults;
  wire [13:0] c_pgs_at_read;
  wire        c_pgs_valid;
  wire [13:0] last_la;
  wire        c_next_valid;

  ND120_PF_CAPTURE #(
      .CNTW(CNTW),
      .PF_VECTOR(1),
      .ROT_LOG2(3),              // rotate fast so the bench can collect all slices
      .ARM_LOG2(4),              // short arm window; check 10 proves it is honoured
      .CENSUS_LOG2(24),          // far away: check 13 tests rotation BEFORE any release
      .MATCH_ANY(1),             // most checks drive arbitrary LA; check 14 tests the filter
      .MATCH_PAGE_ONLY(0),
      .HAS_PTRAM_STROBES(0)      // deliberately 0: check 6 depends on it
  ) DUT (
      .sysclk(sysclk), .clear(clear),
      .tclk(tclk), .tclk_en(tclk_en),
      .pt_15_9(pt), .vacc(vacc), .la_23_10(la),
      .tvec_3_0(tvec), .pviol(pviol), .restr(restr),
      .ptram_cs_n(cs_n), .ptram_oe_n(oe_n), .epgs(epgs),
      .captured(captured),
      .c_pt_15_9(c_pt), .c_vacc(c_vacc), .c_la_23_10(c_la),
      .c_tvec_3_0(c_tvec), .c_pviol(c_pviol), .c_restr(c_restr),
      .c_ptram_cs_n(c_cs_n), .c_ptram_oe_n(c_oe_n),
      .c_pt_prev(c_pt_prev),
      .c_pt_next(c_pt_next),
      .c_next_valid(c_next_valid),
      .n_faults(n_faults),
      .last_la(last_la),
      .c_pgs_at_read(c_pgs_at_read),
      .c_pgs_valid(c_pgs_valid),
      .c_cycle(c_cycle),
      .ptram_strobes_valid(strobes_valid),
      .readout_15_0(readout)
  );

  // second instance with the ADDRESS FILTER ON (the real hunt configuration)
  reg         f_clear = 1'b0, f_tclk = 1'b0, f_tclk_en = 1'b0, f_vacc = 1'b0;
  reg  [6:0]  f_pt = 7'b1110000;
  reg  [13:0] f_la = 14'd0;
  reg  [3:0]  f_tvec = 4'd0;
  wire        f_captured;
  wire [13:0] f_c_la;
  ND120_PF_CAPTURE #(
      .CNTW(CNTW), .PF_VECTOR(1), .ROT_LOG2(3), .ARM_LOG2(4), .CENSUS_LOG2(24),
      .MATCH_ANY(0), .MATCH_PAGE_ONLY(0), .MATCH_LA_19_10(10'o760)
  ) FILT (
      .sysclk(sysclk), .clear(f_clear), .tclk(f_tclk), .tclk_en(f_tclk_en),
      .pt_15_9(f_pt), .vacc(f_vacc), .la_23_10(f_la), .tvec_3_0(f_tvec),
      .pviol(1'b0), .restr(1'b0), .ptram_cs_n(1'b1), .ptram_oe_n(1'b1),
      .captured(f_captured), .c_pt_15_9(), .c_vacc(), .c_la_23_10(f_c_la),
      .c_tvec_3_0(), .c_pviol(), .c_restr(), .c_ptram_cs_n(), .c_ptram_oe_n(),
      .c_pt_prev(), .c_pt_next(), .c_next_valid(), .n_faults(), .last_la(),
      .c_pgs_at_read(), .c_pgs_valid(), .c_cycle(),
      .ptram_strobes_valid(), .readout_15_0()
  );

  integer errors = 0;
  integer checks = 0;
  integer quiet_fails = 0;

  // a cheap per-cycle assertion that does not print 600 lines
  task automatic chk_quiet;
    input cond;
    begin
      if (!cond) quiet_fails = quiet_fails + 1;
    end
  endtask
  integer i;
  reg [103:0] rebuilt;
  reg [7:0] seen_mask;

  task automatic chk;
    input        cond;
    input [639:0] what;   // wide enough that a failure message is never truncated
    begin
      checks = checks + 1;
      if (!cond) begin
        errors = errors + 1;
        $display("  FAIL: %0s", what);
      end
    end
  endtask

  // `clear` also resets the arm counter, so every clear must wait for the
  // block to re-arm before it can capture again. ARM_LOG2=4 here, so 2^4
  // sysclk plus margin.
  task automatic do_clear;
    begin
      clear = 1'b1;
      repeat (2) @(posedge sysclk);
      clear = 1'b0;
      repeat (40) @(posedge sysclk);
    end
  endtask

  // One capturing edge for the FILTERED instance, in whichever form this
  // build uses. Tying tclk_en to 0 made the FF-mode build unable to capture
  // at all, which looked like a filter bug and was not.
  task automatic f_capture_edge;
    begin
`ifdef FPGA_FF_MODE
      @(negedge sysclk); f_tclk_en = 1'b1;
      @(negedge sysclk); f_tclk_en = 1'b0;
`else
      @(negedge sysclk); f_tclk = 1'b0;
      @(negedge sysclk); f_tclk = 1'b1;
      @(negedge sysclk);
`endif
      repeat (3) @(posedge sysclk);
    end
  endtask

  // One capturing edge, however this build produces it.
  task automatic capture_edge;
    begin
`ifdef FPGA_FF_MODE
      @(negedge sysclk);
      tclk_en = 1'b1;
      @(negedge sysclk);
      tclk_en = 1'b0;
`else
      @(negedge sysclk);
      tclk = 1'b0;
      @(negedge sysclk);
      tclk = 1'b1;      // rising edge -> snapshot
      @(negedge sysclk);
`endif
      @(posedge sysclk);
      #0;
    end
  endtask

  initial begin
    $dumpfile("ND120_PF_CAPTURE_tb.vcd");
    $dumpvars(0, ND120_PF_CAPTURE_tb);

    $display("=====================================================");
    $display(" ND120_PF_CAPTURE - right cycle, and lock");
`ifdef FPGA_FF_MODE
    $display(" build: FPGA_FF_MODE");
`else
    $display(" build: default (latch model)");
`endif
    $display("=====================================================");

    // ---------------------------------------------------------------------
    // 11. POWER-UP STATE. `clear` is tied to 0 in the real design, so if any
    //     state register powers up undefined the block reports a frozen fault
    //     the instant the FPGA configures - and the top's dumper then takes
    //     the console TX pin permanently. Measured on silicon 21-AUG-2026.
    //     This check runs BEFORE any clear, deliberately.
    // ---------------------------------------------------------------------
    #1;
    chk(captured === 1'b0, "11 POWER-UP: captured is not 0 out of configuration");
    chk(c_next_valid === 1'b0, "11 POWER-UP: c_next_valid is not 0 out of configuration");
    chk(readout[15:13] === 3'd0, "11 POWER-UP: slice index is not 0 out of configuration");

    repeat (4) @(posedge sysclk);
    // A bare clear: do NOT wait for re-arm, because check 10 needs to run
    // INSIDE the arm window - that is the window that broke on silicon.
    clear = 1'b1;
    repeat (2) @(posedge sysclk);
    clear = 1'b0;
    repeat (2) @(posedge sysclk);

    // ---------------------------------------------------------------------
    // 10. ARMING - nothing may be frozen before the machine is running.
    //     Measured 21-AUG-2026: without arming the block froze during reset /
    //     the WCS load, the top's dumper triggered at power-up and latched the
    //     TX pin away from the console FOREVER, so the boot command could
    //     never be typed. This check runs FIRST, immediately after clear, so
    //     it exercises the window that actually broke.
    // ---------------------------------------------------------------------
    begin : arming
      pt = 7'b0000000; vacc = 1'b1;   // a page-fault-looking input set
      tvec = PF_VEC;
      capture_edge();
      capture_edge();
      chk(captured === 1'b0,
          "10 ARMING: froze a fault before the arm window expired");
      tvec = NO_VEC;
      do_clear();      // start check 5 from a clean, re-armed state
    end

    // ---------------------------------------------------------------------
    // 5. FIRST EDGE: a page fault before ANY capturing edge must not freeze
    //    an undefined snapshot.
    // ---------------------------------------------------------------------
    tvec = PF_VEC;
    repeat (4) @(posedge sysclk);
    chk(captured === 1'b0, "5 FIRST EDGE: captured before any capturing edge");
    tvec = NO_VEC;
    repeat (2) @(posedge sysclk);

    // ---------------------------------------------------------------------
    // 1. RIGHT CYCLE.
    //    Present the FAULTING input set, take a capturing edge, then CHANGE
    //    every input before raising TVEC. A wrong-cycle capture records the
    //    second set and fails here.
    // ---------------------------------------------------------------------
    pt    = 7'b0000000;   // the interesting case: no permissions / idle bus
    vacc  = 1'b1;
    la    = 14'h1F60;
    pviol = 1'b1;
    restr = 1'b0;
    cs_n  = 1'b0;
    oe_n  = 1'b0;
    capture_edge();

    // now move EVERYTHING to a decoy set
    pt    = 7'b1110000;
    vacc  = 1'b0;
    la    = 14'h0123;
    pviol = 1'b0;
    restr = 1'b1;
    cs_n  = 1'b1;
    oe_n  = 1'b1;

    tvec = PF_VEC;                 // the trap becomes visible one edge later
    repeat (3) @(posedge sysclk);

    chk(captured === 1'b1, "1 RIGHT CYCLE: nothing captured at all");
    chk(c_pt === 7'b0000000, "1 RIGHT CYCLE: c_pt is the decoy, not the faulting value");
    chk(c_vacc === 1'b1, "1 RIGHT CYCLE: c_vacc is the decoy");
    chk(c_la === 14'h1F60, "1 RIGHT CYCLE: c_la is the decoy");
    chk(c_pviol === 1'b1, "1 RIGHT CYCLE: c_pviol is the decoy");
    chk(c_restr === 1'b0, "1 RIGHT CYCLE: c_restr is the decoy");
    chk(c_cs_n === 1'b0, "1 RIGHT CYCLE: c_ptram_cs_n is the decoy");
    chk(c_oe_n === 1'b0, "1 RIGHT CYCLE: c_ptram_oe_n is the decoy");
    chk(c_tvec === PF_VEC, "1 RIGHT CYCLE: c_tvec is not the page-fault vector");

    // ---------------------------------------------------------------------
    // 2. LOCK: a second, clearly different page fault must not overwrite it.
    // ---------------------------------------------------------------------
    tvec = NO_VEC;
    repeat (2) @(posedge sysclk);
    pt   = 7'b1010101;
    la   = 14'h2AAA;
    vacc = 1'b1;
    capture_edge();
    tvec = PF_VEC;
    repeat (3) @(posedge sysclk);

    chk(c_pt === 7'b0000000, "2 LOCK: the second fault overwrote c_pt");
    chk(c_la === 14'h1F60, "2 LOCK: the second fault overwrote c_la");

    // ---------------------------------------------------------------------
    // 4. CLEAR releases the lock and a new fault is captured.
    // ---------------------------------------------------------------------
    tvec = NO_VEC;
    @(posedge sysclk);
    do_clear();
    chk(captured === 1'b0, "4 CLEAR: captured did not reset");

    pt   = 7'b0110011;
    la   = 14'h0555;
    vacc = 1'b1;
    capture_edge();
    pt   = 7'b1111111;             // decoy again
    la   = 14'h3FFF;
    tvec = PF_VEC;
    repeat (3) @(posedge sysclk);
    chk(captured === 1'b1, "4 CLEAR: no capture after clear");
    chk(c_pt === 7'b0110011, "4 CLEAR: captured the decoy after clear");
    chk(c_la === 14'h0555, "4 CLEAR: captured the decoy LA after clear");

    // ---------------------------------------------------------------------
    // 3. NEGATIVE CONTROL: no page fault -> nothing captured.
    // ---------------------------------------------------------------------
    tvec = NO_VEC;
    @(posedge sysclk);
    do_clear();
    pt   = 7'b1110000;
    vacc = 1'b1;
    repeat (3) capture_edge();
    tvec = 4'd2;                   // a DIFFERENT trap vector, not a page fault
    repeat (4) @(posedge sysclk);
    chk(captured === 1'b0, "3 NEGATIVE: captured with no page-fault vector");

    // ---------------------------------------------------------------------
    // 7. READOUT FIDELITY.
    //    The evidence leaves the chip through a 16-bit port as four 14-bit
    //    slices. A slice bug would corrupt the answer AFTER it was correctly
    //    captured - the worst kind, because the capture bench would still
    //    pass. Collect every slice and rebuild the word.
    // ---------------------------------------------------------------------
    tvec = NO_VEC;
    @(posedge sysclk);
    do_clear();
    pt = 7'b1010011; vacc = 1'b1; la = 14'h2C7D; pviol = 1'b1; restr = 1'b1;
    cs_n = 1'b0; oe_n = 1'b1;
    capture_edge();
    pt = 7'b0001100; la = 14'h0000;          // decoy
    tvec = PF_VEC;
    repeat (3) @(posedge sysclk);

    seen_mask = 8'b00000000;
    for (i = 0; i < 6000; i = i + 1) begin
      @(posedge sysclk);
      case (readout[15:13])
        3'd0: begin rebuilt[12:0]   = readout[12:0]; seen_mask[0] = 1'b1; end
        3'd1: begin rebuilt[25:13]  = readout[12:0]; seen_mask[1] = 1'b1; end
        3'd2: begin rebuilt[38:26]  = readout[12:0]; seen_mask[2] = 1'b1; end
        3'd3: begin rebuilt[51:39]  = readout[12:0]; seen_mask[3] = 1'b1; end
        3'd4: begin rebuilt[64:52]  = readout[12:0]; seen_mask[4] = 1'b1; end
        3'd5: begin rebuilt[77:65]  = readout[12:0]; seen_mask[5] = 1'b1; end
        3'd6: begin rebuilt[90:78]  = readout[12:0]; seen_mask[6] = 1'b1; end
        3'd7: begin rebuilt[103:91] = readout[12:0]; seen_mask[7] = 1'b1; end
      endcase
    end
    chk(seen_mask === 8'b11111111, "7 READOUT: not all eight slices were emitted");
    chk(rebuilt[6:0]   === 7'b1010011,  "7 READOUT: PT does not survive the slicing");
    chk(rebuilt[7]     === 1'b1,        "7 READOUT: VACC does not survive the slicing");
    chk(rebuilt[21:8]  === 14'h2C7D,    "7 READOUT: LA does not survive the slicing");
    chk(rebuilt[25:22] === PF_VEC,      "7 READOUT: TVEC does not survive the slicing");
    chk(rebuilt[26]    === 1'b1,        "7 READOUT: PVIOL does not survive the slicing");
    chk(rebuilt[27]    === 1'b1,        "7 READOUT: RESTR does not survive the slicing");
    chk(rebuilt[28]    === 1'b0,        "7 READOUT: ptram CS_n does not survive the slicing");
    chk(rebuilt[29]    === 1'b1,        "7 READOUT: ptram OE_n does not survive the slicing");
    chk(rebuilt[30]    === 1'b1,        "7 READOUT: captured flag does not survive the slicing");
    chk(rebuilt[31]    === 1'b0,        "7 READOUT: strobes_valid does not survive the slicing");

    // ---------------------------------------------------------------------
    // 8. THE DISCRIMINATOR - PT before / at / after the faulting edge.
    //    This is the check the whole experiment rests on. If PT was zero when
    //    the fault latched but is NON-ZERO one edge later, the page-table
    //    entry merely ARRIVED LATE and the fault was spurious. If it is still
    //    zero, the entry really is unmapped. A broken c_pt_next would make
    //    those two indistinguishable while still looking like a clean result.
    // ---------------------------------------------------------------------
    tvec = NO_VEC;
    @(posedge sysclk);
    do_clear();

    pt = 7'b1010101; vacc = 1'b1;      // the edge BEFORE the fault
    capture_edge();
    pt = 7'b0000000;                   // the faulting edge: PT idle/no permits
    capture_edge();
    tvec = PF_VEC;
    repeat (3) @(posedge sysclk);
    chk(captured === 1'b1,          "8 DISCRIM: no capture");
    chk(c_pt === 7'b0000000,        "8 DISCRIM: the faulting PT is wrong");
    chk(c_pt_prev === 7'b1010101,   "8 DISCRIM: c_pt_prev is not the previous edge");
    chk(c_next_valid === 1'b0,      "8 DISCRIM: c_pt_next was taken before any later edge");

    pt = 7'b1110000;                   // the PTE arrives, one edge late
    capture_edge();
    repeat (2) @(posedge sysclk);
    chk(c_next_valid === 1'b1,      "8 DISCRIM: c_pt_next never became valid");
    chk(c_pt_next === 7'b1110000,   "8 DISCRIM: c_pt_next did not record the late PTE");

    pt = 7'b0001111;                   // a further edge must NOT overwrite it
    capture_edge();
    repeat (2) @(posedge sysclk);
    chk(c_pt_next === 7'b1110000,   "8 DISCRIM: a later edge overwrote c_pt_next");

    // ---------------------------------------------------------------------
    // 9. THE TRIGGER CONTRACT - locks the coupling that broke twice.
    //    ND120_TANG20K_TOP triggers its dump on the `captured` flag seen in
    //    the ROTATING readout, so it must know which slice carries it and at
    //    which payload bit. frozen[30] with 13-bit slices means SLICE 2,
    //    PAYLOAD BIT 4. If the word layout ever moves and this check is not
    //    updated, the board triggers at power-up and the dumper takes the TX
    //    pin before the console can be used - measured 21-AUG-2026, twice.
    // ---------------------------------------------------------------------
    begin : trigger_contract
      integer guard;
      reg found;
      found = 1'b0;
      // DUT is already captured from check 8, so the flag must be visible.
      for (guard = 0; guard < 4000 && !found; guard = guard + 1) begin
        @(posedge sysclk);
        if (readout[15:13] == 3'd2) begin
          found = 1'b1;
          chk(readout[4] === 1'b1,
              "9 TRIGGER: captured flag is NOT at slice 2 payload bit 4 - ND120_TANG20K_TOP will mis-trigger");
        end
      end
      chk(found === 1'b1, "9 TRIGGER: slice 2 never appeared in the readout");
    end

    // ---------------------------------------------------------------------
    // 12. STALE LEVEL - the bug silicon found that this bench did not.
    //     TVEC is registered and HOLDS between edges. If the arm window
    //     expires while TVEC is ALREADY sitting at the page-fault value from
    //     an earlier fault, a level trigger freezes an unrelated later
    //     snapshot. Measured 21-AUG-2026: the captured word said PVIOL=1 with
    //     VACC=0, which is physically impossible, and that is how it showed.
    //     Only a fresh 0->1 transition may capture.
    // ---------------------------------------------------------------------
    begin : stale_level
      clear = 1'b1; repeat (2) @(posedge sysclk); clear = 1'b0;
      // TVEC sits at the fault value for the WHOLE arm window
      tvec  = PF_VEC;
      pt    = 7'b1110000;   // granting - an unrelated, healthy cycle
      vacc  = 1'b0;
      repeat (60) @(posedge sysclk);   // arm expires with TVEC already high
      capture_edge();
      capture_edge();
      repeat (4) @(posedge sysclk);
      chk(captured === 1'b0,
          "12 STALE LEVEL: froze on a HELD page-fault vector instead of a fresh transition");

      // now a genuine transition: drop and re-raise
      tvec = NO_VEC;
      repeat (4) @(posedge sysclk);
      pt   = 7'b0000000;
      vacc = 1'b1;
      capture_edge();
      tvec = PF_VEC;
      repeat (4) @(posedge sysclk);
      chk(captured === 1'b1, "12 STALE LEVEL: a fresh transition was NOT captured");
      chk(c_vacc === 1'b1,   "12 STALE LEVEL: captured the wrong cycle's VACC");
    end

    // ---------------------------------------------------------------------
    // 13. READOUT MUST NOT ROTATE BEFORE A CAPTURE.
    //     The board samples the rotating window over time. If it rotates
    //     before the freeze, the ring blends pre- and post-capture slices and
    //     the reconstructed word describes no real state. Measured on silicon
    //     21-AUG-2026: a dump decoded to captured=0 AND c_next_valid=1.
    // ---------------------------------------------------------------------
    begin : no_rotate_before_capture
      integer k;
      clear = 1'b1; repeat (2) @(posedge sysclk); clear = 1'b0;
      tvec = NO_VEC; pt = 7'b1110000; vacc = 1'b0;
      for (k = 0; k < 600; k = k + 1) begin
        @(posedge sysclk);
        chk_quiet(readout[15:13] === 3'd0);
      end
      chk(quiet_fails === 0,
          "13 ROTATION: the readout rotated before anything was captured");
    end

    // ---------------------------------------------------------------------
    // 14. ADDRESS FILTER - only the targeted page may be frozen.
    //     During a boot the FIRST page fault is a ROUTINE one (measured on
    //     silicon 21-AUG-2026: page table 10, page 14 - serviced normally).
    //     The fault that halts SINTRAN is the ND-500 window, PNUMB = 0o760.
    //     Capturing the first fault therefore captures the wrong event.
    //     A separate instance with the filter ON is checked here.
    // ---------------------------------------------------------------------
    begin : addr_filter
      f_clear = 1'b1; repeat (2) @(posedge sysclk); f_clear = 1'b0;
      repeat (40) @(posedge sysclk);

      // a fault at the WRONG page must be ignored
      f_pt = 7'b0000000; f_vacc = 1'b1; f_la = 14'o0014;
      f_tvec = NO_VEC; repeat (4) @(posedge sysclk);
      // Switch TCLK on the NEGEDGE. Changing it on posedge races the
      // sampling always-block and the snapshot silently never happens -
      // pre_valid stays 0 and nothing can ever be captured.
      f_capture_edge();
      f_tvec = PF_VEC; repeat (6) @(posedge sysclk);
      chk(f_captured === 1'b0, "14 FILTER: froze a fault at a page other than the target");

      // a fault at the TARGET page must be frozen
      f_tvec = NO_VEC; repeat (4) @(posedge sysclk);
      f_la = 14'o0760;
      f_capture_edge();
      f_tvec = PF_VEC; repeat (6) @(posedge sysclk);
      chk(f_captured === 1'b1, "14 FILTER: did NOT freeze the fault at the target page");
      chk(f_c_la === 14'o0760, "14 FILTER: froze the wrong address");
    end

    // ---------------------------------------------------------------------
    // 15. PGS-AT-READ (Phase 4b) - the decisive pair.
    //     pgs_shadow follows the real PGS rule: load LA whenever VACC is high.
    //     After a fault is frozen, the FIRST EPGS must freeze whatever PGS
    //     holds AT THAT MOMENT. If a later VACC access changed it, the two
    //     addresses differ - and that difference IS the bug being hunted.
    // ---------------------------------------------------------------------
    begin : pgs_at_read
      do_clear();
      // the faulting access
      pt = 7'b0000000; vacc = 1'b1; la = 14'o1360; tvec = NO_VEC;
      capture_edge();
      tvec = PF_VEC; repeat (4) @(posedge sysclk);
      chk(captured === 1'b1, "15 PGS: the fault was not captured");
      chk(c_la === 14'o1360, "15 PGS: wrong faulting LA captured");
      chk(c_pgs_valid === 1'b0, "15 PGS: froze a PGS value before any EPGS");

      // a LATER translated access to a different address - this is the overwrite
      la = 14'o0760; vacc = 1'b1;
      repeat (4) @(posedge sysclk);

      // now the handler reads PGS
      epgs = 1'b1; repeat (3) @(posedge sysclk); epgs = 1'b0;
      repeat (2) @(posedge sysclk);
      chk(c_pgs_valid === 1'b1, "15 PGS: EPGS did not freeze a PGS value");
      chk(c_pgs_at_read === 14'o0760,
          "15 PGS: did not record the OVERWRITTEN value the handler would see");
      chk(c_pgs_at_read !== c_la,
          "15 PGS: overwrite not detectable - the two addresses match");
    end

    // ---------------------------------------------------------------------
    // 6. STROBE HONESTY.
    // ---------------------------------------------------------------------
    chk(strobes_valid === 1'b0,
        "6 STROBE: HAS_PTRAM_STROBES=0 but ptram_strobes_valid says the bits are real");

    $display("-----------------------------------------------------");
    $display(" checks run : %0d", checks);
    $display(" failures   : %0d", errors);
    if (errors == 0) begin
      $display(" The freeze register lands on the faulting edge and locks.");
      $display(" NOTE: this proves the CAPTURE is trustworthy. It says nothing");
      $display(" about why a page fault occurs - that is what the captured word");
      $display(" is for.");
      $display("TB_RESULT: PASS");
    end else begin
      $display(" DO NOT TRUST ANY CAPTURED WORD FROM THIS BLOCK until fixed.");
      $display("TB_RESULT: FAIL");
    end
    $display("=====================================================");
    $finish;
  end

endmodule

`default_nettype wire

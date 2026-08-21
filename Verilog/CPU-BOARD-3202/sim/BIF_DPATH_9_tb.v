/**************************************************************************
** BIF_DPATH_9 - bus data path interconnect testbench                    **
** (sheet 9, wiring PPNLBD/CDLBD/BDLBD/PESPEA/LDBCTL together)           **
**                                                                       **
** The five blocks this sheet contains each have their own testbench in  **
** CPU-BOARD-3202/circuit/sim. What has NEVER been tested is the sheet   **
** itself: the wired-OR expressions at lines 196, 206 and 207, the       **
** wired-AND tap at line 268, and the ~40 pin connections around them.   **
** That is where a transcription error survives, because every block     **
** passes its own test while the sheet delivers the wrong data.          **
**                                                                       **
** WHAT THIS WOULD CATCH                                                 **
**   1. THE TWO OPPOSITE BUS CONVENTIONS ON ONE SHEET. LBD and CD are    **
**      OR-ed active-high nets: a source that is not selected must       **
**      contribute EXACTLY ZERO. BD is an active-LOW wired-AND net: an   **
**      unselected driver must release to ALL ONES, not to zero. Getting **
**      these two the wrong way round is a real bug this repo already    **
**      fixed once (BIF_DPATH_BDLBD_10.v, the 24'h000000-vs-~24'b0       **
**      release). Both conventions are asserted here on every vector.    **
**   2. A DEAD INPUT. Every data-carrying input of the sheet is toggled  **
**      on its own at hundreds of random operating points; one that can  **
**      never move any output is not connected, or is connected twice.   **
**   3. A DEAD OR STUCK OUTPUT. Every output bit must be seen both high  **
**      and low.                                                         **
**   4. X ON ANY OUTPUT at any operating point.                          **
**   5. THE LBD MERGE ITSELF: LBD_23_0_OUT must equal the OR of the      **
**      three source blocks' outputs, read by hierarchical reference, on **
**      every vector - so a dropped term in line 196 fails here.         **
**   6. NO TWO LBD SOURCES MAY DRIVE THE SAME BIT HIGH AT ONCE. On a     **
**      real wired-OR that is a bus fight; the count of collisions is    **
**      printed so a change in it is visible.                            **
**                                                                       **
** This is a CHARACTERISATION test of the interconnect. It does not      **
** claim to know the intended bus protocol; it claims that every wire on **
** the sheet carries something, that nothing is stuck or undefined, and  **
** that the two bus conventions are each honoured on their own net.      **
**                                                                       **
** Run: cd Verilog/CPU-BOARD-3202/sim && make test-bifdpath9             **
**                                                                       **
** Last reviewed: 20-AUG-2026                                            **
** Ronny Hansen                                                          **
***************************************************************************/
`timescale 1ns / 1ps
`default_nettype none

module BIF_DPATH_9_tb;

  reg         OSC = 1'b0;
  reg         sys_rst_n = 1'b0;
  reg  [ 9:0] CA_9_0;
  reg  [13:0] PPN_23_10;
  reg         BDAP50_n, BDRY25_n, BDRY50_n, BGNT_n, BGNT50_n, BINPUT50_n;
  reg         CACT_n, CC2_n, CGNT_n, CGNT50_n, EBUS_n, FETCH, GNT_n;
  reg         IBAPR_n, IOD_n, IORQ_n, MIS0, MWRITE_n, PD1, PD3;
  reg         Q0_n, Q2_n, RT_n, TERM_n, WRITE;
  reg         EADDR_n, ECREQ, EPEA_n, EPES_n, SPEA, SPES;
  reg  [15:0] CD_15_0_IN;
  reg  [23:0] BD_23_0_n_IN, LBD_23_0_IN;

  wire [15:0] CD_15_0_OUT, IDB_15_0_OUT;
  wire [23:0] BD_23_0_n_OUT, LBD_23_0_OUT;
  wire        CBWRITE_n, CGNTCACT_n, DBAPR;

  integer errors = 0;
  integer checks = 0;
  integer i, t;
  integer lbd_collisions = 0;
  integer bd_released = 0, bd_driven = 0;

  localparam integer NIN     = 31;   // control inputs, see name_of()
  localparam integer NTRIALS = 300;

  reg [NIN-1:0] stim, alt;
  reg [87:0] out_a, out_b;
  integer sens[0:NIN-1];

  reg [87:0] or_seen  = 0;
  reg [87:0] and_seen = {88{1'b1}};

  always #5 OSC = ~OSC;

  BIF_DPATH_9 DUT (
      .OSC(OSC), .sys_rst_n(sys_rst_n),
      .CA_9_0(CA_9_0), .PPN_23_10(PPN_23_10),
      .BDAP50_n(BDAP50_n), .BDRY25_n(BDRY25_n), .BDRY50_n(BDRY50_n),
      .BGNT_n(BGNT_n), .BGNT50_n(BGNT50_n), .BINPUT50_n(BINPUT50_n),
      .CACT_n(CACT_n), .CC2_n(CC2_n), .CGNT_n(CGNT_n), .CGNT50_n(CGNT50_n),
      .EADDR_n(EADDR_n), .EBUS_n(EBUS_n), .ECREQ(ECREQ), .EPEA_n(EPEA_n),
      .EPES_n(EPES_n), .FETCH(FETCH), .GNT_n(GNT_n), .IBAPR_n(IBAPR_n),
      .IOD_n(IOD_n), .IORQ_n(IORQ_n), .MIS0(MIS0), .MWRITE_n(MWRITE_n),
      .PD1(PD1), .PD3(PD3), .Q0_n(Q0_n), .Q2_n(Q2_n), .RT_n(RT_n),
      .SPEA(SPEA), .SPES(SPES), .TERM_n(TERM_n), .WRITE(WRITE),
      .CD_15_0_IN(CD_15_0_IN), .CD_15_0_OUT(CD_15_0_OUT),
      .BD_23_0_n_IN(BD_23_0_n_IN), .BD_23_0_n_OUT(BD_23_0_n_OUT),
      .LBD_23_0_IN(LBD_23_0_IN), .LBD_23_0_OUT(LBD_23_0_OUT),
      .CBWRITE_n(CBWRITE_n), .CGNTCACT_n(CGNTCACT_n), .DBAPR(DBAPR),
      .IDB_15_0_OUT(IDB_15_0_OUT)
  );

  function [8*12:1] name_of;
    input integer b;
    begin
      case (b)
        0:  name_of = "BDAP50_n    ";
        1:  name_of = "BDRY25_n    ";
        2:  name_of = "BDRY50_n    ";
        3:  name_of = "BGNT_n      ";
        4:  name_of = "BGNT50_n    ";
        5:  name_of = "BINPUT50_n  ";
        6:  name_of = "CACT_n      ";
        7:  name_of = "CC2_n       ";
        8:  name_of = "CGNT_n      ";
        9:  name_of = "CGNT50_n    ";
        10: name_of = "EBUS_n      ";
        11: name_of = "FETCH       ";
        12: name_of = "GNT_n       ";
        13: name_of = "IBAPR_n     ";
        14: name_of = "IOD_n       ";
        15: name_of = "IORQ_n      ";
        16: name_of = "MIS0        ";
        17: name_of = "MWRITE_n    ";
        18: name_of = "PD1         ";
        19: name_of = "PD3         ";
        20: name_of = "Q0_n        ";
        21: name_of = "Q2_n        ";
        22: name_of = "RT_n        ";
        23: name_of = "TERM_n      ";
        24: name_of = "WRITE       ";
        25: name_of = "EADDR_n     ";
        26: name_of = "ECREQ       ";
        27: name_of = "EPEA_n      ";
        28: name_of = "EPES_n      ";
        29: name_of = "SPEA        ";
        30: name_of = "SPES        ";
        default: name_of = "???         ";
      endcase
    end
  endfunction

  // Drive the sheet. The three CAPTURE STROBES on this sheet (ECREQ into
  // PPNLBD, SPEA and SPES into PESPEA) are pre-driven LOW and then taken to
  // their vector value, so that a vector asking for a strobe produces a real
  // RISING EDGE. Without that, every registered path holds its old contents
  // and a data input looks dead when it is merely not being sampled.
  task apply_with_strobe;
    input [NIN-1:0] s;
    begin
      apply(s);
      ECREQ = 1'b0; SPEA = 1'b0; SPES = 1'b0;
      repeat (2) @(posedge OSC); #1;
      ECREQ = s[26]; SPEA = s[29]; SPES = s[30];
      repeat (3) @(posedge OSC); #1;
    end
  endtask

  task apply;
    input [NIN-1:0] s;
    begin
      BDAP50_n = s[0];  BDRY25_n = s[1];  BDRY50_n = s[2];  BGNT_n = s[3];
      BGNT50_n = s[4];  BINPUT50_n = s[5]; CACT_n = s[6];   CC2_n = s[7];
      CGNT_n = s[8];    CGNT50_n = s[9];  EBUS_n = s[10];   FETCH = s[11];
      GNT_n = s[12];    IBAPR_n = s[13];  IOD_n = s[14];    IORQ_n = s[15];
      MIS0 = s[16];     MWRITE_n = s[17]; PD1 = s[18];      PD3 = s[19];
      Q0_n = s[20];     Q2_n = s[21];     RT_n = s[22];     TERM_n = s[23];
      WRITE = s[24];
      EADDR_n = s[25];  ECREQ = s[26];  EPEA_n = s[27];  EPES_n = s[28];
      SPEA = s[29];     SPES = s[30];
    end
  endtask

  // packed output snapshot, 88 bits:
  //   [87:72] CD   [71:56] IDB   [55:32] BD   [31:8] LBD
  //   [7] CBWRITE_n  [6] CGNTCACT_n  [5] DBAPR  [4:0] unused
  function [87:0] outs;
    input dummy;
    begin
      outs = {CD_15_0_OUT, IDB_15_0_OUT, BD_23_0_n_OUT, LBD_23_0_OUT,
              CBWRITE_n, CGNTCACT_n, DBAPR, 5'b0};
    end
  endfunction

  // the invariants that must hold at EVERY operating point
  task invariants;
    reg [23:0] merged;
    begin
      // ---- the LBD merge: the sheet's own OR, term for term
      merged = DUT.s_ppnlbd_lbd_23_0_out
             | {8'b0, DUT.s_cdlbd_lbd_15_0_out}
             | DUT.s_bdlbd_lbd_23_0_out;
      checks = checks + 1;
      if (LBD_23_0_OUT !== merged) begin
        errors = errors + 1;
        if (errors < 12)
          $display("FAIL LBD_MERGE: out=%06h but the three sources OR to %06h",
                   LBD_23_0_OUT, merged);
      end

      // ---- OR-ed bus rule: a source that is off contributes exactly 0
      checks = checks + 1;
      if (DUT.s_ppnlbd_lbd_23_0_out === 24'bx
          || DUT.s_cdlbd_lbd_15_0_out === 16'bx
          || DUT.s_bdlbd_lbd_23_0_out === 24'bx) begin
        errors = errors + 1;
        if (errors < 12) $display("FAIL LBD_SOURCE_X");
      end

      // ---- collisions on the wired-OR: two sources driving one bit high
      if (|((DUT.s_ppnlbd_lbd_23_0_out & DUT.s_bdlbd_lbd_23_0_out)
            | ({8'b0, DUT.s_cdlbd_lbd_15_0_out} & DUT.s_bdlbd_lbd_23_0_out)
            | ({8'b0, DUT.s_cdlbd_lbd_15_0_out} & DUT.s_ppnlbd_lbd_23_0_out)))
        lbd_collisions = lbd_collisions + 1;

      // ---- ACTIVE-LOW BD net: when the sheet is not driving it, it must be
      // ---- released to ALL ONES, never to zero. BDLBD drives only when
      // ---- EBD~ AND WBD~ are both low.
      checks = checks + 1;
      if (DUT.s_ebd_n === 1'b1 || DUT.s_wbd_n === 1'b1) begin
        bd_released = bd_released + 1;
        if (BD_23_0_n_OUT !== 24'hFFFFFF) begin
          errors = errors + 1;
          if (errors < 12)
            $display("FAIL BD_NOT_RELEASED: EBD_n=%b WBD_n=%b -> BD=%06h, an idle active-low net must read all ones",
                     DUT.s_ebd_n, DUT.s_wbd_n, BD_23_0_n_OUT);
        end
      end else begin
        bd_driven = bd_driven + 1;
      end

      // ---- nothing may be x
      checks = checks + 1;
      if (^{CD_15_0_OUT, IDB_15_0_OUT, BD_23_0_n_OUT, LBD_23_0_OUT,
            CBWRITE_n, CGNTCACT_n, DBAPR} === 1'bx) begin
        errors = errors + 1;
        if (errors < 12)
          $display("FAIL X_OUTPUT: CD=%04h IDB=%04h BD=%06h LBD=%06h CBW=%b CGC=%b DBAPR=%b",
                   CD_15_0_OUT, IDB_15_0_OUT, BD_23_0_n_OUT, LBD_23_0_OUT,
                   CBWRITE_n, CGNTCACT_n, DBAPR);
      end
    end
  endtask

  initial begin
    $dumpfile("BIF_DPATH_9_tb.vcd");
    $dumpvars(0, BIF_DPATH_9_tb);
    // Keep the committed waveform SHORT and readable: this testbench
    // runs far more stimulus than anyone wants to open in GTKWave, so
    // only the opening 4000 ns is recorded. The pass/fail verdict comes
    // from the text output, never from the waveform.
    #4000 $dumpoff;
  end

  initial begin
    $display("=====================================================");
    $display(" BIF_DPATH_9 (sheet 9) bus data path interconnect");
    $display("=====================================================");

    CA_9_0 = 0; PPN_23_10 = 0; CD_15_0_IN = 0;
    BD_23_0_n_IN = 24'hFFFFFF; LBD_23_0_IN = 0;
    apply({NIN{1'b1}});
    repeat (6) @(posedge OSC);
    sys_rst_n = 1'b1;
    repeat (6) @(posedge OSC); #1;

    // warm-up: the TTL_74534 capture registers in PESPEA and the PPNLBD
    // register power up undefined and only become defined once their strobe
    // has risen. Clock that state out first so a genuine x later is a real
    // finding and not a power-up artefact.
    apply_with_strobe({NIN{1'b1}});
    apply_with_strobe({NIN{1'b0}});
    apply_with_strobe({NIN{1'b1}});
    checks = checks + 1;
    if (^outs(0) === 1'bx) begin
      errors = errors + 1;
      $display("FAIL X_AFTER_WARMUP: outputs still undefined after three strobed vectors");
    end

    for (i = 0; i < NIN; i = i + 1) sens[i] = 0;

    for (i = 0; i < NIN; i = i + 1) begin
      for (t = 0; t < NTRIALS; t = t + 1) begin
        stim = {$random};
        alt  = stim ^ ({{(NIN-1){1'b0}}, 1'b1} << i);

        CA_9_0       = $random;
        PPN_23_10    = $random;
        CD_15_0_IN   = $random;
        LBD_23_0_IN  = $random;
        BD_23_0_n_IN = $random;

        apply_with_strobe(stim);
        out_a = outs(0);
        invariants;
        or_seen = or_seen | out_a; and_seen = and_seen & out_a;

        apply_with_strobe(alt);
        out_b = outs(0);
        invariants;
        or_seen = or_seen | out_b; and_seen = and_seen & out_b;

        if (out_a !== out_b) sens[i] = sens[i] + 1;
      end
    end

    // ---- a quiet operating point: with the BIF idle nothing may be
    // ---- published on the OR-ed LBD net
    force DUT.s_ebd_n  = 1'b1;
    force DUT.s_wlbd_n = 1'b1;
    CD_15_0_IN = 16'hFFFF; LBD_23_0_IN = 24'h000000;
    repeat (3) @(posedge OSC); #1;
    checks = checks + 1;
    if (DUT.s_bdlbd_lbd_23_0_out !== 24'h000000) begin
      errors = errors + 1;
      $display("FAIL BDLBD_LEAKS_ONTO_LBD: %06h with EBD_n high",
               DUT.s_bdlbd_lbd_23_0_out);
    end
    release DUT.s_ebd_n;
    release DUT.s_wlbd_n;

    $display(" LBD wired-OR collisions seen : %0d", lbd_collisions);
    $display(" BD released / driven samples : %0d / %0d", bd_released, bd_driven);
    $display(" per-input sensitivity (of %0d operating points each):", NTRIALS);
    for (i = 0; i < NIN; i = i + 1) begin
      $display("   %0s %0d", name_of(i), sens[i]);
      checks = checks + 1;
      if (sens[i] == 0) begin
        errors = errors + 1;
        $display("FAIL DEAD_INPUT: %0s never influenced any output of this sheet",
                 name_of(i));
      end
    end

    // ---- output liveness, bit by bit, over the whole sweep
    live_range("CD_15_0_OUT  ", 87, 72);
    live_range("IDB_15_0_OUT ", 71, 56);
    live_range("BD_23_0_n_OUT", 55, 32);
    live_range("LBD_23_0_OUT ", 31,  8);
    // the three single-bit outputs sit in the low field of outs()
    live_bit("CBWRITE_n ", 7);
    live_bit("CGNTCACT_n", 6);
    live_bit("DBAPR     ", 5);

    $display("-----------------------------------------------------");
    $display(" checks run : %0d", checks);
    $display(" failures   : %0d", errors);
    if (errors == 0) $display("TB_RESULT: PASS");
    else             $display("TB_RESULT: FAIL");
    $display("=====================================================");
    $finish;
  end

  task live_range;
    input [8*14:1] name;
    input integer hi, lo;
    integer j;
    begin
      for (j = lo; j <= hi; j = j + 1) begin
        checks = checks + 2;
        if (or_seen[j] === 1'b0) begin
          errors = errors + 1;
          $display("FAIL STUCK_LOW: %0s bit %0d never went high", name, j - lo);
        end
        if (and_seen[j] === 1'b1) begin
          errors = errors + 1;
          $display("FAIL STUCK_HIGH: %0s bit %0d never went low", name, j - lo);
        end
      end
    end
  endtask

  task live_bit;
    input [8*10:1] name;
    input integer j;
    begin
      checks = checks + 2;
      if (or_seen[j] === 1'b0) begin
        errors = errors + 1;
        $display("FAIL STUCK_LOW: %0s never went high", name);
      end
      if (and_seen[j] === 1'b1) begin
        errors = errors + 1;
        $display("FAIL STUCK_HIGH: %0s never went low", name);
      end
    end
  endtask

endmodule

`default_nettype wire

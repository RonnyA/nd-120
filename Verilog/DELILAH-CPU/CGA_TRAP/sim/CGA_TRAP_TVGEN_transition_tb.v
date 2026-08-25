/***************************************************************************************************
** ND120 CGA - CGA_TRAP/TVGEN - TRANSITION (STALE-VECTOR) DETECTOR                                **
**                                                                                                **
** THE GAP THIS FILLS: CGA_TRAP_TVGEN_exhaustive_tb.v sweeps all 524288 STEADY input states and    **
** passes. Every trap-vector bug found on this sheet has instead lived in a TRANSITION - a trap     **
** condition that becomes true and is DISPATCHED before a TCLK edge has captured it:               **
**                                                                                                **
**   * Issue D (27-JUL-2026): on a PGU/WIP rising edge the registered l2v* still held the previous  **
**     "no level-2 condition" default {1,1,1} -> TVEC=0111=7, an unimplemented vector that          **
**     self-jumps and hangs.                                                                       **
**   * ERRFATAL (17-AUG-2026, measured on Tang): on a page fault the registered l1v* still held the **
**     previous PGF=0 -> TVEC=0011=3, dispatched as RING-DOWN. SINTRAN then reports IIC 3 and halts.**
**     Silicon record: TVEC=3 VACC=1 PGF=1 pt15_9=000.                                             **
**                                                                                                 **
** THE INVARIANT: the dispatched vector must always name a condition that is LIVE RIGHT NOW. A      **
** vector for a condition that is not currently true is a stale capture, and vector 7 is not a      **
** vector at all. The mux SELECT {LEV1,LEV2} is combinational, so the moment a condition arises the **
** slot is already selected - the DATA in that slot must agree, or the machine dispatches a lie.    **
**                                                                                                 **
** METHOD: every ORDERED PAIR of condition classes. Apply A, let TCLK capture it, then apply B and  **
** check the vector in that SAME cycle, before any TCLK edge - which is exactly when the hardware   **
** can dispatch, because TRAPN is combinational (CGA_TRAP_BRKDET.v has no clock port at all).       **
**                                                                                                 **
** MUX31LP: A=B=1 selects D2, i.e. behaves as select 10 - confirmed by Ronny 17-AUG-2026 and        **
** matching muxIn_3 = muxIn_2 in CGA_TRAP_TVGEN_P2.v:257-278. So when a page fault (LEV1) and a PGU **
** (LEV2) are live together - which an ALL-ZERO page-table entry always produces, since the PGU bit **
** is clear too - the level-1 slot wins and the required vector is 1.                               **
**                                                                                                 **
** EXPECTED AGAINST TODAY'S RTL: FAILURES. That is the point - this bench is the detector. It turns **
** PASS only when a transition into a trap condition dispatches that condition's own vector.        **
** Do NOT register it in tests/run_all_tests.sh until the vector timing is fixed.                   **
**                                                                                                 **
** Written: 17-AUG-2026                                                                            **
***************************************************************************************************/
`timescale 1ns / 1ps

module CGA_TRAP_TVGEN_transition_tb;

  reg TCLK = 0;
  reg sysclk = 0;
  always #1 sysclk = ~sysclk;
  reg TCLK_EN = 0;

  reg       vacc, ifetch, iind, iwrite, intrq, pan, poni;
  reg       dstop_n, ftrap_n, vtrap_n;
  reg [1:0] ipcr;
  reg [6:0] ipt;

  wire       PVIOL, RESTR;
  wire [3:0] TVEC_3_0;

  CGA_TRAP_TVGEN DUT (
      .sysclk(sysclk), .TCLK_EN(TCLK_EN),
      .DSTOPN(dstop_n), .FTRAPN(ftrap_n),
      .IFETCH(ifetch), .IFETCHN(~ifetch), .IIND(iind), .IINDN(~iind),
      .INTRQ(intrq), .IPCR_1_0(ipcr), .IPCR_1_0_N(~ipcr),
      .IPT_15_9(ipt), .IPT_15_9_N(~ipt), .IWRITE(iwrite), .IWRITEN(~iwrite),
      .PAN(pan), .PONI(poni), .TCLK(TCLK), .VACC(vacc), .VTRAPN(vtrap_n),
      .PVIOL(PVIOL), .RESTR(RESTR), .TVEC_3_0(TVEC_3_0)
  );

  // ---- condition classes: {vacc, ifetch, iwrite, iind, ipcr, ipt}, and the
  // vector the machine MUST dispatch while that class is live.
  // IPT_15_9 index 0 = PT bit 9 ... index 6 = PT bit 15:
  //   WPM=6 RPM=5 FPM=4 WIP=3 PGU=2 ring={1,0}
  localparam N = 7;
  reg [15:0] cls   [0:N-1];
  reg [3:0]  cls_v [0:N-1];
  reg [8*14-1:0] cls_name [0:N-1];

  task setup_classes;
    begin
      // idle: no access at all -> no trap
      cls[0]  = {1'b0,1'b0,1'b0,1'b0,2'b10,7'b1110110}; cls_v[0]=4'd15; cls_name[0]="idle        ";
      // mapped page, PGU+WIP already set -> nothing to trap on
      cls[1]  = {1'b1,1'b1,1'b0,1'b0,2'b10,7'b1111110}; cls_v[1]=4'd15; cls_name[1]="mapped,quiet";
      // mapped page, PGU bit clear -> PGU trap (vector 4)
      cls[2]  = {1'b1,1'b1,1'b0,1'b0,2'b10,7'b1110110}; cls_v[2]=4'd4;  cls_name[2]="PGU         ";
      // write to mapped page, WIP clear, PGU set -> WIP trap (vector 5)
      cls[3]  = {1'b1,1'b0,1'b1,1'b0,2'b10,7'b1110010}; cls_v[3]=4'd5;  cls_name[3]="WIP         ";
      // ALL-ZERO entry = page not present. PGF (LEV1) and PGU (LEV2) both live;
      // MUX31LP A=B=1 -> D2 -> level 1 wins -> vector 1. THIS IS THE ERRFATAL.
      cls[4]  = {1'b1,1'b1,1'b0,1'b0,2'b10,7'b0000000}; cls_v[4]=4'd1;  cls_name[4]="PAGE FAULT  ";
      // fetch into a lower-ring page, FPM set -> ring down (vector 3)
      cls[5]  = {1'b1,1'b1,1'b0,1'b0,2'b11,7'b1111100}; cls_v[5]=4'd3;  cls_name[5]="RING-DOWN   ";
      // write with WPM clear, not fetch/ind -> write protect violation (vector 2)
      cls[6]  = {1'b1,1'b0,1'b1,1'b0,2'b10,7'b0110110}; cls_v[6]=4'd2;  cls_name[6]="PROT-VIOL   ";
    end
  endtask

  task apply(input [15:0] c);
    begin
      {vacc, ifetch, iwrite, iind, ipcr, ipt} = c;
      intrq=0; pan=1; poni=1; dstop_n=1; ftrap_n=1; vtrap_n=1;
    end
  endtask

  task tclk_edge;
    begin
      @(negedge sysclk); TCLK_EN = 1;
      @(negedge sysclk); TCLK = 1; TCLK_EN = 0;
      @(negedge sysclk); TCLK = 0;
    end
  endtask

  integer a, b, errors, checks, v7;

  initial begin
`ifdef FPGA_FF_MODE
    $display("CGA_TRAP_TVGEN_transition_tb: FPGA_FF_MODE (sysclk+TCLK_EN capture)");
`else
    $display("CGA_TRAP_TVGEN_transition_tb: latch/CP mode (posedge TCLK capture)");
`endif
    setup_classes;
    errors = 0; checks = 0; v7 = 0;

    for (a = 0; a < N; a = a + 1) begin
      for (b = 0; b < N; b = b + 1) begin
        if (a != b && cls_v[b] != 4'd15) begin
          // establish class A and let TCLK capture it
          apply(cls[a]); tclk_edge; tclk_edge;
          // now the condition CHANGES to B, and the machine may dispatch in
          // this very cycle - TRAPN is combinational.
          apply(cls[b]); #1;
          checks = checks + 1;
          if (TVEC_3_0 !== cls_v[b]) begin
            errors = errors + 1;
            if (TVEC_3_0 == 4'd7) v7 = v7 + 1;
            $display("*** STALE VECTOR  %0s -> %0s : dispatched TVEC=%0d, condition live is %0d%0s",
                     cls_name[a], cls_name[b], TVEC_3_0, cls_v[b],
                     (TVEC_3_0 == 4'd7) ? "   <== vector 7 is UNIMPLEMENTED (Issue D shape)" : "");
          end
        end
      end
    end

    $display("");
    $display("transitions checked: %0d   stale dispatches: %0d   of which vector 7: %0d",
             checks, errors, v7);
    if (errors == 0) $display("TB_RESULT: PASS (%0d checks)", checks);
    else             $display("TB_RESULT: FAIL (%0d checks, %0d errors)", checks, errors);
    $finish;
  end

endmodule

/**************************************************************************
** ND120 CGA (CPU Gate Array / DELILAH)                                  **
** /CGA/MAC  -  REPLAY TESTBENCH                                         **
**                                                                       **
** Replays a cycle-accurate capture of every CGA_MAC input taken from a   **
** live boot, and checks the module's outputs against what the full       **
** machine produced on the same cycles.                                   **
**                                                                       **
** WHY THIS EXISTS. In a Winchester boot the indirect `JPL I *14` at      **
** 000465 lands at 144162 instead of 144163 - ONE WORD EARLY - once in    **
** 15 executions, with the link register L CORRECT. Only bit 0 of the     **
** loaded P is wrong. CGA_MAC owns the address arithmetic: NLCA_15_0 is   **
** the "+1" output and PCR_15_0 is P. If the +1 is being lost by a        **
** clocking/latch difference, replaying the exact input sequence into a   **
** standalone CGA_MAC reproduces it in isolation - or proves the module   **
** is innocent and the fault is in what drives it.                        **
**                                                                       **
** VECTOR FILE: one binary word per sysclk, produced from the [maccap]    **
** dump by maccap_to_vectors.py.                                          **
**   [170:59] inputs  {MCLKEN,CSMREQ,DOUBLE,ILCSN,MCLK,PONI,PTM,WR3,WR7,  **
**                     CMIS[1:0],CSCOMM[4:0],RB,CD,FIDBO,PR,BR,XR}        **
**   [ 58: 0] expected {ECCR,LA[13:0],LSHADOW,MCA[9:0],NLCA,PCR,VEX}      **
**                                                                       **
** WARMUP: CGA_MAC holds internal state, so the first cycles after reset  **
** cannot match until that state has been re-established by the replayed  **
** inputs. Mismatches inside WARMUP are reported but not failed.          **
***************************************************************************/
`timescale 1ns / 1ps

module CGA_MAC_replay_tb;

  parameter integer MAXVEC = 4096;
  parameter integer WARMUP = 64;      // cycles allowed to converge

  reg [170:0] vec [0:MAXVEC-1];
  integer     nvec, i, mism, mism_nlca, mism_pcr, mism_warm, checked;

  reg         sysclk = 1'b0;
  reg         sys_rst_n = 1'b0;

  reg         MCLK_EN, CSMREQ, DOUBLE, ILCSN, MCLK, PONI, PTM, WR3, WR7;
  reg  [ 1:0] CMIS_1_0;
  reg  [ 4:0] CSCOMM_4_0;
  reg  [15:0] RB_15_0, CD_15_0, FIDBO_15_0, PR_15_0, BR_15_0, XR_15_0;

  wire        ECCR, LSHADOW, VEX;
  wire [13:0] LA_23_10;
  wire [ 9:0] MCA_9_0;
  wire [15:0] NLCA_15_0, PCR_15_0;

  // expected values for the current vector
  reg         e_eccr, e_lshadow, e_vex;
  reg [13:0]  e_la;
  reg [ 9:0]  e_mca;
  reg [15:0]  e_nlca, e_pcr;

  CGA_MAC DUT (
      .sysclk(sysclk), .sys_rst_n(sys_rst_n),
      .MCLK_EN(MCLK_EN), .CSMREQ(CSMREQ), .DOUBLE(DOUBLE), .ILCSN(ILCSN),
      .MCLK(MCLK), .PONI(PONI), .PTM(PTM), .WR3(WR3), .WR7(WR7),
      .CMIS_1_0(CMIS_1_0), .CSCOMM_4_0(CSCOMM_4_0),
      .RB_15_0(RB_15_0), .CD_15_0(CD_15_0), .FIDBO_15_0(FIDBO_15_0),
      .PR_15_0(PR_15_0), .BR_15_0(BR_15_0), .XR_15_0(XR_15_0),
      .ECCR(ECCR), .LA_23_10(LA_23_10), .LSHADOW(LSHADOW), .MCA_9_0(MCA_9_0),
      .NLCA_15_0(NLCA_15_0), .PCR_15_0(PCR_15_0), .VEX(VEX)
  );

  task apply(input integer k);
    begin
      {MCLK_EN,CSMREQ,DOUBLE,ILCSN,MCLK,PONI,PTM,WR3,WR7} = vec[k][170:162];
      CMIS_1_0   = vec[k][161:160];
      CSCOMM_4_0 = vec[k][159:155];
      RB_15_0    = vec[k][154:139];
      CD_15_0    = vec[k][138:123];
      FIDBO_15_0 = vec[k][122:107];
      PR_15_0    = vec[k][106:91];
      BR_15_0    = vec[k][90:75];
      XR_15_0    = vec[k][74:59];
      {e_eccr, e_la, e_lshadow, e_mca, e_nlca, e_pcr, e_vex} = vec[k][58:0];
    end
  endtask

  initial begin
    for (i = 0; i < MAXVEC; i = i + 1) vec[i] = 171'bx;
    $readmemb("maccap_vectors.txt", vec);
    nvec = 0;
    for (i = 0; i < MAXVEC; i = i + 1)
      if (vec[i] !== 171'bx) nvec = i + 1;
    if (nvec == 0) begin
      $display("TB_RESULT: FAIL - no vectors loaded (maccap_vectors.txt missing/empty)");
      $finish;
    end
    $display("CGA_MAC replay: %0d vectors, warmup %0d", nvec, WARMUP);

    mism = 0; mism_nlca = 0; mism_pcr = 0; mism_warm = 0; checked = 0;
    sys_rst_n = 1'b0;
    #20 sys_rst_n = 1'b1;

    for (i = 0; i < nvec; i = i + 1) begin
      apply(i);
      #5 sysclk = 1'b1;
      #5 sysclk = 1'b0;
      if (i >= WARMUP) checked = checked + 1;
      if ({ECCR,LA_23_10,LSHADOW,MCA_9_0,NLCA_15_0,PCR_15_0,VEX} !==
          {e_eccr,e_la,e_lshadow,e_mca,e_nlca,e_pcr,e_vex}) begin
        if (i < WARMUP) begin
          mism_warm = mism_warm + 1;
        end else begin
          // counted below
          mism = mism + 1;
          if (NLCA_15_0 !== e_nlca) mism_nlca = mism_nlca + 1;
          if (PCR_15_0  !== e_pcr)  mism_pcr  = mism_pcr  + 1;
          if (mism <= 20)
            $display("  MISMATCH vec %0d: NLCA got %06o exp %06o | PCR got %06o exp %06o | LA got %05o exp %05o",
                     i, NLCA_15_0, e_nlca, PCR_15_0, e_pcr, LA_23_10, e_la);
        end
      end
    end

    // A run that checks NOTHING must never report PASS: with fewer vectors
    // than WARMUP every cycle is skipped and a naive tb would pass silently.
    $display("vectors checked after warmup: %0d", checked);
    if (checked < 32) begin
      $display("TB_RESULT: FAIL - only %0d vectors checked (need >=32 past warmup of %0d); capture too short",
               checked, WARMUP);
      $finish;
    end
    $display("warmup mismatches (ignored): %0d", mism_warm);
    $display("steady-state mismatches: %0d  (NLCA %0d, PCR %0d)", mism, mism_nlca, mism_pcr);
    if (mism == 0)
      $display("TB_RESULT: PASS - standalone CGA_MAC reproduces the captured outputs exactly");
    else
      $display("TB_RESULT: FAIL - CGA_MAC output differs from the live machine on %0d cycles", mism);
    $finish;
  end

endmodule

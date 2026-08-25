/**************************************************************************
** ND120 CGA (CPU Gate Array / DELILAH)                                  **
** CGA_MIC_STACK_BIT testbench                                           **
**                                                                       **
** Exhaustive verification of the 1-bit x 4-deep microcode-stack cell:   **
**                                                                       **
**  1. Exhaustive transition table: every {4-bit SR44 state} x {6 input  **
**     pins STIN,LOAD,S3,S3N,S4S3N,S4NS3N} = 16 x 64 = 1024 transitions  **
**     (including electrically inconsistent complement combinations -    **
**     the golden model is the raw gate network, re-derived pin-by-pin:  **
**     g1=~(ff&S4S3N), g2=~(QA&S4NS3N), g3=QBN|S3N, A=~(g1&g2&g3),       **
**     B=~((S3|QBN)&(S3N|QCN)), C=~((S3|QCN)&(S3N|QDN)), D=QD;           **
**     LOAD=1 loads {A,B,C,D}, LOAD=0 shifts ff->QA->QB->QC->QD, where   **
**     ff = STIN captured by MEMORY_11 at the MCLK RISE preceding the    **
**     SR44 update at the MCLK FALL). Each transition starts from a      **
**     freshly shifted-in state (verified via STOUT), and the full next  **
**     state is read out through 3 POP steps (LOAD=1,S3=1,S3N=0,         **
**     S4S3N=0,S4NS3N=0 -> QA<=QB<=QC<=QD) since only QA is a pin.       **
**  2. Running checksum of the 1024 golden next-states vs the constant   **
**     computed by the independent Python model gen_mic_stack_golden.py  **
**     (acc = acc*33 + next4 mod 2^32).                                  **
**  3. Two-clock-domain split: MCLK rise alone must not move STOUT;      **
**     the SR44 fall update must use the ff value captured at the        **
**     PRECEDING rise even if STIN changed in between (stale-ff test).   **
**  4. Hold with no clock event.                                         **
**                                                                       **
** Sequential: D_FLIPFLOP_EN on MCLK rise + SR44_EN on MCLK fall.        **
** Compile once plain (posedge CLK / posedge CLKN) and once with         **
** -DFPGA_FF_MODE (sysclk + MCLK_EN / MCLK_FALL_EN capture) - the        **
** Makefile target test-mic-stackbit runs both.                          **
**                                                                       **
** Self-checking: prints TB_RESULT: PASS / FAIL (never silent).          **
**                                                                       **
** 31-JUL-2026                                                           **
** Ronny Hansen                                                          **
***************************************************************************/
`timescale 1ns / 1ps

module CGA_MIC_STACK_BIT_tb;

  reg  sysclk = 0;
  reg  MCLK_EN = 0;
  reg  MCLK_FALL_EN = 0;
  reg  MCLK = 0;
  reg  LOAD = 0;
  reg  S3 = 0;
  reg  S3N = 1;
  reg  S4NS3N = 0;
  reg  S4S3N = 0;
  reg  STIN = 0;
  wire STOUT;

  wire CLKN = ~MCLK;

  integer errors = 0;
  integer checks = 0;
  integer st, v, i;

  // Golden model state (tracked through every clock event).
  reg [3:0] gst;  // gst[0]=QA, gst[1]=QB, gst[2]=QC, gst[3]=QD
  reg       gff;  // golden MEMORY_11 state

  reg [31:0] cksum = 0;
  localparam [31:0] STACKBIT_CKS = 32'hE329C168;  // gen_mic_stack_golden.py

  CGA_MIC_STACK_BIT dut (
      .sysclk      (sysclk),
      .MCLK_EN     (MCLK_EN),
      .MCLK_FALL_EN(MCLK_FALL_EN),
      .CLK         (MCLK),
      .CLKN        (CLKN),
      .LOAD        (LOAD),
      .S3          (S3),
      .S3N         (S3N),
      .S4NS3N      (S4NS3N),
      .S4S3N       (S4S3N),
      .STIN        (STIN),
      .STOUT       (STOUT)
  );

  always #5 sysclk = ~sysclk;

  // MCLK rise event, valid in BOTH build modes (INCOUNT house pattern).
  task mclk_rise;
    begin
      @(negedge sysclk);
      MCLK_EN = 1;
      @(posedge sysclk);
      #1 MCLK = 1;
      @(negedge sysclk);
      MCLK_EN = 0;
      gff = STIN;  // golden: MEMORY_11 captures STIN at the rise
    end
  endtask

  // MCLK fall event (SR44 update), valid in BOTH build modes.
  task mclk_fall;
    begin
      @(negedge sysclk);
      MCLK_FALL_EN = 1;
      @(posedge sysclk);
      #1 MCLK = 0;
      @(negedge sysclk);
      MCLK_FALL_EN = 0;
      gst = bit_next(gst, gff, LOAD, S3, S3N, S4S3N, S4NS3N);
    end
  endtask

  task mclk_cycle;
    begin
      mclk_rise;
      mclk_fall;
    end
  endtask

  // Independent golden gate model (re-derived from the netlist, see header).
  function [3:0] bit_next(input [3:0] q, input ff, input ld, input s3,
                          input s3n, input s43n, input s4n3n);
    reg g1, g2, g3, a, b, c, d;
    begin
      g1 = ~(ff & s43n);
      g2 = ~(q[0] & s4n3n);
      g3 = ~q[1] | s3n;
      a  = ~(g1 & g2 & g3);
      b  = ~((s3 | ~q[1]) & (s3n | ~q[2]));
      c  = ~((s3 | ~q[2]) & (s3n | ~q[3]));
      d  = q[3];
      bit_next = ld ? {d, c, b, a} : {q[2:0], ff};
    end
  endfunction

  task check_stout(input [127:0] name);
    begin
      checks = checks + 1;
      if (STOUT !== gst[0]) begin
        errors = errors + 1;
        $display("FAIL %0s: STOUT=%b expected %b (gst=%b st=%0d v=%0d)",
                 name, STOUT, gst[0], gst, st, v);
      end
    end
  endtask

  // Shift target state in via 4 PUSH-path cycles (LOAD=0): bit QD first.
  task set_state(input [3:0] s_in);
    begin
      LOAD   = 0;
      S3     = 0;
      S3N    = 0;
      S4S3N  = 0;
      S4NS3N = 0;
      for (i = 3; i >= 0; i = i - 1) begin
        STIN = s_in[i];
        mclk_cycle;
      end
    end
  endtask

  // One POP readout step (consistent control encoding).
  task pop_step;
    begin
      LOAD   = 1;
      S3     = 1;
      S3N    = 0;
      S4S3N  = 0;
      S4NS3N = 0;
      STIN   = 0;
      mclk_cycle;
    end
  endtask

  initial begin
`ifdef FPGA_FF_MODE
    $display("CGA_MIC_STACK_BIT_tb: FPGA_FF_MODE (sysclk enable capture)");
`else
    $display("CGA_MIC_STACK_BIT_tb: latch/CP mode (MCLK / ~MCLK edges)");
`endif
    gst = 4'b0000;
    gff = 1'b0;
    #12;

    // ------------------------------------------------------------------
    // 1+2. Exhaustive 16 states x 64 input vectors, with 3-pop readout
    //      and running golden checksum.
    // ------------------------------------------------------------------
    for (st = 0; st < 16; st = st + 1) begin
      for (v = 0; v < 64; v = v + 1) begin
        set_state(st[3:0]);
        check_stout("setup");
        STIN   = v[0];
        LOAD   = v[1];
        S3     = v[2];
        S3N    = v[3];
        S4S3N  = v[4];
        S4NS3N = v[5];
        mclk_cycle;
        cksum = cksum * 33 + {28'b0, gst};
        check_stout("transition");
        pop_step;
        check_stout("readout-QB");
        pop_step;
        check_stout("readout-QC");
        pop_step;
        check_stout("readout-QD");
      end
    end

    checks = checks + 1;
    if (cksum !== STACKBIT_CKS) begin
      errors = errors + 1;
      $display("FAIL checksum: got %08x expected %08x", cksum, STACKBIT_CKS);
    end

    // ------------------------------------------------------------------
    // 3a. Rise alone must not move STOUT (SR44 is a fall-domain register).
    //     State here is post-readout; set a state whose QA would change
    //     on a PUSH shift, then rise only.
    // ------------------------------------------------------------------
    set_state(4'b0000);
    check_stout("domain-setup");
    LOAD   = 0;
    S3     = 0;
    S3N    = 0;
    S4S3N  = 0;
    S4NS3N = 0;
    STIN   = 1;
    mclk_rise;
    check_stout("rise-only-holds");  // gst untouched by mclk_rise
    // Complete the cycle: fall shifts the captured 1 into QA.
    mclk_fall;
    check_stout("fall-completes-shift");

    // ------------------------------------------------------------------
    // 3b. Stale-ff: capture STIN=0 at the rise, flip STIN to 1 before the
    //     fall - the shift must use the CAPTURED 0, not the pin.
    // ------------------------------------------------------------------
    STIN = 0;
    mclk_rise;
    STIN = 1;  // pin changes after the capture; gff stays 0
    mclk_fall;
    check_stout("stale-ff-shifts-old-value");

    // ------------------------------------------------------------------
    // 4. Hold with no clock event.
    // ------------------------------------------------------------------
    STIN   = 1;
    LOAD   = 1;
    S3     = 1;
    S3N    = 1;
    S4S3N  = 1;
    S4NS3N = 1;
    #40;
    check_stout("hold-no-clock");

    // ------------------------------------------------------------------
    // Verdict. Expected: 1024*5 exhaustive+readout + 1 checksum +
    // 3 domain + 1 stale-ff + 1 hold = 5126.
    // ------------------------------------------------------------------
    if (errors == 0 && checks == 5126)
      $display("TB_RESULT: PASS (%0d checks)", checks);
    else
      $display("TB_RESULT: FAIL (%0d errors, %0d of 5126 checks)",
               errors, checks);
    $finish;
  end

endmodule

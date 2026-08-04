/**************************************************************************
** ND120 CGA (CPU Gate Array / DELILAH)                                  **
** CGA_MIC_STACK_BIT12 testbench                                         **
**                                                                       **
** Exhaustive verification of the bit-12 microcode-stack cell (the       **
** STACK_BIT variant that exposes QD as the DEEP output; its SR44 D      **
** input is the same QD feedback, so the gate equations are identical    **
** to STACK_BIT - re-derived pin-by-pin in gen_mic_stack_golden.py):     **
**                                                                       **
**  1. Exhaustive transition table: every {4-bit SR44 state} x {6 input  **
**     pins STIN,LOAD,S3,S3N,S4S3N,S4NS3N} = 16 x 64 = 1024 transitions, **
**     each from a freshly shifted-in state; the full next state is read **
**     out through 3 POP steps. BOTH outputs (STOUT=QA and DEEP=QD) are  **
**     checked at every observation point.                               **
**  2. Running checksum of the 1024 golden next-states vs the Python     **
**     constant (acc = acc*33 + next4 mod 2^32).                         **
**  3. Two-clock-domain split: rise-only hold + stale-ff shift.          **
**  4. Hold with no clock event.                                         **
**                                                                       **
** Sequential: D_FLIPFLOP_EN on MCLK rise + SR44_EN on SCLKN (=~MCLK)    **
** rise. Compile once plain and once with -DFPGA_FF_MODE - the Makefile  **
** target test-mic-stackbit12 runs both.                                 **
**                                                                       **
** Self-checking: prints TB_RESULT: PASS / FAIL (never silent).          **
**                                                                       **
** 31-JUL-2026                                                           **
** Ronny Hansen                                                          **
***************************************************************************/
`timescale 1ns / 1ps

module CGA_MIC_STACK_BIT12_tb;

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
  wire DEEP;
  wire STOUT;

  wire SCLKN = ~MCLK;

  integer errors = 0;
  integer checks = 0;
  integer st, v, i;

  reg [3:0] gst;  // gst[0]=QA(STOUT), gst[3]=QD(DEEP)
  reg       gff;

  reg [31:0] cksum = 0;
  localparam [31:0] STACKBIT12_CKS = 32'hE329C168;  // gen_mic_stack_golden.py

  CGA_MIC_STACK_BIT12 dut (
      .sysclk      (sysclk),
      .MCLK_EN     (MCLK_EN),
      .MCLK_FALL_EN(MCLK_FALL_EN),
      .LOAD        (LOAD),
      .MCLK        (MCLK),
      .S3          (S3),
      .S3N         (S3N),
      .S4NS3N      (S4NS3N),
      .S4S3N       (S4S3N),
      .SCLKN       (SCLKN),
      .STIN        (STIN),
      .DEEP        (DEEP),
      .STOUT       (STOUT)
  );

  always #5 sysclk = ~sysclk;

  task mclk_rise;
    begin
      @(negedge sysclk);
      MCLK_EN = 1;
      @(posedge sysclk);
      #1 MCLK = 1;
      @(negedge sysclk);
      MCLK_EN = 0;
      gff = STIN;
    end
  endtask

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

  // Independent golden gate model (identical network to STACK_BIT; the
  // D input of the SR44 is the QD feedback in both cells).
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

  // Every observation point checks BOTH pins: STOUT=QA and DEEP=QD.
  task check_outs(input [127:0] name);
    begin
      checks = checks + 1;
      if (STOUT !== gst[0]) begin
        errors = errors + 1;
        $display("FAIL %0s: STOUT=%b expected %b (gst=%b st=%0d v=%0d)",
                 name, STOUT, gst[0], gst, st, v);
      end
      checks = checks + 1;
      if (DEEP !== gst[3]) begin
        errors = errors + 1;
        $display("FAIL %0s: DEEP=%b expected %b (gst=%b st=%0d v=%0d)",
                 name, DEEP, gst[3], gst, st, v);
      end
    end
  endtask

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
    $display("CGA_MIC_STACK_BIT12_tb: FPGA_FF_MODE (sysclk enable capture)");
`else
    $display("CGA_MIC_STACK_BIT12_tb: latch/CP mode (MCLK / ~MCLK edges)");
`endif
    gst = 4'b0000;
    gff = 1'b0;
    #12;

    // ------------------------------------------------------------------
    // 1+2. Exhaustive 16 states x 64 input vectors, 3-pop readout,
    //      running golden checksum. STOUT and DEEP checked everywhere.
    // ------------------------------------------------------------------
    for (st = 0; st < 16; st = st + 1) begin
      for (v = 0; v < 64; v = v + 1) begin
        set_state(st[3:0]);
        check_outs("setup");
        STIN   = v[0];
        LOAD   = v[1];
        S3     = v[2];
        S3N    = v[3];
        S4S3N  = v[4];
        S4NS3N = v[5];
        mclk_cycle;
        cksum = cksum * 33 + {28'b0, gst};
        check_outs("transition");
        pop_step;
        check_outs("readout-QB");
        pop_step;
        check_outs("readout-QC");
        pop_step;
        check_outs("readout-QD");
      end
    end

    checks = checks + 1;
    if (cksum !== STACKBIT12_CKS) begin
      errors = errors + 1;
      $display("FAIL checksum: got %08x expected %08x",
               cksum, STACKBIT12_CKS);
    end

    // ------------------------------------------------------------------
    // 3a. Rise alone must not move STOUT/DEEP.
    // ------------------------------------------------------------------
    set_state(4'b0000);
    check_outs("domain-setup");
    LOAD   = 0;
    S3     = 0;
    S3N    = 0;
    S4S3N  = 0;
    S4NS3N = 0;
    STIN   = 1;
    mclk_rise;
    check_outs("rise-only-holds");
    mclk_fall;
    check_outs("fall-completes-shift");

    // ------------------------------------------------------------------
    // 3b. Stale-ff: fall must shift the value captured at the rise.
    // ------------------------------------------------------------------
    STIN = 0;
    mclk_rise;
    STIN = 1;
    mclk_fall;
    check_outs("stale-ff-shifts-old-value");

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
    check_outs("hold-no-clock");

    // ------------------------------------------------------------------
    // Verdict. Expected: 1024*5*2 exhaustive+readout + 1 checksum +
    // 3*2 domain + 1*2 stale-ff + 1*2 hold = 10251.
    // ------------------------------------------------------------------
    if (errors == 0 && checks == 10251)
      $display("TB_RESULT: PASS (%0d checks)", checks);
    else
      $display("TB_RESULT: FAIL (%0d errors, %0d of 10251 checks)",
               errors, checks);
    $finish;
  end

endmodule

/**************************************************************************
** ND120 CGA (CPU Gate Array / DELILAH)                                  **
** CGA_MIC_CONDREG testbench                                             **
**                                                                       **
** Exhaustive verification of the condition register. Golden behavior    **
** re-derived pin-by-pin from the netlist:                               **
**                                                                       **
**   12x SCAN_FF: TE = ~CSSCOND, TI = own Q (hold), D = CSBIT[11:0].     **
**     -> MCLK with CSSCOND=1 loads q <= CSBIT; CSSCOND=0 holds.         **
**   LCC_3_0 = q[11:8], FS_6_3 = q[3:0] (registered, no gating).         **
**   TSEL3 = ~(LCSN & ~q7)  (NAND mask 00 on LCSN, q7 QN)                **
**   TSEL2 = LCSN & q6 ; TSEL1 = LCSN & q5                               **
**   tseln = ~(LCSN & q4) ; TSEL0 = ~tseln = LCSN & q4                   **
**   g3 = XNOR(TSEL2,TSEL1); g7 = ~(TSEL1 & tseln); g4 = ~(g3 & g7)      **
**   ACONDN = ~(g4 & TSEL3)                                              **
**   (so with LCSN=0: TSEL = 4'b1000, ACONDN = 1).                       **
**                                                                       **
**  1. Exhaustive load sweep: all 4096 CSBIT values loaded (CSSCOND=1);  **
**     after each load, all four outputs (LCC, FS, TSEL, ACONDN) are     **
**     checked for BOTH LCSN values (8 checks per load). This covers     **
**     the whole ACONDN cone (q7..q4 x LCSN = 32 combinations) many      **
**     times over.                                                       **
**  2. Running checksum of the golden output sweep vs the constant from  **
**     the independent Python model gen_mic_stack_golden.py.             **
**  3. Hold: 8 LFSR-picked CSBIT values clocked with CSSCOND=0 must      **
**     leave every output unchanged.                                     **
**  4. Hold with no clock event.                                         **
**                                                                       **
** Sequential: 12x SCAN_FF_EN on MCLK. Compile once plain (posedge       **
** MCLK) and once with -DFPGA_FF_MODE (sysclk + MCLK_EN capture) - the   **
** Makefile target test-mic-condreg runs both.                           **
**                                                                       **
** Self-checking: prints TB_RESULT: PASS / FAIL (never silent).          **
**                                                                       **
** 31-JUL-2026                                                           **
** Ronny Hansen                                                          **
***************************************************************************/
`timescale 1ns / 1ps

module CGA_MIC_CONDREG_tb;

  reg         sysclk = 0;
  reg         MCLK_EN = 0;
  reg         MCLK = 0;
  reg  [11:0] CSBIT_11_0 = 0;
  reg         CSSCOND = 0;
  reg         LCSN = 1;
  wire        ACONDN;
  wire [3:0]  FS_6_3;
  wire [3:0]  LCC_3_0;
  wire [3:0]  TSEL_3_0;

  integer errors = 0;
  integer checks = 0;
  integer v, k;

  reg [11:0] gq;  // golden register state

  reg [31:0] lfsr = 32'hFEEDFACE;
  reg [31:0] cksum = 0;
  localparam [31:0] CONDREG_CKS = 32'h87EC2600;  // gen_mic_stack_golden.py

  CGA_MIC_CONDREG dut (
      .sysclk    (sysclk),
      .MCLK_EN   (MCLK_EN),
      .CSBIT_11_0(CSBIT_11_0),
      .CSSCOND   (CSSCOND),
      .LCSN      (LCSN),
      .MCLK      (MCLK),
      .ACONDN    (ACONDN),
      .FS_6_3    (FS_6_3),
      .LCC_3_0   (LCC_3_0),
      .TSEL_3_0  (TSEL_3_0)
  );

  always #5 sysclk = ~sysclk;

  // One MCLK event, valid in BOTH build modes (INCOUNT house pattern).
  task pulse_mclk;
    begin
      @(negedge sysclk);
      MCLK_EN = 1;
      @(posedge sysclk);
      #1 MCLK = 1;
      @(negedge sysclk);
      MCLK    = 0;
      MCLK_EN = 0;
      if (CSSCOND) gq = CSBIT_11_0;
    end
  endtask

  // Independent golden TSEL/ACONDN cone (see header).
  function [4:0] tsel_acond(input [11:0] q, input lcsn);
    reg t3, t2, t1, t0, tn, g3, g7, g4, acondn;
    begin
      t3 = ~(lcsn & ~q[7]);
      t2 = lcsn & q[6];
      t1 = lcsn & q[5];
      tn = ~(lcsn & q[4]);
      t0 = ~tn;
      g3 = ~(t2 ^ t1);
      g7 = ~(t1 & tn);
      g4 = ~(g3 & g7);
      acondn = ~(g4 & t3);
      tsel_acond = {t3, t2, t1, t0, acondn};
    end
  endfunction

  // Check all four outputs at the current LCSN value.
  task check_all(input [127:0] name);
    reg [4:0] g;
    begin
      g = tsel_acond(gq, LCSN);
      checks = checks + 1;
      if (LCC_3_0 !== gq[11:8]) begin
        errors = errors + 1;
        $display("FAIL %0s: LCC=%b expected %b (gq=%03x)",
                 name, LCC_3_0, gq[11:8], gq);
      end
      checks = checks + 1;
      if (FS_6_3 !== gq[3:0]) begin
        errors = errors + 1;
        $display("FAIL %0s: FS=%b expected %b (gq=%03x)",
                 name, FS_6_3, gq[3:0], gq);
      end
      checks = checks + 1;
      if (TSEL_3_0 !== g[4:1]) begin
        errors = errors + 1;
        $display("FAIL %0s: TSEL=%b expected %b (gq=%03x LCSN=%b)",
                 name, TSEL_3_0, g[4:1], gq, LCSN);
      end
      checks = checks + 1;
      if (ACONDN !== g[0]) begin
        errors = errors + 1;
        $display("FAIL %0s: ACONDN=%b expected %b (gq=%03x LCSN=%b)",
                 name, ACONDN, g[0], gq, LCSN);
      end
    end
  endtask

  // Check with LCSN=1 then LCSN=0, accumulating the golden checksum.
  task check_both_lcsn(input [127:0] name);
    reg [4:0] g;
    begin
      LCSN = 1;
      #2;
      check_all(name);
      g = tsel_acond(gq, 1'b1);
      cksum = cksum * 33
            + {17'b0, gq[11:8], gq[3:0], g[4:1], g[0], 1'b1};
      LCSN = 0;
      #2;
      check_all(name);
      g = tsel_acond(gq, 1'b0);
      cksum = cksum * 33
            + {17'b0, gq[11:8], gq[3:0], g[4:1], g[0], 1'b0};
      LCSN = 1;
      #2;
    end
  endtask

  initial begin
`ifdef FPGA_FF_MODE
    $display("CGA_MIC_CONDREG_tb: FPGA_FF_MODE (sysclk+MCLK_EN capture)");
`else
    $display("CGA_MIC_CONDREG_tb: latch/CP mode (posedge MCLK capture)");
`endif
    gq = 12'b0;
    #12;

    // ------------------------------------------------------------------
    // 1+2. Exhaustive load sweep of all 4096 CSBIT values, both LCSN
    //      values, with running golden checksum.
    // ------------------------------------------------------------------
    for (v = 0; v < 4096; v = v + 1) begin
      CSSCOND    = 1;
      CSBIT_11_0 = v[11:0];
      pulse_mclk;
      check_both_lcsn("load");
    end

    checks = checks + 1;
    if (cksum !== CONDREG_CKS) begin
      errors = errors + 1;
      $display("FAIL checksum: got %08x expected %08x", cksum, CONDREG_CKS);
    end

    // ------------------------------------------------------------------
    // 3. Hold: clocked with CSSCOND=0, CSBIT noise must not load.
    // ------------------------------------------------------------------
    CSSCOND    = 1;
    CSBIT_11_0 = 12'o5252;
    pulse_mclk;
    for (k = 0; k < 8; k = k + 1) begin
      lfsr       = lfsr[0] ? (lfsr >> 1) ^ 32'hEDB88320 : lfsr >> 1;
      CSSCOND    = 0;
      CSBIT_11_0 = lfsr[11:0];
      pulse_mclk;
      check_all("hold-clocked");
    end

    // ------------------------------------------------------------------
    // 4. Hold with no clock event (load inputs armed but no MCLK).
    // ------------------------------------------------------------------
    CSSCOND    = 1;
    CSBIT_11_0 = 12'o2525;
    #40;
    check_all("hold-no-clock");

    // ------------------------------------------------------------------
    // Verdict. Expected: 4096*8 sweep + 1 checksum + 8*4 hold +
    // 4 no-clock = 32805.
    // ------------------------------------------------------------------
    if (errors == 0 && checks == 32805)
      $display("TB_RESULT: PASS (%0d checks)", checks);
    else
      $display("TB_RESULT: FAIL (%0d errors, %0d of 32805 checks)",
               errors, checks);
    $finish;
  end

endmodule

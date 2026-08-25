/**************************************************************************
** ND120 CGA (CPU Gate Array / DELILAH)                                  **
** CGA_MAC_SEGPT testbench (integration)                                 **
**                                                                       **
** Integration verification of the SEGPT parent (/CGA/MAC/SEGPT,         **
** page 35), which wires XPT + SEG + PCR and inverts MCLK:               **
**   s_mclk_n = ~MCLK feeds every sub-block MCLKN pin, so the three      **
**   latches are open while MCLK is LOW and the matching LLD* is high.   **
**   FIDBO fields: XPT <- [2:0], SEG <- [7:0], PCR <- [15:0].            **
**                                                                       **
** Golden functions re-derived from the sub-block netlists and verified  **
** by the independent Python gate model (gen_segpt_golden.py,            **
** scratchpad only; first 8 LFSR vectors cross-printed):                 **
**   SEG   = f[7:0], SEGZN = (f[7:0] != 0)                               **
**   PCR   = {f[15:8], f[7], 4'b0000, f[2:0]}                            **
**   XPT   = f[1:0]; VEX = ~EXMN & f[2]; PEX = ~EXMN & ~f[2]             **
**                                                                       **
** Stimulus split (16 data + EXMN + 3 enables + MCLK is too wide for an  **
** exhaustive latched sweep at the parent; the sub-block tbs are the     **
** exhaustive layer): 256 fixed-seed LFSR vectors (16-bit Fibonacci,     **
** taps 16,14,13,11, seed ACE1 - same generator as the Python model) +   **
** 4 corner words, each loaded into all three registers and read under   **
** both EXMN values; then directed integration checks:                   **
**  1. LFSR/corner load sweep: 260 vectors x 8 output checks = 2080.     **
**  2. Per-register load independence (only one LLD* at a time). 11.     **
**  3. MCLK=1 blocks loading even with all LLD*=1. 3 checks.             **
**  4. Transparency polarity: MCLK=0 + LLD*=1 follows comb. 3 checks.    **
**                                                                       **
** The load pulse is valid in BOTH latch builds: plain / -DFPGA_FF_MODE  **
** (mux + posedge-sysclk FF, transparent while enable=1) and             **
** -DUSE_TRANSPARENT_LATCHES (true level latch). The Makefile target     **
** runs all three builds.                                                **
**                                                                       **
** Self-checking: prints TB_RESULT: PASS / FAIL (never silent).          **
**                                                                       **
** 31-JUL-2026                                                           **
** Ronny Hansen                                                          **
***************************************************************************/
`timescale 1ns / 1ps

module CGA_MAC_SEGPT_tb;

  reg         sysclk = 0;
  reg         EXMN = 1;
  reg  [15:0] FIDBO = 0;
  reg         LLDEXM = 0;
  reg         LLDPCR = 0;
  reg         LLDSEG = 0;
  reg         MCLK = 1;      // idle high = latches closed

  wire [15:0] PCR;
  wire        PEX;
  wire        SEGZN;
  wire [ 7:0] SEG;
  wire        VEX;
  wire [ 1:0] XPT;

  integer errors = 0;
  integer checks = 0;
  integer i, e;
  reg [15:0] lfsr;
  reg [15:0] vec;
  reg [15:0] corner[0:3];

  localparam integer EXPECTED_CHECKS = 2097;

  CGA_MAC_SEGPT dut (
      .sysclk    (sysclk),
      .sys_rst_n (1'b1),
      .EXMN      (EXMN),
      .FIDBO_15_0(FIDBO),
      .LLDEXM    (LLDEXM),
      .LLDPCR    (LLDPCR),
      .LLDSEG    (LLDSEG),
      .MCLK      (MCLK),
      .PCR_15_0  (PCR),
      .PEX       (PEX),
      .SEGZN     (SEGZN),
      .SEG_7_0   (SEG),
      .VEX       (VEX),
      .XPT_1_0   (XPT)
  );

  always #5 sysclk = ~sysclk;

  // One load event through the parent's MCLK inverter: MCLK dropped low
  // (latches with LLD*=1 go transparent), a posedge sysclk passes
  // (FF-mode capture), then MCLK returns high (transparent-mode capture
  // at the closing edge). Valid in BOTH latch builds.
  task pulse_load;
    begin
      @(negedge sysclk);
      MCLK = 0;
      @(posedge sysclk);
      #1 MCLK = 1;
      #1;
    end
  endtask

  // 16-bit Fibonacci LFSR, taps 16,14,13,11 - identical to the Python
  // model's stimulus generator (seed ACE1).
  function [15:0] lfsr_next(input [15:0] s);
    begin
      lfsr_next = {s[14:0], s[15] ^ s[13] ^ s[12] ^ s[10]};
    end
  endfunction

  function [15:0] pcr_map(input [15:0] f);
    begin
      pcr_map = {f[15:8], f[7], 4'b0000, f[2:0]};
    end
  endfunction

  task chk(input cond, input [159:0] name);
    begin
      checks = checks + 1;
      if (!cond) begin
        errors = errors + 1;
        $display("FAIL %0s (FIDBO=%04x EXMN=%b SEG=%02x SEGZN=%b PCR=%04x XPT=%b VEX=%b PEX=%b)",
                 name, FIDBO, EXMN, SEG, SEGZN, PCR, XPT, VEX, PEX);
      end
    end
  endtask

  // Full output check for a word loaded into ALL three registers.
  task check_all(input [15:0] f);
    begin
      EXMN = 0;  #2;
      chk(SEG   === f[7:0],               "SEG");
      chk(SEGZN === (f[7:0] != 8'h00),    "SEGZN");
      chk(PCR   === pcr_map(f),           "PCR");
      chk(XPT   === f[1:0],               "XPT");
      chk(VEX   === f[2],                 "VEX EXMN=0");
      chk(PEX   === ~f[2],                "PEX EXMN=0");
      EXMN = 1;  #2;
      chk(VEX   === 1'b0,                 "VEX EXMN=1");
      chk(PEX   === 1'b0,                 "PEX EXMN=1");
    end
  endtask

  initial begin
`ifdef USE_TRANSPARENT_LATCHES
    $display("CGA_MAC_SEGPT_tb: USE_TRANSPARENT_LATCHES (level latch)");
`elsif FPGA_FF_MODE
    $display("CGA_MAC_SEGPT_tb: FPGA_FF_MODE (mux + sysclk FF latch)");
`else
    $display("CGA_MAC_SEGPT_tb: plain build (mux + sysclk FF latch)");
`endif

    // ------------------------------------------------------------------
    // 1. LFSR + corner load sweep: (256 + 4) x 8 = 2080 checks.
    //    Every vector loaded into all three registers, bus then driven
    //    to the complement before reading (proves the registered path,
    //    not a transparent feed-through).
    // ------------------------------------------------------------------
    lfsr = 16'hACE1;
    for (i = 0; i < 256; i = i + 1) begin
      vec = lfsr;
      FIDBO  = vec;
      LLDEXM = 1; LLDSEG = 1; LLDPCR = 1;
      pulse_load;
      LLDEXM = 0; LLDSEG = 0; LLDPCR = 0;
      FIDBO  = ~vec;
      #2;
      check_all(vec);
      lfsr = lfsr_next(lfsr);
    end
    corner[0] = 16'h0000; corner[1] = 16'hFFFF;
    corner[2] = 16'hAAAA; corner[3] = 16'h5555;
    for (i = 0; i < 4; i = i + 1) begin
      vec = corner[i];
      FIDBO  = vec;
      LLDEXM = 1; LLDSEG = 1; LLDPCR = 1;
      pulse_load;
      LLDEXM = 0; LLDSEG = 0; LLDPCR = 0;
      FIDBO  = ~vec;
      #2;
      check_all(vec);
    end

    // ------------------------------------------------------------------
    // 2. Per-register load independence: 11 checks.
    //    Base word A in all three, then single-enable loads.
    // ------------------------------------------------------------------
    FIDBO = 16'h1234;                       // A: f2=1
    LLDEXM = 1; LLDSEG = 1; LLDPCR = 1;
    pulse_load;
    LLDEXM = 0; LLDSEG = 0; LLDPCR = 0;

    // only SEG loads B
    FIDBO = 16'hFF00; LLDSEG = 1;
    pulse_load;
    LLDSEG = 0; EXMN = 0; #2;
    chk(SEG === 8'h00,             "indep SEG<-B");
    chk(SEGZN === 1'b0,            "indep SEGZN(B=00)");
    chk(PCR === pcr_map(16'h1234), "indep PCR holds A");
    chk(XPT === 2'b00,             "indep XPT holds A");

    // only PCR loads C
    FIDBO = 16'h00FF; LLDPCR = 1;
    pulse_load;
    LLDPCR = 0; #2;
    chk(PCR === pcr_map(16'h00FF), "indep PCR<-C");
    chk(SEG === 8'h00,             "indep SEG holds B");
    chk(XPT === 2'b00,             "indep XPT holds A");

    // only XPT loads D (f2=1 -> VEX with EXMN=0)
    FIDBO = 16'h0007; LLDEXM = 1;
    pulse_load;
    LLDEXM = 0; EXMN = 0; #2;
    chk(XPT === 2'b11,             "indep XPT<-D");
    chk(VEX === 1'b1,              "indep VEX(D f2=1)");
    chk(SEG === 8'h00,             "indep SEG holds B");
    chk(PCR === pcr_map(16'h00FF), "indep PCR holds C");

    // ------------------------------------------------------------------
    // 3. MCLK=1 blocks loading: all enables high, data changed, sysclk
    //    edges pass, MCLK never drops - nothing may load. 3 checks.
    // ------------------------------------------------------------------
    @(negedge sysclk);
    FIDBO = 16'h5AA5;
    LLDEXM = 1; LLDSEG = 1; LLDPCR = 1;   // MCLK stays 1
    #22;
    chk(SEG === 8'h00,             "MCLK=1 blocks SEG");
    chk(PCR === pcr_map(16'h00FF), "MCLK=1 blocks PCR");
    chk(XPT === 2'b11,             "MCLK=1 blocks XPT");

    // ------------------------------------------------------------------
    // 4. Transparency polarity: MCLK low + enables high -> outputs
    //    follow the bus combinationally. 3 checks.
    // ------------------------------------------------------------------
    @(negedge sysclk);
    MCLK = 0;                              // enables still all high
    FIDBO = 16'h8181;
    #2;
    chk(SEG === 8'h81,             "transparent SEG follows");
    chk(PCR === pcr_map(16'h8181), "transparent PCR follows");
    chk(XPT === 2'b01,             "transparent XPT follows");
    @(posedge sysclk);
    #1 MCLK = 1;
    LLDEXM = 0; LLDSEG = 0; LLDPCR = 0;

    // ------------------------------------------------------------------
    // Verdict. Expected: 2080 sweep + 11 independence + 3 block +
    // 3 transparency = 2097.
    // ------------------------------------------------------------------
    if (errors == 0 && checks == EXPECTED_CHECKS)
      $display("TB_RESULT: PASS (%0d checks)", checks);
    else
      $display("TB_RESULT: FAIL (%0d errors, %0d of %0d checks)",
               errors, checks, EXPECTED_CHECKS);
    $finish;
  end

endmodule

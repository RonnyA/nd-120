/**************************************************************************
** ND120 CGA (CPU Gate Array / DELILAH)                                  **
** CGA_MAC_SEGPT_PCR testbench                                           **
**                                                                       **
** Exhaustive verification of the PCR register (/CGA/MAC/SEGPT/PCR,      **
** page 37). Netlist read-out (BubblesMask decoded):                     **
**   GATES_1 AND mask 00 : L = MCLKN & LLDPCR (shared by both latches)   **
**   L8 PCR_HI : A..H = FIDBO[15..8] -> PCR[15..8]                       **
**   L4 PCR_LO : A=FIDBO[7]->PCR[7], B=FIDBO[2]->PCR[2],                 **
**               C=FIDBO[1]->PCR[1], D=FIDBO[0]->PCR[0]                  **
**   PCR[6:3] hardwired 0000 (PIL lives there, driven elsewhere);        **
**   FIDBO[6:3] intentionally ignored.                                   **
**   => PCR = {FIDBO[15:8], FIDBO[7], 4'b0000, FIDBO[2:0]}               **
**                                                                       **
** The compact mapping above was verified for ALL 65536 inputs against a **
** literal per-port gate hookup model in the independent Python          **
** generator (gen_segpt_golden.py, scratchpad only), which also emitted  **
** the 32 literal LFSR load vectors below.                               **
**                                                                       **
** Checks (16 data bits + 2 enables -> fully covered):                   **
**  1. Transparent exhaustive sweep: latch open, all 65536 FIDBO values, **
**     PCR vs mapping. 65536 checks.                                     **
**  2. Latched load + hold: 32 Python-emitted LFSR vectors with literal  **
**     expected constants, load then complement-drive hold. 64 checks.   **
**  3. Corner loads 0000/FFFF/AAAA/5555, load + hold. 8 checks.          **
**  4. Enable gating: MCLKN=1&LLDPCR=0, 0&1, 0&0 must not load. 3.       **
**                                                                       **
** The load pulse is valid in BOTH latch builds: plain / -DFPGA_FF_MODE  **
** (mux + posedge-sysclk FF, transparent while L=1) and                  **
** -DUSE_TRANSPARENT_LATCHES (true level latch). The Makefile target     **
** runs all three builds.                                                **
**                                                                       **
** Self-checking: prints TB_RESULT: PASS / FAIL (never silent).          **
**                                                                       **
** 31-JUL-2026                                                           **
** Ronny Hansen                                                          **
***************************************************************************/
`timescale 1ns / 1ps

module CGA_MAC_SEGPT_PCR_tb;

  reg         sysclk = 0;
  reg  [15:0] FIDBO = 0;
  reg         LLDPCR = 0;
  reg         MCLKN = 0;

  wire [15:0] PCR;

  integer errors = 0;
  integer checks = 0;
  integer i;

  localparam integer EXPECTED_CHECKS = 65611;

  reg [15:0] pcr_vec[0:31];
  reg [15:0] pcr_exp[0:31];
  reg [15:0] corner[0:3];

  CGA_MAC_SEGPT_PCR dut (
      .sysclk    (sysclk),
      .sys_rst_n (1'b1),
      .FIDBO_15_0(FIDBO),
      .LLDPCR    (LLDPCR),
      .MCLKN     (MCLKN),
      .PCR_15_0  (PCR)
  );

  always #5 sysclk = ~sysclk;

  // One latch-load event, valid in BOTH latch builds: data stable, L
  // raised, a posedge sysclk passes (FF-mode capture), then L falls
  // (transparent-mode capture at the falling edge of L).
  task load_word(input [15:0] v);
    begin
      @(negedge sysclk);
      FIDBO  = v;
      LLDPCR = 1;
      MCLKN  = 1;
      @(posedge sysclk);
      #1 MCLKN = 0;
      LLDPCR = 0;
      #1;
    end
  endtask

  task check_pcr(input [15:0] exp, input [127:0] name);
    begin
      checks = checks + 1;
      if (PCR !== exp) begin
        errors = errors + 1;
        $display("FAIL %0s: PCR=%04x expected %04x (FIDBO=%04x)",
                 name, PCR, exp, FIDBO);
      end
    end
  endtask

  // Independently verified mapping (see header): high byte straight,
  // bit 7 straight, bits 6:3 forced 0, bits 2:0 straight.
  function [15:0] pcr_map(input [15:0] f);
    begin
      pcr_map = {f[15:8], f[7], 4'b0000, f[2:0]};
    end
  endfunction

  initial begin
`ifdef USE_TRANSPARENT_LATCHES
    $display("CGA_MAC_SEGPT_PCR_tb: USE_TRANSPARENT_LATCHES (level latch)");
`elsif FPGA_FF_MODE
    $display("CGA_MAC_SEGPT_PCR_tb: FPGA_FF_MODE (mux + sysclk FF latch)");
`else
    $display("CGA_MAC_SEGPT_PCR_tb: plain build (mux + sysclk FF latch)");
`endif

    // ------------------------------------------------------------------
    // 1. Transparent exhaustive sweep: 65536 checks.
    // ------------------------------------------------------------------
    @(negedge sysclk);
    MCLKN  = 1;
    LLDPCR = 1;
    for (i = 0; i < 65536; i = i + 1) begin
      FIDBO = i[15:0];
      #2;
      check_pcr(pcr_map(i[15:0]), "transparent sweep");
    end
    MCLKN  = 0;
    LLDPCR = 0;

    // ------------------------------------------------------------------
    // 2. Latched load + hold: 32 LFSR vectors (literal expected values
    //    emitted by gen_segpt_golden.py) x (load + hold) = 64 checks.
    // ------------------------------------------------------------------
      pcr_vec[0] = 16'hace1; pcr_exp[0] = 16'hac81;
      pcr_vec[1] = 16'h59c3; pcr_exp[1] = 16'h5983;
      pcr_vec[2] = 16'hb387; pcr_exp[2] = 16'hb387;
      pcr_vec[3] = 16'h670f; pcr_exp[3] = 16'h6707;
      pcr_vec[4] = 16'hce1e; pcr_exp[4] = 16'hce06;
      pcr_vec[5] = 16'h9c3c; pcr_exp[5] = 16'h9c04;
      pcr_vec[6] = 16'h3879; pcr_exp[6] = 16'h3801;
      pcr_vec[7] = 16'h70f2; pcr_exp[7] = 16'h7082;
      pcr_vec[8] = 16'he1e4; pcr_exp[8] = 16'he184;
      pcr_vec[9] = 16'hc3c8; pcr_exp[9] = 16'hc380;
      pcr_vec[10] = 16'h8791; pcr_exp[10] = 16'h8781;
      pcr_vec[11] = 16'h0f22; pcr_exp[11] = 16'h0f02;
      pcr_vec[12] = 16'h1e45; pcr_exp[12] = 16'h1e05;
      pcr_vec[13] = 16'h3c8a; pcr_exp[13] = 16'h3c82;
      pcr_vec[14] = 16'h7915; pcr_exp[14] = 16'h7905;
      pcr_vec[15] = 16'hf22a; pcr_exp[15] = 16'hf202;
      pcr_vec[16] = 16'he455; pcr_exp[16] = 16'he405;
      pcr_vec[17] = 16'hc8ab; pcr_exp[17] = 16'hc883;
      pcr_vec[18] = 16'h9157; pcr_exp[18] = 16'h9107;
      pcr_vec[19] = 16'h22ae; pcr_exp[19] = 16'h2286;
      pcr_vec[20] = 16'h455d; pcr_exp[20] = 16'h4505;
      pcr_vec[21] = 16'h8abb; pcr_exp[21] = 16'h8a83;
      pcr_vec[22] = 16'h1577; pcr_exp[22] = 16'h1507;
      pcr_vec[23] = 16'h2aee; pcr_exp[23] = 16'h2a86;
      pcr_vec[24] = 16'h55dd; pcr_exp[24] = 16'h5585;
      pcr_vec[25] = 16'habba; pcr_exp[25] = 16'hab82;
      pcr_vec[26] = 16'h5774; pcr_exp[26] = 16'h5704;
      pcr_vec[27] = 16'haee8; pcr_exp[27] = 16'hae80;
      pcr_vec[28] = 16'h5dd1; pcr_exp[28] = 16'h5d81;
      pcr_vec[29] = 16'hbba2; pcr_exp[29] = 16'hbb82;
      pcr_vec[30] = 16'h7745; pcr_exp[30] = 16'h7705;
      pcr_vec[31] = 16'hee8b; pcr_exp[31] = 16'hee83;
    for (i = 0; i < 32; i = i + 1) begin
      load_word(pcr_vec[i]);
      check_pcr(pcr_exp[i], "LFSR load");
      FIDBO = ~pcr_vec[i];      // latch closed - must not propagate
      #22;
      check_pcr(pcr_exp[i], "LFSR hold");
    end

    // ------------------------------------------------------------------
    // 3. Corner loads: 4 x (load + hold) = 8 checks.
    // ------------------------------------------------------------------
    corner[0] = 16'h0000; corner[1] = 16'hFFFF;
    corner[2] = 16'hAAAA; corner[3] = 16'h5555;
    for (i = 0; i < 4; i = i + 1) begin
      load_word(corner[i]);
      check_pcr(pcr_map(corner[i]), "corner load");
      FIDBO = ~corner[i];
      #22;
      check_pcr(pcr_map(corner[i]), "corner hold");
    end

    // ------------------------------------------------------------------
    // 4. Enable gating: 3 checks. State entering here: PCR = map(5555).
    // ------------------------------------------------------------------
    @(negedge sysclk);
    MCLKN = 1; LLDPCR = 0; FIDBO = 16'h1234;
    #22;
    check_pcr(pcr_map(16'h5555), "gating MCLKN=1 LLDPCR=0");

    @(negedge sysclk);
    MCLKN = 0; LLDPCR = 1; FIDBO = 16'h4321;
    #22;
    check_pcr(pcr_map(16'h5555), "gating MCLKN=0 LLDPCR=1");

    @(negedge sysclk);
    MCLKN = 0; LLDPCR = 0; FIDBO = 16'h8765;
    #22;
    check_pcr(pcr_map(16'h5555), "gating MCLKN=0 LLDPCR=0");

    // ------------------------------------------------------------------
    // Verdict. Expected: 65536 sweep + 64 LFSR + 8 corner + 3 gating
    // = 65611.
    // ------------------------------------------------------------------
    if (errors == 0 && checks == EXPECTED_CHECKS)
      $display("TB_RESULT: PASS (%0d checks)", checks);
    else
      $display("TB_RESULT: FAIL (%0d errors, %0d of %0d checks)",
               errors, checks, EXPECTED_CHECKS);
    $finish;
  end

endmodule

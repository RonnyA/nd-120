/**************************************************************************
** ND120 CGA (CPU Gate Array / DELILAH)                                  **
** CGA_MAC_APOS_CALCA testbench                                          **
**                                                                       **
** Exhaustive verification of the CALCA block (/CGA/MAC/APOS/CALCA,      **
** page 32). Netlist read-out (BubblesMask decoded):                     **
**   L8 L_LO/L_HI : transparent while MCLK=0 (L = ~MCLK), ICA -> MCA;    **
**                  MCA_9_0 exposes bits 9:0, bits 15:10 stay internal.  **
**   R81 R_LO/R_HI: capture the latch outputs on posedge MCLK -> LCA.    **
**   ECCR decode  : GATES_1 NAND5(lca0,~lca1,lca2,lca3,~lca4),           **
**                  GATES_2 NAND5(~lca5,lca6,~lca7,~lca8,~lca9),         **
**                  GATES_3 AND3 mask 111 (= AND of inverted inputs)     **
**                  => ECCR = ~ECCRHIN & (LCA[9:0]==10'o0115) (IOX      **
**                  100115 low bits; 10'o0115 = 10'h04D).                **
** The decode was verified for ALL 2048 {LCA[9:0],ECCRHIN} combos        **
** against a literal per-port gate model in the independent Python       **
** generator (gen_tier3_mac_golden.py, scratchpad only), which also      **
** emitted the sweep checksum constant and the 32 literal LFSR load      **
** vectors below.                                                        **
**                                                                       **
** Checks:                                                               **
**  1. Transparent MCA sweep: MCLK=0, all 65536 ICA values,              **
**     MCA_9_0 == ICA[9:0] + running checksum vs the Python constant.    **
**     65536 + 1 checks.                                                 **
**  2. Exhaustive register/decode sweep: all 1024 LCA[9:0] values        **
**     loaded through the latch+register path (upper 6 bits from the     **
**     pattern ICA[15:10] = i[5:0]^i[9:4]); per load check LCA and ECCR  **
**     with ECCRHIN=0 and 1. 3072 checks.                                **
**  3. LFSR load+hold: 32 Python-emitted vectors with literal expected   **
**     constants; load, then complement-drive hold of LCA and MCA.       **
**     96 checks.                                                        **
**  4. Corner loads 0000/FFFF/AAAA/5555, load + hold. 12 checks.         **
**  5. Latch/register gating: MCLK held 1 blocks both; reopening MCLK=0  **
**     makes MCA follow while LCA holds. 4 checks.                       **
**                                                                       **
** The load pulse is valid in ALL THREE builds: plain and -DFPGA_FF_MODE **
** (R81_EN captures at posedge sysclk while MCLK_EN=1, raised while the  **
** latch is still open; the CP-mode R81 captures at the MCLK posedge     **
** raised just after the same sysclk edge) and                           **
** -DUSE_TRANSPARENT_LATCHES (true level L8). The Makefile target runs   **
** all three builds.                                                     **
**                                                                       **
** Self-checking: prints TB_RESULT: PASS / FAIL (never silent).          **
**                                                                       **
** 31-JUL-2026                                                           **
** Ronny Hansen                                                          **
***************************************************************************/
`timescale 1ns / 1ps

module CGA_MAC_APOS_CALCA_tb;

  reg         sysclk = 0;
  reg         MCLK_EN = 0;
  reg         ECCRHIN = 1;
  reg  [15:0] ICA = 0;
  reg         MCLK = 0;

  wire        ECCR;
  wire [15:0] LCA;
  wire [ 9:0] MCA;

  integer errors = 0;
  integer checks = 0;
  integer i;
  reg [31:0] chk;
  reg [15:0] v;
  reg [ 9:0] ii;

  localparam integer EXPECTED_CHECKS = 68721;
  // Emitted by gen_tier3_mac_golden.py (chk = chk*33 + MCA, ICA ascending)
  localparam [31:0] MCA_SWEEP_CHECKSUM = 32'hB65F8000;

  reg [15:0] lfsr[0:31];
  reg [ 9:0] lfsr_mca[0:31];
  reg [15:0] corner[0:3];

  CGA_MAC_APOS_CALCA dut (
      .sysclk   (sysclk),
      .sys_rst_n(1'b1),
      .MCLK_EN  (MCLK_EN),
      .ECCRHIN  (ECCRHIN),
      .ICA_15_0 (ICA),
      .MCLK     (MCLK),
      .ECCR     (ECCR),
      .LCA_15_0 (LCA),
      .MCA_9_0  (MCA)
  );

  always #5 sysclk = ~sysclk;

  // One full load event, valid in ALL THREE builds (see header): open the
  // latch with data stable, give the default-build L8 a sysclk capture,
  // then clock the register (EN-mode at posedge sysclk, CP-mode at the
  // MCLK rise raised just after it). Leaves MCLK=1 (latch closed).
  task load_word(input [15:0] w);
    begin
      @(negedge sysclk);
      MCLK    = 0;
      MCLK_EN = 0;
      ICA     = w;
      @(posedge sysclk);  // default-build L8 reg capture (L=1)
      @(negedge sysclk);
      MCLK_EN = 1;
      @(posedge sysclk);  // FF-mode R81 capture (latch still open)
      #1 MCLK = 1;        // CP-mode R81 capture; latch closes
      @(negedge sysclk);
      MCLK_EN = 0;
      #1;
    end
  endtask

  task check_lca(input [15:0] exp, input [127:0] name);
    begin
      checks = checks + 1;
      if (LCA !== exp) begin
        errors = errors + 1;
        $display("FAIL %0s: LCA=%04x expected %04x (ICA=%04x)",
                 name, LCA, exp, ICA);
      end
    end
  endtask

  task check_mca(input [9:0] exp, input [127:0] name);
    begin
      checks = checks + 1;
      if (MCA !== exp) begin
        errors = errors + 1;
        $display("FAIL %0s: MCA=%03x expected %03x (ICA=%04x)",
                 name, MCA, exp, ICA);
      end
    end
  endtask

  task check_eccr(input exp, input [127:0] name);
    begin
      checks = checks + 1;
      if (ECCR !== exp) begin
        errors = errors + 1;
        $display("FAIL %0s: ECCR=%b expected %b (LCA=%04x ECCRHIN=%b)",
                 name, ECCR, exp, LCA, ECCRHIN);
      end
    end
  endtask

  initial begin
`ifdef USE_TRANSPARENT_LATCHES
    $display("CGA_MAC_APOS_CALCA_tb: USE_TRANSPARENT_LATCHES (level latch)");
`elsif FPGA_FF_MODE
    $display("CGA_MAC_APOS_CALCA_tb: FPGA_FF_MODE (sysclk+MCLK_EN capture)");
`else
    $display("CGA_MAC_APOS_CALCA_tb: plain build (mux+FF latch, CP register)");
`endif

    // ------------------------------------------------------------------
    // 1. Transparent MCA sweep + checksum: 65536 + 1 checks.
    // ------------------------------------------------------------------
    MCLK    = 0;
    MCLK_EN = 0;
    ECCRHIN = 1;
    // Prime the transparent-latch build: the L8 always @(*) block only
    // evaluates on an input CHANGE, so toggle every ICA bit once while the
    // latch is open to clear the x power-up state (checks unaffected).
    ICA = 16'hFFFF;
    #2;
    ICA = 16'h0000;
    #2;
    chk = 32'd0;
    for (i = 0; i < 65536; i = i + 1) begin
      ICA = i[15:0];
      #2;
      check_mca(i[9:0], "transparent sweep");
      chk = chk * 33 + {22'b0, MCA};
    end
    checks = checks + 1;
    if (chk !== MCA_SWEEP_CHECKSUM) begin
      errors = errors + 1;
      $display("FAIL MCA sweep checksum: got %08x expected %08x",
               chk, MCA_SWEEP_CHECKSUM);
    end

    // ------------------------------------------------------------------
    // 2. Exhaustive register/decode sweep: 1024 loads x 3 = 3072 checks.
    //    ECCR must be 1 for exactly LCA[9:0]==10'h04D with ECCRHIN=0.
    // ------------------------------------------------------------------
    for (i = 0; i < 1024; i = i + 1) begin
      ii = i[9:0];
      v  = {ii[5:0] ^ ii[9:4], ii};
      load_word(v);
      check_lca(v, "decode sweep load");
      ECCRHIN = 0;
      #2;
      check_eccr(ii == 10'h04D, "decode sweep ECCRHIN=0");
      ECCRHIN = 1;
      #2;
      check_eccr(1'b0, "decode sweep ECCRHIN=1");
    end

    // ------------------------------------------------------------------
    // 3. LFSR load + hold: 32 x 3 = 96 checks (literal Python vectors).
    // ------------------------------------------------------------------
    lfsr[0] = 16'he270; lfsr_mca[0] = 10'h270;
    lfsr[1] = 16'h7138; lfsr_mca[1] = 10'h138;
    lfsr[2] = 16'h389c; lfsr_mca[2] = 10'h09c;
    lfsr[3] = 16'h1c4e; lfsr_mca[3] = 10'h04e;
    lfsr[4] = 16'h0e27; lfsr_mca[4] = 10'h227;
    lfsr[5] = 16'hb313; lfsr_mca[5] = 10'h313;
    lfsr[6] = 16'hed89; lfsr_mca[6] = 10'h189;
    lfsr[7] = 16'hc2c4; lfsr_mca[7] = 10'h2c4;
    lfsr[8] = 16'h6162; lfsr_mca[8] = 10'h162;
    lfsr[9] = 16'h30b1; lfsr_mca[9] = 10'h0b1;
    lfsr[10] = 16'hac58; lfsr_mca[10] = 10'h058;
    lfsr[11] = 16'h562c; lfsr_mca[11] = 10'h22c;
    lfsr[12] = 16'h2b16; lfsr_mca[12] = 10'h316;
    lfsr[13] = 16'h158b; lfsr_mca[13] = 10'h18b;
    lfsr[14] = 16'hbec5; lfsr_mca[14] = 10'h2c5;
    lfsr[15] = 16'heb62; lfsr_mca[15] = 10'h362;
    lfsr[16] = 16'h75b1; lfsr_mca[16] = 10'h1b1;
    lfsr[17] = 16'h8ed8; lfsr_mca[17] = 10'h2d8;
    lfsr[18] = 16'h476c; lfsr_mca[18] = 10'h36c;
    lfsr[19] = 16'h23b6; lfsr_mca[19] = 10'h3b6;
    lfsr[20] = 16'h11db; lfsr_mca[20] = 10'h1db;
    lfsr[21] = 16'hbced; lfsr_mca[21] = 10'h0ed;
    lfsr[22] = 16'hea76; lfsr_mca[22] = 10'h276;
    lfsr[23] = 16'h753b; lfsr_mca[23] = 10'h13b;
    lfsr[24] = 16'h8e9d; lfsr_mca[24] = 10'h29d;
    lfsr[25] = 16'hf34e; lfsr_mca[25] = 10'h34e;
    lfsr[26] = 16'h79a7; lfsr_mca[26] = 10'h1a7;
    lfsr[27] = 16'h88d3; lfsr_mca[27] = 10'h0d3;
    lfsr[28] = 16'hf069; lfsr_mca[28] = 10'h069;
    lfsr[29] = 16'hcc34; lfsr_mca[29] = 10'h034;
    lfsr[30] = 16'h661a; lfsr_mca[30] = 10'h21a;
    lfsr[31] = 16'h330d; lfsr_mca[31] = 10'h30d;
    for (i = 0; i < 32; i = i + 1) begin
      load_word(lfsr[i]);
      check_lca(lfsr[i], "LFSR load");
      ICA = ~lfsr[i];  // latch closed, register unclocked - must hold
      #22;
      check_lca(lfsr[i], "LFSR LCA hold");
      check_mca(lfsr_mca[i], "LFSR MCA hold");
    end

    // ------------------------------------------------------------------
    // 4. Corner loads: 4 x 3 = 12 checks.
    // ------------------------------------------------------------------
    corner[0] = 16'h0000; corner[1] = 16'hFFFF;
    corner[2] = 16'hAAAA; corner[3] = 16'h5555;
    for (i = 0; i < 4; i = i + 1) begin
      load_word(corner[i]);
      check_lca(corner[i], "corner load");
      ICA = ~corner[i];
      #22;
      check_lca(corner[i], "corner LCA hold");
      check_mca(corner[i][9:0], "corner MCA hold");
    end

    // ------------------------------------------------------------------
    // 5. Gating: 4 checks. State entering here: LCA=5555, MCLK=1.
    // ------------------------------------------------------------------
    ICA = 16'h1234;  // MCLK still 1: latch closed, no register clock
    #22;
    check_lca(16'h5555, "gating MCLK=1 LCA");
    check_mca(10'h155, "gating MCLK=1 MCA");

    @(negedge sysclk);
    MCLK = 0;        // reopen latch: MCA follows, LCA must not
    #22;
    check_mca(10'h234, "reopen MCA follows");
    check_lca(16'h5555, "reopen LCA holds");

    // ------------------------------------------------------------------
    // Verdict. Expected: 65537 + 3072 + 96 + 12 + 4 = 68721.
    // ------------------------------------------------------------------
    if (errors == 0 && checks == EXPECTED_CHECKS)
      $display("TB_RESULT: PASS (%0d checks)", checks);
    else
      $display("TB_RESULT: FAIL (%0d errors, %0d of %0d checks)",
               errors, checks, EXPECTED_CHECKS);
    $finish;
  end

endmodule

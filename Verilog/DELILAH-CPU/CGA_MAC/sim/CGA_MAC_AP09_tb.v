/**************************************************************************
** ND120 CGA (CPU Gate Array / DELILAH)                                  **
** CGA_MAC_AP09 testbench                                                **
**                                                                       **
** Verification of the AP09 address-position block (/CGA/MAC/AP09,       **
** page 31): the ICA wired-OR source selector feeding the CALCA          **
** latch/register pair and the +1 incrementer.                           **
**                                                                       **
** Netlist read-out (BubblesMask decoded, checked gate by gate):         **
**   ICAxA A02   : ~((LCA[n]&HOLD) | (PR[n]&PSEL))                       **
**   ICAxB A02   : ~((ADDSEL&ADD[n]) | (CDSEL&CD[n]))  (bit0 has the    **
**                 CDSEL/CD pin pair swapped vs bits 1-15; AND is        **
**                 commutative, same function)                           **
**   GATES_1..16 : NAND(NLCASEL, NLCA[n])                                **
**   GATES_17..32: OR3 mask 111 (= OR of inverted inputs), so            **
**   ICA[n] = (HOLD&LCA[n])|(PSEL&PR[n])|(ADDSEL&ADD[n])                 **
**            |(CDSEL&CD[n])|(NLCASEL&NLCA[n])                           **
**   AINC        : NLCA = LCA + 1 (always driven, NLCASEL only gates    **
**                 the feedback into ICA, not the NLCA output port)      **
**   CALCA       : L8 latches transparent while MCLK=0 -> MCA[9:0];     **
**                 R81 captures the latch outputs on posedge MCLK ->     **
**                 LCA; ECCR = ~ECCRHIN & (LCA[9:0]==10'o0115)           **
**                 (IOX 100115 low bits, 10'o0115 = 10'h04D).            **
**                                                                       **
** The golden model is behavioral (OR-merge of enabled sources, 16-bit   **
** add, address compare) - re-derived from the schematic intent, not     **
** transliterated from the gates.                                        **
**                                                                       **
** Check layers (fixed total 13648):                                     **
**  S1 priming: 2 loads (2 checks each: MCA at latch-open, LCA after)   **
**     + ICA/NLCA sanity = 6.                                            **
**  S2 selector sweep: 2 LCA contexts x all 32 control combos x 18      **
**     directed data tuples, ICA+NLCA per vector = 2 loads (4) + 2304.  **
**  S3 walking-1/0 per source: PR/ADD/CD 3x32 vectors (96) +            **
**     HOLD/NLCASEL via 16 single-bit LCA loads (16x(2+2)=64) = 160.    **
**  S4 incrementer corners: 12 directed + 16 carry-chain loads,         **
**     NLCA==LCA+1 per load = 28x2 + 28 = 84.                           **
**  S5 ECCR decode: 4 matching addresses (upper-6-bit variants) + 10    **
**     one-bit near-misses, ECCRHIN both polarities = 14x2 + 28 = 56.   **
**  S6 MCA latch transparency/hold: 8 patterns x 4 + resync load = 34.  **
**     (Raising MCLK without MCLK_EN clocks the CP-mode R81 but not the **
**     FF-mode one, so no LCA-dependent check until the resync load.)   **
**  S7 soak: 4000 fixed-seed xorshift32 vectors, ICA+NLCA each; every   **
**     4th does a full load (2 in-task checks) + ECCR check, with       **
**     directed ECCR-hit steering every 16th = 8000 + 3000 = 11000.     **
**                                                                       **
** The load pulse is the proven CGA_MAC_APOS_CALCA_tb sequence, valid   **
** in ALL THREE builds: plain, -DFPGA_FF_MODE (R81_EN sysclk+MCLK_EN    **
** capture) and -DUSE_TRANSPARENT_LATCHES (true level L8). The          **
** Makefile target test-mac-ap09 runs all three.                        **
**                                                                       **
** Self-checking: prints TB_RESULT: PASS / FAIL (never silent).          **
**                                                                       **
** 01-AUG-2026                                                           **
** Ronny Hansen                                                          **
***************************************************************************/
`timescale 1ns / 1ps

module CGA_MAC_AP09_tb;

  reg         sysclk = 0;
  reg         MCLK = 1;
  reg         MCLK_EN = 0;
  reg         ECCRHIN = 1;
  reg         HOLD = 0;
  reg         PSEL = 0;
  reg         ADDSEL = 0;
  reg         CDSEL = 0;
  reg         NLCASEL = 0;
  reg  [15:0] PR = 0;
  reg  [15:0] ADD = 0;
  reg  [15:0] CD = 0;

  wire        ECCR;
  wire [15:0] ICA;
  wire [15:0] LCA;
  wire [ 9:0] MCA;
  wire [15:0] NLCA;

  integer errors = 0;
  integer checks = 0;
  integer i, c, t, k;
  reg [15:0] lca_m;       // golden LCA register model
  reg [15:0] exp_ica;
  reg [15:0] p;
  reg [31:0] rnd;

  localparam integer EXPECTED_CHECKS = 13648;

  reg [15:0] tup_pr [0:17];
  reg [15:0] tup_ad [0:17];
  reg [15:0] tup_cd [0:17];
  reg [15:0] corner [0:11];
  reg [15:0] hitaddr[0:3];
  reg [15:0] mcapat [0:7];

  CGA_MAC_AP09 dut (
      .sysclk   (sysclk),
      .sys_rst_n(1'b1),
      .ADDSEL   (ADDSEL),
      .ADD_15_0 (ADD),
      .CDSEL    (CDSEL),
      .CD_15_0  (CD),
      .ECCRHIN  (ECCRHIN),
      .HOLD     (HOLD),
      .MCLK     (MCLK),
      .MCLK_EN  (MCLK_EN),
      .NLCASEL  (NLCASEL),
      .PR_15_0  (PR),
      .PSEL     (PSEL),
      .ECCR     (ECCR),
      .ICA_15_0 (ICA),
      .LCA_15_0 (LCA),
      .MCA_9_0  (MCA),
      .NLCA_15_0(NLCA)
  );

  always #5 sysclk = ~sysclk;

  // Behavioral golden ICA: OR-merge of every enabled source.
  function [15:0] ica_of;
    input [15:0] lca;
    begin
      ica_of = (HOLD    ? lca            : 16'h0000)
             | (PSEL    ? PR             : 16'h0000)
             | (ADDSEL  ? ADD            : 16'h0000)
             | (CDSEL   ? CD             : 16'h0000)
             | (NLCASEL ? lca + 16'd1    : 16'h0000);
    end
  endfunction

  // xorshift32, fixed seed - reproducible across simulators.
  function [31:0] xs32;
    input [31:0] x;
    reg [31:0] y;
    begin
      y    = x ^ (x << 13);
      y    = y ^ (y >> 17);
      xs32 = y ^ (y << 5);
    end
  endfunction

  task chk16(input [15:0] got, input [15:0] exp, input [127:0] name);
    begin
      checks = checks + 1;
      if (got !== exp) begin
        errors = errors + 1;
        $display("FAIL %0s: got %04x expected %04x (lca_m=%04x sel=%b%b%b%b%b)",
                 name, got, exp, lca_m, HOLD, PSEL, ADDSEL, CDSEL, NLCASEL);
      end
    end
  endtask

  task chk10(input [9:0] got, input [9:0] exp, input [127:0] name);
    begin
      checks = checks + 1;
      if (got !== exp) begin
        errors = errors + 1;
        $display("FAIL %0s: got %03x expected %03x", name, got, exp);
      end
    end
  endtask

  task chk1(input got, input exp, input [127:0] name);
    begin
      checks = checks + 1;
      if (got !== exp) begin
        errors = errors + 1;
        $display("FAIL %0s: got %b expected %b (lca_m=%04x ECCRHIN=%b)",
                 name, got, exp, lca_m, ECCRHIN);
      end
    end
  endtask

  // One full load event, valid in ALL THREE builds (proven sequence from
  // CGA_MAC_APOS_CALCA_tb): open the latch with inputs stable, check MCA
  // transparency, give the default-build L8 a sysclk capture, then clock
  // the register (EN-mode at posedge sysclk, CP-mode at the MCLK rise just
  // after it). Leaves MCLK=1 (latch closed). Checks: 2.
  task load_and_check;
    begin
      @(negedge sysclk);
      MCLK    = 0;
      MCLK_EN = 0;
      #1;
      exp_ica = ica_of(lca_m);
      chk10(MCA, exp_ica[9:0], "load open MCA");
      @(posedge sysclk);  // default-build L8 reg capture (L=1)
      @(negedge sysclk);
      MCLK_EN = 1;
      @(posedge sysclk);  // FF-mode R81 capture (latch still open)
      #1 MCLK = 1;        // CP-mode R81 capture; latch closes
      lca_m   = exp_ica;
      @(negedge sysclk);
      MCLK_EN = 0;
      #1;
      chk16(LCA, lca_m, "load LCA");
    end
  endtask

  task comb_checks;  // ICA + NLCA vs golden, 2 checks
    begin
      #2;
      chk16(ICA, ica_of(lca_m), "ICA");
      chk16(NLCA, lca_m + 16'd1, "NLCA");
    end
  endtask

  initial begin
`ifdef USE_TRANSPARENT_LATCHES
    $display("CGA_MAC_AP09_tb: USE_TRANSPARENT_LATCHES (level latch)");
`elsif FPGA_FF_MODE
    $display("CGA_MAC_AP09_tb: FPGA_FF_MODE (sysclk+MCLK_EN capture)");
`else
    $display("CGA_MAC_AP09_tb: plain build (mux+FF latch, CP register)");
`endif

    // ------------------------------------------------------------------
    // S1. Priming: 2 loads through the CD path (HOLD=NLCASEL=0 so ICA is
    //     independent of the x power-up LCA); the FFFF->0000 pair also
    //     toggles every L8 input to clear the transparent-build x state.
    //     6 checks.
    // ------------------------------------------------------------------
    lca_m = 16'h0000;
    CDSEL = 1;
    CD    = 16'hFFFF;
    load_and_check();
    CD    = 16'h0000;
    load_and_check();
    comb_checks();

    // ------------------------------------------------------------------
    // S2. Selector sweep: 2 LCA contexts x 32 control combos x 18 data
    //     tuples. MCLK stays 1 (register unclocked) through each sweep.
    //     2 loads (4) + 2*32*18*2 = 2308 checks.
    // ------------------------------------------------------------------
    tup_pr[ 0]=16'h0000; tup_ad[ 0]=16'h0000; tup_cd[ 0]=16'h0000;
    tup_pr[ 1]=16'hFFFF; tup_ad[ 1]=16'hFFFF; tup_cd[ 1]=16'hFFFF;
    tup_pr[ 2]=16'hAAAA; tup_ad[ 2]=16'h5555; tup_cd[ 2]=16'hAAAA;
    tup_pr[ 3]=16'h5555; tup_ad[ 3]=16'hAAAA; tup_cd[ 3]=16'h5555;
    tup_pr[ 4]=16'h00FF; tup_ad[ 4]=16'hFF00; tup_cd[ 4]=16'h0F0F;
    tup_pr[ 5]=16'hF0F0; tup_ad[ 5]=16'h00FF; tup_cd[ 5]=16'hFF00;
    tup_pr[ 6]=16'h1234; tup_ad[ 6]=16'h5678; tup_cd[ 6]=16'h9ABC;
    tup_pr[ 7]=16'hDEF0; tup_ad[ 7]=16'h0FED; tup_cd[ 7]=16'hCBA9;
    tup_pr[ 8]=16'h8000; tup_ad[ 8]=16'h0001; tup_cd[ 8]=16'h8001;
    tup_pr[ 9]=16'h7FFF; tup_ad[ 9]=16'hFFFE; tup_cd[ 9]=16'h4000;
    tup_pr[10]=16'h0101; tup_ad[10]=16'h1010; tup_cd[10]=16'h0110;
    tup_pr[11]=16'hFEFE; tup_ad[11]=16'hEFEF; tup_cd[11]=16'hF00F;
    tup_pr[12]=16'hA5A5; tup_ad[12]=16'h5A5A; tup_cd[12]=16'hC3C3;
    tup_pr[13]=16'h3C3C; tup_ad[13]=16'hC3C3; tup_cd[13]=16'h3CC3;
    tup_pr[14]=16'h0F0F; tup_ad[14]=16'hF0F0; tup_cd[14]=16'h0FF0;
    tup_pr[15]=16'hFFF0; tup_ad[15]=16'h000F; tup_cd[15]=16'hFF0F;
    tup_pr[16]=16'h1111; tup_ad[16]=16'h2222; tup_cd[16]=16'h4444;
    tup_pr[17]=16'h8888; tup_ad[17]=16'h4321; tup_cd[17]=16'h00A5;

    for (i = 0; i < 2; i = i + 1) begin
      {HOLD, PSEL, ADDSEL, NLCASEL} = 4'b0000;
      CDSEL = 1;
      CD    = (i == 0) ? 16'h0000 : 16'hA5C3;
      load_and_check();
      for (c = 0; c < 32; c = c + 1) begin
        {HOLD, PSEL, ADDSEL, CDSEL, NLCASEL} = c[4:0];
        for (t = 0; t < 18; t = t + 1) begin
          PR  = tup_pr[t];
          ADD = tup_ad[t];
          CD  = tup_cd[t];
          comb_checks();
        end
      end
    end

    // ------------------------------------------------------------------
    // S3. Walking-1/walking-0 per source. 96 + 64 = 160 checks.
    // ------------------------------------------------------------------
    for (k = 0; k < 16; k = k + 1) begin
      {HOLD, ADDSEL, CDSEL, NLCASEL} = 4'b0000; PSEL = 1;
      PR = 16'h0001 << k;              #2; chk16(ICA, PR,  "walk1 PR");
      PR = ~(16'h0001 << k);           #2; chk16(ICA, PR,  "walk0 PR");
      PSEL = 0; ADDSEL = 1;
      ADD = 16'h0001 << k;             #2; chk16(ICA, ADD, "walk1 ADD");
      ADD = ~(16'h0001 << k);          #2; chk16(ICA, ADD, "walk0 ADD");
      ADDSEL = 0; CDSEL = 1;
      CD = 16'h0001 << k;              #2; chk16(ICA, CD,  "walk1 CD");
      CD = ~(16'h0001 << k);           #2; chk16(ICA, CD,  "walk0 CD");
    end
    for (k = 0; k < 16; k = k + 1) begin
      {HOLD, PSEL, ADDSEL, NLCASEL} = 4'b0000;
      CDSEL = 1;
      CD    = 16'h0001 << k;
      load_and_check();                 // 2 checks, LCA = 1<<k
      CDSEL = 0; HOLD = 1;
      #2; chk16(ICA, lca_m, "walk HOLD");
      HOLD = 0; NLCASEL = 1;
      #2; chk16(ICA, lca_m + 16'd1, "walk NLCASEL");
      NLCASEL = 0;
    end

    // ------------------------------------------------------------------
    // S4. Incrementer corners + carry chain: 28 loads x 2 + 28 = 84.
    // ------------------------------------------------------------------
    corner[ 0]=16'h0000; corner[ 1]=16'h0001; corner[ 2]=16'h00FF;
    corner[ 3]=16'h0100; corner[ 4]=16'h0FFF; corner[ 5]=16'h1000;
    corner[ 6]=16'h7FFF; corner[ 7]=16'h8000; corner[ 8]=16'hAAAA;
    corner[ 9]=16'h5555; corner[10]=16'hFFFE; corner[11]=16'hFFFF;
    {HOLD, PSEL, ADDSEL, NLCASEL} = 4'b0000;
    CDSEL = 1;
    for (i = 0; i < 12; i = i + 1) begin
      CD = corner[i];
      load_and_check();
      #2; chk16(NLCA, lca_m + 16'd1, "corner NLCA");
    end
    for (k = 1; k <= 16; k = k + 1) begin
      CD = (17'h00001 << k) - 17'h00001;  // 2^k - 1: full carry ripple
      load_and_check();
      #2; chk16(NLCA, lca_m + 16'd1, "carry NLCA");
    end

    // ------------------------------------------------------------------
    // S5. ECCR decode: 4 matching (upper-6-bit variants) + 10 one-bit
    //     near-misses, ECCRHIN both ways. 14 loads x 2 + 28 = 56.
    // ------------------------------------------------------------------
    hitaddr[0]=16'h004D; hitaddr[1]=16'hFC4D;
    hitaddr[2]=16'h844D; hitaddr[3]=16'h7C4D;
    for (i = 0; i < 14; i = i + 1) begin
      CD = (i < 4) ? hitaddr[i] : (16'h004D ^ (16'h0001 << (i - 4)));
      load_and_check();
      ECCRHIN = 0;
      #2; chk1(ECCR, lca_m[9:0] == 10'h04D, "ECCR ECCRHIN=0");
      ECCRHIN = 1;
      #2; chk1(ECCR, 1'b0, "ECCR ECCRHIN=1");
    end

    // ------------------------------------------------------------------
    // S6. MCA latch transparency + hold, LCA-independent config (CDSEL
    //     only). The bare MCLK rises here clock the CP-mode R81 but not
    //     the FF-mode one, so no LCA-dependent check until the resync
    //     load at the end. 8 x 4 + 2 = 34 checks.
    // ------------------------------------------------------------------
    mcapat[0]=16'h0000; mcapat[1]=16'hFFFF; mcapat[2]=16'hAAAA;
    mcapat[3]=16'h5555; mcapat[4]=16'h0F0F; mcapat[5]=16'hF0F0;
    mcapat[6]=16'h1234; mcapat[7]=16'h8765;
    for (i = 0; i < 8; i = i + 1) begin
      p = mcapat[i];
      @(negedge sysclk);
      MCLK = 0;
      CD   = p;
      @(posedge sysclk);  // default-build L8 reg capture while open
      #1;
      chk16(ICA, p, "S6 open ICA");
      chk10(MCA, p[9:0], "S6 open MCA");
      @(negedge sysclk);
      #1 MCLK = 1;        // close latch (also a CP-mode R81 edge)
      CD = ~p;
      #2;
      chk16(ICA, ~p, "S6 closed ICA");
      chk10(MCA, p[9:0], "S6 hold MCA");
    end
    CD = 16'h0123;
    load_and_check();     // resync model LCA in every build

    // ------------------------------------------------------------------
    // S7. Soak: 4000 fixed-seed vectors; every 4th a full load + ECCR
    //     check, ECCR-hit steering every 16th. 8000 + 3000 = 11000.
    // ------------------------------------------------------------------
    rnd = 32'hC0FFEE01;
    for (i = 0; i < 4000; i = i + 1) begin
      rnd = xs32(rnd);
      PR  = rnd[15:0];
      {HOLD, PSEL, ADDSEL, CDSEL, NLCASEL} = rnd[20:16];
      ECCRHIN = rnd[21];
      rnd = xs32(rnd);
      ADD = rnd[15:0];
      CD  = rnd[31:16];
      if ((i & 15) == 3) begin
        // steer the next load to LCA[9:0]==04D so ECCR really fires
        {HOLD, PSEL, ADDSEL, NLCASEL} = 4'b0000;
        CDSEL = 1;
        CD    = {CD[15:10], 10'h04D};
        if ((i & 31) == 3) ECCRHIN = 0;
      end
      comb_checks();
      if ((i & 3) == 3) begin
        load_and_check();
        #2; chk1(ECCR, (ECCRHIN == 1'b0) && (lca_m[9:0] == 10'h04D),
                 "soak ECCR");
      end
    end

    // ------------------------------------------------------------------
    // Verdict. Expected: 6 + 2308 + 160 + 84 + 56 + 34 + 11000 = 13648.
    // ------------------------------------------------------------------
    if (errors == 0 && checks == EXPECTED_CHECKS)
      $display("TB_RESULT: PASS (%0d checks)", checks);
    else
      $display("TB_RESULT: FAIL (%0d errors, %0d of %0d checks)",
               errors, checks, EXPECTED_CHECKS);
    $finish;
  end

endmodule

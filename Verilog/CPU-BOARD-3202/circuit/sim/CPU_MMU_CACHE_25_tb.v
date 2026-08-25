/**************************************************************************
** ND120 CPU - unit test                                                 **
** CPU_MMU_CACHE_25: the cache sheet (sheet 25) - TMM2018D_25 data SRAMs **
** 23F/24F, CPN SRAMs 16F/20F, Am9150 used-bit RAM 21F, PAL_44402D       **
** UBITS (via PAL_44402D_EN), the EWC NAND, the HIT AND, and the 26-JUL  **
** banner-word-2 fix: CD_15_0_OUT is HIT-GATED (a miss/inhibit read      **
** contributes 0 to the wired-OR CD bus instead of jamming stale line    **
** data over the memory word).                                           **
**                                                                       **
** THREE BUILD MODES (the Makefile runs all three):                      **
**   plain                          - gated CD_OUT, PAL on posedge UCLK  **
**   -DND120_CACHE_DRIVE_UNGATED    - raw schematic CD drive (escape     **
**                                    hatch): SRAM word drives on MISS   **
**   -DFPGA_FF_MODE                 - gated CD_OUT, PAL registers on     **
**                                    posedge sysclk + UCLK_EN (P3 UCLK  **
**                                    conversion, PAL_44402D_EN USE_EN=1)**
**                                                                       **
** THE TEETH ARE THE HIT-GATE ITSELF: every miss/inhibit read asserts    **
** CD_OUT==0 in the gated builds and CD_OUT==<stale line> in the         **
** ungated build. A mutant with the ungated assign in the normal build   **
** MUST fail the stale-line checks.                                      **
**                                                                       **
** Coverage:                                                             **
**   P0 settle (PAL regs defined via 2 safe UCLK events)                 **
**   P1 exhaustive WCA_n/EWC/CON comb cone: all 256 combos of            **
**      {BRK_n,SW1,WCINH_n,CYD,FMISS,LSHADOW,RT_n,DT_n} (clock frozen)   **
**   P2 refill-write path: 16 addresses (incl. the 0x400/0x000 used-bit  **
**      alias pair) written via WCA_n, incl. "SRAM output forced 0       **
**      while writing"                                                   **
**   P3 hit/miss matrix per address: all {HIT1_n,HIT0_n} x CWR combos    **
**      plus fetch/read/write RT-DT variants; CPN path checked (CPN is   **
**      NOT hit-gated, per the schematic)                                **
**   P4 WCINH_n cache-inhibit: refill suppressed, miss must drive 0      **
**   P5 used-bit lifecycle via UCLK: fetch-hit sets IHIT (blocks fetch   **
**      refill), write-with-hit clears the used bit -> subsequent fetch  **
**      misses (stale-read check), data-read still hits via OUBD         **
**   P6 LFSR phase (800 cycles, seed CAFEB0BA): random reads/writes      **
**      over the filled set, all outputs folded into a running checksum  **
**                                                                       **
** Golden behavior from the INDEPENDENT Python model                     **
** gen_cache_golden.py (scratchpad, not in repo), which procedurally     **
** mirrors every phase and emits the two checksum constants (gated /     **
** ungated) plus the expected check count. Per-sample expectations are   **
** independent formula re-derivations, not copies of the DUT netlist.    **
**                                                                       **
** No VERILATOR_SIM branch exists in this sheet. TMM2018D_25 is used in  **
** its default SYNC-read configuration (TMM_ASYNC_READ not defined),     **
** matching the shipped sim/FPGA builds.                                 **
**                                                                       **
** Self-checking: prints TB_RESULT: PASS / FAIL (never silent).          **
**                                                                       **
** Run: make test-mmucache   (CPU-BOARD-3202/circuit/sim)                **
**                                                                       **
** 31-JUL-2026                                                           **
** Ronny Hansen                                                          **
***************************************************************************/
`timescale 1ns / 1ps

module CPU_MMU_CACHE_25_tb;

  // sysclk starts HIGH so the first posedge comes after the first setup;
  // clk_en freezes the clock (low) for the pure-comb sweep phases.
  reg sysclk = 1;
  reg clk_en = 1;
  always begin
    #5;
    if (clk_en) sysclk = ~sysclk;
  end

  reg         sys_rst_n = 1;
  reg         brk_n = 1;
  reg  [10:0] ca = 0;
  reg         cclr_n = 0;
  reg         cwr = 0;
  reg         cyd = 0;
  reg         dt_n = 1;
  reg         ecd_n = 1;
  reg         fmiss = 0;
  reg  [1:0]  hitn = 2'b11;
  reg         lshadow = 0;
  reg         pd2 = 0;
  reg         rt_n = 1;
  reg         sw1 = 1;
  reg         uclk = 0;
  reg         uclk_en = 0;
  reg         wcinh_n = 1;
  reg  [15:0] cd_in = 0;
  reg  [13:0] cpn_in = 0;

  wire [15:0] cd_out;
  wire [13:0] cpn_out;
  wire        con, con_n, hit, wca_n, led1;

  CPU_MMU_CACHE_25 dut (
      .sysclk     (sysclk),
      .sys_rst_n  (sys_rst_n),
      .BRK_n      (brk_n),
      .CA_10_0    (ca),
      .CCLR_n     (cclr_n),
      .CWR        (cwr),
      .CYD        (cyd),
      .DT_n       (dt_n),
      .ECD_n      (ecd_n),
      .FMISS      (fmiss),
      .HIT_1_0_n  (hitn),
      .LSHADOW    (lshadow),
      .PD2        (pd2),
      .RT_n       (rt_n),
      .SW1_CONSOLE(sw1),
      .UCLK       (uclk),
      .UCLK_EN    (uclk_en),
      .WCINH_n    (wcinh_n),
      .CD_15_0_IN (cd_in),
      .CD_15_0_OUT(cd_out),
      .CPN_23_10_IN (cpn_in),
      .CPN_23_10_OUT(cpn_out),
      .CON  (con),
      .CON_n(con_n),
      .HIT  (hit),
      .WCA_n(wca_n),
      .LED1 (led1)
  );

`ifdef ND120_CACHE_DRIVE_UNGATED
  localparam [31:0] ACC_EXPECT = 32'h9C4B92B9;
  localparam UNGATED = 1'b1;
`else
  localparam [31:0] ACC_EXPECT = 32'hFE7812B9;
  localparam UNGATED = 1'b0;
`endif

  integer errors = 0;
  integer checks = 0;
  integer k, ai, cbi;
  reg [31:0] acc = 0;
  reg [31:0] lfsr = 32'hCAFEB0BA;
  reg [31:0] cw, dw;
  reg [10:0] fill[0:15];
  reg        hit_e, wca_e;
  reg [15:0] cd_e;

  initial begin
    fill[ 0] = 11'h000; fill[ 1] = 11'h001; fill[ 2] = 11'h002;
    fill[ 3] = 11'h003; fill[ 4] = 11'h155; fill[ 5] = 11'h2AA;
    fill[ 6] = 11'h3FF; fill[ 7] = 11'h400; fill[ 8] = 11'h555;
    fill[ 9] = 11'h6AA; fill[10] = 11'h7FF; fill[11] = 11'h7FE;
    fill[12] = 11'h123; fill[13] = 11'h234; fill[14] = 11'h345;
    fill[15] = 11'h456;
  end

  function [15:0] pat(input [10:0] a);
    pat = (((a * 16'h9E37) ^ 16'h1234) | 16'h0001);
  endfunction

  function [13:0] cpnpat(input [10:0] a);
    cpnpat = (({3'b0, a} * 17'h6B) ^ 17'h3A5) & 17'h3FFF;
  endfunction

  // fold current outputs into the running checksum (matches the model)
  task fold(input include_cpn);
    reg [31:0] w;
    begin
      w = {hit, wca_n, cd_out, include_cpn ? cpn_out : 14'b0};
      acc = (acc << 5) - acc + w;
    end
  endtask

  // one sysclk cycle: inputs already set by caller BEFORE the negedge?
  // No - callers set inputs, then call cyc which waits for the next
  // negedge, applies nothing, crosses the posedge and settles #1.
  task cyc;
    begin
      @(negedge sysclk);
      #1;  // inputs are changed here by the caller via pre-set regs
      @(posedge sysclk);
      #1;
    end
  endtask

  // one UCLK capture event, valid in all three build modes: EN spans one
  // sysclk posedge; the CP-mode UCLK rises right after the same edge with
  // stable PAL inputs (no RAM write may be active: WCA_n must be 1).
  task uclk_event;
    begin
      @(negedge sysclk);
      uclk_en = 1;
      @(posedge sysclk);
      #1 uclk = 1;
      #2 uclk = 0;
      uclk_en = 0;
    end
  endtask

  task chk_ctrl(input eh, input ew);
    begin
      checks = checks + 1;
      if (hit !== eh || wca_n !== ew || con !== sw1 || con_n !== ~sw1 ||
          led1 !== ~sw1) begin
        errors = errors + 1;
        $display("FAIL ctrl: HIT=%b (exp %b) WCA_n=%b (exp %b) CON=%b SW1=%b",
                 hit, eh, wca_n, ew, con, sw1);
      end
    end
  endtask

  task chk_cd(input [15:0] e);
    begin
      checks = checks + 1;
      if (cd_out !== e) begin
        errors = errors + 1;
        $display("FAIL CD_OUT: got %04h expected %04h (ca=%03h)", cd_out, e, ca);
      end
    end
  endtask

  task chk_cpn(input [13:0] e);
    begin
      checks = checks + 1;
      if (cpn_out !== e) begin
        errors = errors + 1;
        $display("FAIL CPN_OUT: got %04h expected %04h (ca=%03h)", cpn_out, e, ca);
      end
    end
  endtask

  initial begin
    // ---- P0: settle (2 idle cycles, 2 safe UCLK events) ----
    cyc;
    cyc;
    for (k = 0; k < 2; k = k + 1) begin
      uclk_event;
      #1;
      chk_ctrl(1'b0, 1'b1);
      fold(1'b0);
    end

    // ---- P1: exhaustive WCA/EWC/CON comb sweep (clock frozen) ----
    @(negedge sysclk);
    clk_en = 0;
    for (k = 0; k < 256; k = k + 1) begin
      brk_n   = k[0];
      sw1     = k[1];
      wcinh_n = k[2];
      cyd     = k[3];
      fmiss   = k[4];
      lshadow = k[5];
      rt_n    = k[6];
      dt_n    = k[7];
      #2;
      // independent formula: EWC = BRK_n & CON & WCINH_n; IHIT_n known 1
      wca_e = ~((k[6] & ~k[7] & (k[0] & k[1] & k[2]) & k[3] & ~k[4] & ~k[5]) |
                (~k[6] & 1'b1 & (k[0] & k[1] & k[2]) & k[3] & ~k[4] & ~k[5]));
      chk_ctrl(1'b0, wca_e);
      fold(1'b0);
    end
    // restore idle inputs, resume the clock
    brk_n = 1; sw1 = 1; wcinh_n = 1; cyd = 0; fmiss = 0; lshadow = 0;
    rt_n = 1; dt_n = 1;
    #2;
    clk_en = 1;

    // ---- P2: fill 16 addresses through the refill-write path ----
    // Am9150 24-AUG fix: the used-bit RAM runs a 1024-step clear sweep at
    // POWER-UP (and after every CCLR_n falling edge); while it runs, reads
    // return 0 and external writes are DROPPED. Release CCLR_n first, then
    // wait the sweep out, or the 16 refill writes below never land and
    // every P3/P5 hit fails. The P0/P1 folds are unaffected (the 21F
    // output was already forced 0 there: previously by the CCLR_n gate,
    // now by the sweep), so the recorded golden checksums still hold.
    cclr_n = 1;
    repeat (1200) @(posedge sysclk);
    ecd_n  = 0;
    for (ai = 0; ai < 16; ai = ai + 1) begin
      ca = fill[ai]; cd_in = pat(fill[ai]); cpn_in = cpnpat(fill[ai]);
      rt_n = 0; dt_n = 1; hitn = 2'b11; cyd = 1;
      cyc;
      chk_ctrl(1'b0, 1'b0);      // refill write: WCA_n low
      chk_cd(16'h0000);          // SRAM output forced 0 while writing
      fold(1'b1);
      cyd = 0;
      cyc;
      chk_ctrl(1'b0, 1'b1);      // still a miss (HIT_n=11)
      chk_cd(UNGATED ? pat(fill[ai]) : 16'h0000);   // STALE-LINE TEETH
      chk_cpn(cpnpat(fill[ai]));
      fold(1'b1);
    end

    // ---- P3: hit/miss matrix per address ----
    for (ai = 0; ai < 16; ai = ai + 1) begin
      ca = fill[ai]; cd_in = pat(fill[ai]); cpn_in = cpnpat(fill[ai]);
      rt_n = 0; dt_n = 1; hitn = 2'b11; cwr = 0; cyd = 0;
      cyc;                       // sync-read: dor loads the line
      @(negedge sysclk);
      clk_en = 0;
      for (cbi = 0; cbi < 8; cbi = cbi + 1) begin
        hitn = cbi[1:0];
        cwr  = cbi[2];
        #2;
        hit_e = (cbi[1:0] == 2'b00) && !cbi[2];
        chk_ctrl(hit_e, 1'b1);
        chk_cd(UNGATED ? pat(fill[ai]) : (hit_e ? pat(fill[ai]) : 16'h0000));
        chk_cpn(cpnpat(fill[ai]));
        fold(1'b1);
      end
      // RT/DT variants at HIT_n=00, CWR=0
      hitn = 2'b00; cwr = 0; rt_n = 0; dt_n = 0;   // data read: OUBD path
      #2;
      chk_ctrl(1'b1, 1'b1);
      chk_cd(pat(fill[ai]));
      chk_cpn(cpnpat(fill[ai]));
      fold(1'b1);
      rt_n = 1; dt_n = 0;                          // write cycle: never HIT
      #2;
      chk_ctrl(1'b0, 1'b1);
      chk_cd(UNGATED ? pat(fill[ai]) : 16'h0000);
      chk_cpn(cpnpat(fill[ai]));
      fold(1'b1);
      rt_n = 0; dt_n = 1;
      #2;
      clk_en = 1;
    end

    // ---- P4: WCINH cache-inhibit: refill suppressed, miss drives 0 ----
    ca = 11'h155; cd_in = pat(11'h155); cpn_in = cpnpat(11'h155);
    rt_n = 0; dt_n = 1; hitn = 2'b11; cyd = 1; wcinh_n = 0;
    cyc;
    chk_ctrl(1'b0, 1'b1);        // WCA_n stays high: no refill
    chk_cd(UNGATED ? pat(11'h155) : 16'h0000);   // STALE-LINE TEETH
    chk_cpn(cpnpat(11'h155));
    fold(1'b1);
    cyd = 0; wcinh_n = 1; hitn = 2'b00;

    // ---- P5: used-bit lifecycle at 0x155 ----
    // a) fetch-hit; IHIT then blocks the fetch refill
    ca = 11'h155; cd_in = pat(11'h155); cpn_in = cpnpat(11'h155);
    rt_n = 0; dt_n = 1; hitn = 2'b00; cyd = 0;
    cyc;
    chk_ctrl(1'b1, 1'b1);
    chk_cd(pat(11'h155));        // hit: cached word in ALL modes
    chk_cpn(cpnpat(11'h155));
    fold(1'b1);
    uclk_event;                  // IHIT_reg <- 1
    #1;
    chk_ctrl(1'b1, 1'b1);
    fold(1'b1);
    cyd = 1;                     // fetch refill attempt
    cyc;
    chk_ctrl(1'b1, 1'b1);        // IHIT_n=0 blocks WCA on fetch
    chk_cd(pat(11'h155));
    fold(1'b1);
    cyd = 0;
    // b) write-with-hit clears the used bit -> stale fetch must MISS
    rt_n = 1; dt_n = 0;
    cyc;
    chk_ctrl(1'b0, 1'b1);        // write cycles never HIT
    fold(1'b1);
    uclk_event;                  // NUBI_reg <- 1 (clear on write-hit)
    #1;
    chk_ctrl(1'b0, 1'b1);
    fold(1'b1);
    cyd = 1; cd_in = 16'h600D; cpn_in = 14'h2AB3;
    cyc;                         // WCA write: data + used[0x155][OUBI]<-0
    chk_ctrl(1'b0, 1'b0);
    chk_cd(16'h0000);
    fold(1'b1);
    cyd = 0; rt_n = 0; dt_n = 1; // fetch read: used bit cleared -> MISS
    cyc;
    chk_ctrl(1'b0, 1'b1);
    chk_cd(UNGATED ? 16'h600D : 16'h0000);       // STALE-LINE TEETH
    chk_cpn(14'h2AB3);
    fold(1'b1);
    rt_n = 0; dt_n = 0;          // data read: OUBD still set -> HIT
    cyc;
    chk_ctrl(1'b1, 1'b1);
    chk_cd(16'h600D);
    fold(1'b1);

    // ---- P6: LFSR phase over the filled set ----
    for (k = 0; k < 800; k = k + 1) begin
      lfsr = (lfsr >> 1) ^ (lfsr[0] ? 32'hEDB88320 : 32'h0);
      cw = lfsr;
      lfsr = (lfsr >> 1) ^ (lfsr[0] ? 32'hEDB88320 : 32'h0);
      dw = lfsr;
      ca      = fill[cw[3:0]];
      hitn    = {cw[5], cw[4]};
      cwr     = cw[6];
      rt_n    = cw[7];
      dt_n    = cw[8];
      cyd     = (cw[10:9] == 2'b00);
      wcinh_n = (cw[12:11] == 2'b00) ? 1'b0 : 1'b1;
      ecd_n   = (cw[15:13] == 3'b000) ? 1'b1 : 1'b0;
      sw1     = cw[16];
      fmiss   = (cw[19:17] == 3'b000);
      lshadow = (cw[22:20] == 3'b000);
      brk_n   = (cw[25:23] == 3'b000) ? 1'b0 : 1'b1;
      cd_in   = dw[15:0];
      cpn_in  = dw[29:16];
      cyc;
      checks = checks + 1;
      if (^{hit, wca_n, cd_out, cpn_out} === 1'bx) begin
        errors = errors + 1;
        $display("FAIL lfsr[%0d]: undefined outputs", k);
      end
      fold(1'b1);
    end

    // final checksum vs gen_cache_golden.py
    checks = checks + 1;
    if (acc !== ACC_EXPECT) begin
      errors = errors + 1;
      $display("FAIL checksum: got %08h expected %08h", acc, ACC_EXPECT);
    end

    // Verdict. Expected: 1637 (see gen_cache_golden.py).
    if (errors == 0 && checks == 1637)
      $display("TB_RESULT: PASS (%0d checks)", checks);
    else
      $display("TB_RESULT: FAIL (%0d errors, %0d of 1637 checks)",
               errors, checks);
    $finish;
  end

endmodule

/**************************************************************************
** ND120 CPU - unit test                                                 **
** CACHE SUBSYSTEM COHERENCE BENCH                                       **
**                                                                       **
** DUT = CPU_MMU_CACHE_25 (sheet 25: data SRAMs 23F/24F, tag SRAMs       **
** 16F/20F, Am9150 used-bit RAM 21F, PAL 44402D UBITS) together with     **
** CPU_MMU_HIT_27 (sheet 27 comparators) and the three glue assigns      **
** copied from CPU_MMU_24.v:334-341 (WCA CPN gate, hit-CPN wired-OR,     **
** cache CPN feed). The bench models main memory and a DMA master        **
** beside the cache, and walks CPU-style fetch/read/write cycles         **
** through the pair, so the HIT decision is made from REAL stored tags   **
** and used bits, not from forced HIT_1_0_n levels like the sheet-only   **
** bench CPU_MMU_CACHE_25_tb.v.                                          **
**                                                                       **
** This bench targets the FIXED Shared/support/Am9150.v (24-AUG clear    **
** sweep): a falling edge of RESET_n starts a 1024-step write-port      **
** sweep that zeroes the whole used-bit array; the same sweep runs once  **
** at power-up (counter initializer) and scrubs the undefined cold       **
** state; while the sweep is active data_out reads 0 and external        **
** writes are dropped. Against the OLD model (RESET_n only gated         **
** data_out while low, array contents survived) the CCLR checks in T7    **
** FAIL - that model made the cache-clear command a no-op.               **
**                                                                       **
** CYCLE PROTOCOL (per microcycle, both build modes):                    **
**   set RT_n/DT_n/CA/PPN/CD_IN -> settle 3 sysclks (sync tag read) ->   **
**   sample HIT/CD_OUT -> UCLK event (PAL registers capture: NUBI/NUBD   **
**   write data for 21F, IHIT hit-history) -> CYD=1 (WCA window; a miss  **
**   or a CPU write pulls WCA_n low and the SRAMs write) -> CYD=0.       **
**                                                                       **
** THE CWR PIN IS REAL HERE (30-AUG-2026). CWR into the cache is no       **
** longer a bench register: PAL 44511A (sheet 34, 26H) is instantiated   **
** and its pin 19 drives the cache's CWR input, exactly as sheets 34/25   **
** wire it. Sheet 25 makes HIT with a 74S260 5-input NOR (USED~, HIT~1,   **
** HIT~0, CWR, gnd), so HIT needs that pin LOW on a read. The PAL model  **
** used to drive the pin as ~CWR (the listing names it /CWR): every read  **
** ran the full memory cycle and CACHE-1X0-A00 test 2 reported "DATA is  **
** taken FROM MEMORY when present in DATA CACHE" on the Nexys and in     **
** Verilator alike (29-AUG-2026, fault 2). With the bench driving CWR=0  **
** itself this bench could not see that. Now T3/T4/T7 (data read HITs)   **
** fail against the inverted pin - that is the regression guard. The     **
** bench pulses the PAL's CLK at the end of every cycle (TERM), which is  **
** what releases the CWR hold latch on the board.                        **
**                                                                       **
** WHAT MUST PASS:                                                       **
**   T0  power-up sweep: no hit while the cold-state scrub runs, and -   **
**       with tags/data SEEDED to match but no refill ever executed -    **
**       still no hit afterwards (the valid bits were scrubbed)          **
**   T1  cold fetch miss, refill (WCA_n low in the CYD window)           **
**   T2  fetch hit returns the cached word; IHIT blocks a re-refill      **
**   T3  data-read has its own used bit: first data read misses and      **
**       refills, then hits; the fetch used bit is KEPT (read-modify-    **
**       write of 21F through the PAL registers)                         **
**   T4  CPU write updates the line in place (write-through): the next   **
**       data read hits with the NEW word; the fetch used bit is         **
**       CLEARED by a write hit (PAL term RT_n*DT*HIT0*HIT1)             **
**   T6  KNOWN-HARDWARE-PROPERTY (faithful 1988 behaviour, not a         **
**       defect): a DMA write to main memory does not touch the cache -  **
**       there is no snoop path on sheets 24/25 - so a CPU read without  **
**       an intervening CCLR still HITS the PRE-DMA word. Software owns  **
**       coherence: CCLR after the transfer, or the page marked          **
**       cache-inhibited in the CILR RAM (WCINH).                        **
**   T7  CCLR WORKS: reads are dead while CCLR is low AND while the      **
**       clear sweep runs; after the sweep the previously-valid line     **
**       MISSES. Then a refill makes the line live again and the read    **
**       returns the post-DMA word - the coherence sequence SINTRAN      **
**       relies on. (These are the checks that FAIL on the old model.)   **
**   T8  FMISS forces a miss on a valid line and suppresses the refill   **
**   T9  WCINH_n low (cache-inhibited physical page) suppresses refill   **
**   T10 LSHADOW forces mismatch and suppresses refill                   **
**                                                                       **
** Tag/data arrays (TMM2018D) have no sweep; the bench zero-fills them   **
** hierarchically (bitstream init state) except the deliberately seeded  **
** T0 poison line, because X tags would X out the comparators in RTL     **
** sim.                                                                  **
**                                                                       **
** BUILD MODES (Makefile runs both):                                     **
**   plain          - PAL registers on posedge UCLK                      **
**   -DFPGA_FF_MODE - PAL registers on posedge sysclk + UCLK_EN          **
**                                                                       **
** Self-checking: prints TB_RESULT: PASS / FAIL (never silent).          **
**                                                                       **
** Run: make test-mmucache-dma   (CPU-BOARD-3202/circuit/sim)            **
**                                                                       **
** 24-AUG-2026                                                           **
** Ronny Hansen                                                          **
***************************************************************************/
`timescale 1ns / 1ps

module CPU_MMU_CACHE_DMA_tb;

  localparam integer EXPECTED_CHECKS = 44;   // +2 (30-AUG-2026): the CWR pin itself

  reg sysclk = 0;
  always #5 sysclk = ~sysclk;

  // ---- DUT inputs -------------------------------------------------------
  reg         sys_rst_n = 1;
  reg         brk_n = 1;
  reg  [10:0] ca = 0;
  reg         cclr_n = 1;
  // CWR comes from PAL 44511A pin 19 (see the header) - not a bench reg.
  reg         mreq_n   = 1;   // /MREQ into the PAL: low for the whole microcycle
  reg         pal_clk  = 0;   // CLK into the PAL: pulsed at cycle end (TERM)
  reg         pal_clk_en = 0; // its rise-aligned enable (FPGA_FF_MODE)
  wire        cwr;            // pin 19 as the cache sees it
  wire        cup_unused, lev0_unused;
  reg         cyd = 0;
  reg         dt_n = 1;
  reg         ecd_n = 0;      // cache data SRAMs selected (PAL 44306A ECD)
  reg         fmiss = 0;
  reg         lshadow = 0;
  reg         pd2 = 0;        // tag SRAM CS + PAL OE, always low on the 3202D
  reg         rt_n = 1;
  reg         sw1 = 1;        // cache ON (ND120_CORE.v ties SW1_CONSOLE high)
  reg         uclk = 0;
  reg         uclk_en = 0;
  reg         wcinh_n = 1;
  reg  [15:0] cd_in = 0;
  reg  [13:0] ppn = 0;        // physical page number of the current access

  wire [15:0] cd_out;
  wire [13:0] cache_cpn_out;
  wire        con, con_n, hit, wca_n, led1;
  wire        hit0_n, hit1_n;

  // ---- glue copied from CPU_MMU_24.v:334-341 ----------------------------
  // WCA_31 replacement: while WCA_n is low the PPN drives the CPN bus
  wire [13:0] wca_cpn = wca_n ? 14'b0 : ppn;
  // wired-OR of the WCA drive and the stored tag, into the comparators
  wire [13:0] hit_cpn_in = wca_cpn | cache_cpn_out;
  // the cache tag SRAM write data
  wire [13:0] cache_cpn_in = wca_cpn;

  CPU_MMU_HIT_27 hitdet (
      .PPN_23_10_IN(ppn),
      .CPN_23_10_IN(hit_cpn_in),
      .LSHADOW(lshadow),
      .FMISS(fmiss),
      .CON_n(con_n),
      .HIT0_n(hit0_n),
      .HIT1_n(hit1_n)
  );

`ifdef FPGA_FF_MODE
  localparam integer PAL_CE = 1;
`else
  localparam integer PAL_CE = 0;
`endif
  PAL_44511A_EN #(.USE_ENABLE(PAL_CE)) pal_26h (
      .sysclk(sysclk),
      .EN    (pal_clk_en),
      .CK    (pal_clk),
      .OE_n  (1'b0),          // PD1, always low on the 3202D
      .PIL0  (1'b0), .PIL1(1'b0), .PIL2(1'b0), .PIL3(1'b0),
      .CLK   (pal_clk),
      .MREQ_n(mreq_n),
      .WCA_n (wca_n),
      .CUP   (cup_unused),
      .CWR_n (cwr),           // pin 19 -> net CWR (sheet 34), into the sheet-25 NOR
      .LEV0  (lev0_unused)
  );

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
      .HIT_1_0_n  ({hit1_n, hit0_n}),
      .LSHADOW    (lshadow),
      .PD2        (pd2),
      .RT_n       (rt_n),
      .SW1_CONSOLE(sw1),
      .UCLK       (uclk),
      .UCLK_EN    (uclk_en),
      .WCINH_n    (wcinh_n),
      .CD_15_0_IN (cd_in),
      .CD_15_0_OUT(cd_out),
      .CPN_23_10_IN (cache_cpn_in),
      .CPN_23_10_OUT(cache_cpn_out),
      .CON  (con),
      .CON_n(con_n),
      .HIT  (hit),
      .WCA_n(wca_n),
      .LED1 (led1)
  );

  // ---- bench-side main memory (one 2K-word page per PPN under test) -----
  reg [15:0] memA[0:2047];  // physical page PPN_A
  reg [15:0] memB[0:2047];  // physical page PPN_B

  localparam [13:0] PPN_A = 14'h2A5;
  localparam [13:0] PPN_B = 14'h1153;
  localparam [10:0] C1 = 11'h155;
  localparam [10:0] C2 = 11'h3E7;
  localparam [15:0] W1 = 16'o123456;  // initial memory word at (PPN_A,C1)
  localparam [15:0] W2 = 16'o054321;  // CPU write data
  localparam [15:0] W3 = 16'o177001;  // DMA write data
  localparam [15:0] POISON = 16'o166666;  // seeded pre-scrub line data

  integer errors = 0;
  integer checks = 0;
  integer i;

  task chk(input [255:0] name, input [15:0] got, input [15:0] exp);
    begin
      checks = checks + 1;
      if (got !== exp) begin
        errors = errors + 1;
        $display("FAIL %0s: got=%06o exp=%06o (t=%0t)", name, got, exp, $time);
      end
    end
  endtask

  // one UCLK event, correct for both build modes
  task uclk_tick;
    begin
      @(negedge sysclk);
      uclk_en = 1'b1;
      uclk    = 1'b1;
      @(negedge sysclk);
      uclk_en = 1'b0;
      uclk    = 1'b0;
    end
  endtask

  task settle;
    begin
      repeat (3) @(posedge sysclk);
      @(negedge sysclk);
      #1;
    end
  endtask

  // wait out the Am9150 clear sweep (1024 steps) with margin
  task sweep_wait;
    begin
      repeat (1200) @(posedge sysclk);
    end
  endtask

  // one full CPU microcycle against the cache.
  //   rtn/dtn: RT_n / DT_n phase (fetch: 0/1, data read: 0/0, write: 1/0)
  //   addr/page: cache index and physical page
  //   memword: what main memory drives on CD during this cycle
  //   exp_hit: expected HIT level sampled before the UCLK event
  //   exp_wca: expected WCA_n level inside the CYD window
  task cycle(input rtn, input dtn, input [10:0] addr, input [13:0] page,
             input [15:0] memword, input exp_hit, input exp_wca,
             input [255:0] name);
    begin
      rt_n  = rtn;
      dt_n  = dtn;
      ca    = addr;
      ppn   = page;
      cd_in = memword;
      mreq_n = 1'b0;
      settle;
      chk(name, {15'b0, hit}, {15'b0, exp_hit});
      uclk_tick;
      cyd = 1'b1;
      #1;
      chk({name, "_wca"}, {15'b0, wca_n}, {15'b0, exp_wca});
      repeat (2) @(posedge sysclk);
      @(negedge sysclk);
      cyd  = 1'b0;
      rt_n = 1'b1;
      dt_n = 1'b1;
      // TERM: CLK rises, the PAL's CWR hold latch releases, MREQ goes away
      @(negedge sysclk);
      pal_clk_en = 1'b1;
      pal_clk    = 1'b1;
      @(negedge sysclk);
      pal_clk_en = 1'b0;
      mreq_n     = 1'b1;
      @(negedge sysclk);
      pal_clk    = 1'b0;
      @(posedge sysclk);
    end
  endtask

  reg [15:0] sampled_cd;

  initial begin
    $dumpfile("CPU_MMU_CACHE_DMA_tb.vcd");
    $dumpvars(0, CPU_MMU_CACHE_DMA_tb);

    for (i = 0; i < 2048; i = i + 1) begin
      memA[i] = 16'h00FF ^ i[15:0];
      memB[i] = 16'hB000 | i[15:0];
    end
    memA[C1] = W1;

    // ---- T0: power-up sweep scrubs the cold state ----------------------
    // The used bits (valid bits) live INSIDE the Am9150 array; its power-up
    // clear sweep is running right now, so no line may hit even though the
    // array contents started undefined.
    ca = C1; ppn = PPN_A; rt_n = 0; dt_n = 1;
    settle;
    chk("T0_NO_HIT_DURING_POWERUP_SWEEP", {15'b0, hit}, 16'h0000);
    rt_n = 1; dt_n = 1;

    // The tag/data TMM SRAMs have no sweep: zero-fill them (bitstream init
    // state) EXCEPT a deliberately seeded poison line at C1 whose tag
    // MATCHES the first access - only the scrubbed used bits keep it dead.
    for (i = 0; i < 2048; i = i + 1) begin
      dut.CHIP_23F.g_async.tmm_memory_array[i] = 8'b0;
      dut.CHIP_24F.g_async.tmm_memory_array[i] = 8'b0;
      dut.CHIP_16F.g_async.tmm_memory_array[i] = 8'b0;
      dut.CHIP_20F.g_async.tmm_memory_array[i] = 8'b0;
    end
    dut.CHIP_23F.g_async.tmm_memory_array[C1] = POISON[15:8];
    dut.CHIP_24F.g_async.tmm_memory_array[C1] = POISON[7:0];
    dut.CHIP_16F.g_async.tmm_memory_array[C1] = {2'b00, PPN_A[13:8]};
    dut.CHIP_20F.g_async.tmm_memory_array[C1] = PPN_A[7:0];

    sweep_wait;

    // settle the PAL registers (latch-mode PAL_44402D powers up X)
    uclk_tick;
    uclk_tick;

    // ---- T0b: seeded tags but scrubbed valid bits must NOT hit ---------
    ca = C1; ppn = PPN_A; rt_n = 0; dt_n = 1; cd_in = memA[C1];
    settle;
    chk("T0B_SEEDED_TAG_NO_HIT", {15'b0, hit}, 16'h0000);
    chk("T0B_CD_GATED_ZERO", cd_out, 16'h0000);
    rt_n = 1; dt_n = 1;

    // ---- T1: cold fetch miss + refill ----------------------------------
    cycle(1'b0, 1'b1, C1, PPN_A, memA[C1], 1'b0, 1'b0, "T1_FETCH_MISS");

    // ---- T2: fetch hit, IHIT blocks a second refill --------------------
    rt_n = 0; dt_n = 1; ca = C1; ppn = PPN_A; cd_in = memA[C1];
    settle;
    chk("T2_FETCH_HIT", {15'b0, hit}, 16'h0001);
    chk("T2_CD", cd_out, W1);
    uclk_tick;
    cyd = 1'b1; #1;
    chk("T2_NO_REFILL_wca", {15'b0, wca_n}, 16'h0001);
    @(negedge sysclk);
    cyd = 0; rt_n = 1; dt_n = 1;

    // ---- T3: data read has its own used bit ----------------------------
    cycle(1'b0, 1'b0, C1, PPN_A, memA[C1], 1'b0, 1'b0, "T3_DREAD_MISS");
    rt_n = 0; dt_n = 0; ca = C1; ppn = PPN_A; cd_in = memA[C1];
    settle;
    chk("T3_DREAD_HIT", {15'b0, hit}, 16'h0001);
    chk("T3_CD", cd_out, W1);
    // the pin itself: LOW on a plain read (sheet 25's NOR needs that)
    chk("T3_CWR_PIN_LOW_ON_READ", {15'b0, cwr}, 16'h0000);
    rt_n = 1; dt_n = 1;
    // the fetch used bit was KEPT across the data-read refill
    rt_n = 0; dt_n = 1; settle;
    chk("T3_FETCH_STILL_HITS", {15'b0, hit}, 16'h0001);
    rt_n = 1; dt_n = 1;

    // ---- T4: CPU write updates the line (write-through) ----------------
    memA[C1] = W2;
    // during the write's WCA window the pin must be HIGH (CWR = MREQ*WCA)
    // - checked inside the next cycle() through exp_hit=0; here we also
    // look at the pin directly right after the WCA pulse
    cycle(1'b1, 1'b0, C1, PPN_A, W2, 1'b0, 1'b0, "T4_WRITE");
    chk("T4_CWR_PIN_RELEASED_AFTER_TERM", {15'b0, cwr}, 16'h0000);
    rt_n = 0; dt_n = 0; ca = C1; ppn = PPN_A; cd_in = memA[C1];
    settle;
    chk("T4_DREAD_HIT_NEW", {15'b0, hit}, 16'h0001);
    chk("T4_CD_NEW", cd_out, W2);
    rt_n = 1; dt_n = 1;
    // a write hit clears the FETCH used bit (self-modifying-code guard)
    rt_n = 0; dt_n = 1; settle;
    chk("T4_FETCH_INVALIDATED", {15'b0, hit}, 16'h0000);
    rt_n = 1; dt_n = 1;
    // and the following fetch miss refills it again
    cycle(1'b0, 1'b1, C1, PPN_A, memA[C1], 1'b0, 1'b0, "T4_REFETCH_MISS");

    // ---- T6: DMA writes memory - no snoop, read without CCLR is stale --
    memA[C1] = W3;  // the DMA master writes main memory; no CPU cycle runs
    rt_n = 0; dt_n = 0; ca = C1; ppn = PPN_A; cd_in = memA[C1];
    settle;
    sampled_cd = cd_out;
    chk("T6_STALE_HIT", {15'b0, hit}, 16'h0001);
    chk("T6_STALE_DATA", sampled_cd, W2);
    checks = checks + 1;
    if (sampled_cd === W3) begin
      errors = errors + 1;
      $display("FAIL T6: cache returned the DMA data without a CCLR - a snoop/invalidate path appeared, update this bench");
    end else begin
      $display("KNOWN-HARDWARE-PROPERTY: DMA wrote %06o to memory; without a CCLR the CPU read HITS the cache and gets the pre-DMA %06o.", W3, sampled_cd);
      $display("KNOWN-HARDWARE-PROPERTY: the 1988 board has no snoop - software must issue CCLR after the transfer or mark the page cache-inhibited (CILR/WCINH). T7 proves the CCLR path.");
    end
    rt_n = 1; dt_n = 1;

    // ---- T7: CCLR clears the used bits (the fixed Am9150 sweep) --------
    rt_n = 0; dt_n = 0; ca = C1; ppn = PPN_A; cd_in = memA[C1];
    cclr_n = 0;
    settle;
    chk("T7_HIT_LOW_DURING_CCLR", {15'b0, hit}, 16'h0000);
    cclr_n = 1;
    settle;
    chk("T7_HIT_LOW_DURING_SWEEP", {15'b0, hit}, 16'h0000);
    sweep_wait;
    settle;
    chk("T7_MISS_AFTER_CCLR", {15'b0, hit}, 16'h0000);
    chk("T7_CD_GATED_ZERO", cd_out, 16'h0000);
    rt_n = 1; dt_n = 1;
    // refill and read back: the CPU now sees the post-DMA word - the
    // CCLR-then-reread sequence SINTRAN relies on works end to end
    cycle(1'b0, 1'b0, C1, PPN_A, memA[C1], 1'b0, 1'b0, "T7_REFILL_MISS");
    rt_n = 0; dt_n = 0; ca = C1; ppn = PPN_A; cd_in = memA[C1];
    settle;
    chk("T7_DREAD_HIT_FRESH", {15'b0, hit}, 16'h0001);
    chk("T7_CD_FRESH_DMA_DATA", cd_out, W3);
    rt_n = 1; dt_n = 1;

    // ---- T8: FMISS forces a miss on the (now valid) line ---------------
    fmiss = 1;
    rt_n = 0; dt_n = 0; ca = C1; ppn = PPN_A; cd_in = memA[C1];
    settle;
    chk("T8_FMISS_MISSES", {15'b0, hit}, 16'h0000);
    chk("T8_MEMWORD_PASSES", (hit ? cd_out : memA[C1]), W3);
    uclk_tick;
    cyd = 1; #1;
    chk("T8_NO_REFILL_wca", {15'b0, wca_n}, 16'h0001);
    @(negedge sysclk);
    cyd = 0; fmiss = 0; rt_n = 1; dt_n = 1;

    // ---- T9: WCINH_n (cache-inhibited page) blocks the refill ----------
    wcinh_n = 0;
    cycle(1'b0, 1'b1, C2, PPN_B, memB[C2], 1'b0, 1'b1, "T9_INHIBIT_MISS");
    wcinh_n = 1;
    // nothing was cached: still a miss, and now the refill goes through
    cycle(1'b0, 1'b1, C2, PPN_B, memB[C2], 1'b0, 1'b0, "T9_MISS_REFILL");
    rt_n = 0; dt_n = 1; ca = C2; ppn = PPN_B; cd_in = memB[C2];
    settle;
    chk("T9_HIT_AFTER", {15'b0, hit}, 16'h0001);
    chk("T9_CD", cd_out, memB[C2]);
    rt_n = 1; dt_n = 1;

    // ---- T10: LSHADOW forces mismatch and blocks the refill ------------
    lshadow = 1;
    rt_n = 0; dt_n = 1; ca = C1; ppn = PPN_A; cd_in = memA[C1];
    settle;
    chk("T10_SHADOW_MISSES", {15'b0, hit}, 16'h0000);
    uclk_tick;
    cyd = 1; #1;
    chk("T10_NO_REFILL_wca", {15'b0, wca_n}, 16'h0001);
    @(negedge sysclk);
    cyd = 0; lshadow = 0; rt_n = 1; dt_n = 1;

    // ---- verdict -------------------------------------------------------
    $display("-----------------------------------------------------");
    $display(" checks run : %0d (expected %0d)", checks, EXPECTED_CHECKS);
    $display(" failures   : %0d", errors);
    if (errors == 0 && checks == EXPECTED_CHECKS) begin
      $display("NOTE: PASS = CCLR clear sweep verified working; the T6 no-snoop staleness is a faithful hardware property, not a defect.");
      $display("TB_RESULT: PASS");
    end else begin
      if (checks != EXPECTED_CHECKS)
        $display("FAIL: check count %0d != expected %0d - vacuous or truncated run", checks, EXPECTED_CHECKS);
      $display("TB_RESULT: FAIL");
    end
    $finish;
  end

  // watchdog: never hang silently (two 1200-clk sweep waits included)
  initial begin
    #400000;
    $display("FAIL: watchdog timeout");
    $display("TB_RESULT: FAIL");
    $finish;
  end

endmodule

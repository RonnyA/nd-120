/****************************************************************************
** Cached-path testbench for nd_storage_engine + nd_storage_cache          **
**                                                                         **
** nd_storage_cache_tb.v exercises the directory on its own: it proves the **
** tag/LRU/eviction arithmetic but never moves a byte. THIS testbench      **
** proves the other half - that a cached client actually reads the right   **
** data through the whole chain, that a hit costs NO card traffic, and     **
** that an eviction really does force the next read to fetch again.        **
**                                                                         **
** Chain under test: nd_storage_engine (CACHE_MASK bit 0 set) + the real   **
** nd_storage_cache + the real sd_writer (in rd_mode, CMD17) + the         **
** behavioral sd_card_model + nds_mem_model as the region, at skewed       **
** clocks (clk_cpu ~23.04 MHz, clk_stor ~27.03 MHz).                       **
**                                                                         **
** Cache geometry is deliberately tiny - 2 sets x 2 ways = 4 lines - so    **
** eviction is reached in four reads instead of thousands. Set index is    **
** block[0]: even blocks land in set 0, odd blocks in set 1.               **
**                                                                         **
** Checks:                                                                 **
**   (a) cold read of block 0 fetches 4 sectors and returns the card's     **
**       bytes as client words (byte 2w = word bits 15:8)                  **
**   (b) re-read of block 0 is a HIT: ZERO sd_writer starts and ZERO       **
**       region WRITES, data still correct - the whole point of Phase 4    **
**   (c) block 2 (same set, second way) fetches; block 0 still hits, so    **
**       a cold pool fills both ways before evicting anything              **
**   (d) block 4 (same set, third distinct tag) evicts the LRU way. The    **
**       LRU is block 2 (block 0 was touched more recently), so block 0    **
**       still HITS (0 fetches) and block 2 MISSES (4 fetches). Checked    **
**       in that order on purpose - re-reading block 2 first would evict   **
**       block 0 and the survival check would be meaningless. This is the  **
**       check that the LRU ranks are used for real, not just computed.    **
**   (e) write-allocate: writing block 1 puts the bytes on the CARD and    **
**       publishes the line, so the following read of block 1 hits with    **
**       zero card traffic and returns the written words                   **
**   (f) write-through to a RESIDENT block (block 0): the card is updated  **
**       and the line still hits, now holding the NEW data - a stale hit   **
**       here would be the worst failure this cache can have               **
**   (g) out-of-range block on a cached client -> done+err, zero card and  **
**       zero region traffic (the range check runs before the lookup)      **
**   (h) the DIRECT client (client 1, not in CACHE_MASK) never raises a    **
**       cache lookup, and its read still returns the card's bytes         **
**                                                                         **
** Verdict: TB_RESULT: PASS / TB_RESULT: FAIL <reason>                     **
**                                                                         **
** Ronny Hansen                                                            **
*****************************************************************************/
`timescale 1ns / 1ps

module nd_storage_cachepath_tb;

  localparam STOR_HALF = 18.5;  // ~27.03 MHz
  localparam CPU_HALF  = 21.7;  // ~23.04 MHz
  localparam N         = 2;

  // client 0 = CACHED, client 1 = DIRECT
  localparam [7:0]  CMASK  = 8'b0000_0001;
  localparam [31:0] STAGE  = 32'd8;   // DIRECT staging line, clear of the pool
  localparam        C_WAYS = 2;
  localparam        C_SETS = 2;
  localparam        C_SIDX = 1;
  localparam [31:0] POOL   = 32'd0;   // pool = region blocks 0..3

  localparam [31:0] FIRST0 = 32'd8;   // client 0: sectors 8..39  (8 blocks)
  localparam [31:0] FIRST1 = 32'd40;  // client 1: sectors 40..47 (2 blocks)
  localparam NBLK0 = 8;
  localparam NBLK1 = 2;
  localparam [31:0] SZ0 = NBLK0 * 2048;
  localparam [31:0] SZ1 = NBLK1 * 2048;
  localparam [15:0] NB0 = NBLK0;
  localparam [15:0] NB1 = NBLK1;

  reg clk_stor = 0;
  always #STOR_HALF clk_stor = ~clk_stor;
  reg clk_cpu = 0;
  always #CPU_HALF clk_cpu = ~clk_cpu;

  reg rst_n = 0;

  // ------------------------------------------------------------- DUT wiring
  wire        mem_start_w, mem_we_w, mem_busy_w, mem_done_w;
  wire [19:0] mem_addr_w;
  wire [31:0] mem_wdata_w, mem_rdata_w;

  wire        mnt_start_w;
  wire [2:0]  mnt_client_w;

  reg  [N-1:0]    t_req = 0;
  reg  [N-1:0]    t_wr  = 0;
  reg  [15:0]     t_block0 = 0, t_block1 = 0;
  wire [N-1:0]    open_ok_w, open_err_w, busy_w, done_w, err_w, buf_we_w;
  wire [N*32-1:0] size_bytes_w;
  wire [N*10-1:0] buf_addr_w;
  wire [N*16-1:0] buf_wdata_w;
  reg  [15:0]     rd0 = 0, rd1 = 0;

  wire        eng_wd_err_w;
  wire        sdw_start_w, sdw_busy_w, sdw_done_w, sdw_err_w, sdw_rd_mode_w;
  wire [31:0] sdw_sector_w;
  wire [8:0]  sdw_burst_len_w, sdw_rd_addr_w, sdw_rx_addr_w;
  wire [7:0]  sdw_rd_data_w, sdw_rx_data_w;
  wire        sdw_rx_we_w;

  wire        c_lookup_req_w, c_lookup_done_w, c_lookup_hit_w;
  wire [2:0]  c_lookup_client_w, c_lookup_way_w;
  wire [15:0] c_lookup_block_w;
  wire [10:0] c_lookup_line_w;
  wire        c_alloc_req_w, c_alloc_done_w;
  wire [2:0]  c_alloc_client_w, c_alloc_way_w;
  wire [15:0] c_alloc_block_w;

  nd_storage_engine #(
      .N_CLIENTS     (N),
      .WD_MAX        (32'd200_000),
      .CACHE_MASK    (CMASK),
      .STAGE_BASE_BLK(STAGE)
  ) dut (
      .clk_stor  (clk_stor),
      .rst_stor_n(rst_n),
      .clk_cpu   (clk_cpu),
      .rst_cpu_n (rst_n),

      .mem_start(mem_start_w),
      .mem_we   (mem_we_w),
      .mem_addr (mem_addr_w),
      .mem_wdata(mem_wdata_w),
      .mem_rdata(mem_rdata_w),
      .mem_busy (mem_busy_w),
      .mem_done (mem_done_w),

      .mnt_start (mnt_start_w),
      .mnt_client(mnt_client_w),
      .mnt_done  (1'b0),
      .mnt_err   (1'b0),

      .open_ok_stor   ({N{1'b1}}),
      .open_err_stor  ({N{1'b0}}),
      .size_bytes_stor({SZ1, SZ0}),
      .n_blocks       ({NB1, NB0}),
      .first_sector   ({FIRST1, FIRST0}),
      // Zero-hop FAT-walk geometry (64 KB clusters, first_cluster=2):
      // resolved LBAs equal the old contiguity arithmetic of this bench.
      .first_cluster  ({28'd2, 28'd2}),
      .fat_spc        (8'd128),
      .fat0_sector    (32'd0),
      .fat_is_fat32   (1'b1),

      .sdw_start    (sdw_start_w),
      .sdw_sector   (sdw_sector_w),
      .sdw_busy     (sdw_busy_w),
      .sdw_done     (sdw_done_w),
      .sdw_err      (sdw_err_w),
      .sdw_rd_addr  (sdw_rd_addr_w),
      .sdw_rd_data  (sdw_rd_data_w),
      .sdw_rd_mode  (sdw_rd_mode_w),
      .sdw_burst_len(sdw_burst_len_w),
      .sdw_rx_we    (sdw_rx_we_w),
      .sdw_rx_addr  (sdw_rx_addr_w),
      .sdw_rx_data  (sdw_rx_data_w),

      .cache_lookup_req   (c_lookup_req_w),
      .cache_lookup_client(c_lookup_client_w),
      .cache_lookup_block (c_lookup_block_w),
      .cache_lookup_done  (c_lookup_done_w),
      .cache_lookup_hit   (c_lookup_hit_w),
      .cache_lookup_way   (c_lookup_way_w),
      .cache_lookup_line  (c_lookup_line_w),
      .cache_alloc_req    (c_alloc_req_w),
      .cache_alloc_client (c_alloc_client_w),
      .cache_alloc_block  (c_alloc_block_w),
      .cache_alloc_way    (c_alloc_way_w),
      .cache_alloc_done   (c_alloc_done_w),

      .eng_wd_err(eng_wd_err_w),

      .open_req  ({N{1'b0}}),
      .open_ok   (open_ok_w),
      .open_err  (open_err_w),
      .size_bytes(size_bytes_w),
      .req       (t_req),
      .wr        (t_wr),
      .block     ({t_block1, t_block0}),
      .busy      (busy_w),
      .done      (done_w),
      .err       (err_w),
      .buf_addr  (buf_addr_w),
      .buf_wdata (buf_wdata_w),
      .buf_we    (buf_we_w),
      .buf_rdata ({rd1, rd0})
  );

  nd_storage_cache #(
      .WAYS(C_WAYS), .SETS(C_SETS), .SETIDX(C_SIDX),
      .POOL_BASE_BLK(POOL), .BLKW(16)
  ) u_cache (
      .clk(clk_stor), .rst_n(rst_n),
      .lookup_req   (c_lookup_req_w),
      .lookup_client(c_lookup_client_w),
      .lookup_block (c_lookup_block_w),
      .lookup_done  (c_lookup_done_w),
      .lookup_hit   (c_lookup_hit_w),
      .lookup_way   (c_lookup_way_w),
      .lookup_line  (c_lookup_line_w),
      .alloc_req    (c_alloc_req_w),
      .alloc_client (c_alloc_client_w),
      .alloc_block  (c_alloc_block_w),
      .alloc_way    (c_alloc_way_w),
      .alloc_done   (c_alloc_done_w),
      .inval_req(1'b0), .inval_client(3'd0), .inval_done()
  );

  nds_mem_model #(
      .MEM_WORDS(65536)
  ) u_mem (
      .clk  (clk_stor),
      .rst_n(rst_n),
      .start(mem_start_w),
      .we   (mem_we_w),
      .addr (mem_addr_w),
      .wdata(mem_wdata_w),
      .rdata(mem_rdata_w),
      .busy (mem_busy_w),
      .done (mem_done_w)
  );

  // ------------------------------------------------------------- SD side
  wire sd_clk, sd_cmd, sd_dat0;
  wire wr_cmd_o, wr_cmd_oe, wr_dat0_o, wr_dat0_oe;
  wire cm_cmd_o, cm_cmd_oe, cm_dat0_o, cm_dat0_oe;

  sd_writer #(
      .CLKDIV(8'd2)
  ) u_wr (
      .clk       (clk_stor),
      .rst_n     (rst_n),
      .sd_clk_o  (sd_clk),
      .sd_cmd_i  (sd_cmd),
      .sd_cmd_o  (wr_cmd_o),
      .sd_cmd_oe (wr_cmd_oe),
      .sd_dat0_i (sd_dat0),
      .sd_dat0_o (wr_dat0_o),
      .sd_dat0_oe(wr_dat0_oe),
      .start     (sdw_start_w),
      .rd_mode   (sdw_rd_mode_w),
      .sector    (sdw_sector_w),
      .busy      (sdw_busy_w),
      .done      (sdw_done_w),
      .err       (sdw_err_w),
      .burst_len (sdw_burst_len_w),
      .rca       (16'd0),        // 1-bit engine here: rca is unused
      .use_4bit  (1'b0),
      .width_hold(1'b0),
      .block_next(),
      .rd_addr   (sdw_rd_addr_w),
      .rd_data   (sdw_rd_data_w),
      .rx_we     (sdw_rx_we_w),
      .rx_addr   (sdw_rx_addr_w),
      .rx_data   (sdw_rx_data_w)
  );

  assign sd_cmd  = wr_cmd_oe  ? wr_cmd_o  : (cm_cmd_oe  ? cm_cmd_o  : 1'b1);
  assign sd_dat0 = wr_dat0_oe ? wr_dat0_o : (cm_dat0_oe ? cm_dat0_o : 1'b1);

  sd_card_model #(
      .IMAGE           ("nds_cache_test.img"),
      .MAX_BYTES       (131072),
      .LEGAL_MIN_SECTOR(FIRST0)
  ) card (
      .sd_clk   (sd_clk),
      .sd_cmd_i (sd_cmd),  .sd_cmd_o (cm_cmd_o),  .sd_cmd_oe (cm_cmd_oe),
      .sd_dat0_i(sd_dat0), .sd_dat0_o(cm_dat0_o), .sd_dat0_oe(cm_dat0_oe),
      .sd_dat1_i(1'b1), .sd_dat1_o(), .sd_dat1_oe(),
      .sd_dat2_i(1'b1), .sd_dat2_o(), .sd_dat2_oe(),
      .sd_dat3_i(1'b1), .sd_dat3_o(), .sd_dat3_oe()
  );

  // ------------------------------------------------------------- client bufs
  reg [15:0] cbuf0[0:1023];
  reg [15:0] cbuf1[0:1023];
  always @(posedge clk_cpu) begin
    if (buf_we_w[0]) cbuf0[buf_addr_w[9:0]] <= buf_wdata_w[15:0];
    if (buf_we_w[1]) cbuf1[buf_addr_w[19:10]] <= buf_wdata_w[31:16];
    rd0 <= cbuf0[buf_addr_w[9:0]];
    rd1 <= cbuf1[buf_addr_w[19:10]];
  end

  // ------------------------------------------------------------- patterns
  // What the card holds for client c, block b, client word w. Distinct per
  // (c,b,w) so a wrong line, wrong block or wrong client shows up as data.
  function [15:0] cardpat(input integer c, input integer b, input integer w);
    reg [31:0] t;
    begin
      t = c * 32'h9E37 + b * 32'h1741 + w * 97 + 13;
      cardpat = t[15:0];
    end
  endfunction

  // The words a WRITE puts into the client buffer (different from cardpat so
  // a write that never reaches the card cannot masquerade as a pass).
  function [15:0] wrpat(input integer b, input integer w);
    reg [31:0] t;
    begin
      t = b * 32'h2B3D + w * 811 + 32'h55AA;
      wrpat = t[15:0];
    end
  endfunction

  // ------------------------------------------------------------- monitors
  integer errors = 0;
  reg     last_err0 = 0, last_err1 = 0;
  reg [N-1:0] done_q = 0;
  integer sdw_starts = 0, mem_starts = 0, mem_writes = 0;
  integer lookups_c1 = 0;

  always @(posedge clk_cpu) begin
    done_q <= done_w;
    if (done_w[0]) last_err0 = err_w[0];
    if (done_w[1]) last_err1 = err_w[1];
  end

  always @(posedge clk_stor) begin
    if (sdw_start_w) sdw_starts = sdw_starts + 1;
    if (mem_start_w) begin
      mem_starts = mem_starts + 1;
      if (mem_we_w) mem_writes = mem_writes + 1;
    end
    // (h): the DIRECT client must never consult the directory
    if (c_lookup_req_w && c_lookup_client_w == 3'd1) lookups_c1 = lookups_c1 + 1;
  end

  // ------------------------------------------------------------- helpers
  integer sdw_snap, memw_snap, mems_snap;
  task snap;
    begin
      sdw_snap  = sdw_starts;
      memw_snap = mem_writes;
      mems_snap = mem_starts;
    end
  endtask

  task do_op(input integer c, input [15:0] blk, input wrbit);
    integer guard;
    begin
      @(posedge clk_cpu);
      if (c == 0) begin
        t_req[0] <= 1'b1; t_wr[0] <= wrbit; t_block0 <= blk;
      end else begin
        t_req[1] <= 1'b1; t_wr[1] <= wrbit; t_block1 <= blk;
      end
      @(posedge clk_cpu);
      t_req <= 2'b00;
      guard = 0;
      while (!busy_w[c] && guard < 100) begin
        @(posedge clk_cpu); guard = guard + 1;
      end
      if (!busy_w[c]) begin
        $display("TB_RESULT: FAIL client %0d op never went busy", c);
        $finish;
      end
      guard = 0;
      while (busy_w[c] && guard < 5_000_000) begin
        @(posedge clk_cpu); guard = guard + 1;
      end
      if (busy_w[c]) begin
        $display("TB_RESULT: FAIL client %0d op hung", c);
        $finish;
      end
      repeat (4) @(posedge clk_cpu);
    end
  endtask

  // sd_writer starts since the last snap() must equal want (4 = a fetch of
  // the four sectors of a block, 0 = served from the cache)
  task expect_fetch(input [511:0] what, input integer want);
    begin
      if (sdw_starts - sdw_snap !== want) begin
        $display("FAIL: %0s: %0d card sectors (want %0d)", what,
                 sdw_starts - sdw_snap, want);
        errors = errors + 1;
      end
    end
  endtask

  task expect_no_region_write(input [511:0] what);
    begin
      if (mem_writes !== memw_snap) begin
        $display("FAIL: %0s: %0d region writes (want 0)", what,
                 mem_writes - memw_snap);
        errors = errors + 1;
      end
    end
  endtask

  // the client buffer holds the card's bytes for (c, blk)
  task check_client_card(input integer c, input [15:0] blk);
    integer w;
    reg [15:0] got, exp;
    begin
      for (w = 0; w < 1024; w = w + 1) begin
        exp = cardpat(c, blk, w);
        got = (c == 0) ? cbuf0[w] : cbuf1[w];
        if (got !== exp) begin
          if (errors < 10)
            $display("FAIL: client %0d blk %0d word %0d: got %04x want %04x",
                     c, blk, w, got, exp);
          errors = errors + 1;
        end
      end
    end
  endtask

  // the client buffer holds what a WRITE of blk put there
  task check_client_wr(input [15:0] blk);
    integer w;
    begin
      for (w = 0; w < 1024; w = w + 1)
        if (cbuf0[w] !== wrpat(blk, w)) begin
          if (errors < 10)
            $display("FAIL: read-back blk %0d word %0d: got %04x want %04x",
                     blk, w, cbuf0[w], wrpat(blk, w));
          errors = errors + 1;
        end
    end
  endtask

  // the CARD image of client 0 block blk equals the written pattern
  task check_card_wr(input [15:0] blk);
    integer k;
    reg [15:0] wv;
    reg [7:0]  got, exp;
    begin
      for (k = 0; k < 2048; k = k + 1) begin
        wv  = wrpat(blk, k / 2);
        exp = (k % 2 == 1) ? wv[7:0] : wv[15:8];
        got = card.mem[(FIRST0 + {16'd0, blk} * 4) * 512 + k];
        if (got !== exp) begin
          if (errors < 10)
            $display("FAIL: card blk %0d byte %0d: got %02x want %02x",
                     blk, k, got, exp);
          errors = errors + 1;
        end
      end
    end
  endtask

  task fill_cbuf0_wr(input [15:0] blk);
    integer w;
    begin
      for (w = 0; w < 1024; w = w + 1) cbuf0[w] = wrpat(blk, w);
    end
  endtask

  task poison_cbuf0;
    integer w;
    begin
      for (w = 0; w < 1024; w = w + 1) cbuf0[w] = 16'hDEAD;
    end
  endtask

  // ------------------------------------------------------------- test
  integer b, w;
  reg [15:0] pw;
  initial begin
    // Lay the card pattern down AFTER sd_card_model's own $fread at time 0,
    // so this is not a race against it.
    repeat (2) @(posedge clk_stor);
    for (b = 0; b < NBLK0; b = b + 1)
      for (w = 0; w < 1024; w = w + 1) begin
        pw = cardpat(0, b, w);
        card.mem[(FIRST0 + b * 4) * 512 + 2 * w]     = pw[15:8];
        card.mem[(FIRST0 + b * 4) * 512 + 2 * w + 1] = pw[7:0];
      end
    for (b = 0; b < NBLK1; b = b + 1)
      for (w = 0; w < 1024; w = w + 1) begin
        pw = cardpat(1, b, w);
        card.mem[(FIRST1 + b * 4) * 512 + 2 * w]     = pw[15:8];
        card.mem[(FIRST1 + b * 4) * 512 + 2 * w + 1] = pw[7:0];
      end

    repeat (8) @(posedge clk_stor);
    rst_n = 1;
    repeat (50) @(posedge clk_cpu);

    // ---- (a) cold read of block 0 --------------------------------------
    poison_cbuf0;
    snap;
    do_op(0, 16'd0, 1'b0);
    if (last_err0 !== 1'b0) begin
      $display("FAIL: cold read blk 0 returned err"); errors = errors + 1;
    end
    expect_fetch("cold read blk 0", 4);
    check_client_card(0, 16'd0);

    // ---- (b) re-read of block 0 is a HIT --------------------------------
    poison_cbuf0;
    snap;
    do_op(0, 16'd0, 1'b0);
    expect_fetch("hit re-read blk 0", 0);
    expect_no_region_write("hit re-read blk 0");
    check_client_card(0, 16'd0);
    $display("hit proven: blk 0 re-read served with zero card sectors");

    // ---- (c) block 2 fills the second way; block 0 still hits -----------
    poison_cbuf0;
    snap;
    do_op(0, 16'd2, 1'b0);
    expect_fetch("cold read blk 2", 4);
    check_client_card(0, 16'd2);

    poison_cbuf0;
    snap;
    do_op(0, 16'd0, 1'b0);
    expect_fetch("blk 0 after blk 2 (both ways valid)", 0);
    check_client_card(0, 16'd0);

    // ---- (d) block 4 evicts the LRU way, which must be block 2 ----------
    poison_cbuf0;
    snap;
    do_op(0, 16'd4, 1'b0);
    expect_fetch("cold read blk 4", 4);
    check_client_card(0, 16'd4);

    // Order matters: check the SURVIVOR first. Set 0 now holds {blk 0, blk 4}
    // with blk 4 most recent, so re-reading blk 2 first would evict blk 0 and
    // the survival check below would be testing the wrong thing.
    poison_cbuf0;
    snap;
    do_op(0, 16'd0, 1'b0);
    expect_fetch("blk 0 after eviction (must still HIT)", 0);
    check_client_card(0, 16'd0);

    poison_cbuf0;
    snap;
    do_op(0, 16'd2, 1'b0);
    expect_fetch("blk 2 after eviction (must MISS)", 4);
    check_client_card(0, 16'd2);
    $display("eviction proven: blk 4 evicted blk 2 (the LRU way), not blk 0");

    // ---- (e) write-allocate on block 1 ----------------------------------
    fill_cbuf0_wr(16'd1);
    snap;
    do_op(0, 16'd1, 1'b1);
    if (last_err0 !== 1'b0) begin
      $display("FAIL: write blk 1 returned err"); errors = errors + 1;
    end
    expect_fetch("write blk 1 (4 CMD24, no fetch)", 4);
    check_card_wr(16'd1);

    poison_cbuf0;
    snap;
    do_op(0, 16'd1, 1'b0);
    expect_fetch("read after write-allocate blk 1", 0);
    check_client_wr(16'd1);
    $display("write-allocate proven: blk 1 read back from the cache");

    // ---- (f) write-through to a RESIDENT block (block 0) ----------------
    fill_cbuf0_wr(16'd0);
    snap;
    do_op(0, 16'd0, 1'b1);
    if (last_err0 !== 1'b0) begin
      $display("FAIL: write blk 0 returned err"); errors = errors + 1;
    end
    expect_fetch("write-through blk 0", 4);
    check_card_wr(16'd0);

    poison_cbuf0;
    snap;
    do_op(0, 16'd0, 1'b0);
    expect_fetch("read after write-through blk 0", 0);
    check_client_wr(16'd0);   // NEW data, not the stale cardpat line
    $display("write-through proven: resident blk 0 hit returns the NEW data");

    // ---- (g) out-of-range block on a cached client ----------------------
    snap;
    do_op(0, NB0, 1'b0);
    if (last_err0 !== 1'b1) begin
      $display("FAIL: out-of-range read did not return err"); errors = errors + 1;
    end
    expect_fetch("out-of-range read", 0);
    if (mem_starts !== mems_snap) begin
      $display("FAIL: out-of-range read touched the region (%0d pulses)",
               mem_starts - mems_snap);
      errors = errors + 1;
    end

    // ---- (h) the DIRECT client is untouched by the cache ----------------
    snap;
    do_op(1, 16'd1, 1'b0);
    if (last_err1 !== 1'b0) begin
      $display("FAIL: DIRECT client read returned err"); errors = errors + 1;
    end
    expect_fetch("DIRECT client read", 4);
    check_client_card(1, 16'd1);
    if (lookups_c1 !== 0) begin
      $display("FAIL: the DIRECT client raised %0d cache lookups", lookups_c1);
      errors = errors + 1;
    end

    // ---- card model health ---------------------------------------------
    if (card.crc_errors !== 0) begin
      $display("FAIL: %0d CMD CRC7 errors", card.crc_errors); errors = errors + 1;
    end
    if (card.wr_crc_errors !== 0) begin
      $display("FAIL: %0d data CRC16 errors", card.wr_crc_errors); errors = errors + 1;
    end
    if (card.illegal_writes !== 0) begin
      $display("FAIL: %0d writes below sector %0d", card.illegal_writes, FIRST0);
      errors = errors + 1;
    end
    if (eng_wd_err_w !== 1'b0) begin
      $display("FAIL: engine watchdog fired"); errors = errors + 1;
    end

    if (errors == 0)
      $display("TB_RESULT: PASS (cached path: fill, hit, LRU eviction, write-allocate, write-through)");
    else $display("TB_RESULT: FAIL %0d errors", errors);
    $finish;
  end

  initial begin
    #400_000_000;  // 400 ms absolute watchdog
    $display("TB_RESULT: FAIL absolute watchdog");
    $finish;
  end

endmodule

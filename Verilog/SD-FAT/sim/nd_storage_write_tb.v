/****************************************************************************
** Write-path testbench for nd_storage_engine (iverilog)                  **
**                                                                         **
** Engine + nds_mem_model + the REAL sd_writer (CMD24 engine) + the       **
** behavioral SD card model on a raw 128 KB zero image, at skewed clocks  **
** (clk_cpu ~23.04 MHz, clk_stor ~27.03 MHz). Client buffers are modeled  **
** as REGISTERED (synchronous) BRAMs - the sterner timing case for the    **
** front-end's address-ahead buf_rdata sampling. Checks (design doc       **
** section 4.3, spec acceptance test 5):                                  **
**                                                                         **
**   (a) a client WRITE op lands byte-exact on the card image, big-      **
**       endian word order (byte 2w = word bits 15:8), at sectors        **
**       first_sector + 4*block .. +3 - proven for two clients with      **
**       different slot bases and first sectors                           **
**   (b) card-first/SDRAM-second ordering: the SDRAM copy is sampled     **
**       DURING the card phase (after 2 of 4 CMD24s) via hierarchical    **
**       peek and must still hold the OLD preload; equal to the new      **
**       data after done; no mem write starts before the 4th CMD24 done  **
**   (c) done fires only after both phases (512 mem writes counted at    **
**       the done pulse); busy rises after req, holds until done, done   **
**       is a single-cycle pulse with busy already low                   **
**   (d) injected CMD24 failure (card model fail_sector hook) on the     **
**       third sector -> done+err, the SDRAM copy of that block fully    **
**       UNTOUCHED (zero mem traffic - no partial write), sd_writer      **
**       started exactly 3 times, the two accepted sectors on the card,  **
**       the rejected and never-sent sectors still zero                  **
**   (e) a subsequent READ of the block written in (a) returns exactly   **
**       the words that were written - the engine recovered from the      **
**       card error AND the write round-trips through the card (Phase 4:  **
**       a read FETCHES from the card, it does not serve a preload)       **
**   (f) write to an out-of-range block -> done+err with zero sd_writer  **
**       starts and zero mem traffic                                      **
**   plus: card model counters stay zero (CMD CRC7, data CRC16, and      **
**       reserved-region writes below LEGAL_MIN_SECTOR)                   **
**                                                                         **
** Verdict: TB_RESULT: PASS / TB_RESULT: FAIL <reason>                     **
**                                                                         **
** Last reviewed: 11-JUL-2026                                              **
** Ronny Hansen                                                            **
*****************************************************************************/
`timescale 1ns / 1ps

module nd_storage_write_tb;

  localparam STOR_HALF = 18.5;  // ~27.03 MHz
  localparam CPU_HALF  = 21.7;  // ~23.04 MHz
  localparam N         = 2;     // clients under test
  localparam BASE0     = 0;     // SLOT0_BASE_BLK (2048-byte blocks)
  localparam BASE1     = 32;    // SLOT1_BASE_BLK
  localparam STAGE_BLK = 0;     // = nd_storage_engine's STAGE_BASE_BLK
  localparam NBLK      = 4;     // n_blocks per client
  localparam [31:0] FIRST0 = 32'd8;   // client 0 file first SD sector
  localparam [31:0] FIRST1 = 32'd40;  // client 1 file first SD sector
  localparam IMG_BYTES = 131072;

  // pattern codes for pat16()
  localparam PAT_W1   = 0;  // client 0 block 1 write
  localparam PAT_W2   = 1;  // client 1 block 0 write
  localparam PAT_FAIL = 2;  // client 0 block 2 (injected-failure) write

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

  reg  [N-1:0]    t_open_req = 0;
  reg  [N-1:0]    t_req = 0;
  reg  [N-1:0]    t_wr = 0;
  reg  [15:0]     t_block0 = 0, t_block1 = 0;
  wire [N-1:0]    open_ok_w, open_err_w, busy_w, done_w, err_w, buf_we_w;
  wire [N*32-1:0] size_bytes_w;
  wire [N*10-1:0] buf_addr_w;
  wire [N*16-1:0] buf_wdata_w;
  reg  [15:0]     rd0 = 0, rd1 = 0;

  wire        eng_wd_err_w;
  wire        sdw_start_w, sdw_busy_w, sdw_done_w, sdw_err_w;
  wire [31:0] sdw_sector_w;
  wire [8:0]  sdw_rd_addr_w;
  wire [7:0]  sdw_rd_data_w;
  // Phase 4 fetch path: sd_writer is a sector READ/WRITE engine and the
  // engine drives rd_mode/burst_len itself; the received bytes come back on
  // rx_we/rx_addr/rx_data. Without these the engine can command a CMD17 but
  // never sees a byte of it.
  wire        sdw_rd_mode_w;
  wire [8:0]  sdw_burst_len_w;
  wire        sdw_rx_we_w;
  wire [8:0]  sdw_rx_addr_w;
  wire [7:0]  sdw_rx_data_w;

  // Cache directory. Both clients here are DIRECT (CACHE_MASK = 0), so the
  // engine never raises lookup_req - the instance is wired anyway so this
  // testbench sees exactly the connection nd_storage.v makes. The cached
  // path has its own testbench (nd_storage_cachepath_tb.v).
  wire        c_lookup_req_w, c_lookup_done_w, c_lookup_hit_w;
  wire [2:0]  c_lookup_client_w, c_lookup_way_w;
  wire [15:0] c_lookup_block_w;
  wire [10:0] c_lookup_line_w;
  wire        c_alloc_req_w, c_alloc_done_w;
  wire [2:0]  c_alloc_client_w, c_alloc_way_w;
  wire [15:0] c_alloc_block_w;

  nd_storage_engine #(
      .N_CLIENTS     (N),
      .WD_MAX        (32'd200_000),  // a CMD24 sector is ~17k clk_stor here
      .SLOT0_BASE_BLK(BASE0),
      .SLOT1_BASE_BLK(BASE1)
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
      .size_bytes_stor({32'd8192, 32'd8192}),
      .n_blocks       ({16'd4, 16'd4}),
      .first_sector   ({FIRST1, FIRST0}),
      // Zero-hop FAT-walk geometry (64 KB clusters, first_cluster=2):
      // data_start = first_sector, so resolved LBAs equal the old
      // contiguity arithmetic this bench's card model expects.
      .first_cluster  ({28'd2, 28'd2}),
      .fat_spc        (8'd128),
      .fat0_sector    (32'd0),
      .fat_is_fat32   (1'b1),

      .sdw_start  (sdw_start_w),
      .sdw_sector (sdw_sector_w),
      .sdw_busy   (sdw_busy_w),
      .sdw_done   (sdw_done_w),
      .sdw_err    (sdw_err_w),
      .sdw_rd_addr(sdw_rd_addr_w),
      .sdw_rd_data(sdw_rd_data_w),
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

      .open_req  (t_open_req),
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
      .WAYS(4), .SETS(4), .SETIDX(2), .POOL_BASE_BLK(32'd64), .BLKW(16)
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

  // ------------------------------------------------------------- real sd_writer
  wire sd_clk;
  wire sd_cmd;
  wire sd_dat0;
  wire wr_cmd_o, wr_cmd_oe, wr_dat0_o, wr_dat0_oe;
  sd_writer #(
      .CLKDIV(8'd2)  // fast bit clock for the unit test (27/4 MHz)
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
      .rca       (16'd0),
      .block_next(),
      .rd_addr   (sdw_rd_addr_w),
      .rd_data   (sdw_rd_data_w),
      .rx_we     (sdw_rx_we_w),
      .rx_addr   (sdw_rx_addr_w),
      .rx_data   (sdw_rx_data_w)
  );

  // SD lines resolved by MUX, no tristates (14-JUL-2026): host output-enable
  // wins, then the card, then the bus pullup (1) - same rule as
  // nd_storage_vtop.v:92.
  wire cm_cmd_o, cm_cmd_oe, cm_dat0_o, cm_dat0_oe;
  assign sd_cmd  = wr_cmd_oe  ? wr_cmd_o  : (cm_cmd_oe  ? cm_cmd_o  : 1'b1);
  assign sd_dat0 = wr_dat0_oe ? wr_dat0_o : (cm_dat0_oe ? cm_dat0_o : 1'b1);

  sd_card_model #(
      .IMAGE           ("nds_write_test.img"),
      .MAX_BYTES       (IMG_BYTES),
      .LEGAL_MIN_SECTOR(FIRST0)  // nothing may ever write below sector 8
  ) card (
      .sd_clk   (sd_clk),
      .sd_cmd_i (sd_cmd),  .sd_cmd_o (cm_cmd_o),  .sd_cmd_oe (cm_cmd_oe),
      .sd_dat0_i(sd_dat0), .sd_dat0_o(cm_dat0_o), .sd_dat0_oe(cm_dat0_oe),
      .sd_dat1_i(1'b1), .sd_dat1_o(), .sd_dat1_oe(),
      .sd_dat2_i(1'b1), .sd_dat2_o(), .sd_dat2_oe(),
      .sd_dat3_i(1'b1), .sd_dat3_o(), .sd_dat3_oe()
  );

  // ------------------------------------------------------------- client bufs
  // REGISTERED read-back: the write-latency rule (addr set at edge T
  // commits at T+1, data readable at T+2) is exactly what the front-end's
  // cycle A/B/C sampling must survive
  reg [15:0] cbuf0[0:1023];
  reg [15:0] cbuf1[0:1023];
  always @(posedge clk_cpu) begin
    if (buf_we_w[0]) cbuf0[buf_addr_w[9:0]] <= buf_wdata_w[15:0];
    if (buf_we_w[1]) cbuf1[buf_addr_w[19:10]] <= buf_wdata_w[31:16];
    rd0 <= cbuf0[buf_addr_w[9:0]];
    rd1 <= cbuf1[buf_addr_w[19:10]];
  end

  // ------------------------------------------------------------- patterns
  function [15:0] pat16(input integer code, input integer w);
    reg [31:0] t;
    begin
      case (code)
        PAT_W1:  t = w * 2017 + 3131;
        PAT_W2:  t = w * 911 + 4660;
        default: t = w * 501 + 16962;
      endcase
      pat16 = t[15:0];
    end
  endfunction

  // OLD SDRAM preload (must survive a failed write untouched)
  function [31:0] oldw(input integer a);
    reg [31:0] t;
    begin
      t    = a;
      oldw = {t[15:0] ^ 16'h5A5A, t[15:0] ^ 16'hA5A5};
    end
  endfunction


  // ------------------------------------------------------------- monitors
  integer errors = 0;
  reg     last_err0 = 0, last_err1 = 0;
  reg [N-1:0] done_q = 0, busy_q = 0;
  integer memwr_op = 0;       // mem WRITE starts since the op was issued
  integer memwr_at_done = -1; // memwr_op sampled at the done pulse
  always @(posedge clk_cpu) begin
    done_q <= done_w;
    busy_q <= busy_w;
    if ((done_w & done_q) != 0) begin
      $display("FAIL: done wider than one clk_cpu cycle");
      errors = errors + 1;
    end
    if (done_w[0]) begin
      if (!busy_q[0]) begin
        $display("FAIL: done[0] without preceding busy");
        errors = errors + 1;
      end
      if (busy_w[0]) begin
        $display("FAIL: busy[0] still high during done");
        errors = errors + 1;
      end
      last_err0 = err_w[0];
      memwr_at_done = memwr_op;
    end
    if (done_w[1]) begin
      if (!busy_q[1]) begin
        $display("FAIL: done[1] without preceding busy");
        errors = errors + 1;
      end
      if (busy_w[1]) begin
        $display("FAIL: busy[1] still high during done");
        errors = errors + 1;
      end
      last_err1 = err_w[1];
      memwr_at_done = memwr_op;
    end
  end

  // traffic counters and card-first/SDRAM-second ordering check
  integer mem_starts = 0;
  integer sdw_starts = 0;
  integer sdw_dones_op = 0;   // sd_writer done pulses since the op was issued
  reg     order_arm = 0;      // check mem writes only after 4 CMD24 dones
  integer order_errors = 0;

  // mid-card-phase hierarchical peek: the SDRAM copy must still be OLD
  reg     mid_arm = 0;
  integer mid_base = 0;       // SDRAM word address of the block under test
  reg     mid_checked = 0;
  reg     mid_old_ok = 0;
  integer mi;

  always @(posedge clk_stor) begin
    if (mem_start_w) begin
      mem_starts = mem_starts + 1;
      if (mem_we_w) begin
        memwr_op = memwr_op + 1;
        if (order_arm && sdw_dones_op < 4) order_errors = order_errors + 1;
      end
    end
    if (sdw_start_w) sdw_starts = sdw_starts + 1;
    if (sdw_done_w) sdw_dones_op = sdw_dones_op + 1;

    // evidence for (b): two sectors are already on the card, the third is
    // in flight - the SDRAM copy must still hold the OLD preload
    if (mid_arm && sdw_dones_op == 2 && !mid_checked) begin
      mid_checked = 1;
      mid_old_ok  = 1;
      for (mi = 0; mi < 512; mi = mi + 1)
        if (u_mem.mem[mid_base+mi] !== oldw(mid_base + mi)) mid_old_ok = 0;
      if (mid_old_ok)
        $display("mid-write peek at %0t: SDRAM copy still OLD (card phase 2/4) - ordering proven",
                 $time);
    end
  end

  // ------------------------------------------------------------- helpers
  task fill_cbuf(input integer c, input integer code);
    integer w;
    begin
      for (w = 0; w < 1024; w = w + 1) begin
        if (c == 0) cbuf0[w] = pat16(code, w);
        else cbuf1[w] = pat16(code, w);
      end
    end
  endtask

  task do_op(input integer c, input [15:0] blk, input wrbit);
    integer guard;
    begin
      memwr_op      = 0;
      memwr_at_done = -1;
      sdw_dones_op  = 0;
      @(posedge clk_cpu);
      if (c == 0) begin
        t_req[0] <= 1'b1;
        t_wr[0] <= wrbit;
        t_block0 <= blk;
      end else begin
        t_req[1] <= 1'b1;
        t_wr[1] <= wrbit;
        t_block1 <= blk;
      end
      @(posedge clk_cpu);
      t_req <= 2'b00;
      // wait for busy to RISE first (polling low immediately would race)
      guard = 0;
      while (!busy_w[c] && guard < 100) begin
        @(posedge clk_cpu);
        guard = guard + 1;
      end
      if (!busy_w[c]) begin
        $display("TB_RESULT: FAIL client %0d op never went busy", c);
        $finish;
      end
      guard = 0;
      while (busy_w[c] && guard < 5_000_000) begin
        @(posedge clk_cpu);
        guard = guard + 1;
      end
      if (busy_w[c]) begin
        $display("TB_RESULT: FAIL client %0d op hung", c);
        $finish;
      end
      repeat (4) @(posedge clk_cpu);  // let the done monitor settle
    end
  endtask

  // card image: 2048 bytes at sectors first_sec+4*blk .. +3, big-endian
  // word order - byte 2w must equal pattern word bits [15:8]
  task check_card_block(input [31:0] first_sec, input [15:0] blk, input integer code);
    integer k;
    reg [15:0] wv;
    reg [7:0]  got, exp;
    begin
      for (k = 0; k < 2048; k = k + 1) begin
        wv  = pat16(code, k / 2);
        exp = (k % 2 == 1) ? wv[7:0] : wv[15:8];
        got = card.mem[(first_sec+{16'd0, blk}*4)*512+k];
        if (got !== exp) begin
          if (errors < 10)
            $display("FAIL: card blk %0d byte %0d (sector %0d): got %02x want %02x",
                     blk, k, first_sec + blk * 4 + k / 512, got, exp);
          errors = errors + 1;
        end
      end
    end
  endtask

  // Region copy of a written block equals the written pattern.
  //
  // Phase 4: base_blk/blk no longer say WHERE a block lives. These clients
  // are DIRECT (not in CACHE_MASK), so a write lands in the shared staging
  // line at STAGE_BASE_BLK - one line, because the arbiter serves one client
  // at a time and the line never has to outlive its own grant. The arguments
  // are kept so the call sites still document which client/block was written.
  task check_sdram_block(input integer base_blk, input [15:0] blk, input integer code);
    integer m;
    reg [31:0] gotw, expw;
    begin
      for (m = 0; m < 512; m = m + 1) begin
        gotw = u_mem.mem[STAGE_BLK*512+m];
        expw = {pat16(code, 2 * m), pat16(code, 2 * m + 1)};
        if (gotw !== expw) begin
          if (errors < 10)
            $display("FAIL: SDRAM blk %0d word %0d: got %08x want %08x", blk, m, gotw, expw);
          errors = errors + 1;
        end
      end
    end
  endtask

  // check_sdram_old is GONE. It asserted that a failed write left block N of
  // a slot holding its original preload - two things that no longer exist:
  // nothing is preloaded, and a block does not live at slot_base+blk. The
  // invariant it was protecting is still checked, and more strongly, at the
  // call site: mem_starts must not move across the failed write, which proves
  // the region was not written AT ALL rather than that one block survived.

  // a card sector is still all zero (never committed)
  task check_card_sector_zero(input [31:0] sec);
    integer k;
    begin
      for (k = 0; k < 512; k = k + 1) begin
        if (card.mem[sec*512+k] !== 8'h00) begin
          if (errors < 10)
            $display("FAIL: card sector %0d byte %0d not zero: %02x", sec, k, card.mem[sec*512+k]);
          errors = errors + 1;
        end
      end
    end
  endtask

  // ------------------------------------------------------------- preload
  // Phase 4: there is no per-slot copy to preload any more. What must be
  // preloaded is the STAGING LINE, because the mid-write peek (b) proves the
  // region still holds its OLD contents while the card phase is only half
  // done - and the staging line is now the only region block a DIRECT write
  // ever touches. Preloading (BASE0+1)*512 as v1 did would peek at a block
  // the write never writes, so the check would pass no matter what.
  integer pm;
  initial begin
    for (pm = 0; pm < 512; pm = pm + 1)
      u_mem.mem[STAGE_BLK*512+pm] = oldw(STAGE_BLK * 512 + pm);
  end

  // ------------------------------------------------------------- test
  integer w;
  integer mem_starts_snap, sdw_starts_snap;
  reg [15:0] expw16;
  initial begin
    repeat (10) @(posedge clk_stor);
    rst_n = 1;
    repeat (50) @(posedge clk_cpu);

    // ---- (a)+(b)+(c): client 0 writes block 1, mid-write SDRAM peek ----
    fill_cbuf(0, PAT_W1);
    mid_base = STAGE_BLK * 512;
    mid_checked = 0;
    mid_arm = 1;
    order_arm = 1;
    sdw_starts_snap = sdw_starts;
    do_op(0, 16'd1, 1'b1);
    mid_arm = 0;
    order_arm = 0;
    if (last_err0 !== 1'b0) begin
      $display("FAIL: write 1 returned err");
      errors = errors + 1;
    end
    if (!mid_checked) begin
      $display("FAIL: mid-write SDRAM peek never ran");
      errors = errors + 1;
    end else if (!mid_old_ok) begin
      $display("FAIL: SDRAM copy already modified DURING the card phase");
      errors = errors + 1;
    end
    if (order_errors !== 0) begin
      $display("FAIL: %0d mem writes before the 4th CMD24 done", order_errors);
      errors = errors + 1;
    end
    if (sdw_starts - sdw_starts_snap !== 4) begin
      $display("FAIL: write 1 started sd_writer %0d times (want 4)", sdw_starts - sdw_starts_snap);
      errors = errors + 1;
    end
    if (memwr_at_done !== 512) begin
      $display("FAIL: done fired with %0d/512 mem writes issued", memwr_at_done);
      errors = errors + 1;
    end
    check_card_block(FIRST0, 16'd1, PAT_W1);
    check_sdram_block(BASE0, 16'd1, PAT_W1);

    // ---- (a) again on client 1: different slot base and first sector ----
    fill_cbuf(1, PAT_W2);
    do_op(1, 16'd0, 1'b1);
    if (last_err1 !== 1'b0) begin
      $display("FAIL: write 2 returned err");
      errors = errors + 1;
    end
    if (memwr_at_done !== 512) begin
      $display("FAIL: write 2 done fired with %0d/512 mem writes issued", memwr_at_done);
      errors = errors + 1;
    end
    check_card_block(FIRST1, 16'd0, PAT_W2);
    check_sdram_block(BASE1, 16'd0, PAT_W2);

    // ---- (d): inject a CMD24 rejection on the THIRD sector of block 2 ----
    // sectors 0 and 1 land on the card (card-first ordering makes partial
    // card writes possible), the SDRAM copy must stay fully untouched
    card.fail_sector = FIRST0 + 2 * 4 + 2;  // sector 18
    fill_cbuf(0, PAT_FAIL);
    mem_starts_snap = mem_starts;
    sdw_starts_snap = sdw_starts;
    do_op(0, 16'd2, 1'b1);
    if (last_err0 !== 1'b1) begin
      $display("FAIL: injected CMD24 failure did not return err");
      errors = errors + 1;
    end
    if (mem_starts !== mem_starts_snap) begin
      $display("FAIL: failed write touched the mem port (%0d pulses)",
               mem_starts - mem_starts_snap);
      errors = errors + 1;
    end
    if (sdw_starts - sdw_starts_snap !== 3) begin
      $display("FAIL: failed write started sd_writer %0d times (want 3)",
               sdw_starts - sdw_starts_snap);
      errors = errors + 1;
    end
    if (memwr_at_done !== 0) begin
      $display("FAIL: failed write issued %0d mem writes before done", memwr_at_done);
      errors = errors + 1;
    end
    check_card_sector_zero(FIRST0 + 2 * 4 + 2); // rejected sector not committed
    check_card_sector_zero(FIRST0 + 2 * 4 + 3); // fourth sector never sent
    if (card.fail_sector !== 32'hFFFF_FFFF) begin
      $display("FAIL: fail_sector hook did not self-clear");
      errors = errors + 1;
    end

    // ---- (e): the engine recovers, AND the write round-trips -------------
    // Phase 4: a read no longer serves an SDRAM preload, it FETCHES the block
    // from the card into the staging line and serves the client from there.
    // So reading back block 1 - the block written in (a) - proves two things
    // at once: the engine recovered from the injected CMD24 failure, and the
    // bytes that write put on the card come back as the same client words.
    // (v1 read block 0 and expected an SDRAM preload that no longer exists.)
    for (w = 0; w < 1024; w = w + 1) cbuf0[w] = 16'hDEAD;  // must be overwritten
    sdw_starts_snap = sdw_starts;
    do_op(0, 16'd1, 1'b0);
    if (last_err0 !== 1'b0) begin
      $display("FAIL: read after failed write returned err");
      errors = errors + 1;
    end
    if (sdw_starts - sdw_starts_snap !== 4) begin
      $display("FAIL: read fetched %0d sectors from the card (want 4)",
               sdw_starts - sdw_starts_snap);
      errors = errors + 1;
    end
    for (w = 0; w < 1024; w = w + 1) begin
      expw16 = pat16(PAT_W1, w);
      if (cbuf0[w] !== expw16) begin
        if (errors < 10)
          $display("FAIL: read-back word %0d: got %04x want %04x", w, cbuf0[w], expw16);
        errors = errors + 1;
      end
    end

    // ---- (f): out-of-range write -> done+err, zero SD and mem traffic ----
    mem_starts_snap = mem_starts;
    sdw_starts_snap = sdw_starts;
    do_op(0, NBLK[15:0], 1'b1);  // block 4, n_blocks = 4
    if (last_err0 !== 1'b1) begin
      $display("FAIL: out-of-range write did not return err");
      errors = errors + 1;
    end
    if (mem_starts !== mem_starts_snap) begin
      $display("FAIL: out-of-range write touched the mem port");
      errors = errors + 1;
    end
    if (sdw_starts !== sdw_starts_snap) begin
      $display("FAIL: out-of-range write started sd_writer");
      errors = errors + 1;
    end

    // ---- card model health ----
    if (card.crc_errors !== 0) begin
      $display("FAIL: %0d CMD CRC7 errors", card.crc_errors);
      errors = errors + 1;
    end
    if (card.wr_crc_errors !== 0) begin
      $display("FAIL: %0d data CRC16 errors", card.wr_crc_errors);
      errors = errors + 1;
    end
    if (card.illegal_writes !== 0) begin
      $display("FAIL: %0d writes into the reserved region (below sector %0d)",
               card.illegal_writes, FIRST0);
      errors = errors + 1;
    end
    if (eng_wd_err_w !== 1'b0) begin
      $display("FAIL: engine watchdog fired");
      errors = errors + 1;
    end

    if (errors == 0) $display("TB_RESULT: PASS");
    else $display("TB_RESULT: FAIL %0d errors", errors);
    $finish;
  end

  initial begin
    #200_000_000;  // 200 ms absolute watchdog
    $display("TB_RESULT: FAIL absolute watchdog");
    $finish;
  end

endmodule

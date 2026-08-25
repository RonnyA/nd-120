/****************************************************************************
** sd_fat_freescan - FAT free-space scanner, self-checking unit testbench  **
**                                                                         **
** Full path:                                                              **
**   Verilog/SD-FAT/sim/sd_fat_freescan_tb.v                               **
**                                                                         **
** WHAT IS VERIFIED                                                        **
**   sd_fat_freescan (Verilog/SD-FAT/circuit/sd_fat_freescan.v) counts the **
**   FREE entries of FAT #0 by riding the sd_writer engine's rx byte       **
**   stream. Everything it can get wrong is arithmetic or bookkeeping on   **
**   that stream, and all of it is checked here:                           **
**                                                                         **
**   1. ENTRY FORMAT AND BYTE POSITION. A FAT16 entry is 2 bytes, a FAT32  **
**      entry is 4, little endian, and an entry is FREE only when every    **
**      byte is zero - except that in FAT32 the top nibble of the LAST     **
**      byte is reserved and masked out of the test. A per-byte battery    **
**      drives one non-zero byte at a time through each byte position of   **
**      an otherwise free entry: get the byte position, the entry width or **
**      the mask wrong and exactly one of those cases flips.               **
**      The mask is checked in BOTH directions: FAT32 0xF0000000 and       **
**      0x10000000 must count as free, and the SAME 16-bit pattern         **
**      0xF000 in FAT16 - where there is no mask - must NOT.               **
**   2. THE VALID CLUSTER WINDOW. Clusters 0 and 1 are below the window    **
**      and must never be counted even when their entries are zero;        **
**      cluster max_cluster must be counted and max_cluster+1 must not.    **
**      Each is proved with a FAT in which those are the ONLY zero         **
**      entries, so the expected count is 0 or 1 exactly.                  **
**   3. THE SECTOR WALK. eng_sector must run fat0_sector, +1, +2 ...,      **
**      eng_start must pulse once per sector, sec_tick once per finished   **
**      sector, and the walk must stop with the sector holding the last    **
**      real cluster OR after sectors_per_fat sectors, whichever comes     **
**      first. Both stop rules are exercised on the same FAT image.        **
**   4. free_mb = free_clusters * cluster_size * 512 / 2^20, TRUNCATED,    **
**      at cluster_size 1 (truncates to zero), 64 and 128 (both truncate   **
**      a non-integral MB count downwards).                                **
**   5. PROTOCOL. eng_rd is 1 at all times, eng_start / done / err /       **
**      sec_tick are all exactly one cycle wide, busy is high for the      **
**      whole scan and low outside it, a start pulse arriving while busy   **
**      is ignored, the eng_err path pulses err WITHOUT done and leaves    **
**      the module ready for the next scan, and reset clears the counts.   **
**                                                                         **
** REFERENCE MODEL - WHERE IT COMES FROM                                   **
**   Not from FAT documentation and not from the module name. Two          **
**   independent sources, both inside this file:                           **
**     - a software model (task exp_model) that walks the SAME byte array  **
**       the engine model streams out, applying the rule stated in the     **
**       RTL's own header ("counts the FREE entries (value 0) between      **
**       cluster 2 and the volume's last cluster - a FAT32 entry is masked **
**       to its low 28 bits, a FAT16 entry is the full 16", stopping "with **
**       the sector that holds the last real cluster" or at the end of the **
**       FAT). It is a plain loop over bytes, sharing no code with the DUT.**
**     - hand-computed expected values for the small targeted cases (the   **
**       byte battery, the cluster-window cases), written out in the       **
**       stimulus so a reader can check them by eye.                       **
**   The engine model in this file is behavioural, and its ONE timing      **
**   assumption is taken from the real engine: sd_writer.v raises done     **
**   several states after the last rx_we (Verilog/SD-FAT/circuit/          **
**   sd_writer.v:451-470 streams the bytes, W_DONE at line 650 follows the **
**   CRC and end-bit states), so this model leaves a gap between the last  **
**   byte and eng_done rather than overlapping them.                       **
**                                                                         **
** TEST PLAN                                                               **
**   T1  reset / idle outputs, eng_rd tied high                            **
**   T2  FAT16 byte battery at cluster 5 (5 patterns)                      **
**   T3  FAT16 clusters 0 and 1 zero, nothing else -> count 0              **
**   T4  FAT16 only max_cluster and max_cluster+1 zero -> count 1          **
**   T5  FAT32 byte battery at cluster 5 (8 patterns, incl. nibble mask)   **
**   T6  FAT32 clusters 0 and 1 zero -> count 0                            **
**   T7  FAT16 cluster_size 1, two sectors: count, sector sequence,        **
**       eng_start / sec_tick counts, free_mb truncating to 0              **
**   T8  FAT16 cluster_size 128, one sector: free_mb = 6 from 100 free     **
**   T9  FAT32 cluster_size 64, two sectors: count and free_mb = 3         **
**   T10 sectors_per_fat = 1 on the T7 image: the FAT length stops it      **
**   T11 a start pulse while busy is ignored                               **
**   T12 engine error on the second sector: err, no done, then recovery    **
**   T13 reset clears free_clusters and free_mb                            **
**   T14 CHARACTERISATION: sectors_per_fat = 0 still reads one sector      **
**   T15 CHARACTERISATION: start does not clear free_mb (only reset does)  **
**   Continuous: pulse widths, eng_rd, and a guard that the DUT never      **
**   asks for a sector outside the loaded FAT image.                       **
**                                                                         **
** HOW TO RUN                                                              **
**   cd Verilog/SD-FAT/sim                                                 **
**   iverilog -g2012 -o sd_fat_freescan_tb.vvp                             **
**            ../circuit/sd_fat_freescan.v sd_fat_freescan_tb.v            **
**   vvp -N sd_fat_freescan_tb.vvp                                         **
**   (both source files on one iverilog command line). Under a second of   **
**   CPU; the wall time is dominated by writing the VCD, which is covered  **
**   by the repo gitignore rule for sim VCDs and is not committed.         **
**   Makefile / test-registry target name: test-nds-freescan               **
**                                                                         **
** Last reviewed: 20-AUG-2026                                              **
** Ronny Hansen                                                            **
*****************************************************************************/
`timescale 1ns / 1ps
`default_nettype none

module sd_fat_freescan_tb;

  // -------------------------------------------------------------- clock/reset
  reg clk = 1'b0;
  always #5 clk = ~clk;
  reg rst_n = 1'b0;

  integer checks = 0;
  integer errors = 0;

  task chk(input cond, input [8*72-1:0] what);
    begin
      checks = checks + 1;
      if (!cond) begin
        errors = errors + 1;
        $display("FAIL @%0t: %0s", $time, what);
      end
    end
  endtask

  task chkv(input cond, input [8*72-1:0] what, input integer got, input integer want);
    begin
      checks = checks + 1;
      if (!cond) begin
        errors = errors + 1;
        $display("FAIL @%0t: %0s (got %0d, want %0d)", $time, what, got, want);
      end
    end
  endtask

  // -------------------------------------------------------------- geometry
  localparam [31:0] FAT0 = 32'd100;   // fat0_sector for every test
  localparam integer NSEC = 4;        // sectors held by the FAT image below

  reg        g_fat32;
  reg [7:0]  g_cs;
  reg [31:0] g_dbs;
  reg [31:0] g_tots;
  reg [31:0] g_spf;

  // -------------------------------------------------------------- the DUT
  reg  start = 1'b0;
  wire busy, done, err, sec_tick;
  wire        eng_start;
  wire        eng_rd;
  wire [31:0] eng_sector;
  reg         eng_done = 1'b0;
  reg         eng_err = 1'b0;
  reg         eng_rx_we = 1'b0;
  reg  [8:0]  eng_rx_addr = 9'd0;
  reg  [7:0]  eng_rx_data = 8'd0;
  wire [31:0] free_clusters, free_mb;

  sd_fat_freescan DUT (
      .clk             (clk),
      .rst_n           (rst_n),
      .start           (start),
      .busy            (busy),
      .done            (done),
      .err             (err),
      .sec_tick        (sec_tick),
      .fs_is_fat32     (g_fat32),
      .cluster_size    (g_cs),
      .fat0_sector     (FAT0),
      .sectors_per_fat (g_spf),
      .data_base_sector(g_dbs),
      .total_sectors   (g_tots),
      .eng_start       (eng_start),
      .eng_rd          (eng_rd),
      .eng_sector      (eng_sector),
      .eng_done        (eng_done),
      .eng_err         (eng_err),
      .eng_rx_we       (eng_rx_we),
      .eng_rx_addr     (eng_rx_addr),
      .eng_rx_data     (eng_rx_data),
      .free_clusters   (free_clusters),
      .free_mb         (free_mb)
  );

  // ------------------------------------------------------ the FAT byte image
  // NSEC sectors of 512 bytes, sector s at fat_mem[s*512 +: 512], mapped to
  // absolute card sector FAT0 + s.
  reg [7:0] fat_mem [0:NSEC*512-1];

  integer fi;
  task fat_fill16(input [15:0] val);   // every FAT16 entry of every sector
    begin
      for (fi = 0; fi < NSEC*512; fi = fi + 2) begin
        fat_mem[fi]     = val[7:0];
        fat_mem[fi + 1] = val[15:8];
      end
    end
  endtask

  task fat_fill32(input [31:0] val);   // every FAT32 entry of every sector
    begin
      for (fi = 0; fi < NSEC*512; fi = fi + 4) begin
        fat_mem[fi]     = val[7:0];
        fat_mem[fi + 1] = val[15:8];
        fat_mem[fi + 2] = val[23:16];
        fat_mem[fi + 3] = val[31:24];
      end
    end
  endtask

  task fat_put16(input integer clu, input [15:0] val);
    begin
      fat_mem[2*clu]     = val[7:0];
      fat_mem[2*clu + 1] = val[15:8];
    end
  endtask

  task fat_put32(input integer clu, input [31:0] val);
    begin
      fat_mem[4*clu]     = val[7:0];
      fat_mem[4*clu + 1] = val[15:8];
      fat_mem[4*clu + 2] = val[23:16];
      fat_mem[4*clu + 3] = val[31:24];
    end
  endtask

  // ------------------------------------------------------ the engine model
  // Behavioural sd_writer in read mode: latency, 512 bytes on consecutive
  // cycles at addresses 0..511, a gap, then a one-cycle eng_done. em_fail_on
  // selects a read (0-based, within the current scan) that answers eng_err
  // instead - the engine failure path.
  localparam [2:0] EM_IDLE = 3'd0, EM_LAT = 3'd1, EM_STREAM = 3'd2,
                   EM_GAP  = 3'd3, EM_DONE = 3'd4, EM_ERR = 3'd5;

  reg [2:0]  em_state = EM_IDLE;
  reg [9:0]  em_i = 10'd0;
  reg [7:0]  em_lat = 8'd0;
  reg [31:0] em_sec = 32'd0;
  integer    em_fail_on = -1;       // -1 = never fail
  integer    em_reads = 0;          // reads accepted in this scan
  integer    obs_start_cnt = 0;     // eng_start pulses in this scan
  integer    obs_sec_tick = 0;
  integer    obs_done = 0;
  integer    obs_err = 0;
  reg [31:0] req_log [0:63];        // eng_sector as requested, in order

  integer em_idx;

  always @(posedge clk) begin
    if (!rst_n) begin
      em_state    <= EM_IDLE;
      eng_rx_we   <= 1'b0;
      eng_rx_addr <= 9'd0;
      eng_rx_data <= 8'd0;
      eng_done    <= 1'b0;
      eng_err     <= 1'b0;
      em_i        <= 10'd0;
      em_lat      <= 8'd0;
    end else begin
      eng_rx_we <= 1'b0;
      eng_done  <= 1'b0;
      eng_err   <= 1'b0;
      case (em_state)
        EM_IDLE:
        if (eng_start) begin
          em_sec   <= eng_sector;
          em_i     <= 10'd0;
          em_lat   <= 8'd3;
          em_state <= EM_LAT;
          // guard: the DUT must never ask for a sector outside the image
          if (eng_sector < FAT0 || eng_sector >= FAT0 + NSEC)
            chk(1'b0, "DUT requested a sector outside the loaded FAT");
          if (obs_start_cnt < 64) req_log[obs_start_cnt] <= eng_sector;
          obs_start_cnt <= obs_start_cnt + 1;
        end

        EM_LAT:
        if (em_lat != 8'd0) em_lat <= em_lat - 8'd1;
        else if (em_fail_on == em_reads) begin
          em_reads <= em_reads + 1;
          em_state <= EM_ERR;
        end else begin
          em_reads <= em_reads + 1;
          em_state <= EM_STREAM;
        end

        EM_STREAM: begin
          eng_rx_we   <= 1'b1;
          eng_rx_addr <= em_i[8:0];
          em_idx       = (em_sec - FAT0) * 512 + em_i;
          eng_rx_data <= (em_idx >= 0 && em_idx < NSEC*512) ? fat_mem[em_idx] : 8'hA5;
          if (em_i == 10'd511) begin
            em_i     <= 10'd0;
            em_lat   <= 8'd4;
            em_state <= EM_GAP;
          end else em_i <= em_i + 10'd1;
        end

        EM_GAP:
        if (em_lat != 8'd0) em_lat <= em_lat - 8'd1;
        else em_state <= EM_DONE;

        EM_DONE: begin
          eng_done <= 1'b1;
          em_state <= EM_IDLE;
        end

        EM_ERR: begin
          eng_err  <= 1'b1;
          em_state <= EM_IDLE;
        end

        default: em_state <= EM_IDLE;
      endcase
    end
  end

  // ------------------------------------------------------ continuous checks
  // eng_rd is hardwired high in the RTL; pulses must be exactly one cycle.
  integer w_start = 0, w_done = 0, w_err = 0, w_tick = 0;

  always @(posedge clk) begin
    #1;
    if (rst_n) begin
      chk(eng_rd === 1'b1, "eng_rd is not tied high");

      w_start = eng_start ? w_start + 1 : 0;
      w_done  = done      ? w_done  + 1 : 0;
      w_err   = err       ? w_err   + 1 : 0;
      w_tick  = sec_tick  ? w_tick  + 1 : 0;
      chk(w_start < 2, "eng_start wider than one cycle");
      chk(w_done  < 2, "done wider than one cycle");
      chk(w_err   < 2, "err wider than one cycle");
      chk(w_tick  < 2, "sec_tick wider than one cycle");

      if (sec_tick) obs_sec_tick = obs_sec_tick + 1;
      if (done)     obs_done     = obs_done + 1;
      if (err)      obs_err      = obs_err + 1;

      chk(busy !== 1'bx && done !== 1'bx && err !== 1'bx, "control output went x");
    end
  end

  // ------------------------------------------------- independent expectation
  // A plain software walk of the same bytes, written from the rule in the
  // module header. Shares nothing with the DUT.
  function integer ilog2p2(input integer v);
    integer r;
    begin
      r = 0;
      while (v > 1) begin
        v = v >> 1;
        r = r + 1;
      end
      ilog2p2 = r;
    end
  endfunction

  task exp_model(output integer e_cnt, output integer e_sec,
                 output integer e_max, output integer e_mb);
    integer ew, eps, clu, k, e, b, left, zero, bv, l2;
    reg stop;
    begin
      ew  = g_fat32 ? 4 : 2;
      eps = 512 / ew;
      l2  = ilog2p2(g_cs);
      e_max = ((g_tots - (g_dbs + g_cs * 2)) >> l2) + 1;
      clu = 0; e_cnt = 0; k = 0; left = g_spf; stop = 1'b0;
      while (!stop) begin
        for (e = 0; e < eps; e = e + 1) begin
          zero = 1;
          for (b = 0; b < ew; b = b + 1) begin
            bv = fat_mem[k*512 + e*ew + b];
            if (g_fat32 && b == ew - 1) bv = bv & 8'h0F;
            if (bv != 0) zero = 0;
          end
          if (clu >= 2 && clu <= e_max && zero) e_cnt = e_cnt + 1;
          clu = clu + 1;
        end
        k = k + 1;
        if (clu > e_max || left <= 1) stop = 1'b1;
        else left = left - 1;
      end
      e_sec = k;
      e_mb  = (e_cnt << l2) >> 11;
    end
  endtask

  // -------------------------------------------------------------- run a scan
  integer guard;
  task run_scan;
    begin
      obs_start_cnt = 0;
      obs_sec_tick  = 0;
      obs_done      = 0;
      obs_err       = 0;
      em_reads      = 0;
      @(negedge clk);
      start = 1'b1;
      @(negedge clk);
      start = 1'b0;
      guard = 0;
      while (obs_done == 0 && obs_err == 0 && guard < 200000) begin
        @(posedge clk);
        guard = guard + 1;
      end
      if (guard >= 200000) begin
        $display("checks=%0d failures=%0d", checks, errors + 1);
        $display("TB_RESULT: FAIL");
        $finish;
      end
      @(negedge clk);
    end
  endtask

  // check a completed scan against the independent model
  integer e_cnt, e_sec, e_max, e_mb;
  task check_vs_model(input [8*24-1:0] tag);
    begin
      exp_model(e_cnt, e_sec, e_max, e_mb);
      chkv(free_clusters == e_cnt, {tag, " free_clusters"},  free_clusters, e_cnt);
      chkv(free_mb == e_mb,        {tag, " free_mb"},        free_mb,       e_mb);
      chkv(obs_start_cnt == e_sec, {tag, " eng_start count"},obs_start_cnt, e_sec);
      chkv(obs_sec_tick == e_sec,  {tag, " sec_tick count"}, obs_sec_tick,  e_sec);
      chkv(obs_done == 1,          {tag, " done pulses"},    obs_done,      1);
      chkv(obs_err == 0,           {tag, " err pulses"},     obs_err,       0);
    end
  endtask

  // -------------------------------------------------------------- watchdog
  initial begin
    #4_000_000;
    $display("checks=%0d failures=%0d", checks, errors + 1);
    $display("TB_RESULT: FAIL");
    $finish;
  end

  // -------------------------------------------------------------- VCD
  initial begin
    $dumpfile("sd_fat_freescan_tb.vcd");
    $dumpvars(0, sd_fat_freescan_tb);
  end

  // -------------------------------------------------------------- stimulus
  integer bi, want, i;
  reg [31:0] pat32 [0:7];
  reg [31:0] pex32 [0:7];
  reg [15:0] pat16 [0:4];
  reg [31:0] pex16 [0:4];

  initial begin
    // small-window geometry used by the targeted cases: max_cluster = 10
    //   usable = total - (data_base + 2*cs) = 9, cluster_size 1 -> max = 10
    g_fat32 = 1'b0; g_cs = 8'd1; g_dbs = 32'd1000; g_tots = 32'd1011;
    g_spf = 32'd4;
    fat_fill16(16'hFFFF);

    repeat (4) @(posedge clk);
    @(negedge clk);
    rst_n = 1'b1;
    @(negedge clk);

    // ---- T1: idle after reset -------------------------------------------
    chk(busy === 1'b0, "T1 busy set out of reset");
    chk(done === 1'b0 && err === 1'b0, "T1 done/err set out of reset");
    chk(eng_start === 1'b0, "T1 eng_start set out of reset");
    chk(eng_rd === 1'b1, "T1 eng_rd not tied high");
    chkv(free_clusters == 32'd0, "T1 free_clusters not 0", free_clusters, 0);
    chkv(free_mb == 32'd0, "T1 free_mb not 0", free_mb, 0);

    // ---- T2: FAT16 byte battery at cluster 5 -----------------------------
    // one entry inside the valid window, everything else 0xFFFF. FAT16 has
    // NO nibble mask, so 0xF000 must NOT count - the case that separates
    // FAT16 handling from FAT32 handling.
    pat16[0] = 16'h0000; pex16[0] = 1;
    pat16[1] = 16'h0001; pex16[1] = 0;
    pat16[2] = 16'h0100; pex16[2] = 0;
    pat16[3] = 16'hF000; pex16[3] = 0;
    pat16[4] = 16'hFFFF; pex16[4] = 0;
    for (bi = 0; bi < 5; bi = bi + 1) begin
      g_fat32 = 1'b0; g_cs = 8'd1; g_dbs = 32'd1000; g_tots = 32'd1011;
      g_spf = 32'd4;
      fat_fill16(16'hFFFF);
      fat_put16(5, pat16[bi]);
      run_scan;
      want = pex16[bi];
      chkv(free_clusters == want, "T2 FAT16 byte battery", free_clusters, want);
      chkv(obs_start_cnt == 1, "T2 battery sectors read", obs_start_cnt, 1);
      check_vs_model("T2");
    end

    // ---- T3: FAT16 clusters 0 and 1 zero -> not counted -------------------
    fat_fill16(16'hFFFF);
    fat_put16(0, 16'h0000);
    fat_put16(1, 16'h0000);
    run_scan;
    chkv(free_clusters == 0, "T3 clusters 0/1 were counted", free_clusters, 0);
    check_vs_model("T3");

    // ---- T4: only max_cluster and max_cluster+1 zero -> exactly 1 ---------
    fat_fill16(16'hFFFF);
    fat_put16(10, 16'h0000);   // == max_cluster, must count
    fat_put16(11, 16'h0000);   // one past, must not
    run_scan;
    chkv(free_clusters == 1, "T4 max_cluster window wrong", free_clusters, 1);
    check_vs_model("T4");

    // ---- T5: FAT32 byte battery at cluster 5 ------------------------------
    // 0xF0000000 and 0x10000000 are FREE (top nibble masked); one non-zero
    // bit anywhere else is not.
    pat32[0] = 32'h00000000; pex32[0] = 1;
    pat32[1] = 32'hF0000000; pex32[1] = 1;
    pat32[2] = 32'h10000000; pex32[2] = 1;
    pat32[3] = 32'h00000001; pex32[3] = 0;
    pat32[4] = 32'h00000100; pex32[4] = 0;
    pat32[5] = 32'h00010000; pex32[5] = 0;
    pat32[6] = 32'h01000000; pex32[6] = 0;
    pat32[7] = 32'h0FFFFFFF; pex32[7] = 0;
    for (bi = 0; bi < 8; bi = bi + 1) begin
      g_fat32 = 1'b1; g_cs = 8'd1; g_dbs = 32'd1000; g_tots = 32'd1011;
      g_spf = 32'd4;
      fat_fill32(32'h0FFFFFFF);
      fat_put32(5, pat32[bi]);
      run_scan;
      want = pex32[bi];
      chkv(free_clusters == want, "T5 FAT32 byte battery", free_clusters, want);
      chkv(obs_start_cnt == 1, "T5 battery sectors read", obs_start_cnt, 1);
      check_vs_model("T5");
    end

    // ---- T6: FAT32 clusters 0 and 1 zero -> not counted -------------------
    fat_fill32(32'h0FFFFFFF);
    fat_put32(0, 32'h00000000);
    fat_put32(1, 32'h00000000);
    run_scan;
    chkv(free_clusters == 0, "T6 FAT32 clusters 0/1 counted", free_clusters, 0);
    check_vs_model("T6");

    // ---- T7: FAT16, cluster_size 1, two sectors ---------------------------
    // usable = 299 -> max_cluster = 300, so the walk needs sector 0
    // (clusters 0..255) and sector 1 (256..511) and stops there.
    g_fat32 = 1'b0; g_cs = 8'd1; g_dbs = 32'd1000; g_tots = 32'd1301;
    g_spf = 32'd4;
    fat_fill16(16'hFFFF);
    fat_put16(0, 16'h0000);          // below the window
    fat_put16(1, 16'h0000);          // below the window
    for (i = 2; i <= 101; i = i + 1) fat_put16(i, 16'h0000);   // 100 free
    fat_put16(300, 16'h0000);        // == max_cluster, counts  -> 101
    for (i = 301; i <= 511; i = i + 1) fat_put16(i, 16'h0000);  // all above
    run_scan;
    chkv(free_clusters == 101, "T7 count over two sectors", free_clusters, 101);
    chkv(obs_start_cnt == 2, "T7 sectors read", obs_start_cnt, 2);
    chkv(obs_sec_tick == 2, "T7 sec_tick count", obs_sec_tick, 2);
    chkv(req_log[0] == FAT0, "T7 first sector requested", req_log[0], FAT0);
    chkv(req_log[1] == FAT0 + 1, "T7 second sector requested", req_log[1], FAT0 + 1);
    chkv(free_mb == 0, "T7 free_mb should truncate to 0", free_mb, 0);
    check_vs_model("T7");

    // ---- T8: FAT16, cluster_size 128 -> free_mb = 6 from 100 free ---------
    // usable = 25472 -> 25472>>7 = 199 -> max_cluster = 200 (one sector)
    // free_mb = 100 * 128 * 512 / 2^20 = 6.25 -> 6
    g_fat32 = 1'b0; g_cs = 8'd128; g_dbs = 32'd1000; g_tots = 32'd26728;
    g_spf = 32'd4;
    fat_fill16(16'hFFFF);
    for (i = 2; i <= 101; i = i + 1) fat_put16(i, 16'h0000);   // 100 free
    run_scan;
    chkv(free_clusters == 100, "T8 count", free_clusters, 100);
    chkv(free_mb == 6, "T8 free_mb truncation", free_mb, 6);
    chkv(obs_start_cnt == 1, "T8 sectors read", obs_start_cnt, 1);
    check_vs_model("T8");

    // ---- T9: FAT32, cluster_size 64, two sectors --------------------------
    // usable = 12736 -> 12736>>6 = 199 -> max_cluster = 200
    // 128 entries per sector, so clusters 0..255 need two sectors.
    // 98 zero entries (2..99) + 0xF0000000 + 0x10000000 + max_cluster = 101
    // free_mb = 101 * 64 * 512 / 2^20 = 3.16 -> 3
    g_fat32 = 1'b1; g_cs = 8'd64; g_dbs = 32'd2000; g_tots = 32'd14864;
    g_spf = 32'd4;
    fat_fill32(32'h0FFFFFFF);
    fat_put32(0, 32'h00000000);      // below the window
    fat_put32(1, 32'h00000000);      // below the window
    for (i = 2; i <= 99; i = i + 1) fat_put32(i, 32'h00000000);  // 98
    fat_put32(100, 32'hF0000000);    // free (masked)      -> 99
    fat_put32(101, 32'h10000000);    // free (masked)      -> 100
    fat_put32(102, 32'h00000001);    // NOT free
    fat_put32(200, 32'h00000000);    // == max_cluster     -> 101
    fat_put32(201, 32'h00000000);    // one past, ignored
    run_scan;
    chkv(free_clusters == 101, "T9 FAT32 count", free_clusters, 101);
    chkv(free_mb == 3, "T9 FAT32 free_mb", free_mb, 3);
    chkv(obs_start_cnt == 2, "T9 sectors read", obs_start_cnt, 2);
    chkv(req_log[1] == FAT0 + 1, "T9 second sector requested", req_log[1], FAT0 + 1);
    check_vs_model("T9");

    // ---- T10: sectors_per_fat stops the walk before the cluster rule ------
    // Same image as T7 but a one-sector FAT: only clusters 0..255 are seen,
    // so the 100 free ones in 2..101 are counted and nothing else.
    g_fat32 = 1'b0; g_cs = 8'd1; g_dbs = 32'd1000; g_tots = 32'd1301;
    g_spf = 32'd1;
    fat_fill16(16'hFFFF);
    fat_put16(0, 16'h0000);
    fat_put16(1, 16'h0000);
    for (i = 2; i <= 101; i = i + 1) fat_put16(i, 16'h0000);
    fat_put16(300, 16'h0000);
    run_scan;
    chkv(free_clusters == 100, "T10 sectors_per_fat limit", free_clusters, 100);
    chkv(obs_start_cnt == 1, "T10 sectors read", obs_start_cnt, 1);
    check_vs_model("T10");

    // ---- T11: a start pulse while busy is ignored -------------------------
    // Same image and geometry as T7 (two sectors). A second start is injected
    // during the first sector's byte stream; if it were honoured the counters
    // would restart and the totals would be wrong.
    g_spf = 32'd4;
    fat_fill16(16'hFFFF);
    fat_put16(0, 16'h0000);
    fat_put16(1, 16'h0000);
    for (i = 2; i <= 101; i = i + 1) fat_put16(i, 16'h0000);
    fat_put16(300, 16'h0000);
    for (i = 301; i <= 511; i = i + 1) fat_put16(i, 16'h0000);
    obs_start_cnt = 0; obs_sec_tick = 0; obs_done = 0; obs_err = 0; em_reads = 0;
    @(negedge clk);
    start = 1'b1;
    @(negedge clk);
    start = 1'b0;
    repeat (200) @(negedge clk);      // mid-stream of sector 0
    chk(busy === 1'b1, "T11 not busy mid-scan");
    start = 1'b1;                     // spurious start while busy
    @(negedge clk);
    start = 1'b0;
    guard = 0;
    while (obs_done == 0 && obs_err == 0 && guard < 200000) begin
      @(posedge clk);
      guard = guard + 1;
    end
    @(negedge clk);
    chkv(free_clusters == 101, "T11 spurious start disturbed the count",
         free_clusters, 101);
    chkv(obs_start_cnt == 2, "T11 spurious start caused extra reads",
         obs_start_cnt, 2);
    chkv(obs_done == 1, "T11 done pulses", obs_done, 1);

    // ---- T12: engine error on the second sector ---------------------------
    em_fail_on = 1;                   // second read of the scan answers err
    run_scan;
    chkv(obs_err == 1, "T12 err not pulsed", obs_err, 1);
    chkv(obs_done == 0, "T12 done pulsed on the error path", obs_done, 0);
    chk(busy === 1'b0, "T12 busy stuck after an engine error");
    chkv(obs_start_cnt == 2, "T12 reads before the failure", obs_start_cnt, 2);
    em_fail_on = -1;
    // ...and the module is ready for the next scan (recovery)
    run_scan;
    chkv(free_clusters == 101, "T12 recovery scan count", free_clusters, 101);
    chkv(obs_done == 1, "T12 recovery done", obs_done, 1);

    // ---- T13: reset clears the counts -------------------------------------
    chk(free_clusters != 32'd0, "T13 precondition: a non-zero count");
    @(negedge clk);
    rst_n = 1'b0;
    @(posedge clk); #1;
    chkv(free_clusters == 32'd0, "T13 reset did not clear free_clusters",
         free_clusters, 0);
    chkv(free_mb == 32'd0, "T13 reset did not clear free_mb", free_mb, 0);
    chk(busy === 1'b0, "T13 busy set in reset");
    @(negedge clk);
    rst_n = 1'b1;
    @(negedge clk);

    // ---- T14: CHARACTERISATION - sectors_per_fat = 0 ----------------------
    // RECORDS OBSERVED BEHAVIOUR, not a specification. s_left is loaded with
    // sectors_per_fat and the stop test is "s_left <= 1", so a FAT declared
    // ZERO sectors long is still read for exactly one sector before the scan
    // ends. Reported as an oddity, not fixed here.
    g_fat32 = 1'b0; g_cs = 8'd1; g_dbs = 32'd1000; g_tots = 32'd1301;
    g_spf = 32'd0;
    fat_fill16(16'hFFFF);
    for (i = 2; i <= 11; i = i + 1) fat_put16(i, 16'h0000);
    run_scan;
    chkv(obs_start_cnt == 1, "T14 sectors_per_fat=0 read count", obs_start_cnt, 1);
    chkv(free_clusters == 10, "T14 sectors_per_fat=0 count", free_clusters, 10);
    chkv(obs_done == 1, "T14 done", obs_done, 1);

    // ---- T15: CHARACTERISATION - start does not clear free_mb -------------
    // RECORDS OBSERVED BEHAVIOUR. The FS_IDLE start branch clears
    // free_clusters but NOT free_mb, so after a scan that ends in an engine
    // error free_mb still reads the value the PREVIOUS successful scan left
    // there. Harmless while callers only sample free_mb at done, which is
    // the documented contract - recorded here so a change is visible.
    g_fat32 = 1'b1; g_cs = 8'd64; g_dbs = 32'd2000; g_tots = 32'd14864;
    g_spf = 32'd4;
    fat_fill32(32'h0FFFFFFF);
    fat_put32(0, 32'h00000000);
    fat_put32(1, 32'h00000000);
    for (i = 2; i <= 99; i = i + 1) fat_put32(i, 32'h00000000);
    fat_put32(100, 32'hF0000000);
    fat_put32(101, 32'h10000000);
    fat_put32(102, 32'h00000001);
    fat_put32(200, 32'h00000000);
    fat_put32(201, 32'h00000000);
    run_scan;
    chkv(free_mb == 3, "T15 precondition free_mb", free_mb, 3);
    em_fail_on = 0;                  // the very first read fails
    run_scan;
    em_fail_on = -1;
    chkv(obs_err == 1, "T15 err on the failed scan", obs_err, 1);
    chkv(free_clusters == 0, "T15 free_clusters cleared by start",
         free_clusters, 0);
    chkv(free_mb == 3, "T15 free_mb SURVIVES a new scan (characterisation)",
         free_mb, 3);

    // ---- verdict -----------------------------------------------------------
    repeat (4) @(posedge clk);
    $display("checks=%0d failures=%0d", checks, errors);
    if (errors == 0) $display("TB_RESULT: PASS");
    else $display("TB_RESULT: FAIL");
    $finish;
  end

endmodule

`default_nettype wire

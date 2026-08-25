/****************************************************************************
** sd_fat_rewrite - byte-exact FAT16 surgery testbench                     **
**                                                                         **
** Full path:                                                              **
**   Verilog/SD-FAT/sim/sd_fat_rewrite_tb.v                                **
**                                                                         **
** WHAT IS VERIFIED                                                        **
**   sd_fat_rewrite (Verilog/SD-FAT/circuit/sd_fat_rewrite.v) edits a live **
**   FAT filesystem in place: it frees a file's old cluster chain, finds a **
**   contiguous free run, writes the new chain into every FAT copy, and    **
**   patches the 32-byte directory entry. Every one of those is a WRITE TO **
**   A REAL CARD, so the only verification worth having is byte-exact: not **
**   "did it finish", but "which bytes of which sectors changed, and to    **
**   what".                                                                **
**                                                                         **
**   This bench therefore keeps a SHADOW IMAGE. Before each operation the  **
**   shadow is copied from the card; the expected changes - and ONLY the   **
**   expected changes - are then applied to the shadow by hand; afterwards **
**   all 16 sectors x 512 bytes are compared. A stray byte anywhere in the **
**   image fails the test, which is what catches a wrong sector number, a  **
**   wrong offset, an off-by-one in the write-latency dance, or a second   **
**   FAT copy landing in the wrong place.                                  **
**                                                                         **
** WHERE THE REFERENCE MODEL COMES FROM                                    **
**   Not from any FAT specification and not from how other FAT writers     **
**   behave. Every expected byte in this file was derived by hand from the **
**   RTL itself:                                                           **
**     - fat_sec()/fat_off()          sd_fat_rewrite.v:117-122             **
**     - the S_FREE_Z zeroing and its write-latency rule  :279-296         **
**     - S_SCAN_DEC's free-run bookkeeping                :338-360         **
**     - chain_val (next cluster, or EOC on the last)     :221-224         **
**     - S_DIR_P / S_DIR_P2 field offsets 0x1C-0x1F, 0x1A/0x1B, 0x14/0x15  **
**     - crbyte()'s fresh 8.3 entry layout                :204-219         **
**   The geometry below (cluster_size=1, so 512 bytes per cluster, one FAT **
**   sector holding clusters 0..255) was chosen so that every cluster the  **
**   tests touch lives in ONE FAT sector, which makes the expected sector  **
**   traffic countable by hand.                                            **
**                                                                         **
** THE ENGINE MODEL                                                        **
**   A behavioural stand-in for sd_writer driving a 16-sector card image.  **
**     read  (eng_rd=1): stream bytes 0..N-1 on eng_rx_we/addr/data, one   **
**                       per clock, then pulse eng_done.                   **
**     write (eng_rd=0): walk eng_tx_addr 0..N-1 giving eng_tx_data - a    **
**                       REGISTERED read of the DUT's buffer               **
**                       (sd_fat_rewrite.v:113) - one full clock to        **
**                       settle before sampling, then pulse eng_done.      **
**   N is 512 for every functional test. Switches inject eng_err on the    **
**   next read or the next write, and freeze the card (writes acknowledged **
**   but not stored) for the chain-loop test.                              **
**                                                                         **
** TEST PLAN                                                               **
**   T1  realloc=0: ONLY the size dword at entry+0x1C..0x1F changes; the   **
**       first-cluster fields at +0x1A/+0x1B and +0x14/+0x15 are untouched;**
**       exactly one read and one write, both of dir_sector.               **
**   T2  realloc=1, K = ceil(new_size / 512) boundaries: 512 -> 1 cluster, **
**       513 -> 2, 0 -> 1 (forced), and a 5-cluster case that must reuse   **
**       clusters it has just freed. Full byte-exact FAT + directory check.**
**   T3  no contiguous space: err, err_kind=0, and NOT ONE sector written. **
**   T4  injected READ failure  -> err_kind=1, card untouched.             **
**   T5  injected WRITE failure -> err_kind=2.                             **
**   T6  chain loop while freeing -> err_kind=3. See the caveat below.     **
**   T7  create=1: the FIRST free root slot wins (a 0xE5 deleted entry     **
**       ahead of never-used 0x00 entries), the fresh 8.3 entry is exact,  **
**       and the flush goes to the sector the slot was FOUND in - with     **
**       dir_sector deliberately set to 0, sector 0 must never be written  **
**       (the field failure recorded at sd_fat_rewrite.v:451-459).         **
**   T8  root directory full -> err, err_kind=0.                           **
**   T9  num_fats=1: FAT copy #1 is not written at all.                    **
**                                                                         **
** CAVEAT ON T6 - stated plainly rather than faked                         **
**   err_kind=3 needs guard[16], i.e. 65536 chain hops. On a working card  **
**   that is UNREACHABLE: the free walk ZEROES each entry as it visits it  **
**   and writes the sector back, so any real loop self-heals within its    **
**   own length and then terminates through the "cur < 2" exit instead.    **
**   To reach the guard at all this bench freezes the card (writes are     **
**   acknowledged but discarded) and shortens the transfer to 8 bytes per  **
**   sector, purely to make 65536 hops simulatable. Both are artificial    **
**   and are the reason T6 checks only the verdict, never card content.    **
**   Build without -DSD_FAT_REWRITE_TB_LOOP to skip it.                    **
**                                                                         **
** HOW TO RUN                                                              **
**   cd Verilog/SD-FAT/sim && make test-fat-rewrite                        **
**   or:                                                                   **
**     iverilog -g2012 -o sd_fat_rewrite_tb.vvp \                          **
**              ../circuit/sd_fat_rewrite.v sd_fat_rewrite_tb.v            **
**     vvp -N sd_fat_rewrite_tb.vvp                                        **
**   Add -DSD_FAT_REWRITE_TB_LOOP for T6 (adds ~26 ms of simulated time).  **
**                                                                         **
** Last reviewed: 20-AUG-2026                                              **
** Ronny Hansen                                                            **
*****************************************************************************/
`timescale 1ns / 1ps
`default_nettype none

module sd_fat_rewrite_tb;

  // ------------------------------------------------------------ clock/reset
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

  // ------------------------------------------------------------ geometry
  // cluster_size = 1 sector  => 512 bytes per cluster
  // FAT16: fat_sec(c) = fat0 + (c>>8), fat_off(c) = 2*c
  //        so clusters 0..255 all live in ONE sector, sector 4.
  localparam integer SEC_FAT0  = 4;   // FAT copy #0, first sector
  localparam integer SEC_FAT1  = 6;   // = SEC_FAT0 + sectors_per_fat(2)
  localparam integer SEC_ROOT0 = 8;
  localparam integer SEC_ROOT1 = 9;

  localparam [31:0] G_FAT0    = 32'd4;
  localparam [31:0] G_SPF     = 32'd2;
  localparam [31:0] G_DATABAS = 32'd100;
  localparam [31:0] G_TOTAL   = 32'd200;
  // usable = 200 - (100 + 1*2) = 98 ; max_cluster = (98 >> 0) + 1 = 99
  localparam integer MAXCLU   = 99;

  localparam [87:0] NAME83 = "NEWFILE BIN";
  localparam [15:0] FDATE  = 16'h4A21;

  // ------------------------------------------------------------ DUT wiring
  reg         start = 1'b0;
  reg         realloc = 1'b0;
  reg         create = 1'b0;
  reg  [31:0] dir_sector = 32'd0;
  reg  [3:0]  dir_index = 4'd0;
  reg  [31:0] old_first_cluster = 32'd0;
  reg  [31:0] new_size = 32'd0;
  reg  [7:0]  num_fats = 8'd2;
  reg  [31:0] root_start = 32'd8;
  reg  [31:0] root_secs = 32'd2;

  wire        busy, done, err;
  wire [1:0]  err_kind;
  wire [31:0] new_first_cluster;

  wire        eng_start, eng_rd;
  wire [31:0] eng_sector;
  wire [7:0]  eng_tx_data;

  reg         eng_busy = 1'b0;
  reg         eng_done = 1'b0;
  reg         eng_err = 1'b0;
  reg         eng_rx_we = 1'b0;
  reg  [8:0]  eng_rx_addr = 9'd0;
  reg  [7:0]  eng_rx_data = 8'd0;
  reg  [8:0]  eng_tx_addr = 9'd0;

  sd_fat_rewrite DUT (
      .clk              (clk),
      .rst_n            (rst_n),
      .start            (start),
      .realloc          (realloc),
      .busy             (busy),
      .done             (done),
      .err              (err),
      .err_kind         (err_kind),
      .fs_is_fat32      (1'b0),
      .cluster_size     (8'd1),
      .fat0_sector      (G_FAT0),
      .sectors_per_fat  (G_SPF),
      .num_fats         (num_fats),
      .data_base_sector (G_DATABAS),
      .total_sectors    (G_TOTAL),
      .root_start       (root_start),
      .root_secs        (root_secs),
      .root_cluster     (32'd2),
      .create           (create),
      .name83           (NAME83),
      .fdate            (FDATE),
      .dir_sector       (dir_sector),
      .dir_index        (dir_index),
      .old_first_cluster(old_first_cluster),
      .new_size         (new_size),
      .new_first_cluster(new_first_cluster),
      .eng_start        (eng_start),
      .eng_rd           (eng_rd),
      .eng_sector       (eng_sector),
      .eng_busy         (eng_busy),
      .eng_done         (eng_done),
      .eng_err          (eng_err),
      .eng_rx_we        (eng_rx_we),
      .eng_rx_addr      (eng_rx_addr),
      .eng_rx_data      (eng_rx_data),
      .eng_tx_addr      (eng_tx_addr),
      .eng_tx_data      (eng_tx_data)
  );

  // ------------------------------------------------------------ card image
  localparam integer NSEC = 16;
  reg [7:0] card [0:NSEC-1][0:511];
  reg [7:0] shdw [0:NSEC-1][0:511];

  // engine model controls / instrumentation
  integer xfer_n     = 512;   // bytes moved per transfer
  reg     card_froze = 1'b0;  // writes acknowledged but discarded (T6 only)
  reg     inj_rd_err = 1'b0;
  reg     inj_wr_err = 1'b0;
  integer n_reads    = 0;
  integer n_writes   = 0;
  integer rd_log [0:63];
  integer wr_log [0:63];
  integer rd_n = 0;
  integer wr_n = 0;

  task clr_counts;
    begin
      n_reads = 0; n_writes = 0; rd_n = 0; wr_n = 0;
    end
  endtask

  // ------------------------------------------------- behavioural sd_writer
  integer e_a;
  integer e_sec;
  reg     e_rd;

  initial begin
    forever begin
      @(posedge clk); #1;
      if (eng_start && rst_n) begin
        e_sec = eng_sector;
        e_rd  = eng_rd;
        eng_busy = 1'b1;
        if (e_rd) begin
          if (rd_n < 64) begin rd_log[rd_n] = e_sec; rd_n = rd_n + 1; end
          if (inj_rd_err) begin
            inj_rd_err = 1'b0;
            repeat (3) @(posedge clk);
            #1 eng_err = 1'b1;
            @(posedge clk); #1 eng_err = 1'b0;
          end else begin
            n_reads = n_reads + 1;
            for (e_a = 0; e_a < xfer_n; e_a = e_a + 1) begin
              @(posedge clk); #1;
              eng_rx_we   = 1'b1;
              eng_rx_addr = e_a[8:0];
              eng_rx_data = (e_sec < NSEC) ? card[e_sec][e_a] : 8'h00;
            end
            @(posedge clk); #1;
            eng_rx_we = 1'b0;
            eng_done  = 1'b1;
            @(posedge clk); #1 eng_done = 1'b0;
          end
        end else begin
          if (wr_n < 64) begin wr_log[wr_n] = e_sec; wr_n = wr_n + 1; end
          if (inj_wr_err) begin
            inj_wr_err = 1'b0;
            repeat (3) @(posedge clk);
            #1 eng_err = 1'b1;
            @(posedge clk); #1 eng_err = 1'b0;
          end else begin
            n_writes = n_writes + 1;
            for (e_a = 0; e_a < xfer_n; e_a = e_a + 1) begin
              @(posedge clk); #1 eng_tx_addr = e_a[8:0];
              @(posedge clk); #1;
              if (!card_froze && e_sec < NSEC) card[e_sec][e_a] = eng_tx_data;
            end
            @(posedge clk); #1 eng_done = 1'b1;
            @(posedge clk); #1 eng_done = 1'b0;
          end
        end
        eng_busy = 1'b0;
      end
    end
  end

  // ------------------------------------------------------------ pulse latch
  reg       saw_done = 1'b0;
  reg       saw_err = 1'b0;
  reg [1:0] saw_kind = 2'd0;
  always @(posedge clk) begin
    #1;
    if (done) saw_done = 1'b1;
    if (err) begin saw_err = 1'b1; saw_kind = err_kind; end
  end

  // ------------------------------------------------------------ helpers
  integer ii, jj;

  task init_image;
    begin
      for (ii = 0; ii < NSEC; ii = ii + 1)
        for (jj = 0; jj < 512; jj = jj + 1) card[ii][jj] = 8'h00;

      // sector 0 - a recognisable boot sector. Nothing in this module has
      // any business writing here; T7 proves it does not.
      for (jj = 0; jj < 512; jj = jj + 1) card[0][jj] = jj[7:0] ^ 8'h5A;

      // FAT copy #0, sector 4 (clusters 0..255, two bytes each, little endian)
      fput16(SEC_FAT0, 0, 16'hFFF8);   // media descriptor
      fput16(SEC_FAT0, 1, 16'hFFFF);
      fput16(SEC_FAT0, 2, 16'hFFFF);   // in use
      fput16(SEC_FAT0, 3, 16'h0000);   // free
      fput16(SEC_FAT0, 4, 16'hFFFF);   // in use
      fput16(SEC_FAT0, 5, 16'h0000);   // free
      fput16(SEC_FAT0, 6, 16'h0000);   // free
      fput16(SEC_FAT0, 7, 16'hFFFF);   // in use
      fput16(SEC_FAT0, 8, 16'h0000);   // free
      fput16(SEC_FAT0, 9, 16'h0000);   // free
      fput16(SEC_FAT0, 10, 16'h000B);  // the target file's chain: 10 -> 11
      fput16(SEC_FAT0, 11, 16'h000C);  //                          11 -> 12
      fput16(SEC_FAT0, 12, 16'hFFFF);  //                          12 -> EOC
      fput16(SEC_FAT0, 13, 16'hFFFF);  // in use: caps the free run at 8..12
      // clusters 14.. stay 0 (free)

      // FAT copy #1, sector 6 - a true mirror
      for (jj = 0; jj < 512; jj = jj + 1) card[SEC_FAT1][jj] = card[SEC_FAT0][jj];

      // root directory sector 8: three live entries, then the target at 3
      mk_entry(SEC_ROOT0, 0, "FILE0   TXT");
      mk_entry(SEC_ROOT0, 1, "FILE1   TXT");
      mk_entry(SEC_ROOT0, 2, "FILE2   TXT");
      mk_entry(SEC_ROOT0, 3, "TARGET  BIN");
      eput16(SEC_ROOT0, 3, 8'h1A, 16'd10);      // first cluster = 10
      eput16(SEC_ROOT0, 3, 8'h14, 16'hBEEF);    // FAT16 reserved: must survive
      eput32(SEC_ROOT0, 3, 8'h1C, 32'd1500);    // size
    end
  endtask

  // write FAT16 entry c (little endian) into sector s
  task fput16(input integer s, input integer c, input [15:0] v);
    begin
      card[s][2*c]     = v[7:0];
      card[s][2*c + 1] = v[15:8];
    end
  endtask

  // 16/32-bit little-endian field at offset o inside 32-byte entry e
  task eput16(input integer s, input integer e, input [7:0] o, input [15:0] v);
    begin
      card[s][32*e + o]     = v[7:0];
      card[s][32*e + o + 1] = v[15:8];
    end
  endtask
  task eput32(input integer s, input integer e, input [7:0] o, input [31:0] v);
    begin
      card[s][32*e + o]     = v[7:0];
      card[s][32*e + o + 1] = v[15:8];
      card[s][32*e + o + 2] = v[23:16];
      card[s][32*e + o + 3] = v[31:24];
    end
  endtask

  // a plausible live 8.3 entry (byte 0 is neither 0x00 nor 0xE5)
  task mk_entry(input integer s, input integer e, input [87:0] nm);
    begin
      for (jj = 0; jj < 11; jj = jj + 1) card[s][32*e + jj] = nm[8*(10-jj) +: 8];
      card[s][32*e + 11] = 8'h20;
    end
  endtask

  // shadow-side equivalents (expected image)
  task sfput16(input integer s, input integer c, input [15:0] v);
    begin
      shdw[s][2*c]     = v[7:0];
      shdw[s][2*c + 1] = v[15:8];
    end
  endtask
  task seput16(input integer s, input integer e, input [7:0] o, input [15:0] v);
    begin
      shdw[s][32*e + o]     = v[7:0];
      shdw[s][32*e + o + 1] = v[15:8];
    end
  endtask
  task seput32(input integer s, input integer e, input [7:0] o, input [31:0] v);
    begin
      shdw[s][32*e + o]     = v[7:0];
      shdw[s][32*e + o + 1] = v[15:8];
      shdw[s][32*e + o + 2] = v[23:16];
      shdw[s][32*e + o + 3] = v[31:24];
    end
  endtask

  task snap;   // shadow := card
    begin
      for (ii = 0; ii < NSEC; ii = ii + 1)
        for (jj = 0; jj < 512; jj = jj + 1) shdw[ii][jj] = card[ii][jj];
    end
  endtask

  task mirror_shadow;  // FAT#1 is written from the SAME buffer as FAT#0
    begin
      for (jj = 0; jj < 512; jj = jj + 1) shdw[SEC_FAT1][jj] = shdw[SEC_FAT0][jj];
    end
  endtask

  integer cs, cb, cbad;
  task chk_image(input [8*72-1:0] tag);
    begin
      for (cs = 0; cs < NSEC; cs = cs + 1) begin
        cbad = -1;
        for (cb = 0; cb < 512; cb = cb + 1)
          if (cbad < 0 && card[cs][cb] !== shdw[cs][cb]) cbad = cb;
        checks = checks + 1;
        if (cbad >= 0) begin
          errors = errors + 1;
          $display("FAIL %0s: sector %0d byte %0d (0x%0h) got %02h expected %02h",
                   tag, cs, cbad, cbad[8:0], card[cs][cbad], shdw[cs][cbad]);
        end
      end
    end
  endtask

  task do_reset;
    begin
      @(negedge clk); rst_n = 1'b0;
      repeat (3) @(negedge clk);
      rst_n = 1'b1;
      @(negedge clk);
      saw_done = 1'b0; saw_err = 1'b0; saw_kind = 2'd0;
    end
  endtask

  integer wc;
  task run_op(input integer tmo);
    begin
      saw_done = 1'b0; saw_err = 1'b0; saw_kind = 2'd0;
      @(negedge clk); start = 1'b1;
      @(negedge clk); start = 1'b0;
      wc = 0;
      while (!saw_done && !saw_err && wc < tmo) begin
        @(posedge clk); #2; wc = wc + 1;
      end
      if (wc >= tmo) begin
        $display("checks=%0d failures=%0d", checks, errors + 1);
        $display("TB_RESULT: FAIL  (operation did not terminate in %0d clocks)", tmo);
        $finish;
      end
      repeat (2) @(negedge clk);
    end
  endtask

  // was any sector written outside the allowed set?
  integer q;
  task chk_never_wrote(input integer s, input [8*72-1:0] tag);
    integer hit;
    begin
      hit = 0;
      for (q = 0; q < wr_n; q = q + 1) if (wr_log[q] == s) hit = 1;
      chk(hit == 0, tag);
    end
  endtask

  // ------------------------------------------------------------ watchdog
  initial begin
    #500_000_000;
    $display("checks=%0d failures=%0d", checks, errors + 1);
    $display("TB_RESULT: FAIL  (watchdog: testbench did not finish)");
    $finish;
  end

  // ------------------------------------------------------------ VCD
  initial begin
    $dumpfile("sd_fat_rewrite_tb.vcd");
    $dumpvars(0, sd_fat_rewrite_tb);
  end

  // ------------------------------------------------------------ stimulus
  initial begin
    init_image;
    do_reset;

    // =====================================================================
    // T1  realloc = 0 : patch the size field and nothing else
    // =====================================================================
    realloc = 1'b0; create = 1'b0;
    dir_sector = 32'd8; dir_index = 4'd3;
    old_first_cluster = 32'd10;
    new_size = 32'h00123456;
    num_fats = 8'd2;
    snap; clr_counts;
    run_op(100000);

    chk(saw_done === 1'b1 && saw_err === 1'b0, "T1 did not finish cleanly");
    chk(new_first_cluster === 32'd10, "T1 new_first_cluster != old_first_cluster");
    chk(n_reads == 1, "T1 sector read count is not exactly 1");
    chk(n_writes == 1, "T1 sector write count is not exactly 1");
    chk(rd_n == 1 && rd_log[0] == 8, "T1 the read was not of dir_sector");
    chk(wr_n == 1 && wr_log[0] == 8, "T1 the write was not of dir_sector");
    // only the size dword may move
    seput32(SEC_ROOT0, 3, 8'h1C, 32'h00123456);
    chk_image("T1 realloc=0");
    // and say so explicitly for the two cluster fields
    chk(card[SEC_ROOT0][32*3 + 8'h1A] === 8'h0A &&
        card[SEC_ROOT0][32*3 + 8'h1B] === 8'h00, "T1 first-cluster 0x1A/0x1B was touched");
    chk(card[SEC_ROOT0][32*3 + 8'h14] === 8'hEF &&
        card[SEC_ROOT0][32*3 + 8'h15] === 8'hBE, "T1 reserved 0x14/0x15 was touched");

    // =====================================================================
    // T2a realloc = 1, new_size = 512 -> exactly ONE cluster
    //     old chain 10,11,12 is freed first; the first free cluster is 3.
    // =====================================================================
    init_image; do_reset;
    realloc = 1'b1; create = 1'b0;
    dir_sector = 32'd8; dir_index = 4'd3;
    old_first_cluster = 32'd10;
    new_size = 32'd512;
    num_fats = 8'd2;
    snap; clr_counts;
    run_op(200000);

    chk(saw_done === 1'b1 && saw_err === 1'b0, "T2a did not finish cleanly");
    chk(new_first_cluster === 32'd3, "T2a allocated the wrong first cluster");
    // expected image: chain 10,11,12 freed; cluster 3 = EOC; entry patched
    sfput16(SEC_FAT0, 10, 16'h0000);
    sfput16(SEC_FAT0, 11, 16'h0000);
    sfput16(SEC_FAT0, 12, 16'h0000);
    sfput16(SEC_FAT0, 3,  16'hFFFF);
    mirror_shadow;
    seput32(SEC_ROOT0, 3, 8'h1C, 32'd512);
    seput16(SEC_ROOT0, 3, 8'h1A, 16'd3);
    seput16(SEC_ROOT0, 3, 8'h14, 16'h0000);   // FAT16: written as zeros
    chk_image("T2a K=1");
    chk(n_reads == 6, "T2a read count (3 free hops + scan + chain + dir) wrong");
    chk(n_writes == 9, "T2a write count (3x2 free + 1x2 chain + 1 dir) wrong");
    chk_never_wrote(0, "T2a wrote sector 0");

    // =====================================================================
    // T2b new_size = 513 -> TWO clusters (one byte over the boundary)
    // =====================================================================
    init_image; do_reset;
    realloc = 1'b1; new_size = 32'd513;
    snap; clr_counts;
    run_op(200000);
    chk(saw_done === 1'b1 && saw_err === 1'b0, "T2b did not finish cleanly");
    // free 10,11,12 ; runs of 2: 3 alone(no), 5+6 yes -> first cluster 5
    chk(new_first_cluster === 32'd5, "T2b allocated the wrong first cluster");
    sfput16(SEC_FAT0, 10, 16'h0000);
    sfput16(SEC_FAT0, 11, 16'h0000);
    sfput16(SEC_FAT0, 12, 16'h0000);
    sfput16(SEC_FAT0, 5, 16'd6);       // 5 -> 6
    sfput16(SEC_FAT0, 6, 16'hFFFF);    // 6 -> EOC
    mirror_shadow;
    seput32(SEC_ROOT0, 3, 8'h1C, 32'd513);
    seput16(SEC_ROOT0, 3, 8'h1A, 16'd5);
    seput16(SEC_ROOT0, 3, 8'h14, 16'h0000);
    chk_image("T2b K=2");

    // =====================================================================
    // T2c new_size = 0 -> K forced to 1, never an empty chain
    // =====================================================================
    init_image; do_reset;
    realloc = 1'b1; new_size = 32'd0;
    snap; clr_counts;
    run_op(200000);
    chk(saw_done === 1'b1 && saw_err === 1'b0, "T2c did not finish cleanly");
    chk(new_first_cluster === 32'd3, "T2c size 0 did not still allocate cluster 3");
    sfput16(SEC_FAT0, 10, 16'h0000);
    sfput16(SEC_FAT0, 11, 16'h0000);
    sfput16(SEC_FAT0, 12, 16'h0000);
    sfput16(SEC_FAT0, 3, 16'hFFFF);
    mirror_shadow;
    seput32(SEC_ROOT0, 3, 8'h1C, 32'd0);
    seput16(SEC_ROOT0, 3, 8'h1A, 16'd3);
    seput16(SEC_ROOT0, 3, 8'h14, 16'h0000);
    chk_image("T2c K=1 forced");

    // =====================================================================
    // T2d new_size = 2560 -> FIVE clusters. The only run that long is
    //     8..12, which exists ONLY because 10,11,12 were just freed.
    // =====================================================================
    init_image; do_reset;
    realloc = 1'b1; new_size = 32'd2560;
    snap; clr_counts;
    run_op(200000);
    chk(saw_done === 1'b1 && saw_err === 1'b0, "T2d did not finish cleanly");
    chk(new_first_cluster === 32'd8, "T2d did not reuse the just-freed run at 8");
    sfput16(SEC_FAT0, 8,  16'd9);
    sfput16(SEC_FAT0, 9,  16'd10);
    sfput16(SEC_FAT0, 10, 16'd11);
    sfput16(SEC_FAT0, 11, 16'd12);
    sfput16(SEC_FAT0, 12, 16'hFFFF);
    mirror_shadow;
    seput32(SEC_ROOT0, 3, 8'h1C, 32'd2560);
    seput16(SEC_ROOT0, 3, 8'h1A, 16'd8);
    seput16(SEC_ROOT0, 3, 8'h14, 16'h0000);
    chk_image("T2d K=5 contiguous chain");
    chk(n_writes == 9, "T2d write count wrong (chain batched into one sector)");

    // =====================================================================
    // T3  no contiguous space: K larger than the whole volume.
    //     old_first_cluster = 0 so nothing is freed first - the refusal
    //     must cost ZERO sector writes.
    // =====================================================================
    init_image; do_reset;
    realloc = 1'b1; create = 1'b0;
    old_first_cluster = 32'd0;
    new_size = 32'd102400;              // 200 clusters, max_cluster = 99
    snap; clr_counts;
    run_op(200000);
    chk(saw_err === 1'b1 && saw_done === 1'b0, "T3 did not report err");
    chk(saw_kind === 2'd0, "T3 err_kind is not 0 (resource verdict)");
    chk(n_writes == 0, "T3 refusal wrote to the card");
    chk_image("T3 no space");

    // =====================================================================
    // T4  injected READ failure -> err_kind = 1, card untouched
    // =====================================================================
    init_image; do_reset;
    realloc = 1'b0; create = 1'b0;
    old_first_cluster = 32'd10;
    new_size = 32'd777;
    snap; clr_counts;
    inj_rd_err = 1'b1;
    run_op(200000);
    chk(saw_err === 1'b1 && saw_done === 1'b0, "T4 did not report err");
    chk(saw_kind === 2'd1, "T4 err_kind is not 1 (engine READ failed)");
    chk(n_writes == 0, "T4 wrote to the card after a read failure");
    chk_image("T4 read error");
    chk(busy === 1'b0, "T4 DUT did not return to idle");

    // =====================================================================
    // T5  injected WRITE failure -> err_kind = 2
    // =====================================================================
    init_image; do_reset;
    realloc = 1'b0;
    new_size = 32'd777;
    snap; clr_counts;
    inj_wr_err = 1'b1;
    run_op(200000);
    chk(saw_err === 1'b1 && saw_done === 1'b0, "T5 did not report err");
    chk(saw_kind === 2'd2, "T5 err_kind is not 2 (engine WRITE failed)");
    chk(n_reads == 1, "T5 did not read the directory sector first");
    chk_image("T5 write error");

    // =====================================================================
    // T7  create = 1 : first free root slot, exact fresh entry, and the
    //     flush must go to the sector the slot was FOUND in.
    //     dir_sector is deliberately 0 - sector 0 must survive.
    // =====================================================================
    init_image;
    // entry 3 becomes a DELETED slot with junk behind it; entries 4..15 are
    // never-used 0x00 slots. The scan must take 3, the first free one.
    card[SEC_ROOT0][32*3] = 8'hE5;
    for (jj = 1; jj < 32; jj = jj + 1) card[SEC_ROOT0][32*3 + jj] = 8'h5C;
    do_reset;
    realloc = 1'b0; create = 1'b1;
    dir_sector = 32'd0;      // WRONG on purpose (a created file has no entry)
    dir_index = 4'd15;       // WRONG on purpose
    old_first_cluster = 32'hDEADBEEF;   // ignored when create=1
    new_size = 32'd512;
    num_fats = 8'd2;
    root_start = 32'd8; root_secs = 32'd2;
    snap; clr_counts;
    run_op(300000);

    chk(saw_done === 1'b1 && saw_err === 1'b0, "T7 create did not finish cleanly");
    chk(new_first_cluster === 32'd3, "T7 created file got the wrong first cluster");
    chk_never_wrote(0, "T7 WROTE SECTOR 0 - the boot-sector destroying bug");
    chk_never_wrote(SEC_ROOT1, "T7 wrote root sector 9 (slot was in sector 8)");
    // expected: the fresh 8.3 entry at slot 3, then the size/cluster patch
    for (jj = 0; jj < 11; jj = jj + 1) shdw[SEC_ROOT0][32*3 + jj] = NAME83[8*(10-jj) +: 8];
    shdw[SEC_ROOT0][32*3 + 11] = 8'h20;                 // ATTR_ARCHIVE
    for (jj = 12; jj < 32; jj = jj + 1) shdw[SEC_ROOT0][32*3 + jj] = 8'h00;
    seput16(SEC_ROOT0, 3, 8'h10, FDATE);                // create date
    seput16(SEC_ROOT0, 3, 8'h12, FDATE);                // access date
    seput16(SEC_ROOT0, 3, 8'h18, FDATE);                // write date
    seput32(SEC_ROOT0, 3, 8'h1C, 32'd512);              // size patch
    seput16(SEC_ROOT0, 3, 8'h1A, 16'd3);                // first cluster patch
    // create frees nothing (oldc_r is forced to 0), so cluster 3 is the
    // first free one and 10/11/12 keep the old file's chain
    sfput16(SEC_FAT0, 3, 16'hFFFF);
    mirror_shadow;
    chk_image("T7 create");

    // =====================================================================
    // T8  root directory full -> err, err_kind = 0
    // =====================================================================
    init_image;
    for (ii = 0; ii < 16; ii = ii + 1) begin
      mk_entry(SEC_ROOT0, ii, "FULL    DIR");
      mk_entry(SEC_ROOT1, ii, "FULL    DIR");
    end
    do_reset;
    realloc = 1'b0; create = 1'b1;
    dir_sector = 32'd0; dir_index = 4'd0;
    new_size = 32'd512;
    root_start = 32'd8; root_secs = 32'd2;
    snap; clr_counts;
    run_op(300000);
    chk(saw_err === 1'b1 && saw_done === 1'b0, "T8 root-full did not report err");
    chk(saw_kind === 2'd0, "T8 err_kind is not 0 (root directory full)");
    chk(n_reads == 2, "T8 did not scan exactly the two root sectors");
    chk(n_writes == 0, "T8 wrote to the card with a full root directory");
    chk_image("T8 root full");

    // =====================================================================
    // T9  num_fats = 1 : FAT copy #1 must not be written at all
    // =====================================================================
    init_image; do_reset;
    realloc = 1'b1; create = 1'b0;
    dir_sector = 32'd8; dir_index = 4'd3;
    old_first_cluster = 32'd10;
    new_size = 32'd512;
    num_fats = 8'd1;
    snap; clr_counts;
    run_op(200000);
    chk(saw_done === 1'b1 && saw_err === 1'b0, "T9 did not finish cleanly");
    chk_never_wrote(SEC_FAT1, "T9 wrote FAT copy #1 with num_fats=1");
    chk(n_writes == 5, "T9 write count wrong (3 free + 1 chain + 1 dir)");
    sfput16(SEC_FAT0, 10, 16'h0000);
    sfput16(SEC_FAT0, 11, 16'h0000);
    sfput16(SEC_FAT0, 12, 16'h0000);
    sfput16(SEC_FAT0, 3,  16'hFFFF);
    seput32(SEC_ROOT0, 3, 8'h1C, 32'd512);
    seput16(SEC_ROOT0, 3, 8'h1A, 16'd3);
    seput16(SEC_ROOT0, 3, 8'h14, 16'h0000);
    chk_image("T9 num_fats=1");

`ifdef SD_FAT_REWRITE_TB_LOOP
    // =====================================================================
    // T6  chain loop -> err_kind = 3.  ARTIFICIAL, see the header: the card
    //     is frozen (writes discarded) and only 8 bytes move per sector, so
    //     the self-pointing entry survives long enough to reach guard[16]
    //     at 65536 hops. Verdict only - no card content is checked.
    // =====================================================================
    // 65536 near-identical hops would add a quarter of a GIGABYTE of
    // waveform and nothing at all to the timing diagram, so the dump is
    // stopped for the duration of this one test.
    $dumpoff;
    init_image;
    fput16(SEC_FAT0, 2, 16'h0002);      // cluster 2 points at itself
    do_reset;
    realloc = 1'b1; create = 1'b0;
    dir_sector = 32'd8; dir_index = 4'd3;
    old_first_cluster = 32'd2;
    new_size = 32'd512;
    num_fats = 8'd1;                    // halve the writes: hops are cheaper
    xfer_n = 8;                         // only the entry bytes at 4,5 matter
    card_froze = 1'b1;
    clr_counts;
    run_op(20000000);
    chk(saw_err === 1'b1 && saw_done === 1'b0, "T6 chain loop did not report err");
    chk(saw_kind === 2'd3, "T6 err_kind is not 3 (FAT chain corrupt)");
    xfer_n = 512;
    card_froze = 1'b0;
    $dumpon;
`endif

    // ------------------------------------------------------------ verdict
    repeat (4) @(posedge clk);
    $display("checks=%0d failures=%0d", checks, errors);
    if (errors == 0) $display("TB_RESULT: PASS");
    else $display("TB_RESULT: FAIL");
    $finish;
  end

endmodule

`default_nettype wire

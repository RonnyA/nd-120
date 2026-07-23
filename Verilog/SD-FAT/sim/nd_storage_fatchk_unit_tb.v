/****************************************************************************
** Unit testbench for nd_storage_fatchk (iverilog)                         **
**                                                                         **
** The contiguity checker against a SCRIPTED sd_writer read-mode stub      **
** serving synthetic FAT sectors from a byte array (no card model, no     **
** mount - pure unit tb, runs in seconds). The stub honors the real       **
** engine shape: one start pulse, rx_we byte stream (1 byte / 4 clk),     **
** done a few cycles after the last byte, err injection on demand, and    **
** it FAILS the run on any sector outside the synthetic FAT window        **
** (catches bad fat_sec math).                                            **
**                                                                         **
** Cases (design doc section 2.4):                                        **
**   FAT16: contiguous ok (1 read - sector cache), FAT-sector-crossing    **
**   chain ok (exactly 2 reads: re-read on sector change only),           **
**   fragmented -> bad, missing EOC -> bad, EOC threshold 0xFFF7 ok /     **
**   0xFFF6 bad, cluster_size=4 single-cluster ok.                        **
**   FAT32: contiguous with garbage in entry bits [31:28] ok (28-bit      **
**   mask), fragmented -> bad, EOC threshold 0x0FFFFFF7 ok / 0x0FFFFFF6   **
**   bad.                                                                 **
**   Guards: size 0 -> ok with ZERO reads; first_cluster 0/1 -> bad,      **
**   zero reads; cluster_size 0 -> bad; cluster count > HOP_CAP -> bad,   **
**   zero reads; injected engine err -> bad; a clean run AFTER the err    **
**   run passes (the checker does not wedge).                             **
**                                                                         **
** Request pulses are NONBLOCKING one-cycle pulses; every wait polls      **
** busy-RISE before polling it low; absolute watchdog 10 ms.              **
**                                                                         **
** Verdict: TB_RESULT: PASS / TB_RESULT: FAIL <reason>                     **
**                                                                         **
** Last reviewed: 11-JUL-2026                                              **
** Ronny Hansen                                                            **
*****************************************************************************/
`timescale 1ns / 1ps

module nd_storage_fatchk_unit_tb;

  localparam HALF     = 18.5;      // ~27 MHz
  localparam FAT0_SEC = 32'd100;   // synthetic FAT window: sectors 100..107
  localparam FAT_SECS = 8;

  reg clk = 0;
  always #HALF clk = ~clk;
  reg rst_n = 0;

  // ------------------------------------------------------------- DUT
  reg         t_start = 0;
  reg         t_f32 = 0;
  reg  [7:0]  t_cs = 8'd1;
  reg  [31:0] t_first = 0;
  reg  [31:0] t_size = 0;
  wire        chk_busy, chk_done, chk_ok;
  wire        e_start;
  wire [31:0] e_sector;
  reg         e_done = 0;
  reg         e_err = 0;
  reg         e_rx_we = 0;
  reg  [8:0]  e_rx_addr = 0;
  reg  [7:0]  e_rx_data = 0;

  nd_storage_fatchk #(
      .WD_MAX(32'd200_000)
  ) dut (
      .clk_stor     (clk),
      .rst_stor_n   (rst_n),
      .chk_start    (t_start),
      .chk_busy     (chk_busy),
      .chk_done     (chk_done),
      .chk_ok       (chk_ok),
      .fs_is_fat32  (t_f32),
      .cluster_size (t_cs),
      .fat0_sector  (FAT0_SEC),
      .first_cluster(t_first),
      .size_bytes   (t_size),
      .sdw_start    (e_start),
      .sdw_sector   (e_sector),
      .sdw_done     (e_done),
      .sdw_err      (e_err),
      .sdw_rx_we    (e_rx_we),
      .sdw_rx_addr  (e_rx_addr),
      .sdw_rx_data  (e_rx_data)
  );

  // ------------------------------------------------------------- engine stub
  reg [7:0] fat_img[0:FAT_SECS*512-1];

  reg         err_mode = 0;
  reg         serving = 0;
  reg  [31:0] srv_sec = 0;
  integer     srv_i = 0, srv_div = 0, err_cnt = 0, done_cnt = 0;
  integer     reads = 0;

  always @(posedge clk) begin
    e_done  <= 1'b0;
    e_err   <= 1'b0;
    e_rx_we <= 1'b0;
    if (e_start) begin
      reads = reads + 1;
      if (err_mode) begin
        err_cnt <= 32;  // err a while after start, like a real timeout
      end else begin
        if (e_sector < FAT0_SEC || e_sector >= FAT0_SEC + FAT_SECS) begin
          $display("TB_RESULT: FAIL read outside the FAT window (sector %0d)",
                   e_sector);
          $finish;
        end
        serving  <= 1'b1;
        srv_sec  <= e_sector;
        srv_i    <= 0;
        srv_div  <= 0;
        done_cnt <= 0;
      end
    end else if (err_cnt > 0) begin
      err_cnt <= err_cnt - 1;
      if (err_cnt == 1) e_err <= 1'b1;
    end else if (serving) begin
      if (srv_i < 512) begin
        srv_div <= srv_div + 1;
        if (srv_div == 3) begin  // one byte per 4 clk
          srv_div   <= 0;
          e_rx_we   <= 1'b1;
          e_rx_addr <= srv_i[8:0];
          e_rx_data <= fat_img[(srv_sec-FAT0_SEC)*512+srv_i];
          srv_i     <= srv_i + 1;
        end
      end else begin
        done_cnt <= done_cnt + 1;  // CRC/end-bit gap before done
        if (done_cnt == 8) begin
          serving <= 1'b0;
          e_done  <= 1'b1;
        end
      end
    end
  end

  // ------------------------------------------------------------- helpers
  integer errors = 0;
  reg seen_done = 0;
  always @(posedge clk) if (chk_done) seen_done = 1;

  task clear_fat;
    integer i;
    begin
      for (i = 0; i < FAT_SECS * 512; i = i + 1) fat_img[i] = 8'h00;
    end
  endtask

  task set16(input [31:0] c, input [15:0] v);
    begin  // linear FAT16 entry (byte offset c*2 from FAT start)
      fat_img[c*2]   = v[7:0];
      fat_img[c*2+1] = v[15:8];
    end
  endtask

  task set32(input [31:0] c, input [31:0] v);
    begin  // linear FAT32 entry (byte offset c*4 from FAT start)
      fat_img[c*4]   = v[7:0];
      fat_img[c*4+1] = v[15:8];
      fat_img[c*4+2] = v[23:16];
      fat_img[c*4+3] = v[31:24];
    end
  endtask

  task run_chk(input f32, input [7:0] cs, input [31:0] first,
               input [31:0] size, input exp_ok, input integer exp_reads,
               input [255:0] what);
    integer guard;
    begin
      t_f32     = f32;
      t_cs      = cs;
      t_first   = first;
      t_size    = size;
      reads     = 0;
      seen_done = 0;
      @(posedge clk);
      t_start <= 1'b1;
      @(posedge clk);
      t_start <= 1'b0;
      // busy must RISE first, then fall
      guard = 0;
      while (!chk_busy && guard < 100) begin
        @(posedge clk);
        guard = guard + 1;
      end
      if (!chk_busy) begin
        $display("TB_RESULT: FAIL %0s: checker never went busy", what);
        $finish;
      end
      guard = 0;
      while (chk_busy && guard < 200_000) begin
        @(posedge clk);
        guard = guard + 1;
      end
      if (chk_busy) begin
        $display("TB_RESULT: FAIL %0s: checker hung", what);
        $finish;
      end
      repeat (5) @(posedge clk);
      if (!seen_done) begin
        $display("FAIL: %0s: no chk_done pulse", what);
        errors = errors + 1;
      end
      if (chk_ok !== exp_ok) begin
        $display("FAIL: %0s: chk_ok=%b (want %b)", what, chk_ok, exp_ok);
        errors = errors + 1;
      end
      if (exp_reads >= 0 && reads !== exp_reads) begin
        $display("FAIL: %0s: %0d FAT sector reads (want %0d)", what, reads,
                 exp_reads);
        errors = errors + 1;
      end
    end
  endtask

  // ------------------------------------------------------------- test
  integer i;
  initial begin
    clear_fat;
    repeat (10) @(posedge clk);
    rst_n = 1;
    repeat (10) @(posedge clk);

    // ---- FAT16: contiguous chain, one FAT sector, one read -------------
    for (i = 10; i < 15; i = i + 1) set16(i, i[15:0] + 16'd1);
    set16(15, 16'hFFFF);
    run_chk(0, 8'd1, 32'd10, 32'd3001, 1'b1, 1, "f16 contiguous");

    // ---- FAT16: chain crosses a FAT sector boundary, exactly 2 reads ---
    for (i = 250; i < 261; i = i + 1) set16(i, i[15:0] + 16'd1);
    set16(261, 16'hFFF8);
    run_chk(0, 8'd1, 32'd250, 32'd6144, 1'b1, 2, "f16 sector crossing");

    // ---- FAT16: fragmented at the first hop -----------------------------
    set16(10, 16'd20);
    run_chk(0, 8'd1, 32'd10, 32'd3001, 1'b0, -1, "f16 fragmented");
    set16(10, 16'd11);  // repair

    // ---- FAT16: missing EOC (last entry keeps pointing on) --------------
    set16(15, 16'd16);
    run_chk(0, 8'd1, 32'd10, 32'd3001, 1'b0, -1, "f16 missing EOC");

    // ---- FAT16: EOC threshold 0xFFF7 ok / 0xFFF6 bad ---------------------
    set16(15, 16'hFFF7);
    run_chk(0, 8'd1, 32'd10, 32'd3001, 1'b1, -1, "f16 EOC 0xFFF7");
    set16(15, 16'hFFF6);
    run_chk(0, 8'd1, 32'd10, 32'd3001, 1'b0, -1, "f16 EOC 0xFFF6");
    set16(15, 16'hFFFF);  // repair

    // ---- FAT16: cluster_size 4 (2048 B/cluster), single-cluster file ----
    set16(30, 16'hFFFF);
    run_chk(0, 8'd4, 32'd30, 32'd2048, 1'b1, 1, "f16 cs4 single");

    // ---- FAT32: contiguous, garbage in bits [31:28] (28-bit mask) -------
    set32(5, 32'hF000_0006);
    set32(6, 32'h3000_0007);
    set32(7, 32'h0000_0008);
    set32(8, 32'hAFFF_FFFF);  // masked 0x0FFFFFFF: proper EOC
    run_chk(1, 8'd1, 32'd5, 32'd2048, 1'b1, 1, "f32 contiguous");

    // ---- FAT32: fragmented ----------------------------------------------
    set32(6, 32'h3000_0009);
    run_chk(1, 8'd1, 32'd5, 32'd2048, 1'b0, -1, "f32 fragmented");
    set32(6, 32'h3000_0007);  // repair

    // ---- FAT32: EOC threshold 0x0FFFFFF7 ok / 0x0FFFFFF6 bad -------------
    set32(8, 32'h0FFF_FFF7);
    run_chk(1, 8'd1, 32'd5, 32'd2048, 1'b1, -1, "f32 EOC ...F7");
    set32(8, 32'h0FFF_FFF6);
    run_chk(1, 8'd1, 32'd5, 32'd2048, 1'b0, -1, "f32 EOC ...F6");
    set32(8, 32'hAFFF_FFFF);  // repair

    // ---- guards -----------------------------------------------------------
    run_chk(0, 8'd1, 32'd10, 32'd0, 1'b1, 0, "size 0 (no traffic)");
    run_chk(0, 8'd1, 32'd0, 32'd512, 1'b0, 0, "first_cluster 0");
    run_chk(0, 8'd1, 32'd1, 32'd512, 1'b0, 0, "first_cluster 1");
    run_chk(0, 8'd0, 32'd10, 32'd512, 1'b0, 0, "cluster_size 0");
    // 128 MB at 512 B/cluster = 262144 clusters > HOP_CAP (1<<17): refuse
    run_chk(0, 8'd1, 32'd10, 32'h0800_0000, 1'b0, 0, "hop cap");

    // ---- injected engine error, then a clean run (no wedge) --------------
    // (rebuild the FAT16 chain first: the FAT32 entries at clusters 5..8
    // occupy linear bytes 20..35 = FAT16 clusters 10..17)
    for (i = 10; i < 15; i = i + 1) set16(i, i[15:0] + 16'd1);
    set16(15, 16'hFFFF);
    err_mode = 1;
    run_chk(0, 8'd1, 32'd10, 32'd3001, 1'b0, -1, "engine err");
    err_mode = 0;
    run_chk(0, 8'd1, 32'd10, 32'd3001, 1'b1, 1, "clean after err");

    if (errors == 0) $display("TB_RESULT: PASS");
    else $display("TB_RESULT: FAIL %0d errors", errors);
    $finish;
  end

  initial begin
    #10_000_000;  // 10 ms absolute watchdog
    $display("TB_RESULT: FAIL absolute watchdog");
    $finish;
  end

endmodule

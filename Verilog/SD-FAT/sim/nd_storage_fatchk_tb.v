/****************************************************************************
** Full-stack fatchk testbench for nd_storage (iverilog)                   **
**                                                                         **
** The mount-time contiguity gate (SDFAT_STORAGE_CHECK) through the real  **
** stack: nd_storage (reader + writer + mount + fatchk + engine + SD pin  **
** mux) against the behavioral SD card model serving the FAT16 image     **
** built by make_storage_image.sh - which contains FRAG.IMG, a 2048-byte  **
** file whose cluster chain is DELIBERATELY fragmented (the script walks  **
** the FAT and refuses to emit the image unless it verifiably is).        **
** Client 0 of the DUT is parameterized to FRAG.IMG; client 1 keeps the   **
** default FLOPPY1.IMG (4096 B, contiguous). Skewed clocks (clk_cpu       **
** ~23.04 MHz, clk_stor ~27.03 MHz), SIMULATE=1, WR_CLKDIV=1 (13.5 MHz   **
** class FAT reads - the hardware setting, proven by test-writer-div1).   **
**                                                                         **
** Split out of nd_storage_tb.v on purpose: the mount gate was already    **
** minutes of iverilog wall time, so the check cases run as their own     **
** registered target (test-nds-fatchk). Checks:                           **
**                                                                         **
**   (a) open client 0 (FRAG.IMG): the mount runs M_LOAD/M_PARK/M_CHK,   **
**       the checker reads the FAT via sd_writer CMD17 and fails the      **
**       open: done+err, open_err level, NO open_ok; sd_status ERROR.     **
**       (The SDRAM slot legitimately received the preload - the check    **
**       runs after M_LOAD by design; the contract is open_err only.)     **
**   (b) open client 1 (FLOPPY1.IMG, contiguous): the SAME checker path   **
**       passes it - open_ok, size 4096, n_blocks 2, sd_status OK (the   **
**       fragmented neighbor changes nothing).                            **
**   (c) reopen client 0: open_err again - a check-failed open leaves     **
**       nothing wedged and stays repeatable (the retry contract).        **
**   plus: the checker verifiably RAN (3 chk_done pulses, >= 1 CMD17     **
**       FAT read per card-touching open), card model health (CRC7 = 0,  **
**       ZERO writes via LEGAL_MIN_SECTOR = whole card - the checker is  **
**       read-only), preload FIFO overflow sticky = 0, engine watchdog   **
**       never fired.                                                     **
**                                                                         **
** Request pulses are NONBLOCKING one-cycle pulses; every wait polls      **
** busy-RISE before polling it low; absolute watchdog 150 ms.             **
**                                                                         **
** Verdict: TB_RESULT: PASS / TB_RESULT: FAIL <reason>                     **
**                                                                         **
** Last reviewed: 11-JUL-2026                                              **
** Ronny Hansen                                                            **
*****************************************************************************/
`timescale 1ns / 1ps
`include "sd_fat_features.vh"

module nd_storage_fatchk_tb;

  localparam STOR_HALF = 18.5;  // ~27.03 MHz
  localparam CPU_HALF  = 21.7;  // ~23.04 MHz
  localparam N         = 7;

  localparam integer FLP_BYTES = 4096;
  localparam IMG_BYTES = 4 * 1024 * 1024;
  localparam IMG_SECTORS = IMG_BYTES / 512;

  reg clk_stor = 0;
  always #STOR_HALF clk_stor = ~clk_stor;
  reg clk_cpu = 0;
  always #CPU_HALF clk_cpu = ~clk_cpu;

  reg rst_n = 0;

`ifndef SDFAT_STORAGE_CHECK
  initial begin
    $display("TB_RESULT: FAIL built without SDFAT_STORAGE_CHECK");
    $finish;
  end
`endif

  // ------------------------------------------------------------- DUT
  wire        sd_clk, sd_cmd_o, sd_cmd_oe, sd_dat0_o, sd_dat0_oe;
  wire        sd_cmd, sd_dat0;  // resolved pads
  pullup (sd_cmd);
  pullup (sd_dat0);
  assign sd_cmd  = sd_cmd_oe ? sd_cmd_o : 1'bz;
  assign sd_dat0 = sd_dat0_oe ? sd_dat0_o : 1'bz;

  wire        mem_start_w, mem_we_w, mem_busy_w, mem_done_w;
  wire [19:0] mem_addr_w;
  wire [31:0] mem_wdata_w, mem_rdata_w;

  reg  [N-1:0]    t_open_req = 0;
  wire [N-1:0]    open_ok_w, open_err_w, busy_w, done_w, err_w, buf_we_w;
  wire [N*32-1:0] size_bytes_w;
  wire [N*10-1:0] buf_addr_w;
  wire [N*16-1:0] buf_wdata_w;

  wire [1:0] sd_status_w, card_type_w, fs_type_w;

  nd_storage #(
      .N_CLIENTS (N),
      .RD_CLK_DIV(3'd1),           // 27 MHz class clock in the tb
      .WR_CLKDIV (8'd1),           // 13.5 MHz class FAT reads (hw setting)
      .WD_MAX    (32'd5_000_000),
      .SIMULATE  (1),
      .FILE0_NAME("FRAG.IMG"),     // client 0 = the fragmented file
      .FILE0_LEN (8'd8)
  ) dut (
      .clk_stor  (clk_stor),
      .rst_stor_n(rst_n),
      .clk_cpu   (clk_cpu),
      .rst_cpu_n (rst_n),
      .sd_clk_o  (sd_clk),
      .sd_cmd_i  (sd_cmd),
      .sd_cmd_o  (sd_cmd_o),
      .sd_cmd_oe (sd_cmd_oe),
      .sd_dat0_i (sd_dat0),
      .sd_dat0_o (sd_dat0_o),
      .sd_dat0_oe(sd_dat0_oe),
      .mem_start (mem_start_w),
      .mem_we    (mem_we_w),
      .mem_addr  (mem_addr_w),
      .mem_wdata (mem_wdata_w),
      .mem_rdata (mem_rdata_w),
      .mem_busy  (mem_busy_w),
      .mem_done  (mem_done_w),
      .open_req  (t_open_req),
      .open_ok   (open_ok_w),
      .open_err  (open_err_w),
      .size_bytes(size_bytes_w),
      .req       ({N{1'b0}}),
      .wr        ({N{1'b0}}),
      .block     ({N{16'd0}}),
      .busy      (busy_w),
      .done      (done_w),
      .err       (err_w),
      .buf_addr  (buf_addr_w),
      .buf_wdata (buf_wdata_w),
      .buf_we    (buf_we_w),
      .buf_rdata ({N{16'd0}}),
      .sd_status (sd_status_w),
      .card_type (card_type_w),
      .fs_type   (fs_type_w)
  );

  nds_mem_model #(
      .MEM_WORDS(32768)
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

  // the checker only READS: any card write at all is illegal in this tb
  sd_card_model #(
      .IMAGE           ("nds_storage.img"),
      .MAX_BYTES       (IMG_BYTES),
      .LEGAL_MIN_SECTOR(IMG_SECTORS)
  ) card (
      .sd_clk (sd_clk),
      .sd_cmd (sd_cmd),
      .sd_dat0(sd_dat0)
  );

  // ------------------------------------------------------------- monitors
  integer errors = 0;

`ifdef SDFAT_STORAGE_CHECK
  integer chk_dones = 0;
  always @(posedge clk_stor) if (dut.u_fatchk.chk_done) chk_dones = chk_dones + 1;
  integer fat_reads = 0;
  always @(posedge clk_stor) if (dut.u_fatchk.sdw_start) fat_reads = fat_reads + 1;
`endif

  // ------------------------------------------------------------- helpers
  task wait_op(input [2:0] c, input [31:0] max_cpu_cycles, input [127:0] what);
    integer guard;
    begin
      // busy must RISE first - polling low immediately would race the FE
      guard = 0;
      while (!busy_w[c] && guard < 1000) begin
        @(posedge clk_cpu);
        guard = guard + 1;
      end
      if (!busy_w[c]) begin
        $display("TB_RESULT: FAIL %0s: client %0d never went busy", what, c);
        $finish;
      end
      guard = 0;
      while (busy_w[c] && guard < max_cpu_cycles) begin
        @(posedge clk_cpu);
        guard = guard + 1;
      end
      if (busy_w[c]) begin
        $display("TB_RESULT: FAIL %0s: client %0d op hung", what, c);
        $finish;
      end
      repeat (20) @(posedge clk_cpu);  // let levels (open_ok/err) settle
    end
  endtask

  task do_open(input [2:0] c, input [127:0] what);
    begin
      @(posedge clk_cpu);
      t_open_req[c] <= 1'b1;
      @(posedge clk_cpu);
      t_open_req[c] <= 1'b0;
      wait_op(c, 32'd3_000_000, what);
    end
  endtask

  // ------------------------------------------------------------- test
  initial begin
    repeat (10) @(posedge clk_stor);
    rst_n = 1;
    repeat (50) @(posedge clk_cpu);

    // ---- (a) open client 0: FRAG.IMG is fragmented -> the check fails --
    do_open(3'd0, "open frag");
    if (err_w[0] !== 1'b1 || open_err_w[0] !== 1'b1 || open_ok_w[0] !== 1'b0) begin
      $display("FAIL: frag open flags (err=%b oerr=%b ok=%b)",
               err_w[0], open_err_w[0], open_ok_w[0]);
      errors = errors + 1;
    end
    if (sd_status_w !== 2'd2) begin
      $display("FAIL: sd_status not ERROR after frag open (%0d)", sd_status_w);
      errors = errors + 1;
    end

    // ---- (b) open client 1: contiguous FLOPPY1.IMG passes the checker --
    do_open(3'd1, "open floppy1");
    if (err_w[1] !== 1'b0 || open_ok_w[1] !== 1'b1 || open_err_w[1] !== 1'b0) begin
      $display("FAIL: floppy1 open flags (err=%b ok=%b oerr=%b)",
               err_w[1], open_ok_w[1], open_err_w[1]);
      errors = errors + 1;
    end
    if (size_bytes_w[63:32] !== FLP_BYTES[31:0]) begin
      $display("FAIL: floppy1 size_bytes %0d (want %0d)",
               size_bytes_w[63:32], FLP_BYTES);
      errors = errors + 1;
    end
    if (dut.u_mount.r_nblk[1] !== 16'd2) begin
      $display("FAIL: floppy1 n_blocks %0d (want 2)", dut.u_mount.r_nblk[1]);
      errors = errors + 1;
    end
    if (sd_status_w !== 2'd3) begin
      $display("FAIL: sd_status not OK after floppy1 open (%0d)", sd_status_w);
      errors = errors + 1;
    end

    // ---- (c) reopen client 0: the failed open is cleanly retryable -----
    do_open(3'd0, "reopen frag");
    if (err_w[0] !== 1'b1 || open_err_w[0] !== 1'b1 || open_ok_w[0] !== 1'b0) begin
      $display("FAIL: frag reopen flags (err=%b oerr=%b ok=%b)",
               err_w[0], open_err_w[0], open_ok_w[0]);
      errors = errors + 1;
    end
    if (open_ok_w[1] !== 1'b1) begin
      $display("FAIL: floppy1 open_ok lost across the frag reopen");
      errors = errors + 1;
    end

    // ---- health ---------------------------------------------------------
`ifdef SDFAT_STORAGE_CHECK
    if (chk_dones !== 3) begin
      $display("FAIL: checker ran %0d times (want 3: every open gated)",
               chk_dones);
      errors = errors + 1;
    end
    if (fat_reads < 3) begin
      $display("FAIL: only %0d CMD17 FAT reads (want >= 1 per open)", fat_reads);
      errors = errors + 1;
    end
`endif
    if (card.crc_errors !== 0) begin
      $display("FAIL: CMD CRC7 errors (%0d)", card.crc_errors);
      errors = errors + 1;
    end
    if (card.illegal_writes !== 0) begin
      $display("FAIL: card writes in a read-only tb (%0d)", card.illegal_writes);
      errors = errors + 1;
    end
    if (dut.u_mount.load_fifo_ovf !== 1'b0) begin
      $display("FAIL: mount preload FIFO overflowed");
      errors = errors + 1;
    end
    if (dut.u_engine.eng_wd_err !== 1'b0) begin
      $display("FAIL: engine watchdog fired");
      errors = errors + 1;
    end
    if (fs_type_w !== 2'd2) begin
      $display("FAIL: latched fs_type %0d (want FAT16)", fs_type_w);
      errors = errors + 1;
    end

    if (errors == 0) $display("TB_RESULT: PASS");
    else $display("TB_RESULT: FAIL %0d errors", errors);
    $finish;
  end

  initial begin
    #150_000_000;  // 150 ms absolute watchdog
    $display("TB_RESULT: FAIL absolute watchdog");
    $finish;
  end

endmodule

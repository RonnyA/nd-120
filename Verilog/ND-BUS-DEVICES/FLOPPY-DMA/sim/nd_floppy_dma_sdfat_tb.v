/**************************************************************************
** TESTBENCH: the DMA floppy backend seam served by the REAL SD-FAT      **
** stack, in Verilator - the Tang floppy integration, functionally.      **
**                                                                       **
**   direct FDISK/FDBUF driver (stands in for ND_FLOPPY_DMA)             **
**        |                                                              **
**   nd_storage_devices #(.INCLUDE_FLOPPY(1))                          **
**        |  -> nd_storage -> floppy adapter (client 1 = FLOPPY1.IMG)    **
**        v                                                              **
**   sd_card_model (nds_storage.img) + nds_mem_model (SDRAM staging)     **
**                                                                       **
** The driver issues a sector READ on the FDISK seam exactly as          **
** ND_FLOPPY_DMA does (disk_req + lsect/format/drive/wordcount) and       **
** captures the words the backend writes into the device sector buffer   **
** (FDBUF_ADDR/WDATA/WE). Those words come from FLOPPY1.IMG on the        **
** simulated SD card, mounted and served by the SAME RTL that runs on    **
** the Tang board, and are compared against the known FLOPPY1.IMG        **
** pattern (make_storage_image.sh:                                       **
**   byte k = (k%256 + 29*((k/256)%256) + 7) % 256, big-endian words).   **
**                                                                       **
** Verdict line: TB_RESULT: PASS / TB_RESULT: FAIL                       **
***************************************************************************/

`timescale 1ns / 1ps

module nd_floppy_dma_sdfat_tb;

  reg sysclk = 0;
  reg sys_rst_n = 0;
  always #10 sysclk = ~sysclk;
  wire clk_stor = sysclk;

  // ---- FDISK/FDBUF backend seam (driver = the "device") ----
  reg         disk_req = 0, disk_wr = 0;
  reg  [15:0] disk_lsect = 0;
  reg  [1:0]  disk_format = 0, disk_drive = 0;
  reg  [10:0] disk_wordcount = 0;
  wire        disk_done, disk_err;
  wire [ 3:0] disk_err_code;   // WHY (SD-FAT/circuit/nd_storage_status.vh)
  wire [3:0]  disk_media_fmt;
  wire [9:0]  dbuf_addr;
  wire [15:0] dbuf_wdata;
  wire        dbuf_we;
  reg  [15:0] dbuf_rdata = 0;   // device buffer readout (writes only; unused here)

  // capture the sector the backend fills into the device buffer
  reg [15:0] cap[0:1023];

  // ---- the REAL SD-FAT stack wrapper (INCLUDE_FLOPPY=1) ----
  wire s_sd_clk_o, s_sd_cmd_o, s_sd_cmd_oe, s_sd_dat0_o, s_sd_dat0_oe;
  wire cm_cmd_o, cm_cmd_oe, cm_dat0_o, cm_dat0_oe;
  wire s_sd_cmd  = s_sd_cmd_oe  ? s_sd_cmd_o  : (cm_cmd_oe  ? cm_cmd_o  : 1'b1);
  wire s_sd_dat0 = s_sd_dat0_oe ? s_sd_dat0_o : (cm_dat0_oe ? cm_dat0_o : 1'b1);

  wire        stor_mem_start, stor_mem_we, stor_mem_busy, stor_mem_done;
  wire [19:0] stor_mem_addr;
  wire [31:0] stor_mem_wdata, stor_mem_rdata;
  wire [1:0]  sd_status;

  nd_storage_devices #(
      .SIMULATE(1),
      .INCLUDE_TAPE(0),      // floppy-only build: no tape (the Tang floppy config)
      .INCLUDE_FLOPPY(1)
  ) u_src (
      .clk_stor  (clk_stor),
      .rst_stor_n(sys_rst_n),
      .clk_cpu   (sysclk),
      .rst_cpu_n (sys_rst_n),

      .byte_req     (1'b0),
      .byte_valid   (),
      .byte_data    (),
      .source_rewind(1'b0),

      .FDISK_REQ      (disk_req),
      .FDISK_WR       (disk_wr),
      .FDISK_LSECT    (disk_lsect),
      .FDISK_FORMAT   (disk_format),
      .FDISK_DRIVE    (disk_drive),
      .FDISK_WORDCOUNT(disk_wordcount),
      .FDISK_DONE     (disk_done),
      .FDISK_ERR      (disk_err),
      .FDISK_ERR_CODE (disk_err_code),
      .FDISK_MEDIA_FMT(disk_media_fmt),
      .FDBUF_ADDR     (dbuf_addr),
      .FDBUF_WDATA    (dbuf_wdata),
      .FDBUF_WE       (dbuf_we),
      .FDBUF_RDATA    (dbuf_rdata),

      .sd_clk_o  (s_sd_clk_o),
      .sd_cmd_i  (s_sd_cmd),
      .sd_cmd_o  (s_sd_cmd_o),
      .sd_cmd_oe (s_sd_cmd_oe),
      .sd_dat0_i (s_sd_dat0),
      .sd_dat0_o (s_sd_dat0_o),
      .sd_dat0_oe(s_sd_dat0_oe),

      .mem_start(stor_mem_start),
      .mem_we   (stor_mem_we),
      .mem_addr (stor_mem_addr),
      .mem_wdata(stor_mem_wdata),
      .mem_rdata(stor_mem_rdata),
      .mem_busy (stor_mem_busy),
      .mem_done (stor_mem_done),

      .sd_status(sd_status)
  );

  // capture the backend's buffer fill
  always @(posedge sysclk) if (dbuf_we) cap[dbuf_addr] <= dbuf_wdata;

  localparam IMG_BYTES = 4 * 1024 * 1024;
  sd_card_model #(
      .IMAGE           ("nds_storage.img"),
      .MAX_BYTES       (IMG_BYTES),
      .LEGAL_MIN_SECTOR(0)
  ) card (
      .sd_clk   (s_sd_clk_o),
      .sd_cmd_i (s_sd_cmd),  .sd_cmd_o (cm_cmd_o),  .sd_cmd_oe (cm_cmd_oe),
      .sd_dat0_i(s_sd_dat0), .sd_dat0_o(cm_dat0_o), .sd_dat0_oe(cm_dat0_oe),
      .sd_dat1_i(1'b1), .sd_dat1_o(), .sd_dat1_oe(),
      .sd_dat2_i(1'b1), .sd_dat2_o(), .sd_dat2_oe(),
      .sd_dat3_i(1'b1), .sd_dat3_o(), .sd_dat3_oe()
  );

  nds_mem_model #(
      .MEM_WORDS(1048576)
  ) u_mem (
      .clk  (clk_stor),
      .rst_n(sys_rst_n),
      .start(stor_mem_start),
      .we   (stor_mem_we),
      .addr (stor_mem_addr),
      .wdata(stor_mem_wdata),
      .rdata(stor_mem_rdata),
      .busy (stor_mem_busy),
      .done (stor_mem_done)
  );

  integer errors = 0;
  task check(input cond, input [255:0] what);
    begin
      if (!cond) begin
        errors = errors + 1;
        $display("FAIL: %0s (time %0t)", what, $time);
      end
    end
  endtask

  // expected FLOPPY1.IMG content (make_storage_image.sh pattern), big-endian
  function [7:0] flp1_byte(input integer k);
    flp1_byte = (k % 256 + 29 * ((k / 256) % 256) + 7) % 256;
  endfunction
  function [15:0] flp1_word(input integer w);
    flp1_word = {flp1_byte(2 * w), flp1_byte(2 * w + 1)};
  endfunction

  integer i, guard;

  // issue one sector READ on the FDISK seam and wait for completion
  task fread(input [15:0] lsect, input [1:0] fmt, input [10:0] wc);
    begin
      @(posedge sysclk);
      disk_lsect     <= lsect;
      disk_format    <= fmt;
      disk_drive     <= 2'd0;
      disk_wordcount <= wc;
      disk_wr        <= 1'b0;
      disk_req       <= 1'b1;
      @(posedge sysclk);
      disk_req <= 1'b0;
      guard = 0;
      while (!disk_done && guard < 1000000) begin @(posedge sysclk); guard = guard + 1; end
      check(disk_done, "FDISK read never completed (disk_done)");
      check(!disk_err, "FDISK read reported disk_err");
    end
  endtask

  initial begin
    for (i = 0; i < 1024; i = i + 1) cap[i] = 16'hDEAD;

    repeat (5) @(negedge sysclk);
    sys_rst_n = 1;

    // wait for the SD-FAT mount + FLOPPY1.IMG open through the wrapper
    guard = 0;
    while (u_src.open_ok_w[1] !== 1'b1 && guard < 4000000) begin
      @(posedge sysclk); guard = guard + 1;
    end
    check(u_src.open_ok_w[1] === 1'b1, "FLOPPY1.IMG never opened");
    repeat (4) @(posedge sysclk);  // let size_bytes latch before reading it
    $display("[tb] FLOPPY1.IMG open after %0d cycles: size=%0d media_fmt=%01x",
             guard, u_src.size_bytes_w[63:32], disk_media_fmt);
    check(u_src.size_bytes_w[63:32] === 32'd4096, "FLOPPY1.IMG size not 4096");

    // READ sector 0 (256 words, format 0) and compare to FLOPPY1.IMG
    for (i = 0; i < 1024; i = i + 1) cap[i] = 16'hDEAD;
    fread(16'd0, 2'd0, 11'd256);
    for (i = 0; i < 256; i = i + 1)
      if (cap[i] !== flp1_word(i)) begin
        check(1'b0, "FLOPPY1.IMG sector-0 word mismatch");
        if (errors < 6) $display("   [w%0d] got %04x exp %04x", i, cap[i], flp1_word(i));
      end

    // READ sector 1 (words 256..511) to prove sector addressing
    for (i = 0; i < 1024; i = i + 1) cap[i] = 16'hDEAD;
    fread(16'd1, 2'd0, 11'd256);
    for (i = 0; i < 256; i = i + 1)
      if (cap[i] !== flp1_word(256 + i))
        check(1'b0, "FLOPPY1.IMG sector-1 word mismatch");

    if (errors == 0)
      $display("TB_RESULT: PASS (FLOPPY1.IMG served through nd_storage floppy adapter from the SD card, in Verilator)");
    else begin
      $display("%0d errors", errors);
      $display("TB_RESULT: FAIL");
    end
    $finish;
  end

  initial begin
    #2000000000;
    $display("TIMEOUT");
    $display("TB_RESULT: FAIL");
    $finish;
  end

endmodule

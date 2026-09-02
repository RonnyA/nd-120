/*****************************************************************************
**  nd_storage_mister_devices_tb.v                                          **
**                                                                          **
**  Full path: Verilog/fpga/mister/sim/nd_storage_mister_devices_tb.v       **
**                                                                          **
**  The whole MiSTer storage subsystem - two floppy adapters, two           **
**  Winchester adapters, the tape adapter, nd_storage_hps - driven at the   **
**  controller seams (FDISK_*, FDBUF_*, WDISK_*, WDBUF_*, the tape byte port)  **
**  exactly as ND120_CORE drives them, against hps_io_model.v with five     **
**  images mounted. This is the FIRST configuration anywhere with a second  **
**  floppy drive and a second Winchester unit, so the point of the bench    **
**  is slot separation: drive 1's data must come from slot 1 and unit 1's   **
**  from slot 3, and the OR of the two adapters' outputs must be clean.     **
**                                                                          **
**  Checks:                                                                 **
**   (1) floppy drive 1 with no image -> FDISK_ERR + NOTOPEN, no data       **
**   (2) FDISK_MEDIA_FMT follows FDISK_DRIVE (8-inch image on drive 0,      **
**       1.2 MB image on drive 1)                                           **
**   (3) floppy read, drive 0 then drive 1: wordcount words, in order,      **
**       equal to the right file's bytes as big-endian words                **
**   (4) floppy write on drive 1 (read-modify-write inside a block): the    **
**       file holds the sector, the rest of the block is untouched          **
**   (5) Winchester read unit 0 and unit 1: CHS -> LBA -> file offset,      **
**       each from its own slot                                             **
**   (6) Winchester write unit 1, one sector (half a block, the RMW path    **
**       SINTRAN uses): file updated; read back through unit 1             **
**   (7) tape: bytes in file order, rewind restarts, EOF is silence, and    **
**       the sticky TDISK_FAULT stays clear for a real end of tape          **
**   (8) tape before any image is mounted: silence + TDISK_FAULT NOTOPEN,   **
**       cleared by rewind once an image is there                           **
**   Plus the HPS model's handshake-rule counter must end at zero.          **
**                                                                          **
**  Verdict: TB_RESULT: PASS / TB_RESULT: FAIL                              **
*****************************************************************************/

`timescale 1ns / 1ps
`include "nd_storage_status.vh"

module nd_storage_mister_devices_tb;

  localparam integer N = 5;
  localparam integer IMG = 1572864;   // 1.5 MB per slot: room for a 1.2 MB floppy

  integer errors = 0;

  reg clk_cpu = 0;
  reg clk_sys = 0;
  always #25.0 clk_cpu = ~clk_cpu;   // 20 MHz
  always #12.5 clk_sys = ~clk_sys;   // 40 MHz
  reg rst_n = 0;

  // ---- tape seam ----
  reg        byte_req = 0, source_rewind = 0;
  wire       byte_valid;
  wire [7:0] byte_data;
  wire       tfault;
  wire [3:0] tcode;

  // ---- floppy seam ----
  reg         FDISK_REQ = 0, FDISK_WR = 0;
  reg  [15:0] FDISK_LSECT = 0;
  reg  [ 1:0] FDISK_FORMAT = 0, FDISK_DRIVE = 0;
  reg  [10:0] FDISK_WORDCOUNT = 0;
  wire        FDISK_DONE, FDISK_ERR, FDBUF_WE;
  wire [ 3:0] FDISK_ERR_CODE, FDISK_MEDIA_FMT;
  wire [ 9:0] FDBUF_ADDR;
  wire [15:0] FDBUF_WDATA;
  // the controller's sector buffer: COMBINATIONAL read (ND_FLOPPY_DMA)
  reg  [15:0] fdev[0:1023];
  wire [15:0] FDBUF_RDATA = fdev[FDBUF_ADDR];

  // ---- Winchester seam ----
  reg         WDISK_START = 0, WDISK_REQ = 0, WDISK_WR = 0;
  reg  [15:0] WDISK_BLKADDR1 = 0, WDISK_BLKADDR2 = 0;
  reg  [ 2:0] WDISK_UNIT = 0;
  reg  [10:0] WDISK_WORDCOUNT = 0;
  wire        WDISK_DONE, WDISK_ERR, WDBUF_WE;
  wire [ 3:0] WDISK_ERR_CODE;
  wire [ 9:0] WDBUF_ADDR;
  wire [15:0] WDBUF_WDATA;
  // the controller's buffer: REGISTERED read (ND_WINCHESTER)
  reg  [15:0] wdev[0:1023];
  reg  [15:0] WDBUF_RDATA = 0;

  // ---- hps side ----
  wire [N-1:0]    img_mounted;
  wire            img_readonly;
  wire [63:0]     img_size;
  wire [N*32-1:0] sd_lba;
  wire [N*6-1:0]  sd_blk_cnt;
  wire [N-1:0]    sd_rd, sd_wr, sd_ack;
  wire [12:0]     sd_buff_addr;
  wire [15:0]     sd_buff_dout, sd_buff_din;
  wire            sd_buff_wr;
  wire [N-1:0]    MOUNTED;
  integer         n_reads, n_writes, violations;

  nd_storage_mister_devices dut (
      .clk_cpu(clk_cpu), .rst_cpu_n(rst_n), .clk_sys(clk_sys), .rst_sys_n(rst_n),
      .byte_req(byte_req), .byte_valid(byte_valid), .byte_data(byte_data),
      .source_rewind(source_rewind), .TDISK_FAULT(tfault), .TDISK_ERR_CODE(tcode),
      .FDISK_REQ(FDISK_REQ), .FDISK_WR(FDISK_WR), .FDISK_LSECT(FDISK_LSECT),
      .FDISK_FORMAT(FDISK_FORMAT), .FDISK_DRIVE(FDISK_DRIVE), .FDISK_WORDCOUNT(FDISK_WORDCOUNT),
      .FDISK_DONE(FDISK_DONE), .FDISK_ERR(FDISK_ERR), .FDISK_ERR_CODE(FDISK_ERR_CODE),
      .FDISK_MEDIA_FMT(FDISK_MEDIA_FMT),
      .FDBUF_ADDR(FDBUF_ADDR), .FDBUF_WDATA(FDBUF_WDATA), .FDBUF_WE(FDBUF_WE), .FDBUF_RDATA(FDBUF_RDATA),
      .WDISK_START(WDISK_START), .WDISK_REQ(WDISK_REQ), .WDISK_WR(WDISK_WR),
      .WDISK_BLKADDR1(WDISK_BLKADDR1), .WDISK_BLKADDR2(WDISK_BLKADDR2), .WDISK_UNIT(WDISK_UNIT),
      .WDISK_WORDCOUNT(WDISK_WORDCOUNT),
      .WDISK_DONE(WDISK_DONE), .WDISK_ERR(WDISK_ERR), .WDISK_ERR_CODE(WDISK_ERR_CODE),
      .WDBUF_ADDR(WDBUF_ADDR), .WDBUF_WDATA(WDBUF_WDATA), .WDBUF_WE(WDBUF_WE), .WDBUF_RDATA(WDBUF_RDATA),
      .img_mounted(img_mounted), .img_readonly(img_readonly), .img_size(img_size),
      .sd_lba(sd_lba), .sd_blk_cnt(sd_blk_cnt), .sd_rd(sd_rd), .sd_wr(sd_wr), .sd_ack(sd_ack),
      .sd_buff_addr(sd_buff_addr), .sd_buff_dout(sd_buff_dout), .sd_buff_din(sd_buff_din),
      .sd_buff_wr(sd_buff_wr),
      .MOUNTED(MOUNTED)
  );

  hps_io_model #(.VDNUM(N), .IMG_BYTES(IMG)) hps (
      .clk_sys(clk_sys),
      .img_mounted(img_mounted), .img_readonly(img_readonly), .img_size(img_size),
      .sd_lba(sd_lba), .sd_blk_cnt(sd_blk_cnt), .sd_rd(sd_rd), .sd_wr(sd_wr), .sd_ack(sd_ack),
      .sd_buff_addr(sd_buff_addr), .sd_buff_dout(sd_buff_dout), .sd_buff_din(sd_buff_din),
      .sd_buff_wr(sd_buff_wr),
      .n_reads(n_reads), .n_writes(n_writes), .violations(violations)
  );

  // ---- device buffers + capture bookkeeping ----------------------------------
  integer f_we_count, f_order_ok, f_expect;
  integer w_we_count, w_order_ok, w_expect;
  reg [15:0] fcap[0:1023];
  reg [15:0] wcap[0:1023];
  // Both controller buffers ACCEPT backend writes, as the real cards do: the
  // Winchester adapter's read-modify-write stages the untouched half of the
  // block in the controller's buffer above the guest's words and then pulls
  // the whole block back out of it - a bench that only captured those writes
  // handed zeros back and "corrupted" the other sector (found 01-SEP-2026).
  always @(posedge clk_cpu) begin
    WDBUF_RDATA <= wdev[WDBUF_ADDR];
    if (WDBUF_WE) wdev[WDBUF_ADDR] <= WDBUF_WDATA;
    if (FDBUF_WE) fdev[FDBUF_ADDR] <= FDBUF_WDATA;
    if (FDBUF_WE) begin
      fcap[FDBUF_ADDR] <= FDBUF_WDATA;
      if (FDBUF_ADDR != f_expect) f_order_ok = 0;
      f_expect   = f_expect + 1;
      f_we_count = f_we_count + 1;
    end
    if (WDBUF_WE) begin
      wcap[WDBUF_ADDR] <= WDBUF_WDATA;
      if (WDBUF_ADDR != w_expect) w_order_ok = 0;
      w_expect   = w_expect + 1;
      w_we_count = w_we_count + 1;
    end
  end

  task check(input cond, input [1023:0] what);
    begin
      if (!cond) begin errors = errors + 1; $display("  FAIL: %0s", what); end
    end
  endtask

  task fill_image(input integer s, input [7:0] seed, input integer nbytes);
    integer b;
    begin
      for (b = 0; b < nbytes; b = b + 1) hps.img[s*IMG + b] = seed ^ b[7:0] ^ b[15:8] ^ b[23:16];
    end
  endtask

  // ND word at byte offset off of slot s
  function [15:0] fword(input integer s, input integer off);
    fword = {hps.img[s*IMG + off], hps.img[s*IMG + off + 1]};
  endfunction

  // ---- floppy op: one sector ----
  reg        r_err;
  reg [3:0]  r_code;
  integer    r_cycles;
  task fop(input [1:0] drive, input is_wr, input [1:0] fmt, input [15:0] lsect, input [10:0] wc);
    begin
      f_we_count = 0; f_order_ok = 1; f_expect = 0;
      @(posedge clk_cpu);
      FDISK_DRIVE <= drive; FDISK_WR <= is_wr; FDISK_FORMAT <= fmt;
      FDISK_LSECT <= lsect; FDISK_WORDCOUNT <= wc; FDISK_REQ <= 1'b1;
      @(posedge clk_cpu);
      FDISK_REQ <= 1'b0;
      r_cycles = 0;
      while (!FDISK_DONE && (r_cycles < 400000)) begin @(posedge clk_cpu); r_cycles = r_cycles + 1; end
      r_err = FDISK_ERR; r_code = FDISK_ERR_CODE;
      check(FDISK_DONE, "floppy op never completed");
      @(posedge clk_cpu);
    end
  endtask

  // ---- Winchester op: start + one chunk ----
  task wop(input [2:0] unit, input is_wr, input [15:0] cyl, input [7:0] head, input [7:0] sect,
           input [10:0] wc);
    begin
      w_we_count = 0; w_order_ok = 1; w_expect = 0;
      @(posedge clk_cpu);
      WDISK_UNIT <= unit; WDISK_WR <= is_wr; WDISK_BLKADDR2 <= cyl;
      WDISK_BLKADDR1 <= {head, sect}; WDISK_WORDCOUNT <= wc;
      WDISK_START <= 1'b1; WDISK_REQ <= 1'b1;
      @(posedge clk_cpu);
      WDISK_START <= 1'b0; WDISK_REQ <= 1'b0;
      r_cycles = 0;
      while (!WDISK_DONE && (r_cycles < 400000)) begin @(posedge clk_cpu); r_cycles = r_cycles + 1; end
      r_err = WDISK_ERR; r_code = WDISK_ERR_CODE;
      check(WDISK_DONE, "Winchester op never completed");
      @(posedge clk_cpu);
    end
  endtask

  // CHS -> byte offset, Winchester geometry 8 heads x 9 sectors x 1024 B
  function integer w_off(input integer cyl, input integer head, input integer sect);
    w_off = ((cyl * 8 + head) * 9 + sect) * 1024;
  endfunction

  // ---- tape: one byte, or silence ----
  reg        t_got;
  reg [7:0]  t_byte;
  task tbyte;
    begin
      t_got = 0;
      @(posedge clk_cpu); byte_req <= 1'b1; @(posedge clk_cpu); byte_req <= 1'b0;
      r_cycles = 0;
      while (!byte_valid && (r_cycles < 20000)) begin @(posedge clk_cpu); r_cycles = r_cycles + 1; end
      if (byte_valid) begin t_got = 1; t_byte = byte_data; end
      @(posedge clk_cpu);
    end
  endtask

  integer w, bad, i;

  initial begin
    f_we_count = 0; f_order_ok = 1; f_expect = 0;
    w_we_count = 0; w_order_ok = 1; w_expect = 0;
    for (w = 0; w < 1024; w = w + 1) begin fdev[w] = 0; wdev[w] = 0; fcap[w] = 0; wcap[w] = 0; end
    repeat (5) @(posedge clk_cpu);
    rst_n = 1;
    repeat (20) @(posedge clk_cpu);

    // ---------------- (8) tape before any mount ----------------------------
    $display("(8) tape with no image");
    tbyte;
    check(!t_got, "tape with no image must be silent");
    check(tfault && (tcode == `NDS_ERR_NOTOPEN), "TDISK_FAULT must say NOTOPEN");

    // ---------------- (1) floppy drive 1 with no image ---------------------
    $display("(1) floppy drive 1 with no image");
    fop(2'd1, 1'b0, 2'd3, 16'd0, 11'd512);
    check(r_err && (r_code == `NDS_ERR_NOTOPEN), "floppy on an empty slot must be NOTOPEN");
    check(f_we_count == 0, "no data on an empty slot");

    // ---------------- mounts -------------------------------------------------
    fill_image(0, 8'h10, 315392);       // 8-inch, 512 B/sector
    fill_image(1, 8'h20, 1261568);      // 1.2 MB, 1024 B/sector
    fill_image(2, 8'h30, 262144);       // WD0: 256 KB is enough for the CHS used
    fill_image(3, 8'h40, 262144);       // WD1
    fill_image(4, 8'h50, 3000);         // tape: 3000 bytes (past one block)
    hps.mount(0, 32'd315392, 1'b0);
    hps.mount(1, 32'd1261568, 1'b0);
    hps.mount(2, 32'd262144, 1'b0);
    hps.mount(3, 32'd262144, 1'b0);
    hps.mount(4, 32'd3000, 1'b0);
    repeat (10) @(posedge clk_cpu);
    check(MOUNTED == 5'b11111, "all five slots mounted");

    // ---------------- (2) media format follows the drive ---------------------
    $display("(2) media format per drive");
    @(posedge clk_cpu); FDISK_DRIVE <= 2'd0; @(posedge clk_cpu); #1;
    check(FDISK_MEDIA_FMT == 4'h0, "drive 0 (315392 B) must report format 0");
    @(posedge clk_cpu); FDISK_DRIVE <= 2'd1; @(posedge clk_cpu); #1;
    check(FDISK_MEDIA_FMT == 4'hF, "drive 1 (1.2 MB) must report format F");

    // ---------------- (3) floppy reads, both drives -------------------------
    $display("(3) floppy read drive 0 sector 5 (fmt 0, 256 w), drive 1 sector 2 (fmt 3, 512 w)");
    fop(2'd0, 1'b0, 2'd0, 16'd5, 11'd256);
    check(!r_err, "drive 0 read errs");
    check((f_we_count == 256) && f_order_ok, "drive 0: 256 words in order");
    bad = 0;
    for (w = 0; w < 256; w = w + 1) if (fcap[w] != fword(0, 5*512 + 2*w)) bad = bad + 1;
    check(bad == 0, "drive 0 data = slot 0 file, sector 5");
    fop(2'd1, 1'b0, 2'd3, 16'd2, 11'd512);
    check(!r_err, "drive 1 read errs");
    check((f_we_count == 512) && f_order_ok, "drive 1: 512 words in order");
    bad = 0;
    for (w = 0; w < 512; w = w + 1) if (fcap[w] != fword(1, 2*1024 + 2*w)) bad = bad + 1;
    check(bad == 0, "drive 1 data = slot 1 file, sector 2 (not slot 0)");

    // ---------------- (4) floppy write on drive 1 --------------------------
    $display("(4) floppy write drive 1 sector 3 (RMW inside block 1)");
    for (w = 0; w < 512; w = w + 1) fdev[w] = 16'hD000 + w;
    fop(2'd1, 1'b1, 2'd3, 16'd3, 11'd512);
    check(!r_err, "drive 1 write errs");
    bad = 0;
    for (w = 0; w < 512; w = w + 1) if (fword(1, 3*1024 + 2*w) != (16'hD000 + w)) bad = bad + 1;
    check(bad == 0, "slot 1 file holds the written sector");
    bad = 0;   // the other sector of the same block must be untouched
    for (w = 0; w < 512; w = w + 1) if (fword(1, 2*1024 + 2*w) != fcap[w]) bad = bad + 1;
    check(bad == 0, "the neighbouring sector survived the read-modify-write");
    // slot 0 must be untouched
    check(fword(0, 3*1024) != 16'hD000, "slot 0 must not see drive 1's write");

    // ---------------- (5) Winchester reads, both units ----------------------
    $display("(5) Winchester read unit 0 (cyl 2 head 3 sect 4) and unit 1 (cyl 1 head 0 sect 0)");
    wop(3'd0, 1'b0, 16'd2, 8'd3, 8'd4, 11'd512);
    check(!r_err, "unit 0 read errs");
    check((w_we_count == 512) && w_order_ok, "unit 0: 512 words in order");
    bad = 0;
    for (w = 0; w < 512; w = w + 1) if (wcap[w] != fword(2, w_off(2, 3, 4) + 2*w)) bad = bad + 1;
    check(bad == 0, "unit 0 data = slot 2 file at CHS (2,3,4)");
    wop(3'd1, 1'b0, 16'd1, 8'd0, 8'd0, 11'd512);
    check(!r_err, "unit 1 read errs");
    check((w_we_count == 512) && w_order_ok, "unit 1: 512 words in order");
    bad = 0;
    for (w = 0; w < 512; w = w + 1) if (wcap[w] != fword(3, w_off(1, 0, 0) + 2*w)) bad = bad + 1;
    check(bad == 0, "unit 1 data = slot 3 file at CHS (1,0,0) (not slot 2)");

    // ---------------- (6) Winchester write unit 1, one sector -----------------
    $display("(6) Winchester write unit 1, one sector at CHS (1,0,1) - half a block");
    for (w = 0; w < 512; w = w + 1) wdev[w] = 16'hB000 + w;
    wop(3'd1, 1'b1, 16'd1, 8'd0, 8'd1, 11'd512);
    check(!r_err, "unit 1 write errs");
    bad = 0;
    for (w = 0; w < 512; w = w + 1) if (fword(3, w_off(1, 0, 1) + 2*w) != (16'hB000 + w)) bad = bad + 1;
    check(bad == 0, "slot 3 file holds the written sector");
    bad = 0;
    for (w = 0; w < 512; w = w + 1) if (fword(3, w_off(1, 0, 0) + 2*w) != wcap[w]) bad = bad + 1;
    check(bad == 0, "the other half of the block survived");
    check(fword(2, w_off(1, 0, 1)) != 16'hB000, "slot 2 must not see unit 1's write");
    for (w = 0; w < 1024; w = w + 1) wdev[w] = 0;
    wop(3'd1, 1'b0, 16'd1, 8'd0, 8'd1, 11'd512);
    bad = 0;
    for (w = 0; w < 512; w = w + 1) if (wcap[w] != (16'hB000 + w)) bad = bad + 1;
    check(bad == 0, "unit 1 write then read round-trips");

    // ---------------- (7) tape ---------------------------------------------
    $display("(7) tape stream, rewind, EOF");
    @(posedge clk_cpu); source_rewind <= 1'b1; @(posedge clk_cpu); source_rewind <= 1'b0;
    repeat (4) @(posedge clk_cpu);
    check(!tfault, "rewind clears the sticky fault");
    bad = 0;
    for (i = 0; i < 2100; i = i + 1) begin      // crosses the 2048-byte block edge
      tbyte;
      if (!t_got || (t_byte != hps.img[4*IMG + i])) bad = bad + 1;
    end
    check(bad == 0, "tape bytes in file order across a block boundary");
    @(posedge clk_cpu); source_rewind <= 1'b1; @(posedge clk_cpu); source_rewind <= 1'b0;
    tbyte;
    check(t_got && (t_byte == hps.img[4*IMG + 0]), "rewind restarts at byte 0");
    @(posedge clk_cpu); source_rewind <= 1'b1; @(posedge clk_cpu); source_rewind <= 1'b0;
    for (i = 0; i < 3000; i = i + 1) tbyte;
    tbyte;
    check(!t_got, "past EOF the tape is silent");
    check(!tfault, "end of tape is not a fault");

    check(violations == 0, "HPS handshake rules violated (see HPS MODEL lines)");

    if (errors == 0) $display("TB_RESULT: PASS");
    else             $display("TB_RESULT: FAIL (%0d)", errors);
    $finish;
  end

  initial begin
    #2_000_000_000;
    $display("TB_RESULT: FAIL (watchdog)");
    $finish;
  end

endmodule

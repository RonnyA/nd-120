/**************************************************************************
** TESTBENCH: ND_FLOPPY_PIO through ND_BUS_SLAVE                         **
**                                                                       **
** Same scripted CPU-side bus master as the BUS-IF tb; the disk backend  **
** is an image array in the tb (format 3: 512 bytes x 8 sectors x 77     **
** tracks, word w of the image = its linear word address).               **
**                                                                       **
** Covered: drive select + format decode, sector read into the buffer    **
** and word-by-word readout, buffer write + sector write to the image,   **
** seek/recalibrate completion, sector auto-increment, error cases       **
** (no drive selected, sector out of range), status registers, level-11  **
** interrupt on completion, IDENT code 021 + clear-on-IDENT.             **
**                                                                       **
** Verdict line: TB_RESULT: PASS / TB_RESULT: FAIL                       **
**                                                                       **
** Last reviewed: 11-JUL-2026                                            **
** Ronny Hansen                                                          **
***************************************************************************/

`timescale 1ns / 1ps

module nd_floppy_pio_tb;

  reg sysclk = 0;
  reg sys_rst_n = 0;
  always #10 sysclk = ~sysclk;

  // CPU-side bus
  reg  [23:0] bd_out = 24'hFFFFFF;
  wire [23:0] bd_in;
  reg  bapr_n = 1, bioxe_n = 1, binack_n = 1, outident_n = 1;
  wire binput_n, bdap_n, bdry_n;
  wire bint10_n, bint11_n, bint12_n, bint13_n;

  wire [15:0] iox_addr, iox_wdata, iox_rdata;
  wire iox_wr, iox_rd;
  wire ident_strobe;
  wire [3:0] ident_level;
  wire [3:0] intp;
  wire ident_hit;
  wire [15:0] ident_code;

  ND_BUS_SLAVE u_slave (
      .sysclk(sysclk), .sys_rst_n(sys_rst_n),
      .BD_23_0_n_OUT(bd_out), .BD_23_0_n_IN(bd_in),
      .BAPR_n(bapr_n), .BIOXE_n(bioxe_n), .BINACK_n(binack_n),
      .OUTIDENT_n(outident_n),
      .BINPUT_n(binput_n), .BDAP_n(bdap_n), .BDRY_n(bdry_n),
      .BINT10_n(bint10_n), .BINT11_n(bint11_n),
      .BINT12_n(bint12_n), .BINT13_n(bint13_n),
      .iox_addr(iox_addr), .iox_wr(iox_wr), .iox_wdata(iox_wdata),
      .iox_rd(iox_rd), .iox_rdata(iox_rdata),
      .int_pending(intp),
      .ident_strobe(ident_strobe), .ident_level(ident_level),
      .ident_hit(ident_hit), .ident_code(ident_code)
  );

  // Disk backend wires
  wire        disk_req;
  wire [2:0]  disk_op;
  wire [6:0]  disk_sector, disk_track;
  wire [1:0]  disk_format;
  wire [2:0]  disk_drive;
  wire [9:0]  disk_buf_start;
  wire [10:0] disk_wordcount;
  reg         disk_done = 0;
  reg         disk_err_notrdy = 0, disk_err_missing = 0;
  reg  [9:0]  dbuf_addr = 0;
  reg  [15:0] dbuf_wdata = 0;
  reg         dbuf_we = 0;
  wire [15:0] dbuf_rdata;

  ND_FLOPPY_PIO #(
      .DELAY_TICKS(16'd20)  // short completion delay for the tb
  ) u_floppy (
      .sysclk(sysclk), .sys_rst_n(sys_rst_n),
      .iox_addr(iox_addr), .iox_wr(iox_wr), .iox_wdata(iox_wdata),
      .iox_rd(iox_rd), .iox_rdata(iox_rdata),
      .int_pending(intp),
      .ident_strobe(ident_strobe), .ident_level(ident_level),
      .ident_grant_in(1'b1), .ident_grant_out(),
      .ident_hit(ident_hit), .ident_code(ident_code),
      .disk_req(disk_req), .disk_op(disk_op),
      .disk_sector(disk_sector), .disk_track(disk_track),
      .disk_format(disk_format), .disk_drive(disk_drive),
      .disk_buf_start(disk_buf_start), .disk_wordcount(disk_wordcount),
      .disk_done(disk_done),
      .disk_err_notrdy(disk_err_notrdy), .disk_err_missing(disk_err_missing),
      .dbuf_addr(dbuf_addr), .dbuf_wdata(dbuf_wdata), .dbuf_we(dbuf_we),
      .dbuf_rdata(dbuf_rdata)
  );

  // Disk image: format 3 = 512 B/sector (256 words), 8 sectors, 77 tracks
  // word w = its linear word address (truncated to 16 bits)
  localparam WORDS_PER_SECTOR = 256;
  localparam SECTORS = 8;
  reg [15:0] image[0:(77 * SECTORS * WORDS_PER_SECTOR) - 1];
  integer ii;
  initial begin
    for (ii = 0; ii < 77 * SECTORS * WORDS_PER_SECTOR; ii = ii + 1)
      image[ii] = ii[15:0];
  end

  // Backend model: serve read/write/format sector transfers
  integer base, w;
  always @(posedge sysclk) begin
    disk_done        <= 1'b0;
    disk_err_notrdy  <= 1'b0;
    disk_err_missing <= 1'b0;
    dbuf_we          <= 1'b0;
    if (disk_req) begin
      base = ((disk_sector - 1) + disk_track * SECTORS) * WORDS_PER_SECTOR;
      if (disk_op == 3'd4) begin  // read data
        for (w = 0; w < disk_wordcount; w = w + 1) begin
          @(posedge sysclk);
          dbuf_addr  <= (disk_buf_start + w[9:0]);
          dbuf_wdata <= image[base + w];
          dbuf_we    <= 1'b1;
        end
        @(posedge sysclk);
        dbuf_we   <= 1'b0;
        disk_done <= 1'b1;
      end else if (disk_op == 3'd1 || disk_op == 3'd2) begin  // write
        for (w = 0; w < disk_wordcount; w = w + 1) begin
          dbuf_addr <= (disk_buf_start + w[9:0]);
          @(posedge sysclk);
          @(posedge sysclk);
          image[base + w] = dbuf_rdata;
        end
        disk_done <= 1'b1;
      end else begin  // format etc: fill the track with AAFF
        for (w = 0; w < SECTORS * WORDS_PER_SECTOR; w = w + 1)
          image[disk_track * SECTORS * WORDS_PER_SECTOR + w] = 16'hAAFF;
        disk_done <= 1'b1;
      end
    end
  end

  integer errors = 0;

  task check(input cond, input [255:0] what);
    begin
      if (!cond) begin
        errors = errors + 1;
        $display("FAIL: %0s (time %0t)", what, $time);
      end
    end
  endtask

  // ---- bus master tasks (same sequences as the BUS-IF tb) ----

  task bus_apr(input [15:0] addr);
    begin
      @(negedge sysclk);
      bd_out = ~{8'd0, addr};
      bapr_n = 0;
      @(negedge sysclk);
      @(negedge sysclk);
      bapr_n = 1;
      bd_out = 24'hFFFFFF;
      @(negedge sysclk);
    end
  endtask

  task iox_write(input [15:0] addr, input [15:0] data);
    integer guard;
    begin
      bus_apr(addr | 16'd1);
      bd_out  = ~{8'd0, data};
      bioxe_n = 0;
      guard = 0;
      while (bdry_n !== 1'b0 && guard < 50) begin
        @(negedge sysclk); guard = guard + 1;
      end
      check(bdry_n === 1'b0, "iox_write: BDRY_n never asserted");
      @(negedge sysclk);
      bioxe_n = 1;
      bd_out  = 24'hFFFFFF;
      @(negedge sysclk);
      @(negedge sysclk);
    end
  endtask

  task iox_read(input [15:0] addr, output [15:0] data);
    integer guard;
    begin
      bus_apr(addr & 16'hFFFE);
      bioxe_n = 0;
      guard = 0;
      while (binput_n !== 1'b0 && guard < 50) begin
        @(negedge sysclk); guard = guard + 1;
      end
      check(binput_n === 1'b0, "iox_read: BINPUT_n never asserted");
      binack_n = 0;
      guard = 0;
      while (bdry_n !== 1'b0 && guard < 50) begin
        @(negedge sysclk); guard = guard + 1;
      end
      check(bdry_n === 1'b0, "iox_read: BDRY_n never asserted");
      data = ~bd_in[15:0];
      binack_n = 1;
      bioxe_n  = 1;
      @(negedge sysclk);
      @(negedge sysclk);
    end
  endtask

  task ident(input [15:0] levelcode, output hit, output [15:0] code);
    integer guard;
    begin
      bus_apr(levelcode);
      outident_n = 0;
      guard = 0;
      while (binput_n !== 1'b0 && guard < 10) begin
        @(negedge sysclk); guard = guard + 1;
      end
      if (binput_n === 1'b0) begin
        hit = 1;
        binack_n = 0;
        guard = 0;
        while (bdry_n !== 1'b0 && guard < 50) begin
          @(negedge sysclk); guard = guard + 1;
        end
        code = ~bd_in[15:0];
        binack_n = 1;
      end else begin
        hit  = 0;
        code = 0;
      end
      outident_n = 1;
      @(negedge sysclk);
      @(negedge sysclk);
    end
  endtask

  integer test_tag = 0;

  task wait_ready;
    integer guard;
    reg [15:0] st;
    begin
      guard = 0;
      st = 0;
      while (!(st & 16'o000010) && guard < 200) begin
        iox_read(16'o001562, st);
        guard = guard + 1;
      end
      if (!(st & 16'o000010))
        $display("wait_ready: tag %0d last status %o", test_tag, st);
      check((st & 16'o000010) !== 0, "device never became ready");
    end
  endtask

  reg [15:0] rdata;
  reg        ihit;
  reg [15:0] icode;
  integer    i;
  integer    sect2_base;

  initial begin
`ifdef DUMPFILE
    $dumpfile("nd_floppy_pio_tb.vcd");
    $dumpvars(0, nd_floppy_pio_tb);
`endif
    repeat (5) @(negedge sysclk);
    sys_rst_n = 1;
    repeat (5) @(negedge sysclk);

    // 1: initial status: ready for transfer, no errors
    iox_read(16'o001562, rdata);
    check((rdata & 16'o000010) !== 0, "RFT not set after reset");
    check((rdata & 16'o000020) === 0, "error OR bit set after reset");

    // 2: read without a selected drive -> driveNotReady in RSR2.
    // Like the C model, RFT stays 0 on this error (only a device clear
    // restores it), so poll for busy to drop instead of ready.
    iox_write(16'o001563, 16'o010000);  // command: read data (bit 12)
    repeat (10) @(negedge sysclk);
    iox_read(16'o001564, rdata);
    check((rdata & 16'h0100) !== 0, "driveNotReady not set");
    iox_read(16'o001562, rdata);
    check((rdata & 16'o000020) !== 0, "RSR1 error OR bit not set");

    // recover with device clear (control bit 4), as the driver does
    iox_write(16'o001563, 16'o000020);

    // 3: select drive 0, format 3 (512 B x 8 sectors)
    iox_write(16'o001565, 16'hC001);  // modeBit=1, drive 0, format 3
    // sector 2, no auto-increment
    iox_write(16'o001567, {1'b0, 7'd2, 8'd0});
    // clear buffer pointer, then command: read data
    iox_write(16'o001563, 16'o000040);
    iox_write(16'o001563, 16'o010000);
    test_tag = 2;
    wait_ready();
    iox_read(16'o001562, rdata);
    check((rdata & 16'o000100) !== 0, "rwComplete not set after read");
    check((rdata & 16'o000020) === 0, "error after good read");

    // 4: buffer readout = image words of track 0 sector 2
    // (the transfer advanced the pointer - clear it first, as the driver does)
    iox_write(16'o001563, 16'o000040);
    sect2_base = 1 * WORDS_PER_SECTOR;  // (sector-1)=1, track 0
    for (i = 0; i < 4; i = i + 1) begin
      iox_read(16'o001560, rdata);
      check(rdata === (sect2_base[15:0] + i[15:0]), "sector data wrong");
    end

    // 5: sector out of range -> sectorMissing
    iox_write(16'o001567, {1'b0, 7'd12, 8'd0});  // sector 12 > 8
    iox_write(16'o001563, 16'o010000);
    test_tag = 3;
    wait_ready();
    iox_read(16'o001564, rdata);
    check((rdata & 16'h0800) !== 0, "sectorMissing not set");

    // 6: write a pattern to track 0 sector 1 and read it back
    iox_write(16'o001567, {1'b0, 7'd1, 8'd0});
    iox_write(16'o001563, 16'o000040);  // clear buffer pointer
    for (i = 0; i < WORDS_PER_SECTOR; i = i + 1)
      iox_write(16'o001561, 16'h5A00 + i[15:0]);
    iox_write(16'o001563, 16'o000040);
    iox_write(16'o001563, 16'o001000);  // command: write data (bit 9)
    test_tag = 4;
    wait_ready();
    check(image[0] === 16'h5A00, "image word 0 not written");
    check(image[3] === 16'h5A03, "image word 3 not written");
    // read it back through the device
    iox_write(16'o001563, 16'o000040);
    iox_write(16'o001563, 16'o010000);
    test_tag = 5;
    wait_ready();
    iox_write(16'o001563, 16'o000040);
    iox_read(16'o001560, rdata);
    check(rdata === 16'h5A00, "written sector readback wrong");

    // 7: seek (difference +2) then recalibrate; seekComplete both times
    iox_write(16'o001565, 16'h0200);  // modeBit=0, diff=2, direction in
    iox_write(16'o001563, 16'o020000);  // command: seek (bit 13)
    test_tag = 6;
    wait_ready();
    iox_read(16'o001562, rdata);
    check((rdata & 16'o000200) !== 0, "seekComplete not set after seek");
    iox_write(16'o001563, 16'o040000);  // command: recalibrate (bit 14)
    test_tag = 7;
    wait_ready();
    iox_read(16'o001562, rdata);
    check((rdata & 16'o000200) !== 0, "seekComplete not set after recal");

    // 8: auto-increment: read sector 1 with autoIncrement, sector -> 2
    iox_write(16'o001567, {1'b1, 7'd1, 8'd0});
    iox_write(16'o001563, 16'o000040);
    iox_write(16'o001563, 16'o010000);
    test_tag = 8;
    wait_ready();
    // reading again without touching WSCT must fetch sector 2
    iox_write(16'o001563, 16'o000040);
    iox_write(16'o001563, 16'o010000);
    test_tag = 9;
    wait_ready();
    iox_write(16'o001563, 16'o000040);
    iox_read(16'o001560, rdata);
    check(rdata === sect2_base[15:0], "auto-increment did not advance");

    // 9: interrupt + IDENT: enable interrupt, run a command
    check(bint11_n === 1'b1, "BINT11 asserted before enable");
    iox_write(16'o001563, 16'o010002);  // enableInterrupt + read data
    test_tag = 10;
    wait_ready();
    check(bint11_n === 1'b0, "BINT11_n not asserted on completion");
    ident(16'o000011, ihit, icode);     // IDENT PL11
    check(ihit === 1'b1, "IDENT PL11 no hit");
    check(icode === 16'o000021, "IDENT code not 021");
    check(bint11_n === 1'b1, "BINT11_n not released after IDENT");
    ident(16'o000011, ihit, icode);
    check(ihit === 1'b0, "second IDENT PL11 unexpectedly hit");

    if (errors == 0) $display("TB_RESULT: PASS");
    else begin
      $display("%0d errors", errors);
      $display("TB_RESULT: FAIL");
    end
    $finish;
  end

  initial begin
    #20000000;
    $display("TIMEOUT");
    $display("TB_RESULT: FAIL");
    $finish;
  end

endmodule

/*****************************************************************************
**  nd_winchester_compare_tb.v                                              **
**                                                                          **
**  Full path:                                                              **
**    Verilog/ND-BUS-DEVICES/WINCHESTER/sim/nd_winchester_compare_tb.v      **
**                                                                          **
**  M3 COMPARE (sec 3.4.7). Three things must hold, and the first of them   **
**  is what a SINTRAN boot actually depends on:                             **
**                                                                          **
**    1. The memory address register ADVANCES by the word count, exactly    **
**       as it does after a read. The guest reads +0 back after every       **
**       operation; a compare that leaves the register where the guest      **
**       loaded it is visible to the guest as a failed transfer.            **
**    2. A mismatch sets status b10 (compare error) and stops there,        **
**       leaving the address at the word that failed.                       **
**    3. No data is written to ND memory. "No data transfer to the          **
**       computer memory is performed" - the words go the other way.        **
**                                                                          **
**  WHY THIS BENCH EXISTS - 10-AUG-2026, from silicon.                      **
**                                                                          **
**  ND_WINCHESTER.v routed M3 to the same do-nothing stub as M2 and M5,     **
**  with a comment claiming that matched both C models. It does not:        **
**  nd100x's src/devices/winchester/deviceWinchester.c reads the sector,    **
**  DMA-reads the same words back out of ND memory, compares them, and      **
**  writes the advanced core address into the memory address register.      **
**                                                                          **
**  Booting WD0.IMG with '20500&', the Tang and nd100x request the SAME     **
**  124 disc addresses and then split at exactly the group where SINTRAN    **
**  reads block 0 twice and compares it. nd100x moves on and reaches its    **
**  login banner; the Tang re-issued block 0 eleven times and printed       **
**  SINTRAN's own 'TRANSFER ERROR'.                                         **
**                                                                          **
**  Ronny Hansen                                                            **
*****************************************************************************/

`timescale 1ns / 1ps

module nd_winchester_compare_tb;

  localparam [15:0] BASE = 16'o000500;

  localparam R_MEMADDR = 16'd0;   // read: LO then HI
  localparam R_LOADADR = 16'd1;   // write: HI then LO
  localparam R_BLOCK   = 16'd3;
  localparam R_STATUS  = 16'd4;
  localparam R_CONTROL = 16'd5;
  localparam R_WORDCNT = 16'd7;

  // M3 compare, unit 0, head 0, activate (b2) + interrupt enable (b0).
  // b13:11 = 011 = M3.
  localparam [15:0] CTRL_CMP  = 16'o014005;
  // M0 read with the same head/unit, for the no-write-to-memory check.
  localparam [15:0] CTRL_READ = 16'o000005;

  localparam [31:0] TB_DELAY_TICKS = 32'd20;

  // Short on purpose: the compare walks every word, and the point of the
  // bench is the register arithmetic, not throughput.
  localparam integer NWORDS = 8;

  localparam [15:0] LOAD_HI = 16'o000003;
  localparam [15:0] LOAD_LO = 16'o040000;

  reg sysclk = 0;
  reg sys_rst_n = 0;
  always #10 sysclk = ~sysclk;

  reg  [15:0] iox_addr  = 16'd0;
  reg         iox_wr    = 1'b0;
  reg  [15:0] iox_wdata = 16'd0;
  reg         iox_rd    = 1'b0;
  wire [15:0] iox_rdata;
  wire        iox_sel;
  wire [3:0]  int_pending;

  wire        dma_req, dma_wr;
  wire [23:0] dma_addr;
  wire [15:0] dma_wdata;
  reg  [15:0] dma_rdata = 16'd0;
  reg         dma_ack = 1'b0;

  wire        disk_start, disk_req, disk_wr;
  wire [15:0] disk_blkaddr1, disk_blkaddr2;
  wire [2:0]  disk_unit;
  wire [10:0] disk_wordcount;
  reg         disk_done = 1'b0;

  reg  [ 9:0] dbuf_addr  = 10'd0;
  reg  [15:0] dbuf_wdata = 16'd0;
  reg         dbuf_we    = 1'b0;

  ND_WINCHESTER #(.DELAY_TICKS(TB_DELAY_TICKS)) dut (
      .sysclk        (sysclk),
      .sys_rst_n     (sys_rst_n),
      .iox_addr      (iox_addr),
      .iox_wr        (iox_wr),
      .iox_wdata     (iox_wdata),
      .iox_rd        (iox_rd),
      .iox_rdata     (iox_rdata),
      .iox_sel       (iox_sel),
      .int_pending   (int_pending),
      .ident_strobe  (1'b0),
      .ident_level   (4'd0),
      .ident_grant_in(1'b0),
      .ident_grant_out(),
      .ident_hit     (),
      .ident_code    (),
      .dma_req       (dma_req),
      .dma_wr        (dma_wr),
      .dma_addr      (dma_addr),
      .dma_wdata     (dma_wdata),
      .dma_rdata     (dma_rdata),
      .dma_ack       (dma_ack),
      .dma_err       (1'b0),
      .dma_busy      (1'b0),
      .disk_start    (disk_start),
      .disk_req      (disk_req),
      .disk_wr       (disk_wr),
      .disk_blkaddr1 (disk_blkaddr1),
      .disk_blkaddr2 (disk_blkaddr2),
      .disk_unit     (disk_unit),
      .disk_wordcount(disk_wordcount),
      .disk_done     (disk_done),
      .disk_err_in   (1'b0),
      .disk_err_code (4'd0),
      .dbuf_addr     (dbuf_addr),
      .dbuf_wdata    (dbuf_wdata),
      .dbuf_we       (dbuf_we),
      .dbuf_rdata    ()
  );

  // ---- ND memory model -----------------------------------------------------
  // Only the window the bench uses. dma_writes counts every write the DUT
  // attempts, which is how check 3 (no data to memory) is measured.
  reg [15:0] ndmem[0:63];
  integer    dma_writes = 0;
  wire [23:0] base_addr = {LOAD_HI[7:0], LOAD_LO};

  always @(posedge sysclk) begin
    dma_ack <= 1'b0;
    if (dma_req && !dma_ack) begin
      dma_ack <= 1'b1;
      if (dma_wr) begin
        dma_writes <= dma_writes + 1;
        if ((dma_addr - base_addr) < 64) ndmem[dma_addr - base_addr] <= dma_wdata;
      end else begin
        dma_rdata <= ((dma_addr - base_addr) < 64) ?
                     ndmem[dma_addr - base_addr] : 16'hDEAD;
      end
    end
  end

  // ---- disc backend model --------------------------------------------------
  // Fills the DUT's sector buffer through the same port the real adapter
  // uses, then raises disk_done.
  reg [15:0] discdata[0:63];
  integer    fi;

  always @(posedge sysclk) begin
    disk_done <= 1'b0;
    dbuf_we   <= 1'b0;
    if (disk_req && !disk_wr && !disk_done) begin
      for (fi = 0; fi < NWORDS; fi = fi + 1) begin
        @(posedge sysclk);
        dbuf_addr  <= fi[9:0];
        dbuf_wdata <= discdata[fi];
        dbuf_we    <= 1'b1;
      end
      @(posedge sysclk);
      dbuf_we   <= 1'b0;
      disk_done <= 1'b1;
    end
  end

  integer errors = 0;

  reg [15:0] bus_capture = 16'd0;
  always @(posedge sysclk) if (iox_rd) bus_capture <= iox_rdata;

  task iox_write(input [15:0] a, input [15:0] d);
    begin
      @(posedge sysclk);
      iox_addr  <= a;
      iox_wdata <= d;
      iox_wr    <= 1'b1;
      @(posedge sysclk);
      iox_wr    <= 1'b0;
      @(posedge sysclk);
    end
  endtask

  task iox_read(input [15:0] a, output [15:0] d);
    begin
      @(posedge sysclk);
      iox_addr <= a;
      iox_rd   <= 1'b1;
      @(posedge sysclk);
      iox_rd   <= 1'b0;
      @(posedge sysclk);
      d = bus_capture;
    end
  endtask

  reg [15:0] st, mlo, mhi;
  integer    polls;

  task wait_finished;
    begin
      polls = 0;
      st = 16'd0;
      while (!st[3] && polls < 40000) begin
        iox_read(BASE + R_STATUS, st);
        polls = polls + 1;
      end
      if (!st[3]) begin
        $display("FAIL: operation never reported FINISHED (status %o)", st);
        errors = errors + 1;
      end
    end
  endtask

  // Load the registers for an operation on block 0 and fire the control word.
  task run_op(input [15:0] ctrl);
    begin
      iox_write(BASE + R_BLOCK,   16'd0);
      iox_write(BASE + R_LOADADR, LOAD_HI);
      iox_write(BASE + R_LOADADR, LOAD_LO);
      iox_write(BASE + R_WORDCNT, NWORDS[15:0]);
      iox_write(BASE + R_CONTROL, ctrl);
    end
  endtask

  // A status read is one of the four flip-flop reset conditions, so it is
  // what makes the following +0 pair come back LO then HI.
  task read_memaddr(output [15:0] lo, output [15:0] hi);
    begin
      iox_read(BASE + R_STATUS,  st);
      iox_read(BASE + R_MEMADDR, lo);
      iox_read(BASE + R_MEMADDR, hi);
    end
  endtask

  task expect_addr(input [31:0] want, input [255:0] what);
    reg [23:0] got;
    begin
      read_memaddr(mlo, mhi);
      got = {mhi[7:0], mlo};
      if (got !== want[23:0]) begin
        $display("FAIL: %0s - memory address register reads %o, expected %o",
                 what, got, want[23:0]);
        errors = errors + 1;
      end else begin
        $display("[ ok ] %0s - memory address register = %o", what, got);
      end
    end
  endtask

  integer i;

  initial begin
    for (i = 0; i < 64; i = i + 1) begin
      discdata[i] = 16'h1000 + i[15:0];
      ndmem[i]    = 16'h0000;
    end

    $display("=== Winchester M3 compare ===");
    repeat (6) @(posedge sysclk);
    sys_rst_n = 1;
    repeat (6) @(posedge sysclk);

    // ---- 1. matching compare -----------------------------------------------
    // Put the disc words into memory first, so the compare must succeed.
    for (i = 0; i < NWORDS; i = i + 1) ndmem[i] = discdata[i];
    dma_writes = 0;

    run_op(CTRL_CMP);
    wait_finished;

    iox_read(BASE + R_STATUS, st);
    if (st[10]) begin
      $display("FAIL: matching compare reported a compare error (status %o)", st);
      errors = errors + 1;
    end else begin
      $display("[ ok ] matching compare reports no compare error (status %o)", st);
    end
    if (st[4]) begin
      $display("FAIL: matching compare set the inclusive-OR bit (status %o)", st);
      errors = errors + 1;
    end

    // THE CHECK THE SINTRAN BOOT DEPENDS ON.
    expect_addr({LOAD_HI[7:0], LOAD_LO} + NWORDS, "matching compare");

    if (dma_writes != 0) begin
      $display("FAIL: compare wrote %0d words to ND memory - sec 3.4.7 says",
               dma_writes);
      $display("      no data transfer to the computer memory is performed");
      errors = errors + 1;
    end else begin
      $display("[ ok ] compare wrote nothing to ND memory");
    end

    // ---- 2. mismatching compare --------------------------------------------
    // Corrupt one word in the middle. The compare must stop THERE.
    ndmem[3] = 16'hBEEF;
    dma_writes = 0;

    run_op(CTRL_CMP);
    wait_finished;

    iox_read(BASE + R_STATUS, st);
    if (!st[10]) begin
      $display("FAIL: mismatching compare did not set b10 (status %o)", st);
      errors = errors + 1;
    end else begin
      $display("[ ok ] mismatching compare sets b10 (status %o)", st);
    end
    if (!st[4]) begin
      $display("FAIL: compare error did not raise the inclusive-OR bit b4 (%o)",
               st);
      errors = errors + 1;
    end

    expect_addr({LOAD_HI[7:0], LOAD_LO} + 3, "mismatching compare");

    // ---- 3. a read still works ---------------------------------------------
    // The compare shares the disc-read path, so prove the read it borrowed
    // from still moves data and still advances the address.
    for (i = 0; i < NWORDS; i = i + 1) ndmem[i] = 16'h0000;
    dma_writes = 0;

    run_op(CTRL_READ);
    wait_finished;

    expect_addr({LOAD_HI[7:0], LOAD_LO} + NWORDS, "read after compare");

    if (dma_writes != NWORDS) begin
      $display("FAIL: read moved %0d words to memory, expected %0d",
               dma_writes, NWORDS);
      errors = errors + 1;
    end
    for (i = 0; i < NWORDS; i = i + 1) begin
      if (ndmem[i] !== discdata[i]) begin
        $display("FAIL: read word %0d is %h, expected %h",
                 i, ndmem[i], discdata[i]);
        errors = errors + 1;
      end
    end
    if (errors == 0) $display("[ ok ] read after compare moved the right data");

    if (errors == 0) $display("TB_RESULT: PASS");
    else             $display("TB_RESULT: FAIL (%0d errors)", errors);
    $finish;
  end

  initial begin
    #20_000_000;
    $display("FAIL: timeout");
    $display("TB_RESULT: FAIL (timeout)");
    $finish;
  end

endmodule

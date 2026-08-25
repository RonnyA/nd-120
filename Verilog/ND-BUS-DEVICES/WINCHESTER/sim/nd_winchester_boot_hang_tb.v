/**************************************************************************
** TESTBENCH: ND_WINCHESTER - the SINTRAN boot hang, replayed exactly     **
**                                                                       **
** Captured from a Verilator SINTRAN boot (18-AUG-2026). The driver polls **
** status (+4) waiting for b2 ACTIVE to clear, and on operation 11 it     **
** never does: 13,356 polls all returned 060005 (b2 set, b3 clear) while  **
** the nd100x oracle returned 060011 (b2 clear, b3 FINISHED) and went on. **
**                                                                       **
** Both operations move 4608 words and complete every disk request. The   **
** ONLY differences in their setup are the memory address and control     **
** word bit 5, which is the low bit of the head number (s_head <=         **
** iox_wdata[8:5]): operation 10 is head 1, operation 11 is head 0.       **
**                                                                       **
** Operation 10 is replayed FIRST and on purpose. Replaying the hanging   **
** operation alone would miss a fault that is caused by state the         **
** PREVIOUS operation left behind, and that is a live possibility - the   **
** controller demonstrably completed seven operations before it hung.     **
***************************************************************************/
`timescale 1ns / 1ps

module nd_winchester_boot_hang_tb;

  localparam [15:0] BASE = 16'o000500;
  localparam [31:0] SHORT_DELAY = 32'd20;

  localparam SB_FINISHED = 3;
  localparam SB_ACTIVE   = 2;

  reg sysclk = 0;
  reg sys_rst_n = 0;
  always #10 sysclk = ~sysclk;

  reg  [15:0] iox_addr = 16'd0;
  reg         iox_wr = 1'b0;
  reg  [15:0] iox_wdata = 16'd0;
  reg         iox_rd = 1'b0;
  wire [15:0] iox_rdata;
  wire        iox_sel;
  wire [3:0]  int_pending;

  wire        dma_req, dma_wr;
  wire [23:0] dma_addr;
  wire [15:0] dma_wdata;
  wire        disk_start, disk_req, disk_wr;
  wire [15:0] disk_blkaddr1, disk_blkaddr2;
  wire [2:0]  disk_unit;
  wire [10:0] disk_wordcount;
  wire [15:0] dbuf_rdata;

  // --- DMA backend: acknowledge one word per request, never busy ---------
  reg dma_ack = 1'b0;
  integer dma_words = 0;
  integer dma_stall_after = 0;          // 0 = never stall
  always @(posedge sysclk) begin
    if (dma_req && (dma_stall_after == 0 || dma_words < dma_stall_after)) begin
      dma_ack   <= 1'b1;
      dma_words <= dma_words + 1;
    end else begin
      dma_ack <= 1'b0;
    end
  end

  // --- Disk backend: complete every request a few cycles later ----------
  // Models a working card. If the controller still fails to finish with a
  // backend that always completes, the fault is in the controller.
  reg  [3:0] disk_dly = 4'd0;
  reg        disk_done = 1'b0;
  integer    disk_reqs = 0;
  integer    disk_words = 0;
  always @(posedge sysclk) begin
    disk_done <= 1'b0;
    if (disk_req && disk_dly == 4'd0) begin
      disk_dly   <= 4'd4;
      disk_reqs  <= disk_reqs + 1;
      disk_words <= disk_words + disk_wordcount;
    end else if (disk_dly != 4'd0) begin
      disk_dly <= disk_dly - 4'd1;
      if (disk_dly == 4'd1) disk_done <= 1'b1;
    end
  end

  ND_WINCHESTER #(.DELAY_TICKS(SHORT_DELAY)) dut (
      .sysclk(sysclk), .sys_rst_n(sys_rst_n),
      .iox_addr(iox_addr), .iox_wr(iox_wr), .iox_wdata(iox_wdata),
      .iox_rd(iox_rd), .iox_rdata(iox_rdata), .iox_sel(iox_sel),
      .int_pending(int_pending),
      .ident_strobe(1'b0), .ident_level(4'd0), .ident_grant_in(1'b0),
      .ident_grant_out(), .ident_hit(), .ident_code(),
      .dma_req(dma_req), .dma_wr(dma_wr), .dma_addr(dma_addr),
      .dma_wdata(dma_wdata), .dma_rdata(16'd0), .dma_ack(dma_ack),
      .dma_err(1'b0), .dma_busy(1'b0),
      .disk_start(disk_start), .disk_req(disk_req), .disk_wr(disk_wr),
      .disk_blkaddr1(disk_blkaddr1), .disk_blkaddr2(disk_blkaddr2),
      .disk_unit(disk_unit), .disk_wordcount(disk_wordcount),
      .disk_done(disk_done), .disk_err_in(1'b0), .disk_err_code(4'd0),
      .dbuf_addr(10'd0), .dbuf_wdata(16'd0), .dbuf_we(1'b0),
      .dbuf_rdata(dbuf_rdata)
  );

  integer errors = 0;

  task iox_write(input [15:0] a, input [15:0] data);
    begin
      @(negedge sysclk);
      iox_addr = a; iox_wdata = data; iox_wr = 1'b1;
      @(negedge sysclk);
      iox_wr = 1'b0;
    end
  endtask

  task iox_read(input [15:0] a, output [15:0] d);
    begin
      @(negedge sysclk);
      iox_addr = a; iox_rd = 1'b1;
      #1 d = iox_rdata;
      @(posedge sysclk); @(negedge sysclk);
      iox_rd = 1'b0;
    end
  endtask

  // Replay one boot operation exactly as the driver issued it.
  task run_op(input [15:0] ma_lo, input [15:0] go, input [255:0] name);
    reg [15:0] st;
    integer polls;
    begin
      $display("\n--- %0s : MA=%06o  GO=%06o (head=%0d) ---",
               name, ma_lo, go, (go >> 5) & 4'hF);
      iox_write(BASE + 16'd5, 16'o000020);   // device clear
      iox_write(BASE + 16'd5, 16'o000020);
      iox_write(BASE + 16'd7, 16'o000000);   // word count 0
      iox_write(BASE + 16'd3, 16'o000200);   // block address
      iox_write(BASE + 16'd1, 16'o000000);   // memory address HI
      iox_write(BASE + 16'd1, ma_lo);        // memory address LO
      iox_write(BASE + 16'd7, 16'o011000);   // word count = 4608
      iox_write(BASE + 16'd5, go);           // GO

      polls = 0;
      st = 16'hFFFF;
      while (polls < 200000 && st[SB_ACTIVE] !== 1'b0) begin
        iox_read(BASE + 16'd4, st);
        polls = polls + 1;
      end
      $display("    disk requests=%0d  words=%0d  polls=%0d  status=%06o",
               disk_reqs, disk_words, polls, st);
      if (st[SB_ACTIVE] !== 1'b0) begin
        $display("    FAIL: b2 ACTIVE never cleared - THE BOOT HANG REPRODUCED");
        errors = errors + 1;
      end else if (st[SB_FINISHED] !== 1'b1) begin
        $display("    FAIL: b2 cleared but b3 FINISHED not set (status %06o)", st);
        errors = errors + 1;
      end else begin
        $display("    ok: b2 clear, b3 finished");
      end
    end
  endtask

  initial begin
    sys_rst_n = 1'b0;
    repeat (5) @(negedge sysclk);
    sys_rst_n = 1'b1;
    repeat (5) @(negedge sysclk);

    $display("== ND_WINCHESTER: SINTRAN boot hang replay ==");
    run_op(16'o051000, 16'o000045, "operation 10 (completed on the real boot)");
    run_op(16'o040000, 16'o000005, "operation 11 (HUNG on the real boot)");

    // Now withhold the memory acknowledge partway through a transfer and
    // show it produces the EXACT status the boot shows (060005: b2 active,
    // b3 not finished) - i.e. the observed hang is the memory side never
    // answering, not the disc side and not the control word.
    $display("\n--- control: memory side stops answering mid-transfer ---");
    dma_stall_after = dma_words + 2000;
    begin : stalled
      reg [15:0] st2; integer i2;
      iox_write(BASE + 16'd5, 16'o000020);
      iox_write(BASE + 16'd5, 16'o000020);
      iox_write(BASE + 16'd7, 16'o000000);
      iox_write(BASE + 16'd3, 16'o000200);
      iox_write(BASE + 16'd1, 16'o000000);
      iox_write(BASE + 16'd1, 16'o040000);
      iox_write(BASE + 16'd7, 16'o011000);
      iox_write(BASE + 16'd5, 16'o000005);
      st2 = 16'h0; i2 = 0;
      while (i2 < 4000) begin iox_read(BASE + 16'd4, st2); i2 = i2 + 1; end
      $display("    status after %0d polls = %06o   (boot shows 060005)", i2, st2);
      if (st2 == 16'o060005)
        $display("    MATCHES THE BOOT SIGNATURE exactly");
      else
        $display("    does NOT match the boot signature");
    end

    $display("\nTB_RESULT: %0s  (%0d failures)",
             (errors == 0) ? "PASS" : "FAIL", errors);
    $finish;
  end

  initial begin
    #50_000_000;
    $display("TB_RESULT: FAIL - global timeout");
    $finish;
  end

endmodule

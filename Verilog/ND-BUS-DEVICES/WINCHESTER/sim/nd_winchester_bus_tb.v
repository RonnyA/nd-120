/****************************************************************************
** TESTBENCH: ND_WINCHESTER behind the REAL ND_BUS_SLAVE                   **
**                                                                         **
** Every other Winchester bench drives iox_rd / iox_wr directly, so the    **
** card has never been tested through the adapter that actually generates  **
** those strobes on the board. That is a real hole: the failing register   **
** is the ONE register whose value depends on how many times the strobe    **
** fires (+0 alternates LO then HI on successive reads), so a bus adapter  **
** that produced two strobes for one programmer-visible IOX, or that       **
** latched the data on the wrong edge, would swap the two halves - and     **
** would do it while leaving the transferred data and the status word      **
** completely correct.                                                     **
**                                                                         **
** That is exactly the silicon symptom: DISC-TEMA J02 "DU-DI-C" on the     **
** Tang returns all 512 data words byte-identical to the nd100x C model    **
** and the identical status word 060010, then reports                      **
** "Memory address Register not as expected".                              **
**                                                                         **
** ND-100 bus sequence driven here (ND-06.026.1 EN p126, and the state     **
** machine in ND_BUS_SLAVE.v):                                             **
**   BAPR falls   - address on BD, direction in the LSB (0 read, 1 write)  **
**   BIOXE falls  - IOX window; on a write the data is on BD, on a read    **
**                  the slave raises BINPUT to say it will answer          **
**   BINACK falls - CPU ready; the slave issues its single-cycle iox_rd    **
**                  and puts the answer on BD with BDAP/BDRY               **
**                                                                         **
** Checks:                                                                 **
**   (a) ONE programmer-visible IOX read produces exactly ONE iox_rd       **
**       strobe - two would advance the +0 alternator twice per read       **
**   (b) two successive reads of +0 return LOW then HIGH, through the bus  **
**   (c) the same after a transfer, where the value is the advanced        **
**       address - the exact readback DISC-TEMA reports as wrong           **
**   (d) a write pair still loads HI then LO through the bus               **
**                                                                         **
** Verdict: TB_RESULT: PASS / TB_RESULT: FAIL <reason>                     **
**                                                                         **
** Ronny Hansen                                                            **
*****************************************************************************/
`timescale 1ns / 1ps

module nd_winchester_bus_tb;

  localparam [15:0] BASE = 16'o000500;

  localparam R_READ_MA    = 16'd0;
  localparam R_LOAD_MA    = 16'd1;
  localparam R_LOAD_BLOCK = 16'd3;
  localparam R_STATUS     = 16'd4;
  localparam R_CONTROL    = 16'd5;
  localparam R_LOAD_WC    = 16'd7;

  localparam [15:0] MA_HI_IN   = 16'o000001;
  localparam [15:0] MA_LO_IN   = 16'o000000;
  localparam [15:0] WORD_COUNT = 16'o001000;   // 512
  localparam [15:0] CTRL_GO    = 16'o000005;

  reg sysclk = 0;
  reg sys_rst_n = 0;
  always #10 sysclk = ~sysclk;

  // ---- CPU-side bus, all active low ---------------------------------------
  reg  [23:0] BD_OUT = 24'hFFFFFF;   // driven by the "CPU"
  wire [23:0] BD_IN;                 // driven by the slave
  reg         BAPR_n = 1'b1;
  reg         BIOXE_n = 1'b1;
  reg         BINACK_n = 1'b1;
  wire        BINPUT_n, BDAP_n, BDRY_n;

  // ---- device-side bus ----------------------------------------------------
  wire [15:0] iox_addr;
  wire        iox_wr, iox_rd;
  wire [15:0] iox_wdata;
  wire [15:0] wd_rdata;
  wire        wd_sel;
  wire [3:0]  wd_intp;

  ND_BUS_SLAVE u_slave (
      .sysclk(sysclk),
      .sys_rst_n(sys_rst_n),
      .BD_23_0_n_OUT(BD_OUT),
      .BD_23_0_n_IN (BD_IN),
      .BAPR_n(BAPR_n),
      .BIOXE_n(BIOXE_n),
      .BINACK_n(BINACK_n),
      .OUTIDENT_n(1'b1),
      .BINPUT_n(BINPUT_n),
      .BDAP_n(BDAP_n),
      .BDRY_n(BDRY_n),
      .BINT10_n(), .BINT11_n(), .BINT12_n(), .BINT13_n(),
      .iox_addr(iox_addr),
      .iox_wr(iox_wr),
      .iox_wdata(iox_wdata),
      .iox_rd(iox_rd),
      .iox_rdata(wd_rdata),
      .iox_hit(wd_sel),
      .int_pending(wd_intp),
      .ident_strobe(), .ident_level(),
      .ident_hit(1'b0), .ident_code(16'd0)
  );

  wire        dma_req, dma_wr;
  wire [23:0] dma_addr;
  wire [15:0] dma_wdata;
  reg         dma_ack = 1'b0;
  wire        disk_req, disk_wr, disk_start;
  wire [10:0] disk_wordcount;
  reg         disk_done = 1'b0;

  ND_WINCHESTER #(.DELAY_TICKS(32'd20)) dut (
      .sysclk(sysclk),
      .sys_rst_n(sys_rst_n),
      .iox_addr(iox_addr),
      .iox_wr(iox_wr),
      .iox_wdata(iox_wdata),
      .iox_rd(iox_rd),
      .iox_rdata(wd_rdata),
      .iox_sel(wd_sel),
      .trace_rec(), .trace_we(),
      .int_pending(wd_intp),
      .ident_strobe(1'b0), .ident_level(4'd0), .ident_grant_in(1'b0),
      .ident_grant_out(), .ident_hit(), .ident_code(),
      .dma_req(dma_req), .dma_wr(dma_wr), .dma_addr(dma_addr),
      .dma_wdata(dma_wdata), .dma_rdata(16'hA5A5),
      .dma_ack(dma_ack), .dma_err(1'b0), .dma_busy(1'b0),
      .disk_start(disk_start), .disk_req(disk_req), .disk_wr(disk_wr),
      .disk_blkaddr1(), .disk_blkaddr2(), .disk_unit(),
      .disk_wordcount(disk_wordcount),
      .disk_done(disk_done), .disk_err_in(1'b0), .disk_err_code(4'd0),
      .dbuf_addr(10'd0), .dbuf_wdata(16'd0), .dbuf_we(1'b0), .dbuf_rdata()
  );

  // trivial backends: one ack per DMA word, every disk chunk completes
  always @(posedge sysclk) begin
    dma_ack <= 1'b0;
    if (dma_req && !dma_ack) dma_ack <= 1'b1;
  end
  reg [1:0] disk_dly = 2'd0;
  always @(posedge sysclk) begin
    disk_done <= 1'b0;
    if (disk_req) disk_dly <= 2'd2;
    else if (disk_dly != 2'd0) begin
      disk_dly <= disk_dly - 2'd1;
      if (disk_dly == 2'd1) disk_done <= 1'b1;
    end
  end

  // ---- the check that only a bus-level bench can make ---------------------
  integer rd_strobes = 0;
  always @(posedge sysclk) if (iox_rd) rd_strobes = rd_strobes + 1;

  integer errors = 0;

  task check_eq(input [15:0] got, input [15:0] want, input [1023:0] msg);
    begin
      if (got !== want) begin
        $display("FAIL: %0s: got %o want %o", msg, got, want);
        errors = errors + 1;
      end else $display("[ ok ] %0s = %o", msg, got);
    end
  endtask

  // ---- ND-100 bus master --------------------------------------------------
  // Address LSB carries the direction: 0 = read, 1 = write.
  task bus_write(input [15:0] a, input [15:0] d);
    begin
      @(posedge sysclk);
      BD_OUT <= ~{8'h00, a | 16'h0001};   // LSB 1 = write
      @(posedge sysclk);
      BAPR_n <= 1'b0;
      @(posedge sysclk);
      BAPR_n <= 1'b1;
      BD_OUT <= ~{8'h00, d};
      repeat (2) @(posedge sysclk);
      BIOXE_n <= 1'b0;
      repeat (2) @(posedge sysclk);
      BIOXE_n <= 1'b1;
      BD_OUT  <= 24'hFFFFFF;
      repeat (3) @(posedge sysclk);
    end
  endtask

  task bus_read(input [15:0] a, output [15:0] d);
    integer g;
    begin
      @(posedge sysclk);
      BD_OUT <= ~{8'h00, a & ~16'h0001};  // LSB 0 = read
      @(posedge sysclk);
      BAPR_n <= 1'b0;
      @(posedge sysclk);
      BAPR_n <= 1'b1;
      BD_OUT <= 24'hFFFFFF;
      repeat (2) @(posedge sysclk);
      BIOXE_n <= 1'b0;
      // The slave raises BINPUT to say it will answer, and BINACK must fall
      // INSIDE the IOX window: ND_BUS_SLAVE returns to ST_IDLE on the BIOXE
      // RISE, so a BINACK after that is never answered. (Modelling it the
      // other way produced zero read strobes - a bench bug, not an RTL one.)
      repeat (2) @(posedge sysclk);
      BINACK_n <= 1'b0;
      g = 0;
      while (BDRY_n !== 1'b0 && g < 100) begin
        @(posedge sysclk);
        g = g + 1;
      end
      d = ~BD_IN[15:0];
      @(posedge sysclk);
      BINACK_n <= 1'b1;
      BIOXE_n  <= 1'b1;
      repeat (3) @(posedge sysclk);
    end
  endtask

  // ---- test ---------------------------------------------------------------
  reg [15:0] st, ma_lo, ma_hi;
  integer guard, snap;
  initial begin
    repeat (5) @(posedge sysclk);
    sys_rst_n = 1;
    repeat (10) @(posedge sysclk);

    // (a)+(d): a write pair, then ONE read - count the strobes it produced
    bus_write(BASE + R_LOAD_MA, MA_HI_IN);
    bus_write(BASE + R_LOAD_MA, MA_LO_IN);
    snap = rd_strobes;
    bus_read(BASE + R_READ_MA, ma_lo);
    if (rd_strobes - snap !== 1) begin
      $display("FAIL: one IOX read produced %0d iox_rd strobes (want 1) - the +0 alternator advances once per STROBE, so anything but 1 swaps the halves",
               rd_strobes - snap);
      errors = errors + 1;
    end else $display("[ ok ] one IOX read = one iox_rd strobe");
    check_eq(ma_lo, MA_LO_IN, "bus read 1 of +0 (LOW)");
    bus_read(BASE + R_READ_MA, ma_hi);
    check_eq(ma_hi, MA_HI_IN, "bus read 2 of +0 (HIGH)");

    // (c): the readback DISC-TEMA reports as wrong - after a real transfer
    bus_read(BASE + R_STATUS, st);                 // resets the alternator
    bus_write(BASE + R_LOAD_BLOCK, 16'd0);
    bus_write(BASE + R_LOAD_MA,    MA_HI_IN);
    bus_write(BASE + R_LOAD_MA,    MA_LO_IN);
    bus_write(BASE + R_LOAD_WC,    WORD_COUNT);
    bus_write(BASE + R_CONTROL,    CTRL_GO);
    guard = 0;
    st = 16'd0;
    while (guard < 100000 && !(st[3] && !st[2])) begin
      bus_read(BASE + R_STATUS, st);
      guard = guard + 1;
    end
    if (!(st[3] && !st[2])) begin
      $display("TB_RESULT: FAIL transfer never finished (last status %o)", st);
      $finish;
    end
    $display("status at finish = %o", st);
    bus_read(BASE + R_READ_MA, ma_lo);
    bus_read(BASE + R_READ_MA, ma_hi);
    check_eq(ma_lo, 16'o001000, "bus MAR read 1 after the transfer (LOW)");
    check_eq(ma_hi, 16'o000001, "bus MAR read 2 after the transfer (HIGH)");

    if (errors == 0)
      $display("TB_RESULT: PASS (Winchester register access through ND_BUS_SLAVE)");
    else $display("TB_RESULT: FAIL %0d errors", errors);
    $finish;
  end

  initial begin
    #50_000_000;
    $display("TB_RESULT: FAIL absolute watchdog");
    $finish;
  end

endmodule

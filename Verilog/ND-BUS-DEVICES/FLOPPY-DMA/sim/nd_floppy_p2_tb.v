/**************************************************************************
** TESTBENCH: ND_FLOPPY_DMA - floppy campaign phase P2                    **
**            iox_rd STROBE WIDTH + the BOOT-READ CONSUME rule            **
**                                                                       **
**   scripted CPU bus master -> ND_BUS_SLAVE -> ND_FLOPPY_DMA            **
**                                                   |                   **
**                                             disk image backend        **
**                                                                       **
** P1 (nd_floppy_iox_tb) asserts the register matrix at the DEVICE port  **
** with a hand-pulsed iox_rd. P2 closes the two questions P1 left open   **
** (CONFORMANCE.md sec 7 bug-candidates 1 & 2, sec 9.4) by driving the   **
** REAL CPU-side bus handshake so the strobe is the one ND_BUS_SLAVE     **
** actually generates:                                                   **
**                                                                       **
**  1  STROBE WIDTH (sec 7.1): the slave must pulse iox_rd for exactly   **
**       one sysclk cycle. A wider strobe would advance the boot pointer **
**       more than once per bus read (over-consumption). Proven by a     **
**       continuous monitor over the whole run: iox_rd is never high on  **
**       two consecutive sysclk edges.                                   **
**  2  ONE CONSUME PER READ: a single bus +0 read in boot mode advances  **
**       s_bootptr by exactly 1 (the width property, observed at the     **
**       pointer).                                                       **
**  3  REFILL AT EXACTLY 512 (positive control): read a full 512-word    **
**       chunk, then the next activate refetches chunk 1 - s_lsect++,    **
**       s_bootptr wraps to 0, +0 now serves image[512].                 **
**  4  OVERRUN WEDGE (sec 7.2 cand. 2, a regression trap documenting     **
**       TODAY's truth): the +0 read is gated on neither s_rft nor       **
**       s_buf_valid (cand. 1), so an extra un-polled read drives        **
**       s_bootptr to 513. The refill branch fires ONLY at ==512, so a   **
**       following activate can NOT refetch - s_bootptr stays 513,       **
**       s_lsect frozen: the stream wedges until a device clear. This    **
**       test PINS that behaviour so a future fix flips it deliberately. **
**                                                                       **
** Authority for the stream/pointer semantics: the portable core         **
** NDDeviceCore/src/nd_floppy_dma.c + the RTL under test. The nd100x C   **
** oracle stubs autoload, so it is not the authority here (same note as  **
** nd_floppy_boot_tb).                                                   **
**                                                                       **
** Verdict line: TB_RESULT: PASS / TB_RESULT: FAIL                       **
***************************************************************************/

`timescale 1ns / 1ps

module nd_floppy_p2_tb;

  reg sysclk = 0;
  reg sys_rst_n = 0;
  always #10 sysclk = ~sysclk;

  // ---- CPU-side bus (IOX master) ----
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
      .iox_rd(iox_rd), .iox_rdata(iox_rdata), .iox_hit(1'b1),
      .int_pending(intp),
      .ident_strobe(ident_strobe), .ident_level(ident_level),
      .ident_hit(ident_hit), .ident_code(ident_code)
  );

  // ---- DMA master port: the autoload byte-server never issues a dma_req,
  //      so tie the master side idle (leaner than a full BCU + memory). ----
  wire        c_dma_req, c_dma_wr;
  wire [23:0] c_dma_addr;
  wire [15:0] c_dma_wdata;
  reg  [15:0] c_dma_rdata = 16'd0;
  reg         c_dma_ack = 1'b0, c_dma_err = 1'b0, c_dma_busy = 1'b0;

  // ---- disk backend (fills the boot sector buffer via dbuf_we) ----
  wire        disk_req, disk_wr;
  wire [15:0] disk_lsect;
  wire [1:0]  disk_format, disk_drive;
  wire [10:0] disk_wordcount;
  reg         disk_done = 0, disk_err_in = 0;
  reg  [3:0]  disk_media_fmt = 4'b1111;
  reg  [9:0]  dbuf_addr = 0;
  reg  [15:0] dbuf_wdata = 0;
  reg         dbuf_we = 0;
  wire [15:0] dbuf_rdata;

  // DISK_TIMEOUT off (0): the boot buffer always fills, no watchdog path.
  ND_FLOPPY_DMA #(
      .DELAY_TICKS(16'd20),
      .DISK_TIMEOUT(16'd0)
  ) u_fdma (
      .sysclk(sysclk), .sys_rst_n(sys_rst_n),
      .iox_addr(iox_addr), .iox_wr(iox_wr), .iox_wdata(iox_wdata),
      .iox_rd(iox_rd), .iox_rdata(iox_rdata),
      .int_pending(intp),
      .ident_strobe(ident_strobe), .ident_level(ident_level),
      .ident_grant_in(1'b1), .ident_grant_out(),
      .ident_hit(ident_hit), .ident_code(ident_code),
      .dma_req(c_dma_req), .dma_wr(c_dma_wr), .dma_addr(c_dma_addr),
      .dma_wdata(c_dma_wdata), .dma_rdata(c_dma_rdata),
      .dma_ack(c_dma_ack), .dma_err(c_dma_err), .dma_busy(c_dma_busy),
      .disk_req(disk_req), .disk_wr(disk_wr),
      .disk_lsect(disk_lsect), .disk_format(disk_format),
      .disk_drive(disk_drive), .disk_wordcount(disk_wordcount),
      .disk_done(disk_done), .disk_err_in(disk_err_in),
      .disk_media_fmt(disk_media_fmt),
      .dbuf_addr(dbuf_addr), .dbuf_wdata(dbuf_wdata), .dbuf_we(dbuf_we),
      .dbuf_rdata(dbuf_rdata)
  );

  // ---- disk image model (flat big-endian word stream) ----
  // Boot reads format 3 (512 words/sector); logical sector N -> word offset
  // N*512, so image[global_word] serves the stream in flat order.
  localparam BWPS = 512;                 // words per boot sector (format 3)
  localparam IMG_WORDS = 4 * BWPS;       // a few boot chunks
  reg [15:0] image[0:IMG_WORDS - 1];
  integer ii;
  initial for (ii = 0; ii < IMG_WORDS; ii = ii + 1) image[ii] = 16'hA000 + ii[15:0];

  integer w, base;
  always @(posedge sysclk) begin
    disk_done   <= 1'b0;
    disk_err_in <= 1'b0;
    dbuf_we     <= 1'b0;
    if (disk_req && !disk_wr) begin
      base = disk_lsect * ((disk_format == 2'd3) ? 512 :
                           (disk_format == 2'd2) ? 64 :
                           (disk_format == 2'd1) ? 128 : 256);
      for (w = 0; w < disk_wordcount; w = w + 1) begin
        @(posedge sysclk);
        dbuf_addr  <= w[9:0];
        dbuf_wdata <= image[base + w];
        dbuf_we    <= 1'b1;
      end
      @(posedge sysclk);
      dbuf_we   <= 1'b0;
      disk_done <= 1'b1;
    end
  end

  // ---- STROBE-WIDTH monitor (sec 7.1) --------------------------------------
  // Count consecutive sysclk edges on which iox_rd is high. A correct
  // single-cycle strobe never reaches 2. rd_run_max is asserted == 1 at the
  // end of the run, covering every bus read the tb performs.
  integer rd_run = 0, rd_run_max = 0;
  always @(posedge sysclk) begin
    if (iox_rd) rd_run = rd_run + 1;
    else        rd_run = 0;
    if (rd_run > rd_run_max) rd_run_max = rd_run;
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

  // ---- CPU-side IOX tasks (identical framing to nd_floppy_boot_tb) ----
  task bus_apr(input [15:0] addr);
    begin
      @(negedge sysclk); bd_out = ~{8'd0, addr}; bapr_n = 0;
      @(negedge sysclk); @(negedge sysclk);
      bapr_n = 1; bd_out = 24'hFFFFFF; @(negedge sysclk);
    end
  endtask

  task iox_write(input [15:0] addr, input [15:0] data);
    integer guard;
    begin
      bus_apr(addr | 16'd1);
      bd_out  = ~{8'd0, data}; bioxe_n = 0; guard = 0;
      while (bdry_n !== 1'b0 && guard < 50) begin @(negedge sysclk); guard = guard + 1; end
      check(bdry_n === 1'b0, "iox_write: BDRY_n never asserted");
      @(negedge sysclk); bioxe_n = 1; bd_out = 24'hFFFFFF;
      @(negedge sysclk); @(negedge sysclk);
    end
  endtask

  task iox_read(input [15:0] addr, output [15:0] data);
    integer guard;
    begin
      bus_apr(addr & 16'hFFFE);
      bioxe_n = 0; guard = 0;
      while (binput_n !== 1'b0 && guard < 50) begin @(negedge sysclk); guard = guard + 1; end
      check(binput_n === 1'b0, "iox_read: BINPUT_n never asserted");
      binack_n = 0; guard = 0;
      while (bdry_n !== 1'b0 && guard < 50) begin @(negedge sysclk); guard = guard + 1; end
      check(bdry_n === 1'b0, "iox_read: BDRY_n never asserted");
      data = ~bd_in[15:0];
      binack_n = 1; bioxe_n = 1; @(negedge sysclk); @(negedge sysclk);
    end
  endtask

  // Activate one boot word and poll +2 for RFT (status bit 3). Returns the
  // final status word. guard-limited so a genuine hang FAILS, not spins.
  task boot_activate_poll(output [15:0] st, output timed_out);
    integer guard;
    begin
      iox_write(16'o001563, 16'o000004);   // control bit 2 = activate
      guard = 0; st = 0; timed_out = 1'b0;
      while (!(st & 16'h0008) && guard < 30000) begin
        iox_read(16'o001562, st);
        guard = guard + 1;
      end
      if (!(st & 16'h0008)) timed_out = 1'b1;
    end
  endtask

  task device_clear;
    begin
      iox_write(16'o001563, 16'o000020);   // control bit 4 = device clear
      repeat (10) @(negedge sysclk);
    end
  endtask

  reg [15:0] st, bw, r0;
  reg        tmo;
  integer    k;
  integer    ptr_before, ptr_after, lsect_before;

  initial begin
`ifdef DUMPFILE
    $dumpfile("nd_floppy_p2_tb.vcd");
    $dumpvars(0, nd_floppy_p2_tb);
`endif
    repeat (5) @(negedge sysclk);
    sys_rst_n = 1;
    repeat (5) @(negedge sysclk);

    // ================= Test 2: ONE CONSUME PER BUS READ ==================
    // Enter boot (chunk 0 loaded), then a single +0 bus read advances the
    // boot pointer by exactly 1 - the strobe-width property at the pointer.
    boot_activate_poll(st, tmo);
    check(!tmo, "T2: boot entry RFT never released");
    check((st & 16'h8000) !== 0, "T2: dualDensity (b15) not set in boot");
    ptr_before = u_fdma.s_bootptr;
    iox_read(16'o001560, bw);
    ptr_after = u_fdma.s_bootptr;
    check(ptr_after - ptr_before == 1,
          "T2: one bus +0 read must advance s_bootptr by exactly 1");
    check(bw === image[ptr_before],
          "T2: +0 must serve image[bootptr] (first boot word)");

    // ================= Test 3: REFILL AT EXACTLY 512 (positive) ==========
    // From here bootptr is 1. Read up to exactly 512 (511 more reads), then
    // the next activate must refetch chunk 1: s_lsect++, bootptr -> 0, and
    // +0 now serves image[512].
    for (k = 1; k < 512; k = k + 1) iox_read(16'o001560, bw);
    check(u_fdma.s_bootptr == 512, "T3: pointer should sit at exactly 512");
    lsect_before = u_fdma.s_lsect;
    boot_activate_poll(st, tmo);        // activate at ==512 -> refetch
    check(!tmo, "T3: refill activate at 512 never released RFT");
    check(u_fdma.s_lsect == lsect_before + 1,
          "T3: refill at 512 must advance s_lsect to the next chunk");
    check(u_fdma.s_bootptr == 0, "T3: refill at 512 must wrap bootptr to 0");
    iox_read(16'o001560, bw);
    check(bw === image[512], "T3: after refill +0 must serve image[512]");

    // ================= Test 4: OVERRUN WEDGE (regression trap) ===========
    // Fresh boot. The +0 read is gated on neither RFT nor buf_valid, so an
    // extra un-polled read pushes bootptr one past 512 -> 513. The refill
    // branch keys on ==512 ONLY, so a following activate can NOT refetch:
    // bootptr stays 513, s_lsect frozen. This PINS today's wedge.
    device_clear;
    boot_activate_poll(st, tmo);        // boot entry, bootptr -> 0
    check(!tmo, "T4: fresh boot entry hung");
    // 513 un-polled +0 reads: the un-gated read consumes every time.
    for (k = 0; k < 513; k = k + 1) iox_read(16'o001560, bw);
    check(u_fdma.s_bootptr == 513,
          "T4: un-gated +0 read must reach bootptr 513 (over-consumption)");
    lsect_before = u_fdma.s_lsect;
    iox_write(16'o001563, 16'o000004); // activate with bootptr==513
    repeat (20) @(negedge sysclk);
    // TODAY's truth: refetch unreachable at 513 - no new chunk fetched.
    check(u_fdma.s_bootptr == 513,
          "T4 (pinned wedge): activate at 513 does NOT refetch (bootptr stays 513)");
    check(u_fdma.s_lsect == lsect_before,
          "T4 (pinned wedge): s_lsect frozen - refill unreachable past 512");
    // Recovery: device clear leaves boot mode; +0 returns the idle constant 1.
    device_clear;
    iox_read(16'o001560, r0);
    check(r0 === 16'd1, "T4: device clear must recover - +0 returns idle 1");

    // ================= Test 1: STROBE WIDTH verdict (sec 7.1) ============
    // Every bus read above passed through the monitor; the strobe must never
    // have been high on two consecutive sysclk edges.
    check(rd_run_max == 1,
          "T1: iox_rd must be a single-cycle strobe (no over-consumption)");
    $display("NOTE: max consecutive iox_rd-high sysclk edges = %0d (must be 1)", rd_run_max);

    if (errors == 0) $display("TB_RESULT: PASS");
    else begin
      $display("%0d errors", errors);
      $display("TB_RESULT: FAIL");
    end
    $finish;
  end

  initial begin
    #200000000;
    $display("TIMEOUT");
    $display("TB_RESULT: FAIL");
    $finish;
  end

endmodule

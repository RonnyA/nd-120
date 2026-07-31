/**************************************************************************
** TESTBENCH: ND_FLOPPY_DMA - the '1560&' AUTOLOAD byte-server           **
**                                                                       **
**   scripted CPU bus master -> ND_BUS_SLAVE -> ND_FLOPPY_DMA            **
**                                                   |                   **
**                                             disk image backend        **
**                                                                       **
** This tb machine-checks the autoload / boot byte-server against the    **
** behavioural authority for that path. The nd100x C oracle              **
** (deviceFloppyDMA.c) does NOT implement the byte-server - its          **
** ExecuteAutoload() is a stub that only DMAs a LOAD-ERROR image - so    **
** the authority for the STREAM is the portable core                     **
** NDDeviceCore/src/nd_floppy_dma.c (execute_autoload / boot_present_word**
** / boot_start_read / boot_fail) plus the ND-120 microcode contract     **
** (docs/floppy-autoload-microcode-contract.md, ETLO1 load-code bit13=0):**
**                                                                       **
**   per stream word: write +3 = 4 (activate, control bit 2),           **
**   poll +2 until status bit 3 (RFT) set, read +0 = the next word.      **
**   The stream is a FLAT big-endian word sequence starting at byte 0,   **
**   served 512 words (FLOPPY_BOOT_CHUNK_WORDS) at a time, the buffer     **
**   refilled from the media at byte offset chunk*1024 (format 3 =        **
**   1024 B/sector, logical sector = chunk).                             **
**                                                                       **
** Phases:                                                               **
**  A  boot entry + exact word stream across a chunk boundary (0..600)   **
**       - proves the flat-512-word refill serves image[k] verbatim.     **
**  B  boot EXIT via device clear -> +0 returns the idle constant 1.     **
**  C  BOOT-FAIL (the fix): a backend read error during a boot refill    **
**       must reproduce boot_fail() - clear boot mode, report oct 50     **
**       (NO_BOOTSTRAP) + hard error on the IOX status word, and RELEASE  **
**       the RFT poll (no silent hang). +0 then returns the idle 1, and   **
**       a fresh activate re-enters boot cleanly (serves word 0 again).   **
**                                                                       **
** Verdict line: TB_RESULT: PASS / TB_RESULT: FAIL                       **
***************************************************************************/

`timescale 1ns / 1ps

module nd_floppy_boot_tb;

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

  // ---- DMA master + BCU + memory (not exercised by autoload, but the
  //      port must be connected; the boot path never issues a dma_req) ----
  wire        c_dma_req, c_dma_wr;
  wire [23:0] c_dma_addr;
  wire [15:0] c_dma_wdata, c_dma_rdata;
  wire        c_dma_ack, c_dma_err, c_dma_busy;

  wire        m_breq_n;
  reg         bmem_n = 1;
  reg         grant_head_n = 1;
  wire [23:0] m_bd_out_n;
  reg  [23:0] mem_bd_n = 24'hFFFFFF;
  wire [23:0] mbd_bus_n = m_bd_out_n & mem_bd_n;
  wire        m_bapr_n, m_binput_n, m_bdap_n;
  reg         m_bdry_n = 1;

  ND_DMA_MASTER #(.TIMEOUT_TICKS(16'd500), .MIN_GAP_TICKS(8'd4)) u_dma (
      .sysclk(sysclk), .sys_rst_n(sys_rst_n),
      .dma_req(c_dma_req), .dma_wr(c_dma_wr), .dma_addr(c_dma_addr),
      .dma_wdata(c_dma_wdata), .dma_rdata(c_dma_rdata),
      .dma_ack(c_dma_ack), .dma_err(c_dma_err), .dma_busy(c_dma_busy),
      .BREQ_n(m_breq_n),
      .INGRANT_n(grant_head_n), .OUTGRANT_n(),
      .BMEM_n(bmem_n),
      .BD_23_0_n_OUT(m_bd_out_n), .BD_23_0_n_IN(mbd_bus_n),
      .BAPR_n(m_bapr_n), .BINPUT_n(m_binput_n), .BDAP_n(m_bdap_n),
      .BDRY_n(m_bdry_n)
  );

  reg [15:0] memory [0:65535];
  reg [23:0] m_addr;
  reg        m_write;
  reg [3:0]  m_state = 0;
  reg [3:0]  m_cnt = 0;
  always @(posedge sysclk) begin
    case (m_state)
      4'd0: if (m_breq_n == 1'b0) begin m_cnt <= 4'd2; m_state <= 4'd1; end
      4'd1: begin
        if (m_cnt != 0) m_cnt <= m_cnt - 4'd1;
        else begin bmem_n <= 1'b0; grant_head_n <= 1'b0; m_state <= 4'd2; end
      end
      4'd2: if (m_bapr_n == 1'b0) begin
        m_addr  <= ~mbd_bus_n; m_write <= (m_binput_n == 1'b0); m_state <= 4'd3;
      end
      4'd3: if (m_bdap_n == 1'b0) begin
        if (m_write) memory[m_addr[15:0]] <= ~mbd_bus_n[15:0];
        else mem_bd_n <= ~{8'd0, memory[m_addr[15:0]]};
        m_bdry_n <= 1'b0; grant_head_n <= 1'b1; m_state <= 4'd4;
      end
      4'd4: if (m_bdap_n == 1'b1) begin
        m_bdry_n <= 1'b1; mem_bd_n <= 24'hFFFFFF; bmem_n <= 1'b1; m_state <= 4'd5;
      end
      4'd5: m_state <= 4'd0;
      default: m_state <= 4'd0;
    endcase
  end

  // ---- disk backend ----
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

  // DISK_TIMEOUT off (0) here so the ONLY boot-fail path tested is the
  // explicit backend read error (disk_err_in), not the watchdog - the two
  // share the same boot_fail end-state in the RTL.
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
  localparam IMG_WORDS = 8 * BWPS;       // a few boot chunks
  reg [15:0] image[0:IMG_WORDS - 1];
  integer ii;
  initial for (ii = 0; ii < IMG_WORDS; ii = ii + 1) image[ii] = 16'hA000 + ii[15:0];

  // fail-injection: when armed, the NEXT disk_req answers with a read error
  // (disk_done + disk_err_in) and fills nothing - models a boot refill that
  // hit a dead/again-silent medium mid-stream.
  reg boot_fail_arm = 0;

  integer w, base;
  always @(posedge sysclk) begin
    disk_done   <= 1'b0;
    disk_err_in <= 1'b0;
    dbuf_we     <= 1'b0;
    if (disk_req && boot_fail_arm) begin
      boot_fail_arm <= 1'b0;
      disk_done     <= 1'b1;   // answer, but as an error - no buffer fill
      disk_err_in   <= 1'b1;
    end else if (disk_req && !disk_wr) begin
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

  integer errors = 0;
  task check(input cond, input [255:0] what);
    begin
      if (!cond) begin
        errors = errors + 1;
        $display("FAIL: %0s (time %0t)", what, $time);
      end
    end
  endtask

  // ---- CPU-side IOX tasks (identical framing to nd_floppy_dma_tb) ----
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
  // final status word so callers can also inspect error / hard-error bits.
  // guard-limited so a genuine hang (RFT never released) FAILS instead of
  // spinning forever - that is exactly the silent-hang regression we guard.
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

  reg [15:0] st, bw, r0;
  reg        tmo;
  integer    k;

  initial begin
`ifdef DUMPFILE
    $dumpfile("nd_floppy_boot_tb.vcd");
    $dumpvars(0, nd_floppy_boot_tb);
`endif
    for (k = 0; k < 65536; k = k + 1) memory[k] = 16'hDEAD;

    repeat (5) @(negedge sysclk);
    sys_rst_n = 1;
    repeat (5) @(negedge sysclk);

    // -------- Phase A: boot entry + exact word stream, crossing the 512-word
    //          chunk boundary (600 > 512 forces one refill) ----------------
    // +0 outside boot mode is the idle constant 1 (C oracle FloppyDMA_Read).
    iox_read(16'o001560, r0);
    check(r0 === 16'd1, "A: +0 before boot must be idle constant 1");

    for (k = 0; k < 600; k = k + 1) begin
      boot_activate_poll(st, tmo);
      check(!tmo, "A: boot stream RFT never released (silent hang)");
      check((st & 16'h8000) !== 0, "A: dualDensity (b15) not set during boot");
      iox_read(16'o001560, bw);
      if (bw !== image[k])
        check(1'b0, "A: boot stream word mismatch vs flat image");
    end

    // -------- Phase B: leave boot mode by device clear (control bit 4) ----
    iox_write(16'o001563, 16'o000020);   // deviceClear
    repeat (10) @(negedge sysclk);
    iox_read(16'o001560, r0);
    check(r0 === 16'd1, "B: +0 after device-clear must return idle 1");

    // -------- Phase C: BOOT-FAIL end-state (the fix under test) -----------
    // Arm the backend to error on the first boot refill. The first activate
    // enters boot and starts the chunk-0 read; that read returns an error.
    boot_fail_arm = 1'b1;
    boot_activate_poll(st, tmo);
    // The controller MUST release the poll (boot_fail sets RFT) - a hang here
    // is the exact silent-boot failure this test exists to catch.
    check(!tmo, "C: boot-fail must release RFT, not hang the poll");
    // IOX hardware status word (+2): hard error b7 set, OR-of-errors b4 set.
    // The numeric error code (oct 50) lives only in Status Word 1 (CB+6),
    // which autoload never writes (no command block) - so assert it on the
    // flags the hardware status word DOES carry.
    check((st & 16'h0080) !== 0, "C: boot-fail hard error (b7) not set");
    check((st & 16'h0010) !== 0, "C: boot-fail OR-of-errors (b4) not set");
    // boot mode cleared: +0 returns the idle constant 1, NOT stale buffer.
    iox_read(16'o001560, r0);
    check(r0 === 16'd1, "C: +0 after boot-fail must return idle 1 (boot cleared)");

    // A fresh activate must re-enter boot cleanly and serve word 0 again.
    boot_activate_poll(st, tmo);
    check(!tmo, "C: re-entry after boot-fail hung");
    iox_read(16'o001560, bw);
    check(bw === image[0], "C: re-entry did not restart the stream at word 0");

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

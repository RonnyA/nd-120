/**************************************************************************
** TESTBENCH: ND_FLOPPY_DMA - the full DMA device stack                  **
**                                                                       **
**   scripted CPU bus master -> ND_BUS_SLAVE -> ND_FLOPPY_DMA            **
**                                    |              |                   **
**                                    |         ND_DMA_MASTER            **
**                                    |              |                   **
**                              BCU + ND-memory model (from the DMA tb)  **
**                                                                       **
** The CPU side builds a 12-word command block in the memory model,      **
** loads the pointer registers by IOX, writes the execute bit, and       **
** polls status - exactly like the real driver. The controller then      **
** DMA-fetches the block, moves sector data between the disk-image       **
** model and ND memory through the DMA master, and DMA-writes status     **
** back into the block.                                                  **
**                                                                       **
** Covered: dualDensity status bit (always 1), multi-sector read         **
** crossing a sector boundary with a partial tail (300 words), write     **
** of two full sectors, status writeback words (RSR1 copy, last memory   **
** address, remaining words = 0), IDENTIFY stub completion, level-11     **
** interrupt on completion + IDENT code 021 + clear-on-IDENT - and a     **
** REAL floppy image phase: testdata/210523I01-XX-01D.img (an original   **
** ND distribution diskette, 1261568 bytes) is loaded into the disk      **
** model and read back through the controller at the start, middle and   **
** end of the image, word-compared against the file content.             **
**                                                                       **
** Verdict line: TB_RESULT: PASS / TB_RESULT: FAIL                       **
**                                                                       **
** Last reviewed: 11-JUL-2026                                            **
** Ronny Hansen                                                          **
***************************************************************************/

`timescale 1ns / 1ps

module nd_floppy_dma_tb;

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
      .iox_rd(iox_rd), .iox_rdata(iox_rdata),
      .int_pending(intp),
      .ident_strobe(ident_strobe), .ident_level(ident_level),
      .ident_hit(ident_hit), .ident_code(ident_code)
  );

  // ---- DMA master between the controller and the memory bus ----
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

  // ---- disk backend wires ----
  wire        disk_req, disk_wr;
  wire [15:0] disk_lsect;
  wire [1:0]  disk_format, disk_drive;
  wire [10:0] disk_wordcount;
  reg         disk_done = 0, disk_err_in = 0;
  reg  [9:0]  dbuf_addr = 0;
  reg  [15:0] dbuf_wdata = 0;
  reg         dbuf_we = 0;
  wire [15:0] dbuf_rdata;

  ND_FLOPPY_DMA #(
      .DELAY_TICKS(16'd20)
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
      .dbuf_addr(dbuf_addr), .dbuf_wdata(dbuf_wdata), .dbuf_we(dbuf_we),
      .dbuf_rdata(dbuf_rdata)
  );

  // ---- BCU + ND memory model (same protocol as the DMA master tb) ----
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
        m_addr  <= ~mbd_bus_n;
        m_write <= (m_binput_n == 1'b0);
        m_state <= 4'd3;
      end
      4'd3: if (m_bdap_n == 1'b0) begin
        if (m_write) memory[m_addr[15:0]] <= ~mbd_bus_n[15:0];
        else mem_bd_n <= ~{8'd0, memory[m_addr[15:0]]};
        m_bdry_n     <= 1'b0;
        grant_head_n <= 1'b1;
        m_state      <= 4'd4;
      end
      4'd4: if (m_bdap_n == 1'b1) begin
        m_bdry_n <= 1'b1;
        mem_bd_n <= 24'hFFFFFF;
        bmem_n   <= 1'b1;
        m_state  <= 4'd5;
      end
      4'd5: m_state <= 4'd0;
      default: m_state <= 4'd0;
    endcase
  end

  // ---- disk image model (format 0: 256 words per sector) ----
  // Sized for the real image: 1261568 bytes = 630784 words = 2464
  // logical sectors at 256 words. The synthetic pattern fills the
  // low sectors for the protocol tests; the real image is loaded
  // over it for the real-image phase.
  localparam WPS = 256;
  localparam IMG_WORDS = 630784;
  reg [15:0] image[0:IMG_WORDS - 1];
  integer ii, w, base;
  initial begin
    for (ii = 0; ii < 64 * WPS; ii = ii + 1)
      image[ii] = 16'h9000 + ii[15:0];
  end

  reg img_loaded;
  initial img_loaded = 0;

  task load_real_image;
    integer fd, n;
    begin
      fd = $fopen("../../testdata/210523I01-XX-01D.img", "rb");
      if (fd == 0) begin
        // image files are local-only (gitignored) - see testdata/README.md
        $display("[tb] SKIP real-image phase: testdata/210523I01-XX-01D.img not present");
      end else begin
        img_loaded = 1;
        // $fread packs big-endian per element - the same byte order the
        // C models use (ReadWord: hi byte first)
        n = $fread(image, fd);
        $fclose(fd);
        check(n == 2 * IMG_WORDS, "real image short read");
        $display("[tb] real image loaded: %0d bytes; first words %06o %06o %06o %06o",
                 n, image[0], image[1], image[2], image[3]);
      end
    end
  endtask

  always @(posedge sysclk) begin
    disk_done   <= 1'b0;
    disk_err_in <= 1'b0;
    dbuf_we     <= 1'b0;
    if (disk_req) begin
      base = disk_lsect * WPS;
      if (!disk_wr) begin
        for (w = 0; w < disk_wordcount; w = w + 1) begin
          @(posedge sysclk);
          dbuf_addr  <= w[9:0];
          dbuf_wdata <= image[base + w];
          dbuf_we    <= 1'b1;
        end
        @(posedge sysclk);
        dbuf_we   <= 1'b0;
        disk_done <= 1'b1;
      end else begin
        for (w = 0; w < disk_wordcount; w = w + 1) begin
          dbuf_addr <= w[9:0];
          @(posedge sysclk);
          @(posedge sysclk);
          image[base + w] = dbuf_rdata;
        end
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

  // ---- CPU-side IOX tasks (same sequences as the other tbs) ----

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

  // execute a command block already placed at CB and wait for ready
  task run_command(input [15:0] cb, input enable_int);
    integer guard;
    reg [15:0] st;
    begin
      iox_write(16'o001565, 16'd0);        // pointer high
      iox_write(16'o001567, cb);           // pointer low
      iox_write(16'o001563,
                16'h0100 | (enable_int ? 16'h0002 : 16'h0000));
      guard = 0;
      st = 0;
      while (!(st & 16'h0008) && guard < 30000) begin
        iox_read(16'o001562, st);
        guard = guard + 1;
      end
      check((st & 16'h0008) !== 0, "controller never became ready");
      check((st & 16'h8000) !== 0, "dualDensity bit not set in RSR1");
    end
  endtask

  reg [15:0] rdata;
  reg        ihit;
  reg [15:0] icode;
  integer    i;

  localparam CB = 16'h0100;  // command block address in ND memory

  initial begin
`ifdef DUMPFILE
    $dumpfile("nd_floppy_dma_tb.vcd");
    $dumpvars(0, nd_floppy_dma_tb);
`endif
    for (i = 0; i < 65536; i = i + 1) memory[i] = 16'hDEAD;

    repeat (5) @(negedge sysclk);
    sys_rst_n = 1;
    repeat (5) @(negedge sysclk);

    // 1: RSR1 basics before any command
    iox_read(16'o001562, rdata);
    check((rdata & 16'h8000) !== 0, "dualDensity not set at reset");
    check((rdata & 16'h0008) !== 0, "not ready at reset");

    // 2: READ 300 words (multi-sector: 256 + 44) from lsect 2 to 0x4000
    memory[CB + 0] = 16'h0000;  // func 0 read, drive 0, format 0
    memory[CB + 1] = 16'd2;     // logical sector 2
    memory[CB + 2] = 16'd0;     // mem addr high
    memory[CB + 3] = 16'h4000;  // mem addr low
    memory[CB + 4] = 16'h8000;  // word-count select
    memory[CB + 5] = 16'd300;   // 300 words
    run_command(CB, 1'b0);
    for (i = 0; i < 300; i = i + 1) begin
      if (memory[16'h4000 + i] !== (16'h9000 + (2 * WPS + i)))
        check(1'b0, "read data wrong in ND memory");
    end
    check(memory[16'h4000 + 300] === 16'hDEAD, "read overran its count");
    // status writeback: w6 RSR1 (dualDensity set), w9 last mem addr low,
    // w11 remaining words = 0
    check((memory[CB + 6] & 16'h8000) !== 0, "writeback RSR1 missing");
    check(memory[CB + 9] === (16'h4000 + 16'd300), "writeback last addr wrong");
    check(memory[CB + 11] === 16'd0, "writeback remaining not 0");

    // 3: WRITE 512 words (two sectors) from 0x5000 to lsect 10
    for (i = 0; i < 512; i = i + 1) memory[16'h5000 + i] = 16'hB000 + i[15:0];
    memory[CB + 0] = 16'h0001;  // func 1 write
    memory[CB + 1] = 16'd10;
    memory[CB + 2] = 16'd0;
    memory[CB + 3] = 16'h5000;
    memory[CB + 4] = 16'h8000;
    memory[CB + 5] = 16'd512;
    run_command(CB, 1'b0);
    for (i = 0; i < 512; i = i + 1) begin
      if (image[10 * WPS + i] !== (16'hB000 + i[15:0]))
        check(1'b0, "written image data wrong");
    end
    check(image[12 * WPS] === (16'h9000 + 12 * WPS), "write overran the image");

    // 4: IDENTIFY (0x38) stub: completes with clean status writeback
    memory[CB + 0] = 16'h0038;
    memory[CB + 5] = 16'd0;
    memory[CB + 6] = 16'hDEAD;
    run_command(CB, 1'b0);
    check((memory[CB + 6] & 16'h8000) !== 0, "identify writeback missing");

    // 5: interrupt + IDENT: run a command with interrupt enabled
    check(bint11_n === 1'b1, "BINT11 asserted before enable");
    memory[CB + 0] = 16'h0000;
    memory[CB + 1] = 16'd1;
    memory[CB + 3] = 16'h6000;
    memory[CB + 5] = 16'd16;
    run_command(CB, 1'b1);
    check(bint11_n === 1'b0, "BINT11_n not asserted on completion");
    ident(16'o000011, ihit, icode);
    check(ihit === 1'b1, "IDENT PL11 no hit");
    check(icode === 16'o000021, "IDENT code not 021");
    check(bint11_n === 1'b1, "BINT11_n not released after IDENT");

    // 6: REAL IMAGE phase - load the ND distribution diskette and read
    //    it back through the controller at start, middle and end
    load_real_image();
    if (img_loaded) begin
    // 6a: first 512 words (lsect 0, two sectors)
    memory[CB + 0] = 16'h0000;
    memory[CB + 1] = 16'd0;
    memory[CB + 2] = 16'd0;
    memory[CB + 3] = 16'h7000;
    memory[CB + 4] = 16'h8000;
    memory[CB + 5] = 16'd512;
    run_command(CB, 1'b0);
    for (i = 0; i < 512; i = i + 1) begin
      if (memory[16'h7000 + i] !== image[i])
        check(1'b0, "real image start readback wrong");
    end
    // 6b: middle of the image (lsect 1200)
    memory[CB + 1] = 16'd1200;
    memory[CB + 3] = 16'h7000;
    memory[CB + 5] = 16'd512;
    run_command(CB, 1'b0);
    for (i = 0; i < 512; i = i + 1) begin
      if (memory[16'h7000 + i] !== image[1200 * WPS + i])
        check(1'b0, "real image middle readback wrong");
    end
    // 6c: the last two sectors of the diskette
    memory[CB + 1] = 16'd2462;
    memory[CB + 3] = 16'h7000;
    memory[CB + 5] = 16'd512;
    run_command(CB, 1'b0);
    for (i = 0; i < 512; i = i + 1) begin
      if (memory[16'h7000 + i] !== image[2462 * WPS + i])
        check(1'b0, "real image end readback wrong");
    end
    end  // img_loaded

    if (errors == 0) $display("TB_RESULT: PASS");
    else begin
      $display("%0d errors", errors);
      $display("TB_RESULT: FAIL");
    end
    $finish;
  end

  initial begin
    #400000000;
    $display("TIMEOUT");
    $display("TB_RESULT: FAIL");
    $finish;
  end

endmodule

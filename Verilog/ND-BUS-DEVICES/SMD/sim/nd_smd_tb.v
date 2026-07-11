/**************************************************************************
** TESTBENCH: ND_SMD - SMD disk controller full DMA stack                **
**                                                                       **
** Same harness family as the floppy-DMA tb: scripted CPU IOX ->        **
** ND_BUS_SLAVE -> ND_SMD -> ND_DMA_MASTER -> BCU + ND-memory model,     **
** plus a linear disk-image model addressed from the block address       **
** registers (tb mapping: word offset = blkaddrII * 2048 + blkaddrI *    **
** 64; the backend owns the geometry, as in nd100x).                     **
**                                                                       **
** Covered: register multiplex bit (CWR) on reads and status b15,        **
** M0 read transfer of 1500 words (crosses the 1K-word buffer chunk),    **
** core address / word counter readback after completion, M1 write of    **
** 800 words, M4 seek -> on-cylinder, interrupt + IDENT code 017.        **
**                                                                       **
** Verdict line: TB_RESULT: PASS / TB_RESULT: FAIL                       **
**                                                                       **
** Last reviewed: 11-JUL-2026                                            **
** Ronny Hansen                                                          **
***************************************************************************/

`timescale 1ns / 1ps

module nd_smd_tb;

  reg sysclk = 0;
  reg sys_rst_n = 0;
  always #10 sysclk = ~sysclk;

  // ---- CPU-side bus ----
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

  // ---- DMA master ----
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

  // ---- SMD controller under test ----
  wire        disk_start, disk_req, disk_wr;
  wire [15:0] disk_blkaddr1, disk_blkaddr2;
  wire [2:0]  disk_unit;
  wire [10:0] disk_wordcount;
  reg         disk_done = 0, disk_err_in = 0;
  reg  [9:0]  dbuf_addr = 0;
  reg  [15:0] dbuf_wdata = 0;
  reg         dbuf_we = 0;
  wire [15:0] dbuf_rdata;

  ND_SMD #(.DELAY_TICKS(16'd10)) u_smd (
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
      .disk_start(disk_start), .disk_req(disk_req), .disk_wr(disk_wr),
      .disk_blkaddr1(disk_blkaddr1), .disk_blkaddr2(disk_blkaddr2),
      .disk_unit(disk_unit), .disk_wordcount(disk_wordcount),
      .disk_done(disk_done), .disk_err_in(disk_err_in),
      .dbuf_addr(dbuf_addr), .dbuf_wdata(dbuf_wdata), .dbuf_we(dbuf_we),
      .dbuf_rdata(dbuf_rdata)
  );

  // ---- BCU + ND memory model ----
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

  // ---- disk model: linear word array, position from block address ----
  // The array doubles as a WINDOW into the 75 MB real SMD image
  // (BIGDISK0-L2-100.IMG, gitignored - see testdata/README.md):
  // window_base is subtracted from the computed position, and the
  // real-image phase loads 1M-word windows with $fseek + $fread.
  localparam WIN_WORDS = 1048576;
  reg [15:0] image[0:WIN_WORDS - 1];
  integer window_base;  // in words
  integer disk_pos;     // advances across chunks within one transfer
  integer ii, w;
  initial begin
    window_base = 0;
    for (ii = 0; ii < 16384; ii = ii + 1)
      image[ii] = 16'h7000 + ii[15:0];
  end

  reg img_avail;
  initial img_avail = 0;

  task load_window(input integer word_base);
    integer fd, n;
    begin
      fd = $fopen("../../testdata/BIGDISK0-L2-100.IMG", "rb");
      if (fd == 0) begin
        img_avail = 0;
      end else begin
        img_avail = 1;
        n = $fseek(fd, word_base * 2, 0);
        n = $fread(image, fd);
        $fclose(fd);
        window_base = word_base;
        $display("[tb] SMD image window @word %0d: %0d bytes, first words %06o %06o",
                 word_base, n, image[0], image[1]);
      end
    end
  endtask

  always @(posedge sysclk) begin
    disk_done   <= 1'b0;
    disk_err_in <= 1'b0;
    dbuf_we     <= 1'b0;
    if (disk_start) begin
      disk_pos = disk_blkaddr2 * 2048 + disk_blkaddr1 * 64 - window_base;
    end
    if (disk_req) begin
      if (!disk_wr) begin
        for (w = 0; w < disk_wordcount; w = w + 1) begin
          @(posedge sysclk);
          dbuf_addr  <= w[9:0];
          dbuf_wdata <= image[disk_pos + w];
          dbuf_we    <= 1'b1;
        end
        @(posedge sysclk);
        dbuf_we   <= 1'b0;
        disk_pos  = disk_pos + disk_wordcount;
        disk_done <= 1'b1;
      end else begin
        for (w = 0; w < disk_wordcount; w = w + 1) begin
          dbuf_addr <= w[9:0];
          @(posedge sysclk);
          @(posedge sysclk);
          image[disk_pos + w] = dbuf_rdata;
        end
        disk_pos  = disk_pos + disk_wordcount;
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

  // ---- IOX tasks ----

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

  task wait_ready;
    integer guard;
    reg [15:0] st;
    begin
      guard = 0;
      st = 0;
      while (!(st & 16'h0008) && guard < 30000) begin
        iox_read(16'o001544, st);
        guard = guard + 1;
      end
      check((st & 16'h0008) !== 0, "controller never became ready");
    end
  endtask

  reg [15:0] rdata;
  reg        ihit;
  reg [15:0] icode;
  integer    i, dpos, nzcount;

  initial begin
`ifdef DUMPFILE
    $dumpfile("nd_smd_tb.vcd");
    $dumpvars(0, nd_smd_tb);
`endif
    for (i = 0; i < 65536; i = i + 1) memory[i] = 16'hDEAD;

    repeat (5) @(negedge sysclk);
    sys_rst_n = 1;
    repeat (5) @(negedge sysclk);

    // 1: reset status: ready, CWR=0 -> status b15 = 0
    iox_read(16'o001544, rdata);
    check((rdata & 16'h0008) !== 0, "not ready at reset");
    check((rdata & 16'h8000) === 0, "CWR bit set at reset");

    // 1b: BOOT MODE (the '1540&' handshake): write 004005 to +3, poll
    //     +2 for ready; block 0 (1024 words) must land at ND memory 0
    for (i = 0; i < 1100; i = i + 1) memory[i] = 16'hDEAD;
    iox_write(16'o001543, 16'o004005);
    begin : bootwait
      integer guard;
      reg [15:0] st;
      guard = 0; st = 0;
      while (!(st & 16'h0008) && guard < 30000) begin
        iox_read(16'o001542, st);
        guard = guard + 1;
      end
      check((st & 16'h0008) !== 0, "boot autoload never ready on +2");
      check((st & 16'h0010) === 0, "boot autoload flagged error");
    end
    for (i = 0; i < 1024; i = i + 1)
      if (memory[i] !== image[i])
        check(1'b0, "boot block wrong in ND memory");
    check(memory[1024] === 16'hDEAD, "boot autoload overran 1024 words");

    // 2: M0 READ 1500 words (crosses the 1K buffer chunk) from
    //    blkaddrII=1, blkaddrI=2 (tb map: word 2176) to core 0x4000
    iox_write(16'o001541, 16'h4000);   // core address
    iox_write(16'o001543, 16'd2);      // block address I (CWR=0)
    iox_write(16'o001545, 16'h8000);   // control: CWR=1 (no GO)
    iox_write(16'o001543, 16'd1);      // block address II (CWR=1)
    iox_write(16'o001545, 16'h0000);   // control: CWR=0
    iox_write(16'o001547, 16'd1500);   // word count
    iox_write(16'o001545, 16'h0004);   // control: ACTIVE, op M0
    wait_ready();
    dpos = 1 * 2048 + 2 * 64;
    for (i = 0; i < 1500; i = i + 1) begin
      if (memory[16'h4000 + i] !== (16'h7000 + dpos[15:0] + i[15:0]))
        check(1'b0, "M0 read data wrong in ND memory");
    end
    check(memory[16'h4000 + 1500] === 16'hDEAD, "M0 overran its count");
    // core address readback (CWR=0) and word counter (CWR=1)
    iox_read(16'o001540, rdata);
    check(rdata === (16'h4000 + 16'd1500), "core address readback wrong");
    iox_write(16'o001545, 16'h8000);   // CWR=1
    iox_read(16'o001540, rdata);
    check(rdata === 16'd0, "word counter not 0 after transfer");
    // note: +4 with CWR=1 returns the ECC pattern, not the status, so
    // the b15 mirror is not observable that way (same as nd100x)
    iox_write(16'o001545, 16'h0000);   // CWR back to 0

    // 3: M1 WRITE 800 words from core 0x5000 to blkaddrII=3, blkaddrI=0
    for (i = 0; i < 800; i = i + 1) memory[16'h5000 + i] = 16'hC000 + i[15:0];
    iox_write(16'o001541, 16'h5000);
    iox_write(16'o001543, 16'd0);      // block address I
    iox_write(16'o001545, 16'h8000);
    iox_write(16'o001543, 16'd3);      // block address II
    iox_write(16'o001545, 16'h0000);
    iox_write(16'o001547, 16'd800);
    iox_write(16'o001545, 16'h0804);   // ACTIVE (b2), op M1 (b11)
    wait_ready();
    dpos = 3 * 2048;
    for (i = 0; i < 800; i = i + 1) begin
      if (image[dpos + i] !== (16'hC000 + i[15:0]))
        check(1'b0, "M1 written image data wrong");
    end
    check(image[dpos + 800] === (16'h7000 + dpos[15:0] + 16'd800),
          "M1 overran the image");

    // 4: M4 seek -> on-cylinder in status b14 and seek condition
    iox_write(16'o001545, 16'h2004);   // ACTIVE, op M4 (b13=1? M4 = 0100)
    wait_ready();
    iox_read(16'o001544, rdata);
    check((rdata & 16'h4000) !== 0, "onCylinder not set after seek");
    iox_read(16'o001542, rdata);
    check((rdata & 16'h4000) !== 0, "seek condition missing on-cylinder");

    // 5: interrupt + IDENT: M0 read with interrupt enabled
    check(bint11_n === 1'b1, "BINT11 asserted before enable");
    iox_write(16'o001541, 16'h6000);
    iox_write(16'o001547, 16'd16);
    iox_write(16'o001545, 16'h0005);   // ACTIVE, M0, int enable (b0)
    wait_ready();
    check(bint11_n === 1'b0, "BINT11_n not asserted on completion");
    ident(16'o000011, ihit, icode);
    check(ihit === 1'b1, "IDENT PL11 no hit");
    check(icode === 16'o000017, "IDENT code not 017");
    check(bint11_n === 1'b1, "BINT11_n not released after IDENT");

    // 6: REAL IMAGE phase - three windows of the 75 MB SMD disk 0
    //    (start, middle, exact tail), each read through the controller
    //    and word-compared against the file content
    load_window(0);
    if (!img_avail) begin
      $display("[tb] SKIP real-image phase: testdata/BIGDISK0-L2-100.IMG not present");
    end else begin
      // start: blkaddrII=0, blkaddrI=0 -> word 0
      iox_write(16'o001541, 16'h7000);
      iox_write(16'o001543, 16'd0);
      iox_write(16'o001545, 16'h8000);
      iox_write(16'o001543, 16'd0);
      iox_write(16'o001545, 16'h0000);
      iox_write(16'o001547, 16'd1024);
      iox_write(16'o001545, 16'h0004);
      wait_ready();
      for (i = 0; i < 1024; i = i + 1)
        if (memory[16'h7000 + i] !== image[i])
          check(1'b0, "SMD image start readback wrong");

      nzcount = 0;
      for (i = 0; i < 1024; i = i + 1) if (memory[16'h7000 + i] !== 16'd0) nzcount = nzcount + 1;
      check(nzcount > 0, "SMD start window compared only zeros (vacuous)");

      // middle: data-rich region, window at word 5120*2048 (byte 20971520)
      load_window(5120 * 2048);
      iox_write(16'o001541, 16'h7000);
      iox_write(16'o001543, 16'd0);       // blkaddr I
      iox_write(16'o001545, 16'h8000);
      iox_write(16'o001543, 16'd5120);    // blkaddr II
      iox_write(16'o001545, 16'h0000);
      iox_write(16'o001547, 16'd1024);
      iox_write(16'o001545, 16'h0004);
      wait_ready();
      for (i = 0; i < 1024; i = i + 1)
        if (memory[16'h7000 + i] !== image[i])
          check(1'b0, "SMD image middle readback wrong");
      nzcount = 0;
      for (i = 0; i < 1024; i = i + 1) if (memory[16'h7000 + i] !== 16'd0) nzcount = nzcount + 1;
      check(nzcount > 0, "SMD middle window compared only zeros (vacuous)");

      // far region: the deepest data-bearing cylinder (blkaddrII 18472)
      load_window(18472 * 2048);
      iox_write(16'o001541, 16'h7000);
      iox_write(16'o001543, 16'd0);
      iox_write(16'o001545, 16'h8000);
      iox_write(16'o001543, 16'd18472);
      iox_write(16'o001545, 16'h0000);
      iox_write(16'o001547, 16'd1024);
      iox_write(16'o001545, 16'h0004);
      wait_ready();
      for (i = 0; i < 1024; i = i + 1)
        if (memory[16'h7000 + i] !== image[i])
          check(1'b0, "SMD image far readback wrong");
      nzcount = 0;
      for (i = 0; i < 1024; i = i + 1) if (memory[16'h7000 + i] !== 16'd0) nzcount = nzcount + 1;
      check(nzcount > 0, "SMD far window compared only zeros (vacuous)");
    end

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

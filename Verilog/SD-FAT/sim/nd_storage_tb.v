/****************************************************************************
** Full-stack mount testbench for nd_storage (iverilog)                    **
**                                                                         **
** nd_storage (reader + writer + engine + mount FSM + SD pin mux) against **
** the behavioral SD card model serving a real FAT16 image (built by      **
** make_storage_image.sh: TAPE.BPUN 3001 B, FLOPPY1.IMG 4096 B,           **
** FLOPPY2.IMG deliberately absent) and the behavioral mem-port model,    **
** at skewed clocks (clk_cpu ~23.04 MHz, clk_stor ~27.03 MHz).            **
** SIMULATE=1 shortens the card init; image and payloads are the SMALLEST **
** that still exercise every case (this full stack costs real iverilog   **
** wall time per simulated ms - the big-image multi-client soak belongs  **
** to the step-6 Verilator gate), and the second (oversize) instance is  **
** CLOCK-GATED until its own phase so it costs nothing before that.      **
** Checks (design doc section 6, step 4; spec sections 6/7):              **
**                                                                         **
**   (a) open client 0 (TAPE.BPUN): open_ok, size_bytes=3001, n_blocks=2 **
**       (ceil), SDRAM slot 0 byte-exact vs the image file including the **
**       zero-padded 32-bit tail word                                     **
**   (b) open client 1 (FLOPPY1.IMG): open_ok, size 4096, n_blocks=2,    **
**       SDRAM slot 1 (base block 32) byte-exact                          **
**   (c) open client 2 (FLOPPY2.IMG missing): done+err, open_err level,  **
**       no open_ok; sd_status degrades to ERROR                          **
**   (d) open an SMD client (3): open_err immediately, ZERO SD clock     **
**       edges (no reader release, no card traffic), sd_status untouched **
**   (e) block READ on client 1 (block 1) through the client port         **
**       returns the exact file bytes (proves the whole engine read      **
**       stack against mount-loaded geometry); out-of-range block 2 ->   **
**       done+err                                                         **
**   (f) reopen client 0: open_ok drops while the mount rebuilds, comes  **
**       back up, slot content still byte-exact (the rewind path)         **
**   (g) oversize: a second nd_storage with SLOT0_SIZE_BLK=1 (2048 B <   **
**       3001 B) answers open_err with NO partial open_ok and ZERO mem   **
**       writes (the mount parks before the first payload byte)          **
**   plus: card model health on both cards (CMD CRC7 = 0, no writes at   **
**       all via LEGAL_MIN_SECTOR = whole card), preload FIFO overflow   **
**       sticky = 0, engine watchdog never fired                          **
**                                                                         **
** Request pulses are NONBLOCKING one-cycle pulses; every wait polls      **
** busy-RISE before polling it low; absolute watchdog 150 ms.             **
**                                                                         **
** Verdict: TB_RESULT: PASS / TB_RESULT: FAIL <reason>                     **
**                                                                         **
** Last reviewed: 11-JUL-2026                                              **
** Ronny Hansen                                                            **
*****************************************************************************/
`timescale 1ns / 1ps

module nd_storage_tb;

  localparam STOR_HALF = 18.5;  // ~27.03 MHz
  localparam CPU_HALF  = 21.7;  // ~23.04 MHz
  localparam N         = 7;

  localparam integer TAPE_BYTES = 3001;
  localparam integer FLP_BYTES  = 4096;
  localparam integer SLOT0_BASE = 0;    // blocks (dut defaults)
  localparam integer SLOT1_BASE = 32;
  localparam IMG_BYTES = 4 * 1024 * 1024;
  localparam IMG_SECTORS = IMG_BYTES / 512;

  reg clk_stor = 0;
  always #STOR_HALF clk_stor = ~clk_stor;
  reg clk_cpu = 0;
  always #CPU_HALF clk_cpu = ~clk_cpu;

  reg rst_n = 0;

  // ------------------------------------------------------------- patterns
  // MUST match make_storage_image.sh (see its header): the cross-block
  // step term keeps a 2048-byte shift from aliasing mod 256
  function [7:0] pat_tape(input integer k);
    pat_tape = ((k % 256) + 37 * ((k / 256) % 256) + 129) % 256;
  endfunction

  function [7:0] pat_flp(input integer k);
    pat_flp = ((k % 256) + 29 * ((k / 256) % 256) + 7) % 256;
  endfunction

  // ------------------------------------------------------------- DUT 1
  wire        sd1_clk, sd1_cmd_o, sd1_cmd_oe, sd1_dat0_o, sd1_dat0_oe;
  // SD lines resolved by MUX, no tristates (14-JUL-2026): host output-enable
  // wins, then the card, then the bus pullup (1) - same rule as
  // nd_storage_vtop.v:92. Lets the same card model run under iverilog AND
  // Verilator.
  wire        c1_cmd_o, c1_cmd_oe, c1_dat0_o, c1_dat0_oe;
  wire        sd1_cmd  = sd1_cmd_oe  ? sd1_cmd_o  : (c1_cmd_oe  ? c1_cmd_o  : 1'b1);
  wire        sd1_dat0 = sd1_dat0_oe ? sd1_dat0_o : (c1_dat0_oe ? c1_dat0_o : 1'b1);

  wire        mem_start_w, mem_we_w, mem_busy_w, mem_done_w;
  wire [19:0] mem_addr_w;
  wire [31:0] mem_wdata_w, mem_rdata_w;

  reg  [N-1:0]    t_open_req = 0;
  reg  [N-1:0]    t_req = 0;
  reg  [N-1:0]    t_wr = 0;
  reg  [N*16-1:0] t_block = 0;
  wire [N-1:0]    open_ok_w, open_err_w, busy_w, done_w, err_w, buf_we_w;
  wire [N*32-1:0] size_bytes_w;
  wire [N*10-1:0] buf_addr_w;
  wire [N*16-1:0] buf_wdata_w;
  reg  [15:0]     rd1 = 0;
  wire [N*16-1:0] buf_rdata_w = {80'd0, rd1, 16'd0};

  wire [1:0] sd_status_w, card_type_w, fs_type_w;

  nd_storage #(
      .N_CLIENTS (N),
      .RD_CLK_DIV(3'd1),          // 27 MHz class clock in the tb
      .WR_CLKDIV (8'd2),          // never used here (no writes)
      .WD_MAX    (32'd5_000_000),
      .SIMULATE  (1)
  ) dut (
      .clk_stor  (clk_stor),
      .rst_stor_n(rst_n),
      .clk_cpu   (clk_cpu),
      .rst_cpu_n (rst_n),
      .sd_clk_o  (sd1_clk),
      .sd_cmd_i  (sd1_cmd),
      .sd_cmd_o  (sd1_cmd_o),
      .sd_cmd_oe (sd1_cmd_oe),
      .sd_dat0_i (sd1_dat0),
      .sd_dat0_o (sd1_dat0_o),
      .sd_dat0_oe(sd1_dat0_oe),
      .mem_start (mem_start_w),
      .mem_we    (mem_we_w),
      .mem_addr  (mem_addr_w),
      .mem_wdata (mem_wdata_w),
      .mem_rdata (mem_rdata_w),
      .mem_busy  (mem_busy_w),
      .mem_done  (mem_done_w),
      .open_req  (t_open_req),
      .open_ok   (open_ok_w),
      .open_err  (open_err_w),
      .size_bytes(size_bytes_w),
      .req       (t_req),
      .wr        (t_wr),
      .block     (t_block),
      .busy      (busy_w),
      .done      (done_w),
      .err       (err_w),
      .buf_addr  (buf_addr_w),
      .buf_wdata (buf_wdata_w),
      .buf_we    (buf_we_w),
      .buf_rdata (buf_rdata_w),
      .sd_status (sd_status_w),
      .card_type (card_type_w),
      .fs_type   (fs_type_w)
  );

  nds_mem_model #(
      .MEM_WORDS(32768)
  ) u_mem (
      .clk  (clk_stor),
      .rst_n(rst_n),
      .start(mem_start_w),
      .we   (mem_we_w),
      .addr (mem_addr_w),
      .wdata(mem_wdata_w),
      .rdata(mem_rdata_w),
      .busy (mem_busy_w),
      .done (mem_done_w)
  );

  // any card write at all is illegal in this tb (mount only reads)
  sd_card_model #(
      .IMAGE           ("nds_storage.img"),
      .MAX_BYTES       (IMG_BYTES),
      .LEGAL_MIN_SECTOR(IMG_SECTORS)
  ) card (
      .sd_clk   (sd1_clk),
      .sd_cmd_i (sd1_cmd),  .sd_cmd_o (c1_cmd_o),  .sd_cmd_oe (c1_cmd_oe),
      .sd_dat0_i(sd1_dat0), .sd_dat0_o(c1_dat0_o), .sd_dat0_oe(c1_dat0_oe),
      .sd_dat1_i(1'b1), .sd_dat1_o(), .sd_dat1_oe(),
      .sd_dat2_i(1'b1), .sd_dat2_o(), .sd_dat2_oe(),
      .sd_dat3_i(1'b1), .sd_dat3_o(), .sd_dat3_oe()
  );

  // client 1 buffer: REGISTERED BRAM (the sterner timing case)
  reg [15:0] cbuf1[0:1023];
  always @(posedge clk_cpu) begin
    if (buf_we_w[1]) cbuf1[buf_addr_w[19:10]] <= buf_wdata_w[31:16];
    rd1 <= cbuf1[buf_addr_w[19:10]];
  end

  // ------------------------------------------------------------- DUT 2
  // oversize case: identical card image, but SLOT0 shrunk to ONE block
  // (2048 B) so TAPE.BPUN (3001 B) must be refused with zero mem traffic.
  // CLOCK-GATED until phase (g): a second full instance would otherwise
  // double the event cost of the whole run for nothing.
  reg dut2_en  = 0;
  reg rst2_n   = 0;
  wire clk_stor2 = clk_stor & dut2_en;
  wire clk_cpu2  = clk_cpu & dut2_en;

  wire        sd2_clk, sd2_cmd_o, sd2_cmd_oe, sd2_dat0_o, sd2_dat0_oe;
  wire        c2_cmd_o, c2_cmd_oe, c2_dat0_o, c2_dat0_oe;
  wire        sd2_cmd  = sd2_cmd_oe  ? sd2_cmd_o  : (c2_cmd_oe  ? c2_cmd_o  : 1'b1);
  wire        sd2_dat0 = sd2_dat0_oe ? sd2_dat0_o : (c2_dat0_oe ? c2_dat0_o : 1'b1);

  wire        m2_start_w, m2_we_w, m2_busy_w, m2_done_w;
  wire [19:0] m2_addr_w;
  wire [31:0] m2_wdata_w, m2_rdata_w;

  reg  [N-1:0] t2_open_req = 0;
  wire [N-1:0] ov_open_ok_w, ov_open_err_w, ov_busy_w, ov_done_w, ov_err_w;

  nd_storage #(
      .N_CLIENTS     (N),
      .RD_CLK_DIV    (3'd1),
      .WR_CLKDIV     (8'd2),
      .WD_MAX        (32'd5_000_000),
      .SIMULATE      (1),
      .SLOT0_SIZE_BLK(32'd1)   // deliberately tiny: forces the oversize fail
  ) dut_ovf (
      .clk_stor  (clk_stor2),
      .rst_stor_n(rst2_n),
      .clk_cpu   (clk_cpu2),
      .rst_cpu_n (rst2_n),
      .sd_clk_o  (sd2_clk),
      .sd_cmd_i  (sd2_cmd),
      .sd_cmd_o  (sd2_cmd_o),
      .sd_cmd_oe (sd2_cmd_oe),
      .sd_dat0_i (sd2_dat0),
      .sd_dat0_o (sd2_dat0_o),
      .sd_dat0_oe(sd2_dat0_oe),
      .mem_start (m2_start_w),
      .mem_we    (m2_we_w),
      .mem_addr  (m2_addr_w),
      .mem_wdata (m2_wdata_w),
      .mem_rdata (m2_rdata_w),
      .mem_busy  (m2_busy_w),
      .mem_done  (m2_done_w),
      .open_req  (t2_open_req),
      .open_ok   (ov_open_ok_w),
      .open_err  (ov_open_err_w),
      .size_bytes(),
      .req       ({N{1'b0}}),
      .wr        ({N{1'b0}}),
      .block     ({N{16'd0}}),
      .busy      (ov_busy_w),
      .done      (ov_done_w),
      .err       (ov_err_w),
      .buf_addr  (),
      .buf_wdata (),
      .buf_we    (),
      .buf_rdata ({N{16'd0}}),
      .sd_status (),
      .card_type (),
      .fs_type   ()
  );

  nds_mem_model #(
      .MEM_WORDS(64)
  ) u_mem2 (
      .clk  (clk_stor2),
      .rst_n(rst2_n),
      .start(m2_start_w),
      .we   (m2_we_w),
      .addr (m2_addr_w),
      .wdata(m2_wdata_w),
      .rdata(m2_rdata_w),
      .busy (m2_busy_w),
      .done (m2_done_w)
  );

  sd_card_model #(
      .IMAGE           ("nds_storage.img"),
      .MAX_BYTES       (IMG_BYTES),
      .LEGAL_MIN_SECTOR(IMG_SECTORS)
  ) card2 (
      .sd_clk   (sd2_clk),
      .sd_cmd_i (sd2_cmd),  .sd_cmd_o (c2_cmd_o),  .sd_cmd_oe (c2_cmd_oe),
      .sd_dat0_i(sd2_dat0), .sd_dat0_o(c2_dat0_o), .sd_dat0_oe(c2_dat0_oe),
      .sd_dat1_i(1'b1), .sd_dat1_o(), .sd_dat1_oe(),
      .sd_dat2_i(1'b1), .sd_dat2_o(), .sd_dat2_oe(),
      .sd_dat3_i(1'b1), .sd_dat3_o(), .sd_dat3_oe()
  );

  // ------------------------------------------------------------- monitors
  integer errors = 0;

  // dut2 mem traffic must stay ZERO (oversize parks before any payload)
  integer m2_starts = 0;
  always @(posedge clk_stor) if (m2_start_w) m2_starts = m2_starts + 1;

  // SD clock silence window for the SMD case
  reg     smd_watch = 0;
  integer smd_sdclk_edges = 0;
  always @(posedge sd1_clk) if (smd_watch) smd_sdclk_edges = smd_sdclk_edges + 1;

  // ------------------------------------------------------------- helpers
  task wait_op(input [2:0] c, input [31:0] max_cpu_cycles, input [127:0] what);
    integer guard;
    begin
      // busy must RISE first - polling low immediately would race the FE
      guard = 0;
      while (!busy_w[c] && guard < 1000) begin
        @(posedge clk_cpu);
        guard = guard + 1;
      end
      if (!busy_w[c]) begin
        $display("TB_RESULT: FAIL %0s: client %0d never went busy", what, c);
        $finish;
      end
      guard = 0;
      while (busy_w[c] && guard < max_cpu_cycles) begin
        @(posedge clk_cpu);
        guard = guard + 1;
      end
      if (busy_w[c]) begin
        $display("TB_RESULT: FAIL %0s: client %0d op hung", what, c);
        $finish;
      end
      repeat (20) @(posedge clk_cpu);  // let levels (open_ok/err/size) settle
    end
  endtask

  task do_open(input [2:0] c, input [127:0] what);
    begin
      @(posedge clk_cpu);
      t_open_req[c] <= 1'b1;
      @(posedge clk_cpu);
      t_open_req[c] <= 1'b0;
      wait_op(c, 32'd3_000_000, what);
    end
  endtask

  task do_read(input [2:0] c, input [15:0] blk, input [127:0] what);
    begin
      @(posedge clk_cpu);
      t_req[c]           <= 1'b1;
      t_wr[c]            <= 1'b0;
      t_block[16*c+:16]  <= blk;
      @(posedge clk_cpu);
      t_req[c] <= 1'b0;
      wait_op(c, 32'd1_000_000, what);
    end
  endtask

  // SDRAM slot content vs the pattern file (fbytes bytes from base_blk,
  // tail 32-bit word zero-padded)
  task check_slot(input integer base_blk, input integer fbytes, input integer is_tape,
                  input [127:0] what);
    integer m, nw, k, b;
    reg [31:0] gotw, expw;
    begin
      nw = (fbytes + 3) / 4;
      for (m = 0; m < nw; m = m + 1) begin
        expw = 32'd0;
        for (b = 0; b < 4; b = b + 1) begin
          k = 4 * m + b;
          if (k < fbytes)
            expw[8*(3-b)+:8] = is_tape ? pat_tape(k) : pat_flp(k);
        end
        gotw = u_mem.mem[base_blk*512+m];
        if (gotw !== expw) begin
          if (errors < 10)
            $display("FAIL: %0s SDRAM word %0d: got %08x want %08x", what, m, gotw, expw);
          errors = errors + 1;
        end
      end
    end
  endtask

  // ------------------------------------------------------------- test
  integer w, guard;
  reg [15:0] expw16;
  initial begin
    repeat (10) @(posedge clk_stor);
    rst_n = 1;
    repeat (50) @(posedge clk_cpu);

    if (sd_status_w !== 2'd0) begin
      $display("FAIL: sd_status not NOTCHK after reset (%0d)", sd_status_w);
      errors = errors + 1;
    end

    // ---- (a) open client 0: TAPE.BPUN --------------------------------
    do_open(3'd0, "open tape");
    if (err_w[0] !== 1'b0 || open_ok_w[0] !== 1'b1 || open_err_w[0] !== 1'b0) begin
      $display("FAIL: tape open flags (err=%b ok=%b oerr=%b)",
               err_w[0], open_ok_w[0], open_err_w[0]);
      errors = errors + 1;
    end
    if (size_bytes_w[31:0] !== TAPE_BYTES[31:0]) begin
      $display("FAIL: tape size_bytes %0d (want %0d)", size_bytes_w[31:0], TAPE_BYTES);
      errors = errors + 1;
    end
    if (dut.u_mount.r_nblk[0] !== 16'd2) begin
      $display("FAIL: tape n_blocks %0d (want 2 = ceil(3001/2048))", dut.u_mount.r_nblk[0]);
      errors = errors + 1;
    end
    if (sd_status_w !== 2'd3) begin
      $display("FAIL: sd_status not OK after tape open (%0d)", sd_status_w);
      errors = errors + 1;
    end
    check_slot(SLOT0_BASE, TAPE_BYTES, 1, "tape");

    // ---- (b) open client 1: FLOPPY1.IMG -------------------------------
    do_open(3'd1, "open floppy1");
    if (err_w[1] !== 1'b0 || open_ok_w[1] !== 1'b1 || open_err_w[1] !== 1'b0) begin
      $display("FAIL: floppy1 open flags (err=%b ok=%b oerr=%b)",
               err_w[1], open_ok_w[1], open_err_w[1]);
      errors = errors + 1;
    end
    if (size_bytes_w[63:32] !== FLP_BYTES[31:0]) begin
      $display("FAIL: floppy1 size_bytes %0d (want %0d)", size_bytes_w[63:32], FLP_BYTES);
      errors = errors + 1;
    end
    if (dut.u_mount.r_nblk[1] !== 16'd2) begin
      $display("FAIL: floppy1 n_blocks %0d (want 2)", dut.u_mount.r_nblk[1]);
      errors = errors + 1;
    end
    check_slot(SLOT1_BASE, FLP_BYTES, 0, "floppy1");

    // ---- (c) open client 2: FLOPPY2.IMG is MISSING ---------------------
    do_open(3'd2, "open missing");
    if (err_w[2] !== 1'b1 || open_err_w[2] !== 1'b1 || open_ok_w[2] !== 1'b0) begin
      $display("FAIL: missing-file open flags (err=%b oerr=%b ok=%b)",
               err_w[2], open_err_w[2], open_ok_w[2]);
      errors = errors + 1;
    end
    if (sd_status_w !== 2'd2) begin
      $display("FAIL: sd_status not ERROR after missing file (%0d)", sd_status_w);
      errors = errors + 1;
    end

    // ---- (d) SMD client 3: v1 answers open_err with zero card traffic --
    smd_sdclk_edges = 0;
    smd_watch = 1;
    do_open(3'd3, "open smd0");
    smd_watch = 0;
    if (err_w[3] !== 1'b1 || open_err_w[3] !== 1'b1 || open_ok_w[3] !== 1'b0) begin
      $display("FAIL: SMD open flags (err=%b oerr=%b ok=%b)",
               err_w[3], open_err_w[3], open_ok_w[3]);
      errors = errors + 1;
    end
    if (smd_sdclk_edges !== 0) begin
      $display("FAIL: SMD open produced %0d SD clock edges (want 0)", smd_sdclk_edges);
      errors = errors + 1;
    end
    if (sd_status_w !== 2'd2) begin
      $display("FAIL: SMD mask-fail changed sd_status (%0d, want still 2)", sd_status_w);
      errors = errors + 1;
    end

    // ---- (e) block READ on client 1 through the client port ------------
    do_read(3'd1, 16'd1, "read flp blk1");
    if (err_w[1] !== 1'b0) begin
      $display("FAIL: floppy1 block 1 read returned err");
      errors = errors + 1;
    end
    for (w = 0; w < 1024; w = w + 1) begin
      expw16 = {pat_flp(2048 + 2 * w), pat_flp(2048 + 2 * w + 1)};
      if (cbuf1[w] !== expw16) begin
        if (errors < 10)
          $display("FAIL: flp blk1 word %0d: got %04x want %04x", w, cbuf1[w], expw16);
        errors = errors + 1;
      end
    end
    // out-of-range block (n_blocks = 2) -> done+err, no traffic needed
    do_read(3'd1, 16'd2, "read flp blk2");
    if (err_w[1] !== 1'b1) begin
      $display("FAIL: out-of-range block 2 read did not return err");
      errors = errors + 1;
    end

    // ---- (f) reopen client 0: the rewind path --------------------------
    @(posedge clk_cpu);
    t_open_req[0] <= 1'b1;
    @(posedge clk_cpu);
    t_open_req[0] <= 1'b0;
    // open_ok[0] must DROP while the slot rebuilds
    guard = 0;
    while (open_ok_w[0] && guard < 100000) begin
      @(posedge clk_cpu);
      guard = guard + 1;
    end
    if (open_ok_w[0]) begin
      $display("FAIL: reopen did not clear open_ok[0] during the rebuild");
      errors = errors + 1;
    end
    wait_op(3'd0, 32'd3_000_000, "reopen tape");
    if (err_w[0] !== 1'b0 || open_ok_w[0] !== 1'b1) begin
      $display("FAIL: reopen flags (err=%b ok=%b)", err_w[0], open_ok_w[0]);
      errors = errors + 1;
    end
    if (size_bytes_w[31:0] !== TAPE_BYTES[31:0]) begin
      $display("FAIL: reopen size_bytes %0d", size_bytes_w[31:0]);
      errors = errors + 1;
    end
    if (sd_status_w !== 2'd3) begin
      $display("FAIL: sd_status not OK after reopen (%0d)", sd_status_w);
      errors = errors + 1;
    end
    check_slot(SLOT0_BASE, TAPE_BYTES, 1, "tape-reopen");

    // ---- (g) oversize file vs tiny slot (second instance) --------------
    // wake the clock-gated instance and give it a clean reset window
    @(negedge clk_stor);
    dut2_en = 1;
    repeat (30) @(posedge clk_stor);
    rst2_n = 1;
    repeat (30) @(posedge clk_cpu);
    @(posedge clk_cpu);
    t2_open_req[0] <= 1'b1;
    @(posedge clk_cpu);
    t2_open_req[0] <= 1'b0;
    guard = 0;
    while (!ov_busy_w[0] && guard < 1000) begin
      @(posedge clk_cpu);
      guard = guard + 1;
    end
    if (!ov_busy_w[0]) begin
      $display("TB_RESULT: FAIL oversize open never went busy");
      $finish;
    end
    guard = 0;
    while (ov_busy_w[0] && guard < 3_000_000) begin
      @(posedge clk_cpu);
      guard = guard + 1;
    end
    if (ov_busy_w[0]) begin
      $display("TB_RESULT: FAIL oversize open hung");
      $finish;
    end
    repeat (20) @(posedge clk_cpu);
    if (ov_err_w[0] !== 1'b1 || ov_open_err_w[0] !== 1'b1 || ov_open_ok_w[0] !== 1'b0) begin
      $display("FAIL: oversize open flags (err=%b oerr=%b ok=%b)",
               ov_err_w[0], ov_open_err_w[0], ov_open_ok_w[0]);
      errors = errors + 1;
    end
    if (m2_starts !== 0) begin
      $display("FAIL: oversize open touched the mem port (%0d pulses)", m2_starts);
      errors = errors + 1;
    end

    // ---- health ---------------------------------------------------------
    if (card.crc_errors !== 0 || card2.crc_errors !== 0) begin
      $display("FAIL: CMD CRC7 errors (%0d/%0d)", card.crc_errors, card2.crc_errors);
      errors = errors + 1;
    end
    if (card.illegal_writes !== 0 || card2.illegal_writes !== 0) begin
      $display("FAIL: card writes in a read-only tb (%0d/%0d)",
               card.illegal_writes, card2.illegal_writes);
      errors = errors + 1;
    end
    if (dut.u_mount.load_fifo_ovf !== 1'b0) begin
      $display("FAIL: mount preload FIFO overflowed");
      errors = errors + 1;
    end
    if (dut.u_engine.eng_wd_err !== 1'b0) begin
      $display("FAIL: engine watchdog fired");
      errors = errors + 1;
    end
    if (card_type_w === 2'd0 || fs_type_w !== 2'd2) begin
      $display("FAIL: latched card_type/fs_type (%0d/%0d, want nonzero/FAT16)",
               card_type_w, fs_type_w);
      errors = errors + 1;
    end

    if (errors == 0) $display("TB_RESULT: PASS");
    else $display("TB_RESULT: FAIL %0d errors", errors);
    $finish;
  end

  initial begin
    #150_000_000;  // 150 ms absolute watchdog
    $display("TB_RESULT: FAIL absolute watchdog");
    $finish;
  end

endmodule

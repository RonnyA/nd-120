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
  // 8, matching nd_storage's client count since SMD3.IMG was replaced by
  // WD0/WD1.IMG. This is deliberately the FULL count: the mount FSM's range
  // guard truncates if written as N_CLIENTS[2:0], and at 8 that becomes
  // 3'b000 so NO client mounts at all. Running this bench at 7 could never
  // catch that - it is the one configuration where the bug exists.
  localparam N         = 8;

  localparam integer TAPE_BYTES = 3001;
  localparam integer FLP_BYTES  = 4096;
  localparam integer WD_BYTES   = 16384;   // WD0.IMG, client 6 (cached)
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

  // FRAG.IMG payload pattern (make_storage_image.sh nds_frag.bin)
  function [7:0] pat_frag(input integer k);
    pat_frag = ((k % 256) + 53 * ((k / 256) % 256) + 201) % 256;
  endfunction

  function [7:0] pat_flp(input integer k);
    pat_flp = ((k % 256) + 29 * ((k / 256) % 256) + 7) % 256;
  endfunction

  // WD0.IMG payload pattern (make_storage_image.sh nds_wd0.bin)
  function [7:0] pat_wd(input integer k);
    pat_wd = ((k % 256) + 61 * ((k / 256) % 256) + 83) % 256;
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

  // DAT1-3. Only the 4-bit bus uses them for data; in 1-bit mode both sides
  // release and the board's external pull-ups hold them high, which is the
  // 1'b1 default below. Wiring them for real is what lets this tb exercise
  // the CMD55+ACMD6 width switch - the path that needs the card's published
  // RCA and that no nd_storage harness covered before.
  wire        sd1_dat1_o, sd1_dat1_oe, c1_dat1_o, c1_dat1_oe;
  wire        sd1_dat2_o, sd1_dat2_oe, c1_dat2_o, c1_dat2_oe;
  wire        sd1_dat3_o, sd1_dat3_oe, c1_dat3_o, c1_dat3_oe;
  wire        sd1_dat1 = sd1_dat1_oe ? sd1_dat1_o : (c1_dat1_oe ? c1_dat1_o : 1'b1);
  wire        sd1_dat2 = sd1_dat2_oe ? sd1_dat2_o : (c1_dat2_oe ? c1_dat2_o : 1'b1);
  wire        sd1_dat3 = sd1_dat3_oe ? sd1_dat3_o : (c1_dat3_oe ? c1_dat3_o : 1'b1);

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
  wire [N*16-1:0] buf_rdata_w = {96'd0, rd1, 16'd0};

  wire [1:0] sd_status_w, card_type_w, fs_type_w;

  nd_storage #(
      .N_CLIENTS (N),
      .FILE4_NAME("FRAG.IMG"), .FILE4_LEN(8'd8),
      .RD_CLK_DIV(3'd1),          // 27 MHz class clock in the tb
      .WR_CLKDIV (8'd2),          // never used here (no writes)
      .WD_MAX    (32'd5_000_000),
`ifdef NDS_TB_4BIT
      .USE_4BIT  (1),
`endif
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
      .sd_dat1_i (sd1_dat1),
      .sd_dat1_o (sd1_dat1_o),
      .sd_dat1_oe(sd1_dat1_oe),
      .sd_dat2_i (sd1_dat2),
      .sd_dat2_o (sd1_dat2_o),
      .sd_dat2_oe(sd1_dat2_oe),
      .sd_dat3_i (sd1_dat3),
      .sd_dat3_o (sd1_dat3_o),
      .sd_dat3_oe(sd1_dat3_oe),
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
      .sd_dat1_i(sd1_dat1), .sd_dat1_o(c1_dat1_o), .sd_dat1_oe(c1_dat1_oe),
      .sd_dat2_i(sd1_dat2), .sd_dat2_o(c1_dat2_o), .sd_dat2_oe(c1_dat2_oe),
      .sd_dat3_i(sd1_dat3), .sd_dat3_o(c1_dat3_o), .sd_dat3_oe(c1_dat3_oe)
  );

  // client 1 buffer: REGISTERED BRAM (the sterner timing case)
  reg [15:0] cbuf1[0:1023];
  // Phase 4: the region is a cache, not a staged copy, so correctness is
  // checked by READING blocks through the client port (which drives the
  // fetch/hit path) instead of inspecting region words after an open.
  reg [15:0] cbuf0 [0:1023];
  reg [15:0] cbuf3 [0:1023];
  reg [15:0] cbuf4 [0:1023];
  // client 6 = WD0.IMG, the Winchester. It is a CACHED client (CACHE_MASK
  // bit 6) and, until 08-AUG-2026, no card-image testbench ever read a
  // block through a cached client with real mount geometry - every
  // full-stack read here was tape (0) or floppy (1), both DIRECT.
  reg [15:0] cbuf6 [0:1023];

  always @(posedge clk_cpu) begin
    if (buf_we_w[0]) cbuf0[buf_addr_w[9:0]]   <= buf_wdata_w[15:0];
    if (buf_we_w[3]) cbuf3[buf_addr_w[39:30]] <= buf_wdata_w[63:48];
    if (buf_we_w[4]) cbuf4[buf_addr_w[49:40]] <= buf_wdata_w[79:64];
    if (buf_we_w[6]) cbuf6[buf_addr_w[69:60]] <= buf_wdata_w[111:96];
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

  // Read every block of a file through the CLIENT PORT and compare against
  // the pattern. This replaces v1's check_slot, which read the region
  // directly on the assumption that an open had staged the whole image
  // there. Nothing is staged now, so the only meaningful question is
  // whether a block request returns the right bytes - which exercises the
  // cache miss/fill (or the DIRECT fetch) all the way to the card.
  task check_blocks(input [2:0] c, input integer fbytes, input integer is_tape,
                    input [127:0] what);
    integer blk, nblk, j, k0, k1;
    reg [15:0] gotw, expw;
    begin
      nblk = (fbytes + 2047) / 2048;
      for (blk = 0; blk < nblk; blk = blk + 1) begin
        do_read(c, blk[15:0], what);
        for (j = 0; j < 1024; j = j + 1) begin
          k0 = blk*2048 + 2*j;
          k1 = k0 + 1;
          if (k0 < fbytes) begin
            expw[15:8] = (is_tape == 2) ? pat_frag(k0)
                       : (is_tape == 1) ? pat_tape(k0) : pat_flp(k0);
            expw[7:0]  = (k1 < fbytes)
                       ? ((is_tape == 2) ? pat_frag(k1)
                          : (is_tape == 1) ? pat_tape(k1) : pat_flp(k1))
                       : 8'd0;
            case (c)
              3'd0:    gotw = cbuf0[j];
              3'd3:    gotw = cbuf3[j];
              3'd4:    gotw = cbuf4[j];
              default: gotw = cbuf1[j];
            endcase
            if (gotw !== expw) begin
              if (errors < 10)
                $display("FAIL: %0s blk %0d word %0d: got %04x want %04x",
                         what, blk, j, gotw, expw);
              errors = errors + 1;
            end
          end
        end
      end
    end
  endtask

  // ------------------------------------------------------------- test
  integer w, guard, blkn;
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
    check_blocks(3'd0, TAPE_BYTES, 1, "tape");

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
    check_blocks(3'd1, FLP_BYTES, 0, "floppy1");

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

    // ---- (d2) FRAGMENTED file via the FAT walker -------------------------
    // FRAG.IMG's second cluster is deliberately relocated past the chain
    // (make_storage_image.sh FAT surgery). Under the retired contiguity
    // fence this file was the open_err case; with runtime FAT walking the
    // read must return byte-exact content ACROSS the fragment seam.
    do_open(3'd4, "open frag");
    if (err_w[4] !== 1'b0 || open_ok_w[4] !== 1'b1 || open_err_w[4] !== 1'b0) begin
      $display("FAIL: frag open flags (err=%b ok=%b oerr=%b)",
               err_w[4], open_ok_w[4], open_err_w[4]);
      errors = errors + 1;
    end
    check_blocks(3'd4, 2048, 2, "frag");

    // ---- (d) disc-class client 3: Phase 4 OPENS it -----------------------
    // v1 asserted the opposite: a client outside PRELOAD_MASK answered
    // open_err with ZERO card traffic, because v1 could only serve an image
    // it had staged whole into the region and a disc image never fits. The
    // cache removed that restriction, so the SAME open must now SUCCEED and
    // must talk to the card to do it.
    smd_sdclk_edges = 0;
    smd_watch = 1;
    do_open(3'd3, "open smd0");
    smd_watch = 0;
    // SMD0.IMG is NOT on the test card (make_storage_image.sh builds only
    // TAPE.BPUN, FLOPPY1.IMG and FRAG.IMG), so this open must fail as
    // file-not-found. The Phase-4 difference from v1 is WHY: v1 refused it
    // sight-unseen because it was outside PRELOAD_MASK, doing zero card
    // traffic. A cached client is a real client now - it has to go and look.
    if (open_err_w[3] !== 1'b1 || open_ok_w[3] !== 1'b0) begin
      $display("FAIL: missing-file open flags (oerr=%b ok=%b, want err)",
               open_err_w[3], open_ok_w[3]);
      errors = errors + 1;
    end
    if (smd_sdclk_edges === 0) begin
      $display("FAIL: cached client open did no card traffic - it must look");
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

    // ---- (h) block READ on client 6 (WD0.IMG) - the CACHED path --------
    // This is the case the guest was failing on real silicon 08-AUG-2026:
    // the Winchester controller reported finished, no error, a full 1024-
    // word DMA - and every word was zero. Client 6 is CACHED, so a cold
    // read must MISS, fetch four card sectors, fill the region line,
    // publish the tag and only then serve the client. Anything that serves
    // the line before the fill lands returns exactly 1024 zero words.
    do_open(3'd6, "open wd0");
    if (!open_ok_w[6] || open_err_w[6]) begin
      $display("FAIL: WD0.IMG open (ok=%b err=%b)", open_ok_w[6], open_err_w[6]);
      errors = errors + 1;
    end
    if (size_bytes_w[32*6+:32] !== WD_BYTES) begin
      $display("FAIL: WD0.IMG size %0d, want %0d",
               size_bytes_w[32*6+:32], WD_BYTES);
      errors = errors + 1;
    end
    for (blkn = 0; blkn < 3; blkn = blkn + 1) begin
      for (w = 0; w < 1024; w = w + 1) cbuf6[w] = 16'hDEAD;  // poison
      do_read(3'd6, blkn[15:0], "read wd0");
      if (err_w[6] !== 1'b0) begin
        $display("FAIL: WD0 block %0d read returned err", blkn);
        errors = errors + 1;
      end
      for (w = 0; w < 1024; w = w + 1) begin
        expw16 = {pat_wd(blkn*2048 + 2*w), pat_wd(blkn*2048 + 2*w + 1)};
        if (cbuf6[w] !== expw16) begin
          if (errors < 10)
            $display("FAIL: WD0 blk %0d word %0d: got %04x want %04x",
                     blkn, w, cbuf6[w], expw16);
          errors = errors + 1;
        end
      end
    end
    // re-read block 0: now RESIDENT, so it must come back from the region
    // line with no card traffic and still be the card's bytes
    for (w = 0; w < 1024; w = w + 1) cbuf6[w] = 16'hDEAD;
    do_read(3'd6, 16'd0, "reread wd0 blk0");
    for (w = 0; w < 1024; w = w + 1) begin
      expw16 = {pat_wd(2*w), pat_wd(2*w + 1)};
      if (cbuf6[w] !== expw16) begin
        if (errors < 10)
          $display("FAIL: WD0 blk0 HIT word %0d: got %04x want %04x",
                   w, cbuf6[w], expw16);
        errors = errors + 1;
      end
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
    check_blocks(3'd0, TAPE_BYTES, 1, "tape-reopen");

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
    // Phase 4: a file LARGER THAN ITS SLOT is the normal case now - that is
    // the whole point, a 75 MB image against a 4 MB region. The open must
    // SUCCEED. v1 asserted it failed.
    if (ov_open_ok_w[0] !== 1'b1 || ov_open_err_w[0] !== 1'b0) begin
      $display("FAIL: oversize open flags (oerr=%b ok=%b, want ok)",
               ov_open_err_w[0], ov_open_ok_w[0]);
      errors = errors + 1;
    end
    // And it must stage NOTHING. This is the assertion that proves the
    // preload is really gone: a mount that still streamed the file into the
    // region would show hundreds of mem pulses here (751 before M_LOAD was
    // taken out of the path), and on a 75 MB image would never finish.
    if (m2_starts !== 0) begin
      $display("FAIL: open staged into the region (%0d mem pulses, want 0)", m2_starts);
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

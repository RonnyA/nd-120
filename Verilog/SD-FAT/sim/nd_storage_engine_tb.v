/****************************************************************************
** Unit testbench for nd_storage_engine (iverilog)                        **
**                                                                         **
** Engine + nds_mem_model at skewed clocks (clk_cpu ~23.04 MHz,           **
** clk_stor ~27.03 MHz, non-integer ratio) with two clients whose mem     **
** slots are preloaded with distinct address-unique patterns:             **
**                                                                         **
**   (a) round-robin grant order with pointer advance past the winner:    **
**       three rounds of simultaneous requests - (0,1), (0,1), then a     **
**       solo client-0 op, then (1,0) because the pointer moved past 0    **
**   (b) block data arrives byte-exact in each client's buffer (the tb   **
**       models the client buffer as a BRAM driven by buf_addr/wdata/we) **
**   (c) busy/done/err handshake per the spec waveform: busy rises after **
**       req and holds until done, done is a single-cycle pulse, err is  **
**       valid with done                                                  **
**   (d) out-of-range block answers done+err with ZERO mem-port traffic  **
**       (mem_start pulses counted), and the engine recovers             **
**   (e) open path plumbing: open_req reaches the mount stub             **
**       (mnt_start/mnt_client) and completes with done, err=0;          **
**       size_bytes is sampled at the open_ok rise                       **
**                                                                         **
** The write path (W_*) is exercised end-to-end against the real         **
** sd_writer + card model in nd_storage_write_tb.v (test-nds-write).     **
**                                                                         **
** Verdict: TB_RESULT: PASS / TB_RESULT: FAIL <reason>                     **
**                                                                         **
** Last reviewed: 11-JUL-2026                                              **
** Ronny Hansen                                                            **
*****************************************************************************/
`timescale 1ns / 1ps

module nd_storage_engine_tb;

  localparam STOR_HALF = 18.5;  // ~27.03 MHz
  localparam CPU_HALF  = 21.7;  // ~23.04 MHz
  localparam N         = 2;     // clients under test
  localparam BASE0     = 0;     // SLOT0_BASE_BLK
  localparam BASE1     = 32;    // SLOT1_BASE_BLK
  localparam NBLK      = 4;     // n_blocks per client

  reg clk_stor = 0;
  always #STOR_HALF clk_stor = ~clk_stor;
  reg clk_cpu = 0;
  always #CPU_HALF clk_cpu = ~clk_cpu;

  reg rst_n = 0;

  // ------------------------------------------------------------- DUT wiring
  wire        mem_start_w, mem_we_w, mem_busy_w, mem_done_w;
  wire [19:0] mem_addr_w;
  wire [31:0] mem_wdata_w, mem_rdata_w;

  wire        mnt_start_w;
  wire [1:0]  mnt_client_w;
  reg         mnt_done_r = 0;

  reg  [N-1:0]    t_open_req = 0;
  reg  [N-1:0]    t_req = 0;
  reg  [N-1:0]    t_wr = 0;
  reg  [15:0]     t_block0 = 0, t_block1 = 0;
  wire [N-1:0]    open_ok_w, open_err_w, busy_w, done_w, err_w, buf_we_w;
  wire [N*32-1:0] size_bytes_w;
  wire [N*10-1:0] buf_addr_w;
  wire [N*16-1:0] buf_wdata_w;
  reg  [15:0]     rd0 = 0, rd1 = 0;

  wire        eng_wd_err_w;
  wire        sdw_start_w;
  wire [31:0] sdw_sector_w;
  wire [8:0]  sdw_rd_addr_unused = 9'd0;
  wire [7:0]  sdw_rd_data_w;

  nd_storage_engine #(
      .N_CLIENTS     (N),
      .WD_MAX        (32'd10_000),
      .SLOT0_BASE_BLK(BASE0),
      .SLOT1_BASE_BLK(BASE1)
  ) dut (
      .clk_stor  (clk_stor),
      .rst_stor_n(rst_n),
      .clk_cpu   (clk_cpu),
      .rst_cpu_n (rst_n),

      .mem_start(mem_start_w),
      .mem_we   (mem_we_w),
      .mem_addr (mem_addr_w),
      .mem_wdata(mem_wdata_w),
      .mem_rdata(mem_rdata_w),
      .mem_busy (mem_busy_w),
      .mem_done (mem_done_w),

      .mnt_start (mnt_start_w),
      .mnt_client(mnt_client_w),
      .mnt_done  (mnt_done_r),
      .mnt_err   (1'b0),

      .open_ok_stor   ({N{1'b1}}),
      .open_err_stor  ({N{1'b0}}),
      .size_bytes_stor({32'd8192, 32'd8192}),
      .n_blocks       ({16'd4, 16'd4}),
      .first_sector   (64'd0),

      .sdw_start  (sdw_start_w),
      .sdw_sector (sdw_sector_w),
      .sdw_busy   (1'b0),
      .sdw_done   (1'b0),
      .sdw_err    (1'b0),
      .sdw_rd_addr(sdw_rd_addr_unused),
      .sdw_rd_data(sdw_rd_data_w),

      .eng_wd_err(eng_wd_err_w),

      .open_req  (t_open_req),
      .open_ok   (open_ok_w),
      .open_err  (open_err_w),
      .size_bytes(size_bytes_w),
      .req       (t_req),
      .wr        (t_wr),
      .block     ({t_block1, t_block0}),
      .busy      (busy_w),
      .done      (done_w),
      .err       (err_w),
      .buf_addr  (buf_addr_w),
      .buf_wdata (buf_wdata_w),
      .buf_we    (buf_we_w),
      .buf_rdata ({rd1, rd0})
  );

  nds_mem_model #(
      .MEM_WORDS(65536)
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

  // ------------------------------------------------------------- mount stub
  reg        mnt_pend = 0;
  reg [7:0]  mnt_cnt = 0;
  reg [1:0]  mnt_cli_seen = 0;
  integer    mnt_starts = 0;
  always @(posedge clk_stor) begin
    mnt_done_r <= 1'b0;
    if (mnt_start_w) begin
      mnt_pend     <= 1'b1;
      mnt_cnt      <= 8'd0;
      mnt_cli_seen <= mnt_client_w;
      mnt_starts   = mnt_starts + 1;
    end else if (mnt_pend) begin
      mnt_cnt <= mnt_cnt + 8'd1;
      if (mnt_cnt == 8'd20) begin
        mnt_done_r <= 1'b1;
        mnt_pend   <= 1'b0;
      end
    end
  end

  // ------------------------------------------------------------- client bufs
  // the tb models each client's BRAM, driven by the engine's buf port
  reg [15:0] cbuf0[0:1023];
  reg [15:0] cbuf1[0:1023];
  always @(posedge clk_cpu) begin
    if (buf_we_w[0]) cbuf0[buf_addr_w[9:0]] <= buf_wdata_w[15:0];
    if (buf_we_w[1]) cbuf1[buf_addr_w[19:10]] <= buf_wdata_w[31:16];
    // registered read-back (write path, exercised in step 3)
    rd0 <= cbuf0[buf_addr_w[9:0]];
    rd1 <= cbuf1[buf_addr_w[19:10]];
  end

  // ------------------------------------------------------------- monitors
  integer errors = 0;
  integer ord[0:31];    // completion (= grant) order
  integer ord_n = 0;
  reg     last_err0 = 0, last_err1 = 0;
  reg [N-1:0] done_q = 0, busy_q = 0;
  always @(posedge clk_cpu) begin
    done_q <= done_w;
    busy_q <= busy_w;
    if ((done_w & done_q) != 0) begin
      $display("FAIL: done wider than one clk_cpu cycle");
      errors = errors + 1;
    end
    if (done_w[0]) begin
      if (!busy_q[0]) begin
        $display("FAIL: done[0] without preceding busy");
        errors = errors + 1;
      end
      if (busy_w[0]) begin
        $display("FAIL: busy[0] still high during done");
        errors = errors + 1;
      end
      last_err0 = err_w[0];
      ord[ord_n] = 0;
      ord_n = ord_n + 1;
    end
    if (done_w[1]) begin
      if (!busy_q[1]) begin
        $display("FAIL: done[1] without preceding busy");
        errors = errors + 1;
      end
      if (busy_w[1]) begin
        $display("FAIL: busy[1] still high during done");
        errors = errors + 1;
      end
      last_err1 = err_w[1];
      ord[ord_n] = 1;
      ord_n = ord_n + 1;
    end
  end

  // mem-port traffic counter (for the zero-traffic range-error check)
  integer mem_starts = 0;
  always @(posedge clk_stor) if (mem_start_w) mem_starts = mem_starts + 1;

  // ------------------------------------------------------------- helpers
  task wait_ops(input integer target);
    integer guard;
    begin
      guard = 0;
      while (ord_n < target && guard < 2_000_000) begin
        @(posedge clk_cpu);
        guard = guard + 1;
      end
      if (ord_n < target) begin
        $display("TB_RESULT: FAIL waiting for op %0d timed out (have %0d)", target, ord_n);
        $finish;
      end
    end
  endtask

  task check_ord(input integer idx, input integer want);
    begin
      if (ord[idx] !== want) begin
        $display("FAIL: grant order[%0d] = client %0d (want %0d)", idx, ord[idx], want);
        errors = errors + 1;
      end
    end
  endtask

  task req_both(input [15:0] b0, input [15:0] b1);
    integer guard;
    begin
      @(posedge clk_cpu);
      t_req    <= 2'b11;
      t_wr     <= 2'b00;
      t_block0 <= b0;
      t_block1 <= b1;
      @(posedge clk_cpu);
      t_req <= 2'b00;
      guard = 0;
      while (busy_w != 2'b11 && guard < 100) begin
        @(posedge clk_cpu);
        guard = guard + 1;
      end
      if (busy_w != 2'b11) begin
        $display("TB_RESULT: FAIL simultaneous requests never went busy");
        $finish;
      end
    end
  endtask

  task req_one(input integer c, input [15:0] blk, input wrbit);
    integer guard;
    begin
      @(posedge clk_cpu);
      if (c == 0) begin
        t_req[0] <= 1'b1;
        t_wr[0] <= wrbit;
        t_block0 <= blk;
      end else begin
        t_req[1] <= 1'b1;
        t_wr[1] <= wrbit;
        t_block1 <= blk;
      end
      @(posedge clk_cpu);
      t_req <= 2'b00;
      guard = 0;
      while (!busy_w[c] && guard < 100) begin
        @(posedge clk_cpu);
        guard = guard + 1;
      end
      if (!busy_w[c]) begin
        $display("TB_RESULT: FAIL client %0d request never went busy", c);
        $finish;
      end
    end
  endtask

  task check_buf(input integer c, input [15:0] blk);
    integer w;
    reg [31:0] ma;
    reg [31:0] a32;
    reg [15:0] expw, gotw;
    begin
      for (w = 0; w < 1024; w = w + 1) begin
        ma   = ((c == 0 ? BASE0 : BASE1) + blk) * 512 + (w / 2);
        a32  = u_mem.mem[ma];
        expw = (w % 2 == 1) ? a32[15:0] : a32[31:16];
        gotw = (c == 0) ? cbuf0[w] : cbuf1[w];
        if (gotw !== expw) begin
          if (errors < 10)
            $display("FAIL: client %0d block %0d word %0d: got %04x want %04x",
                     c, blk, w, gotw, expw);
          errors = errors + 1;
        end
      end
    end
  endtask

  // ------------------------------------------------------------- mem preload
  // distinct, address-unique patterns per client slot
  integer pb, pm;
  reg [31:0] pa;
  initial begin
    for (pb = 0; pb < NBLK; pb = pb + 1) begin
      for (pm = 0; pm < 512; pm = pm + 1) begin
        pa = (BASE0 + pb) * 512 + pm;
        u_mem.mem[pa] = {pa[15:0] ^ 16'h1111, pa[15:0] ^ 16'hEEEE};
        pa = (BASE1 + pb) * 512 + pm;
        u_mem.mem[pa] = {pa[15:0] ^ 16'h2222, pa[15:0] ^ 16'hDDDD};
      end
    end
  end

  // ------------------------------------------------------------- test
  integer mem_starts_before;
  initial begin
    repeat (10) @(posedge clk_stor);
    rst_n = 1;
    repeat (50) @(posedge clk_cpu);

    // (e) open status plumbing: levels synced, size sampled at open_ok rise
    if (open_ok_w !== 2'b11) begin
      $display("FAIL: open_ok did not sync through (%b)", open_ok_w);
      errors = errors + 1;
    end
    if (size_bytes_w[31:0] !== 32'd8192 || size_bytes_w[63:32] !== 32'd8192) begin
      $display("FAIL: size_bytes not sampled (%0d, %0d)",
               size_bytes_w[31:0], size_bytes_w[63:32]);
      errors = errors + 1;
    end

    // (e) open handshake through the mount stub
    @(posedge clk_cpu);
    t_open_req[0] <= 1'b1;
    @(posedge clk_cpu);
    t_open_req[0] <= 1'b0;
    wait_ops(1);
    if (last_err0 !== 1'b0) begin
      $display("FAIL: open of client 0 returned err");
      errors = errors + 1;
    end
    if (mnt_starts !== 1 || mnt_cli_seen !== 2'd0) begin
      $display("FAIL: mount stub saw %0d starts, client %0d", mnt_starts, mnt_cli_seen);
      errors = errors + 1;
    end
    @(posedge clk_cpu);
    t_open_req[1] <= 1'b1;
    @(posedge clk_cpu);
    t_open_req[1] <= 1'b0;
    wait_ops(2);
    if (mnt_starts !== 2 || mnt_cli_seen !== 2'd1) begin
      $display("FAIL: mount stub saw %0d starts, client %0d", mnt_starts, mnt_cli_seen);
      errors = errors + 1;
    end

    // (a)+(b) round 1: both clients simultaneously -> grant order (0,1)
    req_both(16'd0, 16'd0);
    wait_ops(4);
    check_ord(2, 0);
    check_ord(3, 1);
    if (last_err0 || last_err1) begin
      $display("FAIL: round 1 returned err");
      errors = errors + 1;
    end
    check_buf(0, 16'd0);
    check_buf(1, 16'd0);

    // round 2: both again -> (0,1)
    req_both(16'd1, 16'd2);
    wait_ops(6);
    check_ord(4, 0);
    check_ord(5, 1);
    check_buf(0, 16'd1);
    check_buf(1, 16'd2);

    // solo client 0: leaves the round-robin pointer at 0
    req_one(0, 16'd2, 1'b0);
    wait_ops(7);
    check_ord(6, 0);
    check_buf(0, 16'd2);

    // round 3: both again -> (1,0) because the pointer advanced past 0
    req_both(16'd3, 16'd3);
    wait_ops(9);
    check_ord(7, 1);
    check_ord(8, 0);
    check_buf(0, 16'd3);
    check_buf(1, 16'd3);

    // (d) out-of-range block: done+err with ZERO mem traffic
    mem_starts_before = mem_starts;
    req_one(0, NBLK[15:0], 1'b0);  // block 4, n_blocks = 4
    wait_ops(10);
    if (last_err0 !== 1'b1) begin
      $display("FAIL: out-of-range block did not return err");
      errors = errors + 1;
    end
    if (mem_starts !== mem_starts_before) begin
      $display("FAIL: out-of-range block touched the mem port (%0d pulses)",
               mem_starts - mem_starts_before);
      errors = errors + 1;
    end

    // recovery: a normal read still works after the error
    req_one(0, 16'd0, 1'b0);
    wait_ops(11);
    if (last_err0 !== 1'b0) begin
      $display("FAIL: read after range error returned err");
      errors = errors + 1;
    end
    check_buf(0, 16'd0);

    // total mem traffic: exactly 512 reads per successful block op
    if (mem_starts !== 8 * 512) begin
      $display("FAIL: mem_start pulses = %0d (want %0d)", mem_starts, 8 * 512);
      errors = errors + 1;
    end
    if (eng_wd_err_w !== 1'b0) begin
      $display("FAIL: engine watchdog fired");
      errors = errors + 1;
    end

    if (errors == 0) $display("TB_RESULT: PASS");
    else $display("TB_RESULT: FAIL %0d errors", errors);
    $finish;
  end

  initial begin
    #100_000_000;  // 100 ms absolute watchdog
    $display("TB_RESULT: FAIL absolute watchdog (ops done: %0d)", ord_n);
    $finish;
  end

endmodule

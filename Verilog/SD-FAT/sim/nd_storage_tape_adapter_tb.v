/****************************************************************************
** Testbench for nd_storage_tape_adapter (iverilog) - step 7, spec        **
** acceptance test 4 (byte-compare, mid-stream rewind, EOF silence).      **
**                                                                         **
** TWO TIERS in one run:                                                   **
**                                                                         **
** Tier A (unit): adapter against a SCRIPTED client-port stub serving a    **
** 3001-byte image from an array (no SD, no SDRAM). The stub poisons      **
** every byte past EOF with 0xEE (the zero-padded slot tail) and counts   **
** fetches. Checks:                                                        **
**   (a1) silence before open (no byte_valid, no c_req)                    **
**   (a2) open_start passes through as exactly one c_open_req pulse        **
**   (a3) full 3001-byte stream byte-exact vs the pattern (covers BOTH     **
**        halves of every word: even byte = [15:8], big-endian, design    **
**        doc 4.1) with the block-boundary check made explicit: still     **
**        1 fetch after byte 2047, a 2nd fetch serving byte 2048           **
**   (a4) EOF silence: byte_req at 3001 never answers, ZERO new fetches   **
**        (the poisoned tail is never served)                              **
**   (a5) rewind mid-position, byte-compare from 0 again (one refetch)    **
**   (a6) c_err on a fetch: silent, no wedge, next byte_req retries and   **
**        succeeds                                                         **
**   (a7) rewind DURING an in-flight fetch: result discarded, no stale    **
**        byte_valid, next byte_req serves byte 0                          **
**                                                                         **
** Tier B (full stack): a second adapter on CLIENT 0 of the real           **
** nd_storage stack (reader + writer + mount + engine + fatchk) with the  **
** behavioral SD card model serving nds_storage.img (TAPE.BPUN, 3001 B,   **
** built by make_storage_image.sh) and the behavioral mem-port model, at  **
** skewed clocks (clk_cpu ~23.04 MHz, clk_stor ~27.03 MHz). Checks:       **
**   (b1) open via the adapter's open_start: open_ok, size_bytes = 3001   **
**   (b2) stream the ENTIRE file byte-by-byte, byte-exact vs the image    **
**        pattern                                                          **
**   (b3) EOF silence: no byte_valid, no client req, no SDRAM traffic     **
**   (b4) rewind, re-read the first 100 bytes byte-exact                  **
**   plus card health: CMD CRC7 = 0, zero card writes (read-only tb)      **
**                                                                         **
** Request pulses are NONBLOCKING one-cycle pulses (repo lesson).          **
** Verdict: TB_RESULT: PASS / TB_RESULT: FAIL <reason>                     **
**                                                                         **
** Last reviewed: 11-JUL-2026                                              **
** Ronny Hansen                                                            **
*****************************************************************************/
`timescale 1ns / 1ps

module nd_storage_tape_adapter_tb;

  localparam STOR_HALF = 18.5;  // ~27.03 MHz
  localparam CPU_HALF  = 21.7;  // ~23.04 MHz
  localparam N         = 7;

  localparam integer TAPE_BYTES  = 3001;  // NOT a 2048 multiple (on purpose)
  localparam integer U_IMG_BYTES = 4096;  // 2 blocks incl. poisoned tail
  localparam IMG_BYTES   = 4 * 1024 * 1024;
  localparam IMG_SECTORS = IMG_BYTES / 512;

  reg clk_stor = 0;
  always #STOR_HALF clk_stor = ~clk_stor;
  reg clk_cpu = 0;
  always #CPU_HALF clk_cpu = ~clk_cpu;

  reg rst_n = 0;

  integer errors = 0;

  // MUST match make_storage_image.sh (nds_tape.bin)
  function [7:0] pat_tape(input integer k);
    pat_tape = ((k % 256) + 37 * ((k / 256) % 256) + 129) % 256;
  endfunction

  // =====================================================================
  // Tier A: adapter vs scripted client-port stub
  // =====================================================================
  reg         ua_byte_req = 0;
  wire        ua_byte_valid;
  wire [7:0]  ua_byte_data;
  reg         ua_rewind = 0;
  reg         ua_open_start = 0;

  wire        ua_open_req, ua_req, ua_wr;
  wire [15:0] ua_block;
  wire [15:0] ua_buf_rdata;

  reg         u_open_ok = 0;
  reg  [31:0] u_size = TAPE_BYTES;
  reg         u_err_inject = 0;

  reg         u_busy = 0, u_done = 0, u_err = 0, u_bwe = 0;
  reg  [9:0]  u_baddr = 0;
  reg  [15:0] u_bwdata = 0;

  nd_storage_tape_adapter dut_u (
      .clk_cpu      (clk_cpu),
      .rst_n        (rst_n),
      .byte_req     (ua_byte_req),
      .byte_valid   (ua_byte_valid),
      .byte_data    (ua_byte_data),
      .source_rewind(ua_rewind),
      .open_start   (ua_open_start),
      .c_open_req   (ua_open_req),
      .c_open_ok    (u_open_ok),
      .c_open_err   (1'b0),
      .c_size_bytes (u_size),
      .c_req        (ua_req),
      .c_wr         (ua_wr),
      .c_block      (ua_block),
      .c_busy       (u_busy),
      .c_done       (u_done),
      .c_err        (u_err),
      .c_buf_addr   (u_baddr),
      .c_buf_wdata  (u_bwdata),
      .c_buf_we     (u_bwe),
      .c_buf_rdata  (ua_buf_rdata)
  );

  // stub image: pattern bytes, then 0xEE POISON past EOF (the padded tail
  // that must never be served as data)
  reg [7:0] u_img[0:U_IMG_BYTES-1];
  integer ii;
  initial begin
    for (ii = 0; ii < U_IMG_BYTES; ii = ii + 1)
      u_img[ii] = (ii < TAPE_BYTES) ? pat_tape(ii) : 8'hEE;
  end

  // scripted stub: latch a read request, wait a few cycles, then stream
  // 1024 big-endian words (or answer done+err when u_err_inject is set)
  integer u_fetches = 0;
  integer u_open_reqs = 0;
  reg [15:0] u_lblk = 0;
  integer u_wi = 0, u_dly = 0;
  reg [1:0] u_st = 0;

  always @(posedge clk_cpu) begin
    u_done <= 1'b0;
    u_err  <= 1'b0;
    u_bwe  <= 1'b0;
    if (ua_open_req) begin
      u_open_reqs = u_open_reqs + 1;
      u_open_ok <= 1'b1;
    end
    case (u_st)
      2'd0: begin
        if (ua_req && !ua_wr) begin
          u_fetches = u_fetches + 1;
          u_lblk <= ua_block;
          u_busy <= 1'b1;
          u_dly  <= 5 + (u_fetches % 7);
          u_st   <= 2'd1;
        end
      end
      2'd1: begin
        if (u_dly == 0) begin
          if (u_err_inject) begin
            u_done <= 1'b1;
            u_err  <= 1'b1;
            u_busy <= 1'b0;
            u_st   <= 2'd0;
          end else begin
            u_wi <= 0;
            u_st <= 2'd2;
          end
        end else u_dly <= u_dly - 1;
      end
      2'd2: begin
        if (u_wi < 1024) begin
          u_bwe    <= 1'b1;
          u_baddr  <= u_wi[9:0];
          u_bwdata <= {u_img[u_lblk*2048+2*u_wi], u_img[u_lblk*2048+2*u_wi+1]};
          u_wi     <= u_wi + 1;
        end else begin
          u_done <= 1'b1;
          u_busy <= 1'b0;
          u_st   <= 2'd0;
        end
      end
      default: u_st <= 2'd0;
    endcase
  end

  // sticky byte_valid monitor for the discard/silence phases
  reg u_saw_valid = 0;
  always @(posedge clk_cpu) if (ua_byte_valid) u_saw_valid <= 1'b1;

  // tier-A byte fetch: pulse byte_req, wait for byte_valid (or give up)
  task u_getb(input [31:0] max_cycles, output reg ok, output reg [7:0] d);
    integer g;
    begin
      @(posedge clk_cpu);
      ua_byte_req <= 1'b1;
      @(posedge clk_cpu);
      ua_byte_req <= 1'b0;
      ok = 0;
      d  = 8'h00;
      g  = 0;
      while (!ok && g < max_cycles) begin
        @(posedge clk_cpu);
        if (ua_byte_valid) begin
          ok = 1;
          d  = ua_byte_data;
        end
        g = g + 1;
      end
    end
  endtask

  task u_pulse_rewind;
    begin
      @(posedge clk_cpu);
      ua_rewind <= 1'b1;
      @(posedge clk_cpu);
      ua_rewind <= 1'b0;
      @(posedge clk_cpu);
    end
  endtask

  // =====================================================================
  // Tier B: adapter on client 0 of the REAL nd_storage stack
  // =====================================================================
  wire        sd1_clk, sd1_cmd_o, sd1_cmd_oe, sd1_dat0_o, sd1_dat0_oe;
  // SD lines resolved by MUX, no tristates (14-JUL-2026): host output-enable
  // wins, then the card, then the bus pullup (1) - same rule as
  // nd_storage_vtop.v:92.
  wire        cm_cmd_o, cm_cmd_oe, cm_dat0_o, cm_dat0_oe;
  wire        sd1_cmd  = sd1_cmd_oe  ? sd1_cmd_o  : (cm_cmd_oe  ? cm_cmd_o  : 1'b1);
  wire        sd1_dat0 = sd1_dat0_oe ? sd1_dat0_o : (cm_dat0_oe ? cm_dat0_o : 1'b1);

  wire        mem_start_w, mem_we_w, mem_busy_w, mem_done_w;
  wire [19:0] mem_addr_w;
  wire [31:0] mem_wdata_w, mem_rdata_w;

  reg         fa_byte_req = 0;
  wire        fa_byte_valid;
  wire [7:0]  fa_byte_data;
  reg         fa_rewind = 0;
  reg         fa_open_start = 0;

  wire        fa_open_req, fa_req, fa_wr;
  wire [15:0] fa_block;
  wire [15:0] fa_buf_rdata;

  wire [N-1:0]    open_ok_w, open_err_w, busy_w, done_w, err_w, buf_we_w;
  wire [N*32-1:0] size_bytes_w;
  wire [N*10-1:0] buf_addr_w;
  wire [N*16-1:0] buf_wdata_w;
  wire [1:0]      sd_status_w, card_type_w, fs_type_w;

  nd_storage_tape_adapter dut_f (
      .clk_cpu      (clk_cpu),
      .rst_n        (rst_n),
      .byte_req     (fa_byte_req),
      .byte_valid   (fa_byte_valid),
      .byte_data    (fa_byte_data),
      .source_rewind(fa_rewind),
      .open_start   (fa_open_start),
      .c_open_req   (fa_open_req),
      .c_open_ok    (open_ok_w[0]),
      .c_open_err   (open_err_w[0]),
      .c_size_bytes (size_bytes_w[31:0]),
      .c_req        (fa_req),
      .c_wr         (fa_wr),
      .c_block      (fa_block),
      .c_busy       (busy_w[0]),
      .c_done       (done_w[0]),
      .c_err        (err_w[0]),
      .c_buf_addr   (buf_addr_w[9:0]),
      .c_buf_wdata  (buf_wdata_w[15:0]),
      .c_buf_we     (buf_we_w[0]),
      .c_buf_rdata  (fa_buf_rdata)
  );

  nd_storage #(
      .N_CLIENTS (N),
      .RD_CLK_DIV(3'd1),
      .WR_CLKDIV (8'd2),
      .WD_MAX    (32'd5_000_000),
      .SIMULATE  (1)
  ) dut_s (
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
      .open_req  ({6'd0, fa_open_req}),
      .open_ok   (open_ok_w),
      .open_err  (open_err_w),
      .size_bytes(size_bytes_w),
      .req       ({6'd0, fa_req}),
      .wr        ({6'd0, fa_wr}),
      .block     ({96'd0, fa_block}),
      .busy      (busy_w),
      .done      (done_w),
      .err       (err_w),
      .buf_addr  (buf_addr_w),
      .buf_wdata (buf_wdata_w),
      .buf_we    (buf_we_w),
      .buf_rdata ({{6{16'd0}}, fa_buf_rdata}),
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

  // any card write at all is illegal in this tb (tape is read-only)
  sd_card_model #(
      .IMAGE           ("nds_storage.img"),
      .MAX_BYTES       (IMG_BYTES),
      .LEGAL_MIN_SECTOR(IMG_SECTORS)
  ) card (
      .sd_clk   (sd1_clk),
      .sd_cmd_i (sd1_cmd),  .sd_cmd_o (cm_cmd_o),  .sd_cmd_oe (cm_cmd_oe),
      .sd_dat0_i(sd1_dat0), .sd_dat0_o(cm_dat0_o), .sd_dat0_oe(cm_dat0_oe),
      .sd_dat1_i(1'b1), .sd_dat1_o(), .sd_dat1_oe(),
      .sd_dat2_i(1'b1), .sd_dat2_o(), .sd_dat2_oe(),
      .sd_dat3_i(1'b1), .sd_dat3_o(), .sd_dat3_oe()
  );

  // sticky monitors for the tier-B EOF silence window
  reg f_watch = 0;
  integer f_watch_valids = 0, f_watch_reqs = 0, f_watch_mems = 0;
  always @(posedge clk_cpu) begin
    if (f_watch && fa_byte_valid) f_watch_valids = f_watch_valids + 1;
    if (f_watch && fa_req)        f_watch_reqs   = f_watch_reqs + 1;
  end
  always @(posedge clk_stor)
    if (f_watch && mem_start_w) f_watch_mems = f_watch_mems + 1;

  task f_getb(input [31:0] max_cycles, output reg ok, output reg [7:0] d);
    integer g;
    begin
      @(posedge clk_cpu);
      fa_byte_req <= 1'b1;
      @(posedge clk_cpu);
      fa_byte_req <= 1'b0;
      ok = 0;
      d  = 8'h00;
      g  = 0;
      while (!ok && g < max_cycles) begin
        @(posedge clk_cpu);
        if (fa_byte_valid) begin
          ok = 1;
          d  = fa_byte_data;
        end
        g = g + 1;
      end
    end
  endtask

  // =====================================================================
  // test sequence
  // =====================================================================
  integer k, guard;
  reg gok;
  reg [7:0] gd;

  initial begin
    repeat (10) @(posedge clk_stor);
    rst_n = 1;
    repeat (20) @(posedge clk_cpu);

    // ---- Tier A ---------------------------------------------------------

    // (a1) not open: silence, zero traffic
    u_getb(32'd300, gok, gd);
    if (gok) begin
      $display("FAIL: (a1) byte_valid before open");
      errors = errors + 1;
    end
    if (u_fetches !== 0) begin
      $display("FAIL: (a1) c_req before open (%0d)", u_fetches);
      errors = errors + 1;
    end

    // (a2) open_start -> exactly one c_open_req pulse
    @(posedge clk_cpu);
    ua_open_start <= 1'b1;
    @(posedge clk_cpu);
    ua_open_start <= 1'b0;
    repeat (10) @(posedge clk_cpu);
    if (u_open_reqs !== 1 || u_open_ok !== 1'b1) begin
      $display("FAIL: (a2) open_start pass-through (reqs=%0d ok=%b)",
               u_open_reqs, u_open_ok);
      errors = errors + 1;
    end

    // (a3) full stream, byte-exact, explicit block-boundary fetch check
    for (k = 0; k < TAPE_BYTES; k = k + 1) begin
      u_getb(32'd5000, gok, gd);
      if (!gok) begin
        $display("TB_RESULT: FAIL (a3) no byte_valid for byte %0d", k);
        $finish;
      end
      if (gd !== pat_tape(k)) begin
        if (errors < 10)
          $display("FAIL: (a3) byte %0d: got %02x want %02x", k, gd, pat_tape(k));
        errors = errors + 1;
      end
      if (k == 2047 && u_fetches !== 1) begin
        $display("FAIL: (a3) fetch count after byte 2047 = %0d (want 1)", u_fetches);
        errors = errors + 1;
      end
      if (k == 2048 && u_fetches !== 2) begin
        $display("FAIL: (a3) byte 2048 did not fetch block 1 (%0d)", u_fetches);
        errors = errors + 1;
      end
    end
    if (u_fetches !== 2) begin
      $display("FAIL: (a3) total fetches %0d (want 2)", u_fetches);
      errors = errors + 1;
    end

    // (a4) EOF silence: size 3001 is NOT a 2048 multiple; the poisoned
    // tail (0xEE) must never come out, and no new fetches may happen
    for (k = 0; k < 3; k = k + 1) begin
      u_getb(32'd400, gok, gd);
      if (gok) begin
        $display("FAIL: (a4) byte_valid past EOF (try %0d, data %02x)", k, gd);
        errors = errors + 1;
      end
    end
    if (u_fetches !== 2) begin
      $display("FAIL: (a4) EOF caused traffic (fetches=%0d)", u_fetches);
      errors = errors + 1;
    end

    // (a5) rewind, byte-compare from 0 (one refetch of block 0)
    u_pulse_rewind;
    for (k = 0; k < 300; k = k + 1) begin
      u_getb(32'd5000, gok, gd);
      if (!gok) begin
        $display("TB_RESULT: FAIL (a5) no byte_valid for byte %0d after rewind", k);
        $finish;
      end
      if (gd !== pat_tape(k)) begin
        if (errors < 10)
          $display("FAIL: (a5) byte %0d after rewind: got %02x want %02x",
                   k, gd, pat_tape(k));
        errors = errors + 1;
      end
    end
    if (u_fetches !== 3) begin
      $display("FAIL: (a5) fetches after rewind %0d (want 3)", u_fetches);
      errors = errors + 1;
    end

    // (a6) c_err on the fetch: silent, no wedge, retry succeeds
    u_pulse_rewind;
    u_err_inject = 1;
    u_getb(32'd400, gok, gd);
    if (gok) begin
      $display("FAIL: (a6) byte_valid despite c_err");
      errors = errors + 1;
    end
    if (u_fetches !== 4) begin
      $display("FAIL: (a6) errored fetch not attempted (%0d)", u_fetches);
      errors = errors + 1;
    end
    u_err_inject = 0;
    u_getb(32'd5000, gok, gd);
    if (!gok || gd !== pat_tape(0)) begin
      $display("FAIL: (a6) retry after c_err (ok=%b data=%02x want %02x)",
               gok, gd, pat_tape(0));
      errors = errors + 1;
    end
    if (u_fetches !== 5) begin
      $display("FAIL: (a6) retry fetch count %0d (want 5)", u_fetches);
      errors = errors + 1;
    end

    // (a7) rewind DURING an in-flight fetch: discard, no stale byte
    // advance to block 1 first so the in-flight fetch is a real miss
    for (k = 1; k < 2050; k = k + 1) begin
      u_getb(32'd5000, gok, gd);
      if (!gok) begin
        $display("TB_RESULT: FAIL (a7) prefill stalled at byte %0d", k);
        $finish;
      end
    end
    u_pulse_rewind;  // position 0, buffer invalid
    @(posedge clk_cpu);
    ua_byte_req <= 1'b1;   // starts a fetch of block 0
    @(posedge clk_cpu);
    ua_byte_req <= 1'b0;
    guard = 0;
    while (!u_busy && guard < 100) begin
      @(posedge clk_cpu);
      guard = guard + 1;
    end
    if (!u_busy) begin
      $display("TB_RESULT: FAIL (a7) in-flight fetch never started");
      $finish;
    end
    u_saw_valid = 0;
    @(posedge clk_cpu);
    ua_rewind <= 1'b1;     // rewind while the stub streams
    @(posedge clk_cpu);
    ua_rewind <= 1'b0;
    // let the stub finish and give the adapter room to (wrongly) serve
    repeat (1500) @(posedge clk_cpu);
    if (u_saw_valid) begin
      $display("FAIL: (a7) stale byte_valid after rewind-during-fetch");
      errors = errors + 1;
    end
    u_getb(32'd5000, gok, gd);
    if (!gok || gd !== pat_tape(0)) begin
      $display("FAIL: (a7) byte 0 after discarded fetch (ok=%b data=%02x want %02x)",
               gok, gd, pat_tape(0));
      errors = errors + 1;
    end

    $display("tier A (unit stub) done: %0d errors, %0d fetches", errors, u_fetches);

    // ---- Tier B ---------------------------------------------------------

    // (b1) open TAPE.BPUN through the adapter's open_start
    @(posedge clk_cpu);
    fa_open_start <= 1'b1;
    @(posedge clk_cpu);
    fa_open_start <= 1'b0;
    guard = 0;
    while (!open_ok_w[0] && !open_err_w[0] && guard < 3_000_000) begin
      @(posedge clk_cpu);
      guard = guard + 1;
    end
    if (!open_ok_w[0]) begin
      $display("TB_RESULT: FAIL (b1) tape open did not complete (oerr=%b)",
               open_err_w[0]);
      $finish;
    end
    repeat (50) @(posedge clk_cpu);  // let busy/size settle
    if (size_bytes_w[31:0] !== TAPE_BYTES[31:0]) begin
      $display("FAIL: (b1) size_bytes %0d (want %0d)", size_bytes_w[31:0], TAPE_BYTES);
      errors = errors + 1;
    end

    // (b2) stream the ENTIRE file byte-by-byte, byte-exact
    for (k = 0; k < TAPE_BYTES; k = k + 1) begin
      f_getb(32'd2_000_000, gok, gd);
      if (!gok) begin
        $display("TB_RESULT: FAIL (b2) full stack stalled at byte %0d", k);
        $finish;
      end
      if (gd !== pat_tape(k)) begin
        if (errors < 10)
          $display("FAIL: (b2) byte %0d: got %02x want %02x", k, gd, pat_tape(k));
        errors = errors + 1;
      end
    end

    // (b3) EOF silence: no byte_valid, no client req, no SDRAM traffic
    f_watch_valids = 0;
    f_watch_reqs   = 0;
    f_watch_mems   = 0;
    f_watch        = 1;
    for (k = 0; k < 3; k = k + 1) begin
      @(posedge clk_cpu);
      fa_byte_req <= 1'b1;
      @(posedge clk_cpu);
      fa_byte_req <= 1'b0;
      repeat (2000) @(posedge clk_cpu);
    end
    f_watch = 0;
    if (f_watch_valids !== 0 || f_watch_reqs !== 0 || f_watch_mems !== 0) begin
      $display("FAIL: (b3) EOF not silent (valid=%0d req=%0d mem=%0d)",
               f_watch_valids, f_watch_reqs, f_watch_mems);
      errors = errors + 1;
    end

    // (b4) rewind, re-read the first 100 bytes
    @(posedge clk_cpu);
    fa_rewind <= 1'b1;
    @(posedge clk_cpu);
    fa_rewind <= 1'b0;
    @(posedge clk_cpu);
    for (k = 0; k < 100; k = k + 1) begin
      f_getb(32'd2_000_000, gok, gd);
      if (!gok) begin
        $display("TB_RESULT: FAIL (b4) rewind re-read stalled at byte %0d", k);
        $finish;
      end
      if (gd !== pat_tape(k)) begin
        if (errors < 10)
          $display("FAIL: (b4) byte %0d after rewind: got %02x want %02x",
                   k, gd, pat_tape(k));
        errors = errors + 1;
      end
    end

    // ---- health ---------------------------------------------------------
    if (card.crc_errors !== 0) begin
      $display("FAIL: CMD CRC7 errors (%0d)", card.crc_errors);
      errors = errors + 1;
    end
    if (card.illegal_writes !== 0) begin
      $display("FAIL: card writes in a read-only tb (%0d)", card.illegal_writes);
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

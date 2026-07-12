/****************************************************************************
** Testbench for nd_storage_floppy_adapter (iverilog) - step 8, spec      **
** acceptance test 6 (floppy through the full stack).                      **
**                                                                         **
** The adapter maps ND_FLOPPY_DMA's disk-image backend port (one logical  **
** SECTOR per disk_req: disk_wr/lsect/format/drive/wordcount ->            **
** disk_done/disk_err + dbuf_addr/wdata/we/rdata, the contract read from   **
** ND-BUS-DEVICES/FLOPPY-DMA/circuit/ND_FLOPPY_DMA.v) onto ONE nd_storage  **
** client port. The disk-port driver below replays the device's observed   **
** handshake (fields registered with the req pulse, done sampled as a      **
** level, combinational dbuf_rdata).                                       **
**                                                                         **
** TWO TIERS in one run:                                                   **
**                                                                         **
** Tier A (unit): adapter vs a SCRIPTED client-port stub serving a 4096-   **
** byte image from a byte array (no SD, no SDRAM), plus a scripted disk-   **
** port driver. A full expectation shadow of the stub image is re-checked  **
** byte-for-byte after every write (RMW preservation proof). Checks:       **
**   (a1) not open: request -> clean done+err, ZERO client traffic         **
**   (a2) open_start -> exactly one c_open_req pulse                       **
**   (a3) full-sector read (fmt 3, 512 w), word-exact, one fetch           **
**   (a4) multi-chunk sequential read: same-block hit (no fetch), next     **
**        block miss (one fetch)                                           **
**   (a5) partial read (wordcount 100 inside a block), word-exact          **
**   (a6) full aligned BLOCK write (wc 1024): direct commit, NO pre-read   **
**   (a7) PARTIAL writes: RMW on a cache miss (pre-read counted) and on a  **
**        cache hit (no pre-read); untouched words preserved (shadow)      **
**   (a8) out-of-range read -> done+err, zero traffic, retry OK            **
**   (a9) step-6 TAIL RULE: size 3001 -> write to the partial tail block   **
**        errs with zero traffic; write to the full block 0 and a read     **
**        ending inside the file still work; a read past EOF errs          **
**   (a10) c_err on the fetch and on the COMMIT -> done+err, cache         **
**        dropped, no wedge, retry succeeds                                **
**   (a11) drive mismatch (DRIVE=0, request for drive 1): TOTAL silence    **
** Tier B (full stack): a second adapter on CLIENT 1 of the real           **
** nd_storage stack (reader + writer + mount + engine + fatchk) with the   **
** behavioral SD card model on nds_storage.img (FLOPPY1.IMG, 4096 B) and   **
** the behavioral mem-port model, skewed clocks. Checks:                   **
**   (b1) open via open_start: open_ok, size 4096                          **
**   (b2) read all four fmt-3 sectors, byte-exact vs the image pattern     **
**   (b3) write one full sector through the disk port; verify the bytes    **
**        LANDED IN THE RIGHT FLOPPY1.IMG CARD SECTORS (card.mem peek at   **
**        first_sector) and read back through the disk port after a        **
**        cache-flushing read of the other block                           **
**   (b4) RMW partial write (fmt 0 sector inside block 1): written region  **
**        exact on the card, neighbors inside the block preserved,         **
**        read-back exact                                                  **
**   (b5) out-of-range -> done+err with ZERO mem-port traffic              **
**   (b6) WHOLE-CARD shadow compare: except the two written regions, all   **
**        4 MB of the card image are byte-identical to the pre-test        **
**        snapshot (catches any stray write anywhere - stronger than       **
**        LEGAL_MIN_SECTOR)                                                **
**   plus card health: CMD CRC7 = 0, data CRC16 = 0                        **
**                                                                         **
** Request pulses are NONBLOCKING one-cycle pulses (repo lesson).          **
** Verdict: TB_RESULT: PASS / TB_RESULT: FAIL <reason>                     **
**                                                                         **
** Last reviewed: 11-JUL-2026                                              **
** Ronny Hansen                                                            **
*****************************************************************************/
`timescale 1ns / 1ps

module nd_storage_floppy_adapter_tb;

  localparam STOR_HALF = 18.5;  // ~27.03 MHz
  localparam CPU_HALF  = 21.7;  // ~23.04 MHz
  localparam N         = 7;

  localparam integer FLP_BYTES   = 4096;  // FLOPPY1.IMG in nds_storage.img
  localparam IMG_BYTES   = 4 * 1024 * 1024;
  localparam IMG_SECTORS = IMG_BYTES / 512;

  reg clk_stor = 0;
  always #STOR_HALF clk_stor = ~clk_stor;
  reg clk_cpu = 0;
  always #CPU_HALF clk_cpu = ~clk_cpu;

  reg rst_n = 0;

  integer errors = 0;

  // MUST match make_storage_image.sh (nds_flp1.bin)
  function [7:0] pat_flp(input integer k);
    pat_flp = ((k % 256) + 29 * ((k / 256) % 256) + 7) % 256;
  endfunction

  // file word w = {byte 2w, byte 2w+1} (big-endian, design doc 4.1)
  function [15:0] fw(input integer w);
    fw = {pat_flp(2 * w), pat_flp(2 * w + 1)};
  endfunction

  // deterministic write patterns (distinct per phase)
  function [15:0] wpatB(input integer w);
    wpatB = 16'h5A00 + w[15:0];
  endfunction
  function [15:0] wpatC(input integer w);
    wpatC = 16'hC300 ^ {w[7:0], w[15:8]};
  endfunction
  function [15:0] wpatD(input integer w);
    wpatD = 16'hD700 + {w[7:0], 1'b1, w[14:8]};
  endfunction
  function [15:0] wpatE(input integer w);
    wpatE = 16'hE100 ^ w[15:0];
  endfunction
  function [15:0] wpatF(input integer w);
    wpatF = 16'hF500 + w[15:0];
  endfunction

  // =====================================================================
  // Tier A: adapter vs scripted client-port stub + scripted disk driver
  // =====================================================================
  reg         ta_req = 0, ta_wr = 0;
  reg  [15:0] ta_lsect = 0;
  reg  [1:0]  ta_fmt = 0, ta_drive = 0;
  reg  [10:0] ta_wc = 0;
  wire        ta_done, ta_err;
  wire [9:0]  ta_dbuf_addr;
  wire [15:0] ta_dbuf_wdata;
  wire        ta_dbuf_we;
  reg         ua_open_start = 0;

  wire        ua_open_req, ua_req, ua_wr;
  wire [15:0] ua_block;
  wire [15:0] ua_buf_rdata;

  reg         u_open_ok = 0;
  reg  [31:0] u_size = FLP_BYTES;
  reg         u_err_inject = 0;   // error EVERY client op
  reg         u_err_on_wr  = 0;   // error only client WRITE ops (the commit)

  reg         u_busy = 0, u_done = 0, u_err = 0, u_bwe = 0;
  reg  [9:0]  u_baddr = 0;
  reg  [15:0] u_bwdata = 0;

  // device sector buffer model (combinational readout, like the device)
  reg [15:0] ta_dev[0:1023];
  wire [15:0] ta_dbuf_rdata = ta_dev[ta_dbuf_addr];

  // capture of the adapter's read serve into the "device buffer"
  reg [15:0] ta_cap[0:1023];
  always @(posedge clk_cpu)
    if (ta_dbuf_we) ta_cap[ta_dbuf_addr] <= ta_dbuf_wdata;

  nd_storage_floppy_adapter #(
      .DRIVE(2'd0)
  ) dut_u (
      .clk_cpu       (clk_cpu),
      .rst_n         (rst_n),
      .disk_req      (ta_req),
      .disk_wr       (ta_wr),
      .disk_lsect    (ta_lsect),
      .disk_format   (ta_fmt),
      .disk_drive    (ta_drive),
      .disk_wordcount(ta_wc),
      .disk_done     (ta_done),
      .disk_err      (ta_err),
      .dbuf_addr     (ta_dbuf_addr),
      .dbuf_wdata    (ta_dbuf_wdata),
      .dbuf_we       (ta_dbuf_we),
      .dbuf_rdata    (ta_dbuf_rdata),
      .open_start    (ua_open_start),
      .c_open_req    (ua_open_req),
      .c_open_ok     (u_open_ok),
      .c_open_err    (1'b0),
      .c_size_bytes  (u_size),
      .c_req         (ua_req),
      .c_wr          (ua_wr),
      .c_block       (ua_block),
      .c_busy        (u_busy),
      .c_done        (u_done),
      .c_err         (u_err),
      .c_buf_addr    (u_baddr),
      .c_buf_wdata   (u_bwdata),
      .c_buf_we      (u_bwe),
      .c_buf_rdata   (ua_buf_rdata)
  );

  // stub image (4096 B) + expectation shadow (updated by the driver on
  // every commanded write; compared byte-for-byte after each write op)
  reg [7:0] u_img[0:FLP_BYTES-1];
  reg [7:0] u_exp[0:FLP_BYTES-1];
  integer ii;
  initial begin
    for (ii = 0; ii < FLP_BYTES; ii = ii + 1) begin
      u_img[ii] = pat_flp(ii);
      u_exp[ii] = pat_flp(ii);
    end
  end

  // scripted client stub: read = stream 1024 big-endian words in;
  // write = pull 1024 words out with the engine's A/B/C address timing
  integer u_fetches = 0;
  integer u_writes  = 0;
  integer u_open_reqs = 0;
  reg [15:0] u_lblk = 0;
  reg        u_iswr = 0;
  integer u_wi = 0, u_dly = 0;
  reg [2:0] u_st = 0;
  reg [1:0] u_ph = 0;

  always @(posedge clk_cpu) begin
    u_done <= 1'b0;
    u_err  <= 1'b0;
    u_bwe  <= 1'b0;
    if (ua_open_req) begin
      u_open_reqs = u_open_reqs + 1;
      u_open_ok <= 1'b1;
    end
    case (u_st)
      3'd0: begin
        if (ua_req) begin
          if (ua_wr) u_writes = u_writes + 1;
          else u_fetches = u_fetches + 1;
          u_lblk <= ua_block;
          u_iswr <= ua_wr;
          u_busy <= 1'b1;
          u_dly  <= 5 + ((u_fetches + u_writes) % 7);
          u_st   <= 3'd1;
        end
      end
      3'd1: begin
        if (u_dly == 0) begin
          if (u_err_inject || (u_err_on_wr && u_iswr)) begin
            u_done <= 1'b1;
            u_err  <= 1'b1;
            u_busy <= 1'b0;
            u_st   <= 3'd0;
          end else if (u_iswr) begin
            u_wi <= 0;
            u_ph <= 2'd0;
            u_st <= 3'd3;
          end else begin
            u_wi <= 0;
            u_st <= 3'd2;
          end
        end else u_dly <= u_dly - 1;
      end
      3'd2: begin  // read: stream the block into the adapter
        if (u_wi < 1024) begin
          u_bwe    <= 1'b1;
          u_baddr  <= u_wi[9:0];
          u_bwdata <= {u_img[u_lblk*2048+2*u_wi], u_img[u_lblk*2048+2*u_wi+1]};
          u_wi     <= u_wi + 1;
        end else begin
          u_done <= 1'b1;
          u_busy <= 1'b0;
          u_st   <= 3'd0;
        end
      end
      3'd3: begin  // write: pull the block from the adapter (A/B/C timing)
        case (u_ph)
          2'd0: begin
            u_baddr <= u_wi[9:0];
            u_ph    <= 2'd1;
          end
          2'd1: u_ph <= 2'd2;
          2'd2: begin
            u_img[u_lblk*2048+2*u_wi]   = ua_buf_rdata[15:8];
            u_img[u_lblk*2048+2*u_wi+1] = ua_buf_rdata[7:0];
            u_ph <= 2'd0;
            if (u_wi == 1023) begin
              u_done <= 1'b1;
              u_busy <= 1'b0;
              u_st   <= 3'd0;
            end else u_wi <= u_wi + 1;
          end
          default: u_ph <= 2'd0;
        endcase
      end
      default: u_st <= 3'd0;
    endcase
  end

  // ---- tier A driver tasks --------------------------------------------
  // fields registered with the req pulse (same as the device engine)
  task a_op(input wr, input [1:0] fmt, input [15:0] lsect, input [10:0] wc,
            input [1:0] drv, input [31:0] max_cycles,
            output reg ok, output reg err);
    integer g;
    begin
      @(posedge clk_cpu);
      ta_wr    <= wr;
      ta_fmt   <= fmt;
      ta_lsect <= lsect;
      ta_wc    <= wc;
      ta_drive <= drv;
      ta_req   <= 1'b1;
      @(posedge clk_cpu);
      ta_req <= 1'b0;
      ok  = 0;
      err = 0;
      g   = 0;
      while (!ok && g < max_cycles) begin
        @(posedge clk_cpu);
        if (ta_done) begin
          ok  = 1;
          err = ta_err;
        end
        g = g + 1;
      end
    end
  endtask

  // record a commanded write into the expectation shadow
  task a_expect_write(input [1:0] fmt, input [15:0] lsect, input [10:0] wc);
    integer w0, w, wps;
    reg [15:0] dv;
    begin
      wps = (fmt == 2'd0) ? 256 : (fmt == 2'd1) ? 128 :
            (fmt == 2'd2) ? 64 : 512;
      w0  = lsect * wps;
      for (w = 0; w < wc; w = w + 1) begin
        dv = ta_dev[w];
        u_exp[2*(w0+w)]   = dv[15:8];
        u_exp[2*(w0+w)+1] = dv[7:0];
      end
    end
  endtask

  // full byte compare of the stub image vs the expectation shadow
  task a_check_img(input integer code);
    integer b;
    begin
      for (b = 0; b < FLP_BYTES; b = b + 1) begin
        if (u_img[b] !== u_exp[b]) begin
          if (errors < 10)
            $display("FAIL: (a%0d) stub image byte %0d: got %02x want %02x",
                     code, b, u_img[b], u_exp[b]);
          errors = errors + 1;
        end
      end
    end
  endtask

  // compare a read capture against the expectation shadow
  task a_check_cap(input [1:0] fmt, input [15:0] lsect, input [10:0] wc,
                   input integer code);
    integer w0, w, wps;
    reg [15:0] want;
    begin
      wps = (fmt == 2'd0) ? 256 : (fmt == 2'd1) ? 128 :
            (fmt == 2'd2) ? 64 : 512;
      w0  = lsect * wps;
      for (w = 0; w < wc; w = w + 1) begin
        want = {u_exp[2*(w0+w)], u_exp[2*(w0+w)+1]};
        if (ta_cap[w] !== want) begin
          if (errors < 10)
            $display("FAIL: (a%0d) capture word %0d: got %04x want %04x",
                     code, w, ta_cap[w], want);
          errors = errors + 1;
        end
      end
    end
  endtask

  // =====================================================================
  // Tier B: adapter on client 1 of the REAL nd_storage stack
  // =====================================================================
  wire        sd1_clk, sd1_cmd_o, sd1_cmd_oe, sd1_dat0_o, sd1_dat0_oe;
  wire        sd1_cmd, sd1_dat0;
  pullup (sd1_cmd);
  pullup (sd1_dat0);
  assign sd1_cmd  = sd1_cmd_oe ? sd1_cmd_o : 1'bz;
  assign sd1_dat0 = sd1_dat0_oe ? sd1_dat0_o : 1'bz;

  wire        mem_start_w, mem_we_w, mem_busy_w, mem_done_w;
  wire [19:0] mem_addr_w;
  wire [31:0] mem_wdata_w, mem_rdata_w;

  reg         fb_req = 0, fb_wr = 0;
  reg  [15:0] fb_lsect = 0;
  reg  [1:0]  fb_fmt = 0, fb_drive = 0;
  reg  [10:0] fb_wc = 0;
  wire        fb_done, fb_err;
  wire [9:0]  fb_dbuf_addr;
  wire [15:0] fb_dbuf_wdata;
  wire        fb_dbuf_we;
  reg         fb_open_start = 0;

  reg [15:0] fb_dev[0:1023];
  wire [15:0] fb_dbuf_rdata = fb_dev[fb_dbuf_addr];

  reg [15:0] fb_cap[0:1023];
  always @(posedge clk_cpu)
    if (fb_dbuf_we) fb_cap[fb_dbuf_addr] <= fb_dbuf_wdata;

  wire        fb_open_req, fb_creq, fb_cwr;
  wire [15:0] fb_block;
  wire [15:0] fb_buf_rdata;

  wire [N-1:0]    open_ok_w, open_err_w, busy_w, done_w, err_w, buf_we_w;
  wire [N*32-1:0] size_bytes_w;
  wire [N*10-1:0] buf_addr_w;
  wire [N*16-1:0] buf_wdata_w;
  wire [1:0]      sd_status_w, card_type_w, fs_type_w;

  nd_storage_floppy_adapter #(
      .DRIVE(2'd0)
  ) dut_f (
      .clk_cpu       (clk_cpu),
      .rst_n         (rst_n),
      .disk_req      (fb_req),
      .disk_wr       (fb_wr),
      .disk_lsect    (fb_lsect),
      .disk_format   (fb_fmt),
      .disk_drive    (fb_drive),
      .disk_wordcount(fb_wc),
      .disk_done     (fb_done),
      .disk_err      (fb_err),
      .dbuf_addr     (fb_dbuf_addr),
      .dbuf_wdata    (fb_dbuf_wdata),
      .dbuf_we       (fb_dbuf_we),
      .dbuf_rdata    (fb_dbuf_rdata),
      .open_start    (fb_open_start),
      .c_open_req    (fb_open_req),
      .c_open_ok     (open_ok_w[1]),
      .c_open_err    (open_err_w[1]),
      .c_size_bytes  (size_bytes_w[63:32]),
      .c_req         (fb_creq),
      .c_wr          (fb_cwr),
      .c_block       (fb_block),
      .c_busy        (busy_w[1]),
      .c_done        (done_w[1]),
      .c_err         (err_w[1]),
      .c_buf_addr    (buf_addr_w[19:10]),
      .c_buf_wdata   (buf_wdata_w[31:16]),
      .c_buf_we      (buf_we_w[1]),
      .c_buf_rdata   (fb_buf_rdata)
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
      .open_req  ({5'd0, fb_open_req, 1'b0}),
      .open_ok   (open_ok_w),
      .open_err  (open_err_w),
      .size_bytes(size_bytes_w),
      .req       ({5'd0, fb_creq, 1'b0}),
      .wr        ({5'd0, fb_cwr, 1'b0}),
      .block     ({80'd0, fb_block, 16'd0}),
      .busy      (busy_w),
      .done      (done_w),
      .err       (err_w),
      .buf_addr  (buf_addr_w),
      .buf_wdata (buf_wdata_w),
      .buf_we    (buf_we_w),
      .buf_rdata ({{5{16'd0}}, fb_buf_rdata, 16'd0}),
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

  // writes ARE legal in this tb (to FLOPPY1.IMG data sectors); the
  // whole-card shadow compare below is the strong stray-write gate
  sd_card_model #(
      .IMAGE           ("nds_storage.img"),
      .MAX_BYTES       (IMG_BYTES),
      .LEGAL_MIN_SECTOR(0)
  ) card (
      .sd_clk (sd1_clk),
      .sd_cmd (sd1_cmd),
      .sd_dat0(sd1_dat0)
  );

  // whole-card snapshot (taken before any tier-B activity)
  reg [7:0] card_shadow[0:IMG_BYTES-1];
  reg [31:0] f_first_sec;

  // sticky monitors for the tier-B out-of-range silence window
  reg f_watch = 0;
  integer f_watch_mems = 0, f_watch_reqs = 0;
  always @(posedge clk_cpu)
    if (f_watch && fb_creq) f_watch_reqs = f_watch_reqs + 1;
  always @(posedge clk_stor)
    if (f_watch && mem_start_w) f_watch_mems = f_watch_mems + 1;

  task b_op(input wr, input [1:0] fmt, input [15:0] lsect, input [10:0] wc,
            input [31:0] max_cycles, output reg ok, output reg err);
    integer g;
    begin
      @(posedge clk_cpu);
      fb_wr    <= wr;
      fb_fmt   <= fmt;
      fb_lsect <= lsect;
      fb_wc    <= wc;
      fb_drive <= 2'd0;
      fb_req   <= 1'b1;
      @(posedge clk_cpu);
      fb_req <= 1'b0;
      ok  = 0;
      err = 0;
      g   = 0;
      while (!ok && g < max_cycles) begin
        @(posedge clk_cpu);
        if (fb_done) begin
          ok  = 1;
          err = fb_err;
        end
        g = g + 1;
      end
    end
  endtask

  // =====================================================================
  // test sequence
  // =====================================================================
  integer k, f0, w0, b;
  reg gok, gerr;
  reg [7:0] expb;
  integer shadow_diffs;

  initial begin
`ifdef DUMPFILE
    $dumpfile("nd_storage_floppy_adapter_tb.vcd");
    $dumpvars(0, nd_storage_floppy_adapter_tb);
`endif
    repeat (10) @(posedge clk_stor);
    rst_n = 1;
    repeat (20) @(posedge clk_cpu);

    // ---- Tier A ---------------------------------------------------------

    // (a1) not open: read request -> clean done+err, zero client traffic
    a_op(1'b0, 2'd3, 16'd0, 11'd512, 2'd0, 32'd2000, gok, gerr);
    if (!gok || !gerr) begin
      $display("FAIL: (a1) not-open request (ok=%b err=%b)", gok, gerr);
      errors = errors + 1;
    end
    if (u_fetches !== 0 || u_writes !== 0) begin
      $display("FAIL: (a1) client traffic before open (%0d/%0d)",
               u_fetches, u_writes);
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

    // (a3) full-sector read: fmt 3 (512 w) lsect 0, one fetch
    a_op(1'b0, 2'd3, 16'd0, 11'd512, 2'd0, 32'd20000, gok, gerr);
    if (!gok || gerr) begin
      $display("TB_RESULT: FAIL (a3) read did not complete (ok=%b err=%b)", gok, gerr);
      $finish;
    end
    a_check_cap(2'd3, 16'd0, 11'd512, 3);
    if (u_fetches !== 1) begin
      $display("FAIL: (a3) fetch count %0d (want 1)", u_fetches);
      errors = errors + 1;
    end

    // (a4) multi-chunk sequential: lsect 1 = same block (hit), lsect 2/3 =
    // block 1 (one more fetch)
    a_op(1'b0, 2'd3, 16'd1, 11'd512, 2'd0, 32'd20000, gok, gerr);
    if (!gok || gerr) begin
      $display("FAIL: (a4) lsect 1 read (ok=%b err=%b)", gok, gerr);
      errors = errors + 1;
    end
    a_check_cap(2'd3, 16'd1, 11'd512, 4);
    if (u_fetches !== 1) begin
      $display("FAIL: (a4) same-block read refetched (%0d)", u_fetches);
      errors = errors + 1;
    end
    a_op(1'b0, 2'd3, 16'd2, 11'd512, 2'd0, 32'd20000, gok, gerr);
    a_check_cap(2'd3, 16'd2, 11'd512, 4);
    a_op(1'b0, 2'd3, 16'd3, 11'd512, 2'd0, 32'd20000, gok, gerr);
    if (!gok || gerr) begin
      $display("FAIL: (a4) lsect 3 read (ok=%b err=%b)", gok, gerr);
      errors = errors + 1;
    end
    a_check_cap(2'd3, 16'd3, 11'd512, 4);
    if (u_fetches !== 2) begin
      $display("FAIL: (a4) fetch count %0d (want 2)", u_fetches);
      errors = errors + 1;
    end

    // (a5) partial read: fmt 0 lsect 1 (block 0, word offset 256), 100 words
    // (cache holds block 1 now -> one refetch)
    a_op(1'b0, 2'd0, 16'd1, 11'd100, 2'd0, 32'd20000, gok, gerr);
    if (!gok || gerr) begin
      $display("FAIL: (a5) partial read (ok=%b err=%b)", gok, gerr);
      errors = errors + 1;
    end
    a_check_cap(2'd0, 16'd1, 11'd100, 5);
    if (u_fetches !== 3) begin
      $display("FAIL: (a5) fetch count %0d (want 3)", u_fetches);
      errors = errors + 1;
    end

    // (a6) full aligned BLOCK write (wc 1024, fmt 3 lsect 0 -> block 0,
    // offset 0): direct commit, NO pre-read
    for (k = 0; k < 1024; k = k + 1) ta_dev[k] = wpatB(k);
    f0 = u_fetches;
    a_expect_write(2'd3, 16'd0, 11'd1024);
    a_op(1'b1, 2'd3, 16'd0, 11'd1024, 2'd0, 32'd30000, gok, gerr);
    if (!gok || gerr) begin
      $display("TB_RESULT: FAIL (a6) full-block write (ok=%b err=%b)", gok, gerr);
      $finish;
    end
    if (u_fetches !== f0) begin
      $display("FAIL: (a6) full-block write issued a pre-read (%0d)",
               u_fetches - f0);
      errors = errors + 1;
    end
    if (u_writes !== 1) begin
      $display("FAIL: (a6) write count %0d (want 1)", u_writes);
      errors = errors + 1;
    end
    a_check_img(6);

    // (a7) PARTIAL write, cache MISS (cache = block 0 after a6): fmt 3
    // lsect 3 -> block 1 offset 512 -> RMW pre-read + commit
    for (k = 0; k < 512; k = k + 1) ta_dev[k] = wpatC(k);
    f0 = u_fetches;
    a_expect_write(2'd3, 16'd3, 11'd512);
    a_op(1'b1, 2'd3, 16'd3, 11'd512, 2'd0, 32'd30000, gok, gerr);
    if (!gok || gerr) begin
      $display("TB_RESULT: FAIL (a7) RMW-miss write (ok=%b err=%b)", gok, gerr);
      $finish;
    end
    if (u_fetches !== f0 + 1) begin
      $display("FAIL: (a7) RMW miss pre-read count (%0d)", u_fetches - f0);
      errors = errors + 1;
    end
    a_check_img(7);
    // PARTIAL write, cache HIT (cache = block 1 now): fmt 3 lsect 2 ->
    // block 1 offset 0 -> overlay only, no pre-read
    for (k = 0; k < 512; k = k + 1) ta_dev[k] = wpatD(k);
    f0 = u_fetches;
    a_expect_write(2'd3, 16'd2, 11'd512);
    a_op(1'b1, 2'd3, 16'd2, 11'd512, 2'd0, 32'd30000, gok, gerr);
    if (!gok || gerr) begin
      $display("TB_RESULT: FAIL (a7) RMW-hit write (ok=%b err=%b)", gok, gerr);
      $finish;
    end
    if (u_fetches !== f0) begin
      $display("FAIL: (a7) RMW hit issued a pre-read (%0d)", u_fetches - f0);
      errors = errors + 1;
    end
    a_check_img(7);
    if (u_writes !== 3) begin
      $display("FAIL: (a7) write count %0d (want 3)", u_writes);
      errors = errors + 1;
    end

    // (a8) out-of-range read (fmt 3 lsect 4 ends at byte 5120 > 4096):
    // clean done+err, zero traffic, retry OK
    f0 = u_fetches;
    a_op(1'b0, 2'd3, 16'd4, 11'd512, 2'd0, 32'd2000, gok, gerr);
    if (!gok || !gerr) begin
      $display("FAIL: (a8) out-of-range read (ok=%b err=%b)", gok, gerr);
      errors = errors + 1;
    end
    if (u_fetches !== f0) begin
      $display("FAIL: (a8) out-of-range caused traffic");
      errors = errors + 1;
    end
    a_op(1'b0, 2'd3, 16'd0, 11'd512, 2'd0, 32'd20000, gok, gerr);
    if (!gok || gerr) begin
      $display("FAIL: (a8) retry after OOR (ok=%b err=%b)", gok, gerr);
      errors = errors + 1;
    end
    a_check_cap(2'd3, 16'd0, 11'd512, 8);

    // (a9) step-6 TAIL RULE: shrink the file to 3001 bytes (NOT a 2048
    // multiple). Writes touching the partial tail block 1 must ERR with
    // zero traffic; block 0 stays writable; reads ending inside the file
    // still work; reads past EOF err.
    u_size = 32'd3001;
    f0 = u_fetches;
    k  = u_writes;
    a_op(1'b1, 2'd3, 16'd2, 11'd512, 2'd0, 32'd2000, gok, gerr);
    if (!gok || !gerr) begin
      $display("FAIL: (a9) tail-block write not refused (ok=%b err=%b)", gok, gerr);
      errors = errors + 1;
    end
    if (u_fetches !== f0 || u_writes !== k) begin
      $display("FAIL: (a9) tail-block write caused traffic");
      errors = errors + 1;
    end
    for (b = 0; b < 256; b = b + 1) ta_dev[b] = wpatE(b);
    a_expect_write(2'd0, 16'd0, 11'd256);
    a_op(1'b1, 2'd0, 16'd0, 11'd256, 2'd0, 32'd30000, gok, gerr);
    if (!gok || gerr) begin
      $display("FAIL: (a9) full-block-0 write refused (ok=%b err=%b)", gok, gerr);
      errors = errors + 1;
    end
    a_check_img(9);
    a_op(1'b0, 2'd3, 16'd3, 11'd512, 2'd0, 32'd2000, gok, gerr);
    if (!gok || !gerr) begin
      $display("FAIL: (a9) read past EOF not refused (ok=%b err=%b)", gok, gerr);
      errors = errors + 1;
    end
    a_op(1'b0, 2'd0, 16'd4, 11'd256, 2'd0, 32'd20000, gok, gerr);
    if (!gok || gerr) begin
      $display("FAIL: (a9) in-range read near EOF refused (ok=%b err=%b)", gok, gerr);
      errors = errors + 1;
    end
    a_check_cap(2'd0, 16'd4, 11'd256, 9);
    u_size = FLP_BYTES;

    // (a10) c_err on the FETCH: done+err, cache dropped, retry succeeds
    u_err_inject = 1;
    f0 = u_fetches;
    a_op(1'b0, 2'd3, 16'd0, 11'd512, 2'd0, 32'd20000, gok, gerr);
    if (!gok || !gerr) begin
      $display("FAIL: (a10) fetch c_err not reported (ok=%b err=%b)", gok, gerr);
      errors = errors + 1;
    end
    if (u_fetches !== f0 + 1) begin
      $display("FAIL: (a10) errored fetch not attempted");
      errors = errors + 1;
    end
    u_err_inject = 0;
    a_op(1'b0, 2'd3, 16'd0, 11'd512, 2'd0, 32'd20000, gok, gerr);
    if (!gok || gerr) begin
      $display("FAIL: (a10) retry after fetch c_err (ok=%b err=%b)", gok, gerr);
      errors = errors + 1;
    end
    a_check_cap(2'd3, 16'd0, 11'd512, 10);
    // c_err on the COMMIT only (cache-hit overlay path): done+err, cache
    // dropped; the retry re-fetches (RMW) and succeeds
    u_err_on_wr = 1;
    for (k = 0; k < 512; k = k + 1) ta_dev[k] = wpatF(k);
    a_op(1'b1, 2'd3, 16'd1, 11'd512, 2'd0, 32'd30000, gok, gerr);
    if (!gok || !gerr) begin
      $display("FAIL: (a10) commit c_err not reported (ok=%b err=%b)", gok, gerr);
      errors = errors + 1;
    end
    a_check_img(10);  // failed commit must not have changed the stub image
    u_err_on_wr = 0;
    f0 = u_fetches;
    a_expect_write(2'd3, 16'd1, 11'd512);
    a_op(1'b1, 2'd3, 16'd1, 11'd512, 2'd0, 32'd30000, gok, gerr);
    if (!gok || gerr) begin
      $display("FAIL: (a10) retry after commit c_err (ok=%b err=%b)", gok, gerr);
      errors = errors + 1;
    end
    if (u_fetches !== f0 + 1) begin
      $display("FAIL: (a10) retry did not re-fetch after dropped cache (%0d)",
               u_fetches - f0);
      errors = errors + 1;
    end
    a_check_img(10);

    // (a11) drive mismatch: DRIVE=0 adapter must be TOTALLY silent for a
    // drive-1 request (in a 2-drive system the other instance answers)
    f0 = u_fetches;
    k  = u_writes;
    a_op(1'b0, 2'd3, 16'd0, 11'd512, 2'd1, 32'd400, gok, gerr);
    if (gok) begin
      $display("FAIL: (a11) adapter answered a drive-1 request");
      errors = errors + 1;
    end
    if (u_fetches !== f0 || u_writes !== k) begin
      $display("FAIL: (a11) drive-1 request caused traffic");
      errors = errors + 1;
    end
    a_op(1'b0, 2'd3, 16'd0, 11'd512, 2'd0, 32'd20000, gok, gerr);
    if (!gok || gerr) begin
      $display("FAIL: (a11) drive-0 request after mismatch (ok=%b err=%b)",
               gok, gerr);
      errors = errors + 1;
    end

    $display("tier A (unit stub) done: %0d errors, %0d fetches, %0d writes",
             errors, u_fetches, u_writes);

    // ---- Tier B ---------------------------------------------------------

    // whole-card snapshot BEFORE any tier-B activity
    for (k = 0; k < IMG_BYTES; k = k + 1) card_shadow[k] = card.mem[k];

    // (b1) open FLOPPY1.IMG (client 1) through the adapter's open_start
    @(posedge clk_cpu);
    fb_open_start <= 1'b1;
    @(posedge clk_cpu);
    fb_open_start <= 1'b0;
    k = 0;
    while (!open_ok_w[1] && !open_err_w[1] && k < 3_000_000) begin
      @(posedge clk_cpu);
      k = k + 1;
    end
    if (!open_ok_w[1]) begin
      $display("TB_RESULT: FAIL (b1) floppy open did not complete (oerr=%b)",
               open_err_w[1]);
      $finish;
    end
    repeat (50) @(posedge clk_cpu);
    if (size_bytes_w[63:32] !== FLP_BYTES[31:0]) begin
      $display("FAIL: (b1) size_bytes %0d (want %0d)",
               size_bytes_w[63:32], FLP_BYTES);
      errors = errors + 1;
    end
    f_first_sec = dut_s.s_first_sector[63:32];
    $display("[tb] FLOPPY1.IMG first card sector = %0d", f_first_sec);

    // (b2) read all four fmt-3 sectors, byte-exact vs the image pattern
    for (k = 0; k < 4; k = k + 1) begin
      b_op(1'b0, 2'd3, k, 11'd512, 32'd3_000_000, gok, gerr);
      if (!gok || gerr) begin
        $display("TB_RESULT: FAIL (b2) read lsect %0d (ok=%b err=%b)",
                 k, gok, gerr);
        $finish;
      end
      w0 = k * 512;
      for (b = 0; b < 512; b = b + 1) begin
        if (fb_cap[b] !== fw(w0 + b)) begin
          if (errors < 10)
            $display("FAIL: (b2) lsect %0d word %0d: got %04x want %04x",
                     k, b, fb_cap[b], fw(w0 + b));
          errors = errors + 1;
        end
      end
    end

    // (b3) write fmt-3 lsect 1 (block 0, words 512..1023) through the
    // disk port; verify the card bytes at first_sector, then read back
    // after a cache-flushing read of block 1
    for (k = 0; k < 512; k = k + 1) fb_dev[k] = wpatB(k);
    b_op(1'b1, 2'd3, 16'd1, 11'd512, 32'd6_000_000, gok, gerr);
    if (!gok || gerr) begin
      $display("TB_RESULT: FAIL (b3) full-stack write (ok=%b err=%b)", gok, gerr);
      $finish;
    end
    // card check: file bytes 1024..2047 = card sectors first_sec+2/+3
    for (k = 0; k < 1024; k = k + 1) begin
      expb = (k % 2 == 0) ? wpatB(k / 2) >> 8 : wpatB(k / 2) & 8'hFF;
      if (card.mem[(f_first_sec+2)*512+k] !== expb) begin
        if (errors < 10)
          $display("FAIL: (b3) card byte %0d of the written region: got %02x want %02x",
                   k, card.mem[(f_first_sec+2)*512+k], expb);
        errors = errors + 1;
      end
    end
    // read-back through the disk port: flush the cache with block 1 first
    b_op(1'b0, 2'd3, 16'd2, 11'd512, 32'd3_000_000, gok, gerr);
    if (!gok || gerr) begin
      $display("FAIL: (b3) flush read (ok=%b err=%b)", gok, gerr);
      errors = errors + 1;
    end
    b_op(1'b0, 2'd3, 16'd1, 11'd512, 32'd3_000_000, gok, gerr);
    if (!gok || gerr) begin
      $display("FAIL: (b3) read-back (ok=%b err=%b)", gok, gerr);
      errors = errors + 1;
    end
    for (b = 0; b < 512; b = b + 1) begin
      if (fb_cap[b] !== wpatB(b)) begin
        if (errors < 10)
          $display("FAIL: (b3) read-back word %0d: got %04x want %04x",
                   b, fb_cap[b], wpatB(b));
        errors = errors + 1;
      end
    end
    // block 0's first half must be untouched
    b_op(1'b0, 2'd3, 16'd0, 11'd512, 32'd3_000_000, gok, gerr);
    for (b = 0; b < 512; b = b + 1) begin
      if (fb_cap[b] !== fw(b)) begin
        if (errors < 10)
          $display("FAIL: (b3) untouched word %0d changed: got %04x want %04x",
                   b, fb_cap[b], fw(b));
        errors = errors + 1;
      end
    end

    // (b4) RMW partial write: fmt 0 lsect 5 (block 1, words 256..511 of
    // the block = file words 1280..1535 = card sector first_sec+5)
    for (k = 0; k < 256; k = k + 1) fb_dev[k] = wpatC(k);
    b_op(1'b1, 2'd0, 16'd5, 11'd256, 32'd6_000_000, gok, gerr);
    if (!gok || gerr) begin
      $display("TB_RESULT: FAIL (b4) RMW write (ok=%b err=%b)", gok, gerr);
      $finish;
    end
    for (k = 0; k < 512; k = k + 1) begin
      expb = (k % 2 == 0) ? wpatC(k / 2) >> 8 : wpatC(k / 2) & 8'hFF;
      if (card.mem[(f_first_sec+5)*512+k] !== expb) begin
        if (errors < 10)
          $display("FAIL: (b4) card byte %0d of the RMW region: got %02x want %02x",
                   k, card.mem[(f_first_sec+5)*512+k], expb);
        errors = errors + 1;
      end
    end
    // read-back: flush with block 0, then fmt-3 lsect 2 covers file words
    // 1024..1535 (first 256 untouched, last 256 = the RMW data)
    b_op(1'b0, 2'd3, 16'd0, 11'd512, 32'd3_000_000, gok, gerr);
    b_op(1'b0, 2'd3, 16'd2, 11'd512, 32'd3_000_000, gok, gerr);
    if (!gok || gerr) begin
      $display("FAIL: (b4) read-back (ok=%b err=%b)", gok, gerr);
      errors = errors + 1;
    end
    for (b = 0; b < 256; b = b + 1) begin
      if (fb_cap[b] !== fw(1024 + b)) begin
        if (errors < 10)
          $display("FAIL: (b4) preserved word %0d: got %04x want %04x",
                   b, fb_cap[b], fw(1024 + b));
        errors = errors + 1;
      end
      if (fb_cap[256+b] !== wpatC(b)) begin
        if (errors < 10)
          $display("FAIL: (b4) RMW word %0d: got %04x want %04x",
                   b, fb_cap[256+b], wpatC(b));
        errors = errors + 1;
      end
    end

    // (b5) out-of-range through the full stack: done+err, zero traffic
    f_watch_mems = 0;
    f_watch_reqs = 0;
    f_watch = 1;
    b_op(1'b0, 2'd3, 16'd4, 11'd512, 32'd2000, gok, gerr);
    if (!gok || !gerr) begin
      $display("FAIL: (b5) out-of-range read (ok=%b err=%b)", gok, gerr);
      errors = errors + 1;
    end
    b_op(1'b1, 2'd3, 16'd4, 11'd512, 32'd2000, gok, gerr);
    if (!gok || !gerr) begin
      $display("FAIL: (b5) out-of-range write (ok=%b err=%b)", gok, gerr);
      errors = errors + 1;
    end
    f_watch = 0;
    if (f_watch_reqs !== 0 || f_watch_mems !== 0) begin
      $display("FAIL: (b5) out-of-range not silent (req=%0d mem=%0d)",
               f_watch_reqs, f_watch_mems);
      errors = errors + 1;
    end

    // (b6) whole-card shadow compare: ONLY the two written regions may
    // differ from the pre-test snapshot
    shadow_diffs = 0;
    for (k = 0; k < IMG_BYTES; k = k + 1) begin
      if (k >= (f_first_sec + 2) * 512 && k < (f_first_sec + 4) * 512) begin
        b    = k - (f_first_sec + 2) * 512;
        expb = (b % 2 == 0) ? wpatB(b / 2) >> 8 : wpatB(b / 2) & 8'hFF;
      end else if (k >= (f_first_sec + 5) * 512 && k < (f_first_sec + 6) * 512) begin
        b    = k - (f_first_sec + 5) * 512;
        expb = (b % 2 == 0) ? wpatC(b / 2) >> 8 : wpatC(b / 2) & 8'hFF;
      end else begin
        expb = card_shadow[k];
      end
      if (card.mem[k] !== expb) begin
        if (shadow_diffs < 10)
          $display("FAIL: (b6) card byte %0d (sector %0d): got %02x want %02x",
                   k, k / 512, card.mem[k], expb);
        shadow_diffs = shadow_diffs + 1;
      end
    end
    if (shadow_diffs !== 0) begin
      $display("FAIL: (b6) %0d stray card bytes changed", shadow_diffs);
      errors = errors + 1;
    end

    // ---- health ---------------------------------------------------------
    if (card.crc_errors !== 0) begin
      $display("FAIL: CMD CRC7 errors (%0d)", card.crc_errors);
      errors = errors + 1;
    end
    if (card.wr_crc_errors !== 0) begin
      $display("FAIL: data CRC16 errors (%0d)", card.wr_crc_errors);
      errors = errors + 1;
    end

    if (errors == 0) $display("TB_RESULT: PASS");
    else $display("TB_RESULT: FAIL %0d errors", errors);
    $finish;
  end

  initial begin
    #300_000_000;  // 300 ms absolute watchdog
    $display("TB_RESULT: FAIL absolute watchdog");
    $finish;
  end

endmodule

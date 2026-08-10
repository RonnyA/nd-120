`include "nd_storage_status.vh"
/****************************************************************************
** Testbench for nd_storage_disc_adapter (iverilog)                         **
**                                                                         **
** The adapter maps ND_SMD's disk-image backend port (chunk transfers:     **
** disk_start latches the base position from the CYLINDER/HEAD/SECTOR      **
** address as ((cyl*5 + head)*18 + sector) * 512 words - a 1024-byte       **
** sector is 512 words and a cylinder is 46080 words, so positions are     **
** SECTOR-granular. The old blkaddr2*2048 + blkaddr1*64 map agreed with    **
** this only at block 0 and allowed 64-word positions no real drive can    **
** address. Each disk_req then moves one chunk of disk_wordcount words     **
** and the position advances linearly - the contract read from             **
** ND-BUS-DEVICES/SMD/circuit/ND_SMD.v and identical to BOTH existing      **
** backends: the unit tb model and simDevices/NDBus.cpp) onto ONE          **
** nd_storage client port, ZERO-BSRAM stream-through style: reads          **
** forward the engine's block stream into the device buffer (a chunk may   **
** span two blocks); writes accept FULL ALIGNED BLOCKS only and serve      **
** the engine's pull straight from the device buffer (whose readout is     **
** REGISTERED, as in the sync-read ND_SMD buffer - modeled that way        **
** here).                                                                  **
**                                                                         **
** TWO TIERS in one run:                                                   **
**                                                                         **
** Tier A (unit): adapter vs a SCRIPTED client-port stub serving a 4096-   **
** byte image from a byte array (no SD, no SDRAM). Checks:                 **
**   (a1) not open: request -> clean done+err, ZERO client traffic         **
**   (a2) open_start -> exactly one c_open_req pulse                       **
**   (a3) boot-shape read: disk_start+disk_req SAME cycle, base 0,         **
**        wc 1024 -> block 0 word-exact, one fetch                         **
**   (a4) continuation chunk (req only, no start) -> block 1, one fetch    **
**   (a5) block-SPANNING read: base sector 1 (word 512), wc 1024 ->        **
**        two fetches, word-exact across the boundary                      **
**   (a6) partial mid-block read: base sector 1 (word 512), wc 100         **
**   (a7) aligned full-block write (base word 1024, wc 1024): ONE          **
**        client write, NO pre-read, image shadow exact                    **
**   (a8) multi-chunk aligned write (base 0: chunk 1024 + chunk 1024):     **
**        two client writes, whole image shadow exact                      **
**   (a9) UNALIGNED write (base word 512) and PARTIAL write (wc 512)       **
**        refused: done+err, zero client traffic                           **
**   (a10) out-of-range read refused with zero traffic; a read ending      **
**        exactly at EOF works                                             **
**   (a11) c_err on the fetch and on the COMMIT -> done+err, retry OK      **
**   (a12) unit mismatch (UNIT=0, request for unit 1): TOTAL silence       **
**   (a13) wc=0 -> clean done, zero traffic                                **
** Tier B (full stack): a second adapter on CLIENT 1 of the real           **
** nd_storage stack (reader + writer + mount + engine + fatchk) with the   **
** behavioral SD card model on nds_storage.img (FLOPPY1.IMG, 4096 B,       **
** reused as the SMD image - the adapter is file-name-agnostic) and the    **
** behavioral mem-port model, skewed clocks. Checks:                       **
**   (b1) open via open_start: open_ok, size 4096                          **
**   (b2) boot-shape read chunk + continuation chunk, byte-exact vs the    **
**        image pattern                                                    **
**   (b3) block-spanning read (base sector 1 = word 512, wc 1024)          **
**   (b4) aligned full-block write to block 1: bytes LANDED IN THE RIGHT   **
**        CARD SECTORS (card.mem peek at first_sector+4..5), read-back     **
**        through the disk port exact, block 0 preserved                   **
**   (b5) unaligned write refused with ZERO c_req/mem-port traffic         **
**   (b6) WHOLE-CARD shadow compare: except the one written block, all     **
**        4 MB of the card image are byte-identical to the pre-test        **
**        snapshot                                                         **
**   plus card health: CMD CRC7 = 0, data CRC16 = 0                        **
**                                                                         **
** Request pulses are NONBLOCKING one-cycle pulses (repo lesson).          **
** Verdict: TB_RESULT: PASS / TB_RESULT: FAIL <reason>                     **
**                                                                         **
** Last reviewed: 31-JUL-2026                                              **
** Ronny Hansen                                                            **
*****************************************************************************/
`timescale 1ns / 1ps

module nd_storage_disc_adapter_tb;

  localparam STOR_HALF = 18.5;  // ~27.03 MHz
  localparam CPU_HALF  = 21.7;  // ~23.04 MHz
  localparam N         = 7;

  localparam integer IMG_FILE_BYTES = 4096;  // FLOPPY1.IMG in nds_storage.img
  localparam IMG_BYTES   = 4 * 1024 * 1024;

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

  // =====================================================================
  // Tier A: adapter vs scripted client-port stub + scripted disk driver
  // =====================================================================
  reg         ta_start = 0, ta_req = 0, ta_wr = 0;
  reg  [15:0] ta_blk1 = 0, ta_blk2 = 0;
  reg  [2:0]  ta_unit = 0;
  reg  [10:0] ta_wc = 0;
  wire        ta_done, ta_err;
  wire [ 3:0] ta_code;              // WHY, from nd_storage_status.vh
  wire [9:0]  ta_dbuf_addr;
  wire [15:0] ta_dbuf_wdata;
  wire        ta_dbuf_we;
  reg         ua_open_start = 0;

  wire        ua_open_req, ua_req, ua_wr;
  wire [15:0] ua_block;
  wire [15:0] ua_buf_rdata;

  reg         u_open_ok = 0;
  reg  [31:0] u_size = IMG_FILE_BYTES;
  reg         u_err_inject = 0;   // error EVERY client op
  reg         u_err_on_wr  = 0;   // error only client WRITE ops (the commit)

  reg         u_busy = 0, u_done = 0, u_err = 0, u_bwe = 0;
  // The reason the scripted client reports with u_err. The adapter must
  // hand it to the controller UNCHANGED - a failure inside nd_storage must
  // not be flattened into the adapter's own generic verdict.
  reg  [ 3:0] u_err_code = `NDS_ERR_CARDIO;
  reg  [9:0]  u_baddr = 0;
  reg  [15:0] u_bwdata = 0;

  // device buffer model: REGISTERED readout, like ND_SMD's sync-read BSRAM
  reg [15:0] ta_dev[0:1023];
  reg [15:0] ta_dbuf_rdata;
  always @(posedge clk_cpu) ta_dbuf_rdata <= ta_dev[ta_dbuf_addr];

  // capture of the adapter's read serve into the "device buffer"
  reg [15:0] ta_cap[0:1023];
  always @(posedge clk_cpu)
    if (ta_dbuf_we) ta_cap[ta_dbuf_addr] <= ta_dbuf_wdata;

  nd_storage_disc_adapter #(
      .UNIT(3'd0)
  ) dut_u (
      .clk_cpu       (clk_cpu),
      .rst_n         (rst_n),
      .disk_start    (ta_start),
      .disk_req      (ta_req),
      .disk_wr       (ta_wr),
      .disk_blkaddr1 (ta_blk1),
      .disk_blkaddr2 (ta_blk2),
      .disk_unit     (ta_unit),
      .disk_wordcount(ta_wc),
      .disk_done     (ta_done),
      .disk_err      (ta_err),
      .disk_err_code (ta_code),
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
      .c_err_code    (u_err_code),
      .c_buf_addr    (u_baddr),
      .c_buf_wdata   (u_bwdata),
      .c_buf_we      (u_bwe),
      .c_buf_rdata   (ua_buf_rdata)
  );

  // stub image (4096 B) + expectation shadow
  reg [7:0] u_img[0:IMG_FILE_BYTES-1];
  reg [7:0] u_exp[0:IMG_FILE_BYTES-1];
  integer ii;
  initial begin
    for (ii = 0; ii < IMG_FILE_BYTES; ii = ii + 1) begin
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
  // one chunk request; with_start replays the boot/M0 pattern where
  // disk_start and disk_req pulse in the SAME cycle
  task a_op(input with_start, input wr, input [15:0] blk1, input [15:0] blk2,
            input [10:0] wc, input [2:0] unit, input [31:0] max_cycles,
            output reg ok, output reg err);
    integer g;
    begin
      @(posedge clk_cpu);
      ta_wr    <= wr;
      ta_blk1  <= blk1;
      ta_blk2  <= blk2;
      ta_wc    <= wc;
      ta_unit  <= unit;
      ta_req   <= 1'b1;
      ta_start <= with_start;
      @(posedge clk_cpu);
      ta_req   <= 1'b0;
      ta_start <= 1'b0;
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

  // start-only pulse (the M1 write pattern: GO pulses disk_start alone,
  // the first disk_req follows after the memory fill)
  task a_start(input [15:0] blk1, input [15:0] blk2, input [2:0] unit);
    begin
      @(posedge clk_cpu);
      ta_blk1  <= blk1;
      ta_blk2  <= blk2;
      ta_unit  <= unit;
      ta_start <= 1'b1;
      @(posedge clk_cpu);
      ta_start <= 1'b0;
    end
  endtask

  // record a commanded write into the expectation shadow (chunk at word
  // position w0, wc words from the device buffer)
  task a_expect_write(input integer w0, input [10:0] wc);
    integer w;
    reg [15:0] dv;
    begin
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
      for (b = 0; b < IMG_FILE_BYTES; b = b + 1) begin
        if (u_img[b] !== u_exp[b]) begin
          if (errors < 10)
            $display("FAIL: (a%0d) stub image byte %0d: got %02x want %02x",
                     code, b, u_img[b], u_exp[b]);
          errors = errors + 1;
        end
      end
    end
  endtask

  // compare a read capture (chunk starting at word position w0, wc words)
  // against the expectation shadow
  task a_check_cap(input integer w0, input [10:0] wc, input integer code);
    integer w;
    reg [15:0] want;
    begin
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
  wire        cm_cmd_o, cm_cmd_oe, cm_dat0_o, cm_dat0_oe;
  wire        sd1_cmd  = sd1_cmd_oe  ? sd1_cmd_o  : (cm_cmd_oe  ? cm_cmd_o  : 1'b1);
  wire        sd1_dat0 = sd1_dat0_oe ? sd1_dat0_o : (cm_dat0_oe ? cm_dat0_o : 1'b1);

  wire        mem_start_w, mem_we_w, mem_busy_w, mem_done_w;
  wire [19:0] mem_addr_w;
  wire [31:0] mem_wdata_w, mem_rdata_w;

  reg         fb_start = 0, fb_req = 0, fb_wr = 0;
  reg  [15:0] fb_blk1 = 0, fb_blk2 = 0;
  reg  [2:0]  fb_unit = 0;
  reg  [10:0] fb_wc = 0;
  wire        fb_done, fb_err;
  wire [ 3:0] fb_code;
  wire [9:0]  fb_dbuf_addr;
  wire [15:0] fb_dbuf_wdata;
  wire        fb_dbuf_we;
  reg         fb_open_start = 0;

  // device buffer model, registered readout (ND_SMD sync-read style)
  reg [15:0] fb_dev[0:1023];
  reg [15:0] fb_dbuf_rdata;
  always @(posedge clk_cpu) fb_dbuf_rdata <= fb_dev[fb_dbuf_addr];

  reg [15:0] fb_cap[0:1023];
  always @(posedge clk_cpu)
    if (fb_dbuf_we) fb_cap[fb_dbuf_addr] <= fb_dbuf_wdata;

  wire        fb_open_req, fb_creq, fb_cwr;
  wire [15:0] fb_block;
  wire [15:0] fb_buf_rdata;

  wire [N-1:0]    open_ok_w, open_err_w, busy_w, done_w, err_w, buf_we_w;
  wire [N*4-1:0]  err_code_w;
  wire [N*32-1:0] size_bytes_w;
  wire [N*10-1:0] buf_addr_w;
  wire [N*16-1:0] buf_wdata_w;
  wire [1:0]      sd_status_w, card_type_w, fs_type_w;

  nd_storage_disc_adapter #(
      .UNIT(3'd0)
  ) dut_f (
      .clk_cpu       (clk_cpu),
      .rst_n         (rst_n),
      .disk_start    (fb_start),
      .disk_req      (fb_req),
      .disk_wr       (fb_wr),
      .disk_blkaddr1 (fb_blk1),
      .disk_blkaddr2 (fb_blk2),
      .disk_unit     (fb_unit),
      .disk_wordcount(fb_wc),
      .disk_done     (fb_done),
      .disk_err      (fb_err),
      .disk_err_code (fb_code),
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
      .c_err_code    (err_code_w[7:4]),
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
      .err_code  (err_code_w),
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

  sd_card_model #(
      .IMAGE           ("nds_storage.img"),
      .MAX_BYTES       (IMG_BYTES),
      .LEGAL_MIN_SECTOR(0)
  ) card (
      .sd_clk   (sd1_clk),
      .sd_cmd_i (sd1_cmd),  .sd_cmd_o (cm_cmd_o),  .sd_cmd_oe (cm_cmd_oe),
      .sd_dat0_i(sd1_dat0), .sd_dat0_o(cm_dat0_o), .sd_dat0_oe(cm_dat0_oe),
      .sd_dat1_i(1'b1), .sd_dat1_o(), .sd_dat1_oe(),
      .sd_dat2_i(1'b1), .sd_dat2_o(), .sd_dat2_oe(),
      .sd_dat3_i(1'b1), .sd_dat3_o(), .sd_dat3_oe()
  );

  // whole-card snapshot (taken before any tier-B activity)
  reg [7:0] card_shadow[0:IMG_BYTES-1];
  reg [31:0] f_first_sec;

  // sticky monitors for the tier-B refusal silence window
  reg f_watch = 0;
  integer f_watch_mems = 0, f_watch_reqs = 0;
  always @(posedge clk_cpu)
    if (f_watch && fb_creq) f_watch_reqs = f_watch_reqs + 1;
  always @(posedge clk_stor)
    if (f_watch && mem_start_w) f_watch_mems = f_watch_mems + 1;

  task b_op(input with_start, input wr, input [15:0] blk1, input [15:0] blk2,
            input [10:0] wc, input [31:0] max_cycles,
            output reg ok, output reg err);
    integer g;
    begin
      @(posedge clk_cpu);
      fb_wr    <= wr;
      fb_blk1  <= blk1;
      fb_blk2  <= blk2;
      fb_wc    <= wc;
      fb_unit  <= 3'd0;
      fb_req   <= 1'b1;
      fb_start <= with_start;
      @(posedge clk_cpu);
      fb_req   <= 1'b0;
      fb_start <= 1'b0;
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
    $dumpfile("nd_storage_disc_adapter_tb.vcd");
    $dumpvars(0, nd_storage_disc_adapter_tb);
`endif
    repeat (10) @(posedge clk_stor);
    rst_n = 1;
    repeat (20) @(posedge clk_cpu);

    // ---- Tier A ---------------------------------------------------------

    // (a1) not open: read request -> clean done+err, zero client traffic
    a_op(1'b1, 1'b0, 16'd0, 16'd0, 11'd1024, 3'd0, 32'd4000, gok, gerr);
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

    // (a3) boot-shape read: start+req same cycle, base 0, wc 1024
    a_op(1'b1, 1'b0, 16'd0, 16'd0, 11'd1024, 3'd0, 32'd20000, gok, gerr);
    if (!gok || gerr) begin
      $display("TB_RESULT: FAIL (a3) boot read did not complete (ok=%b err=%b)", gok, gerr);
      $finish;
    end
    a_check_cap(0, 11'd1024, 3);
    if (u_fetches !== 1) begin
      $display("FAIL: (a3) fetch count %0d (want 1)", u_fetches);
      errors = errors + 1;
    end

    // (a4) continuation chunk (req only): position advanced to word 1024
    a_op(1'b0, 1'b0, 16'd0, 16'd0, 11'd1024, 3'd0, 32'd20000, gok, gerr);
    if (!gok || gerr) begin
      $display("FAIL: (a4) continuation read (ok=%b err=%b)", gok, gerr);
      errors = errors + 1;
    end
    a_check_cap(1024, 11'd1024, 4);
    if (u_fetches !== 2) begin
      $display("FAIL: (a4) fetch count %0d (want 2)", u_fetches);
      errors = errors + 1;
    end

    // (a5) block-spanning read: base sector 1 = word 512, wc 1024 covers
    // words 512..1535 = block 0 tail + block 1 head -> exactly two fetches
    f0 = u_fetches;
    a_op(1'b1, 1'b0, 16'd1, 16'd0, 11'd1024, 3'd0, 32'd40000, gok, gerr);
    if (!gok || gerr) begin
      $display("TB_RESULT: FAIL (a5) spanning read (ok=%b err=%b)", gok, gerr);
      $finish;
    end
    a_check_cap(512, 11'd1024, 5);
    if (u_fetches !== f0 + 2) begin
      $display("FAIL: (a5) fetch count %0d (want %0d)", u_fetches, f0 + 2);
      errors = errors + 1;
    end

    // (a6) partial mid-block read: base sector 1 = word 512, wc 100
    a_op(1'b1, 1'b0, 16'd1, 16'd0, 11'd100, 3'd0, 32'd20000, gok, gerr);
    if (!gok || gerr) begin
      $display("FAIL: (a6) partial read (ok=%b err=%b)", gok, gerr);
      errors = errors + 1;
    end
    a_check_cap(512, 11'd100, 6);

    // (a7) aligned full-block write: base sector 2 = word 1024 (block 1),
    // wc 1024 -> ONE client write, NO pre-read
    for (k = 0; k < 1024; k = k + 1) ta_dev[k] = wpatB(k);
    f0 = u_fetches;
    a_expect_write(1024, 11'd1024);
    a_op(1'b1, 1'b1, 16'd2, 16'd0, 11'd1024, 3'd0, 32'd40000, gok, gerr);
    if (!gok || gerr) begin
      $display("TB_RESULT: FAIL (a7) aligned block write (ok=%b err=%b)", gok, gerr);
      $finish;
    end
    if (u_fetches !== f0) begin
      $display("FAIL: (a7) aligned write issued a pre-read (%0d)",
               u_fetches - f0);
      errors = errors + 1;
    end
    if (u_writes !== 1) begin
      $display("FAIL: (a7) write count %0d (want 1)", u_writes);
      errors = errors + 1;
    end
    a_check_img(7);

    // (a8) multi-chunk aligned write: start at 0, chunk 1024 (block 0),
    // continuation chunk 1024 (block 1)
    for (k = 0; k < 1024; k = k + 1) ta_dev[k] = wpatC(k);
    a_expect_write(0, 11'd1024);
    a_op(1'b1, 1'b1, 16'd0, 16'd0, 11'd1024, 3'd0, 32'd40000, gok, gerr);
    if (!gok || gerr) begin
      $display("FAIL: (a8) chunk-1 write (ok=%b err=%b)", gok, gerr);
      errors = errors + 1;
    end
    for (k = 0; k < 1024; k = k + 1) ta_dev[k] = wpatC(k + 1024);
    a_expect_write(1024, 11'd1024);
    a_op(1'b0, 1'b1, 16'd0, 16'd0, 11'd1024, 3'd0, 32'd40000, gok, gerr);
    if (!gok || gerr) begin
      $display("FAIL: (a8) chunk-2 write (ok=%b err=%b)", gok, gerr);
      errors = errors + 1;
    end
    if (u_writes !== 3) begin
      $display("FAIL: (a8) write count %0d (want 3)", u_writes);
      errors = errors + 1;
    end
    a_check_img(8);

    // (a9) unaligned write (base sector 1 = word 512) and partial write:
    // done+err with zero client traffic
    f0 = u_fetches;
    k  = u_writes;
    a_op(1'b1, 1'b1, 16'd1, 16'd0, 11'd1024, 3'd0, 32'd4000, gok, gerr);
    if (!gok || !gerr) begin
      $display("FAIL: (a9) unaligned write not refused (ok=%b err=%b)", gok, gerr);
      errors = errors + 1;
    end
    // ...and say WHICH refusal it was. Before 09-AUG-2026 all three of
    // "not open", "out of range" and "unaligned" left the adapter as one
    // anonymous bit, so a driver could not tell a rejected request shape
    // from a dead card.
    if (ta_code !== `NDS_ERR_WRALIGN) begin
      $display("FAIL: (a9) unaligned write reason %0d, want WRALIGN", ta_code);
      errors = errors + 1;
    end
    a_op(1'b1, 1'b1, 16'd0, 16'd0, 11'd512, 3'd0, 32'd4000, gok, gerr);
    if (!gok || !gerr) begin
      $display("FAIL: (a9) partial write not refused (ok=%b err=%b)", gok, gerr);
      errors = errors + 1;
    end
    if (ta_code !== `NDS_ERR_WRALIGN) begin
      $display("FAIL: (a9) partial write reason %0d, want WRALIGN", ta_code);
      errors = errors + 1;
    end
    if (u_fetches !== f0 || u_writes !== k) begin
      $display("FAIL: (a9) refused writes caused traffic (%0d/%0d)",
               u_fetches - f0, u_writes - k);
      errors = errors + 1;
    end
    a_check_img(9);

    // (a10) out-of-range read: cylinder 1 = word 46080, far past the 2048-
    // word file; a read ending exactly at EOF (sector 3, wc 512) works
    f0 = u_fetches;
    a_op(1'b1, 1'b0, 16'd0, 16'd1, 11'd64, 3'd0, 32'd4000, gok, gerr);
    if (!gok || !gerr) begin
      $display("FAIL: (a10) out-of-range read (ok=%b err=%b)", gok, gerr);
      errors = errors + 1;
    end
    if (ta_code !== `NDS_ERR_RANGE) begin
      $display("FAIL: (a10) out-of-range reason %0d, want RANGE", ta_code);
      errors = errors + 1;
    end
    if (u_fetches !== f0) begin
      $display("FAIL: (a10) out-of-range caused traffic");
      errors = errors + 1;
    end
    a_op(1'b1, 1'b0, 16'd3, 16'd0, 11'd512, 3'd0, 32'd20000, gok, gerr);
    if (!gok || gerr) begin
      $display("FAIL: (a10) EOF-boundary read refused (ok=%b err=%b)", gok, gerr);
      errors = errors + 1;
    end
    if (ta_code !== `NDS_ERR_NONE) begin
      $display("FAIL: (a10) a SUCCESS reported reason %0d, want NONE", ta_code);
      errors = errors + 1;
    end
    a_check_cap(1536, 11'd512, 10);

    // (a11) c_err on the FETCH: done+err, retry succeeds; c_err on the
    // COMMIT: done+err, image unchanged
    u_err_inject = 1;
    u_err_code   = `NDS_ERR_NOCARD;   // a specific reason from nd_storage
    f0 = u_fetches;
    a_op(1'b1, 1'b0, 16'd0, 16'd0, 11'd1024, 3'd0, 32'd20000, gok, gerr);
    if (!gok || !gerr) begin
      $display("FAIL: (a11) fetch c_err not reported (ok=%b err=%b)", gok, gerr);
      errors = errors + 1;
    end
    // the reason must arrive UNCHANGED - the adapter passes it on, it does
    // not substitute a verdict of its own
    if (ta_code !== `NDS_ERR_NOCARD) begin
      $display("FAIL: (a11) fetch reason %0d, want the injected NOCARD",
               ta_code);
      errors = errors + 1;
    end
    if (u_fetches !== f0 + 1) begin
      $display("FAIL: (a11) errored fetch not attempted");
      errors = errors + 1;
    end
    u_err_inject = 0;
    a_op(1'b1, 1'b0, 16'd0, 16'd0, 11'd1024, 3'd0, 32'd20000, gok, gerr);
    if (!gok || gerr) begin
      $display("FAIL: (a11) retry after fetch c_err (ok=%b err=%b)", gok, gerr);
      errors = errors + 1;
    end
    a_check_cap(0, 11'd1024, 11);
    u_err_on_wr = 1;
    u_err_code  = `NDS_ERR_CARDIO;
    for (k = 0; k < 1024; k = k + 1) ta_dev[k] = wpatB(k + 7);
    a_op(1'b1, 1'b1, 16'd0, 16'd0, 11'd1024, 3'd0, 32'd40000, gok, gerr);
    if (!gok || !gerr) begin
      $display("FAIL: (a11) commit c_err not reported (ok=%b err=%b)", gok, gerr);
      errors = errors + 1;
    end
    if (ta_code !== `NDS_ERR_CARDIO) begin
      $display("FAIL: (a11) commit reason %0d, want the injected CARDIO",
               ta_code);
      errors = errors + 1;
    end
    a_check_img(11);  // failed commit must not have changed the stub image
    u_err_on_wr = 0;
    a_expect_write(0, 11'd1024);
    a_op(1'b1, 1'b1, 16'd0, 16'd0, 11'd1024, 3'd0, 32'd40000, gok, gerr);
    if (!gok || gerr) begin
      $display("FAIL: (a11) retry after commit c_err (ok=%b err=%b)", gok, gerr);
      errors = errors + 1;
    end
    a_check_img(11);

    // (a12) unit mismatch: UNIT=0 adapter must be TOTALLY silent for a
    // unit-1 request (a per-unit instance set ORs its pins)
    f0 = u_fetches;
    k  = u_writes;
    a_op(1'b1, 1'b0, 16'd0, 16'd0, 11'd1024, 3'd1, 32'd400, gok, gerr);
    if (gok) begin
      $display("FAIL: (a12) adapter answered a unit-1 request");
      errors = errors + 1;
    end
    if (u_fetches !== f0 || u_writes !== k) begin
      $display("FAIL: (a12) unit-1 request caused traffic");
      errors = errors + 1;
    end
    a_op(1'b1, 1'b0, 16'd0, 16'd0, 11'd1024, 3'd0, 32'd20000, gok, gerr);
    if (!gok || gerr) begin
      $display("FAIL: (a12) unit-0 request after mismatch (ok=%b err=%b)",
               gok, gerr);
      errors = errors + 1;
    end

    // (a13) wc=0: clean completion, zero traffic
    f0 = u_fetches;
    k  = u_writes;
    a_op(1'b1, 1'b0, 16'd0, 16'd0, 11'd0, 3'd0, 32'd4000, gok, gerr);
    if (!gok || gerr) begin
      $display("FAIL: (a13) wc=0 (ok=%b err=%b)", gok, gerr);
      errors = errors + 1;
    end
    if (u_fetches !== f0 || u_writes !== k) begin
      $display("FAIL: (a13) wc=0 caused traffic");
      errors = errors + 1;
    end

    // (aM1) M1-shape: start-only pulse, then the chunk req later
    a_start(16'd2, 16'd0, 3'd0);   // sector 2 = word 1024
    repeat (5) @(posedge clk_cpu);
    for (k = 0; k < 1024; k = k + 1) ta_dev[k] = wpatC(k + 5);
    a_expect_write(1024, 11'd1024);
    a_op(1'b0, 1'b1, 16'd0, 16'd0, 11'd1024, 3'd0, 32'd40000, gok, gerr);
    if (!gok || gerr) begin
      $display("FAIL: (aM1) start-then-req write (ok=%b err=%b)", gok, gerr);
      errors = errors + 1;
    end
    a_check_img(14);

    $display("tier A (unit stub) done: %0d errors, %0d fetches, %0d writes",
             errors, u_fetches, u_writes);

    // ---- Tier B ---------------------------------------------------------

    // whole-card snapshot BEFORE any tier-B activity
    for (k = 0; k < IMG_BYTES; k = k + 1) card_shadow[k] = card.mem[k];

    // (b1) open FLOPPY1.IMG-as-SMD-image (client 1) via open_start
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
      $display("TB_RESULT: FAIL (b1) open did not complete (oerr=%b)",
               open_err_w[1]);
      $finish;
    end
    repeat (50) @(posedge clk_cpu);
    if (size_bytes_w[63:32] !== IMG_FILE_BYTES[31:0]) begin
      $display("FAIL: (b1) size_bytes %0d (want %0d)",
               size_bytes_w[63:32], IMG_FILE_BYTES);
      errors = errors + 1;
    end
    f_first_sec = dut_s.s_first_sector[63:32];
    $display("[tb] image first card sector = %0d", f_first_sec);

    // (b2) boot-shape read chunk + continuation chunk, byte-exact
    b_op(1'b1, 1'b0, 16'd0, 16'd0, 11'd1024, 32'd3_000_000, gok, gerr);
    if (!gok || gerr) begin
      $display("TB_RESULT: FAIL (b2) boot read chunk 1 (ok=%b err=%b)", gok, gerr);
      $finish;
    end
    for (b = 0; b < 1024; b = b + 1) begin
      if (fb_cap[b] !== fw(b)) begin
        if (errors < 10)
          $display("FAIL: (b2) chunk-1 word %0d: got %04x want %04x",
                   b, fb_cap[b], fw(b));
        errors = errors + 1;
      end
    end
    b_op(1'b0, 1'b0, 16'd0, 16'd0, 11'd1024, 32'd3_000_000, gok, gerr);
    if (!gok || gerr) begin
      $display("TB_RESULT: FAIL (b2) boot read chunk 2 (ok=%b err=%b)", gok, gerr);
      $finish;
    end
    for (b = 0; b < 1024; b = b + 1) begin
      if (fb_cap[b] !== fw(1024 + b)) begin
        if (errors < 10)
          $display("FAIL: (b2) chunk-2 word %0d: got %04x want %04x",
                   b, fb_cap[b], fw(1024 + b));
        errors = errors + 1;
      end
    end

    // (b3) block-spanning read: base sector 1 (word 512), wc 1024
    b_op(1'b1, 1'b0, 16'd1, 16'd0, 11'd1024, 32'd6_000_000, gok, gerr);
    if (!gok || gerr) begin
      $display("TB_RESULT: FAIL (b3) spanning read (ok=%b err=%b)", gok, gerr);
      $finish;
    end
    for (b = 0; b < 1024; b = b + 1) begin
      if (fb_cap[b] !== fw(512 + b)) begin
        if (errors < 10)
          $display("FAIL: (b3) word %0d: got %04x want %04x",
                   b, fb_cap[b], fw(512 + b));
        errors = errors + 1;
      end
    end

    // (b4) aligned full-block write to block 1 (base sector 2 = word 1024):
    // card bytes at first_sector+4..5, read-back, block 0 preserved
    for (k = 0; k < 1024; k = k + 1) fb_dev[k] = wpatB(k);
    b_op(1'b1, 1'b1, 16'd2, 16'd0, 11'd1024, 32'd6_000_000, gok, gerr);
    if (!gok || gerr) begin
      $display("TB_RESULT: FAIL (b4) block write (ok=%b err=%b)", gok, gerr);
      $finish;
    end
    // card check: file bytes 2048..4095 = card sectors first_sec+4/+5/+6/+7
    for (k = 0; k < 2048; k = k + 1) begin
      expb = (k % 2 == 0) ? wpatB(k / 2) >> 8 : wpatB(k / 2) & 8'hFF;
      if (card.mem[(f_first_sec+4)*512+k] !== expb) begin
        if (errors < 10)
          $display("FAIL: (b4) card byte %0d of the written block: got %02x want %02x",
                   k, card.mem[(f_first_sec+4)*512+k], expb);
        errors = errors + 1;
      end
    end
    // read-back through the disk port
    b_op(1'b1, 1'b0, 16'd2, 16'd0, 11'd1024, 32'd3_000_000, gok, gerr);
    if (!gok || gerr) begin
      $display("FAIL: (b4) read-back (ok=%b err=%b)", gok, gerr);
      errors = errors + 1;
    end
    for (b = 0; b < 1024; b = b + 1) begin
      if (fb_cap[b] !== wpatB(b)) begin
        if (errors < 10)
          $display("FAIL: (b4) read-back word %0d: got %04x want %04x",
                   b, fb_cap[b], wpatB(b));
        errors = errors + 1;
      end
    end
    // block 0 must be untouched
    b_op(1'b1, 1'b0, 16'd0, 16'd0, 11'd1024, 32'd3_000_000, gok, gerr);
    for (b = 0; b < 1024; b = b + 1) begin
      if (fb_cap[b] !== fw(b)) begin
        if (errors < 10)
          $display("FAIL: (b4) untouched word %0d changed: got %04x want %04x",
                   b, fb_cap[b], fw(b));
        errors = errors + 1;
      end
    end

    // (b5) unaligned write refused with ZERO c_req/mem-port traffic
    f_watch_mems = 0;
    f_watch_reqs = 0;
    f_watch = 1;
    b_op(1'b1, 1'b1, 16'd1, 16'd0, 11'd1024, 32'd2000, gok, gerr);
    if (!gok || !gerr) begin
      $display("FAIL: (b5) unaligned write (ok=%b err=%b)", gok, gerr);
      errors = errors + 1;
    end
    b_op(1'b1, 1'b0, 16'd0, 16'd1, 11'd64, 32'd2000, gok, gerr);
    if (!gok || !gerr) begin
      $display("FAIL: (b5) out-of-range read (ok=%b err=%b)", gok, gerr);
      errors = errors + 1;
    end
    f_watch = 0;
    if (f_watch_reqs !== 0 || f_watch_mems !== 0) begin
      $display("FAIL: (b5) refusals not silent (req=%0d mem=%0d)",
               f_watch_reqs, f_watch_mems);
      errors = errors + 1;
    end

    // (b6) whole-card shadow compare: ONLY the written block may differ
    shadow_diffs = 0;
    for (k = 0; k < IMG_BYTES; k = k + 1) begin
      if (k >= (f_first_sec + 4) * 512 && k < (f_first_sec + 8) * 512) begin
        b    = k - (f_first_sec + 4) * 512;
        expb = (b % 2 == 0) ? wpatB(b / 2) >> 8 : wpatB(b / 2) & 8'hFF;
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

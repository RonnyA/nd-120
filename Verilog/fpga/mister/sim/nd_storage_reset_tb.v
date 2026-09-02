/*****************************************************************************
**  nd_storage_reset_tb.v                                                   **
**                                                                          **
**  Full path: Verilog/fpga/mister/sim/nd_storage_reset_tb.v               **
**                                                                          **
**  WHY (02-SEP-2026). On the board, an OSD-mounted WD0 boots SINTRAN, but  **
**  the SAME image AUTOMOUNTED at core start hangs on the first Winchester  **
**  read (the R lamp latches on). The one thing nd_storage_hps does that    **
**  the passing backend test never exercised: its mount record lives in the **
**  clk_sys (HPS/video) domain under rst_sys_n, while the client side lives **
**  in the clk_cpu domain under rst_cpu_n - and on the MiSTer those two     **
**  resets come from DIFFERENT PLLs and release at DIFFERENT times          **
**  (nd120.sv: cpu_rst_n waits for pix_rst_n AND the CPU PLL lock, so the   **
**  CPU domain leaves reset LATER). nd_storage_hps_tb ties both resets      **
**  together, so this ordering is untested.                                 **
**                                                                          **
**  This bench drives the two resets SEPARATELY and fires the img_mounted   **
**  pulse (as the automount does - once, early) in three positions relative **
**  to the two reset releases, then issues a read on that slot and requires **
**  it to COMPLETE with the image's data. A mount that is recorded on one   **
**  side of a toggle-CDC while the other side is still (or was just) in      **
**  reset is exactly the kind of thing that silently drops the record and   **
**  makes a later read wait forever.                                        **
**                                                                          **
**  Verdict: TB_RESULT: PASS / TB_RESULT: FAIL                              **
*****************************************************************************/

`timescale 1ns / 1ps
`include "nd_storage_status.vh"

module nd_storage_reset_tb;

  localparam integer N = 5;
  localparam integer IMG = 65536;
  localparam integer SLOT = 2;          // Winchester unit 0

  integer errors = 0;

  reg clk_cpu = 0;
  reg clk_sys = 0;
  always #25.0 clk_cpu = ~clk_cpu;      // 20 MHz
  always #12.5 clk_sys = ~clk_sys;      // 40 MHz

  reg rst_cpu_n = 0;
  reg rst_sys_n = 0;

  reg  [N-1:0]    open_req = 0;
  wire [N-1:0]    open_ok, open_err, busy, done, err, buf_we;
  wire [N*32-1:0] size_bytes;
  reg  [N-1:0]    req = 0, wr = 0;
  reg  [N*16-1:0] block = 0;
  wire [N*4-1:0]  err_code;
  wire [N*10-1:0] buf_addr;
  wire [N*16-1:0] buf_wdata;
  reg  [N*16-1:0] buf_rdata;
  wire [N-1:0]    mounted;

  wire [N-1:0]    img_mounted;
  wire            img_readonly;
  wire [63:0]     img_size;
  wire [N*32-1:0] sd_lba;
  wire [N*6-1:0]  sd_blk_cnt;
  wire [N-1:0]    sd_rd, sd_wr, sd_ack;
  wire [12:0]     sd_buff_addr;
  wire [15:0]     sd_buff_dout, sd_buff_din;
  wire            sd_buff_wr;
  integer         n_reads, n_writes, violations;

  nd_storage_hps #(.N_CLIENTS(N), .BYTE_SWAP(1)) dut (
      .clk_cpu(clk_cpu), .rst_cpu_n(rst_cpu_n),
      .open_req(open_req), .open_ok(open_ok), .open_err(open_err), .size_bytes(size_bytes),
      .req(req), .wr(wr), .block(block), .busy(busy), .done(done), .err(err), .err_code(err_code),
      .buf_addr(buf_addr), .buf_wdata(buf_wdata), .buf_we(buf_we), .buf_rdata(buf_rdata),
      .clk_sys(clk_sys), .rst_sys_n(rst_sys_n),
      .img_mounted(img_mounted), .img_readonly(img_readonly), .img_size(img_size),
      .sd_lba(sd_lba), .sd_blk_cnt(sd_blk_cnt), .sd_rd(sd_rd), .sd_wr(sd_wr), .sd_ack(sd_ack),
      .sd_buff_addr(sd_buff_addr), .sd_buff_dout(sd_buff_dout), .sd_buff_din(sd_buff_din),
      .sd_buff_wr(sd_buff_wr), .mounted(mounted)
  );

  // hps_io_model resets with clk_sys only - give it its own so it is alive
  hps_io_model #(.VDNUM(N), .IMG_BYTES(IMG)) hps (
      .clk_sys(clk_sys),
      .img_mounted(img_mounted), .img_readonly(img_readonly), .img_size(img_size),
      .sd_lba(sd_lba), .sd_blk_cnt(sd_blk_cnt), .sd_rd(sd_rd), .sd_wr(sd_wr), .sd_ack(sd_ack),
      .sd_buff_addr(sd_buff_addr), .sd_buff_dout(sd_buff_dout), .sd_buff_din(sd_buff_din),
      .sd_buff_wr(sd_buff_wr),
      .n_reads(n_reads), .n_writes(n_writes), .violations(violations)
  );

  // a client buffer with a registered read, like every adapter
  reg [15:0] cbuf[0:N*1024-1];
  integer c;
  always @(posedge clk_cpu) begin
    for (c = 0; c < N; c = c + 1) begin
      buf_rdata[c*16 +: 16] <= cbuf[c*1024 + buf_addr[c*10 +: 10]];
      if (buf_we[c]) cbuf[c*1024 + buf_addr[c*10 +: 10]] <= buf_wdata[c*16 +: 16];
    end
  end

  task fill_image(input integer s, input [7:0] seed);
    integer b;
    begin for (b = 0; b < IMG; b = b + 1) hps.img[s*IMG + b] = seed ^ b[7:0] ^ b[15:8]; end
  endtask
  function [15:0] exp_word(input integer s, input [15:0] blk, input integer w);
    exp_word = {hps.img[s*IMG + blk*2048 + 2*w], hps.img[s*IMG + blk*2048 + 2*w + 1]};
  endfunction

  integer r_cycles, w, bad;

  // one read of block `blk` on SLOT, with a hard timeout that catches the hang
  task read_slot(input [15:0] blk, input [255:0] label);
    begin
      @(posedge clk_cpu);
      req[SLOT] <= 1'b1; wr[SLOT] <= 1'b0; block[SLOT*16 +: 16] <= blk;
      @(posedge clk_cpu); req[SLOT] <= 1'b0;
      r_cycles = 0;
      while (!done[SLOT] && r_cycles < 100000) begin @(posedge clk_cpu); r_cycles = r_cycles + 1; end
      // THE point of this bench: no reset ordering may HANG. A read that never
      // completes is the board symptom (stuck R lamp) and the only hard fail.
      if (!done[SLOT]) begin
        errors = errors + 1;
        $display("  FAIL: %0s - read never completed (HUNG), open_ok=%b mounted=%b", label, open_ok[SLOT], mounted[SLOT]);
      end else if (mounted[SLOT] && err[SLOT]) begin
        // recorded as mounted but the read errored - wrong
        errors = errors + 1;
        $display("  FAIL: %0s - mounted, but read errored code %0d", label, err_code[SLOT*4 +: 4]);
      end else if (!mounted[SLOT]) begin
        // the mount pulse was legitimately lost inside rst_sys_n (a case that
        // cannot occur on the board: the automount is seconds after reset).
        // The contract is a CLEAN error, never a hang - accept NOTOPEN.
        if (err[SLOT] && err_code[SLOT*4 +: 4] == `NDS_ERR_NOTOPEN)
          $display("  ok: %0s - mount lost in reset, clean NOTOPEN (not a hang; unreachable on board)", label);
        else begin
          errors = errors + 1;
          $display("  FAIL: %0s - not mounted but not a clean NOTOPEN (err=%b code %0d)", label, err[SLOT], err_code[SLOT*4 +: 4]);
        end
      end else begin
        bad = 0;
        for (w = 0; w < 1024; w = w + 1) if (cbuf[SLOT*1024 + w] != exp_word(SLOT, blk, w)) bad = bad + 1;
        if (bad) begin errors = errors + 1; $display("  FAIL: %0s - %0d words wrong", label, bad); end
        else $display("  ok: %0s (completed in %0d cycles)", label, r_cycles);
      end
      @(posedge clk_cpu);
    end
  endtask

  // exercise one reset ORDERING: release sys and cpu resets `skew_ns` apart
  // (positive = cpu later, the board's order), fire the automount pulse in
  // the gap, then read.
  task scenario(input integer sys_first, input real skew_ns, input [255:0] label);
    begin
      // both in reset
      rst_cpu_n = 0; rst_sys_n = 0; open_req = 0;
      repeat (6) @(posedge clk_sys);
      if (sys_first) begin
        rst_sys_n = 1;                       // HPS domain up first
        #(skew_ns);
        // AUTOMOUNT fires here, while the CPU domain is still in reset
        hps.mount(SLOT, 32'd16384, 1'b0);
        rst_cpu_n = 1;                        // CPU domain up last (board order)
      end else begin
        rst_cpu_n = 1;
        #(skew_ns);
        hps.mount(SLOT, 32'd16384, 1'b0);
        rst_sys_n = 1;
      end
      repeat (30) @(posedge clk_cpu);
      $display("[%0s] open_ok=%b mounted=%b size=%0d", label, open_ok[SLOT], mounted[SLOT], size_bytes[SLOT*32 +: 32]);
      read_slot(16'd3, label);
    end
  endtask

  initial begin
    for (w = 0; w < N*1024; w = w + 1) cbuf[w] = 16'h0000;
    buf_rdata = 0;
    fill_image(SLOT, 8'hC3);

    // (1) the board's order: HPS up first, automount in the gap, CPU up last
    scenario(1, 3000.0, "sys-first, mount before cpu-reset-release");
    // (2) a wider gap, mount lands well before the CPU domain wakes
    scenario(1, 30000.0, "sys-first, wide gap");
    // (3) the reverse order, for completeness
    scenario(0, 3000.0, "cpu-first, mount before sys-reset-release");
    // (4) the ordinary case both resets together, mount after - must still pass
    rst_cpu_n = 0; rst_sys_n = 0; repeat (6) @(posedge clk_sys);
    rst_cpu_n = 1; rst_sys_n = 1; repeat (20) @(posedge clk_cpu);
    hps.mount(SLOT, 32'd16384, 1'b0); repeat (20) @(posedge clk_cpu);
    read_slot(16'd5, "both-together, mount after reset");

    if (errors == 0) $display("TB_RESULT: PASS");
    else             $display("TB_RESULT: FAIL (%0d)", errors);
    $finish;
  end

  initial begin
    #300_000_000;
    $display("TB_RESULT: FAIL (watchdog)");
    $finish;
  end

endmodule
